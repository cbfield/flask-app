#!/usr/bin/env just --justfile

@default:
    just --list
    printf "\nStatus:\n"
    just status

image := "cbfield/flask-app:latest"
port := "5001"
log_level := "DEBUG"

api HOST="localhost" PATH="/" TIMEOUT="5" RETRIES="3" DELAY="1" MAX_TIME="10" RETRY_MAX_TIME="40":
    curl \
        --connect-timeout {{TIMEOUT}} \
        --max-time {{MAX_TIME}} \
        --retry {{RETRIES}} \
        --retry-delay {{DELAY}} \
        --retry-max-time {{RETRY_MAX_TIME}} \
        --retry-connrefused \
        --no-progress-meter \
        http://{{HOST}}:{{port}}/api/v1{{PATH}}

build:
    docker build -t {{image}} .

clean: stop clean-containers clean-images
clean-all: (stop "$(just get-all)") (clean-containers "$(just get-all)") clean-images

clean-containers IDS="$(docker ps -aq)":
    if [[ -n "{{IDS}}" ]]; then \
        docker rm -vf {{IDS}}; \
    fi

clean-images:
    docker image prune --all --force

@get +FLAGS="-q":
    echo $(docker ps {{FLAGS}} --filter ancestor={{image}})

@get-all +FLAGS="-q":
    echo $(docker ps {{FLAGS}})

install-jq VERSION="$(utils/jq-latest.sh)" INSTALL_DIR="~/bin" TARGET="$(uname -m)-$(uname -s | cut -d- -f1)":
    #!/usr/bin/env -S bash -euxo pipefail
    case {{TARGET}} in
        arm64-Darwin)      asset=jq-macos-arm64;;
        x86_64-Darwin)     asset=jq-macos-amd64;;
        x86_64-Linux)      asset=jq-linux-amd64;;
        x86_64-MINGW64_NT) asset=jq-windows-amd64;;
        x86_64-Windows_NT) asset=jq-windows-amd64;;
    esac
    curl -L \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -o {{INSTALL_DIR}}/jq \
        --no-progress-meter \
        https://github.com/jqlang/jq/releases/download/jq-{{VERSION}}/"$asset"
    chmod +x {{INSTALL_DIR}}/jq
    set +x
    if command -v jq >/dev/null; then
        printf "\njq installed: %s\n\n" $(jq --version)
    else
        printf "\njq installed successfully! But it doesn't appear to be on your \$PATH.\n"
        printf "You can add it to your path by running this:\n\n❯ export PATH={{INSTALL_DIR}}:\$PATH\n\n"
    fi

require *FLAGS:
    just require-dev {{FLAGS}}
    just require-test {{FLAGS}}
    just require-prod {{FLAGS}}

require-dev *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-dev.txt requirements-dev.in

require-prod *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements.txt requirements.in

require-test *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-test.txt requirements-test.in

restart: build && run
    nc -z localhost {{port}} >/dev/null 2>&1 && just stop || :

run: build
    docker run -d --restart=always -p {{port}}:5000 -e LOG_LEVEL={{log_level}} {{image}}

status CONTAINERS="$(just get)":
    #!/usr/bin/env -S bash -euo pipefail
    if [[ -z {{CONTAINERS}} ]]; then
        printf "\nNo development containers.\n\n";
    else
        printf "\nDevelopment Containers:\n\n"
        format='{"Name":.Names,"Image":.Image,"Ports":.Ports,"Created":.RunningFor,"Status":.Status}'
        if ! command -v jq >/dev/null; then
            docker ps --format=json | docker run -i --rm ghcr.io/jqlang/jq "$format"
        else
            docker ps --format=json | jq "$format"; echo
        fi
    fi
    printf "$(docker ps -a)\n\n$(docker images)\n\n"

stop CONTAINERS="$(just get)":
    if [[ -n {{CONTAINERS}} ]]; then docker stop {{CONTAINERS}}; fi

test: build
    python -m pytest
