# Wiro U-Boot v2.0 for XR1710G / Wiro U-Boot v2.0（XR1710G 专用）

This branch (`uboot-2.0`) is the complete source tree of **Wiro U-Boot v2.0**, the
recovery-capable HTTP U-Boot for the **Gemtek XR1710G** (Airoha AN7581), shipped as
`xr1710g-wiro-uboot-v2.0-flash-slot.bin` together with community firmware v2.0
(tag `v2.0` in this repository).

本分支（`uboot-2.0`）是 **Wiro U-Boot v2.0** 的完整源码树——XR1710G 的 Recovery
HTTP U-Boot，随 v2.0 社区固件以 `xr1710g-wiro-uboot-v2.0-flash-slot.bin` 发布。

## Identity / 版本标识

- Version string: `U-Boot 2026.10-xr1710g-wiro-recovery 2.0+`
- Recovery web UI build: `xr1710g-wiro-recovery-2.0` (bottom of the recovery page)
- Environment schema: `XR1710G-WIRO` / schema `1` / generation `2026101101`
  (see `include/xr1710g-wiro-build.h`)

## Changes vs Wiro U-Boot v1.0.0 / 相对 v1.0.0 的变化

- Fixed the recovery-page HTTP upload failing when DHCP could not get an
  address. 修复 Recovery 页 HTTP 上传在 DHCP 获取地址失败时无法工作的问题。
- Honest Factory-rebuild progress: `write` completes at 95% with
  phase=FACTORY ("rebuilding Factory from read-only DSD…"), jumps to 100%
  only after `recovery_sync_and_verify_factory()` read-back passes, and shows
  the exact error code on failure instead of a silent fake completion.
  Factory 重建进度语义：write 完成 = 95% + FACTORY 阶段提示，回读校验通过才
  到 100%，失败显示具体错误码，不再假完成。
- Fixed the DSD `-EUCLEAN` false failure: bit-flip-corrected reads from the
  factory UBI volume are no longer treated as fatal. 修复 DSD 位翻转纠错
  （-EUCLEAN）被误判为致命错误导致的 Factory 重建假失败。
- Rebased onto the **U-Boot 2026.10** baseline with Airoha AN7581 support.

## Building / 构建

```sh
make xr1710g_defconfig
make -j"$(nproc)"
```

Outputs: `u-boot.bin` / `u-boot-dtb.bin` (1,022,984 bytes for the released
build). The published flash-slot image (`xr1710g-wiro-uboot-v2.0-flash-slot.bin`,
1,041,807 bytes) wraps the build with the chainloader-slot packaging inputs in
`package/` (`chainloader.its`, `chainloader-shim.bin`,
`chainloader-control.dtb`, `legacy-prefix.bin`) via `mkimage -f
package/chainloader.its`. 刷机槽位镜像由 `package/` 内的 chainloader 打包
输入经 mkimage 生成。

Flash it only into the U-Boot slot from the recovery page
(`192.168.255.1`, hold reset while powering on). Firmware v2.0 runs fine on
the previous Wiro U-Boot v1.0.0; updating U-Boot is optional. 刷写仅限
Recovery 页更新 U-Boot 槽位；固件 v2.0 在 v1.0.0 上同样可用，更新 U-Boot
为可选操作。

## Provenance and license / 来源与许可

Based on the Wiro http-uboot tree by Yanghan Ye (YYH2913), internal base
commit `53b73174c0fcb192a355e79710cdef5be61b14af`, ported to the U-Boot
2026.10 / AN7581 baseline. License: GPL-2.0-or-later per U-Boot plus each
bundled component's own license (see `Licenses/`). No device calibration
(Factory/EEPROM) data is included. 基于 Yanghan Ye（YYH2913）的 Wiro
http-uboot 树（内部基线提交 `53b73174`）移植到 U-Boot 2026.10 / AN7581
基线。许可遵循 U-Boot 的 GPL-2.0-or-later 及各组件自身许可；不含任何设备
校准（Factory/EEPROM）数据。
