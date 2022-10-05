# Github Workflows

These workflows handle building and pushing the container image defined in this repository to various registries. As of now, the two supported registries are Dockerhub and Google Artifact Registry.

## Multi-Platform Images

These workflows build images that are compatible with the platforms `linux/amd64` and `linux/arm64`. In order to support this, there are two setup steps that are run in each build: `Set up Docker Buildx` and `Set up QEMU`.

## Tags

Tags will be created for each image based on the event that triggered the workflow.

- A tag matching a branch name will be created when branches are pushed
- When a Git tag matching `v*.*.*` is pushed, three tags will be created (example for `v1.2.3` tag push):
  - `1.2.3`
  - `1.2`
  - `1`

## Secrets

These workflows depend on repository secrets to function properly.

### Dockerhub

The Dockerhub workflow depends on these secrets:

- `DOCKERHUB_REPO`: The name of the Dockerhub repository (e.g. `my-image`)
- `DOCKERHUB_TOKEN`: A Dockerhub API token used for authenticating with the repository
- `DOCKERHUB_USERNAME`: The Dockerhub username or organization name with ownership of the repository

### Google Artifact Registry

The Google Artifact Registry workflow depends on these secrets:

- `GOOGLE_IMAGE_URL`: The URL of the image being pushed (e.g. `<region>-docker.pkg.dev/<project-id>/<registry-repo-id>/<image-name>`)
- `GOOGLE_REGISTRY_URL`: The URL of the artifact registry (e.g. `<region>-docker.pkg.dev`)
- `GOOGLE_SERVICE_ACCOUNT`: The Google service account that will push the image (e.g. `<sa-name>@<project-id>.iam.gserviceaccount.com`)
- `GOOGLE_WIP`: The ID of the Google Workload Identity Provider associated with the service account (e.g. `iam.googleapis.com/projects/<project-number>/locations/global/workloadIdentityPools/<identity-pool-id>/providers/<provider-id>`)
