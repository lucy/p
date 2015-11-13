#!/usr/bin/env bash

set -e
set -o pipefail
umask 077

p_dir="${P_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/p}"
p_store="$p_dir/store"
gpg_opts=(--quiet --yes --batch)

if [[ -r "$p_dir/config" ]]; then
	# shellcheck disable=SC1090
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
git_p() { git -C "$p_dir" "$@"; }

arg_done() {
	if (($#)); then
		die 'too many arguments'
	fi
}

arg_z() {
	if [[ -z "$2" ]]; then
		dief 'supply a %s' "$1"
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
	git_p add "$p_store"
	git_p commit -m '' --allow-empty-message
}

p_create() {
	arg_done "$@"
	if [[ -e "$p_store" ]]; then
		dief 'store already exists at %s' "$p_store"
		exit 1
	fi
	git_p init
	init
}

p_insert() {
	local force=0
	while (($#)); do
		case "$1" in
		-f) force=1; shift ;;
		-*) dief 'invalid argument: %s' "$1" ;;
		*)
			if [[ -z "$name" ]]; then
				name="$1"
			else
				die 'too many arguments'
			fi
			shift
			;;
		esac
	done

	arg_z name "$name"

	local store pw
	store="$(load)"
	if ((!force)) && get "$name" &>/dev/null <<< "$store"; then
		die 'entry already exists'
	fi
	if [[ -t 0 ]]; then
		stty -echo
		read -r -p 'entry: ' pw
		stty echo
		echo
	else
		pw="$(cat)"
	fi
	set "$name" "$pw" <<< "$store" | save
}

p_delete() {
	local name="$1"
	arg_z name "$name"
	shift
	arg_done "$@"

	local store
	store="$(load)"
	if ! get "$name" <<< "$store" &>/dev/null; then
		die 'no such entry'
	fi
	jshon -Q -d "$name" <<< "$store" | save
}

p_print() {
	local name="$1"
	arg_z name "$name"
	shift
	arg_done "$@"

	load | get "$name"
}

p_edit() {
	local name="$1"
	arg_z name "$name"
	shift
	arg_done "$@"

	local store new
	store="$(load)"
	get "$name" <<< "$store" > "$temp_dir/e"
	"${EDITOR:-vi}" "$temp_dir/e"
	new="$(<"$temp_dir/e")"
	set "$name" "$new" <<< "$store" | save
}

p_list() {
	arg_done "$@"
	load | jshon -k
}

p_gen() {
	local force=0 name length
	while (($#)); do
		case "$1" in
		--) shift; break ;;
		-f) force=1; shift ;;
		-*) dief 'invalid option: %s' "$1" ;;
		*)
			if [[ -z "$name" ]]; then
				name="$1"
			elif [[ -z "$length" ]]; then
				length="$1"
			else
				die 'too many arguments'
			fi
			shift
			;;
		esac
	done
	arg_z name "$name"
	arg_z length "$length"

	arg=()
	if ((force)); then
		arg+=(-f)
	fi
	pwgen -s "$@" "$length" 1 | p_insert "${arg[@]}" "$name"
}

usage() {
	cat >&2 <<EOF
Usage: p [option ...] command [option ...] [argument ...]

commands:
  c           create db
  d name      delete
  e name      edit
  g name len  generate
  i name      insert
  l           list
  p name      print

toplevel options:
  -h  display usage

g options:
  --  pass rest of arguments to pwgen
  -f  overwrite

i options:
  -f  overwrite
EOF
}

cancel=0
while (($#)); do
	case "$1" in
	c) cmd=p_create; break ;;
	d) cmd=p_delete; break ;;
	e) cmd=p_edit; break ;;
	g) cmd=p_gen; break ;;
	i) cmd=p_insert; break ;;
	l) cmd=p_list; break ;;
	p) cmd=p_print; break ;;
	-c) cancel=1; shift ;;
	-h) usage; exit ;;
	-*) dief 'invalid argument: %s' "$1" ;;
	*) dief 'invalid command: %s' "$1" ;;
	esac
done

cleanup() {
	if [[ -n "$temp_dir" ]]; then
		rm -rf "$temp_dir" || {
			log 'something bad happened!'
			logf 'couldn''t remove temp dir at %s' "$temp_dir"
		}
	fi
}
trap cleanup EXIT

temp_dir="$(mktemp -d)"
if ((cancel)); then
	gpg_opts+=(--pinentry-mode cancel)
fi

shift # shift away command name
"$cmd" "$@"
