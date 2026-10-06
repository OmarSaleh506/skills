#!/usr/bin/env bash
# branch-guard — PreToolUse hook (matcher: Bash)
#
# Before Claude runs a shell command, blocks:
#   1. force pushes (--force, -f, +refspec). --force-with-lease is allowed.
#   2. pushes that target a protected branch (explicit refspec, or a bare
#      `git push` / `git push origin HEAD` while on one).
#   3. commits made while a protected branch is checked out.
# and, for any other push, runs the project's local checks first so a red CI
# run is caught before it leaves the machine:
#   `make check` | npm scripts "lint"/"typecheck" | `ruff check` + `ruff format --check`
#
# Contract (https://code.claude.com/docs/en/hooks):
#   exit 0 : allow      exit 2 : block — stderr is shown to Claude as the reason
#
# Edit PROTECTED below to match your branching model. Fails open (allows) if
# python3 is missing or the input can't be parsed.

command -v python3 >/dev/null 2>&1 || exit 0

HOOK_INPUT=$(cat) python3 - <<'PY'
import json
import os
import re
import shlex
import shutil
import subprocess
import sys

PROTECTED = {"main", "master", "develop", "staging", "production"}
CHECK_TIMEOUT_SECONDS = 540  # stays under Claude Code's 600 s hook timeout
TAIL_LINES = 40
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}


def block(message):
    print(f"branch-guard: {message}", file=sys.stderr)
    sys.exit(2)


def git_invocations(command):
    """Yield (repo_dir_or_None, subcommand, args) for each `git` call in a command line."""
    for segment in re.split(r"&&|\|\||[;|\n&]", command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        names = [os.path.basename(t) for t in tokens]
        if "git" not in names:
            continue
        rest = tokens[names.index("git") + 1:]
        repo_dir = None
        while rest and rest[0].startswith("-"):
            opt = rest.pop(0)
            if opt in GIT_OPTS_WITH_VALUE and rest:
                value = rest.pop(0)
                if opt == "-C":
                    repo_dir = value
        if rest:
            yield repo_dir, rest[0], rest[1:]


def current_branch(repo_dir):
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=repo_dir, capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.stdout.strip() if out.returncode == 0 else ""


def is_force(args):
    for arg in args:
        if arg in ("--force", "--mirror"):
            return True
        if re.fullmatch(r"-[a-zA-Z]*f[a-zA-Z]*", arg):
            return True
    positionals = [a for a in args if not a.startswith("-")]
    return any(ref.startswith("+") for ref in positionals[1:])


def pushed_branches(args, repo_dir):
    """Destination branch names of a push; the current branch if none are named."""
    positionals = [a for a in args if not a.startswith("-")]
    refspecs = positionals[1:]
    if not refspecs:
        return [current_branch(repo_dir)]
    branches = []
    for ref in refspecs:
        dest = ref.lstrip("+").split(":")[-1]
        dest = dest[len("refs/heads/"):] if dest.startswith("refs/heads/") else dest
        branches.append(current_branch(repo_dir) if dest == "HEAD" else dest)
    return branches


def check_command(root):
    """The project's local check command as a shell string, or None."""
    makefile = os.path.join(root, "Makefile")
    if os.path.isfile(makefile):
        with open(makefile, encoding="utf-8", errors="replace") as fh:
            if re.search(r"^check:", fh.read(), re.MULTILINE):
                return "make check"
    package_json = os.path.join(root, "package.json")
    if os.path.isfile(package_json):
        try:
            with open(package_json, encoding="utf-8") as fh:
                scripts = json.load(fh).get("scripts") or {}
        except (OSError, ValueError):
            scripts = {}
        present = [name for name in ("lint", "typecheck") if name in scripts]
        if present:
            return " && ".join(f"npm run --silent {name}" for name in present)
        return None
    if os.path.isfile(os.path.join(root, "pyproject.toml")) and shutil.which("ruff"):
        return "ruff check . && ruff format --check ."
    return None


def run_checks(root):
    cmd = check_command(root)
    if not cmd:
        return
    try:
        result = subprocess.run(
            cmd, shell=True, cwd=root, capture_output=True, text=True,
            timeout=CHECK_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        block(f"pre-push checks (`{cmd}`) timed out after {CHECK_TIMEOUT_SECONDS}s.")
    if result.returncode != 0:
        tail = "\n".join((result.stdout + result.stderr).strip().splitlines()[-TAIL_LINES:])
        block(f"pre-push checks failed (`{cmd}`). Fix these before pushing:\n{tail}")


try:
    data = json.loads(os.environ.get("HOOK_INPUT", ""))
except ValueError:
    sys.exit(0)

command = (data.get("tool_input") or {}).get("command") or ""
cwd = data.get("cwd") or os.getcwd()
project_root = os.environ.get("CLAUDE_PROJECT_DIR") or cwd
pushes = []

for repo_dir, sub, args in git_invocations(command):
    repo = os.path.join(cwd, repo_dir) if repo_dir else cwd
    if sub == "commit":
        branch = current_branch(repo)
        if branch in PROTECTED:
            block(f"blocked commit directly on '{branch}'. Create a feature branch first "
                  "(git switch -c feat/your-change).")
    elif sub == "push":
        if is_force(args):
            block("blocked force push. Use --force-with-lease only if you really need to "
                  "rewrite remote history, and explain why to the user.")
        for branch in pushed_branches(args, repo):
            if branch in PROTECTED:
                block(f"blocked direct push to '{branch}'. Push a feature branch and open a PR instead.")
        pushes.append(repo)

if pushes:
    run_checks(project_root)

sys.exit(0)
PY
