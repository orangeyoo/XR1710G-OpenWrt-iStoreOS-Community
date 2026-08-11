include $(TOPDIR)/rules.mk

PKG_NAME:=xr1710g-status-core
PKG_VERSION:=1.0.0
PKG_RELEASE:=2
PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=XR1710G Maintainer

include $(INCLUDE_DIR)/package.mk

define Package/xr1710g-status-core
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=XR1710G safe status collection helpers
  DEPENDS:=+jsonfilter
endef

define Package/xr1710g-status-core/description
 Shared cache, locking, JSON validation and physical-link helpers for the
 XR1710G LuCI status applications.
endef

define Build/Compile
endef

define Package/xr1710g-status-core/install
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/xr1710g-status-common $(1)/usr/libexec/
endef

$(eval $(call BuildPackage,xr1710g-status-core))
