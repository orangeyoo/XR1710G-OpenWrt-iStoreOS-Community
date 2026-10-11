RAMFS_COPY_BIN='fitblk fit_check_sign'

REQUIRE_IMAGE_METADATA=1

nokia_initial_setup()
{
	[ "$(rootfs_type)" = "tmpfs" ] || return 0

	fw_setenv bootcmd "flash read 0xc0000 0x800000 0x85000000; bootm 0x85000000"
}

platform_check_image() {
	local board=$(board_name)

	[ "$#" -gt 1 ] && return 1

	case "$board" in
	econet,xr1710g-ubi)
		# Clean UBI installation does not persist OpenWrt's generic
		# compat_version marker. Decide upgrade safety from the real flash
		# layout instead. Old BMT/BBT layouts are never written.
		xr_mtd_size_is() {
			awk -v label="$1" -v expected="$2" '
				$4 == "\"" label "\"" && tolower($2) == expected { found = 1 }
				END { exit(found ? 0 : 1) }
			' /proc/mtd 2>/dev/null
		}
		if ! xr_mtd_size_is vendor 00600000 || \
		   ! xr_mtd_size_is chainloader 00100000 || \
		   ! xr_mtd_size_is ubi 1b700000 || \
		   ! xr_mtd_size_is reserved_bmt 04200000; then
			echo "XR1710G UBI 2.0 boundaries are not active; refusing normal sysupgrade." >&2
			echo "Install the corrected chainloader/U-Boot and recreate UBI through recovery first." >&2
			return 1
		fi
		fit_check_image "$1"
		return $?
		;;
	nokia,xg-040g-md)
		nand_do_platform_check "$board" "$1"
		return $?
		;;
	nokia,xg-040g-md-ubi)
		fit_check_image "$1"
		return $?
		;;
	esac

	return 0
}

platform_do_upgrade() {
	local board=$(board_name)

	case "$board" in
		gemtek,w1700k-ubi|\
		nokia,xg-040g-md-ubi)
			fit_do_upgrade "$1"
			;;
		econet,xr1710g-ubi)
			fit_do_upgrade "$1"
			;;
		*)
			nand_do_upgrade "$1"
			;;
	esac
}

platform_pre_upgrade() {
	local board=$(board_name)

	case "$board" in
	nokia,xg-040g-md)
		nokia_initial_setup
		;;
	*)
		;;
	esac
}
