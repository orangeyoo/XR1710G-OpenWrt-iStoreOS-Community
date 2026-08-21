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
# Remove only the obsolete duplicate left by the interrupted pre-audit build;
# it is not part of the refreshed baseline and is never installed again.
rm -f package/network/services/hostapd/patches/804-nl80211-report-unexpected-frame-events-to-correct-bss.patch
rm -f \
	package/network/services/uhttpd/patches/501-1-feat-add-raw-proxy.patch \
	package/network/services/uhttpd/patches/501-2-fix-force-backend-close-for-proxied-http.patch \
	package/network/services/uhttpd/patches/501-3-feat-forward-original-request-headers-to-backend.patch
git restore --source=HEAD --worktree --staged \
	package/firmware/wireless-regdb \
	package/kernel/mt76 \
	package/network/services/hostapd \
	package/network/services/uhttpd \
	include/image.mk \
	target/linux/airoha/Makefile \
	target/linux/airoha/an7581/base-files/etc/board.d/02_network \
	target/linux/airoha/an7581/base-files/lib/upgrade/platform.sh \
	target/linux/airoha/image/an7581.mk \
	target/linux/airoha/patches-6.18
git -C feeds/packages restore --source=HEAD --worktree --staged -- utils/dockerd
git -C feeds/luci restore --source=HEAD --worktree --staged -- \
	applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js \
	applications/luci-app-dockerman/po/zh_Hans/dockerman.po \
	modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js \
	modules/luci-base/po/zh_Hans/base.po

cp /builder/feeds.d/openwrt feeds.conf
./scripts/feeds update -a
./scripts/feeds uninstall -a >/dev/null 2>&1 || true
/builder/scripts/prepare-istore-feed.sh
./scripts/feeds install -a
cp -a /builder/files/. files/
cp -a /builder/apps/. package/
cp /builder/configs/openwrt.config .config
/builder/diy-part2.d/openwrt.sh
make defconfig

grep -qx 'CONFIG_PACKAGE_wpad-mesh-openssl=y' .config
grep -qx 'PKG_RELEASE:=1' package/network/services/hostapd/Makefile
[ -f package/network/services/hostapd/patches/060-nl80211-fix-reporting-spurious-frame-events.patch ]
if find package/network/services/hostapd/patches -maxdepth 1 -type f \
	-name '*unexpected-frame-events-to-correct-bss*.patch' | grep -q .; then
	echo "Duplicate local hostapd WDS backport is present" >&2
	exit 1
fi

# Force package preparation so the baseline fix is proven in the prepared
# source rather than accepting a stale cached worktree.
make package/network/services/hostapd/clean
BUILD_JOBS="$(sh "$GITHUB_WORKSPACE/scripts/detect-build-jobs.sh")"
echo "Using $BUILD_JOBS parallel build jobs (override with XR_BUILD_JOBS)"
make package/network/services/hostapd/compile -j"$BUILD_JOBS" V=sc

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
	-name 'wpad-mesh-openssl-2026.07.09~f08f2749-r1.apk' -print -quit)"
common_pkg="$(find "$package_dir" -maxdepth 1 -type f \
	-name 'hostapd-common-2026.07.09~f08f2749-r1.apk' -print -quit)"
[ -f "$wpad_pkg" ]
[ -f "$common_pkg" ]

out=/work/hostapd-wds-baseline
rm -rf "$out"
mkdir -p "$out"
cp "$wpad_pkg" "$common_pkg" "$out/"
sha256sum "$out"/*.apk > "$out/SHA256SUMS"
printf '%s\n' "$hostapd_source" > "$out/PREPARED-SOURCE.txt"
printf 'Hostapd WDS package build complete: %s\n' "$out"
