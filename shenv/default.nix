{ util-linux, writeShellApplication, ... }:
let
  shenv = writeShellApplication {
    name = "shenv";
    text = import ./shenv.nix {
      shenv = placeholder "out";
      inherit util-linux;
    };
  };
in shenv
