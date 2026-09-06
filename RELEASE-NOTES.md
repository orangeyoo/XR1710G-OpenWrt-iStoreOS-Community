# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.5.0

## 中文

Gemtek XR1710G（Airoha AN7581 + MediaTek MT7996）非官方社区固件。这是基于 v1.4 的小范围修复，**没有升级内核、网卡/Wi-Fi 驱动、插件或 U-Boot**。

### 本次更新

1. **5GHz EHT160 启动修复**：改用前台 CAC，规避后台 CAC 找不到临时可用信道时 AP 初始化失败。保留 DFS/雷达检测，升级迁移保留用户的频宽、信道、SSID 和密码；首次默认仍为 channel 36 / EHT80 / 请求 29dBm，不强制把用户选择的 160MHz 改回 80MHz。DFS 检测期间 5GHz 暂时不广播，本次 channel 36 实测约 60 秒。
2. **修正出厂管理员密码**：直接在系统镜像预置公开默认密码 `password` 的哈希，不再仅依赖首启脚本；保留配置升级不覆盖已有密码。
3. **交流群提示**：修改管理员密码页增加“本固件交流群 1061612207”，含英文翻译，保持 Argon 主题和密码提交逻辑不变。

6GHz 默认仍是 channel 37 / EHT160 / 802.11s 空密钥禁用模板。2.4GHz、10G/PPE/NPU、Full Cone、Docker、iStore、PassWall2、OpenClash及风扇策略沿用 v1.4。

### 四个文件，用途不要混淆

| 文件 | 用途 |
|---|---|
| xr1710g-community-v1.5.0-sysupgrade.itb | 唯一系统固件：兼容系统后台升级或 U-Boot 系统刷写入口 |
| xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin | 已验证 Wiro U-Boot；仅在“更新 U-Boot / Update U-Boot”入口使用，已有兼容版本不必重刷 |
| SHA256SUMS.txt | 系统与 U-Boot 两个文件的完整性校验，不刷入 |
| FLASHING-GUIDE.md | 中英文刷机教程，不刷入 |

**已有兼容 U-Boot 不需要再次更新。** 同一下载区已附上 [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) 的原始已验证文件；它不是 1.5 系统镜像。其上游署名、许可证及对应源码书面提供承诺见该专页，本次原样附带，不改版本或二进制。

- 后台：系统 → 备份/升级，上传 sysupgrade ITB。
- Wiro Recovery：选择“系统固件双清”，先备份。此操作会清除旧配置和 overlay 中的 Docker 等数据。红灯通常闪烁约三分钟，必须等页面 **100%、绿灯常亮、系统可访问**，不要中途断电。
- 旧兼容 HTTP U-Boot：Firmware → UBI 2.0 - 439 MiB，使用同一个 sysupgrade ITB。
- **不要把系统 ITB 上传到 Update U-Boot。**
- 干净安装：管理地址 **192.168.50.1**，用户名 **root**，初始密码 **password**。2.4/5GHz Wi-Fi 初始无密码；6GHz Mesh 空密钥默认关闭。请单独有线连接后立即设置管理员和无线密码。
- 保留配置升级继续使用原地址和密码。两台干净设备不要同时入网，以免 DHCP/地址冲突。

SHA-256：

    ad44bd363957d8b7a893f09fc411a6ce6f0fd4ff2872e0b60f0b1fa11872ea0d  xr1710g-community-v1.5.0-sysupgrade.itb
    8f150e5ad4aaedcfae4ed6f705c6bf5e32a2e4fe70802d1cf23bc926544eca1f  xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin

### 验证与来源

无线修复已在两台 XR1710G 上分别通过 EHT160 无线重载及软件重启验证；1.5 镜像通过完整离线内容、版本、密码和翻译检查。内核、设备树、wpad、mt76/MT7996 等关键二进制与 1.4 逐字节相同。维护者确认后发布；新镜像完整刷后验收尚无记录，不把历史 10G/Mesh 测速当成本版新增结果，也不作所有环境零故障承诺。

[源码变更](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.5.0/CHANGES-v1.md) · [上游署名与许可证](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.5.0/ATTRIBUTION.md)。本项目不是 OpenWrt、iStoreOS 或硬件厂商官方发布，各组件继续适用原许可证。

### 交流群与赞赏

**本固件交流群：1061612207**

![Wiro 交流群二维码](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/wiro-qq-group.jpg)

赞赏自愿，不影响下载、使用或开源许可。

![赞赏码](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/support-qr.png)

## English

Unofficial community firmware for **Gemtek XR1710G (Airoha AN7581 + MediaTek MT7996)**.

### Changes from v1.4

1. **5GHz EHT160 startup:** use foreground CAC to avoid AP initialization failure when background CAC has no available temporary channel. DFS remains enabled. Migration keeps owner width/channel/SSID/security; the factory setting remains channel 36 / EHT80 / requested 29dBm. Wait for CAC before expecting the AP to broadcast (approximately 60 seconds on channel 36 in our test).
2. **Factory login:** seed the hash for the public default administrator password **password** directly in the image. Preserved upgrades retain the existing password.
3. **Password-page notice:** add “Firmware community QQ group: 1061612207” with Chinese translation; no change to Argon styling or password submission.

No kernel, Ethernet/Wi-Fi driver, plugin or U-Boot upgrade. The 2.4GHz/6GHz settings, 10G/PPE/NPU, Docker, iStore, Full Cone, PassWall2, OpenClash and fan policies retain the v1.4 baseline. The 6GHz template remains channel 37 / EHT160 / 802.11s, disabled with an empty key.

### Download and flash

Four files are provided: **sysupgrade ITB** (system firmware), **xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin** (optional U-Boot, only for **Update U-Boot**), **SHA256SUMS.txt** (checksums for both binaries), and **FLASHING-GUIDE.md** (bilingual instructions). GitHub's source archives are not flashable firmware.

Use **System → Backup / Flash Firmware**, Wiro Recovery **System Firmware Double-Clean**, or compatible legacy HTTP U-Boot **Firmware → UBI 2.0 - 439 MiB**. Never upload a system ITB to **Update U-Boot**. Existing compatible U-Boot does not need reflashing; [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) is also attached here unchanged. Its version remains v1.0.0; upstream attribution, licenses and the written corresponding-source offer remain available on that dedicated release page.

Double-clean erases old configuration and overlay data. Back up first; wait for **100%, a solid green LED and a reachable system**. The red LED commonly blinks for about three minutes. Never interrupt power.

Clean login: **192.168.50.1 / root / password**. Initial 2.4/5GHz networks are open; the empty-key 6GHz Mesh is disabled. Connect one unit by Ethernet and set passwords immediately. Preserved upgrades keep existing address/password.

The initial UI is Chinese. Open **System → System → Language and Style** (系统 → 系统 → 语言和界面), select **English**, and click **Save & Apply** (保存并应用).

### Validation and attribution

The live Wi-Fi fix passed EHT160 reload and software-reboot checks on two units. The 1.5 image passed offline content/version/credential/translation checks; kernel, device tree, wpad and mt76/MT7996 binaries match v1.4. Publication is approved by the maintainer; complete new-image post-flash acceptance is not recorded. Historical 10G/Mesh benchmarks are not new v1.5 results or guarantees for every environment.

See [changes](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.5.0/CHANGES-v1.md) and [attribution](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.5.0/ATTRIBUTION.md). Original component licenses remain applicable.
