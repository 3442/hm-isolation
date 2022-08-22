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
	exec setpriv --inh-caps=-all -- "${shenv}/bin/shenv"
elif [ -n "''${__ENV_SHENV:-}" ]; then
	"$__ENV_GENERATION/activate" || true
	unset __ENV_GENERATION __ENV_SHENV __ENV_VIEW
	exec -- "$SHELL"
fi

eval set -- "$(getopt -n shenv -l help -o h -- "$@")"

usage() {
	cat >&2 <<-EOF
	usage: $0 [options] <env>
	  -h, --help    Print this message and exit
	EOF
}

while true; do
	case "$1" in
		-h|--help)
			usage
			exit 0
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

[ $# -eq 1 ] || { usage; exit 1; }
ENV="$1"

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

__ENV_UNSHARE=1 exec unshare -Ucm --keep-caps -- "$0"
''
