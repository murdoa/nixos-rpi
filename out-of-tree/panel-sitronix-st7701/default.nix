{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.hardware.out-of-tree.panel-sitronix-st7701;
in
{
  options.hardware.out-of-tree.panel-sitronix-st7701 = {
    enable = lib.mkEnableOption "out-of-tree Sitronix ST7701 display panel driver";
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ./driver.nix { })
    ];

    boot.kernelPatches = [
      {
        name = "disable-in-tree-st7701";
        patch = null;
        structuredExtraConfig = with lib.kernel; {
          # Disable in-tree driver in favor of out-of-tree version
          DRM_PANEL_SITRONIX_ST7701 = lib.mkForce no;
        };
      }
    ];

    boot.kernelModules = [ "panel-sitronix-st7701" ];
  };
}
