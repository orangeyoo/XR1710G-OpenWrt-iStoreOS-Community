#!/bin/sh
# XR1710G iStoreOS community port first-boot defaults.
# Keep this deliberately small: board-specific port and Wi-Fi defaults remain
# owned by target/linux/airoha so future hardware fixes are not overridden.

board_name="$(cat /tmp/sysinfo/board_name 2>/dev/null)"
[ "$board_name" = "econet,xr1710g-ubi" ] || exit 0

# Do not continue into the deliberately open first-boot AP policy if the
# earlier credential default failed. OpenWrt retains failed uci-defaults for a
# later retry, so this keeps the exceptional path closed without overwriting
# an owner-supplied hash.
root_hash="$(awk -F: '$1 == "root" { print $2; exit }' /etc/shadow 2>/dev/null)"
if [ -z "$root_hash" ]; then
	logger -t xr1710g-firstboot \
		'root credential is not ready; retaining first-boot defaults for retry' 2>/dev/null || true
	exit 1
fi

uci -q set system.@system[0].hostname='iStoreOS-XR1710G'
uci -q set luci.main.lang='zh_cn'
# luci-theme-argon's own 30_luci-theme-argon default selects Argon only when
# the theme is first installed. Register the theme here as a fallback, but do
# not rewrite mediaurlbase: a sysupgrade must preserve the owner's theme.
uci -q set luci.themes.Argon='/luci-static/argon'
uci -q set network.globals.packet_steering='1'
uci -q set firewall.@defaults[0].flow_offloading='1'
uci -q set firewall.@defaults[0].flow_offloading_hw='1'

# Ship OpenClash ready to configure, but never intercept traffic before the
# owner has supplied and reviewed a subscription/profile.
uci -q set openclash.config.enable='0'

# OpenClash appends its watchdog rules to root's crontab. An absent file makes
# OpenClash 0.47.133 stop at "Step 5: Add Cron Rules, Start Daemons...".
mkdir -p /etc/crontabs
touch /etc/crontabs/root
chmod 0600 /etc/crontabs/root

# The generic APK feed generator exposes every enabled build feed. Only the
# official OpenWrt feeds exist on downloads.openwrt.org; restore this known-good
# list on first boot so QuickStart never loops on nonexistent third-party URLs.
mkdir -p /etc/apk/repositories.d
cat > /etc/apk/repositories.d/distfeeds.list <<'REPOSEOF'
# This file is managed by the XR1710G community port.
https://downloads.openwrt.org/snapshots/targets/airoha/an7581/packages/packages.adb
https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/base/packages.adb
https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/luci/packages.adb
https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/packages/packages.adb
https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/routing/packages.adb
https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/telephony/packages.adb
https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/video/packages.adb
REPOSEOF

# Wireless discovery before kmodloader is empty on this board.  This helper
# runs now, after kmodloader, waits until all three bands and their interfaces
# exist, then atomically applies the open-AP/roaming/disabled-Mesh policy.
# A failure deliberately makes this uci-default remain for the next boot.
if ! /usr/sbin/xr1710g-wireless-defaults; then
	logger -t xr1710g-firstboot \
		'wireless policy was not applied; retaining first-boot defaults for retry' 2>/dev/null || true
	exit 1
fi

# Use usteer only to exchange neighbor information. The zero thresholds and
# disabled kick paths reproduce the non-aggressive profile that roamed well in
# the real two-floor test. Do not add ssid_list: an empty list means every SSID
# and keeps working after the owner renames the networks.
if uci -q show usteer.@usteer[0] >/dev/null 2>&1; then
	uci -q set usteer.@usteer[0].network='lan'
	uci -q set usteer.@usteer[0].enabled='1'
	uci -q set usteer.@usteer[0].assoc_steering='0'
	uci -q set usteer.@usteer[0].aggressiveness='0'
	uci -q set usteer.@usteer[0].load_kick_enabled='0'
	uci -q set usteer.@usteer[0].band_steering_interval='0'
	uci -q set usteer.@usteer[0].link_measurement_interval='0'
	uci -q set usteer.@usteer[0].min_snr='0'
	uci -q set usteer.@usteer[0].roam_scan_snr='0'
	uci -q set usteer.@usteer[0].roam_trigger_snr='0'
	uci -q delete usteer.@usteer[0].ssid_list
	uci -q commit usteer
	/etc/init.d/usteer enable
fi

uci -q commit system
uci -q commit luci
uci -q commit openclash
uci -q commit network
uci -q commit firewall

exit 0
