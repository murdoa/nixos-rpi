{
  pkgs,
  lib,
  config,
  ...
}:
let
  kioskCmd = "${pkgs.timebase_hmi}/bin/timebase_hmi";
  kioskAppScript = pkgs.writeShellScript "kiosk-app" ''
    set -euo pipefail

    # Force GTK to request an OpenGL ES context supported by VC4.
    export GDK_GL=gles

    exec ${kioskCmd}
  '';
  novncCertificate = pkgs.writeShellScript "novnc-certificate" ''
    set -euo pipefail

    if [[ ! -s /var/lib/novnc/tls.key || ! -s /var/lib/novnc/tls.crt ]]; then
      ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout /var/lib/novnc/tls.key \
        -out /var/lib/novnc/tls.crt \
        -days 3650 \
        -subj /CN=192.168.0.157 \
        -addext subjectAltName=IP:192.168.0.157
    fi
  '';
  westonConfig = pkgs.writeText "weston.ini" ''
    [core]
    shell=kiosk-shell.so
    idle-time=0
    require-input=false

    [output]
    name=vnc
    mirror-of=DPI-1
    resizeable=false

    [vnc]
    refresh-rate=20
  '';
  startWeston = pkgs.writeShellScript "start-weston-kiosk" ''
    set -euo pipefail

    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    unset DISPLAY

    exec ${pkgs.weston}/bin/weston \
      --backend=drm,vnc \
      --renderer=gl \
      --config=${westonConfig} \
      --address=0.0.0.0 \
      --port=5900 \
      --disable-transport-layer-security \
      -- \
      ${kioskAppScript}
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

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Hynitron CST3240 Touchscreen", ENV{LIBINPUT_CALIBRATION_MATRIX}="-0.041853 -0.925575 0.917412 1.004484 0.003865 0.009742"
    ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card1", TAG+="systemd"
  '';

  environment.systemPackages = with pkgs; [
    weston
    libdrm
    mesa-demos # optional: glxgears etc (small)
    cage
  ];

  # Weston authenticates VNC clients through this PAM service.
  security.pam.services.weston-remote-access = { };

  users.users.kiosk = {
    isNormalUser = true;
    description = "Kiosk user";
    password = "default";
    extraGroups = [
      "video"
      "input"
      "render"
      "seat"
    ];
  };

  # Start the compositor directly instead of waiting for getty autologin, PAM,
  # and a per-user systemd manager. Ordering after plymouth-quit gives Weston
  # the DRM master immediately after the splash releases it.
  systemd.services.weston-kiosk = {
    description = "Weston kiosk session";
    wantedBy = [ "multi-user.target" ];
    wants = [ "plymouth-quit.service" ];
    requires = [ "dev-dri-card1.device" ];
    after = [
      "dev-dri-card1.device"
      "seatd.service"
      "plymouth-quit.service"
    ];
    serviceConfig = {
      User = "kiosk";
      Group = "users";
      SupplementaryGroups = [
        "video"
        "input"
        "render"
        "seat"
      ];
      RuntimeDirectory = "kiosk";
      RuntimeDirectoryMode = "0700";
      Environment = "XDG_RUNTIME_DIR=/run/kiosk";
      ExecStart = "${startWeston}";
      Restart = "always";
      RestartSec = 1;
    };
  };

  systemd.services.novnc = {
    description = "Browser VNC gateway";
    wantedBy = [ "multi-user.target" ];
    wants = [ "weston-kiosk.service" ];
    after = [
      "network.target"
      "weston-kiosk.service"
    ];
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "novnc";
      ExecStartPre = novncCertificate;
      ExecStart = ''
        ${pkgs.python3Packages.websockify}/bin/websockify \
          --web=${pkgs.novnc}/share/webapps/novnc \
          --cert=/var/lib/novnc/tls.crt \
          --key=/var/lib/novnc/tls.key \
          --ssl-only \
          0.0.0.0:6080 127.0.0.1:5900
      '';
      Restart = "always";
      RestartSec = 1;
    };
  };

  networking.firewall.allowedTCPPorts = [
    5900
    6080
  ];

  boot.kernelParams = [
    "consoleblank=0"
  ];
}
