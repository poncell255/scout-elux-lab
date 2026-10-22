# Em todas as OUs: app "Google Chrome", arquivo /setup/glpi-agent/auth (senha do inventario do GLPI) e imagem com Chrome + GLPI Agent.
# Imagens (ELIAS): v12 = v4 + chrome + glpi; v13 = v5 (TV); v14 = v8 (Populos Dev); v15 = v11 (Porto).
param([string]$PaginaInicial = 'https://www.google.com', [string]$Nome = 'Google Chrome', [string]$Icones = 'C:\ScoutSetup\icons',
      [hashtable]$Imagens = @{ 0='populos-elux7-v12.idf'; 3='populos-elux7-v12.idf'; 4='populos-elux7-v12.idf'; 5='populos-elux7-v13.idf'; 6='populos-elux7-v14.idf'; 7='populos-elux7-v15.idf' })
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$auth = 'elux:' + (($c | Where-Object {$_ -match '^GLPI inventario'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-chrome-glpi.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction(); $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ $v=$p[$k]; if($v -is [byte[]]){ $q=$z.Parameters.Add($k,[Data.SqlDbType]::VarBinary,-1); $q.Value=$v } else { [void]$z.Parameters.AddWithValue($k,$v) } }; $z.ExecuteScalar() }
try {
  if((X "SELECT COUNT(*) FROM UCFT WHERE MemberType=-1 AND MemberID=-1 AND FileType=1 AND FileName='chrome.png'") -eq 0){
    [void](X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (-1,-1,1,'chrome.png',-1,0,@tm,@fc)" @{'@tm'=$now;'@fc'=[IO.File]::ReadAllBytes("$Icones\chrome.png")}) }
  $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText="SELECT GroupID FROM Groups ORDER BY GroupID"; $r=$z.ExecuteReader(); $ous=@(); while($r.Read()){ $ous+=$r.GetInt32(0) }; $r.Close()
  foreach($ou in $ous){
    if((X "SELECT COUNT(*) FROM Application WHERE GroupID=@ou AND Name=@n" @{'@ou'=$ou;'@n'=$Nome}) -eq 0){
      $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
      [void](X "INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1) VALUES (@id,5,@n,0,0,1,0,1,@ou,'chrome',0,-1,1,'',@n,0)" @{'@id'=$id;'@n'=$Nome;'@ou'=$ou})
      [void](X "INSERT INTO Local (ApplicationID, Type, Parameter, Hidden) VALUES (@id,'CUSTOM',@p,0)" @{'@id'=$id;'@p'="/usr/bin/google-chrome --no-first-run --no-default-browser-check $PaginaInicial"})
      $msg="Chrome -> $id" } else { $msg='ja tem Chrome' }
    $old=X "SELECT TOP 1 UCFTID FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination='/setup/glpi-agent/auth'" @{'@ou'=$ou}
    if($old){ [void](X "UPDATE UCFT SET FileContent=@fc, TimeModified=@tm WHERE UCFTID=@u" @{'@fc'=[Text.Encoding]::ASCII.GetBytes("$auth`n");'@tm'=$now;'@u'=$old}) }
    else {
      $u=X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,'glpi-auth',0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou'=$ou;'@tm'=$now;'@fc'=[Text.Encoding]::ASCII.GetBytes("$auth`n")}
      [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, 'glpi-auth', '/setup/glpi-agent/auth', 'GLPI Agent: usuario:senha do inventario', @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$ou;'@u'=$u}) }
    "  OU ${ou}: $msg; auth GLPI ok" }
  foreach($s in $Imagens.Keys){ [void](X "UPDATE Setup SET ImageFile=@i WHERE SetupID=@s" @{'@i'=$Imagens[$s];'@s'=[int]$s}); "  setup ${s}: $($Imagens[$s])" }
  [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1")
  $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
