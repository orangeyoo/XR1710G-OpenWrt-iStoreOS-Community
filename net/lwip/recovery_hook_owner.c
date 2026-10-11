// SPDX-License-Identifier: GPL-2.0+

#include <recovery-hook-owner.h>

#ifdef RECOVERY_HOOK_OWNER_HOST_TEST
#include <errno.h>
#else
#include <linux/errno.h>
#endif

bool recovery_hook_owner_active(const struct recovery_hook_owner *owner)
{
	return owner && owner->netif && owner->arg;
}

bool recovery_hook_owner_matches(const struct recovery_hook_owner *owner,
				 const void *netif, const void *arg)
{
	return recovery_hook_owner_active(owner) && owner->netif == netif &&
	       owner->arg == arg;
}

bool recovery_hook_owner_owns_netif(const struct recovery_hook_owner *owner,
				    const void *netif)
{
	return recovery_hook_owner_active(owner) && owner->netif == netif;
}

int recovery_hook_owner_claim(struct recovery_hook_owner *owner,
			      const void *netif, void *arg)
{
	if (!owner || !netif || !arg)
		return -EINVAL;

	if (recovery_hook_owner_active(owner))
		return recovery_hook_owner_matches(owner, netif, arg) ? 0 :
								       -EBUSY;

	owner->netif = netif;
	owner->arg = arg;
	return 0;
}

bool recovery_hook_owner_release(struct recovery_hook_owner *owner,
				 const void *netif, const void *arg)
{
	if (!recovery_hook_owner_matches(owner, netif, arg))
		return false;

	owner->netif = 0;
	owner->arg = 0;
	return true;
}
