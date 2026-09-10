# v1.6.1 Wi-Fi 稳定性修复说明 / Wi-Fi stability fixes for v1.6.1

状态 Status：源码已完成，离线门禁通过；**尚未构建镜像、尚未实机验收**。
Source complete and offline-checked; **no image built, no on-device
acceptance yet**.

## 背景 Background

2026-09-10 对 v1.6 双机只读诊断（记忆第 135 节）确认：5GHz 手机频繁断线
不是驱动层故障，而是三个叠加因素——

1. iPhone 每次跨 AP 漫游都退回全量 SAE 认证（`ft_over_ds='0'` 只允许
   over-the-air FT，而 Apple 终端惯用 FT-over-DS），弱信号下认证响应
   无法被确认，日志中 66 次 `did not acknowledge authentication
   response` 全部来自同一台手机；
2. 手机同时弱信号关联两台 AP（-79/-84 dBm）乒乓漫游；
3. 楼上节点 WAN 口空置，内核 `airoha-pcs` 诊断补丁以每秒约 2 条的
   限速上限持续刷 `USXGMII AN down`，约 8 分钟就把节点 logread 环形
   缓冲冲空，完全失去节点侧排查能力。

v1.6.0 已实机验证 `ft_over_ds='1'` 热修（记忆第 136 节）：两台 wifi
reload 后 FT-over-DS 生效、无新增认证失败、PPPoE 未重拨。本版把该
结论固化进镜像，并一并修复排查中发现的其余 Wi-Fi 相关问题。

## 修复内容 Fixes

### 1. 0923 补丁修订：PCS 日志改为状态跳变才打印
`patches/kernel/0923-net-pcs-airoha-an7581-rx-lock-diagnostics.patch`

- `USXGMII AN down` 与 `no-signal` 两条稳态诊断改为每个 down/no-signal
  周期只打印一次（新增 `rxlock_link_down_reported[]` /
  `rxlock_no_signal_reported[]` 状态跟踪）；link 恢复后状态复位，下次
  掉线仍会报告。
- 真实异常事件 `cdr-reset` 诊断保持每次打印，RX-lock 恢复逻辑不变。
- 验收标准：节点 WAN 口空置运行 10 分钟，该两条消息各 ≤1 条，
  hostapd 历史不再被冲掉。

### 2. FT-over-DS 默认值与升级迁移
- `files/usr/sbin/xr1710g-wireless-defaults`：5GHz 首启策略
  `ft_over_ds` 由 `'0'` 改 `'1'`（FT-over-DS 与 over-the-air 同时可用，
  Apple 终端漫游不再退回全量认证）。
- 新增 `files/etc/uci-defaults/98-xr1710g-ft-over-ds`：保留配置升级时，
  仅对已启用 802.11r 且 `ft_over_ds='0'` 的接口迁移为 `'1'`；密钥、
  信道、SSID 等用户配置全部保留；mesh/非 FT 接口不动。

### 3. LuCI 应用回滚窗口 90→300 秒
- 新增 `files/etc/uci-defaults/98-xr1710g-luci-apply-window`：仅当
  `luci.apply.rollback` 为出厂值 90（或缺失）时设为 300，用户自定义
  值保留。
- 动机：社区 EHT160 "配置自动回退"反馈的已知触发链——ch36/EHT160 切换
  需 ~60 秒 CAC，无线管理会话 90 秒确认窗口先到，LuCI 自动回滚，用户
  看到 160 被改回 80。300 秒窗口覆盖 CAC + 重连。该修复只消除回滚
  误伤，不改变 v1.5 已修复的后台 CAC 启动故障本身。

### 4. MLO 页面隐藏 802.11s Mesh 接口
`patches/luci/0660-xr1710g-mlo-hide-mesh-ifaces.patch`（应用于
feeds/base/luci-app-mlo，diy-part2.d/openwrt.sh 已接线）

- MLO 编辑器网格过滤 `mode='mesh'` 接口，杜绝把 6GHz 回程 Mesh 接口
  误改成 AP/STA 导致回程损坏（2026-08-14 记忆已标记该风险）。
- 存在 Mesh 接口时页面显示提示：Mesh 回程请在 网络→无线 管理。
- 注：提示文案为英文（第三方应用未含 zh_Hans 翻译条目）。

## 门禁 Gates

- `test-xr1710g-tools.sh`：新增 0923 跳变标记断言、MLO 补丁断言、
  首启策略 `ft_over_ds=1` 断言。
- `test-wireless-defaults.sh`：新增两个迁移脚本的完整用例（错误板型
  不动、仅 FT 接口迁移、用户值保留、幂等、90→300/自定义值保留/缺失
  补建路径）。
- `verify-xr1710g-build.sh`：两个迁移脚本与 mlo.js 进入双 rootfs 抽取
  与逐字节比对清单；镜像内容断言（迁移语义、`'90'` 门禁、mesh 过滤
  标记）；首启 `ft_over_ds='1'` 镜像断言。
- 0923/0660 补丁均通过干净基线 `patch --dry-run`、应用结果与预期
  逐字节一致、已打补丁源码上拒绝重复应用；0660 通过 `node --check`。

## 边界 Boundaries

- `luci.apply=internal` 节缺失时的补建分支无法被 mock-uci 用例覆盖
  （mock 的 get 不会失败），实机验收时覆盖。
- FT-over-DS 对 Apple 漫游的收益已由 2026-09-10 热修实机背书；1.6.1
  镜像刷入后仍需按序验收（先楼上节点）。
- 未改动 mt76 驱动、hostapd、监管档、功率与 U-Boot。
