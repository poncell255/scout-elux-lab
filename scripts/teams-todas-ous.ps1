# Teams for Linux (pacote populos_teams) em todas as OUs, menos as listadas em -Exceto (padrão: 9 = TV Projetos).
# App local "Microsoft Teams" (/usr/bin/teams-for-linux, ícone teams) e imagem com o pacote nos setups dessas OUs.
param([int[]]$Exceto = @(9), [string]$Nome = 'Microsoft Teams',
      [hashtable]$Imagens = @{ 0='populos-elux7-v22.idf'; 3='populos-elux7-v22.idf'; 4='populos-elux7-v22.idf'; 6='populos-elux7-v24.idf'; 7='populos-elux7-v23.idf' })
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-teams.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ [void]$z.Parameters.AddWithValue($k,$p[$k]) }; $z.ExecuteScalar() }
try {
  $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText="SELECT GroupID, SetupID FROM Groups ORDER BY GroupID"; $r=$z.ExecuteReader(); $ous=@(); while($r.Read()){ $ous+=,@($r.GetInt32(0),$r.GetInt32(1)) }; $r.Close()
  foreach($o in $ous){
    $ou=$o[0]; if($ou -in $Exceto){ "  OU ${ou}: pulada"; continue }
    if(-not $Imagens.ContainsKey($o[1])){ "  OU ${ou}: setup $($o[1]) sem imagem com Teams, pulada"; continue }
    if((X "SELECT COUNT(*) FROM Application WHERE GroupID=@ou AND Name=@n" @{'@ou'=$ou;'@n'=$Nome}) -gt 0){ "  OU ${ou}: já tem"; continue }
    $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
    [void](X "INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1) VALUES (@id,5,@n,0,0,1,0,1,@ou,'teams',0,-1,1,'',@n,0)" @{'@id'=$id;'@n'=$Nome;'@ou'=$ou})
    [void](X "INSERT INTO Local (ApplicationID, Type, Parameter, Hidden) VALUES (@id,'CUSTOM','/usr/bin/teams-for-linux',0)" @{'@id'=$id})
    "  OU ${ou}: Teams -> $id" }
  foreach($s in $Imagens.Keys){ [void](X "UPDATE Setup SET ImageFile=@i WHERE SetupID=@s" @{'@i'=$Imagens[$s];'@s'=[int]$s}); "  setup ${s}: $($Imagens[$s])" }
  [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1")
  $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
