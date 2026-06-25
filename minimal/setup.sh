#!/usr/bin/env bash
#
# Run the Vance Anus --setup wizard against the compose-managed Mongo
# without keeping anus as a permanent service in this minimal stack.
#
# Pulls the anus image on first run, joins the existing `vance_default`
# network, sets the same secrets the brain uses, runs the interactive
# wizard, and exits.
#
# Usage:
#   ./setup.sh                  # interactive setup wizard
#   ./setup.sh --sudo "cmd"     # any other anus command (re-uses the
#                                 same one-shot pattern)
#
# Requires: `docker compose up -d` to have run (so the vance_default
# network and mongodb container exist) and a populated .env next to
# this script.

set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
    echo "✗ .env missing — copy .env.example to .env first." >&2
    exit 1
fi

# shellcheck disable=SC1091
set -a; source .env; set +a

NETWORK="${COMPOSE_PROJECT_NAME:-vance}_default"
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "✗ Docker network '$NETWORK' not found." >&2
    echo "  Start the stack first:  docker compose up -d" >&2
    exit 1
fi

MONGO_URI="mongodb://${MONGO_INITDB_ROOT_USERNAME:-root}:${MONGO_INITDB_ROOT_PASSWORD:-example}@mongodb:27017/${VANCE_MONGODB_DATABASE:-vance}?authSource=admin"
IMAGE="${VANCE_IMAGE_NAMESPACE:-mhus}/vance-anus:${IMAGE_TAG:-latest}"

# Default invocation is the setup wizard; any args override.
ARGS=("$@")
if [ ${#ARGS[@]} -eq 0 ]; then
    ARGS=(--setup)
fi

exec docker run --rm -it \
    --network "$NETWORK" \
    -e SPRING_PROFILES_ACTIVE=prod \
    -e VANCE_MONGODB_URI="$MONGO_URI" \
    -e VANCE_MONGODB_DATABASE="${VANCE_MONGODB_DATABASE:-vance}" \
    -e VANCE_ENCRYPTION_PASSWORD="${VANCE_ENCRYPTION_PASSWORD:-changeit}" \
    "$IMAGE" \
    "${ARGS[@]}"
