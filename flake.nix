{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    ssh-keys = {
      url = "https://github.com/murdoa.keys";
      flake = false;
    };
    timebaseHmi = {
      url = "git+ssh://git@github.com/solarpi-org/timebase-hmi.git?ref=refs/heads/flutter-3.35";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      ssh-keys,
      timebaseHmi,
      nixos-generators,
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
          specialArgs = specialArgs // {
            inherit inputs;
          };
          modules =
            modules
            ++ [
              {
                imports = [
                  nixos-generators.nixosModules.all-formats
                ];
                formatConfigs.sd-aarch64 =
                  { config, lib, ... }:
                  {
                    # sdImage.compressImage = lib.mkForce false;
                    # fileExtension = lib.mkForce ".img";
                  };
                nixpkgs.hostPlatform = buildSystem;
              }
              {
                nixpkgs.overlays = [
                  (final: prev: {
                    weston = prev.weston.overrideAttrs (oldAttrs: {
                      patches = (oldAttrs.patches or [ ]) ++ [
                        ./patches/weston-mirror-transformed-mode.patch
                      ];
                    });
                    novnc = prev.novnc.overrideAttrs (oldAttrs: {
                      postPatch = (oldAttrs.postPatch or "") + ''
                        substituteInPlace app/ui.js \
                          --replace-fail "UI.initSetting('show_dot', false);" \
                                         "UI.initSetting('show_dot', true);"
                        substituteInPlace vnc_lite.html \
                          --replace-fail 'const password = prompt("Password required:");' \
                                         'const username = prompt("Username required:"); const password = prompt("Password required:");' \
                          --replace-fail 'rfb.sendCredentials({ password: password });' \
                                         'rfb.sendCredentials({ username: username, password: password });'
                      '';
                    });
                    timebase_hmi = timebaseHmi.packages.${targetSystem}.default.overrideAttrs (oldAttrs: {
                      postPatch = (oldAttrs.postPatch or "") + ''
                        mkdir -p assets
                        cp ${final.dejavu_fonts.minimal}/share/fonts/truetype/DejaVuSans.ttf assets/
                        cat >> pubspec.yaml <<'EOF'
                          fonts:
                            - family: Roboto
                              fonts:
                                - asset: assets/DejaVuSans.ttf
                        EOF
                      '';
                      extraWrapProgramArgs = ''
                        --prefix LD_LIBRARY_PATH : ${
                          final.lib.makeLibraryPath [
                            final.mesa
                            final.libglvnd
                            final.gtk3
                          ]
                        }
                      '';
                    });
                  })
                ];
              }
            ]
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

      images = {
        pi3 = nixosConfigurations.pi3.config.formats.sd-aarch64;
        pi3-native = nixosConfigurations.pi3-native.config.formats.sd-aarch64;
      };

      # Generate packages for all supported build systems
      packages = forAllSystems (system: {
        # Cross-compiled images (default)
        pi3-image = images.pi3.out;
        # Native build images (aarch64 only)
        pi3-image-native = images.pi3-native.out;
        # Flutter app package
        flutter = timebaseHmi.packages.${system}.default;
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
              IMAGE=$(readlink -f "${image.out}/${image.config.image.fileName}")

              UNCOMPRESSED_SIZE="$(zstd -dc $IMAGE | wc -c)"


              if [ ! -e "$DEVICE" ]; then
                echo "Error: Device $DEVICE does not exist"
                exit 1
              fi

              if [ ! -b "$DEVICE" ]; then
                echo "Error: $DEVICE is not a block device"
                exit 1
              fi

              echo "Flashing $IMAGE to $DEVICE..."
              ${pkgs.coreutils}/bin/cat -- "$IMAGE" \
            | ${pkgs.zstd}/bin/zstd -d -c \
            | ${pkgs.pv}/bin/pv -s "$UNCOMPRESSED_SIZE" \
            | sudo ${pkgs.coreutils}/bin/dd of="$DEVICE" bs=8M oflag=direct status=none

              sync

              echo "Done!"
            '';
        in
        {
          flash-pi3 = {
            type = "app";
            program = "${mkFlashScript images.pi3}/bin/flash";
          };
          flash-pi3-native = {
            type = "app";
            program = "${mkFlashScript images.pi3-native}/bin/flash";
          };
        };

      nixosConfigurations = {
        # Pi 3 - cross-compiled from x86_64
        pi3 = mkPiConfig {
          buildSystem = "x86_64-linux";
          targetSystem = "aarch64-linux";
          specialArgs = {
            inherit ssh-keys;
          };
          modules = [
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
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
            ./configuration.nix
          ];
        };
      };
    };
}
