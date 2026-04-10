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
