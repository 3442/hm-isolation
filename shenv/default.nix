{ btrfs-progs, config, runtimeShell, shellcheck, stdenv, util-linux, ... }:
let
  cfg = config.home.isolation;
  version = "0.1.2";
in stdenv.mkDerivation {
  pname = "shenv";
  inherit version;
  src = ./.;

  inherit runtimeShell;
  btrfs_progs = if cfg.btrfsSupport then btrfs-progs else null; 
  util_linux = util-linux;

  installPhase = ''
    mkdir -p $out/bin
    substituteAll $src/shenv.sh $out/bin/shenv
    chmod +x $out/bin/shenv
  '';

  checkPhase = ''
    ${stdenv.shellDryRun} $out/bin/shenv
    ${shellcheck}/bin/shellcheck $out/bin/shenv
  '';

  meta.mainProgram = "shenv";
}
