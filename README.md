# vance-startup

The fastest way to run [Vance](https://vance.mhus.de) locally — a Docker
Compose stack that pulls prebuilt images from Docker Hub and brings up
MongoDB, the Brain (server) and the Web UI, plus an interactive
one-shot setup wizard for the first tenant + user + LLM provider.

## Requirements

- Docker 24+ with Compose v2 (i.e. `docker compose`, not `docker-compose`)
- ~2 GB free RAM
- Outbound HTTPS to Docker Hub (for image pulls) and to your LLM provider
  (Anthropic, OpenAI, Gemini, …)

## Quick start

```bash
git clone https://github.com/mhus/vance-startup.git
cd vance-startup
cp .env.example .env

# IMPORTANT: edit .env and change at least
#   VANCE_ENCRYPTION_PASSWORD
#   VANCE_INTERNAL_TOKEN
# before any non-local use.

# 1. Start the stack (MongoDB + Brain + Web UI).
docker compose up -d

# 2. First-time setup: create a tenant + user and configure an LLM provider.
#    This is an interactive one-shot wizard — answer the prompts, then it exits.
docker compose run --rm anus --setup
```

Then open <http://localhost:8080> in your browser and log in with the user
you just created in step 2.

### What the setup wizard asks for

Have these ready before running `--setup`:

- **Tenant name + title** — e.g. `acme` / `Acme Inc.`
- **First user** — login, display name, email, password
- **LLM provider** — Gemini, OpenAI or Anthropic
- **API key** for the chosen provider
- **Optional: Serper API key** for web research

The wizard writes everything to MongoDB and exits. Re-run it later to add
another tenant or user; existing entries are not overwritten unless you
explicitly change them.

To stop:

```bash
docker compose down            # keep data
docker compose down -v         # also delete MongoDB volume — full reset
```

## What this starts

| Service | Image | Port | Role |
|---|---|---|---|
| `mongodb` | `mongo:7.0` | 27017 | Persistence — think-processes, documents, settings |
| `brain` | `mhus/vance-brain` | 9990 | Vance Brain server (REST + WebSocket) |
| `face` | `mhus/vance-face` | 8080 | Web UI |

Data is kept in named Docker volumes (`vance_mongo-data`, `vance_brain-data`,
`vance_brain-logs`).

## Optional add-ons

The compose file ships three additional services, gated by Compose
[profiles](https://docs.docker.com/compose/profiles/) so they don't run
unless you ask for them.

### Redis (profile: `live`)

Required for multi-pod deployments that need cross-instance live-WS
fan-out. Not needed for a single-pod local stack.

```bash
docker compose --profile live up -d
# also set VANCE_REDIS_ENABLED=true in .env
```

### mongo-express (profile: `admin`)

A web UI for MongoDB at <http://localhost:9081> — handy for debugging.
Default login `admin` / `admin` (change in `.env`).

```bash
docker compose --profile admin up -d
```

### Anus admin shell (profile: `tools`)

Interactive Vance admin CLI for ongoing operations (tenant management,
user management, settings inspection). Requires a BCrypt password hash in
`VANCE_ANUS_PASSWORD_HASH`.

```bash
# Generate the hash once (replace 'mypassword'):
docker compose run --rm anus hash --plain mypassword
# Paste the output into .env as VANCE_ANUS_PASSWORD_HASH, then:
docker compose run --rm anus
```

For the first-time setup wizard (no password required), use
`docker compose run --rm anus --setup` — see [Quick start](#quick-start).

## Configuration

All knobs live in `.env`. The defaults are safe for `localhost` only —
**change passwords before exposing the stack to a network**. The most
important ones:

| Variable | Default | Notes |
|---|---|---|
| `VANCE_ENCRYPTION_PASSWORD` | `changeit` | Encrypts secrets at rest in MongoDB. Changing it later invalidates existing encrypted values. |
| `VANCE_INTERNAL_TOKEN` | `changeit-internal` | Shared secret for cross-pod internal calls. |
| `MONGO_INITDB_ROOT_PASSWORD` | `example` | MongoDB root password. |
| `IMAGE_TAG` | `latest` | Pin to a specific Vance release tag for reproducible deploys. |

## Upgrading

```bash
docker compose pull
docker compose up -d
```

If you've pinned `IMAGE_TAG`, bump it in `.env` first.

## Troubleshooting

- **Brain restarts on boot:** check `docker compose logs brain` — usually a
  MongoDB connection issue (wrong credentials in `.env`) or a port clash on
  9990.
- **Web UI loads but shows a connection error:** the Web UI talks to the
  Brain via the browser, not container-to-container. Make sure `BRAIN_PORT`
  is reachable from your host.
- **Port already in use:** override the affected `*_PORT` in `.env`.

## Documentation

- Full docs: <https://vance.mhus.de>
- Source: <https://github.com/mhus/vance>

## License

MIT — see [`LICENSE`](LICENSE).
