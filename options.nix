{ lib, ... }:
with lib.types; let
  inherit (lib) mkOption mkEnableOption;
in {
  options.home.isolation = {
    enable = mkEnableOption "isolated user environments";

    active = mkOption {
      type = bool;
      description = ''
        Whether the current configuration being evaluated is for an isolated
        environment. You can use this option to disable heavier parts of your
        home configuration for isolated environments, improving build times.
        Never set this option, it is determined automatically.
      '';
    };

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

          persist = mkOption {
            default = {};
            description = ''
              Options controlling persistence of the environment's home directory.
            '';

            type = submodule {
              options = {
                under = mkOption {
                  default = null;
                  type = nullOr str;
                  description = ''
                    This directory becomes the home directory of the environment.
                    Setting this option to a non-null value enables environment
                    persistence. The path is relative to the real home directory
                    and is created upon environment entry if it doesn't exist.
                  '';
                };
              };
            };
          };
        };
      });
    };
  };
}
