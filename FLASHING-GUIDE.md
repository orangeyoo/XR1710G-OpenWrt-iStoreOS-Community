# XR1710G Community First Release Flashing Guide / 第一版刷机说明

## 中文：普通用户只看这里

Release 下载区保留 4 个刷写/校验文件，另附本说明：

| 文件 | 用途 | 什么时候用 |
|---|---|---|
| `xr1710g-uboot-first-release-flash-slot.bin` | U-Boot 引导程序，含大文件上传流控修复 | 只有在 U-Boot 的 Update U-Boot 页面刷一次；已有合适 U-Boot 可跳过 |
| `xr1710g-community-first-release-recovery.itb` | Recovery 系统镜像 | U-Boot Recovery 页面使用，适合新刷、救砖或需要完整恢复时使用 |
| `xr1710g-community-first-release-sysupgrade.itb` | 正常升级镜像 | 已经运行兼容 OpenWrt/iStoreOS 时使用，保留配置与否按页面选项决定 |
| `SHA256SUMS.txt` | 文件完整性校验 | 刷写前核对，不刷入路由器 |

最简单的选择：

1. 路由器已经能正常进入兼容 OpenWrt：只刷 `sysupgrade.itb`。
2. 路由器进入 U-Boot Recovery 页面：使用 `recovery.itb`。
3. 只有需要更新 U-Boot 时，才先刷 `uboot-first-release-flash-slot.bin`。它不是系统固件。

不要把两个系统镜像连续刷入，也不要把裸 `u-boot.bin` 刷入 U-Boot 槽位。刷写前确认设备型号是 Gemtek XR1710G，并核对 SHA256SUMS.txt。

## English: the short version

The Release contains four flashing/checksum files plus this short guide:

| File | Purpose | When to use it |
|---|---|---|
| `xr1710g-uboot-first-release-flash-slot.bin` | U-Boot bootloader with paced large-file uploads | Flash once from U-Boot's Update U-Boot page; skip if a suitable U-Boot is already installed |
| `xr1710g-community-first-release-recovery.itb` | Recovery system image | Use on the U-Boot Recovery page for a new install, recovery, or a full reinstall |
| `xr1710g-community-first-release-sysupgrade.itb` | Normal upgrade image | Use when compatible OpenWrt/iStoreOS is already running; choose whether to keep settings on the page |
| `SHA256SUMS.txt` | Integrity checks | Verify before flashing; never flash this file |

Use the shortest path:

1. A router already running compatible OpenWrt: flash only `sysupgrade.itb`.
2. A router at the U-Boot Recovery page: use `recovery.itb`.
3. Update U-Boot only when needed, using `uboot-first-release-flash-slot.bin` once. It is not a system image.

Do not flash both system images one after another. Do not flash a raw `u-boot.bin` into the U-Boot slot. Confirm the device is a Gemtek XR1710G and verify `SHA256SUMS.txt` first.

### 首次进入如何切换英文

首启界面默认是简体中文。英文用户登录 LuCI 后：

1. 打开左侧 **系统**。
2. 进入 **系统** 或 **系统属性** 页面。
3. 找到 **语言和界面**（Language and Style）。
4. 将 **语言** 改为 **English**。
5. 点击 **保存并应用**，刷新页面即可。

也可以在 LuCI 的 **System → System → Language and Style** 中完成同样操作。语言切换不会修改 WAN、LAN、Wi-Fi 或 Mesh 配置。

### Switching from Chinese to English

The first boot uses Simplified Chinese. After logging in to LuCI:

1. Open **System** in the left menu.
2. Open the **System** or **System Properties** page.
3. Find **Language and Style**.
4. Select **English** in the **Language** field.
5. Click **Save & Apply**, then refresh the page.

The same path is **System → System → Language and Style**. Changing the UI language does not change WAN, LAN, Wi-Fi, or Mesh settings.
