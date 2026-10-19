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


## Archive verification

Before clearing a source log, the script checks the copied file's SHA-256 hash. For compressed archives it also reads back the ZIP entry and verifies its hash. If verification fails or the source changes during rotation, the original is retained. This is intended for inactive or cooperative log writers: simultaneous writes immediately around clearing cannot be made atomic by this approach. `-WhatIf` previews actions.
