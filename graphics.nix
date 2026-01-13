{
  pkgs,
  lib,
  config,
  ...
}:
let
  kioskCmd = "${pkgs.weston}/bin/weston-terminal";
  startWeston = pkgs.writeShellScript "start-weston-kiosk" ''
    set -euo pipefail

    export XDG_RUNTIME_DIR="/run/user/$(id -u)"

    exec ${pkgs.weston}/bin/weston \
      --backend=drm-backend.so \
      --shell=kiosk-shell.so \
      --idle-time=0 \
      -- \
      ${kioskCmd}
  '';
in
{
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
    ];
  };

  services.getty.autologinUser = "kiosk";
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
