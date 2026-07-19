#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gcp-gke-cluster-management-defaults.bash
source "${SCRIPT_DIR}/gcp-gke-cluster-management-defaults.bash"

: "${OUTPUT_SUB_PATH:=kaptain-out}"
: "${DOCKER_CONTEXT_SUB_PATH:=src/docker}"

if gke_is_consumer_build; then
  base_image_record="${OUTPUT_SUB_PATH}/gcp-gke-cluster-management/base-image"
  if [[ ! -f "${base_image_record}" ]]; then
    echo "ERROR: base image record not found: ${base_image_record}" >&2
    exit 1
  fi
  if ! grep -Eq '^[^[:space:]]+:[0-9]+\.[0-9]+\.[0-9]+(@sha256:[0-9a-f]{64})?$' "${base_image_record}"; then
    echo "ERROR: consumer-mode base image must use a three-part C.D.E tag." >&2
    exit 1
  fi
  exit 0
fi

dockerfile_path="${DOCKER_CONTEXT_SUB_PATH}/Dockerfile"

if [[ ! -f "${dockerfile_path}" ]]; then
  echo "ERROR: Dockerfile not found: ${dockerfile_path}" >&2
  exit 1
fi

if ! grep -Eq '^FROM[[:space:]]+[^[:space:]]+:[^[:space:]]+' "${dockerfile_path}"; then
  echo "ERROR: Dockerfile must start from a tagged base image." >&2
  exit 1
fi
