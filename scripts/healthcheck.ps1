$ErrorActionPreference = "Stop"

$RootDir = Split-Path $PSScriptRoot -Parent
$SettingsPath = Join-Path $RootDir "settings.json"
$Port = 8787

if (Test-Path $SettingsPath) {
  try {
    $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    if ($settings.port) {
      $Port = [int]$settings.port
    }
  } catch { }
}

$response = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/health" -TimeoutSec 5
$response | ConvertTo-Json -Depth 10
