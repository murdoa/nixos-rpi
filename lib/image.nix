{ nixpkgs }:
let
  lib = nixpkgs.lib;

  mkHybridImage =
    nixosConfiguration:
    nixosConfiguration.config.system.build.image.overrideAttrs (old: {
      preInstall = (old.preInstall or "") + ''
        ${nixpkgs.legacyPackages.${nixosConfiguration.pkgs.stdenv.hostPlatform.system}.gptfdisk}/bin/sgdisk --hybrid 1:EE ${nixosConfiguration.config.image.baseName}.raw
        echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${nixpkgs.legacyPackages.${nixosConfiguration.pkgs.stdenv.hostPlatform.system}.util-linux}/bin/fdisk ${nixosConfiguration.config.image.baseName}.raw
      '';
    });

  mkImage =
    nixosConfiguration:
    if lib.attrByPath [ "config" "image" "hybridMbr" ] false nixosConfiguration then
      mkHybridImage nixosConfiguration
    else
      nixosConfiguration.config.system.build.image;
in
{
  inherit mkHybridImage mkImage;
}
