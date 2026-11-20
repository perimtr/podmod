#!/bin/bash
# Build the podmod firmware for the iPod mini 2G.
#
# Fetches Rockbox at the pinned commit (first run only), applies
# podmod-firmware.patch, embeds the startup logo, builds with the ARM toolchain
# from tools/build-toolchain.sh, and writes:
#   firmware/out/rockbox-full.zip              firmware + codecs + fonts
#   theme/podmod/.rockbox/langs/podmod.lng     menu names matching this build
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$ROOT/src/rockbox
COMMIT=3a299f5dea2b35846d0d4609d1259587ded4ca5b
export PATH="$ROOT/tools/arm/bin:$PATH"
command -v arm-elf-eabi-gcc >/dev/null || { echo "ARM toolchain missing: run tools/build-toolchain.sh first"; exit 1; }

if [ ! -d "$SRC" ]; then
  git clone https://github.com/Rockbox/rockbox.git "$SRC"
  git -C "$SRC" checkout "$COMMIT"
  git -C "$SRC" apply "$ROOT/firmware/podmod-firmware.patch"
fi

# Startup logo: PODMOD_LOGO if set, else your own trace if present, else the
# neutral placeholder.
TRACE=${PODMOD_LOGO:-$ROOT/firmware/boot-logo-trace.txt}
[ -f "$TRACE" ] || TRACE=$ROOT/firmware/logo-placeholder.txt
echo "startup logo: $TRACE"
python3 "$ROOT/firmware/mklogo.py" "$TRACE" "$SRC/apps/bitmaps/native/rockboxlogo.138x46x2.bmp"

B=$SRC/build-mini
mkdir -p "$B" "$ROOT/firmware/out"
cd "$B"
[ -f Makefile ] || ../tools/configure --target=ipodmini2g --type=N
make -j"$(sysctl -n hw.physicalcpu 2>/dev/null || nproc)" > make.log 2> make.err || { grep -E 'error|Error' make.err | head -20; exit 1; }
make fullzip >> make.log 2>> make.err
cp rockbox-full.zip rockbox-info.txt "$ROOT/firmware/out/"

# Language file with the friendlier menu names, matching this exact build.
L=$ROOT/lang/dev; mkdir -p "$L"
python3 "$ROOT/lang/mklang.py" "$SRC/apps/lang/english.lang" "$L/podmod.lang"
perl "$SRC/tools/updatelang" "$SRC/apps/lang/english.lang" "$L/podmod.lang" "$L/p.tmp" > /dev/null
perl "$SRC/tools/genlang" -e="$SRC/apps/lang/english.lang" \
  -t=ipodmini2g:"$(cat apps/genlang-features)" -i="$(sed -n 's/^Target id: //p' rockbox-info.txt)" \
  -b="$L/podmod.lng" "$L/p.tmp"
mkdir -p "$ROOT/theme/podmod/.rockbox/langs"
cp "$L/podmod.lng" "$ROOT/theme/podmod/.rockbox/langs/podmod.lng"
ls -l "$ROOT/firmware/out/rockbox-full.zip" "$ROOT/theme/podmod/.rockbox/langs/podmod.lng"
