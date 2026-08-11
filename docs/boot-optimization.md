# Boot optimisation

## Baseline

Measured on the Raspberry Pi 3 DUT at `192.168.0.157` before optimisation:

- kernel image: 63,617,536 bytes
- initrd: 22,077,720 bytes
- kernel phase reported by systemd: 11.966 s
- userspace: 78.752 s
- firmware-to-first-kernel-message was approximately 16 s
- `dhcpcd.service`: 30.960 s despite static network configuration
- `systemd-journal-flush.service`: 13.531 s
- `systemd-journald.service`: 88.505 s while full DRM tracing was enabled

The logging delay was caused by `drm.debug=0x1ff`, `loglevel=7`, and
`ignore_loglevel`. The VC4 driver emitted messages for every Weston/Flutter DRM
operation.

## Platform-pruning result

Deployed and boot-tested on 2026-08-11:

- kernel image reduced from 63,617,536 to 44,526,080 bytes (30.0%)
- initrd reduced from 22,077,720 to 22,065,319 bytes
- systemd kernel phase reduced from 11.966 to 11.612 s
- userspace reduced from 78.752 to 11.983 s, primarily from removing DRM
  tracing, the DHCP timeout, and persistent journal replay
- total systemd-reported startup reduced from 90.718 to 23.595 s
- no failed units
- root MMC, USB Ethernet/SSH, VC4/V3D, DPI panel, Plymouth dependencies,
  touchscreen, Weston, and the Flutter kiosk all remained functional

The first `Linux version` timestamp moved only from 16.338 to 15.923 s despite
the 19 MB image reduction. Platform pruning therefore substantially improves
build/output size but only saved about 0.4 s in the pre-userspace path on this
SD card and firmware combination.

## Early splash result

The initial initrd listed the panel driver but omitted its `i2c_gpio` provider.
The ST7701 reset GPIO is supplied by a PCA9539 on that bus, so panel probing
deferred until stage two. HDMI and composite nodes also kept VC4's component
master waiting for stage-two dependencies even though only DPI is used.

After ordering the complete panel dependency chain in the initrd and disabling
the unused HDMI and VEC device-tree nodes:

- PCA9539 available: 16.448 s
- ST7701 initialized: 16.459 s
- VC4 initialized: 16.473 s
- DPI framebuffer available: 16.478 s

Previously the DPI framebuffer appeared at 21.254 s. The LCD graphics path is
now ready **4.776 seconds earlier**, only 48 ms after `/init` starts. Remaining
time before this point is firmware/kernel loading and cannot be addressed by
further initrd driver ordering.

## U-Boot autoboot experiment

The stock Raspberry Pi 3 U-Boot embedded environment used `bootdelay=2` and
`boot_targets=mmc usb pxe dhcp`. A board override now sets `bootdelay=0` while
keeping `ZERO_BOOTDELAY_CHECK`, standard distro boot, extlinux parsing, and all
boot targets. NixOS generation updates therefore remain unchanged.

The replacement U-Boot booted successfully, but the first Linux timestamp only
moved from 16.322 to 16.214 seconds, within normal boot variance. The apparent
two-second default delay is not materially present on this bootstd/extlinux
path. The dominant pre-kernel cost is loading the 44.5 MB uncompressed kernel
and 22 MB initrd from ext4, not U-Boot's autoboot countdown.

## Compressed extlinux kernels

The extlinux installer now creates a gzip-compressed kernel for every NixOS
generation and retains an uncompressed `nixos-default-raw` recovery entry for
the active generation. Generation discovery, initrds, DTBs, command lines and
cleanup otherwise follow the upstream builder.

The Raspberry Pi U-Boot defaults placed the decompression buffer at 32 MiB,
which was unsafe for this layout. U-Boot is patched to use a 256 MiB scratch
address with a 64 MiB compressed-input allowance. With that separation,
`booti` successfully boots the 18,359,596-byte gzip kernel instead of reading
the 44,526,080-byte raw Image.

The final compressed-default deployment booted repeatedly with the expected
NixOS generation, no failed units, working DPI/touch/network, and Weston. The
first Linux timestamp remained approximately 16.0 seconds, however, so kernel
compression produced no measurable boot-time improvement on this setup. Its
main benefit is reducing boot storage and I/O; the complexity should be weighed
against that modest practical value.

## Changes and staged experiments

Keep each stage independently bootable and benchmark it before proceeding.

1. Remove DRM debug logging, disable DHCP, and use a bounded volatile journal.
2. Keep the pinned mainline kernel but disable non-Raspberry-Pi ARM64 platforms.
3. Repair x86_64-to-aarch64 cross-compilation to shorten development builds.
4. Set `autoModules = false`, retaining the mainline ARM64 defconfig plus
   explicit NixOS and DUT requirements. Do not initially set `preferBuiltin`:
   built-ins enlarge the firmware-loaded kernel image.
5. Remove one optional subsystem per commit and boot-test it.
6. Only after the driver set is proven, test size optimisation and removal of
   unrelated generic facilities such as ACPI, EFI, kexec, hibernation, and NUMA.

The useful pattern from the Zynq project is:

```nix
linux = prev.linux.override {
  autoModules = false;
  preferBuiltin = false;
};
```

Nixpkgs' `autoModules = true` answers `m` for otherwise unspecified tristate
options. That creates hundreds of modules an appliance will never load and
substantially increases clean kernel build time. Nix kernel derivations are
clean builds, so configuration changes do not reuse object files.

The Zynq project also starts from a board defconfig, explicitly adds NixOS and
hardware requirements with `structuredExtraConfig`, exposes the resulting
`kernel.configfile` for review, and builds bespoke drivers out-of-tree.

## DUT hardware and required kernel support

Inventory captured from `lsmod`, sysfs driver bindings, mounts, DRM, network,
and input devices on 2026-08-11. A module being loaded is not sufficient proof
that the appliance needs it; required and optional groups are separated below.

### Boot and root filesystem

Required support, whether built-in or present in the initrd:

- MMC core and block: `mmc_block`, `rpmb_core`
- BCM2835 SD host (`sdhost-bcm2835`)
- SDHCI and `sdhci-iproc`
- partition parsing
- ext4 root filesystem
- devtmpfs, proc, sysfs, tmpfs and initrd support

The FAT filesystem is only needed when `/boot/firmware` is explicitly mounted;
it is configured `noauto` and is not part of normal boot.

### Early display and Plymouth

These must be available in the initrd for the earliest possible splash:

- `vc4`
- DRM core and KMS helpers
- `drm_exec`
- `drm_dma_helper`
- `drm_display_helper`
- `cec` (currently a VC4/display-helper dependency)
- `panel_sitronix_st7701` (out-of-tree)
- `drm_mipi_dbi`
- `spi_gpio`
- `spi_bitbang`
- `reset_gpio`
- `pwm_gpio`
- `pwm_bl`
- BCM2835 clock, mailbox, DMA, GPIO/pinctrl, PWM and firmware interfaces
- VC4 DPI, HVS, pixel valve, V3D and DRM components
- fixed regulators and PCA953x GPIO expander used by the panel overlay

The DUT exposes `/dev/dri/card1`, `/dev/dri/renderD128`, and `DPI-1` through
`vc4-drm`. HDMI is disabled by kernel parameter but VC4 currently still binds
its HDMI and audio-codec devices.

### Touch input

Required for the kiosk, but not required in the initrd:

- `hynitron_cst3240` (out-of-tree)
- `i2c_gpio`
- PCA953x GPIO expander
- input and evdev support

The panel appears as `Hynitron CST3240 Touchscreen` on I2C address `0x5a`.

### Wired networking and SSH

Required after root mount:

- DWC2 USB host
- USB hub support
- `usbnet`
- `smsc95xx`
- `smsc` PHY support
- IPv4 networking

The only physical network interface is USB Ethernet `enu1u1`, driven by
`smsc95xx`. Removing this path also removes our recovery mechanism, which would
be impressively stupid.

### Kiosk graphics

Required by Weston/Flutter:

- VC4 DRM/KMS stack listed above
- V3D rendering support
- dma-buf and sync primitives

### Loaded but apparently optional

Candidates for separate removal experiments:

- Wi-Fi: `brcmfmac`, `brcmutil`, `cfg80211`
- Bluetooth: `hci_uart`, `btbcm`, `btqca`, `bluetooth`, `ecdh_generic`, `ecc`
- camera/MMAL: `bcm2835_v4l2`, `bcm2835_mmal_vchiq`, `videobuf2_*`, `videodev`, `mc`
- analogue/HDMI audio: `snd_bcm2835`, `snd_soc_hdmi_codec`
- joystick/mouse compatibility: `joydev`, `mousedev`
- UIO: `uio_pdrv_genirq`, `uio`
- VLAN: `8021q`, `garp`, `mrp`, `stp`, `llc`
- firewall/netfilter stack: `nf_tables`, `nft_compat`, `nf_conntrack`, `x_tables`
- FUSE: `fuse`
- device mapper: `dm_mod`, `dax`

Before disabling firewall kernel support, set `networking.firewall.enable = false`
so NixOS does not request those modules. Wi-Fi, Bluetooth, camera and audio
should likewise be disabled at the NixOS module level before their kernel
options are removed.

### Useful but non-essential platform facilities

These are currently bound and cheap enough to defer until late optimisation:

- Raspberry Pi CPU frequency scaling
- thermal sensor and hardware monitor
- hardware RNG
- watchdog
- LEDs
- armv8 PMU

## Validation for every kernel experiment

1. Preserve the previous extlinux generation and ensure physical SD recovery is
   available.
2. Record kernel and initrd byte sizes.
3. Boot and confirm Plymouth appears.
4. Confirm `/` mounts and the system reaches `multi-user.target`.
5. Confirm `enu1u1` and SSH work.
6. Confirm `DPI-1`, `renderD128`, Weston and Flutter work.
7. Confirm touchscreen events arrive.
8. Capture `systemd-analyze time`, `critical-chain`, and failed units.
9. Compare loaded modules and sysfs driver bindings against this inventory.
