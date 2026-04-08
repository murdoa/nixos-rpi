{
  imports = [
    ../modules/base.nix
    ../boards/raspberry-pi/pi4-image.nix
  ];

  networking.hostName = "nixos-rpi4";
}
