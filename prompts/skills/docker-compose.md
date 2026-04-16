---
name: docker-compose
description: >
  Use this skill whenever the user wants to create, edit, extend, or review a Docker Compose
  or Dockerfile setup. Triggers include: "docker-compose", "docker compose", "compose file",
  "Dockerfile", "containerize", "spin up X in Docker", "set up a service", or requests
  involving databases, message brokers, reverse proxies, automation tools (n8n, Grafana,
  Prometheus, Ollama, etc.). Also trigger when the user wants to add a new service to an
  existing compose file, fix an existing compose/Dockerfile, or asks about connecting
  containers together. Always trigger when the user shares an existing docker-compose.yml
  or Dockerfile for review or modification — even if they don't explicitly say "use your
  skill". If the user mentions Raspberry Pi + Docker, always use this skill. Apply all
  rules proactively without waiting to be asked.
---

# Docker Compose Skill

Produces production-quality Docker Compose configurations: pinned image versions, Raspberry Pi 5
compatibility when applicable, inter-service networking, custom runner images, launcher scripts,
and README documentation.

Also reads and modifies **existing** compose files and Dockerfiles — upgrading them to meet these
standards or extending them per user request.

---

## Workflow

### A. Reading an existing configuration

When the user provides or references an existing `docker-compose.yml` / `Dockerfile`:

1. **Read the file** — use the file-reading skill or `view` tool if it is on disk; parse it if
   provided inline.
2. **Audit against the rules below** — identify every violation:
   - `latest` or floating tags
   - Missing `platform:` when RPi5 is the target
   - Missing network definitions
   - No launcher script (if 3+ services)
   - No README or outdated README
   - Custom runner needed but missing
3. **Report findings first** — list what needs changing and why, briefly. Then ask: "Shall I apply
   all fixes?" or proceed directly if the user already asked you to fix/update.
4. **Apply changes** — produce the full updated file(s), not just diffs.

### B. Creating from scratch

Go straight to producing all required files per the rules below.

---

## Core Rules

### Rule 1 — Pin every image version, never use `latest`

Every `image:` field in compose and every `FROM` in a Dockerfile must use a specific, immutable tag.

**How to choose the right tag:**
- Use the most specific semver available: `postgres:16.3-alpine` not `postgres:16` not `postgres:latest`
- Prefer `-alpine` variants for smaller images; use `-slim` (Debian) when Alpine's musl libc causes
  build failures (common with numpy, pandas, scipy, torch)
- If you are not certain of the exact latest patch, pick the highest specific version you know and
  add a `# verify: https://hub.docker.com/r/<image>/tags` comment
- For private / custom images built in the same project, pin via a build arg or label, not `latest`

```yaml
# CORRECT
services:
  db:
    image: postgres:16.3-alpine       # PostgreSQL 16.3 — verify: hub.docker.com/r/postgres/tags

# WRONG — never do this
  db:
    image: postgres:latest
    image: postgres:16                # floating minor/patch
```

When **modifying an existing file** that uses `latest` or floating tags: replace every such tag with
a pinned version and add a comment with the Docker Hub URL.

---

### Rule 2 — Raspberry Pi 5 compatibility

Apply this rule when the user mentions RPi, Raspberry Pi, or ARM deployment, or when the project
is small/homelab enough that RPi is a plausible target — ask if unsure.

- Add `platform: linux/arm64` to every service
- Verify the chosen image tag has an `arm64` manifest (check the "OS/Arch" tab on Docker Hub)
- If an image has **no ARM64 variant**:
  - Suggest an alternative image that does support ARM64
  - Or provide a `Dockerfile` that builds from an ARM64-compatible base
  - Mention `qemu`-based emulation only as a last resort, with a performance warning
- For custom Dockerfiles, use ARM64-compatible base images

```yaml
services:
  app:
    image: node:20.14-alpine
    platform: linux/arm64             # Raspberry Pi 5 (ARM64/aarch64)
```

---

### Rule 3 — Custom runner images when needed

When a service needs capabilities beyond its base image (extra system packages, Python libraries,
build tools, etc.) — most common example: n8n + Python data science stack:

- Write a `Dockerfile` for the custom runner
- Place it at `docker/<service-name>/Dockerfile`
- Use multi-stage builds to keep the final image small
- Base choice:
  - Alpine (`-alpine`) when possible — smaller, faster
  - Debian Slim (`-slim`) when musl causes compilation failures (numpy, pandas, matplotlib, etc.)
- Pin the base image version in the Dockerfile too
- Reference it from compose with `build: context + dockerfile`

```
docker/
└── n8n-python/
    └── Dockerfile
```

```yaml
services:
  n8n:
    build:
      context: .
      dockerfile: docker/n8n-python/Dockerfile
    image: n8n-python:1.0.0           # local tag for caching
```

Example Dockerfile pattern (n8n + Python data science):

```dockerfile
# Stage 1: Python dependency builder
# Using Debian slim base — Alpine musl breaks numpy/pandas compilation
FROM python:3.12-slim AS python-builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Final n8n image with Python runtime injected
FROM n8nio/n8n:1.48.3
USER root

# Install Python runtime (minimal — no dev toolchain)
RUN apk add --no-cache python3 || true

# Copy pre-built Python packages from builder stage
COPY --from=python-builder /install /usr/local

USER node
```

---

### Rule 4 — Inter-service networking

Every multi-service compose file must have explicit network definitions:

- Define at least one named network (e.g., `app-network`)
- Assign services to networks explicitly — do not rely on the default implicit network
- Use service names as hostnames within the network (Docker DNS)
- Document connection strings in comments or README

```yaml
services:
  api:
    image: myapp:1.2.3
    networks:
      - app-network
    environment:
      DB_HOST: db           # Docker DNS — resolves to the db container
      DB_PORT: 5432

  db:
    image: postgres:16.3-alpine
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

When **modifying an existing file** that uses the implicit default network: add explicit network
definitions and `networks:` keys to each service.

---

### Rule 5 — Launcher script (3+ services)

When the compose file has 3 or more services, provide a launcher shell script:

- File: `start.sh` (and optionally `stop.sh`)
- Make it executable: note `chmod +x start.sh` in the README
- Handle common operations: start, stop, restart, logs, pull
- Keep all code and inline comments in English

```bash
#!/usr/bin/env bash
# start.sh — project stack launcher
set -euo pipefail

COMPOSE_FILE="docker-compose.yml"

usage() {
  echo "Usage: $0 [up|down|restart|logs|pull]"
  exit 1
}

case "${1:-up}" in
  up)
    echo "Starting all services..."
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  down)
    echo "Stopping all services..."
    docker compose -f "$COMPOSE_FILE" down
    ;;
  restart)
    docker compose -f "$COMPOSE_FILE" down
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  logs)
    docker compose -f "$COMPOSE_FILE" logs -f
    ;;
  pull)
    echo "Pulling pinned images..."
    docker compose -f "$COMPOSE_FILE" pull
    ;;
  *)
    usage
    ;;
esac
```

---

### Rule 6 — README.md

Every project must have a `README.md`. If one exists, add or update a **Docker** section.
If none exists, create the full file. Write it in English.

Required README sections for Docker setups:

```markdown
## Prerequisites
- Docker >= 24.x
- Docker Compose >= 2.x
- (RPi only) Raspberry Pi 5, 64-bit OS (Raspberry Pi OS Bookworm or Ubuntu 24.04 arm64)

## Services
| Service | Image | Port(s) | Description |
|---------|-------|---------|-------------|
| ...     | ...   | ...     | ...         |

## Quick Start
```bash
cp .env.example .env        # copy and edit environment variables
chmod +x start.sh
./start.sh                  # or: docker compose up -d
```

## Configuration
Document important environment variables, volume mounts, config file locations.

## Networking
Explain which ports are exposed to the host and how services connect internally.

## Updating Images
```bash
./start.sh pull
./start.sh restart
```
```

---

### Rule 7 — Language

All code, Dockerfiles, shell scripts, compose files, and inline comments must be in English.
README.md must also be in English.

When modifying existing files: translate any non-English comments during the edit pass.

---

## Output checklist

Before presenting output, verify every item:

- [ ] Every `image:` uses a pinned, specific version tag (no `latest`, no floating minor/major)
- [ ] `platform: linux/arm64` present on all services (if RPi5 target)
- [ ] Custom `Dockerfile` provided for services that need extra dependencies
- [ ] Named networks defined and assigned to all services
- [ ] `start.sh` provided (if 3+ services)
- [ ] `README.md` created or updated with Docker section
- [ ] All code, comments, and docs are in English
- [ ] Docker Hub verify-links added for any tags that are uncertain

---

## File layout reference

```
project/
├── docker-compose.yml
├── .env.example                  # template for required environment variables
├── start.sh                      # launcher script (if 3+ services)
├── README.md
└── docker/
    └── <service-name>/
        └── Dockerfile            # custom runner image (if needed)
```
