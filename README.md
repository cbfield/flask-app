# Flask Application

This is a template for a simple, containerized Flask application.

The machinary for managing this application is however significantly more sophisticated. This project uses [Just](https://github.com/casey/just?tab=readme-ov-file).

You can run the command `just` to see the scripts available. If you don't have `just` installed yet, then you can get it by running `./utilts/install-just.sh`

Little preview:

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
- `just publish-ghcr`
- `just publish-gar`
- `just publish-dockerhub`

### Starter .env

You can leave this `.env` file at the root of the repository to configure the behavior of the `justfile`:

```env
APP_NAME=flask-app
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
GH_TOKEN_FILE=/Users/chris/.secret/gh_token
GHCR_TOKEN_FILE=/Users/chris/.secret/ghcr_token
GITHUB_NAMESPACE=my-github-username
LOG_LEVEL=DEBUG
PYPI_USERNAME=somebody
PYPI_TOKEN_FILE=/Users/chris/.secret/pypi_token
```
