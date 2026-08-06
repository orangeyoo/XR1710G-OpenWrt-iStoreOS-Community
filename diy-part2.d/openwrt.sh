#!/bin/bash
# OpenWrt DIY part2
# — 在 .config 加载之后、make 之前运行 —

# The baseline's first Airoha TRNG follow-up opens the SCU clock gates after
# touching RNG_EN. Install the reviewed ordering-only patch deterministically
# and refuse stale or duplicate copies.
trng_patch_src="$GITHUB_WORKSPACE/patches/kernel/0921-hwrng-airoha-enable-scu-clocks-before-trng.patch"
trng_patch_dir="target/linux/airoha/patches-6.18"
trng_patch_dst="$trng_patch_dir/921-hwrng-airoha-enable-scu-clocks-before-trng.patch"
trng_base_patch="$trng_patch_dir/920-hwrng-airoha-fix-init-sequence-default-to-DRBG.patch"
[ -f "$trng_patch_src" ] || {
	echo "Missing XR1710G TRNG clock-ordering patch" >&2
	exit 1
}
[ -f "$trng_base_patch" ] || {
	echo "Missing expected Airoha TRNG base patch" >&2
	exit 1
}
grep -Fq 'val |= RNG_EN | RNG_OSC_EN;' "$trng_base_patch" || {
	echo "Unexpected Airoha TRNG base patch; refusing an unreviewed rebase" >&2
	exit 1
}
rm -f "$trng_patch_dst"
install -m 0644 "$trng_patch_src" "$trng_patch_dst"
grep -Fq 'enable SCU clocks before starting TRNG' "$trng_patch_dst" || {
	echo "Installed Airoha TRNG patch failed content validation" >&2
	exit 1
}

# Image assembly enables every rc.common service after overlay files are
# copied. Make AdGuard Home opt-in at the immutable rootfs level as well as in
# the first-boot policy: pass it through prepare_rootfs' disabled-service list
# for every target image.
image_makefile='include/image.mk'
old_prepare_rootfs='$(call prepare_rootfs,$(mkfs_cur_target_dir),$(TOPDIR)/files)'
new_prepare_rootfs='$(call prepare_rootfs,$(mkfs_cur_target_dir),$(TOPDIR)/files,adguardhome)'
old_prepare_line="$(printf '\t%s' "$old_prepare_rootfs")"
new_prepare_line="$(printf '\t%s' "$new_prepare_rootfs")"
if grep -Fqx "$new_prepare_line" "$image_makefile"; then
	:
elif grep -Fqx "$old_prepare_line" "$image_makefile"; then
	prepare_line_number="$(grep -nFx "$old_prepare_line" "$image_makefile" |
		cut -d: -f1)"
	[ -n "$prepare_line_number" ] || exit 1
	sed -i "${prepare_line_number}c\\${new_prepare_line}" "$image_makefile"
else
	echo "Unexpected image rootfs assembly call; cannot disable AdGuard Home" >&2
	exit 1
fi
grep -Fqx "$new_prepare_line" "$image_makefile" || {
	echo "Unable to disable AdGuard Home during image rootfs assembly" >&2
	exit 1
}

# Backport the upstream fix for NL80211_CMD_UNEXPECTED_4ADDR_FRAME event
# routing.  With multiple BSS contexts sharing one nl80211 driver, the pinned
# hostapd revision delivers this event to the first BSS instead of the BSS
# identified by the event ifindex.  XR1710G AP-WDS therefore authenticates but
# never creates its AP_VLAN/WDS interface.  Refuse to apply this narrowly
# reviewed fix to any unrecognized hostapd baseline.
hostapd_makefile="package/network/services/hostapd/Makefile"
hostapd_wds_patch_src="$GITHUB_WORKSPACE/patches/hostapd/0804-nl80211-report-unexpected-frame-events-to-correct-bss.patch"
hostapd_wds_patch_dst="package/network/services/hostapd/patches/804-nl80211-report-unexpected-frame-events-to-correct-bss.patch"
[ -f "$hostapd_makefile" ] || {
	echo "Missing pinned hostapd package Makefile" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_DATE:=2026-04-02' "$hostapd_makefile" || {
	echo "Unexpected hostapd source date; refusing an unreviewed WDS backport" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_VERSION:=b004de0bf1b54d669d358b7f33d6f474bd9719a6' \
	"$hostapd_makefile" || {
	echo "Unexpected hostapd source revision; refusing an unreviewed WDS backport" >&2
	exit 1
}
grep -qx 'PKG_RELEASE:=2' "$hostapd_makefile" || {
	echo "Unexpected hostapd package release; refusing an ambiguous WDS update" >&2
	exit 1
}
[ -f "$hostapd_wds_patch_src" ] || {
	echo "Missing reviewed hostapd WDS event-routing patch" >&2
	exit 1
}
grep -Fq '61280edc2e1d6e38566d386e64227655eee3120e' \
	"$hostapd_wds_patch_src" || {
	echo "Hostapd WDS patch is not the reviewed upstream backport" >&2
	exit 1
}
grep '^+' "$hostapd_wds_patch_src" |
	grep -Fq 'wpa_supplicant_event(bss->ctx, EVENT_RX_FROM_UNKNOWN, &event);' || {
	echo "Hostapd WDS patch failed content validation" >&2
	exit 1
}

sed -i 's/^PKG_RELEASE:=2$/PKG_RELEASE:=3/' "$hostapd_makefile"
rm -f "$hostapd_wds_patch_dst"
install -m 0644 "$hostapd_wds_patch_src" "$hostapd_wds_patch_dst"

grep -qx 'PKG_RELEASE:=3' "$hostapd_makefile" || {
	echo "Unable to select the WDS-fixed hostapd package release" >&2
	exit 1
}
grep -Fq 'wpa_supplicant_event(bss->ctx, EVENT_RX_FROM_UNKNOWN, &event);' \
	"$hostapd_wds_patch_dst" || {
	echo "Installed hostapd WDS patch failed content validation" >&2
	exit 1
}

# Backport iStoreOS' reviewed raw reverse-proxy stack to the newer uhttpd
# revision used by this XR1710G port.  The capability is required by the new
# LinkEase Full /apps entry, but this image deliberately does not install that
# optional runtime and therefore does not create a default proxy mapping.
# Keep all three upstream patches content-addressed so a future iStoreOS branch
# update cannot silently change the code compiled into a community release.
uhttpd_makefile="package/network/services/uhttpd/Makefile"
uhttpd_patch_dir="package/network/services/uhttpd/patches"
uhttpd_proxy_patch_src="$GITHUB_WORKSPACE/patches/uhttpd"
uhttpd_package_patch="$uhttpd_proxy_patch_src/0000-package-enable-proxy-uci.patch"
uhttpd_proxy_patches='501-1-feat-add-raw-proxy.patch 501-2-fix-force-backend-close-for-proxied-http.patch 501-3-feat-forward-original-request-headers-to-backend.patch'
[ -f "$uhttpd_makefile" ] || {
	echo "Missing pinned uhttpd package Makefile" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_DATE:=2026-06-16' "$uhttpd_makefile" || {
	echo "Unexpected uhttpd source date; refusing an unreviewed proxy rebase" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_VERSION:=7b1bec45826bd78c8afc993435bdc0f1df2fe399' \
	"$uhttpd_makefile" || {
	echo "Unexpected uhttpd source revision; refusing an unreviewed proxy rebase" >&2
	exit 1
}
grep -qx 'PKG_RELEASE:=1' "$uhttpd_makefile" || {
	echo "Unexpected uhttpd package release; refusing an ambiguous proxy update" >&2
	exit 1
}
# The pinned OpenWrt baseline has no uhttpd patch directory. Reject any
# unexpected pre-existing patch rather than silently changing patch order.
if [ -d "$uhttpd_patch_dir" ] &&
	find "$uhttpd_patch_dir" -maxdepth 1 -type f -name '*.patch' -print | grep -q .; then
	echo "Unexpected pre-existing uhttpd patch series" >&2
	exit 1
fi
[ -f "$uhttpd_package_patch" ] || {
	echo "Missing reviewed uhttpd UCI integration patch" >&2
	exit 1
}

patch -p1 --forward --batch < "$uhttpd_package_patch"
grep -Fq 'config_list_foreach "$cfg" proxy_prefix append_proxy_prefix' \
	package/network/services/uhttpd/files/uhttpd.init || {
	echo "uhttpd init does not expose proxy_prefix UCI mappings" >&2
	exit 1
}
grep -Fq 'list proxy_prefix' package/network/services/uhttpd/files/uhttpd.config || {
	echo "uhttpd config does not document proxy_prefix mappings" >&2
	exit 1
}

mkdir -p "$uhttpd_patch_dir"
for uhttpd_patch in $uhttpd_proxy_patches; do
	[ -f "$uhttpd_proxy_patch_src/$uhttpd_patch" ] || {
		echo "Missing reviewed iStoreOS uhttpd patch: $uhttpd_patch" >&2
		exit 1
	}
	rm -f "$uhttpd_patch_dir/$uhttpd_patch"
	install -m 0644 "$uhttpd_proxy_patch_src/$uhttpd_patch" \
		"$uhttpd_patch_dir/$uhttpd_patch"
done

[ "$(sha256sum "$uhttpd_patch_dir/501-1-feat-add-raw-proxy.patch" | cut -d' ' -f1)" = \
	'b87ac4cea290fd0cff99b1e7092f0a5847ac94a678ca590691d35e884d65fb1e' ] || {
	echo "Unexpected iStoreOS raw-proxy patch content" >&2
	exit 1
}
[ "$(sha256sum "$uhttpd_patch_dir/501-2-fix-force-backend-close-for-proxied-http.patch" | cut -d' ' -f1)" = \
	'e8b84a06e0d40de9a0c0a3ad642b2f40ce0fd7f9d3260934eb29ba346d875753' ] || {
	echo "Unexpected iStoreOS proxy-close patch content" >&2
	exit 1
}
[ "$(sha256sum "$uhttpd_patch_dir/501-3-feat-forward-original-request-headers-to-backend.patch" | cut -d' ' -f1)" = \
	'e23262991b6b8cb59d107f16560876a6e542e0bbfbe60e9dddd9c92ca625071c' ] || {
	echo "Unexpected iStoreOS forwarded-header patch content" >&2
	exit 1
}

sed -i 's/^PKG_RELEASE:=1$/PKG_RELEASE:=2/' "$uhttpd_makefile"
grep -qx 'PKG_RELEASE:=2' "$uhttpd_makefile" || {
	echo "Unable to select the proxy-enabled uhttpd package release" >&2
	exit 1
}

# Pin the upstream mt76 revision that was A/B tested on two XR1710G units,
# then apply the reviewed AN7581/NPU rebase and terminal-failure statistics
# fix.  Keep this fully reproducible from the public upstream git commit: no
# build-volume tarball or mutable branch is allowed to affect the image.
mt76_makefile="package/kernel/mt76/Makefile"
mt76_an7581_patch_src="$GITHUB_WORKSPACE/patches/mt76/0100-xr1710g-rebase-yyh-an7581-npu-stack-on-b2704cf5.patch"
mt76_stats_patch_src="$GITHUB_WORKSPACE/patches/mt76/0099-wifi-mt76-mt7996-report-only-terminal-tx-failures.patch"
mt76_an7581_patch_dst="package/kernel/mt76/patches/0100-xr1710g-rebase-yyh-an7581-npu-stack-on-b2704cf5.patch"
mt76_stats_patch_dst="package/kernel/mt76/patches/0101-wifi-mt76-mt7996-report-only-terminal-tx-failures.patch"
[ -f "$mt76_makefile" ] || {
	echo "Missing pinned mt76 package Makefile" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_VERSION:=59676919ea408b0b13a9d23f2e2e1a1ab407fba1' \
	"$mt76_makefile" || {
	echo "Unexpected mt76 source revision; refusing an unreviewed driver rebase" >&2
	exit 1
}
[ -f "$mt76_an7581_patch_src" ] || {
	echo "Missing reviewed XR1710G AN7581/NPU rebase patch" >&2
	exit 1
}
[ -f "$mt76_stats_patch_src" ] || {
	echo "Missing reviewed MT7996 tx_failed patch" >&2
	exit 1
}
grep -qx 'PKG_RELEASE=3' "$mt76_makefile" || {
	echo "Unexpected mt76 package release; refusing an ambiguous driver update" >&2
	exit 1
}

# These are the deterministic git-archive/zstd values produced by OpenWrt's
# own download helper for the public b2704cf5 commit.
sed -i \
	-e 's/^PKG_RELEASE=3$/PKG_RELEASE=5/' \
	-e 's/^PKG_SOURCE_DATE:=2026-07-01$/PKG_SOURCE_DATE:=2026-08-01/' \
	-e 's/^PKG_SOURCE_VERSION:=59676919ea408b0b13a9d23f2e2e1a1ab407fba1$/PKG_SOURCE_VERSION:=b2704cf5a4068b672bf47ad5bf6b4802b6770a90/' \
	-e 's/^PKG_MIRROR_HASH:=8a6dc6dac37ed56fcbfd874359f5c25acb65bcfaa795d50494cba17c98405dd5$/PKG_MIRROR_HASH:=fc94437f3271a16d3865c16ec3bbdf828ac18a730953a74fc80f76abf461eb67/' \
	"$mt76_makefile"

# The old patch series targets 59676919. Its board-specific result was
# reviewed and rebased as one consolidated patch above, so never apply both.
find package/kernel/mt76/patches -maxdepth 1 -type f -name '*.patch' -delete
install -m 0644 "$mt76_an7581_patch_src" "$mt76_an7581_patch_dst"
install -m 0644 "$mt76_stats_patch_src" "$mt76_stats_patch_dst"

grep -qx 'PKG_RELEASE=5' "$mt76_makefile" || {
	echo "Unable to select the A/B-tested mt76 package release" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_VERSION:=b2704cf5a4068b672bf47ad5bf6b4802b6770a90' \
	"$mt76_makefile" || {
	echo "Unable to select the A/B-tested upstream mt76 revision" >&2
	exit 1
}
grep -qx 'PKG_MIRROR_HASH:=fc94437f3271a16d3865c16ec3bbdf828ac18a730953a74fc80f76abf461eb67' \
	"$mt76_makefile" || {
	echo "Unable to pin the b2704cf5 source archive hash" >&2
	exit 1
}
grep -Fq 'mt7996_mcu_get_per_sta_info' "$mt76_an7581_patch_dst" || {
	echo "Installed AN7581/NPU patch failed content validation" >&2
	exit 1
}
grep -Fq 'wcid->stats.tx_failed +=' "$mt76_stats_patch_dst" || {
	echo "Installed MT7996 statistics patch failed content validation" >&2
	exit 1
}

# The XR1710G device profile pulls in wpad-basic-mbedtls by default.  A full
# wpad-mesh build conflicts with every other hostapd/wpad provider, so remove
# all explicit providers before loading our package selections.
sed -i -E \
	'/^CONFIG_PACKAGE_(hostapd|hostapd-basic|hostapd-basic-mbedtls|hostapd-basic-openssl|hostapd-basic-wolfssl|hostapd-mbedtls|hostapd-mini|hostapd-openssl|hostapd-wolfssl|wpad|wpad-basic|wpad-basic-mbedtls|wpad-basic-openssl|wpad-basic-wolfssl|wpad-mbedtls|wpad-mesh-mbedtls|wpad-mesh-openssl|wpad-mesh-wolfssl|wpad-mini|wpad-openssl|wpad-wolfssl)(=| is not set)/d' \
	.config
sed -i -E '/^CONFIG_PACKAGE_(iw|iw-full)(=| is not set)/d' .config
sed -i -E \
	'/^CONFIG_(USES_SEPARATE_INITRAMFS|TARGET_ROOTFS_INITRAMFS_SEPARATE|TARGET_INITRAMFS_COMPRESSION_(NONE|GZIP|BZIP2|LZMA|LZO|LZ4|XZ|ZSTD))(=| is not set)/d' \
	.config

# Advertise the target capability required for Kconfig to expose and retain
# TARGET_ROOTFS_INITRAMFS_SEPARATE. The XR1710G FIT recipe already has
# "with-initrd"; this makes that path functional without changing its layout.
sed -i -E \
	's/^(FEATURES:=.*[[:space:]])ramdisk([[:space:]].*)$/\1separate_ramdisk\2/' \
	target/linux/airoha/Makefile
grep -Eq '^FEATURES:=.*(^|[[:space:]])separate_ramdisk([[:space:]]|$)' \
	target/linux/airoha/Makefile || {
	echo "Unable to enable Airoha separate-ramdisk target capability" >&2
	exit 1
}

# Keep profiles.json/ImageBuilder metadata aligned with the actual image.
# Limit the substitution to the XR1710G device block; other Airoha profiles
# retain their upstream wireless provider.
sed -i \
	'/^define Device\/econet_xr1710g-ubi$/,/^endef$/ s/wpad-basic-mbedtls/wpad-mesh-openssl/' \
	target/linux/airoha/image/an7581.mk
xr1710g_profile="$(
	sed -n '/^define Device\/econet_xr1710g-ubi$/,/^endef$/p' \
		target/linux/airoha/image/an7581.mk
)"
printf '%s\n' "$xr1710g_profile" | grep -Fq 'wpad-mesh-openssl' || {
	echo "Unable to select wpad-mesh-openssl in the XR1710G profile" >&2
	exit 1
}
if printf '%s\n' "$xr1710g_profile" | grep -Fq 'wpad-basic-mbedtls'; then
	echo "XR1710G profile still contains wpad-basic-mbedtls" >&2
	exit 1
fi

# ===== 追加第三方插件包（不影响 .config 主文件）=====
PKG_CONF="$GITHUB_WORKSPACE/packages/openwrt.conf"
[ -f "$PKG_CONF" ] && grep -v '^#' "$PKG_CONF" | grep -v '^$' >> .config && echo "已加载第三方插件: openwrt" || true

# ===== 修改内核选项示例 =====
# sed -i '/CONFIG_PACKAGE_kmod-usb-ohci/d' .config
sed -i '/CONFIG_PACKAGE_mihomo-alpha/d' .config

# Brand this explicitly as a community port, not an official iStoreOS build.
sed -i -E \
	-e '/^CONFIG_VERSION_(DIST|NUMBER|MANUFACTURER|PRODUCT|HOME_URL|SUPPORT_URL|REPO)=/d' \
	.config
cat >> .config <<'CONFIGEOF'
CONFIG_VERSIONOPT=y
CONFIG_VERSION_DIST="iStoreOS-XR1710G-Community"
CONFIG_VERSION_NUMBER="v8"
CONFIG_VERSION_MANUFACTURER="XR1710G Community"
CONFIG_VERSION_PRODUCT="XR1710G iStoreOS Community Port"
CONFIG_VERSION_HOME_URL="https://doc.linkease.com/zh/guide/istoreos/"
CONFIG_VERSION_SUPPORT_URL="https://github.com/YYH2913/openwrt"
# This port tracks an OpenWrt snapshot.  A releases/%V URL expands to the
# nonexistent releases/SNAPSHOT tree and makes every APK source return 404.
CONFIG_VERSION_REPO="https://downloads.openwrt.org/snapshots"

# The Airoha recovery FIT recipe uses "with-initrd". Keep the normal kernel
# unchanged and attach the complete recovery rootfs as a compressed ramdisk.
CONFIG_USES_SEPARATE_INITRAMFS=y
CONFIG_TARGET_ROOTFS_INITRAMFS_SEPARATE=y
CONFIG_TARGET_INITRAMFS_COMPRESSION_XZ=y
CONFIGEOF

# ===== UCI 默认值示例 ======
# mkdir -p openwrt/files/etc/uci-defaults
# cat > openwrt/files/etc/uci-defaults/99-custom << 'UCIEOF'
# uci set system.@system[0].timezone='CST-8'
# uci commit system
# UCIEOF
