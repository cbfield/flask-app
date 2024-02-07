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

api HOST="localhost" PATH="/api/v1/":
    curl \
        --connect-timeout 5 \
        --max-time 10 \
        --retry 3 \
        --retry-delay 1 \
        --retry-max-time 30 \
        --retry-connrefused \
        --no-progress-meter \
        http://{{HOST}}:{{port}}{{PATH}}

build: start-docker
    docker build -t {{image}} .

build-requirements *FLAGS:
    just build-requirements-dev {{FLAGS}}
    just build-requirements-test {{FLAGS}}
    just build-requirements-prod {{FLAGS}}

build-requirements-dev *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-dev.txt requirements-dev.in

build-requirements-prod *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements.txt requirements.in

build-requirements-test *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-test.txt requirements-test.in

clean: stop clean-containers clean-images
clean-all: (stop "$(just get-all-containers)") clean-all-containers clean-all-images

clean-all-containers:
    docker rm -vf $(docker ps -aq)

clean-all-images:
    docker image prune --all --force

clean-containers CONTAINERS="$(just get-dev-containers)":
    docker rm -vf "{{CONTAINERS}}"

clean-images IMAGES="$(just get-dev-images)":
    docker rmi $(docker images -f "dangling=true" -q)
    docker rmi "{{IMAGES}}"

# Pretty-print development container information
dev-containers:
    #!/usr/bin/env -S bash -euo pipefail
    format='{"Name":.Names,"Image":.Image,"Ports":.Ports,"Created":.RunningFor,"Status":.Status}'
    if ! command -v jq >/dev/null; then jq="docker run -i --rm ghcr.io/jqlang/jq"; else jq=jq; fi
    docker ps --filter ancestor={{image}} --format=json 2>/dev/null | eval '$jq "$format"'

# Pretty-print Docker status information
docker-status:
    #!/usr/bin/env -S bash -euo pipefail
    containers=$(docker ps -a)
    images=$(docker images)
    printf "\nContainers:\n\n%s\n\nImages:\n\n%s\n\n" "$containers" "$images"

# List development container IDs
@get-dev-containers:
    echo $(docker ps -q --filter ancestor={{image}})

# List development image IDs
@get-dev-images:
    echo $(docker images -q)

# Install jq via pre-built binary from the Github API (latest version by default)
install-jq VERSION="" INSTALL_DIR="~/bin" TARGET="":
    #!/usr/bin/env -S bash -euo pipefail
    version="{{VERSION}}"
    if [[ -z "$version" ]]; then
        echo "Looking up latest version..."
        headers='-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28"'
        releases=$(curl -L --no-progress-meter "$headers" https://api.github.com/repos/jqlang/jq/releases)
        version=$(echo "$releases" | python3 -c 'import sys, json; print(json.load(sys.stdin)[0]["tag_name"].split("-")[-1])')
        printf "Found %s\n" "$version"
    fi
    platform=$(uname -m)-$(uname -s | cut -d- -f1)
    case "$platform" in
        arm64-Darwin)       asset=jq-macos-arm64;;
        x86_64-Darwin)      asset=jq-macos-amd64;;
        x86_64-Linux)       asset=jq-linux-amd64;;
        x86_64-MINGW64_NT)  asset=jq-windows-amd64;;
        x86_64-Windows_NT)  asset=jq-windows-amd64;;
    esac
    if [[ -n "{{TARGET}}" ]]; then
        asset={{TARGET}}
    fi
    curl -L \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -o {{INSTALL_DIR}}/jq \
        --no-progress-meter \
        https://github.com/jqlang/jq/releases/download/jq-"$version"/"$asset"
    chmod +x {{INSTALL_DIR}}/jq
    set +x
    if command -v jq >/dev/null; then
        if jq --version >/dev/null; then
            printf "\njq installed: %s\n\n" $(jq --version)
        else
            printf "\nInstallation failed!\n\n"
        fi
    else
        printf "\njq installed successfully! But it doesn't appear to be on your \$PATH.\n"
        printf "You can add it to your path by running this:\n\n❯ export PATH={{INSTALL_DIR}}:\$PATH\n\n"
    fi

# Build and run the app, restarting it if already running
restart: build
    nc -z localhost {{port}} >/dev/null 2>&1 && just stop || :
    docker run -d --restart=always -p {{port}}:5000 -e LOG_LEVEL={{log_level}} {{image}}

# Build and run the app
run:
    #!/usr/bin/env -S bash -euo pipefail
    if [[ -n $(just get-dev-containers) ]]; then
        printf "There are already dev containers running:\n\n$()\n\n(hint:\n\n❯ just restart)\n\n"
        exit
    fi
    just build
    docker run -d --restart=always -p {{port}}:5000 -e LOG_LEVEL={{log_level}} {{image}}

# Start the Docker daemon. TODO implement for linux/ windows
start-docker:
    #!/usr/bin/env -S bash -euo pipefail
    if ( ! docker stats --no-stream 2>/dev/null ); then
        echo "Starting the Docker daemon..."
        if [[ {{os()}} == "macos" ]]; then
            open /Applications/Docker.app
        else if command -v systemctl >/dev/null; then
            sudo systemctl start docker
        else
            echo "Unable to start the Docker daemon." >&2
            exit 1
        fi
        fi
        while ( ! docker stats --no-stream 2>/dev/null ); do
            sleep 1
        done
    fi

# Print information about the current development environment
status:
    #!/usr/bin/env -S bash -euo pipefail
    containers=$(just get-dev-containers 2>/dev/null)
    if [[ -z $containers ]]; then
        printf "\nNo development containers.\n\n";
    else
        printf "\nDevelopment Containers:\n\n"
        just dev-containers; echo
    fi
    printf "Docker Status:\n\n"
    if ( docker stats --no-stream 2>/dev/null ); then
        just docker-status
    else
        printf "Daemon stopped.\n\n"
    fi

# Stop the given containers
stop CONTAINERS="$(just get-dev-containers)":
    if [[ -n {{CONTAINERS}} ]]; then docker stop {{CONTAINERS}}; fi

# TODO this
test: build
    python -m pytest
