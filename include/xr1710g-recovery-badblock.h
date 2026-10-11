/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __XR1710G_RECOVERY_BADBLOCK_H__
#define __XR1710G_RECOVERY_BADBLOCK_H__

#include <stdbool.h>
#include <errno.h>

struct xr1710g_recovery_badblock_gate {
	bool forbidden;
	unsigned int blocked_attempts;
};

static inline void xr1710g_recovery_badblock_forbid(
	struct xr1710g_recovery_badblock_gate *gate)
{
	if (gate)
		gate->forbidden = true;
}

static inline int xr1710g_recovery_badblock_check(
	struct xr1710g_recovery_badblock_gate *gate)
{
	if (!gate || !gate->forbidden)
		return 0;

	gate->blocked_attempts++;
	return -EROFS;
}

#endif /* __XR1710G_RECOVERY_BADBLOCK_H__ */
