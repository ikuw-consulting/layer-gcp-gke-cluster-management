# Layer GCP GKE Cluster Management

Kaptain config layer providing a GCP GKE cluster management image build flow as
a `postVersionsAndNaming` hook on top of the standard
`basic-quality-and-versioning` workflow.

For information on how the image works in use, see
`image-gcp-gke-cluster-management`.

Standalone image projects that reference this layer inherit:

- **Base image composition** - generates a Dockerfile from the configured GKE
  cluster management base image.
- **Pre-build validation** - verifies Docker build inputs before the image
  build runs.
- **Docker build** - calls buildon's `docker-build-dockerfile` flow with the
  generated Dockerfile.
- **Post-build validation** - checks the configured image output is present and
  runnable by the build tooling.
- **User hook slots** - optional `userPreDockerPrepare` and
  `userPostDockerTests` for project-specific glue.

## Build Modes

For build kinds other than `kubernetes-bundle-docker-dockerfile`, the layer
keeps its standalone derived-image flow: prepare the Dockerfile, validate it,
invoke `docker-build-dockerfile` once, validate the output, and run the optional
Docker hook slots.

When the merged Kaptain manifest exports
`BUILD_KIND=kubernetes-bundle-docker-dockerfile`, the layer switches to
consumer mode. It records and validates the configured management base image,
but it does not:

- generate a Dockerfile;
- invoke `docker-build-dockerfile`; or
- run its standalone Docker hook slots.

The consuming final-package workflow owns Dockerfile preparation, its
`preDockerPrepare` and `postDockerTests` hooks, and the single Docker build.
This consumer-mode contract starts with layer release `1.1.0`.

## Release Version

The root build reads the exact release version from `version.txt`. The first
consumer-compatible release is `1.1.0`; Kaptain does not auto-increment it.
After `1.1.0` is published, change `version.txt` deliberately for each later
release. Exact-source mode rejects a version whose Git tag already exists.
Publish management image `1.34.1` before publishing layer `1.1.0`, so the
layer's default base-image reference is resolvable when consumers adopt it.

## Configuring Hook Slots

The orchestrator reads optional hook paths from the consuming project's
`kaptainpm/final/KaptainPM.yaml` under `user-data`.
These slots apply to the standalone derived-image flow.

```yaml
user-data:
  gcp-gke-cluster-management:
    userPreDockerPrepare: bin/copy-scripts-to-docker-context.bash
    userPostDockerTests: bin/run-image-checks.bash
```

Path resolution is relative to the repo root. Files must be executable.

## Reference

```yaml
user-data:
  gcp-gke-cluster-management:
    baseImage:
      registry: ghcr.io
      namespace: ikuw-consulting
      name: image/image-gcp-gke-cluster-management
      tag: "1.34.1"
    userPreDockerPrepare: bin/copy-scripts-to-docker-context.bash
    userPostDockerTests: bin/run-image-checks.bash
```
