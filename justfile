#!/usr/bin/env just --justfile

#------------ Settings ------------
set dotenv-load
set export
#------------ Settings ------------

#------------ Variables -----------
APP_NAME := `echo ${APP_NAME:-flask-app}`
APP_LOG_LEVEL := `echo ${APP_LOG_LEVEL:-INFO}`
APP_PORT := `echo ${APP_PORT:-5001}`

AWS_DEFAULT_REGION := `echo ${AWS_DEFAULT_REGION:-us-west-2}`
AWS_ECR_REPOSITORY := `echo ${AWS_ECR_REPOSITORY:-flask-app}`

GCLOUD_REGION := `echo ${CLOUDSDK_COMPUTE_ZONE:-us-west1}`
GCLOUD_REGISTRY := `echo ${GCLOUD_REGISTRY:-main}`
GCLOUD_REPOSITORY := `echo ${GCLOUD_REPOSITORY:-flask-app}`

GH_TOKEN := ```
    if test -n "${GH_TOKEN:-}"; then { echo "${GH_TOKEN:-}"; exit; }; fi
    if test -f "${GH_TOKEN_FILE:-}"; then cat "${GH_TOKEN_FILE:-}"; fi
```

PYPI_TOKEN := ```
    if test -n "${PYPI_TOKEN:-}"; then { echo "${PYPI_TOKEN:-}"; exit; }; fi
    if test -f "${PYPI_TOKEN_FILE:-}"; then cat "${PYPI_TOKEN_FILE:-}"; fi
```

GHCR_TOKEN := ```
    if test -n "${GHCR_TOKEN:-}"; then { echo "${GHCR_TOKEN:-}"; exit; }; fi
    if test -f "${GHCR_TOKEN_FILE:-}"; then cat "${GHCR_TOKEN_FILE:-}"; fi
```
#------------ Variables -----------

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
        -sL \
        http://localhost:${APP_PORT}{{PATH}}

# (AWS API) Start a session with AWS CodeArtifact
aws-codeartifact-login: _requires-aws
    #!/usr/bin/env -S bash -euxo pipefail
    if test -z "${AWS_CODEARTIFACT_DOMAIN}" && test -z "${AWS_CODEARTIFACT_REPOSITORY}"; then
        exit
    fi
    repo_flags="--domain ${AWS_CODEARTIFACT_DOMAIN} --domain-owner ${AWS_CODEARTIFACT_DOMAIN_OWNER} --repository ${AWS_CODEARTIFACT_REPOSITORY}"
    if command -v npm >/dev/null; then
        aws codeartifact login --tool npm $repo_flags
    fi
    if test -x {{justfile_directory()}}/.venv-dev/bin/activate; then
        source {{justfile_directory()}}/.venv-dev/bin/activate
    fi
    if command -v pip >/dev/null; then
        aws codeartifact login --tool pip $repo_flags
    fi
    if command -v poetry >/dev/null; then
        endpoint=$(aws codeartifact get-repository-endpoint --domain ${AWS_CODEARTIFACT_DOMAIN} --domain-owner ${aws_codeartifact_domain_owner} --repository ${AWS_CODEARTIFACT_REPOSITORY} --format pypi --query repositoryEndpoint --output text)
        token=$(aws codeartifact get-authorization-token --domain ${AWS_CODEARTIFACT_DOMAIN} --domain-owner ${AWS_CODEARTIFACT_DOMAIN_OWNER} --query authorizationToken --output text)
        poetry config repositories.codeartifact "$endpoint"
        poetry config http-basic.codeartifact aws "$token"
    fi

# (AWS API) Start a session with AWS Elastic Container Registry
aws-ecr-login ACCOUNT="${AWS_ECR_ACCOUNT_ID}" REGION="${AWS_DEFAULT_REGION}": _requires-aws
    #!/usr/bin/env -S bash -euxo pipefail
    address=$(just _get-aws-ecr-address "{{ACCOUNT}}" "{{REGION}}")
    aws ecr get-login-password --region "{{REGION}}" | docker login --username AWS --password-stdin "$address"

# Build the app container with Docker
build: start-docker
    docker build -t "${APP_NAME}" .

# Generate requirements*.txt from requirements*.in using pip-tools
build-reqs-all:
    #!/usr/bin/env -S bash -euxo pipefail
    just build-reqs
    just build-reqs dev
    just build-reqs fmt
    just build-reqs lint
    just build-reqs test

# Generate requirements-{{PY_ENV}}.txt files from requirements-{{PY_ENV}}.in files
build-reqs PY_ENV="":
    #!/usr/bin/env -S bash -euxo pipefail
    reqs_name=requirements/requirements
    if test -n "{{PY_ENV}}"; then
        reqs_name+="-{{PY_ENV}}"
    fi
    if test ! -x {{justfile_directory()}}/.venv-dev/bin/activate; then
        python3 -m venv {{justfile_directory()}}/.venv-dev
    fi
    source {{justfile_directory()}}/.venv-dev/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements/requirements-dev.txt
    pip-compile --strip-extras --no-emit-index-url -o "$reqs_name".txt "$reqs_name".in

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
            if test -z $(just _is-ancestor "$image"); then
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
    if test ! -x {{justfile_directory()}}/.venv-fmt/bin/activate; then
        python3 -m venv {{justfile_directory()}}/.venv-fmt
    fi
    source {{justfile_directory()}}/.venv-fmt/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements/requirements-fmt.txt
    isort {{justfile_directory()}}/src
    black {{justfile_directory()}}/src

# List development container IDs
@get-dev-containers:
    echo $(docker ps -q --filter name="${APP_NAME}*")

# List development image IDs
@get-dev-images:
    echo $(docker images -q)

# (AWS API util) Get AWS Elastic Container Registry address for the current AWS account
_get-aws-ecr-address ACCOUNT="${AWS_ECR_ACCOUNT_ID}" REGION="${AWS_DEFAULT_REGION}":
    #!/usr/bin/env -S bash -euxo pipefail
    if test -n "{{ACCOUNT}}"; then
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
    #!/usr/bin/env -S bash -euxo pipefail
    headers="-H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' -H \"Authorization: Bearer ${GH_TOKEN}\""
    curl $headers -sL https://api.github.com/repos/{{OWNER}}/{{REPO}}/releases/tags/{{TAG}} | just _handle-gh-api-errors

# Download a Github release binary asset
get-gh-release-binary OWNER REPO TAG ASSET DEST:
    #!/usr/bin/env -S bash -euxo pipefail
    printf "\nRetrieving Release Binary...\n\nOWNER:\t\t%s\nREPO:\t\t%s\nRELEASE TAG:\t%s\nTARGET:\t\t%s\nDESTINATION:\t%s\n\n" {{OWNER}} {{REPO}} {{TAG}} {{ASSET}} {{DEST}}
    asset_id=$(just get-gh-release {{OWNER}} {{REPO}} {{TAG}} | just _get-gh-release-asset-id {{ASSET}})
    if test -z "$asset_id"; then
        printf "Asset %s not found.\n\n" "{{ASSET}}" >&2; exit 1
    fi
    curl -sL -o "{{DEST}}" \
      -H "Accept: application/octet-stream" -H "X-GitHub-Api-Version: 2022-11-28" -H "Authorization: Bearer ${GH_TOKEN}" \
      https://api.github.com/repos/{{OWNER}}/{{REPO}}/releases/assets/$asset_id
    chmod +x "{{DEST}}"

# Get the latest release for a given Github repo
get-latest-gh-release OWNER REPO:
    #!/usr/bin/env -S bash -euxo pipefail
    headers="-H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' -H \"Authorization: Bearer ${GH_TOKEN}\""
    releases=$(curl "$headers" -sL https://api.github.com/repos/{{OWNER}}/{{REPO}}/releases)
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
    #!/usr/bin/env -S bash -euxo pipefail
    echo "Installing the AWS Command Line Interface..."
    case "{{os()}}" in
        linux)
            curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            trap 'rm -rf -- "awscliv2.zip"' EXIT
            unzip awscliv2.zip
            sudo ./aws/install --update
            trap 'rm -rf -- "./aws"' EXIT
        ;;
        macos)
            curl -sL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
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

# Install the GCloud Command Line Interface
install-gcloud VERSION="463.0.0":
    #!/usr/bin/env -S bash -euxo pipefail
    echo "Installing the Google Cloud Command Line Interface..."
    url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads"
    machine=$(uname -m | sed -e 's/arm64/arm/g')
    distribution=$(uname -s | tr '[:upper:]' '[:lower:]')
    curl -sL \
        "$url/google-cloud-cli-{{VERSION}}-$distribution-$machine.tar.gz" | tar -xzf - -C "$HOME"
    "$HOME/google-cloud-sdk/install.sh" -q
    gcloud_path="$HOME/google-cloud-sdk/path.$(basename $SHELL).inc"
    completion="$HOME/google-cloud-sdk/completion.$(basename $SHELL).inc"
    rcfile="$HOME/.$(basename $SHELL)rc"
    if ! grep -q "$gcloud_path" "$HOME/.$(basename $SHELL)rc"; then
        printf "\n# Google Cloud SDK PATH\nif [ -f %s ]; then . %s; fi\n\n" "$gcloud_path" "$gcloud_path" >> "$rcfile"
    fi
    if ! grep -q "$completion" "$HOME/.$(basename $SHELL)rc"; then
        printf "\n# Google Cloud SDK Completion\nif [ -f %s ]; then . %s; fi\n\n" "$completion" "$completion" >> "$rcfile"
    fi

# Install jq via pre-built binary from the Github API
install-jq VERSION="latest" INSTALL_DIR="$HOME/bin" TARGET="":
    #!/usr/bin/env -S bash -euxo pipefail
    version="{{VERSION}}"
    if [ "$version" == "latest" ]; then
        echo "Looking up latest version..."
        release=$(just get-latest-gh-release jqlang jq)
        version=$(echo "$release" | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"].split("-")[-1])')
        printf "Found %s\n" "$version."
    else
        printf "Validating version %s...\n" "$version"
        release=$(just get-gh-release jqlang jq "jq-$version")
        if test -n "$release"; then
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
    if test -n "{{TARGET}}"; then
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
_is-ancestor IMAGE:
    #!/usr/bin/env -S bash -euo pipefail
    for container in $(docker ps -aq); do
        if docker ps -q --filter "ancestor={{IMAGE}}" | grep -q .; then
            echo -n 0; exit
        fi
    done

# Lint src/ (pylint & flake8)
lint:
    #!/usr/bin/env -S bash -euxo pipefail
    if test ! -x {{justfile_directory()}}/.venv-lint/bin/activate; then
        python3 -m venv {{justfile_directory()}}/.venv-lint
    fi
    source {{justfile_directory()}}/.venv-lint/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements/requirements-lint.txt
    status=0
    if ! pylint -v {{justfile_directory()}}/src; then
        status=1
    fi
    if ! mypy {{justfile_directory()}}/src; then
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
    docker ps --filter name="${APP_NAME}*" --format=json 2>/dev/null | eval '$jq "$format"'

# Publish Python package to AWS CodeArtifact
publish-aws-codeartifact: aws-codeartifact-login
    #!/usr/bin/env -S bash -euxo pipefail
    if test ! -x {{justfile_directory()}}/.venv-dev/bin/activate; then
        python3 -m venv {{justfile_directory()}}/.venv-dev
    fi
    source {{justfile_directory()}}/.venv-dev/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements/requirements.txt
    poetry build && poetry publish -r codeartifact

# Publish Python package to PyPI
publish-pypi:
    #!/usr/bin/env -S bash -euxo pipefail
    if test ! -x {{justfile_directory()}}/.venv-dev/bin/activate; then
        python3 -m venv {{justfile_directory()}}/.venv-dev
    fi
    source {{justfile_directory()}}/.venv-dev/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements/requirements.txt
    poetry config --unset
    poetry config pypi-token.pypi ${PYPI_TOKEN}
    poetry build && poetry publish

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
    tags="-t ${DOCKERHUB_NAMESPACE}/${APP_NAME}:latest"
    for tag in {{TAGS}}; do
        tags+=" -t ${DOCKERHUB_NAMESPACE}/${APP_NAME}:$tag"
    done
    docker build --push $tags .

# Publish container image to Google Artifact Registry
publish-gar *TAGS="": _requires-gcloud
    #!/usr/bin/env -S bash -euxo pipefail
    tags="-t ${GCLOUD_REGION}-docker.pkg.dev/${GCLOUD_PROJECT_ID}/${GCLOUD_REGISTRY}/${APP_NAME}:latest"
    for tag in {{TAGS}}; do
        tags+=" -t ${GCLOUD_REGION}-docker.pkg.dev/${GCLOUD_PROJECT_ID}/${GCLOUD_REGISTRY}/${APP_NAME}:$tag"
    done
    docker build --push $tags .

# Publish container image to Github Container Registry
publish-ghcr *TAGS="":
    #!/usr/bin/env -S bash -euxo pipefail
    docker login ghcr.io -u ${GH_NAMESPACE} -p ${GHCR_TOKEN}
    tags="-t ghcr.io/${GH_NAMESPACE}/${APP_NAME}:latest"
    for tag in {{TAGS}}; do
        tags+=" -t ghcr.io/${GH_NAMESPACE}/${APP_NAME}:$tag"
    done
    docker build --push $tags .

# (AWS API util) Ensure the user is logged into AWS if possible, or exit
_requires-aws:
    #!/usr/bin/env -S bash -euo pipefail
    if ! command -v aws >/dev/null; then
        printf "You need the AWS Command Line Interface to run this command.\n\n❯ just install-aws\n\n" >&2
        exit 1
    fi
    if test -z $(aws sts get-caller-identity 2>/dev/null); then
        aws sso login
    fi

# (GCloud API util) Ensure the user is logged into GCloud if possible, or exit
_requires-gcloud:
    #!/usr/bin/env -S bash -euo pipefail
    if ! command -v gcloud >/dev/null; then
        printf "You need the Google Cloud Command Line Interface to run this command.\n\n❯ just install-gcloud\n\n" >&2
        exit 1
    fi
    if test -z $(gcloud auth list --filter=status:ACTIVE --format="value(account)"); then
        gcloud auth login
    fi

# Build and run the app
run PORT="" NAME="": build
    #!/usr/bin/env -S bash -euo pipefail
    name="{{NAME}}"
    if test -z "$name"; then 
        name="flask-app-$(head -c 8 <<< `uuidgen`)"
    fi
    docker run --rm -d --name="${name}" -p "${APP_PORT}" -e "LOG_LEVEL=${LOG_LEVEL}" "${APP_NAME}"

# Start the Docker daemon
start-docker:
    #!/usr/bin/env -S bash -euo pipefail
    if ( ! docker stats --no-stream 2>/dev/null ); then
        echo "Starting the Docker daemon..."
        if [ "{{os()}}" = "macos" ]; then
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
    if test -z $containers; then
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
    if test ! -x {{justfile_directory()}}/.venv-test/bin/activate; then
        python3 -m venv {{justfile_directory()}}/.venv-test
    fi
    source {{justfile_directory()}}/.venv-test/bin/activate
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements/requirements-test.txt
    pytest --verbose
