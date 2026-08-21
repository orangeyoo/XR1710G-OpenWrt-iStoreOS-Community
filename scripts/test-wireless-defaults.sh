#!/bin/sh
set -eu

POLICY="${1:-}"
[ -f "$POLICY" ] || {
	echo "usage: test-wireless-defaults.sh <xr1710g-wireless-defaults>" >&2
	exit 2
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/bin" "$TMP/state"

fail() {
	echo "WIRELESS DEFAULT TEST FAILED: $*" >&2
	exit 1
}

cat > "$TMP/bin/board_name" <<'EOF'
#!/bin/sh
echo econet,xr1710g-ubi
EOF

cat > "$TMP/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF

cat > "$TMP/bin/wifi" <<'EOF'
#!/bin/sh
set -eu
[ "${1:-}" = config ] || exit 1
db="${XR_TEST_STATE:?}/uci.db"
mode="${XR_TEST_WIFI_MODE:-complete}"

if ! grep -q '^wireless\.radio0\.band=' "$db"; then
	cat >> "$db" <<'RADIO2'
wireless.radio0.band=2g
wireless.default_radio0.device=radio0
wireless.default_radio0.mode=ap
wireless.default_radio0.ssid=XR1710G
wireless.default_radio0.encryption=none
wireless.default_radio0.key=
wireless.default_radio0.disabled=0
RADIO2
fi

if [ "$mode" != missing5 ] &&
	! grep -q '^wireless\.radio1\.band=' "$db"; then
	cat >> "$db" <<'RADIO5'
wireless.radio1.band=5g
wireless.default_radio1.device=radio1
wireless.default_radio1.mode=ap
wireless.default_radio1.ssid=XR1710G-5G
wireless.default_radio1.encryption=none
wireless.default_radio1.key=
wireless.default_radio1.disabled=0
RADIO5
fi

if [ "$mode" != missing6 ] &&
	! grep -q '^wireless\.radio2\.band=' "$db"; then
	cat >> "$db" <<'RADIO6'
wireless.radio2.band=6g
wireless.default_radio2.device=radio2
wireless.default_radio2.mode=ap
wireless.default_radio2.ssid=XR1710G-6G
wireless.default_radio2.encryption=owe
wireless.default_radio2.owe_groups=19
wireless.default_radio2.key=
wireless.default_radio2.disabled=0
RADIO6
fi
EOF

cat > "$TMP/bin/uci" <<'EOF'
#!/bin/sh
set -eu
db="${XR_TEST_STATE:?}/uci.db"
touch "$db"
cmd="${1:-}"
[ "$cmd" != -q ] || {
	shift
	cmd="${1:-}"
}
shift || true

case "$cmd" in
get)
	key="$1"
	awk -v key="$key" \
		'index($0, key "=") == 1 { print substr($0, length(key) + 2) }' \
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
	assignment="$1"
	key="${assignment%%=*}"
	value="${assignment#*=}"
	awk -v key="$key" 'index($0, key "=") != 1' "$db" > "$db.tmp"
	mv "$db.tmp" "$db"
	printf '%s=%s\n' "$key" "$value" >> "$db"
	;;
delete)
	key="$1"
	if ! awk -v key="$key" \
		'index($0, key "=") == 1 || index($0, key ".") == 1 {
			found=1
		} END { exit !found }' "$db"; then
		exit 1
	fi
	awk -v key="$key" \
		'index($0, key "=") != 1 && index($0, key ".") != 1' \
		"$db" > "$db.tmp"
	mv "$db.tmp" "$db"
	;;
commit)
	printf '%s\n' "${1:-all}" >> "${XR_TEST_STATE:?}/commits"
	;;
*)
	echo "unsupported test uci command: $cmd" >&2
	exit 1
	;;
esac
EOF

chmod 0755 "$TMP/bin"/*
export XR_TEST_STATE="$TMP/state"
export PATH="$TMP/bin:/usr/bin:/bin"

reset_state() {
	: > "$XR_TEST_STATE/uci.db"
	: > "$XR_TEST_STATE/commits"
}

assert_line() {
	grep -Fqx "$1" "$XR_TEST_STATE/uci.db" ||
		fail "missing state: $1"
}

assert_no_key() {
	if grep -Eq "^wireless\\.$1\\.key=" "$XR_TEST_STATE/uci.db"; then
		fail "$1 retained a preset key"
	fi
}

# A complete clean discovery must create two open terminal APs and one
# disabled, empty-key SAE Mesh template.
reset_state
XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=complete sh "$POLICY"
assert_line 'wireless.default_radio0.mode=ap'
assert_line 'wireless.default_radio0.encryption=none'
assert_line 'wireless.default_radio0.disabled=0'
assert_line 'wireless.default_radio1.mode=ap'
assert_line 'wireless.default_radio1.encryption=none'
assert_line 'wireless.default_radio1.disabled=0'
assert_line 'wireless.radio2.band=6g'
assert_line 'wireless.radio2.channel=37'
assert_line 'wireless.radio2.htmode=EHT160'
assert_line 'wireless.default_radio2.mode=mesh'
assert_line 'wireless.default_radio2.network=lan'
assert_line 'wireless.default_radio2.encryption=sae'
assert_line 'wireless.default_radio2.disabled=1'
assert_line 'system.@system[0].xr1710g_wireless_defaults=1'
assert_no_key default_radio0
assert_no_key default_radio1
assert_no_key default_radio2
if grep -Eq '^wireless\.default_radio2\.(ssid|owe_groups|owe_transition_)=' \
	"$XR_TEST_STATE/uci.db"; then
	fail '6 GHz Mesh retained an AP/OWE-only option'
fi
if grep -Eq '^wireless\.radio2\.(channel=auto|htmode=EHT20)$' \
	"$XR_TEST_STATE/uci.db"; then
	fail '6 GHz Mesh fell back to automatic channel or 20 MHz'
fi

# The completion marker protects owner changes on later boots.
uci -q set wireless.default_radio1.ssid=OWNER-5G
XR1710G_WIFI_WAIT_ATTEMPTS=1 XR_TEST_WIFI_MODE=complete sh "$POLICY"
assert_line 'wireless.default_radio1.ssid=OWNER-5G'

# An absent 6 GHz radio must fail without accepting a partial configuration.
reset_state
if XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=missing6 \
	sh "$POLICY" >/dev/null 2>&1; then
	fail 'policy accepted a radio set without 6 GHz'
fi
if grep -Fq 'system.@system[0].xr1710g_wireless_defaults=1' \
	"$XR_TEST_STATE/uci.db"; then
	fail 'missing 6 GHz radio was marked complete'
fi

# If 6 GHz appears before 5 GHz, fail closed immediately. The first pass may
# commit the safeguard once, but the retry must not rewrite it repeatedly.
reset_state
if XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=missing5 \
	sh "$POLICY" >/dev/null 2>&1; then
	fail 'policy accepted a 6 GHz-present radio set without 5 GHz'
fi
assert_line 'wireless.default_radio2.disabled=1'
assert_no_key default_radio2
if grep -Fq 'system.@system[0].xr1710g_wireless_defaults=1' \
	"$XR_TEST_STATE/uci.db"; then
	fail '6 GHz safeguard marked an incomplete radio set complete'
fi
[ "$(grep -c '^wireless$' "$XR_TEST_STATE/commits")" -eq 1 ] ||
	fail '6 GHz safeguard rewrote the same partial state more than once'

# A non-empty key supplied by an owner during the incomplete-discovery window
# must be preserved even though the partially discovered 6 GHz interface is
# forced disabled.
reset_state
XR_TEST_WIFI_MODE=missing5 wifi config
uci -q set wireless.default_radio2.key=owner-test-key
if XR1710G_WIFI_WAIT_ATTEMPTS=1 XR_TEST_WIFI_MODE=missing5 \
	sh "$POLICY" >/dev/null 2>&1; then
	fail 'policy accepted an owner-key partial radio set without 5 GHz'
fi
assert_line 'wireless.default_radio2.disabled=1'
assert_line 'wireless.default_radio2.key=owner-test-key'

# Once the missing radio appears, the retained first-boot policy must converge.
reset_state
if XR1710G_WIFI_WAIT_ATTEMPTS=1 XR_TEST_WIFI_MODE=missing5 \
	sh "$POLICY" >/dev/null 2>&1; then
	fail 'policy accepted the convergence fixture before 5 GHz appeared'
fi
XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=complete sh "$POLICY"
assert_line 'wireless.default_radio2.mode=mesh'
assert_line 'wireless.default_radio2.network=lan'
assert_line 'wireless.default_radio2.encryption=sae'
assert_line 'wireless.default_radio2.disabled=1'
assert_line 'system.@system[0].xr1710g_wireless_defaults=1'
assert_no_key default_radio2

echo 'WIRELESS DEFAULT TEST PASSED'
