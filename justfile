#!/usr/bin/env just --justfile

# Variables

image := "cbfield/flask-app:latest"
port := "5001"
log_level := "DEBUG"

# Recipes

@default:
    just --list
    printf "\nStatus:\n"
    just status

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

build-requirements *FLAGS:
    just require-dev {{FLAGS}}
    just require-test {{FLAGS}}
    just require-prod {{FLAGS}}

build-requirements-dev *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-dev.txt requirements-dev.in

build-requirements-prod *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements.txt requirements.in

build-requirements-test *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-test.txt requirements-test.in

clean: stop clean-containers clean-images
clean-all: (stop "$(just get-all-containers)") (clean-containers "$(just get-all-containers)") clean-images

clean-containers CONTAINERS="$(docker ps -aq)":
    #!/usr/bin/env -S bash -euxo pipefail
    if [[ -n "{{CONTAINERS}}" ]]; then
        docker rm -vf {{CONTAINERS}}
    fi

clean-images:
    docker image prune --all --force

@get-all-containers +FLAGS="-q":
    echo $(docker ps {{FLAGS}})

@get-dev-containers +FLAGS="-q":
    echo $(docker ps {{FLAGS}} --filter ancestor={{image}})

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

restart: build && run
    nc -z localhost {{port}} >/dev/null 2>&1 && just stop || :

run: build
    docker run -d --restart=always -p {{port}}:5000 -e LOG_LEVEL={{log_level}} {{image}}

status CONTAINERS="$(just get-dev-containers)":
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
    printf "Containers:\n\n$(docker ps -a)\n\nImages:\n\n$(docker images)\n\n"

stop CONTAINERS="$(just get-dev-containers)":
    if [[ -n {{CONTAINERS}} ]]; then docker stop {{CONTAINERS}}; fi

test: build
    python -m pytest
