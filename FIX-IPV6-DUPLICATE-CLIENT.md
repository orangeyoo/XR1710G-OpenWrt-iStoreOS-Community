# v1.6.0 DHCPv6 / MT7996 fixes

## 中文

已从实际公开 v1.5.0 镜像确认同类触发路径仍在：PPPoE 的自动 IPv6 子接口与手动 DHCPv6 接口绑定同一个 L3 设备，两个 odhcp6c 争用同名 ubus 对象，失败客户端不断重启。不是所有安装都会触发，也不是 IPv6 本身不稳定。

修复仅抑制重复实例，不关闭 IPv6、不删除用户配置、不重启正常客户端：

- PPP IPv6 hook 检查显式、启用且自动启动的 DHCPv6 接口，覆盖自定义名称、`device`/旧 `ifname`、`@wan`/直接设备及有界别名链。
- DHCPv6 启动前检查同设备已存在的 netifd 客户端；重复逻辑接口报 `DHCPV6_DUPLICATE_CLIENT` 并阻止自动重试。修正重复配置后，用对应接口的重新连接操作恢复；不会自动停止另一个正常客户端。
- 手动启动且未带 netifd `INTERFACE` 环境变量的第三方 odhcp6c 不能可靠归属，不杀进程；此场景不宣称完整覆盖。
- 普通 PPP 自动 IPv6、独立接口、原接口自身重启和续租路径保持不变。

驱动保留 b2704cf5、AN7581/NPU 适配和既有 10G 本机流量保护，回移两项官方 mt76 修复（包 release 6 → 7）：

1. [d73f612](https://github.com/openwrt/mt76/commit/d73f61254a7957466831cf5b8b10afefca7144ae)：MCU 拒绝 TWT 协议时摘除已挂入的链表节点，避免后续链表损坏/释放后使用。
2. [0898393](https://github.com/openwrt/mt76/commit/0898393ee0a0b881e4dcccf820d7f69546032709)：断开关联后的管理帧使用 ALTX 队列，避免滞留普通缓冲队列。

寄存器零地址修复经核对已存在于准备好的基线，不重复添加。WED/RRO 改动不等同于本平台的 Airoha PPE，未盲目混入；没有整体更新内核、mac80211、hostapd、EEPROM 或监管规则。补丁保留完整上游作者和签署信息。没有证据声称这两项修复能直接提高峰值吞吐。

出厂密码仍为 `password`，无线默认及空密钥规则保持 v1.5；不把家庭 160MHz/FT/密码配置写入镜像。U-Boot 不变。构建工作树新增二进制 Git 属性，避免 Windows checkout 把原有 Clash 内核当文本改换行；不更新 Clash 内核本身。

验收：离线回归、编译和实际镜像差异核验通过；先楼上后主路由，两台刷后基本检查通过，主路由PPPoE/IPv6正常、仅一个稳定DHCPv6客户端，无重复注册报错。5GHz160和6GHz320 Mesh正常。长期游戏/漫游/压力测试及断电冷启动未作为本次完整验收项目。

## English

The released v1.5 image contains the duplicate-client path: PPP automatic IPv6 and an explicitly configured DHCPv6 interface can launch two odhcp6c instances on one L3 device. Their per-device ubus object registration collides and the unsuccessful client repeatedly restarts.

The fix preserves IPv6 and the working client. The PPP hook skips automatic child creation when an enabled, auto-start explicit DHCPv6 interface targets that link. A setup-time guard blocks another netifd-owned client on the same device, reporting `DHCPV6_DUPLICATE_CLIENT`. Correct the duplicate configuration and reconnect that interface to retry. Unowned, manually launched third-party processes are not killed or claimed as fully covered.

The b2704cf5 driver base, board integration and existing 10G/PPE protection remain. Two official mt76 fixes are backported: failed-TWT list cleanup (d73f612) and ALTX queue selection for disassociated stations (0898393). Original attribution is retained. No wholesale kernel/mac80211/hostapd or regulatory update, and no claimed throughput gain without measurement.

Factory defaults, existing-password retention, plugins and U-Boot stay unchanged. Offline/build/image checks passed, followed by post-flash basic checks on both units. Main-router PPPoE/IPv6 recovered with one stable DHCPv6 client and no duplicate-registration errors; 5GHz160 and 6GHz320 Mesh worked. Long-term gaming/roaming/stress and power-off cold-boot testing are not claimed as completed.
