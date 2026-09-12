# XR1710G v1.6.1 刷机指南 / Flashing Guide

## 中文

仅适用于 **Gemtek XR1710G**。升级前备份；有两台先升节点、确认正常再升主路由。

**你是哪种情况？直接跳到对应一节：**

| 你的情况 | 去哪节 |
|---|---|
| 已经在跑兼容 OpenWrt / iStoreOS，只想升级 | 路径 1：后台升级 |
| 装了 Wiro U-Boot，想全新/彻底重装 | 路径 2：系统固件双清 |
| 旧版兼容 HTTP U-Boot | 路径 3：旧 U-Boot 全刷 |

三个路径刷的都是**同一个文件**：`xr1710g-community-v1.6.1-sysupgrade.itb`。

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.6.1-sysupgrade.itb` | **唯一系统固件** |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | 可选 U-Boot 更新，仅在"更新 U-Boot / Update U-Boot"入口使用 |
| `SHA256SUMS.txt` | 系统与 U-Boot 校验，不刷入 |
| `FLASHING-GUIDE.md` | 本说明，不刷入 |

### 路径 1：后台升级（已在运行兼容系统）

1. **备份**需要的配置（系统 → 备份/升级 → 生成备份）。
2. 上传 `xr1710g-community-v1.6.1-sysupgrade.itb` → 勾选保留配置 → 确认 → 等待重启。
3. 保留配置升级继续使用原地址和密码；跨发行版或清理顽固旧配置时建议**不**保留。

⚠️ 旧版后台备份大配置可能触发 30 秒超时：若确认后一直不重启，**不要反复提交**——检查升级任务后安排受控 SSH 升级或修补旧入口。新固件修好未来升级，但救不了正在运行的旧入口；这不需要动 U-Boot。

### 路径 2：Wiro U-Boot 系统固件双清（全新/彻底重装）

**先物理进入 Recovery：**

1. 电脑网线接路由器的 **10GbE（10G）端口**，网卡设为**自动获取 IP**（进 Recovery 后会拿到 `192.168.255.x`；拿不到就手动设 `192.168.255.2/24`）。
2. 给路由器**接通电源**开机。
3. 看到 **10GbE 端口 LED 开始闪烁时，长按 reset 复位键不松手**——拿不准时机就多按几秒，进入窗口的时间余量很大。
4. **状态指示灯从常亮红灯变成跑马灯（流水灯）= 已进入恢复模式**，松开按键。
5. 电脑打开 `http://192.168.255.1/`。

**然后在页面里：**

1. 选 **系统固件双清 / System Firmware Double-Clean**，上传同一个 sysupgrade ITB。
2. 🔴 **双清会清掉旧配置、overlay 和里面的 Docker 数据——先备份！**
3. 红灯闪约 3 分钟属正常；等 **页面 100% + 绿灯常亮 + 系统可访问** 才算完成。全程不要断电、复位、拔线。

> 双清重建 `ubootenv / ubootenv2 / fit / rootfs_data`；出厂 EEPROM 和 MAC 数据从厂商 DSD 区域恢复。设备唯一硬件数据（EEPROM、DSD、校准）不会被清除。

### 路径 3：旧版兼容 HTTP U-Boot

物理进入方法与路径 2 相同（10GbE 口 + 电源开启后长按 reset 至跑马灯），页面打开 `http://192.168.255.1/` 后：

1. 若没有自动 DHCP：电脑手动设 `192.168.255.2/24`。
2. 选 **Firmware → UBI 2.0 - 439 MiB**，上传同一个 sysupgrade ITB。完成后电脑恢复自动获取。

⚠️ 旧 U-Boot 页面带 UBI 布局选择器（UBI 2.0 / 1.5 / 1.0）：**必须选与所刷镜像内嵌布局一致的一项**（本项目固件为 UBI 2.0），不要只按页面当前检测到的布局选——不匹配时内核可能加载但系统无限等待。完全重建会重建 `ubootenv / ubootenv2 / fit / rootfs_data` 并重置已保存的 U-Boot 环境变量；EEPROM 与 MAC 从厂商 DSD 恢复。

### U-Boot 要不要一起刷？

**不需要。** 已有兼容 U-Boot 的设备升系统不用重刷 U-Boot。下载区附的是原样未改的 Wiro v1.0.0；需要更换时看 [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) 专页（含上游署名、许可证与对应源码承诺）。只有 flash-slot.bin 能进"更新 U-Boot"；**系统 ITB 和裸 u-boot.bin 不能刷进 U-Boot 槽位**。

### 刷完第一次开机

- 管理地址 `192.168.50.1`，用户名 `root`，管理员初始密码 `password`（保留配置升级不覆盖原密码）。
- 2.4/5GHz 无默认 Wi-Fi 密码、初始开放——**立即设置加密**；6GHz 无预设 SAE 密钥，Mesh 模板默认禁用。
- 5GHz 首次默认 EHT80；手动改 EHT160 时 DFS 检测期间暂不广播，等检测完再判断。
- 两台新刷设备**不要同时**接入同一网络（默认地址和 DHCP 相同会冲突）。
- 不要复制另一台设备的 Factory、EEPROM、caldata 或 MAC。
- 界面默认中文：**系统 → 系统 → 语言和界面 → English → 保存并应用**。
- 交流群：1061612207。

## English

For **Gemtek XR1710G** only. With two units, flash the node first. Back up before upgrading. All three paths flash the **same file**: `xr1710g-community-v1.6.1-sysupgrade.itb`.

| Your situation | Path |
|---|---|
| Already running compatible OpenWrt / iStoreOS | 1 — Web upgrade |
| Wiro U-Boot installed, clean/full reinstall | 2 — System Firmware Double-Clean |
| Legacy compatible HTTP U-Boot | 3 — Legacy U-Boot full flash |

**Path 1 — Web upgrade.** Back up settings, open **System → Backup / Flash Firmware**, upload the ITB, keep settings if upgrading within this firmware line, confirm and wait for reboot. If an old page times out after ~30 seconds without rebooting, do not resubmit; inspect the task and arrange a controlled SSH upgrade or entrypoint hotfix. No U-Boot change is needed.

**Path 2 — Double-Clean.** Enter Recovery physically first:

1. Connect the computer to the router's **10GbE port** with the NIC set to **DHCP** (Recovery assigns `192.168.255.x`; fall back to static `192.168.255.2/24` if needed).
2. Power the router on.
3. **When the 10GbE port LED starts blinking, press and hold the reset button** — the timing window is generous, so hold a few extra seconds if unsure.
4. The status LED changing from solid red to a marquee/running pattern means Recovery is active; release the button.
5. Open `http://192.168.255.1/` in the browser.

Then choose **System Firmware Double-Clean** and upload the same ITB. 🔴 This erases configuration, overlay and Docker data — back up first. The red LED blinks for about three minutes; wait for **100%, a solid green LED and a reachable system**. Never cut power during writing. The double-clean rebuilds `ubootenv/ubootenv2/fit/rootfs_data`; factory EEPROM and MAC data are restored from the vendor DSD area — unique hardware data is never wiped.

**Path 3 — Legacy U-Boot.** Enter Recovery the same way (10GbE port, hold reset after power-on until the marquee LED), open `http://192.168.255.1/`, and if DHCP is unavailable set the computer to `192.168.255.2/24`. Choose **Firmware → UBI 2.0 - 439 MiB** and upload the same ITB, then restore computer DHCP afterwards.

⚠️ The legacy page includes a UBI layout selector (2.0 / 1.5 / 1.0): **pick the layout embedded in the image you are flashing** (this project's images are UBI 2.0), not merely what the page currently detects — a mismatch can leave the kernel loaded but the system waiting forever. A full rebuild recreates `ubootenv/ubootenv2/fit/rootfs_data` and resets saved U-Boot environment values; EEPROM and MAC are restored from the vendor DSD.

**U-Boot:** existing compatible U-Boot does not need re-flashing for this system update. The optional `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` is unchanged; see the [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) page for the procedure, credits, licenses and the written corresponding-source offer. Only that flash-slot file may be uploaded to **Update U-Boot** — never a system ITB or raw u-boot.bin.

**First boot.** Address `192.168.50.1`, user `root`, password `password` (preserved upgrades keep credentials). Initial 2.4/5GHz networks are open — set encryption immediately; the empty-key 6GHz mesh template stays disabled. Factory 5GHz width is EHT80; EHT160 is selectable and needs its DFS/CAC wait before broadcasting. Configure clean units one at a time; never copy another device's Factory, EEPROM, caldata or MAC. UI starts in Chinese: **System → System → Language and Style → English → Save & Apply**.
