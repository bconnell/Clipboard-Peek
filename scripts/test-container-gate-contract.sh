#!/usr/bin/env bash
# Exercises the container gate's cheap, dependency-free fail-closed boundaries.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

bash -n scripts/container-release-gate.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

set +e
SOURCE_SHA=invalid bash scripts/container-release-gate.sh > "$tmp/invalid.log" 2>&1
invalid_status=$?
SOURCE_SHA=0123456789abcdef0123456789abcdef01234567 bash scripts/container-release-gate.sh > "$tmp/no-output.log" 2>&1
missing_status=$?
set -e

[[ "$invalid_status" != 0 ]] || { echo 'FAIL: invalid SHA was accepted' >&2; exit 1; }
[[ "$missing_status" != 0 ]] || { echo 'FAIL: missing output mount was accepted' >&2; exit 1; }
grep -q 'source commit is not an exact 40-character SHA' "$tmp/invalid.log"
grep -q 'output mount is missing' "$tmp/no-output.log"

for ignored in '.git' '.packages' 'artifacts'; do
  grep -qx "$ignored" .dockerignore || {
    echo "FAIL: $ignored is not excluded from build context" >&2
    exit 1
  }
done

echo 'Container gate shell syntax and negative boundary tests passed.'
