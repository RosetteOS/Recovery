# Hardware Partition Layout & Dual-Slot A/B Boot Model

This document details the eMMC physical partition layout, the hardware A/B slot mechanics, and the persistent storage architecture used by Creality X2000 devices (Ender-3 V3 KE and Nebula Pad).

---

## 1. Physical Partition Table

The onboard eMMC is partitioned with a standard GPT partition table:

| Partition | Label | Fixed Capacity | Mount / Role | Active Slot 1 (Stock) | Active Slot 2 (RosetteOS) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/dev/mmcblk0p1` | `ota` | **1 MiB** | Boot marker storage | Stores `ota:kernel` or `ota:kernel2` | Shared |
| `/dev/mmcblk0p2` | `sn_mac` | **1 MiB** | Factory serial & MAC addresses | Read-only identity | Shared |
| `/dev/mmcblk0p3` | `rtos` | **4 MiB** | Aux RTOS firmware (Slot 1) | Active | Inactive |
| `/dev/mmcblk0p4` | `rtos2` | **4 MiB** | Aux RTOS firmware (Slot 2) | Inactive | Active |
| `/dev/mmcblk0p5` | `kernel` | **8 MiB** | Linux uImage (Slot 1) | Active | Inactive |
| `/dev/mmcblk0p6` | `kernel2` | **8 MiB** | Linux uImage (Slot 2) | Inactive | Active |
| `/dev/mmcblk0p7` | `rootfs` | **500 MiB** | SquashFS rootfs (Slot 1) | Active | Inactive |
| `/dev/mmcblk0p8` | `rootfs2` | **500 MiB** | SquashFS rootfs (Slot 2) | Inactive | Active |
| `/dev/mmcblk0p9` | `rootfs_data` | **300 MiB** | Ext4 writable overlay | `/overlay` | `/overlay` |
| `/dev/mmcblk0p10` | `userdata` | **~6.1 GiB** | Ext4 persistent storage | Mounted at `/usr/data` | Mounted at `/usr/data` |

---

## 2. Boot Selection via the OTA Marker

The bootloader (U-Boot) reads the 1 MiB `ota` partition (`/dev/mmcblk0p1`) on power-up to decide which kernel and rootfs to mount. The partition contains a simple ASCII string:

* `ota:kernel` $\rightarrow$ Boots **Slot 1** (Stock CrealityOS: kernel `p5`, rootfs `p7`).
* `ota:kernel2` $\rightarrow$ Boots **Slot 2** (Custom / RosetteOS: kernel `p6`, rootfs `p8`).

### How Stock OTA Updater Flashes to Slot 2

When you run a USB update from the stock Creality touchscreen:
1. Stock firmware queries which slot is currently running (`local_get_kernel_dev_path`).
2. Since the printer is running on Slot 1 (`ota:kernel`), the updater targets the **inactive** slot:
   - Flashes `xImage` to `kernel2` (`mmcblk0p6`).
   - Flashes `rootfs.squashfs` to `rootfs2` (`mmcblk0p8`).
   - Flashes `zero.bin` to `rtos2` (`mmcblk0p4`).
3. Calls `local_set_next_boot_device`, which writes `ota:kernel2` into `mmcblk0p1`.
4. Reboots into RosetteOS.

> [!NOTE]
> Stock firmware in Slot 1 (`mmcblk0p5` and `mmcblk0p7`) is **never overwritten** by this process.

---

## 3. Persistent Data Isolation (`/usr/data`)

`/dev/mmcblk0p10` is the single shared ~6.1 GiB persistent partition mounted at `/usr/data`. Both Slot 1 and Slot 2 share this partition, but they use strict directory separation:

```
/usr/data/
├── creality/            # Stock CrealityOS files (gcode, logs, userdata, factory data)
│   ├── userdata/
│   └── printer_data/
└── rosetteos/              # RosetteOS isolated runtime
    ├── apps/            # Mutable checkouts (klipper, moonraker, mainsail)
    ├── envs/            # Python virtual environments
    ├── system/          # Boot logs, activation state, machine configs
    └── printer_data/    # Klipper config (printer.cfg), macros, Moonraker DB
```

Because RosetteOS namespaces its data under `/usr/data/rosetteos/`, flashing it does not erase or corrupt stock print history, WiFi credentials, or factory calibration files.

---

## 4. Reverting to Stock Firmware

If you ever wish to return to stock CrealityOS, you do not need to reflash. You simply toggle the boot marker back to Slot 1:

### From a RosetteOS shell (SSH)
```bash
echo -n "ota:kernel" > /dev/mmcblk0p1
sync
reboot
```

### From Stock CrealityOS (if toggling forward again)
```bash
. /etc/ota_bin/ota_utils.sh
. /etc/ota_bin/ota_local_method.sh
local_set_next_boot_device
reboot
```
