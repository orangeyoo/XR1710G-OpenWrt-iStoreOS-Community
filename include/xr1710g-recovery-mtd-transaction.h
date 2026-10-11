/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __XR1710G_RECOVERY_MTD_TRANSACTION_H__
#define __XR1710G_RECOVERY_MTD_TRANSACTION_H__

#include <stddef.h>
#include <string.h>
#include <errno.h>

struct xr1710g_recovery_mtd_ops {
	int (*is_bad)(void *ctx, unsigned long long addr);
	int (*erase)(void *ctx, unsigned long long addr, size_t len);
	int (*write)(void *ctx, unsigned long long addr, const void *buf,
		     size_t len, size_t *retlen);
	int (*read)(void *ctx, unsigned long long addr, void *buf,
		    size_t len, size_t *retlen);
	void (*mutated)(void *ctx);
	void (*erase_progress)(void *ctx, size_t done);
	void (*write_progress)(void *ctx, size_t done);
	void (*service)(void *ctx);
};

enum xr1710g_recovery_mtd_stage {
	XR1710G_MTD_STAGE_ARGUMENT = 0,
	XR1710G_MTD_STAGE_PREFLIGHT,
	XR1710G_MTD_STAGE_ERASE,
	XR1710G_MTD_STAGE_WRITE,
	XR1710G_MTD_STAGE_WRITE_READBACK,
	XR1710G_MTD_STAGE_FINAL_READBACK,
	XR1710G_MTD_STAGE_DONE,
};

/*
 * Rewrite one fixed MTD slot without bad-block shifting. Every erase/write is
 * single-attempt. The complete image and all bytes to the end of the slot are
 * read back before success. There is deliberately no markbad operation.
 */
static inline int xr1710g_recovery_mtd_rewrite_verified(
	const struct xr1710g_recovery_mtd_ops *ops, void *ctx,
	unsigned long long ofs, size_t region_len, size_t erase_size,
	const void *image, size_t image_size, void *scratch, size_t scratch_size,
	enum xr1710g_recovery_mtd_stage *stage)
{
	const unsigned char *src = image;
	unsigned char *verify = scratch;
	size_t consumed = 0;
	size_t addr;
	int ret;

	if (stage)
		*stage = XR1710G_MTD_STAGE_ARGUMENT;
	if (!stage || !ops || !ops->is_bad || !ops->erase || !ops->write ||
	    !ops->read ||
	    !ops->mutated || !image || !image_size || !scratch ||
	    !erase_size || scratch_size < erase_size || image_size > region_len ||
	    region_len % erase_size || ofs % erase_size)
		return -EINVAL;

	/* Preflight the whole fixed slot before the first destructive operation. */
	*stage = XR1710G_MTD_STAGE_PREFLIGHT;
	for (addr = 0; addr < region_len; addr += erase_size) {
		ret = ops->is_bad(ctx, ofs + addr);
		if (ret < 0)
			return ret;
		if (ret > 0)
			return -EIO;
	}

	for (addr = 0; addr < region_len; addr += erase_size) {
		*stage = XR1710G_MTD_STAGE_ERASE;
		ops->mutated(ctx);
		ret = ops->erase(ctx, ofs + addr, erase_size);
		if (ret)
			return ret;
		if (ops->erase_progress)
			ops->erase_progress(ctx, addr + erase_size);
		if (ops->service)
			ops->service(ctx);
	}

	while (consumed < image_size) {
		size_t chunk = image_size - consumed;
		size_t retlen = 0;

		if (chunk > erase_size)
			chunk = erase_size;
		*stage = XR1710G_MTD_STAGE_WRITE;
		ops->mutated(ctx);
		ret = ops->write(ctx, ofs + consumed, src + consumed, chunk,
				 &retlen);
		if (ret)
			return ret;
		if (retlen != chunk)
			return -EIO;

		retlen = 0;
		*stage = XR1710G_MTD_STAGE_WRITE_READBACK;
		memset(verify, 0xa5, erase_size);
		ret = ops->read(ctx, ofs + consumed, verify, chunk, &retlen);
		if (ret)
			return ret;
		if (retlen != chunk || memcmp(verify, src + consumed, chunk))
			return -EIO;

		consumed += chunk;
		if (ops->write_progress)
			ops->write_progress(ctx, consumed);
		if (ops->service)
			ops->service(ctx);
	}

	consumed = 0;
	*stage = XR1710G_MTD_STAGE_FINAL_READBACK;
	for (addr = 0; addr < region_len; addr += erase_size) {
		size_t expected = 0;
		size_t retlen = 0;
		size_t i;

		ret = ops->is_bad(ctx, ofs + addr);
		if (ret < 0)
			return ret;
		if (ret > 0)
			return -EIO;

		memset(verify, 0xa5, erase_size);
		ret = ops->read(ctx, ofs + addr, verify, erase_size, &retlen);
		if (ret)
			return ret;
		if (retlen != erase_size)
			return -EIO;

		if (consumed < image_size) {
			expected = image_size - consumed;
			if (expected > erase_size)
				expected = erase_size;
		}
		if (expected && memcmp(verify, src + consumed, expected))
			return -EIO;
		for (i = expected; i < erase_size; i++) {
			if (verify[i] != 0xff)
				return -EIO;
		}

		consumed += expected;
		if (ops->service)
			ops->service(ctx);
	}

	if (consumed != image_size)
		return -ENOSPC;
	*stage = XR1710G_MTD_STAGE_DONE;
	return 0;
}

#endif /* __XR1710G_RECOVERY_MTD_TRANSACTION_H__ */
