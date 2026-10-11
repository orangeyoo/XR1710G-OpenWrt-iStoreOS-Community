/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __XR1710G_WIRO_ENV_SAFETY_H__
#define __XR1710G_WIRO_ENV_SAFETY_H__

#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <errno.h>

struct xr1710g_wiro_env_io_ops {
	int (*write)(void *ctx, const char *volume, const void *buf, size_t size);
	int (*read)(void *ctx, const char *volume, void *buf, size_t size);
};

struct xr1710g_wiro_env_requirements {
	const char *magic;
	const char *schema;
	const char *generation;
};

enum xr1710g_wiro_env_content_state {
	XR1710G_WIRO_ENV_CONTENT_CURRENT = 0,
	XR1710G_WIRO_ENV_CONTENT_ERASED,
	XR1710G_WIRO_ENV_CONTENT_STALE,
	XR1710G_WIRO_ENV_CONTENT_MALFORMED,
};

static inline bool xr1710g_wiro_env_all_value(const unsigned char *data,
					       size_t data_size,
					       unsigned char value)
{
	size_t i;

	if (!data || !data_size)
		return false;
	for (i = 0; i < data_size; i++) {
		if (data[i] != value)
			return false;
	}

	return true;
}

static inline bool xr1710g_wiro_env_required_value_valid(const char *value,
							  bool numeric)
{
	const unsigned char *pos = (const unsigned char *)value;

	if (!pos || !*pos)
		return false;
	if (!numeric)
		return true;
	while (*pos) {
		if (*pos < '0' || *pos > '9')
			return false;
		pos++;
	}

	return true;
}

static inline enum xr1710g_wiro_env_content_state
xr1710g_wiro_env_classify_content(
	const unsigned char *data, size_t data_size,
	const struct xr1710g_wiro_env_requirements *required)
{
	static const char *const names[] = {
		"wiro_env_magic",
		"wiro_env_schema",
		"wiro_env_generation",
	};
	const char *values[3];
	const unsigned char *pos = data;
	size_t remaining = data_size;
	unsigned int seen[3] = { 0 };
	bool terminated = false;

	if (!data || !data_size || !required ||
	    !xr1710g_wiro_env_required_value_valid(required->magic, false) ||
	    !xr1710g_wiro_env_required_value_valid(required->schema, true) ||
	    !xr1710g_wiro_env_required_value_valid(required->generation, true))
		return XR1710G_WIRO_ENV_CONTENT_MALFORMED;

	if (xr1710g_wiro_env_all_value(data, data_size, 0x00) ||
	    xr1710g_wiro_env_all_value(data, data_size, 0xff))
		return XR1710G_WIRO_ENV_CONTENT_ERASED;

	values[0] = required->magic;
	values[1] = required->schema;
	values[2] = required->generation;
	while (remaining) {
		const unsigned char *equals;
		size_t entry_len;
		unsigned int i;

		if (!*pos) {
			if (remaining < 2 || pos[1])
				return XR1710G_WIRO_ENV_CONTENT_MALFORMED;
			terminated = true;
			break;
		}

		entry_len = strnlen((const char *)pos, remaining);
		if (entry_len == remaining)
			return XR1710G_WIRO_ENV_CONTENT_MALFORMED;
		equals = memchr(pos, '=', entry_len);
		if (!equals || equals == pos)
			return XR1710G_WIRO_ENV_CONTENT_MALFORMED;

		for (i = 0; i < 3; i++) {
			size_t name_len = strlen(names[i]);
			size_t value_len;

			if ((size_t)(equals - pos) != name_len ||
			    memcmp(pos, names[i], name_len))
				continue;
			seen[i]++;
			if (seen[i] != 1)
				return XR1710G_WIRO_ENV_CONTENT_MALFORMED;
			value_len = entry_len - name_len - 1;
			if (value_len != strlen(values[i]) ||
			    memcmp(equals + 1, values[i], value_len))
				return XR1710G_WIRO_ENV_CONTENT_STALE;
		}

		pos += entry_len + 1;
		remaining -= entry_len + 1;
	}

	if (!terminated)
		return XR1710G_WIRO_ENV_CONTENT_MALFORMED;
	if (seen[0] != 1 || seen[1] != 1 || seen[2] != 1)
		return XR1710G_WIRO_ENV_CONTENT_STALE;

	return XR1710G_WIRO_ENV_CONTENT_CURRENT;
}

static inline bool xr1710g_wiro_env_generation_matches(
	const unsigned char *data, size_t data_size, const char *required)
{
	struct xr1710g_wiro_env_requirements requirements = {
		.magic = "compat",
		.schema = "1",
		.generation = required,
	};

	/* Compatibility wrapper retained for old host callers only. */
	if (!required || !*required)
		return true;
	return xr1710g_wiro_env_classify_content(data, data_size,
						   &requirements) ==
	       XR1710G_WIRO_ENV_CONTENT_CURRENT;
}

static inline int xr1710g_wiro_env_clear_and_verify(
	const struct xr1710g_wiro_env_io_ops *ops, void *ctx,
	const char *volume, const void *zero_buf, void *verify_buf, size_t size)
{
	int ret;

	if (!ops || !ops->write || !ops->read || !volume || !*volume ||
	    !zero_buf || !verify_buf || !size)
		return -EINVAL;

	ret = ops->write(ctx, volume, zero_buf, size);
	if (ret)
		return ret;

	memset(verify_buf, 0xa5, size);
	ret = ops->read(ctx, volume, verify_buf, size);
	if (ret)
		return ret;
	if (memcmp(zero_buf, verify_buf, size))
		return -EIO;

	return 0;
}

#endif /* __XR1710G_WIRO_ENV_SAFETY_H__ */
