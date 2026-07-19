#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r file; do
  bash -n "${file}"
done < <(find src/layer src/test -type f \( -name '*.bash' -o -name 'run-tests.bash' \) | sort)

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -e SC1091 src/layer/*.bash src/test/*.bash src/test/fixtures/*.bash
fi

while IFS= read -r test_file; do
  bash "${test_file}"
done < <(find src/test -maxdepth 1 -type f -name '*-test.bash' | sort)
