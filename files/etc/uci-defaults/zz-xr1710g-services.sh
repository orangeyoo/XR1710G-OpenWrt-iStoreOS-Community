#!/bin/sh
# Service policy applied after package-owned UCI defaults on first boot.

[ "$(cat /tmp/sysinfo/board_name 2>/dev/null)" = 'econet,xr1710g-ubi' ] || exit 0

# Favor deterministic latency on this four-core router. Store the default in
# UCI and let the dedicated boot service replay the owner's later selection on
# every boot instead of making this one-shot uci-default the source of truth.
uci -q set system.@system[0].xr1710g_governor='performance'
uci -q commit system
if [ -x /etc/init.d/xr1710g-cpufreq ]; then
	/etc/init.d/xr1710g-cpufreq enable
	/etc/init.d/xr1710g-cpufreq start
fi

if [ -x /etc/init.d/xr1710g-uboot-recovery-restore ]; then
	/etc/init.d/xr1710g-uboot-recovery-restore enable
fi

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
