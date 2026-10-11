/* SPDX-License-Identifier: GPL-2.0+ */

#ifndef __RECOVERY_FPORT_H__
#define __RECOVERY_FPORT_H__

#ifdef RECOVERY_FPORT_HOST_TEST
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#ifndef RECOVERY_HOST_TYPES_DEFINED
#define RECOVERY_HOST_TYPES_DEFINED
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
#endif
#else
#include <linux/types.h>
#endif

#define RECOVERY_FPORT_LAN	1
#define RECOVERY_FPORT_WAN	2
#define RECOVERY_FPORT_10G	4
#define RECOVERY_FPORT_MAX_TARGETS	3
#define RECOVERY_FPORT_RX_SPORT_GDM1_MIN	0x10
#define RECOVERY_FPORT_RX_SPORT_GDM1_MAX	0x14
#define RECOVERY_FPORT_RX_SPORT_10G	0x18
#define RECOVERY_FPORT_HW_GDM4		9

struct recovery_fport_plan {
	u8 order[RECOVERY_FPORT_MAX_TARGETS];
	u8 count;
	bool strict_primary;
};

struct recovery_fport_status {
	u8 rx_fport;
	u8 rx_sport;
	u8 rx_qdma;
	u8 tx_fport;
	u8 primary_fport;
	u8 primary_hw_fport;
	u8 attempt_mask;
	u8 success_mask;
	u8 last_tx_hw_fport;
	int primary_error;
	int last_tx_error;
	u32 attempts_fport1;
	u32 attempts_fport2;
	u32 attempts_fport4;
	u32 successes_fport1;
	u32 successes_fport2;
	u32 successes_fport4;
	u32 failures_fport1;
	u32 failures_fport2;
	u32 failures_fport4;
};

struct recovery_fport_send_status {
	int result[RECOVERY_FPORT_MAX_TARGETS];
	u8 attempt_mask;
	u8 success_mask;
	int primary_error;
};

typedef int (*recovery_fport_send_fn)(void *ctx, u8 fport);

bool recovery_fport_is_valid(u8 fport);
u8 recovery_fport_bit(u8 fport);
u8 recovery_fport_from_rx_sport(u8 sport);
u8 recovery_fport_encode_hw(u8 fport);
bool recovery_fport_is_raw_dhcp_reply(const u8 *frame, size_t frame_len);

int recovery_fport_plan_init(struct recovery_fport_plan *plan,
			     u8 last_rx_fport, u8 fallback_fport,
			     bool dual_service, bool allow_10g);

int recovery_fport_plan_result(const struct recovery_fport_plan *plan,
			       const int *results, u8 *attempt_mask,
			       u8 *success_mask, int *primary_error);

int recovery_fport_send_plan(const struct recovery_fport_plan *plan,
			     recovery_fport_send_fn send, void *ctx,
			     struct recovery_fport_send_status *status);

#if defined(CONFIG_AIROHA_ETH)
int airoha_recovery_get_fport_status(struct recovery_fport_status *status);
#endif

#endif /* __RECOVERY_FPORT_H__ */
