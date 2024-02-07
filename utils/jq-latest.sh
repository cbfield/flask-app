#!/usr/bin/env -S bash -euo pipefail

releases=$(curl -L \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --no-progress-meter \
        https://api.github.com/repos/jqlang/jq/releases)

if command -v python3 >/dev/null; then
        echo "$releases" | python3 -c 'import sys, json; print(json.load(sys.stdin)[0]["tag_name"].split("-")[-1])'
else
        echo "$releases" | python -c 'import sys, json; print(json.load(sys.stdin)[0]["tag_name"].split("-")[-1])'
fi
