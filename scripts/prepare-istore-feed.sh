#!/bin/sh
set -eu

makefile="feeds/istore/luci/luci-app-store/Makefile"
is_opkg="feeds/istore/luci/luci-app-store/root/bin/is-opkg"
quickstart_js="feeds/linkease_nas_luci/luci/luci-app-quickstart/htdocs/luci-static/quickstart/index.js"
quickstart_template="feeds/linkease_nas_luci/luci/luci-app-quickstart/luasrc/view/quickstart/main.htm"
istore_feed="feeds/linkease_nas_luci"
home_routes_patch="${GITHUB_WORKSPACE:-/builder}/patches/istore/0300-keep-home-routes-independent-of-quickstart-startup.patch"
old='LUCI_DEPENDS+=$(if $(CONFIG_USE_APK),+apk +luci-compat,+opkg)'
new='LUCI_DEPENDS+=+USE_APK:apk +USE_APK:luci-compat +!USE_APK:opkg'
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

# Apply one verified policy to all APK install and upgrade paths. The helper
# checks exact upstream anchors, so an iStore update cannot silently produce a
# partially patched package manager.
python3 "$(dirname "$0")/patch-istore-wrapper.py" "$is_opkg"
grep -Fq 'SYSTEM_REPOSITORIES=/etc/apk/repositories.d/distfeeds.list' "$is_opkg"
grep -Fq 'apk_wrap add --simulate "$@"' "$is_opkg"
grep -Fq 'apk_wrap upgrade --simulate "$@"' "$is_opkg"
grep -Fq 'apk_wrap "$action" --simulate "$@"' "$is_opkg"
grep -Fq 'Preflight dependency resolution failed; no packages were changed.' "$is_opkg"

[ -f "$quickstart_js" ] || {
	echo "QuickStart frontend not found: $quickstart_js" >&2
	exit 1
}
python3 "$(dirname "$0")/patch-quickstart-link-state.py" "$quickstart_js" "$quickstart_template"
[ "$(grep -Fo '.linkState!=="UP"' "$quickstart_js" | wc -l)" -eq 5 ]
! grep -Fq '.linkState=="DOWN"' "$quickstart_js"
[ "$(grep -Fo '["wan","lan1","lan2","lan3"].includes(x.name)' "$quickstart_js" | wc -l)" -eq 2 ]
grep -Fq 'index.js?v=xr-portfilter2' "$quickstart_template"

[ -f "$home_routes_patch" ] || {
	echo "QuickStart/iStoreX home routing patch not found: $home_routes_patch" >&2
	exit 1
}
home_routes_controller="luci/luci-app-istorex/luasrc/controller/istorex.lua"
quickstart_controller="luci/luci-app-quickstart/luasrc/controller/quickstart.lua"
for controller in "$home_routes_controller" "$quickstart_controller"; do
	[ -f "$istore_feed/$controller" ] || {
		echo "Home controller not found: $istore_feed/$controller" >&2
		exit 1
	}
done
if grep -Fq 'pgrep quickstart' \
	"$istore_feed/$home_routes_controller" \
	"$istore_feed/$quickstart_controller" ||
	grep -Fq 'redirect_fallback' \
		"$istore_feed/$home_routes_controller" \
		"$istore_feed/$quickstart_controller"; then
	git -C "$istore_feed" apply --check "$home_routes_patch"
	git -C "$istore_feed" apply "$home_routes_patch"
fi
! grep -Fq 'pgrep quickstart' \
	"$istore_feed/$home_routes_controller" \
	"$istore_feed/$quickstart_controller"
! grep -Fq 'redirect_fallback' \
	"$istore_feed/$home_routes_controller" \
	"$istore_feed/$quickstart_controller"
grep -Fq 'entry({"admin", "istorex"}, call("istorex_template"))' \
	"$istore_feed/$home_routes_controller"
grep -Fq 'entry({"admin", "quickstart"}, template("quickstart/home")' \
	"$istore_feed/$quickstart_controller"

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
