{ lib, config, pkgs, modulesPath, ... }:
let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
  ukiFile = config.system.boot.loader.ukiFile;
  efiSource = "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
  firmwareSource = "${pkgs.raspberrypifw}/share/raspberrypi/boot";
  uBootSource = "${pkgs.ubootRaspberryPiZero}/u-boot.bin";
  configTxt = pkgs.writeText "config.txt" ''
    [pi0]
    kernel=u-boot.bin
    disable_overscan=1

    [all]
    enable_uart=1
    avoid_warnings=1
  '';

  espContents = {
    "/".source = firmwareSource;
    "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source = efiSource;
    "/EFI/Linux/${ukiFile}".source = "${config.system.build.uki}/${ukiFile}";
    "/u-boot.bin".source = uBootSource;
    "/config.txt".source = configTxt;
    "/cmdline.txt".source = config.hardware.raspberry-pi.boot.cmdlineFile;
  };

  installBootLoader = pkgs.writeShellScript "install-raspberry-pi-boot-partition" ''
    set -euo pipefail

    if [ "$#" -lt 1 ]; then
      echo "usage: $0 <system-toplevel>" >&2
      exit 1
    fi

    toplevel="$1"
    boot_mount=${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint}
    tmp="$(${pkgs.coreutils}/bin/mktemp -d -t raspberry-pi-boot.XXXXXX)"
    trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT

    if ! mountpoint -q "$boot_mount"; then
      echo "error: $boot_mount is not mounted" >&2
      exit 1
    fi

    bootspec_json="$toplevel/boot.json"
    if [ ! -f "$bootspec_json" ]; then
      echo "error: missing bootspec at $bootspec_json" >&2
      exit 1
    fi

    kernel_source="$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".kernel // empty' "$bootspec_json")"
    initrd_source="$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".initrd // empty' "$bootspec_json")"
    kernel_params="$(${pkgs.jq}/bin/jq -r '([."org.nixos.bootspec.v1".init | "init=" + .] + (."org.nixos.bootspec.v1".kernelParams // [])) | join(" ")' "$bootspec_json")"
    label="$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".label // "NixOS"' "$bootspec_json")"

    if [ -z "$kernel_source" ] || [ "$kernel_source" = "null" ]; then
      echo "error: missing kernel path in $bootspec_json" >&2
      exit 1
    fi

    kernel_basename="$(basename "$kernel_source")"
    kernel_store_dir="$(basename "$(dirname "$kernel_source")")"
    if [ "$kernel_basename" = "$kernel_store_dir" ]; then
      kernel_target="EFI/nixos/''${kernel_basename}.efi"
    else
      kernel_target="EFI/nixos/''${kernel_store_dir}-''${kernel_basename}.efi"
    fi

    initrd_target=""
    if [ -n "$initrd_source" ] && [ "$initrd_source" != "null" ]; then
      initrd_basename="$(basename "$initrd_source")"
      initrd_store_dir="$(basename "$(dirname "$initrd_source")")"
      if [ "$initrd_basename" = "$initrd_store_dir" ]; then
        initrd_target="EFI/nixos/''${initrd_basename}.efi"
      else
        initrd_target="EFI/nixos/''${initrd_store_dir}-''${initrd_basename}.efi"
      fi
    fi

    mkdir -p "$tmp/EFI/BOOT" "$tmp/EFI/nixos" "$tmp/loader/entries"
    cp -r --no-preserve=mode,ownership ${lib.escapeShellArg firmwareSource}/. "$tmp/"
    cp --no-preserve=mode,ownership ${lib.escapeShellArg efiSource} "$tmp/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI"
    cp --no-preserve=mode,ownership "$kernel_source" "$tmp/$kernel_target"
    if [ -n "$initrd_target" ]; then
      cp --no-preserve=mode,ownership "$initrd_source" "$tmp/$initrd_target"
    fi
    cp --no-preserve=mode,ownership ${lib.escapeShellArg uBootSource} "$tmp/u-boot.bin"
    cp --no-preserve=mode,ownership ${lib.escapeShellArg configTxt} "$tmp/config.txt"
    cp --no-preserve=mode,ownership ${lib.escapeShellArg config.hardware.raspberry-pi.boot.cmdlineFile} "$tmp/cmdline.txt"

    cat > "$tmp/loader/loader.conf" <<EOF
    default nixos-generation-current.conf
    timeout 1
    editor no
    console-mode keep
    EOF

    cat > "$tmp/loader/entries/nixos-generation-current.conf" <<EOF
    title NixOS
    sort-key nixos
    version $label
    linux /$kernel_target
    EOF
    if [ -n "$initrd_target" ]; then
      printf 'initrd /%s\n' "$initrd_target" >> "$tmp/loader/entries/nixos-generation-current.conf"
    fi
    printf 'options %s\n' "$kernel_params" >> "$tmp/loader/entries/nixos-generation-current.conf"

    ${pkgs.rsync}/bin/rsync \
      -rLtD \
      --delete \
      --delete-excluded \
      --no-owner \
      --no-group \
      --no-perms \
      --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
      "$tmp/" "$boot_mount/"

    sync
  '';
in
{
  imports = [ "${modulesPath}/image/repart.nix" ];

  boot.kernelPatches = [
    {
      name = "config-enable-zboot";
      patch = null;
      structuredExtraConfig = {
        EFI = lib.mkForce lib.kernel.yes;
        EFI_ZBOOT = lib.mkForce lib.kernel.yes;
        EFIVAR_FS = lib.mkForce lib.kernel.yes;
      };
    }
  ];

  hardware.enableRedistributableFirmware = true;
  boot.initrd.systemd.tpm2.enable = false;

  nixpkgs.overlays = [
    (_: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  systemd.repart.enable = true;
  systemd.repart.partitions."01-root".Type = "root";

  boot.loader = {
    generic-extlinux-compatible.enable = lib.mkForce false;
    grub.enable = lib.mkForce false;
    external.enable = true;
    external.installHook = installBootLoader;
    efi.canTouchEfiVariables = false;
  };

  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "bcm2835-rpi-zero-w.dtb";

  hardware.raspberry-pi.boot = {
    serialConsole = "ttyAMA0";
    kernelConsoleParams = [
      "console=ttyAMA0,115200"
      "console=tty1"
    ];
  };

  image.hybridMbr = lib.mkForce true;

  image.repart = {
    name = "image";
    compression.enable = true;
    partitions = {
      "01-esp" = {
        contents = espContents;
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = "ESP";
          SizeMinBytes = "512M";
          Flags = "0x4";
        };
      };

      "02-root" = {
        storePaths = [ config.system.build.toplevel ];
        repartConfig = {
          Type = "root";
          Format = "ext4";
          Label = "nixos";
          Minimize = "guess";
          GrowFileSystem = true;
        };
      };
    };
  };
}
