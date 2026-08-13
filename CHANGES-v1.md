# XR1710G Community Firmware v1.2.0 Pre-release Changes / v1.2.0 预发布版变更

> Unofficial community build for Gemtek XR1710G only. / 非官方社区构建，仅适用于 Gemtek XR1710G。

## 中文

- 平台：Linux 6.18.41及新版AN7581以太网、PCIe、PHY、PPE底座，保留NAND/UBI 2.0与默认管理地址 `192.168.50.1`。
- 无线底层：hostapd 2026-07-09加WDS事件修复；mt76 `b2704cf5` 加NSS operating-mode传递和XR1710G无线线程分配。
- 无线默认：2.4GHz HE20/自动信道/请求28dBm；5GHz channel36/EHT80/请求29dBm，并固化inactivity/low-ACK修复；6GHz channel37/EHT320/请求28dBm模板。
- 首次安全：2.4/5GHz不预置密码；6GHz SAE空密钥模板默认禁用，用户设置两端相同密钥后再开启。
- 界面：PPPoE/VLAN关闭时显示“未启用或未配置”；普通端口页隐藏内部eth0；恢复页保留iStoreOS恢复出厂，并在旧YYH U-Boot不支持可靠一次性触发时整块隐藏无效的软件Recovery入口。
- 性能：干净首启默认使用内核performance governor；Airoha页面选择的其他可用策略会持久保存并在后续启动重放。
- 无线：固定mt76/MT7996适配 `b2704cf5`；支持802.11s/WPA3-SAE、EHT320和补充AP-WDS；MLO默认关闭。
- 监管：标准US/AU不变；增加默认关闭的XZ组合实验档，并在LuCI显示共享PHY和无AFC合规警告。
- 状态页：统一缓存、锁、超时恢复和失败降级；移除RPC热路径中的原始寄存器访问；PPE快照限制64项。
- 端口状态：以物理carrier为准，修复空网口误报连接和速率。
- iStore：安装、升级、自更新和APK事务先模拟，依赖失败时零修改退出。
- Docker：预装OpenWrt上游Moby/containerd/runc/compose/Dockerman；默认关闭，统一使用 `/overlay/docker/`。
- 网络角色：WAN检测前拉起物理口；主路由激活恢复dnsmasq自启动；角色工具不自动切网或重启。
- 界面：保留iStoreOS风格、iStore/QuickStart/Argon、OpenClash和中英文界面。

既有实机证据：两台XR1710G在约5米、木质楼梯和水泥楼板间的客厅摆位，以XZ/channel37/EHT320完成约10分钟双向满载；20次均超过400Mbps，中位数约715/720Mbps，空闲双向600 Ping均0%丢包，无Mesh断链、设备重启或关键驱动错误。本轮各项功能也已通过运行态热修验收；最终ITB通过完整离线镜像门禁，但按维护者决定未再次刷入实机复验，因此v1.2.0标记为Pre-release。

## English

- Platform: Linux 6.18.41 with the refreshed AN7581 Ethernet, PCIe, PHY, and PPE baseline, while retaining NAND/UBI 2.0 and default management address `192.168.50.1`.
- Wireless core: hostapd 2026-07-09 plus the WDS event fix; mt76 `b2704cf5` plus operating-mode/NSS propagation and XR1710G worker distribution.
- Wireless defaults: 2.4GHz HE20/automatic channel/requested 28dBm; 5GHz channel36/EHT80/requested 29dBm with inactivity/low-ACK fixes; 6GHz channel37/EHT320/requested 28dBm template.
- First-boot security: no preset 2.4/5GHz password; the empty-key 6GHz SAE template remains disabled until the owner configures both nodes.
- UI: accurate disabled PPPoE/VLAN wording and internal eth0 hidden from ordinary port status. The recovery page keeps iStoreOS factory reset and completely hides the invalid software-Recovery section when the installed YYH U-Boot lacks a reliable one-shot trigger.
- Performance: a clean install defaults to the kernel performance governor; another available policy selected on the Airoha page is persisted and replayed on later boots.
- Wireless: pinned mt76/MT7996 adaptation `b2704cf5`; 802.11s/WPA3-SAE, EHT320, and supplementary AP-WDS support; MLO remains disabled by default.
- Regulatory: standard US/AU entries remain unchanged. An opt-in XZ composite laboratory profile includes prominent shared-PHY and no-AFC warnings.
- Status pages: shared cache, locking, stale-lock recovery, and per-component fallback; no raw-register access in RPC hot paths; PPE samples are capped at 64 entries.
- Physical ports: carrier is the source of truth, fixing unplugged ports incorrectly showing links and speeds.
- iStore: install, upgrade, self-update, and direct APK transactions are simulated before any package database mutation.
- Docker: upstream OpenWrt Moby/containerd/runc/compose/Dockerman are preinstalled but disabled by default and share `/overlay/docker/`.
- Network roles: WAN carrier checks first bring up the physical interface; main-role activation restores dnsmasq autostart; role tools do not switch the network or reboot automatically.
- UI: iStoreOS-style navigation, iStore/QuickStart/Argon, OpenClash, and Chinese/English UI remain included.

Existing hardware evidence: two XR1710G units approximately 5 metres apart across a wooden staircase and concrete floor completed about ten minutes of bidirectional XZ/channel 37/EHT320 load. All 20 runs exceeded 400Mbps, medians were about 715/720Mbps, two post-load 600-packet idle Ping tests had 0% loss, and no Mesh disconnect, reboot, or critical driver error occurred. The current changes were also accepted as runtime hot fixes. The final ITB files passed the complete offline image gate but, by the maintainer's decision, were not reflashed for another post-flash run; v1.2.0 is therefore marked as a Pre-release.
