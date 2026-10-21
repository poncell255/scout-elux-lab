# Entradas de hosts no eLux para o DC (o DNS do DHCP do Wi-Fi não resolve populos.local).
# Scout: Host(HostID, IPAddress, Name) + HostList(HostListID, SetupID, HostID) -> /setup/hosts.
param([int[]]$Setups = @(0,1,2), [string]$Ip = '10.20.0.10', [string[]]$Nomes = @('POPAD01.populos.local','POPAD01','populos.local'))
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-hosts.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ [void]$z.Parameters.AddWithValue($k,$p[$k]) }; $z.ExecuteScalar() }
try {
  foreach($n in $Nomes){
    $h=X "SELECT HostID FROM Host WHERE Name=@n AND IPAddress=@ip" @{'@n'=$n;'@ip'=$Ip}
    if($null -eq $h -or $h -is [DBNull]){ $h=X "SELECT ISNULL(MAX(HostID),0)+1 FROM Host WITH (UPDLOCK, HOLDLOCK)"; [void](X "INSERT INTO Host (HostID, IPAddress, Name, ReservedInt1, ReservedInt2) VALUES (@h,@ip,@n,0,0)" @{'@h'=$h;'@ip'=$Ip;'@n'=$n}) }
    foreach($s in $Setups){ [void](X "IF NOT EXISTS (SELECT 1 FROM HostList WHERE SetupID=@s AND HostID=@h) INSERT INTO HostList (HostListID, SetupID, HostID, ReservedInt1, ReservedInt2) SELECT ISNULL(MAX(HostListID),0)+1, @s, @h, 0, 0 FROM HostList WITH (UPDLOCK, HOLDLOCK)" @{'@s'=$s;'@h'=$h}) }
    "  $Ip $n -> setups $($Setups -join ',')" }
  [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1")
  $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
