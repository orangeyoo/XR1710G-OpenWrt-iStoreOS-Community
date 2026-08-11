#!/usr/bin/env python3
"""Normalize every non-UP QuickStart link state as physically disconnected."""

from pathlib import Path
import sys


if len(sys.argv) not in (2, 3):
    raise SystemExit(
        f"usage: {sys.argv[0]} PATH-TO-quickstart-index.js [PATH-TO-main.htm]"
    )

path = Path(sys.argv[1])
text = path.read_text()
old = '.linkState=="DOWN"'
new = '.linkState!=="UP"'

# The backend already returns LOWERLAYERDOWN for carrier-less Ethernet ports.
# The upstream UI only recognizes literal DOWN, so it paints every other state
# green and may display a stale speed. Fix the shared renderer, not one port.
if old in text:
    count = text.count(old)
    if count != 5:
        raise SystemExit(f"QuickStart link-state anchors: expected 5, found {count}")
    text = text.replace(old, new)
elif text.count(new) != 5:
    raise SystemExit("QuickStart link-state renderer has unreviewed upstream structure")

if old in text or text.count(new) != 5:
    raise SystemExit("QuickStart link-state normalization incomplete")

with path.open("w", newline="\n") as stream:
    stream.write(text)

if len(sys.argv) == 3:
    template = Path(sys.argv[2])
    page = template.read_text()
    old_assets = (
        'index.js?v=0.12.8-r1',
        'index.js<%# ?v=PKG_VERSION %>',
    )
    new_asset = 'index.js?v=xr-linkstate1'
    if new_asset not in page:
        matches = [anchor for anchor in old_assets if page.count(anchor) == 1]
        if len(matches) != 1:
            raise SystemExit("QuickStart asset-version anchor is unreviewed")
        page = page.replace(matches[0], new_asset, 1)
    if page.count(new_asset) != 1:
        raise SystemExit("QuickStart asset cache-busting incomplete")
    with template.open("w", newline="\n") as stream:
        stream.write(page)
