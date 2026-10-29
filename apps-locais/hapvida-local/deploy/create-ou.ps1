$ErrorActionPreference='Stop'
$SetupOrigem=9; $OuOrigem=13; $Nome='HAPVIDA Local'
$src='C:\Users\Administrator\Downloads\hapvida-local'
$cred='C:\ScoutSetup\credenciais.txt';$lines=[IO.File]::ReadAllLines($cred)
$line=$lines | Where-Object {$_.StartsWith('HAPVIDA Local admin / ')} | Select-Object -First 1
if($line){$pwd=($line -split ' / ',2)[1].Trim()}else{
 $line=$lines | Where-Object {$_.StartsWith('HAPVIDA admin / ')} | Select-Object -First 1
 if(-not $line){throw 'Credencial administrativa de origem ausente'}
 $pwd=($line -split ' / ',2)[1].Trim()
 [IO.File]::AppendAllText($cred,"`r`nHAPVIDA Local admin / $pwd`r`n",[Text.UTF8Encoding]::new($false))
}
$salt=New-Object byte[] 16;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();$rng.GetBytes($salt);$rng.Dispose()
$derive=[Security.Cryptography.Rfc2898DeriveBytes]::new($pwd,$salt,210000,[Security.Cryptography.HashAlgorithmName]::SHA256)
$hash=$derive.GetBytes(32);$derive.Dispose()
$auth=@{salt=([BitConverter]::ToString($salt)).Replace('-','').ToLowerInvariant();iterations=210000;digest=([BitConverter]::ToString($hash)).Replace('-','').ToLowerInvariant()} | ConvertTo-Json -Compress
$cn=[Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True');$cn.Open()
$backup='C:\ScoutSetup\backup\ScoutEnterprise-pre-hapvida-local-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'.bak'
$z=$cn.CreateCommand();$z.CommandTimeout=600;$z.CommandText='BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM';[void]$z.Parameters.AddWithValue('@p',$backup);[void]$z.ExecuteNonQuery();$z.CommandText='RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM';[void]$z.ExecuteNonQuery();"Backup verificado: $backup"
$tx=$cn.BeginTransaction();$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandTimeout=600; $z.CommandText=$sql; foreach($k in $p.Keys){ $v=$p[$k]; if($v -is [byte[]]){ $q=$z.Parameters.Add($k,[Data.SqlDbType]::VarBinary,-1); $q.Value=$v } else { [void]$z.Parameters.AddWithValue($k,$v) } }; $z.ExecuteScalar() }
function Cols($t,$excl){ $l=($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
function Arquivo($ou,$nome,$destino,$desc,[byte[]]$bytes){
  $u=X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou'=$ou;'@n'=$nome;'@tm'=$now;'@fc'=$bytes}
  [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$ou;'@n'=$nome;'@d'=$destino;'@ds'=$desc;'@u'=$u}) }


function Rows($sql){$z=$cn.CreateCommand();$z.Transaction=$tx;$z.CommandText=$sql;$tb=[Data.DataTable]::new();$da=[Data.SqlClient.SqlDataAdapter]::new($z);[void]$da.Fill($tb);return ,$tb}
try{
if((X "SELECT COUNT(*) FROM Groups WITH (UPDLOCK,HOLDLOCK) WHERE Name='HAPVIDA Local'") -ne 0){throw 'OU ja existe; preservada'}
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


[void](X "UPDATE Setup SET AuthType=0,DefaultDomain=NULL,DomainFieldStatus=NULL,ImageFile='populos-elux7-v30.idf',PersistentHomeApplications='ALL' WHERE SetupID=@s" @{'@s'=$s})
$ou=X 'SELECT MAX(GroupID)+1 FROM Groups WITH (UPDLOCK,HOLDLOCK)';$k=Cols 'Groups' @('GroupID','Name','DeviceCount','UseParent','SetupID')
[void](X "INSERT INTO Groups (GroupID,Name,DeviceCount,UseParent,SetupID,$k) SELECT @ou,@n,0,0,@s,$k FROM Groups WHERE GroupID=13" @{'@ou'=$ou;'@n'=$Nome;'@s'=$s})
$ka=Cols 'Application' @('ApplicationID','GroupID');$apps=Rows 'SELECT ApplicationID FROM Application WHERE GroupID=13 ORDER BY ApplicationID'
$patientApp=0;$adminApp=0
foreach($a in $apps.Rows){
 $id=X 'SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK,HOLDLOCK)'
 [void](X "INSERT INTO Application (ApplicationID,GroupID,$ka) SELECT @id,@ou,$ka FROM Application WHERE ApplicationID=@old" @{'@id'=$id;'@ou'=$ou;'@old'=$a.ApplicationID})
 foreach($t in 'Browser','Local','RDP','Storefront','VDA','AVD'){$k=Cols $t @('ApplicationID');[void](X "INSERT INTO [$t] (ApplicationID,$k) SELECT @id,$k FROM [$t] WHERE ApplicationID=@old" @{'@id'=$id;'@old'=$a.ApplicationID})}
 if($a.ApplicationID -eq 79){$patientApp=$id;[void](X "UPDATE Local SET Parameter='/usr/bin/hapvida-local-paciente' WHERE ApplicationID=@id" @{'@id'=$id})}
 if($a.ApplicationID -eq 80){$adminApp=$id;[void](X "UPDATE Local SET Parameter='/usr/bin/hapvida-local-admin' WHERE ApplicationID=@id" @{'@id'=$id})}
}
if(-not $patientApp -or -not $adminApp){throw 'Apps de saude nao encontrados na origem'}
$files=Rows "SELECT f.FileSource,f.FileDestination,f.Description,u.FileContent FROM FileEntry f JOIN UCFT u ON f.UCFTID=u.UCFTID WHERE f.MemberType=1 AND f.MemberID=13 AND f.FileDestination NOT LIKE '/setup/hapvida/%' AND f.FileDestination NOT LIKE '/setup/krb5.conf.d/%'"
foreach($r in $files.Rows){Arquivo $ou $r.FileSource $r.FileDestination $r.Description ([byte[]]$r.FileContent)}
$ki=Cols 'IniEntry' @('IniEntryID','MemberID');$ini=Rows 'SELECT IniEntryID FROM IniEntry WHERE MemberType=1 AND MemberID=13'
foreach($r in $ini.Rows){$id=X 'SELECT ISNULL(MAX(IniEntryID),0)+1 FROM IniEntry WITH (UPDLOCK,HOLDLOCK)';[void](X "INSERT INTO IniEntry (IniEntryID,MemberID,$ki) SELECT @id,@ou,$ki FROM IniEntry WHERE IniEntryID=@old" @{'@id'=$id;'@ou'=$ou;'@old'=$r.IniEntryID})}
$utf=[Text.UTF8Encoding]::new($false)
Arquivo $ou 'admin-auth.json' '/setup/hapvida-local/admin-auth.json' 'HAPVIDA Local: verificador PBKDF2 administrativo, sem senha em texto' ($utf.GetBytes($auth))
Arquivo $ou 'logo.png' '/setup/hapvida-local/logo.png' 'HAPVIDA Local: logo da identificacao' ([IO.File]::ReadAllBytes("$src\app\web\static\logo.png"))
Arquivo $ou 'cor-fundo' '/setup/hapvida-local/cor-fundo' 'HAPVIDA Local: cor da identificacao' ($utf.GetBytes("#FFF7EC`n"))
if((X 'SELECT AuthType FROM Setup WHERE SetupID=@s' @{'@s'=$s}) -ne 0){throw 'Autenticacao da nova OU divergente'}
[void](X 'UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID=@ou' @{'@ou'=$ou})
$tx.Commit();"COMMIT OK: HAPVIDA Local OU=$ou Setup=$s, sem AD, imagem v30, paciente=$patientApp cadastro=$adminApp, apps=$($apps.Rows.Count), arquivos base=$($files.Rows.Count). Nenhum dispositivo movido."
}catch{if($tx.Connection){$tx.Rollback()};throw}finally{$cn.Close()}