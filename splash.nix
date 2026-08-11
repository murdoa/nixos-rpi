{
  pkgs,
  lib,
  config,
  ...
}:
{

  # systemd.services.plymouth-quit.enable = lib.mkForce false;
  # systemd.services.plymouth-quit-wait.enable = lib.mkForce false;

  boot = {
    plymouth = {
      enable = true;
      theme = "abstract_ring_alt";
      themePackages = with pkgs; [
        # By default we would install all themes
        # (adi1090x-plymouth-themes.override {
        #   selected_themes = [ "abstract_ring_alt" ];
        # })
        (pkgs.callPackage ./pkgs/plymouth-theme/default.nix {})
        
      ];
      extraConfig = ''
        ShowDelay=0
        DeviceTimeout=60
      '';
    };

    # plymouth = {
    #   enable = true;
    #   theme = "abstract_ring_alt";
    #   themePackages = with pkgs; [
    #     (pkgs.callPackage ./pkgs/plymouth-theme/default.nix {})
    #   ];
    # };

    # Load the panel's providers before its consumers.  In particular, the
    # panel reset is supplied by a PCA9539 on an i2c-gpio bus.  Without
    # i2c_gpio in the initrd the panel probe defers until stage two, leaving the
    # LCD dark for roughly five seconds while Plymouth is already running.
    initrd.kernelModules = [
      "i2c_gpio"
      "spi_gpio"
      "spi_bitbang"
      "reset_gpio"
      "pwm_gpio"
      "pwm_bl"

      "drm_mipi_dbi"
      "panel_sitronix_st7701"

      "drm_exec"
      "drm_dma_helper"
      "drm_display_helper"
      "cec"
      "vc4"
    ];



    # Enable "Silent boot"
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "console=tty1"
      "fbcon=map:1"
      # "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "vt.global_cursor_default=0"
    ];
    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    loader.timeout = 0;
  };
}
