param([string]$Pasta = 'C:\ScoutSetup\icons')
# Ícones Word, Excel e PowerPoint (estilo Office: folha clara à direita, quadrado com a letra à esquerda), 128 px e 32 px.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
function Arred($x, $y, $w, $h, $r) { $p = New-Object Drawing.Drawing2D.GraphicsPath; $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90); $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90); $p.CloseFigure(); $p }
function Cor($h) { [Drawing.ColorTranslator]::FromHtml($h) }
$apps = @(
    @{ n = 'word'; l = 'W'; escuro = '#185ABD'; medio = '#2B7CD3'; claro = '#41A5EE'; folha = 'linhas' },
    @{ n = 'excel'; l = 'X'; escuro = '#107C41'; medio = '#21A366'; claro = '#33C481'; folha = 'grade' },
    @{ n = 'powerpoint'; l = 'P'; escuro = '#C43E1C'; medio = '#ED6C47'; claro = '#FF8F6B'; folha = 'pizza' })
$prev = New-Object Drawing.Bitmap 460, 160; $gp = [Drawing.Graphics]::FromImage($prev); $gp.Clear((Cor '#1E2A3A')); $gp.InterpolationMode = 'HighQualityBicubic'
$i = 0
foreach ($a in $apps) {
    $b = New-Object Drawing.Bitmap 128, 128, ([Drawing.Imaging.PixelFormat]::Format32bppArgb); $g = [Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.PixelOffsetMode = 'HighQuality'
    # folha
    $g.FillPath((New-Object Drawing.SolidBrush (Cor $a.claro)), (Arred 34 8 88 112 12))
    $g.FillRectangle((New-Object Drawing.SolidBrush (Cor $a.medio)), 34, 50, 88, 30)
    $g.FillPath((New-Object Drawing.SolidBrush (Cor $a.escuro)), (Arred 34 80 88 40 12)); $g.FillRectangle((New-Object Drawing.SolidBrush (Cor $a.escuro)), 34, 80, 88, 20)
    $branco = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(150, 255, 255, 255))
    switch ($a.folha) {
        'linhas' { foreach ($y in 22, 36, 64, 92) { $g.FillRectangle($branco, 78, $y, 32, 5) } }
        'grade' { $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(150, 255, 255, 255)), 3; $g.DrawLine($pen, 92, 8, 92, 120); foreach ($y in 36, 64, 92) { $g.DrawLine($pen, 70, $y, 122, $y) } }
        'pizza' { $g.FillPie($branco, 70, 22, 44, 44, 0, 270) }
    }
    # quadrado com a letra
    $g.FillPath((New-Object Drawing.SolidBrush (Cor $a.escuro)), (Arred 6 32 64 64 8))
    $f = New-Object Drawing.Font 'Segoe UI', 44, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString($a.l, $f, [Drawing.Brushes]::White, (New-Object Drawing.RectangleF 6, 33, 64, 64), $sf); $g.Dispose()
    $b.Save("$Pasta\$($a.n)-128.png", [Drawing.Imaging.ImageFormat]::Png)
    $p = New-Object Drawing.Bitmap 32, 32, ([Drawing.Imaging.PixelFormat]::Format32bppArgb); $g = [Drawing.Graphics]::FromImage($p)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.DrawImage($b, 0, 0, 32, 32); $g.Dispose()
    $p.Save("$Pasta\$($a.n).png", [Drawing.Imaging.ImageFormat]::Png)
    $gp.DrawImage($b, 10 + $i * 150, 16, 128, 128); $gp.DrawImage($p, 104 + $i * 150, 120, 32, 32); $i++
}
$gp.Dispose(); $prev.Save("$Pasta\preview-office.png", [Drawing.Imaging.ImageFormat]::Png)
Get-ChildItem $Pasta -Filter *.png | Where-Object Name -Match 'word|excel|powerpoint|office' | Select-Object Name, Length
