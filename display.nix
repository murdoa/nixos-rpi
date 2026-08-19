{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.solarPi;

  mkScreenSelector =
    name: specialisation:
    pkgs.writeShellScriptBin name ''
      set -euo pipefail

      system=/nix/var/nix/profiles/system/specialisation/${specialisation}
      if [[ ! -x "$system/bin/switch-to-configuration" ]]; then
        echo "Screen specialisation '${specialisation}' is not installed" >&2
        exit 1
      fi

      sudo "$system/bin/switch-to-configuration" boot
      echo "Selected ${specialisation} for the next boot. Reboot to apply."
    '';
in
{
  options.hardware.solarPi.display = lib.mkOption {
    type = lib.types.enum [
      "er-tft-3.71"
      "er-tft-4.58"
    ];
    default = "er-tft-3.71";
    description = "SolarPi DPI panel fitted to the appliance.";
  };

  config = {
    hardware.out-of-tree.panel-sitronix-st7701.enable = true;
    hardware.out-of-tree.touchscreen-hynitron-cst3240.enable = cfg.display == "er-tft-3.71";

    hardware.deviceTree.overlays = [
      (
        if cfg.display == "er-tft-3.71" then
          {
            name = "vc4-kms-dpi-er_tft_3_71_1";
            dtsFile = ./dt-overlays/vc4-kms-dpi-er-tft-3-71-1-overlay.dts;
          }
        else
          {
            name = "vc4-kms-dpi-er_tft_4_58_1";
            dtsFile = ./dt-overlays/vc4-kms-dpi-er-tft-4-58-1-overlay.dts;
          }
      )
    ];

    specialisation = {
      er-tft-3-71.configuration.hardware.solarPi.display = lib.mkForce "er-tft-3.71";
      er-tft-4-58.configuration.hardware.solarPi.display = lib.mkForce "er-tft-4.58";
    };

    environment.systemPackages = [
      (mkScreenSelector "select-screen-3.71" "er-tft-3-71")
      (mkScreenSelector "select-screen-4.58" "er-tft-4-58")
    ];
  };
}
