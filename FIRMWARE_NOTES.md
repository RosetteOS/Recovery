# Firmware Architecture & Packaging Notes

This document contains technical reference information on stock firmware layouts, encryption passwords, partition budgets, and packaging mechanics for the **Ender-3 V3 KE** and **Creality Nebula Pad**.

---

## 1. Stock Firmware Baselines

| Target | Official Baseline Image | Version | Board Name | Derived 7z Encryption Password |
| :--- | :--- | :--- | :--- | :--- |
| **Ender-3 V3 KE** | `assets/Ender-3_V3_KE_F005_ota_img_V1.1.0.17.img` | `V1.1.0.17` | `F005` | `$1$cxswfile$ZFd0RWFYkJQugbtKVGL9y0` |
| **Nebula Pad** | `assets/NEBULA_ota_img_V1.1.0.30.img` | `V1.1.0.30` | `NEBULA` | `$1$cxswfile$XG7ANbYX3bq2H2xmmwrka.` |

### Password Derivation Algorithm
```bash
openssl passwd -1 -salt cxswfile "${BOARD_NAME}C3_7e_bz"
```
Or in Python:
```python
derive_creality_password(board_name)  # implemented in tools/pack_rosetteos.py
```

---

## 2. Partition Capacities & Budget Qualification

Creality's X2000 partition table enforces hard upper bounds on flashable images:

| Sub-Payload | Target Partition | Hardware Limit | RosetteOS Payload Size | Headroom |
| :--- | :--- | :--- | :--- | :--- |
| **`xImage`** (Linux kernel) | `kernel` (`p5`) / `kernel2` (`p6`) | **8 MiB** (8,388,608 B) | **5.54 MiB** (5,541,952 B) | +2.71 MiB (66.1% used) |
| **`rootfs.squashfs`** | `rootfs` (`p7`) / `rootfs2` (`p8`) | **500 MiB** (524,288,000 B) | **330.85 MiB** (346,923,008 B) | +169.15 MiB (66.2% used) |
| **`zero.bin`** (RTOS) | `rtos` (`p3`) / `rtos2` (`p4`) | **4 MiB** (4,194,304 B) | **0.41–0.42 MiB** (~430 KiB) | +3.58 MiB (10.3% used) |

Both kernel and rootfs fit comfortably with substantial safety margins.

---

## 3. Tooling Overview

* **[`build_rosetteos_image.sh`](build_rosetteos_image.sh)**:
  Top-level script for building ready-to-flash RosetteOS `.img` files directly from build artifacts.
* **[`tools/pack_rosetteos.py`](tools/pack_rosetteos.py)**:
  Core Python packager. Validates partition budgets, verifies SHA256 against `build-manifest.txt`, slices payloads into 1 MiB chunks with MD5 sidecars, derives board passwords, and compresses encrypted 7z envelopes.
* **[`assets/zero.bin`](assets/zero.bin)**:
  Cached RTOS binary for the Ender-3 V3 KE (`F005`).
* **[`assets/zero_nebula.bin`](assets/zero_nebula.bin)**:
  Cached RTOS binary for the Nebula Smart Kit / Nebula Pad (`NEBULA`).
* **`tools/ke_firmware.py`** (historical):
  Legacy utility for extracting stock images, overlaying files onto stock rootfs, and repacking pre-rooted stock images.

---

## 4. Key Rules for Creality OTA Packages

From reverse-engineering `/etc/ota_bin/local_ota_update.sh`:

1. **Folder Name Parity**: The root directory inside the 7z archive **must match the `.img` filename** without the `.img` extension.
   - Example: `NEBULA_ota_img_V1.1.0.34.img` $\rightarrow$ folder inside 7z must be `NEBULA_ota_img_V1.1.0.34/`.
2. **Dotted Versioning**: The version must be formatted with dots (e.g. `1.1.0.34`), not a raw integer, so `master-server`'s `[0-9]{1,3}` parser can compare versions.
3. **Chunking**: Chunks are 1,048,576 bytes each. Chunk `0000` points to the whole-file MD5, and subsequent chunks chain the previous chunk's MD5.
