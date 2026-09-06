#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
exec ./scripts/godot.sh --path "$PWD"
