#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=/dev/null
source "$REPO_ROOT/profiles/features.conf"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/policy.sh"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

CPU_VENDOR="intel"
resolve_policy <<< $'\n\n\n\n' >/dev/null
[[ "$KEEP_KVM" == "yes" ]] || fail "Intel default did not preserve KVM."
[[ "$KEEP_INTEL_TDX" == "yes" ]] || fail "Intel default did not preserve TDX."
[[ "$KEEP_NVME_FABRICS" == "yes" ]] || fail "Default did not preserve NVMe Fabrics."
[[ "$KEEP_NVME_TARGET" == "yes" ]] || fail "Default did not preserve NVMe Target."

CPU_VENDOR="intel"
resolve_policy <<< $'n\nn\nn\nn\n' >/dev/null
[[ "$KEEP_KVM" == "no" ]] || fail "Intel opt-out did not remove KVM."
[[ "$KEEP_INTEL_TDX" == "no" ]] || fail "Intel opt-out did not remove TDX."
[[ "$KEEP_NVME_FABRICS" == "no" ]] || fail "Opt-out did not remove NVMe Fabrics."
[[ "$KEEP_NVME_TARGET" == "no" ]] || fail "Opt-out did not remove NVMe Target."

CPU_VENDOR="amd"
resolve_policy <<< $'\n\n\n\n' >/dev/null
[[ "$KEEP_KVM" == "yes" ]] || fail "AMD default did not preserve KVM."
[[ "$KEEP_AMD_SEV" == "yes" ]] || fail "AMD default did not preserve SEV."
[[ "$KEEP_NVME_FABRICS" == "yes" ]] || fail "AMD default did not preserve NVMe Fabrics."
[[ "$KEEP_NVME_TARGET" == "yes" ]] || fail "AMD default did not preserve NVMe Target."

printf 'Policy prompt tests passed.\n'
