#!/bin/sh
set -eu

SCRIPT="${1:-}"
CUSTOM_DEFAULTS="${2:-}"
REAL_JSHN_LIB="${3:-}"
REAL_JSHN_BIN="${4:-}"
[ -f "$SCRIPT" ] || {
	echo "usage: test-root-password-default.sh <50-root-passwd> [99-custom.sh] [real-jshn.sh real-jshn-bin]" >&2
	exit 2
}
[ -z "$REAL_JSHN_LIB$REAL_JSHN_BIN" ] ||
	{ [ -f "$REAL_JSHN_LIB" ] && [ -x "$REAL_JSHN_BIN" ]; } || {
	echo 'real jshn compatibility check requires both library and host binary' >&2
	exit 2
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

cat > "$TMP/jshn.sh" <<'EOF'
json_init() {
	# Real OpenWrt jshn.sh reads namespace variables before initialising them.
	# This deliberately fails if the caller reintroduces `set -u`.
	: "${JSON_PREFIX}"
	: "${JSON_UNSET}"
	MOCK_JSON=
}

json_load() {
	[ "$1" != 'INVALID' ] || return 1
	MOCK_JSON="$1"
}

json_is_a() {
	[ "$1" = credentials ] && [ "$2" = object ] &&
		printf '%s' "$MOCK_JSON" | grep -q '"credentials"'
}

json_select() {
	return 0
}

json_get_var() {
	local destination="$1"
	local key="$2"
	local fallback="${3-}"
	local value present

	present=0
	printf '%s' "$MOCK_JSON" |
		grep -q "\\\"$key\\\"[[:space:]]*:" && present=1
	value="$(printf '%s' "$MOCK_JSON" |
		sed -n "s/.*\\\"$key\\\"[[:space:]]*:[[:space:]]*\\\"\\([^\\\"]*\\)\\\".*/\\1/p")"
	[ "$present" -eq 1 ] || value="$fallback"
	eval "$destination=\$value"
	[ "$present" -eq 1 ] || [ "$#" -ge 3 ]
}
EOF

cat > "$TMP/passwd-ok" <<'EOF'
#!/bin/sh
IFS= read -r first || exit 1
IFS= read -r second || exit 1
if IFS= read -r extra; then
	exit 1
fi
[ "$first" = "${XR_ROOT_PASSWD_EXPECTED:?}" ] || exit 1
[ "$second" = "$first" ] || exit 1
sed -i 's|^root:[^:]*|root:test-generated-hash|' "$XR_ROOT_PASSWD_SHADOW"
printf '%s\n' called > "$XR_ROOT_PASSWD_PASSWD_MARKER"
EOF

cat > "$TMP/passwd-fail" <<'EOF'
#!/bin/sh
cat >/dev/null
printf '%s\n' called > "$XR_ROOT_PASSWD_PASSWD_MARKER"
exit 1
EOF

chmod 0755 "$TMP/passwd-ok" "$TMP/passwd-fail"

run_policy() {
	jshn_lib="${2:-$TMP/jshn.sh}"
	policy_shell="${XR_ROOT_PASSWD_TEST_SHELL:-sh}"
	XR_ROOT_PASSWD_BOARD_JSON="$TMP/board.json" \
	XR_ROOT_PASSWD_SHADOW="$TMP/shadow" \
	XR_ROOT_PASSWD_JSHN_LIB="$jshn_lib" \
	XR_ROOT_PASSWD_PASSWD_BIN="$1" \
	XR_ROOT_PASSWD_PASSWD_MARKER="$TMP/passwd.called" \
	XR_ROOT_PASSWD_EXPECTED='plain-test' \
		"$policy_shell" "$SCRIPT"
}

# Empty hash: the plain branch must set a non-empty result.
printf '%s\n' 'root::0:0:99999:7:::' > "$TMP/shadow"
printf '%s\n' '{"credentials":{"root_password_plain":"plain-test"}}' > "$TMP/board.json"
rm -f "$TMP/passwd.called"
run_policy "$TMP/passwd-ok"
grep -q '^root:test-generated-hash:' "$TMP/shadow"
[ -f "$TMP/passwd.called" ]

# Existing owner hash: preserve the file byte-for-byte and never call passwd.
printf '%s\n' 'root:owner-hash:0:0:99999:7:::' > "$TMP/shadow"
cp "$TMP/shadow" "$TMP/shadow.expected"
printf '%s\n' INVALID > "$TMP/board.json"
rm -f "$TMP/passwd.called"
run_policy "$TMP/passwd-fail"
cmp "$TMP/shadow" "$TMP/shadow.expected"
[ ! -e "$TMP/passwd.called" ]

# passwd failure: return non-zero and leave the empty hash for a retry.
printf '%s\n' 'root::0:0:99999:7:::' > "$TMP/shadow"
printf '%s\n' '{"credentials":{"root_password_plain":"plain-test"}}' > "$TMP/board.json"
rm -f "$TMP/passwd.called"
if run_policy "$TMP/passwd-fail" >/dev/null 2>&1; then
	echo 'password policy ignored a passwd failure' >&2
	exit 1
fi
grep -q '^root::' "$TMP/shadow"
[ -f "$TMP/passwd.called" ]

# A supplied hash takes precedence and prevents the plain branch from running.
printf '%s\n' 'root::0:0:99999:7:::' > "$TMP/shadow"
printf '%s\n' '{"credentials":{"root_password_hash":"test-board-hash","root_password_plain":"plain-test"}}' > "$TMP/board.json"
rm -f "$TMP/passwd.called"
run_policy "$TMP/passwd-fail"
grep -q '^root:test-board-hash:' "$TMP/shadow"
[ ! -e "$TMP/passwd.called" ]

# Missing and malformed board metadata must fail while the root hash is empty.
printf '%s\n' 'root::0:0:99999:7:::' > "$TMP/shadow"
rm -f "$TMP/board.json"
if run_policy "$TMP/passwd-ok" >/dev/null 2>&1; then
	echo 'password policy accepted missing board metadata' >&2
	exit 1
fi
printf '%s\n' INVALID > "$TMP/board.json"
if run_policy "$TMP/passwd-ok" >/dev/null 2>&1; then
	echo 'password policy accepted malformed board metadata' >&2
	exit 1
fi

if [ -n "$CUSTOM_DEFAULTS" ]; then
	[ -f "$CUSTOM_DEFAULTS" ] || {
		echo "missing first-boot defaults script: $CUSTOM_DEFAULTS" >&2
		exit 1
	}
	grep -Fq 'root_hash="$(awk -F:' "$CUSTOM_DEFAULTS" ||
		{
			echo 'first-boot defaults do not inspect the root shadow hash' >&2
			exit 1
		}
	grep -Fq "if [ -z \"\$root_hash\" ]; then" "$CUSTOM_DEFAULTS" ||
		{
			echo 'first-boot defaults do not fail closed on an empty root hash' >&2
			exit 1
		}
	guard_block="$(sed -n \
		'/if \[ -z "$root_hash" \]; then/,/^[[:space:]]*fi$/p' \
		"$CUSTOM_DEFAULTS")"
	printf '%s\n' "$guard_block" | grep -Eq '^[[:space:]]*exit 1[[:space:]]*$' ||
		{
			echo 'empty-root first-boot guard does not stop execution' >&2
			exit 1
		}
	guard_line="$(grep -n -m1 'root_hash="$(awk -F:' "$CUSTOM_DEFAULTS" | cut -d: -f1)"
	first_mutation_line="$(grep -n -m1 -E \
		'^[[:space:]]*((uci|mkdir|touch|chmod)[[:space:]]|/usr/sbin/xr1710g-wireless-defaults)' \
		"$CUSTOM_DEFAULTS" | cut -d: -f1)"
	[ -n "$guard_line" ] && [ -n "$first_mutation_line" ] &&
		[ "$guard_line" -lt "$first_mutation_line" ] ||
		{
			echo 'root fail-closed guard does not precede first-boot mutations' >&2
			exit 1
		}
fi

if [ -n "$REAL_JSHN_LIB" ]; then
	# Exercise the actual OpenWrt parser with its host-side jshn binary.
	# Plain-only and hash-only metadata are both valid board declarations; a
	# missing optional sibling must not trip errexit.
	printf '%s\n' 'root::0:0:99999:7:::' > "$TMP/shadow"
	printf '%s\n' '{"credentials":{"root_password_plain":"plain-test"}}' > "$TMP/board.json"
	rm -f "$TMP/passwd.called"
	XR_ROOT_PASSWD_TEST_SHELL=bash PATH="$(dirname "$REAL_JSHN_BIN"):$PATH" \
		run_policy "$TMP/passwd-ok" "$REAL_JSHN_LIB"
	grep -q '^root:test-generated-hash:' "$TMP/shadow"

	printf '%s\n' 'root::0:0:99999:7:::' > "$TMP/shadow"
	printf '%s\n' '{"credentials":{"root_password_hash":"test-board-hash"}}' > "$TMP/board.json"
	rm -f "$TMP/passwd.called"
	XR_ROOT_PASSWD_TEST_SHELL=bash PATH="$(dirname "$REAL_JSHN_BIN"):$PATH" \
		run_policy "$TMP/passwd-fail" "$REAL_JSHN_LIB"
	grep -q '^root:test-board-hash:' "$TMP/shadow"
	[ ! -e "$TMP/passwd.called" ]
fi

echo 'ROOT PASSWORD DEFAULT TEST PASSED'
