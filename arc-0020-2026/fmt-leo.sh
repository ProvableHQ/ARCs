#!/usr/bin/env bash
# Apply `leo fmt` to all Leo programs in this directory
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROGRAMS=(wrapped_credits wrapped_token_registry dummy_exchange token_registry)

for prog in "${PROGRAMS[@]}"; do
  if [[ -d "$prog" ]]; then
    echo "Formatting $prog..."
    (cd "$prog" && leo fmt .)
  fi
done

echo "Done."
