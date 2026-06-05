#!/usr/bin/env bash
# Apply `leo fmt` to all Leo programs in this directory
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROGRAMS=(freezelist compliant_token_template)

for prog in "${PROGRAMS[@]}"; do
  if [[ -d "$prog" ]]; then
    echo "Formatting $prog..."
    (cd "$prog" && leo fmt .)
  fi
done

echo "Done."
