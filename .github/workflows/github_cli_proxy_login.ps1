$ErrorActionPreference = "Stop"

$ProxyPorts = @(
  7890, 7897, 10809, 10808, 20171, 2080, 8080
)

$FoundProxy = $null

foreach ($Port in $ProxyPorts) {
  $ok = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet
  if ($ok) {
    $FoundProxy = "http://127.0.0.1:$Port"
    break
  }
}

if ($FoundProxy) {
  Write-Host "Using proxy: $FoundProxy"
  $env:HTTP_PROXY = $FoundProxy
  $env:HTTPS_PROXY = $FoundProxy
  $env:NO_PROXY = "localhost,127.0.0.1"
} else {
  Write-Host "No common local proxy port was detected."
  Write-Host "If you use Clash/v2rayN/etc, enable system proxy or edit this script with your proxy port."
}

Write-Host "Testing GitHub connection..."
try {
  Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 20 | Out-Null
  Write-Host "GitHub connection OK."
} catch {
  Write-Host "GitHub connection still failed:"
  Write-Host $_.Exception.Message
  Write-Host ""
  Write-Host "Please enable proxy/VPN first, then run this script again."
  exit 1
}

Write-Host "Starting GitHub CLI login..."
& gh auth login --hostname github.com --web
