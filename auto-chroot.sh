#!/usr/bin/env sh

# Auto Arch Linux chroot environment
# POSIX compliant, no bashisms
# by: William C. Canin <https://williamcanin.github.io>

VERSION="0.1.0"
MNT="/mnt"
PROBE="/mnt/.probe"

mkdir -p "$PROBE"

cleanup() {
    umount "$PROBE" 2>/dev/null
}

trap cleanup EXIT

echo "[ auto-chroot - v$VERSION ]"
echo "Scanning block devices..."

# ----------------------------
# Step 1: Unlock LUKS devices
# ----------------------------

lsblk -rpno NAME,TYPE | while read -r dev type; do
    if [ "$type" != "part" ]; then
        continue
    fi

    if cryptsetup isLuks "$dev" 2>/dev/null; then
        name="crypt_$(basename "$dev")"

        if [ ! -e "/dev/mapper/$name" ]; then
            echo "LUKS detected: $dev"
            cryptsetup open "$dev" "$name"
        fi
    fi
done

# ----------------------------
# Step 2: Detect ROOT partitions
# ----------------------------

ROOTS=""

for dev in $(lsblk -rpno NAME,TYPE | awk '$2=="part"{print $1}'); do

    # skip LUKS raw devices (only mapped matter later)
    case "$dev" in
        /dev/mapper/*) continue ;;
    esac

    mount "$dev" "$PROBE" 2>/dev/null || continue

    if [ -f "$PROBE/etc/os-release" ]; then
        ROOTS="$ROOTS $dev"
    fi

    umount "$PROBE" 2>/dev/null
done

# normalize list
set -- "$ROOTS"

if [ $# -eq 0 ]; then
    echo "No valid Linux root partition found."
    exit 1
fi

# ----------------------------
# Step 3: Handle multiple roots
# ----------------------------

if [ $# -gt 1 ]; then
    echo "Multiple root partitions detected:"

    i=1
    for r in "$@"; do
        echo "[$i] $r"
        i=$((i + 1))
    done

    printf "Select root [1-%s]: " "$#"
    read -r choice

    i=1
    for r in "$@"; do
        if [ "$i" -eq "$choice" ]; then
            ROOT="$r"
            break
        fi
        i=$((i + 1))
    done
else
    ROOT="$1"
fi

echo "Root selected: $ROOT"

# ----------------------------
# Step 4: Mount ROOT safely
# ----------------------------

if ! mountpoint -q "$MNT"; then
    mount "$ROOT" "$MNT"
fi

# ----------------------------
# Step 5: Detect EFI / BOOT
# ----------------------------

EFI=""

for dev in $(lsblk -rpno NAME,FSTYPE | awk '$2=="vfat"{print $1}'); do

    mount "$dev" "$PROBE" 2>/dev/null || continue

    if [ -d "$PROBE/EFI" ] || [ -d "$PROBE/boot/efi" ]; then
        EFI="$dev"
    fi

    umount "$PROBE" 2>/dev/null

    [ -n "$EFI" ] && break
done

# ----------------------------
# Step 6: Mount EFI
# ----------------------------

if [ -n "$EFI" ]; then
    echo "Mounting EFI: $EFI"
    mkdir -p "$MNT/boot"

    if ! mountpoint -q "$MNT/boot"; then
        mount "$EFI" "$MNT/boot"
    fi
fi

# ----------------------------
# Step 7: Detect separate /home
# ----------------------------

HOME_DEV=""

for dev in $(lsblk -rpno NAME,FSTYPE | awk '$2!="vfat" && $2!="crypto_LUKS"{print $1}'); do

    mount "$dev" "$PROBE" 2>/dev/null || continue

    if [ -d "$PROBE/home" ] && [ -f "$PROBE/etc/os-release" ]; then
        if [ "$dev" != "$ROOT" ]; then
            HOME_DEV="$dev"
        fi
    fi

    umount "$PROBE" 2>/dev/null

    [ -n "$HOME_DEV" ] && break
done

if [ -n "$HOME_DEV" ]; then
    echo "Mounting separate /home: $HOME_DEV"
    mkdir -p "$MNT/home"

    if ! mountpoint -q "$MNT/home"; then
        mount "$HOME_DEV" "$MNT/home"
    fi
fi

# ----------------------------
# Step 8: System mounts
# ----------------------------

echo "Mounting system filesystems..."

mount -t proc proc "$MNT/proc"
mount --rbind /dev "$MNT/dev"
mount --rbind /sys "$MNT/sys"
mount --rbind /run "$MNT/run"

# ----------------------------
# Step 9: Enter chroot
# ----------------------------

echo "Entering chroot environment..."

arch-chroot "$MNT"
