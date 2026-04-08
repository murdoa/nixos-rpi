# NixOS Raspberry Pi image template

A minimal template for building NixOS images for Raspberry Pi boards, with first-class support for **Pi 3** and **Pi 4**.

## Supported boards

- Raspberry Pi 3 / 3B+
- Raspberry Pi 4
- Raspberry Pi Zero W (experimental)

## Build requirements

On NixOS hosts, enable binfmt for aarch64 builds:

```nix
{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
```

## Build images

### Pi 3

```bash
nix build .#packages.x86_64-linux.pi3-image
```

### Pi 4

```bash
nix build .#packages.x86_64-linux.pi4-image
```

### Pi 0 (experimental)

```bash
nix build .#packages.x86_64-linux.pi0-image
```

## Flashing

```bash
nix run .#flash-pi3 -- /dev/sdX
nix run .#flash-pi4 -- /dev/sdX
```

## Layout

- `hosts/` - top-level board configs
- `modules/` - reusable generic modules
- `boards/raspberry-pi/` - board-specific image/boot logic
- `examples/` - optional product-specific features

## Default login

- user: `nixos`
- password: `nixos`

Change that before shipping anything that touches the public internet. Obviously.
