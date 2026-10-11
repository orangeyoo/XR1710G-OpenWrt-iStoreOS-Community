#!/usr/bin/env python3
"""Give each completed LuCI rootfs a deterministic static-resource namespace."""

import hashlib
import os
from pathlib import Path
import re
import sys


INPUTS = (
    'www/luci-static',
    'usr/share/ucode/luci',
    'usr/lib/lua/luci',
    'usr/share/luci',
)
MANIFEST = 'usr/share/luci-static-version'
ALIAS = re.compile(r'luci-static-[0-9a-f]{64}\Z')


def generate(root):
    root = Path(root)
    if not (root / 'www/luci-static').is_dir():
        return None

    digest = hashlib.sha256(b'luci-static-namespace-v1\0')
    for folder in INPUTS:
        base = root / folder
        if not base.is_dir():
            continue
        # Do not follow directory symlinks. Their targets are hashed as links;
        # ordinary assets and templates are hashed by content, never by mtime.
        for path in sorted(base.rglob('*')):
            if path.is_symlink():
                kind, content = b'L', os.readlink(path).encode()
            elif path.is_file():
                kind, content = b'F', path.read_bytes()
            else:
                continue
            name = path.relative_to(root).as_posix().encode()
            digest.update(kind + len(name).to_bytes(8, 'big') + name)
            digest.update(len(content).to_bytes(8, 'big') + content)

    version = digest.hexdigest()
    alias = root / 'www' / ('luci-static-' + version)
    if alias.exists() or alias.is_symlink():
        if not alias.is_symlink() or os.readlink(alias) != 'luci-static':
            raise RuntimeError('Refusing to replace non-generated path: ' + str(alias))
    else:
        # Sibling alias avoids a directory cycle and covers relative CSS/font URLs.
        alias.symlink_to('luci-static', target_is_directory=True)

    manifest = root / MANIFEST
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(version + '\n')

    # prepare_rootfs can run repeatedly for different image variants.
    for old in (root / 'www').iterdir():
        if (old != alias and ALIAS.fullmatch(old.name) and old.is_symlink()
                and os.readlink(old) == 'luci-static'):
            old.unlink()
    return version


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Usage: luci-static-version.py ROOTFS')
    version = generate(sys.argv[1])
    if version:
        print('LuCI static content version: ' + version)
