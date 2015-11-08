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

##### Files
* `$P_DIR/config`: sourced for environment variables
* `$P_DIR/store`: simple encrypted json store

##### Migrate (don't!)
```bash
( cd "${PASSWORD_STORE:-$HOME/.password-store}/" && find . \( -name .git -o -name .gpg-id \) -prune -o -type f -print ) | sed -e 's/^\.\///' -e 's/\.gpg$//' | while IFS= read -r n; do pass show "$n" | p i "$n"; done
```

##### Dependencies
* bash
* git
* gpg2
* jshon
* mktemp
* pwgen
