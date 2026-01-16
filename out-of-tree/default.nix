{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ./panel-sitronix-st7701
    ./touchscreen-hynitron-cst3240
  ];
}
