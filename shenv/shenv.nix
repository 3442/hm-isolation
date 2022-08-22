{ shenv }: ''
if [ -n "''${__ENV_UNSHARE:-}" ]; then
	# https://github.com/NixOS/nixpkgs/issues/42117
	PATH=":$PATH:"
	PATH="''${PATH//:\/run\/wrappers\/bin:/:}"
	PATH="''${PATH#:}"
	PATH="''${PATH%:}"

	cd
	PIVOT="$(mktemp -d)"
	trap 'rm -df -- "$PIVOT"' EXIT
	mount --rbind -- . "$PIVOT"
	mount -t tmpfs tmpfs .

	cd
	mkdir -p "./$__ENV_VIEW"
	[ -d /run/mount ] && mount -t tmpfs tmpfs /run/mount
	mount --move -- "$PIVOT" "./$__ENV_VIEW"
	[ -d /run/mount ] && umount /run/mount
	rm -df -- "$PIVOT"

	unset __ENV_UNSHARE

	# We cannot use $0 here since that may reference $HOME
	exec setpriv --inh-caps=-all -- "${shenv}/bin/shenv" "$@"
elif [ -n "''${__ENV_SHENV:-}" ]; then
	"$__ENV_GENERATION/activate" || true
	unset __ENV_GENERATION __ENV_PATH __ENV_SHENV __ENV_VIEW
	exec -- "$@"
fi

eval set -- "$(getopt -n shenv -l help,path,print-path -o +hpP -- "$@")"

usage() {
	cat >&2 <<-EOF
	usage: $0 [options] <env> [-- <program> [arguments]]
	  -h, --help        Print this message and exit
	  -p, --path        Only add the environment's path to \$PATH
	  -P, --print-path  Print the environment's path and exit
	EOF
}

OPT_PATH=""
OPT_PRINT_PATH=""

while true; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;

		-p|--path)
			OPT_PATH=1
			shift
			;;

		-P|--print-path)
			OPT_PRINT_PATH=1
			shift
			;;

		--)
			shift
			break
			;;

		*)
			usage
			exit 1
			;;
	esac
done

[ $# -ge 1 ] || { usage; exit 1; }
ENV="$1"
shift
[ $# -eq 0 ] && set -- "$SHELL"

CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/hm-isolation"
ENV_DIR="$CONFIG/static/$ENV"

[ -f "$ENV_DIR/env" ] || {
	echo "$0: environment '$ENV' not found"
	exit 1
}

set -a
# shellcheck disable=SC1091
. "$ENV_DIR/env"
set +a

[ "$__ENV_SHENV" = "${shenv}" ] || {
	echo "$0: environment does not match this version of hm-isolation: $ENV_DIR" >&2
	exit 1
}

if [ -n "$OPT_PRINT_PATH" ]; then
	echo "$__ENV_PATH"
	exit 0
elif [ -n "$OPT_PATH" ]; then
	PATH="$__ENV_PATH:$PATH"
	exec -- "$@"
fi

__ENV_UNSHARE=1 exec unshare -Ucm --keep-caps -- "$0" "$@"
''
