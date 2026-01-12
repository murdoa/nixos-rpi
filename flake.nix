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
    rec {
      images =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          pi4 = self.nixosConfigurations.pi4.config.system.build.image;
          pi3 = self.nixosConfigurations.pi3.config.system.build.image.overrideAttrs {
            preInstall = ''
              ${pkgs.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi3.config.image.baseName}.raw
              echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${pkgs.util-linux}/bin/fdisk ${self.nixosConfigurations.pi3.config.image.baseName}.raw
            '';
          };
          pi0 = self.nixosConfigurations.pi0.config.system.build.image.overrideAttrs {
            preInstall = ''
              ${pkgs.gptfdisk}/bin/sgdisk --hybrid 1:EE ${self.nixosConfigurations.pi0.config.image.baseName}.raw
              echo -e "M\nt\n1\n0b\nw\nr\nw\n" | ${pkgs.util-linux}/bin/fdisk ${self.nixosConfigurations.pi0.config.image.baseName}.raw
            '';
          };
        };
      packages.x86_64-linux.pi-image = images.pi4;
      packages.aarch64-linux.pi-image = images.pi4;
      packages.x86_64-linux.pi3-image = images.pi3;
      packages.aarch64-linux.pi3-image = images.pi3;
      packages.x86_64-linux.pi0-image = images.pi0;
      packages.aarch64-linux.pi0-image = images.pi0;

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
        };

      nixosConfigurations = {
        pi0 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs ssh-keys;
          };
          modules = [
            {
              nixpkgs.crossSystem = {
                system = "armv6l-linux";
              };
            }
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            ./repart/repart-pi0.nix
            ./configuration.nix
          ];
        };
        pi3 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit ssh-keys;
          };
          modules = [
            {
              nixpkgs.crossSystem = {
                system = "aarch64-linux";
              };
            }
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            ./repart/repart-pi3.nix
            ./configuration.nix
          ];
        };
        pi4 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit ssh-keys;
          };
          modules = [
            {
              nixpkgs.crossSystem = {
                system = "aarch64-linux";
              };
            }
            nixos-hardware.nixosModules.raspberry-pi-4
            ./repart/repart.nix
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            ./configuration.nix
          ];
        };
      };
    };
}
