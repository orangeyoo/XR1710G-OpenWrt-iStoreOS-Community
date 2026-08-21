# XR1710G U-Boot / XR1710G U-Boot

## 中文

本项目发布的 U-Boot 来源于 [YYH2913/http-uboot](https://github.com/YYH2913/http-uboot)，适用于 Gemtek XR1710G。系统固件和 U-Boot 是两个独立的刷写对象；系统 `.itb` 不包含 U-Boot 分区内容。

### 我们重新改了什么

本目录的社区补丁只修改恢复页面的大文件 HTTP 上传路径：

1. 将 TCP 接收窗口固定为 16 KiB，并关闭窗口缩放，限制突发数据。
2. 以每 16 ms 归还 8 KiB 的节奏释放接收额度，让上传客户端通过 TCP 背压控制突发流量。
3. 在连接错误、取消或中断时清理定时器、半包和 POST 状态，使失败后可以立即重试。
4. 保留原有镜像校验、写入边界检查，以及“完整接收后才擦除/写入”的流程。

除上述上传路径外，本项目不改变 YYH2913 的镜像校验、分区写入和恢复布局逻辑。实机已经完成静态地址 Recovery 页面访问、约 138.6 MB 系统镜像完整刷写和正常启动；中断上传不会提前开始擦写。不同浏览器、网卡和链路环境仍可能存在差异。

### 重要刷写边界

- 只能刷 `*-flash-slot.bin`，不能把裸 `u-boot.bin` 或单独的 FIT 当作刷写文件。
- 不修改 Factory、EEPROM、caldata 或无线校准数据。
- 刷写前核对 Release 中的 SHA-256。
- 进入 Recovery 后手动把电脑设置为 `192.168.255.2/24`，访问 `http://192.168.255.1/`。
- 不把某一种浏览器或网卡的结果扩展成所有客户端均可用的保证。

构建基线、补丁和校验值见 [`SOURCE-COMMIT.txt`](SOURCE-COMMIT.txt)、[`patches/0001-httpd-pace-XR1710G-recovery-uploads.patch`](patches/0001-httpd-pace-XR1710G-recovery-uploads.patch) 与 Release 附带的构建说明。

## English

The U-Boot published by this project is derived from [YYH2913/http-uboot](https://github.com/YYH2913/http-uboot) for the Gemtek XR1710G. The system firmware and U-Boot are separate flashing objects; the system `.itb` does not contain the U-Boot partition.

### What we changed

The community patch in this directory changes only the large-file HTTP upload path used by the recovery page:

1. Fix the TCP receive window at 16 KiB and disable window scaling to limit bursts.
2. Return 8 KiB of receive credit every 16 ms so upload clients apply TCP backpressure instead of sending an uncontrolled burst.
3. On connection errors, cancellation, or interruption, clean up timers, partial buffers, and POST state so an upload can be retried immediately.
4. Preserve the existing image validation, write-boundary checks, and erase/write-after-complete behavior.

Outside this upload path, the project does not change YYH2913 image validation, partition-writing, or recovery-layout behavior. Hardware testing covered the static-address Recovery page, a complete approximately 138.6 MB system-image flash, and a normal boot. An interrupted upload did not start an early erase. Browser, adapter, and link behavior can still vary.

### Flashing boundaries

- Flash only the `*-flash-slot.bin` file. Do not flash a raw `u-boot.bin` or a standalone FIT as the slot image.
- Factory, EEPROM, caldata, and wireless calibration data are not modified.
- Verify the SHA-256 listed in the Release before flashing.
- Configure the computer manually as `192.168.255.2/24` after entering Recovery and open `http://192.168.255.1/`.
- Do not generalize one browser or network adapter result into a guarantee for every client.
