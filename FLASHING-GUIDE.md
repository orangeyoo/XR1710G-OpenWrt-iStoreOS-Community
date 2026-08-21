# XR1710G v1.4.0 Flashing Guide / XR1710G v1.4.0 刷机说明

## 中文

### Release 文件

Release 只保留以下必要文件：

| 文件 | 用途 | 是否刷入 |
|---|---|---|
| `xr1710g-community-v1.4.0-sysupgrade.itb` | 后台升级及兼容 HTTP U-Boot 的永久系统安装；普通用户优先使用 | 是 |
| `xr1710g-community-v1.4.0-recovery.itb` | 临时救援、恢复或诊断，不代替永久系统安装 | 仅在救援流程明确要求时临时使用 |
| `xr1710g-uboot-flash-slot.bin` | 基于 YYH2913 HTTP U-Boot 的实机验证兼容版，加入大文件上传节流与安全中断处理 | 只有需要更新 U-Boot 时才刷 |
| `SHA256SUMS.txt` | 校验下载文件是否完整 | 否 |
| `FLASHING-GUIDE.md` | 本说明 | 否 |

### 刷机前

1. 确认设备型号为 **Gemtek XR1710G**。
2. 使用 `SHA256SUMS.txt` 核对准备刷写的文件。
3. 备份需要保留的设置。跨发行版升级或排查旧配置问题时，不要保留旧配置。
4. 只连接当前目标设备，保证供电稳定，刷写过程中不要断电。
5. 不要修改或复制其他设备的 Factory、EEPROM、caldata、MAC 或无线校准数据。

### 路径 A：已运行兼容 OpenWrt/iStoreOS

1. 打开 **系统 → 备份/升级**。
2. 上传 `xr1710g-community-v1.4.0-sysupgrade.itb`。
3. 确认文件和目标设备无误后开始升级。
4. 等待写入和重启完成，不要断电。

这是正常后台升级的优先路径。不要把 Recovery 镜像或 U-Boot 文件上传到系统升级入口。

### 路径 B：兼容 HTTP U-Boot 永久安装

1. 断电后按设备对应方式进入 U-Boot Recovery。
2. 将直连电脑手动设置为：

   - IPv4：`192.168.255.2`
   - 子网掩码：`255.255.255.0`
   - 网关：留空

3. 打开 `http://192.168.255.1/`。
4. 选择 **Firmware**。
5. 布局选择 **UBI 2.0 - 439 MiB**。
6. 上传 `xr1710g-community-v1.4.0-sysupgrade.itb`。
7. 等待擦除、写入和重启全部完成，不要中途断电或关闭页面。

兼容 HTTP U-Boot 的 **Firmware + UBI 2.0 - 439 MiB** 路径同样优先使用 Sysupgrade。不要把系统 ITB 刷入 **Update U-Boot**。

### Recovery 镜像什么时候用

`xr1710g-community-v1.4.0-recovery.itb` 是临时救援/恢复镜像，用于无法正常启动系统时的诊断或恢复流程。它不是普通用户的永久系统镜像。

只有当 Recovery 页面或明确的救援步骤要求“临时启动/加载 Recovery”时才使用它。临时系统启动后，仍使用 `xr1710g-community-v1.4.0-sysupgrade.itb` 完成永久安装。不要把 Recovery ITB 刷入 U-Boot 槽位。

### U-Boot 更新

`xr1710g-uboot-flash-slot.bin` 是基于 YYH2913 HTTP U-Boot 的实机验证兼容版，加入大文件上传节流与安全中断处理；不需要因为系统升级到 v1.4.0 而重复刷写。进入 Recovery 后仍按上文手动设置电脑为 `192.168.255.2/24`。

只有设备尚未使用兼容 U-Boot、或明确需要更新 U-Boot 时，才在 **Update U-Boot** 页面上传该文件。不要把系统 ITB、Recovery ITB、裸 `u-boot.bin` 或独立 FIT 刷入 U-Boot 槽位。

### 首次启动

- 管理地址：`192.168.50.1`
- 用户名：`root`
- 初始管理员密码：`password`
- 2.4/5GHz Wi-Fi：没有预置密码，首次为开放网络
- 6GHz：空 SAE 密钥的 802.11s 模板，默认禁用

请先用网线单独连接一台设备，立即修改管理员密码并为 2.4/5GHz 设置无线加密，再接入家庭网络。两台新刷设备不要同时接入同一网络，以免 `192.168.50.1` 和 DHCP 冲突。

首次界面默认简体中文。切换英文：进入 **系统 → 系统 → 语言和界面**，选择 **English**，然后点击 **保存并应用**。

## English

### Release files

The Release contains only the required files:

| File | Purpose | Flash it? |
|---|---|---|
| `xr1710g-community-v1.4.0-sysupgrade.itb` | Compatible web upgrades and permanent installation through compatible HTTP U-Boot; preferred for normal use | Yes |
| `xr1710g-community-v1.4.0-recovery.itb` | Temporary rescue, recovery, or diagnostics; not a permanent system replacement | Only when a rescue procedure explicitly requests it |
| `xr1710g-uboot-flash-slot.bin` | Hardware-validated compatible build based on YYH2913 HTTP U-Boot, with paced large uploads and safe interrupted-upload cleanup | Only when a U-Boot update is needed |
| `SHA256SUMS.txt` | Download integrity checks | No |
| `FLASHING-GUIDE.md` | This guide | No |

### Before flashing

1. Confirm that the device is a **Gemtek XR1710G**.
2. Verify the selected file against `SHA256SUMS.txt`.
3. Back up any settings you need. Do not preserve settings when changing distributions or eliminating an old configuration problem.
4. Connect only the target device, provide stable power, and never interrupt a write.
5. Never modify or copy Factory, EEPROM, caldata, MAC addresses, or wireless calibration data from another unit.

### Path A: compatible OpenWrt/iStoreOS is running

1. Open **System → Backup / Flash Firmware**.
2. Upload `xr1710g-community-v1.4.0-sysupgrade.itb`.
3. Confirm the file and target device, then start the upgrade.
4. Wait for writing and reboot to finish. Do not remove power.

This is the preferred web-upgrade path. Never upload the Recovery image or U-Boot file to the system-upgrade form.

### Path B: permanent installation through compatible HTTP U-Boot

1. Power off and enter U-Boot Recovery using the procedure for the device.
2. Configure the directly connected computer manually:

   - IPv4: `192.168.255.2`
   - Netmask: `255.255.255.0`
   - Gateway: leave empty

3. Open `http://192.168.255.1/`.
4. Select **Firmware**.
5. Select **UBI 2.0 - 439 MiB**.
6. Upload `xr1710g-community-v1.4.0-sysupgrade.itb`.
7. Wait for erase, write, and reboot to complete. Do not remove power or close the page during the operation.

The compatible HTTP U-Boot **Firmware + UBI 2.0 - 439 MiB** path also prefers Sysupgrade. Never upload a system ITB to **Update U-Boot**.

### When to use the Recovery image

`xr1710g-community-v1.4.0-recovery.itb` is a temporary rescue/recovery image for diagnosis or recovery when the installed system cannot boot. It is not the normal permanent system image.

Use it only when a Recovery page or an explicit rescue procedure asks for a temporary Recovery boot/load. After the temporary system starts, use `xr1710g-community-v1.4.0-sysupgrade.itb` for permanent installation. Never flash the Recovery ITB into the U-Boot slot.

### Updating U-Boot

`xr1710g-uboot-flash-slot.bin` is a hardware-validated compatible build based on YYH2913 HTTP U-Boot, with paced large uploads and safe interrupted-upload cleanup. A v1.4.0 system upgrade does not require flashing it again. Continue to configure the computer manually as `192.168.255.2/24` after entering Recovery.

Upload it on **Update U-Boot** only when the device does not already have compatible U-Boot or when a U-Boot update is explicitly required. Never flash a system ITB, Recovery ITB, raw `u-boot.bin`, or standalone FIT into the U-Boot slot.

### First boot

- Management address: `192.168.50.1`
- User: `root`
- Initial administrator password: `password`
- 2.4/5GHz Wi-Fi: no preset password, initially open
- 6GHz: empty-key 802.11s SAE template, disabled by default

Connect one unit by Ethernet, immediately replace the administrator password, and configure 2.4/5GHz encryption before attaching it to the home network. Do not attach two clean units at the same time, because both start at `192.168.50.1` with DHCP enabled.

The first-boot UI is Simplified Chinese. Open **System → System → Language and Style**, select **English**, and click **Save & Apply**.
