{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.home.isolation;
in {
  imports = [ ./options.nix ./static.nix ];

  home = mkIf cfg.enable {
    packages = [ (pkgs.callPackage ./shenv { inherit config; }) ];

    isolation = {
      active = mkForce false;

      environments = let
        rootModule = module: { ... }: {
          inherit (config) _module;
          imports = [ module ];
        };
      in mapAttrs (_: rootModule) cfg.modules;

      modules = let
        listing = filterAttrs isModule (builtins.readDir cfg.modulesUnder);
        isModule = name: type: hasSuffix ".nix" name || type == "directory";

        module = name: _: {
          name = removeSuffix ".nix" name;
          value = cfg.modulesUnder + "/${name}";
        };
      in optionalAttrs (cfg.modulesUnder != null) (mapAttrs' module listing);
    };
  };
}
