{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.home.isolation;
  shenv = pkgs.callPackage ./shenv {};
in {
  config = mkIf cfg.enable {
    home.packages = [ shenv ];
  };
}
