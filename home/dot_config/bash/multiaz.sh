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

  AZURE_CONFIG_DIR="$dir" command "$@"
}

az-env() {
  aze "$@"
}

az-run() {
  aze "$@"
}

az() {
  local dir="${AZURE_CONFIG_DIR:-$AZURE_DEV_CONFIG_DIR}"
  mkdir -p "$dir" || return $?
  AZURE_CONFIG_DIR="$dir" command az "$@"
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
