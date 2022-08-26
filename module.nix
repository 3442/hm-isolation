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
    };
  };
}
