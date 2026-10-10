# Firmware Changelog

Differences, release milestones, and architecture changes across this workspace.

---

## 1.0.0 — RosetteOS Stock USB Installer (2026-09-24)

### New Features & Architecture Transformation
* **Transformed Repo into RosetteOS Installer**: Repurposed workspace from a stock pre-root patcher into a full-featured stock-compatible installer generator for **RosetteOS** (Linux 6.6-rt + Klipper/Moonraker/GuppyScreen).
* **Zero-Disassembly / Single-USB Install**: Users can install RosetteOS directly from an unmodified stock printer or Nebula Pad via the touchscreen UI without needing Ingenic mask-ROM recovery mode, cloner tools, or prior root access.
* **Dual Target Hardware Profiles**:
  * **Ender-3 V3 KE** (Board target `F005`)
  * **Creality Nebula Smart Kit / Nebula Pad** (Board target `NEBULA`)
* **Standalone Build Script (`build_rosetteos_image.sh`)**:
  * Automates preflight checks, asset selection, packaging, and validation.
  * Supports `--target {ke,nebula,all}`, `--version`, `--artifacts`, and `--output`.
* **Direct RosetteOS Packager (`tools/pack_rosetteos.py`)**:
  * Directly encapsulates production RosetteOS `xImage` and `rootfs.squashfs` without requiring SquashFS re-compression.
  * Validates hardware partition budgets: Kernel $\le$ 8 MiB (5.54 MiB used), Rootfs $\le$ 500 MiB (330.85 MiB used).
  * Validates SHA256 checksums against `build-manifest.txt`.
  * Generates 1 MiB payload chunks, MD5 hash sidecars, and Creality manifests.
  * Implements pure-Python Unix MD5-crypt password derivation for any Creality board.
  * Automatically verifies created 7z archives upon completion.
* **Cached RTOS Binaries**:
  * Extracted and cached `assets/zero.bin` (KE, 432 KB) and `assets/zero_nebula.bin` (Nebula, 424 KB), making builds completely standalone without needing the 118 MB stock firmware images.

### Forensics, Bug Fixes & Live Qualification
* **Resolved OTA Extraction Failure on Stock Updater**:
  * *Root Cause*: Creality's `/etc/ota_bin/local_ota_update.sh` computes `OTA_UNZIP_FILE_NAME=${OTA_FILE_NAME%.img*}` and expects `ota_config.in` at `<TEMP_DIR>/<OTA_UNZIP_FILE_NAME>/ota_config.in`. When the archive file and internal folder names drifted, extraction aborted.
  * *Fix*: Ensured root directory inside the 7z archive strictly matches the `.img` filename without `.img`.
* **Resolved Version Comparison Rejection**:
  * *Root Cause*: Creality's `master-server` (`UpgradeManager.c`) parses versions after `ota_img_V` using regex `[0-9]{1,3}`. Raw integers like `11034` failed comparison against dotted stock versions.
  * *Fix*: Formatted all release versions with standard dotted numbers (e.g. `1.1.0.34`), ensuring `master-server` and `local_ota_update.sh` recognize the update as newer than stock (`1.1.0.30` / `1.1.0.17`).
* **Live Qualification**:
  * Successfully verified on real Creality Nebula Pad hardware via USB flash drive.

---

## 0.0.1 — Pre-Rooted Stock Firmware (Legacy)

* Baseline: `Ender-3_V3_KE_F005_ota_img_V1.1.0.17.img`
* Added `overlay_rootfs/etc/init.d/S05agree_root` to create `/usr/data/creality/userdata/user_agree_root` at boot.
* Enabled root access on stock CrealityOS.
* Provided `tools/ke_firmware.py` for SquashFS metadata-preserving rebuilds.
