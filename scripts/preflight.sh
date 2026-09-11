#!/usr/bin/env bash
# Checks that the CLI tools required by this repo are installed.
set -uo pipefail

missing=0

check() {
  local bin="$1" install_hint="$2"
  if command -v "$bin" >/dev/null 2>&1; then
    echo "✓ $bin found ($(command -v "$bin"))"
  else
    echo "✗ $bin not found - install with: $install_hint"
    missing=1
  fi
}

check task      "brew install go-task"
check terraform "brew install terraform"
check kind      "brew install kind"
check kubectl   "brew install kubectl"
check helm      "brew install helm"
check deck      "brew install kong/deck/deck"
check docker    "brew install --cask docker (or colima/orbstack)"
check jq        "brew install jq"
check curl      "brew install curl"

# docker daemon reachability (kind needs a running container runtime)
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "✓ docker daemon is reachable"
  else
    echo "✗ docker CLI found but daemon is not reachable - start Docker/Colima/OrbStack"
    missing=1
  fi
fi

if [ "$missing" -ne 0 ]; then
  echo ""
  echo "Missing prerequisites - install the above before running 'task up'"
  exit 1
fi

echo ""
echo "All prerequisites satisfied."
