{ config, lib, extendModules, ... }:
with lib.types; let
  inherit (lib) mkEnableOption mkForce mkOption mkOptionDefault mkOverride optionalString;
  outerConfig = config;
  cfg = config.home.isolation;
in {
  options.home.isolation = {
    enable = mkEnableOption "isolated user environments";

    active = mkOption {
      type = bool;
      default = false;

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

      type = attrsOf (submodule ({ config, name, ... }: {
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
                enable = mkOption {
                  type = bool;
                  defaultText = "namespaced";

                  description = ''
                    Whether to enable home environment persistence.
                  '';
                };

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

          hm = mkOption {
            default = {};
            visible = "shallow";

            description = ''
              Arbitrary Home Manager configuration.
            '';

            type = (extendModules {
              modules = [ {
                specialization = mkOverride 0 {};

                home = {
                  inherit (config) packages;

                  extraBuilderCommands = ''
                    substituteInPlace $out/activate \
                      --replace 'declare -gr ' 'declare -g '
                  '';

                  activation.isolateProfile =
                    (lib.hm.dag.entryBefore [ "checkLinkTargets" "checkFilesChanged" ] ''
                      declare -g isolationSelfPath="${config.hm.xdg.configHome}/hm-isolation/self"
                      declare -g nixProfilePath="$isolationSelfPath/profile"
                      declare -g genProfilePath="$isolationSelfPath/home-manager"
                      declare -g newGenGcPath="$genProfilePath"
                      declare -g oldGenPath="$(readlink -f "$genProfilePath")"

                      declare -g oldGenNum=0
                      declare -g newGenNum=0
                    '');

                  activation.installPackages = mkForce
                    (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                      $DRY_RUN_CMD ln -Tsf -- $newGenPath/home-path "$HOME/.nix-profile"
                    '');

                  activation.cleanIsolationSelf = mkOverride 0
                    (lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
                      $DRY_RUN_CMD mkdir -p "$isolationSelfPath"
                    '');

                  homeDirectory = let
                    path = optionalString
                      (config.persist.enable && !config.namespaced)
                      "/${config.persist.under}";
                  in mkForce "${outerConfig.home.homeDirectory}${path}";

                  isolation = {
                    active = mkOverride 0 true;
                    environments = mkOverride 0 {};
                  };
                };
              } ];
            }).type;

            apply = hm: if config.namespaced || config.persist.enable then hm else outerConfig;
          };
        };

        config.persist = {
          enable = mkOptionDefault (config.namespaced && cfg.defaults.persist.base != null);

          under = mkOptionDefault
            (if config.persist.enable && cfg.defaults.persist.base != null
              then "${cfg.defaults.persist.base}/${name}"
              else null);
        };
      }));
    };

    modules = mkOption {
      type = attrsOf path;
      default = {};

      description = ''
        Setting this option allows you to define environments in their own module
        set, separate from the outer Home Manager configuration tree. Note that
        these module are imported as submodules of the environment. Thus, options
        such as <literal>static</literal> and <literal>packages</literal> are exposed
        to it at the root of the module option and configuration hierarchy.
      '';
    };

    modulesUnder = mkOption {
      type = nullOr path;
      default = null;

      description = ''
        If set, imports all files and directories under the path and defines one
        environment module per node. The environment name is taken from the filename
        after removing any <literal>.nix</literal> suffix. The base path must be a directory.
      '';
    };
  };

  config = with lib; let
    errors = [
      (env: {
        assertion = env.persist.enable -> env.persist.under != null;

        message =
          "persistence is enabled but persist.under is not set";
      })

      (env: {
        assertion = env.persist.btrfs -> cfg.btrfsSupport;

        message =
          "btrfs persistence requires home.isolation.btrfsSupport";
      })
    ];

    warns = [
      (env: {
        assertion = !env.persist.enable -> env.persist.under == null;

        message =
          "not persistent, but persist.under is set";
      })
    ];

    named = map (c: name: env: (c: {
      inherit (c) assertion;
      message = "environment '${name}': ${c.message}";
    }) (c env));

    checks = checks: flatten
      (mapAttrsToList (name: env: map (a: a name env) (named checks)) cfg.environments);
  in mkIf cfg.enable {
    warnings = map (w: w.message) (filter (w: !w.assertion) (checks warns));
    assertions = checks errors;
  };
}
