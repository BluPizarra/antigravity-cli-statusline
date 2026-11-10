@echo off
setlocal
python "%~dp0statusline.py" 2>nul
if %errorlevel% neq 0 (
    py -3 "%~dp0statusline.py" 2>nul
)
exit /b 0
