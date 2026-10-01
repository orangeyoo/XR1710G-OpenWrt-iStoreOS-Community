# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware

**Current release: [v1.9](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v1.9)** · Updated: 2026-09-29 · Binary-only release; source publication is planned for the next version.

[![Release](https://img.shields.io/github/v/release/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/total?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/latest)
[![Stars](https://img.shields.io/github/stars/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/stargazers)
[![Forks](https://img.shields.io/github/forks/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/forks)
[![Issues](https://img.shields.io/github/issues/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/issues)
[![Last Commit](https://img.shields.io/github/last-commit/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/commits/public-first-release)
[![GPL-2.0](https://img.shields.io/badge/license-GPL--2.0--or--later-blue?style=flat-square)](ATTRIBUTION.md)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%20line-0099FF?style=flat-square)](https://openwrt.org)
[![Kernel](https://img.shields.io/badge/kernel-6.18.53-green?style=flat-square)](CHANGES-v1.md)
[![Wi-Fi 7](https://img.shields.io/badge/Wi--Fi%207-MT7996%20tri--band-8A2BE2?style=flat-square)](https://en.wikipedia.org/wiki/Wi-Fi_7)
[![SoC](https://img.shields.io/badge/SoC-Airoha%20AN7581-333333?style=flat-square)](https://www.airoha.com/)
[![iStoreOS](https://img.shields.io/badge/iStoreOS-component%20integration-FF6600?style=flat-square)](https://github.com/YYH2913/openwrt)
[![Docker](https://img.shields.io/badge/Docker-preinstalled%2C%20off%20by%20default-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![QQ Group](https://img.shields.io/badge/QQ%20group-1061612207-orange?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0)

Unofficial community firmware for the **Gemtek XR1710G**: tri-band Wi-Fi 7, a dedicated 6GHz mesh backhaul, the iStore app shop and Docker — ready to flash.

**[Download v1.9](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v1.9)** · [What changed](#new-in-v19) · [Flashing guide](FLASHING-GUIDE.md) · [Mesh guide](MESH-GUIDE-ZH.md) · [中文](README.md)

## At a glance

| Item | Details |
|---|---|
| For | **Gemtek XR1710G only** (Airoha AN7581 + MediaTek MT7996) |
| What it is | Unofficial OpenWrt / iStoreOS community firmware — not an official vendor release |
| Highlights | Tri-band Wi-Fi 7, two-unit 6GHz dedicated backhaul, iStore, OpenClash/PassWall2, Docker |
| After flashing | Manage at `http://192.168.50.1` |
| Login | User `root`; the initial administrator password is `password` |
| First Wi-Fi | 2.4/5GHz start open; set passwords right after login |

⚠️ Do not flash other models or look-alike Airoha/MediaTek devices.

## Four steps to get going

1. **Download** — download the system image and checksum file; flash only the system image.
2. **Flash** — already running compatible OpenWrt/iStoreOS: upload in the web UI; fresh/full install: upload the same file through compatible U-Boot. See [FLASHING-GUIDE.md](FLASHING-GUIDE.md).
3. **Log in** — connect by Ethernet, open `192.168.50.1`, use `root / password`.
4. **Finish** — change the admin password, set 2.4/5GHz Wi-Fi passwords; for a two-unit mesh see the one-page [mesh guide](MESH-GUIDE-ZH.md) (fill-in tables).

The UI starts in Simplified Chinese. Switch to English under **System → System → Language and Style → English → Save & Apply**.

## New in v1.9

- Correct EHT320 wireless rate capability configuration.
- Fix Ethernet RX processing and LRO state handling; LRO remains disabled by default.
- Restore the MLO interface and clean up initialization, with three independent single-link MLO AP defaults.
- Fix first-boot wireless overrides: EHT20 on 2.4GHz and EHT160 on 5/6GHz.
- Add missing 6GHz OWE support and fix related configuration errors.
- Fix stale web resources after firmware upgrades.

Disable MLO on mesh backhaul interfaces. MLO + WDS bridging still has compatibility issues.

If 5GHz stops working after changing the country code, restart the 5GHz radio and wait for DFS checks to complete.

Full per-version history since v1.4: [CHANGES-v1.md](CHANGES-v1.md).

## Downloads

| File | Purpose |
|---|---|
| `xr1710g-community-v1.9-sysupgrade.itb` | **The only system image** — web upgrades and compatible U-Boot permanent installs |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | Optional Wiro U-Boot v1.0.0; use only in Update U-Boot |
| `SHA256SUMS.txt` | System image and U-Boot checksums; not flashed |

The bundled Wiro U-Boot v1.0.0 is unchanged from its [original release](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0), which includes instructions, provenance and license details. Devices with compatible U-Boot do not need to reflash it.

No separate recovery.itb is needed; GitHub's auto-generated Source code archives are not flashable; never flash a system ITB into the U-Boot slot. If an old upgrade page times out without rebooting, do not resubmit — follow the guide.

## Factory defaults

Wireless defaults apply after the drivers finish loading on a clean first boot:

- 2.4GHz: US, channel 1, EHT20, 28 dBm requested; SSID `XR1710G`, initially open with no preset password.
- 5GHz: US, channel 36, EHT160, 29 dBm requested; SSID `XR1710G-5G`, initially open with no preset password, with 802.11k/v/r and stale-client protection enabled.
- 6GHz: US, PSC channel 37, EHT160, 28 dBm requested; SSID `XR1710G-6G`, initially an OWE AP with PMF required.
- Each band defaults to an independent single-link MLO AP. Configure mesh backhaul separately with MLO disabled on that interface.
- 2.4/5GHz have no preset Wi-Fi password; change the administrator password and set wireless encryption immediately after first login.
- All three bands share one Linux PHY: the regulatory domain applies to all bands together and cannot differ per band.

For legacy clients, 2.4GHz can be switched to mixed WPA/WPA2. The XZ experimental profile (AU-derived + 6GHz 36 dBm experimental rules) ships disabled and is for authorized, controlled testing only.

## Two-unit mesh (6GHz backhaul)

```
ONT ── Main (192.168.50.1) ════ 6GHz dedicated link ════ Node (192.168.50.2)
              │                                            │
     Phones/laptops use the 2.4/5GHz SSID — one name everywhere, roaming
```

Full steps in [MESH-GUIDE-ZH.md](MESH-GUIDE-ZH.md) (one-page, table-driven, Chinese). Role helper:

```sh
xr1710g-role status
xr1710g-role main-dhcp 192.168.50.1/24   # or main-pppoe
xr1710g-role node 192.168.50.2/24 192.168.50.1
```

The tool backs up and commits configuration only; it never reloads the network or reboots on its own.

## Feature overview

| Area | Contents |
|---|---|
| System | Linux 6.18.53, UBI 2.0 layout, default address 192.168.50.1, performance governor, single-controller fan policy |
| Wireless | Tri-band Wi-Fi 7 (MT7996 on mt76 be5ce791-r10 / backports 7.2-r4), 802.11s mesh, 802.11k/v/r, BBR enabled |
| Shop/plugins | iStore, iStoreX, QuickStart, Argon theme, OpenClash, PassWall2 (off by default; never enable both proxies together), Nikki, EqosPlus |
| Docker | Upstream OpenWrt Moby/containerd/runc/compose + Dockerman; preinstalled but off; all entry points share one config |
| Network | Software/hardware flow offload disabled by default, Full Cone NAT (enabled by default; cannot bypass CGNAT or double NAT), 10G port protection fixes |
| Diagnostics | `xr1710g-role`, privacy-safe `xr1710g-mesh-diag`, cached status pages (no devmem in LuCI hot paths) |

## Validation boundaries (honesty)

- v1.9: both units were checked with ordinary APs and 6GHz mesh. Fresh-install OWE client association and long-term stability remain unverified.
- v1.4-era figures (10G direct 3.85/1.69 Gbps; 6GHz 320MHz site test ~715/720 Mbps median) were measured under specific conditions — see [CHANGES-v1.md](CHANGES-v1.md); they are not guarantees for every environment.
- Historical highlights: v1.5 fixed 5GHz 160MHz foreground-CAC startup; v1.4 fixed the LAN editor, home redirects, fan control and Dockerman Moby 29 display, Removes GlassTheme and its Chinese package, and preinstalled Full Cone NAT and PassWall2.

## Source release

This release ships binaries only. The corresponding source is planned for the next release; existing public source does not reproduce v1.9.

## Building

```sh
docker volume create xr1710g-istoreos-final
docker run --name xr1710g-istoreos-build-final \
  -v xr1710g-istoreos-final:/work \
  -v "$PWD":/builder:ro \
  ubuntu:22.04 bash /builder/scripts/build-local-docker.sh
```

Key entry points: `configs/openwrt.config` (pinned configuration), `feeds.d/openwrt` (pinned upstream feeds), `diy-part2.d/openwrt.sh` (community integration), `patches/` (patch sets), `scripts/prebuild-xr1710g-release.sh` (source gate), `scripts/verify-xr1710g-build.sh` (image gate).

## Upstream and licenses

Built on board support from [YYH2913/openwrt](https://github.com/YYH2913/openwrt), integrated the way public iStoreOS components are, and uses/attributes YYH2913/http-uboot, naoki66/ImmortalWrt-for-Gemtek-XR1710G, OpenWrt, mt76, hostapd, iStore/iStoreX, QuickStart, OpenClash, PassWall2, Argon, Nikki, sirpdboy/EqosPlus and Airoha/MediaTek upstream content. Pinned commits and licenses: [ATTRIBUTION.md](ATTRIBUTION.md). Third-party components keep their original licenses; no upstream endorses this firmware.

## Community and support

| Community QQ group **1061612207** | Voluntary support |
|---|---|
| <img src="https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/wiro-qq-group.jpg" width="240" alt="QQ group QR code"> | <img src="https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/support-qr.png" width="240" alt="Support QR code"> |
