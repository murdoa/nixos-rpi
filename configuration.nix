{
  pkgs,
  lib,
  config,
  ssh-keys,
  ...
}:
{
  imports = [
  ];

  nixpkgs.overlays = [
    (import ./kernel/overlay.nix)
  ];

  nix.optimise.automatic = true;
  nix.settings.auto-optimise-store = true;

  boot.kernelPackages = lib.mkForce (pkgs.linuxKernel.packagesFor pkgs.linux_rpi3_custom);

  boot.kernelModules = [
    "vc4"
    "vc4_hdmi"
    "drm_kms_helper"
  ];

  boot.initrd.kernelModules = [
    "vc4"
    "vc4_hdmi"
  ];

  boot.blacklistedKernelModules = [
    "simpledrm"
  ];

  boot.kernelParams = [
    "video=simpledrm:off"
    "vc4.force_hotplug=1"
    "drm.debug=0x1"
    # "console=tty1"
  ];

  hardware.deviceTree.filter = "*rpi*.dtb";
  hardware.deviceTree.overlays = [
    {
      name = "vc4-kms-v3d";
      dtsFile = ./dt-overlays/vc4-kms-v3d-overlay.dts;
    }
    {
      name = "vc4-kms-dpi-er_tft_4_58_1";
      dtsFile = ./dt-overlays/vc4-kms-dpi-er-tft-4-58-1-overlay.dts;
    }
  ];

  boot.initrd.checkJournalingFS = false;
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    noCheck = true; # skip fsck on ESP
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    noCheck = true; # skip fsck on rootfs
  };

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    vim
    git
    libdrm
  ];
  services.openssh.enable = true;
  networking.hostName = "nixos";

  users = {
    users.nixos = {
      password = "default";
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keyFiles = [ ssh-keys.outPath ];
    };
  };

  nix.settings = {
    experimental-features = lib.mkDefault "nix-command flakes";
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
  system.stateVersion = "25.11";
}
