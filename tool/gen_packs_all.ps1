Add-Type -AssemblyName System.Drawing
$D = "C:\Users\Particular\Desktop"
$root = "C:\Users\Particular\Desktop\app30\assets\stickers"
if(Test-Path $root){ Remove-Item $root -Recurse -Force }
New-Item -ItemType Directory -Force $root | Out-Null
$S = 512
$PER = 24   # figurinhas por pack (max WhatsApp = 30)

# pack: id,name,emoji,cor1,cor2,simbolo(heart/sun/moon/star/none),fontes "app:cat,app:cat"
$packs = @(
 @{id="amor";       name="Amor";          emoji="❤️"; c1=@(255,95,109); c2=@(255,143,177); sym="heart"; src="app25:amor,app29:amor_amizade,app25:saudade"}
 @{id="bomdia";     name="Bom Dia";       emoji="☀️"; c1=@(255,154,60); c2=@(255,210,90);  sym="sun";   src="app25:bomdia"}
 @{id="boanoite";   name="Boa Noite";     emoji="🌙"; c1=@(75,108,183); c2=@(24,40,72);    sym="moon";  src="app25:boanoite"}
 @{id="amizade";    name="Amizade";       emoji="🫂"; c1=@(17,153,142); c2=@(62,239,125);  sym="heart"; src="app29:verdadeira,app29:melhores_amigas,app29:melhores_amigos"}
 @{id="motivacao";  name="Motivação";     emoji="🚀"; c1=@(71,118,230); c2=@(142,84,233);  sym="star";  src="app25:positivas,app25:inspiracao,app27:treino"}
 @{id="curtas";     name="Frases Curtas"; emoji="✨"; c1=@(55,59,68);   c2=@(66,134,244);  sym="none";  src="app25:curtas,app25:curtinhas,app29:curtas,app27:curtas"}
 @{id="autoestima"; name="Amor Próprio";  emoji="💜"; c1=@(218,34,255);  c2=@(151,51,238);  sym="star";  src="app25:autoestima"}
 @{id="gratidao";   name="Gratidão";      emoji="🙏"; c1=@(240,152,25);  c2=@(237,222,93);  sym="heart"; src="app25:gratidao,app29:gratidao"}
 @{id="fe";         name="Fé e Deus";     emoji="✝"; c1=@(26,41,128);   c2=@(38,208,206);  sym="star";  src="app12:fe,app12:gratidao,app29:fe,app27:fe"}
 @{id="indiretas";  name="Indiretas";     emoji="😏"; c1=@(32,1,34);     c2=@(111,0,0);     sym="none";  src="app27:indiretas,app27:atitude"}
 @{id="aniversario";name="Aniversário";   emoji="🎉"; c1=@(248,87,166);  c2=@(255,88,88);   sym="star";  src="app29:aniversario,app27:aniversario"}
 @{id="saudade";    name="Saudade";       emoji="🥺"; c1=@(96,108,136);  c2=@(63,76,107);   sym="heart"; src="app25:saudade,app29:distancia"}
 @{id="vida";       name="Sobre a Vida";  emoji="🌿"; c1=@(15,32,39);    c2=@(44,83,100);   sym="none";  src="app25:vida,app25:reflexao,app25:refletir"}
 @{id="atitude";    name="Atitude";       emoji="🔥"; c1=@(15,12,41);    c2=@(48,43,99);    sym="star";  src="app27:atitude,app27:sozinha"}
 @{id="engracadas"; name="Engraçadas";    emoji="😂"; c1=@(253,200,48);  c2=@(243,115,53);  sym="none";  src="app29:engracadas,app25:alegria"}
)

$cache=@{}
function LoadCat($app,$cat){
  $k="$app/$cat"; if($cache.ContainsKey($k)){ return $cache[$k] }
  $f="$D\$app\assets\frases\$cat.json"
  $r=@()
  if(Test-Path $f){ try{ $r=[System.IO.File]::ReadAllText($f,[System.Text.Encoding]::UTF8)|ConvertFrom-Json }catch{} }
  $cache[$k]=$r; return $r
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

$manifest=@()
foreach($pk in $packs){
  $dir="$root\$($pk.id)"; New-Item -ItemType Directory -Force $dir | Out-Null
  # agrega frases das fontes
  $all=@()
  foreach($srcpair in ($pk.src -split ",")){ $p2=$srcpair -split ":"; $all += (LoadCat $p2[0] $p2[1]) }
  # normaliza, tira aspas, dedup, filtra CURTAS, ordena por tamanho
  $seen=New-Object System.Collections.Generic.HashSet[string]
  $cand=@()
  foreach($fr in $all){ if(-not $fr){continue}
    $t=($fr -replace '^["“”]+','' -replace '["“”]+$','').Trim()
    if($t.Length -lt 6 -or $t.Length -gt 60){ continue }
    if(($t -split '\s+').Count -gt 8){ continue }
    if($seen.Add($t.ToLower())){ $cand += $t }
  }
  $cand = $cand | Sort-Object { $_.Length } | Select-Object -First $PER
  $files=@(); $n=0
  foreach($fr in $cand){
    $n++
    $bmp=New-Object System.Drawing.Bitmap([int]$S,[int]$S); $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
    $m=18; $cw=$S-2*$m
    $rect=New-Object System.Drawing.Rectangle($m,$m,$cw,$cw)
    $c1=[System.Drawing.Color]::FromArgb(255,$pk.c1[0],$pk.c1[1],$pk.c1[2])
    $c2=[System.Drawing.Color]::FromArgb(255,$pk.c2[0],$pk.c2[1],$pk.c2[2])
    $grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$c1,$c2,120)
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)),(RoundRect ($m-8) ($m-8) ($cw+16) ($cw+16) 100))
    $g.FillPath($grad,(RoundRect $m $m $cw $cw 92))
    $wsym=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60,255,255,255))
    switch($pk.sym){
      "heart"{ $g.FillPath($wsym,(HeartPath ($S/2) 148 6.0)) }
      "sun"  { $g.FillEllipse($wsym,($S/2-46),102,92,92) }
      "moon" { $g.FillEllipse($wsym,($S/2-44),100,88,88); $g.FillEllipse((New-Object System.Drawing.SolidBrush($c1)),($S/2-14),96,80,80) }
      "star" { $g.FillPath($wsym,(StarPath ($S/2) 148 52)) }
    }
    $fmt=New-Object System.Drawing.StringFormat; $fmt.Alignment='Center'; $fmt.LineAlignment='Center'
    $size=62
    do{ $font=New-Object System.Drawing.Font("Segoe UI",$size,[System.Drawing.FontStyle]::Bold)
        $meas=$g.MeasureString($fr,$font,($cw-70)); $size-=2 } while(($meas.Height -gt 205 -or $meas.Width -gt ($cw-56)) -and $size -gt 24)
    $box=New-Object System.Drawing.RectangleF($m,($m+66),$cw,($cw-116))
    $g.DrawString($fr,$font,(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,0,0,0))),(New-Object System.Drawing.RectangleF(($m+3),($m+69),$cw,($cw-116))),$fmt)
    $g.DrawString($fr,$font,[System.Drawing.Brushes]::White,$box,$fmt)
    $bf=New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
    $g.DrawString("Figurinhas de Frases",$bf,(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190,255,255,255))),(New-Object System.Drawing.RectangleF($m,($S-$m-50),$cw,28)),$fmt)
    $file="$dir\{0:D2}.png" -f $n
    $bmp.Save($file,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    $files += "assets/stickers/$($pk.id)/{0:D2}.png" -f $n
  }
  $manifest += [ordered]@{ id=$pk.id; name=$pk.name; emoji=$pk.emoji;
    c1=("#{0:X2}{1:X2}{2:X2}" -f $pk.c1[0],$pk.c1[1],$pk.c1[2]);
    c2=("#{0:X2}{1:X2}{2:X2}" -f $pk.c2[0],$pk.c2[1],$pk.c2[2]);
    count=$files.Count; stickers=$files; texts=@($cand) }
  "{0,-12} {1} figurinhas" -f $pk.name,$files.Count
}
$json=$manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText("$root\packs.json",$json,(New-Object System.Text.UTF8Encoding($false)))
"==== TOTAL: " + (($manifest|ForEach-Object{$_.count}|Measure-Object -Sum).Sum) + " figurinhas em " + $manifest.Count + " packs"
