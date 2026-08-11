# XR1710G 6 GHz laboratory regulatory material

## 中文

本目录保存上游设备适配分支曾使用的 6 GHz 实验室补丁，仅用于源码审计、复现和受控实验研究。

- 该补丁把本地 `US` 6 GHz 软件上限从 29 dBm 改为 36 dBm。
- 它不是 AFC（Automated Frequency Coordination，自动频率协调）实现。
- 它不能证明设备、地点、频道、带宽或使用方式获得 Standard Power 授权。
- XR1710G 的三个频段共用同一个 PHY，Linux `cfg80211` 最终只能对整个 PHY 应用一个监管域；网页中的三个 UCI 字段并不等于内核可以同时执行三套国家规则。
- 固件将实验能力隔离在用户自定义代码 `XZ` 下；它不是 AU、US 或任何国家监管域。
- `XZ` 是完整组合配置：2.4/5 GHz 精确继承本固件固定版本的 AU 规则，6 GHz 使用 36 dBm、NO-OUTDOOR、无 AFC 的实验规则，从而避免启用 XZ 后 2.4/5 GHz 频道全部不可用。
- `XZ` 默认关闭且绝不自动启用，只在 6 GHz Radio 的国家代码列表中明确标为组合实验选项；用户选择后，LuCI 会把 XZ 写入三张 Radio 配置，避免启动顺序把共享 PHY 监管域覆盖回其他值。默认仍为标准 US。
- 普通使用应选择设备实际使用地对应的标准 ISO 3166 国家码，并遵守当地法规。

主动选择 `XZ` 不代表获得 Standard Power 授权。用户必须自行确认受控实验室条件或其他合法
授权，并遵守所在地法规、频道及功率限制。

## English

This directory preserves a historical 6 GHz laboratory patch from the device adaptation branch for source audit, reproduction, and controlled research only.

- The patch changes the local `US` 6 GHz software ceiling from 29 dBm to 36 dBm.
- It is not an Automated Frequency Coordination (AFC) implementation.
- It does not establish Standard Power authorization for any device, location, channel, bandwidth, or operating mode.
- All three XR1710G bands share one PHY, and Linux `cfg80211` ultimately applies one regulatory domain to that entire PHY. Three UCI fields do not mean the kernel can enforce three country domains simultaneously.
- The firmware isolates the experimental capability under user-assigned code `XZ`; it is not AU, US, or any country domain.
- `XZ` is a complete composite profile: 2.4/5 GHz exactly inherit the AU rules from the pinned database, while 6 GHz uses the 36 dBm, NO-OUTDOOR, no-AFC laboratory rule. This keeps 2.4/5 GHz channels available when XZ is selected.
- `XZ` is off by default, is never selected automatically, and appears only on the 6 GHz radio with an explicit composite-laboratory label. Once selected, LuCI writes XZ to all three radio sections so startup order cannot replace the shared-PHY domain. Standard US remains the default.
- Normal operation should use the standard ISO 3166 country code for the actual location and comply with local rules.

Selecting `XZ` does not grant Standard Power authorization. The operator must establish controlled-laboratory conditions or other authorization and comply with all local channel and power rules.
