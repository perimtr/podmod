#!/bin/bash
# Install the theme into the simulator, run an input script headlessly, and
# write a contact sheet:  simshot.sh <input-script> <out.png> [columns]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SIM=$ROOT/src/rockbox/build-sim
cp -R "$ROOT/theme/podmod/.rockbox/" "$SIM/simdisk/.rockbox/"
grep -hv '^#' "$ROOT/theme/podmod/.rockbox/Recommended Settings.cfg" "$ROOT/theme/podmod/.rockbox/themes/iPod Clean.cfg" | sed 's|langs/podmod.lng|langs/podmod-sim.lng|' > "$SIM/simdisk/.rockbox/config.cfg"
cp "$ROOT/lang/sim/podmod.lng" "$SIM/simdisk/.rockbox/langs/podmod-sim.lng"
rm -f "$SIM"/simdisk/dump*.bmp
cd "$SIM"
PODMOD_SCRIPT=$1 SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy ./rockboxui >sim.log 2>&1 &
P=$!
for _ in $(seq 1 90); do kill -0 $P 2>/dev/null || break; sleep 1; done
kill -9 $P 2>/dev/null && echo "simulator killed after timeout" || true
grep -iE 'skin|pars|error|fail' sim.log | head -10 || true
python3 "$ROOT/theme/tools/sheet.py" "$2" 3 "${3:-3}" simdisk/dump*.bmp
