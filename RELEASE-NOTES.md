# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.5.0

## 中文

Gemtek XR1710G（Airoha AN7581 + MediaTek MT7996）非官方社区固件。本次是基于 v1.4.0 的小范围修复，**没有升级内核、网卡/Wi-Fi 驱动、插件或 U-Boot**。

### 本次只改了什么

1. **5GHz 160MHz 启动修复**：后台 CAC 找不到临时可用信道时可能导致 AP 初始化失败，现改用前台 CAC，保留 DFS/雷达检测。首次默认仍为 channel 36 / EHT80 / 请求 29dBm；手动选择 EHT160 后，迁移不会强制改回 EHT80，也不修改用户信道、SSID 或无线密码。DFS 检测期间 5GHz 可能暂时没有信号，应等待检测完成；本次 channel 36 实测约 60 秒。
2. **修正出厂管理员密码**：直接在出厂镜像预置公开默认密码 `password` 的哈希，不再只依赖首次启动脚本。保留配置升级继续使用原密码，不覆盖已有密码。
3. **密码页交流群提示**：增加“本固件交流群 1061612207”，同时提供英文说明，保持 Argon 主题及密码提交逻辑不变。

6GHz 默认模板仍为 channel 37 / EHT160 / 802.11s，空密钥时禁用；2.4GHz、10G/PPE/NPU、Full Cone、Docker、iStore、PassWall2、OpenClash及风扇策略保持 v1.4 基线。

### 普通用户只需这三个文件

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.5.0-sysupgrade.itb` | 唯一系统固件；兼容系统后台升级或兼容 U-Boot 的系统刷写入口 |
| `SHA256SUMS.txt` | 核对文件完整性，不刷入 |
| `FLASHING-GUIDE.md` | 中英文刷机教程，不刷入 |

**已有兼容 U-Boot 不必再次更新。** 如确实需要 U-Boot，请到独立的 [Wiro U-Boot v1.0.0 Release](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) 下载；它不是 1.5 系统镜像，不能混刷入口。

- 后台升级：系统 → 备份/升级，上传上述 sysupgrade ITB。
- Wiro Recovery：使用“系统固件双清”入口；会清除旧配置及 overlay 数据，先备份。红灯通常闪烁约三分钟，必须等待页面 100%、绿灯常亮并能进入系统，不要中途断电。
- 旧兼容 HTTP U-Boot：Firmware → UBI 2.0 - 439 MiB，上传同一个 sysupgrade ITB。
- 干净安装：`192.168.50.1`，用户名 `root`，密码 `password`。2.4/5GHz Wi-Fi 无预设密码，6GHz 空密钥 Mesh 默认关闭。先单独有线连接，立即设置管理员与无线密码。
- 保留配置升级：沿用原管理地址和密码；两台干净设备不要同时接入同一网络。

SHA-256：
```text
ad44bd363957d8b7a893f09fc411a6ce6f0fd4ff2872e0b60f0b1fa11872ea0d  xr1710g-community-v1.5.0-sysupgrade.itb
```

### 验证说明

5GHz 修复已在两台 XR1710G 上分别通过 EHT160 无线重载及软件重启验证。1.5 镜像通过完整离线内容、版本、密码和翻译校验；内核、设备树、wpad、mt76/MT7996 等关键二进制与 1.4 逐字节相同。维护者确认后发布；这些证据不等于对所有环境的零故障承诺，也不能替代尚未记录的新镜像刷后完整验收。此前 10G 与 Mesh 吞吐数据属于历史 1.4 测试，不作为本版新增测速结果。

源码改动及上游署名见 [CHANGES-v1.md](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/public-first-release/CHANGES-v1.md) 和 [ATTRIBUTION.md](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/public-first-release/ATTRIBUTION.md)。各组件继续遵守原许可证。本项目不是 OpenWrt、iStoreOS 或硬件厂商的官方发布。

### 交流群与赞赏

本固件交流群：**1061612207**。

![Wiro 交流群二维码](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/wiro-qq-group.jpg)

赞赏自愿，不影响下载、使用或开源许可。

![赞赏码](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/support-qr.png)

## English

Unofficial OpenWrt / iStoreOS community firmware for **Gemtek XR1710G (Airoha AN7581 + MediaTek MT7996)**.

### Changes from v1.4.0

1. **5GHz EHT160 startup:** use foreground CAC to avoid AP initialization failure when background CAC cannot find an available temporary channel. DFS/radar detection remains enabled. The factory setting remains channel 36 / EHT80 / requested 29dBm; migration preserves the selected width, channel, SSID and security. The 5GHz AP may be unavailable during CAC; channel 36 took approximately 60 seconds in our test.
2. **Factory administrator password:** seed the hash for the public default `password` directly in the image rather than relying solely on a first-boot script. Preserved upgrades keep the owner's password.
3. **Password-page notice:** add “Firmware community QQ group: 1061612207” with Chinese translation; no change to Argon styling or password submission.

No kernel, Ethernet/Wi-Fi driver, plugin or U-Boot update. The 2.4GHz and 6GHz settings, 10G/PPE/NPU behavior, Docker, iStore, Full Cone, PassWall2, OpenClash and fan policies retain the v1.4 baseline. The 6GHz template remains channel 37 / EHT160 / 802.11s, disabled with an empty key.

### Download and install

Only three files are needed: the **sysupgrade ITB** (system firmware), **SHA256SUMS.txt** (integrity check) and **FLASHING-GUIDE.md** (bilingual instructions). GitHub's automatically generated source archives are not flashable firmware.

Use **System → Backup / Flash Firmware**, Wiro Recovery **System Firmware Double-Clean**, or compatible legacy HTTP U-Boot **Firmware → UBI 2.0 - 439 MiB**. Never upload a system ITB to **Update U-Boot**. An existing compatible U-Boot does not need updating; the optional [Wiro U-Boot release](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) is separate.

Wiro double-clean erases old configuration and overlay data: back up first. Wait for the page to reach 100%, a solid green LED and a reachable system. The red LED commonly blinks for about three minutes. Never interrupt power.

Clean-install login: `192.168.50.1`, user `root`, password `password`. Initial 2.4/5GHz Wi-Fi is open; the empty-key 6GHz Mesh template is disabled. Connect one unit by Ethernet and immediately set administrator and Wi-Fi passwords. Preserved upgrades retain the existing address and password.

The initial UI is Chinese. Open **System → System → Language and Style** (系统 → 系统 → 语言和界面), select **English**, and click **Save & Apply** (保存并应用).

### Validation and attribution

The live Wi-Fi fix passed EHT160 reload and software-reboot checks on two XR1710G units. The 1.5 image passed offline content/version/credential/translation checks; kernel, device tree, wpad and mt76/MT7996 binaries match v1.4 byte for byte. Publication is approved by the maintainer; a complete post-flash acceptance record for this new image has not been supplied. Previous 10G/Mesh results are historical v1.4 evidence, not new v1.5 benchmarks or a guarantee for every environment.

See [changes](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/public-first-release/CHANGES-v1.md) and [attribution](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/public-first-release/ATTRIBUTION.md) for source modifications and upstream credits. Original component licenses remain applicable.
