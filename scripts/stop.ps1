$ErrorActionPreference = "Stop"

$RuntimeDir = Join-Path ([System.IO.Path]::GetTempPath()) "codex-gateway-pool"
$PidFile = Join-Path $RuntimeDir "pid"

$pm2 = Get-Command pm2 -ErrorAction SilentlyContinue
if ($pm2) {
  try {
    pm2 stop codex-gateway-pool
  } catch { }
  exit 0
}

if (Test-Path $PidFile) {
  $pidValue = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
  if ($pidValue) {
    $existing = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
    if ($existing) {
      Stop-Process -Id $existing.Id -Force -ErrorAction SilentlyContinue
    }
  }
  Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}
