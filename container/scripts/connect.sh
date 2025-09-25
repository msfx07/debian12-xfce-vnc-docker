#!/bin/sh
set -e

PORT=${1:-5901}
CLIENT=${VNC_CLIENT:-vncviewer}
URL="vnc://127.0.0.1:${PORT}"
CLIENT_NO_PASS=${CLIENT_NO_PASS:-}

if command -v "$CLIENT" >/dev/null 2>&1; then
  echo "Launching $CLIENT to connect to $URL"
  if [ "$CLIENT" = "vncviewer" ]; then
    if [ -n "$CLIENT_NO_PASS" ] && [ "$CLIENT_NO_PASS" != "0" ]; then
      echo "Starting vncviewer in no-auth mode (-SecurityTypes None)"
      vncviewer -SecurityTypes None 127.0.0.1:${PORT} || true
    else
      vncviewer 127.0.0.1:${PORT} || true
    fi
  else
    "$CLIENT" "$URL" || true
  fi
elif command -v remmina >/dev/null 2>&1; then
  echo "Launching remmina to connect to $URL"
  remmina -c "$URL" || true
elif command -v vinagre >/dev/null 2>&1; then
  echo "Launching vinagre to connect to $URL"
  vinagre "$URL" || true
else
  echo "No VNC client found in PATH. Try: vncviewer, remmina, or set VNC_CLIENT to your client command."
  echo "Attempting to open $URL with a system handler (xdg-open / open / cmd.exe)..."
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open "$URL" >/dev/null 2>&1 || true
  elif command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /C start "" "$URL" >/dev/null 2>&1 || true
  else
    echo "No system URL opener found (xdg-open/open/cmd.exe). Please open: $URL manually."
  fi

  echo
  if [ -f /etc/os-release ] && grep -qi ubuntu /etc/os-release; then
    echo "Install TigerVNC viewer on Debian/Ubuntu:"
    echo "  sudo apt update && sudo apt install -y tigervnc-viewer"
  elif [ -f /etc/os-release ] && grep -qi debian /etc/os-release; then
    echo "Install TigerVNC viewer on Debian:"
    echo "  sudo apt update && sudo apt install -y tigervnc-viewer"
  elif [ "$(uname)" = "Darwin" ]; then
    echo "Install TigerVNC viewer on macOS (Homebrew):"
    echo "  brew install tigervnc"
  elif command -v choco >/dev/null 2>&1; then
    echo "Install TigerVNC viewer on Windows (Chocolatey):"
    echo "  choco install tigervnc"
  else
    echo "If you're on Linux: install tigervnc-viewer or remmina. On macOS: brew install tigervnc. On Windows: install TigerVNC or RealVNC."
  fi
fi
