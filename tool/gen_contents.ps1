$root = "C:\Users\Particular\Desktop\app30\assets\stickers"
$packs = [System.IO.File]::ReadAllText("$root\packs.json",[System.Text.Encoding]::UTF8) | ConvertFrom-Json
$out = [ordered]@{ publisher = "Figurinhas de Frases"; packs = @() }
foreach($p in $packs){
  $files = @()
  foreach($s in $p.stickers){ $files += ($s -split "/")[-1] }   # 01.png ...
  $out.packs += [ordered]@{
    identifier = $p.id
    name       = $p.name
    emoji      = $p.emoji
    stickers   = $files
  }
}
$json = $out | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText("$root\contents.json",$json,(New-Object System.Text.UTF8Encoding($false)))
"contents.json: $($out.packs.Count) packs"
