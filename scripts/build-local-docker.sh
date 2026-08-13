#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export GITHUB_WORKSPACE=/builder
# GNU tar's configure intentionally refuses uid 0 unless this documented
# override is set. GitHub Actions builds as an unprivileged user, while this
# local Docker helper intentionally uses the container's root user.
export FORCE_UNSAFE_CONFIGURE=1
# Do not inherit Windows PATH entries into OpenWrt/Go shell recipes.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

apt-get update -qq
# shellcheck disable=SC2046
apt-get install -y -qq $(tr -d '\r' < /builder/depends/ubuntu-22.04)

if [ ! -d /work/openwrt/.git ]; then
	git clone --filter=blob:none \
		--branch xr1710g-6.18-integration \
		https://github.com/YYH2913/openwrt.git /work/openwrt
fi

cd /work/openwrt
git fetch --depth=1 origin 99598e539d47aa9f137baff43f0c2f77becc2e50
git checkout 99598e539d47aa9f137baff43f0c2f77becc2e50
git clean -ffd

cp /builder/feeds.d/openwrt feeds.conf
cp -a /builder/files/. files/
cp -a /builder/apps/. package/
chmod 0755 files/etc/uci-defaults/99-custom.sh
chmod 0755 files/etc/uci-defaults/41_uhttpd_proxy_linkease
chmod 0755 files/etc/uci-defaults/zz-xr1710g-services.sh
chmod 0755 files/etc/init.d/xr1710g-bootlog
chmod 0755 files/etc/init.d/xr1710g-cpufreq
chmod 0755 files/etc/init.d/xr1710g-uboot-recovery-restore
chmod 0755 files/usr/sbin/xr1710g-mesh-diag
chmod 0755 files/usr/sbin/xr1710g-role
chmod 0755 files/usr/sbin/xr1710g-wan-carrier
chmod 0755 files/usr/sbin/xr1710g-wireless-defaults
chmod 0755 files/etc/openclash/core/clash_meta
chmod 0600 files/etc/crontabs/root
chmod 0755 package/luci-app-xr1710g-recovery/root/usr/libexec/rpcd/luci.xr1710g_recovery

sh /builder/scripts/test-xr1710g-tools.sh /builder

./scripts/feeds update -a
/builder/scripts/prepare-istore-feed.sh
XR_ISTORE_FIXTURE="$PWD/feeds/istore/luci/luci-app-store/root/bin/is-opkg" \
XR_QUICKSTART_FIXTURE="$PWD/feeds/linkease_nas_luci/luci/luci-app-quickstart/htdocs/luci-static/quickstart/index.js" \
  /builder/scripts/test-status-and-istore-safety.sh /builder
./scripts/feeds install -a

cp /builder/configs/openwrt.config .config
/builder/diy-part2.d/openwrt.sh
make defconfig

grep -qx 'CONFIG_PACKAGE_luci-app-store=y' .config
grep -qx 'CONFIG_PACKAGE_quickstart=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-quickstart=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-istorex=y' .config
grep -qx 'CONFIG_PACKAGE_luci-theme-argon=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-argon-config=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-openclash=y' .config
grep -qx 'CONFIG_PACKAGE_usteer=y' .config
grep -qx 'CONFIG_PACKAGE_wpad-mesh-openssl=y' .config

make download -j16
# Only remove failed top-level archive placeholders. Recursing into
# dl/go-mod-cache would delete legitimate small Go source files and corrupt
# packages such as yq.
find dl -maxdepth 1 -type f -size -1024c -delete

# Do not allow an incremental package cache to retain the v7 uhttpd binary.
# v8 adds iStoreOS' reviewed reverse-proxy stack to this package.
make package/network/services/uhttpd/clean
for xr_package in \
	luci-app-airoha-fancontrol \
	luci-app-airoha-flowsense \
	luci-app-airoha-npu \
	luci-app-xr1710g-recovery \
	xr1710g-status-core; do
	make "package/$xr_package/clean"
done
make -j16
for xr_stamp in \
	.luci-app-airoha-fancontrol_installed \
	.luci-app-airoha-flowsense_installed \
	.luci-app-airoha-npu_installed \
	.luci-app-xr1710g-recovery_installed \
	.luci-i18n-airoha-fancontrol-zh-cn_installed \
	.luci-i18n-airoha-flowsense-zh-cn_installed \
	.luci-i18n-airoha-npu-zh-cn_installed \
	.luci-i18n-xr1710g-recovery-zh-cn_installed \
	.xr1710g-status-core_installed; do
	rm -f "staging_dir/target-aarch64_cortex-a53_musl/root-airoha/stamp/$xr_stamp"
done
make package/install -j1
grep -Eq 'if ?\(oneShot\)' \
	build_dir/target-aarch64_cortex-a53_musl/root-airoha/www/luci-static/resources/view/system/xr1710g-recovery.js
grep -Eq "a.id ?!== ?'npu_bypass_latency'" \
	build_dir/target-aarch64_cortex-a53_musl/root-airoha/www/luci-static/resources/view/airoha_flowsense/status.js
bash /builder/scripts/rebuild-initramfs-recovery.sh "$PWD"
sh /builder/scripts/verify-xr1710g-build.sh "$PWD" 2>&1 | tee /work/verify.txt

sh /builder/scripts/package-release.sh "$PWD" /work/dist
