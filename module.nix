{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.home.isolation;
in {
  imports = [ ./options.nix ./static.nix ];

  config = mkIf cfg.enable {
    home.packages = [ (pkgs.callPackage ./shenv {}) ];
  };
}
