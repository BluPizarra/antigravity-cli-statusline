# Antigravity CLI Status Line Installer (PowerShell)
$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Antigravity CLI Status Line Installer for Windows" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$configDir = Join-Path $HOME ".gemini\antigravity-cli"
$scriptDir = $PSScriptRoot

if (-not (Test-Path $configDir)) {
    Write-Host "[*] Creating Antigravity CLI directory: $configDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

Write-Host "[*] Copying statusline files to $configDir..." -ForegroundColor Yellow
Copy-Item (Join-Path $scriptDir "statusline.py") (Join-Path $configDir "statusline.py") -Force
Copy-Item (Join-Path $scriptDir "statusline.cmd") (Join-Path $configDir "statusline.cmd") -Force

Write-Host "[*] Updating settings.json (UTF-8 No-BOM)..." -ForegroundColor Yellow
$settingsFile = Join-Path $configDir "settings.json"
$cmdPath = ($configDir + "\statusline.cmd").Replace('\', '/')

if (Test-Path $settingsFile) {
    $rawText = [System.IO.File]::ReadAllText($settingsFile, [System.Text.Encoding]::UTF8)
    $json = $rawText | ConvertFrom-Json
} else {
    $json = [PSCustomObject]@{}
}

$statusLineObj = [PSCustomObject]@{
    type = "command"
    command = $cmdPath
    enabled = $true
}

$json | Add-Member -MemberType NoteProperty -Name "statusLine" -Value $statusLineObj -Force
$jsonText = $json | ConvertTo-Json -Depth 10

# Explicitly write UTF-8 WITHOUT BOM so Go/Antigravity can parse it
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($settingsFile, $jsonText, $utf8NoBom)

Write-Host "[OK] Status line installed successfully!" -ForegroundColor Green
Write-Host "[*] Testing execution:" -ForegroundColor Cyan
'{}' | cmd /c (Join-Path $configDir "statusline.cmd")
Write-Host ""
Write-Host "Restart agy to see your new live status line!" -ForegroundColor Green