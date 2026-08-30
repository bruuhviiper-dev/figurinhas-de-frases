Add-Type -AssemblyName System.Drawing
# Gera identidade do app30 "Figurinhas de Frases":
# icone legado + adaptativo (fg/bg) + splash. Motivo: figurinha die-cut branca
# levemente girada com aspas grandes no gradiente roxo->rosa da marca.
$res = "C:\Users\Particular\Desktop\app30\android\app\src\main\res"

# paleta da marca (igual ao main.dart)
$purple = [System.Drawing.Color]::FromArgb(255,139,92,246)   # 8B5CF6
$pink   = [System.Drawing.Color]::FromArgb(255,236,72,153)   # EC4899
$bgDark = [System.Drawing.Color]::FromArgb(255,13,14,18)     # 0D0E12

function RoundRect($x,$y,$w,$h,$r){ $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $d=$r*2
  $p.AddArc($x,$y,$d,$d,180,90);$p.AddArc($x+$w-$d,$y,$d,$d,270,90);$p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90);$p.AddArc($x,$y+$h-$d,$d,$d,90,90);$p.CloseFigure();return $p }

# desenha o motivo (figurinha + aspas) centrado, ocupando 'motif' px
function DrawMotif($g,$S,$motif){
  $cx=$S/2.0; $cy=$S/2.0
  $st=$g.Save()
  $g.TranslateTransform($cx,$cy); $g.RotateTransform(-8); $g.TranslateTransform(-$cx,-$cy)
  $m=$motif; $x=$cx-$m/2; $y=$cy-$m/2; $r=$m*0.26

  # sombra suave empilhada
  for($k=9;$k -ge 1;$k--){
    $off=$k*($m*0.006); $exp=$k*($m*0.004)
    $sh=RoundRect ([single]($x-$exp)) ([single]($y-$exp+$off+$m*0.02)) ([single]($m+2*$exp)) ([single]($m+2*$exp)) ([single]($r+$exp))
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(11,0,0,0))),$sh)
  }
  # corpo branco (die-cut)
  $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)),(RoundRect $x $y $m $m $r))
  # card interno com leve gradiente branco->cinza claro
  $ib=$m*0.11
  $rectIn=New-Object System.Drawing.Rectangle([int]($x+$ib),[int]($y+$ib),[int]($m-2*$ib),[int]($m-2*$ib))
  $gin=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectIn,[System.Drawing.Color]::FromArgb(255,250,247,255),[System.Drawing.Color]::FromArgb(255,244,238,252),120)
  $g.FillPath($gin,(RoundRect ($x+$ib) ($y+$ib) ($m-2*$ib) ($m-2*$ib) ($r*0.8)))

  # aspas grandes no gradiente da marca
  $qRect=New-Object System.Drawing.Rectangle([int]($x+$m*0.16),[int]($y+$m*0.10),[int]($m*0.7),[int]($m*0.8))
  $qBrush=New-Object System.Drawing.Drawing2D.LinearGradientBrush($qRect,$purple,$pink,60)
  $fmt=New-Object System.Drawing.StringFormat; $fmt.Alignment='Center'; $fmt.LineAlignment='Center'
  $qFont=New-Object System.Drawing.Font("Georgia",[single]($m*0.72),[System.Drawing.FontStyle]::Bold)
  $g.TextRenderingHint='AntiAlias'
  $g.DrawString([string][char]0x201C,$qFont,$qBrush,(New-Object System.Drawing.RectangleF([single]$x,[single]($y+$m*0.06),[single]$m,[single]$m)),$fmt)
  $g.Restore($st)
}

# ---- ICONE LEGADO (full-bleed gradiente) ----
function MakeLegacy($S,$path){
  $bmp=New-Object System.Drawing.Bitmap([int]$S,[int]$S); $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.InterpolationMode='HighQualityBicubic'; $g.Clear([System.Drawing.Color]::Transparent)
  $rect=New-Object System.Drawing.Rectangle(0,0,[int]$S,[int]$S)
  $grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$purple,$pink,120)
  $g.FillPath($grad,(RoundRect 0 0 $S $S ($S*0.22)))
  DrawMotif $g $S ([single]($S*0.62))
  $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
}

# ---- ADAPTATIVO: background gradiente cheio ----
function MakeBg($S,$path){
  $bmp=New-Object System.Drawing.Bitmap([int]$S,[int]$S); $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
  $rect=New-Object System.Drawing.Rectangle(0,0,[int]$S,[int]$S)
  $grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$purple,$pink,120)
  $g.FillRectangle($grad,$rect)
  $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
}
# ---- ADAPTATIVO: foreground = motivo na zona segura (transparente) ----
function MakeFg($S,$path){
  $bmp=New-Object System.Drawing.Bitmap([int]$S,[int]$S); $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
  DrawMotif $g $S ([single]($S*0.52))   # zona segura ~66%, motivo menor
  $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
}
# ---- SPLASH: motivo sobre transparente (fundo dark vem do XML) ----
function MakeSplash($S,$path){
  $bmp=New-Object System.Drawing.Bitmap([int]$S,[int]$S); $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
  DrawMotif $g $S ([single]($S*0.82))
  $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
}

# densidades
$legacy = @{ mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192 }
$adapt  = @{ mdpi=108; hdpi=162; xhdpi=216; xxhdpi=324; xxxhdpi=432 }
$splash = @{ mdpi=96; hdpi=144; xhdpi=192; xxhdpi=288; xxxhdpi=384 }

foreach($d in $legacy.Keys){
  $dir="$res\mipmap-$d"; New-Item -ItemType Directory -Force $dir | Out-Null
  MakeLegacy $legacy[$d] "$dir\ic_launcher.png"
  MakeBg $adapt[$d] "$dir\ic_launcher_background.png"
  MakeFg $adapt[$d] "$dir\ic_launcher_foreground.png"
  $sdir="$res\drawable-$d"; New-Item -ItemType Directory -Force $sdir | Out-Null
  MakeSplash $splash[$d] "$sdir\ic_splash.png"
  "  $d ok"
}

# mipmap-anydpi-v26
$anyd="$res\mipmap-anydpi-v26"; New-Item -ItemType Directory -Force $anyd | Out-Null
$icXml=@'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'@
[System.IO.File]::WriteAllText("$anyd\ic_launcher.xml",$icXml,(New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText("$anyd\ic_launcher_round.xml",$icXml,(New-Object System.Text.UTF8Encoding($false)))

# colors.xml (fundo do splash)
$valdir="$res\values"; New-Item -ItemType Directory -Force $valdir | Out-Null
$colorsXml=@'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="splash_bg">#0D0E12</color>
</resources>
'@
[System.IO.File]::WriteAllText("$valdir\colors.xml",$colorsXml,(New-Object System.Text.UTF8Encoding($false)))

# launch_background.xml (fundo dark + logo centrado)
$lb=@'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_bg" />
    <item>
        <bitmap android:gravity="center" android:src="@drawable/ic_splash" />
    </item>
</layer-list>
'@
[System.IO.File]::WriteAllText("$res\drawable\launch_background.xml",$lb,(New-Object System.Text.UTF8Encoding($false)))
New-Item -ItemType Directory -Force "$res\drawable-v21" | Out-Null
[System.IO.File]::WriteAllText("$res\drawable-v21\launch_background.xml",$lb,(New-Object System.Text.UTF8Encoding($false)))

# values-v31: splash nativo Android 12+
$v31="$res\values-v31"; New-Item -ItemType Directory -Force $v31 | Out-Null
$v31Xml=@'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">@color/splash_bg</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
'@
[System.IO.File]::WriteAllText("$v31\styles.xml",$v31Xml,(New-Object System.Text.UTF8Encoding($false)))

"==== identidade gerada (icone + splash)"
