# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.4.0

**Release type: Stable / Latest.**

Gemtek XR1710G（Airoha AN7581 + MediaTek MT7996）非官方社区固件。This is an unofficial community build and is not an official release from iStoreOS, OpenWrt, Gemtek, Airoha, or MediaTek.

## 中文

### v1.4.0 新增与修复

- 修复 LAN 编辑页报错和静态 IPv4 CIDR 保存：裸地址按 `/24` 规范化，旧式 `ipaddr + netmask` 自动转换，降低重启后 LAN/DHCP 配置失效风险。
- 修复首页错误跳转到“状态 → 概况”；iStoreX/QuickStart 首页路由不再依赖服务启动时序。
- 风扇合并为单一控制器，加入低温最低稳定档、阶梯升速、迟滞和传感器异常兜底。
- 修复 Dockerman 对 Moby 29 信息结构的兼容；Docker 未启动时显示明确提示和启用入口。
- 删除 GlassTheme 及其中文包；干净首启默认 Argon，Sysupgrade 保留用户已有主题。
- 6GHz 首次模板设为 `US / channel 37 / EHT160 / 802.11s / network=lan`；空 SAE 密钥时默认禁用。
- 修复 MT7996 NPU RX 入口网卡信息，让 PPE 缓存未命中后的 bridge/FDB 软件回退保留正确上下文。
- 加入 10G bridge/PPE 本机流量保护，拒绝将本地 FDB、路由器本机目标和同入口回注流错误绑定回 10G GDM4。
- 预装 `kmod-nft-fullcone` 与配套 libnftnl/nftables/firewall4/LuCI 支持，默认关闭。
- 预装 PassWall2 `26.8.20`、Xray `26.7.28`、sing-box `1.13.19`和 firewall4 原生 nftables 透明代理路径，默认关闭；不要与 OpenClash 同时启用。
- 初始管理员密码为 `password`；2.4/5GHz 不预置 Wi-Fi 密码，6GHz 空密钥 Mesh 模板保持禁用。

### 加速边界

有线路由/转发使用 Airoha PPE 硬件 flow offload，MT7996 使用 Airoha NPU 队列。802.11s Mesh Header 仍由 mac80211 生成；本版没有加入未经证明的 802.11s 端到端 PPE 直通。

### 实机与镜像验证

- Recovery 与 Sysupgrade 均通过最终内容门禁，关键 rootfs 内容一致。
- XR1710G `wan` 与测试对端协商 10Gbps Full，`lan1` 与 NAS 协商 5Gbps Full。
- 15 秒、4 并发 TCP：XR → NAS 约 3.85Gbps，NAS → XR 约 1.69Gbps。
- 两端口最终 `rx/tx errors=0`，压力期间没有新增 Link Down、watchdog、DMA/NPU timeout、firmware crash 或 kernel panic。

该结果证明本次线材、对端和直连本机端点条件下的载波与传输稳定性，不代表所有交换机、运营商、路由/NAT 或异构桥接拓扑。

既有两台 XR1710G 在约 5 米、隔木质楼梯和水泥楼板的摆位中，手动使用 XZ/channel 37/EHT320 完成约 10 分钟、20 次双向回程测试：中位数约 715/720Mbps，最低约 678/671Mbps，满载后双向各 600 Ping 均 0% 丢包。该数据是特定环境和手动 EHT320 配置的结果，不是默认 EHT160 的保证。

### 下载文件

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.4.0-sysupgrade.itb` | 后台升级，或兼容 HTTP U-Boot 的 **Firmware + UBI 2.0 - 439 MiB** 永久安装；普通用户优先使用 |
| `xr1710g-community-v1.4.0-recovery.itb` | 临时救援/恢复镜像，不代替永久 Sysupgrade 安装 |
| `xr1710g-uboot-flash-slot.bin` | 基于 YYH2913 HTTP U-Boot 的实机验证兼容版，加入大文件上传节流与安全中断处理；只有需要更新 U-Boot 时才刷 |
| `SHA256SUMS.txt` | 刷写前校验，不刷入路由器 |
| `FLASHING-GUIDE.md` | 中英文刷机说明 |

首次管理地址为 `192.168.50.1`，用户名 `root`，初始密码为 `password`。2.4/5GHz 初始密码为空，属于开放网络；请先用有线单独连接，立即修改管理员密码并设置无线加密。6GHz Mesh 默认禁用，需先为两端设置相同的 Mesh ID 和 SAE 密钥。

<!-- Future releases: keep this donation block immediately below the Chinese section. -->
### 赞赏

如果这套固件帮你省下了折腾时间，欢迎请我喝杯奶茶。赞赏完全自愿，不影响固件的下载、使用或开源许可。

<p align="center">
  <img src="https://raw.githubusercontent.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/public-first-release/docs/assets/zs.png" alt="太烧 Token 求打赏" width="520">
</p>

## English

### New and fixed in v1.4.0

- Fixes the LAN editor exception and static IPv4 CIDR persistence. Bare addresses are normalized to `/24`, while legacy `ipaddr + netmask` data is converted automatically.
- Fixes the home page redirecting to **Status → Overview**. iStoreX/QuickStart home routes no longer depend on service-start timing.
- Uses one fan controller with a low-temperature minimum stable step, staged increases, hysteresis, and sensor-failure fallback.
- Makes Dockerman compatible with the Moby 29 information structure and provides a clear stopped-state message and enable action.
- Removes GlassTheme and its Chinese package. Clean installations default to Argon; Sysupgrade preserves the owner's current theme.
- Sets the clean 6GHz template to `US / channel 37 / EHT160 / 802.11s / network=lan`; it remains disabled while the SAE key is empty.
- Preserves the ingress netdev on MT7996 NPU RX so bridge/FDB software fallback retains the correct context after a PPE cache miss.
- Adds 10G bridge/PPE local-flow protection for local-FDB, router-destination, and same-ingress reinjection traffic.
- Preinstalls `kmod-nft-fullcone` and matching libnftnl/nftables/firewall4/LuCI support, disabled by default.
- Preinstalls PassWall2 `26.8.20`, Xray `26.7.28`, sing-box `1.13.19`, and the firewall4-native nftables transparent-proxy path, disabled by default. Do not enable PassWall2 together with OpenClash.
- Sets the initial administrator password to `password`; 2.4/5GHz have no preset Wi-Fi password, while the empty-key 6GHz Mesh template remains disabled.

### Acceleration boundary

Wired routing and forwarding use Airoha PPE hardware flow offload, while MT7996 uses Airoha NPU queues. mac80211 still builds the 802.11s Mesh Header; this release does not include an unverified end-to-end 802.11s PPE bypass.

### Physical and image validation

- Both Recovery and Sysupgrade passed the final image-content gate with matching critical rootfs content.
- XR1710G `wan` negotiated 10Gbps Full with the test peer, while `lan1` negotiated 5Gbps Full with the NAS.
- A 15-second, four-stream TCP test measured about 3.85Gbps from XR to NAS and 1.69Gbps from NAS to XR.
- Both ports ended at `rx/tx errors=0`, with no new Link Down, watchdog, DMA/NPU timeout, firmware crash, or kernel panic during the load.

This establishes carrier and direct local-endpoint transfer stability with the tested cable and peer. It is not a guarantee for every switch, ISP, routed/NAT, or heterogeneous bridge topology.

An earlier two-unit test at approximately five metres across a wooden staircase and concrete floor used XZ/channel 37/EHT320 manually. Twenty bidirectional backhaul tests over about ten minutes had medians near 715/720Mbps and minima near 678/671Mbps; two post-load 600-packet Ping runs had 0% loss. This is a result for that environment and manual EHT320 configuration, not a guarantee for the default EHT160 template.

### Downloads

| File | Purpose |
|---|---|
| `xr1710g-community-v1.4.0-sysupgrade.itb` | Preferred image for compatible web upgrades and permanent installation through compatible HTTP U-Boot **Firmware + UBI 2.0 - 439 MiB** |
| `xr1710g-community-v1.4.0-recovery.itb` | Temporary rescue/recovery image; it does not replace permanent Sysupgrade installation |
| `xr1710g-uboot-flash-slot.bin` | Hardware-validated compatible build based on YYH2913 HTTP U-Boot, with paced large uploads and safe interrupted-upload cleanup; flash only when a U-Boot update is needed |
| `SHA256SUMS.txt` | Verify before flashing; never flash this file |
| `FLASHING-GUIDE.md` | Bilingual flashing guide |

The initial address is `192.168.50.1`, the user is `root`, and the initial password is `password`. The initial 2.4/5GHz networks have no password and are open; connect one unit by Ethernet and immediately replace the administrator password and configure wireless encryption. The 6GHz Mesh template is disabled until both nodes have matching Mesh IDs and SAE keys.
