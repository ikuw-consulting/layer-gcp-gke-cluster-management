# Layer GCP GKE Cluster Management

Kaptain config layer providing a GCP GKE cluster management image build flow as
a `postVersionsAndNaming` hook on top of the standard
`basic-quality-and-versioning` workflow.

For information on how the image works in use, see
`image-gcp-gke-cluster-management`.

Projects that reference this layer inherit:

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

## Configuring Hook Slots

The orchestrator reads optional hook paths from the consuming project's
`kaptainpm/final/KaptainPM.yaml` under `user-data`.

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
      namespace: kube-kaptain
      name: image/image-gcp-gke-cluster-management
      tag: "1.0"
    userPreDockerPrepare: bin/copy-scripts-to-docker-context.bash
    userPostDockerTests: bin/run-image-checks.bash
```
