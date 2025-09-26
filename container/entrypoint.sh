#!/bin/bash
set -e

# Set up environment
export USER=user9
export HOME=/home/user9
export DISPLAY=:1

# Set runtime XRDP password if provided via env; default to 'secret' for local tests.
# Use chpasswd to set the user's password at container start so the image does not
# bake credentials at build time.
# Default runtime credentials (can be overridden with env vars at runtime).
# NOTE: for production use Docker secrets or bind-mounts instead of env vars.
XRDP_USERNAME=${XRDP_USERNAME:-admin}
# If XRDP_PASSWORD is not supplied via env, generate a random one at startup.
GENERATED_PASSWORD=0
if [ -z "${XRDP_PASSWORD:-}" ]; then
	if command -v openssl >/dev/null 2>&1; then
		XRDP_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)
	else
		XRDP_PASSWORD=$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c16)
	fi
	GENERATED_PASSWORD=1
fi

# Create the XRDP user account (if it doesn't exist) and set the password.
if ! id -u "$XRDP_USERNAME" >/dev/null 2>&1; then
	# Create a home directory and add to sudoers similar to user9
	useradd -m -s /bin/bash "$XRDP_USERNAME" || true
	mkdir -p /etc/sudoers.d || true
	printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$XRDP_USERNAME" > /etc/sudoers.d/"$XRDP_USERNAME" || true
	chmod 0440 /etc/sudoers.d/"$XRDP_USERNAME" || true
fi

# Apply password if chpasswd is available
if [ -n "$XRDP_PASSWORD" ] && command -v chpasswd >/dev/null 2>&1; then
	echo "${XRDP_USERNAME}:${XRDP_PASSWORD}" | chpasswd || true
fi

# Optionally write the password to a mounted file (safer than printing). If the
# target path is not writable, fall back to printing the generated password to
# stderr so operators can retrieve it.
# Default file path (can be overridden): /run/secrets/rdp_password
XRDP_PASSWORD_FILE=${XRDP_PASSWORD_FILE:-/run/secrets/rdp_password}
WRITE_OK=0
# Attempt to write password to the file if its directory exists and is writable
if [ -n "$XRDP_PASSWORD_FILE" ]; then
	dir="$(dirname "$XRDP_PASSWORD_FILE")"
	if [ -d "$dir" ] && [ -w "$dir" ]; then
		printf "%s" "$XRDP_PASSWORD" > "$XRDP_PASSWORD_FILE" 2>/dev/null || true
		chmod 600 "$XRDP_PASSWORD_FILE" 2>/dev/null || true
		chown root:root "$XRDP_PASSWORD_FILE" 2>/dev/null || true
		# Verify write succeeded
		if [ -f "$XRDP_PASSWORD_FILE" ]; then
			WRITE_OK=1
		fi
	fi
fi

# If we generated the password, prefer to inform user of the secret location; if
# writing failed, print the secret to stderr as a fallback.
if [ "$GENERATED_PASSWORD" -eq 1 ]; then
	if [ "$WRITE_OK" -eq 1 ]; then
		printf "Generated XRDP credentials written to: %s\n" "$XRDP_PASSWORD_FILE" 1>&2
	else
		printf "Generated XRDP credentials -> user: %s  password: %s\n" "$XRDP_USERNAME" "$XRDP_PASSWORD" 1>&2
	fi
fi

# Start supervisord to manage services
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
