{
  description = "NixOS Raspberry Pi image template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      supportedBuildSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs supportedBuildSystems;

      mkRpiSystem = import ./lib/mk-system.nix { inherit nixpkgs; };
      mkFlashApp = import ./lib/flash-app.nix { inherit nixpkgs; };
    in
    {
      nixosConfigurations = {
        pi3 = mkRpiSystem {
          buildSystem = "x86_64-linux";
          targetSystem = "aarch64-linux";
          modules = [ ./hosts/pi3.nix ];
        };

        pi3-native = mkRpiSystem {
          buildSystem = "aarch64-linux";
          targetSystem = "aarch64-linux";
          modules = [ ./hosts/pi3.nix ];
        };

        pi4 = mkRpiSystem {
          buildSystem = "x86_64-linux";
          targetSystem = "aarch64-linux";
          modules = [ ./hosts/pi4.nix ];
        };

        pi4-native = mkRpiSystem {
          buildSystem = "aarch64-linux";
          targetSystem = "aarch64-linux";
          modules = [ ./hosts/pi4.nix ];
        };

        pi0 = mkRpiSystem {
          buildSystem = "x86_64-linux";
          targetSystem = "armv6l-linux";
          modules = [ ./hosts/pi0.nix ];
        };
      };

      images = {
        pi3 = self.nixosConfigurations.pi3.config.system.build.image.overrideAttrs (old: {
          preInstall = (old.preInstall or "") + ''
            ${nixpkgs.legacyPackages.x86_64-linux.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3.config.image.baseName}.raw
            echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${nixpkgs.legacyPackages.x86_64-linux.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3.config.image.baseName}.raw
          '';
        });

        pi3-native = self.nixosConfigurations.pi3-native.config.system.build.image.overrideAttrs (old: {
          preInstall = (old.preInstall or "") + ''
            ${nixpkgs.legacyPackages.aarch64-linux.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3-native.config.image.baseName}.raw
            echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${nixpkgs.legacyPackages.aarch64-linux.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3-native.config.image.baseName}.raw
          '';
        });

        pi4 = self.nixosConfigurations.pi4.config.system.build.image;
        pi4-native = self.nixosConfigurations.pi4-native.config.system.build.image;

        pi0 = self.nixosConfigurations.pi0.config.system.build.image.overrideAttrs (old: {
          preInstall = (old.preInstall or "") + ''
            ${nixpkgs.legacyPackages.x86_64-linux.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi0.config.image.baseName}.raw
            echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${nixpkgs.legacyPackages.x86_64-linux.util-linux}/bin/fdisk ${self.nixosConfigurations.pi0.config.image.baseName}.raw
          '';
        });
      };

      packages = forAllSystems (system: {
        default = self.packages.${system}.pi3-image;
        pi3-image = self.images.pi3;
        pi4-image = self.images.pi4;
        pi0-image = self.images.pi0;
        pi3-image-native = self.images.pi3-native;
        pi4-image-native = self.images.pi4-native;
      });

      apps.x86_64-linux = {
        flash-pi3 = mkFlashApp {
          name = "flash-pi3";
          image = self.images.pi3;
        };
        flash-pi4 = mkFlashApp {
          name = "flash-pi4";
          image = self.images.pi4;
        };
        flash-pi0 = mkFlashApp {
          name = "flash-pi0";
          image = self.images.pi0;
        };
        flash-pi3-native = mkFlashApp {
          name = "flash-pi3-native";
          image = self.images.pi3-native;
        };
        flash-pi4-native = mkFlashApp {
          name = "flash-pi4-native";
          image = self.images.pi4-native;
        };
      };

      templates.default = {
        path = ./.;
        description = "Template for building NixOS Raspberry Pi 3/4 images";
      };
    };
}
