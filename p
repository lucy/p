#!/usr/bin/env bash

set -e
set -o pipefail
umask 077

p_dir="${P_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/p}"
p_store="$p_dir/store"
gpg_opts=(--quiet --yes --batch)
temp_dir=

if [[ -r "$p_dir/config" ]]; then
	# shellcheck disable=SC1090
	. "$p_dir/config"
fi

if [[ -n "$P_KEY" ]]; then
	gpg_opts+=('--recipient' "$P_KEY")
else
	gpg_opts+=('--default-recipient-self')
fi

temp_dir() {
	if [[ -z "$temp_dir" ]]; then
		temp_dir="$(mktemp -d)"
	fi
	printf '%s' "$temp_dir"
}

cleanup() {
	if [[ -n "$temp_dir" ]]; then
		rm -rf "$temp_dir"
		if [[ -e "$temp_dir" ]]; then
			log 'could not remove temporary directory: %s' "$temp_dir"
			log 'please make sure it is deleted to avoid data leaks'
			exit 1
		fi
	fi
}
trap cleanup EXIT

log() { fmt="$1"; shift; printf "%s: $fmt\n" 'p' "$@" 1>&2; }
die() { log "$@"; exit 1; }
git_p() { git -C "$p_dir" "$@"; }
gpg_p() { gpg2 "${gpg_opts[@]}" "$@"; }

j_get() { jshon -Q -e "$1" -u; }
j_set() { jshon -Q -s "$2" -i "$1"; }
j_del() { jshon -Q -d "$1"; }

load() {
	gpg_p --decrypt "$p_store"
}

save() {
	local tmp
	tmp="$(temp_dir)"
	gpg_p --encrypt --output "$tmp/store"
	mv "$tmp/store" "$p_store"
	git_p add "$p_store"
	git_p commit -m '' --allow-empty-message
}

p_create() {
	if [[ -e "$p_store" ]]; then
		die 'store already exists at %s' "$p_store"
		exit 1
	fi
	git_p init
	jshon -Q -n object | save
}

p_insert() {
	local name="$1"; shift 1
	local store pw
	store="$(load)"
	if j_get "$name" >/dev/null <<< "$store"; then
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
	j_set "$name" "$pw" <<< "$store" | save
}

p_delete() {
	local name="$1"; shift 1
	local store
	store="$(load)"
	if ! j_get "$name" <<< "$store" &>/dev/null; then
		die 'no such entry'
	fi
	j_del "$name" <<< "$store" | save
}

p_mv() {
	local from="$1" to="$2"; shift 2
	local store pw
	store="$(load)"
	if j_get "$to" >/dev/null <<< "$store"; then
		die 'to already exists'
	fi
	pw="$(j_get "$from" <<< "$store")"
	j_del "$from" <<< "$store" | j_set "$to" "$pw" | save
}

p_print() {
	local name="$1"; shift 1
	load | j_get "$name"
}

p_edit() {
	local name="$1"; shift 1
	local store new tmp
	tmp="$(temp_dir)"
	store="$(load)"
	j_get "$name" <<< "$store" > "$tmp/e"
	"${EDITOR:-vi}" "$tmp/e"
	new="$(<"$tmp/e")"
	j_set "$name" "$new" <<< "$store" | save
}

p_list() {
	load | jshon -k
}

p_gen() {
	local name="$1" length="$2"; shift 2
	pwgen -s "$@" "$length" 1 | p_insert "$name"
}

usage() {
	cat >&2 <<EOF
usage: p [option ...] command

commands:
  c                        create db
  d name                   delete
  e name                   edit
  g name len [option ...]  generate, options passed to pwgen
  i name                   insert
  l                        list
  m from to                move
  p name                   print

options:
  -h                       display usage
  -g option                add gpg option
EOF
}

while (($#)); do
	case "$1" in
	c) cmd=p_create ;;
	d) cmd=p_delete ;;
	e) cmd=p_edit ;;
	g) cmd=p_gen ;;
	i) cmd=p_insert ;;
	l) cmd=p_list ;;
	m) cmd=p_mv ;;
	p) cmd=p_print ;;
	esac

	if [[ -n "$cmd" ]]; then
		shift 1; break
	fi

	case "$1" in
	-g) gpg_opts+=("$2"); shift 2 ;;
	-h) usage; exit ;;
	-*) die 'invalid argument: %s' "$1" ;;
	*) die 'invalid command: %s' "$1" ;;
	esac
done

if [[ -z "$cmd" ]]; then
	exit 1
fi

"$cmd" "$@"
