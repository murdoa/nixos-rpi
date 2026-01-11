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
