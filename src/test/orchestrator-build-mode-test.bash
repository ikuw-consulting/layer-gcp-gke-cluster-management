#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_TMP_ROOT}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    fail "${message}: expected '${expected}', got '${actual}'"
  fi
}

new_sandbox() {
  local sandbox
  sandbox="$(mktemp -d "${TEST_TMP_ROOT}/case.XXXXXX")"

  mkdir -p \
    "${sandbox}/work/kaptain-out" \
    "${sandbox}/build-scripts/src/scripts/main"
  cp "${REPO_ROOT}"/src/layer/*.bash "${sandbox}/work/kaptain-out/"
  cp \
    "${REPO_ROOT}/src/test/fixtures/docker-build-dockerfile.bash" \
    "${sandbox}/build-scripts/src/scripts/main/docker-build-dockerfile"

  printf '%s\n' "${sandbox}"
}

run_orchestrator() {
  local sandbox="$1"
  local build_kind="$2"
  local consumer_base_tag="${3:-}"

  if [[ "${build_kind}" == "kubernetes-bundle-docker-dockerfile" ]]; then
    if [[ -n "${consumer_base_tag}" ]]; then
      (
        cd "${sandbox}/work"
        BUILD_KIND="${build_kind}" \
          GKE_BASE_IMAGE_TAG="${consumer_base_tag}" \
          DOCKER_BUILD_CALLS_FILE="${sandbox}/docker-build-calls" \
          bash kaptain-out/gcp-gke-cluster-management-orchestrator.bash
      )
    else
      (
        cd "${sandbox}/work"
        BUILD_KIND="${build_kind}" \
          DOCKER_BUILD_CALLS_FILE="${sandbox}/docker-build-calls" \
          bash kaptain-out/gcp-gke-cluster-management-orchestrator.bash
      )
    fi
  else
    (
      cd "${sandbox}/work"
      BUILD_KIND="${build_kind}" \
        BUILD_SCRIPTS_REPO_ROOT="${sandbox}/build-scripts" \
        DOCKER_BUILD_CALLS_FILE="${sandbox}/docker-build-calls" \
        bash kaptain-out/gcp-gke-cluster-management-orchestrator.bash
    )
  fi
}

build_call_count() {
  local calls_file="$1"

  if [[ ! -f "${calls_file}" ]]; then
    printf '%s\n' "0"
    return 0
  fi

  awk 'END { print NR }' "${calls_file}"
}

test_consumer_mode_leaves_the_single_build_to_the_final_workflow() {
  local sandbox
  local calls_file
  sandbox="$(new_sandbox)"
  calls_file="${sandbox}/docker-build-calls"

  run_orchestrator \
    "${sandbox}" \
    "kubernetes-bundle-docker-dockerfile" \
    > "${sandbox}/orchestrator-output"

  if [[ -e "${sandbox}/work/src/docker/Dockerfile" ]]; then
    fail "consumer mode generated a competing Dockerfile"
  fi
  assert_equals \
    "ghcr.io/ikuw-consulting/image/image-gcp-gke-cluster-management:1.34.1" \
    "$(cat "${sandbox}/work/kaptain-out/gcp-gke-cluster-management/base-image")" \
    "consumer-mode prepared base image"
  assert_equals \
    "0" \
    "$(build_call_count "${calls_file}")" \
    "consumer-mode layer-owned Docker build count"

  DOCKER_BUILD_CALLS_FILE="${calls_file}" \
    bash "${sandbox}/build-scripts/src/scripts/main/docker-build-dockerfile"

  assert_equals \
    "1" \
    "$(build_call_count "${calls_file}")" \
    "total Docker build count after the standard final workflow runs"
}

test_standalone_mode_retains_one_layer_owned_build() {
  local sandbox
  local calls_file
  sandbox="$(new_sandbox)"
  calls_file="${sandbox}/docker-build-calls"

  run_orchestrator \
    "${sandbox}" \
    "docker-build-dockerfile" \
    > "${sandbox}/orchestrator-output"

  if [[ ! -f "${sandbox}/work/src/docker/Dockerfile" ]]; then
    fail "standalone mode did not generate its Dockerfile"
  fi
  assert_equals \
    "1" \
    "$(build_call_count "${calls_file}")" \
    "standalone layer-owned Docker build count"
}

test_consumer_mode_rejects_a_two_part_base_tag() {
  local sandbox
  sandbox="$(new_sandbox)"

  if run_orchestrator \
    "${sandbox}" \
    "kubernetes-bundle-docker-dockerfile" \
    "1.0" \
    > "${sandbox}/orchestrator-output" 2>&1; then
    fail "consumer mode accepted a two-part management base-image tag"
  fi

  if ! grep -q "must use a three-part C.D.E tag" "${sandbox}/orchestrator-output"; then
    fail "consumer mode did not explain the rejected two-part base-image tag"
  fi
}

test_consumer_mode_leaves_the_single_build_to_the_final_workflow
test_standalone_mode_retains_one_layer_owned_build
test_consumer_mode_rejects_a_two_part_base_tag

echo "orchestrator build-mode tests passed"
