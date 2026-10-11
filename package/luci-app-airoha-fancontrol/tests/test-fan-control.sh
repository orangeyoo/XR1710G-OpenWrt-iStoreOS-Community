#!/bin/sh

set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
CONTROLLER="$APP_DIR/root/usr/sbin/xr1710g-fan-control"
INIT_SCRIPT="$APP_DIR/root/etc/init.d/fan"
MAKEFILE="$APP_DIR/Makefile"
TMP_ROOT="${TMPDIR:-/tmp}/xr1710g-fan-test-$$"

pass=0

cleanup() {
	rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_eq() {
	[ "$1" = "$2" ] || fail "$3 (expected $2, got $1)"
	pass=$((pass + 1))
}

assert_success() {
	"$@" || fail "command failed: $*"
	pass=$((pass + 1))
}

assert_failure() {
	if "$@"; then
		fail "command unexpectedly succeeded: $*"
	fi
	pass=$((pass + 1))
}

mkdir -p "$TMP_ROOT/hwmon"
printf 'nct7802\n' > "$TMP_ROOT/hwmon/name"
printf '1\n' > "$TMP_ROOT/hwmon/pwm1_enable"
printf '0\n' > "$TMP_ROOT/hwmon/pwm1"
printf '59000\n' > "$TMP_ROOT/temp"

XR_FAN_LIB_ONLY=1
export XR_FAN_LIB_ONLY
. "$CONTROLLER"

HYSTERESIS=3
POINT1_TEMP=60
POINT1_PWM=54
POINT2_TEMP=68
POINT2_PWM=69
POINT3_TEMP=76
POINT3_PWM=95
POINT4_TEMP=83
POINT4_PWM=199
POINT5_TEMP=88
POINT5_PWM=255

step=$(step_with_hysteresis 59 0)
assert_eq "$step" 1 "59 C must stay on the minimum step"
assert_eq "$(pwm_for_step "$step")" 54 "minimum step must use PWM 54"

step=$(step_with_hysteresis 69 1)
assert_eq "$step" 2 "69 C must raise the fan to step 2"
assert_eq "$(pwm_for_step "$step")" 69 "step 2 must use PWM 69"

assert_eq "$(step_with_hysteresis 66 2)" 2 "hysteresis must hold step 2 at 66 C"
assert_eq "$(step_with_hysteresis 65 2)" 1 "hysteresis must release step 2 at 65 C"
assert_eq "$(raw_step_for_temp 88)" 5 "88 C must select the full-speed step"
assert_eq "$(pwm_for_step 5)" 255 "the final step must be full speed"

HWMON="$TMP_ROOT/hwmon"
assert_success apply_pwm 54
assert_eq "$(cat "$HWMON/pwm1_enable")" 1 "controller must select hardware manual mode"
assert_eq "$(cat "$HWMON/pwm1")" 54 "checked PWM write must be readable"
assert_failure write_checked "$HWMON/missing" 54

printf '0\n' > "$HWMON/pwm1"
failsafe_full_speed >/dev/null 2>&1
assert_eq "$(cat "$HWMON/pwm1")" 255 "fail-safe must force full speed"

cat > "$TMP_ROOT/uci" <<'EOF'
#!/bin/sh
[ "$1" = "-q" ] && shift
[ "$1" = "get" ] || exit 1
case "$2" in
	fan.settings.mode) echo auto ;;
	fan.settings.curve_preset) echo balanced ;;
	fan.settings.manual_pwm) echo 127 ;;
	fan.settings.poll_interval) echo 1 ;;
	fan.settings.hysteresis) echo 3 ;;
	fan.settings.minimum_pwm) echo 54 ;;
	fan.settings.failsafe_temp) echo 88 ;;
	fan.balanced.point1_temp) echo 60 ;;
	fan.balanced.point1_pwm) echo 54 ;;
	fan.balanced.point2_temp) echo 68 ;;
	fan.balanced.point2_pwm) echo 69 ;;
	fan.balanced.point3_temp) echo 76 ;;
	fan.balanced.point3_pwm) echo 95 ;;
	fan.balanced.point4_temp) echo 83 ;;
	fan.balanced.point4_pwm) echo 199 ;;
	fan.balanced.point5_temp) echo 88 ;;
	fan.balanced.point5_pwm) echo 255 ;;
	*) exit 1 ;;
esac
EOF
chmod +x "$TMP_ROOT/uci"

printf '0\n' > "$HWMON/pwm1"
XR_FAN_HWMON="$HWMON" \
XR_FAN_UCI_BIN="$TMP_ROOT/uci" \
XR_FAN_TEMP_INPUTS="$TMP_ROOT/temp" \
XR_FAN_STATE_FILE="$TMP_ROOT/state" \
XR_FAN_MAX_ITERATIONS=1 \
XR_FAN_LIB_ONLY=0 \
	"$CONTROLLER" run
assert_eq "$(cat "$HWMON/pwm1")" 54 "one controller iteration at 59 C must use PWM 54"
assert_eq "$(sed -n 's/^step=//p' "$TMP_ROOT/state")" 1 "state file must report step 1"

rm_before=$(grep -n 'S??airoha_fan' "$MAKEFILE" | head -n 1 | cut -d: -f1)
root_exit=$(grep -n '\[ -n.*IPKG_INSTROOT.*exit 0' "$MAKEFILE" | head -n 1 | cut -d: -f1)
[ -n "$rm_before" ] && [ -n "$root_exit" ] && [ "$rm_before" -lt "$root_exit" ] ||
	fail "image-root startup link removal must run before the IPKG_INSTROOT exit"
pass=$((pass + 1))

grep -q '/etc/init.d/airoha_fan disable' "$INIT_SCRIPT" ||
	fail "fan service must disable the competing controller"
pass=$((pass + 1))
grep -q 'procd_set_param command /usr/bin/env -u LD_PRELOAD /usr/sbin/xr1710g-fan-control run' "$INIT_SCRIPT" ||
	fail "fan service must supervise the checked controller without the incompatible preload"
pass=$((pass + 1))

printf 'PASS: %d fan-control checks\n' "$pass"
