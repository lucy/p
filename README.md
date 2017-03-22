```
usage: p [option ...] command

commands:
  c          create
  l          list
  p name     print
  i name     insert
  d name     delete
  m from to  rename

options:
  -h  show help
```

# Environment
* `P_DIR`: config and store dir (default: `${XDG_CONFIG_DIR:-$HOME/.config}/p`)
* `P_KEY`: gpg key id

# Files
* `$P_DIR/config`: sourced for environment variables
* `$P_DIR/store`: the store

# Format
The store is a JSON object encrypted with gpg.

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

# Dependencies
* git
* gpg2
* jq
