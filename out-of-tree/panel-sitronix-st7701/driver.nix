{
  stdenv,
  lib,
  kernel,
  kernelModuleMakeFlags,
}:

let
  release = "0.1.0";

in
stdenv.mkDerivation {
  pname = "panel-sitronix-st7701";
  version = "${kernel.version}-${release}";

  src = ./src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags;

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail '/lib/modules/$(shell uname -r)/build' ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
  '';

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    find . -name '*.ko' -exec xz -f {} \;
    install -Dm444 -t $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/gpu/drm/panel/ *.ko.xz
    runHook postInstall
  '';
}