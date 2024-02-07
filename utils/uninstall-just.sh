#!/usr/bin/env -S bash -euxo pipefail

if command -v just >/dev/null; then
    rm $(which just)
fi
