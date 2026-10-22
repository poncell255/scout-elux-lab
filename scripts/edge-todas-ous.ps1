# Adiciona o navegador Microsoft Edge (app tipo Navegador do Scout) em todas as OUs.
# AppTypeID 3 = navegador; Browser.BrowserType 7 = Edge; ProxyType 0 = direto
# (o /usr/bin/microsoft-edge do eLux lê ProxyType do sessions.ini; vazio vira "fixed_servers" sem servidor).
param([string]$PaginaInicial = 'https://www.google.com', [string]$Nome = 'Microsoft Edge')
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-edge.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ [void]$z.Parameters.AddWithValue($k,$p[$k]) }; $z.ExecuteScalar() }
try {
  $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText="SELECT GroupID FROM Groups ORDER BY GroupID"; $r=$z.ExecuteReader(); $ous=@(); while($r.Read()){ $ous+=$r.GetInt32(0) }; $r.Close()
  foreach($ou in $ous){
    if((X "SELECT COUNT(*) FROM Application a JOIN Browser b ON b.ApplicationID=a.ApplicationID WHERE a.GroupID=@ou AND b.BrowserType=7" @{'@ou'=$ou}) -gt 0){ "  OU ${ou}: já tem Edge"; continue }
    $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
    [void](X "INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1) VALUES (@id,3,@n,0,0,1,0,1,@ou,'',0,-1,1,'',@n,0)" @{'@id'=$id;'@n'=$Nome;'@ou'=$ou})
    [void](X "INSERT INTO Browser (ApplicationID, StartPage, CallPage, Proxy, ProxyType, BrowserType, KioskMode, ProxyExceptions) VALUES (@id,@p,@p,'',0,7,0,'')" @{'@id'=$id;'@p'=$PaginaInicial})
    "  OU ${ou}: Edge -> ApplicationID $id" }
  [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1")
  $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
