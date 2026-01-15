#!/usr/bin/env bash

set -euo pipefail

# Check if target is specified
if [ $# -eq 0 ]; then
    echo "Usage: $0 user@host"
    exit 1
fi

TARGET="$1" # user@host

# Extract hostname and check if target is reachable
HOST="${TARGET#*@}"
if ! ping -c 1 -W 1 "$HOST" >/dev/null 2>&1; then
    echo "Error: Cannot reach host $HOST"
    exit 1
fi

out=$(nix build --no-link --print-out-paths -vL .#nixosConfigurations.pi3-native.config.system.build.toplevel)
nix copy --no-check-sigs --to "ssh://$TARGET?compress=false" "$out"

ssh -t "$TARGET" "sudo nix-env -p /nix/var/nix/profiles/system --set '$out'"
ssh -t "$TARGET" "sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch"

