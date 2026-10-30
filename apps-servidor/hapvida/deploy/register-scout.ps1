$ErrorActionPreference='Stop'
$src='C:\Users\Administrator\Downloads\hapvida-saude'
$file='C:\ScoutSetup\diag\idf-populos-v29.json'
$idf=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
if($idf.imageSize -gt 3700MB -or -not($idf.epms | Where-Object name -eq 'populos_hapvida')){throw 'Imagem HAPVIDA nao validada'}
$keyLine=[IO.File]::ReadAllLines('C:\ScoutSetup\credenciais.txt') | Where-Object {$_.StartsWith('HAPVIDA chave dos eLux / ')} | Select-Object -First 1
if(-not $keyLine){throw 'Chave HAPVIDA ausente'}
$key=($keyLine -split ' / ',2)[1].Trim()
$cn=[Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True');$cn.Open()
$backup='C:\ScoutSetup\backup\ScoutEnterprise-pre-hapvida-prontuario-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'.bak'
$z=$cn.CreateCommand();$z.CommandTimeout=600;$z.CommandText='BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM';[void]$z.Parameters.AddWithValue('@p',$backup);[void]$z.ExecuteNonQuery();$z.CommandText='RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM';[void]$z.ExecuteNonQuery();"Backup verificado: $backup"
$tx=$cn.BeginTransaction();$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$params=@{}){$z=$cn.CreateCommand();$z.Transaction=$tx;$z.CommandTimeout=120;$z.CommandText=$sql;foreach($k in $params.Keys){if($params[$k] -is [byte[]]){$q=$z.Parameters.Add($k,[Data.SqlDbType]::VarBinary,-1);$q.Value=$params[$k]}else{[void]$z.Parameters.AddWithValue($k,$params[$k])}};$z.ExecuteScalar()}
function FileEntry($name,$dest,[byte[]]$content){
 $u=X 'INSERT INTO UCFT (MemberType,MemberID,FileType,FileName,FileMode,FTResult,TimeModified,FileContent) VALUES (1,13,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)' @{'@n'=$name;'@tm'=$now;'@fc'=$content}
 [void](X "INSERT INTO FileEntry (FileEntryID,MemberType,MemberID,FileSource,FileDestination,Description,UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1,1,13,@n,@d,'HAPVIDA: exames e prontuario demonstrativos',@u FROM FileEntry WITH (UPDLOCK,HOLDLOCK)" @{'@n'=$name;'@d'=$dest;'@u'=$u})
}
try{
 if((X "SELECT COUNT(*) FROM Groups WHERE GroupID=13 AND Name='HAPVIDA' AND SetupID=9") -ne 1){throw 'OU HAPVIDA diverge do esperado'}
 if((X "SELECT COUNT(*) FROM Application WHERE GroupID=13 AND Name='Exames e Prontuario'") -gt 0){throw 'Aplicativo ja existe; preservado'}
 if((X "SELECT COUNT(*) FROM FileEntry WHERE MemberType=1 AND MemberID=13 AND FileDestination LIKE '/setup/hapvida/%'") -gt 0){throw 'Arquivos HAPVIDA ja existem; preservados'}
 $id=X 'SELECT ISNULL(MAX(ApplicationID),0)+1 FROM Application WITH (UPDLOCK,HOLDLOCK)'
 [void](X "INSERT INTO Application (ApplicationID,AppTypeID,Name,AutoStart,TM,AppOnDesktop,Roaming,AppLevel,GroupID,IconName,PassThrough,Xinerama,SortID,LooseParameters,DisplayName,ReservedInt1) VALUES (@id,5,'Exames e Prontuario',0,0,1,0,1,13,'hapvida',0,-1,1,'','Exames e Prontuario',0)" @{'@id'=$id})
 [void](X "INSERT INTO Local (ApplicationID,Type,Parameter,Hidden) VALUES (@id,'CUSTOM','/usr/bin/hapvida-prontuario',0)" @{'@id'=$id})
 $logo=[IO.File]::ReadAllBytes("$src\app\web\static\logo.png")
 if((X "SELECT COUNT(*) FROM UCFT WHERE MemberType=-1 AND MemberID=-1 AND FileType=1 AND FileName='hapvida.png'") -eq 0){[void](X "INSERT INTO UCFT (MemberType,MemberID,FileType,FileName,FileMode,FTResult,TimeModified,FileContent) VALUES (-1,-1,1,'hapvida.png',-1,0,@tm,@fc)" @{'@tm'=$now;'@fc'=$logo})}
 $utf=[Text.UTF8Encoding]::new($false)
 FileEntry 'logo.png' '/setup/hapvida/logo.png' $logo
 FileEntry 'cor-fundo' '/setup/hapvida/cor-fundo' ($utf.GetBytes("#FFF7EC`n"))
 FileEntry 'servidor' '/setup/hapvida/servidor' ($utf.GetBytes("http://10.5.0.166/hapvida`n"))
 FileEntry 'chave' '/setup/hapvida/chave' ($utf.GetBytes("$key`n"))
 [void](X "UPDATE Setup SET ImageFile='populos-elux7-v29.idf' WHERE SetupID=9 AND AuthType=3")
 [void](X 'UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID=13')
 $tx.Commit();"COMMIT OK: aplicativo $id na OU HAPVIDA, imagem v29, AutoStart=0, TM=0. Nenhum comando de reboot/update enviado."
}catch{if($tx.Connection){$tx.Rollback()};throw}finally{$cn.Close()}
