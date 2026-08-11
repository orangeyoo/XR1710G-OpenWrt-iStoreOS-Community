# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware

**Languages:** [English (this page)](README-EN.md) | [中文](README.md) | [Bilingual Flashing Guide](FLASHING-GUIDE.md)

**Gemtek XR1710G, Airoha AN7581, MediaTek MT7996, OpenWrt, iStoreOS, Wi-Fi 7, and 6GHz 802.11s Mesh.**

This is an unofficial community port for the **Econet/Gemtek XR1710G (Airoha AN7581 + MT7996)**. It builds on the board support from [YYH2913/openwrt](https://github.com/YYH2913/openwrt) and integrates iStore, QuickStart, Argon, OpenClash, upstream OpenWrt Docker packages, and XR1710G status and diagnostic components following the public modular approach used by iStoreOS.

It is not an official release from LinkEase/iStoreOS, OpenWrt, Gemtek, Airoha, or MediaTek. It is only for the XR1710G and must not be flashed to visually similar devices or other Airoha/MediaTek hardware.

## v1.1.0 highlights

- Platform-wide reliability fixes for the Airoha SoC/NPU, FlowSense, and fan pages: shared caching, per-item locks, stale-lock recovery, and graceful degradation. LuCI request paths no longer poll physical registers through `devmem`.
- Fixes the reported LuCI session failure after opening a status page; repeated snapshots and browser sessions passed on two physical units.
- Fixes unplugged Ethernet ports being reported as connected or showing a negotiated speed by using physical `carrier` as the source of truth.
- iStore install, upgrade, self-update, and direct APK transactions now run `--simulate` first, leaving the package database unchanged when dependencies cannot be resolved.
- Preinstalls upstream OpenWrt Moby, containerd, runc, docker-compose, and Dockerman. Docker is stopped and disabled by default; iStore, Dockerman, and the CLI share `/etc/config/dockerd`, `/var/run/docker.sock`, and `/overlay/docker/`.
- Dockerman shows a clear stopped-state message and an enable action instead of only exposing a socket error.
- Brings up the physical WAN device before link detection and restores dnsmasq autostart during main-router role activation.
- Adds an opt-in XZ composite laboratory profile with complete Chinese and English shared-PHY/no-AFC warnings. Standard US/AU entries are unchanged, and XZ is disabled by default.

See [CHANGES-v1.md](CHANGES-v1.md) for the full change list and [ATTRIBUTION.md](ATTRIBUTION.md) for source and license boundaries.

## Core features

- Linux 6.18.38 with XR1710G AN7581 device tree, NAND/UBI 2.0, Ethernet, and NPU support.
- Pinned XR1710G mt76/MT7996 adaptation commit `b2704cf5`.
- Tri-band 2.4/5/6GHz Wi-Fi 7 and WPA3-SAE 802.11s Mesh.
- hostapd AP-WDS multi-BSS event-routing fix. WDS is supplementary and is not the default backhaul.
- MLO is disabled by default; the recommended stable backhaul remains single-hop 802.11s.
- iStore, iStoreX, QuickStart, Argon, OpenClash, Nikki, EqosPlus, and diagnostic pages.
- Default management address `192.168.50.1/24`, reducing conflicts with common `192.168.1.1` optical modems.
- `/usr/sbin/xr1710g-role` for preparing main-router and node roles without automatically switching the network path or rebooting.
- `/usr/sbin/xr1710g-mesh-diag` for Mesh, signal, PHY rate, retry, temperature, and log summaries.

## Default wireless policy

On a clean first boot, wireless defaults are applied only after the driver is ready:

- 2.4GHz: US, mixed WPA/WPA2 Personal for older-client compatibility.
- 5GHz: US, channel 36, EHT80, mixed WPA2/WPA3, with conservative 802.11k/v/r roaming assistance.
- 6GHz: US, PSC channel 37, EHT80, WPA3-SAE 802.11s Mesh.
- Mesh ID and password are explicit `CHANGE-ME` placeholders and must be changed identically on both units before deployment.

EHT80 is the initial-link and recovery-safe default, not a performance limit. With an independent management path and tested recovery, both ends can be changed to identical EHT160/EHT320 settings.

All three XR1710G bands share one Linux PHY, so the kernel ultimately applies one regulatory domain. The three LuCI radios cannot be treated as independent country domains. Standard country profiles retain their original regulatory database rules.

### XZ laboratory profile

XZ is an opt-in composite laboratory profile: 2.4/5GHz use pinned AU-derived rules, while 6GHz adds an experimental 36dBm no-AFC rule. XZ is not a country domain. This firmware does not implement AFC and does not grant Standard Power authority. XZ is disabled by default and is intended only for controlled laboratory work or specifically authorized testing. The user is responsible for complying with local laws, channels, and power limits. Actual transmit power remains constrained by the driver, firmware, and Factory calibration; selecting a 36dBm limit does not mean the hardware will transmit at 36dBm.

## Two-unit hardware validation

The two units were installed about five metres apart on different floors, across a wooden staircase and a concrete floor, with the upstairs node in the second-floor living room. With XZ/channel 37/EHT320 selected manually:

- 6GHz 802.11s remained `ESTAB`, with signal around `-63 to -67dBm`.
- The 30-second bidirectional baseline was approximately `716/735Mbps`.
- Twenty bidirectional four-stream runs over roughly ten minutes produced medians of `715/720Mbps` and minima of `678/671Mbps`; every run exceeded 400Mbps.
- Two 600-packet idle Ping tests after load both had 0% loss, averaging about 2ms.
- Across tens of millions of transmitted packets, `tx failed` increased by only 1/3 and driver retry rates were about 3.36%/2.10%.
- Peak temperatures were about 56.3/59.3 degrees C. No `airtime_link_metric_get`, MT7996 reset/timeout/crash, MCU timeout, firmware crash, Call Trace, kernel panic, or reboot occurred.

The iperf3 endpoints ran on the routers, with peak CPU around 44.8%. These figures validate backhaul stability and are not a claim of maximum throughput between two external 2.5GbE clients. Results vary with placement, construction, interference, and regulatory settings.

## Router, node, and roaming setup

The same image does not guess which unit should become the main router. Two clean units both start at `192.168.50.1` with DHCP enabled, so configure them one at a time:

1. Keep a non-conflicting LAN address and DHCP on the main router. Configure DHCP/PPPoE only on the dedicated WAN interface; never turn LAN into PPPoE.
2. Give the node a static address in the same subnet, such as `192.168.50.2`; disable its DHCPv4, RA, and DHCPv6 servers; and point its gateway/DNS to the main router.
3. Configure identical 2.4/5GHz SSIDs, encryption modes, and passwords on both units. Settings are not automatically synchronized.
4. Configure identical 6GHz Mesh ID, SAE key, channel, width, and regulatory profile on both units.
5. Keep wired management available until `mesh plink: ESTAB` is confirmed, then disconnect the node cable.

Role-tool examples:

```sh
xr1710g-role status
xr1710g-role main-dhcp 192.168.50.1/24
xr1710g-role main-pppoe 192.168.50.1/24
xr1710g-role node 192.168.50.2/24 192.168.50.1
```

The tool backs up UCI and commits configuration, but does not automatically reload networking/wireless or reboot. PPPoE passwords are read through hidden terminal input and are not written to command history.

## Docker

This project does not implement a private Docker engine. The firmware only preinstalls the upstream packages supplied through OpenWrt feeds: Moby `dockerd`/CLI, containerd, runc, docker-compose, and luci-app-dockerman.

- Installed, stopped, and disabled by default.
- Starts only after the user enables it through iStore or Dockerman.
- iStore, Dockerman, and the command line control the same `/etc/init.d/dockerd` service.
- The data root is `/overlay/docker/` on the roughly 311MiB overlay, not a separate large disk. External storage is recommended for many images or containers.

## Flashing

Read the [bilingual flashing guide](FLASHING-GUIDE.md). The Release contains only four required downloads: the validated YYH2913 U-Boot, one Sysupgrade system image, SHA256SUMS, and the bilingual guide.

For a normal install through YYH2913 HTTP U-Boot, open `http://192.168.255.1/`, choose **Firmware + UBI 2.0 - 439 MiB**, and upload `xr1710g-community-v1.1.0-sysupgrade.itb`. Do not use an initramfs development image as the normal installer.

The device must use the matching XR1710G UBI 2.0 layout:

| Partition | Start | Size |
|---|---:|---:|
| `vendor` | `0x00000000` | `0x00600000` |
| `chainloader` | `0x00600000` | `0x00100000` |
| `ubi` | `0x00700000` | `0x1b700000` |
| `reserved_bmt` | `0x1be00000` | `0x04200000` |

Do not modify or copy Factory, EEPROM, caldata, MAC, or wireless calibration data from another device. First boot uses `192.168.50.1`, user `root`, and an empty password. Connect by Ethernet and set an administrator password immediately.

### Switching the UI to English

The first-boot UI is Simplified Chinese. Open **System -> System -> Language and Style**, select **English**, and click **Save & Apply**. Changing the UI language does not alter WAN, LAN, Wi-Fi, or Mesh settings.

## Build and verification

The build pins its base and feed commits and checks source anchors, RPC safety, iStore transaction preflight, QuickStart physical-link logic, recovery/sysupgrade image consistency, image types, and release hygiene.

```sh
docker volume create xr1710g-istoreos-final
docker run --name xr1710g-istoreos-build-final \
  -v xr1710g-istoreos-final:/work \
  -v "$PWD":/builder:ro \
  ubuntu:22.04 bash /builder/scripts/build-local-docker.sh
```

Important files:

- `configs/openwrt.config`: pinned build configuration.
- `feeds.d/openwrt`: pinned upstream feed commits.
- `diy-part2.d/openwrt.sh`: XR1710G/iStoreOS community integration.
- `patches/`: OpenWrt, LuCI, package, and regulatory patches.
- `scripts/test-status-and-istore-safety.sh`: status, physical-link, and iStore transaction-safety tests.
- `scripts/verify-xr1710g-build.sh`: final image gate.
- `uboot/`: YYH2913 U-Boot source and independent experimental patch notes.

## Upstream projects and licenses

This project uses and credits work from YYH2913/openwrt, YYH2913/http-uboot, naoki66/ImmortalWrt-for-Gemtek-XR1710G, OpenWrt, mt76, hostapd, iStoreOS, iStore/iStoreX, QuickStart, OpenClash, Argon, Nikki, sirpdboy/EqosPlus, and Airoha/MediaTek upstream projects. See [ATTRIBUTION.md](ATTRIBUTION.md) for pinned commits, purposes, and licenses. Third-party components remain under their respective licenses, and this project does not imply endorsement by those upstream projects.

## Reporting an issue

Include the hardware batch, main-router/node role, regulatory profile, 6GHz channel and width, placement distance, and the relevant summaries from `xr1710g-mesh-diag`, `dmesg`, `iw dev`, and `ubus call network.wireless status`.
