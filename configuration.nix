{
  pkgs,
  lib,
  config,
  ssh-keys,
  ...
}:
{
  imports = [
    ./graphics.nix
    ./splash.nix
  ];

  nix.optimise.automatic = true;
  nix.settings.auto-optimise-store = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelPatches = [
    {
      name = "0001-st7701s-driver-er-tft-4-58-1";
      patch = ./kernel-patches/0001-st7701s-driver-er-tft-4-58-1.patch;
    }
  ];

  boot.kernelModules = [
    "usbhid"
    "usb-storage"
  ];

  boot.kernelParams = [
    "console=tty1"
    "video=HDMI-A-1:d"
  ];

  hardware.deviceTree.filter = "*rpi*.dtb";
  hardware.deviceTree.overlays = [
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
    evtest
  ];
  services.openssh.enable = true;
  networking = {
    hostName = "nixos";

    nameservers = [ "1.1.1.1" "9.9.9.9" ];
    
    interfaces.enu1u1.ipv4.addresses = [
      {
        address = "192.168.0.157";
        prefixLength = 24;
      }
    ];

    defaultGateway = {
      address = "192.168.0.1";
      interface = "enu1u1";
    };
  };

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
