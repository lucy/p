##### Usage
```
p [option ...] command [option ...] [argument ...]

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
```

##### Environment
* `P_DIR`: config and store dir (default: `${XDG_CONFIG_DIR:-$HOME/.config}/p`)
* `P_KEY`: gnupg key id
* `EDITOR`: used for `p e`

##### Migrate (don't!)
```bash
( cd "${PASSWORD_STORE:-$HOME/.password-store}/" && find . \( -name .git -o -name .gpg-id \) -prune -o -type f -print ) | sed -e 's/^\.\///' -e 's/\.gpg$//' | while IFS= read -r n; do pass show "$n" | p i "$n"; done
```

##### Files
* `$P_DIR/config`: sourced for environment variables
* `$P_DIR/store`: the store

##### Format
The store is a simple json object with string values encrypted with gpg.
```
~/.config/p > p c
Initialized empty Git repository in ~/.config/p/.git/
[master (root-commit) 10970bd] 
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 store
~/.config/p master > p i www/runescape.com
entry: 
[master c141447] 
 1 file changed, 0 insertions(+), 0 deletions(-)
 rewrite store (100%)
~/.config/p master > p i 'literally anything is fine'
entry: 
[master ddc8312] 
 1 file changed, 0 insertions(+), 0 deletions(-)
 rewrite store (100%)
~/.config/p master > gpg -qd store
{
 "www\/runescape.com": "hunter2",
 "literally anything is fine": "password123"
}
```

##### Dependencies
* bash
* git
* gpg2
* jshon
* mktemp
* pwgen
* xclip
