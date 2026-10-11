// SPDX-License-Identifier: GPL-2.0
/*
 * Author: Christian Marangi <ansuelsmth@gmail.com>
 */

#include <asm/gpio.h>
#include <asm/global_data.h>
#include <asm/io.h>
#include <dt-bindings/gpio/gpio.h>
#include <dm/device.h>
#include <dm/ofnode.h>
#include <env.h>
#include <fdt_support.h>
#include <mtd.h>
#include <net-common.h>
#include <ubi_uboot.h>
#include <linux/bitops.h>
#include <linux/delay.h>
#include <linux/err.h>
#include <linux/kconfig.h>
#include <linux/string.h>
#include <xr1710g-recovery-factory-gate.h>
#include <xr1710g-wiro-build.h>
#include <xr1710g-wiro-env-safety.h>

DECLARE_GLOBAL_DATA_PTR;

#define XR1710G_CHIP_SCU_BASE		0x1fa20000
#define XR1710G_GPIO_SYSCTL_BASE	0x1fbf0200

#define XR1710G_REG_GPIO_CTRL		0x0000
#define XR1710G_REG_GPIO_DATA		0x0004
#define XR1710G_REG_GPIO_OE		0x0014
#define XR1710G_REG_GPIO_CTRL1		0x0020
#define XR1710G_REG_GPIO_FLASH_MODE_CFG	0x0034
#define XR1710G_REG_GPIO_CTRL2		0x0060
#define XR1710G_REG_GPIO_CTRL3		0x0064
#define XR1710G_REG_GPIO_DATA1		0x0070
#define XR1710G_REG_GPIO_OE1		0x0078

#define XR1710G_VENDOR_PART		"vendor"
#define XR1710G_UBI_PART		"ubi"
#define XR1710G_FACTORY_VOL		"factory"
#define XR1710G_DSD_OFFSET		0x400000
#define XR1710G_DSD_ENV_SIZE		0x1000
#define XR1710G_DSD_EEPROM_OFFSET	(XR1710G_DSD_OFFSET + 0x5000)
#define XR1710G_EEPROM_SIZE		0x1e00
#define XR1710G_FACTORY_EEPROM_OFFSET	0x0000
#define XR1710G_FACTORY_WAN_MAC_OFFSET	0x5000
#define XR1710G_FACTORY_LAN_MAC_OFFSET	0x6000
#define XR1710G_FACTORY_SIZE		(XR1710G_FACTORY_LAN_MAC_OFFSET + ARP_HLEN)

struct xr1710g_ubi_layout {
	const char *version;
	const char *part;
};

static const struct xr1710g_ubi_layout xr1710g_ubi_layouts[] = {
	{ "2.0", XR1710G_UBI_PART },
	{ "1.5", "ubi1.5" },
	{ "1.0", "ubi1.0" },
};

static const struct xr1710g_ubi_layout *xr1710g_active_ubi_layout =
	&xr1710g_ubi_layouts[0];
static bool xr1710g_ubi_layout_probed;
static bool xr1710g_ubi_layout_available;
static bool xr1710g_recovery_requested;

static const char *const xr1710g_fdt_lan_mac_paths[] = {
	"/soc/ethernet@1fb50000/ethernet@1",
};

static const char *const xr1710g_fdt_10g_lan_mac_paths[] = {
	"/soc/ethernet@1fb50000/ethernet@4",
};

static const char *const xr1710g_fdt_wan_mac_paths[] = {
	"/soc/ethernet@1fb50000/ethernet@2",
};

static bool xr1710g_is_compatible(void)
{
	return of_machine_is_compatible("econet,xr1710g") ||
	       of_machine_is_compatible("econet,xr1710g-ubi") ||
	       of_machine_is_compatible("gemtek,xr1710g") ||
	       of_machine_is_compatible("gemtek,xr1710g-ubi");
}

const struct xr1710g_wiro_env_requirements *env_ubi_required_markers(void)
{
	static const struct xr1710g_wiro_env_requirements requirements = {
		.magic = XR1710G_WIRO_ENV_MAGIC,
		.schema = XR1710G_WIRO_ENV_SCHEMA,
		.generation = XR1710G_WIRO_ENV_GENERATION,
	};

	return xr1710g_is_compatible() ? &requirements : NULL;
}

static void xr1710g_clrsetbits_le32(uintptr_t addr, u32 clear, u32 set)
{
	u32 val = readl((void __iomem *)addr);

	val &= ~clear;
	val |= set;
	writel(val, (void __iomem *)addr);
}

static uintptr_t xr1710g_gpio_data_reg(u32 gpio)
{
	return XR1710G_GPIO_SYSCTL_BASE +
	       (gpio < 32 ? XR1710G_REG_GPIO_DATA : XR1710G_REG_GPIO_DATA1);
}

static uintptr_t xr1710g_gpio_oe_reg(u32 gpio)
{
	return XR1710G_GPIO_SYSCTL_BASE +
	       (gpio < 32 ? XR1710G_REG_GPIO_OE : XR1710G_REG_GPIO_OE1);
}

static uintptr_t xr1710g_gpio_dir_reg(u32 gpio)
{
	static const u16 dir_regs[] = {
		XR1710G_REG_GPIO_CTRL,
		XR1710G_REG_GPIO_CTRL1,
		XR1710G_REG_GPIO_CTRL2,
		XR1710G_REG_GPIO_CTRL3,
	};

	return XR1710G_GPIO_SYSCTL_BASE + dir_regs[gpio / 16];
}

static void xr1710g_gpio_direction_input(u32 gpio)
{
	u32 bank_bit = BIT(gpio % 32);
	u32 dir_bit = BIT(2 * (gpio % 16));

	xr1710g_clrsetbits_le32(xr1710g_gpio_oe_reg(gpio), bank_bit, 0);
	xr1710g_clrsetbits_le32(xr1710g_gpio_dir_reg(gpio), dir_bit, 0);
}

static void xr1710g_gpio_prepare_input(u32 gpio)
{
	/*
	 * GPIO0..GPIO15 share the flash/PWM mux register. Clear the bit to
	 * force the pin back to GPIO before sampling the button.
	 */
	if (gpio < 16)
		xr1710g_clrsetbits_le32(XR1710G_CHIP_SCU_BASE +
					XR1710G_REG_GPIO_FLASH_MODE_CFG,
					BIT(gpio), 0);

	xr1710g_gpio_direction_input(gpio);
}

static int xr1710g_recovery_button_pressed_raw(ofnode root)
{
	struct ofnode_phandle_args args;
	u32 gpio, gpio_flags = 0, val;
	int ret;

	ret = ofnode_parse_phandle_with_args(root, "recovery-gpios",
					     "#gpio-cells", 0, 0, &args);
	if (ret || args.args_count < 1)
		return 0;

	gpio = args.args[0];
	if (args.args_count > 1)
		gpio_flags = args.args[1];

	xr1710g_gpio_prepare_input(gpio);

	val = readl((void __iomem *)xr1710g_gpio_data_reg(gpio));
	ret = !!(val & BIT(gpio % 32));

	return gpio_flags & GPIO_ACTIVE_LOW ? !ret : ret;
}

static bool xr1710g_recovery_button_pressed_stable(ofnode root)
{
	int pressed = 0;
	int i;

	/* Reject a transient sample without delaying normal boot materially. */
	for (i = 0; i < 5; i++) {
		pressed += xr1710g_recovery_button_pressed_raw(root) > 0;
		if (i != 4)
			udelay(2000);
	}

	return pressed >= 4;
}

static int xr1710g_read_vendor_data(size_t offset, size_t size, void *buf)
{
	struct mtd_info *mtd;
	size_t retlen = 0;
	int ret;

	mtd_probe_devices();
	mtd = get_mtd_device_nm(XR1710G_VENDOR_PART);
	if (IS_ERR_OR_NULL(mtd))
		return IS_ERR(mtd) ? PTR_ERR(mtd) : -ENODEV;

	ret = mtd_read(mtd, offset, size, &retlen, buf);
	put_mtd_device(mtd);
	if (ret)
		return ret;
	if (retlen != size)
		return -EIO;

	return 0;
}

static int xr1710g_read_dsd_eeprom(u8 *buf)
{
	int ret;

	ret = xr1710g_read_vendor_data(XR1710G_DSD_EEPROM_OFFSET,
				       XR1710G_EEPROM_SIZE, buf);
	if (ret)
		return ret;

	/*
	 * Stock calibration blobs start with the MT7990 chip ID. Refuse to
	 * overwrite the target volume when the DSD payload does not look sane.
	 */
	if (buf[0] != 0x90 || buf[1] != 0x79)
		return -EINVAL;

	return 0;
}

static int xr1710g_dsd_get_var(const char *buf, size_t len, const char *key,
				 char *value, size_t value_len)
{
	size_t key_len = strlen(key);
	const char *cur = buf;
	const char *end;
	const char *match = NULL;
	size_t match_len = 0;
	size_t text_len = 0;
	int matches = 0;

	if (!buf || !key || !*key || !value || !value_len || !len)
		return -EINVAL;

	while (text_len < len && (u8)buf[text_len] != 0x00 &&
	       (u8)buf[text_len] != 0xff) {
		u8 c = buf[text_len];

		if ((c < 0x20 && c != '\n' && c != '\r' && c != '\t') ||
		    (c == '\r' && (text_len + 1 >= len ||
		     buf[text_len + 1] != '\n')))
			return -EBADMSG;
		text_len++;
	}
	if (text_len == len && buf[len - 1] != '\n')
		return -EBADMSG;
	for (size_t i = text_len; i < len; i++) {
		if ((u8)buf[i] != 0x00 && (u8)buf[i] != 0xff)
			return -EBADMSG;
	}
	end = buf + text_len;

	while (cur < end) {
		const char *line_end = memchr(cur, '\n', end - cur);
		size_t line_len;

		if (!line_end)
			line_end = end;

		line_len = line_end - cur;
		if (line_len && cur[line_len - 1] == '\r')
			line_len--;
		if (line_len > key_len && !memcmp(cur, key, key_len)) {
			matches++;
			match = cur + key_len;
			match_len = line_len - key_len;
		}

		if (line_end == end)
			break;
		cur = line_end + 1;
	}

	if (!matches)
		return -ENOENT;
	if (matches != 1)
		return -EEXIST;
	if (!match_len)
		return -EINVAL;
	if (match_len >= value_len)
		return -ENOSPC;

	memcpy(value, match, match_len);
	value[match_len] = '\0';
	return 0;
}

static int xr1710g_mac_hex_nibble(char ch)
{
	if (ch >= '0' && ch <= '9')
		return ch - '0';
	if (ch >= 'a' && ch <= 'f')
		return ch - 'a' + 10;
	if (ch >= 'A' && ch <= 'F')
		return ch - 'A' + 10;

	return -EINVAL;
}

static int xr1710g_parse_canonical_mac(const char *text, u8 *mac)
{
	size_t i;

	if (!text || !mac || strlen(text) != ARP_HLEN_ASCII)
		return -EINVAL;

	for (i = 0; i < ARP_HLEN; i++) {
		size_t pos = i * 3;
		int hi = xr1710g_mac_hex_nibble(text[pos]);
		int lo = xr1710g_mac_hex_nibble(text[pos + 1]);

		if (hi < 0 || lo < 0 ||
		    (i + 1 < ARP_HLEN && text[pos + 2] != ':'))
			return -EINVAL;

		mac[i] = (hi << 4) | lo;
	}

	return is_valid_ethaddr(mac) ? 0 : -EINVAL;
}

static int xr1710g_mac_add_checked(const u8 *base, u8 delta, u8 *mac)
{
	unsigned int carry = delta;
	int i;

	memcpy(mac, base, ARP_HLEN);
	for (i = ARP_HLEN - 1; i >= 0 && carry; i--) {
		carry += mac[i];
		mac[i] = carry & 0xff;
		carry >>= 8;
	}

	if (carry || !is_valid_ethaddr(mac))
		return -ERANGE;

	return 0;
}

static int xr1710g_validate_mac_plan(const u8 *lan_mac, const u8 *wan_mac,
				     u8 *lan_10g_mac)
{
	u8 derived[4][ARP_HLEN];
	int i, j, ret;

	if (!is_valid_ethaddr(lan_mac) || !is_valid_ethaddr(wan_mac) ||
	    !memcmp(lan_mac, wan_mac, ARP_HLEN))
		return -EINVAL;

	for (i = 0; i < ARRAY_SIZE(derived); i++) {
		ret = xr1710g_mac_add_checked(lan_mac, i + 1, derived[i]);
		if (ret)
			return ret;
		if (!memcmp(derived[i], wan_mac, ARP_HLEN))
			return -EADDRINUSE;
		for (j = 0; j < i; j++) {
			if (!memcmp(derived[i], derived[j], ARP_HLEN))
				return -EADDRINUSE;
		}
	}

	memcpy(lan_10g_mac, derived[3], ARP_HLEN);
	return 0;
}

static int xr1710g_get_dsd_ethaddrs(u8 *lan_mac, u8 *wan_mac)
{
	u8 lan_10g_mac[ARP_HLEN];
	char *buf;
	char lan_str[ARP_HLEN_ASCII + 1];
	char wan_str[ARP_HLEN_ASCII + 1];
	int ret;

	buf = malloc(XR1710G_DSD_ENV_SIZE + 1);
	if (!buf)
		return -ENOMEM;

	ret = xr1710g_read_vendor_data(XR1710G_DSD_OFFSET, XR1710G_DSD_ENV_SIZE,
				       buf);
	if (ret)
		goto out;

	buf[XR1710G_DSD_ENV_SIZE] = '\0';

	ret = xr1710g_dsd_get_var(buf, XR1710G_DSD_ENV_SIZE, "lan_mac=",
				  lan_str, sizeof(lan_str));
	if (ret)
		goto out;

	ret = xr1710g_dsd_get_var(buf, XR1710G_DSD_ENV_SIZE, "wan_mac=",
				  wan_str, sizeof(wan_str));
	if (ret)
		goto out;

	ret = xr1710g_parse_canonical_mac(lan_str, lan_mac);
	if (ret)
		goto out;
	ret = xr1710g_parse_canonical_mac(wan_str, wan_mac);
	if (ret)
		goto out;
	ret = xr1710g_validate_mac_plan(lan_mac, wan_mac, lan_10g_mac);
	if (ret)
		goto out;

out:
	free(buf);
	return ret;
}

static int xr1710g_create_ubi_volume(const char *name, size_t size)
{
	struct ubi_mkvol_req req;
	struct ubi_device *ubi;
	int ret;

	if (!name || !*name)
		return -EINVAL;

	ubi = ubi_get_device(0);
	if (!ubi)
		return -ENODEV;

	memset(&req, 0, sizeof(req));
	req.vol_id = UBI_VOL_NUM_AUTO;
	req.alignment = 1;
	req.bytes = size;
	req.vol_type = UBI_STATIC_VOLUME;
	req.name_len = strlen(name);
	if (req.name_len > UBI_VOL_NAME_MAX) {
		ubi_put_device(ubi);
		return -ENAMETOOLONG;
	}
	memcpy(req.name, name, req.name_len);
	req.name[req.name_len] = '\0';

	mutex_lock(&ubi->device_mutex);
	ret = ubi_create_volume(ubi, &req);
	mutex_unlock(&ubi->device_mutex);
	ubi_put_device(ubi);

	return ret;
}

static int xr1710g_resize_ubi_volume(const char *name, size_t size)
{
	struct ubi_volume_desc *desc;
	struct ubi_volume *vol;
	int ret, needed_pebs;

	if (!name || !*name)
		return -EINVAL;

	desc = ubi_open_volume_nm(0, name, UBI_EXCLUSIVE);
	if (IS_ERR_OR_NULL(desc))
		return IS_ERR(desc) ? PTR_ERR(desc) : -ENODEV;

	vol = desc->vol;
	needed_pebs = DIV_ROUND_UP(size, vol->usable_leb_size);

	mutex_lock(&vol->ubi->device_mutex);
	ret = ubi_resize_volume(desc, needed_pebs);
	mutex_unlock(&vol->ubi->device_mutex);
	ubi_close_volume(desc);

	return ret;
}

static int xr1710g_ensure_ubi_volume(const char *name, size_t size)
{
	struct ubi_volume_desc *desc;
	unsigned long long cur_size;
	int ret;

	if (!name || !*name)
		return -EINVAL;

	desc = ubi_open_volume_nm(0, name, UBI_READWRITE);
	if (IS_ERR_OR_NULL(desc)) {
		ret = xr1710g_create_ubi_volume(name, size);
		if (!ret)
			return 0;
		return ret;
	}

	cur_size = (unsigned long long)desc->vol->reserved_pebs *
		   (unsigned long long)desc->vol->usable_leb_size;
	ubi_close_volume(desc);

	if (size <= cur_size)
		return 0;

	return xr1710g_resize_ubi_volume(name, size);
}

static const struct xr1710g_ubi_layout *
xr1710g_find_ubi_layout(const char *part)
{
	int i;

	if (!part)
		return NULL;

	for (i = 0; i < ARRAY_SIZE(xr1710g_ubi_layouts); i++) {
		if (!strcmp(part, xr1710g_ubi_layouts[i].part))
			return &xr1710g_ubi_layouts[i];
	}

	return NULL;
}

static int xr1710g_select_ubi(const char *part)
{
	struct ubi_device *ubi;
	bool selected = false;

	if (!xr1710g_find_ubi_layout(part))
		return -EINVAL;

	ubi = ubi_get_device(0);
	if (ubi) {
		selected = ubi->mtd && !strcmp(ubi->mtd->name, part);
		ubi_put_device(ubi);
	}

	return selected ? 0 : ubi_part(part, NULL);
}

const char *xr1710g_detect_ubi_part(void)
{
	int i, ret;

	if (!xr1710g_is_compatible())
		return XR1710G_UBI_PART;

	if (xr1710g_ubi_layout_probed)
		return xr1710g_active_ubi_layout->part;

	xr1710g_ubi_layout_probed = true;
	for (i = 0; i < ARRAY_SIZE(xr1710g_ubi_layouts); i++) {
		ret = xr1710g_select_ubi(xr1710g_ubi_layouts[i].part);
		if (ret) {
			/* Only a size mismatch justifies probing a larger legacy view. */
			if (ret == -ENOMEM && i + 1 < ARRAY_SIZE(xr1710g_ubi_layouts))
				continue;
			break;
		}

		xr1710g_active_ubi_layout = &xr1710g_ubi_layouts[i];
		xr1710g_ubi_layout_available = true;
		printf("XR1710G: detected UBI %s on '%s'\n",
		       xr1710g_active_ubi_layout->version,
		       xr1710g_active_ubi_layout->part);
		break;
	}

	return xr1710g_active_ubi_layout->part;
}

const char *xr1710g_detect_ubi_version(void)
{
	xr1710g_detect_ubi_part();
	return xr1710g_ubi_layout_available ?
		xr1710g_active_ubi_layout->version : "unformatted";
}

const char *env_ubi_get_part(void)
{
	return xr1710g_detect_ubi_part();
}

int xr1710g_sync_factory_part(const char *part)
{
	u8 *src = NULL, *dst = NULL;
	u8 *wan_mac, *lan_mac;
	bool same = false;
	int ret = 0;

	if (!xr1710g_is_compatible())
		return 0;

	ret = xr1710g_select_ubi(part);
	if (ret) {
		printf("XR1710G: skipping factory sync; UBI is unavailable: %d\n",
		       ret);
		return ret;
	}

	src = malloc(XR1710G_FACTORY_SIZE);
	dst = malloc(XR1710G_FACTORY_SIZE);
	if (!src || !dst) {
		ret = -ENOMEM;
		goto out;
	}

	memset(src, 0xff, XR1710G_FACTORY_SIZE);
	wan_mac = src + XR1710G_FACTORY_WAN_MAC_OFFSET;
	lan_mac = src + XR1710G_FACTORY_LAN_MAC_OFFSET;

	ret = xr1710g_read_dsd_eeprom(src + XR1710G_FACTORY_EEPROM_OFFSET);
	if (ret) {
		printf("XR1710G: failed to read Wi-Fi EEPROM from DSD: %d\n",
		       ret);
		goto out;
	}

	ret = xr1710g_get_dsd_ethaddrs(lan_mac, wan_mac);
	if (ret) {
		printf("XR1710G: failed to read MAC addresses from DSD: %d\n",
		       ret);
		goto out;
	}

	ret = ubi_volume_read(XR1710G_FACTORY_VOL, (char *)dst, 0,
			      XR1710G_FACTORY_SIZE);
	if (!ret && !memcmp(src, dst, XR1710G_FACTORY_SIZE))
		same = true;

	if (same) {
		ret = 0;
		goto out;
	}

	ret = xr1710g_ensure_ubi_volume(XR1710G_FACTORY_VOL,
					XR1710G_FACTORY_SIZE);
	if (ret) {
		printf("XR1710G: failed to prepare UBI volume '%s': %d\n",
		       XR1710G_FACTORY_VOL, ret);
		goto out;
	}

	ret = ubi_volume_write(XR1710G_FACTORY_VOL, src, 0,
			       XR1710G_FACTORY_SIZE);
	if (ret) {
		printf("XR1710G: failed to update UBI volume '%s': %d\n",
		       XR1710G_FACTORY_VOL, ret);
		goto out;
	}

	printf("XR1710G: synchronized %u bytes of DSD factory data to '%s'\n",
	       XR1710G_FACTORY_SIZE, XR1710G_FACTORY_VOL);

out:
	free(src);
	free(dst);
	return ret;
}

int xr1710g_sync_factory(void)
{
	const char *part = xr1710g_detect_ubi_part();

	if (!xr1710g_ubi_layout_available)
		return -ENODEV;

	return xr1710g_sync_factory_part(part);
}

static int xr1710g_get_runtime_ethaddrs(u8 *lan_mac, u8 *wan_mac,
					u8 *lan_10g_mac)
{
	int ret;

	ret = xr1710g_get_dsd_ethaddrs(lan_mac, wan_mac);
	if (ret) {
		if (!eth_env_get_enetaddr("ethaddr", lan_mac) ||
		    !eth_env_get_enetaddr("eth1addr", wan_mac))
			return ret;
	}

	return xr1710g_validate_mac_plan(lan_mac, wan_mac, lan_10g_mac);
}

static void xr1710g_sync_runtime_ethaddrs(void)
{
	u8 lan_mac[ARP_HLEN], wan_mac[ARP_HLEN];
	u8 lan_10g_mac[ARP_HLEN];

	if (!xr1710g_is_compatible())
		return;

	if (xr1710g_get_runtime_ethaddrs(lan_mac, wan_mac, lan_10g_mac))
		return;

	eth_env_set_enetaddr("ethaddr", lan_mac);
	eth_env_set_enetaddr("eth1addr", wan_mac);
}

static int xr1710g_fdt_set_mac(void *blob, const char *path, const u8 *mac)
{
	int node, ret;

	node = fdt_path_offset(blob, path);
	if (node < 0)
		return node;

	ret = fdt_setprop(blob, node, "mac-address", mac, ARP_HLEN);
	if (ret)
		return ret;

	return fdt_setprop(blob, node, "local-mac-address", mac, ARP_HLEN);
}

static void xr1710g_fixup_fdt_macs(void *blob)
{
	u8 lan_mac[ARP_HLEN], wan_mac[ARP_HLEN];
	u8 lan_10g_mac[ARP_HLEN];
	int i, ret;

	if (!xr1710g_is_compatible())
		return;

	if (xr1710g_get_runtime_ethaddrs(lan_mac, wan_mac, lan_10g_mac))
		return;

	for (i = 0; i < ARRAY_SIZE(xr1710g_fdt_lan_mac_paths); i++) {
		ret = xr1710g_fdt_set_mac(blob, xr1710g_fdt_lan_mac_paths[i],
					  lan_mac);
		if (ret && ret != -FDT_ERR_NOTFOUND)
			printf("XR1710G: failed to update MAC for %s: %d\n",
			       xr1710g_fdt_lan_mac_paths[i], ret);
	}

	for (i = 0; i < ARRAY_SIZE(xr1710g_fdt_10g_lan_mac_paths); i++) {
		ret = xr1710g_fdt_set_mac(blob,
					  xr1710g_fdt_10g_lan_mac_paths[i],
					  lan_10g_mac);
		if (ret && ret != -FDT_ERR_NOTFOUND)
			printf("XR1710G: failed to update MAC for %s: %d\n",
			       xr1710g_fdt_10g_lan_mac_paths[i], ret);
	}

	for (i = 0; i < ARRAY_SIZE(xr1710g_fdt_wan_mac_paths); i++) {
		ret = xr1710g_fdt_set_mac(blob, xr1710g_fdt_wan_mac_paths[i],
					  wan_mac);
		if (ret && ret != -FDT_ERR_NOTFOUND)
			printf("XR1710G: failed to update MAC for %s: %d\n",
			       xr1710g_fdt_wan_mac_paths[i], ret);
	}
}

int board_init(void)
{
	/* address of boot parameters */
	gd->bd->bi_boot_params = CFG_SYS_SDRAM_BASE + 0x100;

	/*
	 * Capture Recovery before environment relocation can attach UBI.  The
	 * one-way gate keeps this boot from creating any new NAND bad marker.
	 */
	if (xr1710g_is_compatible() &&
	    xr1710g_recovery_button_pressed_stable(ofnode_path("/"))) {
		xr1710g_recovery_requested = true;
		ubi_recovery_forbid_new_bad_blocks();
	}

	return 0;
}

int run_http_recovery(void);

static int xr1710g_recovery_button_pressed(void)
{
	struct gpio_desc rec_gpio;
	ofnode root;
	int ret;

	if (!xr1710g_is_compatible())
		return 0;

	memset(&rec_gpio, 0, sizeof(rec_gpio));
	root = ofnode_path("/");
	ret = gpio_request_by_name_nodev(root, "recovery-gpios", 0, &rec_gpio,
					 GPIOD_IS_IN);
	if (ret)
		return xr1710g_recovery_button_pressed_raw(root);

	ret = dm_gpio_get_value(&rec_gpio);
	dm_gpio_free(NULL, &rec_gpio);

	return ret > 0;
}

int board_late_init(void)
{
	char boot_ubi[64];
	const char *ubi_part;
	bool recovery_requested;
	ulong recovery_addr;

	/*
	 * A late-only button sample is not allowed to enter Recovery: env
	 * relocation may already have attached UBI before the no-markbad latch.
	 */
	recovery_requested = xr1710g_recovery_requested;
	if (!recovery_requested && xr1710g_recovery_button_pressed())
		printf("XR1710G: refusing late Recovery request after environment load\n");
	if (recovery_requested)
		ubi_recovery_forbid_new_bad_blocks();

	xr1710g_sync_runtime_ethaddrs();
	ubi_part = xr1710g_detect_ubi_part();
	snprintf(boot_ubi, sizeof(boot_ubi),
		 "ubi part %s && run boot_production", ubi_part);
	env_set("boot_ubi", boot_ubi);
	(void)xr1710g_preboot_factory_sync(recovery_requested,
		xr1710g_ubi_layout_available, ubi_part,
		xr1710g_sync_factory_part);

	if (!recovery_requested)
		return 0;

	printf("Recovery button detected, starting web recovery...\n");
	env_set("ipaddr", "192.168.255.1");
	env_set("netmask", "255.255.255.0");
	env_set("gatewayip", "0.0.0.0");

	/*
	 * Keep the recovery upload buffer well away from the low-memory
	 * boot/load addresses. Large HTTP uploads are staged fully in RAM
	 * before flashing.
	 */
	recovery_addr = gd->ram_base + 0x10000000UL;
	if ((recovery_addr < gd->ram_base) ||
	    (recovery_addr >= gd->ram_base + gd->ram_size))
		recovery_addr = CONFIG_SYS_LOAD_ADDR;
	env_set_hex("recovery_addr", recovery_addr);

	if (IS_ENABLED(CONFIG_HTTPD_RECOVERY))
		run_http_recovery();
	else
		printf("HTTP recovery is not enabled.\n");

	return 0;
}

#if defined(CONFIG_OF_LIBFDT) && defined(CONFIG_OF_BOARD_SETUP)
int ft_board_setup(void *blob, struct bd_info *bd)
{
	if (!blob)
		return 0;

	xr1710g_fixup_fdt_macs(blob);

	return 0;
}
#endif
