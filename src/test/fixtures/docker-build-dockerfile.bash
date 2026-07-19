#!/usr/bin/env bash
set -euo pipefail

: "${DOCKER_BUILD_CALLS_FILE:?DOCKER_BUILD_CALLS_FILE is required}"

printf '%s\n' "docker-build-dockerfile" >> "${DOCKER_BUILD_CALLS_FILE}"
