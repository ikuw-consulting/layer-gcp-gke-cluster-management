#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d)"
KAPTAIN_BUILDON_REPO_ROOT="${KAPTAIN_BUILDON_REPO_ROOT:-${KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT:-}}"
PINNED_KAPTAIN_VERSION="1.1.59"
PINNED_KAPTAIN_COMMIT="410ea07308ab63e6ba979783ff99d60105d1fc1d"
PINNED_FINAL_REFERENCE="src/scripts/reference/kubernetes-bundle-docker-dockerfile"
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

assert_pinned_final_workflow_has_one_docker_build() {
  local actual_commit
  local reference_build_count

  if [[ -z "${KAPTAIN_BUILDON_REPO_ROOT}" ]]; then
    fail "KAPTAIN_BUILDON_REPO_ROOT is required to inspect Kaptain ${PINNED_KAPTAIN_VERSION}"
  fi
  if [[ ! -d "${KAPTAIN_BUILDON_REPO_ROOT}/.git" ]]; then
    fail "KAPTAIN_BUILDON_REPO_ROOT is not a Git checkout: ${KAPTAIN_BUILDON_REPO_ROOT}"
  fi

  actual_commit="$(
    git -C "${KAPTAIN_BUILDON_REPO_ROOT}" \
      rev-parse "${PINNED_KAPTAIN_VERSION}^{}"
  )"
  assert_equals \
    "${PINNED_KAPTAIN_COMMIT}" \
    "${actual_commit}" \
    "Kaptain ${PINNED_KAPTAIN_VERSION} commit"

  reference_build_count="$(
    git -C "${KAPTAIN_BUILDON_REPO_ROOT}" \
      show "${PINNED_KAPTAIN_VERSION}:${PINNED_FINAL_REFERENCE}" |
      awk '/^[[:space:]]*run_step "docker-build-dockerfile"[[:space:]]*$/ { count++ } END { print count + 0 }'
  )"
  assert_equals \
    "1" \
    "${reference_build_count}" \
    "pinned standard final-workflow Docker build count"
}

test_consumer_mode_preserves_final_dockerfile_and_leaves_build_to_final_workflow() {
  local sandbox
  local calls_file
  sandbox="$(new_sandbox)"
  calls_file="${sandbox}/docker-build-calls"

  mkdir -p "${sandbox}/work/src/docker"
  cp \
    "${REPO_ROOT}/src/test/fixtures/final-package.Dockerfile" \
    "${sandbox}/work/src/docker/Dockerfile"

  run_orchestrator \
    "${sandbox}" \
    "kubernetes-bundle-docker-dockerfile" \
    > "${sandbox}/orchestrator-output"

  if ! cmp -s \
    "${REPO_ROOT}/src/test/fixtures/final-package.Dockerfile" \
    "${sandbox}/work/src/docker/Dockerfile"; then
    fail "consumer mode changed the preexisting final-package Dockerfile"
  fi
  assert_equals \
    "ghcr.io/ikuw-consulting/image/image-gcp-gke-cluster-management:1.34.1" \
    "$(cat "${sandbox}/work/kaptain-out/gcp-gke-cluster-management/base-image")" \
    "consumer-mode prepared base image"
  assert_equals \
    "0" \
    "$(build_call_count "${calls_file}")" \
    "consumer-mode layer-owned Docker build count"

  assert_pinned_final_workflow_has_one_docker_build
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

test_consumer_mode_preserves_final_dockerfile_and_leaves_build_to_final_workflow
test_standalone_mode_retains_one_layer_owned_build
test_consumer_mode_rejects_a_two_part_base_tag

echo "orchestrator build-mode tests passed"
