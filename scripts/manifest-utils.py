#!/usr/bin/env python3
"""Utility functions for updating repository and team manifests."""
import os
import yaml

def _read(path):
    if os.path.exists(path):
        with open(path) as f:
            return yaml.safe_load(f) or {}
    return {}

def _write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        yaml.safe_dump(data, f, sort_keys=False)

def upsert_repo_team(repo_path, team_slug, permission, timestamp):
    """Add or update a team's permission on a repository manifest."""
    data = _read(repo_path)
    teams = data.setdefault("teams", [])
    for team in teams:
        if team.get("slug") == team_slug:
            if team.get("permission") == permission:
                return False
            team["permission"] = permission
            team["lastUpdatedAt"] = timestamp
            _write(repo_path, data)
            return True
    teams.append({"slug": team_slug, "permission": permission, "lastUpdatedAt": timestamp})
    _write(repo_path, data)
    return True

def remove_repo_team(repo_path, team_slug, timestamp):
    """Remove a team from a repository manifest."""
    data = _read(repo_path)
    teams = data.get("teams", [])
    new_teams = [t for t in teams if t.get("slug") != team_slug]
    if new_teams == teams:
        return False
    data["teams"] = new_teams
    _write(repo_path, data)
    return True

def upsert_team_repo(team_path, repo_name, permission, timestamp):
    """Add or update a repository on a team manifest."""
    data = _read(team_path)
    repos = data.setdefault("repositories", [])
    for repo in repos:
        if repo.get("name") == repo_name:
            if repo.get("permission") == permission:
                return False
            repo["permission"] = permission
            repo["lastUpdatedAt"] = timestamp
            _write(team_path, data)
            return True
    repos.append({"name": repo_name, "permission": permission, "lastUpdatedAt": timestamp})
    _write(team_path, data)
    return True

def remove_team_repo(team_path, repo_name, timestamp):
    """Remove a repository from a team manifest."""
    data = _read(team_path)
    repos = data.get("repositories", [])
    new_repos = [r for r in repos if r.get("name") != repo_name]
    if new_repos == repos:
        return False
    data["repositories"] = new_repos
    _write(team_path, data)
    return True

def upsert_repo_environment(repo_path, env_name, timestamp):
    """Add an environment to a repository manifest and touch lastUpdatedAt."""
    data = _read(repo_path)
    spec = data.setdefault("spec", {})
    envs = spec.setdefault("environments", [])
    if env_name in envs:
        return False
    envs.append(env_name)
    touch_last_updated(repo_path, timestamp, data)
    return True

def touch_last_updated(path, timestamp, data=None):
    """Update status.lastUpdatedAt on a manifest."""
    data = data if data is not None else _read(path)
    status = data.setdefault("status", {})
    status["lastUpdatedAt"] = timestamp
    _write(path, data)
    return True
