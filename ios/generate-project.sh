#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen" >&2; exit 1; }
mkdir -p "$SCRIPT_DIR/Generated"
xcodegen generate --spec "$SCRIPT_DIR/project.yml" --project "$SCRIPT_DIR"
echo "Created: $SCRIPT_DIR/Fukura.xcodeproj"
