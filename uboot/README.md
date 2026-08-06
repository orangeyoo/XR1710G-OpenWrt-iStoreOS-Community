# XR1710G U-Boot / XR1710G U-Boot

## 中文

本项目发布的 U-Boot 来源于 [YYH2913/http-uboot](https://github.com/YYH2913/http-uboot)，适用于 Gemtek XR1710G。系统固件和 U-Boot 是两个独立的刷写对象；系统 `.itb` 不包含 U-Boot 分区内容。

### 我们重新改了什么

本目录的 RC1 补丁只修改恢复页面的大文件 HTTP 上传路径：

1. 将 TCP 接收窗口固定为 16 KiB，并关闭窗口缩放，限制突发数据。
2. 以每 16 ms 归还 8 KiB 的节奏释放接收额度，让浏览器通过 TCP 背压稳定上传约 76 MiB 的 XR1710G 镜像。
3. 在连接错误、取消或中断时清理定时器、半包和 POST 状态，使失败后可以立即重试。
4. 保留原有镜像校验、写入边界检查，以及“完整接收后才擦除/写入”的流程。

正式 YYH2913 U-Boot 二进制没有被本项目重新修改；RC1 是可复现的上传修复构建，发布前仍应在新设备上做真机验收。

### 重要刷写边界

- 只能刷 `*-flash-slot.bin`，不能把裸 `u-boot.bin` 或单独的 FIT 当作刷写文件。
- 不修改 Factory、EEPROM、caldata 或无线校准数据。
- 刷写前核对 Release 中的 SHA-256。
- RC1 在真机完成 Chrome/Edge 完整上传、取消后重试和正常启动验证前，不标记为稳定版。

构建基线、补丁和校验值见 [`SOURCE-COMMIT.txt`](SOURCE-COMMIT.txt)、[`patches/0001-httpd-pace-XR1710G-recovery-uploads.patch`](patches/0001-httpd-pace-XR1710G-recovery-uploads.patch) 与 Release 附带的构建说明。

## English

The U-Boot published by this project is derived from [YYH2913/http-uboot](https://github.com/YYH2913/http-uboot) for the Gemtek XR1710G. The system firmware and U-Boot are separate flashing objects; the system `.itb` does not contain the U-Boot partition.

### What we changed

The RC1 patch in this directory changes only the large-file HTTP upload path used by the recovery page:

1. Fix the TCP receive window at 16 KiB and disable window scaling to limit bursts.
2. Return 8 KiB of receive credit every 16 ms so normal browsers apply TCP backpressure and reliably upload the approximately 76 MiB XR1710G image.
3. On connection errors, cancellation, or interruption, clean up timers, partial buffers, and POST state so an upload can be retried immediately.
4. Preserve the existing image validation, write-boundary checks, and erase/write-after-complete behavior.

The official YYH2913 U-Boot binary was not otherwise modified by this project. RC1 is a reproducible upload-fix build and must be validated on a real new device before being called stable.

### Flashing boundaries

- Flash only the `*-flash-slot.bin` file. Do not flash a raw `u-boot.bin` or a standalone FIT as the slot image.
- Factory, EEPROM, caldata, and wireless calibration data are not modified.
- Verify the SHA-256 listed in the Release before flashing.
- RC1 remains experimental until Chrome/Edge full upload, cancel-and-retry, and normal boot are verified on hardware.
