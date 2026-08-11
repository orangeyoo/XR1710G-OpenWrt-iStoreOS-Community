#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export GITHUB_WORKSPACE=/builder
# GNU tar's configure intentionally refuses uid 0 unless this documented
# override is set. GitHub Actions builds as an unprivileged user, while this
# local Docker helper intentionally uses the container's root user.
export FORCE_UNSAFE_CONFIGURE=1
# Do not inherit Windows PATH entries into OpenWrt/Go shell recipes.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

apt-get update -qq
# shellcheck disable=SC2046
apt-get install -y -qq $(tr -d '\r' < /builder/depends/ubuntu-22.04)

if [ ! -d /work/openwrt/.git ]; then
	git clone --filter=blob:none \
		--branch xr1710g-6.18-integration \
		https://github.com/YYH2913/openwrt.git /work/openwrt
fi

cd /work/openwrt
git fetch --depth=1 origin 2a845ee80c7c52caafe57d518a15b16738eb9ed7
git checkout 2a845ee80c7c52caafe57d518a15b16738eb9ed7
git clean -ffd

cp /builder/feeds.d/openwrt feeds.conf
cp -a /builder/files/. files/
cp -a /builder/apps/. package/
chmod 0755 files/etc/uci-defaults/99-custom.sh
chmod 0755 files/etc/uci-defaults/41_uhttpd_proxy_linkease
chmod 0755 files/etc/uci-defaults/zz-xr1710g-services.sh
chmod 0755 files/etc/init.d/xr1710g-bootlog
chmod 0755 files/usr/sbin/xr1710g-mesh-diag
chmod 0755 files/usr/sbin/xr1710g-role
chmod 0755 files/usr/sbin/xr1710g-wan-carrier
chmod 0755 files/usr/sbin/xr1710g-wireless-defaults
chmod 0755 files/etc/openclash/core/clash_meta
chmod 0600 files/etc/crontabs/root

sh /builder/scripts/test-xr1710g-tools.sh /builder

./scripts/feeds update -a
/builder/scripts/prepare-istore-feed.sh
XR_ISTORE_FIXTURE="$PWD/feeds/istore/luci/luci-app-store/root/bin/is-opkg" \
XR_QUICKSTART_FIXTURE="$PWD/feeds/linkease_nas_luci/luci/luci-app-quickstart/htdocs/luci-static/quickstart/index.js" \
  /builder/scripts/test-status-and-istore-safety.sh /builder
./scripts/feeds install -a

cp /builder/configs/openwrt.config .config
/builder/diy-part2.d/openwrt.sh
make defconfig

grep -qx 'CONFIG_PACKAGE_luci-app-store=y' .config
grep -qx 'CONFIG_PACKAGE_quickstart=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-quickstart=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-istorex=y' .config
grep -qx 'CONFIG_PACKAGE_luci-theme-argon=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-argon-config=y' .config
grep -qx 'CONFIG_PACKAGE_luci-app-openclash=y' .config
grep -qx 'CONFIG_PACKAGE_usteer=y' .config
grep -qx 'CONFIG_PACKAGE_wpad-mesh-openssl=y' .config

make download -j16
# Only remove failed top-level archive placeholders. Recursing into
# dl/go-mod-cache would delete legitimate small Go source files and corrupt
# packages such as yq.
find dl -maxdepth 1 -type f -size -1024c -delete

# Do not allow an incremental package cache to retain the v7 uhttpd binary.
# v8 adds iStoreOS' reviewed reverse-proxy stack to this package.
make package/network/services/uhttpd/clean
make -j16
bash /builder/scripts/rebuild-initramfs-recovery.sh "$PWD"
sh /builder/scripts/verify-xr1710g-build.sh "$PWD" 2>&1 | tee /work/verify.txt

sh /builder/scripts/package-release.sh "$PWD" /work/dist
