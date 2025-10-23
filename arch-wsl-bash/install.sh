#!/bin/bash

REPO="extra"

# Function to update system packages
update_system() {
    echo "========================================"
    echo "Updating system packages..."
    sudo pacman -Syu --noconfirm --needed
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

# Function to install development tools
dev_tools() {
    echo "========================================"
    echo "Installing development tools..."
    
    # Define packages with their repositories (format: package:repo or just package for default repo)
    PACKAGES=(
        vim
        fastfetch
        fzf
        github-cli
        zoxide
        ripgrep
        eza
        fd
        bat
        less:core
        which:core
        make:core
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
        nix
        direnv
        docker
        docker-buildx
        docker-compose
        lazydocker
        jq
        yq
        kubectl
        kubectx
        helm
        fluxcd
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
        if sudo pacman -Qi ${package} &>/dev/null; then
            # Package is installed, check if it needs updates
            if sudo pacman -Qu ${package} &>/dev/null; then
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
        sudo pacman -S --noconfirm --needed "${packages_to_install[@]}"
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
    CONFIG_START="# === Arch Dev Setup Config START ==="
    CONFIG_END="# === Arch Dev Setup Config END ==="
    
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
export EDITOR="vim"

# Tool aliases
alias ls='eza -l --color=auto'
alias ff='fzf'
alias cat='bat'
alias n='nvim'
alias step='step-cli'
alias tree='ls -aR | grep ":$" | perl -pe "s/:$//;s/[^-][^\/]*\//    /g;s/^    (\S)/└── \1/;s/(^    |    (?= ))/│   /g;s/    (\S)/└── \1/"'

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

fastfetch
$CONFIG_END
EOF
    
    echo "Bash configuration updated. Run 'source ~/.bashrc' or restart your terminal to apply changes."
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
        echo "experimental-features = nix-command flakes" > "$NIX_CONF"
    else
        echo "Nix experimental features already configured"
    fi

    # Enable and start nix-daemon service
    echo "Enabling and starting nix-daemon service..."
    sudo systemctl enable --now nix-daemon.service

    echo "Nix configuration complete!"
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
    echo "Configuring git"
    git config --global user.name "Martin Othamar"
    git config --global user.email "martin@othamar.net"
    git config --global init.defaultBranch main
    git config --global push.autoSetupRemote true
    echo "----------------------------------------"
    echo "========================================"
}

# Main installation function
install_all() {
    echo "Setting up development environment on CachyOS..."
    update_system
    create_bash_login
    dev_tools
    install_lazyvim
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
