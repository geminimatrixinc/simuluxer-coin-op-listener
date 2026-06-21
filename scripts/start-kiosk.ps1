param(
  [string]$AppRoot = (Split-Path -Parent $PSScriptRoot),
  [int]$Port = 3000,
  [string]$BrowserPath = ""
)

$ErrorActionPreference = "Stop"

function Test-ServerReady {
  param([int]$TargetPort)

  try {
    Invoke-WebRequest -Uri "http://localhost:$TargetPort/api/session/latest" -UseBasicParsing -TimeoutSec 2 | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Resolve-BrowserPath {
  param([string]$PreferredPath)

  if ($PreferredPath -and (Test-Path $PreferredPath)) {
    return $PreferredPath
  }

  $candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  return ""
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "Node.js is not installed or not on PATH."
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw "npm is not installed or not on PATH."
}

if (-not (Test-Path $AppRoot)) {
  throw "AppRoot path not found: $AppRoot"
}

Set-Location $AppRoot

if (-not (Test-Path (Join-Path $AppRoot "node_modules"))) {
  Write-Host "Installing dependencies..."
  npm install
}

$serverReady = Test-ServerReady -TargetPort $Port

if (-not $serverReady) {
  Write-Host "Starting local kiosk server on port $Port..."
  $serverCommand = "Set-Location '$AppRoot'; npm start"
  Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $serverCommand -WindowStyle Hidden | Out-Null

  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    if (Test-ServerReady -TargetPort $Port) {
      $serverReady = $true
      break
    }
  }
}

if (-not $serverReady) {
  throw "Server did not become ready at http://localhost:$Port"
}

$kioskUrl = "http://localhost:$Port"
$browserExe = Resolve-BrowserPath -PreferredPath $BrowserPath

Write-Host "Opening kiosk URL: $kioskUrl"

if ($browserExe) {
  Start-Process -FilePath $browserExe -ArgumentList "--kiosk", "--new-window", $kioskUrl | Out-Null
} else {
  Start-Process $kioskUrl | Out-Null
}

Write-Host "Kiosk startup complete."
