```
usage: p [option ...] command

commands:
  c                        create db
  d name                   delete
  e name                   edit
  g name len [option ...]  generate
  i name                   insert
  l                        list
  m from to                move
  p name                   print
  x from to                git diff

options:
  -h         display usage
  -g option  add gpg option

notes:
  e, x  WARNING: these write your passwords to "$(mktemp -d)"
  g     options are passed to pwgen
```

# Environment
* `P_DIR`: config and store dir (default: `${XDG_CONFIG_DIR:-$HOME/.config}/p`)
* `P_KEY`: gnupg key id
* `EDITOR`: used for `p e` (edit entry)

# Files
* `$P_DIR/config`: sourced for environment variables
* `$P_DIR/store`: the store

# Format
The store is a simple JSON object encrypted with gpg.

#### Initialise the store:
```
~/.config/p > p c
Initialized empty Git repository in ~/.config/p/.git/
[master (root-commit) 10970bd]
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 store
 ```

#### Insert entries:
```
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
```

#### JSON dump:
```json
~/.config/p master > gpg -qd store
{
 "www\/runescape.com": "hunter2",
 "literally anything is fine": "password123"
}
```

# Migrate (don't!)
```bash
( cd "${PASSWORD_STORE:-$HOME/.password-store}/" && \
  find . \( -name .git -o -name .gpg-id \) -prune -o -type f -print ) | \
sed -e 's/^\.\///' -e 's/\.gpg$//' | \
while IFS= read -r n; do pass show "$n" | p i "$n"; done
```

# Dependencies
* bash
* git
* gpg2
* [jshon](https://github.com/keenerd/jshon)
* mktemp
* pwgen

# `dmenu_p`
Autotypes a password selected with dmenu using xdotool.
```
dmenu_p [dmenu opt ...]
```

# Why does it use bash
POSIX sh lacks some features required to implement this program correctly.
These include trap [...] EXIT to avoid leaving sensitive temporary files and
arrays for correctly building the gpg parameter list.

# Limitations
Unlike `pass`, `p` stores all entries in a single file. This means you have to
decrypt all your passwords to access just one of them, which can reduce
security if you run your decryption operations on e.g. a yubikey. The upside to
this is that your entry names are not leaked.

TODO: optionally encrypt+base64 entries in the store?
