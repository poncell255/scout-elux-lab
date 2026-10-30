$ErrorActionPreference='Stop'
$cn=[Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True');$cn.Open()
$backup='C:\ScoutSetup\backup\ScoutEnterprise-pre-hapvida-admin-ad-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'.bak'
$z=$cn.CreateCommand();$z.CommandTimeout=600;$z.CommandText='BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM';[void]$z.Parameters.AddWithValue('@p',$backup);[void]$z.ExecuteNonQuery();$z.CommandText='RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM';[void]$z.ExecuteNonQuery();"Backup verificado: $backup"
$tx=$cn.BeginTransaction();$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$params=@{}){$z=$cn.CreateCommand();$z.Transaction=$tx;$z.CommandText=$sql;foreach($k in $params.Keys){if($params[$k] -is [byte[]]){$p=$z.Parameters.Add($k,[Data.SqlDbType]::VarBinary,-1);$p.Value=$params[$k]}else{[void]$z.Parameters.AddWithValue($k,$params[$k])}};$z.ExecuteScalar()}
try{
 if((X "SELECT COUNT(*) FROM Groups WHERE GroupID=13 AND Name='HAPVIDA' AND SetupID=9") -ne 1){throw 'OU divergente'}
 if((X "SELECT COUNT(*) FROM Application WHERE GroupID=13 AND ApplicationID=79") -ne 1){throw 'App paciente nao localizado'}
 [void](X "UPDATE Application SET Name=N'Exames e Prontuário',DisplayName=N'Exames e Prontuário',AutoStart=0,TM=0 WHERE ApplicationID=79 AND GroupID=13")
 $admin=X "SELECT ApplicationID FROM Application WHERE GroupID=13 AND Name='Cadastro de Pacientes'"
 if(-not $admin){
  $admin=X 'SELECT ISNULL(MAX(ApplicationID),0)+1 FROM Application WITH (UPDLOCK,HOLDLOCK)'
  [void](X "INSERT INTO Application (ApplicationID,AppTypeID,Name,AutoStart,TM,AppOnDesktop,Roaming,AppLevel,GroupID,IconName,PassThrough,Xinerama,SortID,LooseParameters,DisplayName,ReservedInt1) VALUES (@id,5,'Cadastro de Pacientes',0,0,1,0,1,13,'hapvida',0,-1,1,'','Cadastro de Pacientes',0)" @{'@id'=$admin})
  [void](X "INSERT INTO Local (ApplicationID,Type,Parameter,Hidden) VALUES (@id,'CUSTOM','/usr/bin/microsoft-edge --app=http://10.5.0.166/hapvida/admin --no-first-run --no-default-browser-check --password-store=basic --user-data-dir=/home/elux/.config/microsoft-edge/app-hapvida-admin --class=HapvidaCadastro',0)" @{'@id'=$admin})
 }
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes("HAPVIDA: login somente AD. Biometria exclusiva do aplicativo de prontuario.`n")
 $u=X "SELECT UCFTID FROM FileEntry WHERE MemberType=1 AND MemberID=13 AND FileDestination='/setup/populos-digital/DESATIVADO'"
 if($u){[void](X 'UPDATE UCFT SET FileContent=@fc,TimeModified=@tm WHERE UCFTID=@u' @{'@fc'=$bytes;'@tm'=$now;'@u'=$u})}
 else{
  $u=X "INSERT INTO UCFT (MemberType,MemberID,FileType,FileName,FileMode,FTResult,TimeModified,FileContent) VALUES (1,13,0,'DESATIVADO',0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@fc'=$bytes;'@tm'=$now}
  [void](X "INSERT INTO FileEntry (FileEntryID,MemberType,MemberID,FileSource,FileDestination,Description,UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1,1,13,'DESATIVADO','/setup/populos-digital/DESATIVADO','HAPVIDA: desativa digital no login AD',@u FROM FileEntry WITH (UPDLOCK,HOLDLOCK)" @{'@u'=$u})
 }
 [void](X 'UPDATE Setup SET AuthType=3 WHERE SetupID=9')
 [void](X 'UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID=13')
 $tx.Commit();"COMMIT OK: paciente app 79, cadastro app $admin; AD sem portao de digital. Flag DESATIVADO entregue somente a OU 13."
}catch{if($tx.Connection){$tx.Rollback()};throw}finally{$cn.Close()}
