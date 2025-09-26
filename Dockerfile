### FILE: Dockerfile
FROM debian:12-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TZ=Asia/Manila \
    HOSTNAME=debian12-xfce


# Install dependencies, desktop environment, and utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xfce4 xfce4-goodies openbox \
        xrdp xorgxrdp \
            htop bmon nano iputils-ping net-tools dnsutils make firefox-esr \
            dbus-x11 sudo passwd locales tzdata curl gnupg2 ca-certificates supervisor && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    ln -snf /usr/share/zoneinfo/Asia/Manila /etc/localtime && \
    echo "Asia/Manila" > /etc/timezone && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 1000 user9 && \
    useradd -m -u 1000 -g 1000 -s /bin/bash user9 && \
    usermod -aG sudo user9 && \
    mkdir -p /etc/sudoers.d && \
    printf 'user9 ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/user9 && \
    chmod 0440 /etc/sudoers.d/user9 && \
    # Ensure /bin/bash is listed in /etc/shells and set as the user's login shell
    if ! grep -q "^/bin/bash$" /etc/shells 2>/dev/null; then echo "/bin/bash" >> /etc/shells; fi && \
    chsh -s /bin/bash user9 || true && \
    # Ensure default SHELL env is set system-wide
    echo "SHELL=/bin/bash" >> /etc/environment || true

# Ensure home directory and basic permissions exist for the user
RUN mkdir -p /home/user9 && \
    chown -R user9:user9 /home/user9

# Copy entrypoint and supervisord config (organized under container/)
COPY container/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY container/supervisord.conf /etc/supervisor/supervisord.conf
RUN mkdir -p /var/log/supervisor && \
    chmod 755 /var/log/supervisor && \
    chmod +x /usr/local/bin/entrypoint.sh

# Add VNC start wrapper and default xstartup for the user (from container/)
# Add XRDP start wrapper (container/) and ensure permissions
COPY container/xrdp-start.sh /usr/local/bin/xrdp-start.sh
RUN chmod +x /usr/local/bin/xrdp-start.sh && \
    chown user9:user9 /home/user9 || true
COPY container/startwm.sh /etc/xrdp/startwm.sh
RUN chmod 755 /etc/xrdp/startwm.sh || true

# Expose RDP port
EXPOSE 3389

# Healthcheck for xrdp
HEALTHCHECK CMD pgrep -f xrdp >/dev/null || exit 1

# Set entrypoint to start supervisord via the entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Note: the image exposes RDP (xrdp) on port 3389 by default. Configure xrdp
# authentication and firewalling if you plan to expose the service.