#!/bin/bash

SECUREFLOW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECUREFLOW_REPO_ROOT="$(cd "${SECUREFLOW_SCRIPT_DIR}/.." && pwd)"
DOCKER_WAIT_SECONDS="${DOCKER_WAIT_SECONDS:-120}"

require_command() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo "ERROR: Required command '$1' is not installed or is not on PATH." >&2
        exit 1
    fi
}

wait_for_docker() {
    if docker info > /dev/null 2>&1; then
        return
    fi

    if [[ "$(uname -s)" == "Darwin" && -d "/Applications/Docker.app" ]]; then
        echo "Docker daemon is not running. Starting Docker Desktop..."
        open -g -a Docker || true
    else
        echo "ERROR: Docker daemon is not running. Start Docker and re-run this script." >&2
        exit 1
    fi

    echo "Waiting for Docker daemon to become available..."
    for ((i = 1; i <= DOCKER_WAIT_SECONDS; i++)); do
        if docker info > /dev/null 2>&1; then
            echo "Docker daemon is ready."
            return
        fi
        sleep 1
    done

    echo "ERROR: Docker daemon did not become available within ${DOCKER_WAIT_SECONDS}s." >&2
    exit 1
}
