{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.home.isolation;
in {
  imports = [ ./options.nix ./static.nix ];

  home = {
    isolation.active = false;
    packages = optional cfg.enable (pkgs.callPackage ./shenv { inherit config; });
  };
}
