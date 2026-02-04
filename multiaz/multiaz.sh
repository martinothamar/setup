#!/bin/bash

# Config markers for bashrc
CONFIG_START="# === MultiAZ Config START ==="
CONFIG_END="# === MultiAZ Config END ==="

# The shell functions to install
read -r -d '' MULTIAZ_CONFIG << 'EOF'
# Azure multi-profile wrappers
export AZURE_DEV_CONFIG_DIR="$HOME/.azure-dev"
export AZURE_PROD_CONFIG_DIR="$HOME/.azure-prod"

az() {
  AZURE_CONFIG_DIR="$AZURE_DEV_CONFIG_DIR" command az "$@"
}

azp() {
  AZURE_CONFIG_DIR="$AZURE_PROD_CONFIG_DIR" command az "$@"
}

az-init() {
  mkdir -p "$AZURE_DEV_CONFIG_DIR" "$AZURE_PROD_CONFIG_DIR"
  echo "Login to dev Azure account:"
  AZURE_CONFIG_DIR="$AZURE_DEV_CONFIG_DIR" command az login --use-device-code
  echo ""
  echo "Login to prod Azure account:"
  AZURE_CONFIG_DIR="$AZURE_PROD_CONFIG_DIR" command az login --use-device-code
}
EOF

install() {
  # Remove existing config if present
  if grep -q "$CONFIG_START" ~/.bashrc 2>/dev/null; then
    echo "Updating existing multiaz configuration..."
    sed -i "/$CONFIG_START/,/$CONFIG_END/d" ~/.bashrc
  else
    echo "Installing multiaz configuration..."
  fi

  # Append config to bashrc
  cat >> ~/.bashrc << EOF

$CONFIG_START
$MULTIAZ_CONFIG
$CONFIG_END
EOF

  echo "MultiAZ installed. Run 'source ~/.bashrc' then 'az-init' to login."
}

install
