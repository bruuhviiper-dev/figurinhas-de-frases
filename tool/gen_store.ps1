Add-Type -AssemblyName System.Drawing
# Screenshots da Play Store (padrao dos outros apps): fundo gradiente da marca
# (roxo -> rosa), headline + subtitulo no topo e o print real dentro de um mockup
# arredondado. Le 0N_*.png em prints_figurinhas e gera store_NN.png.
$dir = "C:\Users\Particular\entregaveis_playstore\prints_figurinhas"
$W = 1080; $H = 1920

# t = cor do topo (roxo), b = cor da base (rosa)
$slides = @(
  @{f="01_home.png";     h1="Figurinhas de Frases";     h2="Centenas de figurinhas pro seu WhatsApp"; t=@(76,29,149);  b=@(236,72,153)},
  @{f="02_animadas.png"; h1="Figurinhas animadas";      h2="Stickers que se mexem nas conversas";     t=@(91,33,182);  b=@(219,39,119)},
  @{f="03_preview.png";  h1="Direto no WhatsApp";        h2="Um toque e o pacote vai pro teclado";      t=@(67,26,138);  b=@(236,72,153)},
  @{f="04_criar.png";    h1="Crie suas figurinhas";     h2="Monte stickers com a frase que quiser";    t=@(88,28,176);  b=@(225,45,125)},
  @{f="05_amor.png";     h1="Pra toda ocasiao";         h2="Amor, bom dia, indiretas, motivacao e fe"; t=@(72,28,145);  b=@(236,72,153)},
  @{f="06_busca.png";    h1="Encontre a frase certa";   h2="Busque por tema e mande na hora";           t=@(84,30,168);  b=@(222,42,122)}
)

function RoundRect($x,$y,$w,$h,$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r*2
  $p.AddArc($x,$y,$d,$d,180,90); $p.AddArc($x+$w-$d,$y,$d,$d,270,90)
  $p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90); $p.AddArc($x,$y+$h-$d,$d,$d,90,90)
  $p.CloseFigure(); return $p
}

$n = 0
foreach ($s in $slides) {
  $n++
  $shotPath = Join-Path $dir $s.f
  if (-not (Test-Path $shotPath)) { Write-Output ("PULOU (sem print): " + $s.f); continue }
  $bmp = New-Object System.Drawing.Bitmap($W,$H)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'; $g.InterpolationMode='HighQualityBicubic'
  $rect = New-Object System.Drawing.Rectangle(0,0,$W,$H)
  $c1 = [System.Drawing.Color]::FromArgb(255,$s.t[0],$s.t[1],$s.t[2])
  $c2 = [System.Drawing.Color]::FromArgb(255,$s.b[0],$s.b[1],$s.b[2])
  $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$c1,$c2,90)
  $g.FillRectangle($grad,$rect)
  # brilho suave rosa/branco no topo
  $glow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $glow.AddEllipse(-200,-560,$W+400,1120)
  $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($glow)
  $pgb.CenterColor=[System.Drawing.Color]::FromArgb(80,255,180,230)
  $pgb.SurroundColors=@([System.Drawing.Color]::FromArgb(0,255,180,230))
  $g.FillPath($pgb,$glow)
  $white=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $shadow=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(110,0,0,0))
  $sub=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240,245,225,240))
  $fmt=New-Object System.Drawing.StringFormat; $fmt.Alignment='Center'
  $size=66
  do { $fT=New-Object System.Drawing.Font("Segoe UI",$size,[System.Drawing.FontStyle]::Bold); $m=$g.MeasureString($s.h1,$fT); $size-=2 } while ($m.Width -gt ($W-120) -and $size -gt 30)
  $fS=New-Object System.Drawing.Font("Segoe UI Semibold",25)
  $g.DrawString($s.h1,$fT,$shadow,(New-Object System.Drawing.RectangleF(4,124,$W,130)),$fmt)
  $g.DrawString($s.h1,$fT,$white,(New-Object System.Drawing.RectangleF(0,120,$W,130)),$fmt)
  $g.DrawString($s.h2,$fS,$sub,(New-Object System.Drawing.RectangleF(0,250,$W,60)),$fmt)
  $shot=[System.Drawing.Image]::FromFile($shotPath)
  $crop=[int]($shot.Height*0.045)  # remove a barra de status do topo
  $srcH=$shot.Height-$crop
  $fh=1420; $fw=[int]($fh*$shot.Width/$srcH); $fx=[int](($W-$fw)/2); $fy=360
  $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,13,14,18))),(RoundRect ($fx-16) ($fy-16) ($fw+32) ($fh+32) 62))
  $g.SetClip((RoundRect $fx $fy $fw $fh 46))
  $destRect=New-Object System.Drawing.Rectangle($fx,$fy,$fw,$fh)
  $g.DrawImage($shot,$destRect,0,$crop,$shot.Width,$srcH,[System.Drawing.GraphicsUnit]::Pixel)
  $g.ResetClip(); $shot.Dispose()
  $out=Join-Path $dir ("store_{0:D2}.png" -f $n)
  $bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  Write-Output ("ok " + $out)
}
Write-Output ("FIM: " + $n)
