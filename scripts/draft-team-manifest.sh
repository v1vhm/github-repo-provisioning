#!/usr/bin/env bash
# draft-team-manifest.sh
# Usage: draft-team-manifest.sh <team_slug> <team_name> <created_at> <requested_by> <description> <privacy> <parent_team_slug> <members_block> <aliases_block>
# Writes manifest to teams/manifests/<team_slug>.yaml

set -euo pipefail

TEAM_SLUG="$1"
TEAM_NAME="$2"
CREATED_AT="$3"
REQUESTED_BY="$4"
DESCRIPTION="$5"
PRIVACY="$6"
PARENT_TEAM_SLUG="$7"
MEMBERS_BLOCK="$8"
ALIASES_BLOCK="$9"

MANIFEST_PATH="teams/manifests/${TEAM_SLUG}.yaml"

cat > "$MANIFEST_PATH" <<MANIFEST
apiVersion: v1
kind: GitHubTeam
metadata:
  name: "$TEAM_NAME"
  slug: "$TEAM_SLUG"
  createdAt: "$CREATED_AT"
  createdBy: "$REQUESTED_BY"
spec:
  description: "$DESCRIPTION"
  privacy: "$PRIVACY"
  parent:
    slug: "${PARENT_TEAM_SLUG:-null}"
  members:
$MEMBERS_BLOCK
  aliases:
$ALIASES_BLOCK
status:
  phase: creating
MANIFEST

echo "MANIFEST=$MANIFEST_PATH" >> "$GITHUB_ENV"
