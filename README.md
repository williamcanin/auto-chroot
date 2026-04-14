# smart-chroot (Arch Linux Rescue Tool)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-green.svg)](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sh.html)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-supported-blue)](https://archlinux.org)

A POSIX-compliant interactive Arch Linux chroot rescue tool that mounts partitions and enters an installed Linux system with or without user interaction, depending on whether a configuration file is provided.

It is designed for use in Arch Linux live environments (archiso), system recovery, and rescue workflows.

---

## CI Status

[![Auto-chroot real environment tests](https://github.com/williamcanin/smart-chroot/actions/workflows/ci.yml/badge.svg)](https://github.com/williamcanin/smart-chroot/actions/workflows/ci.yml) [![Auto Release (smart-chroot)](https://github.com/williamcanin/smart-chroot/actions/workflows/release.yml/badge.svg)](https://github.com/williamcanin/smart-chroot/actions/workflows/release.yml)

---

## Features

- Two operation modes: **config file** (fully automated) or **interactive** (step-by-step prompts)
- Remote `.conf` config file support via URL (downloaded with `curl`)
- LUKS encrypted volume unlocking (interactive password prompt only when needed)
- Mounts `root`, `home`, and `boot` partitions
- INI-style config parser using only `awk` — no Python, no `jq`, no extra dependencies
- Fully POSIX-compliant (`#!/usr/bin/env sh`)
- Works with NVMe, SATA, USB, and LUKS setups

---

## Requirements

The following tools must be available in the live environment:

- `sh`
- `mount`
- `cryptsetup` (for LUKS support)
- `arch-chroot` (from `arch-install-scripts`)
- `curl` (for remote config file download)
- `awk` (for INI config parsing)

All of these are already available in the official Arch Linux ISO.

---

## Usage (Arch Linux Live ISO)

Boot into an Arch Linux live environment and run:

```sh
sh <(curl -fsSL https://williamcanin.github.io/smart-chroot/latest)
```

Alternatively:

```sh
curl -fsSL https://raw.githubusercontent.com/williamcanin/smart-chroot/main/smart-chroot.sh -o smart-chroot.sh
chmod +x smart-chroot.sh
sudo sh smart-chroot.sh
```

> **Note:** The script must be run as root.

---

## Operation Modes

### Mode 1 — Config file (automated)

When prompted, answer `y` and provide the URL of your `.conf` file:

```
Do you have a configuration file (.conf)? [y/n]: y
Enter the URL of your configuration file:
> https://my-site.com/config.conf
```

The script downloads and validates the file, then mounts all partitions automatically. The only interaction required is typing the LUKS password, if any partition is encrypted.

### Mode 2 — Interactive

When prompted, answer `n` to go through the step-by-step flow:

```
Do you have a configuration file (.conf)? [y/n]: n
```

The script will ask for each partition device individually:

```
=== ROOT Partition ===
Enter the root partition (e.g. /dev/sda2):
> /dev/sda2
Is the root partition LUKS-encrypted? [y/n]: y
Enter a name for the encrypted partition (e.g. linux-root):
> linux-root

=== HOME Partition ===
Enter the home partition (e.g. /dev/sdb1):
> /dev/sdb1
Is the home partition LUKS-encrypted? [y/n]: n

=== BOOT Partition ===
Enter the boot partition (e.g. /dev/sda1):
> /dev/sda1
```

---

## Configuration File Format

The config file uses a simple INI format with three sections: `[system]`, `[home]`, and `[boot]`.

```ini
[system]
mount=/dev/mapper/linux-arch
luks=false
luks_name=
luks_device=

[home]
mount=/dev/mapper/home
luks=true
luks_name=home
luks_device=/dev/sdc1

[boot]
mount=/dev/sda1
```

### Fields

| Section    | Key          | Description                                              |
|------------|--------------|----------------------------------------------------------|
| `[system]` | `mount`      | Device to mount as root (use `/dev/mapper/<n>` if LUKS) |
| `[system]` | `luks`       | `true` if the root partition is LUKS-encrypted           |
| `[system]` | `luks_name`  | Name for the LUKS mapper (e.g. `linux-root`)             |
| `[system]` | `luks_device`| Physical block device to unlock (e.g. `/dev/sda2`)       |
| `[home]`   | `mount`      | Device to mount as `/mnt/home`                           |
| `[home]`   | `luks`       | `true` if the home partition is LUKS-encrypted           |
| `[home]`   | `luks_name`  | Name for the LUKS mapper (e.g. `home`)                   |
| `[home]`   | `luks_device`| Physical block device to unlock (e.g. `/dev/sdc1`)       |
| `[boot]`   | `mount`      | Device to mount as `/mnt/boot` (e.g. `/dev/sda1`)        |

> Lines starting with `#` are treated as comments and ignored. Inline comments are also supported.

---

## Boot Flow

```
[ Script starts ]
        |
        v
[ Has config file? ] ---> yes ---> download & validate .conf
        |                                     |
        no                                    v
        |                        [ Read [system], [home], [boot] ]
        v                                     |
[ Interactive prompts ]                       |
        |                                     |
        +------------------+------------------+
                           |
                           v
               [ LUKS partition? ] ---> yes ---> cryptsetup open <device> <name>
                           |                     (password prompt)
                           no
                           |
                           v
               [ mount root -> /mnt ]
               [ mount home -> /mnt/home ]
               [ mount boot -> /mnt/boot ]
                           |
                           v
               [ arch-chroot /mnt ]
```

---

## Safety

This tool does NOT:

- Format disks
- Modify partitions
- Delete data

It only mounts existing filesystems and enters a chroot environment. However, it operates on block devices as root, so use with caution.

---

## Limitations

- Multiple Linux installations on the same machine may require manual device identification
- Advanced Btrfs subvolume layouts are not supported
- LVM setups are not handled
- No EFI auto-detection; boot partition must be specified manually

---

## Development

See `CONTRIBUTING.md` for development guidelines and environment setup.

---

## License

MIT License © William Canin

See `LICENSE` file for details.

---

## Donation

If you liked this project and enjoyed it, buy me a coffee; it motivates me to continue providing support.

<div class="donation">
  <a href="https://williamcanin.github.io/donate/" target="_blank">
    <img width="160" height="100" src="assets/images/icons/donation.svg" alt="Donate"/>
  </a>
</div>
