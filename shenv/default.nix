{ btrfs-progs, config, runtimeShell, shellcheck, stdenv, util-linux, ... }:
let
  cfg = config.home.isolation;
  version = "0.1.3";
in stdenv.mkDerivation {
  pname = "shenv";
  inherit version;
  src = ./.;

  inherit runtimeShell;
  btrfs_progs = if cfg.btrfsSupport then btrfs-progs else null; 
  util_linux = util-linux;

  installPhase = ''
    mkdir -p $out/bin $out/share/zsh/site-functions
    substituteAll $src/shenv.sh $out/bin/shenv
    chmod +x $out/bin/shenv
    cp $src/completion.zsh $out/share/zsh/site-functions/_shenv
  '';

  checkPhase = ''
    ${stdenv.shellDryRun} $out/bin/shenv
    ${shellcheck}/bin/shellcheck $out/bin/shenv
  '';

  meta.mainProgram = "shenv";
}
