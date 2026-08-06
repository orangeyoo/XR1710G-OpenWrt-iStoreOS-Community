#!/bin/bash
set -euo pipefail

export FORCE_UNSAFE_CONFIGURE=1
export GITHUB_WORKSPACE=/builder

cd /work/openwrt
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
# Package-only v8 trials may leave this otherwise untracked series in the
# persistent build volume.  The pinned baseline has no uhttpd patches; remove
# only the three reviewed trial filenames before the deterministic DIY step.
rm -f \
	package/network/services/uhttpd/patches/501-1-feat-add-raw-proxy.patch \
	package/network/services/uhttpd/patches/501-2-fix-force-backend-close-for-proxied-http.patch \
	package/network/services/uhttpd/patches/501-3-feat-forward-original-request-headers-to-backend.patch
git restore --source=HEAD --worktree --staged \
	package/kernel/mt76 \
	package/network/services/hostapd \
	package/network/services/uhttpd \
	include/image.mk \
	target/linux/airoha/Makefile \
	target/linux/airoha/image/an7581.mk \
	target/linux/airoha/patches-6.18
cp /builder/feeds.d/openwrt feeds.conf
cp -a /builder/files/. files/
cp -a /builder/apps/. package/
chmod 0755 files/etc/uci-defaults/99-custom.sh
chmod 0755 files/etc/uci-defaults/41_uhttpd_proxy_linkease
chmod 0755 files/etc/uci-defaults/zz-xr1710g-services.sh
chmod 0755 files/etc/init.d/xr1710g-bootlog
chmod 0755 files/usr/sbin/xr1710g-mesh-diag
chmod 0755 files/usr/sbin/xr1710g-role
chmod 0755 files/usr/sbin/xr1710g-wireless-defaults
chmod 0755 files/etc/openclash/core/clash_meta
chmod 0600 files/etc/crontabs/root

sh /builder/scripts/test-xr1710g-tools.sh /builder

./scripts/feeds update -a
/builder/scripts/prepare-istore-feed.sh
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
grep -qx 'CONFIG_VERSION_NUMBER="v8"' .config

grep -qx 'CONFIG_PACKAGE_luci-app-istorex=y' .config
grep -qx 'CONFIG_PACKAGE_luci-theme-argon=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-argon-config=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-openclash=y' .config
grep -qx 'CONFIG_PACKAGE_usteer=y' .config

# Force the pinned source and both reviewed patches through a clean mt76
# prepare/compile cycle.  This prevents an older rootfs package from surviving
# merely because an experimental package-only compile populated the cache.
make package/kernel/mt76/clean
# Force both changed source sets through preparation again: otherwise an
# incremental volume can retain the old AdGuard files or pre-921 kernel tree.
make package/feeds/packages/adguardhome/clean
# The v8 image retains the configured preinit address as its generated default
# LAN address.  base-files emits both /lib/preinit/00_preinit.conf and
# /etc/board.d/99-lan-ip, so force it through a clean build rather than
# accepting either file from an older incremental image.
make package/base-files/clean
# The hostapd WDS event-routing backport changes the monolithic wpad binary.
# Force a fresh package build so image assembly cannot reuse the r2 package
# left in an incremental build volume.
make package/network/services/hostapd/clean
# The iStoreOS reverse-proxy stack changes the uhttpd executable.  Force a
# clean package build so an incremental v7 binary cannot enter v8.
make package/network/services/uhttpd/clean
# Kernel/Prepare removes and recreates the whole per-target kernel build
# directory when a patch input changes. Invoke the official target clean so
# there is no chance that the pre-921 vmlinux, modules or stamp survives.
make target/linux/clean
make -j16
bash /builder/scripts/rebuild-initramfs-recovery.sh "$PWD"
sh /builder/scripts/verify-xr1710g-build.sh "$PWD" | tee /work/verify.txt

sh /builder/scripts/package-release.sh "$PWD" /work/dist
