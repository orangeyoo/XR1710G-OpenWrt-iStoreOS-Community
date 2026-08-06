# XR1710G：U-Boot 与系统固件刷写说明

## 先区分两个文件

### 1. U-Boot/chainloader

推荐使用 YYH2913 正式发布的：

```text
Release: 260712
Source commit: ab7fd65100f1f1fb14e1555dcc6a630985b4194a
File: xr1710g-uboot-v2026.07-ab7fd651-flash-slot.bin
Size: 908722 bytes
SHA256: 44e8911c55d3e8f2a8be1befb8a8d892047780ab46850057949a661ec2e45953
```

上游地址：

- https://github.com/YYH2913/http-uboot/releases/tag/260712
- https://github.com/YYH2913/http-uboot/releases/download/260712/xr1710g-uboot-v2026.07-ab7fd651-flash-slot.bin

这是写入 XR1710G `chainloader`/旧 `tclinux` 头部的 Bootloader 镜像。
不要使用 `u-boot.bin`、`u-boot.img`、W1700K chainloader、Airoha EVB
preloader/FIP。

### 2. iStoreOS 社区系统固件

本项目生成的是：

```text
*-squashfs-sysupgrade.itb
```

这是在 HTTP U-Boot 网页里选择 `Firmware` 后上传的系统固件，不是
Bootloader。

`*-initramfs-recovery.itb` 是 RAM/Recovery 调试镜像。使用 YYH2913 HTTP
Recovery 网页正常安装系统时，不上传这个文件。

## 你已经有 YYH2913 HTTP U-Boot 时

如果能进入 `http://192.168.255.1`，先观察页面。

### 页面已有 UBI 2.0/1.5/1.0 选择器

不需要重复升级 U-Boot，直接刷系统：

1. 目标选择 `Firmware`，不是 `U-Boot`。
2. 布局选择 `UBI 2.0 - 439 MiB`。
3. 上传本项目的 `*-squashfs-sysupgrade.itb`。
4. 确认开始后不要断电。

本固件内嵌 DTB 已验证为：

```text
ubi = <0x00700000 0x1b700000>
```

它对应且只能选择 `UBI 2.0`。网页选择器不会转换镜像布局；选错布局可能造成
`not enough PEBs` 或启动时一直等待 `/dev/fit0`。

这次操作会完整擦除并重建所选 UBI，重新创建 `ubootenv`、`ubootenv2`、
`fit` 和 `rootfs_data`。现有 OpenWrt/iStoreOS 配置不会保留。Factory
EEPROM/MAC 数据由 U-Boot 从 vendor DSD 区恢复。

### 页面没有布局选择器，但有 `Update U-Boot`/`U-Boot` 目标

先升级 U-Boot：

1. 目标选择 `U-Boot`。
2. 上传
   `xr1710g-uboot-v2026.07-ab7fd651-flash-slot.bin`。
3. 等待写入和重启完成，不能断电。
4. 再次进入 `http://192.168.255.1`。
5. 确认页面出现 UBI 2.0/1.5/1.0 选择器。
6. 按上一节选择 `Firmware` + `UBI 2.0`，上传 sysupgrade 镜像。

不要把 U-Boot 的 `*-flash-slot.bin` 上传到 `Firmware`，也不要把系统
sysupgrade 镜像上传到 `U-Boot`。

## 进入 HTTP Recovery

1. 电脑连接 XR1710G 的 10GbE 网口。
2. 电脑网卡设为自动获取地址（DHCP）。
3. 路由器上电。
4. 10GbE 指示灯开始闪烁后，按住 Reset。
5. 状态灯从常亮红色变为流动效果后松开。
6. 浏览器打开 `http://192.168.255.1`。

## 如果现在还是原厂 U-Boot

原厂 U-Boot 没有上述 HTTP Recovery 页面时，不能直接套用网页升级步骤。
`flash-slot.bin` 的首次安装位置取决于当前 MTD 布局及第一阶段
`bootcmd`。先取得：

```sh
ubus call system board
cat /proc/mtd
fw_printenv
```

如果能够接串口，还应取得：

```text
version
printenv bootcmd loadaddr fdt_high
```

只有确认仍是旧布局并且 `tclinux` 确实对应 `/dev/mtd5` 时，才可能使用上游
文档中的“只备份、擦除并写入 tclinux 前 1 MiB”迁移方式。不能仅凭另一台
XR1710G 的 MTD 编号直接执行 `flash_erase`/`nandwrite`。

## 本地静态验收

交付包中的 U-Boot 文件已验证：

```text
offset 0x0000: 27 05 19 56  (legacy uImage magic)
offset 0x2100: d0 0d fe ed  (FIT/FDT magic)
embedded version: U-Boot 2026.07-00760-gab7fd65100f1
HTTP recovery: 192.168.255.1
layouts: UBI 2.0, UBI 1.5, UBI 1.0
```

这只是文件结构与上游哈希验收，不等于已在你的两台设备上完成真机验证。

