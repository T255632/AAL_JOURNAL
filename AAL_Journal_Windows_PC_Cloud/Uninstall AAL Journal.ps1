$ErrorActionPreference='SilentlyContinue'
$Target = Join-Path $env:LOCALAPPDATA 'Programs\AAL Journal'
$desktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AAL Journal.lnk'
$start = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AAL Journal.lnk'
Remove-Item -LiteralPath $desktop -Force
Remove-Item -LiteralPath $start -Force
# BrowserProfile is intentionally preserved so journal data is not accidentally destroyed.
$preserve = Join-Path $env:LOCALAPPDATA 'AAL Journal'
Remove-Item -LiteralPath $Target -Recurse -Force
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show('AAL Journal was removed. Your local journal browser profile was left in AppData so your data is not destroyed.','AAL Journal') | Out-Null
