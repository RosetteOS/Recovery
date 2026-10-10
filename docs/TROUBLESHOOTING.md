# Troubleshooting & USB Flashing Diagnostics

This document covers common issues when flashing RosetteOS via USB OTA, root causes, and diagnostic steps.

---

## 1. "No firmware found" / "No local update available"

When you insert the USB drive and navigate to **Settings** $\rightarrow$ **Firmware Update** $\rightarrow$ **Local Update**, the screen reports no file found.

### Root Causes & Fixes:
1. **USB Drive File System**:
   * The Creality Linux kernel does not reliably mount exFAT or NTFS drives on early boot.
   * **Fix**: Format the USB flash drive as **FAT32** with an **MBR** (Master Boot Record) partition table. Avoid GPT partition tables on the flash drive.
2. **File Location**:
   * The `.img` file must be placed in the **root directory** of the USB drive (e.g. `E:\NEBULA_ota_img_V1.1.0.34.img`), not inside a folder.
3. **Filename Format**:
   * Creality's `master-server` scans for files matching `ota_img_V`.
   * Files must be named:
     - For Nebula Pad: `NEBULA_ota_img_V<version>.img`
     - For Ender-3 V3 KE: `Ender-3_V3_KE_F005_ota_img_V<version>.img`

---

## 2. "Update failed" Immediately After Confirming

The screen detects the update, you click "Update Now", the progress bar appears for a split second, and it immediately reports "Update Failed".

### Root Cause:
* Creality's updater extracts the 7z archive to a temporary directory and looks for `ota_config.in` in `<TEMP_DIR>/<UNZIP_FOLDER>/ota_config.in`.
* If the root directory inside the 7z archive does not match the `.img` filename (without `.img`), `cp -f $ota_site_config` fails.
* **Resolution**: The updated `build_rosetteos_image.sh` / `tools/pack_rosetteos.py` guarantees this alignment automatically. Ensure you use images built with the latest packager.

---

## 3. "Current version is newest" / Won't Allow Flashing

The UI says the firmware is already up-to-date or newer.

### Root Cause:
* In `local_ota_update.sh`:
  ```bash
  if [ $current_version -ge $ota_current_version ]; then
      echo "ota not update: current version is newest"
      exit 2
  fi
  ```
* If your device is running `1.1.0.30` and the package version is `1.1.0.30` or lower, it refuses to flash.
* **Fix**: Pass a higher version number when running the build script:
  ```bash
  ./build_rosetteos_image.sh --target nebula --version 1.1.0.35
  ```

---

## 4. How to Inspect Live Update Logs on the Printer

If you have SSH access to stock firmware and want to see what `local_ota_update.sh` is doing during a flash:

1. Connect to the printer via SSH:
   ```bash
   ssh root@<printer-ip>
   ```
2. Trigger the local update manually from the command line to see stdout/stderr in real time:
   ```bash
   sh -x /etc/ota_bin/local_ota_update.sh /media/sda1/NEBULA_ota_img_V1.1.0.34.img
   ```
3. Check temporary updater logs:
   ```bash
   ls -la /usr/data/creality/ota_updater*
   ```
