{ lib, config, pkgs, ... }:
let
  cfg = config.hardware.raspberry-pi.silentSerialBoot;
  bootCfg = config.hardware.raspberry-pi.boot;

  normalizedCmdline =
    lib.filter (arg: arg != "") (
      [ ]
      ++ lib.optionals cfg.enable [ "console=null" ]
      ++ cfg.kernelParams
    );
in
{
  options.hardware.raspberry-pi = {
    boot = {
      cmdlineFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        internal = true;
        description = "Generated cmdline.txt file for Raspberry Pi firmware boot.";
      };

      serialConsole = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Primary serial console device for the board, e.g. ttyAMA0.";
      };

      kernelConsoleParams = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Board-specific kernel console parameters used when silent serial boot is disabled.";
      };
    };

    silentSerialBoot = {
      enable = lib.mkEnableOption "silent boot on Raspberry Pi serial-connected systems";

      kernelParams = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "quiet"
          "loglevel=0"
          "rd.udev.log_level=0"
          "udev.log_priority=0"
          "systemd.show_status=false"
          "systemd.log_level=emerg"
          "vt.global_cursor_default=0"
        ];
        description = "Extra kernel parameters appended when silent serial boot is enabled.";
      };
    };
  };

  config = {
    hardware.raspberry-pi.boot.cmdlineFile = pkgs.writeText "cmdline.txt" (
      lib.concatStringsSep " " normalizedCmdline
    );

    boot.consoleLogLevel = lib.mkDefault (if cfg.enable then 0 else 7);
    boot.initrd.verbose = lib.mkDefault (!cfg.enable);
    boot.kernelParams =
      lib.mkIf true (
        lib.optionals (!cfg.enable) bootCfg.kernelConsoleParams
        ++ lib.optionals cfg.enable cfg.kernelParams
      );

    systemd.enableEmergencyMode = lib.mkDefault (!cfg.enable);
    systemd.services =
      lib.optionalAttrs (bootCfg.serialConsole != null) {
        "serial-getty@${bootCfg.serialConsole}".enable = lib.mkDefault (!cfg.enable);
      }
      // {
        "serial-getty@ttyAMA0".enable = lib.mkDefault (!cfg.enable);
        "serial-getty@ttyS0".enable = lib.mkDefault (!cfg.enable);
      };
  };
}
