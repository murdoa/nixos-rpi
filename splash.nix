{
  pkgs,
  lib,
  config,
  ...
}:
{
  boot = {
    plymouth = {
      enable = true;
      theme = "cuts";
      themePackages = with pkgs; [
        # By default we would install all themes
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "cuts" ];
        })
      ];
    };

    initrd.kernelModules = [
      "panel_sitronix_st7701"
      "drm_mipi_dbi"

      "vc4"
      "cec"
      "drm_dma_helper"
      "drm_display_helper"
      "drm_exec"

      "spi_gpio"
      "spi-bitbang"

      "pwm_bl"
      "pwm_gpio"

      "reset_gpio"
    ];

  #   [   19.562649] vc4-drm soc:gpu: bound 3f400000.hvs (ops vc4_hvs_ops [vc4])
  # [   19.570618] rc rc0: vc4-hdmi as /devices/platform/soc/3f902000.hdmi/rc/rc0
  # [   19.570858] input: vc4-hdmi as /devices/platform/soc/3f902000.hdmi/rc/rc0/input3
  # [   19.583723] input: vc4-hdmi HDMI Jack as /devices/platform/soc/3f902000.hdmi/sound/card1/input4
  # [   19.584493] vc4-drm soc:gpu: bound 3f902000.hdmi (ops vc4_hdmi_ops [vc4])
  # [   19.584909] vc4-drm soc:gpu: bound 3f806000.vec (ops vc4_vec_ops [vc4])
  # [   19.692412] vc4-drm soc:gpu: bound 3f400000.hvs (ops vc4_hvs_ops [vc4])
  # [   19.695617] rc rc0: vc4-hdmi as /devices/platform/soc/3f902000.hdmi/rc/rc0
  # [   19.697865] input: vc4-hdmi as /devices/platform/soc/3f902000.hdmi/rc/rc0/input7
  # [   19.706376] input: vc4-hdmi HDMI Jack as /devices/platform/soc/3f902000.hdmi/sound/card1/input8
  # [   19.706985] vc4-drm soc:gpu: bound 3f902000.hdmi (ops vc4_hdmi_ops [vc4])
  # [   19.707382] vc4-drm soc:gpu: bound 3f806000.vec (ops vc4_vec_ops [vc4])
  # [   19.707678] vc4-drm soc:gpu: bound 3f208000.dpi (ops vc4_dpi_ops [vc4])
  # [   19.708086] vc4-drm soc:gpu: bound 3f004000.txp (ops vc4_txp_ops [vc4])
  # [   19.708560] vc4-drm soc:gpu: bound 3f206000.pixelvalve (ops vc4_crtc_ops [vc4])
  # [   19.708921] vc4-drm soc:gpu: bound 3f207000.pixelvalve (ops vc4_crtc_ops [vc4])
  # [   19.709376] vc4-drm soc:gpu: bound 3f807000.pixelvalve (ops vc4_crtc_ops [vc4])
  # [   19.713820] vc4-drm soc:gpu: bound 3fc00000.v3d (ops vc4_v3d_ops [vc4])
  # [   19.731841] [drm] Initialized vc4 0.0.0 for soc:gpu on minor 0
  # [   20.329689] vc4-drm soc:gpu: [drm] fb0: vc4drmfb frame buffer device


    # Enable "Silent boot"
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "fbcon=map:1"
      "console=tty1"
    ];
    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    loader.timeout = 0;
  };
}
