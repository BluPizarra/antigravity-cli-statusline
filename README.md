# Antigravity CLI Status Line

[![Python](https://img.shields.io/badge/Python-3.x-404258?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Bash](https://img.shields.io/badge/Bash-GNU-474E68?style=for-the-badge&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-50577A?style=for-the-badge&logo=powershell&logoColor=white)](https://microsoft.com/powershell)
[![Windows](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-6B728E?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/BluPizarra/antigravity-cli-statusline)
[![License: MIT](https://img.shields.io/badge/License-MIT-404258?style=for-the-badge)](LICENSE)
[![Academic](https://img.shields.io/badge/APC-BSIT%20Information%20Technology-474E68?style=for-the-badge)](https://www.apc.edu.ph/)

> Cross-platform, real-time status line renderer for Google Antigravity CLI (`agy`) featuring active model indicators, dynamic context window visualizers, git branch detection, session quotas, and duration tracking.

---

## Overview

The **Antigravity CLI Status Line** enhances the terminal experience of the Google Antigravity CLI (`agy`) by providing a persistent, contextual telemetry bar. Designed for cross-platform compatibility across Windows, macOS, and Linux, the renderer translates real-time JSON session metrics into a sleek terminal status display.

---

## Live Status Line Preview

```text
Gemini 3.8 Flash │ ██░░░░░░░░ 18% │ main │ Session:32% │ Weekly:14% │ 1h 45m │ School
```

### Component Breakdown

1. Model Identifier: Displays the active LLM (e.g., Gemini 3.8 Flash, Claude 3.5 Sonnet) in high-visibility magenta.
2. Context Window Visualizer: Dynamic 10-block unicode bar (`█░`) indicating token context usage with color thresholds:
   - Green: < 50%
   - Yellow: 50% to 79%
   - Red: >= 80%
3. Git Branch Indicator: Fast, non-blocking discovery of the active Git repository branch in green.
4. Session Quota: Real-time 5-hour rolling session limit usage.
5. Weekly Quota: Weekly rolling limit usage.
6. Session Duration: Elapsed active time computed from session transcript creation.
7. Active Workspace: Current folder name formatted in cyan.

---

## Features

- Zero-Dependency Windows Engine: Pure Python 3 (`statusline.py`) implementation designed specifically to eliminate WSL or external tool requirements on Windows.
- Cross-Platform Parity: Includes native Bash scripts (`statusline.sh`) and PowerShell installers (`install_statusline.ps1`, `install_statusline.bat`).
- Automated Settings Integration: Installers automatically inject and configure `settings.json` with strict UTF-8 (No-BOM) compliance.
- IDE Synchronization: Caches telemetry to `rate-cache.json` for seamless synchronization with VS Code and Antigravity IDE extensions.
- Fast Non-Blocking Git Resolution: Resolves Git branch state through direct `.git/HEAD` inspection without incurring CLI subprocess overhead.

---

## Installation

### Windows Installation

#### Option 1: Automated Batch Installer (Recommended)
1. Clone or download this repository.
2. Double-click `install_statusline.bat`.
3. Restart `agy` or start a new terminal session.

#### Option 2: PowerShell
Run the installer via PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install_statusline.ps1
```

---

### macOS and Linux Installation

Run the universal installer shell script:

```bash
bash install_statusline.sh
```

Ensure `jq` is installed for JSON parsing on Unix environments:

```bash
# macOS
brew install jq

# Debian / Ubuntu
sudo apt install jq
```

---

## Manual Configuration

If you prefer configuring your status line manually, update `%USERPROFILE%\.gemini\antigravity-cli\settings.json` (Windows) or `~/.gemini/antigravity-cli/settings.json` (macOS/Linux):

### Windows (`statusline.cmd`)

```json
{
  "statusLine": {
    "type": "command",
    "command": "C:/Users/<Username>/.gemini/antigravity-cli/statusline.cmd",
    "enabled": true
  }
}
```

### macOS / Linux (`statusline.sh`)

```json
{
  "statusLine": {
    "type": "command",
    "command": "/home/<username>/.gemini/antigravity-cli/statusline.sh",
    "enabled": true
  }
}
```

---

## Repository Structure

```text
antigravity-cli-statusline/
├── install_statusline.bat       # Windows 1-click batch installer
├── install_statusline.ps1       # Windows PowerShell automated setup
├── install_statusline.sh        # macOS / Linux automated installer
├── statusline.cmd               # Windows batch launcher wrapper
├── statusline.py                # Cross-platform Python statusline engine
├── statusline.sh                # Unix bash statusline engine
├── windows_setup_guide.md       # Windows setup and troubleshooting notes
├── portable_statusline_setup.md # Standalone portable configuration guide
├── statusline_sharing_guide.md  # Detailed feature overview and schema docs
├── LICENSE                      # MIT License
└── README.md                    # Project documentation
```

---

## Author

**Bludylan Cyrus A. Pizarra**  
Asia Pacific College — School of Computing and Information Technologies  
GitHub: [@BluPizarra](https://github.com/BluPizarra)

---

## License

This project is licensed under the [MIT License](LICENSE).
