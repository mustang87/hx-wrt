include $(TOPDIR)/rules.mk

PKG_NAME:=hx-brand
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/hx-brand
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=HX-WRT branding base
endef

define Package/hx-brand/description
HX-WRT branding files and metadata.
endef

define Build/Compile
endef

define Package/hx-brand/install
	$(INSTALL_DIR) $(1)/etc/hx-wrt
	$(INSTALL_CONF) ./files/etc/hx-wrt/brand.conf $(1)/etc/hx-wrt/brand.conf
endef

$(eval $(call BuildPackage,hx-brand))
