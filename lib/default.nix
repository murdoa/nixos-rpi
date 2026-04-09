{ nixpkgs }:
let
  boards = import ./boards.nix;
  mkRpiSystemImpl = import ./mk-system.nix { inherit nixpkgs boards; };
  mkFlashApp = import ./flash-app.nix { inherit nixpkgs; };
  imageLib = import ./image.nix { inherit nixpkgs; };
in
{
  inherit boards mkFlashApp;
  inherit (imageLib) mkHybridImage mkImage;

  mkRpiSystem = mkRpiSystemImpl;
}
