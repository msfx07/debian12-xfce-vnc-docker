#!/bin/sh
set -e

PORT=${1:-3389}
CLIENT=${RDP_CLIENT:-xfreerdp}
URL="127.0.0.1:${PORT}"
CLIENT_NO_PASS=${CLIENT_NO_PASS:-}
# Optional parameters (can be provided as env vars): RES (e.g., 1920x1080), USER, PASS
RES=${RES:-}
USER=${USER:-}
PASS=${PASS:-}
if [ -n "$RES" ]; then
  # normalize 1920X1080 or 1920x1080 to 1920x1080
  RES=$(echo "$RES" | tr 'X' 'x')
  # basic validation: should match WIDTHxHEIGHT
  if ! echo "$RES" | grep -E '^[0-9]+x[0-9]+$$' >/dev/null 2>&1; then
    echo "Warning: RES format invalid: $RES (expected WIDTHxHEIGHT)" 1>&2
    RES=
  fi
fi

if command -v "$CLIENT" >/dev/null 2>&1; then
  echo "Launching $CLIENT to connect to $URL"
  if [ "$CLIENT" = "xfreerdp" ]; then
    # xfreerdp syntax: xfreerdp /v:host:port [options]
    opts="/cert:ignore"
    if [ -n "$RES" ]; then
      opts="$opts /size:$RES"
    fi
    if [ -n "$USER" ]; then
      opts="$opts /u:$USER"
    fi
    if [ -n "$PASS" ]; then
      opts="$opts /p:$PASS"
    elif [ -n "$CLIENT_NO_PASS" ] && [ "$CLIENT_NO_PASS" != "0" ]; then
      opts="$opts /u: /p:"
    fi
    xfreerdp /v:$URL $opts || true
  elif [ "$CLIENT" = "rdesktop" ]; then
    rdesktop_opts="-z"
    if [ -n "$RES" ]; then
      # rdesktop uses dimension flag -g WIDTHxHEIGHT
      rdesktop_opts="$rdesktop_opts -g $RES"
    fi
    if [ -n "$USER" ]; then
      rdesktop_opts="$rdesktop_opts -u $USER"
    fi
    if [ -n "$PASS" ]; then
      rdesktop_opts="$rdesktop_opts -p $PASS"
    fi
    rdesktop $rdesktop_opts $URL || true
  else
    "$CLIENT" "$URL" || true
  fi
elif command -v remmina >/dev/null 2>&1; then
  echo "Launching remmina to connect to rdp://$URL"
  remmina -c "rdp://$URL" || true
else
  echo "No RDP client found in PATH. Try: xfreerdp, rdesktop, remmina, or set RDP_CLIENT to your client command."
  echo "Attempting to open an RDP URL via xdg-open if available: rdp://$URL"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "rdp://$URL" >/dev/null 2>&1 || true
  else
    echo "No system URL opener found (xdg-open). Please connect manually to: $URL"
  fi

  echo
  if [ -f /etc/os-release ] && grep -qi ubuntu /etc/os-release; then
    echo "Install xfreerdp on Debian/Ubuntu:"
    echo "  sudo apt update && sudo apt install -y freerdp2-x11"
  elif [ -f /etc/os-release ] && grep -qi debian /etc/os-release; then
    echo "Install xfreerdp on Debian:"
    echo "  sudo apt update && sudo apt install -y freerdp2-x11"
  elif [ "$(uname)" = "Darwin" ]; then
    echo "On macOS, use Microsoft Remote Desktop from the App Store or FreeRDP builds."
  elif command -v choco >/dev/null 2>&1; then
    echo "Install an RDP client on Windows (for example Microsoft Remote Desktop)."
  else
    echo "If you're on Linux: install freerdp2-x11 (xfreerdp) or remmina. On macOS: use Microsoft Remote Desktop. On Windows: use the built-in RDP client."
  fi
fi
