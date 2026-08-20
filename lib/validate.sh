#!/usr/bin/env bash

set -euo pipefail

validation_error() {
    printf 'VALIDATION ERROR: %s\n' "$*" >&2
    return 1
}

config_state() {
    local config="$1"
    local symbol="$2"

    if grep -q "^CONFIG_${symbol}=y$" "$config"; then
        printf 'y'
    elif grep -q "^CONFIG_${symbol}=m$" "$config"; then
        printf 'm'
    elif grep -q "^# CONFIG_${symbol} is not set$" "$config"; then
        printf 'n'
    else
        printf 'absent'
    fi
}

validate_disabled() {
    local config="$1"
    local symbol="$2"
    local state

    state="$(config_state "$config" "$symbol")"

    if [[ "$state" != "n" && "$state" != "absent" ]]; then
        validation_error \
            "CONFIG_${symbol} should be disabled, but resolved to '${state}'."
        return 1
    fi

    printf '    OK  CONFIG_%s disabled (%s)\n' "$symbol" "$state"
}

validate_enabled_bool() {
    local config="$1"
    local symbol="$2"
    local state

    state="$(config_state "$config" "$symbol")"

    if [[ "$state" != "y" ]]; then
        validation_error \
            "CONFIG_${symbol} should be enabled, but resolved to '${state}'."
        return 1
    fi

    printf '    OK  CONFIG_%s = y\n' "$symbol"
}

validate_enabled_any() {
    local config="$1"
    local symbol="$2"
    local state

    state="$(config_state "$config" "$symbol")"

    if [[ "$state" != "y" && "$state" != "m" ]]; then
        validation_error \
            "CONFIG_${symbol} should be enabled, but resolved to '${state}'."
        return 1
    fi

    printf '    OK  CONFIG_%s enabled as %s\n' "$symbol" "$state"
}

validate_preserved() {
    local baseline="$1"
    local config="$2"
    local symbol="$3"
    local before
    local after

    before="$(config_state "$baseline" "$symbol")"
    after="$(config_state "$config" "$symbol")"

    if [[ "$before" != "$after" ]]; then
        validation_error \
            "CONFIG_${symbol} changed unexpectedly: '${before}' -> '${after}'."
        return 1
    fi

    printf '    OK  CONFIG_%s preserved as %s\n' "$symbol" "$after"
}

validate_protected_symbol() {
    local tree="$1"
    local baseline="$2"
    local config="$3"
    local symbol="$4"
    local before

    before="$(config_state "$baseline" "$symbol")"

    if [[ "$before" == "y" || "$before" == "m" ]]; then
        validate_preserved "$baseline" "$config" "$symbol"
        return
    fi

    # Older/LTS kernels may predate a protected ThinkPad driver. That is not a
    # policy regression; there is nothing this builder can preserve. If the
    # symbol exists in the selected source but upstream left it disabled, fail
    # instead of silently claiming the facility is protected.
    if ! kconfig_symbol_exists "$tree" "$symbol"; then
        printf '    OK  CONFIG_%s unavailable in this kernel version\n' "$symbol"
        return 0
    fi

    if [[ "$before" != "y" && "$before" != "m" ]]; then
        validation_error \
            "ThinkPad allowlist requires CONFIG_${symbol}, but the normalized upstream baseline resolved to '${before}'."
        return 1
    fi
}

validate_profile_invariants() {
    local config="$1"
    local symbol

    for symbol in "${REQUIRE_ENABLED_BOOL[@]}"; do
        validate_enabled_bool "$config" "$symbol" || return 1
    done

    for symbol in "${REQUIRE_DISABLED[@]}"; do
        validate_disabled "$config" "$symbol" || return 1
    done
}

validate_kernel_policy() {
    local tree="$1"
    local baseline="$2"
    local config="$tree/.config"

    [[ -f "$baseline" ]] || {
        validation_error "Baseline config does not exist: $baseline"
        return 1
    }

    [[ -f "$config" ]] || {
        validation_error "Resolved config does not exist: $config"
        return 1
    }

    printf '==> Validating resolved kernel configuration...\n'

    # Portable profile invariants.
    validate_profile_invariants "$config" || return 1

    # Universal ThinkPad userspace/hardware contract. The current build host
    # is intentionally irrelevant; every listed facility must be enabled by
    # upstream and remain untouched by KernelForge.
    local symbol
    for symbol in "${PRESERVE_ENABLED[@]}"; do
        validate_protected_symbol "$tree" "$baseline" "$config" "$symbol" || return 1
    done

    # Some general laptop facilities are deliberate variant policy choices.
    # Preserve the normalized upstream state without requiring it to be on.
    for symbol in "${PRESERVE_BASELINE_STATE[@]}"; do
        validate_preserved "$baseline" "$config" "$symbol" || return 1
    done

    # General-purpose features are preserved by default and removed only after
    # the user explicitly answers no.
    case "${CPU_VENDOR:-unknown}" in
        intel)
            if [[ "${KEEP_KVM:-yes}" == "yes" ]]; then
                validate_preserved "$baseline" "$config" KVM_INTEL || return 1
            else
                validate_disabled "$config" KVM_INTEL || return 1
            fi

            if [[ "${KEEP_INTEL_TDX:-yes}" == "yes" ]]; then
                validate_preserved "$baseline" "$config" KVM_INTEL_TDX || return 1
            else
                validate_disabled "$config" KVM_INTEL_TDX || return 1
            fi
            ;;
        amd)
            if [[ "${KEEP_KVM:-yes}" == "yes" ]]; then
                validate_preserved "$baseline" "$config" KVM_AMD || return 1
            else
                validate_disabled "$config" KVM_AMD || return 1
            fi

            if [[ "${KEEP_AMD_SEV:-yes}" == "yes" ]]; then
                validate_preserved "$baseline" "$config" KVM_AMD_SEV || return 1
            else
                validate_disabled "$config" KVM_AMD_SEV || return 1
            fi
            ;;
    esac

    if [[ "${KEEP_NVME_FABRICS:-yes}" == "yes" ]]; then
        for symbol in NVME_FABRICS NVME_RDMA NVME_FC NVME_TCP; do
            validate_preserved "$baseline" "$config" "$symbol" || return 1
        done
    else
        for symbol in NVME_FABRICS NVME_RDMA NVME_FC NVME_TCP; do
            validate_disabled "$config" "$symbol" || return 1
        done
    fi

    if [[ "${KEEP_NVME_TARGET:-yes}" == "yes" ]]; then
        validate_preserved "$baseline" "$config" NVME_TARGET || return 1
    else
        validate_disabled "$config" NVME_TARGET || return 1
    fi

    validate_preserved "$baseline" "$config" BLK_DEV_NVME || return 1

    # Other vendors' host firmware/platform drivers are the first deliberately
    # removed hardware class. Consumer HID/USB devices are not included here.
    for symbol in "${DISABLE_NON_THINKPAD_PLATFORM[@]}"; do
        validate_disabled "$config" "$symbol" || return 1
    done

    printf '==> Kernel policy validation passed.\n'
}
