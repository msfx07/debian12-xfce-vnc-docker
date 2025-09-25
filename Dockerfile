### FILE: Dockerfile
FROM debian:12-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TZ=Asia/Manila \
    HOSTNAME=debian12-xfce \
    VNC_NO_PASSWORD=1

# Install dependencies, desktop environment, and utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xfce4 xfce4-goodies openbox \
    tigervnc-standalone-server tigervnc-common tigervnc-tools \
        htop bmon nano iputils-ping net-tools dnsutils make firefox-esr \
        dbus-x11 sudo locales tzdata curl gnupg2 ca-certificates supervisor && \
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

# Prepare VNC directory for the user. Password handling is controlled at runtime
# by the VNC_NO_PASSWORD and VNC_PASSWORD environment variables. By default
# this image is built to allow passwordless VNC connections (VNC_NO_PASSWORD=1).
RUN mkdir -p /home/user9/.vnc && \
    chown -R user9:user9 /home/user9/.vnc

# Copy entrypoint and supervisord config (organized under container/)
COPY container/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY container/supervisord.conf /etc/supervisor/supervisord.conf
RUN mkdir -p /var/log/supervisor && \
    chmod 755 /var/log/supervisor && \
    chmod +x /usr/local/bin/entrypoint.sh

# Add VNC start wrapper and default xstartup for the user (from container/)
COPY container/vnc-start.sh /usr/local/bin/vnc-start.sh
COPY container/xstartup /home/user9/.vnc/xstartup
RUN chmod +x /usr/local/bin/vnc-start.sh && \
    mkdir -p /home/user9/.vnc && \
    chown -R user9:user9 /home/user9/.vnc && \
    chmod 700 /home/user9/.vnc && \
    chmod 755 /home/user9/.vnc/xstartup && \
    chown user9:user9 /home/user9/.vnc/xstartup

# Expose VNC port
EXPOSE 5901

# Healthcheck for VNC server (checks common vnc process names)
HEALTHCHECK CMD pgrep -f Xtigervnc >/dev/null || pgrep -f Xvnc >/dev/null || exit 1

# Set entrypoint to start supervisord via the entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Security warning: image defaults to passwordless VNC
# WARNING: VNC access is disabled by password by default in this image (VNC_NO_PASSWORD=1).
# This is convenient for local testing but is insecure for production or public networks.