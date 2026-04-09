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

      rpiLib = import ./lib { inherit nixpkgs; };
      mkRpiSystem = rpiLib.mkRpiSystem;
      mkFlashApp = rpiLib.mkFlashApp;
    in
    {
      lib = rpiLib;

      nixosModules = {
        base = import ./modules/base.nix;
        pi0-image = import ./boards/raspberry-pi/pi0-image.nix;
        pi3-common-image = import ./boards/raspberry-pi/pi3-common-image.nix;
        pi4-image = import ./boards/raspberry-pi/pi4-image.nix;
        pi3 = import ./hosts/pi3.nix;
        pi3b = import ./hosts/pi3b.nix;
        pi3bplus = import ./hosts/pi3bplus.nix;
        pi4 = import ./hosts/pi4.nix;
      };

      nixosConfigurations = {
        pi3 = mkRpiSystem {
          buildSystem = "x86_64-linux";
          board = "pi3";
        };

        pi3-native = mkRpiSystem {
          buildSystem = "aarch64-linux";
          board = "pi3";
        };

        pi3b = mkRpiSystem {
          buildSystem = "x86_64-linux";
          board = "pi3b";
        };

        pi3b-native = mkRpiSystem {
          buildSystem = "aarch64-linux";
          board = "pi3b";
        };

        pi3bplus = mkRpiSystem {
          buildSystem = "x86_64-linux";
          board = "pi3bplus";
        };

        pi3bplus-native = mkRpiSystem {
          buildSystem = "aarch64-linux";
          board = "pi3bplus";
        };

        pi4 = mkRpiSystem {
          buildSystem = "x86_64-linux";
          board = "pi4";
        };

        pi4-native = mkRpiSystem {
          buildSystem = "aarch64-linux";
          board = "pi4";
        };

        pi0 = mkRpiSystem {
          buildSystem = "x86_64-linux";
          board = "pi0";
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

        pi3b = self.nixosConfigurations.pi3b.config.system.build.image.overrideAttrs (old: {
          preInstall = (old.preInstall or "") + ''
            ${nixpkgs.legacyPackages.x86_64-linux.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3b.config.image.baseName}.raw
            echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${nixpkgs.legacyPackages.x86_64-linux.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3b.config.image.baseName}.raw
          '';
        });

        pi3b-native = self.nixosConfigurations.pi3b-native.config.system.build.image.overrideAttrs (old: {
          preInstall = (old.preInstall or "") + ''
            ${nixpkgs.legacyPackages.aarch64-linux.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3b-native.config.image.baseName}.raw
            echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${nixpkgs.legacyPackages.aarch64-linux.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3b-native.config.image.baseName}.raw
          '';
        });

        pi3bplus = self.nixosConfigurations.pi3bplus.config.system.build.image.overrideAttrs (old: {
          preInstall = (old.preInstall or "") + ''
            ${nixpkgs.legacyPackages.x86_64-linux.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3bplus.config.image.baseName}.raw
            echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${nixpkgs.legacyPackages.x86_64-linux.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3bplus.config.image.baseName}.raw
          '';
        });

        pi3bplus-native = self.nixosConfigurations.pi3bplus-native.config.system.build.image.overrideAttrs (old: {
          preInstall = (old.preInstall or "") + ''
            ${nixpkgs.legacyPackages.aarch64-linux.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3bplus-native.config.image.baseName}.raw
            echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${nixpkgs.legacyPackages.aarch64-linux.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3bplus-native.config.image.baseName}.raw
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
        pi3b-image = self.images.pi3b;
        pi3bplus-image = self.images.pi3bplus;
        pi4-image = self.images.pi4;
        pi0-image = self.images.pi0;
        pi3-image-native = self.images.pi3-native;
        pi3b-image-native = self.images.pi3b-native;
        pi3bplus-image-native = self.images.pi3bplus-native;
        pi4-image-native = self.images.pi4-native;
      });

      apps.x86_64-linux = {
        flash-pi3 = mkFlashApp {
          name = "flash-pi3";
          image = self.images.pi3;
        };
        flash-pi3b = mkFlashApp {
          name = "flash-pi3b";
          image = self.images.pi3b;
        };
        flash-pi3bplus = mkFlashApp {
          name = "flash-pi3bplus";
          image = self.images.pi3bplus;
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
        flash-pi3b-native = mkFlashApp {
          name = "flash-pi3b-native";
          image = self.images.pi3b-native;
        };
        flash-pi3bplus-native = mkFlashApp {
          name = "flash-pi3bplus-native";
          image = self.images.pi3bplus-native;
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
