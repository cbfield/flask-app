#!/usr/bin/env just --justfile

image := "cbfield/flask-app:latest"

build:
    docker build -t {{image}} .

test: build
    pytest

run: build
    docker run -it -p 5001:5000 -e LOG_LEVEL=DEBUG {{image}}

running PORT="5001":
    test $(lsof -i:{{PORT}} | wc -l) -gt 0

jq *ARGS:
    #!/usr/bin/env -S bash -eo pipefail
    if ! just running; then
        printf "\nApp is not running. To start the app, run:\n❯ just run\n\n"
        exit 1
    fi
    curl --no-progress-meter http://localhost:5001/api/v1/ | jq {{ARGS}}
