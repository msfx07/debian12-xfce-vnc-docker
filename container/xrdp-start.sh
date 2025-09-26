#!/bin/bash
set -e

# Simple xrdp start wrapper for Docker + supervisord
# Starts xrdp and xrdp-sesman so the container exposes RDP on port 3389.

# If a custom XRDP_PORT is set, use it (default 3389)
XRDP_PORT=${XRDP_PORT:-3389}

# Ensure /var/run and /var/log exist and have correct perms
mkdir -p /var/run/xrdp /var/log/xrdp
chown -R root:root /var/run/xrdp /var/log/xrdp || true

echo "Starting xrdp services on port $XRDP_PORT"

# Start sesman (session manager)
if command -v xrdp-sesman >/dev/null 2>&1; then
  xrdp-sesman --nodaemon &
else
  echo "xrdp-sesman not found in PATH; exiting" >&2
  exit 2
fi

# Start xrdp (RDP server)
if command -v xrdp >/dev/null 2>&1; then
  # xrdp will read /etc/xrdp/xrdp.ini for listen port; override via --port if supported
  xrdp --nodaemon
else
  echo "xrdp not found in PATH; exiting" >&2
  exit 2
fi
