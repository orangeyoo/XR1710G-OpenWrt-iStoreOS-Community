#!/bin/bash
# Immortalwrt DIY part2
# — 在 .config 加载之后、make 之前运行 —

# =================================================================
# 步骤 1：【最先执行】加载你的第三方插件包配置（包含你的 mihomo 配置）
# =================================================================
PKG_CONF="$GITHUB_WORKSPACE/packages/immortalwrt.conf"
if [ -f "$PKG_CONF" ]; then
    grep -v '^#' "$PKG_CONF" | grep -v '^$' >> .config
    echo "已成功加载第三方插件配置"
fi

# =================================================================
# 步骤 2：【彻底物理删除】你不想要的 luci-app-clientstatus
# =================================================================
echo "正在物理剔除 clientstatus 组件..."
rm -rf feeds/luci/applications/luci-app-clientstatus
rm -rf package/feeds/luci/luci-app-clientstatus

# =================================================================
# 步骤 3：移除缺失依赖的 sdl3 游戏残余组件，消除满屏报错
# =================================================================
rm -rf package/feeds/video/sdl3
rm -rf package/feeds/video/sdl2-compat
rm -rf package/feeds/video/sdl3-*
rm -rf feeds/video/video/sdl3*

# =================================================================
# 步骤 4：替换 libffi 源码，避开 aarch64 路径匹配 Bug
# =================================================================
echo "正在降级替换 libffi 源码..."
rm -rf feeds/packages/libs/libffi
git clone https://github.com/openwrt/packages.git tmp/openwrt-packages --depth=1
cp -r tmp/openwrt-packages/libs/libffi feeds/packages/libs/
rm -rf tmp/openwrt-packages

# =================================================================
# 步骤 5：【最后兜底】从 .config 中强行抹除 clientstatus 冲突条目
# =================================================================
sed -i '/CONFIG_PACKAGE_luci-i18n-clientstatus-zh-cn/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-clientstatus/d' .config
sed -i '/CONFIG_PACKAGE_mihomo-alpha/d' .config
