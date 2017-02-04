#!/bin/sh

set -e
umask 077

usage() {
	cat >&2 <<-EOF
	usage: p [option ...] command

	commands:
	  c          create db
	  l          list
	  p name     print
	  i name     insert
	  d name     delete
	  m from to  rename

	options:
	  -h  show help
	EOF
}

p_dir="${P_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/p}"
p_store="$p_dir/store"
gpg_opts='--quiet --yes --batch'

if [ -r "$p_dir/config" ]; then
	# shellcheck disable=SC1090
	. "$p_dir/config"
fi

gpg() {
	if [ -n "$P_KEY" ]; then
		# shellcheck disable=SC2086
		gpg2 $gpg_opts --recipient "$P_KEY" "$@"
	else
		# shellcheck disable=SC2086
		gpg2 $gpg_opts --default-recipient-self "$P_KEY" "$@"
	fi
}

die() { fmt="$1"; shift; printf "%s: $fmt\n" 'p' "$@" 1>&2; exit 1; }

# shellcheck disable=SC2016
j_get() { jq '.[$key]' --arg key "$1" -r; }
# shellcheck disable=SC2016
j_set() { jq '.[$key] = $val' --arg key "$1" --arg val "$2"; }
# shellcheck disable=SC2016
j_del() { jq 'del(.[$key])' --arg key "$1"; }

load() { gpg --decrypt "$p_store"; }

save() {
	rm "$p_store" # this is in git anyway
	gpg --encrypt --output "$p_store"
	git -C "$p_dir" add "$p_store"
	git -C "$p_dir" commit -m 'update'
}

p_create() {
	if [ -e "$p_store" ]; then
		die 'store already exists at %s' "$p_store"
	fi
	git -C "$p_dir" init
	printf '{}\n' | save
}

p_insert() {
	name="$1"
	if ! shift; then die 'missing name'; fi
	store="$(load)"
	if printf '%s' "$store" | j_get "$name" >/dev/null; then
		die 'entry already exists'
	fi
	if [ -t 0 ]; then
		stty -echo
		read -r 'entry: ' pw
		stty echo
		printf '\n'
	else
		pw="$(cat)"
	fi
	printf '%s' "$store" | j_set "$name" "$pw" | save
}

p_delete() {
	name="$1"
	if ! shift; then die 'missing name'; fi
	store="$(load)"
	if ! printf '%s' "$store" | j_get "$name" >/dev/null 1>&2; then
		die 'no such entry'
	fi
	printf '%s' "$store" | j_del "$name" | save
}

p_move() {
	from="$1" to="$2"
	if ! shift 2; then die 'missing from or to'; fi
	store="$(load)"
	if printf '%s' "$store" | j_get "$to" >/dev/null; then
		die 'to already exists'
	fi
	pw="$(printf '%s' "$store" | j_get "$from")"
	printf '%s' "$store" | j_del "$from" | j_set "$to" "$pw" | save
}

p_print() {
	name="$1"
	if ! shift; then die 'missing name'; fi
	load | j_get "$name"
}

p_list() { load | jq 'keys | .[]' -r; }

while :; do
	case "$1" in
	'') break ;;
	c) shift; p_create "$@"; exit;;
	d) shift; p_delete "$@"; exit;;
	i) shift; p_insert "$@"; exit;;
	l) shift; p_list   "$@"; exit;;
	m) shift; p_move   "$@"; exit;;
	p) shift; p_print  "$@"; exit;;
	-h) usage; exit ;;
	-g) gpg_opts="$gpg_opts $2"; shift 2 ;;
	-*) die 'invalid argument: %s' "$1" ;;
	*) die 'invalid command: %s' "$1" ;;
	esac
done

die 'missing command'
