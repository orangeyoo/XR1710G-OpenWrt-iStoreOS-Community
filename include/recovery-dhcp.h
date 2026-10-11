/* SPDX-License-Identifier: GPL-2.0+ */

#ifndef __RECOVERY_DHCP_H__
#define __RECOVERY_DHCP_H__

#ifdef RECOVERY_DHCP_HOST_TEST
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

#define RECOVERY_DHCP_CHADDR_LEN	16
#define RECOVERY_DHCP_IPV4_LEN		4
#define RECOVERY_DHCP_MAC_LEN		6
#define RECOVERY_DHCP_REPLY_LEN		308
#define RECOVERY_DHCP_ETH_HDR_LEN	14
#define RECOVERY_DHCP_IPV4_HDR_LEN	20
#define RECOVERY_DHCP_UDP_HDR_LEN	8
#define RECOVERY_DHCP_REPLY_FRAME_LEN	\
	(RECOVERY_DHCP_ETH_HDR_LEN + RECOVERY_DHCP_IPV4_HDR_LEN + \
	 RECOVERY_DHCP_UDP_HDR_LEN + RECOVERY_DHCP_REPLY_LEN)

enum recovery_dhcp_parse_result {
	RECOVERY_DHCP_PARSE_OK = 0,
	RECOVERY_DHCP_PARSE_NOT_DHCP,
	RECOVERY_DHCP_PARSE_MALFORMED,
};

enum recovery_dhcp_message_type {
	RECOVERY_DHCP_DISCOVER = 1,
	RECOVERY_DHCP_OFFER = 2,
	RECOVERY_DHCP_REQUEST = 3,
	RECOVERY_DHCP_ACK = 5,
	RECOVERY_DHCP_NAK = 6,
};

struct recovery_dhcp_frame {
	const u8 *payload;
	size_t payload_len;
	u8 src_ip[RECOVERY_DHCP_IPV4_LEN];
	u16 src_port;
	u8 vlan_depth;
};

struct recovery_dhcp_request {
	u8 message_type;
	u8 htype;
	u8 hlen;
	u8 hops;
	u8 xid[4];
	u8 secs[2];
	u8 flags[2];
	u8 ciaddr[RECOVERY_DHCP_IPV4_LEN];
	u8 giaddr[RECOVERY_DHCP_IPV4_LEN];
	u8 chaddr[RECOVERY_DHCP_CHADDR_LEN];
	bool has_server_id;
	u8 server_id[RECOVERY_DHCP_IPV4_LEN];
	bool has_requested_ip;
	u8 requested_ip[RECOVERY_DHCP_IPV4_LEN];
};

struct recovery_dhcp_config {
	u8 server_ip[RECOVERY_DHCP_IPV4_LEN];
	u8 client_ip[RECOVERY_DHCP_IPV4_LEN];
	u8 netmask[RECOVERY_DHCP_IPV4_LEN];
	u32 lease_seconds;
};

enum recovery_dhcp_parse_result
recovery_dhcp_parse_frame(const u8 *frame, size_t frame_len,
			  struct recovery_dhcp_frame *view);

enum recovery_dhcp_parse_result
recovery_dhcp_parse_request(const u8 *payload, size_t payload_len,
			    struct recovery_dhcp_request *request);

u8 recovery_dhcp_select_reply(const struct recovery_dhcp_request *request,
			      const struct recovery_dhcp_config *config);

int recovery_dhcp_build_reply(const struct recovery_dhcp_request *request,
			      const struct recovery_dhcp_config *config,
			      u8 message_type, u8 *payload,
			      size_t payload_capacity);

int recovery_dhcp_build_reply_frame(
			      const struct recovery_dhcp_request *request,
			      const struct recovery_dhcp_config *config,
			      const u8 server_mac[RECOVERY_DHCP_MAC_LEN],
			      u8 message_type, u8 *frame,
			      size_t frame_capacity);

#endif /* __RECOVERY_DHCP_H__ */
