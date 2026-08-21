#!/bin/bash
set -euo pipefail

# WSL may append Windows application directories containing spaces or
# parentheses. OpenWrt embeds PATH in image recipes, so keep this helper as
# hermetic as the main build entrypoint.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# On this Airoha branch the first world build can cache Image-initramfs before
# package/install has populated root-airoha. Rebuild only the initramfs kernel
# after the complete rootfs exists, otherwise a correctly named recovery FIT
# may contain the same empty-initramfs kernel as the sysupgrade image.

TOPDIR="${1:-.}"
cd "$TOPDIR"

TARGET_DIR="$PWD/bin/targets/airoha/an7581"
ROOT_DIR="$PWD/build_dir/target-aarch64_cortex-a53_musl/root-airoha"
KERNEL_DIR="$PWD/build_dir/target-aarch64_cortex-a53_musl/linux-airoha_an7581"
LINUX_DIR="$(find "$KERNEL_DIR" -mindepth 1 -maxdepth 1 -type d \
	-name 'linux-[0-9]*' -print -quit)"

[ -d "$TARGET_DIR" ] || {
	echo "Target output is missing: $TARGET_DIR" >&2
	exit 1
}
[ -x "$ROOT_DIR/usr/sbin/xr1710g-mesh-diag" ] || {
	echo "The complete XR1710G rootfs is not installed yet" >&2
	exit 1
}
[ -n "$LINUX_DIR" ] && [ -d "$LINUX_DIR/usr" ] || {
	echo "Airoha kernel build directory is missing" >&2
	exit 1
}

# The ordinary image target receives adguardhome, dockerd and the legacy
# airoha_fan controller in prepare_rootfs' disabled service list. The separate
# recovery ramdisk is generated directly from root-airoha, whose package
# post-install phase may still have created these links. Remove only their
# generated service links before regenerating the RAM image; the init scripts
# and LuCI applications remain installed. The authoritative checked `fan`
# service stays enabled while the competing legacy controller stays disabled.
find "$ROOT_DIR/etc/rc.d" -maxdepth 1 -type l \
	\( -name 'S??adguardhome' -o -name 'K??adguardhome' \
	-o -name 'S??dockerd' -o -name 'K??dockerd' \
	-o -name 'S??airoha_fan' -o -name 'K??airoha_fan' \) -delete
if find "$ROOT_DIR/etc/rc.d" -maxdepth 1 -type l \
	\( -name 'S??adguardhome' -o -name 'K??adguardhome' \
	-o -name 'S??dockerd' -o -name 'K??dockerd' \
	-o -name 'S??airoha_fan' -o -name 'K??airoha_fan' \) -print |
	grep -q .; then
	echo "Unable to disable optional services in the recovery rootfs" >&2
	exit 1
fi
# Remove only known generated initramfs/recovery outputs. The package and
# toolchain build products remain intact, so this is a short deterministic
# second pass rather than another full build.
rm -f \
	"$KERNEL_DIR/Image-initramfs" \
	"$KERNEL_DIR"/initrd.cpio \
	"$KERNEL_DIR"/initrd.cpio.* \
	"$KERNEL_DIR"/vmlinux-initramfs \
	"$KERNEL_DIR"/vmlinux-initramfs.debug \
	"$KERNEL_DIR"/vmlinux-initramfs.elf

# Keep the kernel's usr/initramfs_data.S source file. Remove only generated
# archives, dependency/command records and objects so Kbuild must regenerate
# them against the now-complete target root.
rm -f \
	"$LINUX_DIR"/usr/initramfs_data.cpio* \
	"$LINUX_DIR"/usr/.initramfs_data.cpio* \
	"$LINUX_DIR"/usr/initramfs_data.o \
	"$LINUX_DIR"/usr/.initramfs_data.o.cmd \
	"$LINUX_DIR"/usr/initramfs_inc_data \
	"$LINUX_DIR"/usr/.initramfs_inc_data.cmd
find "$KERNEL_DIR/tmp" -maxdepth 1 -type f \
	-name '*econet_xr1710g-ubi-initramfs-recovery.itb*' -delete
find "$TARGET_DIR" -maxdepth 1 -type f \
	-name '*econet_xr1710g-ubi-initramfs-recovery.itb' -delete

export FORCE_UNSAFE_CONFIGURE="${FORCE_UNSAFE_CONFIGURE:-1}"
# The XR1710G FIT recipe already requests "with-initrd". Use OpenWrt's
# separate-initramfs mode so the complete rootfs is an explicit FIT ramdisk
# instead of relying on the shared Linux build directory to preserve an
# embedded archive while ordinary and recovery images are assembled.
make -j1 target/linux/install
make -j1 buildinfo
# json_overview_image_info.py preserves an existing profiles.json when the
# version_code is unchanged.  The XR1710G device profile is patched during this
# build to replace wpad-basic-mbedtls with wpad-mesh-openssl, so remove the
# aggregate file and regenerate it from the current per-image JSON fragments.
rm -f "$TARGET_DIR/profiles.json"
make -j1 json_overview_image_info checksum
