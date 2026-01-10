# windows-log-rotator

Rotate and compress log files with a retention policy, because one app will eventually fill your disk.
It always does.

Author: TABARC-Code
Plugin URI: https://github.com/TABARC-Code/

## What it does

- rotates logs by size or age
- compresses rotated logs into zip archives
- deletes archives older than retention days
- writes a simple run log

## Scripts

- `Rotate-Logs.ps1`

## Quick start

```powershell
.\Rotate-Logs.ps1 -Path "C:\Logs" -Pattern "*.log" -MaxSizeMB 50 -KeepDays 14
```

Dry run:

```powershell
.\Rotate-Logs.ps1 -Path "C:\Logs" -WhatIf
```

This is meant for boring sysadmin hygiene, not poetry.
