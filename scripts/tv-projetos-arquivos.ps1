# (Re)entrega os arquivos da OU TV Projetos: start-tv.sh e a configuração do Xorg (Base Mosaic).
# Troca o conteúdo e o TimeModified (UTC) para o eLux baixar de novo.
param([int]$OU = 9)
$arquivos = @(
  @{ Fonte = 'C:\ScoutSetup\tv-projetos\start-tv.sh';      Nome = 'start-tv.sh';      Destino = '/setup/tv/start-tv.sh';                   Desc = 'TV Projetos - 6 telas' },
  @{ Fonte = 'C:\ScoutSetup\tv-projetos\20-tv-mosaic.conf'; Nome = '20-tv-mosaic.conf'; Destino = '/setup/X11/xorg.conf.d/20-tv-mosaic.conf'; Desc = 'TV Projetos - Xorg Base Mosaic' }
)
$c=Get-Content C:\ScoutSetup\credenciais.txt; $sa=(($c | Where-Object {$_ -match '^SQL sa'}) -split ' / ',2)[1].Trim()
$cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx=$cn.BeginTransaction(); $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql,$p=@{}){ $z=$cn.CreateCommand(); $z.Transaction=$tx; $z.CommandText=$sql; foreach($k in $p.Keys){ $v=$p[$k]; if($v -is [byte[]]){ $q=$z.Parameters.Add($k,[Data.SqlDbType]::VarBinary,-1); $q.Value=$v } else { [void]$z.Parameters.AddWithValue($k,$v) } }; $z.ExecuteScalar() }
try {
  foreach($a in $arquivos){
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes(([IO.File]::ReadAllText($a.Fonte) -replace "`r`n","`n"))
    $u=X "SELECT UCFTID FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination=@d" @{'@ou'=$OU;'@d'=$a.Destino}
    if($null -ne $u -and $u -isnot [DBNull]){
      [void](X "UPDATE UCFT SET FileContent=@fc, TimeModified=@tm WHERE UCFTID=@u" @{'@fc'=$bytes;'@tm'=$now;'@u'=$u}); "  atualizado: $($a.Destino) (UCFTID $u)"
    } else {
      $u=X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou'=$OU;'@n'=$a.Nome;'@tm'=$now;'@fc'=$bytes}
      [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou'=$OU;'@n'=$a.Nome;'@d'=$a.Destino;'@ds'=$a.Desc;'@u'=$u}); "  novo: $($a.Destino) (UCFTID $u)"
    }
  }
  [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=@ou" @{'@ou'=$OU})
  $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
