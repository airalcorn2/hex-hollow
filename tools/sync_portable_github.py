#!/usr/bin/env python3
"""Merge a saved Manus source version into the self-contained GitHub checkout.

Run from the managed project after saving a release. Only an existing, clean
checkout of airalcorn2/hex-hollow on main is accepted. No force pushes, deletions,
credential changes, or edits to the managed project are performed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

REPOSITORY = "github.com/airalcorn2/hex-hollow"
PORTABLE_IGNORE = "\n# Self-contained GitHub distribution: retain game media in Git.\n!/assets/**\n"


def git(directory: Path, *args: str, capture: bool = False) -> str:
    result = subprocess.run(
        ["git", "-C", str(directory), *args], check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else ""


def digest(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def load_assets(directory: Path) -> dict:
    return json.loads((directory / "assets.lock.json").read_text())["assets"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-dir", required=True, type=Path, help="Separate existing GitHub checkout")
    parser.add_argument("--push", action="store_true", help="Push the prepared commit to GitHub main")
    parser.add_argument("--message", default="Sync portable Hex Hollow source and all game assets")
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    target = args.repo_dir.resolve()
    if not target.is_dir() or source == target or source in target.parents or target in source.parents:
        raise ValueError("Use a separate existing checkout, outside the managed project")
    for directory in (source, target):
        if git(directory, "branch", "--show-current", capture=True) != "main":
            raise ValueError(f"Checkout must be on main: {directory}")
        if git(directory, "status", "--porcelain", capture=True):
            raise ValueError(f"Save or resolve local changes first: {directory}")
    remote = git(target, "remote", "get-url", "origin", capture=True)
    normalized = remote.removesuffix(".git").removeprefix("https://").removeprefix("git@").replace(":", "/")
    if normalized != REPOSITORY:
        raise ValueError("Target origin must be https://github.com/airalcorn2/hex-hollow.git")
    source_assets = load_assets(source)
    identity = [
        "-c", "user.name=" + git(source, "config", "user.name", capture=True),
        "-c", "user.email=" + git(source, "config", "user.email", capture=True),
    ]
    for relative, info in source_assets.items():
        path = source / relative
        if not relative.startswith("assets/") or ".." in Path(relative).parts or path.is_symlink():
            raise ValueError(f"Unsafe asset path: {relative}")
        if not path.is_file() or digest(path) != info["sha256"]:
            raise ValueError(f"Asset missing or changed since the saved release: {relative}")
    git(target, "fetch", "--no-tags", "origin", "main")
    git(target, *identity, "merge", "--ff-only", "origin/main")
    old_assets = load_assets(target)
    for relative, info in old_assets.items():
        path = target / relative
        if path.is_file() and digest(path) != info["sha256"]:
            raise ValueError(f"GitHub asset differs from its manifest; resolve it before syncing: {relative}")
    source_sha = git(source, "rev-parse", "HEAD", capture=True)
    # Fetch the saved source locally; do not copy credentials or change remotes.
    git(target, "fetch", "--no-tags", str(source), "main")
    git(target, *identity, "merge", "--no-edit", "FETCH_HEAD")
    # The saved source only versions asset metadata. Existing GitHub media is
    # retained by the merge, and current verified bytes are copied explicitly.
    for relative in source_assets:
        destination = target / relative
        if destination.is_symlink():
            raise ValueError(f"Refusing to overwrite a symlink: {relative}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / relative, destination)
    ignore_path = target / ".gitignore"
    ignore_text = ignore_path.read_text()
    if PORTABLE_IGNORE.strip() not in ignore_text:
        ignore_path.write_text(ignore_text.rstrip() + "\n" + PORTABLE_IGNORE)
    (target / ".portable-source.json").write_text(json.dumps({
        "sourceCommit": source_sha, "assetCount": len(source_assets),
        "description": "Saved source version included in this self-contained GitHub distribution",
    }, indent=2) + "\n")
    git(target, "add", "--", "assets", ".gitignore", ".portable-source.json")
    staged = git(target, "diff", "--cached", "--name-only", capture=True)
    if staged:
        git(target, *identity, "commit", "-m", args.message)
    tracked = set(git(target, "ls-files", "assets", capture=True).splitlines())
    for relative, info in source_assets.items():
        if relative not in tracked or digest(target / relative) != info["sha256"]:
            raise ValueError(f"Portable commit failed to retain the current asset: {relative}")
    sha = git(target, "rev-parse", "HEAD", capture=True)
    print(f"Portable version: {sha}; {len(source_assets)} verified assets; source: {source_sha}", flush=True)
    if args.push:
        git(target, "push", "origin", f"{sha}:refs/heads/main")
        print("Pushed the self-contained version to GitHub main.")
    else:
        print("Prepared locally; inspect and test before pushing.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Portable sync stopped: {error}", file=sys.stderr)
        sys.exit(1)
