# XR1710G v1.1.0 公共发布清单

## Release仅保留

- `xr1710g-uboot-yyh2913-260712-flash-slot.bin`
- `xr1710g-community-v1.1.0-sysupgrade.itb`
- `SHA256SUMS.txt`
- `FLASHING-GUIDE.md`

不向普通用户上传initramfs调试镜像、manifest、profiles、内部verify日志、热修包、备份或迁移档案。

## 发布门禁

1. 双镜像本地构建 `VERIFY PASSED`，Sysupgrade与待上传文件SHA-256一致。
2. 楼上节点先完成实机刷写/升级、冷启动、三频、Mesh、Docker默认关闭、Dockerman提示、NPU/FlowSense和关键日志验收。
3. 主路由不因发布验收而重启或刷机。
4. 公开源码与系统镜像使用同一 `v1.1.0` 版本和同一提交范围，不暴露内部开发编号。
5. `FORUM-POST-ENSHAN.md` 与 `FORUM-POST-OPENWRT.md` 只留本地，不提交。
6. 隐私扫描不得包含密码、Token、MAC、公网地址、私有日志或完整用户配置。
7. GitHub Release说明必须写明社区非官方、XR1710G专用、UBI 2.0、XZ实验边界和正确U-Boot路径。

## 当前无线证据

- XZ/channel37/EHT320单跳802.11s，全程ESTAB。
- 约10分钟、20次双向4并发全部超过400Mbps，中位数约715/720Mbps。
- 满载后双向各600个空闲Ping均0%丢包。
- 无新增airtime、MT7996/MCU crash/timeout、Call Trace或设备重启。

该证据用于回程稳定性，不宣称两端2.5G有线客户端的极限吞吐。
