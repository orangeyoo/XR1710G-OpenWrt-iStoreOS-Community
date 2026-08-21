#!/bin/sh
set -eu

BUILDER="${1:-/builder}"
ROLE_SRC="$BUILDER/files/usr/sbin/xr1710g-role"
WAN_CARRIER_SRC="$BUILDER/files/usr/sbin/xr1710g-wan-carrier"
BOOTLOG_SRC="$BUILDER/files/etc/init.d/xr1710g-bootlog"
CPUFREQ_SRC="$BUILDER/files/etc/init.d/xr1710g-cpufreq"
UBOOT_RESTORE_SRC="$BUILDER/files/etc/init.d/xr1710g-uboot-recovery-restore"
RECOVERY_RPC="$BUILDER/apps/luci-app-xr1710g-recovery/root/usr/libexec/rpcd/luci.xr1710g_recovery"
UBOOT_ENV_PATCH="$BUILDER/patches/openwrt/0101-xr1710g-fix-uboot-env-layout.patch"
POLICY_SRC="$BUILDER/files/etc/uci-defaults/zz-xr1710g-services.sh"
ROOT_DEFAULT_SRC="$BUILDER/files/etc/uci-defaults/50-root-passwd"
CUSTOM_DEFAULTS_SRC="$BUILDER/files/etc/uci-defaults/99-custom.sh"
ROOT_DEFAULT_TEST="$BUILDER/scripts/test-root-password-default.sh"
WIRELESS_SRC="$BUILDER/files/usr/sbin/xr1710g-wireless-defaults"
WIRELESS_DEFAULT_TEST="$BUILDER/scripts/test-wireless-defaults.sh"
ARGON_THEME_DEFAULT_TEST="$BUILDER/scripts/test-argon-theme-default.sh"
LAN_GUARD_SRC="$BUILDER/files/usr/sbin/xr1710g-lan-cidr-guard"
LAN_GUARD_INIT="$BUILDER/files/etc/init.d/xr1710g-lan-cidr-guard"
LAN_GUARD_HOTPLUG="$BUILDER/files/etc/hotplug.d/iface/05-xr1710g-lan-cidr-guard"
TRANSITION_PATCH="$BUILDER/patches/openwrt/0100-xr1710g-guard-transition-sysupgrade.patch"
DOCKER_CONFIG="$BUILDER/files/etc/config/dockerd"
DOCKER_KEEP="$BUILDER/files/lib/upgrade/keep.d/xr1710g-docker"
DOCKER_PATCH="$BUILDER/patches/packages/0201-dockerd-support-uci-log-options.patch"
DOCKERMAN_PATCH="$BUILDER/patches/luci/0610-dockerman-disabled-state-guidance.patch"
DOCKERMAN_MOBY29_PATCH="$BUILDER/patches/luci/0611-dockerman-moby29-info-compat.patch"
DOCKERMAN_MOBY29_TEST="$BUILDER/scripts/test-dockerman-moby29.js"
DOCKERMAN_MOBY29_FIXTURE="$BUILDER/scripts/fixtures/dockerman-moby29-info.json"
VERIFY_SCRIPT="$BUILDER/scripts/verify-xr1710g-build.sh"
RECOVERY_SCRIPT="$BUILDER/scripts/rebuild-initramfs-recovery.sh"
REGULATORY_DIY="$BUILDER/diy-part2.d/openwrt.sh"
REGULATORY_VERIFY="$BUILDER/scripts/verify-xr1710g-build.sh"
REGULATORY_LUCI_PATCH="$BUILDER/patches/luci/0600-xr1710g-per-radio-regulatory-guidance.patch"
REGULATORY_XZ_PATCH="$BUILDER/patches/regulatory/0530-xr1710g-6ghz-lab-xz.patch"
REGULATORY_LAB_DOC="$BUILDER/docs/experimental-regulatory/530-us-6ghz-lab-indoor-sp-override.patch.disabled"
REGULATORY_LAB_README="$BUILDER/docs/experimental-regulatory/README.md"
LUCI_STATIC_CIDR_PATCH="$BUILDER/patches/luci/0620-xr1710g-normalize-lan-ipv4-cidr.patch"
LUCI_STATIC_CIDR_TEST="$BUILDER/scripts/test-luci-lan-cidr.js"
LUCI_FIREWALL_FULLCONE_PATCH="$BUILDER/patches/luci/0630-luci-app-firewall-fullcone-switches.patch"
LUCI_FIREWALL_FULLCONE_TEST="$BUILDER/scripts/test-luci-firewall-fullcone.js"
ISTORE_HOME_PATCH="$BUILDER/patches/istore/0300-keep-home-routes-independent-of-quickstart-startup.patch"
ISTORE_PREPARE="$BUILDER/scripts/prepare-istore-feed.sh"
PHY_PATCH_DIR="$BUILDER/patches/kernel"
PPE_LOCAL_GUARD="$PHY_PATCH_DIR/9991-net-airoha-protect-local-bridge-flows-from-ppe-fallback.patch"
PPE_LOCAL_GUARD_SHA256='f0ce6d609b6dbdeaba19b76544c1aff437a20713e9c911edf78ae26f691cfc88'
FULLCONE_PATCH_DIR="$BUILDER/patches/fullcone"
FULLCONE_PACKAGE="$BUILDER/apps/fullconenat-nft/Makefile"
PACKAGE_CONFIG="$BUILDER/packages/openwrt.conf"
OPENWRT_CONFIG="$BUILDER/configs/openwrt.config"
FEEDS_CONFIG="$BUILDER/feeds.d/openwrt"
FAN_TEST="$BUILDER/apps/luci-app-airoha-fancontrol/tests/test-fan-control.sh"

fail() {
	echo "TOOL TEST FAILED: $*" >&2
	exit 1
}

for script in "$ROLE_SRC" "$WAN_CARRIER_SRC" "$BOOTLOG_SRC" "$CPUFREQ_SRC" "$UBOOT_RESTORE_SRC" "$RECOVERY_RPC" "$POLICY_SRC" "$ROOT_DEFAULT_SRC" "$CUSTOM_DEFAULTS_SRC" "$WIRELESS_SRC" "$LAN_GUARD_SRC" "$LAN_GUARD_INIT" "$LAN_GUARD_HOTPLUG"; do
	[ -f "$script" ] || fail "missing $script"
	sh -n "$script" || fail "syntax error in $script"
done
[ -f "$FAN_TEST" ] || fail "missing fan-control regression test"
sh "$FAN_TEST" || fail 'fan-control regression test failed'
grep -Fq 'adguardhome dockerd airoha_fan' "$REGULATORY_DIY" ||
	fail 'image assembly does not suppress the competing airoha_fan service'
grep -Fq 'root_password_is_empty()' "$ROOT_DEFAULT_SRC" ||
	fail 'first-login password policy lacks an empty-hash guard'
grep -Fq "json_get_var root_password_hash root_password_hash ''" \
	"$ROOT_DEFAULT_SRC" &&
	grep -Fq "json_get_var root_password_plain root_password_plain ''" \
	"$ROOT_DEFAULT_SRC" ||
	fail 'first-login password policy does not tolerate absent optional JSON members'
grep -Fq 'if [ -n "${root_password_plain:-}" ] && root_password_is_empty; then' \
	"$ROOT_DEFAULT_SRC" ||
	fail 'plain first-login password can overwrite an existing root hash'
grep -Fq 'if [ -n "${root_password_hash:-}" ] && root_password_is_empty; then' \
	"$ROOT_DEFAULT_SRC" ||
	fail 'hashed first-login password can overwrite an existing root hash'
[ -f "$ROOT_DEFAULT_TEST" ] || fail "missing $ROOT_DEFAULT_TEST"
sh -n "$ROOT_DEFAULT_TEST" ||
	fail 'first-login password regression test has invalid shell syntax'
if grep -Eq '^set -[^[:space:]]*u' "$ROOT_DEFAULT_SRC"; then
	fail 'first-login password policy enables nounset and is incompatible with OpenWrt jshn'
fi
sh "$ROOT_DEFAULT_TEST" "$ROOT_DEFAULT_SRC" "$CUSTOM_DEFAULTS_SRC" ||
	fail 'first-login password regression test failed'
[ -f "$WIRELESS_DEFAULT_TEST" ] || fail "missing $WIRELESS_DEFAULT_TEST"
sh -n "$WIRELESS_DEFAULT_TEST" ||
	fail 'wireless-default regression test has invalid shell syntax'
sh "$WIRELESS_DEFAULT_TEST" "$WIRELESS_SRC" ||
	fail 'wireless-default regression test failed'
[ -f "$ARGON_THEME_DEFAULT_TEST" ] ||
	fail "missing $ARGON_THEME_DEFAULT_TEST"
sh -n "$ARGON_THEME_DEFAULT_TEST" ||
	fail 'Argon theme-default regression test has invalid shell syntax'
grep -Fq 'ARGON_THEME_DEFAULT_TEST=' "$VERIFY_SCRIPT" &&
	grep -Fq 'reject_manifest_pkg luci-theme-glass' "$VERIFY_SCRIPT" &&
	grep -Fq "find \"\$image_root\" -iname '*glass*'" "$VERIFY_SCRIPT" || {
	fail 'final image verifier does not prove Argon default semantics and GlassTheme absence'
}
grep -Fqx 'CONFIG_PACKAGE_luci-theme-argon=y' "$PACKAGE_CONFIG" ||
	fail 'Argon is not selected for the XR1710G image'
grep -Fqx '# CONFIG_PACKAGE_luci-theme-glass is not set' "$OPENWRT_CONFIG" &&
	grep -Fqx '# CONFIG_PACKAGE_luci-i18n-glass-zh-cn is not set' \
		"$OPENWRT_CONFIG" || {
	fail 'OpenWrt configuration does not explicitly deselect both GlassTheme packages'
}
grep -Fq 'for glass_pkg in luci-theme-glass luci-i18n-glass-zh-cn; do' \
	"$REGULATORY_DIY" &&
	grep -Fq '/[[:space:]]luci-i18n-glass-zh-cn[[:space:]]*\\$/d' \
	"$REGULATORY_DIY" &&
	grep -Fq 'luci-theme-glass([[:space:]]|$)' "$REGULATORY_DIY" &&
	grep -Fq 'XR1710G profile still selects GlassTheme' "$REGULATORY_DIY" || {
	fail 'DIY step does not remove and verify both YYH GlassTheme profile packages'
}
if grep -Eq "^[[:space:]]*uci[[:space:]]+-q[[:space:]]+set[[:space:]]+luci\\.main\\.mediaurlbase=" \
	"$CUSTOM_DEFAULTS_SRC"; then
	fail 'XR1710G overlay forces a LuCI theme again during sysupgrade'
fi
grep -Fq 'ucidef_set_root_password_plain "password"' "$REGULATORY_DIY" ||
	fail 'DIY step no longer pins the reviewed XR1710G first-login credential'
if grep -Eq "sed -i .*ucidef_set_root_password_plain.*password.*d" "$REGULATORY_DIY"; then
	fail 'DIY step still removes the reviewed XR1710G first-login credential'
fi
[ -f "$LUCI_STATIC_CIDR_PATCH" ] || fail "missing $LUCI_STATIC_CIDR_PATCH"
[ -f "$LUCI_STATIC_CIDR_TEST" ] || fail "missing $LUCI_STATIC_CIDR_TEST"
node --check "$LUCI_STATIC_CIDR_TEST" ||
	fail 'LuCI LAN CIDR executable regression test has invalid JavaScript'
[ -f "$ISTORE_HOME_PATCH" ] || fail "missing $ISTORE_HOME_PATCH"
[ -f "$ISTORE_PREPARE" ] || fail "missing $ISTORE_PREPARE"
sh -n "$ISTORE_PREPARE" || fail "syntax error in $ISTORE_PREPARE"
grep -Fq 'normalizeLanIPv4(section_id, value, netmask)' "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch does not expose its normalization helper'
grep -Fq 'sanitizeLanIPv4(section_id, value)' "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch does not expose its sparse-value sanitizer'
grep -Fq 'cfgvalue = sanitizeLanIPv4(section_id, cfgvalue)' "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN render path does not sanitize values before widget validation'
grep -Fq "typeof netmask == 'string' && netmask != ''" "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch can pass an absent netmask into maskToPrefix'
if grep -Fq 'let prefix = network.maskToPrefix(netmask);' "$LUCI_STATIC_CIDR_PATCH"; then
	fail 'LuCI LAN CIDR patch still dereferences an absent legacy netmask'
fi
grep -Fq 'or(cidr4,ipmask4,ip4addr("nomask"))' "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch does not accept a bare address before normalization'
grep -Fq 'o.forcewrite = true' "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch does not repair an unchanged legacy value on save'
grep -Fq "typeof a == 'string' && a.indexOf('/') > 0" "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch does not guard sparse IPv4 list entries'
grep -Fq "if (typeof a != 'string' || a == '')" "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI gateway validation can still split a sparse IPv4 list entry'
grep -Fq 'modules/luci-mod-network/htdocs/luci-static/resources/view/network/interfaces.js' \
	"$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch does not cover the network interfaces view'
grep -Fq 'modules/luci-base/ucode/template/header.ut' "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch does not version the shared resource loader'
grep -Fq 'xr-ui-20260820' "$LUCI_STATIC_CIDR_PATCH" ||
	fail 'LuCI LAN CIDR patch lacks a deterministic cache-busting version'
grep -Fq '"$luci_static_protocol" "$luci_interfaces_view"' "$REGULATORY_DIY" ||
	fail 'DIY step does not execute the two-file LuCI LAN regression test'
grep -Fq 'www/luci-static/resources/view/network/interfaces.js' "$VERIFY_SCRIPT" ||
	fail 'image verifier does not inspect the final LuCI network interfaces view'
grep -Fq 'usr/share/ucode/luci/template/header.ut' "$VERIFY_SCRIPT" ||
	fail 'image verifier does not inspect the final LuCI resource version'
if grep -Fq 'pgrep quickstart' "$ISTORE_HOME_PATCH" ||
	grep -Fq 'redirect_fallback' "$ISTORE_HOME_PATCH"; then
	:
else
	fail 'iStore home patch no longer documents the startup-race anchors'
fi
grep -Fq 'pgrep quickstart' "$ISTORE_PREPARE" ||
	fail 'iStore feed preparation does not guard the startup-race baseline'
grep -Fq 'redirect_fallback' "$ISTORE_PREPARE" ||
	fail 'iStore feed preparation does not reject stale fallback routes'

[ -f "$UBOOT_ENV_PATCH" ] || fail "missing $UBOOT_ENV_PATCH"
grep -Fq '"0x4000" "0x1f000"' "$UBOOT_ENV_PATCH" ||
	fail 'XR1710G U-Boot environment layout is not fixed at 0x4000'
grep -Fq "grep -Ec '^/dev/ubi[0-9]+_[0-9]+[[:space:]]+0x0[[:space:]]+0x4000" "$UBOOT_ENV_PATCH" ||
	fail 'preserved XR1710G U-Boot environments are not migrated by exact layout validation'
grep -Fq 'native_one_shot_supported' "$RECOVERY_RPC" ||
	fail 'recovery RPC lacks native one-shot capability detection'
grep -Fq "fw_setenv recovery_trigger 1" "$RECOVERY_RPC" ||
	fail 'native recovery path does not arm the advertised trigger'
if grep -Eq 'legacy_one_shot_supported|legacy-double-reset|xr1710g_recovery_stage|recovery_port 10g' "$RECOVERY_RPC"; then
	fail 'unverified legacy software recovery path is still exposed'
fi
grep -Fq 'fw_setenv bootcmd "$backup"' "$UBOOT_RESTORE_SRC" ||
	fail 'boot service does not restore the saved bootcmd'
grep -Fq 'fw_setenv xr1710g_recovery_stage1' "$UBOOT_RESTORE_SRC" ||
	fail 'boot service does not clear legacy recovery stage 1'
grep -Fq 'fw_setenv xr1710g_recovery_stage2' "$UBOOT_RESTORE_SRC" ||
	fail 'boot service does not clear legacy recovery stage 2'
grep -Fq 'fw_setenv xr1710g_recovery_once' "$UBOOT_RESTORE_SRC" ||
	fail 'boot service does not clear the obsolete legacy trigger'
grep -Fq '/etc/init.d/xr1710g-uboot-recovery-restore enable' "$POLICY_SRC" ||
	fail 'obsolete recovery-variable cleanup service is not enabled'

grep -Fq "xr1710g_governor='performance'" "$POLICY_SRC" ||
	fail 'first-boot service policy does not persist the validated performance default'
grep -Fq '/etc/init.d/xr1710g-lan-cidr-guard enable' "$POLICY_SRC" ||
	fail 'first-boot service policy does not enable the LAN CIDR guard'
grep -Fq '/etc/init.d/xr1710g-lan-cidr-guard start' "$POLICY_SRC" ||
	fail 'first-boot service policy does not run the LAN CIDR guard'
grep -Fq '/etc/init.d/xr1710g-cpufreq enable' "$POLICY_SRC" ||
	fail 'first-boot service policy does not enable cpufreq replay'
grep -Fq 'system.@system[0].xr1710g_governor' "$CPUFREQ_SRC" ||
	fail 'cpufreq service does not load the persistent governor'
grep -Fq 'policy[0-9]*' "$CPUFREQ_SRC" ||
	fail 'cpufreq service does not apply all CPU policies'

for docker_file in \
	"$DOCKER_CONFIG" \
	"$DOCKER_KEEP" \
	"$DOCKER_PATCH" \
	"$DOCKERMAN_PATCH" \
	"$DOCKERMAN_MOBY29_PATCH" \
	"$DOCKERMAN_MOBY29_TEST" \
	"$DOCKERMAN_MOBY29_FIXTURE"; do
	[ -f "$docker_file" ] || fail "missing $docker_file"
done
node --check "$DOCKERMAN_MOBY29_TEST" ||
	fail 'Dockerman Moby 29 DOM regression test has invalid JavaScript'
node -e 'const fs = require("fs"); const v = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); if (!String(v.ServerVersion || "").startsWith("29.") || typeof v.Plugins !== "object" || typeof v.RegistryConfig !== "object" || typeof v.Containerd !== "object") process.exit(1)' "$DOCKERMAN_MOBY29_FIXTURE" ||
	fail 'Dockerman Moby 29 regression fixture lacks required nested structures'
[ -f "$VERIFY_SCRIPT" ] || fail "missing $VERIFY_SCRIPT"
[ -f "$RECOVERY_SCRIPT" ] || fail "missing $RECOVERY_SCRIPT"
for regulatory_file in \
	"$REGULATORY_DIY" \
	"$REGULATORY_VERIFY" \
	"$REGULATORY_LUCI_PATCH" \
	"$REGULATORY_XZ_PATCH" \
	"$REGULATORY_LAB_DOC" \
	"$REGULATORY_LAB_README"; do
	[ -f "$regulatory_file" ] || fail "missing $regulatory_file"
done
grep -Fq 'cp "$regdb_xz_patch" "$regdb_lab_patch"' "$REGULATORY_DIY" ||
	fail 'DIY step does not install the isolated XZ laboratory profile'
grep -Fq 'This is not a real AFC implementation.' "$REGULATORY_LAB_DOC" ||
	fail 'disabled laboratory patch lacks its no-AFC warning'
grep -Fq '`XZ` 默认关闭且绝不自动启用' "$REGULATORY_LAB_README" ||
	fail 'laboratory documentation does not state the opt-in default'
grep -Fq 'country XZ: DFS-ETSI' "$REGULATORY_XZ_PATCH" ||
	fail 'laboratory rule is not isolated under XZ'
grep -Fq '(2400 - 2483.5 @ 40), (4000 mW)' "$REGULATORY_XZ_PATCH" ||
	fail 'XZ composite profile lacks the AU 2.4 GHz rule'
grep -Fq '(5730 - 5850 @ 80), (4000 mW), AUTO-BW' "$REGULATORY_XZ_PATCH" ||
	fail 'XZ composite profile lacks the AU 5 GHz high-power rule'
grep -Fq 'XR1710G composite laboratory profile (AU 2.4/5 GHz + 6 GHz 36 dBm, no AFC)' "$REGULATORY_LUCI_PATCH" ||
	fail 'LuCI patch lacks the explicit laboratory selector'
grep -Fq 'all three bands through one shared PHY' "$REGULATORY_LUCI_PATCH" ||
	fail 'LuCI patch lacks the shared-PHY explanation'
grep -Fq "uci.set('wireless', radio['.name'], 'country', 'XZ')" "$REGULATORY_LUCI_PATCH" ||
	fail 'LuCI patch does not persist XZ across all shared-PHY radio sections'
grep -Fq 'XZ laboratory profile is enabled by default' "$REGULATORY_VERIFY" ||
	fail 'image verifier does not prevent automatic XZ activation'

[ -f "$PHY_PATCH_DIR/0923-net-pcs-airoha-an7581-rx-lock-diagnostics.patch" ] ||
	fail 'AN7581 RX-lock diagnostics patch is missing'
grep -Fq 'action=%s resets=%u' \
	"$PHY_PATCH_DIR/0923-net-pcs-airoha-an7581-rx-lock-diagnostics.patch" ||
	fail 'AN7581 RX-lock diagnostics are missing'
[ -f "$PPE_LOCAL_GUARD" ] ||
	fail 'Airoha PPE local-flow guard is missing'
[ "$(sha256sum "$PPE_LOCAL_GUARD" | awk '{print $1}')" = \
	"$PPE_LOCAL_GUARD_SHA256" ] ||
	fail 'Airoha PPE local-flow guard hash changed'
grep -Fq 'test_bit(BR_FDB_LOCAL, &f->flags)' "$PPE_LOCAL_GUARD" ||
	fail 'bridge forward-path does not reject local FDB entries'
grep -Fq 'u8 daddr[ETH_ALEN + 2] = {};' "$PPE_LOCAL_GUARD" ||
	fail 'Airoha PPE local-flow guard lacks a padded destination buffer'
grep -Fq 'is_etherdev_addr(master, daddr)' "$PPE_LOCAL_GUARD" ||
	fail 'Airoha PPE fallback does not reject bridge-master addresses'
grep -Fq 'egress == skb->dev' "$PPE_LOCAL_GUARD" ||
	fail 'Airoha PPE fallback does not reject same-ingress hairpins'
grep -Fq 'is_etherdev_addr(egress, daddr)' "$PPE_LOCAL_GUARD" ||
	fail 'Airoha PPE fallback does not reject egress-device addresses'
grep -Fq '9991-net-airoha-protect-local-bridge-flows-from-ppe-fallback.patch' \
	"$REGULATORY_DIY" ||
	fail 'DIY script does not install the Airoha PPE local-flow guard'
grep -Fq "ppe_bridge_base_sha256='f7aceb4b5850b2d03a8c954a443b1a2acb809e14b878765e6a17dc90459083ea'" \
	"$REGULATORY_DIY" &&
	grep -Fq "ppe_local_guard_sha256='$PPE_LOCAL_GUARD_SHA256'" \
	"$REGULATORY_DIY" ||
	fail 'DIY script does not lock both Airoha PPE patch hashes'
for retired_patch in \
	"$PHY_PATCH_DIR/0922-net-phy-realtek-allow-xr1710g-sds-mode.patch" \
	"$PHY_PATCH_DIR/0924-net-phy-realtek-xr1710g-init-diagnostics.patch" \
	"$PHY_PATCH_DIR/0925-arm64-dts-airoha-xr1710g-set-rtl826x-sds-mode.patch"; do
	[ ! -e "$retired_patch" ] ||
		fail "failed RTL826x forced-SDS experiment is still present: $retired_patch"
done
grep -Fq '922-net-phy-realtek-allow-xr1710g-sds-mode.patch' "$REGULATORY_DIY" &&
	grep -Fq 'rm -f \' "$REGULATORY_DIY" ||
	fail 'DIY script does not remove stale forced-SDS kernel patches'
grep -Fq "grep -Fq 'realtek,sds-mode' \"\$xr_phy_dts\"" "$REGULATORY_DIY" ||
	fail 'DIY script does not reject stale forced-SDS device-tree properties'
grep -Fq '620-net-pcs-airoha-fix-USXGMII-rate-adaptation-on-speed.patch' "$REGULATORY_DIY" ||
	fail 'DIY script does not preserve the YYH USXGMII speed adaptation'
grep -Fq '621-net-pcs-airoha-AN7581-add-global-digital-reset-for.patch' "$REGULATORY_DIY" ||
	fail 'DIY script does not preserve the YYH speed-change digital reset'
grep -Fq '0103-wifi-mt76-mt7996-set-skb-device-for-npu-rx.patch' "$REGULATORY_DIY" ||
	fail 'DIY script does not install the reviewed MT7996 NPU RX ingress fix'
[ -f "$BUILDER/patches/mt76/0103-wifi-mt76-mt7996-set-skb-device-for-npu-rx.patch" ] ||
	fail 'MT7996 NPU RX ingress patch is missing'
grep -Fq 'mt76_queue_is_npu_rx' \
	"$BUILDER/patches/mt76/0103-wifi-mt76-mt7996-set-skb-device-for-npu-rx.patch" ||
	fail 'MT7996 NPU RX ingress patch lacks NPU queue gating'
grep -Fq 'skb->dev = ieee80211_vif_to_wdev(vif)->netdev' \
	"$BUILDER/patches/mt76/0103-wifi-mt76-mt7996-set-skb-device-for-npu-rx.patch" ||
	fail 'MT7996 NPU RX ingress patch lacks skb device assignment'
[ -f "$FULLCONE_PACKAGE" ] || fail "missing $FULLCONE_PACKAGE"
grep -Fq 'define KernelPackage/nft-fullcone' "$FULLCONE_PACKAGE" ||
	fail 'Full Cone NAT kernel package is incomplete'
for fullcone_patch in \
	"$FULLCONE_PATCH_DIR/0100-libnftnl-add-fullcone-expression-support.patch" \
	"$FULLCONE_PATCH_DIR/0101-nftables-add-fullcone-expression-support.patch" \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch"; do
	[ -f "$fullcone_patch" ] || fail "missing $fullcone_patch"
done
grep -Fq 'expr_ops_fullcone' \
	"$FULLCONE_PATCH_DIR/0100-libnftnl-add-fullcone-expression-support.patch" ||
	fail 'libnftnl Full Cone expression support is missing'
grep -Fq -- '--- a/src/Makefile.in' \
	"$FULLCONE_PATCH_DIR/0100-libnftnl-add-fullcone-expression-support.patch" ||
	fail 'libnftnl Full Cone patch does not update the generated Makefile'
grep -Fq 'expr/fullcone.lo' \
	"$FULLCONE_PATCH_DIR/0100-libnftnl-add-fullcone-expression-support.patch" ||
	fail 'libnftnl generated Makefile does not compile the Full Cone object'
grep -Fq 'NFT_NAT_FULLCONE' \
	"$FULLCONE_PATCH_DIR/0101-nftables-add-fullcone-expression-support.patch" ||
	fail 'nftables Full Cone expression support is missing'
grep -Fq 'delete defs.fullcone6;' \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" ||
	fail 'firewall4 capability fallback does not disable IPv6 Full Cone'
grep -Fq 'zone.masq4_src_subnets' \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" &&
	grep -Fq 'zone.masq4_dest_subnets' \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" &&
	grep -Fq 'zone.masq6_src_subnets' \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" &&
	grep -Fq 'zone.masq6_dest_subnets' \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" ||
	fail 'firewall4 Full Cone srcnat no longer preserves masquerade address restrictions'
grep -Fq 'defs.fullcone && !nft_try_fullcone(4)' \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" &&
	grep -Fq 'defs.fullcone6 && !nft_try_fullcone(6)' \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" ||
	fail 'firewall4 Full Cone capability probes are not independently gated by family'
if grep '^+' "$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" |
	grep -Fq 'zone.auto_helper && !(zone.masq || zone.masq6 ||'; then
	fail 'firewall4 Full Cone patch still suppresses helpers on unrelated zones'
fi
grep -Fq "$(printf '+\toption fullcone\t\t0')" \
	"$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" ||
	fail 'firewall4 Full Cone support is not disabled by default'
if grep '^+' "$FULLCONE_PATCH_DIR/0102-firewall4-add-support-for-fullcone-nat.patch" |
	grep -Eq 'option fullcone[[:space:]]+1'; then
	fail 'firewall4 Full Cone support is enabled by default'
fi
[ -f "$LUCI_FIREWALL_FULLCONE_PATCH" ] ||
	fail 'LuCI Full Cone NAT controls are missing'
[ -f "$LUCI_FIREWALL_FULLCONE_TEST" ] ||
	fail 'LuCI Full Cone NAT regression test is missing'
node --check "$LUCI_FIREWALL_FULLCONE_TEST" ||
	fail 'LuCI Full Cone NAT regression test has invalid JavaScript'
grep -Fq "s.option(form.Flag, 'fullcone'," "$LUCI_FIREWALL_FULLCONE_PATCH" &&
	grep -Fq "s.option(form.Flag, 'fullcone6'," "$LUCI_FIREWALL_FULLCONE_PATCH" ||
	fail 'LuCI Full Cone NAT does not expose independent IPv4/IPv6 switches'
grep -Fq "o.default = '0'" "$LUCI_FIREWALL_FULLCONE_PATCH" ||
	fail 'LuCI Full Cone NAT switches are not explicitly disabled by default'
grep -Fq 'It cannot bypass CGNAT or double NAT.' "$LUCI_FIREWALL_FULLCONE_PATCH" ||
	fail 'LuCI Full Cone NAT safety boundary is missing'
grep -Fqx 'CONFIG_PACKAGE_phytool=y' "$PACKAGE_CONFIG" ||
	fail 'phytool is not selected for explicit MDIO diagnostics'
grep -Fqx 'CONFIG_PACKAGE_kmod-nft-fullcone=y' "$PACKAGE_CONFIG" ||
	fail 'kmod-nft-fullcone is not selected'
[ -f "$FEEDS_CONFIG" ] || fail "missing $FEEDS_CONFIG"
grep -Fqx \
	'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^50de2d79993447258b1bc15a667a6fb1cd6e7222' \
	"$FEEDS_CONFIG" ||
	fail 'PassWall runtime feed is not pinned to the reviewed revision'
grep -Fqx \
	'src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git^bb547ac49d845305a9df2d808c1d2f23ed7eaed3' \
	"$FEEDS_CONFIG" ||
	fail 'PassWall2 feed is not pinned to version 26.8.20'
passwall_runtime_line="$(grep -n '^src-git passwall_packages ' "$FEEDS_CONFIG" |
	cut -d: -f1)"
packages_line="$(grep -n '^src-git packages ' "$FEEDS_CONFIG" | cut -d: -f1)"
[ -n "$passwall_runtime_line" ] && [ -n "$packages_line" ] &&
	[ "$passwall_runtime_line" -lt "$packages_line" ] ||
	fail 'PassWall runtime feed must precede the duplicate official core packages'
for passwall_config in \
	CONFIG_PACKAGE_luci-app-passwall2=y \
	CONFIG_PACKAGE_luci-i18n-passwall2-zh-cn=y \
	CONFIG_PACKAGE_luci-app-passwall2_Basic_Core_All=y \
	CONFIG_PACKAGE_luci-app-passwall2_Nftables_Transparent_Proxy=y; do
	grep -Fqx "$passwall_config" "$PACKAGE_CONFIG" ||
		fail "PassWall2 selection is missing: $passwall_config"
done
grep -Fq "passwall2_commit='bb547ac49d845305a9df2d808c1d2f23ed7eaed3'" \
	"$REGULATORY_DIY" &&
	grep -Fq "passwall_packages_commit='50de2d79993447258b1bc15a667a6fb1cd6e7222'" \
	"$REGULATORY_DIY" &&
	grep -Fq "option enabled '0'" "$REGULATORY_DIY" &&
	grep -Fq 'package/feeds/passwall_packages/xray-core' "$REGULATORY_DIY" &&
	grep -Fq 'package/feeds/passwall_packages/sing-box' "$REGULATORY_DIY" &&
	grep -Fq 'package/feeds/passwall_packages/v2ray-geodata' "$REGULATORY_DIY" || {
	fail 'DIY step does not lock PassWall2 versions, package precedence and disabled default'
}
for yyh_anchor in \
	'179-v7.2-net-airoha-fix-BQL-underflow-in-shared-QDMA-TX-ring.patch' \
	'180-v7.3-net-airoha-fix-max-receive-size-configuration.patch' \
	'181-v7.3-net-airoha-dma-map-xmit-frags-with-skb_frag_dma_map.patch' \
	'922-net-airoha-classify-external-lan-ports-from-DT.patch'; do
	grep -Fq "$yyh_anchor" "$REGULATORY_DIY" ||
		fail "DIY step does not lock the YYH Ethernet baseline: $yyh_anchor"
done
grep -Fq 'usr/sbin/runc \' "$VERIFY_SCRIPT" ||
	fail 'image verifier does not follow the upstream OpenWrt runc path'
if grep -Fq 'usr/bin/runc' "$VERIFY_SCRIPT"; then
	fail 'image verifier still expects the non-upstream runc path'
fi
grep -Fq 'uci -q get dockerd.globals.data_root' "$VERIFY_SCRIPT" ||
	fail 'image verifier does not follow the pinned iStore Docker helper'
grep -Fq -- "-name 'S??dockerd'" "$RECOVERY_SCRIPT" ||
	fail 'recovery rebuild does not remove dockerd autostart'
grep -Fq -- "-name 'K??dockerd'" "$RECOVERY_SCRIPT" ||
	fail 'recovery rebuild does not leave dockerd fully disabled'
grep -Fq -- "-name 'S??airoha_fan'" "$RECOVERY_SCRIPT" ||
	fail 'recovery rebuild does not remove the competing legacy fan autostart'
grep -Fq -- "-name 'K??airoha_fan'" "$RECOVERY_SCRIPT" ||
	fail 'recovery rebuild does not leave the competing legacy fan controller fully disabled'
grep -Fq "option data_root '/overlay/docker/'" "$DOCKER_CONFIG" ||
	fail 'Docker does not use the full writable UBIFS overlay'
grep -Fq "option log_driver 'local'" "$DOCKER_CONFIG" ||
	fail 'Docker does not use the bounded local log driver'
grep -Fq "list log_opts 'max-size=5m'" "$DOCKER_CONFIG" ||
	fail 'Docker max-size policy is missing'
grep -Fq "list log_opts 'max-file=3'" "$DOCKER_CONFIG" ||
	fail 'Docker max-file policy is missing'
grep -Fqx '/etc/rc.d/S99dockerd' "$DOCKER_KEEP" ||
	fail 'Docker enabled state is not preserved across sysupgrade'
grep -Fq 'config_list_foreach globals log_opts json_add_log_option' "$DOCKER_PATCH" ||
	fail 'OpenWrt dockerd UCI log-options patch is incomplete'
[ "$(sha256sum "$DOCKER_PATCH" | cut -d' ' -f1)" = \
	'f2851e370a83380903c1933b59978ac90a1cf8c08b544144a3c8bc6a281654bd' ] ||
	fail 'OpenWrt dockerd UCI log-options patch hash changed'
grep -Fq "handleEnableAndStart(ev)" "$DOCKERMAN_PATCH" ||
	fail 'Dockerman stopped-state patch lacks its enable-and-start action'
grep -Fq "Docker is installed but disabled by default" "$DOCKERMAN_PATCH" ||
	fail 'Dockerman stopped-state patch lacks owner guidance'
grep -Fq "renderNestedDockerInfo(info)" "$DOCKERMAN_MOBY29_PATCH" ||
	fail 'Dockerman Moby 29 patch lacks its nested-info renderer'
grep -Fq "white-space: pre-wrap; overflow-wrap: anywhere" "$DOCKERMAN_MOBY29_PATCH" ||
	fail 'Dockerman Moby 29 patch can still widen the page with nested JSON'
grep -Fq 'node "$dockerman_moby29_test" "$dockerman_overview" "$dockerman_moby29_fixture"' "$REGULATORY_DIY" ||
	fail 'feed preparation does not execute the Dockerman Moby 29 DOM regression test'
grep -Fq "ip link set dev \"\$wan_device\" up" "$WAN_CARRIER_SRC" ||
	fail 'WAN carrier helper does not administratively raise the physical device'
grep -Fq 'carrier=0' "$WAN_CARRIER_SRC" ||
	fail 'WAN carrier helper does not report a no-carrier result'

[ -f "$TRANSITION_PATCH" ] || fail "missing $TRANSITION_PATCH"
grep -Fq 'XR1710G UBI 2.0 boundaries are not active; refusing normal sysupgrade.' \
	"$TRANSITION_PATCH" || fail 'transition patch lacks the fail-closed platform guard'
for boundary in \
	'vendor 00600000' \
	'chainloader 00100000' \
	'ubi 1b700000' \
	'reserved_bmt 04200000'; do
	grep -Fq "xr_mtd_size_is $boundary" "$TRANSITION_PATCH" ||
		fail "transition platform guard lacks boundary: $boundary"
done
grep -Fq 'DEVICE_COMPAT_VERSION := 1.0' "$TRANSITION_PATCH" ||
	fail 'layout-aware image metadata is not stable at compatibility 1.0'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM
mkdir -p "$tmp/bin" "$tmp/state"

cat > "$tmp/bin/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = '-u' ] && { echo 0; exit 0; }
exec /usr/bin/id "$@"
EOF

cat > "$tmp/bin/board_name" <<'EOF'
#!/bin/sh
echo econet,xr1710g-ubi
EOF

cat > "$tmp/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF

cat > "$tmp/bin/wifi" <<'EOF'
#!/bin/sh
set -eu
[ "${1:-}" = 'config' ] || exit 1
db="${XR_TEST_STATE:?}/uci.db"

# Match the real boot sequence: no wireless UCI exists before this command.
# The fixture then represents incremental mac80211 discovery after kmodloader.
if ! grep -q '^wireless\.radio0\.band=' "$db"; then
	cat >> "$db" <<'RADIOS'
wireless.radio0.band=2g
wireless.default_radio0.device=radio0
wireless.default_radio0.mode=ap
wireless.default_radio0.ssid=XR1710G
wireless.default_radio0.encryption=none
wireless.default_radio0.disabled=0
RADIOS
fi

if [ "${XR_TEST_WIFI_MODE:-complete}" != 'missing5' ] &&
	! grep -q '^wireless\.radio1\.band=' "$db"; then
	cat >> "$db" <<'RADIO5'
wireless.radio1.band=5g
wireless.default_radio1.device=radio1
wireless.default_radio1.mode=ap
wireless.default_radio1.ssid=XR1710G-5G
wireless.default_radio1.encryption=none
wireless.default_radio1.disabled=0
RADIO5
fi

if { [ "${XR_TEST_WIFI_MODE:-complete}" = 'complete' ] ||
	[ "${XR_TEST_WIFI_MODE:-complete}" = 'missing5' ]; } &&
	! grep -q '^wireless\.radio2\.band=' "$db"; then
	cat >> "$db" <<'RADIO6'
wireless.radio2.band=6g
wireless.default_radio2.device=radio2
wireless.default_radio2.mode=ap
wireless.default_radio2.ssid=XR1710G-6G
wireless.default_radio2.encryption=owe
wireless.default_radio2.owe_groups=19
wireless.default_radio2.key=
wireless.default_radio2.disabled=0
RADIO6
fi
EOF

cat > "$tmp/bin/ipcalc.sh" <<'EOF'
#!/bin/sh
case "$1" in
	192.168.10.0/24) ip=192.168.10.0; network=192.168.10.0 ;;
	192.168.10.1/24) ip=192.168.10.1; network=192.168.10.0 ;;
	192.168.10.2/24) ip=192.168.10.2; network=192.168.10.0 ;;
	192.168.20.1/24) ip=192.168.20.1; network=192.168.20.0 ;;
	*) exit 1 ;;
esac
echo "IP=$ip"
echo 'NETMASK=255.255.255.0'
echo "NETWORK=$network"
echo "BROADCAST=${network%.*}.255"
echo 'PREFIX=24'
EOF

cat > "$tmp/bin/uci" <<'EOF'
#!/bin/sh
set -eu
db="${XR_TEST_STATE:?}/uci.db"
touch "$db"
cmd="${1:-}"
[ "$cmd" != '-q' ] || { shift; cmd="${1:-}"; }
shift || true
case "$cmd" in
	get)
		key="$1"
		awk -v key="$key" 'index($0, key "=") == 1 { print substr($0, length(key) + 2) }' \
			"$db" | tail -n1
		;;
	show)
		key="${1:-}"
		if [ -z "$key" ]; then
			cat "$db"
		else
			awk -v key="$key" \
				'index($0, key "=") == 1 || index($0, key ".") == 1' "$db"
		fi
		;;
	set)
		assignment="$1"; key="${assignment%%=*}"; value="${assignment#*=}"
		awk -v key="$key" 'index($0, key "=") != 1' "$db" > "$db.tmp"
		mv "$db.tmp" "$db"
		printf '%s=%s\n' "$key" "$value" >> "$db"
		;;
	add_list)
		assignment="$1"; key="${assignment%%=*}"; value="${assignment#*=}"
		old="$(awk -v key="$key" \
			'index($0, key "=") == 1 { print substr($0, length(key) + 2) }' \
			"$db" | tail -n1)"
		awk -v key="$key" 'index($0, key "=") != 1' "$db" > "$db.tmp"
		mv "$db.tmp" "$db"
		printf '%s=%s%s%s\n' "$key" "$old" "${old:+ }" "$value" >> "$db"
		;;
	delete)
		key="$1"
		if ! awk -v key="$key" \
			'index($0, key "=") == 1 || index($0, key ".") == 1 { found=1 } END { exit !found }' \
			"$db"; then
			exit 1
		fi
		awk -v key="$key" 'index($0, key "=") != 1 && index($0, key ".") != 1' \
			"$db" > "$db.tmp"
		mv "$db.tmp" "$db"
		;;
	commit) : ;;
	export)
		case "$1" in
			network|dhcp|system) grep -E "^$1\." "$db" || true ;;
			*) exit 1 ;;
		esac
		;;
	*) echo "unsupported test uci command: $cmd" >&2; exit 1 ;;
esac
EOF

chmod 0755 "$tmp/bin"/*
export XR_TEST_STATE="$tmp/state"
export PATH="$tmp/bin:/usr/bin:/bin"

lan_guard="$tmp/xr1710g-lan-cidr-guard"
cp "$LAN_GUARD_SRC" "$lan_guard"
chmod 0755 "$lan_guard"

# The current OpenWrt base stores static IPv4 addresses as CIDR list values.
# Exercise the guard against the two legacy forms that caused the observed
# /32 LAN and missing DHCP range, plus an invalid mask that must fail closed.
cat > "$XR_TEST_STATE/uci.db" <<'EOF'
network.lan.proto=static
network.lan.ipaddr=192.168.50.1/24
EOF
"$lan_guard" --check ||
	fail 'CIDR-form LAN address was incorrectly marked for repair'

cat > "$XR_TEST_STATE/uci.db" <<'EOF'
network.lan.proto=static
network.lan.ipaddr=192.168.50.1
EOF
"$lan_guard" --check >/dev/null 2>&1 &&
	fail 'bare LAN address was incorrectly accepted as already normalized'
"$lan_guard"
grep -qx 'network.lan.ipaddr=192.168.50.1/24' "$XR_TEST_STATE/uci.db" ||
	fail 'bare LAN address was not normalized to the default /24'
if grep -q '^network.lan.netmask=' "$XR_TEST_STATE/uci.db"; then
	fail 'CIDR guard retained a redundant legacy netmask'
fi

cat > "$XR_TEST_STATE/uci.db" <<'EOF'
network.lan.proto=static
network.lan.ipaddr=192.168.20.1
network.lan.netmask=255.255.0.0
EOF
"$lan_guard"
grep -qx 'network.lan.ipaddr=192.168.20.1/16' "$XR_TEST_STATE/uci.db" ||
	fail 'explicit legacy netmask was not preserved as its /16 prefix'
if grep -q '^network.lan.netmask=' "$XR_TEST_STATE/uci.db"; then
	fail 'explicit legacy netmask was not removed after CIDR conversion'
fi

cat > "$XR_TEST_STATE/uci.db" <<'EOF'
network.lan.proto=static
network.lan.ipaddr=192.168.30.1
network.lan.netmask=255.0.255.0
EOF
if "$lan_guard" >/dev/null 2>&1; then
	fail 'invalid legacy netmask was silently accepted'
fi
grep -qx 'network.lan.ipaddr=192.168.30.1' "$XR_TEST_STATE/uci.db" ||
	fail 'invalid netmask failure changed the LAN address'
grep -qx 'network.lan.netmask=255.0.255.0' "$XR_TEST_STATE/uci.db" ||
	fail 'invalid netmask failure changed the original netmask'

cat > "$XR_TEST_STATE/uci.db" <<'EOF'
network.lan.proto=static
network.lan.device=br-lan
network.lan.ipaddr=192.168.50.1
network.lan.netmask=255.255.255.0
network.wan.device=wan
network.wan.proto=dhcp
dhcp.lan.ignore=0
network.globals.ula_prefix=fd00::/48
EOF

role="$tmp/xr1710g-role"
cp "$ROLE_SRC" "$role"
chmod 0755 "$role"

# The real image has /tmp/sysinfo/board_name but no standalone board_name
# executable.  A helper named board_name() shadows command discovery in ash;
# reject that regression explicitly before exercising the PATH-backed fixture.
if grep -Eq '^board_name\(\)[[:space:]]*\{' "$ROLE_SRC"; then
	fail 'role tool shadows the optional board_name command with a shell function'
fi
grep -Fq 'xr1710g_board_name()' "$ROLE_SRC" ||
	fail 'role tool lacks the non-shadowing board-name helper'
grep -Fq '[ -r /tmp/sysinfo/board_name ]' "$ROLE_SRC" ||
	fail 'role tool does not support the installed /tmp/sysinfo board identity'
grep -Fq 'delete_if_present()' "$ROLE_SRC" ||
	fail 'role tool does not make optional UCI deletes idempotent'

"$role" main-dhcp 192.168.10.1/24 > "$tmp/main.out"
grep -qx "network.lan.ipaddr=192.168.10.1/24" "$XR_TEST_STATE/uci.db" ||
	fail 'main-dhcp did not set the requested LAN address'
grep -qx 'network.lan.ip6assign=64' "$XR_TEST_STATE/uci.db" ||
	fail 'main-dhcp did not enable LAN IPv6 delegation'
grep -qx 'network.wan.proto=dhcp' "$XR_TEST_STATE/uci.db" ||
	fail 'main-dhcp did not keep DHCP on WAN'
if grep -q 'network.lan.proto=pppoe' "$XR_TEST_STATE/uci.db"; then
	fail 'main-dhcp assigned PPPoE to LAN'
fi

"$role" node 192.168.10.2/24 192.168.10.1 > "$tmp/node.out"
grep -qx "network.lan.ipaddr=192.168.10.2/24" "$XR_TEST_STATE/uci.db" ||
	fail 'node did not set the requested management address'
grep -qx "network.lan.gateway=192.168.10.1" "$XR_TEST_STATE/uci.db" ||
	fail 'node did not set the main router as gateway'
grep -qx 'dhcp.lan.ignore=1' "$XR_TEST_STATE/uci.db" ||
	fail 'node did not disable DHCPv4 serving'
grep -qx 'dhcp.lan.ra=disabled' "$XR_TEST_STATE/uci.db" ||
	fail 'node did not disable IPv6 RA serving'
grep -qx 'network.wan.proto=none' "$XR_TEST_STATE/uci.db" ||
	fail 'node did not disable its routed WAN role'
if grep -Fq 'network.globals.ula_prefix=' "$XR_TEST_STATE/uci.db"; then
	fail 'node retained an independent ULA prefix'
fi

if "$role" node 192.168.10.2/24 192.168.20.1 > /dev/null 2>&1; then
	fail 'node accepted a gateway outside its management subnet'
fi
if "$role" main-dhcp 192.168.10.0/24 > /dev/null 2>&1; then
	fail 'main-dhcp accepted the subnet address as LAN address'
fi

if grep -Ev "^[[:space:]]*#|^[[:space:]]*(echo|printf)[[:space:]]|^[[:space:]]*(reboot manually|Changes are backed up)" "$ROLE_SRC" |
	grep -Eq '(/etc/init.d/(network|dnsmasq|odhcpd|firewall|openclash)|wifi (reload|down|up)|(^|[[:space:]])reboot([[:space:]]|$))'; then
	fail 'role tool contains an automatic reload or reboot'
fi

# Exercise the real first-boot ordering bug: wireless starts completely absent,
# the helper triggers post-kmod discovery, and policy is applied only after all
# three bands and their default interfaces have appeared.
if grep -q '^wireless\.' "$XR_TEST_STATE/uci.db"; then
	fail 'wireless fixture unexpectedly exists before post-kmod discovery'
fi
wireless="$tmp/xr1710g-wireless-defaults"
cp "$WIRELESS_SRC" "$wireless"
chmod 0755 "$wireless"
XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=complete "$wireless"

for expected in \
	'wireless.radio0.country=US' \
	'wireless.radio0.channel=auto' \
	'wireless.radio0.htmode=HE20' \
	'wireless.radio0.txpower=28' \
	'wireless.default_radio0.ssid=XR1710G' \
	'wireless.default_radio0.encryption=none' \
	'wireless.default_radio0.uapsd=0' \
	'wireless.default_radio0.disassoc_low_ack=0' \
	'wireless.default_radio0.ieee80211r=0' \
	'wireless.default_radio0.ieee80211k=1' \
	'wireless.default_radio0.bss_transition=1' \
	'wireless.radio1.country=US' \
	'wireless.radio1.channel=36' \
	'wireless.radio1.htmode=EHT80' \
	'wireless.radio1.txpower=29' \
	'wireless.radio1.he_bss_color=2' \
	'wireless.radio1.background_radar=1' \
	'wireless.default_radio1.ssid=XR1710G-5G' \
	'wireless.default_radio1.encryption=none' \
	'wireless.default_radio1.uapsd=0' \
	'wireless.default_radio1.disassoc_low_ack=0' \
	'wireless.default_radio1.max_inactivity=86400' \
	'wireless.default_radio1.ieee80211r=1' \
	'wireless.default_radio1.mobility_domain=6616' \
	'wireless.default_radio1.ft_psk_generate_local=1' \
	'wireless.radio2.country=US' \
	'wireless.radio2.band=6g' \
	'wireless.radio2.channel=37' \
	'wireless.radio2.htmode=EHT160' \
	'wireless.radio2.txpower=28' \
	'wireless.default_radio2.mode=mesh' \
	'wireless.default_radio2.network=lan' \
	'wireless.default_radio2.mesh_id=XR1710G-6G-BACKHAUL' \
	'wireless.default_radio2.encryption=sae' \
	'wireless.default_radio2.mesh_fwding=1' \
	'wireless.default_radio2.disabled=1' \
	'system.@system[0].xr1710g_wireless_defaults=1'; do
	grep -Fqx "$expected" "$XR_TEST_STATE/uci.db" ||
		fail "post-kmod wireless policy is missing: $expected"
done
if grep -Eq '^wireless\.default_radio[012]\.key=' "$XR_TEST_STATE/uci.db"; then
	fail 'factory wireless policy contains a preconfigured key'
fi
if grep -Eqi '5.?GHz.*EHT160|EHT160.*5.?GHz|5g.*EHT160|EHT160.*5g|5.?GHz.*30.?dBm|30.?dBm.*5.?GHz|5g.*30.?dBm|30.?dBm.*5g' \
	"$BUILDER/README.md" "$BUILDER/README-EN.md" \
	"$BUILDER/RELEASE-NOTES.md" "$BUILDER/CHANGES-v1.md"; then
	fail 'public documentation still contains a stale 5 GHz EHT160/30dBm default'
fi
if grep -Eq '^wireless\.default_radio2\.(ssid|owe_groups|owe_transition_)=' \
	"$XR_TEST_STATE/uci.db"; then
	fail '6 GHz mesh retained an AP/OWE-only option'
fi
if grep -Eq '^wireless\.radio2\.(channel=auto|htmode=EHT20)$' \
	"$XR_TEST_STATE/uci.db"; then
	fail '6 GHz mesh fell back to automatic channel or 20 MHz'
fi

# The completion marker prevents a later boot from overwriting owner changes.
uci -q set wireless.default_radio1.ssid='OWNER-5G'
XR1710G_WIFI_WAIT_ATTEMPTS=1 XR_TEST_WIFI_MODE=complete "$wireless"
grep -Fqx 'wireless.default_radio1.ssid=OWNER-5G' "$XR_TEST_STATE/uci.db" ||
	fail 'wireless policy overwrote an owner SSID after its completion marker'

# If one band never appears, do not accept or mark a partial factory config.
awk '
	index($0, "wireless.") != 1 &&
	index($0, "system.@system[0].xr1710g_wireless_defaults=") != 1
' "$XR_TEST_STATE/uci.db" > "$XR_TEST_STATE/uci.db.tmp"
mv "$XR_TEST_STATE/uci.db.tmp" "$XR_TEST_STATE/uci.db"
if XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=incomplete "$wireless" \
	> "$tmp/incomplete.out" 2>&1; then
	fail 'wireless policy accepted an incomplete post-kmod radio set'
fi
if grep -Fq 'system.@system[0].xr1710g_wireless_defaults=1' \
	"$XR_TEST_STATE/uci.db"; then
	fail 'wireless policy marked an incomplete radio set as complete'
fi

# If 6 GHz appears before 5 GHz, disable it and remove only its empty
# discovery key while retaining the uci-default for a later complete retry.
awk '
	index($0, "wireless.") != 1 &&
	index($0, "system.@system[0].xr1710g_wireless_defaults=") != 1
' "$XR_TEST_STATE/uci.db" > "$XR_TEST_STATE/uci.db.tmp"
mv "$XR_TEST_STATE/uci.db.tmp" "$XR_TEST_STATE/uci.db"
if XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=missing5 "$wireless" \
	> "$tmp/missing5.out" 2>&1; then
	fail 'wireless policy accepted a 6 GHz-present but incomplete radio set'
fi
grep -Fqx 'wireless.default_radio2.disabled=1' "$XR_TEST_STATE/uci.db" ||
	fail 'incomplete discovery left the 6 GHz AP enabled'
if grep -q '^wireless\.default_radio2\.key=' "$XR_TEST_STATE/uci.db"; then
	fail 'incomplete discovery retained an empty 6 GHz key'
fi
if grep -Fq 'system.@system[0].xr1710g_wireless_defaults=1' \
	"$XR_TEST_STATE/uci.db"; then
	fail '6 GHz safeguard incorrectly marked an incomplete radio set as complete'
fi

# Once the missing band appears, the same partial state must converge to the
# disabled SAE Mesh template and set the completion marker.
XR1710G_WIFI_WAIT_ATTEMPTS=2 XR_TEST_WIFI_MODE=complete "$wireless"
grep -Fqx 'wireless.default_radio2.mode=mesh' "$XR_TEST_STATE/uci.db" &&
	grep -Fqx 'wireless.default_radio2.encryption=sae' "$XR_TEST_STATE/uci.db" &&
	grep -Fqx 'wireless.default_radio2.disabled=1' "$XR_TEST_STATE/uci.db" &&
	grep -Fqx 'system.@system[0].xr1710g_wireless_defaults=1' "$XR_TEST_STATE/uci.db" ||
	fail 'partial wireless discovery did not converge after the missing band appeared'

grep -Fq 'if ! /usr/sbin/xr1710g-wireless-defaults; then' \
	"$BUILDER/files/etc/uci-defaults/99-custom.sh" ||
	fail 'first-boot wrapper does not retain itself when wireless policy fails'

echo 'TOOL TESTS PASSED'
