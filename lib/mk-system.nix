{ nixpkgs, boards }:
args@{
  buildSystem,
  modules ? [ ],
  specialArgs ? { },
  board ? null,
  targetSystem ? null,
}:
let
  boardDef = if board == null then null else boards.${board};
  resolvedTargetSystem = if targetSystem != null then targetSystem else boardDef.targetSystem;
  boardModule = if boardDef == null then [ ] else [ boardDef.module ];
in
nixpkgs.lib.nixosSystem {
  system = buildSystem;
  inherit specialArgs;
  modules =
    boardModule
    ++ modules
    ++ nixpkgs.lib.optionals (buildSystem != resolvedTargetSystem) [
      {
        nixpkgs.crossSystem = {
          system = resolvedTargetSystem;
        };
      }
    ];
}
