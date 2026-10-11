/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __XR1710G_RECOVERY_VALIDATOR_H
#define __XR1710G_RECOVERY_VALIDATOR_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <linux/types.h>

#define XR1710G_RECOVERY_UBOOT_SLOT_FIT_OFFSET	0x2100U

struct xr1710g_recovery_validation_result {
	const char *detail;
	const char *component;
};

struct xr1710g_recovery_fit_component {
	int node;
	const void *data;
	size_t size;
	size_t offset;
};

void xr1710g_recovery_validation_result_init(
	struct xr1710g_recovery_validation_result *result);

int xr1710g_recovery_fdt_get_single_string(
	const void *fdt, int node, const char *property, const char **value,
	struct xr1710g_recovery_validation_result *result);

int xr1710g_recovery_fdt_find_exact_subnode(const void *fdt, int parent,
					    const char *name);

int xr1710g_recovery_fit_get_component(
	const void *fit, size_t image_size, int images_node, const char *name,
	uint8_t expected_type, bool check_os,
	struct xr1710g_recovery_fit_component *component,
	struct xr1710g_recovery_validation_result *result);

bool xr1710g_recovery_fit_components_overlap(
	const struct xr1710g_recovery_fit_component *a,
	const struct xr1710g_recovery_fit_component *b);

int xr1710g_validate_uboot_slot_image(
	const void *image, size_t size,
	struct xr1710g_recovery_validation_result *result);

#endif /* __XR1710G_RECOVERY_VALIDATOR_H */
