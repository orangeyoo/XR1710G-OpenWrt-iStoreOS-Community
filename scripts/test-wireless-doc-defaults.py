#!/usr/bin/env python3
"""Reject stale default claims, not explanations of opt-in EHT160 repairs."""
import pathlib
import re
import sys


def stale(text):
    return any(
        re.search(r"5\s*G(?:Hz)?", sentence, re.I)
        and re.search(r"default|默认|首次", sentence, re.I)
        and re.search(r"EHT160|30\s*dBm", sentence, re.I)
        for sentence in re.split(r"[\n。！？]|(?<!\d)\.(?:\s|$)", text)
    )


assert stale("5GHz default: EHT160")
assert stale("5GHz首次请求30dBm")
assert not stale("修复5GHz EHT160启动失败。默认仍EHT80。")
assert not stale("Fix 5GHz EHT160 startup. The default remains EHT80.")
for path in sys.argv[1:]:
    if stale(pathlib.Path(path).read_text(encoding="utf-8")):
        print("Stale default claim:", path)
        sys.exit(1)
print("WIRELESS DEFAULT DOCUMENTATION TEST PASSED")
