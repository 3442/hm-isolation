{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.home.isolation;

  statics = filterAttrs (_: opts: opts.static) cfg.environments;
  nonStatics = filterAttrs (_: opts: !opts.static) cfg.environments;

  common = envs: {
    ENVS = attrNames envs;
    SHENV = pkgs.callPackage ./shenv { inherit config; };
  };

  envVars = name: env: let
    maybeNull = arg: escapeShellArg (optionalString (arg != null) arg);
  in {
    "ENV_${name}_CONFIG" =
      optionalString env.namespaced "${env.hm.xdg.configHome}/hm-isolation";

    "ENV_${name}_PATH" = makeBinPath env.packages;
  } // optionalAttrs env.namespaced {
    "ENV_${name}_BTRFS" = env.persist.btrfs;
    "ENV_${name}_GENERATION" = env.hm.home.activationPackage;
    "ENV_${name}_PERSIST" = maybeNull env.persist.under;
    "ENV_${name}_VIEW" = maybeNull env.bindHome;
  };

  envFiles = name: envs: pkgs.runCommand name
    (fold mergeAttrs (common envs) (mapAttrsToList envVars envs))
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
in {
  # This prevents infinite recursion between activationPackages and env files
  xdg.configFile = let
    staticConf."hm-isolation/static".source = envFiles "static-shenvs" statics;
    drvConf = mapAttrs' drv nonStatics;

    drv = name: env: {
      name = "hm-isolation/drv/${name}";
      value.source = builtins.unsafeDiscardOutputDependency
        (envFiles "shenv-${name}" { "${name}" = env; }).drvPath;
    };
  in mkIf (cfg.enable && !cfg.active) (drvConf // optionalAttrs (statics != {}) staticConf);
}
