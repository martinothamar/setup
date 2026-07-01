#!/bin/bash

# CachyOS Dev Environment Setup Script
REPO="cachyos-extra-znver4"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMON_AI_TOOLS="${SCRIPT_DIR}/../common/ai/tools-config.sh"
if [ ! -f "$COMMON_AI_TOOLS" ]; then
  echo "Missing shared AI tools config: $COMMON_AI_TOOLS" >&2
  exit 1
fi
. "$COMMON_AI_TOOLS"

# Function to configure paru
configure_paru() {
  echo "========================================"
  echo "Configuring paru..."
  if grep -q "^#BottomUp" /etc/paru.conf; then
    sudo sed -i 's/^#BottomUp/BottomUp/' /etc/paru.conf
    echo "Enabled BottomUp in paru.conf"
  else
    echo "BottomUp already enabled or not found in paru.conf"
  fi
  echo "========================================"
}

# Function to update system packages
update_system() {
  echo "========================================"
  echo "Updating system packages..."
  paru -Syu --noconfirm --needed
  echo "========================================"
}

# Function to create bash_login
create_bash_login() {
  echo "========================================"
  echo "Creating bash_login file..."
  touch ~/.bash_login
  echo "========================================"
}

# Function to install base tools
base_tools() {
  echo "========================================"
  echo "Installing base tools..."
  paru -S --noconfirm --needed chromium
  echo "========================================"
}

# Function to install development tools
dev_tools() {
  echo "========================================"
  echo "Installing development tools..."

  # Define packages with their repositories (format: package:repo or just package for default repo)
  PACKAGES=(
    vim
    shellcheck
    ghostty
    fastfetch
    fzf
    github-cli
    lazygit
    tmux
    git-delta
    difftastic
    zoxide
    ripgrep
    eza
    fd
    bat
    poppler
    bubblewrap
    htop
    btop
    ncdu
    dive
    just
    hyperfine
    typst
    trippy
    gping
    step-cli
    nix:extra
    direnv
    # Install `agg` separately with: cargo install --git https://github.com/asciinema/agg
    asciinema
    # `agg` looks for JetBrains Mono first; install a supported monospace font for cast rendering.
    ttf-jetbrains-mono:extra
    # We don't use `code`, e.g. C# Dev Kit is only available in M$ version
    visual-studio-code-bin:aur
    tailscale
    docker
    docker-buildx
    docker-compose
    lazydocker
    kubectl:extra
    kubectx
    k9s
    neovim
    lua
    luarocks
    tree-sitter-cli
    wl-clipboard
    virglrenderer
    mise
    rustup
    uv
  )

  packages_to_install=()
  for package_entry in "${PACKAGES[@]}"; do
    # Parse package and repo (default to REPO if no override)
    if [[ "$package_entry" == *":"* ]]; then
      package="${package_entry%:*}"
      repo="${package_entry#*:}"
    else
      package="$package_entry"
      repo="$REPO"
    fi

    # Check if package is installed (use package name only, no repo prefix)
    if paru -Qi ${package} &>/dev/null; then
      # Package is installed, check if it needs updates
      if paru -Qu ${package} &>/dev/null; then
        # Package has updates available
        packages_to_install+=("${repo}/${package}")
      fi
      # If no updates available, skip silently
    else
      # Package is not installed
      packages_to_install+=("${repo}/${package}")
    fi
  done

  if [ ${#packages_to_install[@]} -gt 0 ]; then
    echo "Installing/updating packages: ${packages_to_install[*]}"
    paru -S --noconfirm --needed "${packages_to_install[@]}"
  else
    echo "All arch repo development tools are already installed and up-to-date"
  fi

  echo "----------------------------------------"
  echo "Installing dotnet"
  install_dotnet
  echo "----------------------------------------"

  echo "========================================"
}

# Function to install LazyVim
install_lazyvim() {
  echo "========================================"
  echo "Installing LazyVim..."
  if [ ! -d ~/.config/nvim ]; then
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
  else
    echo "LazyVim already installed, skipping..."
  fi
  echo "========================================"
}

# Function to configure LazyVim
configure_lazyvim() {
  echo "========================================"
  echo "Configuring LazyVim..."

  NVIM_DIR=~/.config/nvim
  if [ ! -d "$NVIM_DIR" ]; then
    echo "LazyVim is not installed at $NVIM_DIR, skipping..."
    echo "========================================"
    return 0
  fi

  PLUGINS_DIR="$NVIM_DIR/lua/plugins"
  CONFIG_FILE="$PLUGINS_DIR/setup-window-sizes.lua"
  MARKDOWN_LINT_CONFIG_FILE="$PLUGINS_DIR/setup-disable-markdown-lint.lua"
  MARKDOWN_RENDER_CONFIG_FILE="$PLUGINS_DIR/setup-disable-markdown-render.lua"
  OPTIONS_FILE="$NVIM_DIR/lua/config/options.lua"
  CLIPBOARD_CONFIG_START="-- === CachyOS Clipboard Config START ==="
  CLIPBOARD_CONFIG_END="-- === CachyOS Clipboard Config END ==="

  if ! mkdir -p "$PLUGINS_DIR"; then
    echo "Failed to create LazyVim plugins directory: $PLUGINS_DIR" >&2
    echo "========================================"
    return 1
  fi

  if ! cat >"$CONFIG_FILE" <<'EOF'; then
-- Generated by the setup installer.
-- Use full-size floating windows to minimize padding on smaller laptop screens.
return {
  {
    "folke/snacks.nvim",
    opts = {
      styles = {
        float = {
          width = 0,
          height = 0,
          row = 0,
          col = 0,
        },
        terminal = {
          width = 0,
          height = 0,
          row = 0,
          col = 0,
        },
        lazygit = {
          width = 0,
          height = 0,
          row = 0,
          col = 0,
        },
      },
      picker = {
        previewers = {
          git = {
            -- `git` preview commands accept context via config, not as a global `-U` flag.
            args = { "-c", "diff.context=999999" },
          },
        },
        sources = {
          -- Show dotfiles in file search, grep, and explorer.
          -- Gitignored files stay hidden (fd/rg default behavior).
          files = { hidden = true },
          grep = { hidden = true },
          explorer = { hidden = true },
          git_diff = {
            -- Default to file-level results instead of per-hunk entries, and request full context.
            group = true,
            cmd_args = { "-U999999" },
          },
        },
        layouts = {
          default = {
            layout = {
              width = 0,
              height = 0,
              row = 0,
              col = 0,
            },
          },
          vertical = {
            layout = {
              width = 0,
              height = 0,
              row = 0,
              col = 0,
            },
          },
        },
      },
    },
  },
}
EOF
    echo "Failed to write LazyVim configuration: $CONFIG_FILE" >&2
    echo "========================================"
    return 1
  fi

  echo "LazyVim window sizing configuration updated: $CONFIG_FILE"

  if ! cat >"$MARKDOWN_LINT_CONFIG_FILE" <<'EOF'; then
-- Generated by the setup installer.
-- Disable markdown linting, diagnostics, and spell squiggles in LazyVim.
local markdown_filetypes = { "markdown", "markdown.mdx", "mdx" }

local function remove_markdownlint(formatters)
  return vim.tbl_filter(function(formatter)
    return formatter ~= "markdownlint-cli2"
  end, formatters or {})
end

local function is_markdownlint_source(source)
  local name = source.name or (source._opts and source._opts.name)
  return name == "markdownlint" or name == "markdownlint_cli2" or name == "markdownlint-cli2"
end

return {
  {
    "LazyVim/LazyVim",
    init = function()
      local group = vim.api.nvim_create_augroup("setup_disable_markdown_diagnostics", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = markdown_filetypes,
        callback = function(args)
          vim.diagnostic.enable(false, { bufnr = args.buf })
          vim.opt_local.spell = false
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == args.buf then
                  vim.wo[win].spell = false
                end
              end
            end
          end)
        end,
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      for _, ft in ipairs(markdown_filetypes) do
        opts.formatters_by_ft[ft] = remove_markdownlint(opts.formatters_by_ft[ft])
      end
      if opts.formatters then
        opts.formatters["markdownlint-cli2"] = nil
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= "markdownlint-cli2"
      end, opts.ensure_installed or {})
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      opts.sources = vim.tbl_filter(function(source)
        return not is_markdownlint_source(source)
      end, opts.sources or {})
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      for _, ft in ipairs(markdown_filetypes) do
        opts.linters_by_ft[ft] = {}
      end
    end,
  },
}
EOF
    echo "Failed to write LazyVim markdown lint configuration: $MARKDOWN_LINT_CONFIG_FILE" >&2
    echo "========================================"
    return 1
  fi

  echo "LazyVim markdown lint configuration updated: $MARKDOWN_LINT_CONFIG_FILE"

  if ! cat >"$MARKDOWN_RENDER_CONFIG_FILE" <<'EOF'; then
-- Generated by the setup installer.
-- Keep render-markdown.nvim available, but start markdown buffers in raw text mode.
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      enabled = false,
    },
  },
}
EOF
    echo "Failed to write LazyVim markdown rendering configuration: $MARKDOWN_RENDER_CONFIG_FILE" >&2
    echo "========================================"
    return 1
  fi

  echo "LazyVim markdown rendering configuration updated: $MARKDOWN_RENDER_CONFIG_FILE"

  if [ ! -f "$OPTIONS_FILE" ]; then
    echo "Missing LazyVim options file: $OPTIONS_FILE" >&2
    echo "========================================"
    return 1
  fi

  if grep -Fq -- "$CLIPBOARD_CONFIG_START" "$OPTIONS_FILE"; then
    if ! sed -i "/$CLIPBOARD_CONFIG_START/,/$CLIPBOARD_CONFIG_END/d" "$OPTIONS_FILE"; then
      echo "Failed to update LazyVim clipboard configuration: $OPTIONS_FILE" >&2
      echo "========================================"
      return 1
    fi
  fi

  if ! cat >>"$OPTIONS_FILE" <<'EOF'; then

-- === CachyOS Clipboard Config START ===
-- Default all yanks/deletes/puts to the system clipboard when a Linux provider is present.
vim.opt.clipboard = "unnamedplus"

-- High-resolution wheels and touchpads can emit many events per gesture.
-- Disable the built-in wheel action and scroll one line on every second event.
vim.opt.mousescroll = "ver:0,hor:0"
do
  local pending_scroll = {
    up = 0,
    down = 0,
    left = 0,
    right = 0,
  }

  local function every_second(direction, keys)
    pending_scroll[direction] = pending_scroll[direction] + 1
    if pending_scroll[direction] < 2 then
      return ""
    end
    pending_scroll[direction] = 0
    return keys
  end

  vim.keymap.set({ "n", "v" }, "<ScrollWheelUp>", function()
    return every_second("up", "<C-Y>")
  end, { expr = true, silent = true, replace_keycodes = true })

  vim.keymap.set({ "n", "v" }, "<ScrollWheelDown>", function()
    return every_second("down", "<C-E>")
  end, { expr = true, silent = true, replace_keycodes = true })

  vim.keymap.set({ "n", "v" }, "<ScrollWheelLeft>", function()
    return every_second("left", "zh")
  end, { expr = true, silent = true, replace_keycodes = true })

  vim.keymap.set({ "n", "v" }, "<ScrollWheelRight>", function()
    return every_second("right", "zl")
  end, { expr = true, silent = true, replace_keycodes = true })

  vim.keymap.set("i", "<ScrollWheelUp>", function()
    return every_second("up", "<C-o><C-Y>")
  end, { expr = true, silent = true, replace_keycodes = true })

  vim.keymap.set("i", "<ScrollWheelDown>", function()
    return every_second("down", "<C-o><C-E>")
  end, { expr = true, silent = true, replace_keycodes = true })

  vim.keymap.set("i", "<ScrollWheelLeft>", function()
    return every_second("left", "<C-o>zh")
  end, { expr = true, silent = true, replace_keycodes = true })

  vim.keymap.set("i", "<ScrollWheelRight>", function()
    return every_second("right", "<C-o>zl")
  end, { expr = true, silent = true, replace_keycodes = true })
end
-- === CachyOS Clipboard Config END ===
EOF
    echo "Failed to write LazyVim clipboard configuration: $OPTIONS_FILE" >&2
    echo "========================================"
    return 1
  fi

  echo "LazyVim clipboard configuration updated: $OPTIONS_FILE"

  # Omnisharp reads config from ~/.omnisharp/omnisharp.json, not from LSP settings.
  # Both settings are required for .editorconfig diagnostic severity rules to work.
  OMNISHARP_DIR=~/.omnisharp
  OMNISHARP_JSON="$OMNISHARP_DIR/omnisharp.json"
  mkdir -p "$OMNISHARP_DIR"

  if ! cat >"$OMNISHARP_JSON" <<'EOF'; then
{
  "FormattingOptions": {
    "enableEditorConfigSupport": true
  },
  "RoslynExtensionsOptions": {
    "enableAnalyzersSupport": true
  }
}
EOF
    echo "Failed to write omnisharp configuration: $OMNISHARP_JSON" >&2
    echo "========================================"
    return 1
  fi

  echo "Omnisharp .editorconfig configuration updated: $OMNISHARP_JSON"
  echo "========================================"
}

# Function to configure bash
configure_bash() {
  echo "========================================"
  CONFIG_START="# === CachyOS Dev Setup Config START ==="
  CONFIG_END="# === CachyOS Dev Setup Config END ==="

  # Remove existing configuration if it exists
  if grep -q "$CONFIG_START" ~/.bashrc; then
    echo "Updating existing bash configuration..."
    # Use sed to remove everything between the markers
    sed -i "/$CONFIG_START/,/$CONFIG_END/d" ~/.bashrc
  else
    echo "Configuring bash aliases and tool activations..."
  fi

  # Add the configuration
  cat >>~/.bashrc <<EOF

$CONFIG_START
export EDITOR="vim"

# Local bin for user scripts
export PATH="\$HOME/.local/bin:\$PATH"
export PATH="\$HOME/.cargo/bin:\$PATH"

# Tool aliases
alias ls='eza -l --color=auto'
alias ff='fzf'
alias cat='bat'
alias n='nvim'
alias step='step-cli'
alias tree='ls -aR | grep ":$" | perl -pe "s/:$//;s/[^-][^\/]*\//    /g;s/^    (\S)/└── \1/;s/(^    |    (?= ))/│   /g;s/    (\S)/└── \1/"'

# Start or attach to tmux sessions for the current repo/directory.
_tw_session() {
  local suffix="\$1"
  shift

  local name="\${1:-\$(basename "\$PWD")}"
  name="\${name//[^A-Za-z0-9_.-]/-}"
  if [[ -n "\$suffix" ]]; then
    name="\${name}-\${suffix}"
  fi

  tmux new-session -A -s "\$name" -c "\$PWD"
}

tw() {
  _tw_session "" "\$@"
}

tw2() {
  _tw_session "2" "\$@"
}

tw3() {
  _tw_session "3" "\$@"
}

# Tool activations
eval "\$(zoxide init bash)"
eval "\$(mise activate bash)"
eval "\$(direnv hook bash)"

# Dotnet configuration
export PATH="\$PATH:\$HOME/.dotnet"
export PATH="\$PATH:\$HOME/.dotnet/tools"
export DOTNET_ROOT="\$HOME/.dotnet"
export DOTNET_TREATWARNINGSASERRORS="true"

# Build PS1 from scratch with SHLVL prefix and optional nix suffix
export PS1="[\$SHLVL:\u@\h \W]\\\\$ "

# Kubectl configuration
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k

# Krew configuration
export PATH="\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH"

if [[ -z \$ASCIINEMA_REC ]]; then
    fastfetch
fi
$CONFIG_END
EOF

  echo "Bash configuration updated. Run 'source ~/.bashrc' or restart your terminal to apply changes."
  echo "========================================"
}

# Function to configure desktop/server mode switch commands
configure_system_modes() {
  echo "========================================"
  echo "Configuring desktop/server mode commands..."

  mkdir -p ~/.local/bin

  cat >~/.local/bin/mode-status <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

show_active() {
  local unit="$1"
  local state
  state="$(systemctl is-active "$unit" 2>/dev/null || true)"
  printf "  %-24s %s\n" "$unit" "${state:-unknown}"
}

show_enabled() {
  local unit="$1"
  local state
  state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
  printf "  %-24s %s\n" "$unit" "${state:-unknown}"
}

echo "Default boot target: $(systemctl get-default)"
echo
echo "Active units:"
show_active graphical.target
show_active multi-user.target
show_active display-manager.service
show_active sshd.service
show_active tailscaled.service
show_active docker.service
echo
echo "Boot enablement:"
show_enabled display-manager.service
show_enabled sshd.service
show_enabled tailscaled.service
show_enabled docker.service
EOF

  cat >~/.local/bin/server-mode <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: server-mode [now|boot|both|status]

  now     Switch this boot to multi-user.target. This stops KDE/SDDM.
  boot    Boot into multi-user.target by default.
  both    Set multi-user.target as default and switch now.
  status  Show current target and service state.

Default: now
USAGE
}

action="${1:-now}"
case "$action" in
  now|switch)
    echo "Switching to server mode: multi-user.target"
    echo "This stops KDE/SDDM and local graphical applications. SSH and Tailscale stay under multi-user.target."
    sudo systemctl --no-block isolate multi-user.target
    ;;
  boot|default)
    sudo systemctl set-default multi-user.target
    ;;
  both)
    sudo systemctl set-default multi-user.target
    sudo systemctl --no-block isolate multi-user.target
    ;;
  status)
    mode-status
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
EOF

  cat >~/.local/bin/desktop-mode <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: desktop-mode [now|boot|both|status]

  now     Switch this boot to graphical.target and start SDDM/KDE login.
  boot    Boot into graphical.target by default.
  both    Set graphical.target as default and switch now.
  status  Show current target and service state.

Default: now
USAGE
}

action="${1:-now}"
case "$action" in
  now|switch)
    echo "Switching to desktop mode: graphical.target"
    sudo systemctl --no-block isolate graphical.target
    ;;
  boot|default)
    sudo systemctl set-default graphical.target
    ;;
  both)
    sudo systemctl set-default graphical.target
    sudo systemctl --no-block isolate graphical.target
    ;;
  status)
    mode-status
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
EOF

  chmod +x ~/.local/bin/mode-status ~/.local/bin/server-mode ~/.local/bin/desktop-mode

  echo "Mode commands installed: server-mode, desktop-mode, mode-status"
  echo "========================================"
}

# Function to configure tmux
configure_tmux() {
  echo "========================================"
  echo "Configuring tmux..."

  cat >~/.tmux.conf <<'EOF'
set -g mouse on
set -g history-limit 100000
setw -g mode-keys vi
EOF

  echo "tmux configuration updated: ~/.tmux.conf"
  echo "========================================"
}

# Function to configure Tailscale
configure_tailscale() {
  echo "========================================"
  echo "Configuring Tailscale..."

  sudo systemctl enable --now tailscaled

  sudo install -d -m 0755 /etc/sysctl.d
  cat <<'EOF' | sudo tee /etc/sysctl.d/99-tailscale-routing.conf >/dev/null
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
  sudo sysctl -p /etc/sysctl.d/99-tailscale-routing.conf

  sleep 1

  if sudo tailscale status --peers=false >/dev/null 2>&1; then
    echo "Tailscale is already connected."
  else
    tailscale_up_args=()
    if [ -n "${SETUP_TAILSCALE_AUTHKEY:-}" ]; then
      tailscale_up_args+=(--auth-key "$SETUP_TAILSCALE_AUTHKEY")
    fi
    sudo tailscale up "${tailscale_up_args[@]}"
  fi

  if [ -n "${SETUP_TAILSCALE_HOSTNAME:-}" ]; then
    sudo tailscale set --hostname "$SETUP_TAILSCALE_HOSTNAME"
  fi
  if [ -n "${SETUP_TAILSCALE_ACCEPT_DNS:-}" ]; then
    sudo tailscale set --accept-dns "$SETUP_TAILSCALE_ACCEPT_DNS"
  fi
  if [ "${SETUP_TAILSCALE_ADVERTISE_EXIT_NODE:-true}" = "true" ]; then
    sudo tailscale set --advertise-exit-node
    echo "Tailscale is advertising this machine as an exit node."
    echo "Approve it in the Tailscale admin console before clients can use it."
  fi

  echo "Tailscale configuration complete!"
  echo "========================================"
}

# Function to install RustDesk
install_rustdesk() {
  echo "========================================"
  echo "Installing RustDesk..."

  # Check if RustDesk is already installed
  if paru -Qi rustdesk &>/dev/null; then
    echo "RustDesk already installed, skipping..."
    echo "========================================"
    return
  fi

  # Create temporary directory
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"

  # Get latest release info from GitHub API
  echo "Fetching latest RustDesk release..."
  LATEST_VERSION=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')

  if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch latest version for rustdesk" >&2
    exit 1
  fi

  PACKAGE_NAME="rustdesk-${LATEST_VERSION}-0-x86_64.pkg.tar.zst"
  DOWNLOAD_URL="https://github.com/rustdesk/rustdesk/releases/download/${LATEST_VERSION}/${PACKAGE_NAME}"

  echo "Downloading RustDesk ${LATEST_VERSION}..."
  if curl -L -o "$PACKAGE_NAME" "$DOWNLOAD_URL"; then
    echo "Installing RustDesk package..."
    paru -U --noconfirm "./$PACKAGE_NAME"
    echo "RustDesk installation completed"
  else
    echo "Failed to download RustDesk package"
    return 1
  fi

  # Clean up
  cd - &>/dev/null
  rm -rf "$TEMP_DIR"

  echo "Rustdesk installed!"
  echo "Remember, we need to set a master password and enable direct IP access to use within tailscale"
  echo "========================================"
}

# Function to configure SSH server
configure_sshd() {
  echo "========================================"
  echo "Configuring SSH server..."

  # Install openssh if not present
  if ! paru -Qi openssh &>/dev/null; then
    paru -S --noconfirm --needed openssh
  fi

  # Enable and start sshd
  sudo systemctl enable --now sshd.service

  echo "SSH server configured and running!"
  echo "========================================"
}

# Function to configure Docker
configure_docker() {
  echo "========================================"
  echo "Configuring Docker..."

  echo "Starting and enabling Docker service..."
  sudo systemctl start docker.service
  sudo systemctl enable docker.service

  echo "Adding current user to docker group..."
  sudo usermod -aG docker $USER

  echo "Docker configuration complete!"
  echo "Note: You may need to log out and back in for group changes to take effect."
  echo "========================================"
}

# Function to configure Nix
configure_nix() {
  echo "========================================"
  echo "Configuring Nix..."

  # Create nix config directory if it doesn't exist
  if [ ! -d ~/.config/nix ]; then
    echo "Creating nix config directory..."
    mkdir -p ~/.config/nix
  else
    echo "Nix config directory already exists"
  fi

  # Configure nix experimental features
  NIX_CONF=~/.config/nix/nix.conf
  if [ ! -f "$NIX_CONF" ] || ! grep -q "experimental-features = nix-command flakes" "$NIX_CONF"; then
    echo "Enabling nix experimental features (nix-command and flakes)..."
    echo "experimental-features = nix-command flakes" >"$NIX_CONF"
  else
    echo "Nix experimental features already configured"
  fi

  # Enable and start nix-daemon service
  echo "Enabling and starting nix-daemon service..."
  sudo systemctl enable --now nix-daemon.service

  echo "Nix configuration complete!"
  echo "========================================"
}

# Function to configure lazygit
configure_lazygit() {
  echo "========================================"
  echo "Configuring lazygit..."

  # Create lazygit config directory if it doesn't exist
  if [ ! -d ~/.config/lazygit ]; then
    echo "Creating lazygit config directory..."
    mkdir -p ~/.config/lazygit
  else
    echo "Lazygit config directory already exists"
  fi

  CONFIG_FILE=~/.config/lazygit/config.yml
  CONFIG_START="# === LazyGit Config START ==="
  CONFIG_END="# === LazyGit Config END ==="

  # Remove existing configuration if it exists
  if [ -f "$CONFIG_FILE" ] && grep -q "$CONFIG_START" "$CONFIG_FILE"; then
    echo "Updating existing lazygit configuration..."
    # Use sed to remove everything between the markers
    sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$CONFIG_FILE"
  else
    echo "Adding lazygit configuration..."
    # Create the file if it doesn't exist
    touch "$CONFIG_FILE"
  fi

  # Add the configuration
  cat >>"$CONFIG_FILE" <<EOF
$CONFIG_START
git:
  diffContextSize: 20
  pagers:
    - colorArg: always
      pager: delta --dark --paging=never --line-numbers-left-format="" --line-numbers-right-format=""
  ignoreWhitespaceInDiffView: true
$CONFIG_END
EOF

  echo "Lazygit configuration complete!"
  echo "========================================"
}

# Function to configure k9s
configure_k9s() {
  echo "========================================"
  echo "Configuring k9s..."

  # Create k9s config directory if it doesn't exist
  mkdir -p ~/.config/k9s

  # Custom flux plugin - single Shift-R for reconcile with --with-source
  cat >~/.config/k9s/plugins.yaml <<'EOF'
plugins:
  reconcile-hr:
    shortCut: Shift-R
    confirm: false
    description: Flux reconcile --with-source
    scopes:
      - helmreleases
    command: bash
    background: false
    args:
      - -c
      - flux reconcile helmrelease --context $CONTEXT -n $NAMESPACE $NAME --with-source | less -K
  reconcile-ks:
    shortCut: Shift-R
    confirm: false
    description: Flux reconcile --with-source
    scopes:
      - kustomizations
    command: bash
    background: false
    args:
      - -c
      - flux reconcile kustomization --context $CONTEXT -n $NAMESPACE $NAME --with-source | less -K
EOF

  echo "k9s configuration complete!"
  echo "========================================"
}

# Function to install kubectl krew
install_krew() {
  echo "========================================"
  echo "Installing kubectl krew..."

  if [ -d "${KREW_ROOT:-$HOME/.krew}" ] && command -v kubectl-krew &>/dev/null; then
    echo "krew already installed, skipping..."
    echo "========================================"
    return
  fi

  (
    set -x
    cd "$(mktemp -d)" &&
      OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
      ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
      KREW="krew-${OS}_${ARCH}" &&
      curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
      tar zxvf "${KREW}.tar.gz" &&
      ./"${KREW}" install krew
  )

  echo "krew installation complete!"
  echo "========================================"
}

# Function to install dotnet
install_dotnet() {
  echo "========================================"
  echo "Installing dotnet..."

  # Download installer
  echo "Downloading dotnet installer..."
  curl -L https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
  chmod +x /tmp/dotnet-install.sh

  # Install dotnet 8.0
  echo "Installing dotnet 8.0..."
  if /tmp/dotnet-install.sh --channel 8.0 --version latest | grep -q "is already installed"; then
    echo "dotnet 8.0 is already installed"
  else
    echo "dotnet 8.0 installed"
  fi

  # Install dotnet 9.0
  echo "Installing dotnet 9.0..."
  if /tmp/dotnet-install.sh --channel 9.0 --version latest | grep -q "is already installed"; then
    echo "dotnet 9.0 is already installed"
  else
    echo "dotnet 9.0 installed"
  fi

  # Install dotnet 10.0
  echo "Installing dotnet 10.0..."
  if /tmp/dotnet-install.sh --channel 10.0 --version latest | grep -q "is already installed"; then
    echo "dotnet 10.0 is already installed"
  else
    echo "dotnet 10.0 installed"
  fi

  echo "dotnet installation complete!"
  echo "========================================"
}

# Function to configure tools
configure_tools() {
  echo "========================================"
  echo "Configuring tools..."

  echo "----------------------------------------"
  echo "Configuring Docker"
  configure_docker
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring Nix"
  configure_nix
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring LazyGit"
  configure_lazygit
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring k9s"
  configure_k9s
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring tmux"
  configure_tmux
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Installing kubectl krew"
  install_krew
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring and connecting to Tailscale"
  configure_tailscale
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring SSH server"
  configure_sshd
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring desktop/server mode commands"
  configure_system_modes
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring LazyVim window sizes"
  configure_lazyvim
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring mise and installing default stable/LTS dev tools"
  mise use -g node@lts
  mise use -g bun@latest
  mise use -g go@1.25
  mise use -g zig@0.14
  mise use -g zls@0.14

  # Not available from builtin arch repos
  go install sigs.k8s.io/kind@latest
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring rustup"
  rustup self upgrade-data
  rustup update stable
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring git and github-cli"
  git config --global user.name "Martin Othamar"
  git config --global user.email "martin@othamar.net"
  git config --global init.defaultBranch main
  git config --global push.autoSetupRemote true
  git config --global rebase.updateRefs true
  gh auth login
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Installing/updating AI tools"
  install_ai_tools
  echo "----------------------------------------"

  echo "----------------------------------------"
  echo "Configuring Claude"
  configure_claude
  echo "----------------------------------------"
  echo "----------------------------------------"
  echo "Configuring Codex"
  configure_codex
  echo "----------------------------------------"
  echo "----------------------------------------"
  echo "Configuring OpenCode"
  configure_opencode
  echo "----------------------------------------"
  echo "----------------------------------------"
  echo "Configuring Copilot"
  configure_copilot
  echo "----------------------------------------"
  echo "----------------------------------------"
  echo "Configuring Pi"
  configure_pi
  echo "----------------------------------------"
  echo "========================================"
}

# Main installation function
install_all() {
  echo "Setting up development environment on CachyOS..."
  configure_paru
  update_system
  create_bash_login
  base_tools
  dev_tools
  install_lazyvim
  install_rustdesk
  configure_bash
  configure_tools
  echo "Development environment setup complete!"
}

# Run full installation by default, or call specific functions for testing
if [ $# -eq 0 ]; then
  install_all
else
  # Allow calling specific functions for testing
  "$@"
fi
