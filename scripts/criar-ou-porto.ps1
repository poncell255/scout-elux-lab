# Cria a OU "Porto": cÃ³pia da OU Populos Dev (apps e arquivos), SEM AD (AuthType 0), entrada sÃ³ por impressÃ£o digital
# (MODO_LOCAL do populos_digital), tela da digital com logo/cor da Porto, Leitor de PDF (Atril) e NICE CXone (Edge --app).
# Apps web do Edge com perfil e classe de janela prÃ³prios (--user-data-dir/--class): Ã­cone certo na barra de tarefas.
param([int]$SetupOrigem = 6, [int]$OuOrigem = 10, [string]$Nome = 'Porto', [string]$Imagem = 'populos-elux7-v11.idf',
      [string]$Logo = 'C:\Users\Administrator\Downloads\portoboot.png', [string]$CorFundo = '#0099ff',
      [string]$UrlCxone = 'https://cxone.niceincontact.com/auth', [string]$Icones = 'C:\ScoutSetup\icons')
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-porto.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction(); $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ $v=$p[$k]; if($v -is [byte[]]){ $q=$z.Parameters.Add($k,[Data.SqlDbType]::VarBinary,-1); $q.Value=$v } else { [void]$z.Parameters.AddWithValue($k,$v) } }; $z.ExecuteScalar() }
function Cols($t,$excl){ $l=($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
function Lista($sql){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; $r=$z.ExecuteReader(); $o=@(); while($r.Read()){ $o+=$r.GetInt32(0) }; $r.Close(); ,$o }
function Arquivo($ou,$nome,$destino,$desc,[byte[]]$bytes){
  $u=X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou'=$ou;'@n'=$nome;'@tm'=$now;'@fc'=$bytes}
  [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$ou;'@n'=$nome;'@d'=$destino;'@ds'=$desc;'@u'=$u}) }
function AppEdge($ou,$nomeApp,$icone,$url,$perfil){
  $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
  [void](X "INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1) VALUES (@id,5,@n,0,0,1,0,1,@ou,@ic,0,-1,1,'',@n,0)" @{'@id'=$id;'@n'=$nomeApp;'@ou'=$ou;'@ic'=$icone})
  [void](X "INSERT INTO Local (ApplicationID, Type, Parameter, Hidden) VALUES (@id,'CUSTOM',@p,0)" @{'@id'=$id;'@p'="/usr/bin/microsoft-edge --app=$url --no-first-run --user-data-dir=/home/elux/.config/microsoft-edge/app-$perfil --class=$(($nomeApp -replace '[^A-Za-z]',''))"})
  $id }
try {
  if((X "SELECT COUNT(*) FROM Groups WHERE Name=@n" @{'@n'=$Nome}) -gt 0){ throw "OU $Nome ja existe" }
  # --- setup novo (clone da Populos Dev) sem AD ---
  $s=X "SELECT MAX(SetupID)+1 FROM Setup WITH (UPDLOCK, HOLDLOCK)"
  $k=Cols 'Setup' @('SetupID'); [void](X "INSERT INTO Setup (SetupID,$k) SELECT @s,$k FROM Setup WHERE SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  foreach($t in @(@{t='ScreenSaver';pk='ScreenSaverID'},@{t='ComPort';pk='ComPortID'},@{t='NetworkProfile';pk='NetworkProfileID'},@{t='EluxVarList';pk='EluxVarListID'},@{t='HostList';pk='HostListID'},@{t='NetDrive';pk='NetDriveID'},@{t='Printer';pk='PrinterID'},@{t='ServerList';pk='ServerListID'})){
    $k=Cols $t.t @($t.pk,'SetupID')
    [void](X "INSERT INTO [$($t.t)] ([$($t.pk)],SetupID,$k) SELECT mx.v+ROW_NUMBER() OVER(ORDER BY o.[$($t.pk)]),@s,$k FROM [$($t.t)] o CROSS JOIN (SELECT ISNULL(MAX([$($t.pk)]),0) v FROM [$($t.t)] WITH (UPDLOCK, HOLDLOCK)) mx WHERE o.SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem}) }
  $k=Cols 'PowerManagementProfile' @('SetupID'); [void](X "INSERT INTO PowerManagementProfile (SetupID,$k) SELECT @s,$k FROM PowerManagementProfile WHERE SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  $k=Cols 'Multimedia' @('MemberType','MemberID'); [void](X "INSERT INTO Multimedia (MemberType,MemberID,$k) SELECT 5,@s,$k FROM Multimedia WHERE MemberType=5 AND MemberID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  $k=Cols 'ScreenSettings' @('MemberType','MemberID'); $ss=X "INSERT INTO ScreenSettings (MemberType,MemberID,$k) SELECT 5,@s,$k FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src; SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@s'=$s;'@src'=$SetupOrigem}
  $old=X "SELECT ScreenSettingsID FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src" @{'@src'=$SetupOrigem}
  $k=Cols 'Screen' @('ScreenSettingsID'); [void](X "INSERT INTO Screen (ScreenSettingsID,$k) SELECT @n,$k FROM Screen WHERE ScreenSettingsID=@o" @{'@n'=$ss;'@o'=$old})
  [void](X "UPDATE Setup SET AuthType=0, DefaultDomain=NULL, DomainFieldStatus=NULL, PersistentHomeApplications='ALL', ImageFile=@img WHERE SetupID=@s" @{'@s'=$s;'@img'=$Imagem})
  "  setup $s (clone do $SetupOrigem, sem AD, home persistente, $Imagem)"

  # --- OU ---
  $ou=X "SELECT MAX(GroupID)+1 FROM Groups WITH (UPDLOCK, HOLDLOCK)"; $k=Cols 'Groups' @('GroupID','Name','DeviceCount','UseParent','SetupID')
  [void](X "INSERT INTO Groups (GroupID,Name,DeviceCount,UseParent,SetupID,$k) SELECT @ou,@n,0,0,@s,$k FROM Groups WHERE GroupID=@src" @{'@ou'=$ou;'@n'=$Nome;'@s'=$s;'@src'=$OuOrigem}); "  OU ${Nome}: GroupID $ou"

  # --- apps da Populos Dev (apps web do Edge recriados com perfil e classe prÃ³prios) ---
  $ka=Cols 'Application' @('ApplicationID','GroupID')
  $web=@{ 'Outlook'='https://outlook.office.com'; 'Teams'='https://teams.microsoft.com'; 'OneDrive'='https://populos-my.sharepoint.com'; 'VS Code (web)'='https://vscode.dev' }
  foreach($a in (Lista "SELECT ApplicationID FROM Application WHERE GroupID=$OuOrigem ORDER BY ApplicationID")){
    $n=X "SELECT Name FROM Application WHERE ApplicationID=@a" @{'@a'=$a}; $ic=X "SELECT IconName FROM Application WHERE ApplicationID=@a" @{'@a'=$a}
    if($web.ContainsKey($n)){ $id=AppEdge $ou $n $ic $web[$n] (($n -replace '[^A-Za-z]','').ToLower()); "  app $n -> $id (Edge, perfil prÃ³prio)"; continue }
    $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
    [void](X "INSERT INTO Application (ApplicationID,GroupID,$ka) SELECT @id,@ou,$ka FROM Application WHERE ApplicationID=@a" @{'@id'=$id;'@ou'=$ou;'@a'=$a})
    foreach($t in 'Browser','Local','RDP','Storefront','VDA','AVD'){ $k=Cols $t @('ApplicationID'); [void](X "INSERT INTO [$t] (ApplicationID,$k) SELECT @id,$k FROM [$t] WHERE ApplicationID=@a" @{'@id'=$id;'@a'=$a}) }
    "  app $n -> $id" }
  # novos: NICE CXone e Leitor de PDF
  if((X "SELECT COUNT(*) FROM UCFT WHERE MemberType=-1 AND MemberID=-1 AND FileType=1 AND FileName='cxone.png'") -eq 0){
    [void](X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (-1,-1,1,'cxone.png',-1,0,@tm,@fc)" @{'@tm'=$now;'@fc'=[IO.File]::ReadAllBytes("$Icones\cxone.png")}) }
  $id=AppEdge $ou 'NICE CXone' 'cxone' $UrlCxone 'cxone'; "  app NICE CXone -> $id"
  $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
  [void](X "INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1) VALUES (@id,5,'Leitor de PDF',0,0,1,0,1,@ou,'',0,-1,1,'','Leitor de PDF',0)" @{'@id'=$id;'@ou'=$ou})
  [void](X "INSERT INTO Local (ApplicationID, Type, Parameter, Hidden) VALUES (@id,'CUSTOM','/usr/bin/atril',0)" @{'@id'=$id}); "  app Leitor de PDF -> $id"

  # --- arquivos da Populos Dev (sem tema e sem Kerberos) + entrada por digital com a marca da Porto ---
  $f=$cn.CreateCommand(); $f.Transaction=$tx; $f.CommandText="SELECT f.FileSource, f.FileDestination, f.Description, u.FileContent FROM FileEntry f JOIN UCFT u ON u.UCFTID=f.UCFTID WHERE f.MemberType=1 AND f.MemberID=$OuOrigem AND f.FileDestination NOT LIKE '/setup/elux/themes/%' AND f.FileDestination NOT LIKE '/setup/krb5.conf.d/%'"; $da=[System.Data.SqlClient.SqlDataAdapter]::new($f); $tb=[System.Data.DataTable]::new(); [void]$da.Fill($tb)
  foreach($r in $tb.Rows){ Arquivo $ou $r.FileSource $r.FileDestination $r.Description ([byte[]]$r.FileContent); "  arquivo $($r.FileDestination)" }
  $utf8=[Text.UTF8Encoding]::new($false)
  Arquivo $ou 'MODO_LOCAL' '/setup/populos-digital/MODO_LOCAL' 'Digital: entrada sem AD' ($utf8.GetBytes("entrada somente por impressao digital (OU $Nome)`n"))
  Arquivo $ou 'logo.png' '/setup/populos-digital/logo.png' 'Digital: logo da tela' ([IO.File]::ReadAllBytes($Logo))
  Arquivo $ou 'cor-fundo' '/setup/populos-digital/cor-fundo' 'Digital: cor de fundo da tela' ($utf8.GetBytes("$CorFundo`n"))
  "  arquivos da digital: MODO_LOCAL, logo.png, cor-fundo"
  $tx.Commit(); "COMMIT OK: OU $ou / setup $s"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()

