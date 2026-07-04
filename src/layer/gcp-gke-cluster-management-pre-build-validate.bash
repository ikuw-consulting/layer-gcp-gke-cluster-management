#!/usr/bin/env bash
set -euo pipefail

: "${DOCKER_CONTEXT_SUB_PATH:=src/docker}"
dockerfile_path="${DOCKER_CONTEXT_SUB_PATH}/Dockerfile"

if [[ ! -f "${dockerfile_path}" ]]; then
  echo "ERROR: Dockerfile not found: ${dockerfile_path}" >&2
  exit 1
fi

if ! grep -Eq '^FROM[[:space:]]+[^[:space:]]+:[^[:space:]]+' "${dockerfile_path}"; then
  echo "ERROR: Dockerfile must start from a tagged base image." >&2
  exit 1
fi
