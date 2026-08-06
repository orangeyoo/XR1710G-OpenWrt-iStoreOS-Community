#!/bin/bash
set -euo pipefail

# Incrementally build only the WDS-fixed hostapd/wpad package in the existing
# XR1710G build volume. This deliberately stops before image assembly or any
# router change.
export FORCE_UNSAFE_CONFIGURE=1
export GITHUB_WORKSPACE=/builder

if ! command -v make >/dev/null 2>&1; then
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	# shellcheck disable=SC2046
	apt-get install -y -qq $(tr -d '\r' < /builder/depends/ubuntu-22.04)
fi

cd /work/openwrt

# Restore every path touched by the deterministic DIY hook so it can enforce
# the same pinned baselines as a clean release build. Preserve downloads,
# feeds, toolchains and unrelated package build caches.
rm -f package/kernel/mt76/patches/*.patch
rm -f package/network/services/hostapd/patches/804-nl80211-report-unexpected-frame-events-to-correct-bss.patch
git restore --source=HEAD --worktree --staged \
	package/kernel/mt76 \
	package/network/services/hostapd \
	include/image.mk \
	target/linux/airoha/Makefile \
	target/linux/airoha/image/an7581.mk \
	target/linux/airoha/patches-6.18

cp /builder/feeds.d/openwrt feeds.conf
cp -a /builder/files/. files/
cp -a /builder/apps/. package/
cp /builder/configs/openwrt.config .config
/builder/diy-part2.d/openwrt.sh
make defconfig

grep -qx 'CONFIG_PACKAGE_wpad-mesh-openssl=y' .config
grep -qx 'PKG_RELEASE:=3' package/network/services/hostapd/Makefile

# Force package preparation so the backport is proven to apply to the pinned
# source rather than accepting a stale cached worktree.
make package/network/services/hostapd/clean
make package/network/services/hostapd/compile -j16 V=sc

hostapd_source="$(find build_dir/target-aarch64_cortex-a53_musl \
	-type f -path '*/src/drivers/driver_nl80211_event.c' \
	-path '*hostapd*' -print | sort | head -n1)"
[ -f "$hostapd_source" ]
grep -Fq 'wpa_supplicant_event(bss->ctx, EVENT_RX_FROM_UNKNOWN, &event);' \
	"$hostapd_source"
if grep -Fq 'wpa_supplicant_event(drv->ctx, EVENT_RX_FROM_UNKNOWN, &event);' \
	"$hostapd_source"; then
	echo "Prepared hostapd source still contains the broken WDS event route" >&2
	exit 1
fi

package_dir='bin/packages/aarch64_cortex-a53/base'
wpad_pkg="$(find "$package_dir" -maxdepth 1 -type f \
	-name 'wpad-mesh-openssl-2026.04.02~b004de0b-r3.apk' -print -quit)"
common_pkg="$(find "$package_dir" -maxdepth 1 -type f \
	-name 'hostapd-common-2026.04.02~b004de0b-r3.apk' -print -quit)"
[ -f "$wpad_pkg" ]
[ -f "$common_pkg" ]

out=/work/hostapd-wds-r3
rm -rf "$out"
mkdir -p "$out"
cp "$wpad_pkg" "$common_pkg" "$out/"
sha256sum "$out"/*.apk > "$out/SHA256SUMS"
printf '%s\n' "$hostapd_source" > "$out/PREPARED-SOURCE.txt"
printf 'Hostapd WDS package build complete: %s\n' "$out"
