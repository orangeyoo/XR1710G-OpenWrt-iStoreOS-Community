# XR1710G U-Boot Source and Compatibility Note

The user-facing flashing paths are maintained in
[FLASHING-GUIDE.md](FLASHING-GUIDE.md). This file records the source and
technical boundary of the U-Boot slot image.

## 中文

Release 中的正式文件名为：

```text
xr1710g-uboot-flash-slot.bin
```

它基于 [YYH2913/http-uboot](https://github.com/YYH2913/http-uboot)，只对
XR1710G HTTP Recovery 的大文件上传路径加入节流与安全中断清理：

- TCP 接收窗口固定为 16 KiB，并关闭窗口缩放，限制突发数据。
- 每 16 ms 归还 8 KiB 接收额度，通过 TCP 背压控制上传速度。
- 连接失败、取消或中断时清理定时器、半包和 POST 状态。
- 保留镜像校验、写入边界检查和“完整接收后才擦除/写入”。

实机已完成静态地址 Recovery 页面访问、约 138.6 MB 系统镜像完整刷写和
正常启动；中断上传不会提前开始擦写。不同浏览器、网卡或链路环境仍可能存在
差异，因此刷写时必须直连有线、核对 SHA-256，并保持稳定供电。

进入 Recovery 后，电脑手动设置：

```text
IPv4: 192.168.255.2
Netmask: 255.255.255.0
Gateway: empty
Recovery: http://192.168.255.1/
```

只可在 **Update U-Boot** 页面刷入 `xr1710g-uboot-flash-slot.bin`。不要把
系统 ITB、Recovery ITB、裸 `u-boot.bin` 或独立 FIT 刷入 U-Boot 槽位。
该文件不会修改 Factory、EEPROM、caldata 或无线校准数据。

## English

The formal Release filename is:

```text
xr1710g-uboot-flash-slot.bin
```

It is based on
[YYH2913/http-uboot](https://github.com/YYH2913/http-uboot) and changes only
the XR1710G HTTP Recovery large-upload path:

- Fix the TCP receive window at 16 KiB and disable window scaling.
- Return 8 KiB of receive credit every 16 ms to apply TCP backpressure.
- Clean timers, partial buffers, and POST state after an error, cancellation,
  or interruption.
- Preserve image validation, write-boundary checks, and erase/write only after
  the complete image has been received.

Hardware testing covered the static-address Recovery page, a complete
approximately 138.6 MB system-image flash, and a normal boot. An interrupted
upload did not start an early erase. Browser, adapter, and link behavior can
still vary, so use a direct wired connection, verify SHA-256, and provide
stable power.

Configure the computer manually after entering Recovery:

```text
IPv4: 192.168.255.2
Netmask: 255.255.255.0
Gateway: empty
Recovery: http://192.168.255.1/
```

Flash only `xr1710g-uboot-flash-slot.bin` on **Update U-Boot**. Never put a
system ITB, Recovery ITB, raw `u-boot.bin`, or standalone FIT into the U-Boot
slot. The slot image does not modify Factory, EEPROM, caldata, or wireless
calibration data.
