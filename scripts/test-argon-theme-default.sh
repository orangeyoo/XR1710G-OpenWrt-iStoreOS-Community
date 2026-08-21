#!/bin/sh
set -eu

ARGON_DEFAULT="${1:-}"
[ -f "$ARGON_DEFAULT" ] || {
	echo "usage: test-argon-theme-default.sh <30_luci-theme-argon>" >&2
	exit 2
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/bin"
STATE="$TMP/state"

fail() {
	echo "ARGON THEME DEFAULT TEST FAILED: $*" >&2
	exit 1
}

cat > "$TMP/bin/uci" <<'EOF'
#!/bin/sh
set -eu
state="${XR_THEME_TEST_STATE:?}"
cmd="${1:-}"
[ "$cmd" != '-q' ] || {
	shift
	cmd="${1:-}"
}
shift || true

case "$cmd" in
get)
	key="${1:?}"
	awk -v key="$key" '
		index($0, key "=") == 1 {
			print substr($0, length(key) + 2)
			found=1
		}
		END { exit !found }
	' "$state"
	;;
batch)
	while IFS= read -r line; do
		line="$(printf '%s\n' "$line" | sed 's/^[[:space:]]*//')"
		case "$line" in
		set\ *)
			assignment="${line#set }"
			key="${assignment%%=*}"
			awk -v key="$key" 'index($0, key "=") != 1' \
				"$state" > "$state.tmp"
			mv "$state.tmp" "$state"
			printf '%s\n' "$assignment" >> "$state"
			;;
		commit\ *|'') ;;
		*) exit 1 ;;
		esac
	done
	;;
*) exit 1 ;;
esac
EOF
chmod 0755 "$TMP/bin/uci"
export XR_THEME_TEST_STATE="$STATE"
PATH="$TMP/bin:/usr/bin:/bin"
export PATH

assert_line() {
	grep -Fqx "$1" "$STATE" || fail "missing state: $1"
}

# A clean rootfs starts with Bootstrap in luci-base. Argon's first-install
# default must replace it and register the theme.
printf '%s\n' 'luci.main.mediaurlbase=/luci-static/bootstrap' > "$STATE"
PKG_UPGRADE=0 sh "$ARGON_DEFAULT"
assert_line 'luci.themes.Argon=/luci-static/argon'
assert_line 'luci.main.mediaurlbase=/luci-static/argon'

# On later uci-default runs, the registered Argon theme proves it was already
# installed. Preserve an owner's current theme instead of forcing Argon.
cat > "$STATE" <<'EOF'
luci.themes.Argon=/luci-static/argon
luci.main.mediaurlbase=/luci-static/material
EOF
PKG_UPGRADE=0 sh "$ARGON_DEFAULT"
assert_line 'luci.themes.Argon=/luci-static/argon'
assert_line 'luci.main.mediaurlbase=/luci-static/material'

# A package-upgrade transaction must also leave the existing choice untouched.
printf '%s\n' 'luci.main.mediaurlbase=/luci-static/material' > "$STATE"
PKG_UPGRADE=1 sh "$ARGON_DEFAULT"
assert_line 'luci.main.mediaurlbase=/luci-static/material'
if grep -q '^luci\.themes\.Argon=' "$STATE"; then
	fail 'package upgrade rewrote the theme registry'
fi

echo 'ARGON THEME DEFAULT TEST PASSED'
