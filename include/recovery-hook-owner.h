/* SPDX-License-Identifier: GPL-2.0+ */

#ifndef __RECOVERY_HOOK_OWNER_H__
#define __RECOVERY_HOOK_OWNER_H__

#ifdef RECOVERY_HOOK_OWNER_HOST_TEST
#include <stdbool.h>
#include <stddef.h>
#else
#include <linux/types.h>
#endif

struct recovery_hook_owner {
	const void *netif;
	void *arg;
};

bool recovery_hook_owner_active(const struct recovery_hook_owner *owner);
bool recovery_hook_owner_matches(const struct recovery_hook_owner *owner,
				 const void *netif, const void *arg);
bool recovery_hook_owner_owns_netif(const struct recovery_hook_owner *owner,
				    const void *netif);
int recovery_hook_owner_claim(struct recovery_hook_owner *owner,
			      const void *netif, void *arg);
bool recovery_hook_owner_release(struct recovery_hook_owner *owner,
				 const void *netif, const void *arg);

#endif /* __RECOVERY_HOOK_OWNER_H__ */
