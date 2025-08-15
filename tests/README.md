# Tests

Sample payloads in this directory mimic the JSON that Port sends to
`workflow_dispatch` triggers. They allow contributors to exercise the
workflows locally and verify parsing logic without needing a real Port
run.

## Running workflows with `act`

1. Create a `.secrets` file in the repository root with the secrets
   required by the workflows (e.g. `GH_APP_ID`,
   `GH_APP_PRIVATE_KEY`, `GH_APP_INSTALLATION_ID`, `PORT_CLIENT_ID`,
   `PORT_CLIENT_SECRET`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
   `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`,
   `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`, etc.).

2. Run a workflow with one of the payloads. For example:

   ```bash
   act -W .github/workflows/create-repository.yml \
       -e tests/payloads/create-repository.json \
       --secret-file .secrets
   ```

3. To execute a "mock" run that skips external calls, append
   `--dryrun`:

   ```bash
   act --dryrun -W .github/workflows/create-repository.yml \
       -e tests/payloads/create-repository.json \
       --secret-file .secrets
   ```

Swap the workflow and payload paths to test other workflows.

## Local CI checks

Continuous integration runs [actionlint](https://github.com/rhysd/actionlint),
[`tflint`](https://github.com/terraform-linters/tflint),
and `terraform validate`. Run the same checks locally before committing:

```bash
actionlint
terraform -chdir=repositories/modules/repo init -backend=false
terraform -chdir=repositories/modules/repo validate
tflint --chdir repositories/modules/repo
terraform -chdir=teams/modules/team init -backend=false
terraform -chdir=teams/modules/team validate
tflint --chdir teams/modules/team
```

Consult the repository's `AGENTS.md` for additional contributor
guidelines.

