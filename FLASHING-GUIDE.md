# XR1710G Community Firmware Flashing Guide / XR1710G 社区固件刷机说明

## 中文：普通用户只看这里

Release 只保留 4 个必要文件：

| 文件 | 用途 | 什么时候用 |
|---|---|---|
| `xr1710g-uboot-yyh2913-260712-flash-slot.bin` | 已验证的 YYH2913 HTTP U-Boot | 设备尚无兼容 U-Boot 时，在 **Update U-Boot** 页面刷一次；已有相同版本可跳过 |
| `xr1710g-community-v1.1.0-sysupgrade.itb` | 唯一的系统固件 | OpenWrt/iStoreOS 后台升级，或 YYH2913 U-Boot 的 **Firmware + UBI 2.0 - 439 MiB** 页面安装 |
| `SHA256SUMS.txt` | 文件完整性校验 | 刷写前核对，不刷入路由器 |
| `FLASHING-GUIDE.md` | 本说明 | 先读，再选择刷机路径 |

### 路径 A：已运行兼容 OpenWrt/iStoreOS

在“备份/升级”页面上传 `xr1710g-community-v1.1.0-sysupgrade.itb`。跨发行版或排查旧配置问题时不要保留配置。

### 路径 B：YYH2913 HTTP U-Boot

1. 电脑设置为 `192.168.255.2/24`，进入 `http://192.168.255.1/`。
2. 选择 **Firmware**。
3. 布局选择 **UBI 2.0 - 439 MiB**。
4. 上传 `xr1710g-community-v1.1.0-sysupgrade.itb`。
5. 等待擦除、写入和重启完成，不要中途断电。

不要在正常安装中上传名为 `initramfs-recovery` 的开发调试镜像。本 Release 不向普通用户提供该文件。

### U-Boot 更新

只有设备尚无兼容 U-Boot 时，才在 **Update U-Boot** 页面刷 `xr1710g-uboot-yyh2913-260712-flash-slot.bin`。它不是系统固件。不要把系统 ITB、裸 `u-boot.bin` 或独立 FIT 刷进 U-Boot 槽位。

刷机前确认型号为 Gemtek XR1710G，并核对 SHA-256。首次启动管理地址为 `192.168.50.1`，用户名 `root`，初始密码为空；登录后立即设置密码。两台新刷设备不要同时接入同一网络，应逐台设置主路由和节点地址。

### 首次进入如何切换英文

首启界面默认简体中文。英文用户登录后进入 **系统 → 系统 → 语言和界面**，将语言改为 **English**，点击 **保存并应用**。

## English: short version

The Release contains only four required files:

| File | Purpose | When to use it |
|---|---|---|
| `xr1710g-uboot-yyh2913-260712-flash-slot.bin` | Validated YYH2913 HTTP U-Boot | Flash once from **Update U-Boot** only when a compatible U-Boot is not already installed |
| `xr1710g-community-v1.1.0-sysupgrade.itb` | The only system image | Use from compatible OpenWrt/iStoreOS, or from YYH2913 U-Boot with **Firmware + UBI 2.0 - 439 MiB** |
| `SHA256SUMS.txt` | Integrity checks | Verify before flashing; never flash this file |
| `FLASHING-GUIDE.md` | This guide | Read before choosing a path |

For a compatible running OpenWrt/iStoreOS system, upload the Sysupgrade image from the backup/upgrade page. Do not preserve settings when switching distributions or eliminating old configuration problems.

For YYH2913 HTTP U-Boot, open `http://192.168.255.1/`, select **Firmware**, select **UBI 2.0 - 439 MiB**, and upload `xr1710g-community-v1.1.0-sysupgrade.itb`. Do not power off while erasing, writing, or rebooting.

Do not use an `initramfs-recovery` development image for a normal installation. It is intentionally not included in this Release.

Update U-Boot only when required, using `xr1710g-uboot-yyh2913-260712-flash-slot.bin` on the **Update U-Boot** page. Never flash the system ITB, a raw `u-boot.bin`, or a standalone FIT into the U-Boot slot.

Confirm the device is a Gemtek XR1710G and verify the SHA-256 values. First boot uses `192.168.50.1`, user `root`, and an empty password; set an administrator password immediately. Configure two freshly flashed units one at a time to avoid duplicate addresses and DHCP servers.

The first boot UI is Simplified Chinese. Open **System → System → Language and Style**, select **English**, and click **Save & Apply**. Changing the UI language does not modify WAN, LAN, Wi-Fi, or Mesh settings.
