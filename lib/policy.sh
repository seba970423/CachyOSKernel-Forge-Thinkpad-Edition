#!/usr/bin/env bash

set -euo pipefail

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '==> %s\n' "$*"
}

ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local answer

    case "$default" in
        yes|no) ;;
        *) die "Invalid yes/no default: $default" ;;
    esac

    while true; do
        if [[ "$default" == "yes" ]]; then
            printf '%s [Y/n]: ' "$prompt"
        else
            printf '%s [y/N]: ' "$prompt"
        fi

        read -r answer

        if [[ -z "$answer" ]]; then
            [[ "$default" == "yes" ]]
            return
        fi

        case "$answer" in
            y|Y|yes|YES|Yes) return 0 ;;
            n|N|no|NO|No) return 1 ;;
            *) printf 'Please answer yes or no.\n' ;;
        esac
    done
}

resolve_virtualization_policy() {
    KEEP_KVM="yes"
    KEEP_INTEL_TDX="n/a"
    KEEP_AMD_SEV="n/a"

    if ask_yes_no \
        "Keep standard KVM virtualization support?" \
        "$DEFAULT_KEEP_KVM"
    then
        KEEP_KVM="yes"
    else
        KEEP_KVM="no"
    fi

    if [[ "$CPU_VENDOR" == "intel" ]]; then
        if ask_yes_no \
            "Keep Intel TDX support?" \
            "$DEFAULT_KEEP_INTEL_TDX"
        then
            KEEP_INTEL_TDX="yes"
        else
            KEEP_INTEL_TDX="no"
        fi
    elif [[ "$CPU_VENDOR" == "amd" ]]; then
        if ask_yes_no \
            "Keep AMD SEV support?" \
            "$DEFAULT_KEEP_AMD_SEV"
        then
            KEEP_AMD_SEV="yes"
        else
            KEEP_AMD_SEV="no"
        fi
    fi
}

resolve_nvme_policy() {
    if ask_yes_no \
        "Keep NVMe-over-Fabrics support?" \
        "$DEFAULT_KEEP_NVME_FABRICS"
    then
        KEEP_NVME_FABRICS="yes"
    else
        KEEP_NVME_FABRICS="no"
    fi

    if ask_yes_no \
        "Keep NVMe Target functionality?" \
        "$DEFAULT_KEEP_NVME_TARGET"
    then
        KEEP_NVME_TARGET="yes"
    else
        KEEP_NVME_TARGET="no"
    fi
}

resolve_policy() {
    resolve_virtualization_policy
    resolve_nvme_policy
}

print_policy_summary() {
    info "Resolved kernel policy:"
    printf '    Standard KVM:        %s\n' "$KEEP_KVM"
    printf '    Intel TDX:           %s\n' "$KEEP_INTEL_TDX"
    printf '    AMD SEV:             %s\n' "$KEEP_AMD_SEV"
    printf '    Target hardware:     universal ThinkPad allowlist\n'
    printf '    Graphics/Wi-Fi/I/O:  preserve ThinkPad allowlist\n'
    printf '    NVMe Fabrics:        %s\n' "$KEEP_NVME_FABRICS"
    printf '    NVMe Target:         %s\n' "$KEEP_NVME_TARGET"
}
