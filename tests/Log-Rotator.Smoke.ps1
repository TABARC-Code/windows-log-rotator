$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('log-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
  $file = Join-Path $root 'test.log'
  'archive verification example' | Set-Content -LiteralPath $file
  & (Join-Path $PSScriptRoot '..\Rotate-Logs.ps1') -Path $root -Pattern 'test.log' -MaxSizeMB 0 -Compress | Out-Null
  if ((Get-Item -LiteralPath $file).Length -ne 0) { throw 'Source was not cleared after verification.' }
  $zips = @(Get-ChildItem -LiteralPath (Join-Path $root 'out') -Filter '*.zip' -File)
  if ($zips.Count -ne 1) { throw 'Expected one verified ZIP.' }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($zips[0].FullName)
  try { if ($archive.Entries.Count -ne 1 -or $archive.Entries[0].Length -le 0) { throw 'Archive invalid.' } }
  finally { $archive.Dispose() }
  Write-Host 'Log Rotator test passed.'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
