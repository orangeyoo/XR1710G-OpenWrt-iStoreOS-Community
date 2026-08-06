#!/bin/sh
# Service policy applied after package-owned UCI defaults on first boot.

[ "$(cat /tmp/sysinfo/board_name 2>/dev/null)" = 'econet,xr1710g-ubi' ] || exit 0

# AdGuard Home is optional.  A fresh image must not expose its setup port or
# compete with dnsmasq for port 53 before the owner explicitly enables it.
if [ -x /etc/init.d/adguardhome ]; then
	agh_config="$(uci -q get adguardhome.config.config_file 2>/dev/null || true)"
	agh_legacy="$(uci -q get adguardhome.config.config 2>/dev/null || true)"
	[ -n "$agh_config" ] || agh_config='/etc/adguardhome/adguardhome.yaml'
	if [ ! -s "$agh_config" ] && { [ -z "$agh_legacy" ] || [ ! -s "$agh_legacy" ]; }; then
		/etc/init.d/adguardhome stop >/dev/null 2>&1 || true
		/etc/init.d/adguardhome disable >/dev/null 2>&1 || true
	fi
fi

# This logger performs no network action.  It records only whether the prior
# boot reached an orderly shutdown path; it cannot identify a watchdog reset.
if [ -x /etc/init.d/xr1710g-bootlog ]; then
	/etc/init.d/xr1710g-bootlog enable
	/etc/init.d/xr1710g-bootlog start
fi

exit 0
