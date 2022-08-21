{ getopt, util-linux, writeShellApplication, ... }:
let
  shenv = writeShellApplication {
    name = "shenv";
    runtimeInputs = [ getopt util-linux ];

    text = import ./shenv.nix {
      shenv = placeholder "out";
    };
  };
in shenv
