#!/bin/bash 

# CachyOS Dev Environment Setup Script
REPO="cachyos-extra-znver4"

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
    # This was needed for `bob` to work, probably a bug there
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
        ghostty
        fzf
        github-cli
        zoxide
        ripgrep
        eza
        fd
        bat
        htop
        just
        hyperfine
        typst
        trippy
        gping
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
        bob
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
    cat >> ~/.bashrc << EOF

$CONFIG_START
# Tool aliases
alias ls='eza -l --color=auto'
alias ff='fzf'
alias cat='bat'
alias n='nvim'
alias tree='ls -aR | grep ":$" | perl -pe "s/:$//;s/[^-][^\/]*\//    /g;s/^    (\S)/└── \1/;s/(^    |    (?= ))/│   /g;s/    (\S)/└── \1/"'

# Tool activations
eval "\$(zoxide init bash)"
eval "\$(mise activate bash)"

# Dotnet configuration
export PATH="\$PATH:\$HOME/.dotnet"
export PATH="\$PATH:\$HOME/.dotnet/tools"
export DOTNET_ROOT="\$HOME/.dotnet"

# Kubectl configuration
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
$CONFIG_END
EOF
    
    echo "Bash configuration updated. Run 'source ~/.bashrc' or restart your terminal to apply changes."
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
    echo "Configuring and connecting to Tailscale"
    sudo systemctl enable --now tailscaled
    sleep 1
    sudo tailscale up
    echo "----------------------------------------"

    echo "----------------------------------------"
    echo "Configuring nvim using bob"
    bob use stable
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
    gh auth login
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
