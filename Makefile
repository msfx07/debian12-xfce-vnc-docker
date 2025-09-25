# Makefile for building and managing the debian-xfce Docker image/container
# Usage: make <target> [VAR=value]
# Examples:
#   make build
#   make run VNC_PASSWORD=secret
#   make stop
#   make rebuild

IMAGE ?= debian12-xfce
CONTAINER ?= desktop
PORT ?= 5901
HOSTNAME ?= debian12-xfce
VNC_PASSWORD ?= secret
DOCKER ?= docker
VNC_CLIENT ?= vncviewer
# Build flags: set BUILD_NO_CACHE=1 to pass --no-cache to docker build
BUILD_NO_CACHE ?= 0
# SQUASH may require Docker experimental features; set BUILD_SQUASH=1 to pass --squash
BUILD_SQUASH ?= 0

.PHONY: help build start stop restart prune rebuild logs exec clean verify-bind
 
.PHONY: connect status

.PHONY: clean-logs
.PHONY: install-verify

.PHONY: itest
itest: ## Integration test: wait for VNC port to be ready on localhost:5901
	@echo "Waiting for VNC port $(PORT) on localhost..."
	@tries=0; \
	while [ $$tries -lt 30 ]; do \
	  if command -v nc >/dev/null 2>&1; then \
	    nc -z 127.0.0.1 $(PORT) >/dev/null 2>&1 && { echo "VNC port $(PORT) is reachable after $$tries seconds"; exit 0; } || true; \
	  else \
	    (</dev/tcp/127.0.0.1/$(PORT)) >/dev/null 2>&1 && { echo "VNC port $(PORT) is reachable after $$tries seconds"; exit 0; } || true; \
	  fi; \
	  tries=$$((tries+1)); sleep 1; \
	done; \
	echo "ERROR: VNC port $(PORT) did not become reachable"; exit 2

help: ## Show this help
	@awk 'BEGIN {FS = "#"} /^[-A-Za-z0-9_]+:.*##/ { printf "%-12s -%s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build the Docker image
	@echo "Building image $(IMAGE)..."
		@FLAGS=""; \
		if [ "$(BUILD_NO_CACHE)" = "1" ]; then FLAGS="$$FLAGS --no-cache"; fi; \
		if [ "$(BUILD_SQUASH)" = "1" ]; then \ 
			if $(DOCKER) build --help 2>/dev/null | grep -q "--squash"; then FLAGS="$$FLAGS --squash"; else echo "Warning: docker build does not support --squash on this host; skipping"; fi; \
		fi; \
		$(DOCKER) build $$FLAGS -t $(IMAGE) .

all: build status ## Build the image and show status
	@echo "Completed 'make all' (build + status)"


start: ## Start the container (will create it if missing). Use this as the single entrypoint to run the container.
	@echo "Starting container $(CONTAINER) (image: $(IMAGE))..."
	@PUBLISH=127.0.0.1:$(PORT):5901; \
	exists=`$(DOCKER) ps -a --filter "name=$(CONTAINER)" --format '{{.Names}}' | grep -w $(CONTAINER) || true`; \
	if [ -z "$$exists" ]; then \
	  $(DOCKER) run -d -p $$PUBLISH -e VNC_PASSWORD=$(VNC_PASSWORD) --name $(CONTAINER) --hostname $(HOSTNAME) $(IMAGE); \
	else \
	  current_ports=`$(DOCKER) ps -a --filter "name=$(CONTAINER)" --format '{{.Ports}}'`; \
	  if echo "$$current_ports" | grep -q "127.0.0.1:$(PORT)->5901/tcp"; then \
	    $(DOCKER) start $(CONTAINER); \
	  else \
	    echo "Container $(CONTAINER) exists but is not bound to 127.0.0.1:$(PORT). Recreating with loopback binding..."; \
	    -$(DOCKER) rm -f $(CONTAINER) >/dev/null 2>&1 || true; \
	    $(DOCKER) run -d -p $$PUBLISH -e VNC_PASSWORD=$(VNC_PASSWORD) --name $(CONTAINER) --hostname $(HOSTNAME) $(IMAGE); \
	  fi; \
	fi

stop: ## Stop and remove the container
	@echo "Stopping and removing $(CONTAINER)..."
	-$(DOCKER) stop $(CONTAINER) >/dev/null 2>&1 || true
	-$(DOCKER) rm $(CONTAINER) >/dev/null 2>&1 || true

restart: stop start ## Restart container

prune: ## Remove stopped containers, unused images, networks and volumes (DANGEROUS)
	@echo "Pruning Docker (containers, images, networks, volumes)..."
	$(DOCKER) system prune -af --volumes

rebuild: ## Rebuild image from scratch (stop container, remove image, build)
	@echo "Rebuilding image $(IMAGE)..."
	-$(DOCKER) stop $(CONTAINER) >/dev/null 2>&1 || true
	-$(DOCKER) rm $(CONTAINER) >/dev/null 2>&1 || true
	-$(DOCKER) rmi -f $(IMAGE) >/dev/null 2>&1 || true
		@FLAGS=""; \
		if [ "$(BUILD_NO_CACHE)" = "1" ]; then FLAGS="$$FLAGS --no-cache"; fi; \
		if [ "$(BUILD_SQUASH)" = "1" ]; then \ 
			if $(DOCKER) build --help 2>/dev/null | grep -q "--squash"; then FLAGS="$$FLAGS --squash"; else echo "Warning: docker build does not support --squash on this host; skipping"; fi; \
		fi; \
		$(DOCKER) build $$FLAGS -t $(IMAGE) .

logs: ## Follow container logs (supervisord output)
	$(DOCKER) logs -f $(CONTAINER)

exec: ## Exec a shell in the running container: make exec SHELL=/bin/bash
	@SHELL_BIN=${SHELL:-/bin/bash}; \
	$(DOCKER) exec -it $(CONTAINER) $$SHELL_BIN

connect: ## Launch a VNC client to connect to the container (wrapper script)
	@chmod +x ./container/scripts/connect.sh || true
	# Prefer connecting without a password by default (container often runs no-auth)
	@# Launch the client in the background using nohup so make exits immediately.
	@CLIENT_NO_PASS=1 nohup ./container/scripts/connect.sh $(PORT) > ./container/nohup-connect.out 2>&1 & \
	pid=$$!; sleep 0.05; \
	echo "Started VNC client (background) with pid $$pid; logs: ./container/nohup-connect.out"

status: ## Show image and container status for $(IMAGE) / $(CONTAINER)
	@echo "Checking image '$(IMAGE)'..."; \
	if $(DOCKER) images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -w "$(IMAGE)" >/dev/null 2>&1; then \
	  echo "Image exists:"; \
	  $(DOCKER) images --filter=reference=$(IMAGE) --format '  {{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}'; \
	else \
	  echo "Image '$(IMAGE)' not found"; \
	fi; \

	@echo; \
	@echo "Checking container '$(CONTAINER)'..."; \
	if $(DOCKER) ps -a --format '{{.Names}}' | grep -w "$(CONTAINER)" >/dev/null 2>&1; then \
	  echo "Container info:"; \
	  $(DOCKER) ps -a --filter "name=$(CONTAINER)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"; \
	  echo "Inspect info:"; \
	  $(DOCKER) inspect --format '  Name: {{.Name}}\n  State: {{.State.Status}}\n  Running: {{.State.Running}}\n  PID: {{.State.Pid}}\n  StartedAt: {{.State.StartedAt}}' $(CONTAINER) || true; \
	else \
	  echo "Container '$(CONTAINER)' not found"; \
	fi

clean: ## Stop and remove container and image
	-$(DOCKER) stop $(CONTAINER) >/dev/null 2>&1 || true
	-$(DOCKER) rm $(CONTAINER) >/dev/null 2>&1 || true
	-$(DOCKER) rmi -f $(IMAGE) >/dev/null 2>&1 || true
	@echo "Cleaned container and image (if they existed)."

clean-logs: ## Rotate/cleanup container/*.out logs (uses container/scripts/clean-logs.sh)
	@chmod +x ./container/scripts/clean-logs.sh || true
	@KEEP=${KEEP:-3} ./container/scripts/clean-logs.sh

install-verify: ## Run ./install.sh --yes and verify Docker daemon + make are available (CI friendly)
	@echo "Running install.sh in non-interactive mode...";
	@chmod +x ./install.sh || true;
	@./install.sh --yes || (echo "install.sh failed; see output" && exit 2);
	@echo "Verifying Docker daemon is responsive...";
	@docker info >/dev/null 2>&1 || (echo "ERROR: Docker daemon not accessible. Try: sudo systemctl start docker" && exit 3);
	@echo "Docker daemon is running";
	@command -v make >/dev/null 2>&1 || (echo "ERROR: make not found in PATH" && exit 4);
	@echo "GNU Make available:"; \
	make --version | head -n1 || true

verify-bind: ## Verify that the container port is bound to 127.0.0.1 and show docker inspect
	@echo "Container ports (docker ps):"; \
	$(DOCKER) ps --filter name=$(CONTAINER) --format '  {{.Names}}\t{{.Status}}\t{{.Ports}}'; \
	@echo; \
	@echo "NetworkSettings.Ports (docker inspect):"; \
	$(DOCKER) inspect --format '{{json .NetworkSettings.Ports}}' $(CONTAINER) 2>/dev/null || true; \
	@echo; \
	@echo "Host listening sockets (ss -tnlp) for port $(PORT):"; \
	(ss -tnlp 2>/dev/null || true) | grep -E ":$(PORT)\s" || echo "(no ss output or not listening on port $(PORT))"
