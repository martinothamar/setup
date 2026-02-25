## Setup arch on WSL 2

```pwsh
# Install wsl (admin powershell)
wsl --install
wsl --install archlinux
```

```pwsh
notepad.exe "$env:USERPROFILE/.wslconfig"
```

.wslconfig content (set based on hardware): 

```
[wsl2]
memory=48GB
swap=0
```

```pwsh
# Install PowerShell
winget install -e --id Microsoft.PowerShell
# Install VSCode
winget install -e --id Microsoft.VisualStudioCode
```

See VSCode setup in [vscode/README.md](/vscode/README.md)

```bash
# Set root passwd and add user
pacman -Syu sudo vim
passwd
useradd -m martin
usermod -aG martin martin
passwd martin
## Add group
EDITOR=vim visudo
```

Edit /etc/wsl.conf
```
[user]
default=martin
```

```pwsh
wsl --terminate archlinux
wsl --manage archlinux --set-default-user username
```

```bash
# Set locale (uncomment en_US)
vim /etc/locale.gen
sudo locale-gen
```

```bash
# Install basic tools
sudo pacman -Syu wget curl git github-cli
gh repo clone martinothamar/setup
```

Now you can run the install.sh script
