# Cria a OU "Provas" (sala de provas): clone do setup da Porto, SEM AD e sem home persistente, barra de tarefas escondida.
# Um único app, "Prova", abre sozinho e roda /setup/provas/prova.sh: digital (populos_digital >= 1.2.0, modo prova)
# -> prova do aluno no Edge em quiosque (site de provas no servidor) -> volta para a digital.
# Arquivos: /setup/provas/{prova.sh,chave,servidor} + os da Porto (GLPI, uberAgent), sem tema, sem MODO_LOCAL e sem a marca da Porto.
param([int]$SetupOrigem = 7, [int]$OuOrigem = 11, [string]$Nome = 'Provas', [string]$Imagem = 'populos-elux7-v27.idf',
      [string]$Servidor = 'http://10.5.0.166/provas', [string]$Script = 'C:\ScoutSetup\provas\elux\prova.sh')
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$chave=(($c | Where-Object {$_ -match '^Provas chave'}) -split ' / ',2)[1].Trim()
$m=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x=$m.CreateCommand(); $x.CommandTimeout=600
$x.CommandText="BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-provas.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction(); $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandTimeout=600; $z.CommandText=$sql; foreach($k in $p.Keys){ $v=$p[$k]; if($v -is [byte[]]){ $q=$z.Parameters.Add($k,[Data.SqlDbType]::VarBinary,-1); $q.Value=$v } else { [void]$z.Parameters.AddWithValue($k,$v) } }; $z.ExecuteScalar() }
function Cols($t,$excl){ $l=($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
function Arquivo($ou,$nome,$destino,$desc,[byte[]]$bytes){
  $u=X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou'=$ou;'@n'=$nome;'@tm'=$now;'@fc'=$bytes}
  [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$ou;'@n'=$nome;'@d'=$destino;'@ds'=$desc;'@u'=$u}) }
try {
  if((X "SELECT COUNT(*) FROM Groups WHERE Name=@n" @{'@n'=$Nome}) -gt 0){ throw "OU $Nome ja existe" }
  # --- setup novo (clone da Porto) ---
  $s=X "SELECT MAX(SetupID)+1 FROM Setup WITH (UPDLOCK, HOLDLOCK)"
  $k=Cols 'Setup' @('SetupID'); [void](X "INSERT INTO Setup (SetupID,$k) SELECT @s,$k FROM Setup WHERE SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  foreach($t in @(@{t='ScreenSaver';pk='ScreenSaverID'},@{t='ComPort';pk='ComPortID'},@{t='NetworkProfile';pk='NetworkProfileID'},@{t='EluxVarList';pk='EluxVarListID'},@{t='HostList';pk='HostListID'},@{t='NetDrive';pk='NetDriveID'},@{t='Printer';pk='PrinterID'},@{t='ServerList';pk='ServerListID'})){
    $k=Cols $t.t @($t.pk,'SetupID')
    [void](X "INSERT INTO [$($t.t)] ([$($t.pk)],SetupID,$k) SELECT mx.v+ROW_NUMBER() OVER(ORDER BY o.[$($t.pk)]),@s,$k FROM [$($t.t)] o CROSS JOIN (SELECT ISNULL(MAX([$($t.pk)]),0) v FROM [$($t.t)] WITH (UPDLOCK, HOLDLOCK)) mx WHERE o.SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem}) }
  $k=Cols 'PowerManagementProfile' @('SetupID'); [void](X "INSERT INTO PowerManagementProfile (SetupID,$k) SELECT @s,$k FROM PowerManagementProfile WHERE SetupID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  $k=Cols 'Multimedia' @('MemberType','MemberID'); [void](X "INSERT INTO Multimedia (MemberType,MemberID,$k) SELECT 5,@s,$k FROM Multimedia WHERE MemberType=5 AND MemberID=@src" @{'@s'=$s;'@src'=$SetupOrigem})
  $k=Cols 'ScreenSettings' @('MemberType','MemberID'); $ss=X "INSERT INTO ScreenSettings (MemberType,MemberID,$k) SELECT 5,@s,$k FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src; SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@s'=$s;'@src'=$SetupOrigem}
  $old=X "SELECT ScreenSettingsID FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src" @{'@src'=$SetupOrigem}
  $k=Cols 'Screen' @('ScreenSettingsID'); [void](X "INSERT INTO Screen (ScreenSettingsID,$k) SELECT @n,$k FROM Screen WHERE ScreenSettingsID=@o" @{'@n'=$ss;'@o'=$old})
  [void](X "UPDATE Setup SET AuthType=0, DefaultDomain=NULL, DomainFieldStatus=NULL, PersistentHomeApplications=NULL, ShowTaskbar=0, TaskbarAutoHide=1, ImageFile=@img WHERE SetupID=@s" @{'@s'=$s;'@img'=$Imagem})
  "  setup $s (clone do $SetupOrigem, sem AD, sem home persistente, sem barra de tarefas, $Imagem)"

  # --- OU, sem herdar os modelos de app globais ---
  $ou=X "SELECT MAX(GroupID)+1 FROM Groups WITH (UPDLOCK, HOLDLOCK)"; $k=Cols 'Groups' @('GroupID','Name','DeviceCount','UseParent','SetupID')
  [void](X "INSERT INTO Groups (GroupID,Name,DeviceCount,UseParent,SetupID,$k) SELECT @ou,@n,0,0,@s,$k FROM Groups WHERE GroupID=@src" @{'@ou'=$ou;'@n'=$Nome;'@s'=$s;'@src'=$OuOrigem})
  [void](X "UPDATE Groups SET UseParentApps=0 WHERE GroupID=@ou" @{'@ou'=$ou}); "  OU ${Nome}: GroupID $ou"

  # --- app único: a sala de provas (abre sozinho e reabre se fechar) ---
  $id=X "SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK, HOLDLOCK)"
  [void](X "INSERT INTO Application (ApplicationID, AppTypeID, Name, AutoStart, TM, AppOnDesktop, Roaming, AppLevel, GroupID, IconName, PassThrough, Xinerama, SortID, LooseParameters, DisplayName, ReservedInt1) VALUES (@id,5,'Prova',1,1,1,0,1,@ou,'',0,-1,1,'','Prova',0)" @{'@id'=$id;'@ou'=$ou})
  [void](X "INSERT INTO Local (ApplicationID, Type, Parameter, Hidden) VALUES (@id,'CUSTOM','/bin/bash /setup/provas/prova.sh',0)" @{'@id'=$id}); "  app Prova -> $id"

  # --- arquivos: os da Porto que valem para todos (GLPI, uberAgent) + os da sala de provas ---
  $f=$cn.CreateCommand(); $f.Transaction=$tx; $f.CommandText="SELECT f.FileSource, f.FileDestination, f.Description, u.FileContent FROM FileEntry f JOIN UCFT u ON u.UCFTID=f.UCFTID WHERE f.MemberType=1 AND f.MemberID=$OuOrigem AND f.FileDestination NOT LIKE '/setup/elux/themes/%' AND f.FileDestination NOT LIKE '/setup/populos-digital/%' AND f.FileDestination NOT LIKE '/setup/ica/%' AND f.FileDestination NOT LIKE '/setup/populos/%'"
  $da=[System.Data.SqlClient.SqlDataAdapter]::new($f); $tb=[System.Data.DataTable]::new(); [void]$da.Fill($tb)
  foreach($r in $tb.Rows){ Arquivo $ou $r.FileSource $r.FileDestination $r.Description ([byte[]]$r.FileContent) }
  "  arquivos copiados da Porto: $($tb.Rows.Count)"
  $utf8=[Text.UTF8Encoding]::new($false)
  $sh = ([IO.File]::ReadAllText($Script)) -replace "`r`n", "`n"
  Arquivo $ou 'prova.sh' '/setup/provas/prova.sh' 'Provas: ciclo digital -> prova em quiosque' ($utf8.GetBytes($sh))
  Arquivo $ou 'chave' '/setup/provas/chave' 'Provas: chave do site (X-Provas-Chave)' ($utf8.GetBytes("$chave`n"))
  Arquivo $ou 'servidor' '/setup/provas/servidor' 'Provas: endereço do site' ($utf8.GetBytes("$Servidor`n"))
  "  arquivos da sala de provas: prova.sh, chave, servidor"
  $tx.Commit(); "COMMIT OK: OU $ou / setup $s"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()


