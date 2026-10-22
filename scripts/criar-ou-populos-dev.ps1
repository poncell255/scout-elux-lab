# Cria a OU "Populos Dev": cópia da OU Populos (apps, tema, Kerberos) com setup próprio (clone do setup 0, com AD)
# e home persistente (Setup.PersistentHomeApplications='ALL'); adiciona VS Code (vscode.dev) e OneDrive como apps do Edge.
# OneDrive: use o endereço do OneDrive corporativo do tenant (<tenant>-my.sharepoint.com); microsoft365.com/onedrive dá "page doesn't exist".
param([int]$SetupOrigem = 0, [int]$OuOrigem = 4, [string]$Nome = 'Populos Dev', [string]$Icones = 'C:\ScoutSetup\icons', [string]$OneDrive = 'https://populos-my.sharepoint.com')
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-populos-dev.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"

$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction(); $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ $v=$p[$k]; if($v -is [byte[]]){ $q=$z.Parameters.Add($k,[Data.SqlDbType]::VarBinary,-1); $q.Value=$v } else { [void]$z.Parameters.AddWithValue($k,$v) } }; $z.ExecuteScalar() }
function Cols($t,$excl){ $l=($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
function Lista($sql){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; $r=$z.ExecuteReader(); $o=@(); while($r.Read()){ $o+=$r.GetInt32(0) }; $r.Close(); ,$o }
try {
  if((X "SELECT COUNT(*) FROM Groups WHERE Name=@n" @{'@n'=$Nome}) -gt 0){ throw "OU $Nome ja existe" }

  # --- setup novo (clone do setup base, com AD) + home persistente ---
  $s=X "SELECT MAX(SetupID)+1 FROM Setup WITH (UPDLOCK, HOLDLOCK)"
  $k=Cols 'Setup' @('SetupID'); [void](X "INSERT INTO Setup (SetupID,$k) SELECT @s,$k FROM Setup WHERE SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  foreach($t in @(@{t='ScreenSaver';pk='ScreenSaverID'},@{t='ComPort';pk='ComPortID'},@{t='NetworkProfile';pk='NetworkProfileID'},@{t='EluxVarList';pk='EluxVarListID'},@{t='HostList';pk='HostListID'},@{t='NetDrive';pk='NetDriveID'},@{t='Printer';pk='PrinterID'},@{t='ServerList';pk='ServerListID'})){
    $k=Cols $t.t @($t.pk,'SetupID')
    $n=X "INSERT INTO [$($t.t)] ([$($t.pk)],SetupID,$k) SELECT mx.v+ROW_NUMBER() OVER(ORDER BY o.[$($t.pk)]),@s,$k FROM [$($t.t)] o CROSS JOIN (SELECT ISNULL(MAX([$($t.pk)]),0) v FROM [$($t.t)] WITH (UPDLOCK, HOLDLOCK)) mx WHERE o.SetupID=@src; SELECT @@ROWCOUNT" @{'@s'=$s;'@src'=$SetupOrigem}
    "  $($t.t): $n" }
  foreach($t in 'PowerManagementProfile','AuthDomain'){ $k=Cols $t @('SetupID'); $n=X "INSERT INTO [$t] (SetupID,$k) SELECT @s,$k FROM [$t] WHERE SetupID=@src; SELECT @@ROWCOUNT" @{'@s'=$s;'@src'=$SetupOrigem}; "  ${t}: $n" }
  $k=Cols 'Multimedia' @('MemberType','MemberID'); [void](X "INSERT INTO Multimedia (MemberType,MemberID,$k) SELECT 5,@s,$k FROM Multimedia WHERE MemberType=5 AND MemberID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  $k=Cols 'ScreenSettings' @('MemberType','MemberID'); $ss=X "INSERT INTO ScreenSettings (MemberType,MemberID,$k) SELECT 5,@s,$k FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src; SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@s'=$s;'@src'=$SetupOrigem}
  $old=X "SELECT ScreenSettingsID FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src" @{'@src'=$SetupOrigem}
  $k=Cols 'Screen' @('ScreenSettingsID'); [void](X "INSERT INTO Screen (ScreenSettingsID,$k) SELECT @n,$k FROM Screen WHERE ScreenSettingsID=@o" @{'@n'=$ss;'@o'=$old})
  [void](X "UPDATE Setup SET PersistentHomeApplications='ALL' WHERE SetupID=@s" @{'@s'=$s})
  "  setup $s criado (clone do $SetupOrigem, com AD, home persistente ALL)"

  # --- OU (cópia da Populos, com setup próprio) ---
  $ou=X "SELECT MAX(GroupID)+1 FROM Groups WITH (UPDLOCK, HOLDLOCK)"; $k=Cols 'Groups' @('GroupID','Name','DeviceCount','UseParent','SetupID')
  [void](X "INSERT INTO Groups (GroupID,Name,DeviceCount,UseParent,SetupID,$k) SELECT @ou,@nome,0,0,@s,$k FROM Groups WHERE GroupID=@src" @{'@ou'=$ou;'@nome'=$Nome;'@s'=$s;'@src'=$OuOrigem}); "  OU ${Nome}: GroupID $ou"

  # --- apps da Populos ---
  $ka=Cols 'Application' @('ApplicationID','GroupID')
  foreach($a in (Lista "SELECT ApplicationID FROM Application WHERE GroupID=$OuOrigem ORDER BY ApplicationID")){
    $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
    [void](X "INSERT INTO Application (ApplicationID,GroupID,$ka) SELECT @id,@ou,$ka FROM Application WHERE ApplicationID=@a" @{'@id'=$id;'@ou'=$ou;'@a'=$a})
    foreach($t in 'Browser','Local','RDP','Storefront','VDA','AVD'){ $k=Cols $t @('ApplicationID'); [void](X "INSERT INTO [$t] (ApplicationID,$k) SELECT @id,$k FROM [$t] WHERE ApplicationID=@a" @{'@id'=$id;'@a'=$a}) }
    "  app $a -> $id" }

  # --- apps novos (Edge em modo app) + ícones globais ---
  foreach($novo in @(@{Nome='VS Code';Icone='vscode';Url='https://vscode.dev'},@{Nome='OneDrive';Icone='onedrive';Url=$OneDrive})){
    if((X "SELECT COUNT(*) FROM UCFT WHERE MemberType=-1 AND MemberID=-1 AND FileType=1 AND FileName=@f" @{'@f'="$($novo.Icone).png"}) -eq 0){
      $png=[IO.File]::ReadAllBytes("$Icones\$($novo.Icone).png")
      [void](X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (-1,-1,1,@f,-1,0,@tm,@fc)" @{'@f'="$($novo.Icone).png";'@tm'=$now;'@fc'=$png}) }
    $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
    [void](X "INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1) VALUES (@id,5,@n,0,0,1,0,1,@ou,@ic,0,-1,1,'',@n,0)" @{'@id'=$id;'@n'=$novo.Nome;'@ou'=$ou;'@ic'=$novo.Icone})
    [void](X "INSERT INTO Local (ApplicationID, Type, Parameter, Hidden) VALUES (@id,'CUSTOM',@p,0)" @{'@id'=$id;'@p'="/usr/bin/microsoft-edge --app=$($novo.Url) --no-first-run"})
    "  app $($novo.Nome) -> $id (ícone $($novo.Icone).png)" }

  # --- arquivos da Populos (tema + Kerberos) e entradas INI ---
  $f=$cn.CreateCommand(); $f.Transaction=$tx; $f.CommandText="SELECT f.FileSource, f.FileDestination, f.Description, u.FileContent FROM FileEntry f JOIN UCFT u ON u.UCFTID=f.UCFTID WHERE f.MemberType=1 AND f.MemberID=$OuOrigem"; $da=[System.Data.SqlClient.SqlDataAdapter]::new($f); $tb=[System.Data.DataTable]::new(); [void]$da.Fill($tb)
  foreach($r in $tb.Rows){
    $u=X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou'=$ou;'@n'=$r.FileSource;'@tm'=$now;'@fc'=[byte[]]$r.FileContent}
    [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$ou;'@n'=$r.FileSource;'@d'=$r.FileDestination;'@ds'=$r.Description;'@u'=$u}) }
  [void](X "INSERT INTO IniEntry (IniEntryID, MemberType, MemberID, IniFile, IniSection, IniKey, IniValue) SELECT (SELECT ISNULL(MAX(IniEntryID),0) FROM IniEntry)+ROW_NUMBER() OVER(ORDER BY IniEntryID), 1, @ou, IniFile, IniSection, IniKey, IniValue FROM IniEntry WHERE MemberType=1 AND MemberID=@src" @{'@ou'=$ou;'@src'=$OuOrigem})
  "  arquivos copiados ($($tb.Rows.Count))"

  $tx.Commit(); "COMMIT OK: OU $ou / setup $s"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
