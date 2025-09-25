# debian-xfce-docker

Lightweight Debian 12 + XFCE Docker image with TigerVNC — run a local desktop for testing, demos, and headless GUI tasks.

This repository packages a compact Debian 12 desktop (XFCE) inside a Docker image and exposes the session via TigerVNC. It's designed for quick local GUI testing, demos, and lightweight CI invocations where a graphical environment is needed.

[![Docker Build](https://img.shields.io/badge/docker-ready-brightgreen.svg)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

---
## Quick start (install Docker + make, then build)

1) If you don't already have Docker and GNU Make, use the bundled helper. It will try to detect and install what's missing:

```sh
./install.sh        # detects/installs Docker and GNU Make when possible
./install.sh --run  # install then run `make all`
```

2) If you already have the tools, build and run the image:

```sh
make all            # builds the Docker image and shows status
```

Tip: `make all` runs `make build` then `make status`.

---
## Try it — quick commands

Clone, install dependencies, build and run (non-interactive):

```sh
# clone the repo, then:
cd debian-xfce
./install.sh --yes --run   # attempts to install Docker + Make, then runs `make all`
```

If you prefer to run interactively (see output and confirm prompts):

```sh
./install.sh               # detect/install interactively
make all                   # build the image and show status
make start                 # start the container
make connect               # open a local VNC viewer (logs to ./container/nohup-connect.out)
```

Notes:
- Some install steps require `sudo` (package installs). If Docker is installed but the daemon isn't running, start it with `sudo systemctl start docker` or `sudo service docker start`.
- To disable colored/emoji output from `install.sh`, set `NO_COLOR=1` before running it.

---
## What you'll find here

- `Dockerfile` — builds the Debian + XFCE image used by `make build`.
- `Makefile` — convenient targets (build, start, stop, status, connect, itest, clean-logs, etc.).
- `install.sh` — helper that detects and attempts to install Docker and GNU Make when missing. It prints colored, emoji-enhanced status messages when run in a terminal; set `NO_COLOR=1` to disable color/emoji output.
- `container/` — runtime files copied into the image and host helpers:
  - `entrypoint.sh` — image entrypoint that starts supervisord and services
  - `vnc-start.sh` — prepares VNC password and launches the VNC server
  - `supervisord.conf` — supervisord config for services
  - `xstartup` — XFCE session startup script
  - `nohup-connect.out` — host-side log produced by `make connect` (ignored by git)
  - `scripts/` — host-side helpers:
    - `connect.sh` — launches a local VNC client to connect to the container
    - `clean-logs.sh` — rotate/cleanup `container/*.out` logs

---
## How to use (short)

- Build the image:

```sh
make build
```

- Start the container (binds VNC to localhost by default):

```sh
make start
```

- Quick checks and helpers:

```sh
make itest           # verify VNC server is reachable
make connect         # open a local viewer (logs to ./container/nohup-connect.out)
make clean-logs      # rotate/prune logs (default KEEP=3)
```

---
## Notes & security

Important security note

- By default the VNC port is bound to `127.0.0.1:$(PORT)` so the desktop isn't exposed publicly. This repository defaults to VNC without a password for convenience (the image sets `VNC_NO_PASSWORD=1`). That mode is convenient for local development and CI, but is insecure if exposed to untrusted networks.

- If you plan to publish this repository, run on a remote host, or otherwise expose the service, set a `VNC_PASSWORD`, bind the port to localhost only, or tunnel VNC over SSH/VPN. See `Makefile` and `container/vnc-start.sh` for configuration options.

---
## Running Firefox

Firefox ESR comes preinstalled. The simplest way to use it is from inside XFCE (via VNC): start the container, connect a viewer, and launch Firefox from the desktop menu or a terminal (`firefox-esr`).

If you prefer to start it from a shell in the container, use `docker exec` to get a shell in the running container and run `firefox-esr` — note that this approach depends on a DISPLAY/DBUS environment and is mainly useful for quick debugging.

---
## Installer notes (CI friendly)

The installer can run non-interactively with `--yes` / `-y` (handy in CI):

```sh
./install.sh --yes --run   # install Docker + make, then run `make all`
```

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
## Contributing

Contributions and issues are welcome — open a merge request or issue on the repo. If you add runtime artifacts (logs, caches), add them to `.gitignore`.

---
## License

This project is provided under the MIT License. See the `LICENSE` file for details.

Recommended repository topics: `docker`, `debian`, `xfce`, `vnc`, `tigervnc`, `desktop-in-docker`, `gui-testing`.
