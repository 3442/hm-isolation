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
    withGen = env.namespaced || env.persist.enable;
    relocateHome = !env.namespaced && env.persist.enable;
    maybeNull = arg: escapeShellArg (optionalString (arg != null) arg);
  in {
    "ENV_${name}_PATH" = makeBinPath env.packages;

    "ENV_${name}_CONFIG" = optionalString withGen "${env.hm.xdg.configHome}/hm-isolation";
    "ENV_${name}_GENERATION" = optionalString withGen "${env.hm.home.activationPackage}";

    "ENV_${name}_PERSIST" = optionalString env.persist.enable env.persist.under;
    "ENV_${name}_PATCHVARS" = relocateHome && env.persist.patchVars;
    "ENV_${name}_BTRFS" = env.persist.enable && env.persist.btrfs;

    "ENV_${name}_VIEW" = optionalString env.namespaced (maybeNull env.bindHome);
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
        PATCHVARS="ENV_''${ENV}_PATCHVARS"
        PERSIST="ENV_''${ENV}_PERSIST"
        VIEW="ENV_''${ENV}_VIEW"

        echo "__ENV_SHENV=$SHENV" >env
        echo "__ENV_PATH=''${!PATH_}" >>env

        if [ -n "''${!CONFIG}" ]; then
          echo "__ENV_CONFIG=''${!CONFIG}" >>env
          echo "__ENV_GENERATION=''${!GENERATION}" >>env
        fi

        if [ -n "''${!PERSIST}" ]; then
          echo "__ENV_PERSIST=''${!PERSIST}" >>env
          echo "__ENV_PATCHVARS=''${!PATCHVARS}" >>env
          echo "__ENV_BTRFS=''${!BTRFS}" >>env
        fi

        if [ -n "''${!VIEW}" ]; then
          echo "__ENV_VIEW=''${!VIEW}" >>env
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
