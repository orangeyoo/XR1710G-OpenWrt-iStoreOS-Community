#!/bin/sh
# Verify the packaged rootfs, not merely a first-boot source declaration.
set -eu
rootfs="${1:?rootfs directory required}"
shadow="$rootfs/etc/shadow"
[ "$(grep -c '^root:' "$shadow")" = 1 ]
actual="$(awk -F: '$1 == "root" {print $2}' "$shadow")"
# OpenWrt's host staging may contain an old LibreSSL openssl without -6.
# Use the build host's OpenSSL rather than whichever binary PATH puts first.
expected="$("${XR_TEST_OPENSSL:-/usr/bin/openssl}" passwd -6 -salt XR1710GFactory password)"
[ "$actual" = "$expected" ] || {
	echo 'Factory administrator credential does not match the documented default' >&2
	exit 1
}
[ "$(stat -c %a "$shadow")" = 600 ] || {
	echo 'Factory shadow must have mode 0600' >&2
	exit 1
}
# A pre-seeded root must not unlock or replace service accounts.
for user in daemon network nobody; do
	awk -F: -v user="$user" '$1 == user && $2 == "*" {ok=1} END {exit !ok}' "$shadow"
done
grep -Fq 'Firmware community QQ group: 1061612207' \
	"$rootfs/www/luci-static/resources/view/system/password.js"
grep -aFq '本固件交流群 1061612207' \
	"$rootfs/usr/lib/lua/luci/i18n/base.zh-cn.lmo"
echo 'FACTORY IMAGE CREDENTIAL AND COMMUNITY NOTE TEST PASSED'
