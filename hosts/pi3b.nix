{
  imports = [
    ../modules/base.nix
    ../boards/raspberry-pi/pi3-common-image.nix
  ];

  networking.hostName = "nixos-rpi3b";
  hardware.deviceTree.name = "broadcom/bcm2837-rpi-3-b.dtb";
  hardware.raspberry-pi.silentSerialBoot.enable = true;
}
