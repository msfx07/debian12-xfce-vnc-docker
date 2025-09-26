#!/usr/bin/env sh
# install.sh - ensure Docker and GNU Make are installed (best-effort, per-distro)

# Minimal arg parsing: support --run, --yes, and --check-rdp (validate-only)
NEED_RUN=0
YES_ALL=0
CHECK_RDP_ONLY=0

# Minimal logging helpers used by this script. Keep these intentionally small so
# the script runs under /bin/sh (dash) without requiring external tooling.
ICON_DOCKER="[docker]"
ICON_MAKE="[make]"
info() { printf "info: %s\n" "$*"; }
warn() { printf "warn: %s\n" "$*" 1>&2; }
error() { printf "error: %s\n" "$*" 1>&2; }
success() { printf "success: %s\n" "$*"; }
usage() { printf "Usage: %s [--run|-r] [--yes|-y] [--check-rdp]\n" "$0"; }
for arg in "$@"; do
  case "$arg" in
    -r|--run) NEED_RUN=1 ;;
    -y|--yes|--yes-to-all) YES_ALL=1 ;;
    --check-rdp) CHECK_RDP_ONLY=1 ;;
    -h|--help) echo "Usage: $0 [--run|-r] [--yes|-y] [--check-rdp]"; exit 0 ;;
    *) ;;
  esac
done

# If the user requested only RDP client validation, do that early and exit
if [ "$CHECK_RDP_ONLY" = "1" ]; then
  if command -v xfreerdp >/dev/null 2>&1; then
    echo "xfreerdp found: $(command -v xfreerdp)"
    exit 0
  else
    echo "xfreerdp not found. No RDP client installed." 1>&2
    exit 2
  fi

fi

## end of quick arg parsing

  # Detect package manager early so subsequent install checks show the detected
  # package manager instead of blank values.
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

# Ensure a local RDP client is available for connecting to the container (xfreerdp/rdesktop/remmina)
install_rdp_client() {
  # Prefer FreeRDP (xfreerdp). Fail fast if install fails.
  if command -v xfreerdp >/dev/null 2>&1; then
    success "xfreerdp already present: $(command -v xfreerdp)"
    return 0
  fi

  warn "xfreerdp not found — attempting to install via $PKG_MGR (will fail on error)."
  case "$PKG_MGR" in
    apt)
      info "Installing freerdp2-x11 via apt..."
      sudo apt-get update || { error "apt-get update failed"; return 1; }
      sudo apt-get install -y freerdp2-x11 || { error "apt-get install freerdp2-x11 failed"; return 1; }
      ;;
    dnf)
      info "Installing freerdp via dnf..."
      sudo dnf install -y freerdp || { error "dnf install freerdp failed"; return 1; }
      ;;
    yum)
      info "Installing freerdp via yum..."
      sudo yum install -y freerdp || { error "yum install freerdp failed"; return 1; }
      ;;
    pacman)
      info "Installing freerdp via pacman..."
      sudo pacman -Sy --noconfirm freerdp || { error "pacman install freerdp failed"; return 1; }
      ;;
    apk)
      info "Installing freerdp via apk..."
      sudo apk add freerdp || { error "apk add freerdp failed"; return 1; }
      ;;
    brew)
      info "Installing freerdp via Homebrew (macOS)..."
      brew install freerdp || { error "brew install freerdp failed"; return 1; }
      ;;
    choco)
      error "Automatic installation on Windows via Chocolatey is not supported by this script; please install FreeRDP manually."
      return 1
      ;;
    *)
      error "No supported package manager detected for installing freerdp. Please install freerdp manually."
      return 1
      ;;
  esac

  # Verify installation
  if command -v xfreerdp >/dev/null 2>&1; then
    success "xfreerdp installed: $(command -v xfreerdp)"
    return 0
  else
    error "xfreerdp still not found after install attempt"
    return 2
  fi
}

info "==> Ensuring an RDP client (xfreerdp/rdesktop/remmina) is installed (optional for local tests)"
if install_rdp_client; then
  success "RDP client available"
else
  warn "RDP client not available after attempted install; use your platform package manager to install freerdp/rdesktop/remmina for local testing."
fi

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

if [ "$NEED_RUN" -eq 1 ]; then
  info "Running: make all"
  make all
fi

success "install.sh finished."
