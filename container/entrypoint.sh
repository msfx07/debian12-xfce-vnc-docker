#!/bin/bash
set -e

# Set up environment
export USER=user9
export HOME=/home/user9
export DISPLAY=:1

# Start supervisord to manage services
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
