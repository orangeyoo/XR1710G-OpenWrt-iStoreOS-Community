/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __XR1710G_RECOVERY_UPLOAD_PARSER_H__
#define __XR1710G_RECOVERY_UPLOAD_PARSER_H__

#include <errno.h>
#include <stddef.h>

enum xr1710g_recovery_upload_target {
	XR1710G_RECOVERY_UPLOAD_FIRMWARE = 0,
	XR1710G_RECOVERY_UPLOAD_UBOOT,
};

enum xr1710g_recovery_upload_layout {
	XR1710G_RECOVERY_LAYOUT_2_0 = 0,
	XR1710G_RECOVERY_LAYOUT_1_5,
	XR1710G_RECOVERY_LAYOUT_1_0,
};

struct xr1710g_recovery_upload_request {
	enum xr1710g_recovery_upload_target target;
	enum xr1710g_recovery_upload_layout layout;
};

static inline int xr1710g_recovery_span_eq(const char *value,
					   size_t value_len,
					   const char *expected)
{
	size_t i;

	for (i = 0; i < value_len; i++) {
		if (!expected[i] || value[i] != expected[i])
			return 0;
	}
	return expected[value_len] == '\0';
}

/*
 * Parse the exact POST URI emitted by the matching Recovery UI.
 *
 * -ESTALE is reserved for an absent or mismatched ui_build value. All URI,
 * query grammar and upload-policy violations return -EINVAL. Percent escapes
 * are deliberately unsupported so decoding order cannot change policy.
 */
static inline int
xr1710g_recovery_parse_upload_uri(const char *uri, const char *expected_build,
				  struct xr1710g_recovery_upload_request *request)
{
	static const char firmware_path[] = "/upload/firmware";
	static const char uboot_path[] = "/upload/uboot";
	const char *query = NULL;
	const char *cursor;
	size_t path_len = 0;
	int build_seen = 0;
	int build_matches = 0;
	int layout_seen = 0;
	enum xr1710g_recovery_upload_layout layout =
		XR1710G_RECOVERY_LAYOUT_2_0;

	if (!uri || !expected_build || !expected_build[0] || !request)
		return -EINVAL;

	for (cursor = uri; *cursor; cursor++) {
		unsigned char c = (unsigned char)*cursor;

		if (c <= 0x20 || c >= 0x7f || c == '%' || c == '#' ||
		    c == '\\')
			return -EINVAL;
		if (*cursor == '?') {
			if (query)
				return -EINVAL;
			query = cursor;
		}
	}

	path_len = query ? (size_t)(query - uri) : (size_t)(cursor - uri);
	if (path_len == sizeof(firmware_path) - 1 &&
	    xr1710g_recovery_span_eq(uri, path_len, firmware_path)) {
		request->target = XR1710G_RECOVERY_UPLOAD_FIRMWARE;
	} else if (path_len == sizeof(uboot_path) - 1 &&
		   xr1710g_recovery_span_eq(uri, path_len, uboot_path)) {
		request->target = XR1710G_RECOVERY_UPLOAD_UBOOT;
	} else {
		return -EINVAL;
	}

	if (!query || !query[1])
		return -ESTALE;

	cursor = query + 1;
	while (*cursor) {
		const char *end = cursor;
		const char *equals = NULL;
		const char *value;
		size_t key_len;
		size_t value_len;

		while (*end && *end != '&') {
			if (*end == '=') {
				if (equals)
					return -EINVAL;
				equals = end;
			}
			end++;
		}
		if (!equals || equals == cursor || equals + 1 == end)
			return -EINVAL;

		key_len = (size_t)(equals - cursor);
		value = equals + 1;
		value_len = (size_t)(end - value);
		if (xr1710g_recovery_span_eq(cursor, key_len, "ui_build")) {
			if (build_seen)
				return -EINVAL;
			build_seen = 1;
			build_matches = xr1710g_recovery_span_eq(value, value_len, expected_build);
		} else if (xr1710g_recovery_span_eq(cursor, key_len,
						 "layout")) {
			if (layout_seen ||
			    request->target != XR1710G_RECOVERY_UPLOAD_FIRMWARE)
				return -EINVAL;
			layout_seen = 1;
			if (xr1710g_recovery_span_eq(value, value_len, "2.0"))
				layout = XR1710G_RECOVERY_LAYOUT_2_0;
			else if (xr1710g_recovery_span_eq(value, value_len, "1.5"))
				layout = XR1710G_RECOVERY_LAYOUT_1_5;
			else if (xr1710g_recovery_span_eq(value, value_len, "1.0"))
				layout = XR1710G_RECOVERY_LAYOUT_1_0;
			else
				return -EINVAL;
		} else {
			return -EINVAL;
		}

		if (!*end)
			break;
		cursor = end + 1;
		if (!*cursor)
			return -EINVAL;
	}

	if (!build_seen || !build_matches)
		return -ESTALE;
	if (request->target == XR1710G_RECOVERY_UPLOAD_FIRMWARE &&
	    !layout_seen)
		return -EINVAL;

	request->layout = layout;
	return 0;
}

#endif /* __XR1710G_RECOVERY_UPLOAD_PARSER_H__ */
