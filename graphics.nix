{
  pkgs,
  lib,
  config,
  ...
}:
let
  # kioskCmd = "${pkgs.flutter_reference_app}/bin/flutter_reference_app";
  kioskCmd = "${pkgs.kitty}/bin/kitty";
  kioskAppScript = pkgs.writeShellScript "kiosk-app" ''
    set -euo pipefail
 
    eglinfo -B

    exec ${kioskCmd}
  '';
  startWeston = pkgs.writeShellScript "start-weston-kiosk" ''
    set -euo pipefail

    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export EGL_LOG_LEVEL=debug
    export WAYLAND_DEBUG=1
    unset DISPLAY

    exec ${pkgs.weston}/bin/weston \
      --backend=drm-backend.so \
      --shell=kiosk-shell.so \
      --idle-time=0 \
      -- \
      ${kioskAppScript}/bin/kiosk-app
  '';
in
{
  services.seatd.enable = true;
  # services.logind.enable = true;
  # security.polkit.enable = true; 

  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    mesa
  ];

  services.udev.packages = with pkgs; [
    libinput
  ];

  environment.systemPackages = with pkgs; [
    weston
    libdrm
    mesa-demos # optional: glxgears etc (small)
    cage
  ];

  users.users.kiosk = {
    isNormalUser = true;
    description = "Kiosk user";
    extraGroups = [
      "video"
      "input"
      "render"
      "seat"
    ];
  };

  services.getty.autologinUser = lib.mkForce "kiosk";
  systemd.services."getty@tty1".enable = true;

  systemd.user.services.weston-kiosk = {
    description = "Weston kiosk session";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${startWeston}";
      Restart = "always";
      RestartSec = 1;
    };
  };

  boot.kernelParams = [
    "consoleblank=0"
  ];
}
