final: prev: {

  linux_rpi3_custom = prev.callPackage ./linux-rpi.nix {
    kernelPatches = with prev.kernelPatches; [
      bridge_stp_helper
      request_key_helper
      { name = "dpi-er-tft-4-58-1"; patch = ./0001-rpi-6.6.y-display-dpi-er-tft-4-58-1.patch;}
    ];
    rpiVersion = 3;
  };

}
