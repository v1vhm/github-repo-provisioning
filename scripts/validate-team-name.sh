#!/usr/bin/env bash
set -euo pipefail

ORG="$1"
SLUG="$2"

if [[ ${#SLUG} -lt 2 || ${#SLUG} -gt 64 ]]; then
  echo "Invalid team slug length: $SLUG" >&2
  exit 1
fi

if [[ ! "$SLUG" =~ ^[a-z0-9-]+$ ]]; then
  echo "Team slug must be lowercase letters, numbers, or hyphens: $SLUG" >&2
  exit 1
fi

if gh api "orgs/$ORG/teams/$SLUG" >/dev/null 2>&1; then
  echo "Team $ORG/$SLUG already exists" >&2
  exit 1
fi
