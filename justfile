#!/usr/bin/env just --justfile

default:
  @just --list

image := "cbfield/flask-app:latest"
port := "5001"
log_level := "DEBUG"

build:
    docker build -t {{image}} .

test: build
    python -m pytest

run: build
    docker run -it -p {{port}}:5000 -e LOG_LEVEL={{log_level}} {{image}}

running:
    test $(lsof -i:{{port}} | wc -l) -gt 0

jq *ARGS:
    if ! just running; then \
        printf "\nApp is not running. (hint: try the command 'just run' first)\n\n"; \
        exit 1; \
    fi
    curl --no-progress-meter http://localhost:5001/api/v1/ | jq {{ARGS}}
