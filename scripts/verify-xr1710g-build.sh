#!/bin/sh
set -eu

TOPDIR="${1:-.}"
CONFIG="$TOPDIR/.config"
TARGET_DIR="${2:-$TOPDIR/bin/targets/airoha/an7581}"

fail() {
	echo "VERIFY FAILED: $*" >&2
	exit 1
}

require_config() {
	grep -qx "$1" "$CONFIG" || fail "missing config: $1"
}

require_manifest_pkg() {
	pkg="$1"
	grep -hEq "^${pkg}[[:space:]]+-[[:space:]]+" "$TARGET_DIR"/*.manifest ||
		fail "manifest does not contain $pkg"
}

[ -f "$CONFIG" ] || fail "$CONFIG not found"

require_config 'CONFIG_TARGET_airoha=y'
require_config 'CONFIG_TARGET_airoha_an7581=y'
require_config 'CONFIG_TARGET_airoha_an7581_DEVICE_econet_xr1710g-ubi=y'
require_config 'CONFIG_PACKAGE_wpad-mesh-openssl=y'
require_config 'CONFIG_PACKAGE_luci-app-store=y'
require_config 'CONFIG_PACKAGE_quickstart=y'
require_config 'CONFIG_PACKAGE_luci-app-quickstart=y'
require_config 'CONFIG_PACKAGE_luci-app-istorex=y'
require_config 'CONFIG_PACKAGE_luci-theme-argon=y'
require_config 'CONFIG_PACKAGE_luci-app-argon-config=y'
require_config 'CONFIG_PACKAGE_luci-app-openclash=y'
require_config 'CONFIG_PACKAGE_usteer=y'
require_config 'CONFIG_PACKAGE_luci-app-airoha-npu=y'
require_config 'CONFIG_PACKAGE_luci-app-airoha-flowsense=y'
require_config 'CONFIG_PACKAGE_luci-app-airoha-fancontrol=y'
require_config 'CONFIG_PACKAGE_xr1710g-status-core=y'
require_config 'CONFIG_PACKAGE_luci-app-dockerman=y'
require_config 'CONFIG_PACKAGE_dockerd=y'
require_config 'CONFIG_PACKAGE_docker=y'
require_config 'CONFIG_PACKAGE_docker-compose=y'
require_config 'CONFIG_PACKAGE_containerd=y'
require_config 'CONFIG_PACKAGE_runc=y'
require_config 'CONFIG_PACKAGE_kmod-veth=y'
require_config 'CONFIG_PACKAGE_kmod-br-netfilter=y'
require_config 'CONFIG_PACKAGE_kmod-nf-ipvs=y'
require_config 'CONFIG_PACKAGE_wireless-regdb=y'
require_config 'CONFIG_PACKAGE_iw-full=y'
require_config 'CONFIG_PACKAGE_adguardhome=y'
require_config 'CONFIG_PACKAGE_luci-app-adguardhome=y'
require_config 'CONFIG_USE_APK=y'
require_config 'CONFIG_TARGET_ROOTFS_INITRAMFS=y'
require_config 'CONFIG_USES_SEPARATE_INITRAMFS=y'
require_config 'CONFIG_TARGET_ROOTFS_INITRAMFS_SEPARATE=y'
require_config 'CONFIG_TARGET_INITRAMFS_COMPRESSION_XZ=y'
require_config 'CONFIG_TARGET_DEFAULT_LAN_IP_FROM_PREINIT=y'
require_config 'CONFIG_PREINITOPT=y'
require_config 'CONFIG_TARGET_PREINIT_IP="192.168.50.1"'
require_config 'CONFIG_TARGET_PREINIT_NETMASK="255.255.255.0"'
require_config 'CONFIG_TARGET_PREINIT_BROADCAST="192.168.50.255"'
require_config 'CONFIG_VERSION_DIST="iStoreOS-XR1710G-Community"'
require_config 'CONFIG_VERSION_NUMBER="v8"'

if grep -Eq '^CONFIG_TARGET_airoha_an7581_DEVICE_(airoha_|gemtek_|nokia_).*=y$' "$CONFIG"; then
	fail "a non-XR1710G device profile is enabled"
fi

if grep -Eq '^CONFIG_PACKAGE_(hostapd|hostapd-basic|hostapd-basic-mbedtls|hostapd-basic-openssl|hostapd-basic-wolfssl|hostapd-mbedtls|hostapd-mini|hostapd-openssl|hostapd-wolfssl|wpad|wpad-basic|wpad-basic-mbedtls|wpad-basic-openssl|wpad-basic-wolfssl|wpad-mbedtls|wpad-mesh-mbedtls|wpad-mesh-wolfssl|wpad-mini|wpad-openssl|wpad-wolfssl)=y$' "$CONFIG"; then
	fail "a conflicting hostapd/wpad provider is enabled"
fi

[ -d "$TARGET_DIR" ] || fail "$TARGET_DIR not found"

grep -Fq '"wpad-mesh-openssl"' "$TARGET_DIR/profiles.json" ||
	fail "XR1710G profile metadata does not select wpad-mesh-openssl"
grep -Fq '"wpad-basic-mbedtls"' "$TARGET_DIR/profiles.json" &&
	fail "XR1710G profile metadata still selects wpad-basic-mbedtls"

require_manifest_pkg wpad-mesh-openssl
require_manifest_pkg luci-app-store
require_manifest_pkg quickstart
require_manifest_pkg luci-app-quickstart
require_manifest_pkg luci-app-istorex
require_manifest_pkg luci-theme-argon
require_manifest_pkg luci-app-argon-config
require_manifest_pkg luci-app-openclash
require_manifest_pkg usteer
require_manifest_pkg luci-app-airoha-npu
require_manifest_pkg luci-app-airoha-flowsense
require_manifest_pkg luci-app-airoha-fancontrol
require_manifest_pkg xr1710g-status-core
require_manifest_pkg luci-app-dockerman
require_manifest_pkg dockerd
require_manifest_pkg docker
require_manifest_pkg docker-compose
require_manifest_pkg containerd
require_manifest_pkg runc
require_manifest_pkg kmod-veth
require_manifest_pkg kmod-br-netfilter
require_manifest_pkg kmod-nf-ipvs
require_manifest_pkg wireless-regdb
require_manifest_pkg iw-full
require_manifest_pkg adguardhome
require_manifest_pkg luci-app-adguardhome
require_manifest_pkg kmod-mt7996e
require_manifest_pkg kmod-mt7996-firmware
require_manifest_pkg airoha-en7581-mt7996-npu-firmware

# Regulatory safety gate. XR1710G's three bands share one PHY, so XZ must be a
# complete composite profile: the pinned AU 2.4/5 GHz rules plus the isolated
# no-AFC 6 GHz 36 dBm rule. Ordinary AU/US remain unchanged, XZ stays off by
# default, and the UI must explain the shared-PHY behavior in both languages.
regdb_patch_dir="$TOPDIR/package/firmware/wireless-regdb/patches"
regdb_lab_patch="$regdb_patch_dir/530-us-6ghz-lab-indoor-sp-override.patch"
regdb_lpi_patch="$regdb_patch_dir/520-w1700k-us-power-limits.patch"
[ -f "$regdb_lab_patch" ] || fail "XZ 6 GHz laboratory profile is missing"
grep -Fq 'country XZ: DFS-ETSI' "$regdb_lab_patch" ||
	fail "36 dBm laboratory rule is not isolated under user-assigned XZ"
grep -Fq 'This profile has no AFC implementation' "$regdb_lab_patch" ||
	fail "XZ laboratory rule lacks its no-AFC source warning"
[ -f "$regdb_lpi_patch" ] || fail "US indoor regulatory patch is missing"
grep -Fq '(5925 - 7125 @ 320), (29), NO-OUTDOOR' "$regdb_lpi_patch" ||
	fail "US indoor regulatory patch has an unexpected power ceiling"
[ "$(grep -R -Fl '(5925 - 7125 @ 320), (36), NO-OUTDOOR' "$regdb_patch_dir" | wc -l)" -eq 1 ] ||
	fail "36 dBm rule must occur exactly once in the isolated XZ profile"
if grep -Fq 'country US:' "$regdb_lab_patch" || grep -Fq 'country AU:' "$regdb_lab_patch"; then
	fail "laboratory profile must not override a real country domain"
fi
for xz_au_rule in \
	'(2400 - 2483.5 @ 40), (4000 mW)' \
	'(5150 - 5250 @ 80), (200 mW), NO-OUTDOOR, AUTO-BW' \
	'(5250 - 5350 @ 80), (100 mW), NO-OUTDOOR, AUTO-BW, DFS' \
	'(5470 - 5600 @ 80), (500 mW), DFS' \
	'(5650 - 5730 @ 80), (500 mW), DFS' \
	'(5730 - 5850 @ 80), (4000 mW), AUTO-BW' \
	'(5850 - 5875 @ 20), (25 mW), AUTO-BW'; do
	grep -Fq "$xz_au_rule" "$regdb_lab_patch" ||
		fail "XZ composite profile lacks pinned AU 2.4/5 GHz rule: $xz_au_rule"
done
[ "$(awk '/^\+\t\(/ { n++ } END { print n + 0 }' "$regdb_lab_patch")" -eq 8 ] ||
	fail "XZ composite profile contains an unexpected number of radio rules"

luci_wireless_js="$TOPDIR/feeds/luci/modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js"
luci_zh_hans_po="$TOPDIR/feeds/luci/modules/luci-base/po/zh_Hans/base.po"
[ -f "$luci_wireless_js" ] || fail "LuCI wireless configuration view is missing"
grep -Fq "CBIWifiCountryValue, 'country', _('Country Code'), countryHelp" \
	"$luci_wireless_js" || fail "shared-PHY country selector guidance is missing"
grep -Fq "this.xr1710gLab6g" "$luci_wireless_js" ||
	fail "XZ laboratory choice is not limited to the 6 GHz radio"
grep -Fq "this.value('XZ', _('XZ - XR1710G composite laboratory profile (AU 2.4/5 GHz + 6 GHz 36 dBm, no AFC)'))" \
	"$luci_wireless_js" || fail "explicit XZ laboratory choice is missing"
grep -Fq 'all three bands through one shared PHY' "$luci_wireless_js" ||
	fail "English shared-PHY regulatory explanation is missing"
grep -Fq "uci.set('wireless', radio['.name'], 'country', 'XZ')" "$luci_wireless_js" ||
	fail "LuCI does not persist XZ across all shared-PHY radio sections"
grep -Fq 'XZ is not a country regulatory domain' "$luci_wireless_js" ||
	fail "English XZ laboratory warning is missing"
[ -f "$luci_zh_hans_po" ] || fail "LuCI Simplified Chinese catalog is missing"
grep -Fq 'msgstr "XZ - XR1710G 组合实验配置（AU 2.4/5 GHz + 6 GHz 36 dBm，无 AFC）"' "$luci_zh_hans_po" ||
	fail "Simplified Chinese XZ laboratory label is missing"
grep -Fq '三个频段共用同一个 PHY' "$luci_zh_hans_po" ||
	fail "Simplified Chinese shared-PHY explanation is missing"
grep -Fq 'msgstr "警告：XZ 不是国家监管域' "$luci_zh_hans_po" ||
	fail "Simplified Chinese XZ laboratory warning is missing"
if grep -RIEq "set wireless\.[^[:space:]]+\.country=['\"]?XZ|option country ['\"]?XZ" \
	"$TOPDIR/files"; then
	fail "XZ laboratory profile is enabled by default"
fi

# v8 selectively backports iStoreOS' reverse-proxy stack onto this port's
# newer uhttpd.  Verify the exact source baseline, content-addressed patch
# series, prepared source and manifest.  LinkEase Full is optional and must
# not be installed or mapped on a clean router.
uhttpd_makefile="$TOPDIR/package/network/services/uhttpd/Makefile"
uhttpd_patch_dir="$TOPDIR/package/network/services/uhttpd/patches"
[ -f "$uhttpd_makefile" ] || fail "uhttpd package Makefile is missing"
grep -qx 'PKG_SOURCE_DATE:=2026-06-16' "$uhttpd_makefile" ||
	fail "unexpected uhttpd source date"
grep -qx 'PKG_SOURCE_VERSION:=7b1bec45826bd78c8afc993435bdc0f1df2fe399' \
	"$uhttpd_makefile" || fail "unexpected uhttpd source revision"
grep -qx 'PKG_RELEASE:=2' "$uhttpd_makefile" ||
	fail "proxy-enabled uhttpd package release is not selected"
[ "$(sha256sum "$uhttpd_patch_dir/501-1-feat-add-raw-proxy.patch" | cut -d' ' -f1)" = \
	'174a2521df1d25b40eb72ef42660ca118a7f7801d0be00d154990277c023b7b5' ] ||
	fail "unexpected iStoreOS raw-proxy patch"
[ "$(sha256sum "$uhttpd_patch_dir/501-2-fix-force-backend-close-for-proxied-http.patch" | cut -d' ' -f1)" = \
	'3d73af37c533240bb38b1b1cdf70b966845c8d33c1ef2ce6166ad341795c437f' ] ||
	fail "unexpected iStoreOS proxy-close patch"
[ "$(sha256sum "$uhttpd_patch_dir/501-3-feat-forward-original-request-headers-to-backend.patch" | cut -d' ' -f1)" = \
	'4d31d429d86d6593acdbe37463f8f34d81f3b082c75455a2f49883ba5970fcbd' ] ||
	fail "unexpected iStoreOS forwarded-header patch"

uhttpd_proxy_source="$(find "$TOPDIR/build_dir/target-aarch64_cortex-a53_musl" \
	-maxdepth 2 -type f -path '*/uhttpd-*/proxy_prefix.c' -print | sort | head -n1)"
[ -f "$uhttpd_proxy_source" ] || fail "prepared uhttpd proxy source is missing"
grep -Fq 'X-Forwarded-Proto:' "$uhttpd_proxy_source" ||
	fail "prepared uhttpd proxy lacks forwarded-proto support"
grep -Fq 'X-Forwarded-Host:' "$uhttpd_proxy_source" ||
	fail "prepared uhttpd proxy lacks forwarded-host support"
grep -Fq 'uh_proxy_prefix_try_init' "$uhttpd_proxy_source" ||
	fail "prepared uhttpd proxy lacks raw request dispatch"
grep -hEq '^uhttpd[[:space:]]+-[[:space:]]+2026\.06\.16~7b1bec45-r2$' \
	"$TARGET_DIR"/*.manifest || fail "manifest does not contain proxy-enabled uhttpd r2"
grep -Fq 'config_list_foreach "$cfg" proxy_prefix append_proxy_prefix' \
	"$TOPDIR/package/network/services/uhttpd/files/uhttpd.init" ||
	fail "uhttpd init does not expose proxy_prefix UCI mappings"
if grep -hEq '^(linkeasefull|luci-app-linkeasefull)[[:space:]]+-[[:space:]]+' \
	"$TARGET_DIR"/*.manifest; then
	fail "optional LinkEase Full was unexpectedly preinstalled"
fi

# XR1710G AP-WDS depends on hostapd receiving
# NL80211_CMD_UNEXPECTED_4ADDR_FRAME in the BSS selected by the event ifindex.
# The pinned upstream revision predates that fix, so verify the exact reviewed
# backport, its package release, the prepared source, and the image manifest.
hostapd_makefile="$TOPDIR/package/network/services/hostapd/Makefile"
hostapd_wds_patch="$TOPDIR/package/network/services/hostapd/patches/804-nl80211-report-unexpected-frame-events-to-correct-bss.patch"
[ -f "$hostapd_makefile" ] || fail "hostapd package Makefile is missing"
grep -qx 'PKG_SOURCE_DATE:=2026-04-02' "$hostapd_makefile" ||
	fail "unexpected hostapd source date"
grep -qx 'PKG_SOURCE_VERSION:=b004de0bf1b54d669d358b7f33d6f474bd9719a6' \
	"$hostapd_makefile" || fail "unexpected hostapd source revision"
grep -qx 'PKG_RELEASE:=3' "$hostapd_makefile" ||
	fail "WDS-fixed hostapd package release is not selected"
[ -f "$hostapd_wds_patch" ] || fail "hostapd WDS event-routing patch is missing"
grep -Fq '61280edc2e1d6e38566d386e64227655eee3120e' \
	"$hostapd_wds_patch" || fail "hostapd WDS patch is not the reviewed upstream backport"
grep -Fq 'wpa_supplicant_event(bss->ctx, EVENT_RX_FROM_UNKNOWN, &event);' \
	"$hostapd_wds_patch" || fail "hostapd WDS patch content is unexpected"
[ "$(find "$TOPDIR/package/network/services/hostapd/patches" -maxdepth 1 \
	-type f -name '*unexpected-frame-events-to-correct-bss*.patch' | wc -l)" -eq 1 ] ||
	fail "hostapd patch directory contains duplicate WDS event-routing patches"

hostapd_source="$(find "$TOPDIR/build_dir/target-aarch64_cortex-a53_musl" \
	-type f -path '*/src/drivers/driver_nl80211_event.c' \
	-path '*hostapd*' -print | sort | head -n1)"
[ -f "$hostapd_source" ] || fail "prepared hostapd nl80211 source is missing"
grep -Fq 'wpa_supplicant_event(bss->ctx, EVENT_RX_FROM_UNKNOWN, &event);' \
	"$hostapd_source" || fail "prepared hostapd source does not route WDS events to the receiving BSS"
if grep -Fq 'wpa_supplicant_event(drv->ctx, EVENT_RX_FROM_UNKNOWN, &event);' \
	"$hostapd_source"; then
	fail "prepared hostapd source still routes WDS events to the first BSS"
fi

grep -hEq '^hostapd-common[[:space:]]+-[[:space:]]+2026\.04\.02~b004de0b-r3$' \
	"$TARGET_DIR"/*.manifest || fail "manifest does not contain WDS-fixed hostapd-common r3"
grep -hEq '^wpad-mesh-openssl[[:space:]]+-[[:space:]]+2026\.04\.02~b004de0b-r3$' \
	"$TARGET_DIR"/*.manifest || fail "manifest does not contain WDS-fixed wpad-mesh-openssl r3"

mt76_makefile="$TOPDIR/package/kernel/mt76/Makefile"
mt76_an7581_patch="$TOPDIR/package/kernel/mt76/patches/0100-xr1710g-rebase-yyh-an7581-npu-stack-on-b2704cf5.patch"
mt76_tx_failed_patch="$TOPDIR/package/kernel/mt76/patches/0101-wifi-mt76-mt7996-report-only-terminal-tx-failures.patch"
grep -qx 'PKG_SOURCE_DATE:=2026-08-01' "$mt76_makefile" ||
	fail "unexpected mt76 source date"
grep -qx 'PKG_SOURCE_VERSION:=b2704cf5a4068b672bf47ad5bf6b4802b6770a90' \
	"$mt76_makefile" || fail "unexpected mt76 source revision"
grep -qx 'PKG_MIRROR_HASH:=fc94437f3271a16d3865c16ec3bbdf828ac18a730953a74fc80f76abf461eb67' \
	"$mt76_makefile" || fail "unexpected mt76 source archive hash"
grep -qx 'PKG_RELEASE=5' "$mt76_makefile" ||
	fail "A/B-tested mt76 package release is not selected"
[ -f "$mt76_an7581_patch" ] ||
	fail "XR1710G AN7581/NPU rebase patch is missing"
grep -Fq 'mt7996_mcu_get_per_sta_info' "$mt76_an7581_patch" ||
	fail "XR1710G AN7581/NPU patch content is unexpected"
[ -f "$mt76_tx_failed_patch" ] ||
	fail "MT7996 terminal tx_failed patch is missing"
grep -Fq 'wcid->stats.tx_failed +=' "$mt76_tx_failed_patch" ||
	fail "MT7996 terminal tx_failed patch content is unexpected"
# A unified diff necessarily retains the rejected expression on a deletion
# line.  Inspect only added lines here; searching the whole patch would treat
# proof that the bad code was removed as if it were still being introduced.
if grep '^+' "$mt76_tx_failed_patch" | grep -Fq 'tx_failed = tx_retries +'; then
	fail "MT7996 patch still folds retries into tx_failed"
fi
[ "$(find "$TOPDIR/package/kernel/mt76/patches" -maxdepth 1 -type f \
	-name '*.patch' | wc -l)" -eq 2 ] ||
	fail "mt76 patch directory contains an unexpected stale patch"

trng_base_patch="$TOPDIR/target/linux/airoha/patches-6.18/920-hwrng-airoha-fix-init-sequence-default-to-DRBG.patch"
trng_order_patch="$TOPDIR/target/linux/airoha/patches-6.18/921-hwrng-airoha-enable-scu-clocks-before-trng.patch"
[ -f "$trng_base_patch" ] || fail "Airoha TRNG base patch is missing"
[ -f "$trng_order_patch" ] || fail "XR1710G TRNG ordering patch is missing"
grep -Fq 'enable SCU clocks before starting TRNG' "$trng_order_patch" ||
	fail "XR1710G TRNG ordering patch content is unexpected"
[ "$(find "$TOPDIR/target/linux/airoha/patches-6.18" -maxdepth 1 -type f \
	-name '921*hwrng*trng*.patch' | wc -l)" -eq 1 ] ||
	fail "Airoha patch directory contains an unexpected TRNG ordering patch"

linux_dir="$(find "$TOPDIR/build_dir/target-aarch64_cortex-a53_musl/linux-airoha_an7581" \
	-mindepth 1 -maxdepth 1 -type d -name 'linux-*' -print -quit)"
trng_source="$linux_dir/drivers/char/hw_random/airoha-trng.c"
[ -f "$trng_source" ] || fail "prepared Airoha TRNG source is missing"
trng_clock_line="$(grep -n 'regmap_set_bits(trng->scu, REG_SCU_BUS_CLK_GAT' \
	"$trng_source" | head -n1 | cut -d: -f1)"
trng_enable_line="$(grep -n 'val |= RNG_EN | RNG_OSC_EN;' \
	"$trng_source" | head -n1 | cut -d: -f1)"
[ -n "$trng_clock_line" ] && [ -n "$trng_enable_line" ] ||
	fail "prepared Airoha TRNG source lacks the required clock or enable operation"
[ "$trng_clock_line" -lt "$trng_enable_line" ] ||
	fail "prepared Airoha TRNG source still enables RNG before its SCU clocks"
grep -Fqx "$(printf '\t%s' '$(call prepare_rootfs,$(mkfs_cur_target_dir),$(TOPDIR)/files,adguardhome dockerd)')" \
	"$TOPDIR/include/image.mk" ||
	fail "image assembly does not mark AdGuard Home and Docker as opt-in"

# Docker is the pinned OpenWrt implementation, not a second local engine:
# Moby dockerd/CLI and containerd/runc come from packages.git, Dockerman comes
# from LuCI, and iStore controls the same UCI file and init service.  The only
# package-feed delta allowed here is the reviewed UCI-to-daemon.json log-opts
# bridge in the OpenWrt service wrapper.
[ "$(git -C "$TOPDIR/feeds/packages" rev-parse HEAD)" = \
	'bd08229d5e93b7753a384a49fa0258847988fc53' ] ||
	fail "unexpected OpenWrt packages feed revision"
[ "$(git -C "$TOPDIR/feeds/luci" rev-parse HEAD)" = \
	'fb6b224af5c4456c5d863e47f6647645384b1677' ] ||
	fail "unexpected OpenWrt LuCI feed revision"
[ "$(git -C "$TOPDIR/feeds/istore" rev-parse HEAD)" = \
	'7c5c69796fd9798610a56a80e1895aa9033e1e6c' ] ||
	fail "unexpected iStore feed revision"
dockerd_makefile="$TOPDIR/feeds/packages/utils/dockerd/Makefile"
dockerd_init_source="$TOPDIR/feeds/packages/utils/dockerd/files/dockerd.init"
[ "$(sha256sum "$GITHUB_WORKSPACE/patches/packages/0201-dockerd-support-uci-log-options.patch" |
	cut -d' ' -f1)" = \
	'f2851e370a83380903c1933b59978ac90a1cf8c08b544144a3c8bc6a281654bd' ] ||
	fail "unexpected OpenWrt dockerd wrapper patch content"
grep -qx 'PKG_VERSION:=29.6.1' "$dockerd_makefile" ||
	fail "unexpected upstream OpenWrt dockerd version"
grep -qx 'PKG_GIT_REF:=docker-v$(PKG_VERSION)' "$dockerd_makefile" ||
	fail "dockerd no longer builds the upstream Moby release"
grep -Fq 'config_list_foreach globals log_opts json_add_log_option' \
	"$dockerd_init_source" || fail "OpenWrt dockerd wrapper lacks bounded log options"
if git -C "$TOPDIR/feeds/packages" diff --name-only -- utils/dockerd |
	grep -Fvx 'utils/dockerd/files/dockerd.init' | grep -q .; then
	fail "Docker engine package contains a non-wrapper local modification"
fi

mt76_manifest_line="$(grep -hE '^kmod-mt7996e[[:space:]]+-[[:space:]]+' \
	"$TARGET_DIR"/*.manifest | head -n1)"
printf '%s\n' "$mt76_manifest_line" | grep -Fq '2026.08.01~b2704cf5-r5' ||
	fail "manifest does not identify the A/B-tested mt76 build"

recovery_pattern='*-v8-*-econet_xr1710g-ubi-initramfs-recovery.itb'
sysupgrade_pattern='*-v8-*-econet_xr1710g-ubi-squashfs-sysupgrade.itb'
recovery_count="$(find "$TARGET_DIR" -maxdepth 1 -type f \
	-name "$recovery_pattern" -print | wc -l)"
sysupgrade_count="$(find "$TARGET_DIR" -maxdepth 1 -type f \
	-name "$sysupgrade_pattern" -print | wc -l)"
[ "$recovery_count" -eq 1 ] ||
	fail "expected exactly one v8 XR1710G recovery image, found $recovery_count"
[ "$sysupgrade_count" -eq 1 ] ||
	fail "expected exactly one v8 XR1710G sysupgrade image, found $sysupgrade_count"
recovery="$(find "$TARGET_DIR" -maxdepth 1 -type f \
	-name "$recovery_pattern" -print -quit)"
sysupgrade="$(find "$TARGET_DIR" -maxdepth 1 -type f \
	-name "$sysupgrade_pattern" -print -quit)"

find "$TARGET_DIR" -maxdepth 1 -type f \
	\( -name '*an7581-evb*' -o -name '*w1700k*' -o -name '*nokia*' -o -name '*preloader*' -o -name '*.fip' \) \
	-print | grep -q . && fail "unsafe/non-XR1710G image found in target output"

DUMPIMAGE="$(find "$TOPDIR/build_dir/host" -maxdepth 3 -type f \
	-path '*/u-boot-*/tools/dumpimage' -perm -u+x -print -quit)"
[ -x "$DUMPIMAGE" ] || fail "OpenWrt host dumpimage is not available"
"$DUMPIMAGE" -l "$recovery" | grep -Eq 'FIT description:|Image [0-9]+ \(' ||
	fail "recovery is not a readable FIT image"
"$DUMPIMAGE" -l "$sysupgrade" | grep -Eq 'FIT description:|Image [0-9]+ \(' ||
	fail "sysupgrade is not a readable FIT image"
"$DUMPIMAGE" -l "$recovery" | grep -q 'Type:[[:space:]]*RAMDisk Image' ||
	fail "recovery FIT does not contain a separate ramdisk"
ramdisk_index="$("$DUMPIMAGE" -l "$recovery" |
	awk '/^ Image [0-9]+ \(initrd-[0-9]+\)/ { print $2; exit }')"
[ -n "$ramdisk_index" ] ||
	fail "recovery FIT ramdisk index cannot be identified"

# A readable FIT and an initramfs-looking filename are insufficient. This
# branch can otherwise retain an early empty Image-initramfs and silently put
# the ordinary kernel into both outputs. Extract and decompress both kernels,
# then prove that recovery embeds our installed rootfs.
command -v xz >/dev/null 2>&1 || fail "xz is required for recovery validation"
command -v gzip >/dev/null 2>&1 || fail "gzip is required for recovery validation"
command -v cpio >/dev/null 2>&1 || fail "cpio is required for recovery validation"
command -v fdtget >/dev/null 2>&1 || fail "fdtget is required for DTB validation"
command -v unsquashfs >/dev/null 2>&1 ||
	fail "unsquashfs is required for sysupgrade rootfs validation"

VERIFY_TMP="$(mktemp -d)"
trap 'rm -rf "$VERIFY_TMP"' EXIT INT TERM
"$DUMPIMAGE" -T flat_dt -p 0 -o "$VERIFY_TMP/recovery.kernel.lzma" \
	"$recovery" >/dev/null
"$DUMPIMAGE" -T flat_dt -p 0 -o "$VERIFY_TMP/sysupgrade.kernel.gz" \
	"$sysupgrade" >/dev/null
"$DUMPIMAGE" -T flat_dt -p "$ramdisk_index" \
	-o "$VERIFY_TMP/recovery.initrd.xz" \
	"$recovery" >/dev/null
"$DUMPIMAGE" -T flat_dt -p 2 -o "$VERIFY_TMP/recovery.dtb" \
	"$recovery" >/dev/null
"$DUMPIMAGE" -T flat_dt -p 1 -o "$VERIFY_TMP/sysupgrade.dtb" \
	"$sysupgrade" >/dev/null
"$DUMPIMAGE" -T flat_dt -p 2 -o "$VERIFY_TMP/sysupgrade.rootfs" \
	"$sysupgrade" >/dev/null
xz --format=lzma -dc "$VERIFY_TMP/recovery.kernel.lzma" \
	> "$VERIFY_TMP/recovery.kernel"
gzip -dc "$VERIFY_TMP/sysupgrade.kernel.gz" \
	> "$VERIFY_TMP/sysupgrade.kernel"
xz -dc "$VERIFY_TMP/recovery.initrd.xz" > "$VERIFY_TMP/recovery.cpio"

cpio -it < "$VERIFY_TMP/recovery.cpio" > "$VERIFY_TMP/recovery.files" 2>/dev/null ||
	fail "recovery ramdisk is not a readable cpio archive"
grep -qx 'init' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain /init"
grep -qx 'usr/sbin/xr1710g-mesh-diag' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the installed XR1710G rootfs"
grep -qx 'usr/libexec/quickstart' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain QuickStart"
grep -qx 'www/luci-static/istore/index.js' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain iStore"
grep -qx 'www/luci-static/istorex/index.js' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the iStoreX home UI"
grep -qx 'www/luci-static/argon/css/cascade.css' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the Argon LuCI theme"
grep -qx 'usr/lib/lua/luci/controller/openclash.lua' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the OpenClash LuCI controller"
grep -qx 'usr/share/openclash/openclash.sh' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the OpenClash runtime"
grep -qx 'usr/share/openclash/ui/metacubexd/index.html' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the Metacubexd dashboard"
grep -qx 'usr/share/openclash/ui/zashboard/index.html' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the Zashboard dashboard"
grep -qx 'etc/openclash/core/clash_meta' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the bundled Mihomo Meta core"
grep -qx 'etc/crontabs/root' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain root's OpenClash crontab"
grep -qx 'etc/init.d/usteer' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the usteer init script"
if ! grep -Eq '^(sbin|usr/sbin)/usteerd$' "$VERIFY_TMP/recovery.files"; then
	fail "recovery ramdisk does not contain the usteer daemon"
fi
grep -qx 'etc/apk/repositories.d/distfeeds.list' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the pinned APK repositories"
grep -qx 'bin/is-opkg' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the iStore package wrapper"
grep -qx 'etc/uci-defaults/99-custom.sh' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain XR1710G first-boot defaults"
grep -qx 'etc/uci-defaults/41_uhttpd_proxy_linkease' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the LinkEase proxy policy"
grep -qx 'etc/uci-defaults/zz-xr1710g-services.sh' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain XR1710G service policy"
grep -qx 'usr/sbin/xr1710g-role' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the XR1710G role tool"
grep -qx 'usr/sbin/xr1710g-wireless-defaults' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the post-kmod wireless policy tool"
grep -qx 'etc/init.d/xr1710g-bootlog' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the persistent boot logger"
grep -qx 'etc/init.d/adguardhome' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the patched AdGuard Home service"
for docker_file in \
	usr/bin/dockerd \
	usr/bin/docker \
	usr/bin/containerd \
	usr/sbin/runc \
	usr/bin/docker-compose \
	etc/init.d/dockerd \
	etc/config/dockerd \
	usr/libexec/istore/docker \
	usr/share/rpcd/ucode/docker_rpc.uc \
	www/luci-static/resources/view/dockerman/overview.js \
	usr/sbin/xr1710g-wan-carrier \
	lib/upgrade/keep.d/xr1710g-docker; do
	grep -qx "$docker_file" "$VERIFY_TMP/recovery.files" ||
		fail "recovery ramdisk lacks upstream Docker integration: $docker_file"
done
if grep -Eq '^etc/rc.d/[SK][0-9][0-9]dockerd$' "$VERIFY_TMP/recovery.files"; then
	fail "recovery ramdisk starts Docker before the owner enables it"
fi
grep -qx 'usr/sbin/uhttpd' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain uhttpd"
grep -qx 'etc/uci-defaults/adguardhome' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the patched AdGuard Home defaults"
if grep -Eq '^etc/rc.d/[SK][0-9][0-9]adguardhome$' "$VERIFY_TMP/recovery.files"; then
	fail "recovery ramdisk enables AdGuard Home by default"
fi
grep -qx 'usr/libexec/rpcd/luci.airoha_npu' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the Airoha NPU RPC backend"
grep -qx 'usr/libexec/rpcd/luci.airoha_flowsense' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the Airoha FlowSense RPC backend"
grep -qx 'usr/libexec/xr1710g-status-common' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the shared XR1710G status core"
grep -qx 'www/luci-static/resources/view/airoha_npu/status.js' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the safe Airoha SoC frontend"
grep -qx 'www/luci-static/resources/view/airoha_flowsense/status.js' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the safe Airoha FlowSense frontend"
grep -qx 'www/luci-static/quickstart/index.js' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the QuickStart frontend"
grep -qx 'usr/lib/lua/luci/view/quickstart/main.htm' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the QuickStart template"
grep -qx 'www/luci-static/resources/view/fan/status.js' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the resilient fan status frontend"
grep -qx 'www/luci-static/resources/view/fan/settings.js' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the resilient fan settings frontend"
grep -qx 'usr/libexec/rpcd/luci.fan' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the Airoha fan RPC backend"
grep -qx 'etc/init.d/npu-jitter' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain the NPU jitter service"
grep -qx 'lib/preinit/00_preinit.conf' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain generated preinit addressing"
grep -qx 'etc/board.d/99-lan-ip' "$VERIFY_TMP/recovery.files" ||
	fail "recovery ramdisk does not contain generated default-LAN policy"

# Recovery and permanent sysupgrade are separate payloads. Checking only the
# initramfs can let a stale permanent rootfs pass unnoticed, so extract the
# FIT's rootfs loadable and prove that the files users actually requested are
# present there as well.
unsquashfs -s "$VERIFY_TMP/sysupgrade.rootfs" >/dev/null 2>&1 ||
	fail "sysupgrade rootfs is not a readable squashfs"
unsquashfs -ll "$VERIFY_TMP/sysupgrade.rootfs" > "$VERIFY_TMP/sysupgrade.files" 2>/dev/null ||
	fail "cannot list sysupgrade squashfs contents"
for installed in \
	'squashfs-root/usr/sbin/xr1710g-mesh-diag' \
	'squashfs-root/usr/libexec/quickstart' \
	'squashfs-root/www/luci-static/istore/index.js' \
	'squashfs-root/www/luci-static/istorex/index.js' \
	'squashfs-root/www/luci-static/argon/css/cascade.css' \
	'squashfs-root/usr/lib/lua/luci/controller/openclash.lua' \
	'squashfs-root/usr/share/openclash/openclash.sh' \
	'squashfs-root/usr/share/openclash/ui/metacubexd/index.html' \
	'squashfs-root/usr/share/openclash/ui/zashboard/index.html' \
	'squashfs-root/etc/openclash/core/clash_meta' \
	'squashfs-root/etc/crontabs/root' \
	'squashfs-root/etc/init.d/usteer' \
	'squashfs-root/etc/apk/repositories.d/distfeeds.list' \
	'squashfs-root/bin/is-opkg' \
	'squashfs-root/etc/uci-defaults/99-custom.sh' \
	'squashfs-root/etc/uci-defaults/41_uhttpd_proxy_linkease' \
	'squashfs-root/etc/uci-defaults/zz-xr1710g-services.sh' \
	'squashfs-root/usr/sbin/xr1710g-role' \
	'squashfs-root/usr/sbin/xr1710g-wan-carrier' \
	'squashfs-root/usr/sbin/xr1710g-wireless-defaults' \
	'squashfs-root/etc/init.d/xr1710g-bootlog' \
	'squashfs-root/etc/init.d/adguardhome' \
	'squashfs-root/usr/bin/dockerd' \
	'squashfs-root/usr/bin/docker' \
	'squashfs-root/usr/bin/containerd' \
	'squashfs-root/usr/sbin/runc' \
	'squashfs-root/usr/bin/docker-compose' \
	'squashfs-root/etc/init.d/dockerd' \
	'squashfs-root/etc/config/dockerd' \
	'squashfs-root/usr/libexec/istore/docker' \
	'squashfs-root/usr/share/rpcd/ucode/docker_rpc.uc' \
	'squashfs-root/www/luci-static/resources/view/dockerman/overview.js' \
	'squashfs-root/lib/upgrade/keep.d/xr1710g-docker' \
	'squashfs-root/usr/sbin/uhttpd' \
	'squashfs-root/etc/uci-defaults/adguardhome' \
	'squashfs-root/lib/preinit/00_preinit.conf' \
	'squashfs-root/etc/board.d/99-lan-ip' \
	'squashfs-root/usr/libexec/rpcd/luci.airoha_npu' \
	'squashfs-root/usr/libexec/rpcd/luci.airoha_flowsense' \
	'squashfs-root/usr/libexec/xr1710g-status-common' \
	'squashfs-root/www/luci-static/resources/view/airoha_npu/status.js' \
	'squashfs-root/www/luci-static/resources/view/airoha_flowsense/status.js' \
	'squashfs-root/www/luci-static/quickstart/index.js' \
	'squashfs-root/usr/lib/lua/luci/view/quickstart/main.htm' \
	'squashfs-root/www/luci-static/resources/view/fan/status.js' \
	'squashfs-root/www/luci-static/resources/view/fan/settings.js'; do
	grep -Fq " $installed" "$VERIFY_TMP/sysupgrade.files" ||
		fail "sysupgrade rootfs does not contain ${installed#squashfs-root/}"
done
if ! grep -Eq ' squashfs-root/(sbin|usr/sbin)/usteerd$' \
	"$VERIFY_TMP/sysupgrade.files"; then
	fail "sysupgrade rootfs does not contain the usteer daemon"
fi
if grep -Eq ' squashfs-root/etc/rc.d/[SK][0-9][0-9]adguardhome$' \
	"$VERIFY_TMP/sysupgrade.files"; then
	fail "sysupgrade rootfs enables AdGuard Home by default"
fi
if grep -Eq ' squashfs-root/etc/rc.d/[SK][0-9][0-9]dockerd$' \
	"$VERIFY_TMP/sysupgrade.files"; then
	fail "sysupgrade rootfs starts Docker before the owner enables it"
fi

mkdir "$VERIFY_TMP/core-root"
(
	cd "$VERIFY_TMP/core-root"
	cpio -idmu \
		'etc/openclash/core/clash_meta' \
		'etc/crontabs/root' \
		'etc/init.d/openclash' \
		'etc/init.d/usteer' \
		'etc/apk/repositories.d/distfeeds.list' \
		'etc/uci-defaults/99-custom.sh' \
		'etc/uci-defaults/41_uhttpd_proxy_linkease' \
		'etc/uci-defaults/zz-xr1710g-services.sh' \
		'usr/sbin/xr1710g-role' \
		'usr/sbin/xr1710g-wan-carrier' \
		'usr/sbin/xr1710g-wireless-defaults' \
		'etc/init.d/xr1710g-bootlog' \
		'etc/init.d/adguardhome' \
		'etc/init.d/dockerd' \
		'etc/config/dockerd' \
		'usr/libexec/istore/docker' \
		'www/luci-static/resources/view/dockerman/overview.js' \
		'lib/upgrade/keep.d/xr1710g-docker' \
		'lib/upgrade/platform.sh' \
		'lib/firmware/regulatory.db' \
		'usr/sbin/uhttpd' \
		'etc/uci-defaults/adguardhome' \
		'lib/preinit/00_preinit.conf' \
		'etc/board.d/99-lan-ip' \
		'bin/is-opkg' \
		'usr/libexec/rpcd/luci.airoha_npu' \
		'usr/libexec/rpcd/luci.airoha_flowsense' \
		'usr/libexec/xr1710g-status-common' \
		'www/luci-static/resources/view/airoha_npu/status.js' \
		'www/luci-static/resources/view/airoha_flowsense/status.js' \
		'www/luci-static/quickstart/index.js' \
		'usr/lib/lua/luci/view/quickstart/main.htm' \
		'www/luci-static/resources/view/fan/status.js' \
		'www/luci-static/resources/view/fan/settings.js' \
		'www/luci-static/resources/view/network/wireless.js' \
		'usr/libexec/rpcd/luci.fan' \
		'etc/init.d/npu-jitter' \
		< "$VERIFY_TMP/recovery.cpio" 2>/dev/null
) || fail "cannot extract files required for package-source validation"

unsquashfs -d "$VERIFY_TMP/permanent-root" "$VERIFY_TMP/sysupgrade.rootfs" \
	etc/openclash/core/clash_meta \
	etc/crontabs/root \
	etc/init.d/openclash \
	etc/init.d/usteer \
	etc/apk/repositories.d/distfeeds.list \
	etc/uci-defaults/99-custom.sh \
	etc/uci-defaults/41_uhttpd_proxy_linkease \
	etc/uci-defaults/zz-xr1710g-services.sh \
	usr/sbin/xr1710g-role \
	usr/sbin/xr1710g-wan-carrier \
	usr/sbin/xr1710g-wireless-defaults \
	etc/init.d/xr1710g-bootlog \
	etc/init.d/adguardhome \
	etc/init.d/dockerd \
	etc/config/dockerd \
	usr/libexec/istore/docker \
	www/luci-static/resources/view/dockerman/overview.js \
	lib/upgrade/keep.d/xr1710g-docker \
	lib/upgrade/platform.sh \
	lib/firmware/regulatory.db \
	usr/sbin/uhttpd \
	etc/uci-defaults/adguardhome \
	lib/preinit/00_preinit.conf \
	etc/board.d/99-lan-ip \
	bin/is-opkg \
	usr/libexec/rpcd/luci.airoha_npu \
	usr/libexec/rpcd/luci.airoha_flowsense \
	usr/libexec/xr1710g-status-common \
	www/luci-static/resources/view/airoha_npu/status.js \
	www/luci-static/resources/view/airoha_flowsense/status.js \
	www/luci-static/quickstart/index.js \
	usr/lib/lua/luci/view/quickstart/main.htm \
	www/luci-static/resources/view/fan/status.js \
	www/luci-static/resources/view/fan/settings.js \
	www/luci-static/resources/view/network/wireless.js \
	usr/libexec/rpcd/luci.fan \
	etc/init.d/npu-jitter >/dev/null 2>&1 ||
	fail "cannot extract files required for permanent-rootfs validation"

# Do not accept a merely successful compile.  Recovery and permanent images
# must carry the exact stripped modules that completed the two-router A/B and
# 60-second soak tests on 2026-08-02.
mkdir "$VERIFY_TMP/recovery-mt76"
(
	cd "$VERIFY_TMP/recovery-mt76"
	cpio -idmu \
		'lib/modules/*/mt76.ko' \
		'lib/modules/*/mt76-connac-lib.ko' \
		'lib/modules/*/mt7996e.ko' \
		< "$VERIFY_TMP/recovery.cpio" 2>/dev/null
) || fail "cannot extract mt76 modules from recovery"
unsquashfs -d "$VERIFY_TMP/permanent-mt76" "$VERIFY_TMP/sysupgrade.rootfs" \
	'lib/modules/*/mt76.ko' \
	'lib/modules/*/mt76-connac-lib.ko' \
	'lib/modules/*/mt7996e.ko' >/dev/null 2>&1 ||
	fail "cannot extract mt76 modules from permanent rootfs"

verify_tested_module() {
	module="$1"
	expected="$2"
	recovery_module="$(find "$VERIFY_TMP/recovery-mt76/lib/modules" -type f \
		-name "$module" -print -quit)"
	permanent_module="$(find "$VERIFY_TMP/permanent-mt76/lib/modules" -type f \
		-name "$module" -print -quit)"
	[ -n "$recovery_module" ] || fail "recovery is missing $module"
	[ -n "$permanent_module" ] || fail "permanent rootfs is missing $module"
	cmp "$recovery_module" "$permanent_module" ||
		fail "recovery and permanent rootfs differ at $module"
	actual="$(sha256sum "$permanent_module" | awk '{ print $1 }')"
	[ "$actual" = "$expected" ] ||
		fail "$module does not match the A/B-tested module: $actual"
}

verify_tested_module mt76.ko \
	b8a82417f4df72277c8623e33939674cf14a33ac9d473315b593c0420a543a80
verify_tested_module mt76-connac-lib.ko \
	0d2f8c5eb501e1f94e4d3452912b66967e7beadfdcf8ed00c729d73b7c4c7d40
verify_tested_module mt7996e.ko \
	bcf4660268e9252e1ad401811b49fd615edb44fb787aa51731fd82818da58585

for critical in \
	etc/openclash/core/clash_meta \
	etc/crontabs/root \
	etc/init.d/openclash \
	etc/init.d/usteer \
	etc/apk/repositories.d/distfeeds.list \
	etc/uci-defaults/99-custom.sh \
	etc/uci-defaults/41_uhttpd_proxy_linkease \
	etc/uci-defaults/zz-xr1710g-services.sh \
	usr/sbin/xr1710g-role \
	usr/sbin/xr1710g-wan-carrier \
	usr/sbin/xr1710g-wireless-defaults \
	etc/init.d/xr1710g-bootlog \
	etc/init.d/adguardhome \
	lib/upgrade/platform.sh \
	lib/firmware/regulatory.db \
	usr/sbin/uhttpd \
	etc/uci-defaults/adguardhome \
	lib/preinit/00_preinit.conf \
	etc/board.d/99-lan-ip \
	bin/is-opkg \
	usr/libexec/rpcd/luci.airoha_npu \
	usr/libexec/rpcd/luci.airoha_flowsense \
	usr/libexec/xr1710g-status-common \
	www/luci-static/resources/view/airoha_npu/status.js \
	www/luci-static/resources/view/airoha_flowsense/status.js \
	www/luci-static/quickstart/index.js \
	usr/lib/lua/luci/view/quickstart/main.htm \
	www/luci-static/resources/view/fan/status.js \
	www/luci-static/resources/view/fan/settings.js \
	www/luci-static/resources/view/network/wireless.js \
	www/luci-static/resources/view/dockerman/overview.js \
	usr/libexec/rpcd/luci.fan \
	etc/init.d/npu-jitter; do
	cmp "$VERIFY_TMP/core-root/$critical" "$VERIFY_TMP/permanent-root/$critical" ||
		fail "recovery and permanent rootfs differ at /$critical"
done

# Validate the actual contents carried by both flashable images. XZ is an
# explicit composite profile, while standard US remains the normal default.
expected_regdb="$TOPDIR/build_dir/target-aarch64_cortex-a53_musl/wireless-regdb-2026.05.30/regulatory.db"
[ -f "$expected_regdb" ] || fail "compiled wireless regulatory database is missing"
for image_root in "$VERIFY_TMP/core-root" "$VERIFY_TMP/permanent-root"; do
	image_regdb="$image_root/lib/firmware/regulatory.db"
	image_wireless_js="$image_root/www/luci-static/resources/view/network/wireless.js"
	cmp "$expected_regdb" "$image_regdb" ||
		fail "image regulatory database differs from the reviewed XZ build"
	grep -Fq 'XR1710G composite laboratory profile (AU 2.4/5 GHz + 6 GHz 36 dBm, no AFC)' "$image_wireless_js" ||
		fail "image LuCI lacks the explicit XZ laboratory selector"
	grep -Fq 'all three bands through one shared PHY' "$image_wireless_js" ||
		fail "image LuCI lacks the shared-PHY regulatory explanation"
	grep -Eq "uci\.set\('wireless',[[:space:]]*radio\['\.name'\],[[:space:]]*'country',[[:space:]]*'XZ'\)" "$image_wireless_js" ||
		fail "image LuCI lacks deterministic shared-PHY XZ persistence"
	grep -Fq 'XZ is not a country regulatory domain' "$image_wireless_js" ||
		fail "image LuCI lacks the XZ no-AFC warning"
	if grep -RIEq "set wireless\.[^[:space:]]+\.country=['\"]?XZ|option country ['\"]?XZ" \
		"$image_root/etc" "$image_root/usr/sbin/xr1710g-wireless-defaults"; then
		fail "image enables XZ laboratory mode without owner action"
	fi
done

# LinkEase Full remains optional, but its package expects the base system to
# provide the /apps same-origin mapping. Verify both the compiled capability
# and the inert policy script without preinstalling the backend.
for image_root in "$VERIFY_TMP/core-root" "$VERIFY_TMP/permanent-root"; do
	image_uhttpd="$image_root/usr/sbin/uhttpd"
	[ -x "$image_uhttpd" ] || fail "image uhttpd is not executable"
	strings "$image_uhttpd" | grep -Fq 'X-Forwarded-Proto' ||
		fail "image uhttpd lacks the reverse-proxy feature"
	proxy_policy="$image_root/etc/uci-defaults/41_uhttpd_proxy_linkease"
	[ -x "$proxy_policy" ] || fail "LinkEase proxy policy is not executable"
	grep -Fq "add_list uhttpd.main.proxy_prefix='/apps=http://127.0.0.1:19290'" \
		"$proxy_policy" || fail "LinkEase /apps mapping is missing or unexpected"
done

# v8 retains v7's deliberate clean-boot/factory-reset address change. Validate the
# generated files carried by both deliverables, not merely the build .config:
# config_generate consumes 99-lan-ip for normal LAN setup, while preinit uses
# 00_preinit.conf for recovery/failsafe networking.
for image_root in "$VERIFY_TMP/core-root" "$VERIFY_TMP/permanent-root"; do
	preinit_conf="$image_root/lib/preinit/00_preinit.conf"
	lan_policy="$image_root/etc/board.d/99-lan-ip"
	grep -Fqx 'pi_ip="192.168.50.1"' "$preinit_conf" ||
		fail "image preinit address is not 192.168.50.1"
	grep -Fqx 'pi_netmask="255.255.255.0"' "$preinit_conf" ||
		fail "image preinit netmask is not 255.255.255.0"
	grep -Fqx 'pi_broadcast="192.168.50.255"' "$preinit_conf" ||
		fail "image preinit broadcast is not 192.168.50.255"
	grep -Fqx 'json_add_string ipaddr "192.168.50.1"' "$lan_policy" ||
		fail "image default LAN address is not 192.168.50.1"
	grep -Fqx 'json_add_string netmask "255.255.255.0"' "$lan_policy" ||
		fail "image default LAN netmask is not 255.255.255.0"
done

core="$VERIFY_TMP/core-root/etc/openclash/core/clash_meta"
[ -x "$core" ] || fail "bundled Mihomo Meta core is not executable"
[ "$(wc -c < "$core")" -eq 10266424 ] ||
	fail "bundled Mihomo Meta core has an unexpected size"
core_sha256="$(sha256sum "$core" | awk '{ print $1 }')"
[ "$core_sha256" = "ceb3fb6715aa6b922851126fa41980489aedd8e3e47fd767380b6d76317c1981" ] ||
	fail "bundled Mihomo Meta core checksum is unexpected: $core_sha256"

openclash_init="$VERIFY_TMP/core-root/etc/init.d/openclash"
grep -Fq 'SAFE_PATHS=/usr/share/openclash:/etc/ssl' "$openclash_init" ||
	fail "OpenClash init does not preserve the standard SAFE_PATHS"
if grep -Eq 'SAFE_PATHS=.*(/tmp|/www)|ui_path=.*/(tmp|www)' "$openclash_init"; then
	fail "OpenClash init redirects its dashboard outside the standard UI path"
fi

root_crontab="$VERIFY_TMP/core-root/etc/crontabs/root"
[ "$(stat -c '%a' "$root_crontab")" = "600" ] ||
	fail "root crontab mode is not 0600"

distfeeds="$VERIFY_TMP/core-root/etc/apk/repositories.d/distfeeds.list"
[ "$(grep -c '^https://downloads\.openwrt\.org/' "$distfeeds")" -eq 7 ] ||
	fail "APK distfeeds does not contain exactly seven official repositories"
if grep -Eq '/releases/SNAPSHOT|/(istore|linkease|openclash|kenzok8|sirpdboy|wukongdaily|nikki)/' \
	"$distfeeds"; then
	fail "APK distfeeds contains a nonexistent or third-party OpenWrt repository"
fi

is_opkg="$VERIFY_TMP/core-root/bin/is-opkg"
grep -Fq -- '--repositories-file ${SYSTEM_REPOSITORIES} "$@"' "$is_opkg" ||
	fail "iStore APK wrapper does not use the reviewed system repository whitelist"
grep -Fq 'SYSTEM_REPOSITORIES=/etc/apk/repositories.d/distfeeds.list' "$is_opkg" ||
	fail "iStore APK wrapper has no fixed system repository whitelist"
grep -Fq 'apk_wrap add --simulate "$@"' "$is_opkg" ||
	fail "iStore APK installs have no dependency preflight"
grep -Fq 'apk_wrap upgrade --simulate "$@"' "$is_opkg" ||
	fail "iStore APK upgrades have no dependency preflight"
grep -Fq 'apk_wrap "$action" --simulate "$@"' "$is_opkg" ||
	fail "iStore direct APK transactions have no dependency preflight"
grep -Fq 'Preflight dependency resolution failed; no packages were changed.' "$is_opkg" ||
	fail "iStore APK dependency failures are not fail-closed"

for image_root in "$VERIFY_TMP/core-root" "$VERIFY_TMP/permanent-root"; do
	quickstart_js="$image_root/www/luci-static/quickstart/index.js"
	[ "$(grep -Fo '.linkState!=="UP"' "$quickstart_js" | wc -l)" -eq 5 ] ||
		fail "QuickStart does not treat non-UP physical link states as disconnected"
	if grep -Fq '.linkState=="DOWN"' "$quickstart_js"; then
		fail "QuickStart still misclassifies LOWERLAYERDOWN as connected"
	fi
	grep -Fq 'index.js?v=xr-linkstate1' \
		"$image_root/usr/lib/lua/luci/view/quickstart/main.htm" ||
		fail "QuickStart link-state fix has no browser cache bust"
done

for image_root in "$VERIFY_TMP/core-root" "$VERIFY_TMP/permanent-root"; do
	grep -Fq 'callFanStatus().catch(function() { return {}; })' \
		"$image_root/www/luci-static/resources/view/fan/status.js" ||
		fail "fan status page does not degrade safely after an RPC failure"
	grep -Fq 'catch(function() { return null; })' \
		"$image_root/www/luci-static/resources/view/fan/status.js" ||
		fail "fan status polling can still reject the whole LuCI page"
	grep -Fq 'callGetAllCurves().catch(function() { return {}; })' \
		"$image_root/www/luci-static/resources/view/fan/settings.js" ||
		fail "fan settings page does not degrade safely after an RPC failure"
done

firstboot="$VERIFY_TMP/core-root/etc/uci-defaults/99-custom.sh"
wireless_defaults="$VERIFY_TMP/core-root/usr/sbin/xr1710g-wireless-defaults"
platform_upgrade="$VERIFY_TMP/core-root/lib/upgrade/platform.sh"
grep -Fq 'XR1710G UBI 2.0 boundaries are not active; refusing normal sysupgrade.' \
	"$platform_upgrade" ||
	fail "permanent image lacks the fail-closed XR1710G layout guard"
for boundary in \
	'vendor 00600000' \
	'chainloader 00100000' \
	'ubi 1b700000' \
	'reserved_bmt 04200000'; do
	grep -Fq "xr_mtd_size_is $boundary" "$platform_upgrade" ||
		fail "permanent platform guard lacks boundary: $boundary"
done
grep -Fq "touch /etc/crontabs/root" "$firstboot" ||
	fail "first-boot defaults do not repair a missing root crontab"
grep -Fq "chmod 0600 /etc/crontabs/root" "$firstboot" ||
	fail "first-boot defaults do not enforce root crontab mode 0600"
grep -Fq 'if ! /usr/sbin/xr1710g-wireless-defaults; then' "$firstboot" ||
	fail "first-boot defaults do not propagate a failed wireless policy"
grep -Fq "wireless_is_complete()" "$wireless_defaults" ||
	fail "wireless policy does not require a complete radio set"
grep -Fq "wifi config" "$wireless_defaults" ||
	fail "wireless policy does not rerun discovery after kmodloader"
for required_band in 2g 5g 6g; do
	grep -Fq "radios_for_band $required_band" "$wireless_defaults" ||
		fail "wireless policy does not require the $required_band radio"
done
grep -Fq "encryption='psk-mixed'" "$wireless_defaults" ||
	fail "2.4 GHz defaults do not provide WPA/WPA2 compatibility"
grep -Fq "uapsd='0'" "$wireless_defaults" ||
	fail "post-kmod AP defaults do not carry the board U-APSD stability setting"
grep -Fq "disassoc_low_ack='0'" "$wireless_defaults" ||
	fail "post-kmod AP defaults do not carry the low-ACK stability setting"
grep -Fq "ieee80211k='1'" "$wireless_defaults" ||
	fail "AP defaults do not enable 802.11k"
grep -Fq "bss_transition='1'" "$wireless_defaults" ||
	fail "AP defaults do not enable 802.11v"
grep -Fq "ieee80211r='0'" "$wireless_defaults" ||
	fail "2.4 GHz defaults do not explicitly disable 802.11r"
grep -Fq "encryption='sae-mixed'" "$wireless_defaults" ||
	fail "5 GHz defaults do not use WPA2/WPA3 transition mode"
grep -Fq "wireless.\"\$radio\".channel='36'" "$wireless_defaults" ||
	fail "5 GHz defaults do not pin the tested channel 36 baseline"
grep -Fq "ieee80211r='1'" "$wireless_defaults" ||
	fail "5 GHz defaults do not enable 802.11r"
grep -Fq "mobility_domain='6616'" "$wireless_defaults" ||
	fail "5 GHz defaults do not set the shared mobility domain"
grep -Fq "ft_over_ds='0'" "$wireless_defaults" ||
	fail "5 GHz defaults do not use over-the-air FT"
grep -Fq "ft_psk_generate_local='1'" "$wireless_defaults" ||
	fail "5 GHz defaults do not generate FT PSK locally"
grep -Fq "mode='mesh'" "$wireless_defaults" ||
	fail "first-boot defaults do not select 802.11s for 6 GHz"
grep -Fq "mesh_id='XR1710G-6G-BACKHAUL'" "$wireless_defaults" ||
	fail "first-boot defaults do not set the 6 GHz mesh ID"
grep -Fq "htmode='EHT80'" "$wireless_defaults" ||
	fail "first-boot defaults do not use the stable EHT80 baseline"
grep -Fq "mesh_fwding='1'" "$wireless_defaults" ||
	fail "first-boot defaults do not enable mesh forwarding"
grep -Fq "delete_if_present wireless.\"\$iface\".owe_groups" "$wireless_defaults" ||
	fail "6 GHz Mesh defaults do not remove the unsupported OWE group option"
grep -Fq "xr1710g_wireless_defaults" "$wireless_defaults" ||
	fail "wireless policy has no one-shot completion marker"
grep -Fq "network.globals.packet_steering='1'" "$firstboot" ||
	fail "first-boot defaults do not enable packet steering"
grep -Fq "flow_offloading_hw='1'" "$firstboot" ||
	fail "first-boot defaults do not enable hardware flow offload"
if grep -Fq "mode='ap'" "$wireless_defaults" || grep -Fq "wds='1'" "$wireless_defaults"; then
	fail "first-boot defaults still contain the rejected AP-WDS backhaul"
fi
for quiet_option in \
	assoc_steering aggressiveness load_kick_enabled \
	band_steering_interval link_measurement_interval \
	min_snr roam_scan_snr roam_trigger_snr; do
	grep -Fq "usteer.@usteer[0].${quiet_option}='0'" "$firstboot" ||
		fail "usteer defaults do not disable $quiet_option"
done
grep -Fq 'uci -q delete usteer.@usteer[0].ssid_list' "$firstboot" ||
	fail "usteer defaults do not clear the SSID allow-list"
grep -Fq '/etc/init.d/usteer enable' "$firstboot" ||
	fail "first-boot defaults do not enable usteer"
if grep -Eiq "(leon|Lhc[[:alnum:]]{5,}|syl_[[:alnum:]_]{6,}|192\\.168\\.50\\.2([^0-9]|$))" \
	"$firstboot" "$wireless_defaults"; then
	fail "first-boot defaults contain a private SSID, credential, or deployment address"
fi

service_policy="$VERIFY_TMP/core-root/etc/uci-defaults/zz-xr1710g-services.sh"
grep -Fq '/etc/init.d/adguardhome disable' "$service_policy" ||
	fail "XR1710G service policy does not disable unconfigured AdGuard Home"
grep -Fq '[ ! -s "$agh_config" ]' "$service_policy" ||
	fail "XR1710G service policy does not preserve an existing AdGuard configuration"
grep -Fq '/etc/init.d/xr1710g-bootlog enable' "$service_policy" ||
	fail "XR1710G service policy does not enable the boot logger"

dockerd_config="$VERIFY_TMP/core-root/etc/config/dockerd"
dockerd_init="$VERIFY_TMP/core-root/etc/init.d/dockerd"
dockerman_overview="$VERIFY_TMP/core-root/www/luci-static/resources/view/dockerman/overview.js"
istore_docker="$VERIFY_TMP/core-root/usr/libexec/istore/docker"
docker_keep="$VERIFY_TMP/core-root/lib/upgrade/keep.d/xr1710g-docker"
grep -Fq "option data_root '/overlay/docker/'" "$dockerd_config" ||
	fail "Docker data root does not use the full writable UBIFS overlay"
grep -Fq "option log_driver 'local'" "$dockerd_config" ||
	fail "Docker does not use its bounded upstream local log driver"
grep -Fq "list log_opts 'max-size=5m'" "$dockerd_config" ||
	fail "Docker max-size policy is missing"
grep -Fq "list log_opts 'max-file=3'" "$dockerd_config" ||
	fail "Docker max-file policy is missing"
grep -Fq 'config_list_foreach globals log_opts json_add_log_option' "$dockerd_init" ||
	fail "installed OpenWrt dockerd wrapper cannot emit log-opts"
grep -Fq "handleEnableAndStart(ev)" "$dockerman_overview" ||
	fail "Dockerman stopped-state page lacks the enable-and-start action"
grep -Fq "Docker is installed but disabled by default" "$dockerman_overview" ||
	fail "Dockerman stopped-state page lacks an owner-facing explanation"
# LuCI may minify this file in the final image.  Normalize insignificant
# whitespace and require the stopped-daemon return to precede the request
# fan-out, so this verifies control flow in both source and minified output.
if ! tr -d '[:space:]' < "$dockerman_overview" |
	grep -Fq 'return[null,info,[],[],[],[],[]];returnPromise.all(['; then
	fail "Dockerman still fans out requests while the local daemon is stopped"
fi
grep -Fq 'uci -q get dockerd.globals.data_root' "$istore_docker" ||
	fail "iStore does not read the shared OpenWrt Docker data root"
grep -Fq 'uci set dockerd.globals.data_root="$dest"' "$istore_docker" ||
	fail "iStore cannot migrate the shared OpenWrt Docker data root"
grep -Fq '/etc/init.d/dockerd restart' "$istore_docker" ||
	fail "iStore does not control the shared OpenWrt dockerd service"
grep -Fqx '/etc/rc.d/S99dockerd' "$docker_keep" ||
	fail "an owner-enabled Docker service would not survive sysupgrade"
if grep -Eq '(^|[[:space:]])(enable|start|restart)([[:space:]]|$)' "$service_policy" |
	grep -q dockerd; then
	fail "first-boot policy starts Docker without owner action"
fi

adguard_defaults="$VERIFY_TMP/core-root/etc/uci-defaults/adguardhome"
adguard_init="$VERIFY_TMP/core-root/etc/init.d/adguardhome"
grep -Fq 'must never expose the setup service on a clean router' "$adguard_defaults" ||
	fail "AdGuard Home defaults do not suppress an unconfigured first-run service"
grep -Fq '[ -s "$config_file" ] || return 0' "$adguard_init" ||
	fail "AdGuard Home interface trigger can still restart an unconfigured service"

role_tool="$VERIFY_TMP/core-root/usr/sbin/xr1710g-role"
wan_carrier_tool="$VERIFY_TMP/core-root/usr/sbin/xr1710g-wan-carrier"
if grep -Eq '^board_name\(\)[[:space:]]*\{' "$role_tool"; then
	fail "XR1710G role tool shadows the optional board_name command"
fi
grep -Fq 'xr1710g_board_name()' "$role_tool" ||
	fail "XR1710G role tool lacks the non-shadowing board-name helper"
grep -Fq '[ -r /tmp/sysinfo/board_name ]' "$role_tool" ||
	fail "XR1710G role tool cannot identify an installed OpenWrt board"
grep -Fq 'delete_if_present()' "$role_tool" ||
	fail "XR1710G role tool can abort on an absent optional UCI setting"
grep -Fq "set network.wan.proto='pppoe'" "$role_tool" ||
	fail "XR1710G role tool does not configure PPPoE on WAN"
if grep -Fq "set network.lan.proto='pppoe'" "$role_tool"; then
	fail "XR1710G role tool can assign PPPoE to LAN"
fi
grep -Fq 'ip link set dev "$wan_device" up' "$wan_carrier_tool" ||
	fail "WAN carrier helper does not raise the physical device before checking carrier"
grep -Fq 'cat "/sys/class/net/$wan_device/carrier"' "$wan_carrier_tool" ||
	fail "WAN carrier helper does not read the selected physical device"
grep -Fq "set network.lan.ip6assign='64'" "$role_tool" ||
	fail "XR1710G role tool does not enable delegated IPv6 on a main-router LAN"
grep -Fq "set dhcp.lan.ra='disabled'" "$role_tool" ||
	fail "XR1710G node role does not disable IPv6 RA serving"
grep -Fq 'delete_if_present network.wan6' "$role_tool" ||
	fail "XR1710G role tool does not remove the stale physical-WAN wan6 section"
grep -Fq 'delete_if_present network.globals.ula_prefix' "$role_tool" ||
	fail "XR1710G node role does not remove its generated ULA prefix"
if grep -Ev "^[[:space:]]*#|^[[:space:]]*(echo|printf)[[:space:]]|^[[:space:]]*(reboot manually|Changes are backed up)" "$role_tool" |
	grep -Eq '(/etc/init.d/(network|dnsmasq|odhcpd|firewall|openclash)|wifi (reload|down|up)|(^|[[:space:]])reboot([[:space:]]|$))'; then
	fail "XR1710G role tool contains an automatic service reload or reboot"
fi

bootlog="$VERIFY_TMP/core-root/etc/init.d/xr1710g-bootlog"
grep -Fq "previous='non-ordered-shutdown'" "$bootlog" ||
	fail "XR1710G boot logger does not record a non-orderly previous shutdown"
grep -Fq 'does not distinguish power loss, watchdog and hard reset' "$bootlog" ||
	fail "XR1710G boot logger overstates its reset-cause capability"
grep -Fq 'MAX_LINES=80' "$bootlog" ||
	fail "XR1710G persistent boot history is not bounded"
grep -Fq "grep -q ' /overlay ' /proc/mounts" "$bootlog" ||
	fail "XR1710G boot logger does not avoid RAM-only Recovery sessions"

for executable in "$service_policy" "$adguard_defaults" "$adguard_init" \
	"$dockerd_init" "$istore_docker" \
	"$role_tool" "$wan_carrier_tool" "$wireless_defaults" "$bootlog"; do
	[ -x "$executable" ] || fail "$(basename "$executable") is not executable"
	if LC_ALL=C grep -q "$(printf '\r')" "$executable"; then
		fail "$(basename "$executable") contains CRLF line endings"
	fi
done

# Release images must never include deployment credentials or the temporary
# A/B rollback machinery used during driver experiments.  Search extracted
# regular files (excluding the verifier, which deliberately contains these
# sentinels) instead of raw compressed images, where byte coincidence is not a
# meaningful content match.
mkdir "$VERIFY_TMP/recovery-all"
(
	cd "$VERIFY_TMP/recovery-all"
	cpio -idmu < "$VERIFY_TMP/recovery.cpio" 2>/dev/null
) || fail "cannot extract complete recovery rootfs for secret scanning"
unsquashfs -d "$VERIFY_TMP/permanent-all" "$VERIFY_TMP/sysupgrade.rootfs" \
	>/dev/null 2>&1 || fail "cannot extract complete permanent rootfs for secret scanning"

# Package manifests alone cannot prove that image assembly installed the new
# monolithic wpad executable. Compare both deliverables with the r3 package
# payload built in this same release run.
wpad_r3_apk="$(find "$TOPDIR/bin/packages/aarch64_cortex-a53/base" -maxdepth 1 \
	-type f -name 'wpad-mesh-openssl-2026.04.02~b004de0b-r3.apk' -print -quit)"
[ -f "$wpad_r3_apk" ] || fail "WDS-fixed wpad r3 package is missing"
mkdir -p "$VERIFY_TMP/wpad-r3-apk"
"$TOPDIR/staging_dir/host/bin/apk" --allow-untrusted extract \
	--destination "$VERIFY_TMP/wpad-r3-apk" "$wpad_r3_apk" >/dev/null ||
	fail "cannot extract WDS-fixed wpad r3 package"
[ -x "$VERIFY_TMP/wpad-r3-apk/usr/sbin/wpad" ] ||
	fail "WDS-fixed package does not contain executable wpad"
wpad_r3_sha256="$(sha256sum "$VERIFY_TMP/wpad-r3-apk/usr/sbin/wpad" | cut -d' ' -f1)"
[ -n "$wpad_r3_sha256" ] || fail "cannot hash WDS-fixed wpad r3 binary"
for image_wpad in \
	"$VERIFY_TMP/recovery-all/usr/sbin/wpad" \
	"$VERIFY_TMP/permanent-all/usr/sbin/wpad"; do
	[ -x "$image_wpad" ] || fail "assembled image does not contain executable wpad"
	[ "$(sha256sum "$image_wpad" | cut -d' ' -f1)" = "$wpad_r3_sha256" ] ||
		fail "assembled image contains stale/non-r3 wpad: $image_wpad"
done
for forbidden in \
	'mt76-test-auto-rollback' 'mt76-ab-test'; do
	if grep -IrFq --exclude='verify-xr1710g-build.sh' "$forbidden" \
		"$VERIFY_TMP/recovery-all" "$VERIFY_TMP/permanent-all"; then
		fail "release rootfs contains forbidden private or experimental marker: $forbidden"
	fi
done
if grep -IrIEq --exclude='verify-xr1710g-build.sh' \
	--exclude='*.crt' --exclude='*.pem' --exclude='*.der' \
	'(ssid|mesh_id|key|password|passwd|secret|username|user)[^[:cntrl:]]{0,80}(leon(_5G)?|Lhc[[:alnum:]]{5,}|syl_[[:alnum:]_]{6,})' \
	"$VERIFY_TMP/recovery-all" "$VERIFY_TMP/permanent-all"; then
	fail "release rootfs contains a private SSID or credential"
fi

for backend in \
	"$VERIFY_TMP/core-root/usr/libexec/rpcd/luci.airoha_npu" \
	"$VERIFY_TMP/core-root/usr/libexec/rpcd/luci.airoha_flowsense"; do
	grep -Fq '\[HW_OFFLOAD\]' "$backend" ||
		fail "$(basename "$backend") does not detect Linux 6.18 hardware offload"
done

for executable in \
	"$VERIFY_TMP/core-root/usr/libexec/rpcd/luci.airoha_npu" \
	"$VERIFY_TMP/core-root/usr/libexec/rpcd/luci.airoha_flowsense" \
	"$VERIFY_TMP/core-root/usr/libexec/rpcd/luci.fan" \
	"$VERIFY_TMP/core-root/etc/init.d/npu-jitter"; do
	[ -x "$executable" ] || fail "$(basename "$executable") is not executable"
	if LC_ALL=C grep -q "$(printf '\r')" "$executable"; then
		fail "$(basename "$executable") contains CRLF line endings"
	fi
done

initrd_size="$(wc -c < "$VERIFY_TMP/recovery.cpio")"
[ "$initrd_size" -gt 10485760 ] ||
	fail "recovery ramdisk is too small to contain a usable rootfs"

for dtb in "$VERIFY_TMP/recovery.dtb" "$VERIFY_TMP/sysupgrade.dtb"; do
	compatible="$(fdtget -t s "$dtb" / compatible 2>/dev/null)" ||
		fail "cannot read compatible from embedded XR1710G DTB"
	printf '%s\n' "$compatible" | grep -Fq 'econet,xr1710g-ubi' ||
		fail "embedded DTB is not for econet,xr1710g-ubi"

	ubi_node="$(fdtget -l "$dtb" /soc/spi@1fa10000/nand@0/partitions 2>/dev/null |
		grep '^partition@700000$' | head -n1)"
	if [ -z "$ubi_node" ]; then
		ubi_node="$(fdtget -l "$dtb" /soc/spi@1fa10000/spi_nand@0/partitions 2>/dev/null |
			grep '^partition@700000$' | head -n1)"
	fi
	[ -n "$ubi_node" ] || fail "cannot locate the embedded UBI partition node"
	ubi_reg="$(fdtget -t x "$dtb" \
		"/soc/spi@1fa10000/nand@0/partitions/$ubi_node" reg 2>/dev/null ||
		fdtget -t x "$dtb" \
		"/soc/spi@1fa10000/spi_nand@0/partitions/$ubi_node" reg 2>/dev/null)"
	[ "$ubi_reg" = "700000 1b700000" ] ||
		fail "embedded DTB is not the XR1710G UBI 2.0 layout: $ubi_reg"
done

echo "VERIFY PASSED"
sha256sum "$recovery" "$sysupgrade"
