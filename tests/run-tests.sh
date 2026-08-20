#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

bash -n \
    "$REPO_ROOT/builder.sh" \
    "$REPO_ROOT/builder-dry-run.sh" \
    "$REPO_ROOT"/lib/*.sh \
    "$SCRIPT_DIR"/*.sh

"$SCRIPT_DIR/validate-reference.sh"
"$SCRIPT_DIR/test-hardware-detection.sh"
"$SCRIPT_DIR/test-policy-prompts.sh"
"$SCRIPT_DIR/test-kernel-naming.sh"
"$SCRIPT_DIR/test-validation-paths.sh"

printf 'All KernelForge ThinkPad Edition tests passed.\n'
