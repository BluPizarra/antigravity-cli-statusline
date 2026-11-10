# Windows Setup Guide for Antigravity CLI Status Line

This guide explains how to install and run the custom status line on Windows.

---

## What Was the Issue?
The original package (`install_statusline.sh`) was written for Linux/macOS using Bash and `jq`. On Windows PowerShell or Command Prompt, bash scripts cannot run natively without WSL or Git Bash.

## How It Works on Windows
1. **Python Script (`statusline.py`)**: Uses native Python 3 to parse the metrics JSON and render colored ANSI output and unicode progress blocks (`█░`).
2. **Command Launcher (`statusline.cmd`)**: Batch wrapper that executes `statusline.py` when Antigravity CLI invokes the status line.
3. **Settings (`settings.json`)**: Configured in `%USERPROFILE%\.gemini\antigravity-cli\settings.json`.

---

## Installation Options

### Option 1: Double-Click
Double-click `install_statusline.bat` in this folder.

### Option 2: PowerShell
Run:
```powershell
powershell -ExecutionPolicy Bypass -File .\install_statusline.ps1
```

---

## Live Status Line Preview
Once active, your Antigravity CLI displays:
```
[Model] │ [Context Window Bar %] │ [Git Branch] │ [Session Quota %] │ [Weekly Quota %] │ [Folder]
```
Example:
```
Gemini 3.8 Flash │ ██░░░░░░░░ 10% │ Session:28% │ Weekly:14% │ School
```
