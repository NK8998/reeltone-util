#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || $1 != --yes ]]; then
  printf 'Usage: %s --yes\n' "$0" >&2
  printf 'Permanently delete all local ReelTone Auth and Reviews database data.\n' >&2
  exit 2
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
compose=(docker compose --project-name reeltone-local --env-file .env.local -f compose.yaml -f compose.local.yaml)

"${compose[@]}" build

printf 'Removing the local PostgreSQL volume and all Auth and Reviews data.\n'
"${compose[@]}" down --volumes
"${compose[@]}" up -d --wait --no-build

printf 'The local stack is ready with empty Auth and Reviews databases.\n'
