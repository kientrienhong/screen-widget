<#
  Build & run Screen Widget on Windows, with live progress.

    powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1                debug build, then launch
    powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Release       release build, then open its folder
    powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Release -Zip  release build + build\ScreenWidget-windows.zip
    powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -SkipAnalyze

  Every step's full output goes to build\logs\<step>.log. The % shown for a
  step is estimated from how long that step took last time (first build: elapsed time only).
  Works in Windows PowerShell 5.1 and PowerShell 7.
#>
param([switch]$Release, [switch]$Zip, [switch]$SkipAnalyze)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$Mode = if ($Release) { 'release' } else { 'debug' }
$Config = if ($Release) { 'Release' } else { 'Debug' }
$LogDir = 'build\logs'
$TimesFile = 'build\.build_times.json'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$Times = @{}
if (Test-Path $TimesFile) {
  try { (Get-Content $TimesFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $Times[$_.Name] = [int]$_.Value } } catch {}
}

$Total = 6
$Spin = @('|', '/', '-', '\')
$BuildStart = Get-Date
$Activity = "Screen Widget - $Mode build"

function Format-Time([int]$s) { '{0:00}:{1:00}' -f [math]::Floor($s / 60), ($s % 60) }

function Write-Result([string]$tag, [string]$color, [int]$index, [string]$title, [string]$rest) {
  Write-Host -NoNewline ("`r" + (' ' * 100) + "`r")
  Write-Host -NoNewline ("  {0,-4} " -f $tag) -ForegroundColor $color
  Write-Host ("[{0}/{1}] {2,-20} {3}" -f $index, $Total, $title, $rest)
}

# Runs one step in the background and shows progress until it finishes.
function Invoke-Step([int]$Index, [string]$Key, [string]$Title, [string]$Command, [string]$Hint = '') {
  $log = Join-Path $LogDir "$Key.log"
  if (Test-Path $log) { Remove-Item $log -Force }
  $start = Get-Date
  $prev = if ($Times.ContainsKey($Key)) { $Times[$Key] } else { 0 }

  $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/d', '/c', "$Command > `"$log`" 2>&1" -NoNewWindow -PassThru
  $null = $p.Handle   # makes ExitCode available after the process ends
  $i = 0
  while (-not $p.HasExited) {
    $el = [int]((Get-Date) - $start).TotalSeconds
    $frac = 0.0; $pct = ''
    if ($prev -gt 0) { $frac = [math]::Min(0.99, $el / $prev); $pct = ' ~{0}%' -f [int]($frac * 100) }
    $line = ''
    try {
      $line = Get-Content $log -Tail 5 -ErrorAction SilentlyContinue | Where-Object { $_.Trim() } | Select-Object -Last 1
      if ($line) { $line = $line.Trim(); if ($line.Length -gt 60) { $line = $line.Substring(0, 60) } }
    } catch {}
    $overall = [int](((($Index - 1) + $frac) / $Total) * 100)
    Write-Progress -Activity $Activity -Status ('[{0}/{1}] {2}  {3}{4}' -f $Index, $Total, $Title, (Format-Time $el), $pct) -CurrentOperation $line -PercentComplete $overall
    $status = ("  {0}    [{1}/{2}] {3,-20} {4}{5}   {6}" -f $Spin[$i % 4], $Index, $Total, $Title, (Format-Time $el), $pct, $line)
    if ($status.Length -gt 99) { $status = $status.Substring(0, 99) }
    Write-Host -NoNewline ("`r" + $status.PadRight(99))
    $i++
    Start-Sleep -Milliseconds 250
  }
  $p.WaitForExit()
  $rc = $p.ExitCode
  $el = [int]((Get-Date) - $start).TotalSeconds

  if ($rc -eq 0) {
    $Times[$Key] = $el
    ($Times | ConvertTo-Json) | Set-Content $TimesFile
    Write-Result 'OK' 'Green' $Index $Title (Format-Time $el)
    return
  }

  Write-Progress -Activity $Activity -Completed
  Write-Result 'FAIL' 'Red' $Index $Title ("{0}  failed (exit {1})" -f (Format-Time $el), $rc)
  Write-Host ''
  Write-Host 'Last lines of the log:'
  Get-Content $log -Tail 40 | Where-Object { $_.Trim() } | Select-Object -Last 30 | ForEach-Object { Write-Host "  $_" }
  Write-Host ''
  if ($Hint) { Write-Host $Hint -ForegroundColor Yellow }
  Write-Host "Full log: $log"
  exit $rc
}

function Skip-Step([int]$Index, [string]$Title, [string]$Why) { Write-Result '-' 'DarkGray' $Index $Title $Why }

Write-Host ''
Write-Host "Screen Widget - Windows - $Mode build"
Write-Host ''

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host 'Flutter is not installed: https://docs.flutter.dev/get-started/install/windows' -ForegroundColor Red
  exit 1
}

Invoke-Step 1 'tools' 'Checking tools' 'flutter --version && flutter config --enable-windows-desktop'

if (Test-Path 'windows\runner') {
  Skip-Step 2 'Project setup' 'already set up'
} else {
  Invoke-Step 2 'setup' 'Project setup' 'powershell -NoProfile -ExecutionPolicy Bypass -File tool\setup_windows.ps1'
}

Invoke-Step 3 'packages' 'Getting packages' 'flutter pub get'

if ($SkipAnalyze) {
  Skip-Step 4 'Checking code' 'skipped'
} else {
  Invoke-Step 4 'analyze' 'Checking code' 'flutter analyze --no-fatal-infos --no-fatal-warnings'
}

# A running copy locks screen_widget.exe (the build would fail) and would keep
# showing the old version, so close it (and any pop-out windows) first.
$running = Get-Process -Name 'screen_widget' -ErrorAction SilentlyContinue
if ($running) {
  Write-Host '  Closing the running Screen Widget...' -ForegroundColor DarkGray
  $running | Stop-Process -Force
  Start-Sleep -Milliseconds 800
}

# Commit the build comes from (shown at the bottom of Settings); "+" = uncommitted changes.
$buildId = 'dev'
try {
  $sha = (git rev-parse --short HEAD 2>$null)
  if ($LASTEXITCODE -eq 0 -and $sha) {
    $buildId = $sha.Trim()
    git diff --quiet HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $buildId = "$buildId+" }
  }
} catch {}

Invoke-Step 5 "compile_$Mode" "Compiling ($Mode, $buildId)" "flutter build windows --$Mode --dart-define=BUILD_ID=$buildId" `
  'If the log mentions Visual Studio: install Visual Studio with the "Desktop development with C++" workload.'

$exe = Get-ChildItem -Path 'build\windows' -Recurse -Filter 'screen_widget.exe' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match "\\$Config\\" } | Select-Object -First 1
Write-Progress -Activity $Activity -Completed
if (-not $exe) {
  Write-Result 'FAIL' 'Red' 6 'Launching app' 'could not find screen_widget.exe under build\windows'
  exit 1
}
if ($Zip) {
  # The .exe needs the DLLs and data\ folder next to it, so ship the whole folder.
  $zipPath = 'build\ScreenWidget-windows.zip'
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
  Compress-Archive -Path (Join-Path $exe.DirectoryName '*') -DestinationPath $zipPath
  Write-Result 'OK' 'Green' 6 'Zipping app' $zipPath
}
if ($Release) {
  Start-Process explorer.exe -ArgumentList "/select,`"$($exe.FullName)`""
  Write-Result 'OK' 'Green' 6 'Opening folder' ''
} else {
  Start-Process $exe.FullName
  Write-Result 'OK' 'Green' 6 'Launching app' ''
}

$total = [int]((Get-Date) - $BuildStart).TotalSeconds
Write-Host ''
Write-Host ("Done in {0}  {1}" -f (Format-Time $total), $exe.FullName) -ForegroundColor Green
Write-Host 'Tip: for hot reload while editing, use: flutter run -d windows' -ForegroundColor DarkGray
