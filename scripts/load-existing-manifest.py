#!/usr/bin/env python3
# load-existing-manifest.py
# Usage: load-existing-manifest.py <manifest_path>
# Prints environment variable assignments for GitHub Actions

import os
import sys
import json
import yaml

if len(sys.argv) != 2:
    print("Usage: load-existing-manifest.py <manifest_path>", file=sys.stderr)
    sys.exit(1)

manifest_path = sys.argv[1]

with open(manifest_path) as f:
    data = yaml.safe_load(f)

print(f"EXISTING_CREATED_AT={data.get('metadata', {}).get('createdAt', '')}")
print(f"EXISTING_CREATED_BY={data.get('metadata', {}).get('createdBy', '')}")
print(f"EXISTING_ALIASES={json.dumps(data.get('spec', {}).get('aliases', []))}")
print(f"EXISTING_ID={data.get('status', {}).get('id', '')}")
print(f"EXISTING_HTML_URL={data.get('status', {}).get('htmlUrl', '')}")
