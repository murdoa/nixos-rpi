{ ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      # Keep standard distro boot and extlinux generation discovery, but remove
      # the stock two-second autoboot pause. ZERO_BOOTDELAY_CHECK retains the
      # ability to interrupt boot from a console by pressing a key immediately.
      ubootRaspberryPi3_64bit = prev.ubootRaspberryPi3_64bit.override {
        extraConfig = ''
          CONFIG_BOOTDELAY=0
          CONFIG_ZERO_BOOTDELAY_CHECK=y
        '';
      };
    })
  ];
}
