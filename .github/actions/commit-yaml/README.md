# commit-yaml

Composite action to commit YAML manifest changes to the repository.

## Inputs
- `path` – File or directory path to commit
- `message` – Commit message

The action stages the provided path, creates a commit on `main`, and pushes it.
