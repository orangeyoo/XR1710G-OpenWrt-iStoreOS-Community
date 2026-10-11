// SPDX-License-Identifier: GPL-2.0+

#include <recovery-fport.h>

#ifdef RECOVERY_FPORT_HOST_TEST
#include <errno.h>
#include <string.h>
#else
#include <linux/errno.h>
#include <linux/string.h>
#endif

#define RECOVERY_RAW_ETH_HDR_LEN	14
#define RECOVERY_RAW_IPV4_MIN_HDR_LEN	20
#define RECOVERY_RAW_UDP_HDR_LEN	8
#define RECOVERY_RAW_DHCP_COOKIE_OFFSET	236
#define RECOVERY_RAW_DHCP_MIN_LEN	240

static u16 recovery_fport_get_be16(const u8 *p)
{
	return ((u16)p[0] << 8) | p[1];
}

bool recovery_fport_is_valid(u8 fport)
{
	return fport == RECOVERY_FPORT_LAN ||
	       fport == RECOVERY_FPORT_WAN ||
	       fport == RECOVERY_FPORT_10G;
}

u8 recovery_fport_bit(u8 fport)
{
	return recovery_fport_is_valid(fport) ? (u8)(1U << fport) : 0;
}

u8 recovery_fport_from_rx_sport(u8 sport)
{
	/* EN7581 reports internal-switch user traffic through GDM1 as 0x10..0x14. */
	if (sport >= RECOVERY_FPORT_RX_SPORT_GDM1_MIN &&
	    sport <= RECOVERY_FPORT_RX_SPORT_GDM1_MAX)
		return RECOVERY_FPORT_LAN;

	if (sport == RECOVERY_FPORT_LAN || sport == RECOVERY_FPORT_WAN)
		return sport;

	if (sport == RECOVERY_FPORT_RX_SPORT_10G)
		return RECOVERY_FPORT_10G;

	return 0;
}

u8 recovery_fport_encode_hw(u8 fport)
{
	return fport == RECOVERY_FPORT_10G ? RECOVERY_FPORT_HW_GDM4 : fport;
}

bool recovery_fport_is_raw_dhcp_reply(const u8 *frame, size_t frame_len)
{
	static const u8 dhcp_cookie[4] = { 0x63, 0x82, 0x53, 0x63 };
	static const u8 broadcast_mac[6] = {
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff
	};
	const u8 *payload;
	const u8 *udp;
	const u8 *ip;
	size_t ip_hlen;
	u16 ip_len;
	u16 udp_len;

	if (!frame ||
	    frame_len < RECOVERY_RAW_ETH_HDR_LEN +
			RECOVERY_RAW_IPV4_MIN_HDR_LEN + RECOVERY_RAW_UDP_HDR_LEN +
			RECOVERY_RAW_DHCP_MIN_LEN ||
	    memcmp(frame, broadcast_mac, sizeof(broadcast_mac)) ||
	    frame[12] != 0x08 || frame[13] != 0x00)
		return false;

	ip = frame + RECOVERY_RAW_ETH_HDR_LEN;
	if ((ip[0] >> 4) != 4 || ip[9] != 17 ||
	    ip[16] != 0xff || ip[17] != 0xff ||
	    ip[18] != 0xff || ip[19] != 0xff)
		return false;

	ip_hlen = (ip[0] & 0x0f) * 4;
	if (ip_hlen < RECOVERY_RAW_IPV4_MIN_HDR_LEN ||
	    frame_len < RECOVERY_RAW_ETH_HDR_LEN + ip_hlen +
			RECOVERY_RAW_UDP_HDR_LEN + RECOVERY_RAW_DHCP_MIN_LEN)
		return false;

	ip_len = recovery_fport_get_be16(ip + 2);
	if (ip_len < ip_hlen + RECOVERY_RAW_UDP_HDR_LEN +
			     RECOVERY_RAW_DHCP_MIN_LEN ||
	    ip_len > frame_len - RECOVERY_RAW_ETH_HDR_LEN ||
	    (ip[6] & 0xbf) || ip[7])
		return false;

	udp = ip + ip_hlen;
	udp_len = recovery_fport_get_be16(udp + 4);
	if (recovery_fport_get_be16(udp) != 67 ||
	    recovery_fport_get_be16(udp + 2) != 68 ||
	    udp_len < RECOVERY_RAW_UDP_HDR_LEN + RECOVERY_RAW_DHCP_MIN_LEN ||
	    udp_len != ip_len - ip_hlen)
		return false;

	payload = udp + RECOVERY_RAW_UDP_HDR_LEN;
	return payload[0] == 2 && payload[1] == 1 && payload[2] == 6 &&
	       !memcmp(payload + RECOVERY_RAW_DHCP_COOKIE_OFFSET, dhcp_cookie,
		       sizeof(dhcp_cookie));
}

static void recovery_fport_plan_add(struct recovery_fport_plan *plan,
				    u8 fport)
{
	int i;

	if (!recovery_fport_is_valid(fport) ||
	    plan->count >= RECOVERY_FPORT_MAX_TARGETS)
		return;

	for (i = 0; i < plan->count; i++) {
		if (plan->order[i] == fport)
			return;
	}

	plan->order[plan->count++] = fport;
}

int recovery_fport_plan_init(struct recovery_fport_plan *plan,
			     u8 last_rx_fport, u8 fallback_fport,
			     bool dual_service, bool allow_10g)
{
	bool last_rx_valid;
	u8 primary;
	int i;

	if (!plan)
		return -EINVAL;

	for (i = 0; i < RECOVERY_FPORT_MAX_TARGETS; i++)
		plan->order[i] = 0;
	plan->count = 0;
	plan->strict_primary = false;

	/* A proven ingress is authoritative, including 10G in single-port mode. */
	last_rx_valid = recovery_fport_is_valid(last_rx_fport);
	/* WAN is safe only when RX metadata proves it was the ingress. */
	if (!recovery_fport_is_valid(fallback_fport) ||
	    (!last_rx_valid && fallback_fport == RECOVERY_FPORT_WAN) ||
	    (fallback_fport == RECOVERY_FPORT_10G && !allow_10g))
		fallback_fport = RECOVERY_FPORT_LAN;

	primary = last_rx_valid ? last_rx_fport : fallback_fport;
	plan->strict_primary = last_rx_valid;
	recovery_fport_plan_add(plan, primary);
	if (plan->strict_primary)
		return plan->count ? 0 : -EINVAL;

	if (dual_service) {
		recovery_fport_plan_add(plan, RECOVERY_FPORT_LAN);
		if (allow_10g)
			recovery_fport_plan_add(plan, RECOVERY_FPORT_10G);
	}

	return plan->count ? 0 : -EINVAL;
}

int recovery_fport_plan_result(const struct recovery_fport_plan *plan,
			       const int *results, u8 *attempt_mask,
			       u8 *success_mask, int *primary_error)
{
	int first_error = -EAGAIN;
	u8 attempted = 0;
	u8 succeeded = 0;
	int i;

	if (!plan || !results || !plan->count ||
	    plan->count > RECOVERY_FPORT_MAX_TARGETS)
		return -EINVAL;

	for (i = 0; i < plan->count; i++) {
		attempted |= recovery_fport_bit(plan->order[i]);
		if (!results[i])
			succeeded |= recovery_fport_bit(plan->order[i]);
		else if (first_error == -EAGAIN)
			first_error = results[i];
	}

	if (attempt_mask)
		*attempt_mask = attempted;
	if (success_mask)
		*success_mask = succeeded;
	if (primary_error)
		*primary_error = results[0];

	/*
	 * When a reply is generated synchronously from an RX frame, success on
	 * another mirrored port must not conceal failure on the actual ingress.
	 */
	if (plan->strict_primary && results[0])
		return results[0];

	return succeeded ? 0 : first_error;
}

int recovery_fport_send_plan(const struct recovery_fport_plan *plan,
			     recovery_fport_send_fn send, void *ctx,
			     struct recovery_fport_send_status *status)
{
	struct recovery_fport_send_status local;
	int ret;
	int i;

	if (!plan || !send || !plan->count ||
	    plan->count > RECOVERY_FPORT_MAX_TARGETS)
		return -EINVAL;

	for (i = 0; i < RECOVERY_FPORT_MAX_TARGETS; i++)
		local.result[i] = -EINVAL;
	local.attempt_mask = 0;
	local.success_mask = 0;
	local.primary_error = 0;

	local.result[0] = send(ctx, plan->order[0]);
	if (plan->strict_primary) {
		local.attempt_mask = recovery_fport_bit(plan->order[0]);
		local.success_mask = local.result[0] ? 0 : local.attempt_mask;
		local.primary_error = local.result[0];
		if (status)
			*status = local;
		return local.result[0];
	}

	for (i = 1; i < plan->count; i++)
		local.result[i] = send(ctx, plan->order[i]);

	ret = recovery_fport_plan_result(plan, local.result,
					 &local.attempt_mask,
					 &local.success_mask,
					 &local.primary_error);
	if (status)
		*status = local;

	return ret;
}
