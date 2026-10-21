# Servidores de horário (NTP) para os eLux em todos os setups. Kerberos/AD exige relógio com < 5 min de diferença.
# Scout: Server.ServerTypeID=4 (SERVERTYPE_TIME) + ServerList(SetupID, ServerID, Instance=0).
param([string[]]$Ntp = @('a.ntp.br','b.ntp.br'))
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-ntp.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ [void]$z.Parameters.AddWithValue($k,$p[$k]) }; $z.ExecuteScalar() }
try {
  $setups=@(); $r=$cn.CreateCommand(); $r.Transaction=$tx; $r.CommandText="SELECT SetupID FROM Setup ORDER BY SetupID"; $rd=$r.ExecuteReader(); while($rd.Read()){ $setups+=$rd.GetInt32(0) }; $rd.Close()
  foreach($n in $Ntp){
    $sid=X "SELECT ServerID FROM Server WHERE ServerTypeID=4 AND IPName=@n" @{'@n'=$n}
    if($null -eq $sid -or $sid -is [DBNull]){ $sid=X "SELECT MAX(ServerID)+1 FROM Server WITH (UPDLOCK, HOLDLOCK)"
      [void](X "INSERT INTO Server (ServerID, Description, IPAddress, IPName, ServerTypeID, ReservedInt1, ReservedInt2) VALUES (@id,'NTP',@n,@n,4,0,0)" @{'@id'=$sid;'@n'=$n}) }
    foreach($s in $setups){
      [void](X "IF NOT EXISTS (SELECT 1 FROM ServerList WHERE SetupID=@s AND ServerID=@id AND ISNULL(Instance,0)=0) INSERT INTO ServerList (ServerListID, Instance, SetupID, ServerID) SELECT ISNULL(MAX(ServerListID),0)+1, 0, @s, @id FROM ServerList WITH (UPDLOCK, HOLDLOCK)" @{'@s'=$s;'@id'=$sid}) }
    "  $n (ServerID $sid) -> setups $($setups -join ',')" }
  [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1")
  $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
