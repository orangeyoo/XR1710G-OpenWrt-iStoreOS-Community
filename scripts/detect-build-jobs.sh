#!/bin/sh
set -eu

# OpenWrt compile jobs are constrained by both CPU and peak memory.  WSL
# exposes a shared memory pool to all distributions, so do not blindly use
# every host thread and risk starving a concurrent build.
if [ -n "${XR_BUILD_JOBS:-}" ]; then
	case "$XR_BUILD_JOBS" in
		*[!0-9]*|'') ;;
		*)
			if [ "$XR_BUILD_JOBS" -ge 1 ]; then
				printf '%s\n' "$XR_BUILD_JOBS"
				exit 0
			fi
			;;
	esac
	echo "XR_BUILD_JOBS must be a positive integer" >&2
	exit 2
fi

cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || printf '1')"
mem_kib="$(awk '/^[[:space:]]*MemTotal:/ { print $2; exit }' /proc/meminfo 2>/dev/null || printf '0')"

# Keep roughly 2 GiB for the kernel, package manager and non-compiler work.
reserve_kib=$((2 * 1024 * 1024))
# A conservative average for mixed OpenWrt C/C++/Rust/Go compile jobs.
per_job_kib=$((768 * 1024))
if [ "$mem_kib" -gt "$reserve_kib" ]; then
	mem_jobs=$(((mem_kib - reserve_kib) / per_job_kib))
else
	mem_jobs=1
fi
[ "$mem_jobs" -ge 1 ] || mem_jobs=1

if [ "$cpu_count" -lt "$mem_jobs" ]; then
	jobs="$cpu_count"
else
	jobs="$mem_jobs"
fi
[ "$jobs" -ge 1 ] || jobs=1
printf '%s\n' "$jobs"
