#!/usr/bin/env just --justfile

# TODO
# test
# lint
# deploy

# Variables

image := "cbfield/flask-app:latest"
port := "5001"
log_level := "DEBUG"
gh_token := `cat ~/.secret/gh_token`

# Recipes

# Show help and status info
@default:
    just --list
    printf "\nStatus:\n"
    just status

# Shortcut for testing APIs running on localhost
api PATH="/api/v1/":
    curl \
        --connect-timeout 5 \
        --max-time 10 \
        --retry 3 \
        --retry-delay 1 \
        --retry-max-time 30 \
        --retry-connrefused \
        --no-progress-meter \
        http://localhost:{{port}}{{PATH}}

# Build the app container with Docker
build: start-docker
    docker build -t {{image}} .

# Generate requirements*.txt from requirements*.in using pip-tools
build-reqs *FLAGS:
    just build-reqs-dev {{FLAGS}}
    just build-reqs-test {{FLAGS}}
    just build-reqs-deploy {{FLAGS}}

# Generate requirements.txt from requirements.in using pip-tools
build-reqs-deploy *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements.txt requirements.in

# Generate requirements-dev.txt from requirements-dev.in using pip-tools
build-reqs-dev *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-dev.txt requirements-dev.in

# Generate requirements-test.txt from requirements-test.in using pip-tools
build-reqs-test *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-test.txt requirements-test.in

# Remove development containers and images
clean: stop clean-containers clean-images

# Remove all containers and images
clean-all: stop-all-containers clean-all-containers clean-all-images

# Remove all containers
clean-all-containers:
    #!/usr/bin/env -S bash -euo pipefail
    containers=$(docker ps -aq)
    if [[ -n "$containers" ]]; then
        docker rm -vf "$containers"
    else
        echo "No containers running."
    fi

# Remove all images
clean-all-images:
    docker image prune --all --force

# Remove containers by ID
clean-containers CONTAINERS="$(just get-dev-containers)":
    docker rm -vf "{{CONTAINERS}}"

# Remove images by ID
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

# (JSON util) Return the first item in a JSON list. Return nothing if invalid JSON or type != list.
_get-first-item:
    #!/usr/bin/env -S python3
    import json, sys
    try:
        d = json.load(sys.stdin)
    except json.decoder.JSONDecodeError:
        sys.exit()
    if type(d) is list: 
        print(json.dumps(d[0]))

# (Github API util) Return the id of a given asset in a Github release
_get-gh-release-asset-id ASSET:
    #!/usr/bin/env -S python3
    import json, sys
    try:
        d = json.load(sys.stdin)
    except json.decoder.JSONDecodeError:
        sys.exit()
    print(next((a["id"] for a in d["assets"] if a["name"]=="{{ASSET}}"),""),end="")

# Get a Github release (json)
get-gh-release OWNER REPO TAG:
    #!/usr/bin/env -S bash -euo pipefail
    headers='-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" -H "Authorization: Bearer {{gh_token}}"'
    curl "$headers" -L --no-progress-meter https://api.github.com/repos/{{OWNER}}/{{REPO}}/releases/tags/{{TAG}} | just _handle-gh-api-errors

# Download a Github release binary asset
get-gh-release-binary OWNER REPO TAG ASSET DEST:
    #!/usr/bin/env -S bash -euo pipefail
    printf "\nRetrieving Release Binary...\n\nOWNER:\t\t%s\nREPO:\t\t%s\nRELEASE TAG:\t%s\nTARGET:\t\t%s\nDESTINATION:\t%s\n\n" {{OWNER}} {{REPO}} {{TAG}} {{ASSET}} {{DEST}}
    asset_id=$(just get-gh-release {{OWNER}} {{REPO}} {{TAG}} | just _get-gh-release-asset-id {{ASSET}})
    if [[ -z "$asset_id" ]]; then
        printf "Asset %s not found.\n\n" "{{ASSET}}" >&2; exit 1
    fi
    curl -L --no-progress-meter -o "{{DEST}}" \
      -H "Accept: application/octet-stream" -H "X-GitHub-Api-Version: 2022-11-28" -H "Authorization: Bearer {{gh_token}}" \
      https://api.github.com/repos/{{OWNER}}/{{REPO}}/releases/assets/$asset_id
    chmod +x "{{DEST}}"

# Get the latest release for a given Github repo
get-latest-gh-release OWNER REPO:
    #!/usr/bin/env -S bash -euo pipefail
    headers='-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" -H "Authorization: Bearer {{gh_token}}"'
    releases=$(curl "$headers" -L --no-progress-meter https://api.github.com/repos/{{OWNER}}/{{REPO}}/releases)
    echo $releases | just _handle-gh-api-errors | just _get-first-item

# (Github API util) Return unchanged JSON input if valid JSON and doesn't contain not-found or rate-limit-exceeded errors.
_handle-gh-api-errors:
    #!/usr/bin/env -S python3
    import json, sys
    try:
        d = json.load(sys.stdin)
    except json.decoder.JSONDecodeError:
        sys.exit()
    if 'message' in d and (d['message']=='Not Found' or d['message'].startswith('API rate limit exceeded')):
        sys.exit()
    print(json.dumps(d))

# Install the latest version of the AWS CLI
install-aws:
    #!/usr/bin/env -S bash -euo pipefail
    if [[ "{{os()}}" == "linux" ]]; then
        curl --no-progress-meter "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        trap 'rm -rf -- "awscliv2.zip"' EXIT
        unzip awscliv2.zip
        sudo ./aws/install
        trap 'rm -rf -- "./aws"' EXIT
    elif [[ "{{os()}}" == "macos" ]]; then
        curl --no-progress-meter "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
        trap 'rm -rf -- "AWSCLIV2.pkg"' EXIT
        sudo installer -pkg AWSCLIV2.pkg -target /
    elif [[ "{{os()}}" == "windows" ]]; then
        msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
    else
        echo "Unable to determine proper install method. Cancelling" >&2; exit 1
    fi

# Install jq via pre-built binary from the Github API
install-jq VERSION="latest" INSTALL_DIR="$HOME/bin" TARGET="":
    #!/usr/bin/env -S bash -euo pipefail
    version="{{VERSION}}"
    if [[ "$version" == "latest" ]]; then
        echo "Looking up latest version..."
        release=$(just get-latest-gh-release jqlang jq)
        version=$(echo "$release" | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"].split("-")[-1])')
        printf "Found %s\n" "$version."
    else
        printf "Validating version %s...\n" "$version"
        release=$(just get-gh-release jqlang jq "jq-$version")
        if [[ -n "$release" ]]; then
            echo "Valid!"
        else
            printf "Version %s not found.\n\n" "$version" >&2; exit 1
        fi
    fi
    case $(uname -m)-$(uname -s | cut -d- -f1) in
        arm64-Darwin)       asset=jq-macos-arm64;;
        x86_64-Darwin)      asset=jq-macos-amd64;;
        x86_64-Linux)       asset=jq-linux-amd64;;
        x86_64-MINGW64_NT)  asset=jq-windows-amd64;;
        x86_64-Windows_NT)  asset=jq-windows-amd64;;
    esac
    if [[ -n "{{TARGET}}" ]]; then
        asset="{{TARGET}}"
    fi
    just get-gh-release-binary jqlang jq "jq-$version" "$asset" "{{INSTALL_DIR}}/jq"
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
    if [[ -n "$(just get-dev-containers)" ]]; then just stop; fi
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

# Start the Docker daemon
start-docker:
    #!/usr/bin/env -S bash -euo pipefail
    if ( ! docker stats --no-stream 2>/dev/null ); then
        echo "Starting the Docker daemon..."
        if [[ {{os()}} == "macos" ]]; then
            open /Applications/Docker.app
        else if command -v systemctl >/dev/null; then
            sudo systemctl start docker
        else
            echo "Unable to start the Docker daemon." >&2; exit 1
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

# Stop containers by ID
stop CONTAINERS="$(just get-dev-containers)":
    if [[ -n "{{CONTAINERS}}" ]]; then docker stop {{CONTAINERS}}; fi

alias stop-all := stop-all-containers
# Stop all containers
stop-all-containers:
    #!/usr/bin/env -S bash -euo pipefail
    containers=$(docker ps -aq)
    if [[ -n "$containers" ]]; then
        docker stop "$containers"
    else
        echo "No containers running."
    fi
