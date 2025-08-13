# Provisioning configuration

This directory documents secrets referenced by `.provisioning/repository-config.yml` when new repositories are created from a template.

## Config secret sources

| ref             | source          |
|-----------------|-----------------|
| ORG_CLOUD_KV_URI | workflow_secret |

`workflow_secret` values come from GitHub Action secrets, while `env` indicates the value is read from an environment variable with the same name.
