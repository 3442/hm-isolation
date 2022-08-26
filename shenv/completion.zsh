#compdef shenv

local context state state_descr line env_path
local -a envs
typeset -A opt_args

_arguments \
	-s -S -A '-*' : \
	'1:hm-isolation environment:->list' \
	'*::environment command:->cmd' \
	--

case $state in
	list)
		envs=("${(@f)$(shenv -l)}")
		_values 'hm-isolation environment' "${envs[@]}"
		;;

	cmd)
		env_path="$(shenv -P -- "${line[1]}" 2>/dev/null)"
		PATH="${env_path#:}:$PATH" _command --
		;;
esac
