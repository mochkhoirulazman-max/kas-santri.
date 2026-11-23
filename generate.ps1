$b64 = (Get-Content -Path "D:\Folder Baru\logo_base64.txt" -Raw).Trim()
$dataUri = "data:image/png;base64," + $b64
$tpl = Get-Content -Path "D:\Folder Baru\template.html" -Raw
$finalHtml = $tpl.Replace("LOGO_PLACEHOLDER_MARKER", $dataUri)
[System.IO.File]::WriteAllText("D:\Folder Baru\index.html", $finalHtml, [System.Text.Encoding]::UTF8)
Write-Output ("Wrote index.html successfully, length: " + (Get-Item "D:\Folder Baru\index.html").Length)
