@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   Antigravity CLI Status Line Installer for Windows
echo ========================================================
echo.

set "CONFIG_DIR=%USERPROFILE%\.gemini\antigravity-cli"
set "SCRIPT_DIR=%~dp0"

if not exist "%CONFIG_DIR%" (
    echo [*] Creating Antigravity CLI config directory...
    mkdir "%CONFIG_DIR%"
)

echo [*] Copying statusline scripts to %CONFIG_DIR%...
copy /Y "%SCRIPT_DIR%statusline.py" "%CONFIG_DIR%\statusline.py" >nul
copy /Y "%SCRIPT_DIR%statusline.cmd" "%CONFIG_DIR%\statusline.cmd" >nul

echo [*] Configuring settings.json (UTF-8 No-BOM)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$settingsFile = Join-Path $env:USERPROFILE '.gemini\antigravity-cli\settings.json';" ^
    "$cmdPath = ($env:USERPROFILE + '/.gemini/antigravity-cli/statusline.cmd').Replace('\', '/');" ^
    "if (Test-Path $settingsFile) { " ^
    "    $rawText = [System.IO.File]::ReadAllText($settingsFile, [System.Text.Encoding]::UTF8); " ^
    "    $json = $rawText | ConvertFrom-Json; " ^
    "} else { " ^
    "    $json = [PSCustomObject]@{}; " ^
    "} " ^
    "$json | Add-Member -MemberType NoteProperty -Name 'statusLine' -Value ([PSCustomObject]@{ type = 'command'; command = $cmdPath; enabled = $true }) -Force; " ^
    "$jsonText = $json | ConvertTo-Json -Depth 10; " ^
    "$utf8NoBom = New-Object System.Text.UTF8Encoding($false); " ^
    "[System.IO.File]::WriteAllText($settingsFile, $jsonText, $utf8NoBom);"

echo.
echo [OK] Status line installed successfully!
echo [*] Testing execution...
echo {} | "%CONFIG_DIR%\statusline.cmd"
echo.
echo Restart agy or launch a new turn to see the live status line!
pause