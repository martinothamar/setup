#!/bin/bash
# Sets up a Linux (Arch/CachyOS, including Arch in WSL) or macOS machine from this repository:
# installs chezmoi, then applies the dotfiles, packages and apps in home/.
#
# From a checkout:  ./bootstrap.sh
# Without one:      bash -c "$(curl -fsSL https://raw.githubusercontent.com/martinothamar/setup/main/bootstrap.sh)"
set -euo pipefail

case "$(uname -s)" in
  Darwin)
    if ! command -v brew >/dev/null; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    if [ "$(uname -m)" = arm64 ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    brew install chezmoi git
    ;;
  Linux)
    if ! command -v pacman >/dev/null; then
      echo "Only Arch-based Linux is supported." >&2
      exit 1
    fi
    sudo pacman -S --needed --noconfirm chezmoi git
    ;;
  *)
    echo "Unsupported OS: $(uname -s). On Windows, run bootstrap.ps1." >&2
    exit 1
    ;;
esac

checkout="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$checkout" ] && [ -f "$checkout/.chezmoiroot" ]; then
  chezmoi init --apply --source "$checkout"
else
  chezmoi init --apply martinothamar/setup
fi
