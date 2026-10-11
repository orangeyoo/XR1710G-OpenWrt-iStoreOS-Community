// SPDX-License-Identifier: GPL-2.0+
/*
 * (c) Copyright 2012 by National Instruments,
 *        Joe Hershberger <joe.hershberger@ni.com>
 */

#include <asm/global_data.h>

#include <command.h>
#include <env.h>
#include <env_internal.h>
#include <errno.h>
#include <malloc.h>
#include <memalign.h>
#include <search.h>
#include <ubi_uboot.h>
#include <xr1710g-wiro-env-safety.h>
#undef crc32

#define _QUOTE(x) #x
#define QUOTE(x) _QUOTE(x)

#if (CONFIG_ENV_UBI_VID_OFFSET == 0)
 #define UBI_VID_OFFSET NULL
#else
 #define UBI_VID_OFFSET QUOTE(CONFIG_ENV_UBI_VID_OFFSET)
#endif

DECLARE_GLOBAL_DATA_PTR;

const char *env_ubi_get_part(void);

__weak const char *env_ubi_required_generation(void)
{
	return NULL;
}

static bool env_ubi_has_required_generation(const env_t *env)
{
	const char *required = env_ubi_required_generation();

	return xr1710g_wiro_env_generation_matches(env->data, ENV_SIZE,
						     required);
}

static int env_ubi_apply_generation_gate(const char *volume, env_t *env,
					 int read_error)
{
	if (read_error || env_ubi_has_required_generation(env))
		return read_error;

	printf("\n** Ignoring stale or ambiguous environment in %s:%s **\n",
	       env_ubi_get_part(), volume);
	return -EPROTO;
}

__weak const char *env_ubi_get_part(void)
{
	return CONFIG_ENV_UBI_PART;
}

#if CONFIG_ENV_REDUNDANT
#define ENV_UBI_VOLUME_REDUND CONFIG_ENV_UBI_VOLUME_REDUND
#else
#define ENV_UBI_VOLUME_REDUND "invalid"
#endif

#ifdef CONFIG_ENV_REDUNDANT
static int env_ubi_save(void)
{
	ALLOC_CACHE_ALIGN_BUFFER(env_t, env_new, 1);
	int ret;

	ret = env_export(env_new);
	if (ret)
		return ret;

	if (ubi_part(env_ubi_get_part(), UBI_VID_OFFSET)) {
		printf("\n** Cannot find mtd partition \"%s\"\n",
		       env_ubi_get_part());
		return 1;
	}

	if (gd->env_valid == ENV_VALID) {
		puts("Writing to redundant UBI... ");
		if (ubi_volume_write(CONFIG_ENV_UBI_VOLUME_REDUND,
				     (void *)env_new, 0, CONFIG_ENV_SIZE)) {
			printf("\n** Unable to write env to %s:%s **\n",
			       env_ubi_get_part(),
			       CONFIG_ENV_UBI_VOLUME_REDUND);
			return 1;
		}
	} else {
		puts("Writing to UBI... ");
		if (ubi_volume_write(CONFIG_ENV_UBI_VOLUME,
				     (void *)env_new, 0, CONFIG_ENV_SIZE)) {
			printf("\n** Unable to write env to %s:%s **\n",
			       env_ubi_get_part(),
			       CONFIG_ENV_UBI_VOLUME);
			return 1;
		}
	}

	puts("done\n");

	gd->env_valid = gd->env_valid == ENV_VALID ? ENV_REDUND : ENV_VALID;

	return 0;
}
#else /* ! CONFIG_ENV_REDUNDANT */
static int env_ubi_save(void)
{
	ALLOC_CACHE_ALIGN_BUFFER(env_t, env_new, 1);
	int ret;

	ret = env_export(env_new);
	if (ret)
		return ret;

	if (ubi_part(env_ubi_get_part(), UBI_VID_OFFSET)) {
		printf("\n** Cannot find mtd partition \"%s\"\n",
		       env_ubi_get_part());
		return 1;
	}

	if (ubi_volume_write(CONFIG_ENV_UBI_VOLUME, (void *)env_new, 0,
			     CONFIG_ENV_SIZE)) {
		printf("\n** Unable to write env to %s:%s **\n",
		       env_ubi_get_part(), CONFIG_ENV_UBI_VOLUME);
		return 1;
	}

	puts("done\n");
	return 0;
}
#endif /* CONFIG_ENV_REDUNDANT */

static int env_ubi_volume_create(const char *volume)
{
	bool dynamic = !IS_ENABLED(CONFIG_ENV_UBI_VOLUME_STATIC);
	struct ubi_volume *vol;
	int ret;

	vol = ubi_find_volume(volume);
	if (vol)
		return 0;

	ret = ubi_create_vol(volume, CONFIG_ENV_SIZE, dynamic, UBI_VOL_NUM_AUTO,
			     false);
	if (ret)
		printf("Failed to create environment volume '%s'\n", volume);

	return ret;
}

#ifdef CONFIG_ENV_REDUNDANT
static int env_ubi_load(void)
{
	ALLOC_CACHE_ALIGN_BUFFER(char, env1_buf, CONFIG_ENV_SIZE);
	ALLOC_CACHE_ALIGN_BUFFER(char, env2_buf, CONFIG_ENV_SIZE);
	int read1_fail, read2_fail, create1_fail = 0, create2_fail = 0;
	env_t *tmp_env1, *tmp_env2;

	/*
	 * In case we have restarted u-boot there is a chance that buffer
	 * contains old environment (from the previous boot).
	 * If UBI volume is zero size, ubi_volume_read() doesn't modify the
	 * buffer.
	 * We need to clear buffer manually here, so the invalid CRC will
	 * cause setting default environment as expected.
	 */
	memset(env1_buf, 0x0, CONFIG_ENV_SIZE);
	memset(env2_buf, 0x0, CONFIG_ENV_SIZE);

	tmp_env1 = (env_t *)env1_buf;
	tmp_env2 = (env_t *)env2_buf;

	if (ubi_part(env_ubi_get_part(), UBI_VID_OFFSET)) {
		printf("\n** Cannot find mtd partition \"%s\"\n",
		       env_ubi_get_part());
		env_set_default(NULL, 0);
		return -EIO;
	}

	if (IS_ENABLED(CONFIG_ENV_UBI_VOLUME_CREATE)) {
		create1_fail = env_ubi_volume_create(CONFIG_ENV_UBI_VOLUME);
		create2_fail = env_ubi_volume_create(CONFIG_ENV_UBI_VOLUME_REDUND);
		if (create1_fail && create2_fail) {
			env_set_default(NULL, 0);
			return -ENODEV;
		}
	}

	if (!create1_fail) {
		read1_fail = ubi_volume_read(CONFIG_ENV_UBI_VOLUME, tmp_env1, 0,
					     CONFIG_ENV_SIZE);
		if (read1_fail)
			printf("\n** Unable to read env from %s:%s **\n",
			       env_ubi_get_part(), CONFIG_ENV_UBI_VOLUME);
	} else {
		read1_fail = create1_fail;
	}
	read1_fail = env_ubi_apply_generation_gate(CONFIG_ENV_UBI_VOLUME,
						   tmp_env1, read1_fail);

	if (!create2_fail) {
		read2_fail = ubi_volume_read(CONFIG_ENV_UBI_VOLUME_REDUND,
					     tmp_env2, 0, CONFIG_ENV_SIZE);
		if (read2_fail)
			printf("\n** Unable to read redundant env from %s:%s **\n",
			       env_ubi_get_part(),
			       CONFIG_ENV_UBI_VOLUME_REDUND);
	} else {
		read2_fail = create2_fail;
	}
	read2_fail = env_ubi_apply_generation_gate(
		CONFIG_ENV_UBI_VOLUME_REDUND, tmp_env2, read2_fail);

	return env_import_redund((char *)tmp_env1, read1_fail, (char *)tmp_env2,
				 read2_fail, H_EXTERNAL);
}
#else /* ! CONFIG_ENV_REDUNDANT */
static int env_ubi_load(void)
{
	ALLOC_CACHE_ALIGN_BUFFER(char, buf, CONFIG_ENV_SIZE);

	/*
	 * In case we have restarted u-boot there is a chance that buffer
	 * contains old environment (from the previous boot).
	 * If UBI volume is zero size, ubi_volume_read() doesn't modify the
	 * buffer.
	 * We need to clear buffer manually here, so the invalid CRC will
	 * cause setting default environment as expected.
	 */
	memset(buf, 0x0, CONFIG_ENV_SIZE);

	if (ubi_part(env_ubi_get_part(), UBI_VID_OFFSET)) {
		printf("\n** Cannot find mtd partition \"%s\"\n",
		       env_ubi_get_part());
		env_set_default(NULL, 0);
		return -EIO;
	}

	if (IS_ENABLED(CONFIG_ENV_UBI_VOLUME_CREATE)) {
		if (env_ubi_volume_create(CONFIG_ENV_UBI_VOLUME)) {
			env_set_default(NULL, 0);
			return -ENODEV;
		}
	}

	if (ubi_volume_read(CONFIG_ENV_UBI_VOLUME, buf, 0, CONFIG_ENV_SIZE)) {
		printf("\n** Unable to read env from %s:%s **\n",
		       env_ubi_get_part(), CONFIG_ENV_UBI_VOLUME);
		env_set_default(NULL, 0);
		return -EIO;
	}
	if (!env_ubi_has_required_generation((env_t *)buf)) {
		printf("\n** Ignoring stale or ambiguous environment in %s:%s **\n",
		       env_ubi_get_part(), CONFIG_ENV_UBI_VOLUME);
		env_set_default("environment generation mismatch", 0);
		return -EPROTO;
	}

	return env_import(buf, 1, H_EXTERNAL);
}
#endif /* CONFIG_ENV_REDUNDANT */

static int env_ubi_safety_write(void *ctx, const char *volume,
				const void *buf, size_t size)
{
	(void)ctx;
	return ubi_volume_write(volume, (void *)buf, 0, size);
}

static int env_ubi_safety_read(void *ctx, const char *volume, void *buf,
			       size_t size)
{
	(void)ctx;
	return ubi_volume_read(volume, buf, 0, size);
}

static int env_ubi_clear_and_verify_volume(const char *volume,
					    const void *zero_buf,
					    void *verify_buf)
{
	static const struct xr1710g_wiro_env_io_ops ops = {
		.write = env_ubi_safety_write,
		.read = env_ubi_safety_read,
	};
	int ret;

	ret = xr1710g_wiro_env_clear_and_verify(&ops, NULL, volume, zero_buf,
						 verify_buf, CONFIG_ENV_SIZE);
	if (ret) {
		printf("\n** Unable to clear env in %s:%s **\n",
		       env_ubi_get_part(), volume);
		return ret;
	}

	return 0;
}

static int env_ubi_erase(void)
{
	ALLOC_CACHE_ALIGN_BUFFER(char, env_buf, CONFIG_ENV_SIZE);
	ALLOC_CACHE_ALIGN_BUFFER(char, verify_buf, CONFIG_ENV_SIZE);
	int ret;

	if (ubi_part(env_ubi_get_part(), UBI_VID_OFFSET)) {
		printf("\n** Cannot find mtd partition \"%s\"\n",
		       env_ubi_get_part());
		return 1;
	}

	memset(env_buf, 0x0, CONFIG_ENV_SIZE);

	ret = env_ubi_clear_and_verify_volume(CONFIG_ENV_UBI_VOLUME, env_buf,
					      verify_buf);
	if (ret)
		return ret;
	if (IS_ENABLED(CONFIG_ENV_REDUNDANT)) {
		ret = env_ubi_clear_and_verify_volume(ENV_UBI_VOLUME_REDUND,
						      env_buf, verify_buf);
		if (ret)
			return ret;
	}

	return 0;
}

U_BOOT_ENV_LOCATION(ubi) = {
	.location	= ENVL_UBI,
	ENV_NAME("UBI")
	.load		= env_ubi_load,
	.save		= ENV_SAVE_PTR(env_ubi_save),
	.erase		= ENV_ERASE_PTR(env_ubi_erase),
};
