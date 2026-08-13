#!/usr/bin/env python3
"""Normalize QuickStart physical-link state and hide internal interfaces."""

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

# The iStoreX home card consumes the generic port-list API, which also returns
# the CPU-facing eth0 link and MT7996 AP/Mesh virtual interfaces.  Those are
# useful to diagnostics, but they are not external jacks.  Keep the backend
# complete and filter only this ordinary home-card renderer.
old_port_list = "y.portList=C.ports||[]"
new_port_list = (
    'y.portList=(C.ports||[]).filter(x=>'
    '["wan","lan1","lan2","lan3"].includes(x.name))'
)
if old_port_list in text:
    if text.count(old_port_list) != 1:
        raise SystemExit("QuickStart home port-list anchor is ambiguous")
    text = text.replace(old_port_list, new_port_list, 1)
elif text.count(new_port_list) != 1:
    raise SystemExit("QuickStart home port-list has unreviewed upstream structure")

if old_port_list in text or text.count(new_port_list) != 1:
    raise SystemExit("QuickStart external-port filter is incomplete")

# The visible "Network interface status" card has a separate state object.
# Filter its rendered list while leaving v.value complete for the dedicated
# interface configuration page and its selection menu.
old_status_list = "d.portList=_.ports||[],v.value=_.ports||[]"
new_status_list = (
    'd.portList=(_.ports||[]).filter(x=>'
    '["wan","lan1","lan2","lan3"].includes(x.name)),'
    'v.value=_.ports||[]'
)
if old_status_list in text:
    if text.count(old_status_list) != 1:
        raise SystemExit("QuickStart status-card port-list anchor is ambiguous")
    text = text.replace(old_status_list, new_status_list, 1)
elif text.count(new_status_list) != 1:
    raise SystemExit("QuickStart status-card port-list has unreviewed structure")

if old_status_list in text or text.count(new_status_list) != 1:
    raise SystemExit("QuickStart status-card external-port filter is incomplete")

with path.open("w", newline="") as stream:
    stream.write(text)

if len(sys.argv) == 3:
    template = Path(sys.argv[2])
    page = template.read_text()
    old_assets = (
        'index.js?v=0.12.8-r1',
        'index.js<%# ?v=PKG_VERSION %>',
    )
    new_asset = 'index.js?v=xr-portfilter2'
    if new_asset not in page:
        old_assets += ('index.js?v=xr-linkstate1', 'index.js?v=xr-portfilter1')
        matches = [anchor for anchor in old_assets if page.count(anchor) == 1]
        if len(matches) != 1:
            raise SystemExit("QuickStart asset-version anchor is unreviewed")
        page = page.replace(matches[0], new_asset, 1)
    if page.count(new_asset) != 1:
        raise SystemExit("QuickStart asset cache-busting incomplete")
    with template.open("w", newline="") as stream:
        stream.write(page)
