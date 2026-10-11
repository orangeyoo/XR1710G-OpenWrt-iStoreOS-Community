include $(TOPDIR)/rules.mk

PKG_NAME:=xr1710g-system
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=XR1710G Maintainer

include $(INCLUDE_DIR)/package.mk

define Package/xr1710g-system
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=XR1710G board system integration
  DEPENDS:=+jsonfilter
endef

define Package/xr1710g-system/description
 Board-level first-boot policy and runtime services for the XR1710G
 (econet,xr1710g-ubi): routed/NAT hardware-offload migration, IRQ/CPU
 affinity, CPU governor, NCT7802 fan control, LAN CIDR guard, boot history,
 sysupgrade RPC helper, wireless first-boot policy, mesh/net diagnostics and
 the main-router/mesh-node role switch helper.
endef

define Build/Compile
endef

define Package/xr1710g-system/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./files/etc/uci-defaults/* $(1)/etc/uci-defaults/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/* $(1)/etc/init.d/
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/etc/hotplug.d/iface/* $(1)/etc/hotplug.d/iface/
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(INSTALL_BIN) ./files/etc/hotplug.d/net/* $(1)/etc/hotplug.d/net/
	$(INSTALL_DIR) $(1)/lib/netifd
	$(INSTALL_BIN) ./files/lib/netifd/xr1710g-dhcpv6-guard.sh $(1)/lib/netifd/
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/lib/upgrade/keep.d/xr1710g-docker $(1)/lib/upgrade/keep.d/
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/usr/libexec/xr1710g-irq-affinity $(1)/usr/libexec/
	$(INSTALL_BIN) ./files/usr/libexec/xr1710g-upgrade $(1)/usr/libexec/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/* $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/* $(1)/usr/share/rpcd/acl.d/
endef

$(eval $(call BuildPackage,xr1710g-system))
