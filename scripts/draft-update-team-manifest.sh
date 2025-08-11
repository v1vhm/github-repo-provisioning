#!/usr/bin/env bash
# draft-update-team-manifest.sh
# Usage: draft-update-team-manifest.sh <team_slug> <team_name> <existing_created_at> <existing_created_by> <description> <privacy> <parent_team_slug> <members_block> <aliases_block> <team_id> <html_url>
# Writes manifest to teams/manifests/<team_slug>.yaml

set -euo pipefail

TEAM_SLUG="$1"
TEAM_NAME="$2"
EXISTING_CREATED_AT="$3"
EXISTING_CREATED_BY="$4"
DESCRIPTION="$5"
PRIVACY="$6"
PARENT_TEAM_SLUG="$7"
MEMBERS_BLOCK="$8"
ALIASES_BLOCK="$9"
TEAM_ID="${10}"
HTML_URL="${11}"

MANIFEST_PATH="teams/manifests/${TEAM_SLUG}.yaml"

cat > "$MANIFEST_PATH" <<MANIFEST
apiVersion: v1
kind: GitHubTeam
metadata:
  name: "$TEAM_NAME"
  slug: "$TEAM_SLUG"
$(if [ -n "$EXISTING_CREATED_AT" ]; then echo "  createdAt: \"$EXISTING_CREATED_AT\""; fi)
$(if [ -n "$EXISTING_CREATED_BY" ]; then echo "  createdBy: \"$EXISTING_CREATED_BY\""; fi)
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
  id: "$TEAM_ID"
  htmlUrl: "$HTML_URL"
  phase: active
  lastUpdatedAt: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
MANIFEST

echo "MANIFEST=$MANIFEST_PATH" >> "$GITHUB_ENV"
