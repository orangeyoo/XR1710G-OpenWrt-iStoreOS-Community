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

---

# 为什么上传慢、什么镜像会被拒（Wiro U-Boot 门禁说明）

## 中文

Wiro U-Boot 的恢复页面在"确认上传"到"重启完成"之间做了多层检查。**每一层不过就立即失败、不写一个字节**。下面按顺序说明每一步在检测什么、为什么这么设计。

## 一、为什么上传这么慢？

上传慢是**故意限速**，不是故障：

- 原版 U-Boot 的网络栈（lwIP）在接收大文件时会卡死在 32–38 KB 处，这是它自身的缺陷。
- Wiro U-Boot 的解决办法是主动节流：**每 16 毫秒只放行 8 KB 数据**（约 500 KB/秒上限），并用固定 16 KB TCP 窗口关闭自动扩张，用背压代替突发。
- 这是实测能稳定传完 160+ MB 系统镜像的唯一可靠方式。速度换稳定——宁可用 5 分钟传完，也不要中途卡死重来。

## 二、上传开始前会拒绝什么？

| 检查 | 不通过的处理 |
|---|---|
| 请求地址必须精确匹配 `/upload/firmware`（带 build 和 layout 参数）或 `/upload/uboot`（带 build 参数） | 拒绝（参数缺失/重复/多余/路径穿越/编码绕道一律拒绝） |
| 页面必须先向 `/about` 验证过服务端版本号，POST 里的 build ID 必须与服务端完全一致 | 拒绝（防止旧缓存页面误操作） |
| 正在进行的上传未结束 | 拒绝新任务（防重复提交） |

## 三、镜像内容校验——"别人的固件刷不进"通常是这一步

收完整个文件后、擦写任何一个字节前，逐项校验：

| 校验项 | 要求 | 常见被拒原因 |
|---|---|---|
| 设备型号 | 必须是 XR1710G（按设备树 compatible 判定） | 刷错设备的镜像 |
| 文件格式 | 必须是合法 FIT/ITB 格式，结构完整、无多余尾部数据 | 传了裸 `.bin`/`.img`/重打包文件 |
| 组件完整性 | 内核、设备树等每个组件边界正确、不重叠、加载地址合法 | 重新打包过、截断或拼接的镜像 |
| **强哈希** | **每个组件至少带一个 SHA-1 或 SHA-256 哈希**（CRC32 可以并存但不算强哈希）；哈希值必须与内容一致 | 他人固件最常栽在这：只有 CRC32、或哈希对不上 |
| 布局匹配 | 系统镜像所选 UBI 布局（2.0/1.5/1.0）必须与镜像内嵌分区一致 | 拿 1.0/1.5 布局的镜像选了 2.0 |
| U-Boot 槽镜像 | 必须是完整的 flash-slot 封装（Legacy 头 + CRC + FIT 三组件拓扑），且每组件带强哈希 | 传裸 `u-boot.bin`/`u-boot.img`/未封装 chainloader |

**没有版本白名单**：不是"只认自家固件"。任何第三方 XR1710G 镜像，只要满足上面全部条件（FIT 结构 + 每组件强哈希 + 布局正确），都可以直接刷。不满足的拒绝原因是结构缺陷，不是排他。

## 四、写入阶段检测什么？

全部校验通过后才开始写入，期间仍然逐步验证：

1. **U-Boot 更新**：整 1 MiB 槽位先全擦 → 写入 → **逐字节读回比对** → 槽尾必须是全 0xFF。
2. **系统双清**：擦除重建所选 UBI 布局 → 写入 FIT → **固定缓冲零动态分配读回全部字节**（防内存耗尽半途而废）→ Factory 区从只读 DSD 重建并读回 → 双份环境变量逐一清零并读回。
3. **任何一步失败**：立即停止、锁死状态、不自动重启、不允许重试——只能重新进 Recovery 从头开始。**绝不标记坏块**、绝不动 Factory/EEPROM/DSD/校准数据。
4. **全部成功**：页面到 100%，确认后 3 秒（兜底 30 秒）重启。

## 五、给刷第三方固件失败的用户的排查顺序

1. 确认镜像是 **XR1710G 专用**的 FIT/ITB 文件（不是别的机型、不是裸 bin）；
2. 确认镜像**每个组件带 SHA-1/SHA-256 哈希**（最常见失败原因：只有 CRC32）；
3. 确认 UBI 布局选择与镜像一致（本项目固件全部是 **UBI 2.0**）；
4. 校验文件 SHA-256 与发布页一致（排除下载损坏）；
5. 都满足仍被拒的，把页面显示的 `error_stage`/`validation_detail` 记下来反馈——那就是精确的拒绝原因。

## English

## Why uploads are slow, and which images are rejected

The Wiro U-Boot recovery page runs layered checks between "confirm" and "reboot", and **fails immediately without writing a single byte** whenever a layer does not pass.

### Why is uploading slow?

It is **deliberate throttling**, not a fault. The stock lwIP stack stalls at 32–38 KB on large uploads, so Wiro U-Boot releases only **8 KB every 16 ms** (≈500 KB/s ceiling) with a fixed 16 KB TCP window and no auto-growth — the only method proven to reliably transfer 160+ MB images. Stability over speed.

### What is checked before anything is written?

- Request URI must match exactly, with matching build ID verified against `/about`; concurrent uploads are refused.
- Image must be a structurally valid FIT/ITB for **XR1710G** (board compatibility check).
- Every FIT component needs boundaries/load addresses that are legal, and **at least one enforced SHA-1 or SHA-256 hash that matches its content** (CRC32 may accompany but never substitutes).
- The selected UBI layout (2.0/1.5/1.0) must match the image's embedded layout.
- U-Boot slot images must be complete flash-slot packages (legacy header + CRC + FIT topology + strong hashes). Raw `u-boot.bin`/`u-boot.img` are rejected.

**There is no vendor whitelist**: any third-party XR1710G image that satisfies all of the above flashes fine. Rejections are structural, not exclusionary.

### What is verified during the write?

Full erase → write → **byte-for-byte readback** (U-Boot slot, including all-0xFF tail check); system rebuild reads back every FIT/Factory byte using fixed buffers, restores Factory from the read-only DSD, and wipes both environment copies with readback. Any failure latches: no auto-retry, no reboot, bad-block tables are never touched, and Factory/EEPROM/caldata are never modified. Only complete success reaches 100% and reboots.

### Troubleshooting order for failed third-party flashes

1. the image is an XR1710G FIT/ITB (not another model, not a raw .bin);
2. every component carries a SHA-1/SHA-256 hash (the most common failure: CRC32-only);
3. the UBI layout matches the image (this project's images are all UBI 2.0);
4. the downloaded file's SHA-256 matches the release page;
5. if all pass and it still fails, report the on-page `error_stage`/`validation_detail` — that is the precise rejection reason.
