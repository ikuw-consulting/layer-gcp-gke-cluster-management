#!/usr/bin/env bash
# shellcheck disable=SC2034

GKE_BASE_IMAGE_REGISTRY="${GKE_BASE_IMAGE_REGISTRY:-ghcr.io}"
GKE_BASE_IMAGE_NAMESPACE="${GKE_BASE_IMAGE_NAMESPACE:-kube-kaptain}"
GKE_BASE_IMAGE_NAME="${GKE_BASE_IMAGE_NAME:-image/image-gcp-gke-cluster-management}"
GKE_BASE_IMAGE_TAG="${GKE_BASE_IMAGE_TAG:-1.0}"
