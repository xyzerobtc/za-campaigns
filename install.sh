#!/usr/bin/env sh
# aibtc install script
# Usage: curl -fsSL aibtc.com/install | sh

set -e

AIBTC_PACKAGE="@aibtc/mcp-server"
AIBTC_VERSION="latest"
NETWORK="${NETWORK:-mainnet}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { printf "${BLUE}[aibtc]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[aibtc]${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}[aibtc]${NC} %s\n" "$1"; }
error()   { printf "${RED}[aibtc]${NC} %s\n" "$1" >&2; }

# Detect OS
detect_os() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  case "$OS" in
    Linux*)  OS_TYPE="linux" ;;
    Darwin*) OS_TYPE="macos" ;;
    MINGW*|MSYS*|CYGWIN*) OS_TYPE="windows" ;;
    *)
      error "Unsupported operating system: $OS"
      exit 1
      ;;
  esac
  case "$ARCH" in
    x86_64|amd64) ARCH_TYPE="x64" ;;
    arm64|aarch64) ARCH_TYPE="arm64" ;;
    *)
      warn "Unsupported architecture: $ARCH — attempting anyway"
      ARCH_TYPE="$ARCH"
      ;;
  esac
}

# Check for required commands
check_command() {
  command -v "$1" >/dev/null 2>&1
}

# Install Node.js via nvm if not present
ensure_node() {
  if check_command node; then
    NODE_VERSION="$(node --version)"
    info "Node.js found: $NODE_VERSION"
    # Require Node.js >= 18
    NODE_MAJOR="$(node --version | sed 's/v//' | cut -d. -f1)"
    if [ "$NODE_MAJOR" -lt 18 ]; then
      warn "Node.js >= 18 required (found $NODE_VERSION). Installing via nvm..."
      install_node_via_nvm
    fi
  else
    info "Node.js not found. Installing via nvm..."
    install_node_via_nvm
  fi
}

install_node_via_nvm() {
  if ! check_command nvm && [ ! -f "$HOME/.nvm/nvm.sh" ]; then
    info "Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | sh
    # shellcheck disable=SC1090
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  else
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  fi
  nvm install --lts
  nvm use --lts
}

# Install or update the aibtc MCP server
install_aibtc() {
  info "Installing $AIBTC_PACKAGE@$AIBTC_VERSION..."

  if check_command npm; then
    npm install -g "$AIBTC_PACKAGE@$AIBTC_VERSION" --silent
    success "Installed $AIBTC_PACKAGE globally via npm"
  else
    error "npm not found. Please install Node.js >= 18 and re-run this script."
    exit 1
  fi
}

# Configure MCP server for supported editors
configure_mcp() {
  AIBTC_MCP_CONFIG='{
  "mcpServers": {
    "aibtc": {
      "command": "npx",
      "args": ["-y", "@aibtc/mcp-server@latest"],
      "env": {
        "NETWORK": "'"$NETWORK"'"
      }
    }
  }
}'

  # Cursor
  if [ -d "$HOME/.cursor" ] || check_command cursor; then
    CURSOR_CONFIG_DIR="$HOME/.cursor"
    mkdir -p "$CURSOR_CONFIG_DIR"
    CURSOR_MCP="$CURSOR_CONFIG_DIR/mcp.json"
    if [ -f "$CURSOR_MCP" ]; then
      warn "Cursor MCP config already exists at $CURSOR_MCP — skipping (edit manually)"
    else
      printf '%s\n' "$AIBTC_MCP_CONFIG" > "$CURSOR_MCP"
      success "Cursor MCP config written to $CURSOR_MCP"
    fi
  fi

  # Claude Code / VS Code (claude-code extension)
  if check_command claude; then
    CLAUDE_CONFIG="$HOME/.claude/mcp.json"
    mkdir -p "$(dirname "$CLAUDE_CONFIG")"
    if [ -f "$CLAUDE_CONFIG" ]; then
      warn "Claude MCP config already exists at $CLAUDE_CONFIG — skipping (edit manually)"
    else
      printf '%s\n' "$AIBTC_MCP_CONFIG" > "$CLAUDE_CONFIG"
      success "Claude MCP config written to $CLAUDE_CONFIG"
    fi
  fi
}

print_banner() {
  printf '\n'
  printf '   ___  ____  ____  ____  ___ \n'
  printf '  / _ \|  _ \|  _ \|  _ \/ __|\n'
  printf ' | | | | |_) | |_) | |_) \__ \\\n'
  printf ' | |_| |  __/|  __/|  _ < (__|\n'
  printf '  \___/|_|   |_|   |_| \_\___|\n'
  printf '\n'
  printf '  AI + Bitcoin on Stacks\n'
  printf '\n'
}

print_next_steps() {
  printf '\n'
  success "aibtc MCP server installed successfully!"
  printf '\n'
  info "Next steps:"
  printf '  1. Restart your editor (Cursor, VS Code, etc.)\n'
  printf '  2. The aibtc MCP server will be available in your AI assistant\n'
  printf '  3. Network: %s\n' "$NETWORK"
  printf '\n'
  info "To use testnet instead:"
  printf '  NETWORK=testnet curl -fsSL aibtc.com/install | sh\n'
  printf '\n'
  info "Documentation: https://aibtc.dev"
  printf '\n'
}

main() {
  print_banner
  detect_os
  info "Platform: $OS_TYPE / $ARCH_TYPE"
  info "Network:  $NETWORK"
  printf '\n'

  ensure_node
  install_aibtc
  configure_mcp
  print_next_steps
}

main "$@"
