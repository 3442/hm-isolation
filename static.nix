{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.home.isolation;
  statics = filterAttrs (_: opts: opts.static) cfg.environments;

  common = {
    ENVS = attrNames statics;
    SHENV = pkgs.callPackage ./shenv { inherit config; };
  };

  envVars = name: env: let
    maybeNull = arg: escapeShellArg (optionalString (arg != null) arg);
    specialization = config.specialization."shenv-${name}".configuration;
  in {
    "ENV_${name}_CONFIG" =
      optionalString env.namespaced "${specialization.xdg.configHome}/hm-isolation";

    "ENV_${name}_PATH" = makeBinPath env.packages;
  } // optionalAttrs env.namespaced {
    "ENV_${name}_BTRFS" = env.persist.btrfs;
    "ENV_${name}_GENERATION" = specialization.home.activationPackage;
    "ENV_${name}_PERSIST" = maybeNull env.persist.under;
    "ENV_${name}_VIEW" = maybeNull env.bindHome;
  };

  static = pkgs.runCommand
    "static-shenvs"
    (fold mergeAttrs common (mapAttrsToList envVars statics))
    ''
      for ENV in $ENVS; do
        mkdir -p $out/$ENV
        cd $out/$ENV

        BTRFS="ENV_''${ENV}_BTRFS"
        CONFIG="ENV_''${ENV}_CONFIG"
        GENERATION="ENV_''${ENV}_GENERATION"
        PATH_="ENV_''${ENV}_PATH"
        PERSIST="ENV_''${ENV}_PERSIST"
        VIEW="ENV_''${ENV}_VIEW"

        echo "__ENV_SHENV=$SHENV" >env
        echo "__ENV_PATH=''${!PATH_}" >>env
        [ -n "''${!CONFIG}" ] || continue

        echo "__ENV_CONFIG=''${!CONFIG}" >>env
        echo "__ENV_GENERATION=''${!GENERATION}" >>env
        echo "__ENV_PERSIST=''${!PERSIST}" >>env
        echo "__ENV_VIEW=''${!VIEW}" >>env

        if [ -n "''${!BTRFS}" ]; then
          echo "__ENV_BTRFS=1" >>env
        fi
      done
    '';

  specialization = env: {
    home = {
      isolation.active = mkForce true;
      packages = env.packages;
    };
  };
in {
  config = mkIf (cfg.enable && statics != {}) {
    # This prevents infinite recursion between activationPackages and env files
    xdg = mkIf (!cfg.active) {
      configFile."hm-isolation/static".source = static;
    };

    specialization = mapAttrs' (name: env: {
      name = "shenv-${name}";
      value.configuration = mkMerge [ (specialization env) env.hm ];
    }) (filterAttrs (_: env: env.namespaced) statics);
  };
}
