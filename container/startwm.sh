#!/bin/sh
# startwm.sh - used by xrdp to start the desktop session
# This script will be copied to /etc/xrdp/startwm.sh in the image

# Ensure environment is clean
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1

# Start XFCE session
# Try to set a sensible default resolution for XRDP sessions. xrdp/xorgxrdp
# provides an X server where xrandr can set the session resolution. We attempt
# to add and set 1920x1080; if xrandr isn't available or fails, fall back to
# starting XFCE normally.
if command -v xrandr >/dev/null 2>&1; then
	# Wait a moment for the X server to be ready and retry a couple of times
	tries=0
	while [ $tries -lt 5 ]; do
		DISPLAY=${DISPLAY:-:0}
		# Get an existing output (e.g., XWAYLAND0 or default) to attach mode to
		output=$(DISPLAY=$DISPLAY xrandr --query 2>/dev/null | awk '/ connected/{print $1; exit}') || true
		if [ -n "$output" ]; then
			# Create the 1920x1080 mode if it doesn't exist
			if ! DISPLAY=$DISPLAY xrandr --query | grep -q "1920x1080"; then
				mode_line=$(DISPLAY=$DISPLAY xrandr --newmode 1920x1080 148.50 1920 2008 2052 2200 1080 1084 1089 1125  +0+0 2>/dev/null || true)
				# If newmode succeeded, add it
				DISPLAY=$DISPLAY xrandr --addmode "$output" 1920x1080 2>/dev/null || true
			fi
			# Try to set the mode
			DISPLAY=$DISPLAY xrandr --output "$output" --mode 1920x1080 2>/dev/null && break
		fi
		tries=$((tries+1))
		sleep 0.5
	done
fi

exec dbus-launch --exit-with-session startxfce4
