Add-Type -AssemblyName System.Drawing
$root = "C:\Users\Particular\Desktop\app30\assets\stickers"
$S = 512

function NewCanvas { $b=New-Object System.Drawing.Bitmap([int]$S,[int]$S); $g=[System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode='AntiAlias'; return @($b,$g) }
function HeartPath($cx,$cy,$s){ $pts=New-Object System.Collections.Generic.List[System.Drawing.PointF]
  for($i=0;$i -le 80;$i++){ $t=[math]::PI*2*$i/80; $x=16*[math]::Pow([math]::Sin($t),3)
    $y=13*[math]::Cos($t)-5*[math]::Cos(2*$t)-2*[math]::Cos(3*$t)-[math]::Cos(4*$t)
    $pts.Add((New-Object System.Drawing.PointF([single]($cx+$x*$s),[single]($cy-$y*$s)))) }
  $gp=New-Object System.Drawing.Drawing2D.GraphicsPath;$gp.AddClosedCurve($pts.ToArray(),0.2);return $gp }

# ---------- CARINHAS ----------
$faceColors = @(@(255,205,60),@(255,170,80),@(255,222,120),@(255,190,90))
$expr = @('feliz','rindo','apaixonada','piscando','fofa','surpresa','tranquila','safada','alegre','sorriso','amor','contente')
$dirC="$root\carinhas"; New-Item -ItemType Directory -Force $dirC | Out-Null
$cFiles=@()
for($i=0;$i -lt 12;$i++){
  $r=NewCanvas; $b=$r[0]; $g=$r[1]
  $fc=$faceColors[$i % $faceColors.Count]
  $face=[System.Drawing.Color]::FromArgb(255,$fc[0],$fc[1],$fc[2])
  $dark=[System.Drawing.Color]::FromArgb(255,60,40,10)
  # rosto
  $g.FillEllipse((New-Object System.Drawing.SolidBrush($face)),56,56,400,400)
  # bochechas rosa
  $blush=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120,255,120,140))
  $g.FillEllipse($blush,120,290,70,42); $g.FillEllipse($blush,322,290,70,42)
  $pen=New-Object System.Drawing.Pen($dark,22); $pen.StartCap='Round'; $pen.EndCap='Round'
  $eb=New-Object System.Drawing.SolidBrush($dark)
  switch($i % 6){
    0 { $g.FillEllipse($eb,175,200,34,44); $g.FillEllipse($eb,303,200,34,44); $g.DrawArc($pen,196,250,120,90,20,140) }
    1 { $g.DrawArc($pen,168,210,60,40,180,180); $g.DrawArc($pen,284,210,60,40,180,180); $g.DrawArc($pen,196,250,120,100,10,160) }
    2 { $g.FillPath($eb,(HeartPath 192 225 2.2)); $g.FillPath($eb,(HeartPath 320 225 2.2)); $g.DrawArc($pen,206,255,100,80,20,140) }
    3 { $g.FillEllipse($eb,175,200,34,44); $g.DrawArc($pen,300,205,44,30,180,180); $g.DrawArc($pen,216,258,80,70,20,140) }
    4 { $g.FillEllipse($eb,178,205,30,38); $g.FillEllipse($eb,306,205,30,38); $g.FillEllipse($eb,230,270,52,52) }
    5 { $g.FillEllipse($eb,175,195,34,50); $g.FillEllipse($eb,303,195,34,50); $g.DrawArc($pen,196,240,120,110,15,150) }
  }
  $file="$dirC\{0:D2}.png" -f ($i+1)
  $b.Save($file,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose()
  $cFiles += "assets/stickers/carinhas/{0:D2}.png" -f ($i+1)
}

# ---------- CORACOES ----------
$hc = @(@(255,60,90),@(255,120,160),@(255,90,90),@(230,40,120),@(255,150,80),@(200,60,200),@(90,140,255),@(60,200,150),@(255,200,60),@(255,80,140),@(180,60,255),@(255,110,110))
$dirH="$root\coracoes"; New-Item -ItemType Directory -Force $dirH | Out-Null
$hFiles=@()
for($i=0;$i -lt 12;$i++){
  $r=NewCanvas; $b=$r[0]; $g=$r[1]
  $c=$hc[$i]
  $c1=[System.Drawing.Color]::FromArgb(255,$c[0],$c[1],$c[2])
  $c2=[System.Drawing.Color]::FromArgb(255,[math]::Min(255,$c[0]+40),[math]::Min(255,$c[1]+40),[math]::Min(255,$c[2]+40))
  $hp=HeartPath 256 250 13.5
  $rect=New-Object System.Drawing.Rectangle(80,70,352,352)
  $grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$c2,$c1,90)
  # contorno branco
  $wp=New-Object System.Drawing.Pen([System.Drawing.Color]::White,26); $wp.LineJoin='Round'
  $g.DrawPath($wp,$hp)
  $g.FillPath($grad,$hp)
  # brilho
  $hl=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90,255,255,255))
  $g.FillEllipse($hl,180,150,70,50)
  $file="$dirH\{0:D2}.png" -f ($i+1)
  $b.Save($file,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose()
  $hFiles += "assets/stickers/coracoes/{0:D2}.png" -f ($i+1)
}

# ---------- anexa aos manifestos ----------
$enc=New-Object System.Text.UTF8Encoding($false)
$packs=[System.IO.File]::ReadAllText("$root\packs.json",[System.Text.Encoding]::UTF8)|ConvertFrom-Json
$packs=[System.Collections.ArrayList]@($packs)
# remove se ja existir (idempotente)
$packs=@($packs | Where-Object { $_.id -ne 'carinhas' -and $_.id -ne 'coracoes' })
$packs=[System.Collections.ArrayList]@($packs)
$null=$packs.Add([ordered]@{ id='carinhas'; name='Carinhas'; emoji='😀'; c1='#FFD93D'; c2='#FF9A3C'; count=$cFiles.Count; stickers=$cFiles; texts=$expr })
$null=$packs.Add([ordered]@{ id='coracoes'; name='Corações'; emoji='❤️'; c1='#FF5F6D'; c2='#FF8FB1'; count=$hFiles.Count; stickers=$hFiles; texts=@(1..12 | ForEach-Object {'coração'}) })
[System.IO.File]::WriteAllText("$root\packs.json",($packs|ConvertTo-Json -Depth 6),$enc)

$cj=[System.IO.File]::ReadAllText("$root\contents.json",[System.Text.Encoding]::UTF8)|ConvertFrom-Json
$cpacks=@($cj.packs | Where-Object { $_.identifier -ne 'carinhas' -and $_.identifier -ne 'coracoes' })
$cpacks=[System.Collections.ArrayList]@($cpacks)
$null=$cpacks.Add([ordered]@{ identifier='carinhas'; name='Carinhas'; emoji='😀'; stickers=@($cFiles | ForEach-Object { ($_ -split '/')[-1] }) })
$null=$cpacks.Add([ordered]@{ identifier='coracoes'; name='Corações'; emoji='❤️'; stickers=@($hFiles | ForEach-Object { ($_ -split '/')[-1] }) })
$cj.packs=$cpacks
[System.IO.File]::WriteAllText("$root\contents.json",($cj|ConvertTo-Json -Depth 6),$enc)
"OK: carinhas=$($cFiles.Count) coracoes=$($hFiles.Count); total packs=$($packs.Count)"
