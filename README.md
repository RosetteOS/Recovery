# RosetteOS Recovery & Firmware Packaging Workspace

This repository provides official recovery and installation packages for **RosetteOS** (Linux 6.6-rt + Klipper/Moonraker/GuppyScreen) on Ingenic X2000 Creality display boards.

It supports two distinct deployment channels:

1. **[Stock CrealityOS USB OTA Update (`.img`)](#1-stock-crealityos-usb-ota-update-img)** *(Recommended)*:
   Zero-disassembly, single-USB installation directly from the stock touchscreen interface. Installs RosetteOS to Slot 2 while preserving stock CrealityOS in Slot 1.
2. **[Ingenic Cloner USB Flashing Package (`.ingenic`)](#2-ingenic-cloner-usb-flashing-package-ingenic)**:
   Low-level recovery archive for bare-metal flashing and unbricking via Ingenic USB Cloner tool in mask-ROM mode.

---

## Supported Hardware

| Hardware | Board Identifier | Stock USB OTA Image | Ingenic Cloner Package |
| :--- | :--- | :--- | :--- |
| **Creality Ender-3 V3 KE** | `F005` | `Ender-3_V3_KE_F005_ota_img_V1.1.0.34.img` | `Ender-3_V3_KE_1.1.0.12-<tag>.ingenic` |
| **Creality Nebula Pad** | `NEBULA` | `NEBULA_ota_img_V1.1.0.34.img` | Compatible via dual-slot kernel/rootfs |

---

## 1. Stock CrealityOS USB OTA Update (`.img`)

The USB OTA updater packages production RosetteOS kernel (`xImage`), root filesystem (`rootfs.squashfs`), and hardware-specific RTOS auxiliary firmware (`zero.bin`) into Creality's encrypted 7z container format.

### Building OTA Packages Locally

Requirements: Python 3.8+ and `7z` (p7zip-full).

```bash
# Build both Ender-3 V3 KE and Nebula Pad OTA images
./build_rosetteos_image.sh --target all

# Or build for a single target
./build_rosetteos_image.sh --target ke
./build_rosetteos_image.sh --target nebula
```

Custom artifacts and versions can be passed:
```bash
./build_rosetteos_image.sh --target all --artifacts /path/to/artifacts --version 1.1.0.35
```

### Flashing via Touchscreen

1. Format a USB flash drive as **FAT32** with an **MBR** partition table.
2. Copy the generated `.img` file to the **root** of the USB flash drive.
3. Insert the drive into the printer or Nebula Pad front USB port.
4. On the touchscreen: navigate to **Settings** $\rightarrow$ **Firmware Update** $\rightarrow$ **Local Update**.
5. Select the firmware file and confirm.
6. The updater will flash RosetteOS into Slot 2 (`kernel2`, `rootfs2`, `rtos2`), point the boot marker to `ota:kernel2`, and reboot.
7. On first boot, RosetteOS seeds `/usr/data/rosetteos/` and automatically starts Klipper, Moonraker, and GuppyScreen.

### Dual-Slot Safety & Stock Reversion

* **Non-Destructive**: Stock CrealityOS in Slot 1 (`mmcblk0p5`/`mmcblk0p7`) is never overwritten.
* **Data Isolation**: Persistent storage in `/usr/data/` is strictly namespaced under `/usr/data/rosetteos/`.
* **Instant Reversion**: To switch back to stock CrealityOS, toggle the boot marker from SSH:
  ```bash
  echo -n "ota:kernel" > /dev/mmcblk0p1 && sync && reboot
  ```

---

## 2. Ingenic Cloner USB Flashing Package (`.ingenic`)

The `scripts/rebuild_ingenic.py` utility injects RosetteOS payloads into Creality's official Ingenic cloner package template (`Ender-3_V3_KE_1.1.0.12.ingenic`).

### Modes of Operation

1. **Dual-Slot Mode (Default)**:
   Preserves stock Slot 1/A payloads and adds RosetteOS Slot 2/B entries:
   - `images/xImage`: Stock Slot 1 kernel.
   - `images/xImage2`: RosetteOS Slot 2 kernel.
   - `images/rootfs.squashfs`: Stock Slot 1 rootfs.
   - `images/rootfs2.squashfs`: RosetteOS Slot 2 rootfs.
   - `images/zero.bin`: Stock RTOS; `images/zero2.bin`: RTOS copy.
   - `images/ota`: Set to `ota:kernel2\n\n` to boot Slot 2.
   - Cloner profile updated to flash both slots.

   ```bash
   python3 scripts/rebuild_ingenic.py \
     Ender-3_V3_KE_1.1.0.12.ingenic \
     rebuilt.ingenic \
     --root2 rootfs.squashfs \
     --kernel2 xImage
   ```

2. **Slot 1 Replacement Mode**:
   Replaces Slot 1 directly without configuring dual-slot partitions:
   ```bash
   python3 scripts/rebuild_ingenic.py \
     Ender-3_V3_KE_1.1.0.12.ingenic \
     stock-slot1-replaced.ingenic \
     --root1 rootfs.squashfs \
     --kernel1 xImage
   ```

---

## 3. Automated GitHub Actions Workflow

The repository includes [`.github/workflows/build-recovery-and-ota.yml`](.github/workflows/build-recovery-and-ota.yml) (dispatched manually via **Actions** $\rightarrow$ **Build RosetteOS Recovery & OTA Packages**):

* **Inputs**:
  * `tag`: Specify an explicit RosetteOS release tag to fetch (e.g. `nightly`, `v1.0.0`), or leave blank to automatically select the newest published release.
  * `ota_version`: Specify the package version recognized by Creality's updater (defaults to `1.1.0.34`).
* **Execution**:
  1. Resolves and downloads `xImage` and `rootfs.squashfs` from [`RosetteOS/RosetteOS`](https://github.com/RosetteOS/RosetteOS).
  2. Rebuilds:
     - Ingenic Cloner package (Slot 1 replacement): `Ender-3_V3_KE_1.1.0.12-<tag>.ingenic`
     - Ender-3 V3 KE Stock OTA package: `Ender-3_V3_KE_F005_ota_img_V<ota_version>.img`
     - Creality Nebula Pad Stock OTA package: `NEBULA_ota_img_V<ota_version>.img`
  3. Uploads all three artifacts and publishes them to the GitHub release.

---

## 4. Technical Documentation

* **[Hardware Partition Layout & A/B Boot Model](docs/A_B_PARTITION_MODEL.md)**
* **[CrealityOS OTA Container & Encryption Specification](docs/CREALITY_OTA_SPECIFICATION.md)**
* **[USB Flashing Troubleshooting & Diagnostics](docs/TROUBLESHOOTING.md)**
* **[Firmware Notes & Hardware Baselines](FIRMWARE_NOTES.md)**
* **[Firmware Changelog](FIRMWARE_CHANGELOG.md)**

---

## 5. Git LFS Notice

Because template packages and stock firmware images exceed GitHub's 100 MB file limit, they are tracked with Git LFS (`*.ingenic`, `*.img`).

Ensure Git LFS is installed before working with repository assets:
```bash
git lfs install
git lfs pull
```
