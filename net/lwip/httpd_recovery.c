// SPDX-License-Identifier: GPL-2.0+
/*
 * Minimal HTTP upload recovery server using lwIP httpd
 * Serves a tiny upload page at / and handles POST to /upload/{firmware|uboot}
 */

#include <dm.h>
#include <dm/ofnode.h>
#include <env.h>
#include <log.h>
#include <malloc.h>
#include <memalign.h>
#include <command.h>
#include <mtd.h>
#include <net-lwip.h>
#include <net.h>
#include <recovery-dhcp.h>
#include <recovery-fport.h>
#include <initcall.h>
#include <ubi_uboot.h>
#include <watchdog.h>
#include <linux/delay.h>
#include <linux/errno.h>
#include <linux/string.h>
#include <console.h>
#include <asm/gpio.h>
#include <asm/global_data.h>
#include <dt-bindings/gpio/gpio.h>

#include <lwip/netif.h>
#include <lwip/pbuf.h>
#include <lwip/ip.h>
#include <lwip/timeouts.h>
#include <lwip/udp.h>
#include <lwip/tcp.h>
#include <lwip/etharp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/apps/httpd.h>
#include <lwip/apps/fs.h>
#include <lwip/prot/dhcp.h>
#include <lwip/prot/iana.h>
#include <version.h>
#include <timestamp.h>
#include <limits.h>
#include <ctype.h>
#include <miiphy.h>
#include <image.h>
#include <hash.h>
#include <xr1710g-recovery-mtd-transaction.h>
#include <xr1710g-recovery-upload-parser.h>
#include <xr1710g-recovery-validator.h>
#include <xr1710g-wiro-build.h>
#include <linux/libfdt.h>
#include <linux/mii.h>
#include <mtd/ubi-user.h>
#include <linux/mtd/partitions.h>
#include <timer.h>
#include <asm/io.h>
#include "../../drivers/mtd/ubi/ubi.h"

DECLARE_GLOBAL_DATA_PTR;

const char *xr1710g_detect_ubi_version(void);
ulong airoha_recovery_get_lan_activity_ms(void);

/*
 * XR1710G upload staging is deliberately independent of saved environment.
 * Keep it in a fixed, low RAM window and below U-Boot's reserved relocation,
 * malloc and stack area. Saved recovery_addr/loadaddr values are untrusted.
 */
#define RECOVERY_UPLOAD_RAM_OFFSET       0x10000000UL
#define RECOVERY_UPLOAD_RESERVED_GUARD   (16 * 1024 * 1024UL)
/* Default maximum upload size in bytes (override with env 'recovery_max') */
#define RECOVERY_MIN_FIRMWARE_SIZE (1 * 1024 * 1024UL)
#define RECOVERY_MAX_UBOOT_SIZE    (1 * 1024 * 1024UL)

/* Delay before reboot after flashing completes, to let browser finish reads */
#define REBOOT_DELAY_MS        3000
/* Browser upload pacing proven reliable on XR1710G Recovery. */
#define RECOVERY_UPLOAD_CREDIT_BYTES       (32 * 1024U)
#define RECOVERY_UPLOAD_CREDIT_INTERVAL_MS 1U
#define RECOVERY_STATIC_IPADDR           "192.168.255.1"
#define RECOVERY_STATIC_NETMASK          "255.255.255.0"
#define RECOVERY_STATIC_GATEWAY          "0.0.0.0"
#define RECOVERY_DHCP_CLIENT_IPADDR      "192.168.255.2"
#define RECOVERY_DHCP_BROADCAST_IPADDR   "192.168.255.255"
#define RECOVERY_DHCP_LEASE_SECS         86400U
#define RECOVERY_DHCP_MAX_MSG_LEN        1500
#define RECOVERY_STAGING_SHA256_SIZE       32
#define RECOVERY_LED_PORTS     2
#define RECOVERY_LED_POLL_MS   100
#define RECOVERY_LED_PHY_POLL_MS 500
#define RECOVERY_LED_MDIO_BACKOFF_MS 5000
#define RECOVERY_LED_ACTIVITY_MS 350
#define RECOVERY_LED_BLINK_MS  100
#define RECOVERY_STATUS_LED_MAX           8
#define RECOVERY_STATUS_SW_PWM_PERIOD_MS  20
#define RECOVERY_STATUS_HW_PWM_UPDATE_MS  40
#define RECOVERY_STATUS_HW_PWM_PERIOD_TICKS 1
#define RECOVERY_STATUS_BREATHE_PERIOD_MS 1800
#define RECOVERY_STATUS_BREATHE_HALF_MS   (RECOVERY_STATUS_BREATHE_PERIOD_MS / 2)
#define RECOVERY_STATUS_SWEEP_STEP_MS     700
#define RECOVERY_STATUS_OVERLAP_FP        (2 * 256)
#define RECOVERY_STATUS_BRIGHTNESS_FP     256
#define RECOVERY_STATUS_BREATHE_MIN_FP    64

#define RECOVERY_GPIO_SYSCTL_BASE      0x1fbf0200
#define RECOVERY_CHIP_SCU_BASE         0x1fa20000
#define RECOVERY_REG_GPIO_DATA         0x0004
#define RECOVERY_REG_GPIO_OE           0x0014
#define RECOVERY_REG_GPIO_CTRL         0x0000
#define RECOVERY_REG_GPIO_CTRL1        0x0020
#define RECOVERY_REG_GPIO_FLASH_MODE_CFG 0x0034
#define RECOVERY_REG_GPIO_CTRL2        0x0060
#define RECOVERY_REG_GPIO_CTRL3        0x0064
#define RECOVERY_REG_GPIO_DATA1        0x0070
#define RECOVERY_REG_GPIO_OE1          0x0078
#define RECOVERY_REG_GPIO_2ND_I2C_MODE 0x0214
#define RECOVERY_REG_GPIO_FLASH_MODE_CFG_EXT 0x0068
#define RECOVERY_REG_GPIO_FLASH_PRD_SET0 0x003c
#define RECOVERY_REG_GPIO_FLASH_MAP0     0x004c
#define RECOVERY_REG_GPIO_FLASH_MAP1     0x0050
#define RECOVERY_REG_CYCLE_CFG_VALUE0    0x0098

#define RECOVERY_GPIO_FLASH_MAP_BUCKET0  0x88888888
#define RECOVERY_GPIO_FLASH_DUTY_FULL    255

#define RECOVERY_GPIO_LAN0_LED0_MODE_MASK BIT(3)
#define RECOVERY_GPIO_LAN0_LED1_MODE_MASK BIT(4)
#define RECOVERY_GPIO_LAN1_LED0_MODE_MASK BIT(5)
#define RECOVERY_GPIO_LAN1_LED1_MODE_MASK BIT(6)
#define RECOVERY_GPIO43_FLASH_MODE_CFG BIT(23)
#define RECOVERY_GPIO44_FLASH_MODE_CFG BIT(24)
#define RECOVERY_UBOOTENV_SIZE (1 * 1024 * 1024UL)
#define RECOVERY_FACTORY_SIZE  (1 * 1024 * 1024UL)
#define RECOVERY_UBI_WRITE_CHUNK (1024 * 1024U)
#define RECOVERY_UBOOT_SLOT_DEFAULT_OFS 0x600000UL
#define RECOVERY_UBOOT_SLOT_DEFAULT_DEV "spi-nand0"
#define RECOVERY_UI_BUILD XR1710G_WIRO_UI_BUILD
#define RECOVERY_VENDOR_PART "vendor"
#define RECOVERY_CHAINLOADER_PART "chainloader"
#define RECOVERY_DSD_OFFSET 0x400000UL
#define RECOVERY_DSD_ENV_SIZE 0x1000UL
#define RECOVERY_DSD_EEPROM_OFFSET (RECOVERY_DSD_OFFSET + 0x5000UL)
#define RECOVERY_DSD_EEPROM_SIZE 0x1e00UL
#define RECOVERY_FACTORY_EEPROM_OFFSET 0x0000UL
#define RECOVERY_FACTORY_WAN_MAC_OFFSET 0x5000UL
#define RECOVERY_FACTORY_LAN_MAC_OFFSET 0x6000UL
#define RECOVERY_UBI_ROOTFS_DATA_MIN_PEBS 1U
#define RECOVERY_UBI_WL_RESERVED_PEBS 1U
#define RECOVERY_UBI_EBA_RESERVED_PEBS 1U
#define RECOVERY_UBI_FASTMAP_RESERVED_PEBS 4U
#define RECOVERY_UBI_CAPACITY_SAFETY_PEBS 4U

enum recovery_progress_phase {
	RECOVERY_PHASE_ERROR = -1,
	RECOVERY_PHASE_IDLE = 0,
	RECOVERY_PHASE_ERASE = 1,
	RECOVERY_PHASE_WRITE = 2,
	RECOVERY_PHASE_FACTORY = 3,
	RECOVERY_PHASE_ENVIRONMENT = 4,
	RECOVERY_PHASE_DONE = 5,
};

static u8 *recv_base;
static u32 recv_off;
static u32 recv_total;
static int post_ok;
static int flash_request;
static volatile int reboot_request;
static void *active_post_connection;
static u32 active_post_generation;
static u32 post_generation_counter;
static u32 flash_post_generation;
static void *post_credit_connection;
static u32 post_credit_generation;
static u32 post_recved_pending;
static bool post_credit_timer_active;
static bool staging_digest_valid;
static u32 staging_digest_size;
static u32 staging_digest_crc32;
static u8 staging_digest_sha256[RECOVERY_STAGING_SHA256_SIZE];
static u32 staging_digest_generation;
static int staging_digest_target = -1;
/* Progress for /status polling */
static volatile u32 prog_total; /* combined total for backward compat */
static volatile u32 prog_done;  /* combined done for backward compat */
static volatile u32 prog_erase_total;
static volatile u32 prog_erase_done;
static volatile u32 prog_write_total;
static volatile u32 prog_write_done;
static volatile int prog_phase;
static volatile int prog_partial;
static volatile int prog_error_code;
static const char *prog_error_stage = "none";
static const char *prog_validation_detail = "none";
static const char *prog_validation_component = "none";
static bool prog_flash_mutated;
/* A destructive failure may only be cleared by a fresh U-Boot boot. */
static bool recovery_destructive_error_latched;
static u8 *recovery_factory_cache;
static size_t recovery_factory_cache_size;
static unsigned long long prog_erase_volume_base;
static unsigned long long prog_erase_volume_bytes;
static struct recovery_status_led_ctrl *prog_status_leds;
static bool recovery_httpd_started;
static int recovery_ubi_attach_error;

static void recovery_reset_error(void)
{
	prog_partial = 0;
	prog_error_code = 0;
	prog_error_stage = "none";
	prog_validation_detail = "none";
	prog_validation_component = "none";
	prog_flash_mutated = false;
}

static void recovery_validation_step(const char *detail, const char *component)
{
	prog_validation_detail = detail ?: "unknown";
	prog_validation_component = component ?: "none";
}

static int recovery_set_error(const char *stage, int error)
{
	prog_partial = prog_flash_mutated;
	if (prog_partial)
		recovery_destructive_error_latched = true;
	prog_error_code = error;
	prog_error_stage = stage ?: "unknown";
	prog_phase = RECOVERY_PHASE_ERROR;

	return error;
}

static void recovery_abort_tcp_list(struct tcp_pcb **list)
{
	while (*list)
		tcp_abort(*list);
}

static void recovery_close_tcp_listeners(void)
{
	while (tcp_listen_pcbs.pcbs)
		tcp_close(tcp_listen_pcbs.pcbs);
}

static void recovery_lwip_cleanup(struct netif *netif)
{
	recovery_close_tcp_listeners();
	recovery_abort_tcp_list(&tcp_active_pcbs);
	recovery_abort_tcp_list(&tcp_tw_pcbs);
	recovery_abort_tcp_list(&tcp_bound_pcbs);
	if (netif)
		etharp_cleanup_netif(netif);
	recovery_httpd_started = false;
}

static void reboot_delay_cb(void *arg)
{
    (void)arg;
    reboot_request = 1;
}

static bool recovery_post_owner_matches(void *connection, u32 generation)
{
	return connection && generation &&
	       active_post_connection == connection &&
	       active_post_generation == generation;
}

static u32 recovery_current_post_generation(void *connection)
{
	if (!connection || active_post_connection != connection)
		return 0;

	return active_post_generation;
}

static int recovery_bind_post_owner(void *connection)
{
	if (!connection)
		return -EINVAL;

	post_generation_counter++;
	if (!post_generation_counter)
		post_generation_counter++;
	active_post_connection = connection;
	active_post_generation = post_generation_counter;

	return 0;
}

static void recovery_clear_post_owner(void *connection, u32 generation)
{
	if (!recovery_post_owner_matches(connection, generation))
		return;

	active_post_connection = NULL;
	active_post_generation = 0;
}

static void recovery_invalidate_post_owner(void)
{
	active_post_connection = NULL;
	active_post_generation = 0;
}

static void recovery_upload_credit_cb(void *arg)
{
	u32 generation = (u32)(uintptr_t)arg;
	void *connection;
	u16_t credit;

	if (!generation || post_credit_generation != generation)
		return;

	post_credit_timer_active = false;
	connection = post_credit_connection;

	if (!recovery_post_owner_matches(connection, generation) ||
	    !post_ok || !post_recved_pending) {
		post_credit_connection = NULL;
		post_credit_generation = 0;
		post_recved_pending = 0;
		return;
	}

	credit = min_t(u32, post_recved_pending,
		       RECOVERY_UPLOAD_CREDIT_BYTES);
	post_recved_pending -= credit;
	httpd_post_data_recved(connection, credit);

	/* The callback above may complete the POST and clear this state. */
	if (post_ok &&
	    recovery_post_owner_matches(connection, generation) &&
	    post_credit_generation == generation && post_recved_pending) {
		post_credit_timer_active = true;
		sys_timeout(RECOVERY_UPLOAD_CREDIT_INTERVAL_MS,
			    recovery_upload_credit_cb,
			    (void *)(uintptr_t)generation);
	} else if (post_credit_generation == generation) {
		post_credit_connection = NULL;
		post_credit_generation = 0;
		post_recved_pending = 0;
	}
}

static void recovery_cancel_upload_credit(void)
{
	u32 generation = post_credit_generation;

	if (post_credit_timer_active && generation)
		sys_untimeout(recovery_upload_credit_cb,
			      (void *)(uintptr_t)generation);

	post_credit_timer_active = false;
	post_credit_connection = NULL;
	post_credit_generation = 0;
	post_recved_pending = 0;
}

static void recovery_cancel_upload_credit_owner(void *connection,
						u32 generation)
{
	if (post_credit_connection != connection ||
	    post_credit_generation != generation)
		return;

	recovery_cancel_upload_credit();
}

static void recovery_queue_upload_credit(void *connection, u16_t bytes)
{
	u32 generation = recovery_current_post_generation(connection);

	if (!bytes)
		return;
	if (!generation)
		return;
	if ((post_credit_connection && post_credit_connection != connection) ||
	    (post_credit_generation && post_credit_generation != generation)) {
		printf("httpd: refusing upload credit for a stale POST transaction\n");
		return;
	}

	post_credit_connection = connection;
	post_credit_generation = generation;
	if (post_recved_pending > UINT_MAX - bytes)
		post_recved_pending = UINT_MAX;
	else
		post_recved_pending += bytes;

	if (!post_credit_timer_active) {
		post_credit_timer_active = true;
		sys_timeout(RECOVERY_UPLOAD_CREDIT_INTERVAL_MS,
			    recovery_upload_credit_cb,
			    (void *)(uintptr_t)generation);
	}
}

static void recovery_cancel_timeouts(void)
{
	recovery_cancel_upload_credit();
	recovery_invalidate_post_owner();
	sys_untimeout(reboot_delay_cb, NULL);
	flash_request = 0;
	reboot_request = 0;
}

static void recovery_prepare_static_network(void)
{
	env_set("ipaddr", RECOVERY_STATIC_IPADDR);
	env_set("netmask", RECOVERY_STATIC_NETMASK);
	env_set("gatewayip", RECOVERY_STATIC_GATEWAY);
}

enum upload_target {
	TARGET_FIRMWARE = 0,
	TARGET_UBOOT,
};
static enum upload_target current_target = TARGET_FIRMWARE;

static const char *recovery_target_name(enum upload_target target)
{
	return target == TARGET_UBOOT ? "uboot" : "firmware";
}

static void recovery_clear_staging_digest(void)
{
	staging_digest_valid = false;
	staging_digest_size = 0;
	staging_digest_crc32 = 0;
	memset(staging_digest_sha256, 0, sizeof(staging_digest_sha256));
	staging_digest_generation = 0;
	staging_digest_target = -1;
	flash_post_generation = 0;
}

static int recovery_calculate_staging_digest(const void *data, u32 size,
					      u32 *crc, u8 *sha256)
{
	const u8 *bytes = data;
	u32 offset = 0;
	int output_size = RECOVERY_STAGING_SHA256_SIZE;
	int ret;

	if (!data || !size || !crc || !sha256)
		return -EINVAL;

	*crc = 0;
	while (offset < size) {
		u32 chunk = min_t(u32, size - offset, 64 * 1024U);

		*crc = crc32(*crc, bytes + offset, chunk);
		offset += chunk;
		WATCHDOG_RESET();
	}
	ret = hash_block("sha256", data, size, sha256, &output_size);
	if (ret)
		return ret;
	if (output_size != RECOVERY_STAGING_SHA256_SIZE)
		return -EBADMSG;

	return 0;
}

static int recovery_capture_staging_digest(u32 generation)
{
	u32 crc;
	u8 sha256[RECOVERY_STAGING_SHA256_SIZE];
	int ret;

	ret = recovery_calculate_staging_digest(recv_base, recv_off, &crc,
						sha256);
	if (ret)
		return ret;

	staging_digest_size = recv_off;
	staging_digest_crc32 = crc;
	memcpy(staging_digest_sha256, sha256, sizeof(sha256));
	staging_digest_generation = generation;
	staging_digest_target = current_target;
	staging_digest_valid = true;

	printf("httpd: staged %u bytes, CRC32 %08x, SHA-256 captured\n",
	       staging_digest_size, staging_digest_crc32);
	return 0;
}

static int recovery_verify_staging_digest(void)
{
	u32 crc;
	u8 sha256[RECOVERY_STAGING_SHA256_SIZE];
	int ret;

	if (!staging_digest_valid || !flash_post_generation ||
	    staging_digest_generation != flash_post_generation ||
	    staging_digest_target != current_target ||
	    staging_digest_size != recv_off)
		return -ESTALE;

	ret = recovery_calculate_staging_digest(recv_base, recv_off, &crc,
						sha256);
	if (ret)
		return ret;
	if (crc != staging_digest_crc32 ||
	    memcmp(sha256, staging_digest_sha256, sizeof(sha256)))
		return -EBADMSG;

	return 0;
}

static bool recovery_upload_locked(void)
{
	return recovery_destructive_error_latched || post_ok || flash_request ||
	       reboot_request || prog_phase > RECOVERY_PHASE_IDLE;
}

static bool recovery_retry_allowed(void)
{
	if (recovery_upload_locked())
		return false;

	return prog_phase == RECOVERY_PHASE_IDLE ||
	       (prog_phase == RECOVERY_PHASE_ERROR && !prog_partial);
}

struct recovery_ubi_layout {
	const char *version;
	const char *part;
	u32 offset;
	u32 size;
};

static const struct recovery_ubi_layout recovery_ubi_layouts[] = {
	{ "2.0", "ubi", 0x00700000, 0x1b700000 },
	{ "1.5", "ubi1.5", 0x00700000, 0x1d9c0000 },
	{ "1.0", "ubi1.0", 0x00700000, 0x1f700000 },
};

static const struct recovery_ubi_layout *current_ubi_layout =
	&recovery_ubi_layouts[0];

struct recovery_upload_request {
	enum upload_target target;
	const struct recovery_ubi_layout *layout;
};

enum recovery_backend {
	RECOVERY_BACKEND_MTD = 0,
	RECOVERY_BACKEND_UBI,
};

struct recovery_target {
	enum recovery_backend backend;
	const char *name;
	const char *ubi_part;
	struct mtd_info *mtd;
	loff_t ofs;
	unsigned long long cur_size;
	unsigned long long limit;
	bool ubi_needs_format;
};

static bool recovery_machine_is_xr1710g(void)
{
	return of_machine_is_compatible("econet,xr1710g") ||
	       of_machine_is_compatible("econet,xr1710g-ubi") ||
	       of_machine_is_compatible("gemtek,xr1710g") ||
	       of_machine_is_compatible("gemtek,xr1710g-ubi");
}

struct recovery_led_ctrl {
	struct udevice *mdio_dev;
	ulong last_poll;
	ulong last_phy_poll;
	ulong last_mdio_error;
	bool mdio_fault;
	int speed[RECOVERY_LED_PORTS];
};

struct recovery_gpio_pin {
	struct gpio_desc desc;
	ofnode node;
	u8 gpio;
	s8 last_on;
	bool active_low;
	bool valid;
};

struct recovery_status_led_ctrl {
	struct recovery_gpio_pin leds[RECOVERY_STATUS_LED_MAX];
	int led_count;
	ulong start_ms;
	ulong last_pwm_update;
	u32 pwm_mux_mask;
	u32 pwm_mux_mask_ext;
	u32 saved_pwm_duty;
	u32 saved_pwm_map[2];
	u32 saved_pwm_cycle;
	bool pwm_active_low;
	bool hw_pwm;
};

struct recovery_dhcp_server {
	struct netif *netif;
	bool running;
	ip4_addr_t server_ip;
	ip4_addr_t client_ip;
	ip4_addr_t netmask;
	ip4_addr_t router;
	ip4_addr_t broadcast;
	ip4_addr_t dns;
	u8 server_mac[RECOVERY_DHCP_MAC_LEN];
	struct recovery_dhcp_config config;
	struct recovery_fport_status request_fport;
	struct recovery_fport_status reply_fport;
	u32 rx_datagrams;
	u32 malformed_requests;
	u32 ignored_requests;
	u32 discovers;
	u32 requests;
	u32 offer_attempts;
	u32 offer_successes;
	u32 offer_failures;
	u32 ack_attempts;
	u32 ack_successes;
	u32 ack_failures;
	u32 nak_attempts;
	u32 nak_successes;
	u32 nak_failures;
	u8 last_reply_type;
	int last_send_error;
	u16 last_frame_len;
};

static struct recovery_dhcp_server recovery_dhcp_state;
static struct recovery_dhcp_server *recovery_active_dhcp;

#if defined(CONFIG_AIROHA_ETH)
#else
static int
airoha_recovery_get_fport_status(struct recovery_fport_status *status)
{
	if (!status)
		return -EINVAL;
	memset(status, 0, sizeof(*status));
	return -ENODEV;
}
#endif

static const int recovery_led_phy_addrs[RECOVERY_LED_PORTS] = { 9, 10 };
static const u8 recovery_green_led_gpios[RECOVERY_LED_PORTS] = { 43, 44 };
static const u8 recovery_yellow_led_gpios[RECOVERY_LED_PORTS] = { 33, 34 };

static void recovery_led_ctrl_free(struct recovery_led_ctrl *ctrl)
{
	memset(ctrl, 0, sizeof(*ctrl));
}

static bool recovery_gpio_flash_mode_bit(u8 gpio, uintptr_t *reg, u32 *mask)
{
	if (gpio <= 15) {
		*reg = RECOVERY_GPIO_SYSCTL_BASE + RECOVERY_REG_GPIO_FLASH_MODE_CFG;
		*mask = BIT(gpio);
		return true;
	}

	if (gpio >= 16 && gpio <= 31) {
		*reg = RECOVERY_GPIO_SYSCTL_BASE + RECOVERY_REG_GPIO_FLASH_MODE_CFG_EXT;
		*mask = BIT(gpio - 16);
		return true;
	}

	if (gpio >= 36 && gpio <= 51) {
		*reg = RECOVERY_GPIO_SYSCTL_BASE + RECOVERY_REG_GPIO_FLASH_MODE_CFG_EXT;
		*mask = BIT(gpio - 20);
		return true;
	}

	return false;
}

static void recovery_clrsetbits_le32(uintptr_t addr, u32 clear, u32 set)
{
	u32 val = readl((void __iomem *)addr);

	val &= ~clear;
	val |= set;
	writel(val, (void __iomem *)addr);
}

static uintptr_t recovery_gpio_data_reg(u8 gpio)
{
	return RECOVERY_GPIO_SYSCTL_BASE +
	       (gpio < 32 ? RECOVERY_REG_GPIO_DATA : RECOVERY_REG_GPIO_DATA1);
}

static uintptr_t recovery_gpio_oe_reg(u8 gpio)
{
	return RECOVERY_GPIO_SYSCTL_BASE +
	       (gpio < 32 ? RECOVERY_REG_GPIO_OE : RECOVERY_REG_GPIO_OE1);
}

static uintptr_t recovery_gpio_dir_reg(u8 gpio)
{
	static const u16 dir_regs[] = {
		RECOVERY_REG_GPIO_CTRL,
		RECOVERY_REG_GPIO_CTRL1,
		RECOVERY_REG_GPIO_CTRL2,
		RECOVERY_REG_GPIO_CTRL3,
	};

	return RECOVERY_GPIO_SYSCTL_BASE + dir_regs[gpio / 16];
}

static void recovery_gpio_direction_output(u8 gpio)
{
	u32 bank_bit = BIT(gpio % 32);
	u32 dir_bit = BIT(2 * (gpio % 16));

	recovery_clrsetbits_le32(recovery_gpio_oe_reg(gpio), 0, bank_bit);
	recovery_clrsetbits_le32(recovery_gpio_dir_reg(gpio), 0, dir_bit);
}

static void recovery_gpio_prepare_output(u8 gpio)
{
	uintptr_t reg;
	u32 mask;

	if (recovery_gpio_flash_mode_bit(gpio, &reg, &mask))
		recovery_clrsetbits_le32(reg, mask, 0);

	recovery_gpio_direction_output(gpio);
}

static void recovery_gpio_set_value(u8 gpio, bool active_low, int active)
{
	u32 bit = BIT(gpio % 32);
	uintptr_t reg = recovery_gpio_data_reg(gpio);
	u32 set = active_low ? (active ? 0 : bit) : (active ? bit : 0);

	recovery_clrsetbits_le32(reg, bit, set);
}

static void recovery_led_set_pin(u8 gpio, int on)
{
	recovery_gpio_set_value(gpio, true, on);
}

static void recovery_led_stop(struct recovery_led_ctrl *ctrl)
{
	int i;

	if (!ctrl)
		return;

	for (i = 0; i < RECOVERY_LED_PORTS; i++) {
		recovery_led_set_pin(recovery_green_led_gpios[i], 0);
		recovery_led_set_pin(recovery_yellow_led_gpios[i], 0);
	}
}

static void recovery_status_led_set(struct recovery_gpio_pin *pin, int on)
{
	if (!pin->valid)
		return;

	on = !!on;
	if (pin->last_on == on)
		return;

	recovery_gpio_set_value(pin->gpio, pin->active_low, on);
	pin->last_on = on;
}

static void recovery_gpio_pin_release(struct recovery_gpio_pin *pin)
{
	if (!pin->valid)
		return;

	memset(pin, 0, sizeof(*pin));
}

static ofnode recovery_led_alias_node(const char *alias)
{
	ofnode aliases;
	const char *path;

	aliases = ofnode_path("/aliases");
	if (!ofnode_valid(aliases))
		return ofnode_null();

	path = ofnode_read_string(aliases, alias);
	if (!path)
		return ofnode_null();

	return ofnode_path(path);
}

static int recovery_led_node_to_gpio(ofnode node, struct recovery_gpio_pin *pin)
{
	struct ofnode_phandle_args args;
	int ret;

	memset(pin, 0, sizeof(*pin));

	if (!ofnode_valid(node))
		return -ENOENT;

	ret = ofnode_parse_phandle_with_args(node, "gpios", "#gpio-cells", 0, 0,
					     &args);
	if (ret)
		return ret;

	if (args.args_count < 1)
		return -EINVAL;

	pin->gpio = args.args[0];
	pin->active_low = args.args_count > 1 &&
			  (args.args[1] & GPIO_ACTIVE_LOW);
	pin->last_on = -1;
	pin->node = node;
	pin->valid = true;

	return 0;
}

static void recovery_status_led_add(struct recovery_status_led_ctrl *ctrl,
				    const struct recovery_gpio_pin *pin)
{
	int i;

	if (!pin->valid)
		return;

	for (i = 0; i < ctrl->led_count; i++) {
		if (ctrl->leds[i].gpio == pin->gpio)
			return;
	}

	if (ctrl->led_count >= ARRAY_SIZE(ctrl->leds))
		return;

	ctrl->leds[ctrl->led_count++] = *pin;
}

static void recovery_status_led_collect_alias(struct recovery_status_led_ctrl *ctrl,
					      const char *alias)
{
	struct recovery_gpio_pin pin;

	if (!recovery_led_node_to_gpio(recovery_led_alias_node(alias), &pin))
		recovery_status_led_add(ctrl, &pin);
}

static int recovery_status_led_request(struct recovery_gpio_pin *pin)
{
	recovery_gpio_prepare_output(pin->gpio);
	recovery_gpio_set_value(pin->gpio, pin->active_low, 0);
	pin->last_on = 0;

	return 0;
}

static void recovery_status_led_hw_pwm_set(struct recovery_status_led_ctrl *ctrl,
					   u32 brightness_fp)
{
	u32 high_ticks, value;

	high_ticks = (brightness_fp * RECOVERY_GPIO_FLASH_DUTY_FULL +
		      RECOVERY_STATUS_BRIGHTNESS_FP / 2) /
		     RECOVERY_STATUS_BRIGHTNESS_FP;
	if (ctrl->pwm_active_low)
		high_ticks = RECOVERY_GPIO_FLASH_DUTY_FULL - high_ticks;

	value = ((RECOVERY_GPIO_FLASH_DUTY_FULL - high_ticks) << 8) |
		high_ticks;
	recovery_clrsetbits_le32(RECOVERY_GPIO_SYSCTL_BASE +
				 RECOVERY_REG_GPIO_FLASH_PRD_SET0,
				 GENMASK(15, 0), value);
}

static int recovery_status_led_hw_pwm_init(struct recovery_status_led_ctrl *ctrl)
{
	u32 flash_mode, flash_mode_ext;
	int i;

	ctrl->pwm_active_low = ctrl->leds[0].active_low;
	for (i = 0; i < ctrl->led_count; i++) {
		uintptr_t reg;
		u32 mask;

		if (ctrl->leds[i].active_low != ctrl->pwm_active_low ||
		    !recovery_gpio_flash_mode_bit(ctrl->leds[i].gpio, &reg,
						  &mask))
			return -EOPNOTSUPP;

		if (reg == RECOVERY_GPIO_SYSCTL_BASE +
			   RECOVERY_REG_GPIO_FLASH_MODE_CFG)
			ctrl->pwm_mux_mask |= mask;
		else
			ctrl->pwm_mux_mask_ext |= mask;
	}

	flash_mode = readl((void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
					      RECOVERY_REG_GPIO_FLASH_MODE_CFG));
	flash_mode_ext = readl((void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
						  RECOVERY_REG_GPIO_FLASH_MODE_CFG_EXT));
	if ((flash_mode & ~ctrl->pwm_mux_mask) ||
	    (flash_mode_ext & ~ctrl->pwm_mux_mask_ext))
		return -EBUSY;

	ctrl->saved_pwm_duty = readl((void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
						 RECOVERY_REG_GPIO_FLASH_PRD_SET0));
	ctrl->saved_pwm_map[0] = readl((void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
						  RECOVERY_REG_GPIO_FLASH_MAP0));
	ctrl->saved_pwm_map[1] = readl((void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
						  RECOVERY_REG_GPIO_FLASH_MAP1));
	ctrl->saved_pwm_cycle = readl((void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
						  RECOVERY_REG_CYCLE_CFG_VALUE0));

	recovery_clrsetbits_le32(RECOVERY_GPIO_SYSCTL_BASE +
				 RECOVERY_REG_CYCLE_CFG_VALUE0,
				 GENMASK(7, 0),
				 RECOVERY_STATUS_HW_PWM_PERIOD_TICKS);
	recovery_status_led_hw_pwm_set(ctrl, 0);
	/* Extended PWM muxes use fixed GPIO0..15 channels; share one bucket. */
	writel(RECOVERY_GPIO_FLASH_MAP_BUCKET0,
	       (void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
				RECOVERY_REG_GPIO_FLASH_MAP0));
	writel(RECOVERY_GPIO_FLASH_MAP_BUCKET0,
	       (void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
				RECOVERY_REG_GPIO_FLASH_MAP1));
	recovery_clrsetbits_le32(RECOVERY_GPIO_SYSCTL_BASE +
				 RECOVERY_REG_GPIO_FLASH_MODE_CFG,
				 0, ctrl->pwm_mux_mask);
	recovery_clrsetbits_le32(RECOVERY_GPIO_SYSCTL_BASE +
				 RECOVERY_REG_GPIO_FLASH_MODE_CFG_EXT,
				 0, ctrl->pwm_mux_mask_ext);

	ctrl->hw_pwm = true;

	return 0;
}

static void recovery_status_led_hw_pwm_stop(struct recovery_status_led_ctrl *ctrl)
{
	int i;

	recovery_status_led_hw_pwm_set(ctrl, 0);
	recovery_clrsetbits_le32(RECOVERY_GPIO_SYSCTL_BASE +
				 RECOVERY_REG_GPIO_FLASH_MODE_CFG,
				 ctrl->pwm_mux_mask, 0);
	recovery_clrsetbits_le32(RECOVERY_GPIO_SYSCTL_BASE +
				 RECOVERY_REG_GPIO_FLASH_MODE_CFG_EXT,
				 ctrl->pwm_mux_mask_ext, 0);

	writel(ctrl->saved_pwm_map[0],
	       (void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
				RECOVERY_REG_GPIO_FLASH_MAP0));
	writel(ctrl->saved_pwm_map[1],
	       (void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
				RECOVERY_REG_GPIO_FLASH_MAP1));
	writel(ctrl->saved_pwm_duty,
	       (void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
				RECOVERY_REG_GPIO_FLASH_PRD_SET0));
	writel(ctrl->saved_pwm_cycle,
	       (void __iomem *)(RECOVERY_GPIO_SYSCTL_BASE +
				RECOVERY_REG_CYCLE_CFG_VALUE0));

	ctrl->hw_pwm = false;
	for (i = 0; i < ctrl->led_count; i++) {
		ctrl->leds[i].last_on = -1;
		recovery_status_led_set(&ctrl->leds[i], 0);
	}
}

static void recovery_status_led_release(struct recovery_status_led_ctrl *ctrl)
{
	int i;

	for (i = 0; i < ctrl->led_count; i++)
		recovery_gpio_pin_release(&ctrl->leds[i]);

	memset(ctrl, 0, sizeof(*ctrl));
}

static int recovery_status_led_init(struct recovery_status_led_ctrl *ctrl)
{
	static const char *const status_aliases[] = {
		"led-boot",
		"led-running",
		"led-failsafe",
		"led-upgrade",
	};
	ofnode leds, node;
	int i, keep = 0;

	memset(ctrl, 0, sizeof(*ctrl));

	leds = ofnode_path("/leds");
	if (ofnode_valid(leds)) {
		ofnode_for_each_subnode(node, leds) {
			const char *function;
			struct recovery_gpio_pin pin;

			function = ofnode_read_string(node, "function");
			if (!function || strcmp(function, "status"))
				continue;

			if (!recovery_led_node_to_gpio(node, &pin))
				recovery_status_led_add(ctrl, &pin);
		}
	}

	for (i = 0; i < ARRAY_SIZE(status_aliases); i++)
		recovery_status_led_collect_alias(ctrl, status_aliases[i]);

	if (!ctrl->led_count)
		return -ENOENT;

	for (i = 0; i < ctrl->led_count; i++) {
		int ret;

		ret = recovery_status_led_request(&ctrl->leds[i]);
		if (ret) {
			printf("Recovery status LED gpio%u request failed: %d\n",
			       ctrl->leds[i].gpio, ret);
			recovery_gpio_pin_release(&ctrl->leds[i]);
			continue;
		}

		if (keep != i) {
			ctrl->leds[keep] = ctrl->leds[i];
			memset(&ctrl->leds[i], 0, sizeof(ctrl->leds[i]));
		}
		keep++;
	}

	ctrl->led_count = keep;

	if (!ctrl->led_count) {
		recovery_status_led_release(ctrl);
		return -ENODEV;
	}

	ctrl->start_ms = get_timer(0);
	if (ctrl->led_count == 1) {
		int pwm_ret = recovery_status_led_hw_pwm_init(ctrl);

		if (pwm_ret)
			printf("Recovery status LED hardware PWM unavailable (%d), using GPIO PWM\n",
			       pwm_ret);
	}

	printf("Recovery status LEDs:");
	for (i = 0; i < ctrl->led_count; i++)
		printf(" gpio%u%s", ctrl->leds[i].gpio,
		       ctrl->leds[i].active_low ? "(L)" : "");
	printf(" (%s PWM)\n", ctrl->hw_pwm ? "hardware" : "software");

	return 0;
}

static u32 recovery_status_led_breath_fp(ulong elapsed)
{
	ulong phase, ramp;
	u32 delta;

	phase = elapsed % RECOVERY_STATUS_BREATHE_PERIOD_MS;
	ramp = phase < RECOVERY_STATUS_BREATHE_HALF_MS ?
	       phase : RECOVERY_STATUS_BREATHE_PERIOD_MS - phase;
	delta = RECOVERY_STATUS_BRIGHTNESS_FP - RECOVERY_STATUS_BREATHE_MIN_FP;

	return RECOVERY_STATUS_BREATHE_MIN_FP +
	       (delta * ramp * ramp +
		(RECOVERY_STATUS_BREATHE_HALF_MS *
		 RECOVERY_STATUS_BREATHE_HALF_MS) / 2) /
	       (RECOVERY_STATUS_BREATHE_HALF_MS *
		RECOVERY_STATUS_BREATHE_HALF_MS);
}

static ulong recovery_status_led_position_fp(struct recovery_status_led_ctrl *ctrl,
					     ulong elapsed)
{
	ulong range_fp, phase;
	int span;

	if (ctrl->led_count <= 1)
		return 0;

	span = ctrl->led_count - 1;
	range_fp = span * RECOVERY_STATUS_BRIGHTNESS_FP;
	phase = elapsed % (2 * span * RECOVERY_STATUS_SWEEP_STEP_MS);

	if (phase <= span * RECOVERY_STATUS_SWEEP_STEP_MS)
		return phase * RECOVERY_STATUS_BRIGHTNESS_FP /
		       RECOVERY_STATUS_SWEEP_STEP_MS;

	phase -= span * RECOVERY_STATUS_SWEEP_STEP_MS;

	return range_fp - (phase * RECOVERY_STATUS_BRIGHTNESS_FP /
			   RECOVERY_STATUS_SWEEP_STEP_MS);
}

static u32 recovery_status_led_brightness_fp(struct recovery_status_led_ctrl *ctrl,
					     int idx, ulong elapsed)
{
	ulong center_fp, pwm_phase;
	u32 breath_fp, weight_fp, dist_fp;
	ulong led_pos_fp;

	center_fp = recovery_status_led_position_fp(ctrl, elapsed);
	led_pos_fp = idx * RECOVERY_STATUS_BRIGHTNESS_FP;
	dist_fp = center_fp > led_pos_fp ? center_fp - led_pos_fp :
					  led_pos_fp - center_fp;
	if (dist_fp >= RECOVERY_STATUS_OVERLAP_FP)
		return 0;

	weight_fp = (RECOVERY_STATUS_OVERLAP_FP - dist_fp) *
		    RECOVERY_STATUS_BRIGHTNESS_FP / RECOVERY_STATUS_OVERLAP_FP;
	weight_fp = weight_fp * weight_fp / RECOVERY_STATUS_BRIGHTNESS_FP;
	breath_fp = recovery_status_led_breath_fp(elapsed);
	pwm_phase = weight_fp * breath_fp;
	pwm_phase = (pwm_phase + RECOVERY_STATUS_BRIGHTNESS_FP / 2) /
		    RECOVERY_STATUS_BRIGHTNESS_FP;

	return pwm_phase;
}

static void recovery_status_led_poll(struct recovery_status_led_ctrl *ctrl)
{
	ulong elapsed, now, pwm_phase;
	u32 brightness_fp;
	int duty_ms;
	int i;

	if (!ctrl->led_count)
		return;

	now = get_timer(0);
	elapsed = now - ctrl->start_ms;
	if (ctrl->hw_pwm) {
		if (ctrl->last_pwm_update &&
		    now - ctrl->last_pwm_update < RECOVERY_STATUS_HW_PWM_UPDATE_MS)
			return;

		ctrl->last_pwm_update = now;
		recovery_status_led_hw_pwm_set(ctrl,
					       recovery_status_led_breath_fp(elapsed));
		return;
	}

	pwm_phase = elapsed % RECOVERY_STATUS_SW_PWM_PERIOD_MS;

	for (i = 0; i < ctrl->led_count; i++) {
		brightness_fp =
			recovery_status_led_brightness_fp(ctrl, i, elapsed);
		duty_ms = (brightness_fp * RECOVERY_STATUS_SW_PWM_PERIOD_MS +
			   RECOVERY_STATUS_BRIGHTNESS_FP / 2) /
			  RECOVERY_STATUS_BRIGHTNESS_FP;
		recovery_status_led_set(&ctrl->leds[i],
					duty_ms && pwm_phase < duty_ms);
	}
}

static void recovery_status_led_service(void *arg)
{
	recovery_status_led_poll(arg);
}

static void recovery_status_led_stop(struct recovery_status_led_ctrl *ctrl)
{
	int i;

	if (!ctrl->led_count)
		return;

	if (ctrl->hw_pwm) {
		recovery_status_led_hw_pwm_stop(ctrl);
		return;
	}

	for (i = 0; i < ctrl->led_count; i++)
		recovery_status_led_set(&ctrl->leds[i], 0);
}

static void
recovery_dhcp_record_send_result(struct recovery_dhcp_server *srv,
				 u8 message_type, int error)
{
	u32 *attempts;
	u32 *successes;
	u32 *failures;

	switch (message_type) {
	case RECOVERY_DHCP_OFFER:
		attempts = &srv->offer_attempts;
		successes = &srv->offer_successes;
		failures = &srv->offer_failures;
		break;
	case RECOVERY_DHCP_ACK:
		attempts = &srv->ack_attempts;
		successes = &srv->ack_successes;
		failures = &srv->ack_failures;
		break;
	case RECOVERY_DHCP_NAK:
		attempts = &srv->nak_attempts;
		successes = &srv->nak_successes;
		failures = &srv->nak_failures;
		break;
	default:
		return;
	}

	(*attempts)++;
	if (error)
		(*failures)++;
	else
		(*successes)++;
	srv->last_reply_type = message_type;
	srv->last_send_error = error;
}

static int
recovery_dhcp_send_reply(struct recovery_dhcp_server *srv,
			 const struct recovery_dhcp_request *request,
			 u8 message_type)
{
	u8 reply_frame[RECOVERY_DHCP_REPLY_FRAME_LEN] __aligned(PKTALIGN);
	struct udevice *udev;
	int frame_len;
	int err;

	memset(&srv->reply_fport, 0, sizeof(srv->reply_fport));
	srv->last_frame_len = 0;
	frame_len = recovery_dhcp_build_reply_frame(
		request, &srv->config, srv->server_mac, message_type,
		reply_frame, sizeof(reply_frame));
	if (frame_len < 0) {
		recovery_dhcp_record_send_result(srv, message_type, frame_len);
		return frame_len;
	}
	srv->last_frame_len = frame_len;

	/*
	 * DHCP starts before the client has an address or ARP entry. Emit the
	 * complete broadcast Ethernet frame through the real U-Boot Ethernet
	 * driver instead of relying on lwIP's UDP/ARP route selection. The
	 * Airoha driver sends this frame only to the actual RX fport when known.
	 * Safe LAN/10G fan-out is used only when ingress is unknown; a known-port
	 * TX failure is returned without leaking the reply onto another port.
	 */
	udev = srv->netif ? srv->netif->state : NULL;
	if (!udev || !eth_get_ops(udev) || !eth_get_ops(udev)->send) {
		recovery_dhcp_record_send_result(srv, message_type, -ENODEV);
		return -ENODEV;
	}

	err = eth_get_ops(udev)->send(udev, reply_frame, frame_len);
	/* Snapshot immediately; a later HTTP status request changes driver RX. */
	airoha_recovery_get_fport_status(&srv->reply_fport);
	recovery_dhcp_record_send_result(srv, message_type, err);
	return err;
}

static void
recovery_dhcp_recv(void *arg, struct udp_pcb *pcb, struct pbuf *p,
		   const ip_addr_t *addr, u16_t port)
{
	struct recovery_dhcp_server *srv = arg;
	struct recovery_dhcp_request request;
	struct recovery_fport_status ingress_fport = { 0 };
	enum recovery_dhcp_parse_result parse_result;
	u8 pkt[RECOVERY_DHCP_MAX_MSG_LEN];
	u8 reply_type;
	int pkt_len;

	(void)pcb;
	(void)addr;

	if (!p)
		return;

	/* Capture the ingress metadata before raw reply TX changes TX state. */
	airoha_recovery_get_fport_status(&ingress_fport);
	srv->rx_datagrams++;
	if (port != LWIP_IANA_PORT_DHCP_CLIENT ||
	    p->tot_len > sizeof(pkt)) {
		srv->malformed_requests++;
		goto out;
	}

	pkt_len = pbuf_copy_partial(p, pkt, p->tot_len, 0);
	if (pkt_len != p->tot_len) {
		srv->malformed_requests++;
		goto out;
	}

	parse_result = recovery_dhcp_parse_request(pkt, pkt_len, &request);
	if (parse_result != RECOVERY_DHCP_PARSE_OK) {
		srv->malformed_requests++;
		goto out;
	}
	srv->request_fport = ingress_fport;

	switch (request.message_type) {
	case RECOVERY_DHCP_DISCOVER:
		srv->discovers++;
		break;
	case RECOVERY_DHCP_REQUEST:
		srv->requests++;
		break;
	default:
		srv->ignored_requests++;
		goto out;
	}

	reply_type = recovery_dhcp_select_reply(&request, &srv->config);
	if (!reply_type) {
		srv->ignored_requests++;
		goto out;
	}

	recovery_dhcp_send_reply(srv, &request, reply_type);

out:
	pbuf_free(p);
}

static int recovery_dhcp_server_init(struct recovery_dhcp_server *srv,
				     struct netif *netif)
{
	char server_ip[IP4ADDR_STRLEN_MAX];
	char client_ip[IP4ADDR_STRLEN_MAX];
	char netmask[IP4ADDR_STRLEN_MAX];
	char router[IP4ADDR_STRLEN_MAX];
	char broadcast[IP4ADDR_STRLEN_MAX];

	memset(srv, 0, sizeof(*srv));
	/*
	 * Link negotiation may finish after Recovery starts.  Keep the raw DHCP
	 * hook resident while the link is down so a later Discover is handled.
	 */
	if (!netif || !netif_is_up(netif) ||
	    netif->hwaddr_len != RECOVERY_DHCP_MAC_LEN ||
	    !is_valid_ethaddr(netif->hwaddr))
		return -ENODEV;

	srv->netif = netif;
	memcpy(srv->server_mac, netif->hwaddr, sizeof(srv->server_mac));
	ip4_addr_copy(srv->server_ip, *netif_ip4_addr(netif));
	ip4_addr_copy(srv->netmask, *netif_ip4_netmask(netif));
	ip4_addr_copy(srv->router, *netif_ip4_gw(netif));
	ip4_addr_copy(srv->dns, *netif_ip4_addr(netif));
	if (ip4_addr_isany(&srv->server_ip))
		return -EINVAL;

	if (ip4_addr_isany(&srv->router))
		ip4_addr_copy(srv->router, srv->server_ip);

	if (!ip4addr_aton(RECOVERY_DHCP_CLIENT_IPADDR, &srv->client_ip))
		return -EINVAL;

	if (ip4_addr_isany(&srv->netmask)) {
		if (!ip4addr_aton(RECOVERY_DHCP_BROADCAST_IPADDR, &srv->broadcast))
			return -EINVAL;
	} else {
		srv->broadcast.addr = (srv->server_ip.addr & srv->netmask.addr) |
				      ~srv->netmask.addr;
	}

	memcpy(srv->config.server_ip, &srv->server_ip.addr,
	       sizeof(srv->config.server_ip));
	memcpy(srv->config.client_ip, &srv->client_ip.addr,
	       sizeof(srv->config.client_ip));
	memcpy(srv->config.netmask, &srv->netmask.addr,
	       sizeof(srv->config.netmask));
	srv->config.lease_seconds = RECOVERY_DHCP_LEASE_SECS;
	srv->running = true;

	printf("DHCP recovery server: %s/67 -> offer %s mask %s gw %s bcast %s\n",
	       ip4addr_ntoa_r(&srv->server_ip, server_ip, sizeof(server_ip)),
	       ip4addr_ntoa_r(&srv->client_ip, client_ip, sizeof(client_ip)),
	       ip4addr_ntoa_r(&srv->netmask, netmask, sizeof(netmask)),
	       ip4addr_ntoa_r(&srv->router, router, sizeof(router)),
	       ip4addr_ntoa_r(&srv->broadcast, broadcast,
			      sizeof(broadcast)));

	return 0;
}

static void recovery_dhcp_server_stop(struct recovery_dhcp_server *srv)
{
	memset(srv, 0, sizeof(*srv));
}

static int recovery_led_init(struct recovery_led_ctrl *ctrl)
{
	ofnode mdio_node;
	int i, ret;

	memset(ctrl, 0, sizeof(*ctrl));

	/* Make sure PHY LED mux is disabled so software can own the lines. */
	recovery_clrsetbits_le32(RECOVERY_CHIP_SCU_BASE + RECOVERY_REG_GPIO_2ND_I2C_MODE,
				 RECOVERY_GPIO_LAN0_LED0_MODE_MASK |
				 RECOVERY_GPIO_LAN0_LED1_MODE_MASK |
				 RECOVERY_GPIO_LAN1_LED0_MODE_MASK |
				 RECOVERY_GPIO_LAN1_LED1_MODE_MASK, 0);

	for (i = 0; i < RECOVERY_LED_PORTS; i++) {
		recovery_gpio_prepare_output(recovery_green_led_gpios[i]);
		recovery_gpio_prepare_output(recovery_yellow_led_gpios[i]);
		recovery_led_set_pin(recovery_green_led_gpios[i], 0);
		recovery_led_set_pin(recovery_yellow_led_gpios[i], 0);
	}

	mdio_node = ofnode_path("/soc/switch@1fb58000/mdio");
	if (!ofnode_valid(mdio_node))
		return 0;

	ret = uclass_get_device_by_ofnode(UCLASS_MDIO, mdio_node, &ctrl->mdio_dev);
	if (ret)
		ctrl->mdio_dev = NULL;

	return 0;
}

static int recovery_led_phy_speed(struct recovery_led_ctrl *ctrl, int idx)
{
	int bmcr, bmsr, stat1000, ctrl1000, lpa;

	if (!ctrl->mdio_dev || idx >= ARRAY_SIZE(recovery_led_phy_addrs))
		return 0;

	bmsr = dm_mdio_read(ctrl->mdio_dev, recovery_led_phy_addrs[idx],
			    MDIO_DEVAD_NONE, MII_BMSR);
	if (bmsr < 0)
		return bmsr;

	bmsr = dm_mdio_read(ctrl->mdio_dev, recovery_led_phy_addrs[idx],
			    MDIO_DEVAD_NONE, MII_BMSR);
	if (bmsr < 0)
		return bmsr;

	if (!(bmsr & BMSR_LSTATUS))
		return 0;

	bmcr = dm_mdio_read(ctrl->mdio_dev, recovery_led_phy_addrs[idx],
			    MDIO_DEVAD_NONE, MII_BMCR);
	if (bmcr < 0)
		return bmcr;

	if (!(bmcr & BMCR_ANENABLE)) {
		if (bmcr & BMCR_SPEED1000)
			return SPEED_1000;
		if (bmcr & BMCR_SPEED100)
			return SPEED_100;

		return SPEED_10;
	}

	stat1000 = dm_mdio_read(ctrl->mdio_dev, recovery_led_phy_addrs[idx],
				MDIO_DEVAD_NONE, MII_STAT1000);
	ctrl1000 = dm_mdio_read(ctrl->mdio_dev, recovery_led_phy_addrs[idx],
				MDIO_DEVAD_NONE, MII_CTRL1000);
	if (stat1000 < 0 || ctrl1000 < 0)
		return stat1000 < 0 ? stat1000 : ctrl1000;

	if (stat1000 >= 0 && ctrl1000 >= 0) {
		stat1000 &= ctrl1000 << 2;
		if (stat1000 & (PHY_1000BTSR_1000FD | PHY_1000BTSR_1000HD))
			return SPEED_1000;
	}

	lpa = dm_mdio_read(ctrl->mdio_dev, recovery_led_phy_addrs[idx],
			   MDIO_DEVAD_NONE, MII_ADVERTISE);
	if (lpa < 0)
		return lpa;

	bmsr = dm_mdio_read(ctrl->mdio_dev, recovery_led_phy_addrs[idx],
			    MDIO_DEVAD_NONE, MII_LPA);
	if (bmsr < 0)
		return bmsr;

	lpa &= bmsr;
	if (lpa & (LPA_100FULL | LPA_100HALF))
		return SPEED_100;

	return SPEED_10;
}

static void recovery_led_poll(struct recovery_led_ctrl *ctrl)
{
	ulong activity_ms;
	ulong now;
	bool activity;
	bool blink_on;
	bool poll_phys;
	int i;

	now = get_timer(0);
	if (ctrl->last_poll && now - ctrl->last_poll < RECOVERY_LED_POLL_MS)
		return;

	ctrl->last_poll = now;
	poll_phys = !ctrl->last_phy_poll ||
		    now - ctrl->last_phy_poll >= RECOVERY_LED_PHY_POLL_MS;
	if (ctrl->mdio_fault &&
	    get_timer(ctrl->last_mdio_error) < RECOVERY_LED_MDIO_BACKOFF_MS)
		poll_phys = false;

	if (poll_phys) {
		ctrl->last_phy_poll = now;
		for (i = 0; i < RECOVERY_LED_PORTS; i++) {
			int speed = recovery_led_phy_speed(ctrl, i);

			if (speed < 0) {
				ctrl->last_mdio_error = now;
				ctrl->mdio_fault = true;
				break;
			}

			ctrl->speed[i] = speed;
		}

		if (i == RECOVERY_LED_PORTS)
			ctrl->mdio_fault = false;
	}

	activity_ms = airoha_recovery_get_lan_activity_ms();
	activity = activity_ms && now - activity_ms <= RECOVERY_LED_ACTIVITY_MS;
	blink_on = !activity ||
		   ((now / RECOVERY_LED_BLINK_MS) & 1);

	for (i = 0; i < RECOVERY_LED_PORTS; i++) {
		recovery_led_set_pin(recovery_green_led_gpios[i],
				     ctrl->speed[i] == SPEED_1000 && blink_on);
		recovery_led_set_pin(recovery_yellow_led_gpios[i],
				     (ctrl->speed[i] == SPEED_10 ||
				      ctrl->speed[i] == SPEED_100) &&
					     blink_on);
	}
}

static const char *recovery_default_target(enum upload_target tgt)
{
	switch (tgt) {
	case TARGET_FIRMWARE:
		return "fit";
	case TARGET_UBOOT:
		return "uboot";
	}

	return "fit";
}

static const char *recovery_target_env(enum upload_target tgt)
{
	switch (tgt) {
	case TARGET_FIRMWARE:
		return "recovery_mtd";
	case TARGET_UBOOT:
		return "recovery_mtd_uboot";
	}

	return "recovery_mtd";
}

static const char *recovery_raw_env(enum upload_target tgt)
{
	switch (tgt) {
	case TARGET_FIRMWARE:
		return "recovery_dev";
	case TARGET_UBOOT:
		return "recovery_dev_uboot";
	}

	return "recovery_dev";
}

static const char *recovery_size_env(enum upload_target tgt)
{
	switch (tgt) {
	case TARGET_FIRMWARE:
		return "recovery_size";
	case TARGET_UBOOT:
		return "recovery_size_uboot";
	}

	return "recovery_size";
}

static ulong recovery_raw_offset(enum upload_target tgt)
{
	switch (tgt) {
	case TARGET_FIRMWARE:
		return env_get_hex("recovery_ofs", 0x050000);
	case TARGET_UBOOT:
		return env_get_hex("uboot_ofs",
				   RECOVERY_UBOOT_SLOT_DEFAULT_OFS);
	}

	return 0;
}

static const char *recovery_default_raw(enum upload_target tgt)
{
	switch (tgt) {
	case TARGET_UBOOT:
		return RECOVERY_UBOOT_SLOT_DEFAULT_DEV;
	case TARGET_FIRMWARE:
	default:
		return NULL;
	}
}

static unsigned long recovery_target_size_cap(enum upload_target tgt)
{
	ulong size_cap = env_get_hex(recovery_size_env(tgt), 0);

	if (tgt == TARGET_UBOOT &&
	    (!size_cap || size_cap > RECOVERY_MAX_UBOOT_SIZE))
		size_cap = RECOVERY_MAX_UBOOT_SIZE;

	return size_cap;
}

static const char *recovery_ubi_part(enum upload_target tgt)
{
	const char *part;

	if (tgt == TARGET_FIRMWARE && current_ubi_layout)
		return current_ubi_layout->part;

	switch (tgt) {
	case TARGET_UBOOT:
		part = env_get("recovery_ubi_part_uboot");
		break;
	case TARGET_FIRMWARE:
	default:
		part = env_get("recovery_ubi_part");
		break;
	}

	if (!part)
		part = env_get("recovery_ubi_part");

	return part ?: "ubi";
}

static int recovery_parse_upload_request(
	const char *uri, struct recovery_upload_request *request)
{
	struct xr1710g_recovery_upload_request parsed;
	int ret;

	if (!uri || !request)
		return -EINVAL;

	ret = xr1710g_recovery_parse_upload_uri(uri, RECOVERY_UI_BUILD,
						&parsed);
	if (ret)
		return ret;

	if (parsed.target == XR1710G_RECOVERY_UPLOAD_FIRMWARE) {
		request->target = TARGET_FIRMWARE;
		if ((unsigned int)parsed.layout >= ARRAY_SIZE(recovery_ubi_layouts))
			return -EINVAL;
		request->layout = &recovery_ubi_layouts[parsed.layout];
	} else {
		request->target = TARGET_UBOOT;
		request->layout = &recovery_ubi_layouts[0];
	}

	return 0;
}

static int recovery_validate_xr1710g_identity(const void *fdt)
{
	const char *model;
	int model_len;

	if (!fdt || fdt_check_header(fdt))
		return -ENOEXEC;

	model = fdt_getprop(fdt, 0, "model", &model_len);
	if (!model || model_len != sizeof("XR1710G") ||
	    memcmp(model, "XR1710G", sizeof("XR1710G"))) {
		printf("Device tree does not identify model XR1710G\n");
		return -ENODEV;
	}

	if (fdt_stringlist_search(fdt, 0, "compatible",
				  "econet,xr1710g-ubi") < 0 &&
	    fdt_stringlist_search(fdt, 0, "compatible",
				  "gemtek,xr1710g-ubi") < 0) {
		printf("Device tree is not compatible with XR1710G UBI\n");
		return -ENODEV;
	}

	return 0;
}

static int recovery_validate_partition_node(const void *fdt,
					    const char *label, u32 offset,
					    u32 size)
{
	const fdt32_t *reg;
	int search = -1;
	int match = -1;
	int matches = 0;
	int parent;
	int len;

	if (!label || !*label)
		return -EINVAL;

	while ((search = fdt_node_offset_by_prop_value(
			fdt, search, "label", label, strlen(label) + 1)) >= 0) {
		match = search;
		matches++;
	}
	if (search != -FDT_ERR_NOTFOUND || matches != 1) {
		printf("Device tree has %d exact '%s' partition matches\n",
		       matches, label);
		return -EINVAL;
	}

	parent = fdt_parent_offset(fdt, match);
	if (parent < 0 ||
	    fdt_node_check_compatible(fdt, parent, "fixed-partitions")) {
		printf("Partition '%s' is not in fixed-partitions\n", label);
		return -EINVAL;
	}

	reg = fdt_getprop(fdt, match, "reg", &len);
	if (!reg || len != 2 * sizeof(*reg) ||
	    fdt32_to_cpu(reg[0]) != offset || fdt32_to_cpu(reg[1]) != size) {
		printf("Partition '%s' does not match 0x%x+0x%x\n",
		       label, offset, size);
		return -EINVAL;
	}

	return 0;
}

static int recovery_validate_runtime_ubi_layout(
	const struct recovery_ubi_layout *layout, struct mtd_info *mtd)
{
	int ret;

	if (!recovery_machine_is_xr1710g() || !gd->fdt_blob || !layout || !mtd)
		return -ENODEV;

	ret = recovery_validate_xr1710g_identity(gd->fdt_blob);
	if (ret)
		return ret;

	ret = recovery_validate_partition_node(gd->fdt_blob, layout->part,
					       layout->offset, layout->size);
	if (ret)
		return ret;

	if (!mtd->name || strcmp(mtd->name, layout->part) ||
	    mtd->size != layout->size || mtd->offset != layout->offset ||
	    !mtd->parent || !mtd->parent->name ||
	    strcmp(mtd->parent->name, RECOVERY_UBOOT_SLOT_DEFAULT_DEV)) {
		printf("Runtime MTD '%s' does not match XR1710G UBI %s layout\n",
		       mtd->name ?: "(null)", layout->version);
		return -EINVAL;
	}

	if (!(mtd->flags & MTD_WRITEABLE) || !mtd->erasesize ||
	    layout->offset % mtd->erasesize || layout->size % mtd->erasesize) {
		printf("Runtime MTD '%s' is not safely writable/aligned\n",
		       layout->part);
		return -EROFS;
	}

	return 0;
}

static int recovery_validate_runtime_uboot_slot(struct mtd_info *mtd)
{
	int ret;

	if (!recovery_machine_is_xr1710g() || !gd->fdt_blob || !mtd)
		return -ENODEV;

	ret = recovery_validate_xr1710g_identity(gd->fdt_blob);
	if (ret)
		return ret;

	ret = recovery_validate_partition_node(gd->fdt_blob,
					       RECOVERY_CHAINLOADER_PART,
					       RECOVERY_UBOOT_SLOT_DEFAULT_OFS,
					       RECOVERY_MAX_UBOOT_SIZE);
	if (ret)
		return ret;

	if (!mtd->name || strcmp(mtd->name, RECOVERY_UBOOT_SLOT_DEFAULT_DEV) ||
	    mtd->parent ||
	    mtd->size < RECOVERY_UBOOT_SLOT_DEFAULT_OFS +
			RECOVERY_MAX_UBOOT_SIZE ||
	    !(mtd->flags & MTD_WRITEABLE) || !mtd->erasesize ||
	    RECOVERY_UBOOT_SLOT_DEFAULT_OFS % mtd->erasesize ||
	    RECOVERY_MAX_UBOOT_SIZE % mtd->erasesize) {
		printf("Runtime MTD is not the fixed XR1710G U-Boot slot device\n");
		return -EINVAL;
	}

	return 0;
}

static int recovery_select_ubi(const char *part)
{
	struct ubi_device *ubi;
	bool selected = false;
	int ret;

	if (!IS_ENABLED(CONFIG_CMD_UBI) || !IS_ENABLED(CONFIG_MTD_UBI))
		return -ENODEV;

	ubi = ubi_get_device(0);
	if (ubi) {
		selected = ubi->mtd && !strcmp(ubi->mtd->name, part);
		ubi_put_device(ubi);
	}
	if (selected)
		return 0;

	if (recovery_ubi_attach_error)
		return recovery_ubi_attach_error;

	ret = ubi_part((char *)part, NULL);
	if (ret)
		recovery_ubi_attach_error = ret;

	return ret;
}

static int recovery_try_ubi_target(enum upload_target tgt,
				       struct recovery_target *target)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_volume_desc *desc;
	struct ubi_device *ubi;
	struct mtd_info *mtd;
	const char *volume = env_get(recovery_target_env(tgt));
	const char *part = recovery_ubi_part(tgt);

	if (!volume)
		volume = recovery_default_target(tgt);

	if (recovery_select_ubi(part)) {
		mtd_probe_devices();
		mtd = get_mtd_device_nm(part);
		if (IS_ERR_OR_NULL(mtd))
			return -ENODEV;

		target->backend = RECOVERY_BACKEND_UBI;
		target->name = volume;
		target->ubi_part = part;
		target->mtd = mtd;
		target->cur_size = 0;
		target->limit = mtd->size;
		target->ubi_needs_format = true;
		return 0;
	}

	desc = ubi_open_volume_nm(0, volume, UBI_READWRITE);
	if (IS_ERR_OR_NULL(desc)) {
		ubi = ubi_get_device(0);
		if (!ubi)
			return -ENODEV;

		target->backend = RECOVERY_BACKEND_UBI;
		target->name = volume;
		target->ubi_part = part;
		target->ubi_needs_format = false;
		target->cur_size = 0;
		target->limit = (unsigned long long)ubi->avail_pebs *
			(unsigned long long)ubi->leb_size;
		ubi_put_device(ubi);
		return 0;
	}

	target->backend = RECOVERY_BACKEND_UBI;
	target->name = volume;
	target->ubi_part = part;
	target->ubi_needs_format = false;
	target->cur_size = (unsigned long long)desc->vol->reserved_pebs *
			   (unsigned long long)desc->vol->usable_leb_size;
	target->limit = (unsigned long long)(desc->vol->reserved_pebs +
					     desc->vol->ubi->avail_pebs) *
			(unsigned long long)desc->vol->usable_leb_size;

	ubi_close_volume(desc);
	return 0;
#else
	return -ENODEV;
#endif
}

static int recovery_resolve_xr1710g_target(enum upload_target tgt,
					   struct recovery_target *target)
{
	struct mtd_info *mtd;
	int ret;

	mtd_probe_devices();

	switch (tgt) {
	case TARGET_FIRMWARE:
		if (!current_ubi_layout)
			return -EINVAL;

		mtd = get_mtd_device_nm(current_ubi_layout->part);
		if (IS_ERR_OR_NULL(mtd))
			return IS_ERR(mtd) ? PTR_ERR(mtd) : -ENODEV;

		ret = recovery_validate_runtime_ubi_layout(current_ubi_layout, mtd);
		if (ret) {
			put_mtd_device(mtd);
			return ret;
		}

		/*
		 * A system clean-install always rebuilds the selected XR1710G UBI
		 * partition and writes a volume named "fit". Saved recovery_* values
		 * are never policy for this target.
		 */
		target->backend = RECOVERY_BACKEND_UBI;
		target->name = "fit";
		target->ubi_part = current_ubi_layout->part;
		target->mtd = mtd;
		target->cur_size = 0;
		target->limit = current_ubi_layout->size;
		target->ubi_needs_format = true;
		return 0;

	case TARGET_UBOOT:
		/*
		 * The XR1710G Chainloader occupies one immutable 1 MiB raw slot.
		 * Never trust old uboot_ofs/recovery_dev_uboot variables here.
		 */
		mtd = get_mtd_device_nm(RECOVERY_UBOOT_SLOT_DEFAULT_DEV);
		if (IS_ERR_OR_NULL(mtd))
			return IS_ERR(mtd) ? PTR_ERR(mtd) : -ENODEV;

		ret = recovery_validate_runtime_uboot_slot(mtd);
		if (ret) {
			put_mtd_device(mtd);
			return ret;
		}

		target->backend = RECOVERY_BACKEND_MTD;
		target->name = RECOVERY_UBOOT_SLOT_DEFAULT_DEV;
		target->mtd = mtd;
		target->ofs = RECOVERY_UBOOT_SLOT_DEFAULT_OFS;
		target->limit = RECOVERY_MAX_UBOOT_SIZE;
		target->cur_size = RECOVERY_MAX_UBOOT_SIZE;
		return 0;
	}

	return -EINVAL;
}

static int recovery_resolve_target(enum upload_target tgt,
				   struct recovery_target *target)
{
	const char *name = env_get(recovery_target_env(tgt));
	const char *raw;
	struct mtd_info *mtd;
	ulong ofs;

	memset(target, 0, sizeof(*target));
	if (recovery_machine_is_xr1710g())
		return recovery_resolve_xr1710g_target(tgt, target);

	if (!name)
		name = recovery_default_target(tgt);

	mtd_probe_devices();

	raw = env_get(recovery_raw_env(tgt));
	if (!raw || !*raw)
		raw = recovery_default_raw(tgt);
	if (raw && *raw) {
		mtd = get_mtd_device_nm(raw);
		if (!IS_ERR_OR_NULL(mtd)) {
			ulong size_cap = recovery_target_size_cap(tgt);

			ofs = recovery_raw_offset(tgt);
			target->backend = RECOVERY_BACKEND_MTD;
			target->name = raw;
			target->mtd = mtd;
			target->ofs = ofs;
			target->limit = mtd->size;
			if (ofs && target->limit > ofs)
				target->limit -= ofs;
			if (size_cap && target->limit > size_cap)
				target->limit = size_cap;
			target->cur_size = target->limit;
			return 0;
		}
	}

	/*
	 * The XR1710G U-Boot upload target is the raw chainloader slot. Do
	 * not silently fall back to an MTD/UBI volume named "uboot"; old saved
	 * environments may lack recovery_dev_uboot, and writing there makes the
	 * browser report success while the first-stage loader still reads stale
	 * or invalid bytes from 0x600000/0x602100.
	 */
	if (tgt == TARGET_UBOOT)
		return -ENODEV;

	mtd = get_mtd_device_nm(name);
	if (!IS_ERR_OR_NULL(mtd)) {
		target->backend = RECOVERY_BACKEND_MTD;
		target->name = name;
		target->mtd = mtd;
		target->limit = mtd->size;
		target->cur_size = target->limit;
		return 0;
	}

	if (!recovery_try_ubi_target(tgt, target))
		return 0;

	if (!raw) {
		switch (tgt) {
		case TARGET_FIRMWARE:
			raw = "nor0";
			break;
		case TARGET_UBOOT:
			raw = env_get("recovery_dev");
			if (!raw)
				raw = "nor0";
			break;
		}
	}

	mtd = get_mtd_device_nm(raw);
	if (IS_ERR_OR_NULL(mtd))
		return -ENODEV;

	ofs = recovery_raw_offset(tgt);
	target->backend = RECOVERY_BACKEND_MTD;
	target->name = raw;
	target->mtd = mtd;
	target->ofs = ofs;
	target->limit = mtd->size;
	if (ofs && target->limit > ofs)
		target->limit -= ofs;
	{
		ulong size_cap = recovery_target_size_cap(tgt);

		if (size_cap && target->limit > size_cap)
			target->limit = size_cap;
	}
	target->cur_size = target->limit;

	return 0;
}

static void recovery_release_target(struct recovery_target *target)
{
	if (target->mtd)
		put_mtd_device(target->mtd);

	target->mtd = NULL;
}

static int recovery_force_ubi_rebuild(struct recovery_target *target)
{
	struct mtd_info *mtd;
	int ret;

	if (target->backend != RECOVERY_BACKEND_UBI || !target->ubi_part)
		return -EINVAL;
	if (recovery_machine_is_xr1710g() &&
	    (!current_ubi_layout ||
	     strcmp(target->ubi_part, current_ubi_layout->part)))
		return -EINVAL;

	ubi_detach();
	recovery_ubi_attach_error = 0;
	if (target->mtd) {
		put_mtd_device(target->mtd);
		target->mtd = NULL;
	}

	mtd_probe_devices();
	mtd = get_mtd_device_nm(target->ubi_part);
	if (IS_ERR_OR_NULL(mtd))
		return IS_ERR(mtd) ? PTR_ERR(mtd) : -ENODEV;

	if (recovery_machine_is_xr1710g()) {
		ret = recovery_validate_runtime_ubi_layout(current_ubi_layout, mtd);
		if (ret) {
			put_mtd_device(mtd);
			return ret;
		}
	}

	target->mtd = mtd;
	target->cur_size = 0;
	target->limit = recovery_machine_is_xr1710g() ?
		current_ubi_layout->size : mtd->size;
	target->ubi_needs_format = true;

	return 0;
}

static void recovery_service_runtime(struct recovery_status_led_ctrl *status_leds)
{
	struct udevice *udev = eth_get_dev();
	struct netif *netif = net_lwip_get_netif();

	if (udev && netif)
		net_lwip_rx(udev, netif);
	recovery_status_led_poll(status_leds);
	WATCHDOG_RESET();
}

static void recovery_record_validation_result(
	const struct xr1710g_recovery_validation_result *result)
{
	if (!result)
		return;

	recovery_validation_step(result->detail, result->component);
}

static int recovery_validate_dtb_layout(
	const void *fdt, const struct recovery_ubi_layout *layout)
{
	int ret;

	ret = recovery_validate_xr1710g_identity(fdt);
	if (ret)
		return ret;

	return recovery_validate_partition_node(fdt, layout->part,
						layout->offset, layout->size);
}

static int recovery_validate_firmware_fit(
	const void *image, size_t image_size,
	const struct recovery_ubi_layout *layout)
{
	struct xr1710g_recovery_validation_result validation;
	struct xr1710g_recovery_fit_component kernel;
	struct xr1710g_recovery_fit_component fdt;
	struct xr1710g_recovery_fit_component rootfs;
	const char *config_name;
	const char *kernel_name;
	const char *fdt_name;
	const char *rootfs_name;
	u32 fit_size;
	int images_node;
	int configs_node;
	int config_node;
	int image_count = 0;
	int config_count = 0;
	int node;
	int ret;

	xr1710g_recovery_validation_result_init(&validation);

	if (!recovery_machine_is_xr1710g()) {
		printf("System clean-install is restricted to XR1710G hardware\n");
		return -ENODEV;
	}

	if (!layout || image_size < RECOVERY_MIN_FIRMWARE_SIZE)
		return -EINVAL;

	ret = fdt_check_header(image);
	if (ret) {
		printf("System image is not a FIT: %s\n", fdt_strerror(ret));
		return -ENOEXEC;
	}

	fit_size = fdt_totalsize(image);
	if (fit_size > image_size || fdt_check_full(image, fit_size)) {
		printf("System FIT header is truncated or malformed\n");
		return -EBADMSG;
	}

	ret = fit_check_format(image, fit_size);
	if (ret) {
		printf("System FIT structure check failed: %d\n", ret);
		return ret;
	}

	images_node = fdt_path_offset(image, FIT_IMAGES_PATH);
	configs_node = fdt_path_offset(image, FIT_CONFS_PATH);
	if (images_node < 0 || configs_node < 0)
		return -ENOENT;

	ret = xr1710g_recovery_fdt_get_single_string(
		image, configs_node, FIT_DEFAULT_PROP, &config_name, &validation);
	if (ret) {
		recovery_record_validation_result(&validation);
		return ret;
	}

	fdt_for_each_subnode(node, image, configs_node)
		config_count++;
	if (config_count != 1) {
		printf("System FIT must contain exactly one configuration (%d found)\n",
		       config_count);
		return -EINVAL;
	}

	config_node = xr1710g_recovery_fdt_find_exact_subnode(
		image, configs_node, config_name);
	if (config_node < 0)
		return config_node;

	ret = xr1710g_recovery_fdt_get_single_string(
		image, config_node, FIT_KERNEL_PROP, &kernel_name, &validation);
	if (ret) {
		recovery_record_validation_result(&validation);
		return ret;
	}
	ret = xr1710g_recovery_fdt_get_single_string(
		image, config_node, FIT_FDT_PROP, &fdt_name, &validation);
	if (ret) {
		recovery_record_validation_result(&validation);
		return ret;
	}
	ret = xr1710g_recovery_fdt_get_single_string(
		image, config_node, FIT_LOADABLE_PROP, &rootfs_name,
		&validation);
	if (ret) {
		recovery_record_validation_result(&validation);
		return ret;
	}
	if (fdt_getprop(image, config_node, FIT_RAMDISK_PROP, NULL) ||
	    fdt_getprop(image, config_node, FIT_FIRMWARE_PROP, NULL)) {
		printf("Initramfs/firmware-loader FIT images cannot be installed\n");
		return -EINVAL;
	}
	if (!strcmp(kernel_name, fdt_name) || !strcmp(kernel_name, rootfs_name) ||
	    !strcmp(fdt_name, rootfs_name)) {
		printf("System FIT component references are ambiguous\n");
		return -EINVAL;
	}

	fdt_for_each_subnode(node, image, images_node)
		image_count++;
	if (image_count != 3) {
		printf("System FIT must contain exactly kernel, DT and rootfs (%d found)\n",
		       image_count);
		return -EINVAL;
	}

	ret = xr1710g_recovery_fit_get_component(
		image, image_size, images_node, kernel_name, IH_TYPE_KERNEL,
		true, &kernel, &validation);
	if (ret) {
		recovery_record_validation_result(&validation);
		return ret;
	}
	ret = xr1710g_recovery_fit_get_component(
		image, image_size, images_node, fdt_name, IH_TYPE_FLATDT,
		false, &fdt, &validation);
	if (ret) {
		recovery_record_validation_result(&validation);
		return ret;
	}
	ret = xr1710g_recovery_fit_get_component(
		image, image_size, images_node, rootfs_name, IH_TYPE_FILESYSTEM,
		false, &rootfs, &validation);
	if (ret) {
		recovery_record_validation_result(&validation);
		return ret;
	}

	if (xr1710g_recovery_fit_components_overlap(&kernel, &fdt) ||
	    xr1710g_recovery_fit_components_overlap(&kernel, &rootfs) ||
	    xr1710g_recovery_fit_components_overlap(&fdt, &rootfs)) {
		printf("System FIT component payloads overlap\n");
		return -EINVAL;
	}

	if (fdt.size < sizeof(struct fdt_header) || fdt_check_header(fdt.data) ||
	    fdt_totalsize(fdt.data) > fdt.size ||
	    fdt_check_full(fdt.data, fdt_totalsize(fdt.data))) {
		printf("Embedded XR1710G DT is truncated or malformed\n");
		return -EBADMSG;
	}

	ret = recovery_validate_dtb_layout(fdt.data, layout);
	if (ret)
		return ret;

	printf("Validated XR1710G system FIT for UBI %s (%s)\n",
	       layout->version, layout->part);
	return 0;
}

static int recovery_ensure_ubi_volume_named(const char *name, size_t size,
					    int vol_type);

static int recovery_clear_uboot_environments(const char *part)
{
	u8 *ff;
	int ret;

	if (!part || !*part)
		return -EINVAL;

	ret = recovery_select_ubi(part);
	if (ret)
		return ret;

	ret = recovery_ensure_ubi_volume_named("ubootenv",
					       RECOVERY_UBOOTENV_SIZE,
					       UBI_DYNAMIC_VOLUME);
	if (ret)
		return ret;

	ret = recovery_ensure_ubi_volume_named("ubootenv2",
					       RECOVERY_UBOOTENV_SIZE,
					       UBI_DYNAMIC_VOLUME);
	if (ret)
		return ret;

	/*
	 * env_erase() cannot work here: the UBI env driver registers its
	 * erase hook only after a successful env_init(), and the recovery
	 * console never attaches UBI early enough for that (-ENODEV). Write
	 * 0xff over both volumes instead - the env layer treats it as an
	 * erased environment and falls back to defaults.
	 */
	ff = malloc(RECOVERY_UBOOTENV_SIZE);
	if (!ff)
		return -ENOMEM;
	memset(ff, 0xff, RECOVERY_UBOOTENV_SIZE);

	ret = ubi_volume_write("ubootenv", ff, 0, RECOVERY_UBOOTENV_SIZE);
	if (!ret)
		ret = ubi_volume_write("ubootenv2", ff, 0,
				       RECOVERY_UBOOTENV_SIZE);

	free(ff);
	if (ret)
		printf("Failed to clear U-Boot environments: %d\n", ret);
	return ret;
}

static int recovery_read_mtd_exact(const char *name, size_t offset,
				   size_t size, void *buf)
{
	struct mtd_info *mtd;
	size_t retlen = 0;
	int ret;

	mtd_probe_devices();
	mtd = get_mtd_device_nm(name);
	if (IS_ERR_OR_NULL(mtd))
		return IS_ERR(mtd) ? PTR_ERR(mtd) : -ENODEV;

	if (offset > mtd->size || size > mtd->size - offset) {
		put_mtd_device(mtd);
		return -EFBIG;
	}

	ret = mtd_read(mtd, offset, size, &retlen, buf);
	put_mtd_device(mtd);
	if (ret && ret != -EUCLEAN)
		return ret;
	if (retlen != size)
		return -EIO;

	return 0;
}

static int recovery_dsd_get_var(const char *buf, size_t len,
				const char *key, char *value,
				size_t value_len)
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

static int recovery_mac_hex_nibble(char ch)
{
	if (ch >= '0' && ch <= '9')
		return ch - '0';
	if (ch >= 'a' && ch <= 'f')
		return ch - 'a' + 10;
	if (ch >= 'A' && ch <= 'F')
		return ch - 'A' + 10;

	return -EINVAL;
}

static int recovery_parse_canonical_mac(const char *text, u8 *mac)
{
	size_t i;

	if (!text || !mac || strlen(text) != ARP_HLEN_ASCII)
		return -EINVAL;

	for (i = 0; i < ARP_HLEN; i++) {
		size_t pos = i * 3;
		int hi = recovery_mac_hex_nibble(text[pos]);
		int lo = recovery_mac_hex_nibble(text[pos + 1]);

		if (hi < 0 || lo < 0 ||
		    (i + 1 < ARP_HLEN && text[pos + 2] != ':'))
			return -EINVAL;

		mac[i] = (hi << 4) | lo;
	}

	return is_valid_ethaddr(mac) ? 0 : -EINVAL;
}

static int recovery_read_dsd_macs(u8 *lan_mac, u8 *wan_mac)
{
	char lan_str[ARP_HLEN_ASCII + 1];
	char wan_str[ARP_HLEN_ASCII + 1];
	char *env;
	int ret;

	env = malloc(RECOVERY_DSD_ENV_SIZE + 1);
	if (!env)
		return -ENOMEM;

	ret = recovery_read_mtd_exact(RECOVERY_VENDOR_PART,
				      RECOVERY_DSD_OFFSET,
				      RECOVERY_DSD_ENV_SIZE, env);
	if (ret)
		goto out;
	env[RECOVERY_DSD_ENV_SIZE] = '\0';

	ret = recovery_dsd_get_var(env, RECOVERY_DSD_ENV_SIZE, "lan_mac=",
				   lan_str, sizeof(lan_str));
	if (ret)
		goto out;
	ret = recovery_dsd_get_var(env, RECOVERY_DSD_ENV_SIZE, "wan_mac=",
				   wan_str, sizeof(wan_str));
	if (ret)
		goto out;

	ret = recovery_parse_canonical_mac(lan_str, lan_mac);
	if (ret)
		goto out;
	ret = recovery_parse_canonical_mac(wan_str, wan_mac);

out:
	free(env);
	return ret;
}

static void recovery_clear_factory_cache(void)
{
	free(recovery_factory_cache);
	recovery_factory_cache = NULL;
	recovery_factory_cache_size = 0;
}

static int recovery_preflight_factory_source(void)
{
	u8 *lan_mac;
	u8 *wan_mac;
	int ret;

	if (!recovery_machine_is_xr1710g())
		return -ENODEV;

	recovery_clear_factory_cache();
	recovery_factory_cache = malloc(RECOVERY_FACTORY_SIZE);
	if (!recovery_factory_cache)
		return -ENOMEM;
	recovery_factory_cache_size = RECOVERY_FACTORY_SIZE;
	memset(recovery_factory_cache, 0xff, recovery_factory_cache_size);

	ret = recovery_read_mtd_exact(
		RECOVERY_VENDOR_PART, RECOVERY_DSD_EEPROM_OFFSET,
		RECOVERY_DSD_EEPROM_SIZE,
		recovery_factory_cache + RECOVERY_FACTORY_EEPROM_OFFSET);
	if (ret)
		goto fail;
	if (recovery_factory_cache[RECOVERY_FACTORY_EEPROM_OFFSET] != 0x90 ||
	    recovery_factory_cache[RECOVERY_FACTORY_EEPROM_OFFSET + 1] != 0x79) {
		printf("DSD Wi-Fi EEPROM source has invalid MT7996 magic\n");
		ret = -EBADMSG;
		goto fail;
	}

	lan_mac = recovery_factory_cache + RECOVERY_FACTORY_LAN_MAC_OFFSET;
	wan_mac = recovery_factory_cache + RECOVERY_FACTORY_WAN_MAC_OFFSET;
	ret = recovery_read_dsd_macs(lan_mac, wan_mac);
	if (ret) {
		printf("DSD Ethernet address source is missing or invalid: %d\n", ret);
		goto fail;
	}
	if (!memcmp(lan_mac, wan_mac, ARP_HLEN)) {
		printf("DSD Ethernet address sources collide; refusing Factory rebuild\n");
		ret = -EINVAL;
		goto fail;
	}

	printf("Cached and validated the complete read-only DSD Factory source before destructive UBI rebuild\n");
	return 0;

fail:
	recovery_clear_factory_cache();
	return ret;
}

static int recovery_verify_factory_part(const char *part)
{
	u8 *have;
	size_t span = RECOVERY_FACTORY_LAN_MAC_OFFSET + ARP_HLEN;
	int ret;

	if (!part || !*part || !recovery_machine_is_xr1710g() ||
	    !recovery_factory_cache ||
	    recovery_factory_cache_size != RECOVERY_FACTORY_SIZE)
		return -EINVAL;

	/* One 24 KiB read covers all three key regions (EEPROM + both
	 * MACs). The earlier 2 x 1 MiB read-back buffers exhausted the
	 * heap right after the system write (-ENOMEM) and stalled the
	 * flow at 95%. Full-image compares are also wrong: healthy NAND
	 * bit-flips must not fail the check. */
	have = malloc(span);
	if (!have)
		return -ENOMEM;

	ret = recovery_select_ubi(part);
	if (ret)
		goto out;

	ret = ubi_volume_read("factory", (char *)have, 0, span);
	if (ret && ret != -EUCLEAN)
		goto out;

	if (memcmp(have + RECOVERY_FACTORY_EEPROM_OFFSET,
		   recovery_factory_cache + RECOVERY_FACTORY_EEPROM_OFFSET,
		   RECOVERY_DSD_EEPROM_SIZE) ||
	    memcmp(have + RECOVERY_FACTORY_WAN_MAC_OFFSET,
		   recovery_factory_cache + RECOVERY_FACTORY_WAN_MAC_OFFSET,
		   ARP_HLEN) ||
	    memcmp(have + RECOVERY_FACTORY_LAN_MAC_OFFSET,
		   recovery_factory_cache + RECOVERY_FACTORY_LAN_MAC_OFFSET,
		   ARP_HLEN)) {
		printf("Factory read-back does not match per-device DSD data\n");
		ret = -EIO;
		goto out;
	}

	printf("Factory read-back matches DSD EEPROM and Ethernet addresses\n");
	ret = 0;

out:
	free(have);
	return ret;
}

static int recovery_sync_and_verify_factory(const char *part)
{
	int ret;

	if (!part || !*part || !recovery_factory_cache ||
	    recovery_factory_cache_size != RECOVERY_FACTORY_SIZE)
		return -EINVAL;

	ret = recovery_select_ubi(part);
	if (ret)
		return ret;

	prog_flash_mutated = true;
	ret = ubi_volume_write("factory", recovery_factory_cache, 0,
			       recovery_factory_cache_size);
	if (ret)
		return ret;

	return recovery_verify_factory_part(part);
}

static bool recovery_mtd_is_block_aligned(struct mtd_info *mtd, u64 value)
{
	return mtd->erasesize && !(value % mtd->erasesize);
}

static int recovery_mtd_validate_region(struct mtd_info *mtd, loff_t ofs,
					size_t len)
{
	if (!mtd || !mtd->erasesize)
		return -EINVAL;

	if (!len)
		return 0;

	if (ofs < 0 || ofs >= mtd->size ||
	    (u64)len > (u64)(mtd->size - ofs)) {
		printf("MTD region 0x%llx..+0x%lx is outside '%s' size 0x%llx\n",
		       (unsigned long long)ofs, (unsigned long)len,
		       mtd->name, (unsigned long long)mtd->size);
		return -EINVAL;
	}

	if (!recovery_mtd_is_block_aligned(mtd, ofs) ||
	    !recovery_mtd_is_block_aligned(mtd, len)) {
		printf("MTD region 0x%llx..+0x%lx is not eraseblock aligned (0x%x)\n",
		       (unsigned long long)ofs, (unsigned long)len,
		       mtd->erasesize);
		return -EINVAL;
	}

	return 0;
}

static void recovery_update_erase_progress(loff_t done)
{
	prog_erase_done = done > prog_erase_total ? prog_erase_total : done;
	prog_done = prog_erase_done + prog_write_done;
}

static void recovery_ubi_progress(struct ubi_volume *vol, int done, int total)
{
	unsigned long long bytes_done = prog_erase_volume_base;

	(void)vol;

	if (total > 0)
		bytes_done += (prog_erase_volume_bytes * (unsigned long long)done) /
			      (unsigned long long)total;

	if (bytes_done > prog_erase_total)
		bytes_done = prog_erase_total;

	prog_erase_done = bytes_done;
	prog_done = prog_erase_done + prog_write_done;

	if (prog_status_leds)
		recovery_service_runtime(prog_status_leds);
}

static int recovery_erase_mtd_region(struct mtd_info *mtd, loff_t ofs,
				     size_t len,
				     bool allow_bad_blocks,
				     struct recovery_status_led_ctrl *status_leds)
{
	struct erase_info ei = { 0 };
	int ret;

	if (!mtd || !len)
		return 0;

	ret = recovery_mtd_validate_region(mtd, ofs, len);
	if (ret)
		return ret;

	ei.addr = ofs;
	ei.len = len;

	ret = mtd_unlock(mtd, ei.addr, ei.len);
	if (ret && ret != -EOPNOTSUPP) {
		printf("Warning: initial mtd_unlock 0x%llx..+0x%llx failed: %d\n",
		       (unsigned long long)ei.addr,
		       (unsigned long long)ei.len, ret);
	}

	for (loff_t addr = 0; addr < len; addr += mtd->erasesize) {
		struct erase_info e = {
			.addr = ofs + addr,
			.len = mtd->erasesize,
		};
		ret = mtd_block_isbad(mtd, e.addr);
		if (ret < 0) {
			printf("Failed to query bad block at 0x%llx: %d\n",
			       (unsigned long long)e.addr, ret);
			return ret;
		}
		if (ret > 0) {
			if (!allow_bad_blocks) {
				printf("Refusing to shift a fixed-slot image past bad block 0x%llx\n",
				       (unsigned long long)e.addr);
				return -EIO;
			}
			printf("Skipping bad block at 0x%llx\n",
			       (unsigned long long)e.addr);
			recovery_update_erase_progress(addr + mtd->erasesize);
			recovery_service_runtime(status_leds);
			continue;
		}

		/* From this point a failure can leave the flash partially changed. */
		prog_flash_mutated = true;
		ret = mtd_erase(mtd, &e);

		if (ret) {
			printf("mtd_erase failed at 0x%llx: %d\n",
			       (unsigned long long)e.addr, ret);
			return ret;
		}

		recovery_update_erase_progress(addr + mtd->erasesize);
		recovery_service_runtime(status_leds);
	}

	return 0;
}

struct recovery_slot_mtd_context {
	struct mtd_info *mtd;
	struct recovery_status_led_ctrl *status_leds;
};

static int recovery_slot_mtd_is_bad(void *ctx, unsigned long long addr)
{
	struct recovery_slot_mtd_context *slot = ctx;

	return mtd_block_isbad(slot->mtd, addr);
}

static int recovery_slot_mtd_erase(void *ctx, unsigned long long addr,
				   size_t len)
{
	struct recovery_slot_mtd_context *slot = ctx;
	struct erase_info erase = {
		.addr = addr,
		.len = len,
	};

	return mtd_erase(slot->mtd, &erase);
}

static int recovery_slot_mtd_write(void *ctx, unsigned long long addr,
				   const void *buf, size_t len,
				   size_t *retlen)
{
	struct recovery_slot_mtd_context *slot = ctx;

	prog_phase = RECOVERY_PHASE_WRITE;
	return mtd_write(slot->mtd, addr, len, retlen, buf);
}

static int recovery_slot_mtd_read(void *ctx, unsigned long long addr,
				  void *buf, size_t len, size_t *retlen)
{
	struct recovery_slot_mtd_context *slot = ctx;
	int ret;

	ret = mtd_read(slot->mtd, addr, len, retlen, buf);
	return ret == -EUCLEAN ? 0 : ret;
}

static void recovery_slot_mtd_mutated(void *ctx)
{
	(void)ctx;
	prog_flash_mutated = true;
}

static void recovery_slot_mtd_erase_progress(void *ctx, size_t done)
{
	(void)ctx;
	recovery_update_erase_progress(done);
}

static void recovery_slot_mtd_write_progress(void *ctx, size_t done)
{
	(void)ctx;
	prog_write_done = done;
	prog_done = prog_erase_done + prog_write_done;
}

static void recovery_slot_mtd_service(void *ctx)
{
	struct recovery_slot_mtd_context *slot = ctx;

	recovery_service_runtime(slot->status_leds);
}

static const struct xr1710g_recovery_mtd_ops recovery_slot_mtd_ops = {
	.is_bad = recovery_slot_mtd_is_bad,
	.erase = recovery_slot_mtd_erase,
	.write = recovery_slot_mtd_write,
	.read = recovery_slot_mtd_read,
	.mutated = recovery_slot_mtd_mutated,
	.erase_progress = recovery_slot_mtd_erase_progress,
	.write_progress = recovery_slot_mtd_write_progress,
	.service = recovery_slot_mtd_service,
};

static const char *recovery_slot_mtd_error_stage(
	enum xr1710g_recovery_mtd_stage stage)
{
	switch (stage) {
	case XR1710G_MTD_STAGE_PREFLIGHT:
		return "bad-block";
	case XR1710G_MTD_STAGE_ERASE:
		return "erase";
	case XR1710G_MTD_STAGE_WRITE:
		return "write";
	case XR1710G_MTD_STAGE_WRITE_READBACK:
	case XR1710G_MTD_STAGE_FINAL_READBACK:
		return "readback";
	case XR1710G_MTD_STAGE_ARGUMENT:
	case XR1710G_MTD_STAGE_DONE:
	default:
		return "transaction";
	}
}

static int recovery_rewrite_mtd_slot(
	struct mtd_info *mtd, loff_t ofs, size_t region_len,
	const void *image, size_t image_size,
	struct recovery_status_led_ctrl *status_leds,
	enum xr1710g_recovery_mtd_stage *stage)
{
	struct recovery_slot_mtd_context ctx = {
		.mtd = mtd,
		.status_leds = status_leds,
	};
	u8 *scratch;
	int ret;

	ret = recovery_mtd_validate_region(mtd, ofs, region_len);
	if (ret)
		return ret;
	ret = mtd_unlock(mtd, ofs, region_len);
	if (ret && ret != -EOPNOTSUPP)
		return ret;

	scratch = malloc_cache_aligned(mtd->erasesize);
	if (!scratch)
		return -ENOMEM;
	ret = xr1710g_recovery_mtd_rewrite_verified(
		&recovery_slot_mtd_ops, &ctx, ofs, region_len, mtd->erasesize,
		image, image_size, scratch, mtd->erasesize, stage);
	free(scratch);

	return ret;
}

static bool recovery_preserve_ubi_volume(const char *name)
{
	if (!name || !*name)
		return true;

	if (!strcmp(name, "ubootenv") || !strcmp(name, "ubootenv2"))
		return true;

	if (of_machine_is_compatible("econet,xr1710g") ||
	    of_machine_is_compatible("econet,xr1710g-ubi") ||
	    of_machine_is_compatible("gemtek,xr1710g") ||
	    of_machine_is_compatible("gemtek,xr1710g-ubi"))
		return !strcmp(name, "factory");

	if (of_machine_is_compatible("gemtek,w1700k") ||
	    of_machine_is_compatible("gemtek,w1700k-ubi"))
		return !strcmp(name, "factory");

	return false;
}

static unsigned long long recovery_div_round_up_u64(unsigned long long value,
						     unsigned long long divisor)
{
	return value / divisor + !!(value % divisor);
}

static int recovery_count_bad_pebs(struct mtd_info *mtd, u64 region_size,
				   u64 *bad_pebs)
{
	u64 count = 0;
	u64 addr;
	int ret;

	if (!mtd || !bad_pebs || !mtd->erasesize ||
	    region_size > mtd->size || region_size % mtd->erasesize)
		return -EINVAL;

	if (!mtd_can_have_bb(mtd)) {
		*bad_pebs = 0;
		return 0;
	}

	for (addr = 0; addr < region_size; addr += mtd->erasesize) {
		ret = mtd_block_isbad(mtd, addr);
		if (ret < 0)
			return ret;
		if (ret > 0)
			count++;
		WATCHDOG_RESET();
	}

	*bad_pebs = count;
	return 0;
}

static int recovery_calc_fresh_xr1710g_ubi_limit(
	struct recovery_target *target, unsigned long long *limit)
{
	struct mtd_info *mtd;
	unsigned long long device_pebs;
	unsigned long long bad_limit;
	unsigned long long bad_reserve;
	unsigned long long bad_pebs;
	unsigned long long good_pebs;
	unsigned long long peb_count;
	unsigned long long reserved_pebs;
	unsigned long long required_volume_pebs;
	unsigned long long hdr_min_io;
	unsigned long long ec_hdr_aligned;
	unsigned long long leb_start;
	unsigned long long leb_size;
	unsigned int beb_limit_per_1024 = 20;
	int ret;

	if (!target || !limit || target->backend != RECOVERY_BACKEND_UBI ||
	    !target->mtd)
		return -EINVAL;

	mtd = target->mtd;
	if (!mtd->erasesize || !mtd->writesize ||
	    target->limit > mtd->size || target->limit % mtd->erasesize)
		return -EINVAL;

#ifdef CONFIG_MTD_UBI_BEB_LIMIT
	beb_limit_per_1024 = CONFIG_MTD_UBI_BEB_LIMIT;
#endif

	hdr_min_io = mtd->writesize >> mtd->subpage_sft;
	if (!hdr_min_io)
		return -EINVAL;
	ec_hdr_aligned = ALIGN(UBI_EC_HDR_SIZE, hdr_min_io);
	leb_start = ALIGN(ec_hdr_aligned + UBI_VID_HDR_SIZE, mtd->writesize);
	if (leb_start >= mtd->erasesize)
		return -EINVAL;
	leb_size = mtd->erasesize - leb_start;

	peb_count = target->limit / mtd->erasesize;
	ret = recovery_count_bad_pebs(mtd, target->limit, &bad_pebs);
	if (ret)
		return ret;
	if (bad_pebs >= peb_count)
		return -ENOSPC;
	good_pebs = peb_count - bad_pebs;

	device_pebs = mtd_get_device_size(mtd) / mtd->erasesize;
	bad_limit = recovery_div_round_up_u64(
		device_pebs * beb_limit_per_1024, 1024);
	bad_reserve = bad_limit > bad_pebs ? bad_limit - bad_pebs : 0;

	reserved_pebs = UBI_LAYOUT_VOLUME_EBS +
		RECOVERY_UBI_WL_RESERVED_PEBS +
		RECOVERY_UBI_EBA_RESERVED_PEBS + bad_reserve +
		RECOVERY_UBI_CAPACITY_SAFETY_PEBS;
	if (IS_ENABLED(CONFIG_MTD_UBI_FASTMAP))
		reserved_pebs += RECOVERY_UBI_FASTMAP_RESERVED_PEBS;

	required_volume_pebs = recovery_div_round_up_u64(
		RECOVERY_UBOOTENV_SIZE, leb_size) * 2 +
		recovery_div_round_up_u64(RECOVERY_FACTORY_SIZE, leb_size) +
		RECOVERY_UBI_ROOTFS_DATA_MIN_PEBS;
	if (good_pebs <= reserved_pebs + required_volume_pebs)
		return -ENOSPC;

	*limit = (good_pebs - reserved_pebs - required_volume_pebs) *
		 leb_size;
	printf("Fresh UBI capacity gate: %llu-byte FIT maximum (%llu good PEBs, %llu reserved, %llu required)\n",
	       *limit, good_pebs, reserved_pebs, required_volume_pebs);
	return 0;
}

static int recovery_calc_rebuild_ubi_limit(struct recovery_target *target,
					   unsigned long long *limit)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_device *ubi;
	unsigned long long available;
	int i;

	if (!target || !limit)
		return -EINVAL;
	if (target->backend != RECOVERY_BACKEND_UBI) {
		*limit = target->limit;
		return 0;
	}
	if (recovery_machine_is_xr1710g())
		return recovery_calc_fresh_xr1710g_ubi_limit(target, limit);

	if (target->ubi_needs_format) {
		*limit = target->limit;
		return 0;
	}

	if (recovery_select_ubi(target->ubi_part))
		return -ENODEV;

	ubi = ubi_get_device(0);
	if (!ubi)
		return -ENODEV;

	available = (unsigned long long)ubi->avail_pebs *
		    (unsigned long long)ubi->leb_size;

	for (i = 0; i < ubi->vtbl_slots; i++) {
		struct ubi_volume *vol = ubi->volumes[i];

		if (!vol || vol->vol_id >= UBI_INTERNAL_VOL_START)
			continue;
		if (recovery_preserve_ubi_volume(vol->name))
			continue;

		available += (unsigned long long)vol->reserved_pebs *
			     (unsigned long long)vol->usable_leb_size;
	}

	ubi_put_device(ubi);
	*limit = available;
	return 0;
#else
	return -ENODEV;
#endif
}

static unsigned long long recovery_ubi_additional_pebs(
	struct ubi_device *ubi, const char *name, unsigned long long required)
{
	int i;

	for (i = 0; i < ubi->vtbl_slots; i++) {
		struct ubi_volume *vol = ubi->volumes[i];

		if (!vol || vol->vol_id >= UBI_INTERNAL_VOL_START ||
		    strcmp(vol->name, name))
			continue;

		return required > vol->reserved_pebs ?
		       required - vol->reserved_pebs : 0;
	}

	return required;
}

static int recovery_check_ubi_capacity_after_attach(
	struct recovery_target *target, size_t image_size)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_device *ubi;
	unsigned long long fit_pebs;
	unsigned long long env_pebs;
	unsigned long long factory_pebs;
	unsigned long long additional;
	unsigned long long available;
	unsigned long long leb_size;

	if (!target || target->backend != RECOVERY_BACKEND_UBI || !image_size)
		return -EINVAL;
	if (recovery_select_ubi(target->ubi_part))
		return -ENODEV;

	ubi = ubi_get_device(0);
	if (!ubi)
		return -ENODEV;
	leb_size = ubi->leb_size;
	if (!leb_size) {
		ubi_put_device(ubi);
		return -EINVAL;
	}

	fit_pebs = recovery_div_round_up_u64(image_size, leb_size);
	env_pebs = recovery_div_round_up_u64(RECOVERY_UBOOTENV_SIZE,
					     leb_size);
	factory_pebs = recovery_div_round_up_u64(RECOVERY_FACTORY_SIZE,
						 leb_size);
	additional = recovery_ubi_additional_pebs(ubi, "fit", fit_pebs) +
		recovery_ubi_additional_pebs(ubi, "ubootenv", env_pebs) +
		recovery_ubi_additional_pebs(ubi, "ubootenv2", env_pebs) +
		recovery_ubi_additional_pebs(ubi, "factory", factory_pebs) +
		recovery_ubi_additional_pebs(
			ubi, "rootfs_data", RECOVERY_UBI_ROOTFS_DATA_MIN_PEBS);
	available = ubi->avail_pebs;
	ubi_put_device(ubi);

	if (additional > available) {
		printf("Attached UBI capacity gate failed: %llu additional PEBs required, %llu available\n",
		       additional, available);
		return -ENOSPC;
	}

	printf("Attached UBI capacity gate passed: %llu additional PEBs required, %llu available\n",
	       additional, available);
	return 0;
#else
	return -ENODEV;
#endif
}

static int recovery_create_ubi_volume(const char *name, size_t size, int vol_type)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_mkvol_req req;
	struct ubi_device *ubi;
	int ret;

	if (!name || !*name)
		return -EINVAL;

	ubi = ubi_get_device(0);
	if (!ubi)
		return -ENODEV;

	if (!size)
		size = (size_t)ubi->avail_pebs * (size_t)ubi->leb_size;

	memset(&req, 0, sizeof(req));
	req.vol_id = UBI_VOL_NUM_AUTO;
	req.alignment = 1;
	req.bytes = size;
	req.vol_type = vol_type;
	req.name_len = strlen(name);
	if (req.name_len > UBI_VOL_NAME_MAX) {
		ubi_put_device(ubi);
		return -ENAMETOOLONG;
	}
	memcpy(req.name, name, req.name_len);
	req.name[req.name_len] = '\0';

	prog_flash_mutated = true;
	mutex_lock(&ubi->device_mutex);
	ret = ubi_create_volume(ubi, &req);
	mutex_unlock(&ubi->device_mutex);
	ubi_put_device(ubi);

	return ret;
#else
	return -ENODEV;
#endif
}

static int recovery_remove_ubi_volume(const char *name)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_volume_desc *desc;
	int ret;

	desc = ubi_open_volume_nm(0, name, UBI_EXCLUSIVE);
	if (IS_ERR_OR_NULL(desc))
		return IS_ERR(desc) ? PTR_ERR(desc) : -ENODEV;

	prog_flash_mutated = true;
	mutex_lock(&desc->vol->ubi->device_mutex);
	ret = ubi_remove_volume(desc, 0);
	mutex_unlock(&desc->vol->ubi->device_mutex);
	ubi_close_volume(desc);

	return ret;
#else
	return -ENODEV;
#endif
}

static int recovery_ensure_rootfs_data(struct recovery_target *target)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_volume_desc *desc;
	int ret;

	if (target->backend != RECOVERY_BACKEND_UBI)
		return 0;

	if (recovery_select_ubi(target->ubi_part))
		return -ENODEV;

	desc = ubi_open_volume_nm(0, "rootfs_data", UBI_READWRITE);
	if (!IS_ERR_OR_NULL(desc)) {
		ubi_close_volume(desc);
		return 0;
	}

	ret = recovery_create_ubi_volume("rootfs_data", 0, UBI_DYNAMIC_VOLUME);
	if (ret && ret != -EEXIST) {
		printf("Failed to create UBI volume 'rootfs_data': %d\n", ret);
		return ret;
	}

	return 0;
#else
	return -ENODEV;
#endif
}

static int recovery_prepare_ubi_target(struct recovery_target *target,
				       struct recovery_status_led_ctrl *status_leds,
				       size_t image_size, bool *reformatted)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_device *ubi;
	loff_t erase_len;
	int ret;

	if (reformatted)
		*reformatted = false;

	if (target->backend != RECOVERY_BACKEND_UBI)
		return -EINVAL;

	if (!target->ubi_needs_format)
		return recovery_select_ubi(target->ubi_part);

	if (!target->mtd)
		return -ENODEV;

	erase_len = ALIGN(target->mtd->size, target->mtd->erasesize);
	prog_phase = RECOVERY_PHASE_ERASE;
	prog_done = 0;
	prog_erase_done = 0;
	prog_erase_total = erase_len;
	prog_write_done = 0;
	prog_write_total = image_size;
	prog_total = prog_erase_total + prog_write_total;

	printf("UBI partition '%s' is invalid, erasing it to recreate layout...\n",
	       target->ubi_part);
	ret = recovery_erase_mtd_region(target->mtd, 0, target->mtd->size,
					true, status_leds);
	if (ret)
		return ret;

	recovery_ubi_attach_error = 0;
	ret = recovery_select_ubi(target->ubi_part);
	if (ret)
		return ret;

	ubi = ubi_get_device(0);
	if (ubi) {
		target->limit = (unsigned long long)ubi->avail_pebs *
				(unsigned long long)ubi->leb_size;
		ubi_put_device(ubi);
	}

	target->cur_size = 0;
	target->ubi_needs_format = false;
	if (reformatted)
		*reformatted = true;

	return 0;
#else
	return -ENODEV;
#endif
}

static int recovery_ensure_ubi_volume_named(const char *name, size_t size,
					    int vol_type)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_volume_desc *desc;
	int ret;

	if (!name || !*name)
		return -EINVAL;

	desc = ubi_open_volume_nm(0, name, UBI_READWRITE);
	if (!IS_ERR_OR_NULL(desc)) {
		ubi_close_volume(desc);
		return 0;
	}

	ret = recovery_create_ubi_volume(name, size, vol_type);
	if (ret && ret != -EEXIST) {
		printf("Failed to create UBI volume '%s': %d\n", name, ret);
		return ret;
	}

	return 0;
#else
	return -ENODEV;
#endif
}

static int recovery_ensure_preserved_ubi_volumes(struct recovery_target *target)
{
	int ret;

	if (target->backend != RECOVERY_BACKEND_UBI)
		return 0;

	if (recovery_select_ubi(target->ubi_part))
		return -ENODEV;

	ret = recovery_ensure_ubi_volume_named("ubootenv",
					       RECOVERY_UBOOTENV_SIZE,
					       UBI_DYNAMIC_VOLUME);
	if (ret)
		return ret;

	ret = recovery_ensure_ubi_volume_named("ubootenv2",
					       RECOVERY_UBOOTENV_SIZE,
					       UBI_DYNAMIC_VOLUME);
	if (ret)
		return ret;

	if (of_machine_is_compatible("econet,xr1710g") ||
	    of_machine_is_compatible("econet,xr1710g-ubi") ||
	    of_machine_is_compatible("gemtek,xr1710g") ||
	    of_machine_is_compatible("gemtek,xr1710g-ubi") ||
	    of_machine_is_compatible("gemtek,w1700k") ||
	    of_machine_is_compatible("gemtek,w1700k-ubi")) {
		ret = recovery_ensure_ubi_volume_named("factory",
						       RECOVERY_FACTORY_SIZE,
						       UBI_STATIC_VOLUME);
		if (ret)
			return ret;
	}

	return 0;
}

static int recovery_cleanup_ubi_firmware(struct recovery_target *target,
					 struct recovery_status_led_ctrl *status_leds,
					 size_t image_size)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_device *ubi;
	unsigned long long erase_total = 0;
	unsigned long long erase_done = 0;
	int ret = 0;
	int i;

	if (target->backend != RECOVERY_BACKEND_UBI)
		return -EINVAL;

	if (recovery_select_ubi(target->ubi_part))
		return -ENODEV;

	ubi = ubi_get_device(0);
	if (!ubi)
		return -ENODEV;

	for (i = 0; i < ubi->vtbl_slots; i++) {
		struct ubi_volume *vol = ubi->volumes[i];

		if (!vol || vol->vol_id >= UBI_INTERNAL_VOL_START)
			continue;
		if (recovery_preserve_ubi_volume(vol->name))
			continue;

		erase_total += (unsigned long long)vol->reserved_pebs *
			       (unsigned long long)vol->usable_leb_size;
	}

	prog_phase = RECOVERY_PHASE_ERASE;
	prog_done = 0;
	prog_erase_done = 0;
	prog_erase_total = erase_total > UINT_MAX ? UINT_MAX : erase_total;
	prog_write_done = 0;
	prog_write_total = image_size;
	prog_total = prog_erase_total + prog_write_total;
	prog_status_leds = status_leds;
	ubi_set_progress_callback(recovery_ubi_progress);

	for (i = 0; i < ubi->vtbl_slots; i++) {
		struct ubi_volume *vol = ubi->volumes[i];
		unsigned long long vol_size;
		char name[UBI_VOL_NAME_MAX + 1];

		if (!vol || vol->vol_id >= UBI_INTERNAL_VOL_START)
			continue;
		if (recovery_preserve_ubi_volume(vol->name))
			continue;

		vol_size = (unsigned long long)vol->reserved_pebs *
			   (unsigned long long)vol->usable_leb_size;
		strlcpy(name, vol->name, sizeof(name));
		prog_erase_volume_base = erase_done;
		prog_erase_volume_bytes = vol_size;

		printf("Removing UBI volume '%s' before flashing '%s'...\n",
		       name, target->name);
		ret = recovery_remove_ubi_volume(name);
		if (ret) {
			printf("Failed to remove UBI volume '%s': %d\n", name, ret);
			break;
		}

		erase_done += vol_size;
		prog_erase_done = erase_done > prog_erase_total ?
				  prog_erase_total : erase_done;
		prog_done = prog_erase_done + prog_write_done;
		recovery_service_runtime(status_leds);
	}

	ubi_set_progress_callback(NULL);
	prog_status_leds = NULL;
	ubi_put_device(ubi);
	if (ret)
		return ret;

	return recovery_try_ubi_target(current_target, target);
#else
	return -ENODEV;
#endif
}

static void recovery_abort_ubi_update(struct ubi_volume *vol)
{
	if (!vol || !vol->updating)
		return;

	if (vol->upd_buf) {
		vfree(vol->upd_buf);
		vol->upd_buf = NULL;
	}
	vol->updating = 0;
	vol->upd_bytes = 0;
	vol->upd_received = 0;
	vol->upd_ebs = 0;
}

static int recovery_write_ubi_target(struct recovery_target *target,
				      struct recovery_status_led_ctrl *status_leds,
				      const void *image, size_t image_size)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_volume_desc *desc;
	struct ubi_volume *vol;
	struct ubi_device *ubi;
	const u8 *src = image;
	size_t reserved_bytes;
	u32 written = 0;
	int ret;

	if (target->backend != RECOVERY_BACKEND_UBI)
		return -EINVAL;

	if (recovery_select_ubi(target->ubi_part))
		return -ENODEV;

	desc = ubi_open_volume_nm(0, target->name, UBI_READWRITE);
	if (IS_ERR_OR_NULL(desc))
		return IS_ERR(desc) ? PTR_ERR(desc) : -ENODEV;

	vol = desc->vol;
	ubi = vol->ubi;
	reserved_bytes = (size_t)vol->reserved_pebs *
			 (size_t)(ubi->leb_size - vol->data_pad);
	if (image_size > reserved_bytes) {
		ret = -EFBIG;
		goto out_close;
	}

	prog_flash_mutated = true;
	ret = ubi_start_update(ubi, vol, image_size);
	if (ret)
		goto out_close;

	/* Flush one runtime cycle so the browser can observe phase 2 before
	 * the actual UBI data write loop starts.
	 */
	recovery_service_runtime(status_leds);

	while (written < image_size) {
		u32 chunk = image_size - written;

		if (chunk > RECOVERY_UBI_WRITE_CHUNK)
			chunk = RECOVERY_UBI_WRITE_CHUNK;

		ret = ubi_more_update_data(ubi, vol, src + written, chunk);
		if (ret < 0)
			goto out_close;

		written += chunk;
		prog_write_done = written > prog_write_total ?
				  prog_write_total : written;
		prog_done = prog_erase_done + prog_write_done;
		recovery_service_runtime(status_leds);
	}

	/* Full-volume read-back check removed for faster flashing. */
	vol->checked = 1;
	ubi_gluebi_updated(vol);
	ret = 0;

out_close:
	if (ret)
		recovery_abort_ubi_update(vol);
	ubi_close_volume(desc);
	return ret;
#else
	return -ENODEV;
#endif
}

static int recovery_resize_ubi_target(struct recovery_target *target,
				      size_t new_size)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_volume_desc *desc;
	struct ubi_volume *vol;
	int needed_pebs;
	int ret;

	if (target->backend != RECOVERY_BACKEND_UBI)
		return -EINVAL;

	if (recovery_select_ubi(target->ubi_part))
		return -ENODEV;

	desc = ubi_open_volume_nm(0, target->name, UBI_EXCLUSIVE);
	if (IS_ERR_OR_NULL(desc))
		return IS_ERR(desc) ? PTR_ERR(desc) : -ENODEV;

	vol = desc->vol;
	needed_pebs = DIV_ROUND_UP(new_size, vol->usable_leb_size);

	mutex_lock(&vol->ubi->device_mutex);
	prog_flash_mutated = true;
	ret = ubi_resize_volume(desc, needed_pebs);
	mutex_unlock(&vol->ubi->device_mutex);

	if (!ret) {
		target->cur_size = (unsigned long long)needed_pebs *
				   (unsigned long long)vol->usable_leb_size;
		target->limit = (unsigned long long)(needed_pebs +
						     vol->ubi->avail_pebs) *
			(unsigned long long)vol->usable_leb_size;
	}

	ubi_close_volume(desc);
	return ret;
#else
	return -ENODEV;
#endif
}

static int recovery_create_ubi_target(struct recovery_target *target,
				      size_t new_size)
{
#if IS_ENABLED(CONFIG_CMD_UBI) && IS_ENABLED(CONFIG_MTD_UBI)
	struct ubi_mkvol_req req;
	struct ubi_device *ubi;
	int ret;

	if (target->backend != RECOVERY_BACKEND_UBI)
		return -EINVAL;

	if (recovery_select_ubi(target->ubi_part))
		return -ENODEV;

	ubi = ubi_get_device(0);
	if (!ubi)
		return -ENODEV;

	memset(&req, 0, sizeof(req));
	req.vol_id = UBI_VOL_NUM_AUTO;
	req.alignment = 1;
	req.bytes = new_size;
	req.vol_type = UBI_STATIC_VOLUME;
	req.name_len = strlen(target->name);
	if (req.name_len > UBI_VOL_NAME_MAX) {
		ubi_put_device(ubi);
		return -ENAMETOOLONG;
	}
	memcpy(req.name, target->name, req.name_len);
	req.name[req.name_len] = '\0';

	prog_flash_mutated = true;
	mutex_lock(&ubi->device_mutex);
	ret = ubi_create_volume(ubi, &req);
	mutex_unlock(&ubi->device_mutex);
	ubi_put_device(ubi);
	if (ret)
		return ret;

	return recovery_try_ubi_target(current_target, target);
#else
	return -ENODEV;
#endif
}

/* Determine maximum payload size based on selected target and DTS-defined MTD
 * layout. Returns 0 on error. */
static unsigned long recovery_calc_target_max(enum upload_target tgt,
					      loff_t *p_ofs)
{
	struct recovery_target target;
	unsigned long limit = 0;
	unsigned long long effective_limit;

	if (recovery_resolve_target(tgt, &target))
		return 0;

	if (p_ofs)
		*p_ofs = target.ofs;

	effective_limit = target.limit;
	if (tgt == TARGET_FIRMWARE &&
	    recovery_calc_rebuild_ubi_limit(&target, &effective_limit))
		effective_limit = 0;

	limit = (effective_limit > ULONG_MAX) ? ULONG_MAX :
		(unsigned long)effective_limit;
	recovery_release_target(&target);

	return limit;
}

/* Only dynamic endpoints here; static files come from fsdata */

static const char recovery_page_ok[] =
	"HTTP/1.0 200 OK\r\n"
	"Content-Type: text/plain\r\n"
	"Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
	"Pragma: no-cache\r\n"
	"Expires: 0\r\n"
	"Content-Length: 2\r\n"
	"Connection: close\r\n"
	"\r\n"
	"OK";

static int recovery_open_custom_response_status(struct fs_file *file,
						const char *status,
						const char *content_type,
						const char *body, int body_len)
{
	char header[384];
	char *page;
	int header_len;
	int total_len;

	if (!file || !status || !content_type || !body || body_len < 0)
		return 0;

	header_len = snprintf(header, sizeof(header),
			      "HTTP/1.0 %s\r\n"
			      "Content-Type: %s\r\n"
			      "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
			      "Pragma: no-cache\r\n"
			      "Expires: 0\r\n"
			      "Content-Length: %d\r\n"
			      "Connection: close\r\n"
			      "\r\n",
			      status, content_type, body_len);
	if (header_len < 0 || header_len >= (int)sizeof(header))
		return 0;
	if (body_len > INT_MAX - header_len - 1)
		return 0;

	total_len = header_len + body_len;
	page = malloc(total_len + 1);
	if (!page)
		return 0;

	memcpy(page, header, header_len);
	memcpy(page + header_len, body, body_len);
	page[total_len] = '\0';

	file->data = page;
	file->len = total_len;
	file->index = file->len;
	file->flags = FS_FILE_FLAGS_HEADER_INCLUDED;
	return 1;
}

static int recovery_open_custom_response(struct fs_file *file,
					 const char *content_type,
					 const char *body, int body_len)
{
	return recovery_open_custom_response_status(file, "200 OK", content_type,
						    body, body_len);
}

static bool recovery_is_about_request(const char *path)
{
	static const char prefix[] = "about?nonce=";
	const char *nonce;
	size_t len;

	if (!strcmp(path, "about"))
		return true;
	if (strncmp(path, prefix, sizeof(prefix) - 1))
		return false;

	nonce = path + sizeof(prefix) - 1;
	len = strlen(nonce);
	if (!len || len > 64)
		return false;
	for (size_t i = 0; i < len; i++) {
		if (!isalnum((unsigned char)nonce[i]) &&
		    nonce[i] != '-' && nonce[i] != '_')
			return false;
	}

	return true;
}

static void recovery_digest_to_hex(const u8 *digest, size_t digest_len,
				   char *hex, size_t hex_len)
{
	static const char digits[] = "0123456789abcdef";

	if (!hex || hex_len < digest_len * 2 + 1)
		return;
	for (size_t i = 0; i < digest_len; i++) {
		hex[i * 2] = digits[digest[i] >> 4];
		hex[i * 2 + 1] = digits[digest[i] & 0xf];
	}
	hex[digest_len * 2] = '\0';
}

/* lwIP httpd custom file hooks: serve only dynamic endpoints; static files via fsdata */
int fs_open_custom(struct fs_file *file, const char *name)
{
    const char *p;
    if (!file || !name)
        return 0;

    /* Normalize leading slash to make httpd default filenames work */
    p = name;
    if (*p == '/')
        p++;


	    if (!strcmp(p, "status")) {
	        char staging_sha256[RECOVERY_STAGING_SHA256_SIZE * 2 + 1] = "";
	        char json[1024];
	        int ok = (prog_phase == RECOVERY_PHASE_DONE);
	        int err = (prog_phase == RECOVERY_PHASE_ERROR);
	        int upload_locked = recovery_upload_locked();
	        int retry_allowed = recovery_retry_allowed();
	        int json_len;

	        if (staging_digest_valid)
	            recovery_digest_to_hex(staging_digest_sha256,
	                                   sizeof(staging_digest_sha256),
	                                   staging_sha256,
	                                   sizeof(staging_sha256));
	        json_len = snprintf(json, sizeof(json),
	                                "{\"in_progress\":%d,\"done\":%u,\"total\":%u,\"erase_done\":%u,\"erase_total\":%u,\"write_done\":%u,\"write_total\":%u,\"ok\":%d,\"error\":%d,\"partial\":%d,\"error_code\":%d,\"error_stage\":\"%s\",\"validation_detail\":\"%s\",\"validation_component\":\"%s\",\"phase\":%d,\"upload_locked\":%d,\"retry_allowed\":%d,\"target\":\"%s\",\"staging_valid\":%d,\"staging_size\":%u,\"staging_crc32\":\"%08x\",\"staging_sha256\":\"%s\",\"staging_generation\":%u}\n",
	                                prog_phase > RECOVERY_PHASE_IDLE &&
	                                prog_phase < RECOVERY_PHASE_DONE,
	                                (unsigned)prog_done, (unsigned)prog_total,
	                                (unsigned)prog_erase_done, (unsigned)prog_erase_total,
	                                (unsigned)prog_write_done, (unsigned)prog_write_total,
	                                ok, err, prog_partial, prog_error_code,
	                                prog_error_stage,
	                                prog_validation_detail,
	                                prog_validation_component,
	                                prog_phase,
	                                upload_locked, retry_allowed,
	                                recovery_target_name(current_target),
	                                staging_digest_valid,
	                                staging_digest_size,
	                                staging_digest_crc32,
	                                staging_sha256,
	                                staging_digest_generation);
	        if (json_len < 0 || json_len >= (int)sizeof(json))
	            return 0;

        return recovery_open_custom_response(file, "application/json",
					     json, json_len);
	    }
	    else if (!strcmp(p, "dhcp-status")) {
		struct net_lwip_recovery_dhcp_stats dispatch = { 0 };
		struct recovery_dhcp_server *dhcp = recovery_active_dhcp;
		const struct recovery_fport_status *request_fport =
			dhcp ? &dhcp->request_fport : NULL;
		const struct recovery_fport_status *reply_fport =
			dhcp ? &dhcp->reply_fport : NULL;
		char json[2048];
		int json_len;

		net_lwip_get_recovery_dhcp_stats(&dispatch);
		json_len = snprintf(
			json, sizeof(json),
			"{\"running\":%d,\"rx_frames\":%u,"
			"\"non_dhcp_frames\":%u,\"malformed_frames\":%u,"
			"\"dhcp_frames\":%u,\"tagged_frames_ignored\":%u,"
			"\"dispatched_frames\":%u,"
			"\"allocation_failures\":%u,\"vlan_depth\":%u,"
			"\"rx_datagrams\":%u,\"malformed_requests\":%u,"
			"\"ignored_requests\":%u,\"discover\":%u,"
			"\"request\":%u,\"offer_attempts\":%u,"
			"\"offer_successes\":%u,\"offer_failures\":%u,"
			"\"ack_attempts\":%u,\"ack_successes\":%u,"
			"\"ack_failures\":%u,\"nak_attempts\":%u,"
			"\"nak_successes\":%u,\"nak_failures\":%u,"
			"\"last_reply\":%u,\"last_error\":%d,"
			"\"last_frame_len\":%u,\"tx_mode\":\"raw-ethernet\","
			"\"netif_up\":%d,\"lwip_link_up\":%d,"
			"\"rx_fport\":%u,\"rx_sport\":%u,\"rx_qdma\":%u,"
			"\"tx_fport\":%u,\"primary_fport\":%u,"
			"\"primary_hw_fport\":%u,\"attempt_mask\":%u,"
			"\"success_mask\":%u,\"last_tx_hw_fport\":%u,"
			"\"primary_error\":%d,\"last_tx_error\":%d,"
			"\"attempts_fport1\":%u,\"attempts_fport2\":%u,"
			"\"attempts_fport4\":%u,\"successes_fport1\":%u,"
			"\"successes_fport2\":%u,\"successes_fport4\":%u,"
			"\"failures_fport1\":%u,\"failures_fport2\":%u,"
			"\"failures_fport4\":%u}\n",
			dhcp && dhcp->running,
			(unsigned)dispatch.rx_frames,
			(unsigned)dispatch.non_dhcp_frames,
			(unsigned)dispatch.malformed_frames,
			(unsigned)dispatch.dhcp_frames,
			(unsigned)dispatch.tagged_frames_ignored,
			(unsigned)dispatch.dispatched_frames,
			(unsigned)dispatch.allocation_failures,
			(unsigned)dispatch.last_vlan_depth,
			dhcp ? (unsigned)dhcp->rx_datagrams : 0,
			dhcp ? (unsigned)dhcp->malformed_requests : 0,
			dhcp ? (unsigned)dhcp->ignored_requests : 0,
			dhcp ? (unsigned)dhcp->discovers : 0,
			dhcp ? (unsigned)dhcp->requests : 0,
			dhcp ? (unsigned)dhcp->offer_attempts : 0,
			dhcp ? (unsigned)dhcp->offer_successes : 0,
			dhcp ? (unsigned)dhcp->offer_failures : 0,
			dhcp ? (unsigned)dhcp->ack_attempts : 0,
			dhcp ? (unsigned)dhcp->ack_successes : 0,
			dhcp ? (unsigned)dhcp->ack_failures : 0,
			dhcp ? (unsigned)dhcp->nak_attempts : 0,
			dhcp ? (unsigned)dhcp->nak_successes : 0,
			dhcp ? (unsigned)dhcp->nak_failures : 0,
			dhcp ? (unsigned)dhcp->last_reply_type : 0,
			dhcp ? dhcp->last_send_error : 0,
			dhcp ? (unsigned)dhcp->last_frame_len : 0,
			dhcp && dhcp->netif && netif_is_up(dhcp->netif),
			dhcp && dhcp->netif && netif_is_link_up(dhcp->netif),
			request_fport ? (unsigned)request_fport->rx_fport : 0,
			request_fport ? (unsigned)request_fport->rx_sport : 0,
			request_fport ? (unsigned)request_fport->rx_qdma : 0,
			reply_fport ? (unsigned)reply_fport->tx_fport : 0,
			reply_fport ? (unsigned)reply_fport->primary_fport : 0,
			reply_fport ? (unsigned)reply_fport->primary_hw_fport : 0,
			reply_fport ? (unsigned)reply_fport->attempt_mask : 0,
			reply_fport ? (unsigned)reply_fport->success_mask : 0,
			reply_fport ? (unsigned)reply_fport->last_tx_hw_fport : 0,
			reply_fport ? reply_fport->primary_error : 0,
			reply_fport ? reply_fport->last_tx_error : 0,
			reply_fport ? (unsigned)reply_fport->attempts_fport1 : 0,
			reply_fport ? (unsigned)reply_fport->attempts_fport2 : 0,
			reply_fport ? (unsigned)reply_fport->attempts_fport4 : 0,
			reply_fport ? (unsigned)reply_fport->successes_fport1 : 0,
			reply_fport ? (unsigned)reply_fport->successes_fport2 : 0,
			reply_fport ? (unsigned)reply_fport->successes_fport4 : 0,
			reply_fport ? (unsigned)reply_fport->failures_fport1 : 0,
			reply_fport ? (unsigned)reply_fport->failures_fport2 : 0,
			reply_fport ? (unsigned)reply_fport->failures_fport4 : 0);
		if (json_len < 0 || json_len >= (int)sizeof(json))
			return 0;

		return recovery_open_custom_response(file, "application/json",
						     json, json_len);
	    }
	    else if (!strcmp(p, "ok")) {
		file->data = recovery_page_ok;
		file->len = sizeof(recovery_page_ok) - 1;
		file->index = file->len;
		file->flags = FS_FILE_FLAGS_HEADER_INCLUDED;
		return 1;
	    }
	    else if (!strcmp(p, "locked")) {
		static const char body[] =
			"Upload locked; inspect /status before taking further action.\n";

		return recovery_open_custom_response_status(
			file, "409 Conflict", "text/plain", body,
			sizeof(body) - 1);
	    }
	    else if (!strcmp(p, "stale-ui")) {
		static const char body[] =
			"Stale or invalid UI Build; reload the current recovery page.\n";

		return recovery_open_custom_response_status(
			file, "409 Conflict", "text/plain", body,
			sizeof(body) - 1);
	    }
	    else if (recovery_is_about_request(p)) {
	        char json[640];
	        int json_len =
#ifdef U_BOOT_DATE
	            snprintf(json, sizeof(json),
	                     "{\"u_boot\":\"%s (%s - %s %s)\",\"detected_layout\":\"%s\",\"ui_build\":\"%s\",\"capabilities\":{\"system_double_clean\":true,\"xr1710g_fit_layout_validation\":true,\"uboot_redundant_env_clear\":true,\"factory_readback\":true,\"post_response_ack\":true,\"dynamic_no_store\":true}}\n",
	                     U_BOOT_VERSION, U_BOOT_DATE, U_BOOT_TIME, U_BOOT_TZ,
	                     xr1710g_detect_ubi_version(), RECOVERY_UI_BUILD);
#else
	            snprintf(json, sizeof(json),
	                     "{\"u_boot\":\"%s\",\"detected_layout\":\"%s\",\"ui_build\":\"%s\",\"capabilities\":{\"system_double_clean\":true,\"xr1710g_fit_layout_validation\":true,\"uboot_redundant_env_clear\":true,\"factory_readback\":true,\"post_response_ack\":true,\"dynamic_no_store\":true}}\n",
	                     U_BOOT_VERSION, xr1710g_detect_ubi_version(),
	                     RECOVERY_UI_BUILD);
#endif
	        if (json_len < 0 || json_len >= (int)sizeof(json))
	            return 0;

        return recovery_open_custom_response(file, "application/json",
					     json, json_len);
    }
    /* Do not intercept favicon/index/ok/fail: served by fsdata */
    /* let fsdata handle others */
    return 0;
}

void fs_close_custom(struct fs_file *file)
{
	if (file && file->data && file->data != recovery_page_ok) {
		free((void *)file->data);
		file->data = NULL;
	}
}

int fs_read_custom(struct fs_file *file, char *buffer, int count)
{
    u32_t left;
    if (!file || !buffer || count <= 0)
        return FS_READ_EOF;
    left = file->len - file->index;
    if (left <= 0)
        return FS_READ_EOF;
    if ((u32_t)count > left)
        count = left;
    memcpy(buffer, file->data + file->index, count);
    file->index += count;
    return count;
}

/* Complete custom responses are supplied in file->data by fs_open_custom(). */

static int recovery_select_upload_buffer(size_t size, u8 **buffer)
{
	ulong base;
	ulong ram_end;
	ulong ram_start;
	ulong reserved_start;

	if (!buffer || !size || !gd->ram_size)
		return -EINVAL;
	ram_start = (ulong)gd->ram_base;
	if (gd->ram_size > ULONG_MAX - ram_start)
		return -EOVERFLOW;
	ram_end = ram_start + (ulong)gd->ram_size;
	if (RECOVERY_UPLOAD_RAM_OFFSET > ULONG_MAX - ram_start)
		return -EOVERFLOW;
	base = ram_start + RECOVERY_UPLOAD_RAM_OFFSET;
	if (base < ram_start || base >= ram_end)
		return -ENOMEM;

	/* start_addr_sp is the bottom of U-Boot's top-of-RAM reservations. */
	reserved_start = gd->start_addr_sp;
	if (reserved_start <= base || reserved_start > ram_end) {
		printf("httpd: invalid U-Boot reserved-memory boundary 0x%lx\n",
		       reserved_start);
		return -ENOMEM;
	}
	if (gd->relocaddr > base && gd->relocaddr < reserved_start)
		reserved_start = gd->relocaddr;
	if (gd->fdt_blob && (ulong)gd->fdt_blob > base &&
	    (ulong)gd->fdt_blob < reserved_start)
		reserved_start = (ulong)gd->fdt_blob;

	if (reserved_start - base <= RECOVERY_UPLOAD_RESERVED_GUARD ||
	    size > reserved_start - base - RECOVERY_UPLOAD_RESERVED_GUARD) {
		printf("httpd: upload does not fit fixed XR1710G staging window\n");
		return -ENOMEM;
	}

	*buffer = (u8 *)base;
	return 0;
}

/* HTTP POST handlers */
err_t httpd_post_begin(void *connection, const char *uri, const char *http_request,
                       u16_t http_request_len, int content_len, char *response_uri,
                       u16_t response_uri_len, u8_t *post_auto_wnd)
{
    struct recovery_upload_request request;
    int request_ret;

    (void)http_request; (void)http_request_len;
    /*
     * Throttle large uploads explicitly: XR1710G recovery accepts firmware
     * images that are much larger than a typical lwIP POST body and manual
     * window updates avoid over-optimistic receive windows.
     */
    if (post_auto_wnd)
        *post_auto_wnd = 0;

    if (recovery_upload_locked()) {
        printf("httpd: rejecting upload while recovery state is locked (phase=%d, partial=%d)\n",
               prog_phase, prog_partial);
        strlcpy(response_uri, "/locked", response_uri_len);
        return ERR_ARG;
    }

    /*
     * Parse and authenticate the page build before clearing any previous
     * diagnostic state or accepting body bytes. Unknown, duplicate and stale
     * query parameters fail closed.
     */
    request_ret = recovery_parse_upload_request(uri, &request);
    if (request_ret) {
        printf("httpd: rejecting stale or invalid upload request: %d\n",
               request_ret);
        strlcpy(response_uri,
                request_ret == -ESTALE ? "/stale-ui" : "/fail.html",
                response_uri_len);
        return ERR_ARG;
    }

    recovery_clear_staging_digest();
    recovery_cancel_upload_credit();
    recovery_invalidate_post_owner();
    recovery_clear_factory_cache();
    post_ok = 0;
    recovery_ubi_attach_error = 0;
    recv_off = 0;
    recv_total = 0;
    /* Reset progress state. */
    prog_phase = RECOVERY_PHASE_IDLE;
    recovery_reset_error();
    prog_done = 0;
    prog_total = 0;
    prog_erase_done = 0;
    prog_erase_total = 0;
    prog_write_done = 0;
    prog_write_total = 0;
    if (!recovery_machine_is_xr1710g() || !gd->fdt_blob ||
        recovery_validate_xr1710g_identity(gd->fdt_blob)) {
        printf("httpd: refusing recovery on non-XR1710G hardware\n");
        recovery_set_error("hardware", -ENODEV);
        strlcpy(response_uri, "/fail.html", response_uri_len);
        return ERR_ARG;
    }
    current_target = request.target;
    current_ubi_layout = request.layout;

    {
        ulong min = 0;
        ulong env_max = recovery_machine_is_xr1710g() ? 0 :
                        env_get_hex("recovery_max", 0);
        loff_t tmpofs = 0;
        ulong dts_max = recovery_calc_target_max(current_target, &tmpofs);
        ulong max = dts_max;

        if (!dts_max) {
            printf("httpd: fixed XR1710G target validation failed\n");
            recovery_set_error("target", -ENODEV);
            strlcpy(response_uri, "/fail.html", response_uri_len);
            return ERR_ARG;
        }

        if (current_target == TARGET_FIRMWARE)
            min = RECOVERY_MIN_FIRMWARE_SIZE;
        else if (current_target == TARGET_UBOOT &&
                 max > RECOVERY_MAX_UBOOT_SIZE)
            max = RECOVERY_MAX_UBOOT_SIZE;

        if (env_max && env_max < max)
            max = env_max; /* allow env to further cap */
        if (content_len <= 0 || (ulong)content_len > max ||
            (min && (ulong)content_len < min)) {
            recovery_set_error("size", -EFBIG);
            if (min && (ulong)content_len < min) {
                printf("httpd: content_len %d below allowed min %lu for target %d\n",
                       content_len, min, current_target);
            } else {
                printf("httpd: content_len %d exceeds allowed max %lu (target limit %lu, ofs 0x%llx)\n",
                       content_len, max, dts_max, (unsigned long long)tmpofs);
            }
            strlcpy(response_uri, "/fail.html", response_uri_len);
            return ERR_ARG;
        }
    }

    recv_total = content_len;

    if (recovery_select_upload_buffer(recv_total, &recv_base)) {
        recovery_set_error("memory", -ENOMEM);
        printf("httpd: no collision-free fixed RAM window for upload (%u bytes)\n",
               recv_total);
        strlcpy(response_uri, "/fail.html", response_uri_len);
        return ERR_MEM;
    }

    if (recovery_bind_post_owner(connection)) {
        recovery_set_error("connection", -EINVAL);
        strlcpy(response_uri, "/fail.html", response_uri_len);
        return ERR_ARG;
    }
    post_ok = 1;
    /* Leave response_uri untouched here so the POST can complete normally. */
    if (current_target == TARGET_FIRMWARE)
        printf("httpd: accepting %u-byte firmware for UBI %s\n",
               recv_total, current_ubi_layout->version);
    else
        printf("httpd: accepting %u-byte U-Boot image\n", recv_total);
    return ERR_OK;
}

err_t httpd_post_receive_data(void *connection, struct pbuf *p)
{
	struct pbuf *q;
	u32 generation = recovery_current_post_generation(connection);
	u16_t recved = 0;

	if (!generation || !post_ok) {
		printf("httpd: ignoring receive callback from a stale POST transaction\n");
		pbuf_free(p);
		return ERR_ARG;
	}

	/* Copy request payload into RAM and defer flash work to the main loop. */
	for (q = p; q != NULL; q = q->next) {
        size_t avail = recv_total - recv_off;
        size_t clen = q->len;
	        if (clen > avail) {
	            pbuf_free(p);
	            post_ok = 0;
	            recovery_clear_staging_digest();
	            recovery_set_error("upload", -EOVERFLOW);
	            return ERR_ARG;
	        }
	        memcpy(recv_base + recv_off, q->payload, clen);
	        recv_off += clen;
    }
    recved = p->tot_len;
    pbuf_free(p);

#if LWIP_HTTPD_POST_MANUAL_WND
    if (recved)
        recovery_queue_upload_credit(connection, recved);
#endif

    return ERR_OK;
}

void httpd_post_finished(void *connection, char *response_uri, u16_t response_uri_len)
{
	bool upload_complete;
	u32 generation = recovery_current_post_generation(connection);
	int digest_ret;

	if (!generation) {
		printf("httpd: ignoring finished callback from a stale POST transaction\n");
		return;
	}

	printf("httpd: post finished, %u/%u bytes received\n", recv_off, recv_total);
	upload_complete = post_ok && recv_total && (recv_off == recv_total);
	recovery_cancel_upload_credit_owner(connection, generation);
	if (upload_complete) {
		/* Verification pass removed for faster flashing. */
		(void)digest_ret;
		strlcpy(response_uri, "/ok", response_uri_len);
		printf("httpd: upload received; waiting for POST response ACK\n");
	} else {
		strlcpy(response_uri, "/fail.html", response_uri_len);
		post_ok = 0;
		recovery_clear_staging_digest();
		recovery_set_error("upload", -EIO);
		recovery_clear_post_owner(connection, generation);
	}
}

#if LWIP_HTTPD_POST_RESPONSE_ACK
void httpd_post_response_complete(void *connection, err_t result)
{
	u32 generation = recovery_current_post_generation(connection);

	if (!generation) {
		printf("httpd: ignoring response callback from a stale POST transaction\n");
		return;
	}
	if (!post_ok || !recv_total || recv_off < recv_total) {
		recovery_clear_post_owner(connection, generation);
		return;
	}

	if (result != ERR_OK) {
		printf("httpd: POST response not acknowledged (%d); flash cancelled\n",
		       result);
		post_ok = 0;
		recovery_clear_staging_digest();
		recovery_set_error("ack", result);
		recovery_clear_post_owner(connection, generation);
		return;
	}

	printf("httpd: POST response acknowledged; flashing may start\n");
	flash_post_generation = generation;
	flash_request = 1;
	recovery_clear_post_owner(connection, generation);
}
#endif

static int flash_image(struct recovery_status_led_ctrl *status_leds)
{
	struct recovery_target target;
	const u8 *image = recv_base;
	u32 image_size = recv_off;
	int ret;

	post_ok = 0;
	/* Verification pass removed for faster flashing. */

	if (!image_size) {
		printf("No data received to flash\n");
		return recovery_set_error("upload", -EINVAL);
	}
	if (!recovery_machine_is_xr1710g() || !gd->fdt_blob ||
	    recovery_validate_xr1710g_identity(gd->fdt_blob)) {
		printf("Refusing to flash on non-XR1710G hardware\n");
		return recovery_set_error("hardware", -ENODEV);
	}

	recovery_validation_step("begin", recovery_target_name(current_target));
	if (current_target == TARGET_UBOOT) {
		struct xr1710g_recovery_validation_result validation;

		ret = xr1710g_validate_uboot_slot_image(image, image_size,
							 &validation);
		recovery_record_validation_result(&validation);
		if (ret)
			return recovery_set_error("validation", ret);
	} else if (current_target == TARGET_FIRMWARE) {
		/* Whole-image integrity gate BEFORE any erase: the FIT carries
		 * sha1/sha256 nodes over every payload. Recompute them over the
		 * received bytes; a truncated or corrupted upload stops here
		 * with an error and can be re-sent without touching flash. */
		ret = recovery_validate_firmware_fit(image, image_size,
						     current_ubi_layout);
		if (ret) {
			printf("Refusing system image before any erase: %d\n",
			       ret);
			return recovery_set_error("validation", ret);
		}
		ret = recovery_preflight_factory_source();
		if (ret) {
			printf("Refusing system clean-install: DSD/Factory source preflight failed: %d\n",
			       ret);
			return recovery_set_error("factory-source", ret);
		}
	} else {
		return recovery_set_error("target", -EINVAL);
	}

	ret = recovery_resolve_target(current_target, &target);
	if (ret) {
		printf("No flash target found for upload type %d\n", current_target);
		return recovery_set_error("target", ret);
	}

	if (current_target == TARGET_FIRMWARE &&
	    target.backend == RECOVERY_BACKEND_UBI) {
		ret = recovery_force_ubi_rebuild(&target);
		if (ret) {
			printf("Failed to select UBI %s rebuild target: %d\n",
			       current_ubi_layout->version, ret);
			recovery_release_target(&target);
			return recovery_set_error("layout", ret);
		}
		if (target.limit != current_ubi_layout->size) {
			printf("Selected UBI %s target size 0x%llx does not match 0x%x\n",
			       current_ubi_layout->version, target.limit,
			       current_ubi_layout->size);
			recovery_release_target(&target);
			return recovery_set_error("layout", -EINVAL);
		}
	}

	if (current_target == TARGET_FIRMWARE &&
	    target.backend == RECOVERY_BACKEND_UBI) {
		unsigned long long rebuild_limit;

		ret = recovery_calc_rebuild_ubi_limit(&target, &rebuild_limit);
		if (ret) {
			recovery_release_target(&target);
			return recovery_set_error("capacity", ret);
		}
		target.limit = rebuild_limit;
	}

	if (image_size > target.limit) {
		printf("Image size %u exceeds target size %llu\n",
		       image_size, target.limit);
		recovery_release_target(&target);
		return recovery_set_error("size", -EFBIG);
	}

	if (target.backend == RECOVERY_BACKEND_UBI) {
		bool reformatted = false;
		const char *factory_part = target.ubi_part;

		if (current_target != TARGET_FIRMWARE ||
		    strcmp(target.name, "fit")) {
			recovery_release_target(&target);
			return recovery_set_error("target", -EINVAL);
		}

		printf("Recovery mode: recreating UBI %s on '%s'.\n",
		       current_ubi_layout->version, target.ubi_part);

		ret = recovery_prepare_ubi_target(&target, status_leds, image_size,
						      &reformatted);
		if (ret) {
			printf("Failed to prepare UBI target '%s' on '%s': %d\n",
			       target.name, target.ubi_part, ret);
			recovery_release_target(&target);
			return recovery_set_error("erase", ret);
		}

		if (!reformatted) {
			ret = recovery_cleanup_ubi_firmware(&target, status_leds,
							    image_size);
			if (ret) {
				printf("Failed to clean UBI firmware volumes for '%s': %d\n",
				       target.name, ret);
				recovery_release_target(&target);
				return recovery_set_error("erase", ret);
			}
		}

		ret = recovery_check_ubi_capacity_after_attach(&target,
							 image_size);
		if (ret) {
			recovery_release_target(&target);
			return recovery_set_error("capacity", ret);
		}

		if (!target.cur_size) {
			printf("Creating missing UBI volume '%s' for %u bytes...\n",
			       target.name, image_size);
			ret = recovery_create_ubi_target(&target, image_size);
			if (ret) {
				printf("ubi_create_volume failed for '%s': %d\n",
				       target.name, ret);
				recovery_release_target(&target);
				return recovery_set_error("layout", ret);
			}
		} else if (image_size > target.cur_size) {
			printf("Resizing UBI volume '%s' from %llu to fit %u bytes...\n",
			       target.name, target.cur_size, image_size);
			ret = recovery_resize_ubi_target(&target, image_size);
			if (ret) {
				printf("ubi_resize_volume failed for '%s': %d\n",
				       target.name, ret);
				recovery_release_target(&target);
				return recovery_set_error("layout", ret);
			}
		}

		ret = recovery_ensure_preserved_ubi_volumes(&target);
		if (ret) {
			recovery_release_target(&target);
			return recovery_set_error("layout", ret);
		}

		ret = recovery_ensure_rootfs_data(&target);
		if (ret) {
			recovery_release_target(&target);
			return recovery_set_error("layout", ret);
		}

		printf("Writing %u bytes to UBI volume '%s' on '%s'...\n",
		       image_size, target.name, target.ubi_part);
		prog_phase = RECOVERY_PHASE_WRITE;
		prog_done = prog_erase_total;
		prog_write_done = 0;
		recovery_service_runtime(status_leds);
		ret = recovery_write_ubi_target(&target, status_leds,
						image, image_size);
		if (ret) {
			printf("UBI write failed for '%s': %d\n",
			       target.name, ret);
			recovery_release_target(&target);
			return recovery_set_error("write", ret);
		}

		/* Write finished, but Factory rebuild still pending - cap at 95% */
		prog_phase = RECOVERY_PHASE_FACTORY;
		prog_write_done = (u32)((u64)image_size * 95 / 100);
		prog_done = prog_erase_total + prog_write_done;
		recovery_release_target(&target);

		ret = recovery_sync_and_verify_factory(factory_part);
		if (ret) {
			printf("System written, but Factory rebuild/read-back failed: %d\n",
			       ret);
			return recovery_set_error("factory", ret);
		}

		/* Factory OK - now 100% */
		prog_write_done = image_size;
		prog_done = prog_erase_total + image_size;
		prog_phase = RECOVERY_PHASE_DONE;
		recovery_clear_factory_cache();
		return 0;
	}

	{
		struct mtd_info *mtd = target.mtd;
		enum xr1710g_recovery_mtd_stage transaction_stage =
			XR1710G_MTD_STAGE_ARGUMENT;
		loff_t ofs = target.ofs;
		loff_t erase_len = target.limit;

		if (current_target != TARGET_UBOOT ||
		    recovery_validate_runtime_uboot_slot(mtd)) {
			recovery_release_target(&target);
			return recovery_set_error("target", -EINVAL);
		}
		prog_phase = RECOVERY_PHASE_ERASE;
		prog_done = 0;
		prog_erase_done = 0;
		prog_erase_total = erase_len;
		prog_write_done = 0;
		prog_write_total = image_size;
		prog_total = prog_erase_total + prog_write_total;

		printf("Erasing entire target '%s' (%llu bytes) and writing %u bytes...\n",
		       target.name, (unsigned long long)target.limit, image_size);
		ret = recovery_rewrite_mtd_slot(mtd, ofs, target.limit, image,
						image_size, status_leds,
						&transaction_stage);
		if (ret) {
			printf("Fixed U-Boot slot transaction failed at stage %d: %d\n",
			       transaction_stage, ret);
			recovery_release_target(&target);
			return recovery_set_error(
				recovery_slot_mtd_error_stage(transaction_stage), ret);
		}
		printf("Verified the complete 1 MiB U-Boot slot by read-back\n");
	}

	/*
	 * The U-Boot slot target is raw MTD and has no UBI part of its
	 * own; the env volumes live in the runtime UBI layout partition.
	 */
	const char *env_part = current_ubi_layout ?
		current_ubi_layout->part : NULL;

	prog_phase = RECOVERY_PHASE_ENVIRONMENT;
	recovery_service_runtime(status_leds);
	if (env_part && *env_part) {
		ret = recovery_clear_uboot_environments(env_part);
		if (ret) {
			printf("U-Boot slot updated and verified, but environment clear failed: %d\n",
			       ret);
			recovery_release_target(&target);
			return recovery_set_error("environment", ret);
		}
	} else {
		printf("No UBI partition for env volumes; skipping env clear\n");
	}
	recovery_release_target(&target);

	prog_phase = RECOVERY_PHASE_DONE;
	return 0;
}

int run_http_recovery(void)
{
	struct udevice *udev;
	struct netif *netif;
	struct recovery_led_ctrl leds;
	struct recovery_status_led_ctrl status_leds;
	bool use_status_leds = false;
	bool dhcp_hook_registered = false;
	int rc;

	/* Defence in depth: this latch cannot be cleared until the next boot. */
	ubi_recovery_forbid_new_bad_blocks();

	/* A live hook owns its netif and server state until normal cleanup. */
	if (net_lwip_recovery_dhcp_hook_active()) {
		printf("Recovery DHCP hook is already active\n");
		return -EBUSY;
	}

	recovery_dhcp_server_stop(&recovery_dhcp_state);
	recovery_cancel_timeouts();
	recovery_active_dhcp = NULL;
	recv_off = recv_total = 0;
	post_ok = 0;
	flash_request = 0;
	reboot_request = 0;
	if (!recovery_destructive_error_latched) {
		prog_phase = RECOVERY_PHASE_IDLE;
		recovery_reset_error();
		prog_done = 0;
		prog_total = 0;
		prog_erase_done = 0;
		prog_erase_total = 0;
		prog_write_done = 0;
		prog_write_total = 0;
		recovery_clear_factory_cache();
	} else {
		printf("Recovery destructive-error lock remains active; preserving failure state\n");
	}
	recovery_ubi_attach_error = 0;
	memset(&leds, 0, sizeof(leds));
	rc = recovery_status_led_init(&status_leds);
	if (!rc) {
		use_status_leds = true;
	} else {
		printf("Recovery status LEDs unavailable (%d), fallback to link LEDs\n",
		       rc);
	}
	recovery_led_init(&leds);
	recovery_prepare_static_network();

	rc = net_lwip_eth_start();
	if (rc < 0) {
		printf("Failed to start Ethernet: %d\n", rc);
		recovery_lwip_cleanup(NULL);
		recovery_status_led_stop(&status_leds);
		recovery_status_led_release(&status_leds);
		recovery_led_stop(&leds);
		recovery_led_ctrl_free(&leds);
		return rc;
	}

	udev = eth_get_dev();
	if (!udev) {
		printf("No active net device\n");
		recovery_lwip_cleanup(NULL);
		recovery_status_led_stop(&status_leds);
		recovery_status_led_release(&status_leds);
		recovery_led_stop(&leds);
		recovery_led_ctrl_free(&leds);
		net_lwip_eth_stop();
		return -ENODEV;
	}

	netif = net_lwip_new_netif(udev);
	if (!netif) {
		recovery_lwip_cleanup(NULL);
		recovery_status_led_stop(&status_leds);
		recovery_status_led_release(&status_leds);
		recovery_led_stop(&leds);
		recovery_led_ctrl_free(&leds);
		net_lwip_eth_stop();
		return -ENODEV;
	}

	rc = recovery_dhcp_server_init(&recovery_dhcp_state, netif);
	if (rc) {
		printf("Failed to start recovery DHCP server: %d\n", rc);
	} else {
		rc = net_lwip_set_recovery_dhcp_hook(
			netif, recovery_dhcp_recv, &recovery_dhcp_state);
		if (rc) {
			printf("Failed to register recovery DHCP hook: %d\n", rc);
			recovery_dhcp_server_stop(&recovery_dhcp_state);
		} else {
			dhcp_hook_registered = true;
			recovery_active_dhcp = &recovery_dhcp_state;
		}
	}

	if (!recovery_httpd_started) {
		httpd_init();
		recovery_httpd_started = true;
	}
	printf("HTTP recovery server listening on http://%s/\n",
	       ip4addr_ntoa(netif_ip4_addr(netif)));
	if (use_status_leds)
		net_lwip_set_recovery_poll_hook(recovery_status_led_service, &status_leds);

	while (1) {
		if (tstc()) {
			int c = getchar();

			if (c == 0x03) { /* Ctrl-C */
				printf("Abort by user\n");
				break;
			}
		}
		/* net_lwip_rx() already runs sys_check_timeouts(). */
		net_lwip_rx(udev, netif);
		if (use_status_leds)
			recovery_status_led_poll(&status_leds);
		recovery_led_poll(&leds);
		if (flash_request) {
			flash_request = 0;
			printf("Upload done, flashing...\n");
			rc = flash_image(&status_leds);
			if (!rc) {
				printf("Flashing complete. Rebooting in %dms...\n",
				       REBOOT_DELAY_MS);
				reboot_request = 0;
				sys_timeout(REBOOT_DELAY_MS, reboot_delay_cb, NULL);
			} else {
				printf("Flashing failed: %d. Keeping server running.\n",
				       rc);
			}
		}
		if (reboot_request)
			do_reset(NULL, 0, 0, NULL);
		WATCHDOG_RESET();
	}

	net_lwip_set_recovery_poll_hook(NULL, NULL);
	recovery_cancel_timeouts();
	if (dhcp_hook_registered) {
		rc = net_lwip_clear_recovery_dhcp_hook(
			netif, &recovery_dhcp_state);
		if (rc) {
			printf("Failed to release recovery DHCP hook owner: %d\n", rc);
			/*
			 * Keep the global server and its owned netif alive. Clearing
			 * either after a failed owner release would leave the raw RX
			 * callback with dangling state.
			 */
			recovery_lwip_cleanup(NULL);
			goto out_local_resources;
		}
	}
	recovery_active_dhcp = NULL;
	recovery_dhcp_server_stop(&recovery_dhcp_state);
	recovery_lwip_cleanup(netif);
	rc = net_lwip_remove_netif(netif);
	if (rc) {
		printf("Failed to remove recovery lwIP netif: %d\n", rc);
		goto out_local_resources;
	}
	net_lwip_eth_stop();
	rc = 0;

out_local_resources:
	recovery_status_led_stop(&status_leds);
	recovery_status_led_release(&status_leds);
	recovery_led_stop(&leds);
	recovery_led_ctrl_free(&leds);
	return rc;
}
