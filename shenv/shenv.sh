#!@runtimeShell@
set -o errexit -o nounset -o pipefail

execTarget() {
	if [ -n "${__ENV_PERSIST:-}" ]; then
		export HOME="$HOME/$__ENV_PERSIST"
	fi

	if [ -n "${__ENV_GENERATION:-}" ]; then
		oldGenPath="$__ENV_CONFIG/self/home-manager"
		[ -e "$oldGenPath" ] && oldGen="$(readlink -f "$oldGenPath")"
		newGen="$(readlink -f "$__ENV_GENERATION")"

		# Note that __ENV_ACTIVATE can also be set in other ways
		[ ! "${oldGen:-}" = "$newGen" ] && __ENV_ACTIVATE=1
	fi

	[ -n "${__ENV_ACTIVATE:-}" ] && { "$__ENV_GENERATION/activate" || true; }

	unset \
		__ENV_ACTIVATE __ENV_BTRFS __ENV_CONFIG__ENV_GENERATION \
		__ENV_PATH __ENV_PERSIST __ENV_SHENV __ENV_VIEW

	if [ -n "${__ENV_GENERATION:-}" ]; then
		__HM_SESS_VARS_SOURCED=""
		source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" || true
	fi

	exec -- "$@"
}

if [ -n "${__ENV_VIEW+x}" ]; then
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

	if [ -n "${__ENV_PERSIST:-}" ]; then
		$MOUNT --rbind -- "$__ENV_PERSIST" .
	else
		$MOUNT -t tmpfs tmpfs .
	fi

	cd

	if [ -n "$__ENV_VIEW" ]; then
		mkdir -p "./$__ENV_VIEW"
		[ -d /run/mount ] && $MOUNT -t tmpfs tmpfs /run/mount
		$MOUNT --move -- "$PIVOT" "./$__ENV_VIEW"
		[ -d /run/mount ] && $UMOUNT /run/mount
		rm -df -- "$PIVOT"
	fi

	unset __ENV_VIEW __ENV_PERSIST

	# We should not use $0 here since that might reference $HOME
	exec @util_linux@/bin/setpriv --inh-caps=-all -- "@out@/bin/shenv" "$@"
elif [ -n "${__ENV_SHENV:-}" ]; then
	execTarget "$@"
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

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hm-isolation"
STATIC_DIR="$CONFIG_DIR/static"
DRV_DIR="$CONFIG_DIR/drv"

[ -n "$OPT_LIST" ] && {
	[ -d "$STATIC_DIR" ] && find -- "$STATIC_DIR/" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
	[ -d "$DRV_DIR" ] && find -- "$DRV_DIR/" -mindepth 1 -maxdepth 1 -type l -printf '%f\n'
	exit
}

[ $# -ge 1 ] || { usage; exit 1; }
ENV="$1"
shift
[ $# -eq 0 ] && set -- "$SHELL"

ENV_DIR="$STATIC_DIR/$ENV"

if [ ! -e "$ENV_DIR" ]; then
	DRV="$DRV_DIR/$ENV"
	[ -L "$DRV" ] && ENV_DIR="$(nix-store --realise -- "$(readlink -f "$DRV")")/$ENV"
fi

if [ ! -f "$ENV_DIR/env" ]; then
	echo "$0: environment '$ENV' not found" >&2
	exit 1
fi

set -a
# shellcheck disable=SC1091
. "$ENV_DIR/env"
set +a

if [ ! "$__ENV_SHENV" = "@out@" ]; then
	echo "$0: environment does not match this version of hm-isolation: $ENV_DIR" >&2
	exit 1
fi

[ -n "${__ENV_GENERATION:-}" ] || OPT_PATH=1

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

if [ -n "${__ENV_VIEW+x}" ]; then
	exec @util_linux@/bin/unshare -Ucm --keep-caps -- "$0" "$@"
else
	execTarget "$@"
fi
