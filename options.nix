{ lib, ... }:
with lib.types; let
  inherit (lib) mkOption mkEnableOption;
in {
  options.home.isolation = {
    enable = mkEnableOption "isolated user environments";

    environments = mkOption {
      default = {};
      description = ''
        Set of static environments known at Home Manager build time.
      '';

      type = attrsOf (submodule {
        options = {
          static = mkOption {
            type = bool;

            description = ''
              Whether to build this environment and all its dependencies along
              usual Home Manager generations. If set to false, environments will
              be built on demand and won't survive the garbage collector.
            '';
          };

          bindHome = mkOption {
            type = str;
            example = "real-home/";

            description = ''
              Where to bind-mount the real /home inside the environment's mount namespace.
              This path is relative to $HOME.
            '';
          };

          packages = mkOption {
            type = listOf package;
            default = [];

            example = literalExpression ''
              with pkgs; [ ghc python310 octave ]
            '';

            description = ''
              Set of packages to include in the environment path.
            '';
          };
        };
      });
    };
  };
}