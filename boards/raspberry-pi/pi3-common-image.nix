{ lib, config, pkgs, modulesPath, ... }:
let
  silentSerialBootEnabled = config.hardware.raspberry-pi.silentSerialBoot.enable;
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
  ukiFile = config.system.boot.loader.ukiFile;
  efiSource = "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
  firmwareSource = "${pkgs.raspberrypifw}/share/raspberrypi/boot";
  uBootPackage =
    if silentSerialBootEnabled then
      pkgs.ubootRaspberryPi3_64bit.override {
        extraConfig = ''
          CONFIG_ENV_IS_IN_FAT=y
          CONFIG_ENV_FAT_FILE="uboot.env"
          CONFIG_SILENT_CONSOLE=y
          CONFIG_SYS_DEVICE_NULLDEV=y
          CONFIG_SILENT_CONSOLE_UPDATE_ON_SET=y
          CONFIG_SILENT_U_BOOT_ONLY=y
        '';
      }
    else
      pkgs.ubootRaspberryPi3_64bit;
  uBootSource = "${uBootPackage}/u-boot.bin";
  uBootEnvText = pkgs.writeText "uboot.env.txt" ''
    silent=1
  '';
  uBootEnv = pkgs.runCommand "uboot.env" { nativeBuildInputs = [ pkgs.ubootTools ]; } ''
    mkenvimage -s 0x4000 -o "$out" ${lib.escapeShellArg uBootEnvText}
  '';
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

  espContents = {
    "/".source = firmwareSource;
    "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source = efiSource;
    "/EFI/systemd/systemd-boot${efiArch}.efi".source = efiSource;
    "/EFI/Linux/${ukiFile}".source = "${config.system.build.uki}/${ukiFile}";
    "/u-boot.bin".source = uBootSource;
    "/config.txt".source = configTxt;
    "/cmdline.txt".source = config.hardware.raspberry-pi.boot.cmdlineFile;
  } // lib.optionalAttrs silentSerialBootEnabled {
    "/uboot.env".source = uBootEnv;
  };
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

  system.activationScripts.raspberryPiUpdateUboot = lib.stringAfter [ "etc" ] ''
    if mountpoint -q ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint}; then
      cp --no-preserve=mode,ownership ${lib.escapeShellArg uBootSource} ${lib.escapeShellArg (config.boot.loader.efi.efiSysMountPoint + "/u-boot.bin")}
      ${lib.optionalString silentSerialBootEnabled ''
        cp --no-preserve=mode,ownership ${lib.escapeShellArg uBootEnv} ${lib.escapeShellArg (config.boot.loader.efi.efiSysMountPoint + "/uboot.env")}
      ''}
      sync
    fi
  '';

  hardware.raspberry-pi.boot = {
    serialConsole = "ttyAMA0";
    kernelConsoleParams = [
      "console=ttyAMA0,115200"
      "console=tty1"
      "earlycon=pl011,0x3f201000"
    ];
  };

  boot.kernelParams = [
    "8250.nr_uarts=0"
  ];

  hardware.deviceTree.enable = true;

  image.hybridMbr = lib.mkForce true;

  image.repart = {
    name = "image";
    compression.enable = false;
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
