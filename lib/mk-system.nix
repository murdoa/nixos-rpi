{ nixpkgs }:
{
  buildSystem,
  targetSystem,
  modules,
  specialArgs ? { },
}:
nixpkgs.lib.nixosSystem {
  system = buildSystem;
  inherit specialArgs;
  modules =
    modules
    ++ nixpkgs.lib.optionals (buildSystem != targetSystem) [
      {
        nixpkgs.crossSystem = {
          system = targetSystem;
        };
      }
    ];
}
