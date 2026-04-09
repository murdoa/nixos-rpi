{ lib, config, pkgs, modulesPath, ... }:
let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
  configTxt = pkgs.writeText "config.txt" ''
    [pi0]
    kernel=u-boot.bin
    disable_overscan=1

    [all]
    enable_uart=1
    avoid_warnings=1
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
  };

  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "bcm2835-rpi-zero-w.dtb";

  image.hybridMbr = lib.mkForce true;

  image.repart = {
    name = "image";
    compression.enable = true;
    partitions = {
      "01-esp" = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source = "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          "/u-boot.bin".source = "${pkgs.ubootRaspberryPiZero}/u-boot.bin";
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
