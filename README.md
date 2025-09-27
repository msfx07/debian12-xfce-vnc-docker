# debian-xfce-docker

Lightweight Debian 12 + XFCE Docker image with xrdp — run a local desktop via RDP for testing, demos, and headless GUI tasks.

This repository packages a compact Debian 12 desktop (XFCE) inside a Docker image and exposes the session via xrdp (RDP). It's designed for quick local GUI testing, demos, and lightweight CI invocations where a graphical environment is needed.
[![Docker Build](https://img.shields.io/badge/docker-ready-brightgreen.svg)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

---
## Assumptions / Prerequisites

This project assumes you have a running Linux desktop environment (any distribution) and that you're testing or demoing a GUI inside Docker. The primary use cases are local development, quick demos, and CI-friendly GUI tests on a Linux host.

- Host requirements: Docker and GNU Make (the included `install.sh` can attempt to install them on many distributions but typically requires `sudo`).
- An RDP client on the client machine to connect to the container (e.g. FreeRDP/xfreerdp, Remmina, or Microsoft Remote Desktop).
- The repository binds the RDP server to localhost by default; this is intended for local testing. If you run on a remote host, secure the connection (set an appropriate password, use an SSH tunnel, or VPN).

---
## Quick start (install Docker + make, then build)

Clone, and install dependencies:

```sh
git clone https://github.com/msfx07/debian12-xfce-docker.git debian-xfce
cd debian-xfce
./install.sh        # detects/installs Docker and GNU Make when possible
./install.sh --run  # install then run `make all`
```

---
## Try it — quick commands

If you prefer to run interactively (see output and confirm prompts):

```sh
make build           # build the image and show status
make start           # start the container
make itest           # verify RDP server is reachable
make status          # display image and container info
```

---
### Make connect with parameters

The `make connect` target now supports passing screen resolution and credentials. Provide parameters on the make command line and they will be forwarded to the host RDP client wrapper (`container/scripts/connect.sh`).

Usage:

```sh
# Specify resolution, user and password (background mode)
make connect RES=1920x1080 USER=admin PASS=Retrieve_Generated_Password

# Use common laptop resolution (HD)
make connect RES=1366x768 USER=admin PASS=Retrieve_Generated_Password
```

Retrieve generated password
---------------------------

If you didn't supply a password via `XRDP_PASSWORD` or a mounted secret, the container entrypoint prints or writes the generated password to the container logs or to the mounted secrets path. To quickly inspect the last 200 log lines (and locate the generated password), run:

```sh
docker logs desktop --tail 200 || true
```

The `|| true` ensures the command exits successfully in scripts even if `docker logs` exits non-zero. If you mounted a file for the password (for example `/run/secrets/rdp_password`), prefer reading that file on the host instead of parsing logs.


Common resolutions
------------------

Here are common WIDTHxHEIGHT values you can pass via `RES=` to `make connect`.
Pick one that matches your display or testing target. The helper normalizes `1920X1080` to `1920x1080` automatically.

- `800x600`   — small / legacy (SVGA)
- `1024x768`  — common legacy desktop (XGA)
- `1280x720`  — 720p (HD)
- `1280x800`  — WXGA (some laptops)
- `1366x768`  — common laptop resolution (HD)
- `1440x900`  — WXGA+
- `1600x900`  — HD+
- `1680x1050` — WSXGA+
- `1920x1080` — 1080p (Full HD) — default target used by the container
- `1920x1200` — WUXGA
- `2560x1440` — 1440p (QHD)
- `3840x2160` — 4K (UHD) — may need more CPU/GPU and a capable client

Notes:

- The `RES` value should be WIDTHxHEIGHT (e.g. `1920x1080`). The script will normalize `1920X1080`.
- The Make target exports these environment variables for the helper script. The helper translates them for `xfreerdp` and `rdesktop`.
- By default, the command runs the client in the background and logs to `./container/nohup-connect.out`. To see client output interactively, run with `FOREGROUND=1` (I can add this if you want it to act differently by default).
- If no client is available the helper will print install hints and try to open an RDP URL via `xdg-open` or `remmina`.

---
### Connect via SSH tunnel (Advanced)

Use an SSH tunnel to securely forward the remote container’s RDP port to your local machine and then connect your local RDP client to localhost. Replace user@remote.host and ports as needed; prefer mounting a secret file (/run/secrets/rdp_password) over passing passwords via environment variables. Example (background, fail-fast if forwarding cannot be established):

Run it in the background (no remote shell)

Adds compression, exit-on-forward-failure, and runs in background (-f -N).
```sh
ssh -f -N -C -o ExitOnForwardFailure=yes -L 3389:localhost:3389 user@remote.host
```

Flags explained:

- -f : put ssh into background after authentication (run in background).
- -N : do not run a remote shell/command (useful for port forwarding only).
- -C : enable compression on the SSH connection.
- -o ExitOnForwardFailure=yes : make ssh exit if port forwarding cannot be established (fail fast).
- -L 33389:localhost:3389 : set up a local port forward — bind local port 33389 and forward connections to localhost:3389 on the remote side.
user@remote.host : replace with your SSH username and remote host (or IP).


---
## What you'll find here

- `Dockerfile` — builds the Debian + XFCE image used by `make build`.
- `Makefile` — convenient targets (build, start, stop, status, connect, itest, clean-logs, etc.).
  - `install.sh` — helper that detects and attempts to install Docker and GNU Make when missing. It also attempts to install xrdp packages when an RDP client/server is not present, which is useful for local integration tests. The script prints colored, emoji-enhanced status messages when run in a terminal; set `NO_COLOR=1` to disable color/emoji output.
- `container/` — runtime files copied into the image and host helpers:
  - `entrypoint.sh` — image entrypoint that starts supervisord and services
  - `xrdp-start.sh` — wrapper that launches xrdp and sesman in the container
  - `supervisord.conf` — supervisord config for services
  - `xstartup` — XFCE session startup script
  - `nohup-connect.out` — host-side log produced by `make connect` (ignored by git)
  - `scripts/` — host-side helpers:
  - `connect.sh` — launches a local RDP client to connect to the container
    - `clean-logs.sh` — rotate/cleanup `container/*.out` logs

- Quick checks and helpers:

```sh
make itest           # verify RDP server is reachable
make status          # display image and container info
make clean           # stop and delete container and remove image
make clean-logs      # rotate/prune logs (default KEEP=3)
```

---
## Installing a local RDP client (FreeRDP)

If you need an RDP client on your host for `make connect` or local testing, install FreeRDP (xfreerdp) using your platform package manager:

Debian/Ubuntu:
```sh
sudo apt update
sudo apt install -y freerdp2-x11
```

Fedora/CentOS (dnf/yum):
```sh
sudo dnf install -y freerdp
# or on older yum-based systems:
sudo yum install -y freerdp
```

Arch Linux:
```sh
sudo pacman -Sy --noconfirm freerdp
```

Alpine:
```sh
sudo apk add freerdp
```

macOS (Homebrew):
```sh
brew install freerdp
```

Windows: use Microsoft Remote Desktop or install FreeRDP builds separately (Chocolatey packages may not be available/complete).

---
## Notes & security

Important security note

- By default the RDP port is bound to `127.0.0.1:$(PORT)` so the desktop isn't exposed publicly and Local Area Network. The image exposes RDP on port $(PORT) and the container's default configuration is intended for local development and CI; if you run on a remote host, secure the service (use firewall rules, SSH tunnels, or configure xrdp authentication).


If Docker is present but the daemon isn't running, the script will offer to start it interactively. In non-interactive mode it won't start the daemon automatically — you'll need to run one of these manually:

```sh
# On most Linux systems with systemd
sudo systemctl start docker

# On older systems
sudo service docker start

# To let your user run docker without sudo
sudo usermod -aG docker $USER
# then re-login for the group change to take effect
```

---
## License

This project is provided under the MIT License. See the `LICENSE` file for details.
