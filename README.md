##### Environment
* `P_DIR`: config and store dir (default: `${XDG_CONFIG_DIR:-$HOME/.config}/p`)
* `P_KEY`: gnupg key id
* `EDITOR`: used for `p e`
##### Files
* `$P_DIR/config`: sourced for environment variables
* `$P_DIR/store`: simple encrypted json store
##### Usage
```
p command [opt ...] [arg ...]

commands:
  c           create db
  p name      print
  x name      add to clipboard
  i name      insert
  e name      edit
  l           list
  g name len  generate

i:
  -f  overwrite

g:
  -f  overwrite
  --  pass rest of arguments to pwgen
```
