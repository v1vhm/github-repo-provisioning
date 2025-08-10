# Tests

This directory contains sample `workflow_dispatch` event payloads for simulating Port-triggered workflows using [act](https://github.com/nektos/act).

## Usage

1. Create a `.secrets` file in the repository root with the secrets required by the workflows (e.g. `GH_ORG`, `GH_APP_ID`, `GH_APP_PRIVATE_KEY`, `GH_APP_INSTALLATION_ID`, `PORT_CLIENT_ID`, `PORT_CLIENT_SECRET`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`, etc.).

2. Run a workflow with one of the provided payloads. For example:

```bash
act -W .github/workflows/create-repository.yml -e tests/payloads/create-repository.json --secret-file .secrets
```

Swap the workflow and payload paths to test other workflows.
