# XR1710G v1.9

- 修正 EHT320 模式下的无线速率能力配置。
- 修复以太网收包处理及 LRO 状态管理问题，LRO 默认关闭。
- 整理 MLO 页面与初始化配置，三频各自单链路，默认开启 MLO。
- 修复首次启动无线配置覆盖：2.4G 使用 EHT20，5G/6G 默认 EHT160。
- 补齐 6GHz OWE 支持，修复相关配置报错。
- 修复固件升级后网页资源缓存导致的旧页面问题。

Mesh 回程请关闭 MLO；MLO + WDS 桥接仍有兼容性问题。

切换国家码后若 5GHz 异常，请重启 5GHz 无线并等待 DFS 检查完成。

本次仅发布固件和校验文件，源码计划随下一版本公布。

附带原版 Wiro U-Boot v1.0.0（`xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin`），仅用于“更新 U-Boot”；已有该版本无需重刷。[使用与许可证说明](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0)。
