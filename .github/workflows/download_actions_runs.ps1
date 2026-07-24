$ErrorActionPreference = "Stop"

$Repo = "BailinT/GKI_KernelSU_SUSFS"
$Runs = @(
  "27146189220",
  "27146184567",
  "27146179443",
  "27146176406",
  "27145984198"
)

$RootDir = "E:\GKI_Actions_Downloads"
$BaseDir = Join-Path $RootDir (Get-Date -Format "yyyyMMdd_HHmmss")

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host "GitHub CLI not found. Installing..."
  winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host "GitHub CLI was installed, but this PowerShell window cannot see it yet."
  Write-Host "Open a new PowerShell window and run this script again."
  exit 1
}

$OldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& gh auth status *> $null
$AuthExitCode = $LASTEXITCODE
$ErrorActionPreference = $OldErrorActionPreference

if ($AuthExitCode -ne 0) {
  Write-Host "Please log in to GitHub when prompted."
  & gh auth login
  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "GitHub login failed. Please log in first, then run this script again."
    Write-Host "Browser login command:"
    Write-Host "  gh auth login --hostname github.com --web"
    Write-Host ""
    Write-Host "Token login command:"
    Write-Host "  gh auth login --hostname github.com --with-token"
    exit 1
  }

  $ErrorActionPreference = "SilentlyContinue"
  & gh auth status *> $null
  $AuthExitCode = $LASTEXITCODE
  $ErrorActionPreference = $OldErrorActionPreference
  if ($AuthExitCode -ne 0) {
    Write-Host "GitHub login was not completed. Please run gh auth login and try again."
    exit 1
  }
}

New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null

foreach ($Run in $Runs) {
  $RunDir = Join-Path $BaseDir $Run
  New-Item -ItemType Directory -Path $RunDir -Force | Out-Null

  Write-Host "Downloading artifacts for run $Run..."
  & gh run download $Run -R $Repo -D $RunDir

  Write-Host "Saving log for run $Run..."
  & gh run view $Run -R $Repo --log | Out-File -FilePath (Join-Path $RunDir "run.log") -Encoding utf8
}

Write-Host "Done."
Write-Host $BaseDir
