#!/usr/bin/env python3
"""
Assemble the self-contained, offline, plain-language companion HTML.

You (the model) write ONLY a body *fragment* — the <header>, <section>s, and
<footer>, with Mermaid diagrams as `<pre class="mermaid">...</pre>` blocks. This
script wraps that fragment in the bundled CSS shell and inlines the pinned Mermaid
bundle, producing one ~3.3MB file that opens by double-click with no network.

Why a script instead of writing the HTML directly: the Mermaid bundle is ~3.3MB
of minified JS — far too large to emit by hand. Inlining it is a hard requirement
(the file must work fully offline), so assembly is delegated here.

Usage:
    python3 build_html.py \
        --content body.html \
        --output /path/to/repo/docs/system-flow.html \
        --title "How <Project> Works, In Plain Language"

Defaults: --shell and --mermaid resolve to the skill's assets/ next to this script.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(HERE, "..", "assets"))


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def main():
    ap = argparse.ArgumentParser(description="Assemble offline Mermaid HTML companion.")
    ap.add_argument("--content", required=True, help="Path to the body fragment HTML.")
    ap.add_argument("--output", required=True, help="Path to write the final HTML.")
    ap.add_argument("--title", default="How the System Works, In Plain Language",
                    help="Document <title> (also keep an <h1> inside --content).")
    ap.add_argument("--shell", default=os.path.join(ASSETS, "html-shell.html"))
    ap.add_argument("--mermaid", default=os.path.join(ASSETS, "mermaid.min.js"))
    args = ap.parse_args()

    # Expand ~ in case any path is given relative to the home directory.
    args.content = os.path.expanduser(args.content)
    args.output = os.path.expanduser(args.output)
    args.shell = os.path.expanduser(args.shell)
    args.mermaid = os.path.expanduser(args.mermaid)

    for label, path in (("shell", args.shell), ("mermaid", args.mermaid),
                        ("content", args.content)):
        if not os.path.isfile(path):
            sys.exit(f"ERROR: {label} file not found: {path}")

    shell = read(args.shell)
    content = read(args.content)
    mermaid = read(args.mermaid)

    for token in ("__TITLE__", "__CONTENT__", "__MERMAID_JS__"):
        if token not in shell:
            sys.exit(f"ERROR: shell is missing required placeholder {token}")

    # Literal replacement (not regex) — the Mermaid blob contains many regex-special
    # characters; str.replace treats both arguments as plain text.
    html = (shell
            .replace("__TITLE__", args.title)
            .replace("__CONTENT__", content)
            .replace("__MERMAID_JS__", mermaid))

    out_dir = os.path.dirname(os.path.abspath(args.output))
    os.makedirs(out_dir, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(html)

    size_mb = os.path.getsize(args.output) / (1024 * 1024)
    n_diagrams = content.count('class="mermaid"')
    print(f"Wrote {args.output} ({size_mb:.2f} MB, {n_diagrams} Mermaid diagram(s)).")
    if n_diagrams == 0:
        print("WARNING: no `<pre class=\"mermaid\">` blocks found in --content.")


if __name__ == "__main__":
    main()
