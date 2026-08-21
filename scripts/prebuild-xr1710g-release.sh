#!/bin/sh
# One authoritative source-level gate for the XR1710G release.
# This intentionally does not build an image. Run it before starting a full
# build so a previously fixed item cannot be omitted by running partial tests.

set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

fail() {
	printf 'PREBUILD FAILED: %s\n' "$*" >&2
	exit 1
}

require_text() {
	file="$1"
	text="$2"
	grep -Fq "$text" "$file" ||
		fail "documentation policy is missing from $(basename "$file"): $text"
}

sh "$root/scripts/test-xr1710g-tools.sh"
sh "$root/scripts/test-status-and-istore-safety.sh" "$root"

node --check "$root/apps/luci-app-xr1710g-recovery/htdocs/luci-static/resources/view/system/xr1710g-recovery.js"
node --check "$root/apps/luci-app-airoha-flowsense/htdocs/luci-static/resources/view/airoha_flowsense/status.js"
node --check "$root/scripts/test-luci-lan-cidr.js"
node --check "$root/scripts/test-luci-firewall-fullcone.js"
sh -n "$root/scripts/test-root-password-default.sh"
sh -n "$root/scripts/test-wireless-defaults.sh"
sh -n "$root/scripts/test-argon-theme-default.sh"
sh -n "$root/apps/luci-app-airoha-flowsense/root/etc/init.d/npu-jitter"
sh -n "$root/apps/luci-app-airoha-flowsense/root/usr/libexec/rpcd/luci.airoha_flowsense"
sh -n "$root/files/usr/sbin/xr1710g-wireless-defaults"

if grep -Eqi '默认(管理员)?密码:[[:space:]]*空|(default )?(administrator )?password:[[:space:]]*(empty|none)' \
	"$root/.github/workflows/build.yml"; then
	fail 'release workflow still claims that the administrator password is empty'
fi

for document in \
	README.md README-EN.md RELEASE-NOTES.md CHANGES-v1.md \
	FLASHING-GUIDE.md MESH-GUIDE-ZH.md; do
	[ -s "$root/$document" ] || fail "missing public document: $document"
done

if grep -Eqi '5.?GHz.*EHT160|EHT160.*5.?GHz|5g.*EHT160|EHT160.*5g|5.?GHz.*30.?dBm|30.?dBm.*5.?GHz|5g.*30.?dBm|30.?dBm.*5g' \
	"$root/README.md" "$root/README-EN.md" \
	"$root/RELEASE-NOTES.md" "$root/CHANGES-v1.md" \
	"$root/FLASHING-GUIDE.md" "$root/MESH-GUIDE-ZH.md"; then
	fail 'public documentation contains a stale 5 GHz EHT160/30dBm default'
fi

require_text "$root/README.md" '初始密码为 `password`'
require_text "$root/README.md" '2.4/5GHz 不预置 Wi-Fi 密码'
require_text "$root/README.md" '没有预置密钥，因此首次默认禁用'
require_text "$root/README.md" 'PSC channel 37、EHT160'
require_text "$root/README.md" '删除 GlassTheme 及其中文包'
require_text "$root/README-EN.md" 'initial administrator password is `password`'
require_text "$root/README-EN.md" '2.4/5GHz have no preset Wi-Fi password'
require_text "$root/README-EN.md" 'It has no preset key and is disabled initially'
require_text "$root/README-EN.md" 'PSC channel 37, EHT160'
require_text "$root/README-EN.md" 'Removes GlassTheme and its Chinese package'
require_text "$root/RELEASE-NOTES.md" '初始管理员密码为 `password`'
require_text "$root/RELEASE-NOTES.md" '6GHz Mesh 默认禁用'
require_text "$root/RELEASE-NOTES.md" 'initial administrator password to `password`'
require_text "$root/RELEASE-NOTES.md" 'The 6GHz Mesh template is disabled'
require_text "$root/CHANGES-v1.md" '2.4/5GHz 也不预置 Wi-Fi 密码'
require_text "$root/CHANGES-v1.md" '6GHz 空密钥模板保持禁用'
require_text "$root/CHANGES-v1.md" 'No 2.4/5GHz Wi-Fi password is preset either'
require_text "$root/CHANGES-v1.md" 'empty-key 6GHz template remains disabled'
require_text "$root/FLASHING-GUIDE.md" '初始管理员密码：`password`'
require_text "$root/FLASHING-GUIDE.md" '6GHz：空 SAE 密钥的 802.11s 模板，默认禁用'
require_text "$root/FLASHING-GUIDE.md" 'Initial administrator password: `password`'
require_text "$root/FLASHING-GUIDE.md" '6GHz: empty-key 802.11s SAE template, disabled by default'
require_text "$root/MESH-GUIDE-ZH.md" '首次管理员密码：`password`'
require_text "$root/MESH-GUIDE-ZH.md" '2.4/5GHz 首次 AP：不预置无线密码'
require_text "$root/MESH-GUIDE-ZH.md" '6GHz 首次模板：不预置 SAE 密钥且默认关闭'

if grep -Eqi \
	'首次.{0,20}(没有管理员密码|管理员密码为空)|clean first boot.{0,30}(has|uses) no administrator password' \
	"$root/README.md" "$root/README-EN.md" \
	"$root/RELEASE-NOTES.md" "$root/CHANGES-v1.md" \
	"$root/FLASHING-GUIDE.md" "$root/MESH-GUIDE-ZH.md"; then
	fail 'public documentation still claims that the administrator password is empty'
fi

# Forum drafts are deliberately local-only. Validate them when present without
# requiring or publishing them in a clean repository checkout.
if [ -f "$root/FORUM-POST-ENSHAN.md" ]; then
	require_text "$root/FORUM-POST-ENSHAN.md" '管理员默认密码：`password`'
	require_text "$root/FORUM-POST-ENSHAN.md" '首次启动为开放网络'
	require_text "$root/FORUM-POST-ENSHAN.md" 'Mesh 模板默认关闭'
fi
if [ -f "$root/FORUM-POST-OPENWRT.md" ]; then
	require_text "$root/FORUM-POST-OPENWRT.md" 'public default password `password`'
	require_text "$root/FORUM-POST-OPENWRT.md" 'first-boot APs have no preset Wi-Fi password'
	require_text "$root/FORUM-POST-OPENWRT.md" 'disabled 6 GHz Mesh template also has no preset key'
fi

placeholder='XR1710G-CHANGE''-ME'
if grep -R -Fq "$placeholder" \
	"$root/files" "$root/apps" \
	"$root/scripts/test-xr1710g-tools.sh" "$root/scripts/verify-xr1710g-build.sh" \
	"$root/README.md" "$root/README-EN.md" \
	"$root/RELEASE-NOTES.md" "$root/CHANGES-v1.md" \
	"$root/FLASHING-GUIDE.md" "$root/MESH-GUIDE-ZH.md"; then
	fail 'factory wireless placeholder password remains in release-controlled files'
fi

# Source-level privacy gate. The complete unpacked-image scan remains in
# verify-xr1710g-build.sh and runs after image assembly.
if grep -IrIEq --exclude='verify-xr1710g-build.sh' --exclude='prebuild-xr1710g-release.sh' \
	--exclude='*.crt' --exclude='*.pem' --exclude='*.der' \
	'(ssid|mesh_id|key|password|passwd|secret|username|user)[^[:cntrl:]]{0,80}(leon(_5G)?|Lhc[[:alnum:]]{5,}|syl_[[:alnum:]_]{6,})' \
	"$root/files" "$root/apps" "$root/configs" "$root/packages" \
	"$root/README.md" "$root/README-EN.md" \
	"$root/RELEASE-NOTES.md" "$root/CHANGES-v1.md" \
	"$root/FLASHING-GUIDE.md" "$root/MESH-GUIDE-ZH.md"; then
	fail 'release-controlled source contains a private SSID or credential'
fi

git -C "$root" diff --check
git -C "$root" diff --cached --check

printf '%s\n' 'XR1710G PREBUILD SOURCE GATE PASSED'
