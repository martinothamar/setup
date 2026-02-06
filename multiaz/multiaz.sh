#!/bin/bash

# Config markers for bashrc
CONFIG_START="# === MultiAZ Config START ==="
CONFIG_END="# === MultiAZ Config END ==="

# The shell functions to install
read -r -d '' MULTIAZ_CONFIG << 'EOF'
# Azure multi-profile wrappers
export AZURE_DEV_CONFIG_DIR="$HOME/.azure-dev"
export AZURE_PROD_CONFIG_DIR="$HOME/.azure-prod"

_az_config_dir_for_env() {
  case "${1:-}" in
    dev) printf '%s\n' "$AZURE_DEV_CONFIG_DIR" ;;
    prod) printf '%s\n' "$AZURE_PROD_CONFIG_DIR" ;;
    *)
      echo "Usage: _az_config_dir_for_env <dev|prod>" >&2
      return 2
      ;;
  esac
}

aze() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: aze <dev|prod|clear> [--] [command] [args...]" >&2
    return 2
  fi

  local env="$1"
  shift

  case "$env" in
    clear)
      if [ "$#" -ne 0 ]; then
        echo "Usage: aze clear" >&2
        return 2
      fi
      unset AZURE_CONFIG_DIR
      echo "AZURE_CONFIG_DIR cleared"
      return 0
      ;;
    dev|prod)
      ;;
    *)
      echo "Usage: aze <dev|prod|clear> [--] [command] [args...]" >&2
      return 2
      ;;
  esac

  local dir
  dir="$(_az_config_dir_for_env "$env")" || return $?
  mkdir -p "$dir" || return $?

  if [ "${1:-}" = "--" ]; then
    shift
  fi

  if [ "$#" -eq 0 ]; then
    export AZURE_CONFIG_DIR="$dir"
    echo "AZURE_CONFIG_DIR=$AZURE_CONFIG_DIR"
    return 0
  fi

  AZURE_CONFIG_DIR="$dir" "$@"
}

az-env() {
  aze "$@"
}

az-run() {
  aze "$@"
}

az() {
  mkdir -p "$AZURE_DEV_CONFIG_DIR" || return $?
  AZURE_CONFIG_DIR="$AZURE_DEV_CONFIG_DIR" command az "$@"
}

azp() {
  mkdir -p "$AZURE_PROD_CONFIG_DIR" || return $?
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
  echo "Use 'aze <dev|prod>' to switch shell context and 'aze <dev|prod> -- <cmd>' for one-off commands."
}

install
