# Translation Audit / 翻译审计

## 中文

本审计覆盖本项目自定义的三个 LuCI 页面：Airoha 风扇控制、Airoha FlowSense 和 Airoha NPU。

- 英文不依赖单独的 `luci-i18n-*-en` 包，LuCI 的英文基线由 LuCI 自身提供。
- 构建配置启用了 `CONFIG_LUCI_LANG_zh_Hans` 和基础中文包，首启脚本只在第一次初始化时将界面设为 `zh_cn`。
- 自定义页面使用英文 `msgid`，中文通过 `zh_Hans` PO 文件覆盖；切换 English 后未翻译的文本会保持英文，不会显示中文硬编码。
- 已修正 NPU 页面中缺失的 Direct PLL、Error、Failed、CPU set to 翻译，并修正 SoC 状态和控制设置措辞。
- 已让 FlowSense 的 BND FLOWS 和 UNB FLOWS 图表标签经过 LuCI 翻译函数。
- 风扇控制页面的温度、PWM、曲线和无线频段条目已覆盖中文翻译。

目前没有声称第三方插件的中文翻译经过本项目重新翻译；它们使用对应上游的 `luci-i18n-*-zh-cn` 包。最终发布前仍应在构建后的镜像中分别选择中文和 English 做一次页面截图验收。

## English

This audit covers the three LuCI pages maintained by this project: Airoha Fan Control, Airoha FlowSense, and Airoha NPU.

- English does not require separate `luci-i18n-*-en` packages; LuCI provides the English baseline itself.
- The build enables `CONFIG_LUCI_LANG_zh_Hans` and the base Chinese package. The first-boot script sets `zh_cn` only during initial UCI initialization.
- Custom pages use English `msgid` strings and Chinese `zh_Hans` PO overrides. After selecting English, untranslated strings remain English rather than falling back to hard-coded Chinese.
- Added missing translations for the NPU Direct PLL, Error, Failed, and CPU set to strings, and corrected the SoC status and control-settings wording.
- Routed the FlowSense BND FLOWS and UNB FLOWS chart labels through the LuCI translation function.
- Fan Control temperature, PWM, curve, and radio-band labels have Chinese translations.

This project does not claim to retranslate every third-party plugin. Those pages use their upstream `luci-i18n-*-zh-cn` packages. Before the corrected source is released as a new image, select both Chinese and English in the built image and perform a visual page check.
