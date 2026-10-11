/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __XR1710G_RECOVERY_FACTORY_GATE_H__
#define __XR1710G_RECOVERY_FACTORY_GATE_H__

#include <stdbool.h>
#include <errno.h>

typedef int (*xr1710g_factory_sync_fn)(const char *part);

/*
 * A Recovery request is captured before environment relocation.  Keep every
 * pre-HTTP Factory mutation behind that captured decision while preserving the
 * existing normal-boot synchronization call.
 */
static inline int xr1710g_preboot_factory_sync(bool recovery_requested,
					       bool layout_available,
					       const char *part,
					       xr1710g_factory_sync_fn sync)
{
	if (recovery_requested || !layout_available)
		return 0;
	if (!part || !sync)
		return -EINVAL;

	return sync(part);
}

#endif /* __XR1710G_RECOVERY_FACTORY_GATE_H__ */
