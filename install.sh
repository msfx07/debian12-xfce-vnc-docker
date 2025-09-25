#!/usr/bin/env sh
# install.sh - ensure Docker and GNU Make are installed (best-effort, per-distro)
#
# Notes:
# - This script performs package installation and may invoke privileged operations (using sudo).
#   You will typically need to run this as a user with sudo privileges or be prepared to enter
#   your password when prompted. Continuous integration environments should provide the
#   necessary permissions or run the installer in an appropriate environment.
# - On macOS the script installs Docker Desktop via Homebrew Cask when possible, but Docker
#   Desktop must be started manually by the user after installation (or the service started)
#   before the Docker daemon is available to run containers.
set -eu

# Color and emoji helpers (fall back to plain text if not a TTY or NO_COLOR is set)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=''
  RESET=''
fi

ICON_INFO="ℹ️"
ICON_OK="✅"
ICON_WARN="⚠️"
ICON_ERROR="❌"
ICON_DOCKER="🐳"
ICON_MAKE="🛠️"

log() { printf "%s\n" "$*"; }
info() { printf "%s %b%s%b\n" "$ICON_INFO" "$BOLD$BLUE" "$*" "$RESET" 1>&2; }
success() { printf "%s %b%s%b\n" "$ICON_OK" "$BOLD$GREEN" "$*" "$RESET" 1>&2; }
warn() { printf "%s %b%s%b\n" "$ICON_WARN" "$BOLD$YELLOW" "$*" "$RESET" 1>&2; }
error() { printf "%s %b%s%b\n" "$ICON_ERROR" "$BOLD$RED" "$*" "$RESET" 1>&2; }

usage() {
  cat <<EOF
Usage: $0 [--run|-r] [--yes|-y|--yes-to-all] [--help]

This script will:
  1) detect your OS package manager
  2) ensure Docker is installed (attempts to install via package manager if missing)
  3) ensure GNU Make is installed (attempts to install if missing)

Use --run to invoke 'make all' after successful installs.
Use --yes or --yes-to-all to run non-interactively (answer 'yes' to prompts).
EOF
}

NEED_RUN=0
YES_ALL=0
for arg in "$@"; do
  case "$arg" in
    -r|--run) NEED_RUN=1 ;;
    -y|--yes|--yes-to-all) YES_ALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $arg"; usage; exit 2 ;;
  esac
done

confirm() {
  # confirm prompt; returns 0 for yes, 1 for no
  if [ "$YES_ALL" = "1" ]; then
    return 0
  fi
  printf "%s [y/N]: " "$1" 1>&2
  if [ -t 0 ]; then
    read -r ans || return 1
  else
    return 1
  fi
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

detect_pkgmgr() {
  PKG_MGR=unknown
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MGR=apt
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR=dnf
  elif command -v yum >/dev/null 2>&1; then
    PKG_MGR=yum
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR=pacman
  elif command -v apk >/dev/null 2>&1; then
    PKG_MGR=apk
  elif command -v brew >/dev/null 2>&1; then
    PKG_MGR=brew
  elif command -v choco >/dev/null 2>&1; then
    PKG_MGR=choco
  fi
  echo "$PKG_MGR"
}

PKG_MGR=$(detect_pkgmgr)
info "Detected package manager: $PKG_MGR"

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    success "$ICON_DOCKER Docker is already installed: $(docker --version | head -n1)"
    return 0
  fi
  warn "$ICON_DOCKER Docker not found — attempting to install via $PKG_MGR (best-effort)."
  case "$PKG_MGR" in
    apt)
      info "$ICON_DOCKER Installing prerequisites and Docker via apt...";
      sudo apt-get update;
      sudo apt-get install -y ca-certificates curl gnupg lsb-release;
      sudo mkdir -p /etc/apt/keyrings;
      curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmour -o /etc/apt/keyrings/docker.gpg || true;
      if command -v lsb_release >/dev/null 2>&1; then
        dist=$(lsb_release -cs) || dist=stable
      else
        dist=stable
      fi
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $dist stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null || true;
      sudo apt-get update;
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
      ;;
    dnf)
      info "$ICON_DOCKER Installing Docker via dnf...";
      sudo dnf -y install dnf-plugins-core;
      sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || true;
      sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true;
      ;;
    yum)
      info "$ICON_DOCKER Installing Docker via yum...";
      sudo yum install -y yum-utils;
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true;
      sudo yum install -y docker-ce docker-ce-cli containerd.io || true;
      ;;
    pacman)
      info "$ICON_DOCKER Installing Docker via pacman...";
      sudo pacman -Sy --noconfirm docker || true;
      ;;
    apk)
      info "$ICON_DOCKER Installing Docker via apk...";
      sudo apk add docker || true;
      ;;
    brew)
      info "$ICON_DOCKER Installing Docker Desktop via Homebrew (macOS)...";
      brew install --cask docker || true;
      ;;
    choco)
      info "$ICON_DOCKER Installing Docker via Chocolatey (Windows)...";
      choco install docker-desktop -y || true;
      ;;
    *)
      warn "No supported package manager detected for installing Docker. Please install Docker manually: https://docs.docker.com/get-docker/";
      return 1;
      ;;
  esac

  # Wait a moment and re-check
  sleep 2
  if command -v docker >/dev/null 2>&1; then
    success "$ICON_DOCKER Docker installed: $(docker --version | head -n1)"
    return 0
  else
    warn "Docker installation attempt finished but 'docker' not found in PATH. You may need to log out/in or start Docker Desktop manually."
    return 2
  fi
}

daemon_running() {
  if docker info >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

try_start_daemon() {
  warn "$ICON_DOCKER Docker is present but the daemon does not appear to be running or you lack permission to access it."
  if confirm "Attempt to start Docker daemon now using systemctl/service (requires sudo)?"; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo systemctl start docker || true
    else
      sudo service docker start || true
    fi
    sleep 2
    if daemon_running; then
      success "$ICON_DOCKER Docker daemon is now running."
      return 0
    else
      error "Failed to start Docker daemon automatically. If you're on macOS, please start Docker Desktop; on Linux check service logs or start manually."
      warn "You may also need to add your user to the docker group: sudo usermod -aG docker \$USER (then re-login)"
      return 2
    fi
  else
    info "Skipping automatic start. Please start Docker manually and re-run this script."
    return 1
  fi
}

install_make() {
  if command -v make >/dev/null 2>&1 && make --version 2>/dev/null | grep -qi "gnu make"; then
    success "$ICON_MAKE GNU Make already installed: $(make --version | head -n1)"
    return 0
  fi

  info "$ICON_MAKE GNU Make not found — attempting install via $PKG_MGR"
  case "$PKG_MGR" in
    apt)
      sudo apt-get update; sudo apt-get install -y make || true;
      ;;
    dnf)
      sudo dnf install -y make || true;
      ;;
    yum)
      sudo yum install -y make || true;
      ;;
    pacman)
      sudo pacman -Sy --noconfirm make || true;
      ;;
    apk)
      sudo apk add make || true;
      ;;
    brew)
      brew install gnu-make || true; # installs as gmake on macOS
      ;;
    choco)
      choco install make -y || true;
      ;;
    *)
      echo "No supported package manager detected for installing Make. Please install GNU Make manually.";
      return 1;
      ;;
  esac

  if command -v make >/dev/null 2>&1; then
    success "$ICON_MAKE GNU Make now available: $(make --version | head -n1)"
    return 0
  elif command -v gmake >/dev/null 2>&1; then
    warn "GNU Make installed as 'gmake' (macOS). You can use gmake or add it to PATH as 'make'.";
    return 0
  else
    warn "Make still not found after installation attempt. Please install manually."
    return 2
  fi
}

info "==> Ensuring Docker is installed (will attempt to install if missing)"
if install_docker; then
  success "Docker is available"
  if ! daemon_running; then
    try_start_daemon || true
  fi
else
  warn "Docker may not be available after installation attempt. You can still install Make or run the project if you have an alternative environment."
fi

info "==> Ensuring GNU Make is installed"
if install_make; then
  success "GNU Make available"
else
  error "GNU Make not available after attempted install. Exiting."
  exit 3
fi

# Install TigerVNC (viewer/server tools) if missing. Useful for local integration tests
install_tigervnc() {
  # Quick check for common vnc binaries
  if command -v Xtigervnc >/dev/null 2>&1 || command -v Xvnc >/dev/null 2>&1 || command -v vncserver >/dev/null 2>&1; then
    success "TigerVNC (or compatible VNC server) already present: $(command -v Xtigervnc || command -v Xvnc || command -v vncserver)"
    return 0
  fi
  warn "TigerVNC not found   attempting to install via $PKG_MGR (best-effort)."
  case "$PKG_MGR" in
    apt)
      info "Installing TigerVNC packages via apt..."
      sudo apt-get update || true
      sudo apt-get install -y tigervnc-standalone-server tigervnc-common tigervnc-tools || true
      ;;
    dnf)
      info "Installing TigerVNC via dnf..."
      sudo dnf install -y tigervnc-server tigervnc || true
      ;;
    yum)
      info "Installing TigerVNC via yum..."
      sudo yum install -y tigervnc-server tigervnc || true
      ;;
    pacman)
      info "Installing TigerVNC via pacman..."
      sudo pacman -Sy --noconfirm tigervnc || true
      ;;
    apk)
      info "Installing TigerVNC via apk..."
      sudo apk add tigervnc || true
      ;;
    brew)
      info "Installing TigerVNC via Homebrew..."
      brew install tigervnc || true
      ;;
    choco)
      info "Installing TigerVNC via Chocolatey..."
      choco install tigervnc -y || true
      ;;
    *)
      warn "No supported package manager detected for installing TigerVNC. Please install tigervnc manually."
      return 1
      ;;
  esac

  sleep 1
  if command -v Xtigervnc >/dev/null 2>&1 || command -v Xvnc >/dev/null 2>&1 || command -v vncserver >/dev/null 2>&1; then
    success "TigerVNC installed: $(command -v Xtigervnc || command -v Xvnc || command -v vncserver)"
    return 0
  else
    warn "TigerVNC installation finished but no vncserver binary found in PATH."
    return 2
  fi
}

info "==> Ensuring TigerVNC is installed (optional for local tests)"
if install_tigervnc; then
  success "TigerVNC available"
else
  warn "TigerVNC not available after attempted install; some local tests or helpers may not run as expected."
fi

if [ "$NEED_RUN" -eq 1 ]; then
  info "Running: make all"
  make all
fi

success "install.sh finished."
