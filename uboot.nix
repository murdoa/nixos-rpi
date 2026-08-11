{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.boot.loader.generic-extlinux-compatible;
  timeout = config.boot.loader.timeout;
  timeoutStr = if timeout == null then "-1" else toString timeout;
  builderArgs =
    "-g ${toString cfg.configurationLimit} -t ${timeoutStr}"
    + lib.optionalString (config.hardware.deviceTree.name != null)
      " -n ${config.hardware.deviceTree.name}"
    + lib.optionalString (!cfg.useGenerationDeviceTree) " -r";

  mkBuilder = builderPkgs:
    builderPkgs.replaceVarsWith {
      src = ./extlinux-conf-builder-compressed.sh;
      isExecutable = true;
      replacements = {
        path = lib.makeBinPath (with builderPkgs; [
          coreutils
          gnugrep
          gnused
          gzip
        ]);
        inherit (builderPkgs) bash;
      };
    };

  builder = mkBuilder pkgs;
  installBootLoader = pkgs.writeShellScript "install-compressed-extlinux-conf" (
    ''
      set -euo pipefail
    ''
    + lib.concatMapStrings (boot: ''
      ${builder} ${builderArgs} -d ${lib.escapeShellArg boot.path} -c "$@"
    '') cfg.mirroredBoots
  );
in
{
  nixpkgs.overlays = [
    (final: prev: {
      # Keep standard distro boot and extlinux generation discovery, but remove
      # the stock two-second autoboot pause. ZERO_BOOTDELAY_CHECK retains the
      # ability to interrupt boot from a console by pressing a key immediately.
      ubootRaspberryPi3_64bit = prev.ubootRaspberryPi3_64bit.override {
        extraConfig = ''
          CONFIG_BOOTDELAY=0
          CONFIG_ZERO_BOOTDELAY_CHECK=y
        '';
      };
    })
  ];

  # NixOS does not currently expose compressed kernels in its generic extlinux
  # builder. Override only artifact population; generation discovery, DTBs,
  # command lines, rollback entries, and cleanup retain upstream semantics.
  system.build.installBootLoader = lib.mkForce installBootLoader;
}
