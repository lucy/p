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
gpg_p() { gpg2 "${gpg_opts[@]}" "$@"; }

arg_done() {
	if (($#)); then
		die 'too many arguments'
	fi
}

arg_z() {
	if [[ -z "$2" ]]; then
		dief 'missing %s' "$1"
	fi
}

init() { jshon -Q -n object | save; }
j_get() { jshon -Q -e "$1" -u; }
j_set() { jshon -Q -s "$2" -i "$1"; }
j_del() { jshon -Q -d "$1"; }

load() { gpg_p --decrypt "$p_store"; }

save() {
	gpg_p --encrypt --output "$temp_dir/store"
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
	local name="$1"
	shift
	arg_z name "$name"
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
	local name="$1"
	arg_z name "$name"
	shift
	arg_done "$@"
	local store
	store="$(load)"
	if ! j_get "$name" <<< "$store" &>/dev/null; then
		die 'no such entry'
	fi
	j_del "$name" <<< "$store" | save
}

p_mv() {
	local from="$1" to="$2"
	arg_z from "$from"
	arg_z to "$to"
	shift 2
	arg_done "$@"
	local store pw
	store="$(load)"
	if j_get "$to" >/dev/null <<< "$store"; then
		die 'to already exists'
	fi
	pw="$(j_get "$from" <<< "$store")"
	j_del "$from" <<< "$store" | j_set "$to" "$pw" | save
}

p_diff() {
	local from="$1" to="$2"
	arg_z 'from commit' "$from"
	arg_z 'to commit' "$to"
	shift 2
	arg_done "$@"
	git_p cat-file blob "$from:store" | gpg_p --decrypt > "$temp_dir/from"
	git_p cat-file blob "$to:store" | gpg_p --decrypt > "$temp_dir/to"
	git --no-pager diff --color=auto --no-ext-diff --no-index \
		"$temp_dir/from" "$temp_dir/to"
}

p_print() {
	local name="$1"
	arg_z name "$name"
	shift
	arg_done "$@"
	load | j_get "$name"
}

p_edit() {
	local name="$1"
	arg_z name "$name"
	shift
	arg_done "$@"
	local store new
	store="$(load)"
	j_get "$name" <<< "$store" > "$temp_dir/e"
	"${EDITOR:-vi}" "$temp_dir/e"
	new="$(<"$temp_dir/e")"
	j_set "$name" "$new" <<< "$store" | save
}

p_list() {
	arg_done "$@"
	load | jshon -k
}

p_gen() {
	local name length
	while (($#)); do
		case "$1" in
		--) shift; break ;;
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
	pwgen -s "$@" "$length" 1 | p_insert "$name"
}

usage() {
	cat >&2 <<EOF
usage: p [option ...] command [option ...] [argument ...]

commands:
  c           create db
  d name      delete
  e name      edit
  g name len  generate
  i name      insert
  l           list
  m from to   move
  p name      print
  x ref ref   diff commits (for debugging)

toplevel options:
  -h  display usage

g options:
  --  pass rest of arguments to pwgen

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
	m) cmd=p_mv; break ;;
	p) cmd=p_print; break ;;
	x) cmd=p_diff; break ;;
	-c) cancel=1; shift ;;
	-h) usage; exit ;;
	-*) dief 'invalid argument: %s' "$1" ;;
	*) dief 'invalid command: %s' "$1" ;;
	esac
done

if [[ -z "$cmd" ]]; then
	usage
	exit 1
fi

if ((cancel)); then
	gpg_opts+=(--pinentry-mode cancel)
fi

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

shift # shift away command name
"$cmd" "$@"
