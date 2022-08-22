{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.home.isolation;
  statics = filterAttrs (_: opts: opts.static) cfg.environments;

  common = {
    ENVS = attrNames statics;
    SHENV = pkgs.callPackage ./shenv {};
  };

  envVars = name: env: {
    "ENV_${name}_GENERATION" =
      config.specialization."shenv-${name}".configuration.home.activationPackage;

    "ENV_${name}_VIEW" = escapeShellArg env.bindHome;
    "ENV_${name}_PATH" = makeBinPath env.packages;
  };

  static = pkgs.runCommand
    "static-shenvs"
    (fold mergeAttrs common (mapAttrsToList envVars statics))
    ''
      for ENV in $ENVS; do
        mkdir -p $out/$ENV
        cd $out/$ENV

        GENERATION="ENV_''${ENV}_GENERATION"
        VIEW="ENV_''${ENV}_VIEW"
        PATH_="ENV_''${ENV}_PATH"

        echo "__ENV_SHENV=$SHENV" >env
        echo "__ENV_GENERATION=''${!GENERATION}" >>env
        echo "__ENV_VIEW=''${!VIEW}" >>env
        echo "__ENV_PATH=''${!PATH_}" >>env
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
      value.configuration = specialization env;
    }) statics;
  };
}
