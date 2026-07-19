#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gcp-gke-cluster-management-defaults.bash
source "${SCRIPT_DIR}/gcp-gke-cluster-management-defaults.bash"

: "${OUTPUT_SUB_PATH:=kaptain-out}"
: "${DOCKER_CONTEXT_SUB_PATH:=src/docker}"

mkdir -p "${OUTPUT_SUB_PATH}/gcp-gke-cluster-management"

base_image="${GKE_BASE_IMAGE_REGISTRY}/${GKE_BASE_IMAGE_NAMESPACE}/${GKE_BASE_IMAGE_NAME}:${GKE_BASE_IMAGE_TAG}"
printf '%s' "${base_image}" > "${OUTPUT_SUB_PATH}/gcp-gke-cluster-management/base-image"

if gke_is_consumer_build; then
  echo "consumer mode: recorded base image without generating a Dockerfile"
  exit 0
fi

mkdir -p "${DOCKER_CONTEXT_SUB_PATH}"
dockerfile_path="${DOCKER_CONTEXT_SUB_PATH}/Dockerfile"

if [[ ! -f "${dockerfile_path}" ]]; then
  cat > "${dockerfile_path}" <<EOF
FROM ${base_image}
EOF
fi
