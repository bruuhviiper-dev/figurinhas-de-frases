Add-Type -AssemblyName System.Drawing
# Restyle NAO-destrutivo: re-renderiza SO os packs de texto listados, no lugar,
# com cara de figurinha (die-cut): sombra suave + contorno branco grosso.
# Nao mexe em animadas / carinhas / coracoes nem no packs.json.
$root = "C:\Users\Particular\Desktop\app30\assets\stickers"
$S = 512

# simbolo decorativo por pack (igual ao gerador original)
$symMap = @{
  amor="heart"; bomdia="sun"; boanoite="moon"; amizade="heart"; motivacao="star";
  curtas="none"; autoestima="star"; gratidao="heart"; fe="star"; indiretas="none";
  aniversario="star"; saudade="heart"; vida="none"; atitude="star"; engracadas="none"
}

function RoundRect($x,$y,$w,$h,$r){ $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $d=$r*2
  $p.AddArc($x,$y,$d,$d,180,90);$p.AddArc($x+$w-$d,$y,$d,$d,270,90);$p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90);$p.AddArc($x,$y+$h-$d,$d,$d,90,90);$p.CloseFigure();return $p }
function HeartPath($cx,$cy,$s){ $pts=New-Object System.Collections.Generic.List[System.Drawing.PointF]
  for($i=0;$i -le 60;$i++){ $t=[math]::PI*2*$i/60; $x=16*[math]::Pow([math]::Sin($t),3)
    $y=13*[math]::Cos($t)-5*[math]::Cos(2*$t)-2*[math]::Cos(3*$t)-[math]::Cos(4*$t)
    $pts.Add((New-Object System.Drawing.PointF([single]($cx+$x*$s),[single]($cy-$y*$s)))) }
  $gp=New-Object System.Drawing.Drawing2D.GraphicsPath;$gp.AddClosedCurve($pts.ToArray(),0.2);return $gp }
function StarPath($cx,$cy,$r){ $gp=New-Object System.Drawing.Drawing2D.GraphicsPath; $pts=@()
  for($i=0;$i -lt 10;$i++){ $ang=-90+$i*36; $rad=[math]::PI*$ang/180; $rr=if($i%2 -eq 0){$r}else{$r*0.45}
    $pts+=New-Object System.Drawing.PointF([single]($cx+$rr*[math]::Cos($rad)),[single]($cy+$rr*[math]::Sin($rad))) }
  $gp.AddPolygon($pts);return $gp }
function HexRGB($hex){ $h=$hex.TrimStart('#')
  return @([Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16),[Convert]::ToInt32($h.Substring(4,2),16)) }

$packs = [System.IO.File]::ReadAllText("$root\packs.json",[System.Text.Encoding]::UTF8) | ConvertFrom-Json
$done=0
foreach($pk in $packs){
  if($pk.animated){ continue }
  if(-not $symMap.ContainsKey($pk.id)){ continue }   # pula carinhas/coracoes/etc
  $dir="$root\$($pk.id)"
  $rgb1=HexRGB $pk.c1; $rgb2=HexRGB $pk.c2
  $c1=[System.Drawing.Color]::FromArgb(255,$rgb1[0],$rgb1[1],$rgb1[2])
  $c2=[System.Drawing.Color]::FromArgb(255,$rgb2[0],$rgb2[1],$rgb2[2])
  $sym=$symMap[$pk.id]
  $n=0
  foreach($fr in $pk.texts){
    $n++
    $bmp=New-Object System.Drawing.Bitmap([int]$S,[int]$S); $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::Transparent)

    # geometria da figurinha (die-cut): corpo branco + card com gradiente
    $wm=30; $wcw=$S-2*$wm             # corpo branco: 30..482
    $bord=15                          # espessura do contorno branco
    $gm=$wm+$bord; $gcw=$wcw-2*$bord  # card gradiente
    $rW=120; $rG=104

    # sombra suave: empilha camadas translucidas deslocadas pra baixo
    for($k=10;$k -ge 1;$k--){
      $off=$k*1.3
      $exp=$k*0.6
      $sh=RoundRect ([single]($wm-$exp)) ([single]($wm-$exp+$off+3)) ([single]($wcw+2*$exp)) ([single]($wcw+2*$exp)) ([single]($rW+$exp))
      $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(9,0,0,0))),$sh)
    }

    # corpo branco (contorno da figurinha)
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)),(RoundRect $wm $wm $wcw $wcw $rW))
    # card com gradiente
    $rect=New-Object System.Drawing.Rectangle($gm,$gm,$gcw,$gcw)
    $grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$c1,$c2,120)
    $g.FillPath($grad,(RoundRect $gm $gm $gcw $gcw $rG))
    # brilho superior sutil
    $gloss=New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle($gm,$gm,$gcw,[int]($gcw*0.5))),[System.Drawing.Color]::FromArgb(46,255,255,255),[System.Drawing.Color]::FromArgb(0,255,255,255),90)
    $g.FillPath($gloss,(RoundRect $gm $gm $gcw ([int]($gcw*0.5)) $rG))

    # simbolo decorativo
    $wsym=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(58,255,255,255))
    switch($sym){
      "heart"{ $g.FillPath($wsym,(HeartPath ($S/2) 158 5.6)) }
      "sun"  { $g.FillEllipse($wsym,($S/2-44),116,88,88) }
      "moon" { $g.FillEllipse($wsym,($S/2-42),114,84,84); $g.FillEllipse((New-Object System.Drawing.SolidBrush($c1)),($S/2-12),110,76,76) }
      "star" { $g.FillPath($wsym,(StarPath ($S/2) 158 50)) }
    }

    # texto central
    $fmt=New-Object System.Drawing.StringFormat; $fmt.Alignment='Center'; $fmt.LineAlignment='Center'
    $size=58
    do{ $font=New-Object System.Drawing.Font("Segoe UI",$size,[System.Drawing.FontStyle]::Bold)
        $meas=$g.MeasureString($fr,$font,($gcw-56)); $size-=2 } while(($meas.Height -gt 200 -or $meas.Width -gt ($gcw-46)) -and $size -gt 22)
    $box=New-Object System.Drawing.RectangleF($gm,($gm+58),$gcw,($gcw-110))
    $g.DrawString($fr,$font,(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(75,0,0,0))),(New-Object System.Drawing.RectangleF(($gm+3),($gm+61),$gcw,($gcw-110))),$fmt)
    $g.DrawString($fr,$font,[System.Drawing.Brushes]::White,$box,$fmt)

    # marca
    $bf=New-Object System.Drawing.Font("Segoe UI",15,[System.Drawing.FontStyle]::Bold)
    $g.DrawString("Figurinhas de Frases",$bf,(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180,255,255,255))),(New-Object System.Drawing.RectangleF($gm,($S-$gm-46),$gcw,26)),$fmt)

    $file="$dir\{0:D2}.png" -f $n
    $bmp.Save($file,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  }
  $done++
  "{0,-12} {1} figurinhas restyled" -f $pk.name,$n
}
"==== $done packs de texto atualizados (die-cut)"
