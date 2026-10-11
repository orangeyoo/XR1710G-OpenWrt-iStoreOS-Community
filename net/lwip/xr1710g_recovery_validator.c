// SPDX-License-Identifier: GPL-2.0+
/*
 * Strict XR1710G Recovery U-Boot flash-slot validation.
 *
 * This source is linked into both the target Recovery server and the host
 * validator. Keep all acceptance decisions here so host tests exercise the
 * exact production implementation.
 */

#include <stdint.h>

#include <linux/types.h>
#include <hash.h>
#include <image.h>
#include <linux/errno.h>
#include <linux/libfdt.h>
#include <linux/string.h>
#include <malloc.h>
#include <xr1710g-recovery-validator.h>

#ifndef USE_HOSTCC
#include <asm/global_data.h>
DECLARE_GLOBAL_DATA_PTR;
#endif

#define XR1710G_RECOVERY_PREFIX_LOAD_ADDR	0x80088000UL
#define XR1710G_RECOVERY_UBOOT_LOAD_ADDR	0x81e00000UL
#define XR1710G_RECOVERY_CHAINLOADER_FIT_BASE	0x81800000UL
#define XR1710G_RECOVERY_FDT_MAGIC		0xd00dfeedU

static void xr1710g_recovery_validation_step(
	struct xr1710g_recovery_validation_result *result,
	const char *detail, const char *component)
{
	if (!result)
		return;

	result->detail = detail ? detail : "unknown";
	result->component = component ? component : "none";
}

void xr1710g_recovery_validation_result_init(
	struct xr1710g_recovery_validation_result *result)
{
	if (!result)
		return;

	result->detail = "none";
	result->component = "none";
}

static uint32_t xr1710g_recovery_be32_to_cpu(const void *p)
{
	const uint8_t *b = p;

	return ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) |
	       ((uint32_t)b[2] << 8) | b[3];
}

int xr1710g_recovery_fdt_get_single_string(
	const void *fdt, int node, const char *property, const char **value,
	struct xr1710g_recovery_validation_result *result)
{
	const char *str;
	int len;

	str = fdt_getprop(fdt, node, property, &len);
	if (!str || len < 2 || str[len - 1] != '\0' ||
	    strnlen(str, len) != len - 1) {
		xr1710g_recovery_validation_step(result, "fit-string", property);
		printf("FIT property '%s' is missing or ambiguous\n", property);
		return -EINVAL;
	}

	*value = str;
	return 0;
}

int xr1710g_recovery_fdt_find_exact_subnode(const void *fdt, int parent,
					    const char *name)
{
	int found = -ENOENT;
	int node;

	fdt_for_each_subnode(node, fdt, parent) {
		const char *node_name = fdt_get_name(fdt, node, NULL);

		if (!node_name || strcmp(node_name, name))
			continue;
		if (found >= 0) {
			printf("FIT contains duplicate node '%s'\n", name);
			return -EEXIST;
		}
		found = node;
	}

	return found;
}

static int xr1710g_recovery_fit_verify_hashes(
	const void *fit, int image_node, const char *component_name,
	const void *data, size_t data_size,
	struct xr1710g_recovery_validation_result *result)
{
	uint32_t seen_algorithms = 0;
	int usable_hashes = 0;
	int hash_node;

	fdt_for_each_subnode(hash_node, fit, image_node) {
		const fdt32_t *ignore;
		const char *algo;
		const void *value;
		const char *node_name = fdt_get_name(fit, hash_node, NULL);
		struct hash_algo *hash_algo;
		uint32_t algorithm_bit;
		int algo_len;
		int ignore_len;
		int value_len;

		if (!node_name ||
		    (strcmp(node_name, FIT_HASH_NODENAME) &&
		     strncmp(node_name, "hash@", strlen("hash@")) &&
		     strncmp(node_name, "hash-", strlen("hash-")))) {
			xr1710g_recovery_validation_step(result, "component-child",
						     component_name);
			return -EBADMSG;
		}

		ignore = fdt_getprop(fit, hash_node, FIT_IGNORE_PROP,
				     &ignore_len);
		if (ignore) {
			if (ignore_len != sizeof(*ignore)) {
				xr1710g_recovery_validation_step(
					result, "hash-ignore-malformed",
					component_name);
				printf("FIT hash '%s/%s' has malformed ignore flag\n",
				       component_name, node_name);
				return -EBADMSG;
			}
			if (fdt32_to_cpu(*ignore)) {
				xr1710g_recovery_validation_step(
					result, "hash-ignored", component_name);
				return -EBADMSG;
			}
		}

		algo = fdt_getprop(fit, hash_node, FIT_ALGO_PROP, &algo_len);
		value = fdt_getprop(fit, hash_node, FIT_VALUE_PROP, &value_len);
		if (!algo || algo_len < 2 || algo[algo_len - 1] != '\0' ||
		    strnlen(algo, algo_len) != algo_len - 1 || !value ||
		    value_len <= 0 || value_len > FIT_MAX_HASH_LEN) {
			xr1710g_recovery_validation_step(result, "hash-descriptor",
						     component_name);
			printf("FIT hash '%s/%s' is incomplete\n",
			       component_name, node_name);
			return -EBADMSG;
		}
		if (!strcmp(algo, "sha1"))
			algorithm_bit = 1U << 0;
		else if (!strcmp(algo, "sha256"))
			algorithm_bit = 1U << 1;
		else {
			/* Stock OpenWrt images ship crc32 nodes alongside sha1.
			 * They are too weak to gate on, so skip instead of
			 * rejecting the whole image; strong nodes below decide. */
			printf("FIT hash '%s/%s': weak algo '%s' skipped\n",
			       component_name, node_name, algo);
			continue;
		}
		if (seen_algorithms & algorithm_bit) {
			xr1710g_recovery_validation_step(result, "hash-duplicate",
						     component_name);
			return -EEXIST;
		}
		if (hash_lookup_algo(algo, &hash_algo) ||
		    hash_algo->digest_size != value_len) {
			xr1710g_recovery_validation_step(result, "hash-length",
						     component_name);
			return -EBADMSG;
		}
		seen_algorithms |= algorithm_bit;
		usable_hashes++;
	}

	if (!usable_hashes || !data || !data_size) {
		xr1710g_recovery_validation_step(result, "hash-required",
						     component_name);
		printf("FIT component '%s' has no valid, enforced hash\n",
		       component_name);
		return -EBADMSG;
	}

	/* Whole-payload recompute: every strong hash node in the FIT is
	 * recalculated over the received bytes and compared. A truncated
	 * or corrupted upload cannot pass. */
	fdt_for_each_subnode(hash_node, fit, image_node) {
		const char *algo;
		const void *value;
		const char *node_name = fdt_get_name(fit, hash_node, NULL);
		uint8_t calc[32];
		int algo_len;
		int value_len;
		int calc_len = sizeof(calc);

		algo = fdt_getprop(fit, hash_node, FIT_ALGO_PROP, &algo_len);
		value = fdt_getprop(fit, hash_node, FIT_VALUE_PROP, &value_len);
		if (!algo || !value || value_len <= 0 ||
		    value_len > (int)sizeof(calc))
			continue;
		if (strcmp(algo, "sha1") && strcmp(algo, "sha256"))
			continue;
		if (hash_block(algo, data, data_size, calc, &calc_len) ||
		    calc_len != value_len ||
		    memcmp(calc, value, value_len)) {
			xr1710g_recovery_validation_step(result, "hash-verify",
						     component_name);
			printf("FIT component '%s' failed '%s' verification (%s)\n",
			       component_name, algo,
			       node_name ? node_name : "hash");
			return -EBADMSG;
		}
	}

	xr1710g_recovery_validation_step(result, "hash-ok", component_name);
	return 0;
}

int xr1710g_recovery_fit_get_component(
	const void *fit, size_t image_size, int images_node, const char *name,
	uint8_t expected_type, bool check_os,
	struct xr1710g_recovery_fit_component *component,
	struct xr1710g_recovery_validation_result *result)
{
	uintptr_t image_addr = (uintptr_t)fit;
	uintptr_t data_addr;
	uint8_t value;
	int ret;

	if (!fit || !name || !component) {
		xr1710g_recovery_validation_step(result, "argument", "fit");
		return -EINVAL;
	}

	memset(component, 0, sizeof(*component));
	component->node = xr1710g_recovery_fdt_find_exact_subnode(
		fit, images_node, name);
	if (component->node < 0) {
		xr1710g_recovery_validation_step(result, "component-node", name);
		printf("FIT component '%s' is missing\n", name);
		return component->node;
	}

	ret = fit_image_get_type(fit, component->node, &value);
	if (ret || value != expected_type) {
		xr1710g_recovery_validation_step(result, "component-type", name);
		printf("FIT component '%s' has the wrong type\n", name);
		return -EINVAL;
	}

	/* OpenWrt filesystem image nodes intentionally omit an arch property. */
	if (expected_type != IH_TYPE_FILESYSTEM) {
		ret = fit_image_get_arch(fit, component->node, &value);
		if (ret || value != IH_ARCH_ARM64) {
			xr1710g_recovery_validation_step(result, "component-arch",
						     name);
			printf("FIT component '%s' is not ARM64\n", name);
			return -EINVAL;
		}
	}

	if (check_os) {
		ret = fit_image_get_os(fit, component->node, &value);
		if (ret || value != IH_OS_LINUX) {
			xr1710g_recovery_validation_step(result, "component-os",
						     name);
			printf("FIT component '%s' is not a Linux image\n", name);
			return -EINVAL;
		}
	}

	ret = fit_image_get_data(fit, component->node, &component->data,
				 &component->size);
	if (ret || !component->data || !component->size) {
		xr1710g_recovery_validation_step(result, "component-payload",
						     name);
		printf("FIT component '%s' has no payload\n", name);
		return ret ? ret : -EINVAL;
	}

	data_addr = (uintptr_t)component->data;
	if (data_addr < image_addr || data_addr - image_addr > image_size) {
		xr1710g_recovery_validation_step(result, "component-bounds", name);
		printf("FIT component '%s' starts outside the upload\n", name);
		return -EFBIG;
	}

	component->offset = data_addr - image_addr;
	if (component->size > image_size - component->offset) {
		xr1710g_recovery_validation_step(result, "component-bounds", name);
		printf("FIT component '%s' extends beyond the upload\n", name);
		return -EFBIG;
	}

	return xr1710g_recovery_fit_verify_hashes(
		fit, component->node, name, component->data, component->size,
		result);
}

bool xr1710g_recovery_fit_components_overlap(
	const struct xr1710g_recovery_fit_component *a,
	const struct xr1710g_recovery_fit_component *b)
{
	return a->offset < b->offset + b->size &&
	       b->offset < a->offset + a->size;
}

static int xr1710g_recovery_fit_require_load_entry(
	const void *fit, int node, ulong expected_load, ulong expected_entry,
	const char *name, struct xr1710g_recovery_validation_result *result)
{
	ulong load;
	ulong entry;

	if (fit_image_get_load(fit, node, &load) ||
	    fit_image_get_entry(fit, node, &entry) ||
	    load != expected_load || entry != expected_entry) {
		xr1710g_recovery_validation_step(result, "component-load-entry",
						     name);
		printf("FIT component '%s' has invalid load/entry addresses\n",
		       name);
		return -EINVAL;
	}

	return 0;
}

static int xr1710g_recovery_fdt_require_u32(
	const void *fdt, int node, const char *property, uint32_t expected,
	struct xr1710g_recovery_validation_result *result)
{
	const fdt32_t *value;
	int len;

	value = fdt_getprop(fdt, node, property, &len);
	if (!value || len != sizeof(*value) ||
	    fdt32_to_cpu(*value) != expected) {
		xr1710g_recovery_validation_step(result, "control-dtb-u32",
						     property);
		printf("Control DT property '%s' is missing or invalid\n",
		       property);
		return -EINVAL;
	}

	return 0;
}

static int xr1710g_validate_chainloader_control_dtb_aligned(
	const void *fdt, size_t size,
	struct xr1710g_recovery_validation_result *result)
{
	const char *payload_node;
	uint32_t total_size;
	int ret;

	if (!fdt || size < sizeof(struct fdt_header) || fdt_check_header(fdt)) {
		xr1710g_recovery_validation_step(result, "control-dtb-header",
						     "fdt@1");
		return -EBADMSG;
	}

	total_size = fdt_totalsize(fdt);
	if (total_size != size || fdt_check_full(fdt, total_size)) {
		xr1710g_recovery_validation_step(result, "control-dtb-size",
						     "fdt@1");
		printf("Chainloader control DT is truncated or has trailing data\n");
		return -EBADMSG;
	}

	if (fdt_stringlist_search(fdt, 0, "compatible",
				  "airoha,xr1710g-chainloader-control") < 0) {
		xr1710g_recovery_validation_step(result,
						     "control-dtb-compatible",
						     "fdt@1");
		printf("Chainloader control DT is not for XR1710G\n");
		return -ENODEV;
	}

	ret = xr1710g_recovery_fdt_get_single_string(
		fdt, 0, "payload-node", &payload_node, result);
	if (ret || strcmp(payload_node, "uboot@1")) {
		xr1710g_recovery_validation_step(result, "control-dtb-payload",
						     "fdt@1");
		printf("Chainloader control DT has an invalid payload node\n");
		return ret ? ret : -EINVAL;
	}

	ret = xr1710g_recovery_fdt_require_u32(
		fdt, 0, "fit-base", XR1710G_RECOVERY_CHAINLOADER_FIT_BASE,
		result);
	if (ret)
		return ret;
	ret = xr1710g_recovery_fdt_require_u32(
		fdt, 0, "fallback-payload-load",
		XR1710G_RECOVERY_UBOOT_LOAD_ADDR, result);
	if (ret)
		return ret;

	return xr1710g_recovery_fdt_require_u32(
		fdt, 0, "fallback-payload-entry",
		XR1710G_RECOVERY_UBOOT_LOAD_ADDR, result);
}

static int xr1710g_validate_chainloader_control_dtb(
	const void *fdt, size_t size,
	struct xr1710g_recovery_validation_result *result)
{
	void *aligned_fdt;
	int ret;

	if (!fdt || size < sizeof(struct fdt_header)) {
		xr1710g_recovery_validation_step(result, "control-dtb-header",
						     "fdt@1");
		return -EBADMSG;
	}

	/*
	 * An embedded FIT data property is only 4-byte aligned, while libfdt
	 * requires its input address to be 8-byte aligned. Validate an exact
	 * aligned copy so alignment cannot make a valid hashed control DT fail.
	 */
	aligned_fdt = memalign(8, size);
	if (!aligned_fdt) {
		xr1710g_recovery_validation_step(result, "control-dtb-memory",
						     "fdt@1");
		return -ENOMEM;
	}
	memcpy(aligned_fdt, fdt, size);

	ret = xr1710g_validate_chainloader_control_dtb_aligned(
		aligned_fdt, size, result);
	free(aligned_fdt);

	return ret;
}

int xr1710g_validate_uboot_slot_image(
	const void *image, size_t size,
	struct xr1710g_recovery_validation_result *result)
{
	const struct legacy_img_hdr *prefix = image;
	const uint8_t *bytes = image;
	const void *fit;
	struct xr1710g_recovery_fit_component fdt;
	struct xr1710g_recovery_fit_component kernel;
	struct xr1710g_recovery_fit_component uboot;
	const char *config_name;
	const char *kernel_name;
	const char *fdt_name;
	const char *loadable_name;
	size_t prefix_header_size;
	size_t prefix_size;
	size_t fit_available;
	uint32_t prefix_data_size;
	uint32_t fit_size;
	uint8_t comp;
	int images_node;
	int configs_node;
	int config_node;
	int image_count = 0;
	int config_count = 0;
	int node;
	int ret;

	xr1710g_recovery_validation_result_init(result);
	xr1710g_recovery_validation_step(result, "legacy-size", "prefix");
	if (!image || size <= XR1710G_RECOVERY_UBOOT_SLOT_FIT_OFFSET +
				   sizeof(struct fdt_header)) {
		printf("U-Boot slot image is too small: %lu bytes\n",
		       (unsigned long)size);
		return -EINVAL;
	}

	xr1710g_recovery_validation_step(result, "legacy-magic", "prefix");
	if (!image_check_magic(prefix)) {
		printf("U-Boot slot legacy prefix magic is invalid\n");
		return -ENOEXEC;
	}

	prefix_header_size = image_get_header_size();
	prefix_data_size = image_get_size(prefix);
	xr1710g_recovery_validation_step(result, "legacy-length", "prefix");
	if (prefix_header_size > XR1710G_RECOVERY_UBOOT_SLOT_FIT_OFFSET ||
	    prefix_data_size > XR1710G_RECOVERY_UBOOT_SLOT_FIT_OFFSET -
			       prefix_header_size) {
		printf("U-Boot slot legacy prefix length is invalid\n");
		return -EFBIG;
	}
	prefix_size = prefix_header_size + prefix_data_size;

	xr1710g_recovery_validation_step(result, "legacy-metadata", "prefix");
	if (image_get_arch(prefix) != IH_ARCH_ARM64 ||
	    image_get_os(prefix) != IH_OS_LINUX ||
	    image_get_type(prefix) != IH_TYPE_KERNEL ||
	    image_get_comp(prefix) != IH_COMP_LZMA ||
	    image_get_load(prefix) != XR1710G_RECOVERY_PREFIX_LOAD_ADDR ||
	    image_get_ep(prefix) != XR1710G_RECOVERY_PREFIX_LOAD_ADDR ||
	    strncmp(image_get_name(prefix), "XR1710G chainloader prefix shim",
		    IH_NMLEN)) {
		printf("U-Boot slot legacy prefix metadata is not XR1710G-compatible\n");
		return -EINVAL;
	}

	xr1710g_recovery_validation_step(result, "legacy-crc", "prefix");
	if (!image_check_hcrc(prefix) || !image_check_dcrc(prefix)) {
		printf("U-Boot slot legacy prefix CRC verification failed\n");
		return -EBADMSG;
	}

	xr1710g_recovery_validation_step(result, "legacy-padding", "prefix");
	for (size_t i = prefix_size;
	     i < XR1710G_RECOVERY_UBOOT_SLOT_FIT_OFFSET; i++) {
		if (bytes[i] != 0x00) {
			printf("U-Boot slot prefix padding is not zero at 0x%lx\n",
			       (unsigned long)i);
			return -EBADMSG;
		}
	}

	fit = bytes + XR1710G_RECOVERY_UBOOT_SLOT_FIT_OFFSET;
	fit_available = size - XR1710G_RECOVERY_UBOOT_SLOT_FIT_OFFSET;
	xr1710g_recovery_validation_step(result, "fit-header", "fit");
	if (xr1710g_recovery_be32_to_cpu(fit) !=
			XR1710G_RECOVERY_FDT_MAGIC || fdt_check_header(fit)) {
		printf("U-Boot slot Chainloader FIT header is invalid\n");
		return -ENOEXEC;
	}

	fit_size = fdt_totalsize(fit);
	xr1710g_recovery_validation_step(result, "fit-size", "fit");
	if (fit_size != fit_available || fdt_check_full(fit, fit_size)) {
		printf("U-Boot slot Chainloader FIT is truncated or has trailing data\n");
		return -EBADMSG;
	}

	xr1710g_recovery_validation_step(result, "fit-format", "fit");
	ret = fit_check_format(fit, fit_size);
	if (ret) {
		printf("U-Boot slot Chainloader FIT structure check failed: %d\n",
		       ret);
		return ret;
	}

	images_node = fdt_path_offset(fit, FIT_IMAGES_PATH);
	configs_node = fdt_path_offset(fit, FIT_CONFS_PATH);
	xr1710g_recovery_validation_step(result, "fit-topology", "fit");
	if (images_node < 0 || configs_node < 0)
		return -ENOENT;

	fdt_for_each_subnode(node, fit, images_node)
		image_count++;
	fdt_for_each_subnode(node, fit, configs_node)
		config_count++;
	if (image_count != 3 || config_count != 1) {
		printf("U-Boot slot FIT requires exactly 3 images and 1 configuration\n");
		return -EINVAL;
	}

	xr1710g_recovery_validation_step(result, "fit-default-config",
					 "conf@1");
	ret = xr1710g_recovery_fdt_get_single_string(
		fit, configs_node, FIT_DEFAULT_PROP, &config_name, result);
	if (ret || strcmp(config_name, "conf@1"))
		return ret ? ret : -EINVAL;
	config_node = xr1710g_recovery_fdt_find_exact_subnode(
		fit, configs_node, config_name);
	if (config_node < 0)
		return config_node;

	xr1710g_recovery_validation_step(result, "fit-config-references",
					 "conf@1");
	ret = xr1710g_recovery_fdt_get_single_string(
		fit, config_node, FIT_KERNEL_PROP, &kernel_name, result);
	if (ret)
		return ret;
	ret = xr1710g_recovery_fdt_get_single_string(
		fit, config_node, FIT_FDT_PROP, &fdt_name, result);
	if (ret)
		return ret;
	ret = xr1710g_recovery_fdt_get_single_string(
		fit, config_node, FIT_LOADABLE_PROP, &loadable_name, result);
	if (ret)
		return ret;
	if (fdt_getprop(fit, config_node, FIT_RAMDISK_PROP, NULL) ||
	    fdt_getprop(fit, config_node, FIT_FIRMWARE_PROP, NULL)) {
		printf("U-Boot slot FIT configuration contains ambiguous references\n");
		return -EINVAL;
	}
	if (strcmp(kernel_name, "kernel@1") || strcmp(fdt_name, "fdt@1") ||
	    strcmp(loadable_name, "uboot@1")) {
		printf("U-Boot slot FIT configuration references are invalid\n");
		return -EINVAL;
	}

	xr1710g_recovery_validation_step(result, "component", kernel_name);
	ret = xr1710g_recovery_fit_get_component(
		fit, fit_size, images_node, kernel_name, IH_TYPE_KERNEL, true,
		&kernel, result);
	if (ret)
		return ret;
	xr1710g_recovery_validation_step(result, "component", fdt_name);
	ret = xr1710g_recovery_fit_get_component(
		fit, fit_size, images_node, fdt_name, IH_TYPE_FLATDT, false,
		&fdt, result);
	if (ret)
		return ret;
	xr1710g_recovery_validation_step(result, "component", loadable_name);
	ret = xr1710g_recovery_fit_get_component(
		fit, fit_size, images_node, loadable_name, IH_TYPE_FIRMWARE,
		false, &uboot, result);
	if (ret)
		return ret;

	if (xr1710g_recovery_fit_components_overlap(&kernel, &fdt) ||
	    xr1710g_recovery_fit_components_overlap(&kernel, &uboot) ||
	    xr1710g_recovery_fit_components_overlap(&fdt, &uboot)) {
		xr1710g_recovery_validation_step(result, "component-overlap",
						     "fit");
		printf("U-Boot slot FIT component payloads overlap\n");
		return -EINVAL;
	}

	if (fit_image_get_comp(fit, kernel.node, &comp) ||
	    comp != IH_COMP_NONE ||
	    fit_image_get_comp(fit, fdt.node, &comp) || comp != IH_COMP_NONE ||
	    fit_image_get_comp(fit, uboot.node, &comp) ||
	    comp != IH_COMP_NONE) {
		xr1710g_recovery_validation_step(result, "component-compression",
						     "fit");
		printf("U-Boot slot FIT components must be uncompressed\n");
		return -EINVAL;
	}

	ret = xr1710g_recovery_fit_require_load_entry(
		fit, kernel.node, XR1710G_RECOVERY_PREFIX_LOAD_ADDR,
		XR1710G_RECOVERY_PREFIX_LOAD_ADDR, kernel_name, result);
	if (ret)
		return ret;
	ret = xr1710g_recovery_fit_require_load_entry(
		fit, uboot.node, XR1710G_RECOVERY_UBOOT_LOAD_ADDR,
		XR1710G_RECOVERY_UBOOT_LOAD_ADDR, loadable_name, result);
	if (ret)
		return ret;

	ret = xr1710g_validate_chainloader_control_dtb(fdt.data, fdt.size,
						       result);
	if (ret)
		return ret;

	xr1710g_recovery_validation_step(result, "ok", "uboot-slot");
	printf("Validated complete XR1710G flash-slot wrapper and component hashes\n");
	return 0;
}
