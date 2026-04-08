{
  imports = [
    ../modules/base.nix
    ../boards/raspberry-pi/pi3-image.nix
  ];

  networking.hostName = "nixos-rpi3";
}
