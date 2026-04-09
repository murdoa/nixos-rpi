{ nixpkgs }:
let
  boards = import ./boards.nix;
  mkRpiSystemImpl = import ./mk-system.nix { inherit nixpkgs boards; };
  mkFlashApp = import ./flash-app.nix { inherit nixpkgs; };
in
{
  inherit boards mkFlashApp;

  mkRpiSystem = mkRpiSystemImpl;
}
