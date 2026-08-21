#!/bin/sh
set -eu

TOPDIR="${1:-.}"
OUTPUT_DIR="${2:-$TOPDIR/dist}"
TARGET_DIR="$TOPDIR/bin/targets/airoha/an7581"

[ -d "$TARGET_DIR" ] || {
	echo "Target output is missing: $TARGET_DIR" >&2
	exit 1
}

release_dir="$OUTPUT_DIR/XR1710G-OpenWrt-iStoreOS-v1.4.0"
public_dir="$release_dir/public-assets"

rm -rf "$release_dir"
mkdir -p "$release_dir"

find "$TARGET_DIR" -maxdepth 1 -type f \
	\( -name '*-v1.4.0-*-econet_xr1710g-ubi-initramfs-recovery.itb' \
	-o -name '*-v1.4.0-*-econet_xr1710g-ubi-squashfs-sysupgrade.itb' \
	-o -name '*-v1.4.0-*-econet_xr1710g-ubi.manifest' \
	-o -name 'config.buildinfo' \
	-o -name 'feeds.buildinfo' \
	-o -name 'profiles.json' \
	-o -name 'version.buildinfo' \) \
	-exec cp -f {} "$release_dir/" \;

[ "$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.4.0-*-econet_xr1710g-ubi-initramfs-recovery.itb' | wc -l)" -eq 1 ] || {
	echo "Release does not contain exactly one v1.4.0 Recovery image" >&2
	exit 1
}
[ "$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.4.0-*-econet_xr1710g-ubi-squashfs-sysupgrade.itb' | wc -l)" -eq 1 ] || {
	echo "Release does not contain exactly one v1.4.0 Sysupgrade image" >&2
	exit 1
}
[ "$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.4.0-*-econet_xr1710g-ubi.manifest' | wc -l)" -eq 1 ] || {
	echo "Release does not contain exactly one v1.4.0 manifest" >&2
	exit 1
}
if find "$release_dir" -maxdepth 1 -type f -name '*snapshot*' -print | grep -q .; then
	echo "Release accidentally contains a stale snapshot artifact" >&2
	exit 1
fi

recovery_image="$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.4.0-*-econet_xr1710g-ubi-initramfs-recovery.itb')"
sysupgrade_image="$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.4.0-*-econet_xr1710g-ubi-squashfs-sysupgrade.itb')"
manifest="$(find "$release_dir" -maxdepth 1 -type f \
	-name '*-v1.4.0-*-econet_xr1710g-ubi.manifest')"

mv "$recovery_image" \
	"$release_dir/xr1710g-community-v1.4.0-recovery.itb"
mv "$sysupgrade_image" \
	"$release_dir/xr1710g-community-v1.4.0-sysupgrade.itb"
mv "$manifest" \
	"$release_dir/xr1710g-community-v1.4.0.manifest"

cp -f /builder/RELEASE-NOTES.md /builder/FLASHING-GUIDE.md \
	/builder/ATTRIBUTION.md "$release_dir/"
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
		xr1710g-community-v1.4.0-recovery.itb \
		xr1710g-community-v1.4.0-sysupgrade.itb \
		xr1710g-community-v1.4.0.manifest \
		> sha256sums
	sha256sum -c sha256sums >&2
	sha256sum \
		xr1710g-community-v1.4.0-recovery.itb \
		xr1710g-community-v1.4.0-sysupgrade.itb \
		> XR1710G-FLASH-FILES.sha256
)

mkdir -p "$public_dir"
cp -f \
	"$release_dir/xr1710g-community-v1.4.0-recovery.itb" \
	"$release_dir/xr1710g-community-v1.4.0-sysupgrade.itb" \
	/builder/FLASHING-GUIDE.md \
	"$public_dir/"

if [ -n "${XR_UBOOT_FLASH_SLOT:-}" ]; then
	[ -f "$XR_UBOOT_FLASH_SLOT" ] || {
		echo "Verified U-Boot slot image is missing: $XR_UBOOT_FLASH_SLOT" >&2
		exit 1
	}
	cp -f "$XR_UBOOT_FLASH_SLOT" \
		"$public_dir/xr1710g-uboot-flash-slot.bin"
fi

(
	cd "$public_dir"
	set -- \
		xr1710g-community-v1.4.0-recovery.itb \
		xr1710g-community-v1.4.0-sysupgrade.itb
	if [ -f xr1710g-uboot-flash-slot.bin ]; then
		set -- "$@" xr1710g-uboot-flash-slot.bin
	fi
	sha256sum "$@" > SHA256SUMS.txt
	sha256sum -c SHA256SUMS.txt >&2
)

printf 'Internal build bundle: %s\nPublic assets: %s\n' \
	"$release_dir" "$public_dir"
