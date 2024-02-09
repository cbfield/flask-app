#!/usr/bin/env just --justfile

# TODO
# publish-ghcr
# publish-gar

# -- Variables --
name := "flask-app"
dockerhub := "cbfield"
log_level := "DEBUG"
localhost_port := "5001"
venv := justfile_directory() + "/.venv"
gh_token := `cat ~/.secret/gh_token`
# -- Variables --

# -- AWS Variables --
aws_codeartifact_domain := ""
aws_codeartifact_domain_owner := ""
aws_codeartifact_repository := ""

aws_default_region := "us-west-2"
aws_ecr_account_id := ""
aws_ecr_repository := "flask-app"
# -- AWS Variables --

# ------------ Recipes ------------

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
        http://localhost:{{localhost_port}}{{PATH}}

# (AWS API) Start a session with AWS CodeArtifact
aws-codeartifact-login: _requires-aws
    #!/usr/bin/env -S bash -euxo pipefail
    if [[ -z "{{aws_codeartifact_domain}}" ]] && [[ -z "{{aws_codeartifact_repository}}" ]]; then
        exit
    fi
    repo_flags="--domain {{aws_codeartifact_domain}} --domain-owner {{aws_codeartifact_domain_owner}} --repository {{aws_codeartifact_repository}}"
    if command -v pip >/dev/null; then
        aws codeartifact login --tool pip $repo_flags
    fi
    if command -v npm >/dev/null; then
        aws codeartifact login --tool npm $repo_flags
    fi

# (AWS API) Start a session with AWS Elastic Container Registry
aws-ecr-login ACCOUNT=aws_ecr_account_id REGION=aws_default_region: _requires-aws
    #!/usr/bin/env -S bash -euxo pipefail
    address=$(just _get-aws-ecr-address "{{ACCOUNT}}" "{{REGION}}")
    aws ecr get-login-password --region "{{REGION}}" | docker login --username AWS --password-stdin "$address"

# Build the app container with Docker
build: start-docker
    docker build -t {{name}} .

# Generate requirements*.txt from requirements*.in using pip-tools
build-reqs *FLAGS:
    just build-reqs-deploy {{FLAGS}}
    just build-reqs-dev {{FLAGS}}
    just build-reqs-fmt {{FLAGS}}
    just build-reqs-lint {{FLAGS}}
    just build-reqs-test {{FLAGS}}

# Generate requirements.txt from requirements.in using pip-tools
build-reqs-deploy *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements.txt requirements.in

# Generate requirements-dev.txt from requirements-dev.in using pip-tools
build-reqs-dev *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-dev.txt requirements-dev.in

# Generate requirements-dev.txt from requirements-dev.in using pip-tools
build-reqs-fmt *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-fmt.txt requirements-fmt.in

# Generate requirements-dev.txt from requirements-dev.in using pip-tools
build-reqs-lint *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-lint.txt requirements-lint.in

# Generate requirements-test.txt from requirements-test.in using pip-tools
build-reqs-test *FLAGS:
    pip-compile {{FLAGS}} --strip-extras -o requirements-test.txt requirements-test.in

# Remove development containers and images
clean: stop clean-containers clean-images

# Remove all containers and images
clean-all: stop-all-containers clean-all-containers clean-all-images

# Remove all containers
clean-all-containers:
    #!/usr/bin/env -S bash -euxo pipefail
    containers=$(docker ps -aq)
    echo -n "$containers" | grep -q . && docker rm -vf "$containers" || :

# Remove all images
clean-all-images:
    docker image prune --all --force

# Remove containers by ID
clean-containers CONTAINERS="$(just get-dev-containers)":
    #!/usr/bin/env -S bash -euxo pipefail
    exited=$(docker ps -q -f "status=exited")
    echo -n "$exited" | grep -q . && docker rm -vf "$exited" || :
    containers="{{CONTAINERS}}"
    echo -n "$containers" | grep -q . && docker rm -vf "$containers" || :

# Remove images by ID
clean-images IMAGES="$(just get-dev-images)":
    #!/usr/bin/env -S bash -euxo pipefail
    dangling=$(docker images -f "dangling=true" -q)
    echo -n "$dangling" | grep -q . && docker rmi -f "$dangling" || :
    images="{{IMAGES}}"
    if echo -n "$images" | grep -q . ; then 
        for image in $images; do
            if [[ -z $(just _is-image-used "$image") ]]; then
                docker rmi -f "$image"
            fi
        done
    fi

# Pretty-print Docker status information
docker-status:
    #!/usr/bin/env -S bash -euo pipefail
    containers=$(docker ps -a)
    images=$(docker images)
    printf "\nContainers:\n\n%s\n\nImages:\n\n%s\n\n" "$containers" "$images"

# Format src/ (black & isort)
fmt:
    #!/usr/bin/env -S bash -euxo pipefail
    if [[ ! -x {{venv}}-fmt/bin/activate ]]; then
        python3 -m venv {{venv}}-fmt
    fi
    source {{venv}}-fmt/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements-fmt.txt
    isort {{justfile_directory()}}/src
    black {{justfile_directory()}}/src

# List development container IDs
@get-dev-containers:
    echo $(docker ps -q --filter name="{{name}}*")

# List development image IDs
@get-dev-images:
    echo $(docker images -q)

# (AWS API util) Get AWS Elastic Container Registry address for the current AWS account
_get-aws-ecr-address ACCOUNT=aws_ecr_account_id REGION=aws_default_region:
    #!/usr/bin/env -S bash -euxo pipefail
    if [[ -n "{{ACCOUNT}}" ]]; then
        echo -n "{{ACCOUNT}}".dkr.ecr.{{REGION}}.amazonaws.com
    else
        account=$(aws sts get-caller-identity | python3 -c "import sys, json; print(json.load(sys.stdin)['Account'])")
        echo -n "$account".dkr.ecr.{{REGION}}.amazonaws.com
    fi

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
    echo "Installing the AWS Command Line Interface..."
    case "{{os()}}" in
        linux)
            curl --no-progress-meter "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            trap 'rm -rf -- "awscliv2.zip"' EXIT
            unzip awscliv2.zip
            sudo ./aws/install
            trap 'rm -rf -- "./aws"' EXIT
        ;;
        macos)
            curl --no-progress-meter "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            trap 'rm -rf -- "AWSCLIV2.pkg"' EXIT
            sudo installer -pkg AWSCLIV2.pkg -target /
        ;;
        windows)
            msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
        ;;
        *)
            echo "Unable to determine proper install method. Cancelling" >&2; exit 1
        ;;
    esac

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

# (Docker util) Check if a given image is being used by any containers
_is-image-used IMAGE:
    #!/usr/bin/env -S bash -euo pipefail
    for container in $(docker ps -aq); do
        if docker ps -q --filter "ancestor={{IMAGE}}" | grep -q .; then
            echo -n 0; exit
        fi
    done

# Lint src/ (pylint & flake8)
lint:
    #!/usr/bin/env -S bash -euxo pipefail
    if [[ ! -x {{venv}}-lint/bin/activate ]]; then
        python3 -m venv {{venv}}-lint
    fi
    source {{venv}}-lint/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements-lint.txt
    status=0
    if ! pylint -v {{justfile_directory()}}/src; then
        status=1
    fi
    if ! flake8 -v {{justfile_directory()}}/src; then
        status=1
    fi
    exit $status

# Pretty-print development container information
pretty-dev-containers:
    #!/usr/bin/env -S bash -euo pipefail
    format='{"Name":.Names,"Image":.Image,"Ports":.Ports,"Created":.RunningFor,"Status":.Status}'
    if ! command -v jq >/dev/null; then jq="docker run -i --rm ghcr.io/jqlang/jq"; else jq=jq; fi
    docker ps --filter name="{{name}}*" --format=json 2>/dev/null | eval '$jq "$format"'

# Publish container image to AWS Elastic Container Registry
publish-aws-ecr *TAGS="": _requires-aws
    #!/usr/bin/env -S bash -euxo pipefail
    ecr=$(just _get-aws-ecr-address)
    tags="-t $ecr/test:latest"
    for tag in {{TAGS}}; do
        tags+=" -t $ecr/test:$tag"
    done
    docker build --push $tags .

# Publish container image to AWS Elastic Container Registry
publish-dockerhub *TAGS="":
    #!/usr/bin/env -S bash -euxo pipefail
    tags="-t {{dockerhub}}/{{name}}:latest"
    for tag in {{TAGS}}; do
        tags+=" -t {{dockerhub}}/{{name}}:$tag"
    done
    docker build --push $tags .

# (AWS API util) Ensure the user is logged into AWS if possible, or exit
_requires-aws:
    #!/usr/bin/env -S bash -euo pipefail
    if ! command -v aws >/dev/null; then
        printf "You need the AWS Command Line Interface to run this command.\n\n❯ just install-aws\n\n" >&2
        exit 1
    fi
    if [[ -z $(aws sts get-caller-identity 2>/dev/null) ]]; then
        aws sso login;
    fi

# Build and run the app
run PORT="" NAME="": build
    #!/usr/bin/env -S bash -euo pipefail
    port="{{localhost_port}}"
    if [[ -z "$port" ]]; then 
        port="{{localhost_port}}"
    fi
    name="{{NAME}}"
    if [[ -z "$name" ]]; then 
        name="flask-app-$(head -c 8 <<< `uuidgen`)"
    fi
    docker run --rm -d --name="$name" -p "$port":5000 -e LOG_LEVEL={{log_level}} {{name}}

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
        just pretty-dev-containers; echo
    fi
    printf "Docker Status:\n\n"
    if ( docker stats --no-stream 2>/dev/null ); then
        just docker-status
    else
        printf "Daemon stopped.\n\n"
    fi

# Stop containers by ID
stop CONTAINERS="$(just get-dev-containers)":
    #!/usr/bin/env -S bash -euxo pipefail
    containers="{{CONTAINERS}}"
    echo -n "$containers" | grep -q . && docker stop "$containers" || :

alias stop-all := stop-all-containers
# Stop all containers
stop-all-containers:
    #!/usr/bin/env -S bash -euxo pipefail
    containers=$(docker ps -aq)
    echo -n "$containers" | grep -q . && docker stop "$containers" || :

# Test src/ (Pytest)
test:
    #!/usr/bin/env -S bash -euxo pipefail
    if [[ ! -x {{venv}}-test/bin/activate ]]; then
        python3 -m venv {{venv}}-test
    fi
    source {{venv}}-test/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements-test.txt
    pytest --verbose
