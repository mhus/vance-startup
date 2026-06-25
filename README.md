# vance-startup

The fastest way to run [Vance](https://vance.mhus.de) locally — Docker
Compose stacks that pull prebuilt images from Docker Hub and bring up
MongoDB, the Brain (server) and the Web UI, plus an interactive
one-shot setup wizard for the first tenant + user + LLM provider.

> [!WARNING]
> **Beta.** Vance is in active development. APIs, data model, configuration keys and engine behaviour can change between releases. Suitable for hands-on experimentation and early adopters; not yet hardened for unattended production use. Pin `IMAGE_TAG` in `.env` to a specific release before depending on a stack.

## Two variants

Pick the subdirectory that matches what you want to run. Each is a
self-contained Docker Compose stack.

| Variant | What's in it | When to pick |
|---|---|---|
| [`minimal/`](minimal/) | MongoDB + Brain + Web UI. Setup wizard runs as a one-shot via `./setup.sh`. | **Default for local installs.** Smallest possible footprint. Live-WS cross-pod features are off — single-pod doesn't need them. |
| [`live/`](live/) | The above + Redis (live features) + mongo-express (debug) + Anus REPL (admin). | Pick this if you want to exercise the live features (multi-tab presence, `documents.changed` push, cross-pod fan-out) or want the debug / admin tooling on tap. |

The workflow below applies to both; just `cd` into the variant you
chose.

## Requirements

- Docker 24+ with Compose v2 (`docker compose`, not `docker-compose`)
- ~2 GB RAM for `minimal/`, ~2.5 GB for `live/`
- Outbound HTTPS to Docker Hub (image pulls) and to your LLM provider
  (Anthropic, OpenAI, Gemini, …)

## Quick start

```bash
git clone https://github.com/mhus/vance-startup.git
cd vance-startup/minimal      # or: cd vance-startup/live
cp .env.example .env

# IMPORTANT: edit .env and change at least
#   VANCE_ENCRYPTION_PASSWORD
#   VANCE_INTERNAL_TOKEN
# before any non-local use.

# 1. Start the stack.
docker compose up -d

# 2. First-time setup: create a tenant + user and configure an LLM provider.
#    Interactive one-shot wizard — answer the prompts, then it exits.
./setup.sh                    # minimal/
# OR (in the live/ variant, where anus ships as a compose service):
docker compose run --rm anus --setup
```

Then open <http://localhost:8080> in your browser and log in with the
user you just created in step 2.

### What the setup wizard asks for

Have these ready before running the wizard:

- **Tenant name + title** — e.g. `acme` / `Acme Inc.`
- **First user** — login, display name, email, password
- **LLM provider** — Gemini, OpenAI or Anthropic
- **API key** for the chosen provider
- **Optional: Serper API key** for web research

The wizard writes everything to MongoDB and exits. Re-run it later to
add another tenant or user; existing entries are not overwritten
unless you explicitly change them.

### Choosing a model

Vance is an agentic system — the model spends a lot of tokens reasoning,
calling tools and writing back. Models that look fine in a chat UI can
collapse under that load. Rough current picture (mid-2026):

| Model | Verdict |
|---|---|
| **GLM-5.2** | **Top recommendation.** Strong tool-use, long context, no licensing friction for agentic workloads. |
| **DeepSeek V4** | Strong choice. Comparable quality to GLM-5.2, very competitive pricing. |
| **Gemini 3.x Pro / Flash** | Solid. Flash is good for the fast-tier alias, Pro for analyze/deep. Wizard preset. **Stick to 3.x — 2.5 is shaky under agentic load.** |
| **OpenAI GPT-4o / o-series** | Solid. Wizard preset. |
| **Anthropic Claude** | Wizard preset, **but read Anthropic's Usage Policy and Commercial Terms first** — they impose restrictions on autonomous-agent use cases that some Vance workflows fall under. Not recommended for unattended production agents unless you've confirmed your use case is covered. |
| **Gemma 4** | The realistic minimum. Works, but expect occasional tool-call failures and weaker long-context reasoning. Use only if you have a hard self-hosting requirement. |
| **Qwen 3.5** | **Not recommended.** Inconsistent tool-call behaviour and instruction-following under Vance's load patterns. |

The wizard ships presets for **Gemini, OpenAI and Anthropic**. For
**GLM-5.2, DeepSeek and self-hosted models** (Gemma via Ollama etc.),
finish the wizard with any provider, then switch the active provider
in the Web UI under Settings → AI, or pre-seed it with
`confidential/init-settings.yaml` (see source repo).

To stop:

```bash
docker compose down            # keep data
docker compose down -v         # also delete MongoDB volume — full reset
```

## What this starts

| Service | Image | Port | `minimal/` | `live/` |
|---|---|---|---|---|
| `mongodb` | `mongo:7.0` | 27017 | ✓ | ✓ |
| `brain` | `mhus/vance-brain` | 9990 | ✓ | ✓ |
| `face` | `mhus/vance-face` | 8080 | ✓ | ✓ |
| `redis` | `redis:7-alpine` | 6379 | — | ✓ |
| `mongo-express` (profile: `admin`) | `mongo-express:1.0` | 9081 | — | opt-in |
| `anus` (profile: `tools`) | `mhus/vance-anus` | — | — | opt-in |

In `minimal/`, the setup wizard runs via `./setup.sh` which spawns
`vance-anus` as a one-shot `docker run` against the existing compose
network — anus is not kept as a permanent service.

Data is kept in named Docker volumes (`vance_mongo-data`,
`vance_brain-data`, `vance_brain-logs`; `vance_redis-data` in `live/`).

## live/ — opt-in profiles

The `live/` variant defines two extra services gated by Compose
[profiles](https://docs.docker.com/compose/profiles/) so they don't run
unless you ask.

### mongo-express (profile: `admin`)

A web UI for MongoDB at <http://localhost:9081> — handy for debugging.
Default login `admin` / `admin` (change in `.env`).

```bash
docker compose --profile admin up -d
```

### Anus admin shell (profile: `tools`)

Interactive Vance admin CLI for ongoing operations (tenant management,
user management, settings inspection). Requires a BCrypt password hash
in `VANCE_ANUS_PASSWORD_HASH`.

```bash
# Generate the hash once (replace 'mypassword'):
docker compose run --rm anus hash --plain mypassword
# Paste the output into .env as VANCE_ANUS_PASSWORD_HASH, then:
docker compose run --rm anus
```

For the first-time setup wizard (no password required), use
`docker compose run --rm anus --setup` (or the `./setup.sh` wrapper
in `minimal/`) — see [Quick start](#quick-start).

## Configuration

All knobs live in the variant's `.env`. Defaults are safe for `localhost`
only — **change passwords before exposing the stack to a network**.
The most important ones:

| Variable | Default | Notes |
|---|---|---|
| `VANCE_ENCRYPTION_PASSWORD` | `changeit` | Encrypts secrets at rest in MongoDB. Changing it later invalidates existing encrypted values. |
| `VANCE_INTERNAL_TOKEN` | `changeit-internal` | Shared secret for cross-pod internal calls. |
| `MONGO_INITDB_ROOT_PASSWORD` | `example` | MongoDB root password. |
| `IMAGE_TAG` | `latest` | Pin to a specific Vance release tag for reproducible deploys. |

## Switching variants

If you've started with `minimal/` and want to try `live/` later:

```bash
cd ../minimal
docker compose down              # stop the minimal stack (keeps volumes)
cd ../live
cp ../minimal/.env .env          # carry your secrets over
docker compose up -d             # MongoDB volume is shared (same `name: vance`)
```

Both variants use the same Compose project name (`vance`), so MongoDB
data persists across the switch. Only Redis state is variant-specific
(and is fine to recreate — ephemeral by design).

## Upgrading

```bash
docker compose pull
docker compose up -d
```

If you've pinned `IMAGE_TAG`, bump it in `.env` first.

## Troubleshooting

- **Brain restarts on boot:** check `docker compose logs brain` — usually
  a MongoDB connection issue (wrong credentials in `.env`) or a port
  clash on 9990.
- **Web UI loads but shows a connection error:** the Web UI talks to the
  Brain via the browser, not container-to-container. Make sure
  `BRAIN_PORT` is reachable from your host.
- **Port already in use:** override the affected `*_PORT` in `.env`.
- **`./setup.sh` complains the network doesn't exist:** run
  `docker compose up -d` first so the `vance_default` network is
  created.
- **Live variant boots without Redis pings:** `docker compose logs brain`
  should show `Redis connection established at redis://redis:6379` near
  the start; if it doesn't, the brain fell back to in-memory and live
  features won't fan out. Check `VANCE_REDIS_URI` and that Redis is
  healthy.

## Documentation

- Full docs: <https://vance.mhus.de>
- Source: <https://github.com/mhus/vance>

## License

MIT — see [`LICENSE`](LICENSE).
