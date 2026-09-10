# v1.6 后台升级修复 / Backend upgrade fix

## 中文

此修复已合并到正式1.6，没有建立1.7。发布系统SHA-256为71f214f1f9341bab9e9245a85bdec8db6ef26b4bac3a1b587381aa2487aa9a38；此前不含此项的本地候选未发布。

旧 LuCI 通过普通 `file.exec` 同步执行 sysupgrade。主路由配置备份单独实测约29秒，加上镜像校验，超过 rpcd 30秒执行期限。安全的“仅校验+仅备份”复现也在30秒被中断；页面忽略错误并持续等待重连。

修复只把确认后的升级交给独立后台任务，普通 RPC 超时不变，原生 sysupgrade 的镜像签名、分区布局校验、配置备份和升级选项不变。页面在准备阶段查询状态；失败显示退出码和日志，断网只视为状态未知/可能重启，不能据此宣称成功。任务互斥，不自动重试；失败需人工确认后才能重新提交。后台任务一旦提交，关闭网页不会取消，请勿断电。

**旧系统执行的是旧升级入口。** 新镜像不能自行修复正在运行的旧系统。若旧版后台超时，应安排维护窗口后修补旧入口或经受控 SSH 升级；不要反复点刷写，也不需要为此升级 U-Boot。

本轮无额外驱动、无线、CPU/NPU、插件、分区或 U-Boot 更改。原1.6的IPv6去重及两项mt76修复仍保留。离线模拟不替代真实刷后验收。

## English

This fix is included in v1.6, not a new v1.7. The released image SHA-256 is 71f214f1f9341bab9e9245a85bdec8db6ef26b4bac3a1b587381aa2487aa9a38; the earlier candidate without this fix was not published.

The old LuCI upgrade action ran sysupgrade through synchronous `file.exec`. Configuration backup alone took about 29 seconds on the main router; image validation pushed preparation past rpcd's 30-second limit. A validation-and-backup-only reproduction timed out at 30 seconds, while the page discarded the error and waited for reconnection.

The confirmed upgrade now runs in a detached task. Ordinary RPC timeouts and native image/layout validation, backup and upgrade options are retained. The page polls preparation status, displays explicit failures and treats connection loss as uncertainty, not verified success. Jobs are mutually exclusive and never automatically retried. Closing the page does not cancel a submitted upgrade. Do not power off.

An old installation still runs its old upgrade entrypoint. Installing a fixed image cannot repair that entrypoint beforehand: schedule a maintenance window for a controlled entrypoint hotfix or SSH upgrade if the old page times out. This issue does not require a U-Boot update.

No additional wireless, driver, CPU/NPU, plugin, partition or U-Boot changes are included. The existing v1.6 IPv6 and two mt76 fixes remain. Offline simulations do not replace post-flash device acceptance.
