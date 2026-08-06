# OpenWrt Community Post: Gemtek XR1710G iStoreOS/OpenWrt Community First Release

## Suggested title

`Gemtek XR1710G community build: Airoha AN7581, MT7996 Wi-Fi 7, 6 GHz 802.11s Mesh/EHT320, iStoreOS-style LuCI and U-Boot`

## Post

I am publishing the first community build for the Gemtek XR1710G.

The target combines an Airoha AN7581 platform with a MediaTek MT7996 Wi-Fi 7 radio. This port focuses on the parts that are currently missing or incomplete in generic OpenWrt images for this device: the XR1710G device tree, NAND/UBI 2.0 layout, MT7996 support, 6 GHz wireless backhaul, iStoreOS-style LuCI integration, OpenClash, and Airoha NPU/flow-offload diagnostics.

### Download

Release:

https://github.com/orangeyoo/iStoreOS-XR1710G-Community/releases/tag/v1.0.0

Source:

https://github.com/orangeyoo/iStoreOS-XR1710G-Community

The Release keeps the user-facing download set small:

| File | Purpose |
|---|---|
| `xr1710g-uboot-first-release-flash-slot.bin` | U-Boot update image; flash once from the U-Boot Update U-Boot page |
| `xr1710g-community-first-release-recovery.itb` | System image for the U-Boot Recovery page |
| `xr1710g-community-first-release-sysupgrade.itb` | Upgrade image for an already running compatible OpenWrt/iStoreOS system |
| `SHA256SUMS.txt` | Integrity verification; never flash this file |
| `FLASHING-GUIDE.md` | Short Chinese and English flashing and language-switch guide |

Do not flash a system ITB as U-Boot, and do not flash a raw `u-boot.bin` into the slot. Confirm the device is a Gemtek XR1710G and verify SHA-256 before flashing.

### What changed in this port

- Reorganized the XR1710G Airoha AN7581 device tree, partition map, and UBI 2.0 image layout.
- Built on Linux 6.18.38 with the XR1710G MT76/MT7996 adaptation pinned at `b2704cf5`.
- Default LAN management address is `192.168.50.1` to reduce collisions with common ONT gateways at `192.168.1.1`.
- Default 6 GHz backhaul is single-hop 802.11s Mesh using the US regulatory domain, PSC channel 37, EHT320, and WPA3-SAE.
- WDS/AP-WDS compatibility fixes are included, but WDS is not the default backhaul and MLO is disabled by default.
- Fixed terminal `tx failed` accounting and added wireless, Mesh, temperature, and NPU diagnostics.
- Integrated an iStoreOS-style LuCI theme, iStore/QuickStart/Argon entry points, OpenClash core, and feed-isolation fixes.
- Added PPPoE/LAN role helpers to prevent assigning PPPoE to LAN.
- The 2.4 GHz initial profile uses a WPA/WPA2 Personal mixed mode for legacy clients. 5 GHz is intended for client access, while 6 GHz is reserved for Mesh backhaul by default.

### 6 GHz backhaul design

The default design is 802.11s Mesh, not MLO. Both nodes must use the same Mesh ID, WPA3-SAE key, channel, and channel width.

This allows 6 GHz to be dedicated to node-to-node backhaul while phones and computers use 5 GHz or 2.4 GHz. Real throughput depends on placement, floor construction, signal level, and interference; PHY rate alone is not a performance guarantee.

### Hardware acceptance

Two physical XR1710G units passed read-only log acceptance:

The nodes were placed on different floors, approximately 5 meters apart, with a wooden staircase and a concrete floor slab between them.

- 6 GHz Mesh state: `ESTAB`
- US regulatory domain, channel 37, EHT320
- `tx failed=0` on both nodes
- Approximately `52.6°C / 56.7°C`
- No firmware crash, MCU timeout, kernel panic, watchdog, UBI/I/O error, or `airtime_link_metric_get` was found

Brief SAE failures and Mesh reconnection during a reboot or radio reload are possible recovery behavior. This is not a zero-second handoff guarantee.

### Known boundaries

- Unofficial community build for Gemtek XR1710G only. Do not flash it on other Airoha or MediaTek devices.
- The Release is marked Pre-release. The U-Boot large-upload fix still needs broader new-device hardware validation.
- The first boot uses Simplified Chinese. English users can open `System → System → Language and Style`, select `English`, and click `Save & Apply`.
- The public system image predates the final translation audit. The source branch contains the translation corrections; the next rebuilt image will include them.
- Do not publish Wi-Fi passwords, PPPoE credentials, root passwords, DDNSTO tokens, or complete `/etc/config` backups in bug reports.

### Attribution

The source tree documents references to YYH2913/openwrt, naoki66/ImmortalWrt-for-Gemtek-XR1710G, iStoreOS/iStoreX, OpenClash, Argon, QuickStart, mt76, hostapd, and upstream Airoha/MediaTek content.

U-Boot source:

https://github.com/YYH2913/http-uboot

See the `uboot/` directory in the source repository for the U-Boot provenance, patch, and non-modified areas.

### Useful bug-report data

Please include the hardware batch, router/node role, 6 GHz Mesh status, channel, width, approximate node distance, and sanitized `dmesg`, `iw dev`, and `ubus call network.wireless status` output. Do not post only a PHY-rate screenshot and do not include private credentials.

Suggested forum category: **Community Builds, Projects & Packages** (or the closest hardware-development category available).

Suggested forum tags: `xr1710g`, `airoha`, `mt7996`, `wifi7`, `6ghz`, `mesh`.
