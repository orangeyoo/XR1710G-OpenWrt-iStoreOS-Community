#!/bin/bash
set -euo pipefail

export FORCE_UNSAFE_CONFIGURE=1
export GITHUB_WORKSPACE=/builder
# WSL may append Windows application paths containing spaces or parentheses.
# OpenWrt embeds PATH in unquoted Go build recipes, so keep this build hermetic
# and Linux-only. Host and cross-tool paths are prepended by OpenWrt itself.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

cd /work/openwrt
# A failed run must not leave a previous VERIFY PASSED log that can be mistaken
# for the current image set. The verifier recreates this file near the end.
rm -f /work/verify.txt
# Return only this disposable compiler worktree to its pinned source state.
# Downloads, feeds, toolchains and build caches are ignored by Git and remain.
git restore --source=HEAD --worktree --staged .
git clean -ffd
git fetch --depth=1 origin 99598e539d47aa9f137baff43f0c2f77becc2e50
git checkout 99598e539d47aa9f137baff43f0c2f77becc2e50
# Target output survives in the persistent compiler volume. Remove only prior
# XR1710G deliverables and aggregate metadata before this release run so the
# verifier can never pair a newly built recovery with an older sysupgrade.
find bin/targets/airoha/an7581 -maxdepth 1 -type f \
	\( -name '*econet_xr1710g-ubi-initramfs-recovery.itb' \
	-o -name '*econet_xr1710g-ubi-squashfs-sysupgrade.itb' \
	-o -name '*econet_xr1710g-ubi.manifest' \
	-o -name 'profiles.json' \
	-o -name 'sha256sums' \) -delete 2>/dev/null || true
# Restore only the tracked files changed by the deterministic DIY step.  Keep
# downloads, feeds and the 22+ GiB compiler cache intact for an incremental
# release build.
rm -f package/kernel/mt76/patches/*.patch
# Earlier package-only trials may leave this otherwise untracked series in the
# persistent build volume.  The pinned baseline has no uhttpd patches; remove
# only the three reviewed trial filenames before the deterministic DIY step.
rm -f \
	package/network/services/uhttpd/patches/501-1-feat-add-raw-proxy.patch \
	package/network/services/uhttpd/patches/501-2-fix-force-backend-close-for-proxied-http.patch \
	package/network/services/uhttpd/patches/501-3-feat-forward-original-request-headers-to-backend.patch
git restore --source=HEAD --worktree --staged \
	package/firmware/wireless-regdb \
	package/kernel/mt76 \
	package/network/services/hostapd \
	package/network/services/uhttpd \
	package/boot/uboot-tools/uboot-envtools/files/airoha_an7581 \
	include/image.mk \
	target/linux/airoha/Makefile \
	target/linux/airoha/an7581/base-files/etc/board.d/02_network \
	target/linux/airoha/an7581/base-files/lib/upgrade/platform.sh \
	target/linux/airoha/image/an7581.mk \
	target/linux/airoha/patches-6.18
git -C feeds/packages restore --source=HEAD --worktree --staged -- utils/dockerd
git -C feeds/luci restore --source=HEAD --worktree --staged -- \
	applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js \
	applications/luci-app-dockerman/po/zh_Hans/dockerman.po \
	applications/luci-app-firewall/htdocs/luci-static/resources/view/firewall/zones.js \
	applications/luci-app-firewall/po/zh_Hans/firewall.po \
	modules/luci-base/htdocs/luci-static/resources/protocol/static.js \
	modules/luci-base/ucode/template/header.ut \
	modules/luci-mod-network/htdocs/luci-static/resources/view/network/interfaces.js \
	modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js \
	modules/luci-base/po/zh_Hans/base.po
rm -f \
	feeds/luci/modules/luci-base/htdocs/luci-static/resources/protocol/static.js.orig \
	feeds/luci/modules/luci-mod-network/htdocs/luci-static/resources/view/network/interfaces.js.backup \
	feeds/luci/modules/luci-mod-network/htdocs/luci-static/resources/view/network/interfaces.js.orig \
	feeds/luci/modules/luci-mod-network/htdocs/luci-static/resources/view/network/interfaces.js.rej
# Persistent compiler volumes retain old package/feeds symlinks. Remove that
# complete selection before adding PassWall2, or the previous official
# xray-core/sing-box links can silently survive the new feed order.
./scripts/feeds uninstall -a >/dev/null 2>&1 || true
cp /builder/feeds.d/openwrt feeds.conf
cp -a /builder/files/. files/
cp -a /builder/apps/. package/
chmod 0755 files/etc/uci-defaults/99-custom.sh
chmod 0755 files/etc/uci-defaults/41_uhttpd_proxy_linkease
chmod 0755 files/etc/uci-defaults/50-root-passwd
chmod 0755 files/etc/uci-defaults/zz-xr1710g-services.sh
chmod 0755 files/etc/init.d/xr1710g-bootlog
chmod 0755 files/etc/init.d/xr1710g-cpufreq
chmod 0755 files/etc/init.d/xr1710g-uboot-recovery-restore
chmod 0755 files/usr/sbin/xr1710g-mesh-diag
chmod 0755 files/usr/sbin/xr1710g-role
chmod 0755 files/usr/sbin/xr1710g-wan-carrier
chmod 0755 files/usr/sbin/xr1710g-wireless-defaults
chmod 0755 files/usr/sbin/xr1710g-lan-cidr-guard
chmod 0755 files/etc/init.d/xr1710g-lan-cidr-guard
chmod 0755 files/etc/hotplug.d/iface/05-xr1710g-lan-cidr-guard
chmod 0755 files/etc/openclash/core/clash_meta
chmod 0600 files/etc/crontabs/root
chmod 0755 package/luci-app-xr1710g-recovery/root/usr/libexec/rpcd/luci.xr1710g_recovery

sh /builder/scripts/test-xr1710g-tools.sh /builder

./scripts/feeds update -a
# Updating a feed does not guarantee that package/feeds symlinks left by a
# reused compiler volume are replaced. Rebuild the complete selection after
# every update so the pinned PassWall feed order is authoritative.
./scripts/feeds uninstall -a >/dev/null 2>&1 || true
/builder/scripts/prepare-istore-feed.sh
XR_ISTORE_FIXTURE="$PWD/feeds/istore/luci/luci-app-store/root/bin/is-opkg" \
XR_QUICKSTART_FIXTURE="$PWD/feeds/linkease_nas_luci/luci/luci-app-quickstart/htdocs/luci-static/quickstart/index.js" \
  /builder/scripts/test-status-and-istore-safety.sh /builder
./scripts/feeds install -a

cp /builder/configs/openwrt.config .config
/builder/diy-part2.d/openwrt.sh
make defconfig

# Kconfig drops custom preinit strings unless PREINITOPT is enabled.  Refuse
# to spend a full build on an image that defconfig has silently normalized
# back to 192.168.1.1, and keep the embedded release identity explicit.
grep -qx 'CONFIG_TARGET_DEFAULT_LAN_IP_FROM_PREINIT=y' .config
grep -qx 'CONFIG_PREINITOPT=y' .config
grep -qx 'CONFIG_TARGET_PREINIT_IP="192.168.50.1"' .config
grep -qx 'CONFIG_TARGET_PREINIT_NETMASK="255.255.255.0"' .config
grep -qx 'CONFIG_TARGET_PREINIT_BROADCAST="192.168.50.255"' .config
grep -qx 'CONFIG_VERSION_DIST="iStoreOS-XR1710G-Community"' .config
grep -qx 'CONFIG_VERSION_NUMBER="v1.4.0"' .config

grep -qx 'CONFIG_PACKAGE_luci-app-istorex=y' .config
grep -qx 'CONFIG_PACKAGE_luci-theme-argon=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-argon-config=y' .config
if grep -Eq '^CONFIG_(DEFAULT|PACKAGE)_luci-(theme-glass|i18n-glass-zh-cn)=y$' \
	.config; then
	echo 'GlassTheme unexpectedly remains selected after defconfig' >&2
	exit 1
fi
grep -qx 'CONFIG_PACKAGE_luci-app-openclash=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-passwall2=y' .config
grep -qx 'CONFIG_PACKAGE_luci-i18n-passwall2-zh-cn=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-passwall2_Basic_Core_All=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-passwall2_Nftables_Transparent_Proxy=y' .config
grep -qx 'CONFIG_PACKAGE_xray-core=y' .config
grep -qx 'CONFIG_PACKAGE_sing-box=y' .config
if grep -qx 'CONFIG_PACKAGE_luci-app-passwall2_Iptables_Transparent_Proxy=y' \
	.config; then
	echo 'PassWall2 unexpectedly selected the legacy iptables proxy path' >&2
	exit 1
fi
grep -qx 'CONFIG_PACKAGE_usteer=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-dockerman=y' .config
grep -qx 'CONFIG_PACKAGE_dockerd=y' .config
grep -qx 'CONFIG_PACKAGE_docker=y' .config
grep -qx 'CONFIG_PACKAGE_docker-compose=y' .config
grep -qx 'CONFIG_PACKAGE_containerd=y' .config
grep -qx 'CONFIG_PACKAGE_runc=y' .config
grep -qx 'CONFIG_PACKAGE_kmod-veth=y' .config
grep -qx 'CONFIG_PACKAGE_kmod-nf-ipvs=y' .config

BUILD_JOBS="$(sh /builder/scripts/detect-build-jobs.sh)"
echo "Using $BUILD_JOBS parallel build jobs (override with XR_BUILD_JOBS)"
# Fetch every newly selected PassWall2 runtime before the expensive target
# clean. Missing Xray/sing-box sources must fail before the kernel rebuild.
make download -j"$BUILD_JOBS"
find dl -maxdepth 1 -type f -size -1024c -delete

# Force the pinned source and both reviewed patches through a clean mt76
# prepare/compile cycle.  This prevents an older rootfs package from surviving
# merely because an experimental package-only compile populated the cache.
make package/kernel/mt76/clean
# Force both changed source sets through preparation again: otherwise an
# incremental volume can retain the old AdGuard files or pre-921 kernel tree.
make package/feeds/packages/adguardhome/clean
# The Docker engine remains the pinned OpenWrt package. Rebuild its package so
# the reviewed UCI wrapper patch and XR1710G default config cannot be hidden by
# an older incremental APK.
make package/feeds/packages/dockerd/clean
# Full Cone spans four separately cached packages. Rebuild the entire chain so
# a current kernel module cannot be paired with stale libnftnl, nftables or
# firewall4 userspace in either flashable rootfs.
make package/libs/libnftnl/clean
make package/network/utils/nftables/clean
make package/network/config/firewall4/clean
make package/fullconenat-nft/clean
# Rebuild Dockerman so the stopped-daemon page and its translations cannot be
# hidden by an incremental APK produced before this owner-facing fix.
make package/feeds/luci/luci-app-dockerman/clean
# The LAN editor, shared resource version and firewall page are patched in the
# LuCI feed.  Rebuild every owning package instead of trusting old APK/stamps.
make package/feeds/luci/luci-base/clean
make package/feeds/luci/luci-mod-network/clean
make package/feeds/luci/luci-app-firewall/clean
# PassWall2 and both maintained aarch64 cores come from newly pinned feeds.
# Clean them so no previous official-feed binary can survive in this volume.
make package/feeds/passwall2/luci-app-passwall2/clean
make package/feeds/passwall_packages/xray-core/clean
make package/feeds/passwall_packages/sing-box/clean
make package/feeds/passwall_packages/chinadns-ng/clean
make package/feeds/passwall_packages/geoview/clean
make package/feeds/passwall_packages/tcping/clean
make package/feeds/passwall_packages/v2ray-geodata/clean
# All five project-owned packages keep stable version numbers during release
# iteration. Clean them together so changed UI/RPC/default files cannot remain
# trapped behind an older package/rootfs staging stamp.
for xr_package in \
	luci-app-airoha-fancontrol \
	luci-app-airoha-flowsense \
	luci-app-airoha-npu \
	luci-app-xr1710g-recovery \
	xr1710g-status-core; do
	make "package/$xr_package/clean"
done
# The current image retains the configured preinit address as its generated default
# LAN address.  base-files emits both /lib/preinit/00_preinit.conf and
# /etc/board.d/99-lan-ip, so force it through a clean build rather than
# accepting either file from an older incremental image.
make package/base-files/clean
# The refreshed baseline carries the hostapd WDS event-routing fix. Force a
# fresh package build so image assembly cannot reuse a stale wpad binary from
# an older incremental build volume.
make package/network/services/hostapd/clean
# The iStoreOS reverse-proxy stack changes the uhttpd executable.  Force a
# clean package build so a stale incremental binary cannot enter the release.
make package/network/services/uhttpd/clean
# Kernel/Prepare removes and recreates the whole per-target kernel build
# directory when a patch input changes. Invoke the official target clean so
# there is no chance that the pre-921 vmlinux, modules or stamp survives.
make target/linux/clean
make -j"$BUILD_JOBS"
# OpenWrt may retain same-version project APK install markers even after the
# package compile was refreshed. Force the assembled rootfs to consume the
# current local package payloads before either image is accepted.
for xr_stamp in \
	.luci-app-airoha-fancontrol_installed \
	.luci-app-airoha-flowsense_installed \
	.luci-app-airoha-npu_installed \
	.luci-app-passwall2_installed \
	.luci-i18n-passwall2-zh-cn_installed \
	.xray-core_installed \
	.sing-box_installed \
	.chinadns-ng_installed \
	.geoview_installed \
	.v2ray-geoip_installed \
	.v2ray-geosite_installed \
	.luci-app-firewall_installed \
	.luci-app-dockerman_installed \
	.luci-app-xr1710g-recovery_installed \
	.luci-base_installed \
	.luci-mod-network_installed \
	.firewall4_installed \
	.kmod-nft-fullcone_installed \
	.libnftnl_installed \
	.nftables-json_installed \
	.luci-i18n-airoha-fancontrol-zh-cn_installed \
	.luci-i18n-airoha-flowsense-zh-cn_installed \
	.luci-i18n-airoha-npu-zh-cn_installed \
	.luci-i18n-dockerman-zh-cn_installed \
	.luci-i18n-firewall-zh-cn_installed \
	.luci-i18n-xr1710g-recovery-zh-cn_installed \
	.xr1710g-status-core_installed; do
	rm -f "staging_dir/target-aarch64_cortex-a53_musl/root-airoha/stamp/$xr_stamp"
done
# OpenWrt's package/install checksum helper scans BUILD_DIR_HOST even though
# this target uses hostpkg for the actual tools. Keep the disposable scan path
# present after a clean build so a missing empty directory cannot abort image
# assembly.
mkdir -p build_dir/host
make package/install -j1
grep -Eq 'if ?\(oneShot\)' \
	build_dir/target-aarch64_cortex-a53_musl/root-airoha/www/luci-static/resources/view/system/xr1710g-recovery.js
grep -Eq "a.id ?!== ?'npu_bypass_latency'" \
	build_dir/target-aarch64_cortex-a53_musl/root-airoha/www/luci-static/resources/view/airoha_flowsense/status.js
bash /builder/scripts/rebuild-initramfs-recovery.sh "$PWD"
sh /builder/scripts/verify-xr1710g-build.sh "$PWD" 2>&1 | tee /work/verify.txt

sh /builder/scripts/package-release.sh "$PWD" /work/dist
