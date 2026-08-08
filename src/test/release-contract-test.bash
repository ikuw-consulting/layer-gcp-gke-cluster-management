#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

assert_yaml_value() {
  local file="$1"
  local expression="$2"
  local expected="$3"
  local message="$4"
  local actual

  actual="$(yq -r "${expression}" "${file}")"
  assert_equals "${expected}" "${actual}" "${message}"
}

test_first_compatible_release_is_exactly_1_1_0() {
  local manifest="${REPO_ROOT}/KaptainPM.yaml"

  assert_yaml_value "${manifest}" '.apiVersion' 'kaptain.org/1.22' \
    "root Kaptain API version"
  assert_yaml_value "${manifest}" '.kind' 'layer-and-layerset-build' \
    "root Kaptain build kind"
  assert_yaml_value "${manifest}" '.spec.layers[0]' \
    'ghcr.io/kube-kaptain/layerset/layerset-and-layer-build:[1.4,2.0)' \
    "root build layer dependency"
  assert_yaml_value "${manifest}" '.spec.global.release.versioning.maxParts' '3' \
    "maximum release version parts"
  assert_yaml_value "${manifest}" '.spec.global.release.versioning.strategy' \
    'file-pattern-match' "release calculation strategy"
  assert_yaml_value "${manifest}" '.spec.global.release.versioning.patternType' \
    'custom' "release source pattern type"
  assert_yaml_value \
    "${manifest}" \
    '.spec.global.release.versioning.useSourceVersionExact' \
    'true' \
    "exact source-version mode"
  assert_yaml_value "${manifest}" \
    '.spec.global.release.versioning.source.subPath' '.' \
    "release source path"
  assert_yaml_value "${manifest}" \
    '.spec.global.release.versioning.source.fileName' 'version.txt' \
    "release source file"
  assert_yaml_value "${manifest}" \
    '.spec.global.release.versioning.source.pattern' \
    '^([0-9]+\.[0-9]+\.[0-9]+)$' \
    "release source pattern"
  assert_equals '1.1.0' "$(tr -d '[:space:]' < "${REPO_ROOT}/version.txt")" \
    "first compatible release version"
}

test_pinned_kaptain_workflow_is_gated_by_tests() {
  local workflow="${REPO_ROOT}/.github/workflows/build.yaml"

  assert_yaml_value "${workflow}" '.jobs.test.runs-on' 'ubuntu-latest' \
    "repository test runner"
  assert_yaml_value "${workflow}" '.jobs.test.steps[1].uses' \
    'actions/checkout@v4' "Kaptain source checkout action"
  assert_yaml_value "${workflow}" '.jobs.test.steps[1].with.repository' \
    'kube-kaptain/buildon-github-actions' "Kaptain source repository"
  assert_yaml_value "${workflow}" '.jobs.test.steps[1].with.ref' \
    '1.1.46' "Kaptain source version"
  assert_yaml_value "${workflow}" '.jobs.test.steps[1].with.path' \
    '.kaptain-buildon-1.1.46' "Kaptain source checkout path"
  assert_yaml_value "${workflow}" '.jobs.test.steps[1].with.fetch-depth' \
    '1' "Kaptain source checkout depth"
  assert_yaml_value "${workflow}" '.jobs.test.steps[2].run' \
    'src/test/run-tests.bash' "repository test command"
  # shellcheck disable=SC2016 # Literal GitHub Actions expression.
  assert_yaml_value \
    "${workflow}" \
    '.jobs.test.steps[2].env.KAPTAIN_BUILDON_REPO_ROOT' \
    '${{ github.workspace }}/.kaptain-buildon-1.1.46' \
    "repository test Kaptain source path"
  assert_yaml_value "${workflow}" '.jobs.build.needs' 'test' \
    "Kaptain build test dependency"
  assert_yaml_value "${workflow}" '.jobs.build.uses' \
    'kube-kaptain/buildon-github-actions/.github/workflows/layer-and-layerset-build.yaml@1.1.46' \
    "pinned Kaptain reusable workflow"
  assert_yaml_value "${workflow}" '.jobs.build.permissions.contents' 'write' \
    "Kaptain workflow contents permission"
  assert_yaml_value "${workflow}" '.jobs.build.permissions.packages' 'write' \
    "Kaptain workflow packages permission"
  assert_yaml_value "${workflow}" '.jobs.build.permissions.checks' 'write' \
    "Kaptain workflow checks permission"
}

test_first_compatible_release_is_exactly_1_1_0
test_pinned_kaptain_workflow_is_gated_by_tests

echo "release contract tests passed"
