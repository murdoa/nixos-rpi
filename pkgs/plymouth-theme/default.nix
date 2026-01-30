{ stdenv, lib, unzip }:

stdenv.mkDerivation {
  pname = "plymouth-abstract-ring-alt-theme";
  version = "1.0";

  src = ./abstract_ring_alt.zip;

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/share/plymouth/themes
    
    # Copy the theme directory (adjust the theme folder name as needed)
    cp -r abstract_ring_alt $out/share/plymouth/themes/
    
    # Fix paths in .plymouth files to point to the nix store
    find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@/usr/@$out/@" {} \;
  '';

  meta = with lib; {
    description = "adi1090x's plymouth theme abstract_ring_alt resized to 240x240";
    platforms = platforms.linux;
  };
}