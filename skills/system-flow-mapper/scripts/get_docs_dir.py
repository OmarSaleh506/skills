#!/usr/bin/env python3
"""
Return the system-flow docs directory for a repository: <repo_root>/docs/system-flow/

Usage:
    python3 get_docs_dir.py [repo_root]   # prints the docs-dir path, no newline

repo_root defaults to the current working directory.

The deliverables (SYSTEM_FLOW.md, the two HTML companions, and state.json) are
written here, inside the analyzed project, so they persist between runs — the
"update, don't recreate" incremental flow needs state.json to survive — and the
path is agent-agnostic. The skill should offer to add docs/system-flow/ to
.gitignore if the user doesn't want the generated files committed.
"""
import argparse
import os


def get_docs_dir(repo_root: str) -> str:
    return os.path.join(os.path.realpath(repo_root), "docs", "system-flow") + os.sep


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Print the system-flow docs dir (<repo>/docs/system-flow/) for a repo."
    )
    ap.add_argument(
        "repo_root",
        nargs="?",
        default=os.getcwd(),
        help="Path to the repo root (default: cwd).",
    )
    args = ap.parse_args()
    print(get_docs_dir(args.repo_root), end="")


if __name__ == "__main__":
    main()
