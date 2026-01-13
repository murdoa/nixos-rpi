{ pkgs, lib, config, ... }:
let
  kioskUser = "nixos";
  outputName = "DPI-1";        # confirm via: modetest -c
  outputMode = "320x960";      # confirm via: cat /sys/class/drm/*/modes
  rotation   = "rotate-90";    # rotate-0/90/180/270
  demoApp    = "weston-flower";  # or "weston-flower", "weston-simple-egl"
in
{
  #### Graphics stack (provides /run/opengl-driver and GBM/EGL)
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    mesa
  ];

  #### Input stack (touchscreen via libinput)
  services.udev.packages = with pkgs; [
    libinput
  ];

  #### Tools + demo clients
  environment.systemPackages = with pkgs; [
    weston
    libdrm
    mesa-demos         # optional: glxgears etc (small)
  ];

  #### Weston configuration (kiosk-ish defaults)
  environment.etc."xdg/weston/weston.ini".text = ''
    [core]
    backend=drm-backend.so
    shell=kiosk-shell.so
    idle-time=0

    [kiosk-shell]
    # Weston 14 kiosk-shell: one app, fullscreen
    path=/run/current-system/sw/bin/weston-flower

    [output]
    name=${outputName}
    mode=${outputMode}
    transform=${rotation}

    # Avoid DPMS blanking
    [output]
    name=${outputName}
    power=on
  '';

  #### Start Weston on tty1 at boot
  systemd.services.weston-kiosk = {
    description = "Weston DRM kiosk";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" "systemd-logind.service" ];

    serviceConfig = {
      User = kioskUser;

      # Make sure a proper runtime dir exists for Wayland socket
      PAMName = "login";
      TTYPath = "/dev/tty1";
      StandardInput = "tty";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;

      Environment = [
        "XDG_RUNTIME_DIR=/run/user/%U"
        "WAYLAND_DISPLAY=wayland-0"
      ];

      ExecStart = "${pkgs.weston}/bin/weston --backend=drm-backend.so --tty=1 --log=/var/log/weston.log";
      Restart = "always";
      RestartSec = 1;
    };
  };

  #### Helpful kernel params for kiosk-like behavior (optional)
  boot.kernelParams = [
    # Keep console from blanking (separate from Weston idle)
    "consoleblank=0"
    # If HDMI is connected and you want to disable it, uncomment:
    # "video=HDMI-A-1:d"
  ];
}
