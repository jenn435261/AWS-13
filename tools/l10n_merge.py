"""Merges new strings into an .arb file and removes obsolete ones.

usage: l10n_merge.py <arb> <strings.json> [--meta]
strings.json: {"key": "text", ...}. With --meta, '@key' entries are kept too.
"""
import json, sys
from collections import OrderedDict

arb_path, strings_path = sys.argv[1], sys.argv[2]
arb = json.load(open(arb_path), object_pairs_hook=OrderedDict)
new = json.load(open(strings_path), object_pairs_hook=OrderedDict)

obsolete = new.pop('__remove__', [])
for key in obsolete:
    arb.pop(key, None)
    arb.pop('@' + key, None)
for key, value in new.items():
    arb[key] = value
open(arb_path, 'w').write(json.dumps(arb, ensure_ascii=False, indent=2) + '\n')
print(arb_path, 'keys:', len([k for k in arb if not k.startswith('@')]))
