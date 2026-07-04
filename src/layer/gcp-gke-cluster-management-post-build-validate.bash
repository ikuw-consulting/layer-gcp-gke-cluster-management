#!/usr/bin/env bash
set -euo pipefail

: "${OUTPUT_SUB_PATH:=kaptain-out}"

if [[ ! -f "${OUTPUT_SUB_PATH}/gcp-gke-cluster-management/base-image" ]]; then
  echo "ERROR: base image record not found; prepare did not run." >&2
  exit 1
fi

cat "${OUTPUT_SUB_PATH}/gcp-gke-cluster-management/base-image"
