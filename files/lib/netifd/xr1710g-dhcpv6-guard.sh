#!/bin/sh
# One DHCPv6 client per L3 device. Never stop the existing working client.
# Configuration inspection runs in a subshell: config_load must not replace
# the PPP hook's JSON/environment state.
xr_dhcpv6_has_explicit() (
	. /lib/functions.sh
	local xr_parent="$1" xr_device="$2" xr_found=1
	[ -n "$xr_parent" ] && [ -n "$xr_device" ] || return 1
	config_load network || return 1
	xr_dhcpv6_match() {
		local section="$1" proto disabled auto device depth=0
		config_get proto "$section" proto
		[ "$proto" = dhcpv6 ] || return
		config_get_bool disabled "$section" disabled 0
		config_get_bool auto "$section" auto 1
		[ "$disabled" = 0 ] && [ "$auto" = 1 ] || return
		config_get device "$section" device
		[ -n "$device" ] || config_get device "$section" ifname
		while [ "$depth" -lt 16 ]; do
			case "$device" in
				"@$xr_parent"|"$xr_device") xr_found=0; return ;;
				@*) section="${device#@}"
					config_get device "$section" device
					[ -n "$device" ] || config_get device "$section" ifname ;;
				*) return ;;
			esac
			depth=$((depth + 1))
		done
	}
	config_foreach xr_dhcpv6_match interface
	return "$xr_found"
)

# Separate these small readers so regression tests can supply process fixtures
# without starting a DHCP client or touching a network interface.
xr_dhcpv6_pids() { pidof odhcp6c 2>/dev/null; }
xr_dhcpv6_device() { tr '\000' '\n' < "/proc/$1/cmdline" 2>/dev/null | tail -n 1; }
xr_dhcpv6_owner() { tr '\000' '\n' < "/proc/$1/environ" 2>/dev/null | sed -n 's/^INTERFACE=//p'; }

xr_dhcpv6_conflict() {
	local config="$1" device="$2" pid owner
	[ -n "$config" ] && [ -n "$device" ] || return 1
	for pid in $(xr_dhcpv6_pids); do
		case "$pid" in ''|*[!0-9]*) continue ;; esac
		[ "$(xr_dhcpv6_device "$pid")" = "$device" ] || continue
		owner="$(xr_dhcpv6_owner "$pid")"
		# An exiting process, or a process outside netifd ownership, cannot
		# safely identify another logical interface. Never kill or adopt it.
		[ -n "$owner" ] && [ "$owner" != "$config" ] || continue
		# Recheck after reading environ to tolerate ordinary process exit.
		[ "$(xr_dhcpv6_device "$pid")" = "$device" ] || continue
		return 0
	done
	return 1
}
