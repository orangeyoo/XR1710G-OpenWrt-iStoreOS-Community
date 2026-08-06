#!/bin/sh
set -eu

BUILDER="${1:-/builder}"
ROLE_SRC="$BUILDER/files/usr/sbin/xr1710g-role"
BOOTLOG_SRC="$BUILDER/files/etc/init.d/xr1710g-bootlog"
POLICY_SRC="$BUILDER/files/etc/uci-defaults/zz-xr1710g-services.sh"
WIRELESS_SRC="$BUILDER/files/usr/sbin/xr1710g-wireless-defaults"

fail() {
	echo "TOOL TEST FAILED: $*" >&2
	exit 1
}

for script in "$ROLE_SRC" "$BOOTLOG_SRC" "$POLICY_SRC" "$WIRELESS_SRC"; do
	[ -f "$script" ] || fail "missing $script"
	sh -n "$script" || fail "syntax error in $script"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM
mkdir -p "$tmp/bin" "$tmp/state"

cat > "$tmp/bin/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = '-u' ] && { echo 0; exit 0; }
exec /usr/bin/id "$@"
EOF

cat > "$tmp/bin/board_name" <<'EOF'
#!/bin/sh
echo econet,xr1710g-ubi
EOF

cat > "$tmp/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF

cat > "$tmp/bin/wifi" <<'EOF'
#!/bin/sh
set -eu
[ "${1:-}" = 'config' ] || exit 1
db="${XR_TEST_STATE:?}/uci.db"

# Match the real boot sequence: no wireless UCI exists before this command.
# The fixture then represents mac80211 discovery after kmodloader.
if ! grep -q '^wireless\.radio0\.band=' "$db"; then
	cat >> "$db" <<'RADIOS'
wireless.radio0.band=2g
wireless.default_radio0.device=radio0
wireless.default_radio0.mode=ap
wireless.default_radio0.ssid=XR1710G
wireless.default_radio0.encryption=none
wireless.default_radio0.disabled=0
wireless.radio1.band=5g
wireless.default_radio1.device=radio1
wireless.default_radio1.mode=ap
wireless.default_radio1.ssid=XR1710G-5G
wireless.default_radio1.encryption=none
wireless.default_radio1.disabled=0
RADIOS
	if [ "${XR_TEST_WIFI_MODE:-complete}" = 'complete' ]; then
		cat >> "$db" <<'RADIO6'
wireless.radio2.band=6g
wireless.default_radio2.device=radio2
wireless.default_radio2.mode=ap
wireless.default_radio2.ssid=XR1710G-6G
wireless.default_radio2.encryption=owe
wireless.default_radio2.owe_groups=19
wireless.default_radio2.disabled=0
RADIO6
	fi
fi
EOF

cat > "$tmp/bin/ipcalc.sh" <<'EOF'
#!/bin/sh
case "$1" in
	192.168.10.0/24) ip=192.168.10.0; network=192.168.10.0 ;;
	192.168.10.1/24) ip=192.168.10.1; network=192.168.10.0 ;;
	192.168.10.2/24) ip=192.168.10.2; network=192.168.10.0 ;;
	192.168.20.1/24) ip=192.168.20.1; network=192.168.20.0 ;;
	*) exit 1 ;;
esac
echo "IP=$ip"
echo 'NETMASK=255.255.255.0'
echo "NETWORK=$network"
echo "BROADCAST=${network%.*}.255"
echo 'PREFIX=24'
EOF

cat > "$tmp/bin/uci" <<'EOF'
#!/bin/sh
set -eu
db="${XR_TEST_STATE:?}/uci.db"
touch "$db"
cmd="${1:-}"
[ "$cmd" != '-q' ] || { shift; cmd="${1:-}"; }
shift || true
case "$cmd" in
	get)
		key="$1"
		awk -v key="$key" 'index($0, key "=") == 1 { print substr($0, length(key) + 2) }' \
			"$db" | tail -n1
		;;
	show)
		key="${1:-}"
		if [ -z "$key" ]; then
			cat "$db"
		else
			awk -v key="$key" \
				'index($0, key "=") == 1 || index($0, key ".") == 1' "$db"
		fi
		;;
	set)
		assignment="$1"; key="${assignment%%=*}"; value="${assignment#*=}"
		awk -v key="$key" 'index($0, key "=") != 1' "$db" > "$db.tmp"
		mv "$db.tmp" "$db"
		printf '%s=%s\n' "$key" "$value" >> "$db"
		;;
	add_list)
		assignment="$1"; key="${assignment%%=*}"; value="${assignment#*=}"
		old="$(awk -v key="$key" \
			'index($0, key "=") == 1 { print substr($0, length(key) + 2) }' \
			"$db" | tail -n1)"
		awk -v key="$key" 'index($0, key "=") != 1' "$db" > "$db.tmp"
		mv "$db.tmp" "$db"
		printf '%s=%s%s%s\n' "$key" "$old" "${old:+ }" "$value" >> "$db"
		;;
	delete)
		key="$1"
		if ! awk -v key="$key" \
			'index($0, key "=") == 1 || index($0, key ".") == 1 { found=1 } END { exit !found }' \
			"$db"; then
			exit 1
		fi
		awk -v key="$key" 'index($0, key "=") != 1 && index($0, key ".") != 1' \
			"$db" > "$db.tmp"
		mv "$db.tmp" "$db"
		;;
	commit) : ;;
	export)
		case "$1" in
			network|dhcp|system) grep -E "^$1\." "$db" || true ;;
			*) exit 1 ;;
		esac
		;;
	*) echo "unsupported test uci command: $cmd" >&2; exit 1 ;;
esac
EOF

chmod 0755 "$tmp/bin"/*
export XR_TEST_STATE="$tmp/state"
export PATH="$tmp/bin:/usr/bin:/bin"
cat > "$XR_TEST_STATE/uci.db" <<'EOF'
network.lan.proto=static
network.lan.device=br-lan
network.lan.ipaddr=192.168.50.1
network.lan.netmask=255.255.255.0
network.wan.device=wan
network.wan.proto=dhcp
dhcp.lan.ignore=0
network.globals.ula_prefix=fd00::/48
EOF

role="$tmp/xr1710g-role"
cp "$ROLE_SRC" "$role"
chmod 0755 "$role"

# The real image has /tmp/sysinfo/board_name but no standalone board_name
# executable.  A helper named board_name() shadows command discovery in ash;
# reject that regression explicitly before exercising the PATH-backed fixture.
if grep -Eq '^board_name\(\)[[:space:]]*\{' "$ROLE_SRC"; then
	fail 'role tool shadows the optional board_name command with a shell function'
fi
grep -Fq 'xr1710g_board_name()' "$ROLE_SRC" ||
	fail 'role tool lacks the non-shadowing board-name helper'
grep -Fq '[ -r /tmp/sysinfo/board_name ]' "$ROLE_SRC" ||
	fail 'role tool does not support the installed /tmp/sysinfo board identity'
grep -Fq 'delete_if_present()' "$ROLE_SRC" ||
	fail 'role tool does not make optional UCI deletes idempotent'

"$role" main-dhcp 192.168.10.1/24 > "$tmp/main.out"
grep -qx "network.lan.ipaddr=192.168.10.1" "$XR_TEST_STATE/uci.db" ||
	fail 'main-dhcp did not set the requested LAN address'
grep -qx 'network.lan.ip6assign=64' "$XR_TEST_STATE/uci.db" ||
	fail 'main-dhcp did not enable LAN IPv6 delegation'
grep -qx 'network.wan.proto=dhcp' "$XR_TEST_STATE/uci.db" ||
	fail 'main-dhcp did not keep DHCP on WAN'
if grep -q 'network.lan.proto=pppoe' "$XR_TEST_STATE/uci.db"; then
	fail 'main-dhcp assigned PPPoE to LAN'
fi

"$role" node 192.168.10.2/24 192.168.10.1 > "$tmp/node.out"
grep -qx "network.lan.ipaddr=192.168.10.2" "$XR_TEST_STATE/uci.db" ||
	fail 'node did not set the requested management address'
grep -qx "network.lan.gateway=192.168.10.1" "$XR_TEST_STATE/uci.db" ||
	fail 'node did not set the main router as gateway'
grep -qx 'dhcp.lan.ignore=1' "$XR_TEST_STATE/uci.db" ||
	fail 'node did not disable DHCPv4 serving'
grep -qx 'dhcp.lan.ra=disabled' "$XR_TEST_STATE/uci.db" ||
	fail 'node did not disable IPv6 RA serving'
grep -qx 'network.wan.proto=none' "$XR_TEST_STATE/uci.db" ||
	fail 'node did not disable its routed WAN role'
if grep -Fq 'network.globals.ula_prefix=' "$XR_TEST_STATE/uci.db"; then
	fail 'node retained an independent ULA prefix'
fi

if "$role" node 192.168.10.2/24 192.168.20.1 > /dev/null 2>&1; then
	fail 'node accepted a gateway outside its management subnet'
fi
if "$role" main-dhcp 192.168.10.0/24 > /dev/null 2>&1; then
	fail 'main-dhcp accepted the subnet address as LAN address'
fi

if grep -Ev "^[[:space:]]*#|^[[:space:]]*(echo|printf)[[:space:]]|^[[:space:]]*(reboot manually|Changes are backed up)" "$ROLE_SRC" |
	grep -Eq '(/etc/init.d/(network|dnsmasq|odhcpd|firewall|openclash)|wifi (reload|down|up)|(^|[[:space:]])reboot([[:space:]]|$))'; then
	fail 'role tool contains an automatic reload or reboot'
fi

# Exercise the real first-boot ordering bug: wireless starts completely absent,
# the helper triggers post-kmod discovery, and policy is applied only after all
# three bands and their default interfaces have appeared.
if grep -q '^wireless\.' "$XR_TEST_STATE/uci.db"; then
	fail 'wireless fixture unexpectedly exists before post-kmod discovery'
fi
wireless="$tmp/xr1710g-wireless-defaults"
cp "$WIRELESS_SRC" "$wireless"
chmod 0755 "$wireless"
XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=complete "$wireless"

for expected in \
	'wireless.radio0.country=US' \
	'wireless.default_radio0.ssid=XR1710G-CHANGE-ME' \
	'wireless.default_radio0.encryption=psk-mixed' \
	'wireless.default_radio0.uapsd=0' \
	'wireless.default_radio0.disassoc_low_ack=0' \
	'wireless.default_radio0.ieee80211r=0' \
	'wireless.default_radio0.ieee80211k=1' \
	'wireless.default_radio0.bss_transition=1' \
	'wireless.radio1.country=US' \
	'wireless.radio1.channel=36' \
	'wireless.radio1.htmode=EHT80' \
	'wireless.default_radio1.ssid=XR1710G-5G-CHANGE-ME' \
	'wireless.default_radio1.encryption=sae-mixed' \
	'wireless.default_radio1.uapsd=0' \
	'wireless.default_radio1.disassoc_low_ack=0' \
	'wireless.default_radio1.ieee80211r=1' \
	'wireless.default_radio1.mobility_domain=6616' \
	'wireless.default_radio1.ft_psk_generate_local=1' \
	'wireless.radio2.country=US' \
	'wireless.radio2.channel=37' \
	'wireless.radio2.htmode=EHT80' \
	'wireless.default_radio2.mode=mesh' \
	'wireless.default_radio2.mesh_id=XR1710G-6G-BACKHAUL' \
	'wireless.default_radio2.encryption=sae' \
	'wireless.default_radio2.mesh_fwding=1' \
	'wireless.default_radio2.disabled=0' \
	'system.@system[0].xr1710g_wireless_defaults=1'; do
	grep -Fqx "$expected" "$XR_TEST_STATE/uci.db" ||
		fail "post-kmod wireless policy is missing: $expected"
done
if grep -Eq '^wireless\.default_radio2\.(ssid|owe_groups|owe_transition_)=' \
	"$XR_TEST_STATE/uci.db"; then
	fail '6 GHz mesh retained an AP/OWE-only option'
fi

# The completion marker prevents a later boot from overwriting owner changes.
uci -q set wireless.default_radio1.ssid='OWNER-5G'
XR1710G_WIFI_WAIT_ATTEMPTS=1 XR_TEST_WIFI_MODE=complete "$wireless"
grep -Fqx 'wireless.default_radio1.ssid=OWNER-5G' "$XR_TEST_STATE/uci.db" ||
	fail 'wireless policy overwrote an owner SSID after its completion marker'

# If one band never appears, do not accept or mark a partial factory config.
awk '
	index($0, "wireless.") != 1 &&
	index($0, "system.@system[0].xr1710g_wireless_defaults=") != 1
' "$XR_TEST_STATE/uci.db" > "$XR_TEST_STATE/uci.db.tmp"
mv "$XR_TEST_STATE/uci.db.tmp" "$XR_TEST_STATE/uci.db"
if XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=incomplete "$wireless" \
	> "$tmp/incomplete.out" 2>&1; then
	fail 'wireless policy accepted an incomplete post-kmod radio set'
fi
if grep -Fq 'system.@system[0].xr1710g_wireless_defaults=1' \
	"$XR_TEST_STATE/uci.db"; then
	fail 'wireless policy marked an incomplete radio set as complete'
fi

grep -Fq 'if ! /usr/sbin/xr1710g-wireless-defaults; then' \
	"$BUILDER/files/etc/uci-defaults/99-custom.sh" ||
	fail 'first-boot wrapper does not retain itself when wireless policy fails'

echo 'TOOL TESTS PASSED'
