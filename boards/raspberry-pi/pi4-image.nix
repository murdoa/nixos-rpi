{ lib, config, pkgs, modulesPath, ... }:
let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
  ukiFile = config.system.boot.loader.ukiFile;
  efiSource = "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
  firmwareSource = "${pkgs.raspberrypifw}/share/raspberrypi/boot";
  uBootSource = "${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin";
  armStubSource = "${pkgs.raspberrypi-armstubs}/armstub8-gic.bin";
  configTxt = pkgs.writeText "config.txt" ''
    [pi4]
    kernel=u-boot.bin
    enable_gic=1
    armstub=armstub8-gic.bin
    disable_overscan=1
    arm_boost=1

    [all]
    arm_64bit=1
    enable_uart=1
    avoid_warnings=1
  '';

  espContents = {
    "/".source = firmwareSource;
    "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source = efiSource;
    "/EFI/Linux/${ukiFile}".source = "${config.system.build.uki}/${ukiFile}";
    "/u-boot.bin".source = uBootSource;
    "/armstub8-gic.bin".source = armStubSource;
    "/config.txt".source = configTxt;
    "/cmdline.txt".source = config.hardware.raspberry-pi.boot.cmdlineFile;
  };

  installBootLoader = pkgs.writeShellScript "install-raspberry-pi-boot-partition" ''
    set -euo pipefail

    if [ "$#" -lt 1 ]; then
      echo "usage: $0 <system-toplevel>" >&2
      exit 1
    fi

    boot_mount=${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint}
    tmp="$(${pkgs.coreutils}/bin/mktemp -d -t raspberry-pi-boot.XXXXXX)"
    trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT

    if ! mountpoint -q "$boot_mount"; then
      echo "error: $boot_mount is not mounted" >&2
      exit 1
    fi

    mkdir -p "$tmp/EFI/BOOT" "$tmp/EFI/Linux"
    cp -r --no-preserve=mode,ownership ${lib.escapeShellArg firmwareSource}/. "$tmp/"
    cp --no-preserve=mode,ownership ${lib.escapeShellArg efiSource} "$tmp/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI"
    uki_source="$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".initrd // empty' "$toplevel/boot.json")"
    if [ -z "$uki_source" ] || [ "$uki_source" = "null" ]; then
      uki_source="$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".kernel // empty' "$toplevel/boot.json")"
    fi
    if [ -z "$uki_source" ] || [ "$uki_source" = "null" ]; then
      echo "error: could not determine UKI path from $toplevel/boot.json" >&2
      exit 1
    fi
    cp --no-preserve=mode,ownership "$uki_source" "$tmp/EFI/Linux/${ukiFile}"
    cp --no-preserve=mode,ownership ${lib.escapeShellArg uBootSource} "$tmp/u-boot.bin"
    cp --no-preserve=mode,ownership ${lib.escapeShellArg armStubSource} "$tmp/armstub8-gic.bin"
    cp --no-preserve=mode,ownership ${lib.escapeShellArg configTxt} "$tmp/config.txt"
    cp --no-preserve=mode,ownership ${lib.escapeShellArg config.hardware.raspberry-pi.boot.cmdlineFile} "$tmp/cmdline.txt"

    ${pkgs.rsync}/bin/rsync \
      -rLtD \
      --delete \
      --delete-excluded \
      --no-owner \
      --no-group \
      --no-perms \
      --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
      "$tmp/" "$boot_mount/"
  '';
in
{
  imports = [ "${modulesPath}/image/repart.nix" ];

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
  hardware.deviceTree.name = "broadcom/bcm2711-rpi-4-b.dtb";

  hardware.raspberry-pi.boot = {
    serialConsole = "ttyAMA0";
    kernelConsoleParams = [
      "console=tty1"
    ];
  };

  image.hybridMbr = lib.mkForce false;

  image.repart = {
    name = "image";
    partitions = {
      "01-esp" = {
        contents = espContents;
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = "ESP";
          SizeMinBytes = "512M";
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
