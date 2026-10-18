#!/usr/bin/env bash
# Starts the Dart/Flutter MCP server for AI coding agents.
# Uses `dart` from PATH, otherwise falls back to the Nix dev shell.
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v dart >/dev/null 2>&1; then
  exec dart mcp-server "$@"
elif command -v nix >/dev/null 2>&1; then
  exec nix develop --command dart mcp-server "$@"
fi

echo "dart not found: install Flutter (see docs/development.md)" >&2
exit 1
