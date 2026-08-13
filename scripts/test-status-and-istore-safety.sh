#!/bin/sh
set -eu

root="${1:-.}"
npu="$root/apps/luci-app-airoha-npu/root/usr/libexec/rpcd/luci.airoha_npu"
flow="$root/apps/luci-app-airoha-flowsense/root/usr/libexec/rpcd/luci.airoha_flowsense"
npu_js="$root/apps/luci-app-airoha-npu/htdocs/luci-static/resources/view/airoha_npu/status.js"
flow_js="$root/apps/luci-app-airoha-flowsense/htdocs/luci-static/resources/view/airoha_flowsense/status.js"
fan_status_js="$root/apps/luci-app-airoha-fancontrol/htdocs/luci-static/resources/view/fan/status.js"
fan_settings_js="$root/apps/luci-app-airoha-fancontrol/htdocs/luci-static/resources/view/fan/settings.js"
core="$root/apps/xr1710g-status-core/files/xr1710g-status-common"
prepare="$root/scripts/prepare-istore-feed.sh"
patcher="$root/scripts/patch-istore-wrapper.py"
quickstart_patcher="$root/scripts/patch-quickstart-link-state.py"
recovery_view="$root/apps/luci-app-xr1710g-recovery/htdocs/luci-static/resources/view/system/xr1710g-recovery.js"
jitter_init="$root/apps/luci-app-airoha-flowsense/root/etc/init.d/npu-jitter"
jitter_config="$root/apps/luci-app-airoha-flowsense/root/etc/config/npu-monitor"

for file in "$npu" "$flow" "$npu_js" "$flow_js" "$fan_status_js" "$fan_settings_js" "$core" "$prepare" "$patcher" "$quickstart_patcher" "$recovery_view" "$jitter_init" "$jitter_config"; do
	[ -f "$file" ] || { echo "missing $file" >&2; exit 1; }
done

rpc_backends="$(find "$root/apps" -type f -path '*/root/usr/libexec/rpcd/luci.*' -print)"
if [ -n "$rpc_backends" ] && grep -Eq '(^|[^A-Za-z])(devmem|/dev/mem)([^A-Za-z]|$)' $rpc_backends; then
	echo 'LuCI RPC backend contains forbidden raw-register access' >&2
	exit 1
fi

! grep -Fq 'npu_bypass_latency' "$flow"
! grep -Fq 'HW offload is enabled but ISP latency is high' "$flow"
grep -Fq 'cake_on_wan' "$flow"
grep -Fq "a.id !== 'npu_bypass_latency'" "$flow_js"
! grep -Fq 'VLAN offload not supported on this device' "$flow_js" "$root/apps/luci-app-airoha-flowsense/po/zh_Hans/luci-app-airoha-flowsense.po"
! grep -Fq 'PPPoE offload not supported on this device' "$flow_js" "$root/apps/luci-app-airoha-flowsense/po/zh_Hans/luci-app-airoha-flowsense.po"
grep -Fq "enabled ? _('Enabled') : _('Not enabled or configured')" "$flow_js"
grep -Fq 'if (oneShot)' "$recovery_view"
! grep -Fq "}, !oneShot)" "$recovery_view"
grep -Fq "option target 'auto'" "$jitter_config"
grep -Fq "config jitter 'jitter'" "$jitter_config"
grep -Fq "npu-monitor.@jitter[0].target" "$jitter_init"
grep -Fq "jsonfilter -e '@[\"dns-server\"][0]'" "$jitter_init"

grep -Fq "method: 'getSnapshot'" "$npu_js"
grep -Fq "method: 'getSnapshot'" "$flow_js"
if grep -Fq 'return Promise.all([' "$npu_js" "$flow_js"; then
	echo 'status page still fans out concurrent RPC requests' >&2
	exit 1
fi
grep -Fq 'if (shown >= 64) next' "$npu"
grep -Fq 'callFanStatus().catch(function() { return {}; })' "$fan_status_js"
grep -Fq 'callGetAllCurves().catch(function() { return {}; })' "$fan_settings_js"
grep -Fq 'catch(function() { return null; })' "$fan_status_js"

grep -Fq 'cat "$sys/carrier"' "$core"
grep -Fq '[ "$carrier" = "1" ]' "$core"
if grep -Fq '[ "$operstate" = "up" ] && up=true' "$flow"; then
	echo 'Ethernet status still treats administrative operstate as carrier' >&2
	exit 1
fi

grep -Fq 'SYSTEM_REPOSITORIES=/etc/apk/repositories.d/distfeeds.list' "$prepare"
grep -Fq 'apk_wrap add --simulate "$@"' "$prepare"
grep -Fq 'apk_wrap upgrade --simulate "$@"' "$prepare"
grep -Fq 'apk_wrap "$action" --simulate "$@"' "$prepare"
grep -Fq 'Preflight dependency resolution failed; no packages were changed.' "$prepare"

# Test the real transformation against a reviewed upstream fixture twice.
# A second run must be a no-op, and upstream drift must fail closed.
fixture="${TMPDIR:-/tmp}/xr-is-opkg-test.$$"
trap 'rm -f "$fixture" "${fixture}.quickstart"' EXIT INT TERM
istore_fixture="${XR_ISTORE_FIXTURE:-$root/tests/fixtures/is-opkg.anchors}"
quickstart_source="${XR_QUICKSTART_FIXTURE:-$root/tests/fixtures/quickstart-index.anchors.js}"
cp "$istore_fixture" "$fixture" 2>/dev/null || {
	echo 'missing reviewed is-opkg fixture' >&2
	exit 1
}
python3 "$patcher" "$fixture"
first_hash="$(sha256sum "$fixture" | awk '{print $1}')"
python3 "$patcher" "$fixture"
second_hash="$(sha256sum "$fixture" | awk '{print $1}')"
[ "$first_hash" = "$second_hash" ]
grep -Fq -- '--repositories-file ${SYSTEM_REPOSITORIES} "$@"' "$fixture"
grep -Fq 'apk_wrap add --simulate "$@"' "$fixture"
grep -Fq 'apk_wrap upgrade --simulate "$@"' "$fixture"

quick_fixture="${fixture}.quickstart"
cp "$quickstart_source" "$quick_fixture" 2>/dev/null || {
	echo 'missing reviewed QuickStart fixture' >&2
	exit 1
}
python3 "$quickstart_patcher" "$quick_fixture"
quick_hash="$(sha256sum "$quick_fixture" | awk '{print $1}')"
python3 "$quickstart_patcher" "$quick_fixture"
[ "$quick_hash" = "$(sha256sum "$quick_fixture" | awk '{print $1}')" ]
[ "$(grep -Fo '.linkState!=="UP"' "$quick_fixture" | wc -l)" -eq 5 ]
! grep -Fq '.linkState=="DOWN"' "$quick_fixture"
[ "$(grep -Fo '["wan","lan1","lan2","lan3"].includes(x.name)' "$quick_fixture" | wc -l)" -eq 2 ]
! grep -Fq 'y.portList=C.ports||[]' "$quick_fixture"
! grep -Fq 'd.portList=_.ports||[],v.value=_.ports||[]' "$quick_fixture"

echo 'status RPC, physical-link and iStore dependency safety checks passed'
