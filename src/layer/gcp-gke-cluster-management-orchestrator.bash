#!/usr/bin/env bash
set -euo pipefail

LAYER_PAYLOAD_DIR="${OUTPUT_SUB_PATH:-kaptain-out}"
FINAL_KPM="kaptainpm/final/KaptainPM.yaml"

read_user_data() {
  local key="$1"
  if [[ ! -f "${FINAL_KPM}" ]]; then
    echo ""
    return 0
  fi

  local value
  value=$(yq -r ".user-data.gcp-gke-cluster-management.${key} // \"\"" "${FINAL_KPM}")
  if [[ "${value}" == "null" ]]; then
    value=""
  fi
  echo "${value}"
}

export_from_user_data() {
  local key="$1"
  local var_name="$2"
  local value
  value=$(read_user_data "${key}")
  if [[ -n "${value}" ]]; then
    export "${var_name}=${value}"
    echo "user-data: exported ${var_name} from .user-data.gcp-gke-cluster-management.${key}"
  fi
}

export_from_user_data "baseImage.registry" GKE_BASE_IMAGE_REGISTRY
export_from_user_data "baseImage.namespace" GKE_BASE_IMAGE_NAMESPACE
export_from_user_data "baseImage.name" GKE_BASE_IMAGE_NAME
export_from_user_data "baseImage.tag" GKE_BASE_IMAGE_TAG

USER_PRE_DOCKER_PREPARE_SCRIPT=$(read_user_data userPreDockerPrepare)
USER_POST_DOCKER_TESTS_SCRIPT=$(read_user_data userPostDockerTests)

banner() {
  echo
  echo "=== gcp-gke-cluster-management-orchestrator: $1 ==="
  echo
}

run_step() {
  local label="$1"
  shift
  banner "${label}"

  local step_output_file="${LAYER_PAYLOAD_DIR}/reference-script-output/${label}"
  mkdir -p "$(dirname "${step_output_file}")"
  : > "${step_output_file}"

  if ! REFERENCE_SCRIPT_OUTPUT="${step_output_file}" "$@"; then
    echo "ERROR: ${label} failed." >&2
    exit 1
  fi

  if [[ -s "${step_output_file}" ]]; then
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      export "${line%%=*}"="${line#*=}"
    done < "${step_output_file}"
  fi
}

run_optional_user_hook() {
  local label="$1"
  local script_path="$2"
  if [[ -z "${script_path}" ]]; then
    echo "(skipping ${label}: not configured)"
    return 0
  fi
  if [[ ! -f "${script_path}" ]]; then
    echo "ERROR: ${label} configured but file not found: ${script_path}" >&2
    exit 2
  fi
  if [[ ! -x "${script_path}" ]]; then
    echo "ERROR: ${label} configured but not executable: ${script_path}" >&2
    exit 3
  fi
  banner "${label}: ${script_path}"
  "${script_path}"
}

require_build_scripts() {
  if [[ -z "${BUILD_SCRIPTS_REPO_ROOT:-}" ]]; then
    echo "ERROR: BUILD_SCRIPTS_REPO_ROOT is not set." >&2
    exit 1
  fi
  if [[ ! -d "${BUILD_SCRIPTS_REPO_ROOT}/src/scripts" ]]; then
    echo "ERROR: BUILD_SCRIPTS_REPO_ROOT does not contain src/scripts." >&2
    exit 1
  fi

  BUILD_SCRIPTS_DIR="${BUILD_SCRIPTS_REPO_ROOT}/src/scripts"
  export BUILD_SCRIPTS_DIR
}

banner "load defaults"
# shellcheck source=gcp-gke-cluster-management-defaults.bash
source "${LAYER_PAYLOAD_DIR}/gcp-gke-cluster-management-defaults.bash"

if ! gke_is_consumer_build; then
  require_build_scripts
fi

run_step "prepare" bash "${LAYER_PAYLOAD_DIR}/gcp-gke-cluster-management-prepare.bash"

if gke_is_consumer_build; then
  banner "consumer mode"
  echo "standard final-package workflow owns Dockerfile generation and the single Docker build"
  run_step "pre-build-validate" bash "${LAYER_PAYLOAD_DIR}/gcp-gke-cluster-management-pre-build-validate.bash"
  run_step "post-build-validate" bash "${LAYER_PAYLOAD_DIR}/gcp-gke-cluster-management-post-build-validate.bash"
else
  run_optional_user_hook "user pre-docker-prepare" "${USER_PRE_DOCKER_PREPARE_SCRIPT}"
  run_step "pre-build-validate" bash "${LAYER_PAYLOAD_DIR}/gcp-gke-cluster-management-pre-build-validate.bash"
  run_step "docker-build-dockerfile" bash "${BUILD_SCRIPTS_DIR}/main/docker-build-dockerfile"
  run_step "post-build-validate" bash "${LAYER_PAYLOAD_DIR}/gcp-gke-cluster-management-post-build-validate.bash"
  run_optional_user_hook "user post-docker-tests" "${USER_POST_DOCKER_TESTS_SCRIPT}"
fi

banner "complete"
