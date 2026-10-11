include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-xr1710g-recovery
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=XR1710G Community
PKG_LICENSE:=GPL-2.0-or-later
LUCI_TITLE:=XR1710G Recovery and Factory Reset
LUCI_DEPENDS:=+luci-base +uboot-envtools

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))
