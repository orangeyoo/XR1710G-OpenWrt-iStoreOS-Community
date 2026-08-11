# XR1710G Community Firmware v1.1.0 Changes / v1.1.0 变更

> Unofficial community build for Gemtek XR1710G only. / 非官方社区构建，仅适用于 Gemtek XR1710G。

## 中文

- 平台：Linux 6.18.38，AN7581 DTS、NAND/UBI 2.0、以太网、NPU和MT7996支持；默认管理地址 `192.168.50.1`。
- 无线：固定mt76/MT7996适配 `b2704cf5`；支持802.11s/WPA3-SAE、EHT320和补充AP-WDS；MLO默认关闭。
- 监管：标准US/AU不变；增加默认关闭的XZ组合实验档，并在LuCI显示共享PHY和无AFC合规警告。
- 状态页：统一缓存、锁、超时恢复和失败降级；移除RPC热路径中的原始寄存器访问；PPE快照限制64项。
- 端口状态：以物理carrier为准，修复空网口误报连接和速率。
- iStore：安装、升级、自更新和APK事务先模拟，依赖失败时零修改退出。
- Docker：预装OpenWrt上游Moby/containerd/runc/compose/Dockerman；默认关闭，统一使用 `/overlay/docker/`。
- 网络角色：WAN检测前拉起物理口；主路由激活恢复dnsmasq自启动；角色工具不自动切网或重启。
- NPU标签：将“VLAN/PPPoE加速”纠正为bridge netfilter标签处理，避免与真正硬件Flow Offload混淆。
- 界面：保留iStoreOS风格、iStore/QuickStart/Argon、OpenClash和中英文界面。

实机验收：两台XR1710G在约5米、木质楼梯和水泥楼板间的客厅摆位，以XZ/channel37/EHT320完成约10分钟双向满载；20次均超过400Mbps，中位数约715/720Mbps，空闲双向600 Ping均0%丢包，无Mesh断链、设备重启或关键驱动错误。

## English

- Platform: Linux 6.18.38 with AN7581 DTS, NAND/UBI 2.0, Ethernet, NPU, and MT7996 support; default management address `192.168.50.1`.
- Wireless: pinned mt76/MT7996 adaptation `b2704cf5`; 802.11s/WPA3-SAE, EHT320, and supplementary AP-WDS support; MLO remains disabled by default.
- Regulatory: standard US/AU entries remain unchanged. An opt-in XZ composite laboratory profile includes prominent shared-PHY and no-AFC warnings.
- Status pages: shared cache, locking, stale-lock recovery, and per-component fallback; no raw-register access in RPC hot paths; PPE samples are capped at 64 entries.
- Physical ports: carrier is the source of truth, fixing unplugged ports incorrectly showing links and speeds.
- iStore: install, upgrade, self-update, and direct APK transactions are simulated before any package database mutation.
- Docker: upstream OpenWrt Moby/containerd/runc/compose/Dockerman are preinstalled but disabled by default and share `/overlay/docker/`.
- Network roles: WAN carrier checks first bring up the physical interface; main-role activation restores dnsmasq autostart; role tools do not switch the network or reboot automatically.
- NPU labels: misleading VLAN/PPPoE “acceleration” labels now identify bridge-netfilter tag handling and are separated from real hardware Flow Offload.
- UI: iStoreOS-style navigation, iStore/QuickStart/Argon, OpenClash, and Chinese/English UI remain included.

Hardware acceptance: two XR1710G units approximately 5 metres apart across a wooden staircase and concrete floor completed about ten minutes of bidirectional XZ/channel 37/EHT320 load. All 20 runs exceeded 400Mbps, medians were about 715/720Mbps, two post-load 600-packet idle Ping tests had 0% loss, and no Mesh disconnect, reboot, or critical driver error occurred.
