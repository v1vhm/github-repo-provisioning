# get-gh-app-token

Composite action to create a GitHub App installation token and export it for subsequent steps.

## Inputs
- `app_id` – GitHub App ID
- `private_key` – GitHub App private key
- `installation_id` – Installation ID

## Outputs
- `token` – The generated installation token

The action also writes the token to `GITHUB_TOKEN` and `GH_TOKEN` for downstream steps.
