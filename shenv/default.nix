{ btrfs-progs, config, util-linux, writeShellApplication, ... }:
let
  cfg = config.home.isolation;
in writeShellApplication {
  name = "shenv"; #TODO: change to pname and add version

  text = import ./shenv.nix {
    inherit util-linux;
    shenv = placeholder "out";
    btrfs-progs = if cfg.btrfsSupport then btrfs-progs else null; 
  };
}
