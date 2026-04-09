{
  pi3 = {
    targetSystem = "aarch64-linux";
    module = ../hosts/pi3.nix;
    imageAttr = "pi3";
    nativeImageAttr = "pi3-native";
    needsHybridMbr = true;
  };

  pi3b = {
    targetSystem = "aarch64-linux";
    module = ../hosts/pi3b.nix;
    imageAttr = "pi3b";
    nativeImageAttr = "pi3b-native";
    needsHybridMbr = true;
  };

  pi3bplus = {
    targetSystem = "aarch64-linux";
    module = ../hosts/pi3bplus.nix;
    imageAttr = "pi3bplus";
    nativeImageAttr = "pi3bplus-native";
    needsHybridMbr = true;
  };

  pi4 = {
    targetSystem = "aarch64-linux";
    module = ../hosts/pi4.nix;
    imageAttr = "pi4";
    nativeImageAttr = "pi4-native";
    needsHybridMbr = false;
  };

  pi0 = {
    targetSystem = "armv6l-linux";
    module = ../hosts/pi0.nix;
    imageAttr = "pi0";
    nativeImageAttr = null;
    needsHybridMbr = true;
  };
}
