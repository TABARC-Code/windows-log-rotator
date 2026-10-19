# TABARC-Code
# Rotate and compress logs.
# Slightly tired note: if you point this at C:\ you deserve what happens.

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [string]$Pattern = "*.log",
  [int]$MaxSizeMB = 50,
  [int]$MaxAgeDays = 7,
  [int]$KeepDays = 30,
  [string]$OutDir = "",
  [switch]$Compress = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

if (-not (Test-Path -LiteralPath $Path)) { throw "Path not found: $Path" }
$root = (Resolve-Path -LiteralPath $Path).Path

if (-not $OutDir) { $OutDir = Join-Path $root "out" }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$now = Get-Date
$maxBytes = $MaxSizeMB * 1MB
$maxAge = $now.AddDays(-$MaxAgeDays)
$keepBefore = $now.AddDays(-$KeepDays)

$log = Join-Path $OutDir "rotate_run.log"
function Log([string]$m){
  $line = "[{0}] {1}" -f ($now.ToString("yyyy-MM-dd HH:mm:ss")), $m
  Add-Content -LiteralPath $log -Value $line -Encoding UTF8
  Write-Host $line
}

$files = Get-ChildItem -LiteralPath $root -File -Filter $Pattern -ErrorAction SilentlyContinue
if (-not $files) { Log "No files matched: $Pattern"; return }

foreach ($f in $files) {
  $rotate = $false
  if ($f.Length -ge $maxBytes) { $rotate = $true }
  if ($f.LastWriteTime -le $maxAge) { $rotate = $true }

  if (-not $rotate) { continue }

  $stamp = $now.ToString("yyyyMMdd_HHmmss")
  $rotName = "{0}.{1}.rotated" -f $f.Name, $stamp
  $rotPath = Join-Path $OutDir $rotName

  if ($PSCmdlet.ShouldProcess($f.FullName, "Rotate to $rotPath")) {
    # Never clear a source unless a verified copy or archive exists.
    Copy-Item -LiteralPath $f.FullName -Destination $rotPath -ErrorAction Stop
    $copiedHash = (Get-FileHash -LiteralPath $rotPath -Algorithm SHA256).Hash
    $currentHash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    if ($currentHash -ne $copiedHash) {
      Log "WARN source changed during copy; retained source and copy: $($f.Name)"
      continue
    }

    if ($Compress) {
      $zipPath = Join-Path $OutDir ($rotName + ".zip")
      try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        Compress-Archive -LiteralPath $rotPath -DestinationPath $zipPath -ErrorAction Stop
        $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
          if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].Length -ne $f.Length) {
            throw 'Unexpected archive contents or length.'
          }
          $entryStream = $zip.Entries[0].Open()
          $hasher = [Security.Cryptography.SHA256]::Create()
          try {
            $archiveHash = [BitConverter]::ToString($hasher.ComputeHash($entryStream)).Replace('-','')
          } finally {
            $hasher.Dispose()
            $entryStream.Dispose()
          }
          if ($archiveHash -ne $copiedHash) { throw 'Archive checksum mismatch.' }
        } finally {
          $zip.Dispose()
        }
        Remove-Item -LiteralPath $rotPath -Force -ErrorAction Stop
        Log "Verified archive: $($zipPath | Split-Path -Leaf)"
      } catch {
        Log "WARN compression/verification failed; original and copy retained: $($_.Exception.Message)"
        continue
      }
    }

    # Detect intervening writes; live logs that change during rotation are left intact.
    if ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -ne $copiedHash) {
      Log "WARN source changed during rotation; original retained: $($f.Name)"
      continue
    }
    Clear-Content -LiteralPath $f.FullName -ErrorAction Stop
    Log "Rotated: $($f.Name) -> $rotName"
  }
}

# Cleanup old archives / rotated files
$old = Get-ChildItem -LiteralPath $OutDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt $keepBefore -and ($_.Name -like "*.zip" -or $_.Name -like "*.rotated") }

foreach ($o in $old) {
  if ($PSCmdlet.ShouldProcess($o.FullName, "Delete old rotated file")) {
    Remove-Item -LiteralPath $o.FullName -Force
    Log "Deleted old: $($o.Name)"
  }
}

Log "Done."
