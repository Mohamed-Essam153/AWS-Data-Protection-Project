#!/usr/bin/env python3
"""Check every link in the repo's markdown files.

    python3 tools/check_links.py              # relative links + #anchors-free paths
    python3 tools/check_links.py --external   # also request each http(s) link

Exit code 1 if anything is broken.
"""
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)\)|\!\[[^\]]*\]\(([^)\s]+)\)")
SKIP_DIRS = {".git", "node_modules", "data", "build", ".pytest_cache"}


def markdown_files():
    for path in ROOT.rglob("*.md"):
        if not SKIP_DIRS.intersection(path.relative_to(ROOT).parts):
            yield path


def strip_code(text):
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    return re.sub(r"`[^`]*`", "", text)


def check_external(url):
    req = urllib.request.Request(url, method="GET", headers={"User-Agent": "dp-lab-link-check"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status < 400, resp.status
    except urllib.error.HTTPError as err:
        return err.code < 400, err.code
    except Exception as err:  # noqa: BLE001 - report anything else as broken
        return False, type(err).__name__


def main():
    external = "--external" in sys.argv
    broken, checked, seen = [], 0, {}
    for md in markdown_files():
        for m in LINK.finditer(strip_code(md.read_text(encoding="utf-8"))):
            target = m.group(1) or m.group(2)
            checked += 1
            if target.startswith(("http://", "https://")):
                if external:
                    if target not in seen:
                        seen[target] = check_external(target)
                    ok, status = seen[target]
                    if not ok:
                        broken.append((md, target, status))
                continue
            if target.startswith(("mailto:", "#")):
                continue
            path = (md.parent / target.split("#")[0]).resolve()
            if not path.exists():
                broken.append((md, target, "missing"))
    for md, target, why in broken:
        print(f"BROKEN  {md.relative_to(ROOT)} -> {target} ({why})")
    print(f"{checked} links checked, {len(broken)} broken" + ("" if external else " (external links not requested)"))
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
