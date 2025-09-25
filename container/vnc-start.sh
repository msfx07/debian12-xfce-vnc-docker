#!/bin/bash
set -e

USER=${USER:-user9}
HOME=${HOME:-/home/$USER}
DISPLAY=${DISPLAY:-:1}

# Ensure .vnc exists and set up password file unless running in no-password mode
mkdir -p "$HOME/.vnc"
chown $USER:$USER "$HOME/.vnc"

# If VNC_NO_PASSWORD is set (non-empty and not 0), run the VNC server without authentication
NO_PASS=${VNC_NO_PASSWORD:-}
if [ -n "$NO_PASS" ] && [ "$NO_PASS" != "0" ]; then
  echo "VNC_NO_PASSWORD is set -> starting VNC server without authentication (SecurityTypes None)"
else
  if [ -n "${VNC_PASSWORD:-}" ]; then
    # Create a VNC password file (restrict permissions)
    echo "$VNC_PASSWORD" | vncpasswd -f > "$HOME/.vnc/passwd"
    chmod 600 "$HOME/.vnc/passwd"
    chown $USER:$USER "$HOME/.vnc/passwd"
  fi
fi

# Diagnostic output
echo "Starting VNC as user=$USER home=$HOME display=$DISPLAY"
echo "Environment:"; env

# Debug helper: show masked info about a file (owner, mode, size, first/last bytes)
show_masked_file() {
  fpath="$1"
  if [ ! -e "$fpath" ]; then
    echo "(no file) $fpath"
    return
  fi
  echo "file: $fpath"
  stat -c '  owner=%U mode=%a size=%s name=%n' "$fpath" || true
  # show first 8 bytes in hex (if readable)
  if command -v od >/dev/null 2>&1; then
    echo -n '  head (hex): ' && od -An -N8 -t x1 "$fpath" | tr -s ' ' | sed 's/^ //'
    # show last 8 bytes in hex
    size=$(stat -c %s "$fpath" 2>/dev/null || echo 0)
    if [ "$size" -gt 8 ]; then
      echo -n '  tail (hex): ' && tail -c 8 "$fpath" | od -An -t x1 | tr -s ' ' | sed 's/^ //'
    fi
  else
    echo "  (od not available; skipping hex dump)"
  fi
}

# Print info about the persistent password file
echo "-- Persistent passwd info --"
show_masked_file "$HOME/.vnc/passwd"

# Also show any temporary tigervnc passwd files that Xtigervnc may create
echo "-- Temporary tigervnc passwd candidates --"
for d in /tmp/tigervnc.*; do
  [ -e "$d/passwd" ] || continue
  show_masked_file "$d/passwd"
done


# Start VNC server as the user, preserving HOME and using sudo -H to set home
# Allow external connections by disabling the localhost-only bind (TigerVNC: -localhost no)
XTIGERVNC=/usr/bin/Xtigervnc
use_xtigervnc=0
if [ -x "$XTIGERVNC" ]; then
  # Detect whether the binary supports the -fg (foreground) option. Some
  # distributions install Xvnc under the Xtigervnc name but that variant doesn't
  # accept -fg which causes an immediate fatal error (seen earlier).
  if "$XTIGERVNC" --help 2>&1 | grep -q -- '-fg'; then
    use_xtigervnc=1
  fi
fi

if [ "$use_xtigervnc" -eq 1 ]; then
  # Use Xtigervnc directly when it supports -fg. If NO_PASS is set, disable auth.
  if [ -n "$NO_PASS" ] && [ "$NO_PASS" != "0" ]; then
    CMD=("$XTIGERVNC" "$DISPLAY" -rfbport 5901 -geometry 1280x800 -depth 24 -localhost=0 -SecurityTypes None -fg)
    echo "Running Xtigervnc (no auth): ${CMD[*]} as user=$USER"
  else
    # -rfbauth uses the classic VNC password file format
    CMD=("$XTIGERVNC" "$DISPLAY" -rfbport 5901 -rfbauth "$HOME/.vnc/passwd" -geometry 1280x800 -depth 24 -localhost=0 -SecurityTypes VncAuth -fg)
    echo "Running Xtigervnc: ${CMD[*]} as user=$USER"
  fi
  # supervisord launches this program as the target user. Exec directly.
  exec env HOME="$HOME" DISPLAY="$DISPLAY" "${CMD[@]}"
else
  # If Xtigervnc either doesn't exist or doesn't support -fg, fall back to the
  # vncserver wrapper which supports running in the foreground (-fg). This keeps
  # behavior compatible with supervisord which expects a foreground process.
  if [ -n "$NO_PASS" ] && [ "$NO_PASS" != "0" ]; then
    # vncserver wrapper refuses to run without authentication unless the
    # --I-KNOW-THIS-IS-INSECURE flag is provided. Add that so passwordless
    # mode can be used intentionally (image defaults to VNC_NO_PASSWORD=1).
    CMD=(vncserver "$DISPLAY" -geometry 1280x800 -depth 24 -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE -fg)
    echo "Xtigervnc not suitable, falling back to (no auth): ${CMD[*]} as user=$USER"
  else
    CMD=(vncserver "$DISPLAY" -geometry 1280x800 -depth 24 -localhost no -SecurityTypes VncAuth -fg)
    echo "Xtigervnc not suitable, falling back to: ${CMD[*]} as user=$USER"
  fi
  # If this script is already running as the target user, avoid sudo and exec
  # the command directly. This helps when supervisord is configured to run the
  # program as the correct user. Otherwise use sudo -H -u to switch user.
  current_uid=$(id -u 2>/dev/null || echo 0)
  target_uid=$(getent passwd "$USER" | cut -d: -f3 2>/dev/null || echo 1000)
  # supervisord runs this program as user9; execute directly
  exec env HOME="$HOME" DISPLAY="$DISPLAY" "${CMD[@]}"
fi
