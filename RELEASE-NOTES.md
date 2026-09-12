# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.6.1

## 中文

面向 **Gemtek XR1710G**（Airoha AN7581 + MT7996）的非官方社区固件。本版在 v1.6.0 基础上修复四个 Wi-Fi 相关问题。

**四项修复**

- **桥接节点日志刷屏**：空置端口（如节点的 WAN 口）不再每秒刷 `USXGMII AN down`，节点日志不再 8 分钟被冲空。实机验证：空置 12 小时仅 1 条，日志完整覆盖整个开机周期。
- **Apple 漫游兼容**：出厂及升级迁移改用 `ft_over_ds='1'`（两种 FT 漫游方式同时可用），iPhone 跨 AP 漫游不再退回完整认证。只改这一个开关，不触碰密钥/信道/SSID。
- **LuCI 配置误回退**：应用 160MHz 等 DFS 频宽需约 60 秒 CAC，原厂 90 秒确认窗口会先到并回滚配置；现出厂提升为 300 秒，已自定义的值不覆盖。
- **MLO 防误操作**：MLO 编辑器隐藏 802.11s Mesh 回程接口，防止误改成 AP/STA 弄断组网。

其余（内核 6.18.41、mt76 r7、IPv6 去重、后台升级、默认密码与无线出厂参数）不变。

**下载与升级**（四文件只有第 1 个需要刷入）

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.6.1-sysupgrade.itb` | 唯一系统固件：后台升级或兼容 U-Boot 永久安装 |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | 可选 U-Boot，仅"更新 U-Boot"入口；已有兼容版不必重刷 |
| `SHA256SUMS.txt` / `FLASHING-GUIDE.md` | 校验与中英文刷机教程，不刷入 |

- 兼容系统：系统 → 备份/升级 → 上传 ITB；保留配置升级自动应用 FT 与回滚窗口迁移。
- Wiro Recovery：10GbE 口连电脑、开机后 10GbE 灯闪烁时长按 reset 至指示灯跑马灯，进 `192.168.255.1` 选"系统固件双清"（会清配置与 overlay，先备份）。
- 旧版后台超时不重启时不要反复提交，详见 FLASHING-GUIDE。

**首次启动**

- 管理地址 `192.168.50.1`，用户名 `root`，初始管理员密码为 `password`（保留配置升级不覆盖）。
- 2.4/5GHz 无预置密码、初始开放，登录后立即设置加密；空密钥 6GHz Mesh 默认禁用，两端设置相同 Mesh ID 与 SAE 密钥后再启用。
- 出厂 5GHz 为信道 36 / EHT80；6GHz 模板信道 37 / EHT160。160/320MHz 可按环境自选，5GHz 选 160 后需等待 DFS/CAC。

**实机验证**：两台已刷入本版——迁移全部生效、节点 12 小时日志仅 1 条、6GHz 320MHz Mesh ESTAB、S24/Mac/iPhone 接入漫游正常、无驱动或内核错误。以上为刷后验收，不构成长期游戏/漫游/极限吞吐承诺。

[完整变更](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/CHANGES-v1.md) · [修复详情](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/FIX-WIFI-STABILITY-V1.6.1.md) · [刷机指南](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/FLASHING-GUIDE.md) · [Mesh 教程](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/MESH-GUIDE-ZH.md)

本项目非 OpenWrt/iStoreOS/Gemtek 官方发布，各组件保留原许可证与上游署名；可选 [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) 未修改。

| 交流群 **1061612207** | 赞赏自愿 |
|---|---|
| <img src="https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/wiro-qq-group.jpg" width="180" alt="QQ群二维码"> | <img src="https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/support-qr.png" width="180" alt="赞赏码"> |

## English

Unofficial community firmware for the **Gemtek XR1710G** (Airoha AN7581 + MT7996). Four Wi-Fi fixes on top of v1.6.0.

**What changed**

- **Bridge-node log flood:** idle ports no longer print `USXGMII AN down` every second; node logs survive (one line over twelve hours on hardware, full boot-to-now retention).
- **Apple roaming compatibility:** factory defaults and upgrades now use `ft_over_ds='1'` (both FT mechanisms advertised); cross-AP roams no longer fall back to full authentication. Only that switch changes.
- **LuCI rollback window:** raised from the stock 90 s to 300 s out of the box so DFS-spanning widths with ~60 s CAC are no longer rolled back; owner values are kept.
- **MLO editor safety:** 802.11s mesh backhaul interfaces are hidden from the AP/STA grid.

Everything else (kernel 6.18.41, mt76 r7, IPv6 and upgrade fixes, credentials, factory wireless defaults) is unchanged.

**Download & upgrade** (only the first file is flashed)

| File | Purpose |
|---|---|
| `xr1710g-community-v1.6.1-sysupgrade.itb` | The only system image — web upgrade or compatible U-Boot install |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | Optional U-Boot, Update-U-Boot page only |
| `SHA256SUMS.txt` / `FLASHING-GUIDE.md` | Checksums and bilingual guide, not flashed |

- Compatible system: **System → Backup / Flash Firmware**, upload the ITB; migrations apply automatically on preserved upgrades.
- Wiro Recovery: 10GbE port to the computer, hold reset after power-on until the marquee LED, open `192.168.255.1`, choose **System Firmware Double-Clean** (erases config and overlay — back up first).
- If an old upgrade page times out, do not resubmit; see the guide.

**First boot**

- Address `192.168.50.1`, user `root`; the image sets the initial administrator password to `password` (preserved upgrades keep existing credentials).
- 2.4/5GHz start open with no preset password; set encryption immediately. The 6GHz Mesh template is disabled until both units share an identical mesh ID and SAE key.
- Factory 5GHz: channel 36 / EHT80; 6GHz template: channel 37 / EHT160. Wider widths are optional; a 5GHz 160MHz AP waits for DFS/CAC before broadcasting.

**Validation:** both units run this image — all migrations active, one PCS line over twelve idle hours, 6GHz 320MHz mesh ESTAB, S24/Mac/iPhone associating and roaming normally, no driver or kernel errors. Post-flash checks, not long-term guarantees.

See [changes](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/CHANGES-v1.md), [fix details](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/FIX-WIFI-STABILITY-V1.6.1.md), [flashing guide](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/FLASHING-GUIDE.md) and [mesh guide](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/MESH-GUIDE-ZH.md). Not an official OpenWrt/iStoreOS/Gemtek release; component licenses and upstream credits apply.
