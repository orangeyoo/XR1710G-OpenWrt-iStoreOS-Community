#!/bin/bash
# OpenWrt DIY part2
# — 在 .config 加载之后、make 之前运行 —

# PassWall2 is built from two mutually pinned upstream feeds. Keep its LuCI
# package and runtime cores on the reviewed revisions, and prove that duplicate
# xray/sing-box packages from the ordinary packages feed did not win feed
# selection merely because an incremental build directory was reused.
passwall2_commit='bb547ac49d845305a9df2d808c1d2f23ed7eaed3'
passwall_packages_commit='50de2d79993447258b1bc15a667a6fb1cd6e7222'
passwall2_feed='feeds/passwall2'
passwall_packages_feed='feeds/passwall_packages'
[ "$(git -C "$passwall2_feed" rev-parse --verify HEAD)" = "$passwall2_commit" ] || {
	echo "Unexpected PassWall2 feed revision" >&2
	exit 1
}
[ "$(git -C "$passwall_packages_feed" rev-parse --verify HEAD)" = \
	"$passwall_packages_commit" ] || {
	echo "Unexpected PassWall runtime feed revision" >&2
	exit 1
}
passwall2_makefile="$passwall2_feed/luci-app-passwall2/Makefile"
passwall2_default="$passwall2_feed/luci-app-passwall2/root/usr/share/passwall2/0_default_config"
grep -Fqx 'PKG_VERSION:=26.8.20' "$passwall2_makefile" || {
	echo "Unexpected PassWall2 LuCI version" >&2
	exit 1
}
grep -Fqx "	option enabled '0'" "$passwall2_default" || {
	echo "PassWall2 upstream default is no longer disabled" >&2
	exit 1
}
grep -Fqx 'PKG_VERSION:=26.7.28' \
	"$passwall_packages_feed/xray-core/Makefile" || {
	echo "Unexpected PassWall Xray version" >&2
	exit 1
}
grep -Fqx 'PKG_VERSION:=1.13.19' \
	"$passwall_packages_feed/sing-box/Makefile" || {
	echo "Unexpected PassWall sing-box version" >&2
	exit 1
}
for passwall_link in \
	package/feeds/passwall2/luci-app-passwall2 \
	package/feeds/passwall_packages/xray-core \
	package/feeds/passwall_packages/sing-box \
	package/feeds/passwall_packages/v2ray-geodata; do
	[ -L "$passwall_link" ] || {
		echo "PassWall package was not selected from its pinned feed: $passwall_link" >&2
		exit 1
	}
done
[ "$(readlink -f package/feeds/passwall2/luci-app-passwall2)" = \
	"$PWD/$passwall2_feed/luci-app-passwall2" ] &&
[ "$(readlink -f package/feeds/passwall_packages/xray-core)" = \
	"$PWD/$passwall_packages_feed/xray-core" ] &&
[ "$(readlink -f package/feeds/passwall_packages/sing-box)" = \
	"$PWD/$passwall_packages_feed/sing-box" ] &&
[ "$(readlink -f package/feeds/passwall_packages/v2ray-geodata)" = \
	"$PWD/$passwall_packages_feed/v2ray-geodata" ] || {
	echo "PassWall package precedence does not match the pinned feeds" >&2
	exit 1
}

# The baseline carries a lab-only US 6 GHz 36 dBm override. Do not silently
# change the ordinary US domain. XR1710G uses one shared PHY, so replace the
# override with a reviewed XZ composite profile: pinned AU rules for 2.4/5 GHz
# plus the opt-in 6 GHz laboratory rule.
regdb_patch_dir='package/firmware/wireless-regdb/patches'
regdb_lab_patch="$regdb_patch_dir/530-us-6ghz-lab-indoor-sp-override.patch"
regdb_lpi_patch="$regdb_patch_dir/520-w1700k-us-power-limits.patch"
regdb_xz_patch="$GITHUB_WORKSPACE/patches/regulatory/0530-xr1710g-6ghz-lab-xz.patch"
[ -f "$regdb_lab_patch" ] || {
	echo "Missing expected baseline 6 GHz laboratory override" >&2
	exit 1
}
grep -Fq 'This is not a real AFC implementation.' "$regdb_lab_patch" || {
	echo "Unexpected 6 GHz laboratory override; refusing an unreviewed regulatory change" >&2
	exit 1
}
[ -f "$regdb_lpi_patch" ] || {
	echo "Missing expected US indoor power-limit patch" >&2
	exit 1
}
grep -Fq '(5925 - 7125 @ 320), (29), NO-OUTDOOR' "$regdb_lpi_patch" || {
	echo "Unexpected US indoor power-limit patch" >&2
	exit 1
}
[ -f "$regdb_xz_patch" ] || {
	echo "Missing reviewed XZ 6 GHz laboratory profile" >&2
	exit 1
}
grep -Fq 'country XZ: DFS-ETSI' "$regdb_xz_patch" || {
	echo "XZ laboratory profile lacks its isolated user-assigned domain" >&2
	exit 1
}
grep -Fq '(5925 - 7125 @ 320), (36), NO-OUTDOOR' "$regdb_xz_patch" || {
	echo "XZ laboratory profile has an unexpected power rule" >&2
	exit 1
}
grep -Fq '(2400 - 2483.5 @ 40), (4000 mW)' "$regdb_xz_patch" || {
	echo "XZ composite profile lacks the pinned AU 2.4 GHz rule" >&2
	exit 1
}
for xz_au_5g_rule in \
	'(5150 - 5250 @ 80), (200 mW), NO-OUTDOOR, AUTO-BW' \
	'(5250 - 5350 @ 80), (100 mW), NO-OUTDOOR, AUTO-BW, DFS' \
	'(5470 - 5600 @ 80), (500 mW), DFS' \
	'(5650 - 5730 @ 80), (500 mW), DFS' \
	'(5730 - 5850 @ 80), (4000 mW), AUTO-BW' \
	'(5850 - 5875 @ 20), (25 mW), AUTO-BW'; do
	grep -Fq "$xz_au_5g_rule" "$regdb_xz_patch" || {
		echo "XZ composite profile lacks pinned AU 5 GHz rule: $xz_au_5g_rule" >&2
		exit 1
	}
done
cp "$regdb_xz_patch" "$regdb_lab_patch"
grep -Fq 'country XZ: DFS-ETSI' "$regdb_lab_patch" || {
	echo "Unable to install the reviewed XZ laboratory profile" >&2
	exit 1
}

# Keep LuCI's native country selector, but accurately explain that XR1710G's
# radios share one PHY and therefore one kernel regulatory domain. XZ is an
# explicit composite laboratory profile, not a normal country domain.
luci_feed='feeds/luci'
luci_wireless_js="$luci_feed/modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js"
luci_zh_hans_po="$luci_feed/modules/luci-base/po/zh_Hans/base.po"
luci_regulatory_patch="$GITHUB_WORKSPACE/patches/luci/0600-xr1710g-per-radio-regulatory-guidance.patch"
luci_static_cidr_patch="$GITHUB_WORKSPACE/patches/luci/0620-xr1710g-normalize-lan-ipv4-cidr.patch"
luci_firewall_fullcone_patch="$GITHUB_WORKSPACE/patches/luci/0630-luci-app-firewall-fullcone-switches.patch"
[ -f "$luci_wireless_js" ] || {
	echo "Missing pinned LuCI wireless configuration view" >&2
	exit 1
}
[ -f "$luci_regulatory_patch" ] || {
	echo "Missing XR1710G shared-PHY regulatory guidance patch" >&2
	exit 1
}
grep -Fq "CBIWifiCountryValue, 'country', _('Country Code')" "$luci_wireless_js" || {
	echo "Unexpected LuCI country selector baseline" >&2
	exit 1
}
git -C "$luci_feed" apply --check "$luci_regulatory_patch"
git -C "$luci_feed" apply "$luci_regulatory_patch"
grep -Fq 'XR1710G composite laboratory profile' "$luci_wireless_js" || {
	echo "LuCI composite laboratory selector failed to install" >&2
	exit 1
}
[ -f "$luci_zh_hans_po" ] || {
	echo "Missing pinned LuCI Simplified Chinese translation catalog" >&2
	exit 1
}
if ! grep -Fq 'msgid "Shared-PHY regulatory mode"' "$luci_zh_hans_po"; then
	cat >> "$luci_zh_hans_po" <<'EOF'

#: modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js
msgid "Select the standard country code matching the location where the router is operated. Available channels and actual transmit power remain limited by regulatory rules, the wireless driver, firmware and factory calibration."
msgstr "请选择路由器实际使用地对应的标准国家代码；可用信道和实际发射功率仍受监管规则、无线驱动、固件及出厂校准共同限制。"

#: modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js
msgid "XR1710G exposes all three bands through one shared PHY, so the kernel ultimately applies one regulatory domain to every radio. XZ is an opt-in composite profile: AU rules for 2.4/5 GHz plus the 6 GHz 36 dBm no-AFC laboratory rule. When XZ is selected here, LuCI writes XZ to all three radio sections so reboot order cannot replace the shared-PHY profile. It is never selected automatically."
msgstr "XR1710G 的三个频段共用同一个 PHY，因此内核最终会把一个监管域应用到全部无线电。XZ 是需主动选择的组合配置：2.4/5 GHz 使用 AU 规则，6 GHz 使用 36 dBm 无 AFC 实验规则。在此选择 XZ 时，LuCI 会把 XZ 写入三张无线电配置，避免重启顺序覆盖共享 PHY 配置；系统绝不会自动启用。"

#: modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js
msgid "Shared-PHY regulatory mode"
msgstr "共享 PHY 监管模式"

#: modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js
msgid "Standard country mode (XZ composite laboratory profile is opt-in)"
msgstr "标准国家模式（XZ 组合实验配置需主动选择）"

#: modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js
msgid "XZ - XR1710G composite laboratory profile (AU 2.4/5 GHz + 6 GHz 36 dBm, no AFC)"
msgstr "XZ - XR1710G 组合实验配置（AU 2.4/5 GHz + 6 GHz 36 dBm，无 AFC）"

#: modules/luci-mod-network/htdocs/luci-static/resources/view/network/wireless.js
msgid "WARNING: XZ is not a country regulatory domain and this firmware does not implement AFC. Choosing XZ on the 6 GHz radio writes XZ to all three radio sections and applies the complete XZ composite profile to the shared PHY: AU 2.4/5 GHz rules plus the experimental 6 GHz rule. It does not grant Standard Power authorization. Use only for controlled laboratory or otherwise authorized testing. You are responsible for compliance with all local laws, rules, channel limits and power limits."
msgstr "警告：XZ 不是国家监管域，本固件也未实现 AFC。在 6 GHz 无线电上选择 XZ，会把 XZ 写入三张无线电配置，并把完整的 XZ 组合配置应用到共享 PHY：2.4/5 GHz 使用 AU 规则，6 GHz 使用实验规则。它不代表已获得标准功率授权；仅限受控实验室或已获得相应授权的测试使用。用户必须自行遵守所在地法律法规、信道及功率限制。"
EOF
fi
grep -Fq 'msgstr "XZ - XR1710G 组合实验配置（AU 2.4/5 GHz + 6 GHz 36 dBm，无 AFC）"' "$luci_zh_hans_po" || {
	echo "LuCI Simplified Chinese laboratory label failed to install" >&2
	exit 1
}

# OpenWrt now stores static IPv4 addresses as CIDR list values.  The generic
# LuCI field accepts a bare IPv4 address for the legacy scalar form, so make
# the XR1710G LAN form normalize it to /24 before saving. Other static
# interfaces and the upstream render path retain their original behavior.
[ -f "$luci_static_cidr_patch" ] || {
	echo "Missing XR1710G LAN CIDR normalization patch" >&2
	exit 1
}
luci_static_protocol="$luci_feed/modules/luci-base/htdocs/luci-static/resources/protocol/static.js"
luci_interfaces_view="$luci_feed/modules/luci-mod-network/htdocs/luci-static/resources/view/network/interfaces.js"
luci_header_template="$luci_feed/modules/luci-base/ucode/template/header.ut"
git -C "$luci_feed" apply --check "$luci_static_cidr_patch"
git -C "$luci_feed" apply "$luci_static_cidr_patch"
grep -Fq 'function normalizeLanIPv4(section_id, value, netmask)' "$luci_static_protocol" || {
	echo "LuCI LAN CIDR normalization failed to install" >&2
	exit 1
}
grep -Fq 'function sanitizeLanIPv4(section_id, value)' "$luci_static_protocol" || {
	echo "LuCI LAN sparse-value sanitizer failed to install" >&2
	exit 1
}
grep -Fq 'or(cidr4,ipmask4,ip4addr("nomask"))' "$luci_static_protocol" || {
	echo "LuCI LAN form still rejects a bare IPv4 address before normalization" >&2
	exit 1
}
grep -Fq "typeof a == 'string' && a.indexOf('/') > 0" "$luci_interfaces_view" || {
	echo "LuCI interfaces view still dereferences sparse IPv4 values" >&2
	exit 1
}
grep -Fq 'xr-ui-20260820' "$luci_header_template" || {
	echo "LuCI LAN resource cache version failed to install" >&2
	exit 1
}
node "$GITHUB_WORKSPACE/scripts/test-luci-lan-cidr.js" \
	"$luci_static_protocol" "$luci_interfaces_view"

# Expose the already optional firewall4 Full Cone backend through two global,
# independently disabled IPv4/IPv6 switches.  Keep this in luci-app-firewall
# so it follows the upstream firewall ACL, UCI and service-reload path.
luci_firewall_zones="$luci_feed/applications/luci-app-firewall/htdocs/luci-static/resources/view/firewall/zones.js"
luci_firewall_zh_hans="$luci_feed/applications/luci-app-firewall/po/zh_Hans/firewall.po"
[ -f "$luci_firewall_fullcone_patch" ] || {
	echo "Missing reviewed LuCI Full Cone NAT controls" >&2
	exit 1
}
[ -f "$luci_firewall_zones" ] && [ -f "$luci_firewall_zh_hans" ] || {
	echo "Missing pinned luci-app-firewall source files" >&2
	exit 1
}
git -C "$luci_feed" apply --check "$luci_firewall_fullcone_patch"
git -C "$luci_feed" apply "$luci_firewall_fullcone_patch"
grep -Fq "s.option(form.Flag, 'fullcone'," "$luci_firewall_zones" &&
	grep -Fq "s.option(form.Flag, 'fullcone6'," "$luci_firewall_zones" || {
	echo "LuCI Full Cone NAT controls failed to install" >&2
	exit 1
}
node "$GITHUB_WORKSPACE/scripts/test-luci-firewall-fullcone.js" \
	"$luci_firewall_zones" "$luci_firewall_zh_hans"

# The 6.18.41 baseline's Airoha TRNG follow-up opens the SCU clock gates after
# touching RNG_EN. Install the reviewed ordering-only patch deterministically
# and refuse stale or duplicate copies.
trng_patch_src="$GITHUB_WORKSPACE/patches/kernel/0921-hwrng-airoha-enable-scu-clocks-before-trng.patch"
trng_patch_dir="target/linux/airoha/patches-6.18"
trng_patch_dst="$trng_patch_dir/921-hwrng-airoha-enable-scu-clocks-before-trng.patch"
trng_base_patch="$trng_patch_dir/920-hwrng-airoha-fix-init-sequence-default-to-DRBG.patch"
[ -f "$trng_patch_src" ] || {
	echo "Missing XR1710G TRNG clock-ordering patch" >&2
	exit 1
}
[ -f "$trng_base_patch" ] || {
	echo "Missing expected Airoha TRNG base patch" >&2
	exit 1
}
grep -Fq 'val |= RNG_EN | RNG_OSC_EN;' "$trng_base_patch" || {
	echo "Unexpected Airoha TRNG base patch; refusing an unreviewed rebase" >&2
	exit 1
}
rm -f "$trng_patch_dst"
install -m 0644 "$trng_patch_src" "$trng_patch_dst"
grep -Fq 'enable SCU clocks before starting TRNG' "$trng_patch_dst" || {
	echo "Installed Airoha TRNG patch failed content validation" >&2
	exit 1
}

# Preserve the YYH2913 QDMA/DMA/MTU and USXGMII reset fixes, remove the failed
# forced RTL826x SDS experiment, and add only the rate-limited AN7581 RX-lock
# diagnostics reviewed from naoki66's current board support. Exact filenames
# and content anchors below make that ordering explicit.
xr_phy_patch_dir='target/linux/airoha/patches-6.18'
xr_phy_dts='target/linux/airoha/dts/an7581-xr1710g-ubi.dts'
yyh_bql_patch="$xr_phy_patch_dir/179-v7.2-net-airoha-fix-BQL-underflow-in-shared-QDMA-TX-ring.patch"
yyh_mtu_patch="$xr_phy_patch_dir/180-v7.3-net-airoha-fix-max-receive-size-configuration.patch"
yyh_dma_patch="$xr_phy_patch_dir/181-v7.3-net-airoha-dma-map-xmit-frags-with-skb_frag_dma_map.patch"
yyh_usxgmii_patch="$xr_phy_patch_dir/620-net-pcs-airoha-fix-USXGMII-rate-adaptation-on-speed.patch"
yyh_speed_reset_patch="$xr_phy_patch_dir/621-net-pcs-airoha-AN7581-add-global-digital-reset-for.patch"
yyh_port_class_patch="$xr_phy_patch_dir/922-net-airoha-classify-external-lan-ports-from-DT.patch"
[ -f "$yyh_bql_patch" ] &&
	grep -Fq 'q->flushing = true;' "$yyh_bql_patch" &&
	grep -Fq 'netdev_tx_completed_queue' "$yyh_bql_patch" || {
	echo "Missing YYH shared-QDMA BQL underflow fix" >&2
	exit 1
}
[ -f "$yyh_mtu_patch" ] &&
	grep -Fq 'AIROHA_MAX_RX_SIZE' "$yyh_mtu_patch" &&
	grep -Fq 'airoha_ppe_set_xmit_frame_size' "$yyh_mtu_patch" || {
	echo "Missing YYH Airoha RX/PPE MTU fix" >&2
	exit 1
}
[ -f "$yyh_dma_patch" ] &&
	grep -Fq 'skb_frag_dma_map' "$yyh_dma_patch" &&
	grep -Fq 'AIROHA_DMA_MAP_PAGE' "$yyh_dma_patch" || {
	echo "Missing YYH fragment DMA mapping fix" >&2
	exit 1
}
[ -f "$yyh_usxgmii_patch" ] &&
	grep -Fq 'AIROHA_PCS_USXGMII_RATE_UPDATE_MODE | mode' "$yyh_usxgmii_patch" || {
	echo "Missing YYH USXGMII speed-adaptation baseline" >&2
	exit 1
}
[ -f "$yyh_speed_reset_patch" ] &&
	grep -Fq 'link_up: performing global digital reset' "$yyh_speed_reset_patch" || {
	echo "Missing YYH AN7581 speed-change digital-reset baseline" >&2
	exit 1
}
[ -f "$yyh_port_class_patch" ] &&
	grep -Fq 'classify external lan ports from DT' "$yyh_port_class_patch" || {
	echo "Missing YYH external-LAN port classification baseline" >&2
	exit 1
}
rm -f \
	"$xr_phy_patch_dir/922-net-phy-realtek-allow-xr1710g-sds-mode.patch" \
	"$xr_phy_patch_dir/923-net-pcs-airoha-an7581-rx-lock-diagnostics.patch" \
	"$xr_phy_patch_dir/924-net-phy-realtek-xr1710g-init-diagnostics.patch"
xr_phy_patch=0923-net-pcs-airoha-an7581-rx-lock-diagnostics.patch
xr_phy_patch_src="$GITHUB_WORKSPACE/patches/kernel/$xr_phy_patch"
xr_phy_patch_dst="$xr_phy_patch_dir/${xr_phy_patch#0}"
[ -f "$xr_phy_patch_src" ] || {
	echo "Missing XR1710G RX-lock diagnostic patch: $xr_phy_patch" >&2
	exit 1
}
install -m 0644 "$xr_phy_patch_src" "$xr_phy_patch_dst"
[ "$(find "$xr_phy_patch_dir" -maxdepth 1 -type f -name '922-net-*.patch' |
	wc -l)" -eq 1 ] || {
	echo "Unexpected 922-net patch set; refusing ambiguous kernel ordering" >&2
	exit 1
}

[ -f "$xr_phy_dts" ] || {
	echo "Missing XR1710G device tree" >&2
	exit 1
}
if grep -Fq 'realtek,sds-mode' "$xr_phy_dts"; then
	echo "XR1710G device tree still contains the failed forced-SDS experiment" >&2
	exit 1
fi

grep -Fq 'action=%s resets=%u' \
	"$xr_phy_patch_dir/923-net-pcs-airoha-an7581-rx-lock-diagnostics.patch" ||
	{ echo "AN7581 RX-lock diagnostics patch failed validation" >&2; exit 1; }

# The baseline 9990 Airoha PPE L2-cache-miss fallback must never interpret a
# bridge-local FDB entry as a physical forwarding path.  Install the reviewed
# guard immediately after 9990 and fail closed if the expected baseline moved.
ppe_bridge_base_patch="$xr_phy_patch_dir/9990-net-airoha-bind-WLAN-bound-flows-on-PPE-driver-L2-cache-miss.patch"
ppe_local_guard_name='9991-net-airoha-protect-local-bridge-flows-from-ppe-fallback.patch'
ppe_local_guard_src="$GITHUB_WORKSPACE/patches/kernel/$ppe_local_guard_name"
ppe_local_guard_dst="$xr_phy_patch_dir/$ppe_local_guard_name"
ppe_bridge_base_sha256='f7aceb4b5850b2d03a8c954a443b1a2acb809e14b878765e6a17dc90459083ea'
ppe_local_guard_sha256='f0ce6d609b6dbdeaba19b76544c1aff437a20713e9c911edf78ae26f691cfc88'
[ -f "$ppe_bridge_base_patch" ] &&
	grep -Fq 'airoha_ppe_foe_prepare_bridge_subflow' "$ppe_bridge_base_patch" &&
	grep -Fq 'dev_fill_forward_path(master, eh->h_dest, &stack)' "$ppe_bridge_base_patch" || {
	echo "Unexpected Airoha PPE bridge-fallback baseline; refusing an unreviewed rebase" >&2
	exit 1
}
[ "$(sha256sum "$ppe_bridge_base_patch" | awk '{print $1}')" = \
	"$ppe_bridge_base_sha256" ] || {
	echo "Airoha PPE bridge-fallback baseline hash changed; refusing an unreviewed rebase" >&2
	exit 1
}
[ -f "$ppe_local_guard_src" ] || {
	echo "Missing Airoha PPE local-flow guard" >&2
	exit 1
}
[ "$(sha256sum "$ppe_local_guard_src" | awk '{print $1}')" = \
	"$ppe_local_guard_sha256" ] || {
	echo "Airoha PPE local-flow guard hash changed" >&2
	exit 1
}
rm -f "$ppe_local_guard_dst"
install -m 0644 "$ppe_local_guard_src" "$ppe_local_guard_dst"
[ "$(sha256sum "$ppe_local_guard_dst" | awk '{print $1}')" = \
	"$ppe_local_guard_sha256" ] || {
	echo "Installed Airoha PPE local-flow guard hash changed" >&2
	exit 1
}
grep -Fq 'test_bit(BR_FDB_LOCAL, &f->flags)' "$ppe_local_guard_dst" &&
	grep -Fq 'u8 daddr[ETH_ALEN + 2] = {};' "$ppe_local_guard_dst" &&
	grep -Fq 'is_etherdev_addr(master, daddr)' "$ppe_local_guard_dst" &&
	grep -Fq 'egress == skb->dev' "$ppe_local_guard_dst" &&
	grep -Fq 'is_etherdev_addr(egress, daddr)' "$ppe_local_guard_dst" || {
	echo "Installed Airoha PPE local-flow guard failed content validation" >&2
	exit 1
}

# Image assembly enables rc.common services after overlay files are copied.
# Keep AdGuard Home and upstream dockerd opt-in, and never enable the legacy
# airoha_fan controller because the checked fan service exclusively owns the
# same NCT7802. An enabled dockerd symlink is explicitly kept across sysupgrade
# by files/lib/upgrade/keep.d/xr1710g-docker.
image_makefile='include/image.mk'
old_prepare_rootfs='$(call prepare_rootfs,$(mkfs_cur_target_dir),$(TOPDIR)/files)'
new_prepare_rootfs='$(call prepare_rootfs,$(mkfs_cur_target_dir),$(TOPDIR)/files,adguardhome dockerd airoha_fan)'
old_prepare_line="$(printf '\t%s' "$old_prepare_rootfs")"
new_prepare_line="$(printf '\t%s' "$new_prepare_rootfs")"
if grep -Fqx "$new_prepare_line" "$image_makefile"; then
	:
elif grep -Fqx "$old_prepare_line" "$image_makefile"; then
	prepare_line_number="$(grep -nFx "$old_prepare_line" "$image_makefile" |
		cut -d: -f1)"
	[ -n "$prepare_line_number" ] || exit 1
	sed -i "${prepare_line_number}c\\${new_prepare_line}" "$image_makefile"
else
	echo "Unexpected image rootfs assembly call; cannot apply opt-in services" >&2
	exit 1
fi
grep -Fqx "$new_prepare_line" "$image_makefile" || {
	echo "Unable to apply opt-in service policy during image assembly" >&2
	exit 1
}

# Keep Docker itself entirely upstream: Moby dockerd, Docker CLI, containerd,
# runc and luci-app-dockerman all come from the pinned OpenWrt feeds.  This
# narrow OpenWrt service-wrapper patch only exposes daemon log-opts through
# the existing dockerd UCI-to-JSON conversion so bounded logs remain
# compatible with iStore and Dockerman's single /etc/config/dockerd.
dockerd_feed='feeds/packages'
dockerd_init="$dockerd_feed/utils/dockerd/files/dockerd.init"
dockerd_patch="$GITHUB_WORKSPACE/patches/packages/0201-dockerd-support-uci-log-options.patch"
[ -f "$dockerd_init" ] || {
	echo "Missing pinned OpenWrt dockerd init script" >&2
	exit 1
}
[ -f "$dockerd_patch" ] || {
	echo "Missing reviewed OpenWrt dockerd UCI log-options patch" >&2
	exit 1
}
[ "$(sha256sum "$dockerd_patch" | cut -d' ' -f1)" = \
	'f2851e370a83380903c1933b59978ac90a1cf8c08b544144a3c8bc6a281654bd' ] || {
	echo "Unexpected OpenWrt dockerd UCI log-options patch content" >&2
	exit 1
}
grep -Fq 'json_add_string "log-driver" "${log_driver}"' "$dockerd_init" || {
	echo "Unexpected OpenWrt dockerd init baseline" >&2
	exit 1
}
git -C "$dockerd_feed" apply --check "$dockerd_patch"
git -C "$dockerd_feed" apply "$dockerd_patch"
grep -Fq 'config_list_foreach globals log_opts json_add_log_option' "$dockerd_init" || {
	echo "OpenWrt dockerd UCI log-options patch failed validation" >&2
	exit 1
}

# YYH2913/http-uboot-xr1710g stores only 0x4000 bytes of environment data in
# each redundant UBI volume. Install the reviewed board-specific envtools
# layout so software recovery requests are visible to the installed U-Boot.
xr_uboot_env_patch="$GITHUB_WORKSPACE/patches/openwrt/0101-xr1710g-fix-uboot-env-layout.patch"
xr_uboot_env_script='package/boot/uboot-tools/uboot-envtools/files/airoha_an7581'
[ -f "$xr_uboot_env_patch" ] || {
	echo "Missing XR1710G U-Boot environment layout patch" >&2
	exit 1
}
[ -f "$xr_uboot_env_script" ] || {
	echo "Missing Airoha uboot-envtools platform script" >&2
	exit 1
}
grep -Fq 'ubootenv_add_ubi_default' "$xr_uboot_env_script" || {
	echo "Unexpected Airoha uboot-envtools baseline" >&2
	exit 1
}
git apply --check "$xr_uboot_env_patch"
git apply "$xr_uboot_env_patch"
grep -Fq 'ubootenv_add_uci_config "$dev" "0x0" "0x4000" "0x1f000" "1"' \
	"$xr_uboot_env_script" || {
	echo "XR1710G U-Boot environment layout patch failed validation" >&2
	exit 1
}

# Keep the upstream Dockerman application, but make its intentional stopped
# state understandable. The pinned page otherwise returns the raw socket
# connection error before rendering any heading or start control.
dockerman_feed='feeds/luci'
dockerman_overview="$dockerman_feed/applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js"
dockerman_zh_hans="$dockerman_feed/applications/luci-app-dockerman/po/zh_Hans/dockerman.po"
dockerman_stopped_patch="$GITHUB_WORKSPACE/patches/luci/0610-dockerman-disabled-state-guidance.patch"
dockerman_moby29_patch="$GITHUB_WORKSPACE/patches/luci/0611-dockerman-moby29-info-compat.patch"
dockerman_moby29_test="$GITHUB_WORKSPACE/scripts/test-dockerman-moby29.js"
dockerman_moby29_fixture="$GITHUB_WORKSPACE/scripts/fixtures/dockerman-moby29-info.json"
[ -f "$dockerman_overview" ] || {
	echo "Missing pinned Dockerman overview" >&2
	exit 1
}
[ -f "$dockerman_zh_hans" ] || {
	echo "Missing pinned Dockerman Simplified Chinese catalog" >&2
	exit 1
}
[ -f "$dockerman_stopped_patch" ] || {
	echo "Missing reviewed Dockerman stopped-state patch" >&2
	exit 1
}
[ -f "$dockerman_moby29_patch" ] || {
	echo "Missing reviewed Dockerman Moby 29 compatibility patch" >&2
	exit 1
}
[ -f "$dockerman_moby29_test" ] || {
	echo "Missing Dockerman Moby 29 DOM regression test" >&2
	exit 1
}
[ -f "$dockerman_moby29_fixture" ] || {
	echo "Missing Dockerman Moby 29 info fixture" >&2
	exit 1
}
grep -Fq "return E('div', {}, [ info_response?.body?.message ]);" "$dockerman_overview" || {
	echo "Unexpected Dockerman stopped-state baseline" >&2
	exit 1
}
git -C "$dockerman_feed" apply --check "$dockerman_stopped_patch"
git -C "$dockerman_feed" apply "$dockerman_stopped_patch"
git -C "$dockerman_feed" apply --check "$dockerman_moby29_patch"
git -C "$dockerman_feed" apply "$dockerman_moby29_patch"
grep -Fq "handleEnableAndStart(ev)" "$dockerman_overview" || {
	echo "Dockerman enable-and-start action failed to install" >&2
	exit 1
}
grep -Fq "renderNestedDockerInfo(info)" "$dockerman_overview" || {
	echo "Dockerman Moby 29 nested-info renderer failed to install" >&2
	exit 1
}
grep -Fq "white-space: pre-wrap; overflow-wrap: anywhere" "$dockerman_overview" || {
	echo "Dockerman nested-info wrapping guard failed to install" >&2
	exit 1
}
node "$dockerman_moby29_test" "$dockerman_overview" "$dockerman_moby29_fixture"
if ! grep -Fq 'msgid "Docker is not running"' "$dockerman_zh_hans"; then
	cat >> "$dockerman_zh_hans" <<'EOF'

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Docker is not running"
msgstr "Docker 未运行"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Docker is installed but disabled by default to conserve memory and storage writes. No Docker resources are used until you enable it."
msgstr "Docker 已安装，但默认关闭以节省内存并减少存储写入。在您主动启用前，Docker 不会占用运行资源。"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Click the button below to enable Docker at boot and start the upstream OpenWrt Docker service now. iStore and Dockerman will use the same service and data directory."
msgstr "点击下方按钮可启用 Docker 开机启动，并立即启动 OpenWrt 上游 Docker 服务。iStore 与 Dockerman 将共用同一服务和数据目录。"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Enable and start Docker"
msgstr "启用并启动 Docker"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Enabling the Docker service failed"
msgstr "启用 Docker 服务失败"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Starting the Docker service failed"
msgstr "启动 Docker 服务失败"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Docker is starting. This page will refresh automatically."
msgstr "Docker 正在启动，页面将自动刷新。"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Failed to enable and start Docker: %s"
msgstr "启用并启动 Docker 失败：%s"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Unable to connect to the configured Docker host."
msgstr "无法连接到已配置的 Docker 主机。"
EOF
fi
if ! grep -Fq 'msgid "Advanced Docker information"' "$dockerman_zh_hans"; then
	cat >> "$dockerman_zh_hans" <<'EOF'

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Advanced Docker information"
msgstr "Docker 高级信息"

#: applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/overview.js
msgid "Nested Docker API values are collapsed by default and formatted for safe viewing."
msgstr "嵌套的 Docker API 信息默认折叠，并经过格式化以便安全查看。"
EOF
fi
grep -Fq 'msgstr "Docker 未运行"' "$dockerman_zh_hans" || {
	echo "Dockerman stopped-state Chinese translation failed to install" >&2
	exit 1
}
grep -Fq 'msgstr "Docker 高级信息"' "$dockerman_zh_hans" || {
	echo "Dockerman Moby 29 Chinese translation failed to install" >&2
	exit 1
}

# The refreshed YYH/OpenWrt baseline already carries the reviewed fix for
# routing NL80211_CMD_UNEXPECTED_4ADDR_FRAME to the BSS selected by the event
# ifindex.  Validate that exact baseline patch instead of stacking a duplicate
# local backport, which would fail while preparing hostapd.
hostapd_makefile="package/network/services/hostapd/Makefile"
hostapd_wds_patch="package/network/services/hostapd/patches/060-nl80211-fix-reporting-spurious-frame-events.patch"
[ -f "$hostapd_makefile" ] || {
	echo "Missing pinned hostapd package Makefile" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_DATE:=2026-07-09' "$hostapd_makefile" || {
	echo "Unexpected hostapd source date; refusing an unreviewed WDS baseline" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_VERSION:=f08f2749aa696c4e47c5c0f591dda99951bf9fac' \
	"$hostapd_makefile" || {
	echo "Unexpected hostapd source revision; refusing an unreviewed WDS baseline" >&2
	exit 1
}
grep -qx 'PKG_RELEASE:=1' "$hostapd_makefile" || {
	echo "Unexpected hostapd package release; refusing an ambiguous WDS baseline" >&2
	exit 1
}
[ -f "$hostapd_wds_patch" ] || {
	echo "Baseline hostapd WDS event-routing patch is missing" >&2
	exit 1
}
grep '^+' "$hostapd_wds_patch" |
grep -Fq 'wpa_supplicant_event(bss->ctx, EVENT_RX_FROM_UNKNOWN, &event);' || {
	echo "Baseline hostapd WDS patch failed new-route validation" >&2
	exit 1
}
grep '^-' "$hostapd_wds_patch" |
	grep -Fq 'wpa_supplicant_event(drv->ctx, EVENT_RX_FROM_UNKNOWN, &event);' || {
	echo "Baseline hostapd WDS patch failed old-route validation" >&2
	exit 1
}
[ "$(find package/network/services/hostapd/patches -maxdepth 1 -type f \
	-name '*unexpected-frame-events-to-correct-bss*.patch' | wc -l)" -eq 0 ] || {
	echo "Duplicate local hostapd WDS backport is present" >&2
	exit 1
}

# Add complete userspace support for the optional kmod-nft-fullcone module.
# This is imported from ImmortalWrt but deliberately defaults to disabled:
# installing the capability must not silently replace the existing WAN NAT or
# alter PPE/OpenClash behavior.  Owners may opt in after real-device testing.
fullcone_patch_dir="$GITHUB_WORKSPACE/patches/fullcone"
fullcone_libnftnl='package/libs/libnftnl/patches/001-xr1710g-fullcone-expression.patch'
fullcone_nftables='package/network/utils/nftables/patches/010-xr1710g-fullcone-expression.patch'
fullcone_firewall4='package/network/config/firewall4/patches/010-xr1710g-fullcone-support.patch'
for fullcone_source in \
	0100-libnftnl-add-fullcone-expression-support.patch \
	0101-nftables-add-fullcone-expression-support.patch \
	0102-firewall4-add-support-for-fullcone-nat.patch; do
	[ -f "$fullcone_patch_dir/$fullcone_source" ] || {
		echo "Missing reviewed Full Cone NAT patch: $fullcone_source" >&2
		exit 1
	}
done
mkdir -p \
	"$(dirname "$fullcone_libnftnl")" \
	"$(dirname "$fullcone_nftables")" \
	"$(dirname "$fullcone_firewall4")"
rm -f "$fullcone_libnftnl" "$fullcone_nftables" "$fullcone_firewall4"
install -m 0644 \
	"$fullcone_patch_dir/0100-libnftnl-add-fullcone-expression-support.patch" \
	"$fullcone_libnftnl"
install -m 0644 \
	"$fullcone_patch_dir/0101-nftables-add-fullcone-expression-support.patch" \
	"$fullcone_nftables"
install -m 0644 \
	"$fullcone_patch_dir/0102-firewall4-add-support-for-fullcone-nat.patch" \
	"$fullcone_firewall4"
grep -Fq 'expr_ops_fullcone' "$fullcone_libnftnl" ||
	{ echo "libnftnl Full Cone patch failed validation" >&2; exit 1; }
grep -Fq 'NFT_NAT_FULLCONE' "$fullcone_nftables" ||
	{ echo "nftables Full Cone patch failed validation" >&2; exit 1; }
grep -Fq $'option fullcone\t\t0' "$fullcone_firewall4" ||
	{ echo "firewall4 Full Cone support is not default-disabled" >&2; exit 1; }
if grep '^+' "$fullcone_firewall4" | grep -Eq 'option fullcone[[:space:]]+1'; then
	echo "firewall4 patch unexpectedly enables Full Cone NAT by default" >&2
	exit 1
fi

# Backport iStoreOS' reviewed raw reverse-proxy stack to the newer uhttpd
# revision used by this XR1710G port.  The capability is required by the new
# LinkEase Full /apps entry, but this image deliberately does not install that
# optional runtime and therefore does not create a default proxy mapping.
# Keep all three upstream patches content-addressed so a future iStoreOS branch
# update cannot silently change the code compiled into a community release.
uhttpd_makefile="package/network/services/uhttpd/Makefile"
uhttpd_patch_dir="package/network/services/uhttpd/patches"
uhttpd_proxy_patch_src="$GITHUB_WORKSPACE/patches/uhttpd"
uhttpd_package_patch="$uhttpd_proxy_patch_src/0000-package-enable-proxy-uci.patch"
uhttpd_proxy_patches='501-1-feat-add-raw-proxy.patch 501-2-fix-force-backend-close-for-proxied-http.patch 501-3-feat-forward-original-request-headers-to-backend.patch'
[ -f "$uhttpd_makefile" ] || {
	echo "Missing pinned uhttpd package Makefile" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_DATE:=2026-06-16' "$uhttpd_makefile" || {
	echo "Unexpected uhttpd source date; refusing an unreviewed proxy rebase" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_VERSION:=7b1bec45826bd78c8afc993435bdc0f1df2fe399' \
	"$uhttpd_makefile" || {
	echo "Unexpected uhttpd source revision; refusing an unreviewed proxy rebase" >&2
	exit 1
}
grep -qx 'PKG_RELEASE:=1' "$uhttpd_makefile" || {
	echo "Unexpected uhttpd package release; refusing an ambiguous proxy update" >&2
	exit 1
}
# The pinned OpenWrt baseline has no uhttpd patch directory. Reject any
# unexpected pre-existing patch rather than silently changing patch order.
if [ -d "$uhttpd_patch_dir" ] &&
	find "$uhttpd_patch_dir" -maxdepth 1 -type f -name '*.patch' -print | grep -q .; then
	echo "Unexpected pre-existing uhttpd patch series" >&2
	exit 1
fi
[ -f "$uhttpd_package_patch" ] || {
	echo "Missing reviewed uhttpd UCI integration patch" >&2
	exit 1
}

patch -p1 --forward --batch < "$uhttpd_package_patch"
grep -Fq 'config_list_foreach "$cfg" proxy_prefix append_proxy_prefix' \
	package/network/services/uhttpd/files/uhttpd.init || {
	echo "uhttpd init does not expose proxy_prefix UCI mappings" >&2
	exit 1
}
grep -Fq 'list proxy_prefix' package/network/services/uhttpd/files/uhttpd.config || {
	echo "uhttpd config does not document proxy_prefix mappings" >&2
	exit 1
}

mkdir -p "$uhttpd_patch_dir"
for uhttpd_patch in $uhttpd_proxy_patches; do
	[ -f "$uhttpd_proxy_patch_src/$uhttpd_patch" ] || {
		echo "Missing reviewed iStoreOS uhttpd patch: $uhttpd_patch" >&2
		exit 1
	}
	rm -f "$uhttpd_patch_dir/$uhttpd_patch"
	install -m 0644 "$uhttpd_proxy_patch_src/$uhttpd_patch" \
		"$uhttpd_patch_dir/$uhttpd_patch"
done

[ "$(sha256sum "$uhttpd_patch_dir/501-1-feat-add-raw-proxy.patch" | cut -d' ' -f1)" = \
	'174a2521df1d25b40eb72ef42660ca118a7f7801d0be00d154990277c023b7b5' ] || {
	echo "Unexpected iStoreOS raw-proxy patch content" >&2
	exit 1
}
[ "$(sha256sum "$uhttpd_patch_dir/501-2-fix-force-backend-close-for-proxied-http.patch" | cut -d' ' -f1)" = \
	'3d73af37c533240bb38b1b1cdf70b966845c8d33c1ef2ce6166ad341795c437f' ] || {
	echo "Unexpected iStoreOS proxy-close patch content" >&2
	exit 1
}
[ "$(sha256sum "$uhttpd_patch_dir/501-3-feat-forward-original-request-headers-to-backend.patch" | cut -d' ' -f1)" = \
	'4d31d429d86d6593acdbe37463f8f34d81f3b082c75455a2f49883ba5970fcbd' ] || {
	echo "Unexpected iStoreOS forwarded-header patch content" >&2
	exit 1
}

sed -i 's/^PKG_RELEASE:=1$/PKG_RELEASE:=2/' "$uhttpd_makefile"
grep -qx 'PKG_RELEASE:=2' "$uhttpd_makefile" || {
	echo "Unable to select the proxy-enabled uhttpd package release" >&2
	exit 1
}

# Pin the upstream mt76 revision that was A/B tested on two XR1710G units,
# then apply the reviewed AN7581/NPU rebase and terminal-failure statistics
# fix.  Keep this fully reproducible from the public upstream git commit: no
# build-volume tarball or mutable branch is allowed to affect the image.
mt76_makefile="package/kernel/mt76/Makefile"
mt76_an7581_patch_src="$GITHUB_WORKSPACE/patches/mt76/0100-xr1710g-rebase-yyh-an7581-npu-stack-on-b2704cf5.patch"
mt76_stats_patch_src="$GITHUB_WORKSPACE/patches/mt76/0099-wifi-mt76-mt7996-report-only-terminal-tx-failures.patch"
mt76_rate_patch_src="$GITHUB_WORKSPACE/patches/mt76/0102-wifi-mt76-mt7996-pass-operating-mode-to-rate-control.patch"
mt76_npu_rx_patch_src="$GITHUB_WORKSPACE/patches/mt76/0103-wifi-mt76-mt7996-set-skb-device-for-npu-rx.patch"
mt76_an7581_patch_dst="package/kernel/mt76/patches/0100-xr1710g-rebase-yyh-an7581-npu-stack-on-b2704cf5.patch"
mt76_stats_patch_dst="package/kernel/mt76/patches/0101-wifi-mt76-mt7996-report-only-terminal-tx-failures.patch"
mt76_rate_patch_dst="package/kernel/mt76/patches/0102-wifi-mt76-mt7996-pass-operating-mode-to-rate-control.patch"
mt76_npu_rx_patch_dst="package/kernel/mt76/patches/0103-wifi-mt76-mt7996-set-skb-device-for-npu-rx.patch"
[ -f "$mt76_makefile" ] || {
	echo "Missing pinned mt76 package Makefile" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_VERSION:=59676919ea408b0b13a9d23f2e2e1a1ab407fba1' \
	"$mt76_makefile" || {
	echo "Unexpected mt76 source revision; refusing an unreviewed driver rebase" >&2
	exit 1
}
[ -f "$mt76_an7581_patch_src" ] || {
	echo "Missing reviewed XR1710G AN7581/NPU rebase patch" >&2
	exit 1
}
[ -f "$mt76_stats_patch_src" ] || {
	echo "Missing reviewed MT7996 tx_failed patch" >&2
	exit 1
}
[ -f "$mt76_rate_patch_src" ] || {
	echo "Missing reviewed MT7996 operating-mode rate-control patch" >&2
	exit 1
}
[ -f "$mt76_npu_rx_patch_src" ] || {
	echo "Missing reviewed MT7996 NPU RX ingress-device patch" >&2
	exit 1
}
grep -qx 'PKG_RELEASE=3' "$mt76_makefile" || {
	echo "Unexpected mt76 package release; refusing an ambiguous driver update" >&2
	exit 1
}

# These are the deterministic git-archive/zstd values produced by OpenWrt's
# own download helper for the public b2704cf5 commit.
sed -i \
	-e 's/^PKG_RELEASE=3$/PKG_RELEASE=6/' \
	-e 's/^PKG_SOURCE_DATE:=2026-07-01$/PKG_SOURCE_DATE:=2026-08-01/' \
	-e 's/^PKG_SOURCE_VERSION:=59676919ea408b0b13a9d23f2e2e1a1ab407fba1$/PKG_SOURCE_VERSION:=b2704cf5a4068b672bf47ad5bf6b4802b6770a90/' \
	-e 's/^PKG_MIRROR_HASH:=8a6dc6dac37ed56fcbfd874359f5c25acb65bcfaa795d50494cba17c98405dd5$/PKG_MIRROR_HASH:=fc94437f3271a16d3865c16ec3bbdf828ac18a730953a74fc80f76abf461eb67/' \
	"$mt76_makefile"

# The old patch series targets 59676919. Its board-specific result was
# reviewed and rebased as one consolidated patch above, so never apply both.
find package/kernel/mt76/patches -maxdepth 1 -type f -name '*.patch' -delete
install -m 0644 "$mt76_an7581_patch_src" "$mt76_an7581_patch_dst"
install -m 0644 "$mt76_stats_patch_src" "$mt76_stats_patch_dst"
install -m 0644 "$mt76_rate_patch_src" "$mt76_rate_patch_dst"
install -m 0644 "$mt76_npu_rx_patch_src" "$mt76_npu_rx_patch_dst"

grep -qx 'PKG_RELEASE=6' "$mt76_makefile" || {
	echo "Unable to select the A/B-tested mt76 package release" >&2
	exit 1
}
grep -qx 'PKG_SOURCE_VERSION:=b2704cf5a4068b672bf47ad5bf6b4802b6770a90' \
	"$mt76_makefile" || {
	echo "Unable to select the A/B-tested upstream mt76 revision" >&2
	exit 1
}
grep -qx 'PKG_MIRROR_HASH:=fc94437f3271a16d3865c16ec3bbdf828ac18a730953a74fc80f76abf461eb67' \
	"$mt76_makefile" || {
	echo "Unable to pin the b2704cf5 source archive hash" >&2
	exit 1
}
grep -Fq 'mt7996_mcu_get_per_sta_info' "$mt76_an7581_patch_dst" || {
	echo "Installed AN7581/NPU patch failed content validation" >&2
	exit 1
}
grep -Fq 'wcid->stats.tx_failed +=' "$mt76_stats_patch_dst" || {
	echo "Installed MT7996 statistics patch failed content validation" >&2
	exit 1
}
grep -Fq 'ra->op_vht_rx_nss = link_sta->rx_nss ? link_sta->rx_nss - 1 : 0;' \
	"$mt76_rate_patch_dst" || {
	echo "Installed MT7996 operating-mode patch failed content validation" >&2
	exit 1
}
grep -Fq 'mt76_queue_is_npu_rx' "$mt76_npu_rx_patch_dst" &&
grep -Fq 'skb->dev = ieee80211_vif_to_wdev(vif)->netdev' \
	"$mt76_npu_rx_patch_dst" || {
	echo "Installed MT7996 NPU RX patch failed content validation" >&2
	exit 1
}

# The refreshed YYH baseline carries XR1710G-specific MT7996 NAPI/TX thread
# distribution in the platform packet-steering hook. Refuse to build if a
# future base silently drops it.
xr_packet_steering='target/linux/airoha/an7581/base-files/usr/libexec/platform/packet-steering.sh'
[ -f "$xr_packet_steering" ] || {
	echo "Missing XR1710G platform packet-steering hook" >&2
	exit 1
}
grep -Fq 'napi/phy*' "$xr_packet_steering" &&
	grep -Fq 'mt76-tx\ phy*' "$xr_packet_steering" || {
	echo "XR1710G MT7996 worker distribution is absent" >&2
	exit 1
}

# Preserve the reviewed YYH first-login credential. The image overlay replaces
# base-files' 50-root-passwd with a guarded variant which applies it only when
# the current root hash is empty, so sysupgrade cannot replace an owner password.
xr_board_network='target/linux/airoha/an7581/base-files/etc/board.d/02_network'
grep -Fq 'ucidef_set_root_password_plain "password"' "$xr_board_network" || {
	echo "Unexpected XR1710G board password baseline" >&2
	exit 1
}
grep -Fq 'root_password_is_empty' files/etc/uci-defaults/50-root-passwd || {
	echo "Missing guarded XR1710G first-login password policy" >&2
	exit 1
}

# The XR1710G device profile pulls in wpad-basic-mbedtls by default.  A full
# wpad-mesh build conflicts with every other hostapd/wpad provider, so remove
# all explicit providers before loading our package selections.
sed -i -E \
	'/^CONFIG_PACKAGE_(hostapd|hostapd-basic|hostapd-basic-mbedtls|hostapd-basic-openssl|hostapd-basic-wolfssl|hostapd-mbedtls|hostapd-mini|hostapd-openssl|hostapd-wolfssl|wpad|wpad-basic|wpad-basic-mbedtls|wpad-basic-openssl|wpad-basic-wolfssl|wpad-mbedtls|wpad-mesh-mbedtls|wpad-mesh-openssl|wpad-mesh-wolfssl|wpad-mini|wpad-openssl|wpad-wolfssl)(=| is not set)/d' \
	.config
sed -i -E '/^CONFIG_PACKAGE_(iw|iw-full)(=| is not set)/d' .config
sed -i -E \
	'/^CONFIG_(USES_SEPARATE_INITRAMFS|TARGET_ROOTFS_INITRAMFS_SEPARATE|TARGET_INITRAMFS_COMPRESSION_(NONE|GZIP|BZIP2|LZMA|LZO|LZ4|XZ|ZSTD))(=| is not set)/d' \
	.config

# Advertise the target capability required for Kconfig to expose and retain
# TARGET_ROOTFS_INITRAMFS_SEPARATE. The XR1710G FIT recipe already has
# "with-initrd"; this makes that path functional without changing its layout.
sed -i -E \
	's/^(FEATURES:=.*[[:space:]])ramdisk([[:space:]].*)$/\1separate_ramdisk\2/' \
	target/linux/airoha/Makefile
grep -Eq '^FEATURES:=.*(^|[[:space:]])separate_ramdisk([[:space:]]|$)' \
	target/linux/airoha/Makefile || {
	echo "Unable to enable Airoha separate-ramdisk target capability" >&2
	exit 1
}

# Keep profiles.json/ImageBuilder metadata aligned with the actual image.
# Limit the substitutions to the XR1710G device block; other Airoha profiles
# retain their upstream wireless provider and theme choices. The YYH baseline
# selects GlassTheme and its Chinese catalog in the XR1710G profile, while this
# iStoreOS port installs Argon and must not ship two competing first-boot
# themes.
xr_profile_file='target/linux/airoha/image/an7581.mk'
xr1710g_profile="$(
	sed -n '/^define Device\/econet_xr1710g-ubi$/,/^endef$/p' \
		"$xr_profile_file"
)"
for glass_pkg in luci-theme-glass luci-i18n-glass-zh-cn; do
	printf '%s\n' "$xr1710g_profile" |
		grep -Eq "(^|[[:space:]])${glass_pkg}([[:space:]]|$)" || {
		echo "Unexpected XR1710G profile: missing reviewed YYH package $glass_pkg" >&2
		exit 1
	}
done
sed -i \
	'/^define Device\/econet_xr1710g-ubi$/,/^endef$/ s/wpad-basic-mbedtls/wpad-mesh-openssl/' \
	"$xr_profile_file"
sed -i -E \
	'/^define Device\/econet_xr1710g-ubi$/,/^endef$/ {
		/[[:space:]]luci-i18n-glass-zh-cn[[:space:]]*\\$/d
		s/(^|[[:space:]])luci-theme-glass([[:space:]]|$)/\1/
	}' "$xr_profile_file"
xr1710g_profile="$(
	sed -n '/^define Device\/econet_xr1710g-ubi$/,/^endef$/p' \
		"$xr_profile_file"
)"
printf '%s\n' "$xr1710g_profile" | grep -Fq 'wpad-mesh-openssl' || {
	echo "Unable to select wpad-mesh-openssl in the XR1710G profile" >&2
	exit 1
}
if printf '%s\n' "$xr1710g_profile" | grep -Fq 'wpad-basic-mbedtls'; then
	echo "XR1710G profile still contains wpad-basic-mbedtls" >&2
	exit 1
fi
if printf '%s\n' "$xr1710g_profile" |
	grep -Eq '(^|[[:space:]])luci-(theme-glass|i18n-glass-zh-cn)([[:space:]]|$)'; then
	echo "XR1710G profile still selects GlassTheme" >&2
	exit 1
fi

# A reused build directory may carry explicit Glass selections from the YYH
# profile even after the profile is corrected. Remove only these two stale
# symbols before defconfig; the package sources remain available to unrelated
# Airoha profiles.
sed -i -E \
	'/^CONFIG_(DEFAULT|PACKAGE)_luci-(theme-glass|i18n-glass-zh-cn)=y$/d' \
	.config

# The first public image used the corrected UBI 2.0 layout but a clean install
# did not persist OpenWrt's generic compatibility marker. Keep metadata stable
# and enforce the real safety condition in the Airoha platform hook instead:
# all four live MTD boundaries must exactly match XR1710G UBI 2.0 before every
# sysupgrade. This supports repeatable background upgrades without weakening
# the old-layout migration guard.
xr_transition_patch="$GITHUB_WORKSPACE/patches/openwrt/0100-xr1710g-guard-transition-sysupgrade.patch"
[ -f "$xr_transition_patch" ] || {
	echo "XR1710G guarded transition patch is missing" >&2
	exit 1
}
git apply --check "$xr_transition_patch"
git apply "$xr_transition_patch"
grep -Fq 'XR1710G UBI 2.0 boundaries are not active' \
	target/linux/airoha/an7581/base-files/lib/upgrade/platform.sh || {
	echo "XR1710G platform layout guard was not installed" >&2
	exit 1
}
xr1710g_profile="$(
	sed -n '/^define Device\/econet_xr1710g-ubi$/,/^endef$/p' \
		target/linux/airoha/image/an7581.mk
)"
printf '%s\n' "$xr1710g_profile" | grep -Fq 'DEVICE_COMPAT_VERSION := 1.0' || {
	echo "XR1710G layout-aware compatibility metadata was not installed" >&2
	exit 1
}

# ===== 追加第三方插件包（不影响 .config 主文件）=====
PKG_CONF="$GITHUB_WORKSPACE/packages/openwrt.conf"
[ -f "$PKG_CONF" ] && grep -v '^#' "$PKG_CONF" | grep -v '^$' >> .config && echo "已加载第三方插件: openwrt" || true

# ===== 修改内核选项示例 =====
# sed -i '/CONFIG_PACKAGE_kmod-usb-ohci/d' .config
sed -i '/CONFIG_PACKAGE_mihomo-alpha/d' .config

# Brand this explicitly as a community port, not an official iStoreOS build.
sed -i -E \
	-e '/^CONFIG_VERSION_(DIST|NUMBER|MANUFACTURER|PRODUCT|HOME_URL|SUPPORT_URL|REPO)=/d' \
	.config
cat >> .config <<'CONFIGEOF'
CONFIG_VERSIONOPT=y
CONFIG_VERSION_DIST="iStoreOS-XR1710G-Community"
CONFIG_VERSION_NUMBER="v1.4.0"
CONFIG_VERSION_MANUFACTURER="XR1710G Community"
CONFIG_VERSION_PRODUCT="XR1710G iStoreOS Community Port"
CONFIG_VERSION_HOME_URL="https://doc.linkease.com/zh/guide/istoreos/"
CONFIG_VERSION_SUPPORT_URL="https://github.com/YYH2913/openwrt"
# This port tracks an OpenWrt snapshot.  A releases/%V URL expands to the
# nonexistent releases/SNAPSHOT tree and makes every APK source return 404.
CONFIG_VERSION_REPO="https://downloads.openwrt.org/snapshots"

# The Airoha recovery FIT recipe uses "with-initrd". Keep the normal kernel
# unchanged and attach the complete recovery rootfs as a compressed ramdisk.
CONFIG_USES_SEPARATE_INITRAMFS=y
CONFIG_TARGET_ROOTFS_INITRAMFS_SEPARATE=y
CONFIG_TARGET_INITRAMFS_COMPRESSION_XZ=y
CONFIGEOF

# ===== UCI 默认值示例 ======
# mkdir -p openwrt/files/etc/uci-defaults
# cat > openwrt/files/etc/uci-defaults/99-custom << 'UCIEOF'
# uci set system.@system[0].timezone='CST-8'
# uci commit system
# UCIEOF
