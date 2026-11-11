# setup

My machines' configuration, applied with [chezmoi](https://www.chezmoi.io/). Development happens in
[agentctl](https://github.com/digdir/digdir-agents) sandboxes, so the hosts mostly need a terminal,
VS Code, Tailscale, agentctl and my [t3code fork](https://github.com/martinothamar/t3code), plus the
Go, Rust and .NET toolchains on the desktops.

| Machine | Packages | Gets |
| --- | --- | --- |
| CachyOS/Arch | paru | Ghostty, VS Code, Tailscale, agentctl, t3code, bash, git, Go, rustup, dotnetup |
| macOS | Homebrew | Ghostty, VS Code, Tailscale, agentctl, t3code, bash (as login shell), git, Go, rustup, dotnetup |
| Windows | winget | Windows Terminal, VS Code, Tailscale, agentctl, t3code, git, Arch in WSL |
| Arch in WSL | pacman | Azure CLI with separate dev/prod logins ([multiaz](home/dot_config/bash/multiaz.sh)), bash, git |

The previous setup (Ansible, per-distro install scripts, AI tool config) is on the
`backup/pre-pivot-2026-11-11` branch.

## New machine

Linux or macOS:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/martinothamar/setup/main/bootstrap.sh)"
```

Windows, in PowerShell (it asks for administrator rights once, and to restart if a Windows feature
was enabled; run it again after the restart):

```powershell
irm https://raw.githubusercontent.com/martinothamar/setup/main/bootstrap.ps1 | iex
```

From an existing checkout, `./bootstrap.sh` uses that checkout as chezmoi's source.

## Keeping machines in sync

```sh
chezmoi update        # pull this repo and apply it
chezmoi status        # what differs between this machine and the repo
chezmoi diff          # the same, as a diff
chezmoi re-add        # take local edits to managed files back into the repo
chezmoi cd            # open a shell in the repo to commit and push
```

`chezmoi apply` also runs the scripts in [`home/.chezmoiscripts`](home/.chezmoiscripts):

- the package install, when [`packages.yaml`](home/.chezmoidata/packages.yaml) changes;
- the t3code fork's installer, when the fork publishes a new release;
- the VS Code extension install, when the extension list changes;
- agentctl's installer, Tailscale's daemon setup, the default Rust toolchain and dotnetup with the latest .NET SDK, once per machine.

Removing a package from the list does not uninstall it.

VS Code's `settings.json` and `keybindings.json` are templates, because they live in a different
place on each OS, so `chezmoi re-add` skips them. Copy changes made in VS Code into
[`home/.chezmoitemplates/vscode/`](home/.chezmoitemplates/vscode/).

Put machine-specific shell setup in `~/.bashrc.local`. It is sourced last and is not managed.

## Personal agents

agentctl reads personal agent definitions from `~/agents/<name>/`. To sync one across machines, run
`chezmoi add ~/agents/<name>`. Logins and secrets stay in agentctl (`agentctl claude login`,
`agentctl secret set`), never in this repo, which is public.
