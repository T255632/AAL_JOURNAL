$ErrorActionPreference = 'Stop'
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Port = 47831
$Url = "http://127.0.0.1:$Port/"
$ProfileDir = Join-Path $env:LOCALAPPDATA 'AAL Journal\BrowserProfile'
New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null

function Find-Browser {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($candidate in $candidates) { if ($candidate -and (Test-Path $candidate)) { return $candidate } }
    return $null
}

$Browser = Find-Browser
if (-not $Browser) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show('AAL Journal needs Microsoft Edge or Google Chrome. Microsoft Edge is included with Windows 10/11.','AAL Journal') | Out-Null
    exit 4
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$ownsListener = $true
try { $listener.Start() } catch { $ownsListener = $false }

$browserArgs = @(
    "--app=$Url",
    "--user-data-dir=$ProfileDir",
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-features=msEdgeFirstRunExperience',
    '--window-size=1440,960'
)

if (-not $ownsListener) {
    Start-Process -FilePath $Browser -ArgumentList $browserArgs | Out-Null
    exit 0
}

function Write-Response($Client, [int]$Status, [string]$ContentType, [byte[]]$Body) {
    $stream = $Client.GetStream()
    $statusText = if ($Status -eq 200) { 'OK' } elseif ($Status -eq 204) { 'No Content' } else { 'Not Found' }
    $headers = "HTTP/1.1 $Status $statusText`r`nContent-Type: $ContentType`r`nContent-Length: $($Body.Length)`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
    $stream.Write($headerBytes,0,$headerBytes.Length)
    if ($Body.Length -gt 0) { $stream.Write($Body,0,$Body.Length) }
    $stream.Flush()
}

function Serve-One($Client) {
    try {
        $stream = $Client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream,[System.Text.Encoding]::ASCII,$false,1024,$true)
        $request = $reader.ReadLine()
        if (-not $request) { return }
        do { $line = $reader.ReadLine() } while ($line -ne $null -and $line -ne '')
        $parts = $request.Split(' ')
        $path = if ($parts.Length -ge 2) { ($parts[1] -split '\?')[0] } else { '/' }
        switch ($path) {
            '/' { Write-Response $Client 200 'text/html; charset=utf-8' ([IO.File]::ReadAllBytes((Join-Path $AppDir 'index.html'))) }
            '/index.html' { Write-Response $Client 200 'text/html; charset=utf-8' ([IO.File]::ReadAllBytes((Join-Path $AppDir 'index.html'))) }
            '/aal_logo.png' { Write-Response $Client 200 'image/png' ([IO.File]::ReadAllBytes((Join-Path $AppDir 'aal_logo.png'))) }
            '/manifest.webmanifest' { Write-Response $Client 200 'application/manifest+json; charset=utf-8' ([IO.File]::ReadAllBytes((Join-Path $AppDir 'manifest.webmanifest'))) }
            '/favicon.ico' { Write-Response $Client 200 'image/x-icon' ([IO.File]::ReadAllBytes((Join-Path $AppDir 'AALJournal.ico'))) }
            default { Write-Response $Client 404 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('Not found')) }
        }
    } catch {
        try { Write-Response $Client 404 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('Not found')) } catch {}
    } finally {
        try { $Client.Close() } catch {}
    }
}

$proc = Start-Process -FilePath $Browser -ArgumentList $browserArgs -PassThru
try {
    while (-not $proc.HasExited) {
        while ($listener.Pending()) {
            $client = $listener.AcceptTcpClient()
            Serve-One $client
        }
        Start-Sleep -Milliseconds 40
        try { $proc.Refresh() } catch {}
    }
} finally {
    try { $listener.Stop() } catch {}
}
