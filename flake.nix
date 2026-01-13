{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    ssh-keys = {
      url = "https://github.com/murdoa.keys";
      flake = false;
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      ssh-keys,
    }@inputs:
    let
      # Systems that can be used as build hosts
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Helper to generate attributes for all systems
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Helper to create Pi configurations with automatic cross-compilation
      mkPiConfig =
        {
          targetSystem, # The system the Pi will run (e.g., "aarch64-linux")
          buildSystem, # The system building the image
          modules,
          specialArgs ? { },
        }:
        nixpkgs.lib.nixosSystem {
          system = buildSystem;
          specialArgs = specialArgs // { inherit inputs; };
          modules =
            modules
            ++ nixpkgs.lib.optionals (buildSystem != targetSystem) [
              {
                nixpkgs.crossSystem = {
                  system = targetSystem;
                };
              }
            ];
        };
    in
    rec {
      images =
        let
          pkgsX86 = nixpkgs.legacyPackages.x86_64-linux;
          pkgsAarch64 = nixpkgs.legacyPackages.aarch64-linux;
        in
        {
          # Cross-compiled images (default)
          pi4 = self.nixosConfigurations.pi4.config.system.build.image;
          pi3 = self.nixosConfigurations.pi3.config.system.build.image.overrideAttrs {
            preInstall = ''
              ${pkgsX86.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3.config.image.baseName}.raw
              echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${pkgsX86.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3.config.image.baseName}.raw
            '';
          };
          pi0 = self.nixosConfigurations.pi0.config.system.build.image.overrideAttrs {
            preInstall = ''
              ${pkgsX86.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi0.config.image.baseName}.raw
              echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${pkgsX86.util-linux}/bin/fdisk ${self.nixosConfigurations.pi0.config.image.baseName}.raw
            '';
          };

          # Native build images (aarch64 only - armv6l not practical)
          pi4-native = self.nixosConfigurations.pi4-native.config.system.build.image;
          pi3-native = self.nixosConfigurations.pi3-native.config.system.build.image.overrideAttrs {
            preInstall = ''
              ${pkgsAarch64.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3-native.config.image.baseName}.raw
              echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${pkgsAarch64.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3-native.config.image.baseName}.raw
            '';
          };
        };

      # Generate packages for all supported build systems
      packages = forAllSystems (system: {
        # Cross-compiled images (default)
        pi-image = images.pi4;
        pi3-image = images.pi3;
        pi0-image = images.pi0;

        # Native build images (aarch64 only)
        pi-image-native = images.pi4-native;
        pi3-image-native = images.pi3-native;
      });

      apps.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          mkFlashScript =
            image:
            pkgs.writeShellScriptBin "flash" ''
              set -euo pipefail
              if [ $# -ne 1 ]; then
                echo "Usage: $0 <device>"
                echo "Example: $0 /dev/sdc"
                exit 1
              fi
              DEVICE="$1"
              IMAGE="${image}/image.raw"

              if [ ! -e "$DEVICE" ]; then
                echo "Error: Device $DEVICE does not exist"
                exit 1
              fi

              if [ ! -b "$DEVICE" ]; then
                echo "Error: $DEVICE is not a block device"
                exit 1
              fi

              echo "Flashing $IMAGE to $DEVICE..."
              ${pkgs.pv}/bin/pv -s "$(stat -c%s "$IMAGE")" "$IMAGE" | sudo ${pkgs.coreutils}/bin/dd of="$DEVICE" bs=8M oflag=direct status=none && sync
              echo "Done!"
            '';
        in
        {
          flash-pi4 = {
            type = "app";
            program = "${mkFlashScript images.pi4}/bin/flash";
          };
          flash-pi3 = {
            type = "app";
            program = "${mkFlashScript images.pi3}/bin/flash";
          };
          flash-pi0 = {
            type = "app";
            program = "${mkFlashScript images.pi0}/bin/flash";
          };
          flash-result = {
            type = "app";
            program = "${mkFlashScript "result"}/bin/flash";
          };
        };

      nixosConfigurations = {
        # Pi Zero - cross-compiled only (armv6l not a practical build system)
        pi0 = mkPiConfig {
          buildSystem = "x86_64-linux";
          targetSystem = "armv6l-linux";
          specialArgs = {
            inherit ssh-keys;
          };
          modules = [
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            ./repart/repart-pi0.nix
            ./configuration.nix
          ];
        };

        # Pi 3 - cross-compiled from x86_64
        pi3 = mkPiConfig {
          buildSystem = "x86_64-linux";
          targetSystem = "aarch64-linux";
          specialArgs = {
            inherit ssh-keys;
          };
          modules = [
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            ./repart/repart-pi3.nix
            ./configuration.nix
          ];
        };

        # Pi 3 - native build on aarch64
        pi3-native = mkPiConfig {
          buildSystem = "aarch64-linux";
          targetSystem = "aarch64-linux";
          specialArgs = {
            inherit ssh-keys;
          };
          modules = [
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            ./repart/repart-pi3.nix
            ./configuration.nix
          ];
        };

        # Pi 4 - cross-compiled from x86_64
        pi4 = mkPiConfig {
          buildSystem = "x86_64-linux";
          targetSystem = "aarch64-linux";
          specialArgs = {
            inherit ssh-keys;
          };
          modules = [
            nixos-hardware.nixosModules.raspberry-pi-4
            ./repart/repart.nix
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            ./configuration.nix
          ];
        };

        # Pi 4 - native build on aarch64
        pi4-native = mkPiConfig {
          buildSystem = "aarch64-linux";
          targetSystem = "aarch64-linux";
          specialArgs = {
            inherit ssh-keys;
          };
          modules = [
            nixos-hardware.nixosModules.raspberry-pi-4
            ./repart/repart.nix
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            ./configuration.nix
          ];
        };
      };
    };
}
