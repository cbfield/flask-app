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

restart: build
    nc -z localhost {{port}} >/dev/null 2>&1 && just stop || :
    docker run -d --restart=always -p {{port}}:5000 -e LOG_LEVEL={{log_level}} {{image}}

run: build
    docker run -d --restart=always -p {{port}}:5000 -e LOG_LEVEL={{log_level}} {{image}}

@status CONTAINERS="$(just get)":
    if [[ -n {{CONTAINERS}} ]]; then \
        printf "\nThe following development containers were found:\n\n"; \
        docker ps --format=json|jq '{"Name":.Names,"Image":.Image,"Ports":.Ports,"Created":.RunningFor,"Status":.Status}'; \
        echo; \
    else \
        printf "\nNo development containers were found.\n\n"; \
    fi

stop CONTAINERS="$(just get)":
    if [[ -n {{CONTAINERS}} ]]; then docker stop {{CONTAINERS}}; fi

test: build
    python -m pytest

wait INTERVAL="0.2" DELAY="0.3":
    #!/usr/bin/env -S bash -eo pipefail
    while : ; do
        nc -z localhost {{port}} >/dev/null 2>&1 && { sleep {{DELAY}}; break; } 
        sleep {{INTERVAL}}
    done
