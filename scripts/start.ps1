$ErrorActionPreference = "Stop"

$RootDir = Split-Path $PSScriptRoot -Parent
$RuntimeDir = Join-Path ([System.IO.Path]::GetTempPath()) "codex-gateway-pool"
$PidFile = Join-Path $RuntimeDir "pid"
$StdoutLog = Join-Path $RuntimeDir "server.out.log"
$StderrLog = Join-Path $RuntimeDir "server.err.log"

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

$pm2 = Get-Command pm2 -ErrorAction SilentlyContinue
if ($pm2) {
  $hasProcess = $false
  try {
    pm2 describe codex-gateway-pool *> $null
    if ($LASTEXITCODE -eq 0) {
      $hasProcess = $true
    }
  } catch { }

  if ($hasProcess) {
    pm2 restart codex-gateway-pool --update-env
  } else {
    pm2 start server.js --name codex-gateway-pool --cwd $RootDir
  }
  exit 0
}

if (Test-Path $PidFile) {
  $oldPid = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
  if ($oldPid) {
    $existing = Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue
    if ($existing) {
      Stop-Process -Id $existing.Id -Force -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 1
    }
  }
}

$process = Start-Process `
  -FilePath "node" `
  -ArgumentList "server.js" `
  -WorkingDirectory $RootDir `
  -RedirectStandardOutput $StdoutLog `
  -RedirectStandardError $StderrLog `
  -WindowStyle Hidden `
  -PassThru

Start-Sleep -Seconds 1

if ($process.HasExited) {
  throw "Server exited immediately. Check $StdoutLog and $StderrLog."
}

Set-Content -Path $PidFile -Value $process.Id
Write-Output "Started PID $($process.Id)"
