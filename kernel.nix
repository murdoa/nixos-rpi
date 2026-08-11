{ lib, ... }:
let
  inherit (lib.kernel) no;
in
{
  # Keep the pinned mainline kernel, but stop building one kernel for virtually
  # every arm64 SoC.  BCM2835 covers the Raspberry Pi 3's BCM2837.
  boot.kernelPatches = [
    {
      name = "rpi3-minimal-config";
      patch = null;
      structuredExtraConfig = lib.mapAttrs (_: lib.mkForce) {
        # Non-Raspberry-Pi arm64 platforms.
        ARCH_ACTIONS = no;
        ARCH_AIROHA = no;
        ARCH_SUNXI = no;
        ARCH_ALPINE = no;
        ARCH_APPLE = no;
        ARCH_BCM_IPROC = no;
        ARCH_BCMBCA = no;
        ARCH_BRCMSTB = no;
        ARCH_BERLIN = no;
        ARCH_BLAIZE = no;
        ARCH_EXYNOS = no;
        ARCH_SPARX5 = no;
        ARCH_K3 = no;
        ARCH_LG1K = no;
        ARCH_HISI = no;
        ARCH_KEEMBAY = no;
        ARCH_MEDIATEK = no;
        ARCH_MESON = no;
        ARCH_MVEBU = no;
        ARCH_NXP = no;
        ARCH_MA35 = no;
        ARCH_NPCM = no;
        ARCH_QCOM = no;
        ARCH_REALTEK = no;
        ARCH_RENESAS = no;
        ARCH_ROCKCHIP = no;
        ARCH_SEATTLE = no;
        ARCH_INTEL_SOCFPGA = no;
        ARCH_STM32 = no;
        ARCH_SYNQUACER = no;
        ARCH_TEGRA = no;
        ARCH_TESLA_FSD = no;
        ARCH_SPRD = no;
        ARCH_THUNDER = no;
        ARCH_THUNDER2 = no;
        ARCH_UNIPHIER = no;
        ARCH_VEXPRESS = no;
        ARCH_VISCONTI = no;
        ARCH_XGENE = no;
        ARCH_ZYNQMP = no;
      };
    }
  ];
}
