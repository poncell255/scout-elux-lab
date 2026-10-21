# Entrega /setup/krb5.conf.d/populos.conf aos eLux das OUs com AD: KDC fixo, sem depender de SRV no DNS do DHCP.
# O /etc/krb5.conf do eLux (pacote kerberos_config) tem "includedir /setup/krb5.conf.d/".
param([int[]]$OUs = @(0,1,2,3,4,5,6), [string]$Kdc = '10.20.0.10')
$conf = @"
[libdefaults]
    default_realm = POPULOS.LOCAL
    dns_lookup_kdc = false
    dns_lookup_realm = false
    rdns = false
    dns_canonicalize_hostname = false

[realms]
    POPULOS.LOCAL = {
        kdc = $Kdc
        admin_server = $Kdc
    }

[domain_realm]
    .populos.local = POPULOS.LOCAL
    populos.local = POPULOS.LOCAL
"@ -replace "`r`n", "`n"
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($conf + "`n")
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-krb5.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction(); $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ [void]$z.Parameters.AddWithValue($k,$p[$k]) }; $z.ExecuteScalar() }
try {
  foreach($ou in $OUs){
    # remove versão anterior deste arquivo na OU
    [void](X "DELETE u FROM UCFT u JOIN FileEntry f ON f.UCFTID=u.UCFTID WHERE f.MemberType=1 AND f.MemberID=@ou AND f.Description=N'Kerberos POPULOS'; DELETE FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND Description=N'Kerberos POPULOS'" @{'@ou'=$ou})
    $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText="INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,'populos.conf',0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)"; [void]$z.Parameters.AddWithValue('@ou',$ou); [void]$z.Parameters.AddWithValue('@tm',$now); $q=$z.Parameters.Add('@fc',[Data.SqlDbType]::VarBinary,-1); $q.Value=$bytes; $u=$z.ExecuteScalar()
    [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, 'populos.conf', '/setup/krb5.conf.d/populos.conf', N'Kerberos POPULOS', @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$ou;'@u'=$u})
    "  OU $ou -> UCFTID $u" }
  [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1")
  $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
