{ btrfs-progs ? null, shenv, util-linux }: ''
if [ -n "''${__ENV_UNSHARE:-}" ]; then
	# https://github.com/NixOS/nixpkgs/issues/42117
	PATH=":$PATH:"
	PATH="''${PATH//:\/run\/wrappers\/bin:/:}"
	PATH="''${PATH#:}"
	PATH="''${PATH%:}"

	MOUNT=${util-linux}/bin/mount
	UMOUNT=${util-linux}/bin/umount

	cd
	if [ -n "$__ENV_VIEW" ]; then
		PIVOT="$(mktemp -d)"
		trap 'rm -df -- "$PIVOT"' EXIT
		$MOUNT --rbind -- . "$PIVOT"
	fi

	if [ -n "$__ENV_PERSIST" ]; then
		$MOUNT --rbind -- "$__ENV_PERSIST" .
	else
		$MOUNT -t tmpfs tmpfs .
	fi

	cd

	PROFILES_SOURCE="$__ENV_CONFIG/self/profiles"
	GCROOTS_SOURCE="$__ENV_CONFIG/self/gcroots"
	PROFILES_TARGET="/nix/var/nix/profiles/per-user/$USER"
	GCROOTS_TARGET="/nix/var/nix/gcroots/per-user/$USER"

	mkdir -p -- "$PROFILES_SOURCE" "$GCROOTS_SOURCE"
	[ -d "$PROFILES_SOURCE/profile" ] || {
		ln -sf -- "$(readlink -f "$PROFILES_TARGET/profile")" "$PROFILES_SOURCE/profile"
	}

	$MOUNT --rbind -- "$PROFILES_SOURCE" "$PROFILES_TARGET"
	$MOUNT --rbind -- "$GCROOTS_SOURCE" "$GCROOTS_TARGET"

	if [ -n "$__ENV_VIEW" ]; then
		mkdir -p "./$__ENV_VIEW"
		[ -d /run/mount ] && $MOUNT -t tmpfs tmpfs /run/mount
		$MOUNT --move -- "$PIVOT" "./$__ENV_VIEW"
		[ -d /run/mount ] && $UMOUNT /run/mount
		rm -df -- "$PIVOT"
	fi

	unset __ENV_UNSHARE

	# We cannot use $0 here since that may reference $HOME
	exec ${util-linux}/bin/setpriv --inh-caps=-all -- "${shenv}/bin/shenv" "$@"
elif [ -n "''${__ENV_SHENV:-}" ]; then
	"$__ENV_GENERATION/activate" || true

	unset \
		__ENV_BTRFS __ENV_CONFIG__ENV_GENERATION \
		__ENV_PATH __ENV_PERSIST __ENV_SHENV __ENV_VIEW

	exec -- "$@"
fi

eval set -- "$(${util-linux}/bin/getopt \
	-n shenv \
	-l help,path,print-path \
	-o +hpP \
	-- "$@")"

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
	PATH="$__ENV_PATH:$PATH" exec -- "$@"
fi

if [ -n "$__ENV_PERSIST" ]; then
	PERSIST="$HOME/$__ENV_PERSIST"
	${if btrfs-progs != null then ''
		if [ -n "''${__ENV_BTRFS:-}" ]; then
			mkdir -p "$(dirname "$PERSIST")"
			[ ! -e "$PERSIST" ] && ${btrfs-progs}/bin/btrfs subvolume create "$PERSIST"
		else
			mkdir -p "$PERSIST"
		fi
	'' else ''
		# No btrfs support
		mkdir -p "$PERSIST"
	''}
fi

__ENV_UNSHARE=1 exec ${util-linux}/bin/unshare -Ucm --keep-caps -- "$0" "$@"
''
