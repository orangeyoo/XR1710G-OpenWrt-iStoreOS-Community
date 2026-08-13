# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.2.0

Gemtek XR1710G（Airoha AN7581 + MediaTek MT7996）非官方社区版 iStoreOS/OpenWrt 固件。This is an unofficial community build and is not an official release from iStoreOS, OpenWrt, Gemtek, Airoha, or MediaTek.

## 中文

### 本版更新

- Linux 6.18.41，更新YYH2913 AN7581以太网、PCIe、PHY和PPE底座。
- mt76/MT7996固定为`b2704cf5`，加入终态`tx failed`统计、operating-mode/NSS传递、AN7581/NPU集成及XR1710G NAPI/TX线程分配。
- hostapd 2026-07-09 `f08f2749`，使用新版底座已有的AP-WDS多BSS事件路由修复。
- 5GHz首次默认改为US/channel 36/EHT80/请求29dBm，并固化`max_inactivity=86400`和`disassoc_low_ack=0`，减少活跃终端被周期清退。
- 三频请求功率默认值为2.4GHz 28dBm、5GHz 29dBm、6GHz 28dBm；6GHz模板保持channel 37/EHT320单跳802.11s。
- 首次2.4/5GHz不预置密码；6GHz SAE空密钥模板默认禁用，设置两端相同密钥后再启用。
- PPPoE/VLAN关闭状态使用准确文案；普通端口状态只显示`wan/lan1/lan2/lan3`，隐藏内部`eth0`和无线虚拟接口。
- 旧YYH U-Boot不支持可靠软件触发时，恢复页隐藏无效的U-Boot入口，只保留iStoreOS恢复出厂；物理Recovery路径不变。
- NPU延迟探测默认自动选择WAN DNS并兼容旧匿名UCI配置，不再把单个远端延迟误报为“NPU绕过”。
- 干净首启默认使用Linux `performance` CPU governor；之后在Airoha页面选择的可用策略会持久保存。

### 验证状态

相关底层和功能已在两台XR1710G上通过运行态热修、游戏稳定性、双向UDP、6GHz Mesh和双机吞吐测试。最终Recovery/Sysupgrade还通过了完整离线镜像门禁，Recovery与永久rootfs关键文件一致，结果为`VERIFY PASSED`。

维护者决定不再把这两个最终ITB重新刷入设备复验，因此本版标记为**Pre-release**。既有约5米、隔木质楼梯和水泥楼板的双机测试中，6GHz回程20轮均超过400Mbps，中位数约715/720Mbps；这些数据是既有实机配置证据，不代表所有环境，也不等同于本次最终ITB的刷后验收。

### 普通用户只下载4个文件

- `xr1710g-community-v1.2.0-sysupgrade.itb`：唯一系统固件；兼容OpenWrt/iStoreOS后台升级，或YYH2913 U-Boot的 **Firmware + UBI 2.0 - 439 MiB** 页面使用。
- `xr1710g-uboot-yyh2913-260712-flash-slot.bin`：仅在没有兼容U-Boot时，从 **Update U-Boot** 页面刷一次。
- `SHA256SUMS.txt`：刷写前校验，不刷入路由器。
- `FLASHING-GUIDE.md`：中英文刷机说明。

首次管理地址为`192.168.50.1`，用户名`root`，管理员密码为空；2.4/5GHz首次也是开放网络。请先单独用网线连接，立即设置管理员密码和无线加密，再接入家庭网络。6GHz Mesh默认关闭，需先在两端设置相同SAE密钥。

## English

### Changes

- Linux 6.18.41 with the refreshed YYH2913 AN7581 Ethernet, PCIe, PHY, and PPE baseline.
- mt76/MT7996 pinned at `b2704cf5`, with terminal `tx failed` accounting, operating-mode/NSS propagation, AN7581/NPU integration, and XR1710G NAPI/TX worker distribution.
- hostapd 2026-07-09 `f08f2749`, using the AP-WDS multi-BSS event-routing fix already present in the refreshed baseline.
- The clean-install 5GHz default is US/channel 36/EHT80/requested 29dBm with `max_inactivity=86400` and `disassoc_low_ack=0` to prevent periodic eviction of active clients.
- Requested power defaults are 28dBm on 2.4GHz, 29dBm on 5GHz, and 28dBm on 6GHz. The 6GHz template remains channel 37/EHT320 single-hop 802.11s.
- No preset 2.4/5GHz password. The empty-key 6GHz SAE Mesh template is disabled until the owner configures both nodes.
- Accurate disabled PPPoE/VLAN wording; ordinary port status shows only `wan`, `lan1`, `lan2`, and `lan3`, hiding internal and wireless virtual interfaces.
- The invalid software U-Boot entry is hidden on legacy YYH U-Boot while iStoreOS factory reset remains available. Physical Recovery is unchanged.
- The NPU latency probe automatically selects a WAN DNS target, remains compatible with legacy anonymous UCI sections, and no longer labels one remote latency result as “NPU bypass.”
- Clean installations default to the Linux `performance` governor; another supported policy selected later in the Airoha page is persisted.

### Validation status

The underlying changes and features were exercised on two physical XR1710G units through runtime hot fixes, game-stability checks, bidirectional UDP, 6GHz Mesh, and two-node throughput tests. The final Recovery and Sysupgrade files also passed the complete offline image gate, including equality checks between critical Recovery and permanent-rootfs content: `VERIFY PASSED`.

The maintainer chose not to reflash these final ITB files for another post-flash run, so v1.2.0 is marked as a **Pre-release**. An existing two-node test at approximately five metres across a wooden staircase and concrete floor produced 20 backhaul runs above 400Mbps with medians near 715/720Mbps. This is evidence from the previously exercised configuration, not a guarantee for every environment or a claim of final-ITB post-flash acceptance.

### Ordinary users need only four files

- `xr1710g-community-v1.2.0-sysupgrade.itb`: the only system image, used from compatible OpenWrt/iStoreOS or from YYH2913 U-Boot with **Firmware + UBI 2.0 - 439 MiB**.
- `xr1710g-uboot-yyh2913-260712-flash-slot.bin`: flash once from **Update U-Boot** only when a compatible U-Boot is not already installed.
- `SHA256SUMS.txt`: verify before flashing; never flash it.
- `FLASHING-GUIDE.md`: bilingual flashing instructions.

The initial address is `192.168.50.1`, the user is `root`, and the administrator password is empty. The 2.4/5GHz networks are also open on first boot. Connect one unit by Ethernet, set the administrator password and wireless encryption immediately, and only then attach it to the home network. The 6GHz Mesh template is disabled until both nodes have the same SAE key.
