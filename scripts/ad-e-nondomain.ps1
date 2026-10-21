# Liga autenticação AD (populos.local) nos setups 0/1/2 e cria a OU "Populos NonDomain"
# com setup próprio (clone do setup 0, sem AD), mesmos apps e tema da OU Populos (GroupID 4).
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | ? {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-ad.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"

$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction(); $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ [void]$z.Parameters.AddWithValue($k,$p[$k]) }; $z.ExecuteScalar() }
# colunas da tabela, sem as excluídas e sem identity
function Cols($t,$excl){ $l=($excl | % { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }

$dominio='populos.local'; $servidores='POPAD01.populos.local'; $base='DC=populos,DC=local'
try {
  if((X "SELECT COUNT(*) FROM Groups WHERE Name='Populos NonDomain'") -gt 0){ throw "OU Populos NonDomain ja existe" }
  # --- setup novo (clone do 0) ---
  $s=X "SELECT MAX(SetupID)+1 FROM Setup WITH (UPDLOCK, HOLDLOCK)"
  $k=Cols 'Setup' @('SetupID'); [void](X "INSERT INTO Setup (SetupID,$k) SELECT @s,$k FROM Setup WHERE SetupID=0" @{'@s'=$s})
  foreach($t in @(@{t='ScreenSaver';pk='ScreenSaverID'},@{t='ComPort';pk='ComPortID'},@{t='NetworkProfile';pk='NetworkProfileID'},@{t='EluxVarList';pk='EluxVarListID'},@{t='HostList';pk='HostListID'},@{t='NetDrive';pk='NetDriveID'},@{t='Printer';pk='PrinterID'})){
    $k=Cols $t.t @($t.pk,'SetupID')
    $n=X "INSERT INTO [$($t.t)] ([$($t.pk)],SetupID,$k) SELECT mx.v+ROW_NUMBER() OVER(ORDER BY o.[$($t.pk)]),@s,$k FROM [$($t.t)] o CROSS JOIN (SELECT ISNULL(MAX([$($t.pk)]),0) v FROM [$($t.t)] WITH (UPDLOCK, HOLDLOCK)) mx WHERE o.SetupID=0; SELECT @@ROWCOUNT" @{'@s'=$s}
    "  $($t.t): $n" }
  $k=Cols 'PowerManagementProfile' @('SetupID'); [void](X "INSERT INTO PowerManagementProfile (SetupID,$k) SELECT @s,$k FROM PowerManagementProfile WHERE SetupID=0" @{'@s'=$s})
  $k=Cols 'Multimedia' @('MemberType','MemberID'); [void](X "INSERT INTO Multimedia (MemberType,MemberID,$k) SELECT 5,@s,$k FROM Multimedia WHERE MemberType=5 AND MemberID=0" @{'@s'=$s})
  $k=Cols 'ScreenSettings' @('MemberType','MemberID'); $ss=X "INSERT INTO ScreenSettings (MemberType,MemberID,$k) SELECT 5,@s,$k FROM ScreenSettings WHERE MemberType=5 AND MemberID=0; SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@s'=$s}
  $old=X "SELECT ScreenSettingsID FROM ScreenSettings WHERE MemberType=5 AND MemberID=0"
  $k=Cols 'Screen' @('ScreenSettingsID'); [void](X "INSERT INTO Screen (ScreenSettingsID,$k) SELECT @n,$k FROM Screen WHERE ScreenSettingsID=@o" @{'@n'=$ss;'@o'=$old})
  "  setup $s criado (clone do 0)"

  # --- OU ---
  $ou=X "SELECT MAX(GroupID)+1 FROM Groups WITH (UPDLOCK, HOLDLOCK)"; $k=Cols 'Groups' @('GroupID','Name','DeviceCount','UseParent','SetupID')
  [void](X "INSERT INTO Groups (GroupID,Name,DeviceCount,UseParent,SetupID,$k) SELECT @ou,'Populos NonDomain',0,0,@s,$k FROM Groups WHERE GroupID=4" @{'@ou'=$ou;'@s'=$s}); "  OU Populos NonDomain: GroupID $ou"

  # --- apps da Populos ---
  $apps=$cn.CreateCommand(); $apps.Transaction=$tx; $apps.CommandText="SELECT ApplicationID FROM Application WHERE GroupID=4 ORDER BY ApplicationID"; $ids=@(); $rd=$apps.ExecuteReader(); while($rd.Read()){ $ids+=$rd.GetInt32(0) }; $rd.Close()
  $ka=Cols 'Application' @('ApplicationID','GroupID')
  foreach($a in $ids){ $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
    [void](X "INSERT INTO Application (ApplicationID,GroupID,$ka) SELECT @id,@ou,$ka FROM Application WHERE ApplicationID=@a" @{'@id'=$id;'@ou'=$ou;'@a'=$a})
    foreach($t in 'Browser','Local','RDP','Storefront','VDA','AVD'){ $k=Cols $t @('ApplicationID'); [void](X "INSERT INTO [$t] (ApplicationID,$k) SELECT @id,$k FROM [$t] WHERE ApplicationID=@a" @{'@id'=$id;'@a'=$a}) }
    "  app $a -> $id" }

  # --- tema da Populos ---
  $f=$cn.CreateCommand(); $f.Transaction=$tx; $f.CommandText="SELECT f.FileSource, f.FileDestination, u.FileContent FROM FileEntry f JOIN UCFT u ON u.UCFTID=f.UCFTID WHERE f.MemberType=1 AND f.MemberID=4"; $da=[System.Data.SqlClient.SqlDataAdapter]::new($f); $tb=[System.Data.DataTable]::new(); [void]$da.Fill($tb)
  foreach($r in $tb.Rows){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText="INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)"; [void]$z.Parameters.AddWithValue('@ou',$ou); [void]$z.Parameters.AddWithValue('@n',$r.FileSource); [void]$z.Parameters.AddWithValue('@tm',$now); $q=$z.Parameters.Add('@fc',[Data.SqlDbType]::VarBinary,-1); $q.Value=[byte[]]$r.FileContent; $u=$z.ExecuteScalar()
    [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, N'Tema Populos NonDomain', @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$ou;'@n'=$r.FileSource;'@d'=$r.FileDestination;'@u'=$u}) }
  [void](X "INSERT INTO IniEntry (IniEntryID, MemberType, MemberID, IniFile, IniSection, IniKey, IniValue) SELECT (SELECT ISNULL(MAX(IniEntryID),0) FROM IniEntry)+ROW_NUMBER() OVER(ORDER BY IniEntryID), 1, @ou, IniFile, IniSection, IniKey, IniValue FROM IniEntry WHERE MemberType=1 AND MemberID=4" @{'@ou'=$ou})
  "  tema copiado ($($tb.Rows.Count) arquivos)"

  # --- AD nos setups 0, 1, 2 ---
  foreach($sid in 0,1,2){
    [void](X "UPDATE Setup SET AuthType=3, DefaultDomain=@d, DomainFieldStatus=0 WHERE SetupID=@s" @{'@s'=$sid;'@d'=$dominio})
    [void](X "INSERT INTO AuthDomain (Name, ServerList, SearchBase, SetupID) VALUES (@n,@l,@b,@s)" @{'@n'=$dominio;'@l'=$servidores;'@b'=$base;'@s'=$sid}) }
  "  AD (AuthType 3, $dominio) nos setups 0,1,2"

  [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1")
  $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
