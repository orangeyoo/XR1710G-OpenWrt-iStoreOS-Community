# XR1710G OpenWrt / iStoreOS Wi-Fi 7 社区固件

**语言 / Languages：** [中文（本页）](README.md) | [English](README-EN.md) | [双语刷机指南 / Bilingual Flashing Guide](FLASHING-GUIDE.md)

**Gemtek XR1710G、Airoha AN7581、MediaTek MT7996、OpenWrt、iStoreOS、Wi-Fi 7、6GHz 802.11s Mesh。**

这是面向 **Econet/Gemtek XR1710G（Airoha AN7581 + MT7996）** 的非官方社区移植。项目以 [YYH2913/openwrt](https://github.com/YYH2913/openwrt) 的板级支持为基础，按 iStoreOS 的公开组件化方式集成 iStore、QuickStart、Argon、OpenClash、上游 Docker 套件及 XR1710G 状态/诊断功能。

它不是 LinkEase/iStoreOS、OpenWrt、Gemtek、Airoha 或 MediaTek 的官方发布版。只适用于 XR1710G，不要刷到相似外壳或其他 Airoha/MediaTek 设备。

## v1.2.0 Pre-release 重点更新

> 本版相关底层和功能已通过两台实机运行态热修、无线与双机测试，最终 Recovery/Sysupgrade 也已通过完整离线镜像门禁。由于用户决定不再把这两个最终 ITB 重新刷入设备复验，本版以 **Pre-release** 发布，不宣称最终镜像已完成刷后验收。

- 平台更新至 Linux 6.18.41 和新版 YYH2913 AN7581 以太网、PCIe、PHY、PPE 底座；hostapd 更新至 2026-07-09，并使用该底座自带的 AP-WDS 多 BSS 事件修复。
- MT7996 增加 operating-mode/NSS 传递修复和 XR1710G 专用 NAPI/TX 工作线程分配；干净首启默认使用 performance governor，用户在 Airoha 页面选择的其他内核策略会持久保存并在后续启动重放。
- 修复 5GHz 活跃终端被 inactivity 计时器周期清退：默认 `max_inactivity=86400`、`disassoc_low_ack=0`；最终采用完成零丢包UDP和游戏稳定性验证的 channel 36/EHT80。
- 首次 2.4/5GHz 不再预置公共密码，6GHz SAE Mesh 空密钥模板默认禁用；设置安全密钥后再启用。
- Airoha 页准确区分“未启用/未配置”和“不支持”，普通端口状态只显示 `wan/lan1/lan2/lan3`，隐藏内部 `eth0`。
- 恢复页始终提供“iStoreOS 恢复出厂”；只有检测到已验证的一次性软件触发时才显示“U-Boot Recovery”，当前旧版YYH U-Boot不显示无效按钮，物理Recovery步骤见刷机指南。

## v1.1.0 已发布修复

- 平台级修复 Airoha SoC/NPU、FlowSense 和风扇页面：共享缓存、互斥锁、过期锁恢复、单项失败降级；移除 LuCI 请求热路径中的 `devmem`/物理寄存器轮询。
- 修复打开状态页后 LuCI 会话失效的社区反馈；两台实机连续快照和浏览器会话保持通过。
- 修复空网口显示“已连接/有协商速率”：链路状态统一以物理 `carrier` 为准。
- iStore 安装、升级、自更新和直接 APK 事务先执行 `--simulate`；依赖解析失败时不修改软件数据库。
- 预装 OpenWrt 上游 Moby、containerd、runc、docker-compose 和 Dockerman。Docker 默认停止且不自启；iStore、Dockerman和命令行共用 `/etc/config/dockerd`、`/var/run/docker.sock` 和 `/overlay/docker/`。
- Docker 关闭时，Dockerman 显示明确说明和启用入口，不再只显示 socket 错误。
- WAN 检测前先拉起物理口；角色工具恢复 dnsmasq 自启动，避免 PPPoE 上线但 LAN 客户端拿不到地址。
- 新增共享 PHY 的 XZ 组合实验档和中英文合规警告。标准 US/AU 不变，XZ 默认关闭。

完整来源和许可证边界见 [ATTRIBUTION.md](ATTRIBUTION.md)，详细变更见 [CHANGES-v1.md](CHANGES-v1.md)。

## 核心能力

- Linux 6.18.41，XR1710G AN7581 DTS、NAND/UBI 2.0、以太网、PPE 和 NPU 支持。
- 固定 XR1710G MT76/MT7996 适配提交 `b2704cf5`。
- 2.4/5/6GHz 三频 Wi-Fi 7，WPA3-SAE 802.11s Mesh。
- hostapd AP-WDS 多 BSS 事件路由修复；WDS是补充能力，不是默认回程。
- MLO默认关闭；当前推荐稳定回程仍是单跳802.11s。
- iStore、iStoreX、QuickStart、Argon、OpenClash、Nikki、EqosPlus和诊断页面。
- 默认管理地址 `192.168.50.1/24`，减少与常见 `192.168.1.1` 光猫冲突。
- `/usr/sbin/xr1710g-role`：安全设置主路由/节点角色，只提交配置，不擅自切网或重启。
- `/usr/sbin/xr1710g-mesh-diag`：生成脱敏的 Mesh、信号、速率、重试、温度和日志摘要。

## 默认无线策略

干净首启后，驱动加载完成才应用无线默认值：

- 2.4GHz：US、自动信道、HE20、请求28dBm；SSID为 `XR1710G`，初始开放且不预置密码。
- 5GHz：US、channel 36、EHT80、请求29dBm；SSID为 `XR1710G-5G`，初始开放且不预置密码，并启用802.11k/v/r及周期重连修复。
- 6GHz：US、PSC channel 37、EHT320、请求28dBm、WPA3-SAE 802.11s Mesh模板；不预置密钥，因此首次默认禁用。

首次登录后应立即为2.4/5GHz设置加密和密码。需要兼容老设备时可把2.4GHz设为WPA/WPA2 Personal混合模式。两台设备的6GHz Mesh必须设置相同的Mesh ID、SAE密钥、频道、带宽和监管域，再分别启用；空密钥不能启动合法的6GHz SAE回程。

XR1710G 三个频段实际共用同一个 Linux PHY，因此内核最终只应用一个监管域。不能把三张 Radio 当作完全独立国家码。标准国家模式保持原始 regdb 规则。

### XZ 实验档

XZ 是用户主动选择的组合实验配置：2.4/5GHz使用固定AU规则，6GHz加入36dBm无AFC实验规则。XZ不是国家监管域，本固件没有实现AFC，也不授予Standard Power权限。它默认关闭，仅限受控实验室或已取得相应授权的测试；用户必须自行遵守当地法律、频道和功率限制。实际功率仍受驱动、固件和Factory校准约束，选择36dBm上限不等于硬件一定以36dBm发射。

## 双机实测

测试摆位为楼上、楼下各一台，节点间约5米，中间隔木质楼梯和水泥楼板，楼上节点位于二楼客厅。手动选择 XZ/channel 37/EHT320 后：

- 6GHz 802.11s全程 `ESTAB`，信号约 `-63～-67dBm`。
- 30秒双向基线约 `716/735Mbps`。
- 连续约10分钟、20次双向4并发：中位数 `715/720Mbps`，最低 `678/671Mbps`，全部超过400Mbps。
- 满载结束后双向各600个空闲Ping均0%丢包，平均约2ms。
- 数千万发送包内 `tx failed` 仅增1/3，驱动重试率约3.36%/2.10%。
- 温度最高约56.3/59.3°C；无 `airtime_link_metric_get`、MT7996 reset/timeout/crash、MCU timeout、firmware crash、Call Trace、kernel panic或设备重启。

该吞吐由两台路由器本机iperf3端点完成，CPU最高约44.8%，适合验证回程稳定性；它不是两端2.5G有线客户端的极限吞吐承诺。环境、墙体、摆位和监管设置不同，结果会变化。

## 两台设备的角色和漫游

同一镜像不会猜测哪台是主路由。两台干净首启都会使用 `192.168.50.1` 和 DHCP，因此必须逐台配置：

1. 主路由保留不冲突LAN地址和DHCP，只在独立WAN接口设置DHCP/PPPoE；不要把LAN改成PPPoE。
2. 节点设置同网段静态地址，例如 `192.168.50.2`，关闭DHCPv4、RA和DHCPv6服务器，并将网关/DNS指向主路由。
3. 两台分别设置相同的2.4/5GHz SSID、加密方式和密码；固件不会自动从主路由同步到节点。
4. 6GHz两端设置相同Mesh ID、SAE密钥、频道、带宽和监管域。
5. 保留网线管理，确认 `mesh plink: ESTAB` 后再拔掉节点网线。

角色工具示例：

```sh
xr1710g-role status
xr1710g-role main-dhcp 192.168.50.1/24
xr1710g-role main-pppoe 192.168.50.1/24
xr1710g-role node 192.168.50.2/24 192.168.50.1
```

工具会先备份UCI，只提交配置，不自动重载网络、无线或重启。PPPoE密码通过隐藏输入读取，不写入命令历史。

## Docker

本项目不实现私有Docker引擎。固件只预装OpenWrt feeds提供的上游开源套件：Moby `dockerd`/CLI、containerd、runc、docker-compose和luci-app-dockerman。

- 默认已安装但停止且不自启。
- 用户从iStore或Dockerman启用后才启动。
- iStore、Dockerman和命令行控制同一个 `/etc/init.d/dockerd`。
- 数据目录为约311MiB overlay中的 `/overlay/docker/`，并非额外的大容量磁盘。大量镜像和容器建议挂载外部存储。

## 刷机

普通用户请阅读 [FLASHING-GUIDE.md](FLASHING-GUIDE.md)。Release只保留4个必要文件：已验证YYH2913 U-Boot、唯一Sysupgrade系统镜像、SHA256SUMS和双语说明。

YYH2913 HTTP U-Boot正常系统安装路径：进入 `http://192.168.255.1/`，选择 **Firmware + UBI 2.0 - 439 MiB**，上传Release里的 `xr1710g-community-v1.2.0-sysupgrade.itb`。不要把initramfs调试镜像当普通安装包。

必须确认设备已经使用匹配的XR1710G UBI 2.0布局：

| 分区 | 起始 | 大小 |
|---|---:|---:|
| `vendor` | `0x00000000` | `0x00600000` |
| `chainloader` | `0x00600000` | `0x00100000` |
| `ubi` | `0x00700000` | `0x1b700000` |
| `reserved_bmt` | `0x1be00000` | `0x04200000` |

不要修改或复制其他设备的Factory、EEPROM、caldata、MAC或无线校准数据。首次启动地址为 `192.168.50.1`，用户名 `root`，初始密码为空；请用有线登录后立即设置密码。

### 切换英文界面

首次界面默认简体中文。进入 **系统 → 系统 → 语言和界面**，把语言改为 **English** 并保存应用。英文路径是 **System → System → Language and Style**。

## 构建和验证

构建脚本固定底座和feeds提交，并执行源码锚点、RPC安全、iStore事务预检、QuickStart链路、隐私扫描、Recovery/Sysupgrade内容一致性和镜像类型门禁。

```sh
docker volume create xr1710g-istoreos-final
docker run --name xr1710g-istoreos-build-final \
  -v xr1710g-istoreos-final:/work \
  -v "$PWD":/builder:ro \
  ubuntu:22.04 bash /builder/scripts/build-local-docker.sh
```

关键文件：

- `configs/openwrt.config`：固定构建配置。
- `feeds.d/openwrt`：固定的上游feeds提交。
- `diy-part2.d/openwrt.sh`：XR1710G/iStoreOS社区集成。
- `patches/`：OpenWrt、LuCI、软件包和监管配置补丁。
- `scripts/test-status-and-istore-safety.sh`：状态页、链路和iStore事务安全测试。
- `scripts/verify-xr1710g-build.sh`：最终镜像门禁。
- `uboot/`：YYH2913 U-Boot来源和独立实验补丁说明。

## 上游与许可证

本项目使用并标注了YYH2913/openwrt、YYH2913/http-uboot、naoki66/ImmortalWrt-for-Gemtek-XR1710G、OpenWrt、mt76、hostapd、iStoreOS、iStore/iStoreX、QuickStart、OpenClash、Argon、Nikki、sirpdboy/EqosPlus及Airoha/MediaTek上游内容。完整固定提交、用途和许可证见 [ATTRIBUTION.md](ATTRIBUTION.md)。各第三方组件继续适用其原许可证，本项目不代表上述上游为此社区固件背书。

## 反馈问题

请注明设备批次、主路由/节点角色、监管域、6GHz信道和带宽、摆放距离，并提交 `xr1710g-mesh-diag`、`dmesg`、`iw dev` 和 `ubus call network.wireless status` 的相关摘要。
