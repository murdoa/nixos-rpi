{
  imports = [
    ../modules/base.nix
    ../boards/raspberry-pi/pi3-common-image.nix
  ];

  networking.hostName = "nixos-rpi3bplus";
  hardware.deviceTree.name = "broadcom/bcm2837-rpi-3-b-plus.dtb";
}
