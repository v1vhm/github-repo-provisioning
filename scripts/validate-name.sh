#!/usr/bin/env bash
set -euo pipefail

ORG="$1"
NAME="$2"

if [[ ${#NAME} -lt 2 || ${#NAME} -gt 100 ]]; then
  echo "Invalid repository name length: $NAME" >&2
  exit 1
fi

if [[ ! "$NAME" =~ ^[a-z0-9-]+$ ]]; then
  echo "Repository name must be lowercase letters, numbers, or hyphens: $NAME" >&2
  exit 1
fi

if gh repo view "$ORG/$NAME" >/dev/null 2>&1; then
  echo "Repository $ORG/$NAME already exists" >&2
  exit 1
fi
