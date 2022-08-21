{ lib, ... }:
with lib.types; let
  inherit (lib) mkOption mkEnableOption;
in {
  options.home.isolation.enable = mkEnableOption "isolated user environments";
}
