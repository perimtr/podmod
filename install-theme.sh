#!/bin/bash
# Copy the podmod theme, font, language and settings files onto the iPod.
#   ./install-theme.sh        (iPod must be plugged in and mounted as IPOD)
set -euo pipefail
cd "$(dirname "$0")"
M=/Volumes/IPOD
[ -d "$M/.rockbox" ] || { echo "iPod not mounted at $M"; exit 1; }
cp -R theme/podmod/.rockbox/ "$M/.rockbox/"
# files from earlier versions of this setup
rm -f /Volumes/IPOD/podmod.cfg /Volumes/IPOD/.rockbox/themes/podmod.cfg
dot_clean -m "$M" 2>/dev/null || true
sync
diff -r theme/podmod/.rockbox/wps/podmod "$M/.rockbox/wps/podmod"
for f in "themes/iPod Clean.cfg" "Recommended Settings.cfg" fonts/15-Podmod-Helvetica-Bold.fnt langs/podmod.lng tagnavi_user.config wps/podmod.wps wps/podmod.sbs; do
  cmp "theme/podmod/.rockbox/$f" "$M/.rockbox/$f"
done
echo "Installed and verified."
