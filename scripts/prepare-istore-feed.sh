#!/bin/sh
set -eu

makefile="feeds/istore/luci/luci-app-store/Makefile"
is_opkg="feeds/istore/luci/luci-app-store/root/bin/is-opkg"
old='LUCI_DEPENDS+=$(if $(CONFIG_USE_APK),+apk +luci-compat,+opkg)'
new='LUCI_DEPENDS+=+USE_APK:apk +USE_APK:luci-compat +!USE_APK:opkg'
old_apk='    APK_CONFIG=${APK_CONF} apk "$@"'
new_apk='    APK_CONFIG=${APK_CONF} apk --repositories-file /dev/null "$@"'
adguard_patch="${GITHUB_WORKSPACE:-/builder}/patches/packages/0200-adguardhome-do-not-autostart-unconfigured.patch"
adguard_defaults='feeds/packages/net/adguardhome/files/adguardhome.defaults'
adguard_init='feeds/packages/net/adguardhome/files/adguardhome.init'

[ -f "$makefile" ] || {
	echo "iStore feed Makefile not found: $makefile" >&2
	exit 1
}

if grep -Fqx "$new" "$makefile"; then
	:
elif grep -Fqx "$old" "$makefile"; then
	line="$(grep -nFx "$old" "$makefile" | cut -d: -f1)"
	[ -n "$line" ] || exit 1
	sed -i "${line}c\\${new}" "$makefile"
else
	echo "Unexpected iStore dependency expression; refusing an unreviewed patch" >&2
	exit 1
fi
grep -Fqx "$new" "$makefile"

[ -f "$is_opkg" ] || {
	echo "iStore package wrapper not found: $is_opkg" >&2
	exit 1
}

# apk-tools 3 still reads /etc/apk/repositories.d in addition to APK_CONFIG.
# iStore's private package database must be isolated from the system feeds;
# otherwise a broken system mirror also makes iStore update/install fail.
if grep -Fqx "$new_apk" "$is_opkg"; then
	:
elif grep -Fqx "$old_apk" "$is_opkg"; then
	line="$(grep -nFx "$old_apk" "$is_opkg" | cut -d: -f1)"
	[ -n "$line" ] || exit 1
	sed -i "${line}c\\${new_apk}" "$is_opkg"
else
	echo "Unexpected iStore APK wrapper; refusing an unreviewed patch" >&2
	exit 1
fi
grep -Fqx "$new_apk" "$is_opkg"

[ -f "$adguard_patch" ] || {
	echo "AdGuard Home policy patch not found: $adguard_patch" >&2
	exit 1
}
[ -f "$adguard_defaults" ] && [ -f "$adguard_init" ] || {
	echo "AdGuard Home package files are missing" >&2
	exit 1
}

# Apply only once and reject an unexpected upstream context.  This keeps
# AdGuard Home available for users who explicitly configure it while a clean
# XR1710G image no longer opens setup port 3000 or races dnsmasq on port 53.
if grep -Fq 'must never expose the setup service on a clean router' "$adguard_defaults" &&
	grep -Fq 'Do not auto-start the first-run web service' "$adguard_init"; then
	:
else
	patch -p1 --forward --batch < "$adguard_patch"
fi
grep -Fq 'must never expose the setup service on a clean router' "$adguard_defaults"
grep -Fq '[ -s "$config_file" ] || return 0' "$adguard_init"

echo "Patched iStore APK handling and optional AdGuard Home startup policy"
