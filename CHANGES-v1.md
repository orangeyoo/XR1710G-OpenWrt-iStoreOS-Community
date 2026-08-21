# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.4.0 — Changes

> Unofficial community firmware for Gemtek XR1710G only. / 非官方社区固件，仅适用于 Gemtek XR1710G。

## 中文

### v1.4.0 新增

#### 网络与 LuCI

- 修复 LAN 编辑页对稀疏 IPv4 数据调用 `.match()` / `.split()` 引发的异常。
- LAN 静态地址保存时接受裸 IPv4，并默认规范化为 `/24`；保留用户明确输入的合法 CIDR。
- 后端 CIDR guard 将旧式 `ipaddr + netmask` 转换为 CIDR，拒绝非法值，并在 LAN 接口事件后保证配置一致。
- `xr1710g-role` 统一写入 CIDR，不再生成旧式独立 netmask。
- iStoreX/QuickStart 首页路由与服务启动状态解耦，首页不再错误跳转到“状态 → 概况”。

#### 风扇与 Docker

- 删除重复的风扇控制入口，只保留一个控制器。
- 加入低温最低稳定档、阶梯升速、迟滞、异常温度/传感器读取失败保护。
- Dockerman 兼容 Moby 29 的嵌套信息结构。
- Docker 未运行时显示明确提示和启用动作；iStore、Dockerman 与命令行继续控制同一上游 OpenWrt Docker 套件。

#### 主题与首次无线模板

- 从 XR1710G 设备包与最终镜像中移除 GlassTheme 及其中文包。
- Argon 在干净首启成为默认主题；Sysupgrade 不覆盖用户已有主题。
- 6GHz 首次模板固定为 US、PSC channel 37、EHT160、WPA3-SAE 802.11s、`network=lan` 和 Mesh forwarding。
- 6GHz 不预置 SAE 密钥，因此首次默认禁用；2.4/5GHz 也不预置 Wi-Fi 密码。

#### NPU、PPE 与 10G

- MT7996 NPU RX 路径设置正确的入口 `skb->dev`，为 PPE 缓存未命中后的 bridge/FDB 软件回退保留上下文。
- 有线 Airoha PPE 硬件 flow offload 与 MT7996 Wi-Fi NPU 队列继续启用。
- 802.11s Mesh Header 仍由 mac80211 生成；没有加入未经证明的端到端 PPE 直通。
- bridge 拒绝本地 FDB 作为普通 forward path；Airoha PPE 回退同时拒绝路由器本机目标和同入口回注，避免本机管理流被错误绑定回 10G GDM4。
- 普通有线转发与 NAT/PPE 卸载保持可用。

#### Full Cone 与 PassWall2

- 加入 `kmod-nft-fullcone`、libnftnl、nftables、firewall4 与 LuCI 的匹配支持。
- Full Cone NAT 默认关闭，不绕过 CGNAT 或双重 NAT，也不承诺 NAT Type 1。
- 预装 PassWall2 `26.8.20`、Xray `26.7.28`、sing-box `1.13.19`、ChinaDNS-NG、geoview、tcping 和固定 GeoIP/GeoSite。
- PassWall2 使用 firewall4 原生 nftables 路径并默认关闭；不要与 OpenClash 同时启用。

#### 构建与发布门禁

- Recovery 与 Sysupgrade 同时检查 Argon/Glass、LAN CIDR、Dockerman Moby 29、Full Cone、PassWall2、无线模板、首次凭据与 MT7996 NPU 修复。
- 构建脚本按 CPU 与可用内存计算安全并发；feeds 重装和 PassWall2 依赖清理可在复用工作树中保持固定版本。
- 初始管理员密码为 `password`；最终镜像门禁检查其存在，并检查 2.4/5GHz 没有预置 Wi-Fi 密码、6GHz 空密钥模板保持禁用。

### v1.4.0 实机证据

- `wan` 协商 10Gbps Full，`lan1` 与测试 NAS 协商 5Gbps Full。
- 15 秒、4 并发 TCP：XR → NAS 约 3.85Gbps，NAS → XR 约 1.69Gbps。
- 两端口最终 `rx/tx errors=0`；无新增 Link Down、watchdog、DMA/NPU timeout、firmware crash 或 kernel panic。
- 该证据限于本次线材、对端和直连本机端点，不应扩展成所有交换机、运营商、路由/NAT 或异构桥接拓扑的保证。

### 从既有版本延续的基线

以下能力不是 v1.4.0 新增，继续由当前镜像保留：

- Linux 6.18.41、hostapd 2026-07-09 `f08f2749`、mt76/MT7996 适配 `b2704cf5`。
- 5GHz channel 36/EHT80/请求 29dBm、`max_inactivity=86400`、`disassoc_low_ack=0`。
- 2.4GHz HE20/自动信道/请求 28dBm；6GHz 请求 28dBm。
- 普通端口状态隐藏内部 `eth0`，PPPoE/VLAN 关闭状态使用准确文案。
- Linux `performance` governor 首次默认及用户策略持久化。
- Airoha 状态页缓存/锁/失败降级、物理 carrier 真值、iStore APK 事务预检。
- OpenWrt 上游 Moby/containerd/runc/docker-compose/Dockerman 默认安装但停止。
- 默认管理地址 `192.168.50.1/24`、NAND/UBI 2.0、iStoreOS 风格导航、iStore、QuickStart、OpenClash、Nikki 与 EqosPlus。

## English

### New in v1.4.0

#### Network and LuCI

- Fixes LAN editor exceptions caused by calling `.match()` / `.split()` on sparse IPv4 data.
- Accepts a bare static LAN IPv4 address and safely normalizes it to `/24`, while preserving an explicitly valid CIDR.
- Adds a back-end CIDR guard that converts legacy `ipaddr + netmask`, rejects invalid values, and keeps the configuration consistent after LAN interface events.
- Makes `xr1710g-role` write CIDR values instead of a separate legacy netmask.
- Decouples iStoreX/QuickStart home routes from service-start state, preventing the home page from redirecting to **Status → Overview**.

#### Fan and Docker

- Removes duplicate fan-control entry points and keeps one controller.
- Adds a low-temperature minimum stable step, staged speed increases, hysteresis, and invalid-temperature/sensor-read fallback.
- Makes Dockerman compatible with the nested Moby 29 information structure.
- Shows a clear stopped-state message and enable action. iStore, Dockerman, and the CLI continue to control the same upstream OpenWrt Docker stack.

#### Theme and first-boot wireless template

- Removes GlassTheme and its Chinese package from the XR1710G device packages and final images.
- Uses Argon on a clean first boot without replacing a theme already selected by the owner during Sysupgrade.
- Sets the 6GHz first-boot template to US, PSC channel 37, EHT160, WPA3-SAE 802.11s, `network=lan`, and Mesh forwarding.
- No 6GHz SAE key is preset, so the interface remains disabled initially. No 2.4/5GHz Wi-Fi password is preset either.

#### NPU, PPE, and 10G

- Sets the correct ingress `skb->dev` on the MT7996 NPU RX path so bridge/FDB software fallback retains context after a PPE cache miss.
- Keeps wired Airoha PPE hardware flow offload and MT7996 Wi-Fi NPU queues enabled.
- mac80211 still builds the 802.11s Mesh Header; no unverified end-to-end PPE bypass is included.
- Rejects a local FDB as an ordinary bridge forward path and makes Airoha PPE fallback reject router-local destinations and same-ingress reinjection, preventing local management flows from being rebound to 10G GDM4.
- Ordinary wired forwarding and NAT/PPE offload remain available.

#### Full Cone and PassWall2

- Adds matching `kmod-nft-fullcone`, libnftnl, nftables, firewall4, and LuCI support.
- Full Cone NAT is disabled by default. It cannot bypass CGNAT or double NAT and does not promise NAT Type 1.
- Preinstalls PassWall2 `26.8.20`, Xray `26.7.28`, sing-box `1.13.19`, ChinaDNS-NG, geoview, tcping, and pinned GeoIP/GeoSite data.
- PassWall2 uses the firewall4-native nftables path and is disabled by default. Do not enable it together with OpenClash.

#### Build and release gates

- Both Recovery and Sysupgrade are checked for Argon/Glass, LAN CIDR, Dockerman Moby 29, Full Cone, PassWall2, the wireless template, initial credentials, and the MT7996 NPU fix.
- Build scripts calculate safe parallelism from CPU and available memory; feed reinstallation and PassWall2 dependency cleanup preserve pinned revisions in a reused work tree.
- The initial administrator password is `password`. Final-image gates verify it, verify that 2.4/5GHz have no preset Wi-Fi password, and verify that the empty-key 6GHz template remains disabled.

### v1.4.0 physical evidence

- `wan` negotiated 10Gbps Full and `lan1` negotiated 5Gbps Full with the test NAS.
- A 15-second, four-stream TCP test measured about 3.85Gbps from XR to NAS and 1.69Gbps from NAS to XR.
- Both ports ended at `rx/tx errors=0`, with no new Link Down, watchdog, DMA/NPU timeout, firmware crash, or kernel panic.
- This evidence is limited to the tested cable, peer, and direct local endpoints. It must not be extended into a guarantee for every switch, ISP, routed/NAT, or heterogeneous bridge topology.

### Baseline carried forward from earlier releases

The following capabilities are preserved but are not new in v1.4.0:

- Linux 6.18.41, hostapd 2026-07-09 `f08f2749`, and mt76/MT7996 adaptation `b2704cf5`.
- 5GHz channel 36/EHT80/requested 29dBm, `max_inactivity=86400`, and `disassoc_low_ack=0`.
- 2.4GHz HE20/automatic channel/requested 28dBm and 6GHz requested 28dBm.
- Internal `eth0` hidden from ordinary port status and accurate wording for disabled PPPoE/VLAN offload.
- Clean-install Linux `performance` governor and persistence of a later user-selected policy.
- Airoha page cache/lock/fallback handling, physical-carrier truth, and iStore APK transaction preflight.
- Upstream OpenWrt Moby/containerd/runc/docker-compose/Dockerman installed but stopped by default.
- Default management address `192.168.50.1/24`, NAND/UBI 2.0, iStoreOS-style navigation, iStore, QuickStart, OpenClash, Nikki, and EqosPlus.
