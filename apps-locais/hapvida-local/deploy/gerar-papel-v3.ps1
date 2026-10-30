param([string]$Saida = 'C:\Users\Administrator\Downloads\hapvida-v3')
# Papel de parede da HAPVIDA no modelo do BTG: losangos laranja sobre azul-escuro HAPVIDA, flor colorida + "Hapvida" no lugar do btg.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class Px {
  public static byte[] Get(Bitmap b){ var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb); var a=new byte[d.Stride*b.Height]; Marshal.Copy(d.Scan0,a,0,a.Length); b.UnlockBits(d); return a; }
  public static Bitmap Make(byte[] a,int w,int h){ var b=new Bitmap(w,h,PixelFormat.Format32bppArgb); var d=b.LockBits(new Rectangle(0,0,w,h),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb); Marshal.Copy(a,0,d.Scan0,a.Length); b.UnlockBits(d); return b; }
  // Logo azul sobre branco/transparente -> máscara (tinta) recolorida
  public static Bitmap Tinta(Bitmap src,int r,int g,int bl){ int w=src.Width,h=src.Height; var a=Get(src); var o=new byte[a.Length];
    for(int i=0;i<a.Length;i+=4){ double al=a[i+3]/255.0; double ink=1.0-a[i+2]/255.0; double m=Math.Max(0,Math.Min(1,al*ink*1.15)); o[i]=(byte)bl;o[i+1]=(byte)g;o[i+2]=(byte)r;o[i+3]=(byte)(m*255); }
    return Make(o,w,h); }
  public static Rectangle Caixa(Bitmap b,int y0,int y1){ var a=Get(b); int w=b.Width; int x0=w,x1=-1,yy0=y1,yy1=-1;
    for(int y=y0;y<y1;y++)for(int x=0;x<w;x++){ if(a[(y*w+x)*4+3]>25){ if(x<x0)x0=x; if(x>x1)x1=x; if(y<yy0)yy0=y; if(y>yy1)yy1=y; } }
    return new Rectangle(x0,yy0,x1-x0+1,yy1-yy0+1); }
  public static int[] Linhas(Bitmap b){ var a=Get(b); int w=b.Width; var s=new int[b.Height]; for(int y=0;y<b.Height;y++)for(int x=0;x<w;x++) if(a[(y*w+x)*4+3]>25) s[y]++; return s; }
  // Papel de parede: decompõe cada pixel do BTG em fundo + branco + azul e recompõe com as cores novas
  public static Bitmap Recolorir(Bitmap src,int[] bg,int[] az,int[] nbg,int[] naz,Rectangle apagar){ int w=src.Width,h=src.Height; var a=Get(src);
    for(int y=0;y<h;y++)for(int x=0;x<w;x++){ int i=(y*w+x)*4; double R=a[i+2],G=a[i+1],B=a[i];
      double wt=Math.Max(0,Math.Min(1,(R-bg[0])/(255.0-bg[0])));
      double s=Math.Max(0,Math.Min(1-wt,(B-bg[2]-wt*(255-bg[2]))/(double)(az[2]-bg[2])));
      if(apagar.Contains(x,y)){wt=0;s=0;}
      double f=1-wt-s; if(x<4||y<4||x>=w-4||y>=h-4){f=1;wt=0;s=0;}
      a[i+2]=(byte)Math.Round(nbg[0]*f+255*wt+naz[0]*s); a[i+1]=(byte)Math.Round(nbg[1]*f+255*wt+naz[1]*s); a[i]=(byte)Math.Round(nbg[2]*f+255*wt+naz[2]*s); a[i+3]=255; }
    return Make(a,w,h); }
}
'@
New-Item -ItemType Directory -Force $Saida | Out-Null
Copy-Item C:\Users\Administrator\Downloads\hapvida-v2\brandImage.png, C:\Users\Administrator\Downloads\hapvida-v2\productImage.png $Saida -Force
$btg = [Drawing.Bitmap]::FromFile('C:\eLuxContainer\theme\btg\desktopBackgroundImage.png')
$c = $btg.GetPixel(400, 800); $q = $btg.GetPixel(1517, 60)
$apagar = New-Object Drawing.Rectangle 1090, 480, 200, 175
$wp = [Px]::Recolorir($btg, @($c.R, $c.G, $c.B), @($q.R, $q.G, $q.B), @(0, 42, 88), @(255, 152, 0), $apagar)
$g = [Drawing.Graphics]::FromImage($wp); $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.TextRenderingHint = 'AntiAliasGridFit'
$flor = [Drawing.Bitmap]::FromFile("$Saida\brandImage.png")
$fw = 150; $fh = [int]($flor.Height * $fw / $flor.Width)
$g.DrawImage($flor, (New-Object Drawing.Rectangle ([int](1190 - $fw / 2)), 478, $fw, $fh))
$fonte = New-Object Drawing.Font 'Segoe UI Semibold', 34, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$fmt = New-Object Drawing.StringFormat; $fmt.Alignment = 'Center'
$g.DrawString('Hapvida', $fonte, [Drawing.Brushes]::White, (New-Object Drawing.RectangleF 1040, (478 + $fh + 2), 300, 50), $fmt); $g.Dispose()
$wp.Save("$Saida\desktopBackgroundImage.png", [Drawing.Imaging.ImageFormat]::Png)
Copy-Item "$Saida\desktopBackgroundImage.png" "$Saida\welcomeBackgroundImage.png" -Force
$cfg = Get-Content C:\Users\Administrator\Downloads\hapvida-v2\config.json -Raw | ConvertFrom-Json; $cfg.name = 'hapvida-v3'
[IO.File]::WriteAllText("$Saida\config.json", ($cfg | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
Get-ChildItem $Saida | Select-Object Name, Length
