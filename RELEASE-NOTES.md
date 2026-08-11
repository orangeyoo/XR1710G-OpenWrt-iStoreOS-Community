# XR1710G Community Firmware v1.1.0 Release Notes

Community-built iStoreOS/OpenWrt firmware for Gemtek XR1710G (Airoha AN7581 + MediaTek MT7996). This is not an official iStoreOS, OpenWrt, Gemtek, Airoha, or MediaTek release.

## Highlights

- Linux 6.18.38 and pinned XR1710G mt76/MT7996 adaptation `b2704cf5`.
- XR1710G UBI 2.0 layout and default LAN `192.168.50.1`.
- 6GHz WPA3-SAE 802.11s, EHT320 capability, supplementary AP-WDS support, and MLO disabled by default.
- Platform-wide LuCI/RPC reliability fix for Airoha NPU, FlowSense, and fan pages.
- Physical-carrier based Ethernet link reporting.
- Transaction-safe iStore preflight for install, upgrade, self-update, and APK operations.
- Upstream OpenWrt Docker stack preinstalled but disabled by default; iStore and Dockerman share `/overlay/docker/`.
- WAN physical-interface and dnsmasq role-activation fixes.
- Opt-in XZ composite laboratory profile with shared-PHY and no-AFC warnings.

## Hardware validation

Two XR1710G units approximately five metres apart across a wooden staircase and concrete floor were tested at XZ/channel 37/EHT320. A 20-run, roughly ten-minute bidirectional four-stream test produced medians near 715/720Mbps and minima near 678/671Mbps. Every run exceeded 400Mbps. Two post-load 600-packet idle Ping tests had 0% loss. Mesh remained ESTAB, temperatures stayed below 60°C, and no critical MT7996/MCU error or reboot occurred.

The iperf3 endpoints ran on the routers and are intended to validate backhaul stability, not claim the maximum throughput between two external 2.5GbE clients.

## Files and flashing

The Release intentionally contains only one system image. Follow `FLASHING-GUIDE.md`.

- A compatible running OpenWrt/iStoreOS system uses `xr1710g-community-v1.1.0-sysupgrade.itb` from its upgrade page.
- YYH2913 HTTP U-Boot uses the same image with **Firmware + UBI 2.0 - 439 MiB**.
- Update U-Boot only when a compatible version is missing, using the supplied validated YYH2913 flash-slot file from **Update U-Boot**.
- Do not flash a system ITB, raw `u-boot.bin`, standalone FIT, or an initramfs development image into the U-Boot slot.

## Regulatory warning

Standard country entries remain available and should be used by normal users. XZ is an opt-in composite laboratory profile, not a country domain. It combines AU-derived 2.4/5GHz rules with an experimental 6GHz 36dBm no-AFC rule. The firmware does not implement AFC and selecting XZ does not grant Standard Power authority. Use only in a controlled laboratory or where specifically authorized, and comply with all local rules. Hardware transmit power remains limited by the driver, firmware, and Factory calibration.

## First boot

Management address: `192.168.50.1`; user: `root`; initial password: empty. Connect by LAN, set a password immediately, and configure two freshly flashed units one at a time. The first UI is Simplified Chinese; switch at **System → System → Language and Style**.

See `README.md`, `CHANGES-v1.md`, `ATTRIBUTION.md`, and `FLASHING-GUIDE.md` for details.
