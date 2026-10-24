#!/usr/bin/env bash
#
# seed-demo.sh - build and run the demo-org seeder.
#
# It creates a demo trusted organisation and a small, self-consistent set of
# SIGNED events (org root, two certified providers at cert depth 1 and 2, two
# verified supplies, one emergency alert), re-verifies each one locally, and
# prints the org root PUBLIC key to install as a trusted org in the app.
#
# Backed by the Go program in cloud/cmd/seed-demo (the Go toolchain is the most
# reliable in this repo). See docs/DEMO_ORG_SETUP.md.
#
# Usage:
#   ./scripts/seed-demo.sh                         # build + verify locally (smoke)
#   ./scripts/seed-demo.sh --cloud URL --key KEY   # also push to a running cloud API
#   ./scripts/seed-demo.sh --seed <hex32>          # deterministic org root key
#
# Any extra args are passed straight through to the Go program.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT/cloud"

# No secrets are printed except PUBLIC keys. Private keys live only in memory.
exec go run ./cmd/seed-demo "$@"
