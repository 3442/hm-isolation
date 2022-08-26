#!@runtimeShell@
set -o errexit -o nounset -o pipefail

if [ -n "${__ENV_UNSHARE:-}" ]; then
	# https://github.com/NixOS/nixpkgs/issues/42117
	PATH=":$PATH:"
	PATH="${PATH//:\/run\/wrappers\/bin:/:}"
	PATH="${PATH#:}"
	PATH="${PATH%:}"

	MOUNT=@util_linux@/bin/mount
	UMOUNT=@util_linux@/bin/umount

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

	if [ ! -d "$PROFILES_SOURCE/profile" ]; then
		ln -sf -- "$(readlink -f "$PROFILES_TARGET/profile")" "$PROFILES_SOURCE/profile"
		export __ENV_ACTIVATE=1
	elif [ ! "$(readlink -f "$PROFILES_SOURCE/home-manager")" = "$__ENV_GENERATION" ]; then
		export __ENV_ACTIVATE=1
	fi

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
	exec @util_linux@/bin/setpriv --inh-caps=-all -- "@out@/bin/shenv" "$@"
elif [ -n "${__ENV_SHENV:-}" ]; then
	[ -n "${__ENV_ACTIVATE:-}" ] && { "$__ENV_GENERATION/activate" || true; }

	unset \
		__ENV_ACTIVATE __ENV_BTRFS __ENV_CONFIG__ENV_GENERATION \
		__ENV_PATH __ENV_PERSIST __ENV_SHENV __ENV_VIEW

	exec -- "$@"
fi

eval set -- "$(@util_linux@/bin/getopt \
	-n shenv \
	-l help,version,activate,list,path,print-path \
	-o +hvalpP \
	-- "$@")"

usage() {
	cat >&2 <<-EOF
	usage: $0 [options] <env> [-- <program> [arguments]]
	  -h, --help        Print this message and exit
	  -v, --version     Print version and exit
	  -a, --activate    Activate the Home Manager generation
	  -l, --list        List available environments
	  -p, --path        Only add the environment's path to \$PATH
	  -P, --print-path  Print the environment's path and exit
	EOF
}

OPT_ACTIVATE=""
OPT_LIST=""
OPT_PATH=""
OPT_PRINT_PATH=""

while true; do
	case "$1" in
		-h|--help)
			usage
			exit
			;;

		-a|--activate)
			OPT_ACTIVATE=1
			shift
			;;

		-l|--list)
			OPT_LIST=1
			shift
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

		-v|--version)
			echo "hm-isolation utility (shenv) @version@"
			exit
			;;

		*)
			usage
			exit 1
			;;
	esac
done

STATIC="${XDG_CONFIG_HOME:-$HOME/.config}/hm-isolation/static"

[ -n "$OPT_LIST" ] && {
	[ -d "$STATIC" ] && find -- "$STATIC/" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
	exit
}

[ $# -ge 1 ] || { usage; exit 1; }
ENV="$1"
shift
[ $# -eq 0 ] && set -- "$SHELL"

ENV_DIR="$STATIC/$ENV"

[ -f "$ENV_DIR/env" ] || {
	echo "$0: environment '$ENV' not found"
	exit 1
}

set -a
# shellcheck disable=SC1091
. "$ENV_DIR/env"
set +a

[ "$__ENV_SHENV" = "@out@" ] || {
	echo "$0: environment does not match this version of hm-isolation: $ENV_DIR" >&2
	exit 1
}

[ -n "${__ENV_CONFIG:-}" ] || OPT_PATH=1

if [ -n "$OPT_PRINT_PATH" ]; then
	echo "$__ENV_PATH"
	exit
elif [ -n "$OPT_PATH" ]; then
	PATH="$__ENV_PATH:$PATH" exec -- "$@"
fi

if [ -n "${__ENV_PERSIST:-}" ]; then
	PERSIST="$HOME/$__ENV_PERSIST"
	if [ -n "@btrfs_progs@" ]; then
		if [ -n "${__ENV_BTRFS:-}" ]; then
			mkdir -p "$(dirname "$PERSIST")"
			[ ! -e "$PERSIST" ] && @btrfs_progs@/bin/btrfs subvolume create "$PERSIST"
		else
			mkdir -p "$PERSIST"
		fi
	else
		# No btrfs support
		mkdir -p "$PERSIST"
	fi
fi

[ -n "$OPT_ACTIVATE" ] && export __ENV_ACTIVATE=1

__ENV_UNSHARE=1 exec @util_linux@/bin/unshare -Ucm --keep-caps -- "$0" "$@"
