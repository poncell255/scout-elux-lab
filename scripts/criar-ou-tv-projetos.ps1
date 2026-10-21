# Cria a OU "TV Projetos": setup próprio sem AD (clone do setup do Modo Kiosk), 6 monitores estendidos (grade 3x2),
# tema da OU Populos, /setup/tv/start-tv.sh e o app local "TV Projetos" (inicia sozinho e reabre se fechar).
param([int]$SetupOrigem = 4, [string]$Script = 'C:\ScoutSetup\tv-projetos\start-tv.sh')
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-tv-projetos.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"

$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction(); $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ [void]$z.Parameters.AddWithValue($k,$p[$k]) }; $z.ExecuteScalar() }
function Cols($t,$excl){ $l=($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
function NovoArquivo($ou,$nome,$destino,$descricao,[byte[]]$bytes){
  $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText="INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)"
  [void]$z.Parameters.AddWithValue('@ou',$ou); [void]$z.Parameters.AddWithValue('@n',$nome); [void]$z.Parameters.AddWithValue('@tm',$now); $q=$z.Parameters.Add('@fc',[Data.SqlDbType]::VarBinary,-1); $q.Value=$bytes; $u=$z.ExecuteScalar()
  [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$ou;'@n'=$nome;'@d'=$destino;'@ds'=$descricao;'@u'=$u})
}
try {
  if((X "SELECT COUNT(*) FROM Groups WHERE Name='TV Projetos'") -gt 0){ throw "OU TV Projetos ja existe" }
  if((X "SELECT AuthType FROM Setup WHERE SetupID=@s" @{'@s'=$SetupOrigem}) -ne 0){ throw "setup $SetupOrigem nao esta sem AD" }

  # --- setup novo (clone do Modo Kiosk, sem AD) ---
  $s=X "SELECT MAX(SetupID)+1 FROM Setup WITH (UPDLOCK, HOLDLOCK)"
  $k=Cols 'Setup' @('SetupID'); [void](X "INSERT INTO Setup (SetupID,$k) SELECT @s,$k FROM Setup WHERE SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  foreach($t in @(@{t='ScreenSaver';pk='ScreenSaverID'},@{t='ComPort';pk='ComPortID'},@{t='NetworkProfile';pk='NetworkProfileID'},@{t='EluxVarList';pk='EluxVarListID'},@{t='HostList';pk='HostListID'},@{t='NetDrive';pk='NetDriveID'},@{t='Printer';pk='PrinterID'},@{t='ServerList';pk='ServerListID'})){
    $k=Cols $t.t @($t.pk,'SetupID')
    $n=X "INSERT INTO [$($t.t)] ([$($t.pk)],SetupID,$k) SELECT mx.v+ROW_NUMBER() OVER(ORDER BY o.[$($t.pk)]),@s,$k FROM [$($t.t)] o CROSS JOIN (SELECT ISNULL(MAX([$($t.pk)]),0) v FROM [$($t.t)] WITH (UPDLOCK, HOLDLOCK)) mx WHERE o.SetupID=@src; SELECT @@ROWCOUNT" @{'@s'=$s;'@src'=$SetupOrigem}
    "  $($t.t): $n" }
  $k=Cols 'PowerManagementProfile' @('SetupID'); [void](X "INSERT INTO PowerManagementProfile (SetupID,$k) SELECT @s,$k FROM PowerManagementProfile WHERE SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  $k=Cols 'Multimedia' @('MemberType','MemberID'); [void](X "INSERT INTO Multimedia (MemberType,MemberID,$k) SELECT 5,@s,$k FROM Multimedia WHERE MemberType=5 AND MemberID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  $k=Cols 'ScreenSettings' @('MemberType','MemberID','ScreenCount'); $ss=X "INSERT INTO ScreenSettings (MemberType,MemberID,ScreenCount,$k) SELECT 5,@s,6,$k FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src; SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@s'=$s;'@src'=$SetupOrigem}
  $old=X "SELECT ScreenSettingsID FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src" @{'@src'=$SetupOrigem}
  # 6 monitores estendidos, grade 3 colunas x 2 linhas. LayoutNext = monitor de referência, LayoutPos 1 = abaixo, 2 = à direita.
  #   1 3 5
  #   2 4 6
  $grade=@(@(1,0,0),@(2,1,1),@(3,2,1),@(4,1,3),@(5,2,3),@(6,1,5))
  $k=Cols 'Screen' @('ScreenSettingsID','MonitorNumber','Name','LayoutPos','LayoutNext','Options')
  foreach($g in $grade){
    [void](X "INSERT INTO Screen (ScreenSettingsID,MonitorNumber,Name,LayoutPos,LayoutNext,Options,$k) SELECT @n,@mn,@nm,@lp,@ln,CASE WHEN @mn=1 THEN Options ELSE Options & ~1 END,$k FROM Screen WHERE ScreenSettingsID=@o AND MonitorNumber=1" @{'@n'=$ss;'@o'=$old;'@mn'=$g[0];'@nm'="Monitor_$($g[0])";'@lp'=$g[1];'@ln'=$g[2]}) }
  "  setup $s criado (clone do $SetupOrigem, sem AD, 6 monitores)"

  # --- OU ---
  $ou=X "SELECT MAX(GroupID)+1 FROM Groups WITH (UPDLOCK, HOLDLOCK)"; $k=Cols 'Groups' @('GroupID','Name','DeviceCount','UseParent','SetupID','UseParentApps')
  [void](X "INSERT INTO Groups (GroupID,Name,DeviceCount,UseParent,SetupID,UseParentApps,$k) SELECT @ou,'TV Projetos',0,0,@s,0,$k FROM Groups WHERE GroupID=4" @{'@ou'=$ou;'@s'=$s}); "  OU TV Projetos: GroupID $ou"

  # --- tema da Populos ---
  $f=$cn.CreateCommand(); $f.Transaction=$tx; $f.CommandText="SELECT f.FileSource, f.FileDestination, u.FileContent FROM FileEntry f JOIN UCFT u ON u.UCFTID=f.UCFTID WHERE f.MemberType=1 AND f.MemberID=4"; $da=[System.Data.SqlClient.SqlDataAdapter]::new($f); $tb=[System.Data.DataTable]::new(); [void]$da.Fill($tb)
  foreach($r in $tb.Rows){ NovoArquivo $ou $r.FileSource $r.FileDestination 'Tema TV Projetos' ([byte[]]$r.FileContent) }
  [void](X "INSERT INTO IniEntry (IniEntryID, MemberType, MemberID, IniFile, IniSection, IniKey, IniValue) SELECT (SELECT ISNULL(MAX(IniEntryID),0) FROM IniEntry)+ROW_NUMBER() OVER(ORDER BY IniEntryID), 1, @ou, IniFile, IniSection, IniKey, IniValue FROM IniEntry WHERE MemberType=1 AND MemberID=4" @{'@ou'=$ou})
  "  tema copiado ($($tb.Rows.Count) arquivos)"

  # --- script das 6 telas (LF, sem BOM) ---
  $txt=[IO.File]::ReadAllText($Script) -replace "`r`n","`n"
  NovoArquivo $ou 'start-tv.sh' '/setup/tv/start-tv.sh' 'TV Projetos - 6 telas' ([Text.UTF8Encoding]::new($false).GetBytes($txt))

  # --- app local: inicia sozinho e reabre se fechar ---
  $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
  [void](X "INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1) VALUES (@id,5,'TV Projetos',1,1,1,0,1,@ou,'',0,-1,1,'','TV Projetos',0)" @{'@id'=$id;'@ou'=$ou})
  [void](X "INSERT INTO Local (ApplicationID, Type, Parameter, Hidden) VALUES (@id,'CUSTOM','/bin/bash /setup/tv/start-tv.sh',0)" @{'@id'=$id})
  "  app TV Projetos -> ApplicationID $id"

  $tx.Commit(); "COMMIT OK: OU $ou / setup $s"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
