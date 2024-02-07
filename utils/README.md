# Utils

The `justfile` at the root of this repository should be able to do just about anything you need. However, you need `just` to use that.

Run this from the root of the repo to install `just`:
- `./utils/install-just.sh`

Run this from the root of the repo to uninstall `just`:
- `./utils/uninstall-just.sh`

### Examples

Help:
```bash
❯ ./utils/install-just.sh --help
Install a binary release of a just hosted on GitHub

USAGE:
    install [options]

FLAGS:
    -h, --help      Display this message
    -f, --force     Force overwriting an existing binary

OPTIONS:
    --tag TAG       Tag (version) of the crate to install, defaults to latest release
    --to LOCATION   Where to install the binary [default: ~/bin]
    --target TARGET
```

Install:
```bash
❯ ./utils/install-just.sh
+ curl --proto =https --tlsv1.2 -sSf https://just.systems/install.sh
+ bash -s -- -f
install: Repository:  https://github.com/casey/just
install: Crate:       just
install: Tag:         1.23.0
install: Target:      aarch64-apple-darwin
install: Destination: /Users/chris/bin
install: Archive:     https://github.com/casey/just/releases/download/1.23.0/just-1.23.0-aarch64-apple-darwin.tar.gz

❯ just --version
just 1.23.0
```

Alternate Install Path (default `~/bin`):
```bash
❯ ./utils/install-just.sh --to ~/Documents -f
+ curl --proto =https --tlsv1.2 -sSf https://just.systems/install.sh
+ bash -s -- --to /Users/chris/Documents -f
install: Repository:  https://github.com/casey/just
install: Crate:       just
install: Tag:         1.23.0
install: Target:      aarch64-apple-darwin
install: Destination: /Users/chris/Documents
install: Archive:     https://github.com/casey/just/releases/download/1.23.0/just-1.23.0-aarch64-apple-darwin.tar.gz
```

Upgrade/ Downgrade:
```bash
❯ ./utils/install-just.sh -f --tag 1.22.1
+ curl --proto =https --tlsv1.2 -sSf https://just.systems/install.sh
+ bash -s -- -f --tag 1.22.1
install: Repository:  https://github.com/casey/just
install: Crate:       just
install: Tag:         1.22.1
install: Target:      aarch64-apple-darwin
install: Destination: /Users/chris/bin
install: Archive:     https://github.com/casey/just/releases/download/1.22.1/just-1.22.1-aarch64-apple-darwin.tar.gz

❯ just --version
just 1.22.1

❯ ./utils/install-just.sh -f
+ curl --proto =https --tlsv1.2 -sSf https://just.systems/install.sh
+ bash -s -- -f
install: Repository:  https://github.com/casey/just
install: Crate:       just
install: Tag:         1.23.0
install: Target:      aarch64-apple-darwin
install: Destination: /Users/chris/bin
install: Archive:     https://github.com/casey/just/releases/download/1.23.0/just-1.23.0-aarch64-apple-darwin.tar.gz

❯ just --version
just 1.23.0
```
