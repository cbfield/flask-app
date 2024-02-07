#!/usr/bin/env -S bash -euxo pipefail

curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- "$@"
