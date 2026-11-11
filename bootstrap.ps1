# Sets up a Windows machine from this repository: the Windows features agentctl and WSL need,
# chezmoi and everything in home/, then Arch in WSL with its own bootstrap.sh run.
#
# irm https://raw.githubusercontent.com/martinothamar/setup/main/bootstrap.ps1 | iex
$ErrorActionPreference = 'Stop'
$raw = 'https://raw.githubusercontent.com/martinothamar/setup/main'

function Update-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

# 1. Windows features, as administrator: HypervisorPlatform for agentctl's sandboxes, and WSL.
Write-Host 'Enabling HypervisorPlatform and WSL (administrator prompt)...'
$features = @'
$r = Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart
wsl.exe --install --no-distribution
if ($r.RestartNeeded) { exit 3010 }
'@
$elevated = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $features)
wsl.exe --status *> $null
if ($elevated.ExitCode -eq 3010 -or $LASTEXITCODE -ne 0) {
    Write-Host 'Restart Windows, then run this script again.'
    return
}

# 2. chezmoi, then home/: packages, agentctl, the t3code fork, VS Code and git config.
winget install --id twpayne.chezmoi --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
winget install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
Update-Path
chezmoi init --apply martinothamar/setup
if ($LASTEXITCODE -ne 0) { throw "chezmoi exited $LASTEXITCODE" }

# 3. Arch in WSL, for the work tools (Azure CLI).
$distro = 'archlinux'
if (-not ((wsl.exe --list --quiet) -replace "`0", '' | Where-Object { $_.Trim() -eq $distro })) {
    wsl.exe --install $distro --no-launch
}
# A distribution whose default user is still root has not been set up, or its setup was cut short:
# arch-init.sh makes the user WSL's default as its last step. A set-up one keeps its users.
if ((wsl.exe -d $distro -- id -u) -eq '0') {
    # A Linux user name has no spaces or capitals: "Martin Othamar" becomes "martinothamar".
    $user = ($env:USERNAME -replace '[^A-Za-z0-9_-]', '').ToLower()
    wsl.exe -d $distro -u root -- curl -fsSL -o /root/arch-init.sh "$raw/wsl/arch-init.sh"
    wsl.exe -d $distro -u root -- bash /root/arch-init.sh $user
    if ($LASTEXITCODE -ne 0) { throw "arch-init.sh exited $LASTEXITCODE" }
    wsl.exe --terminate $distro
}
wsl.exe -d $distro -- curl -fsSL -o /tmp/bootstrap.sh "$raw/bootstrap.sh"
wsl.exe -d $distro -- bash /tmp/bootstrap.sh
if ($LASTEXITCODE -ne 0) { throw "bootstrap.sh in WSL exited $LASTEXITCODE" }

Write-Host 'Done. Sign in to Tailscale from its tray icon if this machine is new.'
