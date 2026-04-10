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
in
{
  imports = [ "${modulesPath}/image/repart.nix" ];

  systemd.repart.enable = true;
  systemd.repart.partitions."01-root".Type = "root";

  boot.loader = {
    generic-extlinux-compatible.enable = lib.mkForce false;
    grub.enable = lib.mkForce false;
    systemd-boot.enable = lib.mkForce true;
    efi.canTouchEfiVariables = false;
  };

  system.activationScripts.raspberryPiUpdateUboot = lib.stringAfter [ "etc" ] ''
    if mountpoint -q ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint}; then
      cp --no-preserve=mode,ownership ${lib.escapeShellArg uBootSource} ${lib.escapeShellArg (config.boot.loader.efi.efiSysMountPoint + "/u-boot.bin")}
      sync
    fi
  '';

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
