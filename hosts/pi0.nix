{
  imports = [
    ../modules/base.nix
    ../boards/raspberry-pi/pi0-image.nix
  ];

  networking.hostName = "nixos-pi0";
}
