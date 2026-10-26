#!/usr/bin/env python3
"""Validate source/documentation checks that do not require WSL or a board."""

import ast
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "README.md", "LICENSE", "CHANGELOG.md", "CONTRIBUTING.md", "SECURITY.md",
    "CODE_OF_CONDUCT.md", "AGENTS.md", "mp_skill.md", "docs/ARCHITECTURE.md",
    "docs/ROADMAP.md", "docs/DEVELOPMENT.md", "docs/HARDWARE_MATRIX.md",
)


def main():
    errors = []
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            errors.append("Missing required file: " + relative)

    python_files = sorted((ROOT / "scripts").rglob("*.py"))
    for path in python_files:
        try:
            ast.parse(path.read_bytes(), filename=str(path.relative_to(ROOT)))
        except SyntaxError as error:
            errors.append(str(error))

    documents = [ROOT / "README.md", ROOT / "AGENTS.md"]
    documents += sorted((ROOT / "docs").rglob("*.md"))
    documents += sorted((ROOT / "agents").rglob("*.md"))
    link_count = 0
    for path in documents:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        if "\t" in text:
            errors.append(str(path.relative_to(ROOT)) + ": tab character in Markdown")
        # Examples inside fenced code blocks are not documentation links.
        text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
        for match in re.finditer(r"\]\(([^\s)]+)", text):
            raw = match.group(1).strip("<>")
            parsed = urlsplit(raw)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            target = unquote(parsed.path)
            resolved = ((ROOT / target.lstrip("/")) if target.startswith("/")
                        else (path.parent / target)).resolve()
            link_count += 1
            if not resolved.exists():
                errors.append(str(path.relative_to(ROOT)) + ": missing link target " + raw)

    if errors:
        for error in errors:
            print("ERROR: " + error, file=sys.stderr)
        return 1
    print("PASS: {} required files, {} Python files, {} Markdown files, {} local links".format(
        len(REQUIRED), len(python_files), len(documents), link_count))
    print("Scope: repository integrity and syntax only; firmware and hardware are not exercised.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
