{ pkgs, lib, ... }:
{
  options.image.hybridMbr = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether the generated raw image should get hybrid MBR post-processing.";
  };

  config = {
    boot.kernelPackages = pkgs.linuxPackages_latest;

    boot.initrd.checkJournalingFS = false;
    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.root = "gpt-auto";
    boot.initrd.supportedFilesystems.ext4 = true;

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      noCheck = true;
    };

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      noCheck = true;
    };

    networking.useDHCP = lib.mkDefault true;
    services.openssh.enable = true;

    users.users.nixos = {
      isNormalUser = true;
      initialPassword = "nixos";
      extraGroups = [ "wheel" ];
    };

    environment.systemPackages = with pkgs; [
      git
      vim
    ];

    nix.optimise.automatic = true;
    nix.settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "@wheel" ];
    };

    system.stateVersion = "25.11";
  };
}
