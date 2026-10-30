$ErrorActionPreference='Stop'
$cn=[Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True');$cn.Open()
$backup='C:\ScoutSetup\backup\ScoutEnterprise-pre-hapvida-camera-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'.bak'
$z=$cn.CreateCommand();$z.CommandTimeout=600;$z.CommandText='BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM';[void]$z.Parameters.AddWithValue('@p',$backup);[void]$z.ExecuteNonQuery();$z.CommandText='RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM';[void]$z.ExecuteNonQuery();"Backup verificado: $backup"
$tx=$cn.BeginTransaction()
try{
 $z=$cn.CreateCommand();$z.Transaction=$tx;$z.CommandText="SELECT l.Parameter FROM Local l JOIN Application a ON a.ApplicationID=l.ApplicationID WHERE a.ApplicationID=80 AND a.GroupID=13 AND a.Name='Cadastro de Pacientes'"
 $current=[string]$z.ExecuteScalar();if($current -notmatch '--user-data-dir=/home/elux/\.config/microsoft-edge/app-hapvida-(admin|camera)'){throw 'Perfil administrativo divergente; preservado'}
 $flag='--unsafely-treat-insecure-origin-as-secure=http://10.5.0.166'
 $current='/usr/bin/microsoft-edge --app=http://10.5.0.166/hapvida/admin --user-data-dir=/home/elux/.config/microsoft-edge/app-hapvida-camera --class=HapvidaCadastro --no-first-run '+$flag
 $z.CommandText='UPDATE Local SET Parameter=@p WHERE ApplicationID=80';[void]$z.Parameters.AddWithValue('@p',$current);[void]$z.ExecuteNonQuery();$z.Parameters.Clear()
 $z.CommandText='UPDATE Device SET ApplicationsChanged=1,SetupChanged=1 WHERE GroupID=13';[void]$z.ExecuteNonQuery()
 $tx.Commit();'Atalho de cadastro ajustado: camera apenas para a origem interna do laboratorio, no perfil separado. Sem politica global ou reinicio.'
}catch{if($tx.Connection){$tx.Rollback()};throw}finally{$cn.Close()}
