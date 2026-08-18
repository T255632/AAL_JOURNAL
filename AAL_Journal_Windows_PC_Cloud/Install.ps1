$ErrorActionPreference='Stop'
$Source = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = Join-Path $env:LOCALAPPDATA 'Programs\AAL Journal'
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$files = @('AAL Journal.exe','AALJournal.ps1','index.html','aal_logo.png','AALJournal.ico','manifest.webmanifest','Uninstall AAL Journal.ps1')
foreach($f in $files){ Copy-Item -LiteralPath (Join-Path $Source $f) -Destination (Join-Path $Target $f) -Force }
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
foreach($shortcutPath in @((Join-Path $desktop 'AAL Journal.lnk'),(Join-Path $startMenu 'AAL Journal.lnk'))){
    $s=$ws.CreateShortcut($shortcutPath)
    $s.TargetPath=Join-Path $Target 'AAL Journal.exe'
    $s.WorkingDirectory=$Target
    $s.IconLocation=(Join-Path $Target 'AALJournal.ico')+',0'
    $s.Description='AAL Journal — Trading Journal Operating System'
    $s.Save()
}
Start-Process -FilePath (Join-Path $Target 'AAL Journal.exe')
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show('AAL Journal is installed. A shortcut was added to your Desktop and Start Menu.','AAL Journal') | Out-Null
