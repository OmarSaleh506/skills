"""Enforce the repo rules in CLAUDE.md: every shipped skill is listed in both
manifests, has valid frontmatter, and has a README row linked to its SKILL.md."""

import json
import logging
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILL_LINE_LIMIT = 500

log = logging.getLogger("validate_skills")


def load_json(rel_path):
    return json.loads((ROOT / rel_path).read_text())


def frontmatter(skill_md):
    match = re.match(r"^---\n(.*?)\n---\n", skill_md.read_text(), re.DOTALL)
    return match.group(1) if match else None


def check_manifests(errors):
    plugin_skills = load_json(".claude-plugin/plugin.json")["skills"]
    marketplace = load_json(".claude-plugin/marketplace.json")
    market_skills = marketplace["plugins"][0]["skills"]
    if sorted(plugin_skills) != sorted(market_skills):
        errors.append(f"skills differ: plugin.json={plugin_skills} marketplace.json={market_skills}")
    on_disk = sorted(f"./skills/{p.parent.name}" for p in ROOT.glob("skills/*/SKILL.md"))
    if sorted(plugin_skills) != on_disk:
        errors.append(f"plugin.json skills {sorted(plugin_skills)} != skills on disk {on_disk}")
    return on_disk


def check_skill(skill_path, readme, errors):
    name = skill_path.removeprefix("./skills/")
    skill_md = ROOT / "skills" / name / "SKILL.md"
    fm = frontmatter(skill_md)
    if fm is None:
        errors.append(f"{name}: SKILL.md has no frontmatter block")
        return
    if not re.search(rf"^name:\s*{re.escape(name)}\s*$", fm, re.MULTILINE):
        errors.append(f"{name}: frontmatter name must equal folder name")
    if not re.search(r"^description:", fm, re.MULTILINE):
        errors.append(f"{name}: frontmatter has no description")
    if f"(./skills/{name}/SKILL.md)" not in readme:
        errors.append(f"{name}: no README row linking ./skills/{name}/SKILL.md")
    line_count = len(skill_md.read_text().splitlines())
    if line_count > SKILL_LINE_LIMIT:
        errors.append(f"{name}: SKILL.md is {line_count} lines (limit {SKILL_LINE_LIMIT}); move detail to references/")


def main():
    errors = []
    readme = (ROOT / "README.md").read_text()
    for skill_path in check_manifests(errors):
        check_skill(skill_path, readme, errors)
    for error in errors:
        log.error(error)
    if errors:
        return 1
    log.info("All skills valid.")
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    sys.exit(main())
