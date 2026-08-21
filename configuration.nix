{
  pkgs,
  lib,
  config,
  ssh-keys,
  ...
}:
{
  imports = [
    ./out-of-tree/default.nix
    ./display.nix
    ./graphics.nix
    ./kernel.nix
    ./splash.nix
    ./uboot.nix
  ];

  nix.optimise.automatic = true;
  nix.settings.auto-optimise-store = true;

  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_latest.override {
    # Platform pruning makes generic arm64 defaults inapplicable.
    ignoreConfigErrors = true;
  });

  # sdImage.compressImage = false;

  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-label/ESP";
  #   fsType = "vfat";
  #   options = [ "fmask=0077" "dmask=0077" ];
  # };

  boot.loader.timeout = 0;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    # Alternatively, this could be removed from the configuration.
    # The filesystem is not needed at runtime, it could be treated
    # as an opaque blob instead of a discrete FAT32 filesystem.
    options = [
      "nofail"
      "noauto"
    ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  boot.kernelModules = [
    "usbhid"
    "usb-storage"
    "panel-sitronix-st7701"
    "bcm2835_v4l2"
  ];

  boot.kernelParams = [
    "video=HDMI-A-1:d"
  ];

  # boot.initrd.systemd.enable = true;
  # boot.initrd.systemd.root = "gpt-auto";
  # boot.initrd.supportedFilesystems.ext4 = true;
  # boot.loader = {
  #   grub.enable = lib.mkForce false;
  #   generic-extlinux-compatible.enable = lib.mkForce true;
  #   systemd-boot.enable = lib.mkForce false;
  #   # systemd-boot.installDeviceTree = true;
  #   efi.canTouchEfiVariables = false;
  # };

  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "broadcom/bcm2837-rpi-3-b-plus.dtb";
  hardware.deviceTree.filter = "*rpi*.dtb";
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    vim
    git
    libdrm
    evtest
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
    v4l-utils
  ];
  environment.sessionVariables.GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPath "lib/gstreamer-1.0" [
    pkgs.gst_all_1.gstreamer.out
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-plugins-ugly
    pkgs.gst_all_1.gst-libav
  ];

  services.openssh.enable = true;
  networking = {
    hostName = "nixos";
    firewall.allowedUDPPorts = [ 9000 ];
    useDHCP = true;
  };

  # DHCP option 42 should supply this server; keep the dedicated-link address
  # as an explicit fallback so display time never depends on the external LAN.
  services.timesyncd = {
    enable = true;
    servers = [ "10.42.0.1" ];
    fallbackServers = [ ];
  };

  # This is an appliance.  Persistent logs both wear the SD card and make boot
  # replay the previous journal before basic.target can be reached.
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=16M
  '';

  users = {
    users.nixos = {
      initialHashedPassword = lib.mkForce null;
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
