#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
port="${UI_PORT:-3001}"

printf 'Serving the lightweight chat UI at http://127.0.0.1:%s\n' "$port"
printf 'Press Ctrl+C to stop it.\n'
exec python -m http.server "$port" --bind 127.0.0.1 --directory "$repo_root/ui"
