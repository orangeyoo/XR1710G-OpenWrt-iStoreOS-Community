# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.4.0

**Languages:** [English (this page)](README-EN.md) | [中文](README.md) | [Bilingual Flashing Guide](FLASHING-GUIDE.md)

**Gemtek XR1710G, Airoha AN7581, MediaTek MT7996, OpenWrt, iStoreOS, Wi-Fi 7, and 6GHz 802.11s Mesh.**

This is an unofficial community port for the **Econet/Gemtek XR1710G (Airoha AN7581 + MT7996)**. It builds on [YYH2913/openwrt](https://github.com/YYH2913/openwrt) board support and integrates iStore, QuickStart, Argon, OpenClash, PassWall2, upstream OpenWrt Docker packages, and XR1710G status and diagnostic components.

This project is not an official release from LinkEase/iStoreOS, OpenWrt, Gemtek, Airoha, or MediaTek. It is only for the XR1710G and must not be flashed to visually similar devices or other Airoha/MediaTek hardware.

## What is new in v1.4.0

- Fixes the LAN editor crash and static IPv4 CIDR persistence. A bare LAN address is safely normalized to `/24`; the back-end guard also converts legacy `ipaddr + netmask` data so LAN and DHCP do not disappear after a reboot.
- Fixes the home page being redirected to **Status → Overview**. iStoreX/QuickStart home routes no longer depend on service-start timing.
- Replaces competing fan services with one controller, including a low-temperature minimum stable step, staged speed increases, hysteresis, and sensor-failure fallback.
- Makes Dockerman compatible with the Moby 29 information structure. A stopped Docker service now shows a clear state and enable action instead of raw nested JSON.
- Removes GlassTheme and its Chinese package. A clean installation defaults to Argon, while Sysupgrade preserves the theme already selected by the owner.
- Sets the clean-install 6GHz template to `US / channel 37 / EHT160 / 802.11s / network=lan`. No SAE key is preset, so the interface remains disabled until both nodes have a matching Mesh ID and key.
- Preserves the ingress netdev on the MT7996 NPU RX path so bridge/FDB software fallback retains the correct context after a PPE cache miss. The accurate boundary is “wired Airoha PPE offload plus MT7996 Wi-Fi NPU queues”; no unverified end-to-end 802.11s PPE bypass is included.
- Adds bridge/PPE protection for router-local traffic after a 10G uplink is active. Local-FDB, router-destination, and same-ingress reinjection flows are not bound back to 10G GDM4, while ordinary wired forwarding and NAT/PPE offload remain available.
- Preinstalls `kmod-nft-fullcone` with matching libnftnl/nftables/firewall4/LuCI support. Full Cone stays disabled by default, cannot bypass CGNAT or double NAT, and does not guarantee NAT Type 1.
- Preinstalls PassWall2 `26.8.20`, Xray `26.7.28`, sing-box `1.13.19`, and the firewall4-native nftables transparent-proxy path. PassWall2 is disabled by default; do not enable it together with OpenClash.
- Strengthens first-boot credential checks: the initial administrator password is `password`; 2.4/5GHz have no preset Wi-Fi password, while the empty-key 6GHz Mesh template remains disabled.

See [CHANGES-v1.md](CHANGES-v1.md) for detailed changes and [ATTRIBUTION.md](ATTRIBUTION.md) for source and license boundaries.

## Core features

- Linux 6.18.41 with XR1710G AN7581 device tree, NAND/UBI 2.0, Ethernet, PPE, and NPU support.
- Pinned XR1710G mt76/MT7996 adaptation commit `b2704cf5`; hostapd baseline 2026-07-09 `f08f2749`.
- Tri-band 2.4/5/6GHz Wi-Fi 7 and WPA3-SAE 802.11s Mesh; MLO is disabled by default.
- WDS/AP-WDS is supplementary and is not the default backhaul. The recommended backhaul remains single-hop 802.11s.
- iStore, iStoreX, QuickStart, Argon, OpenClash, PassWall2, Nikki, EqosPlus, and diagnostic pages.
- Upstream OpenWrt Moby, containerd, runc, docker-compose, and Dockerman. Docker is stopped and disabled by default.
- Default management address `192.168.50.1/24`, reducing conflicts with optical modems commonly using `192.168.1.1`.
- `/usr/sbin/xr1710g-role` prepares main-router and node roles without automatically switching the network path or rebooting.
- `/usr/sbin/xr1710g-mesh-diag` produces privacy-reduced Mesh, signal, PHY-rate, retry, temperature, and log summaries.

## Default wireless policy

Wireless defaults are applied on a clean first boot only after the driver is ready:

- 2.4GHz: US, automatic channel, HE20, requested 28dBm; SSID `XR1710G`, initially open with no preset password.
- 5GHz: US, channel 36, EHT80, requested 29dBm; SSID `XR1710G-5G`, initially open with no preset password, with 802.11k/v/r and the active-client inactivity protection.
- 6GHz: US, PSC channel 37, EHT160, requested 28dBm, WPA3-SAE 802.11s Mesh template attached to `lan`. It has no preset key and is disabled initially.

Immediately replace the administrator password and configure encryption for 2.4/5GHz after the first login. Mixed WPA/WPA2 Personal may be selected on 2.4GHz when older devices require it. Configure the same Mesh ID, SAE key, channel, width, and regulatory profile on both routers before enabling 6GHz.

All three XR1710G bands share one Linux PHY, so the kernel ultimately applies one regulatory domain. The radios cannot be treated as three independent country-code devices. Standard US/AU profiles use the original regdb rules.

### XZ laboratory profile

XZ is an opt-in composite laboratory profile: 2.4/5GHz use fixed AU-derived rules and 6GHz adds a 36dBm no-AFC experimental rule. XZ is not a country regulatory domain, the firmware does not implement AFC, and it grants no Standard Power authorization. It is disabled by default and is only for controlled laboratory work or testing with the required authorization. Users must comply with local channel and power rules. Actual output remains limited by the driver, firmware, and Factory calibration.

## Physical validation scope

Both v1.4.0 Recovery and Sysupgrade images passed the complete content gate. Critical rootfs content and checks for the wireless template, Argon, LAN CIDR, Dockerman, Full Cone, PassWall2, and the NPU fix agree between the two images.

During the isolated 10G test:

- XR1710G `wan` negotiated 10Gbps Full and `lan1` negotiated 5Gbps Full with the test NAS.
- A 15-second, four-stream TCP test measured about 3.85Gbps from XR to NAS and 1.69Gbps from NAS to XR.
- Both ports ended with `rx/tx errors=0`, with no new Link Down, watchdog, DMA/NPU timeout, firmware crash, or kernel panic.

These results establish carrier and direct local-endpoint transfer stability with the tested cable and peer. They are not a guarantee for every switch, ISP, routed/NAT, or heterogeneous bridge topology.

An earlier two-node wireless validation used one unit upstairs and one downstairs, approximately five metres apart across a wooden staircase and concrete floor. With XZ/channel 37/EHT320 selected manually, 20 bidirectional four-stream tests over about ten minutes had medians near 715/720Mbps and minima near 678/671Mbps; two post-load 600-packet Ping runs had 0% loss. This is a result for that placement and manual EHT320 configuration, not a throughput promise for the default EHT160 template or every environment.

## Two-node roles and Mesh

The image does not guess which unit should be the main router. Two clean units both start at `192.168.50.1` with DHCP enabled, so configure them one at a time:

1. Keep a non-conflicting LAN address and DHCP on the main router, and configure Internet access only on the dedicated WAN interface.
2. Give the node a static address in the same subnet, such as `192.168.50.2/24`; disable its DHCPv4, RA, and DHCPv6 servers, then point its gateway and DNS to the main router.
3. Configure the same 2.4/5GHz SSIDs, encryption, and passwords on both units. These settings are not synchronized automatically.
4. Configure the same 6GHz Mesh ID, SAE key, channel, width, and regulatory profile on both units.
5. Keep Ethernet management connected until `mesh plink: ESTAB` is confirmed.

Role-tool examples:

```sh
xr1710g-role status
xr1710g-role main-dhcp 192.168.50.1/24
xr1710g-role main-pppoe 192.168.50.1/24
xr1710g-role node 192.168.50.2/24 192.168.50.1
```

The tool backs up UCI and commits configuration only; it does not reload networking or wireless and does not reboot. The detailed Mesh guide is available in Chinese at [MESH-GUIDE-ZH.md](MESH-GUIDE-ZH.md).

## Docker

This project does not provide a custom Docker engine. It preinstalls the open-source Moby, containerd, runc, docker-compose, and luci-app-dockerman packages from OpenWrt feeds.

- Installed by default, but stopped and disabled.
- Starts only after the owner enables it through iStore, Dockerman, or the CLI.
- All three paths control the same `/etc/init.d/dockerd`, `/etc/config/dockerd`, and `/var/run/docker.sock`.
- The data root is `/overlay/docker/`; use external storage for large image and container collections.

## Release files

The formal Release contains only the required files:

| File | Purpose |
|---|---|
| `xr1710g-community-v1.4.0-sysupgrade.itb` | Preferred image for compatible web upgrades and permanent installation through compatible HTTP U-Boot |
| `xr1710g-community-v1.4.0-recovery.itb` | Temporary rescue/recovery image; it does not replace permanent Sysupgrade installation |
| `xr1710g-uboot-flash-slot.bin` | Hardware-validated compatible build based on YYH2913 HTTP U-Boot, with paced large uploads and safe interrupted-upload cleanup; flash only when a U-Boot update is needed |
| `SHA256SUMS.txt` | Integrity checks; never flash this file |
| `FLASHING-GUIDE.md` | Bilingual file-purpose and flashing guide |

Read [FLASHING-GUIDE.md](FLASHING-GUIDE.md) before flashing. Prefer `xr1710g-community-v1.4.0-sysupgrade.itb` from a compatible OpenWrt/iStoreOS system or from the compatible HTTP U-Boot **Firmware + UBI 2.0 - 439 MiB** page. Never flash a system ITB into the U-Boot slot.

The initial address is `192.168.50.1`, the user is `root`, and the initial password is `password`. Connect one unit by Ethernet and immediately replace the administrator password and configure wireless encryption.

### Switching the UI to English

The first-boot UI is Simplified Chinese. Open **System → System → Language and Style**, select **English**, and click **Save & Apply**.

## Build

```sh
docker volume create xr1710g-istoreos-final
docker run --name xr1710g-istoreos-build-final \
  -v xr1710g-istoreos-final:/work \
  -v "$PWD":/builder:ro \
  ubuntu:22.04 bash /builder/scripts/build-local-docker.sh
```

Key entry points:

- `configs/openwrt.config`: pinned build configuration.
- `feeds.d/openwrt`: pinned upstream feeds commit.
- `diy-part2.d/openwrt.sh`: XR1710G/iStoreOS community integration.
- `patches/`: OpenWrt, LuCI, package, and kernel patches.
- `scripts/prebuild-xr1710g-release.sh`: source release gate.
- `scripts/verify-xr1710g-build.sh`: final Recovery/Sysupgrade image gate.

## Upstreams and licenses

This project uses and credits YYH2913/openwrt, YYH2913/http-uboot, naoki66/ImmortalWrt-for-Gemtek-XR1710G, OpenWrt, mt76, hostapd, iStoreOS, iStore/iStoreX, QuickStart, OpenClash, PassWall2, Argon, Nikki, sirpdboy/EqosPlus, and Airoha/MediaTek upstream work. See [ATTRIBUTION.md](ATTRIBUTION.md) for pinned revisions, purposes, and license boundaries. Each third-party component remains under its own license; inclusion does not imply endorsement.
