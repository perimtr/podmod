#!/bin/bash
# Convert this iPod mini 2G (6 GB, Mac-formatted) to FAT32 and install Rockbox.
#
#   sudo ./install-rockbox.sh
#
# ERASES the iPod's data partition. Safe to re-run: it detects whether the
# partition table has already been converted and resumes from there.
#
# Needs (checked before anything is written):
#   tools/ipodpatcher                         built from Rockbox source
#   downloads/bootloader-ipodmini2g.ipod
#   downloads/rockbox-ipodmini2g-4.0.zip
#   downloads/rockbox-fonts-4.0.zip

set -euo pipefail
cd "$(dirname "$0")"

# Geometry read from this exact iPod (512-byte sectors). The script refuses to
# touch any disk that does not match.
TOTAL=12000556
FW_START=63
FW_SIZE=65536
DATA_START=65600
DATA_SIZE=11934944

PATCHER=tools/ipodpatcher
BOOTLOADER=downloads/bootloader-ipodmini2g.ipod
RB_ZIP=downloads/rockbox-ipodmini2g-4.0.zip
FONTS_ZIP=downloads/rockbox-fonts-4.0.zip
HEAD_IMG=backup/ipod-head-${DATA_START}-sectors.img
VOLNAME=IPOD

die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo; echo "==> $*"; }

[ "$(id -u)" = 0 ] || die "run with sudo"
for f in "$PATCHER" "$BOOTLOADER" "$RB_ZIP" "$FONTS_ZIP"; do
  [ -s "$f" ] || die "missing $f"
done
[ -x "$PATCHER" ] || die "$PATCHER is not executable"

field() { diskutil info "$1" | sed -n "s|^ *$2: *||p"; }
sectors() { diskutil info "$1" | sed -n 's/^ *Disk Size:.*exactly \([0-9]*\) 512-Byte-Units.*/\1/p'; }
offset() { diskutil info "$1" | sed -n 's/^ *Partition Offset:.*(\([0-9]*\) 512-Byte-Device-Blocks)/\1/p'; }

# --- find the iPod -----------------------------------------------------------
say "Looking for the iPod"
found=()
for d in $(diskutil list external physical | awk '/^\/dev\/disk/{print $1}'); do
  [ "$(field "$d" 'Device / Media Name')" = "iPod" ] && found+=("${d#/dev/}")
done
[ "${#found[@]}" = 1 ] || die "expected exactly one iPod disk, found ${#found[@]}. If it was ejected, unplug and replug it, then re-run."
D=${found[0]}
[ "$(field "$D" Protocol)" = "USB" ] || die "$D is not a USB device"
[ "$(sectors "$D")" = "$TOTAL" ] || die "$D has $(sectors "$D") sectors, expected $TOTAL: not the iPod this script was written for"
SCHEME=$(field "$D" 'Content (IOContent)')
diskutil list "$D"

case "$SCHEME" in
  Apple_partition_scheme)
    [ "$(offset "${D}s2")" = "$FW_START" ] && [ "$(sectors "${D}s2")" = "$FW_SIZE" ] || die "firmware partition is not where expected"
    [ "$(offset "${D}s3")" = "$DATA_START" ] && [ "$(sectors "${D}s3")" = "$DATA_SIZE" ] || die "data partition is not where expected"
    STATE=macpod ;;
  FDisk_partition_scheme)
    [ -s "$HEAD_IMG" ] || die "disk is already converted but $HEAD_IMG is missing"
    STATE=winpod ;;
  *) die "unexpected partition scheme: $SCHEME" ;;
esac

echo
echo "This will ERASE everything on /dev/$D (iPod mini, 6 GB) and install Rockbox."
read -r -p "Type ERASE to continue: " answer
[ "$answer" = "ERASE" ] || die "cancelled"

pkill -f '/bin/sleep 1800' 2>/dev/null || true   # release the keep-mounted helper
diskutil unmountDisk force "/dev/$D"

# --- convert the partition table --------------------------------------------
if [ "$STATE" = macpod ]; then
  say "Backing up partition map + Apple firmware (first $DATA_START sectors)"
  mkdir -p backup
  dd if="/dev/r$D" of="$HEAD_IMG" bs=512 count="$DATA_START"
  [ "$(stat -f %z "$HEAD_IMG")" = $((DATA_START * 512)) ] || die "backup is the wrong size"
  [ -n "${SUDO_USER:-}" ] && chown "$SUDO_USER" "$HEAD_IMG"

  say "Writing MBR partition table (firmware stays where it is)"
  MBR=$(mktemp)
  /usr/bin/python3 - "$MBR" "$FW_START" "$FW_SIZE" "$DATA_START" "$DATA_SIZE" <<'PY'
import struct, sys
out, fs, fz, ds, dz = sys.argv[1], *map(int, sys.argv[2:])
entry = lambda typ, start, size: struct.pack('<B3sB3sII', 0, b'\0\0\0', typ, b'\0\0\0', start, size)
mbr = bytes(446) + entry(0x00, fs, fz) + entry(0x0b, ds, dz) + bytes(32) + b'\x55\xaa'
assert len(mbr) == 512
open(out, 'wb').write(mbr)
PY
  dd if="$MBR" of="/dev/r$D" bs=512 count=1
  rm -f "$MBR"
  sync

  say "Waiting for macOS to re-read the partition table"
  for _ in $(seq 1 20); do
    [ "$(field "$D" 'Content (IOContent)')" = "FDisk_partition_scheme" ] && break
    sleep 1
  done
  if [ "$(field "$D" 'Content (IOContent)')" != "FDisk_partition_scheme" ]; then
    echo "macOS has not picked up the new table. Unplug the iPod, plug it back in"
    echo "(choose Ignore if macOS says the disk is unreadable), then re-run this script."
    exit 2
  fi
  diskutil unmountDisk force "/dev/$D" || true
fi

# --- sanity check before formatting -----------------------------------------
say "Checking that the Apple firmware is readable through the new table"
if ! "$PATCHER" "/dev/$D" -l; then
  echo "ipodpatcher could not read the firmware partition. Nothing has been formatted."
  echo "To undo the partition table change:"
  echo "  sudo dd if=$HEAD_IMG of=/dev/r$D bs=512 count=1"
  exit 3
fi

# --- format, bootloader, files ----------------------------------------------
say "Formatting the data partition as FAT32"
diskutil unmountDisk force "/dev/$D" || true
newfs_msdos -F 32 -v "$VOLNAME" "/dev/r${D}s2"

say "Installing the Rockbox bootloader"
diskutil unmountDisk force "/dev/$D" || true
"$PATCHER" "/dev/$D" -a "$BOOTLOADER"

say "Copying Rockbox onto the iPod"
diskutil mount "/dev/${D}s2"
MNT=$(field "${D}s2" 'Mount Point')
[ -d "$MNT" ] || die "the FAT32 volume did not mount"
touch "$MNT/.metadata_never_index"
unzip -q -o "$RB_ZIP" -d "$MNT"
unzip -q -o "$FONTS_ZIP" -d "$MNT"
[ -f "$MNT/.rockbox/rockbox.ipod" ] || die "Rockbox files did not land in $MNT/.rockbox"
dot_clean -m "$MNT" 2>/dev/null || true
sync

say "Ejecting"
diskutil eject "/dev/$D"
echo
echo "Done. Unplug the iPod now; it should boot into Rockbox."
echo "Hold Menu while it starts to boot the original Apple firmware instead."
