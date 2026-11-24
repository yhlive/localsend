#!/usr/bin/env python3
"""Type the bundled four-file manifest into a focused Android emulator field."""

import argparse
from pathlib import Path
import re
import shlex
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--adb', default='adb')
parser.add_argument('--device', default='emulator-5554')
args = parser.parse_args()
if not re.fullmatch(r'emulator-[0-9]+', args.device):
    parser.error('Use an Android emulator ID from adb devices.')

manifest = Path(__file__).with_name('expected-delivery.txt').read_text().splitlines()
adb = [args.adb, '-s', args.device, 'shell']
for index, name in enumerate(manifest):
    if index:
        subprocess.run([*adb, 'input keyevent KEYCODE_ENTER'], check=True)
    subprocess.run([*adb, 'input text ' + shlex.quote(name.replace(' ', '%s'))], check=True)
print('Typed the sample manifest in the focused emulator field.')
