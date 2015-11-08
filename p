#!/usr/bin/env bash

set -e
set -o pipefail
umask 077

p_dir="${P_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/p}"
p_store="$p_dir/store"
gpg_opts=(--quiet --yes --batch)

trap 'if [[ -n "$temp_dir" ]]; then rm -rf "$temp_dir"; fi' EXIT
temp_dir="$(mktemp -d)"

if [[ -r "$p_dir/config" ]]; then
	. "$p_dir/config"
fi

if [[ -n "$P_KEY" ]]; then
	gpg_opts+=('--recipient' "$P_KEY")
else
	gpg_opts+=('--default-recipient-self')
fi


log() { printf '%s: %s\n' 'p' "$1" 1>&2; }
logf() { fmt="$1"; shift; printf "%s: $fmt\n" 'p' "$@" 1>&2; }
die() { log "$@"; exit 1; }
dief() { logf "$@"; exit 1; }
print() { printf '%s' "$@"; }

readpw() {
	if [[ -t 0 ]]; then
		stty -echo
		read -r -p 'entry: ' "$1"
		stty echo
		echo
	else
		read -r -p ':' "$1"
	fi
}


init() { jshon -Q -n object | save; }
get() { jshon -Q -e "$1" -u; }
set() { jshon -Q -s "$2" -i "$1"; }

load() {
	gpg2 "${gpg_opts[@]}" --decrypt "$p_store"
}

save() {
	gpg2 "${gpg_opts[@]}" --encrypt --output "$temp_dir/store"
	mv "$temp_dir/store" "$p_store"
	git -C "$p_dir" add "$p_store"
	git -C "$p_dir" commit -m '' --allow-empty-message
}


p_create() {
	if (($#)); then
		die 'too many arguments'
	fi
	if [[ -e "$p_store" ]]; then
		dief 'store already exists at %s' "$p_store"
		exit 1
	fi
	git -C "$p_dir" init
	init
}

p_insert() {
	local force=0 name
	while (($#)); do
		case "$1" in
		-f) force=1; shift ;;
		-*) dief 'invalid argument: %s' "$1" ;;
		*)
			if [[ -n "$name" ]]; then
				die 'too many arguments'
			fi
			name="$1"
			shift
			;;
		esac
	done

	if [[ -z "$name" ]]; then
		die 'supply a name'
	fi

	local store pw
	store="$(load)"
	if ((!force)) && get "$name" <<< "$store" &>/dev/null; then
		dief 'entry %s already exists' "$name"
	fi
	readpw pw
	set "$name" "$pw" <<< "$store" | save
}

p_print() {
	local name="$1"
	if [[ -z "$name" ]]; then
		die 'supply a name'
	fi
	shift
	if (($#)); then
		die 'too many arguments'
	fi

	load | get "$name"
}

p_clip() {
	local pw
	pw="$(p_print "$@")"
	local argv0="p sleeping on $DISPLAY"
	pkill -f "^$argv0$" || true
	local before
	before="$(xclip -o -selection clipboard | base64)"
	print "$pw" | xclip -selection clipboard
	(
		( exec -a "$argv0" sleep 30 )
		local now
		now="$(xclip -o -selection clipboard)"
		if [[ "$now" == "$(print "$pw" | base64)" ]]; then
			print "$before" | base64 -d | xsel -b
		fi
	) 2>/dev/null & disown
}

p_edit() {
	local name="$1"
	if [[ -z "$name" ]]; then
		die 'supply a name'
	fi
	shift
	if (($#)); then
		die 'too many arguments'
	fi

	local store new
	store="$(load)"
	get "$name" <<< "$store" > "$temp_dir/e"
	"${EDITOR:-vi}" "$temp_dir/e"
	new="$(<"$temp_dir/e")"
	set "$name" "$new" <<< "$store" | save
}

p_list() {
	if (($#)); then
		die 'too many arguments'
	fi
	load | jshon -Q -k
}

p_gen() {
	local force=0 name length
	while (($#)); do
		case "$1" in
		--) shift; break ;;
		-f) force=1; shift ;;
		-*) dief 'invalid option: %s' "$1" ;;
		*)
			if [[ -n "$name" ]]; then
				if [[ -n "$length" ]]; then
					die 'too many arguments'
				fi
				length="$1"
			else
				name="$1"
			fi
			shift
			;;
		esac
	done
	if [[ -z "$name" ]]; then
		die 'supply a name'
	fi
	if [[ -z "$length" ]]; then
		die 'supply a length'
	fi

	arg=()
	if ((force)); then
		arg+=(-f)
	fi
	pwgen -s "$@" "$length" 1 | p_insert "${arg[@]}" "$name"
}


usage() {
	cat >&2 <<-EOF
	Usage: p [option ...] command [option ...] [argument ...]

	commands:
	  c           create db
	  e name      edit
	  g name len  generate
	  i name      insert
	  l           list
	  p name      print
	  x name      add to clipboard

	toplevel options:
	  -h  display usage
	
	g options:
	  --  pass rest of arguments to pwgen
	  -f  overwrite

	i options:
	  -f  overwrite
	EOF
}

while (($#)); do
	case "$1" in
	c) shift; p_create "$@"; break ;;
	e) shift; p_edit "$@"; break ;;
	i) shift; p_insert "$@"; break ;;
	l) shift; p_list "$@"; break ;;
	p) shift; p_print "$@"; break ;;
	x) shift; p_clip "$@"; break ;;
	-h) usage; break ;;
	-*) dief 'invalid argument: %s' "$1" ;;
	*) dief 'invalid command: %s' "$1" ;;
	esac
done
