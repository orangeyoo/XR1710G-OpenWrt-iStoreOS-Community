#!/bin/sh
set -eu

TOPDIR="${1:-.}"
OUTPUT_DIR="${2:-$TOPDIR/dist}"
TARGET_DIR="$TOPDIR/bin/targets/airoha/an7581"

[ -d "$TARGET_DIR" ] || {
	echo "Target output is missing: $TARGET_DIR" >&2
	exit 1
}

version="$(cat "$TARGET_DIR/version.buildinfo")"
source_short="${version##*-}"
release_dir="$OUTPUT_DIR/XR1710G-OpenWrt-iStoreOS-next-linux-6.18.41-${source_short}-mt76-b2704cf5-hostapd-f08f2749-wds-lan-192.168.50.1-ubi2.0"

rm -rf "$release_dir"
mkdir -p "$release_dir"

find "$TARGET_DIR" -maxdepth 1 -type f \
	\( -name '*-v1.2.0-*-econet_xr1710g-ubi-initramfs-recovery.itb' \
	-o -name '*-v1.2.0-*-econet_xr1710g-ubi-squashfs-sysupgrade.itb' \
	-o -name '*-v1.2.0-*-econet_xr1710g-ubi.manifest' \
	-o -name 'config.buildinfo' \
	-o -name 'feeds.buildinfo' \
	-o -name 'profiles.json' \
	-o -name 'version.buildinfo' \) \
	-exec cp -f {} "$release_dir/" \;

[ "$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.2.0-*-econet_xr1710g-ubi-initramfs-recovery.itb' | wc -l)" -eq 1 ] || {
	echo "Release does not contain exactly one v1.2.0 Recovery image" >&2
	exit 1
}
[ "$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.2.0-*-econet_xr1710g-ubi-squashfs-sysupgrade.itb' | wc -l)" -eq 1 ] || {
	echo "Release does not contain exactly one v1.2.0 Sysupgrade image" >&2
	exit 1
}
[ "$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.2.0-*-econet_xr1710g-ubi.manifest' | wc -l)" -eq 1 ] || {
	echo "Release does not contain exactly one v1.2.0 manifest" >&2
	exit 1
}
if find "$release_dir" -maxdepth 1 -type f -name '*snapshot*' -print | grep -q .; then
	echo "Release accidentally contains a stale snapshot artifact" >&2
	exit 1
fi

cp -f /builder/RELEASE-NOTES.md /builder/UBOOT-FLASH-GUIDE.md \
	/builder/FLASHING-GUIDE.md /builder/ATTRIBUTION.md "$release_dir/"
[ -f /work/verify.txt ] || {
	echo "Current verification log is missing: /work/verify.txt" >&2
	exit 1
}
grep -qx 'VERIFY PASSED' /work/verify.txt || {
	echo "Current verification log does not contain VERIFY PASSED" >&2
	exit 1
}
cp -f /work/verify.txt "$release_dir/verify.txt"

(
	cd "$release_dir"
	sha256sum \
		config.buildinfo \
		feeds.buildinfo \
		profiles.json \
		version.buildinfo \
		*-v1.2.0-*-econet_xr1710g-ubi-initramfs-recovery.itb \
		*-v1.2.0-*-econet_xr1710g-ubi-squashfs-sysupgrade.itb \
		*-v1.2.0-*-econet_xr1710g-ubi.manifest \
		> sha256sums
	sha256sum -c sha256sums >&2
	sha256sum \
		*-v1.2.0-*-econet_xr1710g-ubi-initramfs-recovery.itb \
		*-v1.2.0-*-econet_xr1710g-ubi-squashfs-sysupgrade.itb \
		> XR1710G-FLASH-FILES.sha256
)

printf '%s\n' "$release_dir"
