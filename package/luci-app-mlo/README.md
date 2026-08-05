# luci-app-mlo

Standalone LuCI package for editing OpenWrt Wi-Fi MLO settings.

What it does:
- Adds a new `Network -> MLO` page in LuCI
- Writes directly to `wireless` UCI sections
- Exposes `option mlo '1'` and multi-value `device` entries
- Avoids the stock wireless page limitation where `device` is still handled like a single value
- Shows runtime MLD detection and active ifnames from `luci-rpc getWirelessDevices`
- Provides quick-create buttons for AP and STA MLO profiles with safer defaults

Suggested workflow:
1. Place or symlink this folder into your OpenWrt tree, for example:
   `ln -s ../../luci-app-mlo openwrt/package/luci-app-mlo`
2. Enable `luci-app-mlo` in `make menuconfig`
3. Build and flash
4. Open LuCI at `Network -> MLO`

Notes:
- This app edits `/etc/config/wireless` only
- Save & Apply will use normal LuCI/UCI apply flow
- Leave `ifname` empty to let netifd create names such as `ap-mld0` or `sta-mld0`
