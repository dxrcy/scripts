# Scripts

Some POSIX-compliant scripts.

# Setup

Clone repository:

```sh
git clone https://github.com/dxrcy/scripts ~/scripts
```

Add line to shell rc:

```sh
PATH="$HOME/scripts/cmd:$PATH"
```

# Usage

Command scripts are in `/cmd`, which can be added to `$PATH`.

Other files are put in separate folders.

Help comment is defined in a script with `export INFO=`, view with `whatscript [CMD]`

Non-standard commands are checked to be installed with `requires`, returning code 199 if not found.

