#!/bin/bash
# diy-part1 — 版本号补丁，all distros 共用
# 在 scripts/feeds update 之前运行

date_version=$(date +"%Y%m%d%H")
[ -f version ] && sed -i "s/0000000000/${date_version}/g" version || true