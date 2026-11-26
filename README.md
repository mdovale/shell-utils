# shell-utils

Small, self-contained shell functions for everyday work in bash and zsh.
They run under macOS `/bin/bash` 3.2 and zsh 5.

`mkcd`, `play`, `path_prepend`, and `mkvenv` change the current shell, so
this has to be sourced. Executing `init.sh` does nothing useful.

## Install

Add this to `~/.zshrc` or `~/.bashrc`:

```sh
source /path/to/shell-utils/init.sh

# Optional. play defaults to ~/playground and opens cursor when it is installed.
export PLAY_DIR="$HOME/Work-local/__playground"
export PLAY_EDITOR="cursor"
```

An alias with the same name as a command, such as `gitsize`, is removed when
you source this file. The function replaces it. Other aliases are left alone.

`path_prepend` replaces the "add this directory to PATH if it is missing" check:

```sh
path_prepend "/Applications/Cursor.app/Contents/Resources/app/bin"
```

Run `name --help` for the full usage of any command.

## Commands

### mkvenv

Create a virtual environment and activate it.

```sh
mkvenv
mkvenv python3.12
mkvenv --python python3.12 --dir .venv --force
mkvenv python3.12 .venv force
```

`--force` deletes the directory only when it contains `pyvenv.cfg`. It will
not remove a symlink, your home directory, or an ordinary folder.

### play

Create `YYYYMMDD_name` under `PLAY_DIR`, cd into it, drop a Jupyter notebook
there, and open the folder. The next one on the same day is `YYYYMMDD_name-2`.

```sh
play
play experiment
play --no-open --no-notebook scratch
```

### docku

Run a command in a temporary container with the current directory mounted at
`/work`. The default image is `ubuntu:22.04`. The process runs as root unless
you pass `--user`.

```sh
docku
docku --image python:3.12 python
docku --user -- bash -lc 'id'
```

### count_lines

Count lines by extension. `wc -l` format. Skips `.git`, `node_modules`,
`.venv`, `venv`, `__pycache__`, `dist`, `build`, and `.next` unless `--all`
is set.

```sh
count_lines src py,js
count_lines --all . "py, .lua" counts.txt
```

### mkcd

Create a directory and cd into it. Relative paths ignore `CDPATH`.

```sh
mkcd scratch/notes
```

### extract

Unpack an archive in the current directory and keep the archive. Supports
tar, zip, gzip, bzip2, and xz, in either case.

```sh
extract release.tar.gz
mkcd build && extract ../sources.ZIP
```

### path_prepend

Prepend existing directories to `PATH`. The first argument ends up first.
Missing directories are ignored. Directories already on `PATH` stay where
they are.

```sh
path_prepend "$HOME/.local/bin" /opt/homebrew/bin
```

### gitsize

Show `git count-objects -vH` for this repo, or for a directory you pass.

```sh
gitsize
gitsize ~/src/project
```

### gpumem

Show or change the macOS GPU wired-memory limit (`iogpu.wired_limit_mb`).
Apple Silicon and macOS 14 or later. The value is a ceiling, not an
allocation, and it does not survive a reboot. Setting it runs `sysctl`
through `sudo`. Reading does not.

`max` leaves `GPUMEM_RESERVE_GB` GiB for macOS (default 10). An explicit
size that would leave less than that is refused. `reset` restores the
macOS default, about 75% of RAM.

```sh
gpumem
gpumem 86
gpumem max
GPUMEM_RESERVE_GB=12 gpumem max
gpumem reset
```

## Tests

```sh
make test
```
