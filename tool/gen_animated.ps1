Add-Type -AssemblyName System.Drawing
$SZ = 512
$FRAMES = 24
$tmp = "C:\Users\PARTIC~1\AppData\Local\Temp\claude\ani"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force $tmp | Out-Null

function HeartPath($cx,$cy,$s){
  $pts=New-Object System.Collections.Generic.List[System.Drawing.PointF]
  for($i=0;$i -le 80;$i++){ $t=[math]::PI*2*$i/80; $x=16*[math]::Pow([math]::Sin($t),3)
    $y=13*[math]::Cos($t)-5*[math]::Cos(2*$t)-2*[math]::Cos(3*$t)-[math]::Cos(4*$t)
    $pts.Add((New-Object System.Drawing.PointF([single]($cx+$x*$s),[single]($cy-$y*$s)))) }
  $gp=New-Object System.Drawing.Drawing2D.GraphicsPath;$gp.AddClosedCurve($pts.ToArray(),0.2);return $gp }

function Star4($cx,$cy,$outer,$inner){
  $p=New-Object System.Collections.Generic.List[System.Drawing.PointF]
  for($k=0;$k -lt 8;$k++){ $ang=[math]::PI*2*$k/8 - [math]::PI/2
    $rad = if($k % 2 -eq 0){$outer}else{$inner}
    $p.Add((New-Object System.Drawing.PointF([single]($cx+[math]::Cos($ang)*$rad),[single]($cy+[math]::Sin($ang)*$rad)))) }
  return $p.ToArray() }

function RoundRect($x,$y,$w,$h,$rad){
  $gp=New-Object System.Drawing.Drawing2D.GraphicsPath
  $dd=$rad*2
  $gp.AddArc($x,$y,$dd,$dd,180,90)
  $gp.AddArc($x+$w-$dd,$y,$dd,$dd,270,90)
  $gp.AddArc($x+$w-$dd,$y+$h-$dd,$dd,$dd,0,90)
  $gp.AddArc($x,$y+$h-$dd,$dd,$dd,90,90)
  $gp.CloseFigure(); return $gp }

# id, frase, cor1(rgb), cor2(rgb), tipo
$defs = @(
  @{id='ani_amor';    frase='Te amo';           c1=@(255,94,125); c2=@(255,150,180); tipo='heart'},
  @{id='ani_bomdia';  frase='Bom dia';          c1=@(255,159,67);  c2=@(255,206,84);  tipo='sun'},
  @{id='ani_especial';frase='Você é especial';  c1=@(142,68,255);  c2=@(198,120,255); tipo='sparkle'},
  @{id='ani_gratidao';frase='Gratidão';         c1=@(0,176,155);   c2=@(84,220,180);  tipo='shine'},
  @{id='ani_boanoite';frase='Boa noite';        c1=@(37,50,110);   c2=@(90,110,200);  tipo='stars'},
  @{id='ani_forca';   frase='Força!';           c1=@(220,40,70);   c2=@(255,110,90);  tipo='glow'}
)

$white=[System.Drawing.Color]::White
$fontFrase=New-Object System.Drawing.Font('Segoe UI',52,[System.Drawing.FontStyle]::Bold)
$sf=New-Object System.Drawing.StringFormat
$sf.Alignment='Center'; $sf.LineAlignment='Center'

foreach($d in $defs){
  $dir="$tmp\$($d.id)"; New-Item -ItemType Directory -Force $dir | Out-Null
  for($f=0;$f -lt $FRAMES;$f++){
    $t=$f/$FRAMES
    $b=New-Object System.Drawing.Bitmap([int]$SZ,[int]$SZ)
    $g=[System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::Transparent)
    $card=RoundRect 20 20 472 472 56
    $rectG=New-Object System.Drawing.Rectangle(20,20,472,472)
    $col1=[System.Drawing.Color]::FromArgb(255,$d.c1[0],$d.c1[1],$d.c1[2])
    $col2=[System.Drawing.Color]::FromArgb(255,$d.c2[0],$d.c2[1],$d.c2[2])
    $grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectG,$col2,$col1,120)
    $g.FillPath($grad,$card)

    $cx=256; $decoY=175
    switch($d.tipo){
      'heart' {
        $scale=3.4*(1+0.14*[math]::Sin($t*2*[math]::PI))
        $hp=HeartPath $cx $decoY $scale
        $wp=New-Object System.Drawing.Pen($white,10); $wp.LineJoin='Round'
        $g.DrawPath($wp,$hp)
        $inner=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,255,255,255))
        $g.FillPath($inner,$hp)
        $hl=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120,$d.c1[0],$d.c1[1],$d.c1[2]))
        $g.FillPath($hl,(HeartPath $cx $decoY ($scale*0.55)))
      }
      'sun' {
        $rot=$t*2*[math]::PI/6
        $rp=New-Object System.Drawing.Pen($white,12); $rp.StartCap='Round'; $rp.EndCap='Round'
        for($k=0;$k -lt 12;$k++){
          $a=$rot+[math]::PI*2*$k/12
          $len=70+10*[math]::Sin($t*2*[math]::PI+$k)
          $x1=$cx+[math]::Cos($a)*62; $y1=$decoY+[math]::Sin($a)*62
          $x2=$cx+[math]::Cos($a)*$len; $y2=$decoY+[math]::Sin($a)*$len
          $g.DrawLine($rp,[single]$x1,[single]$y1,[single]$x2,[single]$y2)
        }
        $g.FillEllipse((New-Object System.Drawing.SolidBrush($white)),$cx-52,$decoY-52,104,104)
      }
      'sparkle' {
        $pos=@(@(150,120),@(360,150),@(256,90),@(180,230),@(340,240))
        for($k=0;$k -lt $pos.Count;$k++){
          $ph=$k/[double]$pos.Count
          $a=[math]::Max(0,[math]::Sin(($t+$ph)*2*[math]::PI))
          if($a -gt 0){
            $rr=18+10*$a
            $br=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255*$a),255,255,255))
            $g.FillPolygon($br,(Star4 $pos[$k][0] $pos[$k][1] $rr ($rr*0.32)))
          }
        }
      }
      'shine' {
        $g.FillPath((New-Object System.Drawing.SolidBrush($white)),(HeartPath $cx $decoY 2.6))
        $bx=-160+($t*(512+320))
        $old=$g.Clip; $g.SetClip($card)
        $bp=New-Object System.Collections.Generic.List[System.Drawing.PointF]
        $bp.Add((New-Object System.Drawing.PointF([single]$bx,0)))
        $bp.Add((New-Object System.Drawing.PointF([single]($bx+90),0)))
        $bp.Add((New-Object System.Drawing.PointF([single]($bx-90),512)))
        $bp.Add((New-Object System.Drawing.PointF([single]($bx-180),512)))
        $g.FillPolygon((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,255,255,255))),$bp.ToArray())
        $g.Clip=$old
      }
      'stars' {
        $g.FillEllipse((New-Object System.Drawing.SolidBrush($white)),$cx-46,$decoY-46,92,92)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush($col1)),$cx-24,$decoY-52,92,92)
        $pos=@(@(150,110),@(360,130),@(180,240),@(350,235),@(256,80))
        for($k=0;$k -lt $pos.Count;$k++){
          $ph=$k/[double]$pos.Count
          $a=0.4+0.6*[math]::Max(0,[math]::Sin(($t+$ph)*2*[math]::PI))
          $br=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255*$a),255,255,255))
          $g.FillPolygon($br,(Star4 $pos[$k][0] $pos[$k][1] 13 4))
        }
      }
      'glow' {
        $pr=110+30*[math]::Sin($t*2*[math]::PI)
        $gp2=New-Object System.Drawing.Drawing2D.GraphicsPath
        $gp2.AddEllipse($cx-$pr,$decoY-$pr,$pr*2,$pr*2)
        $pgb=New-Object System.Drawing.Drawing2D.PathGradientBrush($gp2)
        $pgb.CenterColor=[System.Drawing.Color]::FromArgb(200,255,255,255)
        $pgb.SurroundColors=@([System.Drawing.Color]::FromArgb(0,255,255,255))
        $g.FillPath($pgb,$gp2)
        $wp=New-Object System.Drawing.Pen($white,14); $wp.LineJoin='Round'
        $g.DrawPath($wp,(HeartPath $cx $decoY 2.4))
      }
    }
    $rectText=New-Object System.Drawing.RectangleF(46,300,420,180)
    $shadow=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90,0,0,0))
    $g.DrawString($d.frase,$fontFrase,$shadow,(New-Object System.Drawing.RectangleF(49,303,420,180)),$sf)
    $g.DrawString($d.frase,$fontFrase,(New-Object System.Drawing.SolidBrush($white)),$rectText,$sf)

    $fn="$dir\frame_{0:D3}.png" -f $f
    $b.Save($fn,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $b.Dispose()
  }
  "frames OK: $($d.id)"
}
"Total: $($defs.Count) stickers x $FRAMES frames em $tmp"
