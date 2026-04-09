{ lib, config, pkgs, modulesPath, ... }:
let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
  configTxt = pkgs.writeText "config.txt" ''
    [pi3]
    kernel=u-boot.bin
    disable_overscan=1

    [all]
    arm_64bit=1
    enable_uart=1
    core_freq=250
    avoid_warnings=1
    disable_fw_kms_setup=1
  '';
in
{
  imports = [ "${modulesPath}/image/repart.nix" ];

  hardware.enableRedistributableFirmware = true;

  systemd.repart.enable = true;
  systemd.repart.partitions."01-root".Type = "root";

  boot.loader = {
    generic-extlinux-compatible.enable = lib.mkForce false;
    grub.enable = lib.mkForce false;
    systemd-boot.enable = lib.mkForce true;
    efi.canTouchEfiVariables = false;
  };

  boot.kernelParams = [
    "console=ttyAMA0,115200"
    "console=tty1"
    "earlycon=pl011,0x3f201000"
  ];

  hardware.deviceTree.enable = true;

  image.repart = {
    name = "image";
    compression.enable = false;
    partitions = {
      "01-esp" = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source = "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/systemd/systemd-boot${efiArch}.efi".source = "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          "/u-boot.bin".source = "${pkgs.ubootRaspberryPi3_64bit}/u-boot.bin";
          "/config.txt".source = configTxt;
          "/".source = "${pkgs.raspberrypifw}/share/raspberrypi/boot";
        };
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
