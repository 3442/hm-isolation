{ config, lib, ... }:
with lib.types; let
  inherit (lib) mkEnableOption mkOption mkOptionDefault;
  cfg = config.home.isolation;
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

    btrfsSupport = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable support for persistent directories backed by btrfs subvolumes.
      '';
    };

    defaults = {
      static = mkOption {
        type = bool;
        default = true;

        description = ''
          Default for <xref linkend="opt-home.isolation.environments._name_.static"/>.
        '';
      };

      namespaced = mkOption {
        type = bool;
        default = false;

        description = ''
          Default for <xref linkend="opt-home.isolation.environments._name_.namespaced"/>.
        '';
      };

      bindHome = mkOption {
        type = nullOr str;
        default = null;
        example = "real-home/";

        description = ''
          Default for <xref linkend="opt-home.isolation.environments._name_.bindHome"/>.
        '';
      };

      persist = {
        base = mkOption {
          type = nullOr str;
          default = null;

          description = ''
            Default base for persistent directories, used in the default value of
            <xref linkend="opt-home.isolation.environments._name_.persist.base"/>.
          '';
        };

        btrfs = mkOption {
          type = bool;
          default = false;

          description = ''
            Default for <xref linkend="opt-home.isolation.environments._name_.persist.btrfs"/>.
          '';
        };
      };
    };

    environments = mkOption {
      default = {};
      description = ''
        Set of environments known at Home Manager build time.
      '';

      type = attrsOf (submodule ({ name, ... }: {
        options = {
          static = mkOption {
            type = bool;
            default = cfg.defaults.static;
            defaultText = "config.home.isolation.defaults.static";

            description = ''
              Whether to build this environment and all its dependencies along
              usual Home Manager generations. If set to false, environments will
              be built on demand and won't survive the garbage collector.
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

          namespaced = mkOption {
            type = bool;
            default = cfg.defaults.namespaced;
            defaultText = "config.home.isolation.defaults.namespaced";

            description = ''
              Whether to run this environment in separate user and mount namespaces.
              With namespaces, each environment gets its own private $HOME. This
              requires kernel support for unrestricted user namespaces. Several other
              environment options require namespaces.
            '';
          };

          bindHome = mkOption {
            type = nullOr str;
            default = cfg.defaults.bindHome;
            defaultText = "config.home.isolation.defaults.bindHome";
            example = "real-home/";

            description = ''
              Where to bind-mount the real /home inside the environment's mount namespace.
              This path is relative to $HOME.
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
                  type = nullOr str;
                  defaultText = "\"\${config.home.isolation.defaults.persist.base}/\${name}\"";

                  description = ''
                    This directory becomes the home directory of the environment.
                    Setting this option to a non-null value enables environment
                    persistence. The path is relative to the real home directory
                    and is created upon environment entry if it doesn't exist.
                  '';
                };

                btrfs = mkOption {
                  type = bool;
                  default = cfg.defaults.persist.btrfs;
                  defaultText = "config.home.isolation.defaults.persist.btrfs";

                  description = ''
                    Create the persistent directory as a btrfs subvolume if it
                    doesn't exist. Require <xref linkend="opt-home.isolation.btrfsSupport"/>.
                  '';
                };
              };
            };
          };

          config = mkOption {
            type = attrs; # TODO: extendModules does not work here
            default = {};
            visible = "shallow";

            description = ''
              Arbitrary Home Manager configuration settings.
            '';
          };
        };

        config.persist.under = let
          under = if cfg.defaults.persist.base != null
            then "${cfg.defaults.persist.base}/${name}"
            else null;
        in mkOptionDefault under;
      }));
    };
  };

  config.assertions = with lib; [
    {
      assertion =
        any (env: env.persist.btrfs) (attrValues cfg.environments) -> cfg.btrfsSupport;

      message =
        "Isolated environments with btrfs persistence require home.isolation.btrfsSupport";
    }
  ];
}
