{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.hardware.out-of-tree.touchscreen-hynitron-cst3240;
in
{
  options.hardware.out-of-tree.touchscreen-hynitron-cst3240 = {
    enable = lib.mkEnableOption "out-of-tree Hynitron CST3240 touch panel driver";
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ./driver.nix { })
    ];

    boot.kernelModules = [ "touchscreen-hynitron-cst3240" ];
  };
}
