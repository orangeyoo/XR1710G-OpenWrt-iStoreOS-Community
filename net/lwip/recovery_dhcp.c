// SPDX-License-Identifier: GPL-2.0+

#include <recovery-dhcp.h>

#ifdef RECOVERY_DHCP_HOST_TEST
#include <string.h>
#else
#include <linux/string.h>
#endif

#define RECOVERY_ETH_HDR_LEN		14
#define RECOVERY_IPV4_MIN_HDR_LEN	20
#define RECOVERY_UDP_HDR_LEN		8
#define RECOVERY_DHCP_FIXED_LEN		236
#define RECOVERY_DHCP_OPTIONS_OFS	240

#define RECOVERY_ETHERTYPE_IPV4		0x0800
#define RECOVERY_ETHERTYPE_VLAN		0x8100
#define RECOVERY_ETHERTYPE_QINQ		0x88a8
#define RECOVERY_ETHERTYPE_VLAN_9100	0x9100

#define RECOVERY_IP_PROTO_UDP		17
#define RECOVERY_DHCP_CLIENT_PORT	68
#define RECOVERY_DHCP_SERVER_PORT	67

#define RECOVERY_DHCP_BOOTREQUEST	1
#define RECOVERY_DHCP_BOOTREPLY		2
#define RECOVERY_DHCP_HTYPE_ETHERNET	1
#define RECOVERY_DHCP_HLEN_ETHERNET	6

#define RECOVERY_DHCP_MAGIC_COOKIE_0	0x63
#define RECOVERY_DHCP_MAGIC_COOKIE_1	0x82
#define RECOVERY_DHCP_MAGIC_COOKIE_2	0x53
#define RECOVERY_DHCP_MAGIC_COOKIE_3	0x63

#define RECOVERY_DHCP_OPTION_PAD		0
#define RECOVERY_DHCP_OPTION_SUBNET	1
#define RECOVERY_DHCP_OPTION_BROADCAST	28
#define RECOVERY_DHCP_OPTION_REQUESTED	50
#define RECOVERY_DHCP_OPTION_LEASE	51
#define RECOVERY_DHCP_OPTION_TYPE	53
#define RECOVERY_DHCP_OPTION_SERVER	54
#define RECOVERY_DHCP_OPTION_END		255

static u16 recovery_get_be16(const u8 *p)
{
	return ((u16)p[0] << 8) | p[1];
}

static void recovery_put_be16(u8 *p, u16 value)
{
	p[0] = value >> 8;
	p[1] = value;
}

static void recovery_put_be32(u8 *p, u32 value)
{
	p[0] = value >> 24;
	p[1] = value >> 16;
	p[2] = value >> 8;
	p[3] = value;
}

static bool recovery_is_vlan(u16 ethertype)
{
	return ethertype == RECOVERY_ETHERTYPE_VLAN ||
	       ethertype == RECOVERY_ETHERTYPE_QINQ ||
	       ethertype == RECOVERY_ETHERTYPE_VLAN_9100;
}

static bool recovery_ipv4_is_zero(const u8 *addr)
{
	return !(addr[0] | addr[1] | addr[2] | addr[3]);
}

static bool recovery_ipv4_equal(const u8 *a, const u8 *b)
{
	return !memcmp(a, b, RECOVERY_DHCP_IPV4_LEN);
}

enum recovery_dhcp_parse_result
recovery_dhcp_parse_frame(const u8 *frame, size_t frame_len,
			  struct recovery_dhcp_frame *view)
{
	size_t l3_off = RECOVERY_ETH_HDR_LEN;
	size_t ip_hlen, ip_total_len, udp_off, udp_len;
	u16 ethertype, fragment;
	u8 vlan_depth = 0;

	if (!frame || !view || frame_len < RECOVERY_ETH_HDR_LEN)
		return RECOVERY_DHCP_PARSE_NOT_DHCP;

	memset(view, 0, sizeof(*view));
	ethertype = recovery_get_be16(frame + 12);

	while (recovery_is_vlan(ethertype)) {
		if (++vlan_depth > 2 || frame_len < l3_off + 4)
			return RECOVERY_DHCP_PARSE_MALFORMED;

		ethertype = recovery_get_be16(frame + l3_off + 2);
		l3_off += 4;
	}

	if (ethertype != RECOVERY_ETHERTYPE_IPV4)
		return RECOVERY_DHCP_PARSE_NOT_DHCP;
	if (frame_len < l3_off + RECOVERY_IPV4_MIN_HDR_LEN)
		return RECOVERY_DHCP_PARSE_MALFORMED;
	if ((frame[l3_off] >> 4) != 4)
		return RECOVERY_DHCP_PARSE_MALFORMED;

	ip_hlen = (frame[l3_off] & 0x0f) * 4;
	if (ip_hlen < RECOVERY_IPV4_MIN_HDR_LEN ||
	    frame_len < l3_off + ip_hlen + RECOVERY_UDP_HDR_LEN)
		return RECOVERY_DHCP_PARSE_MALFORMED;
	if (frame[l3_off + 9] != RECOVERY_IP_PROTO_UDP)
		return RECOVERY_DHCP_PARSE_NOT_DHCP;

	fragment = recovery_get_be16(frame + l3_off + 6);
	if (fragment & 0x3fff)
		return RECOVERY_DHCP_PARSE_MALFORMED;

	ip_total_len = recovery_get_be16(frame + l3_off + 2);
	if (ip_total_len < ip_hlen + RECOVERY_UDP_HDR_LEN ||
	    ip_total_len > frame_len - l3_off)
		return RECOVERY_DHCP_PARSE_MALFORMED;

	udp_off = l3_off + ip_hlen;
	if (recovery_get_be16(frame + udp_off) !=
		    RECOVERY_DHCP_CLIENT_PORT ||
	    recovery_get_be16(frame + udp_off + 2) !=
		    RECOVERY_DHCP_SERVER_PORT)
		return RECOVERY_DHCP_PARSE_NOT_DHCP;

	udp_len = recovery_get_be16(frame + udp_off + 4);
	if (udp_len < RECOVERY_UDP_HDR_LEN + RECOVERY_DHCP_OPTIONS_OFS ||
	    udp_len > ip_total_len - ip_hlen ||
	    udp_off + udp_len > frame_len)
		return RECOVERY_DHCP_PARSE_MALFORMED;

	view->payload = frame + udp_off + RECOVERY_UDP_HDR_LEN;
	view->payload_len = udp_len - RECOVERY_UDP_HDR_LEN;
	memcpy(view->src_ip, frame + l3_off + 12, sizeof(view->src_ip));
	view->src_port = RECOVERY_DHCP_CLIENT_PORT;
	view->vlan_depth = vlan_depth;

	return RECOVERY_DHCP_PARSE_OK;
}

enum recovery_dhcp_parse_result
recovery_dhcp_parse_request(const u8 *payload, size_t payload_len,
			    struct recovery_dhcp_request *request)
{
	size_t off = RECOVERY_DHCP_OPTIONS_OFS;
	bool has_message_type = false;

	if (!payload || !request ||
	    payload_len < RECOVERY_DHCP_OPTIONS_OFS)
		return RECOVERY_DHCP_PARSE_MALFORMED;

	memset(request, 0, sizeof(*request));
	if (payload[0] != RECOVERY_DHCP_BOOTREQUEST ||
	    payload[1] != RECOVERY_DHCP_HTYPE_ETHERNET ||
	    payload[2] != RECOVERY_DHCP_HLEN_ETHERNET ||
	    payload[236] != RECOVERY_DHCP_MAGIC_COOKIE_0 ||
	    payload[237] != RECOVERY_DHCP_MAGIC_COOKIE_1 ||
	    payload[238] != RECOVERY_DHCP_MAGIC_COOKIE_2 ||
	    payload[239] != RECOVERY_DHCP_MAGIC_COOKIE_3)
		return RECOVERY_DHCP_PARSE_MALFORMED;

	request->htype = payload[1];
	request->hlen = payload[2];
	request->hops = payload[3];
	memcpy(request->xid, payload + 4, sizeof(request->xid));
	memcpy(request->secs, payload + 8, sizeof(request->secs));
	memcpy(request->flags, payload + 10, sizeof(request->flags));
	memcpy(request->ciaddr, payload + 12, sizeof(request->ciaddr));
	memcpy(request->giaddr, payload + 24, sizeof(request->giaddr));
	memcpy(request->chaddr, payload + 28, sizeof(request->chaddr));

	while (off < payload_len) {
		u8 code = payload[off++];
		u8 len;

		if (code == RECOVERY_DHCP_OPTION_PAD)
			continue;
		if (code == RECOVERY_DHCP_OPTION_END)
			break;
		if (off >= payload_len)
			return RECOVERY_DHCP_PARSE_MALFORMED;

		len = payload[off++];
		if (off + len > payload_len)
			return RECOVERY_DHCP_PARSE_MALFORMED;

		switch (code) {
		case RECOVERY_DHCP_OPTION_TYPE:
			if (len != 1 || has_message_type)
				return RECOVERY_DHCP_PARSE_MALFORMED;
			request->message_type = payload[off];
			has_message_type = true;
			break;
		case RECOVERY_DHCP_OPTION_SERVER:
			if (len != RECOVERY_DHCP_IPV4_LEN ||
			    request->has_server_id)
				return RECOVERY_DHCP_PARSE_MALFORMED;
			memcpy(request->server_id, payload + off, len);
			request->has_server_id = true;
			break;
		case RECOVERY_DHCP_OPTION_REQUESTED:
			if (len != RECOVERY_DHCP_IPV4_LEN ||
			    request->has_requested_ip)
				return RECOVERY_DHCP_PARSE_MALFORMED;
			memcpy(request->requested_ip, payload + off, len);
			request->has_requested_ip = true;
			break;
		default:
			break;
		}

		off += len;
	}

	return has_message_type ? RECOVERY_DHCP_PARSE_OK :
				  RECOVERY_DHCP_PARSE_MALFORMED;
}

u8 recovery_dhcp_select_reply(const struct recovery_dhcp_request *request,
			      const struct recovery_dhcp_config *config)
{
	if (!request || !config)
		return 0;

	if (request->message_type == RECOVERY_DHCP_DISCOVER)
		return RECOVERY_DHCP_OFFER;
	if (request->message_type != RECOVERY_DHCP_REQUEST)
		return 0;

	if (request->has_server_id &&
	    !recovery_ipv4_equal(request->server_id, config->server_ip))
		return 0;

	/*
	 * option 50 and ciaddr describe mutually exclusive DHCPREQUEST states.
	 * If a malformed client supplies both with different addresses, do not
	 * guess which one is authoritative and risk ACKing the wrong request.
	 */
	if (request->has_requested_ip &&
	    !recovery_ipv4_is_zero(request->ciaddr) &&
	    !recovery_ipv4_equal(request->requested_ip, request->ciaddr))
		return 0;

	if (request->has_requested_ip)
		return recovery_ipv4_equal(request->requested_ip,
					   config->client_ip) ?
			       RECOVERY_DHCP_ACK : RECOVERY_DHCP_NAK;

	if (!recovery_ipv4_is_zero(request->ciaddr))
		return recovery_ipv4_equal(request->ciaddr,
					   config->client_ip) ?
			       RECOVERY_DHCP_ACK : RECOVERY_DHCP_NAK;

	/*
	 * A DHCPREQUEST must identify the requested address either through
	 * option 50 (SELECTING/INIT-REBOOT) or ciaddr (RENEWING/REBINDING).
	 * Silently ignore an incomplete request instead of ACKing an address
	 * that the client did not actually request.
	 */
	return 0;
}

static int recovery_put_option(u8 *payload, size_t *off, size_t capacity,
			       u8 code, const u8 *value, u8 len)
{
	if (*off + 2 + len > capacity)
		return -1;

	payload[(*off)++] = code;
	payload[(*off)++] = len;
	memcpy(payload + *off, value, len);
	*off += len;

	return 0;
}

int recovery_dhcp_build_reply(const struct recovery_dhcp_request *request,
			      const struct recovery_dhcp_config *config,
			      u8 message_type, u8 *payload,
			      size_t payload_capacity)
{
	u8 broadcast[RECOVERY_DHCP_IPV4_LEN];
	u8 lease[4];
	size_t off = RECOVERY_DHCP_OPTIONS_OFS;
	int i;

	if (!request || !config || !payload ||
	    payload_capacity < RECOVERY_DHCP_REPLY_LEN)
		return -1;
	if (message_type != RECOVERY_DHCP_OFFER &&
	    message_type != RECOVERY_DHCP_ACK &&
	    message_type != RECOVERY_DHCP_NAK)
		return -1;

	memset(payload, 0, RECOVERY_DHCP_REPLY_LEN);
	payload[0] = RECOVERY_DHCP_BOOTREPLY;
	payload[1] = request->htype;
	payload[2] = request->hlen;
	payload[3] = request->hops;
	memcpy(payload + 4, request->xid, sizeof(request->xid));
	memcpy(payload + 8, request->secs, sizeof(request->secs));
	memcpy(payload + 10, request->flags, sizeof(request->flags));
	payload[10] |= 0x80;
	if (message_type != RECOVERY_DHCP_NAK)
		memcpy(payload + 16, config->client_ip,
		       RECOVERY_DHCP_IPV4_LEN);
	memcpy(payload + 24, request->giaddr, sizeof(request->giaddr));
	memcpy(payload + 28, request->chaddr, sizeof(request->chaddr));
	payload[236] = RECOVERY_DHCP_MAGIC_COOKIE_0;
	payload[237] = RECOVERY_DHCP_MAGIC_COOKIE_1;
	payload[238] = RECOVERY_DHCP_MAGIC_COOKIE_2;
	payload[239] = RECOVERY_DHCP_MAGIC_COOKIE_3;

	if (recovery_put_option(payload, &off, RECOVERY_DHCP_REPLY_LEN,
				RECOVERY_DHCP_OPTION_TYPE, &message_type, 1) ||
	    recovery_put_option(payload, &off, RECOVERY_DHCP_REPLY_LEN,
				RECOVERY_DHCP_OPTION_SERVER,
				config->server_ip,
				RECOVERY_DHCP_IPV4_LEN))
		return -1;

	if (message_type != RECOVERY_DHCP_NAK) {
		recovery_put_be32(lease, config->lease_seconds);
		for (i = 0; i < RECOVERY_DHCP_IPV4_LEN; i++)
			broadcast[i] = (config->server_ip[i] &
					config->netmask[i]) |
				       (u8)~config->netmask[i];

		if (recovery_put_option(payload, &off,
					RECOVERY_DHCP_REPLY_LEN,
					RECOVERY_DHCP_OPTION_LEASE,
					lease, sizeof(lease)) ||
		    recovery_put_option(payload, &off,
					RECOVERY_DHCP_REPLY_LEN,
					RECOVERY_DHCP_OPTION_SUBNET,
					config->netmask,
					RECOVERY_DHCP_IPV4_LEN) ||
		    recovery_put_option(payload, &off,
					RECOVERY_DHCP_REPLY_LEN,
					RECOVERY_DHCP_OPTION_BROADCAST,
					broadcast,
					RECOVERY_DHCP_IPV4_LEN))
			return -1;
	}

	if (off >= RECOVERY_DHCP_REPLY_LEN)
		return -1;
	payload[off] = RECOVERY_DHCP_OPTION_END;

	return RECOVERY_DHCP_REPLY_LEN;
}

static u32 recovery_checksum_add(u32 sum, const u8 *data, size_t len)
{
	while (len > 1) {
		sum += ((u16)data[0] << 8) | data[1];
		data += 2;
		len -= 2;
	}
	if (len)
		sum += (u16)data[0] << 8;

	return sum;
}

static u16 recovery_checksum_finish(u32 sum)
{
	while (sum >> 16)
		sum = (sum & 0xffff) + (sum >> 16);

	return (u16)~sum;
}

int recovery_dhcp_build_reply_frame(
			      const struct recovery_dhcp_request *request,
			      const struct recovery_dhcp_config *config,
			      const u8 server_mac[RECOVERY_DHCP_MAC_LEN],
			      u8 message_type, u8 *frame,
			      size_t frame_capacity)
{
	static const u8 broadcast_mac[RECOVERY_DHCP_MAC_LEN] = {
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff
	};
	static const u8 broadcast_ip[RECOVERY_DHCP_IPV4_LEN] = {
		0xff, 0xff, 0xff, 0xff
	};
	u8 pseudo_tail[4];
	u8 *ip;
	u8 *udp;
	u8 *payload;
	u16 ip_total_len;
	u16 udp_len;
	u16 checksum;
	u32 sum;
	int payload_len;

	if (!request || !config || !server_mac || !frame ||
	    frame_capacity < RECOVERY_DHCP_REPLY_FRAME_LEN)
		return -1;

	memset(frame, 0, RECOVERY_DHCP_REPLY_FRAME_LEN);
	memcpy(frame, broadcast_mac, sizeof(broadcast_mac));
	memcpy(frame + RECOVERY_DHCP_MAC_LEN, server_mac,
	       RECOVERY_DHCP_MAC_LEN);
	recovery_put_be16(frame + 12, RECOVERY_ETHERTYPE_IPV4);

	ip = frame + RECOVERY_DHCP_ETH_HDR_LEN;
	udp = ip + RECOVERY_DHCP_IPV4_HDR_LEN;
	payload = udp + RECOVERY_DHCP_UDP_HDR_LEN;
	payload_len = recovery_dhcp_build_reply(request, config, message_type,
						payload,
						RECOVERY_DHCP_REPLY_LEN);
	if (payload_len != RECOVERY_DHCP_REPLY_LEN)
		return -1;

	udp_len = RECOVERY_DHCP_UDP_HDR_LEN + payload_len;
	ip_total_len = RECOVERY_DHCP_IPV4_HDR_LEN + udp_len;

	ip[0] = 0x45;
	ip[1] = 0;
	recovery_put_be16(ip + 2, ip_total_len);
	/* Derive a deterministic IP ID from the transaction ID. */
	ip[4] = request->xid[2];
	ip[5] = request->xid[3];
	recovery_put_be16(ip + 6, 0);
	ip[8] = 64;
	ip[9] = RECOVERY_IP_PROTO_UDP;
	memcpy(ip + 12, config->server_ip, RECOVERY_DHCP_IPV4_LEN);
	memcpy(ip + 16, broadcast_ip, RECOVERY_DHCP_IPV4_LEN);
	checksum = recovery_checksum_finish(
		recovery_checksum_add(0, ip, RECOVERY_DHCP_IPV4_HDR_LEN));
	recovery_put_be16(ip + 10, checksum);

	recovery_put_be16(udp, RECOVERY_DHCP_SERVER_PORT);
	recovery_put_be16(udp + 2, RECOVERY_DHCP_CLIENT_PORT);
	recovery_put_be16(udp + 4, udp_len);
	recovery_put_be16(udp + 6, 0);

	sum = recovery_checksum_add(0, config->server_ip,
				    RECOVERY_DHCP_IPV4_LEN);
	sum = recovery_checksum_add(sum, broadcast_ip,
				    RECOVERY_DHCP_IPV4_LEN);
	pseudo_tail[0] = 0;
	pseudo_tail[1] = RECOVERY_IP_PROTO_UDP;
	recovery_put_be16(pseudo_tail + 2, udp_len);
	sum = recovery_checksum_add(sum, pseudo_tail, sizeof(pseudo_tail));
	sum = recovery_checksum_add(sum, udp, udp_len);
	checksum = recovery_checksum_finish(sum);
	/* RFC 768 represents a computed zero checksum as all ones. */
	if (!checksum)
		checksum = 0xffff;
	recovery_put_be16(udp + 6, checksum);

	return RECOVERY_DHCP_REPLY_FRAME_LEN;
}
