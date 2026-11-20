#!/usr/bin/env python3
"""Make podmod.lang: English with a few friendlier menu names.
usage: mklang.py english.lang out.lang"""
import re, sys
RENAME = {
    'LANG_ROCKBOX_TITLE': 'iPod',
    'LANG_TAGCACHE': 'Music',
    'LANG_RESUME_PLAYBACK': 'Resume',
    'LANG_TAGNAVI_ALL_TRACKS': 'All Songs',
    'LANG_TAGNAVI_RANDOM': 'Shuffle',
    'LANG_ROCKBOX_INFO': 'About',
    'LANG_SOUND_SETTINGS': 'Sound',
    'LANG_KEYCLICK': 'Clicker',
    'LANG_KEYCLICK_SOFTWARE': 'Clicker',
    'LANG_SLEEP_TIMER_START_CURRENT': 'Sleep Timer',
}
src = open(sys.argv[1], encoding='utf-8').read()
done = set()
def fix(m):
    block = m.group(0)
    pid = re.search(r'^\s*id:\s*(\S+)', block, re.M).group(1)
    if pid not in RENAME:
        return block
    done.add(pid)
    def dest(d):
        # every variant with real text (targets can have their own wording); leave "none" alone
        return re.sub(r'(^\s*[\w*,-]+:\s*)"[^"]+"', lambda x: x.group(1) + '"%s"' % RENAME[pid], d.group(0), flags=re.M)
    block = re.sub(r'^\s*<dest>.*?</dest>', dest, block, flags=re.S | re.M)
    block = re.sub(r'^\s*<voice>.*?</voice>', dest, block, flags=re.S | re.M)
    return block
out = re.sub(r'^<phrase>.*?^</phrase>', fix, src, flags=re.S | re.M)
missing = set(RENAME) - done
if missing: print('not in this version:', sorted(missing))
open(sys.argv[2], 'w', encoding='utf-8').write(out)
