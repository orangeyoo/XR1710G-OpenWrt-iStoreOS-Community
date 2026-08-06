# XR1710G iStoreOS Community First Release Changes / 第一版变更说明

> Community build, unofficial, XR1710G only. / 社区构建，非官方，仅适用于 XR1710G。

## 中文：我们重新改了什么

### 平台与启动

- 新增并整理 XR1710G 的 Airoha AN7581 设备树、分区和 UBI 2.0 镜像布局。
- 基于 Linux 6.18.38 构建，保留 XR1710G 所需的以太网、交换芯片、NAND/UBI 和无线设备描述。
- 默认 LAN 管理地址改为 `192.168.50.1`，降低与常见光猫 `192.168.1.1` 的冲突概率。
- 没有修改 Factory、EEPROM、caldata、无线校准数据或 U-Boot 分区。

### 无线与回程

- 集成并固定 MT76/MT7996 的 XR1710G 适配提交 `b2704cf5`。
- 增加终态 `tx failed` 统计修正，避免把正常重试误报为终端失败；已在两台实机日志中确认 `tx failed=0`。
- 默认 6 GHz 回程为单跳 802.11s Mesh、US 监管域、PSC 信道 37、EHT320、WPA3-SAE。
- 保留 WDS/AP-WDS 兼容修复，但不把 WDS 设为默认回程，也不默认开启 MLO。
- 添加无线诊断工具，用于检查 Mesh 状态、信号、速率、重试、失败计数和温度。

### 性能与硬件加速

- 集成 Airoha NPU/Flow offload 相关配置和状态页面。
- 增加 NPU 状态、风扇/温度和链路诊断页面；这些页面只读展示硬件状态，不修改校准数据。
- 修复 Airoha TRNG 初始化时 SCU 时钟未准备的问题；该修复仍需不同批次设备进行冷启动验证。

### iStoreOS / LuCI 功能

- 集成 iStoreOS 风格的 LuCI 主题与入口，保留 Argon、QuickStart 和 iStore 应用管理界面。
- 集成 OpenClash 核心和启动所需目录；用户仍需自行导入配置文件。
- 增加软件源隔离与修复逻辑，避免错误的软件源配置导致首页循环刷新。
- 增加 PPPoE/LAN 角色切换工具，避免误把 PPPoE 配置写入 LAN。
- 集成 hostapd WDS 相关修复包，并标明其为补充能力。
- 集成 eqosplus、AdGuardHome 等可选组件时，未配置的服务不会默认自启动。

### 验收结论与边界

- 两台实机：Mesh `ESTAB`，6 GHz 为 US/CH37/EHT320，温度约 `52.6°C / 56.7°C`。
- 日志未发现 `firmware crash`、`MCU timeout`、kernel panic、watchdog、UBI/I/O 错误或 `airtime_link_metric_get`。
- 重载或重启期间可能出现短暂 SAE 认证失败、Mesh 断开和 PPPoE PADO 超时；测试中均自动恢复，不能视为零秒切换承诺。
- 本版本没有把 U-Boot 上传修复混入系统镜像；U-Boot 请见 Release 的独立资产和 [`uboot/`](uboot/) 源码说明。

## English: What we changed

### Platform and boot

- Added and organized the XR1710G Airoha AN7581 device tree, partition layout, and UBI 2.0 image layout.
- Built on Linux 6.18.38 while retaining the XR1710G Ethernet, switch, NAND/UBI, and wireless descriptions.
- Changed the default LAN management address to `192.168.50.1` to reduce collisions with common ONT gateways at `192.168.1.1`.
- Factory, EEPROM, caldata, wireless calibration data, and the U-Boot partition are not modified.

### Wireless and backhaul

- Integrated and pinned the XR1710G MT76/MT7996 adaptation at commit `b2704cf5`.
- Added terminal `tx failed` accounting fixes so normal retries are not reported as terminal failures; both physical units showed `tx failed=0` in acceptance logs.
- The default 6 GHz backhaul is single-hop 802.11s Mesh, US regulatory domain, PSC channel 37, EHT320, and WPA3-SAE.
- WDS/AP-WDS compatibility fixes are included as an optional capability. WDS is not the default backhaul and MLO is not enabled by default.
- Added wireless diagnostics for Mesh state, signal, rates, retries, failures, and temperature.

### Performance and acceleration

- Integrated Airoha NPU/flow-offload configuration and status pages.
- Added read-only NPU, fan/temperature, and link diagnostics; these pages do not alter calibration data.
- Fixed Airoha TRNG initialization when SCU clocks were not prepared; cold-boot validation on additional hardware is still required.

### iStoreOS / LuCI features

- Integrated the iStoreOS-style LuCI theme and navigation while retaining Argon, QuickStart, and iStore application management.
- Included the OpenClash core and required startup directories; users must import their own configuration.
- Added feed isolation and repair logic to prevent a broken feed configuration from causing repeated homepage refreshes.
- Added PPPoE/LAN role switching helpers to prevent accidentally writing PPPoE settings to LAN.
- Included hostapd WDS fixes and documented WDS as supplementary functionality.
- Optional components such as eqosplus and AdGuardHome do not auto-start when unconfigured.

### Acceptance and boundaries

- Two physical units: Mesh `ESTAB`, 6 GHz US/CH37/EHT320, approximately `52.6°C / 56.7°C`.
- No `firmware crash`, `MCU timeout`, kernel panic, watchdog, UBI/I/O error, or `airtime_link_metric_get` was found in the collected logs.
- A reload or reboot can produce brief SAE authentication failures, Mesh disassociation, or PPPoE PADO timeouts; all recovered automatically during testing. This is not a zero-second handoff guarantee.
- The U-Boot HTTP upload fix is not embedded in the system image. Use the separate Release assets and [`uboot/`](uboot/) source notes.
