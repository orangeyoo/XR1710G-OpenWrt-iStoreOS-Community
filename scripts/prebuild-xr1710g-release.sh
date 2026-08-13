#!/bin/sh
# One authoritative source-level gate for the XR1710G release candidate.
# This intentionally does not build an image. Run it before starting a full
# build so a previously fixed item cannot be omitted by running partial tests.

set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

fail() {
	printf 'PREBUILD FAILED: %s\n' "$*" >&2
	exit 1
}

sh "$root/scripts/test-xr1710g-tools.sh"
sh "$root/scripts/test-status-and-istore-safety.sh" "$root"

node --check "$root/apps/luci-app-xr1710g-recovery/htdocs/luci-static/resources/view/system/xr1710g-recovery.js"
node --check "$root/apps/luci-app-airoha-flowsense/htdocs/luci-static/resources/view/airoha_flowsense/status.js"
sh -n "$root/apps/luci-app-airoha-flowsense/root/etc/init.d/npu-jitter"
sh -n "$root/apps/luci-app-airoha-flowsense/root/usr/libexec/rpcd/luci.airoha_flowsense"
sh -n "$root/files/usr/sbin/xr1710g-wireless-defaults"

for document in README.md README-EN.md RELEASE-NOTES.md CHANGES-v1.md; do
	[ -s "$root/$document" ] || fail "missing public document: $document"
done

if grep -Eqi '5.?GHz.*EHT160|EHT160.*5.?GHz|5g.*EHT160|EHT160.*5g|5.?GHz.*30.?dBm|30.?dBm.*5.?GHz|5g.*30.?dBm|30.?dBm.*5g' \
	"$root/README.md" "$root/README-EN.md" \
	"$root/RELEASE-NOTES.md" "$root/CHANGES-v1.md"; then
	fail 'public documentation contains a stale 5 GHz EHT160/30dBm default'
fi

placeholder='XR1710G-CHANGE''-ME'
if grep -R -Fq "$placeholder" \
	"$root/files" "$root/apps" \
	"$root/scripts/test-xr1710g-tools.sh" "$root/scripts/verify-xr1710g-build.sh" \
	"$root/README.md" "$root/README-EN.md" \
	"$root/RELEASE-NOTES.md" "$root/CHANGES-v1.md"; then
	fail 'factory wireless placeholder password remains in release-controlled files'
fi

# Source-level privacy gate. The complete unpacked-image scan remains in
# verify-xr1710g-build.sh and runs after image assembly.
if grep -IrIEq --exclude='verify-xr1710g-build.sh' --exclude='prebuild-xr1710g-release.sh' \
	--exclude='*.crt' --exclude='*.pem' --exclude='*.der' \
	'(ssid|mesh_id|key|password|passwd|secret|username|user)[^[:cntrl:]]{0,80}(leon(_5G)?|Lhc[[:alnum:]]{5,}|syl_[[:alnum:]_]{6,})' \
	"$root/files" "$root/apps" "$root/configs" "$root/packages" \
	"$root/README.md" "$root/README-EN.md" \
	"$root/RELEASE-NOTES.md" "$root/CHANGES-v1.md"; then
	fail 'release-controlled source contains a private SSID or credential'
fi

git -C "$root" diff --check

printf '%s\n' 'XR1710G PREBUILD SOURCE GATE PASSED'
