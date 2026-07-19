#!/usr/bin/env bash
# shellcheck disable=SC2034

GKE_BASE_IMAGE_REGISTRY="${GKE_BASE_IMAGE_REGISTRY:-ghcr.io}"
GKE_BASE_IMAGE_NAMESPACE="${GKE_BASE_IMAGE_NAMESPACE:-ikuw-consulting}"
GKE_BASE_IMAGE_NAME="${GKE_BASE_IMAGE_NAME:-image/image-gcp-gke-cluster-management}"
GKE_BASE_IMAGE_TAG="${GKE_BASE_IMAGE_TAG:-1.34.1}"

GKE_CONSUMER_BUILD_KIND="kubernetes-bundle-docker-dockerfile"

gke_is_consumer_build() {
  [[ "${BUILD_KIND:-}" == "${GKE_CONSUMER_BUILD_KIND}" ]]
}
