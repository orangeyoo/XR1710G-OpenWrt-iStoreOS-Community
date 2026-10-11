# XR1710G v2.0 firmware source tree / v2.0 固件完整源码

This branch (`source-2.0`) contains the complete OpenWrt / iStoreOS build tree that
produced community firmware v2.0 (`2.0 r0+4-b80dbec681`, image
`istoreos-xr1710g-community-2.0-r0+4-b80dbec681-airoha-an7581-econet_xr1710g-ubi-*`).

本分支（`source-2.0`）是社区固件 v2.0（`2.0 r0+4-b80dbec681`）的完整 OpenWrt / iStoreOS
构建源码树，与发布的 sysupgrade / recovery 镜像对应。

## What this tree is / 关于本树

- Base: integration commit `99598e539d` ("airoha: enable Simplified Chinese LuCI for
  XR1710G"); the single commit on top carries the complete device work as one
  reviewable state. 基线为整合提交 `99598e539d`，其上的单个快照提交以可审阅的方式
  携带全部设备适配工作。
- Linux 6.18.53 on the OpenWrt Airoha (AN7581) platform with the XR1710G BSP patch
  set in `target/linux/airoha/patches-6.18/`: the SOE/PPE hardware-offload stack
  (`9999-01`…`9999-12`), LRO queue remap (`9999-16`), buffered DSA/GDM4 forwarding
  (`9999-24`/`9999-25`), backpressure (`9999-26`), flow-route fixes (`9999-27`/
  `9999-28`), WAN LRO IRQ coverage (`9999-30`), PPE L4 stale-slot guard (`9999-31`)
  and the PPPoE PPE-offload MAC-check skip (`9999-32`).
- mt76 / MT7996 NPU RX/TX stack rebased on the AN7581 NPU work
  (`package/kernel/mt76/patches/0100`…`0114`).
- fullcone NAT for firewall4/nftables, XR1710G wireless and firewall factory
  defaults (2.4G EHT20, 5G/6G EHT160, US regulatory), Simplified-Chinese LuCI and
  the `luci-app-airoha-npu` / `luci-app-airoha-flowsense` /
  `luci-app-airoha-fancontrol` / `luci-app-xr1710g-recovery` apps plus
  `xr1710g-status-core`.
- The firmware version suffix is generated from the git state at build time: the
  released images were built from this exact content while it carried three
  additional commits, so a rebuild from this single-commit branch reports a
  different `-rX+N-hash` suffix while producing the same content. 版本后缀由构建时
  的 git 状态生成：发布镜像构建时这些内容还带着三个额外提交，因此从本单提交分支
  重建会得到不同的 `-rX+N-hash` 后缀，但内容一致。

## Building / 构建

Standard OpenWrt flow; the build seed is included:

    cp xr1710g-2.0.seed.config .config
    make defconfig
    make -j"$(nproc)" download world v -s

Images land in `bin/targets/airoha/an7581/`
(`...ubi-squashfs-sysupgrade.itb`, `...ubi-initramfs-recovery.itb`).

Community documentation, flashing guide and release notes live on the repository
default branch `public-first-release`. 社区文档、刷机指南与发布说明在仓库默认分支
`public-first-release`。U-Boot sources are not part of this tree（U-Boot 不在本树内）.

## License / 许可

Same as OpenWrt / iStoreOS and each upstream component; no vendor calibration
(Factory/EEPROM) data is included. 许可遵循 OpenWrt / iStoreOS 及各上游组件；不包含
任何原厂校准（Factory/EEPROM）数据。
