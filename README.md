# nixos-rpi

NixOS image builders and reusable flake modules for Raspberry Pi boards.

You can use this repository in two ways:

- **as a standalone flake** — build and flash Raspberry Pi images directly from this repo
- **as a library flake** — import `lib.mkRpiSystem`, `lib.mkFlashApp`, and `nixosModules.*` from another flake

It currently targets Raspberry Pi boards that boot via the Raspberry Pi firmware + U-Boot + EFI/UKI path, with first-class support for **Pi 3B**, **Pi 3B+**, and **Pi 4**.

## What's in the box

- **Cross- and native-buildable NixOS images** for Raspberry Pi boards
- **Board-specific boot and image modules** for Pi 3B, Pi 3B+, Pi 4, and experimental Pi Zero W
- **Reusable flake library API**:
  - `lib.mkRpiSystem`
  - `lib.mkFlashApp`
  - `lib.mkImage`
  - `lib.mkHybridImage`
  - `lib.boards`
- **Host-side flash apps** with safety checks:
  - removable-device check
  - interactive confirmation
  - `/dev/disk/by-id/...` support
- **Pi 3 serial-console stabilization** for boot debugging:
  - explicit serial kernel parameters
  - `core_freq=250`
  - `enable_uart=1`
- **Optional silent serial boot mode** for deployments where UART is wired to external equipment and boot noise is forbidden

## Quick start

### Build images

```bash
# Pi 3B
nix build .#packages.x86_64-linux.pi3b-image

# Pi 3B+
nix build .#packages.x86_64-linux.pi3bplus-image

# Pi 4
nix build .#packages.x86_64-linux.pi4-image
```

Native image outputs are also available:

```bash
nix build .#packages.x86_64-linux.pi3b-image-native
nix build .#packages.x86_64-linux.pi3bplus-image-native
nix build .#packages.x86_64-linux.pi4-image-native
```

Legacy aliases remain:
- `pi3-image` → Pi 3B+
- `pi3-image-native` → Pi 3B+

### Flash images

```bash
# Cross-built image outputs
nix run .#flash-pi3b -- /dev/disk/by-id/...
nix run .#flash-pi3bplus -- /dev/disk/by-id/...
nix run .#flash-pi4 -- /dev/disk/by-id/...

# Native-built image outputs (still flashed from an x86_64 host)
nix run .#flash-pi3b-native -- /dev/disk/by-id/...
nix run .#flash-pi3bplus-native -- /dev/disk/by-id/...
nix run .#flash-pi4-native -- /dev/disk/by-id/...
```

Flash scripts are interactive and refuse non-removable devices.

Legacy aliases remain:
- `flash-pi3` → Pi 3B+
- `flash-pi3-native` → Pi 3B+

## Supported boards

| Board | Target arch | Status |
|---|---|---|
| Raspberry Pi 3B | `aarch64-linux` | supported |
| Raspberry Pi 3B+ | `aarch64-linux` | supported |
| Raspberry Pi 4 | `aarch64-linux` | supported |
| Raspberry Pi Zero W | `armv6l-linux` | experimental |

## Build hosts

| Build host | Supported |
|---|---|
| `x86_64-linux` | yes |
| `aarch64-linux` | yes |

On NixOS hosts, enable binfmt for `aarch64-linux` builds if needed:

```nix
{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
```

## Project structure

```text
├── flake.nix
├── flake.lock
├── README.md
├── lib/
│   ├── default.nix          # exported library API
│   ├── boards.nix           # board metadata
│   ├── mk-system.nix        # mkRpiSystem
│   └── flash-app.nix        # mkFlashApp
├── modules/
│   └── base.nix             # reusable base system defaults
├── boards/raspberry-pi/
│   ├── pi0-image.nix
│   ├── pi3-common-image.nix
│   └── pi4-image.nix
├── hosts/
│   ├── pi0.nix
│   ├── pi3.nix              # alias to pi3bplus
│   ├── pi3b.nix
│   ├── pi3bplus.nix
│   └── pi4.nix
└── examples/
    └── README.md
```

## Library usage

This flake exposes:

### `lib.mkRpiSystem`
Build a NixOS system for a given board.

Example from another flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rpi.url = "path:/path/to/nixos-rpi";
  };

  outputs = { self, nixpkgs, rpi, ... }: {
    nixosConfigurations.my-pi3b = rpi.lib.mkRpiSystem {
      buildSystem = "x86_64-linux";
      board = "pi3b";
      modules = [
        {
          networking.hostName = "my-pi3b";
          services.openssh.enable = true;
        }
      ];
    };
  };
}
```

### `lib.mkFlashApp`
Create a host-side flash app for an image output.

Example:

```nix
apps.x86_64-linux.flash-my-pi3b = rpi.lib.mkFlashApp {
  name = "flash-my-pi3b";
  image = self.packages.x86_64-linux.my-pi3b-image;
};
```

### `lib.mkImage`
Create the final image derivation for a `nixosConfiguration`, automatically applying the hybrid MBR post-processing required by boards that need it.

Example:

```nix
let
  myPi3b = rpi.lib.mkRpiSystem {
    buildSystem = "x86_64-linux";
    board = "pi3b";
    modules = [ ./configuration.nix ];
  };
in {
  packages.x86_64-linux.my-pi3b-image = rpi.lib.mkImage myPi3b;
}
```

### `lib.mkHybridImage`
Force hybrid-MBR post-processing for a `nixosConfiguration` image. Mostly useful if you're doing something custom and want the raw helper directly.

### `lib.boards`
Board metadata used by `mkRpiSystem`, including:
- target system
- default host module
- image naming
- hybrid MBR requirement

### `nixosModules`
Available exported modules:
- `base`
- `pi0-image`
- `pi3-common-image`
- `pi3`
- `pi3b`
- `pi3bplus`
- `pi4`
- `pi4-image`

This makes it possible to build the same logical system for multiple Pi boards by reusing a common module list and changing only `board = ...`.

## Boot path

### Pi 3 / Pi 4

Boot chain:

```text
Raspberry Pi firmware -> U-Boot -> EFI/systemd-boot -> UKI -> NixOS
```

### Pi 3 serial notes

Pi 3 boards need a little extra help for reliable serial console output. This repository includes Pi 3-specific serial stabilization:

- `console=ttyAMA0,115200`
- `earlycon=pl011,0x3f201000`
- `enable_uart=1`
- `core_freq=250`

These settings help avoid mini-UART clock drift during boot.

### Silent serial boot

For deployments where the UART pins are connected to another device and must stay quiet during boot, enable:

```nix
{
  hardware.raspberry-pi.silentSerialBoot.enable = true;
}
```

This reusable module centralizes the policy and board modules only provide board-specific serial metadata.

When enabled, it:

- suppresses kernel and initrd verbosity
- disables serial getty on the board console
- removes board-specific serial console kernel arguments
- emits a `cmdline.txt` with `console=null` and quiet/loglevel suppression

Exported module:

- `nixosModules.raspberry-pi-silent-boot`

## Default login

Default image credentials:

- **user:** `nixos`
- **password:** `nixos`

Change these before exposing the board to any network you do not control.

## Status

Current status:

- Pi 3B image support: implemented
- Pi 3B+ image support: implemented
- Pi 4 image support: implemented
- Pi 0 support: experimental
- library API (`lib.mkRpiSystem`, `lib.mkFlashApp`, `lib.mkImage`, `nixosModules`): implemented

Known caveats:

- Pi Zero support is still experimental
- Pi 3 and Pi 3B+ are handled as separate targets
- flash apps are host-side convenience wrappers, not full deployment tools

## Why this exists

Building Raspberry Pi NixOS images should not require pulling pieces from multiple repos or rediscovering board-specific boot details from scratch.
