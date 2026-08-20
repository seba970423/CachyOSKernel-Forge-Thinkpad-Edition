#!/usr/bin/env bash

# Kernel Kconfig application and verification layer.
#
# Expected inputs:
#   KEEP_KVM
#   KEEP_INTEL_TDX
#   KEEP_AMD_SEV
#   KEEP_NVME_FABRICS
#   KEEP_NVME_TARGET

kconfig_require_tree() {
    local tree="$1"

    [[ -d "$tree" ]] || {
        echo "ERROR: Kernel source tree does not exist: $tree" >&2
        return 1
    }

    [[ -x "$tree/scripts/config" ]] || {
        echo "ERROR: Kernel scripts/config not found or not executable." >&2
        return 1
    }

    [[ -f "$tree/Makefile" ]] || {
        echo "ERROR: Kernel Makefile not found." >&2
        return 1
    }

    [[ -f "$tree/.config" ]] || {
        echo "ERROR: Kernel .config not found." >&2
        return 1
    }

    return 0
}

kconfig_enable() {
    local tree="$1"
    local symbol="$2"

    "$tree/scripts/config" --file "$tree/.config" --enable "$symbol"
}

kconfig_disable() {
    local tree="$1"
    local symbol="$2"

    "$tree/scripts/config" --file "$tree/.config" --disable "$symbol"
}

kconfig_symbol_exists() {
    local tree="$1"
    local symbol="$2"

    grep -RqsE \
        "^[[:space:]]*(menu)?config[[:space:]]+${symbol}([[:space:]]|$)" \
        "$tree"
}

kconfig_require_symbol() {
    local tree="$1"
    local symbol="$2"

    if ! kconfig_symbol_exists "$tree" "$symbol"; then
        echo "ERROR: CONFIG_${symbol} does not exist in this kernel source tree." >&2
        return 1
    fi

    return 0
}

kconfig_disable_if_present() {
    local tree="$1"
    local symbol="$2"

    if kconfig_symbol_exists "$tree" "$symbol"; then
        kconfig_disable "$tree" "$symbol"
    fi
}


kconfig_apply_profile() {
    local tree="$1"

    kconfig_require_tree "$tree" || return 1

    # --- Processor optimization profile ---

    case "${PROCESSOR_OPT:-}" in
        native)
            kconfig_require_symbol "$tree" X86_NATIVE_CPU || return 1
            kconfig_enable "$tree" X86_NATIVE_CPU || return 1
            ;;
        *)
            echo "ERROR: Unsupported PROCESSOR_OPT: ${PROCESSOR_OPT:-unset}" >&2
            return 1
            ;;
    esac

    # --- Scheduler tick profile ---

    case "${TICKRATE:-}" in
        idle)
            kconfig_require_symbol "$tree" NO_HZ_IDLE || return 1
            kconfig_require_symbol "$tree" NO_HZ_FULL || return 1
            kconfig_require_symbol "$tree" HZ_PERIODIC || return 1

            kconfig_enable "$tree" NO_HZ_IDLE || return 1
            kconfig_disable "$tree" NO_HZ_FULL || return 1
            kconfig_disable "$tree" HZ_PERIODIC || return 1
            ;;
        full)
            kconfig_require_symbol "$tree" NO_HZ_FULL || return 1
            kconfig_enable "$tree" NO_HZ_FULL || return 1
            ;;
        periodic)
            kconfig_require_symbol "$tree" HZ_PERIODIC || return 1
            kconfig_enable "$tree" HZ_PERIODIC || return 1
            ;;
        *)
            echo "ERROR: Invalid TICKRATE: ${TICKRATE:-unset}" >&2
            return 1
            ;;
    esac

    return 0
}

kconfig_apply_policy() {
    local tree="$1"

    kconfig_require_tree "$tree" || return 1

    # --- User-controlled general-purpose virtualization ---

    if [[ "${KEEP_KVM:-yes}" == "no" ]]; then
        case "${CPU_VENDOR:-unknown}" in
            intel)
                kconfig_require_symbol "$tree" KVM_INTEL || return 1
                kconfig_disable "$tree" KVM_INTEL || return 1
                ;;
            amd)
                kconfig_require_symbol "$tree" KVM_AMD || return 1
                kconfig_disable "$tree" KVM_AMD || return 1
                ;;
        esac
    fi

    if [[ "$CPU_VENDOR" == "intel" && "${KEEP_INTEL_TDX:-yes}" == "no" ]]; then
        kconfig_require_symbol "$tree" KVM_INTEL_TDX || return 1
        kconfig_disable "$tree" KVM_INTEL_TDX || return 1
    fi

    if [[ "$CPU_VENDOR" == "amd" && "${KEEP_AMD_SEV:-yes}" == "no" ]]; then
        kconfig_require_symbol "$tree" KVM_AMD_SEV || return 1
        kconfig_disable "$tree" KVM_AMD_SEV || return 1
    fi

    # --- User-controlled specialized NVMe roles ---

    local symbol
    if [[ "${KEEP_NVME_FABRICS:-yes}" == "no" ]]; then
        for symbol in NVME_FABRICS NVME_RDMA NVME_FC NVME_TCP; do
            kconfig_require_symbol "$tree" "$symbol" || return 1
            kconfig_disable "$tree" "$symbol" || return 1
        done
    fi

    if [[ "${KEEP_NVME_TARGET:-yes}" == "no" ]]; then
        kconfig_require_symbol "$tree" NVME_TARGET || return 1
        kconfig_disable "$tree" NVME_TARGET || return 1
    fi

    # CONFIG_BLK_DEV_NVME is never changed by these optional policies.

    # --- Non-ThinkPad host platform drivers ---

    # These are motherboard firmware interfaces for other computer families,
    # not detachable HID or USB peripherals made by those vendors.
    for symbol in "${DISABLE_NON_THINKPAD_PLATFORM[@]}"; do
        kconfig_disable_if_present "$tree" "$symbol" || return 1
    done

    return 0
}
