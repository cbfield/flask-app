# Flask Application

This is a template for a simple, containerized Flask application.

The machinary for managing this application is however significantly more sophisticated. This project uses [Just](https://github.com/casey/just?tab=readme-ov-file).

You can run the command `just` to see the scripts available. If you don't have `just` installed yet, then you can get it by running `./utils/install-just.sh`

Here is a preview:

- `just build`
- `just fmt` (black & isort)
- `just lint` (mypy & pylint & flake8)
- `just test` (pytest)
- `just clean`
- `just clean-all`
- `just install-aws`
- `just install-gcloud`
- `just install-jq`
- `just publish-aws-ecr`
- `just publish-aws-codeartifact`
- `just publish-ghcr`
- `just publish-gar`
- `just publish-dockerhub`
- `just publish-pypi`

### Starter .env

You can leave a `.env` file at the root of the repository to configure the behavior of the `justfile`. Here's a starter:

```env
APP_NAME=flask-app
APP_LOG_LEVEL=DEBUG
APP_PORT=5001
AWS_CODEARTIFACT_DOMAIN=main
AWS_CODEARTIFACT_DOMAIN_OWNER=000000000000
AWS_CODEARTIFACT_REPOSITORY=flask-app
AWS_DEFAULT_REGION=us-west-2
AWS_ECR_ACCOUNT_ID=000000000000
AWS_ECR_REPOSITORY=flask-app
CLOUDSDK_COMPUTE_ZONE=us-west1
CLOUDSDK_CORE_PROJECT=my-project
DOCKERHUB_NAMESPACE=my-dockerhub-username
GCLOUD_GAR_REGISTRY=main
GH_TOKEN_FILE=/Users/me/.secret/gh_token
GHCR_TOKEN_FILE=/Users/me/.secret/ghcr_token
GITHUB_NAMESPACE=my-github-username
PYPI_USERNAME=somebody
PYPI_TOKEN_FILE=/Users/me/.secret/pypi_token
```
