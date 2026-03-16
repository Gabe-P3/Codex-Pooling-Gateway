$ErrorActionPreference = "Stop"

function Read-DefaultValue {
  param(
    [string]$Prompt,
    [string]$DefaultValue
  )

  $value = Read-Host "$Prompt [$DefaultValue]"
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $DefaultValue
  }
  return $value.Trim()
}

function Read-RequiredSecret {
  param([string]$Prompt)

  while ($true) {
    $secure = Read-Host $Prompt -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
      $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
    } finally {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }

    if (-not [string]::IsNullOrWhiteSpace($plain)) {
      return $plain
    }

    Write-Host "Password cannot be empty."
  }
}

function New-HexSecret {
  param([int]$ByteCount = 32)

  $bytes = New-Object byte[] $ByteCount
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  return ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

Write-Host "== Codex Gateway Pool Installer =="
Write-Host ""

$panelPort = [int](Read-DefaultValue -Prompt "Panel port" -DefaultValue "8787")
$adminUsername = Read-DefaultValue -Prompt "Admin username" -DefaultValue "admin"
$adminPassword = Read-RequiredSecret -Prompt "Admin password (required)"
$apiKeyPrefix = Read-DefaultValue -Prompt "Normal API key prefix" -DefaultValue "rneo_codex_"
$masterKeyPrefix = Read-DefaultValue -Prompt "Master API key prefix" -DefaultValue "rneo_master_"
$encryptionSecret = New-HexSecret

$codexHomeRoot = Join-Path $RootDir "data\openai_codex"
New-Item -ItemType Directory -Force -Path $codexHomeRoot | Out-Null

$settings = [ordered]@{
  host = "0.0.0.0"
  port = $panelPort
  httpsEnabled = $false
  dashboardAuthEnabled = $true
  adminUsername = $adminUsername
  adminPassword = $adminPassword
  openaiApiKeyPrefix = $apiKeyPrefix
  openaiMasterKeyPrefix = $masterKeyPrefix
  openaiKeyEncryptionSecret = $encryptionSecret
  openaiCodexTimeoutMs = 120000
  openaiRateLimitCacheTtlMs = 60000
  openaiPromptMaxLen = 49152
  dashboardSessionTtlMs = 2592000000
  openaiPortalSessionTtlMs = 2592000000
  maxSessions = 5000
  codexHomeRoot = $codexHomeRoot
}

$settings | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $RootDir "settings.json")

$statePath = Join-Path $RootDir "data\state.json"
if (-not (Test-Path $statePath)) {
  $state = [ordered]@{
    revision = 1
    users = @{}
    specialMasterKey = [ordered]@{
      keySalt = ""
      keyHash = ""
      keyMask = ""
      keyLabel = ""
      keyCipher = ""
      keyIv = ""
      keyTag = ""
      createdAt = 0
      updatedAt = 0
    }
  }

  $state | ConvertTo-Json -Depth 10 | Set-Content -Path $statePath
}

Write-Host ""
Write-Host "Installing npm dependencies..."
npm install

Write-Host "Checking server syntax..."
node --check server.js

Write-Host ""
Write-Host "Starting server..."
& (Join-Path $RootDir "scripts\start.ps1")

$serverIp = "127.0.0.1"
try {
  $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
    Select-Object -First 1 -ExpandProperty IPAddress
  if ($ip) {
    $serverIp = $ip
  }
} catch { }

Write-Host ""
Write-Host "== Install Complete =="
Write-Host "Admin panel:  http://$serverIp`:$panelPort/"
Write-Host "Portal page:  http://$serverIp`:$panelPort/openai"
Write-Host "Admin login:  $adminUsername"
Write-Host ""
Write-Host "If you use a firewall, allow TCP port $panelPort."
