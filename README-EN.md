# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware

[![Release](https://img.shields.io/github/v/release/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/total?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/latest)
[![Stars](https://img.shields.io/github/stars/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/stargazers)
[![Forks](https://img.shields.io/github/forks/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/forks)
[![Issues](https://img.shields.io/github/issues/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/issues)
[![Last Commit](https://img.shields.io/github/last-commit/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/commits/public-first-release)
[![GPL-2.0](https://img.shields.io/badge/license-GPL--2.0--or--later-blue?style=flat-square)](ATTRIBUTION.md)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%20line-0099FF?style=flat-square)](https://openwrt.org)
[![Kernel](https://img.shields.io/badge/kernel-6.18.41-green?style=flat-square)](CHANGES-v1.md)
[![Wi-Fi 7](https://img.shields.io/badge/Wi--Fi%207-MT7996%20tri--band-8A2BE2?style=flat-square)](https://en.wikipedia.org/wiki/Wi-Fi_7)
[![SoC](https://img.shields.io/badge/SoC-Airoha%20AN7581-333333?style=flat-square)](https://www.airoha.com/)
[![iStoreOS](https://img.shields.io/badge/iStoreOS-component%20integration-FF6600?style=flat-square)](https://github.com/YYH2913/openwrt)
[![Docker](https://img.shields.io/badge/Docker-preinstalled%2C%20off%20by%20default-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![QQ Group](https://img.shields.io/badge/QQ%20group-1061612207-orange?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0)

Unofficial community firmware for the **Gemtek XR1710G**: tri-band Wi-Fi 7, a dedicated 6GHz mesh backhaul, the iStore app shop and Docker — ready to flash.

**[Download v1.6.1](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v1.6.1)** · [What changed](#new-in-v161) · [Flashing guide](FLASHING-GUIDE.md) · [Mesh guide](MESH-GUIDE-ZH.md) · [中文](README.md)

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

1. **Download** — from the release page you only need the four files listed below; most users flash only the first.
2. **Flash** — already running compatible OpenWrt/iStoreOS: upload in the web UI; fresh/full install: upload the same file through compatible U-Boot. See [FLASHING-GUIDE.md](FLASHING-GUIDE.md).
3. **Log in** — connect by Ethernet, open `192.168.50.1`, use `root / password`.
4. **Finish** — change the admin password, set 2.4/5GHz Wi-Fi passwords; for a two-unit mesh see the one-page [mesh guide](MESH-GUIDE-ZH.md) (fill-in tables).

The UI starts in Simplified Chinese. Switch to English under **System → System → Language and Style → English → Save & Apply**.

## New in v1.6.1

- Bridge-node kernel-log flood fixed: an idle WAN port no longer prints `USXGMII AN down` every second; node logs survive (one line over twelve hours on hardware).
- Apple roaming compatibility: factory defaults and preserved-configuration upgrades now use `ft_over_ds='1'`; cross-AP roams no longer fall back to full authentication. Only that switch changes.
- LuCI wireless-config rollback window widened from 90 to 300 seconds so DFS-spanning widths are no longer silently rolled back to 80MHz.
- The MLO editor hides 802.11s mesh backhaul interfaces to prevent breaking the mesh by mistake.
- The IPv6 duplicate-client fix, detached upgrades, mt76 r7 and default credentials are unchanged. Details and validation boundaries: [Wi-Fi fix notes](FIX-WIFI-STABILITY-V1.6.1.md).
- Both units passed post-flash acceptance: migrations active, node logs preserved, mesh ESTAB, multi-vendor phones and laptops associating and roaming normally.

Full per-version history since v1.4: [CHANGES-v1.md](CHANGES-v1.md).

## Downloads: only four files matter

| File | Purpose |
|---|---|
| `xr1710g-community-v1.6.1-sysupgrade.itb` | **The only system image** — web upgrades and compatible U-Boot permanent installs |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | Optional U-Boot update, for the **Update U-Boot** page only; existing compatible U-Boot needs no re-flash |
| `SHA256SUMS.txt` | Checksums; not flashed |
| `FLASHING-GUIDE.md` | Bilingual flashing tutorial; not flashed |

No separate recovery.itb is needed; GitHub's auto-generated Source code archives are not flashable; never flash a system ITB into the U-Boot slot. If an old upgrade page times out without rebooting, do not resubmit — follow the guide.

## Factory defaults

Wireless defaults apply after the drivers finish loading on a clean first boot:

- 2.4GHz: US, automatic channel, HE20, 28 dBm requested; SSID `XR1710G`, initially open with no preset password.
- 5GHz: US, channel 36, EHT80, 29 dBm requested; SSID `XR1710G-5G`, initially open with no preset password, with 802.11k/v/r and stale-client protection enabled.
- 6GHz: US, PSC channel 37, EHT160, 28 dBm requested, WPA3-SAE 802.11s mesh template; It has no preset key and is disabled initially — set an identical mesh ID and key on both units, then enable.
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
| System | Linux 6.18.41, UBI 2.0 layout, default address 192.168.50.1, performance governor, single-controller fan policy |
| Wireless | Tri-band Wi-Fi 7 (MT7996 on the pinned mt76 baseline b2704cf5), 802.11s mesh, 802.11k/v/r, BBR enabled |
| Shop/plugins | iStore, iStoreX, QuickStart, Argon theme, OpenClash, PassWall2 (off by default; never enable both proxies together), Nikki, EqosPlus |
| Docker | Upstream OpenWrt Moby/containerd/runc/compose + Dockerman; preinstalled but off; all entry points share one config |
| Network | Airoha PPE hardware offload, Full Cone NAT (off by default; cannot bypass CGNAT or double NAT), 10G port protection fixes |
| Diagnostics | `xr1710g-role`, privacy-safe `xr1710g-mesh-diag`, cached status pages (no devmem in LuCI hot paths) |

## Validation boundaries (honesty)

- v1.6.1: both units passed post-flash acceptance (migrations active, node logs preserved, mesh ESTAB, normal association/roaming). Not a promise of long-term gaming, walking-roam or peak throughput.
- v1.4-era figures (10G direct 3.85/1.69 Gbps; 6GHz 320MHz site test ~715/720 Mbps median) were measured under specific conditions — see [CHANGES-v1.md](CHANGES-v1.md); they are not guarantees for every environment.
- Historical highlights: v1.5 fixed 5GHz 160MHz foreground-CAC startup; v1.4 fixed the LAN editor, home redirects, fan control and Dockerman Moby 29 display, Removes GlassTheme and its Chinese package, and preinstalled Full Cone NAT and PassWall2.

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

Community QQ group: **1061612207**
