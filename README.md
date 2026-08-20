# KernelForge ThinkPad Edition

A laptop-oriented custom kernel builder for x86-64 ThinkPads running vanilla
Arch Linux or an Arch-based distribution. It uses the CachyOS kernel packaging
repository as upstream and applies a validated ThinkPad profile before optional
compilation and installation.

## Design contract

KernelForge ThinkPad Edition targets the ThinkPad product family, not the
hardware inventory of the machine performing the build.

- Do not break userspace.
- Preserve hardware used across Intel- and AMD-based ThinkPads.
- Preserve integrated and hybrid graphics, including Intel, AMD and NVIDIA.
- Preserve NVMe, SATA/AHCI, M.2 SATA, mSATA and USB storage foundations used
  by different ThinkPad generations.
- Preserve ACPI, battery, thermal, suspend, hibernation, lid, hotkey, docking,
  USB-C, Thunderbolt/USB4, audio, networking and input support.
- Preserve generic HID and consumer gaming controllers used with native games
  and emulators, including Xbox, PlayStation, Nintendo, Steam and generic
  USB/Bluetooth devices.
- Remove non-ThinkPad host platform and firmware drivers only when they have no
  plausible ThinkPad or attached-peripheral use. A subsystem is not removable
  merely because its most common use is on a server or desktop.

The captured T590 configuration is the first regression reference. It is one
member of the universal ThinkPad allowlist, not the outer boundary of support.

Some shared Lenovo foundations retain consumer-family names. In particular,
`IDEAPAD_LAPTOP` is protected because `LENOVO_YMC` depends on it, and Yoga/lap
mode firmware behaviour also exists on ThinkPads such as the T590.

The first deliberately removed class is host firmware/platform support for
other computer families: Surface, ASUS, Dell, Acer, MSI, Toshiba and similar
ACPI/WMI motherboard drivers. Vendor-named consumer HID, controller, USB and
Bluetooth drivers are separate and remain available. For example, removing a
Sony laptop platform driver does not remove Sony controller force feedback.

## Build host versus target

Hardware detection is printed for diagnostics. It does not prune kernel
support. A missing GPU, Wi-Fi adapter, NVMe controller or Thunderbolt controller
on the build host must never remove that support from the universal profile.

Native CPU optimization assumes the builder is run on the target ThinkPad.
Compiling on another CPU may produce a kernel unsuitable for the intended
machine even though the hardware allowlist itself remains universal.

## What the profile changes

The initial ThinkPad profile deliberately applies:

- native x86 CPU optimization;
- tickless-idle operation (`NO_HZ_IDLE`);
- interactive choices for KVM, Intel TDX or AMD SEV, NVMe-over-Fabrics and
  NVMe Target functionality.

Ordinary local NVMe support (`BLK_DEV_NVME`) and SATA/AHCI are always protected.
NVMe Fabrics and NVMe Target are preserved unless the user explicitly removes
them through their respective prompts.

Every general-purpose capability prompt defaults to `[Y/n]`. Pressing Enter
preserves the normalized upstream state. An explicit `n` authorizes KernelForge
to disable that capability and validate the resolved dependency state before
compilation.

## Safe custom naming

After selecting a kernel variant, both the full builder and dry-run ask whether
to keep its upstream package/kernel name or explicitly rename it. Pressing Enter
keeps the upstream name unchanged. Custom names accept 1–48 lowercase letters,
digits, `.`, `_`, `+` or `-`; the builder supplies the `linux-` prefix.

Everything in the ThinkPad contract is validated against the normalized
upstream configuration before compilation starts. Required drivers must be
enabled upstream as built-ins or modules and must remain unchanged after policy
application. Variant-defined facilities are also preserved without overriding
the selected kernel's deliberate defaults; notably, CachyOS Hardened ships with
hibernation disabled while the other tested variants retain it.

## Usage

`pciutils` is optional. When `lspci` is available, KernelForge prints a richer
diagnostic hardware summary; its absence never changes policy or blocks a
build.

KernelForge checks that its foundational build commands are available before
starting. During source preparation, `makepkg` offers to install any missing
package-specific dependencies through `pacman`.

Run the complete workflow:

```bash
git clone https://github.com/seba970423/CachyOSKernel-Forge-Thinkpad-Edition
cd CachyOSKernel-Forge-Thinkpad-Edition
./builder.sh
```

Run configuration preparation and validation without compiling or installing:

```bash
git clone https://github.com/seba970423/CachyOSKernel-Forge-Thinkpad-Edition
cd CachyOSKernel-Forge-Thinkpad-Edition
./builder.sh
```

Both workflows:

1. validate the ThinkPad profile;
2. display host diagnostics;
3. resolve the user-controlled general-capability policy;
4. clone the latest CachyOS kernel packaging repository;
5. select an upstream kernel variant;
6. optionally rename the selected kernel/package;
7. prepare its source tree;
8. normalize the upstream Kconfig baseline;
9. apply the ThinkPad profile and feature policy;
10. resolve Kconfig dependencies;
11. validate the final configuration.

The full builder then optionally compiles, optionally installs exactly the
packages produced by that build, and never reboots automatically.

Build work and compiler temporary files are placed below `/var/tmp`, avoiding
small tmpfs-backed `/tmp` mounts. Work trees are intentionally retained for
inspection.

## Project layout

```text
.
├── builder.sh
├── builder-dry-run.sh
├── lib
│   ├── build.sh
│   ├── hardware.sh
│   ├── kconfig.sh
│   ├── naming.sh
│   ├── pgp.sh
│   ├── policy.sh
│   ├── profile.sh
│   ├── upstream.sh
│   └── validate.sh
├── profiles
│   ├── features.conf
│   ├── thinkpad.conf
│   └── reference
│       ├── thinkpad-t590-cachyos-7.1.8-kernel.txt
│       └── thinkpad-t590-cachyos-7.1.8.config
└── tests
    ├── run-tests.sh
    ├── test-hardware-detection.sh
    ├── test-kernel-naming.sh
    ├── test-policy-prompts.sh
    ├── test-validation-paths.sh
    └── validate-reference.sh
```

## Safety behavior

- No compilation begins before configuration validation passes.
- Dry-run and full builds share the same source-preparation and Kconfig
  pipeline.
- Upstream source checksums are not bypassed.
- Missing upstream PGP keys are handled through the project key workflow.
- The prepared and validated source tree is reused with `makepkg --noextract`.
- Built package paths come from `makepkg --packagelist` and are recorded in a
  per-build manifest.
- Package installation is opt-in.
- Rebooting is always manual.

## Support model

- The builder targets ThinkPads running Arch Linux or an Arch-based
  distribution. IdeaPads and other laptop families are outside its support
  scope.
- Run the builder on the target ThinkPad because native CPU optimization makes
  the resulting kernel package specific to that machine's processor.
- The builder is portable across supported ThinkPads; a prebuilt kernel package
  produced on one machine is not a universal ThinkPad kernel.
- General-purpose capabilities are retained unless the user explicitly declines
  them through the corresponding prompt.
- Variant-defined defaults are respected. In particular, Hardened's disabled
  hibernation state is preserved rather than overridden.
- CachyOS applies its RT i915 compatibility patch to RT and RT-BORE variants;
  KernelForge preserves and validates the resulting Intel graphics support.
- Custom naming preserves the upstream name by default.
- Keep at least one known-good kernel installed until the new kernel has been
  boot-tested successfully.

## Tested status

Dry-run validation has passed for these CachyOS variants:

- `linux-cachyos`
- `linux-cachyos-bmq`
- `linux-cachyos-bore`
- `linux-cachyos-deckify`
- `linux-cachyos-eevdf`
- `linux-cachyos-hardened`
- `linux-cachyos-lts`
- `linux-cachyos-rc`
- `linux-cachyos-rt-bore`
- `linux-cachyos-server`

The RT-BORE workflow was tested end to end on a ThinkPad T590 with an Intel
Core i5-8265U and Intel UHD Graphics 620. The custom `linux-seba-rt-bore`
package compiled, installed through `pacman`, generated its initramfs and Limine
entry, and booted successfully as Linux `7.2.0-1-seba-rt-bore` with BORE and
`PREEMPT_RT` enabled. Intel graphics, NVMe storage, Intel Wi-Fi, audio, KVM and
the active ThinkPad platform drivers were confirmed working after boot.

## Current scope

This is the first ThinkPad-specific profile derived from the proven desktop
builder. The universal allowlist will be expanded conservatively as additional
ThinkPad generations and hardware combinations are audited. Absence from one
captured machine is never sufficient justification for removing support.
