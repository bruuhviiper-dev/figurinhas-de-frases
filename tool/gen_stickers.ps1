Add-Type -AssemblyName System.Drawing
$root = "C:\Users\Particular\Desktop\app30\assets\stickers"
New-Item -ItemType Directory -Force $root | Out-Null
$S = 512

$packs = @(
  @{ id="amor";   name="Amor";    emoji=[char]::ConvertFromUtf32(0x2764); c1=@(255,95,109);  c2=@(255,143,177); heart=$true;  frases=@(
      "Você é meu amor","Te amo hoje e sempre","Meu coração é seu","Você é o meu mundo",
      "Pra sempre nós dois","Meu amor favorito","Você me faz feliz","Louco por você",
      "Meu bem, te amo","Só penso em você","Você é tudo pra mim","Meu amor eterno") },
  @{ id="bomdia"; name="Bom Dia"; emoji=[char]::ConvertFromUtf32(0x2600); c1=@(255,154,60);  c2=@(255,210,90);  heart=$false; frases=@(
      "Bom dia!","Bom dia, meu bem","Que seu dia seja lindo","Bom dia com Deus",
      "Desperta, hoje é seu dia","Bom dia, abençoado","Sorria, é dia novo","Bom dia, força e fé",
      "Um café e bom dia","Bom dia, gratidão","Hoje vai ser incrível","Bom dia, seja feliz") }
)

function RoundRect($x,$y,$w,$h,$r){
  $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $d=$r*2
  $p.AddArc($x,$y,$d,$d,180,90); $p.AddArc($x+$w-$d,$y,$d,$d,270,90)
  $p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90); $p.AddArc($x,$y+$h-$d,$d,$d,90,90)
  $p.CloseFigure(); return $p
}
function HeartPath($cx,$cy,$s){
  $pts=New-Object System.Collections.Generic.List[System.Drawing.PointF]
  for($i=0;$i -le 60;$i++){ $t=[math]::PI*2*$i/60
    $x=16*[math]::Pow([math]::Sin($t),3)
    $y=13*[math]::Cos($t)-5*[math]::Cos(2*$t)-2*[math]::Cos(3*$t)-[math]::Cos(4*$t)
    $pts.Add((New-Object System.Drawing.PointF([single]($cx+$x*$s),[single]($cy-$y*$s)))) }
  $gp=New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddClosedCurve($pts.ToArray(),0.2); return $gp
}

$manifest=@()
foreach($pk in $packs){
  $dir="$root\$($pk.id)"; New-Item -ItemType Directory -Force $dir | Out-Null
  $files=@()
  $n=0
  foreach($fr in $pk.frases){
    $n++
    $bmp=New-Object System.Drawing.Bitmap($S,$S)
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
    # margem transparente (die-cut) + card com gradiente
    $m=18; $cw=$S-2*$m
    $card=RoundRect $m $m $cw $cw 92
    $rect=New-Object System.Drawing.Rectangle($m,$m,$cw,$cw)
    $c1=[System.Drawing.Color]::FromArgb(255,$pk.c1[0],$pk.c1[1],$pk.c1[2])
    $c2=[System.Drawing.Color]::FromArgb(255,$pk.c2[0],$pk.c2[1],$pk.c2[2])
    $grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$c1,$c2,120)
    # borda branca grossa (look de sticker)
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)),(RoundRect ($m-8) ($m-8) ($cw+16) ($cw+16) 100))
    $g.FillPath($grad,$card)
    # simbolo decorativo topo
    if($pk.heart){ $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60,255,255,255))),(HeartPath ($S/2) 150 6.2)) }
    else {
      $sun=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,255,255,255))
      $g.FillEllipse($sun,($S/2-46),104,92,92)
    }
    # texto central
    $fmt=New-Object System.Drawing.StringFormat; $fmt.Alignment='Center'; $fmt.LineAlignment='Center'
    $size=64
    do{ $font=New-Object System.Drawing.Font("Segoe UI",$size,[System.Drawing.FontStyle]::Bold)
        $meas=$g.MeasureString($fr,$font,($cw-70)); $size-=2 } while(($meas.Height -gt 190 -or $meas.Width -gt ($cw-60)) -and $size -gt 26)
    $box=New-Object System.Drawing.RectangleF($m,($m+70),$cw,($cw-120))
    $g.DrawString($fr,$font,(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,0,0,0))),(New-Object System.Drawing.RectangleF(($m+3),($m+73),$cw,($cw-120))),$fmt)
    $g.DrawString($fr,$font,[System.Drawing.Brushes]::White,$box,$fmt)
    # marca
    $bf=New-Object System.Drawing.Font("Segoe UI",17,[System.Drawing.FontStyle]::Bold)
    $g.DrawString("Figurinhas de Frases",$bf,(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,255,255,255))),(New-Object System.Drawing.RectangleF($m,($S-$m-52),$cw,30)),$fmt)
    $file="$dir\{0:D2}.png" -f $n
    $bmp.Save($file,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    $files += "assets/stickers/$($pk.id)/{0:D2}.png" -f $n
  }
  $manifest += [ordered]@{ id=$pk.id; name=$pk.name; emoji=$pk.emoji;
    c1=("#{0:X2}{1:X2}{2:X2}" -f $pk.c1[0],$pk.c1[1],$pk.c1[2]);
    c2=("#{0:X2}{1:X2}{2:X2}" -f $pk.c2[0],$pk.c2[1],$pk.c2[2]);
    count=$files.Count; stickers=$files }
}
$json=$manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText("$root\packs.json",$json,(New-Object System.Text.UTF8Encoding($false)))
"OK: " + ($manifest.Count) + " pacotes, " + (($manifest | ForEach-Object { $_.count } | Measure-Object -Sum).Sum) + " figurinhas"
