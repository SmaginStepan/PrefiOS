#!/usr/bin/env python3
"""Regenerate Pref/Resources/Localizable.xcstrings from the Android app's
strings.xml files (the localization source of truth), plus keys not (yet)
present in the Android resources.

Usage: python3 tools/make_xcstrings.py [path-to-PrefAndroid]
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / "PrefAndroid"
RES = ANDROID / "app/src/main/res"
OUT = ROOT / "Pref/Resources/Localizable.xcstrings"

FILES = {
    "en": RES / "values/strings.xml",
    "ru": RES / "values-ru/strings.xml",
    "es": RES / "values-es/strings.xml",
}

# Keys not (yet) in the Android strings.xml (kept here so regeneration
# keeps them). about_f5 describes the CROSS-PLATFORM multiplayer — move it
# to the Android resources once its About screen lists it too, then drop it
# from this dict.
EXTRA = {
    "about_f5": {
        "en": "- Online multiplayer with friends (3 or 4 players)",
        "ru": "- Сетевая игра с друзьями (3 или 4 игрока)",
        "es": "- Juego en línea con amigos (3 o 4 jugadores)",
    },
}


def android_to_ios(s: str) -> str:
    s = s.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n")
    s = re.sub(r"%(\d+)\$s", r"%\1$@", s)
    s = re.sub(r"%(\d+)\$d", r"%\1$ld", s)
    s = re.sub(r"%s", "%@", s)
    s = re.sub(r"%d", "%ld", s)
    return s


def load(path: Path):
    tree = ET.parse(path)
    return {
        el.get("name"): android_to_ios("".join(el.itertext()))
        for el in tree.getroot().iter("string")
    }


langs = {lang: load(path) for lang, path in FILES.items()}
for key, values in EXTRA.items():
    for lang, value in values.items():
        langs[lang][key] = value

catalog = {"sourceLanguage": "en", "version": "1.0", "strings": {}}
for key in langs["en"]:
    entry = {"extractionState": "manual", "localizations": {}}
    for lang in ("en", "ru", "es"):
        if key in langs[lang]:
            entry["localizations"][lang] = {
                "stringUnit": {"state": "translated", "value": langs[lang][key]}
            }
    catalog["strings"][key] = entry

OUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")

missing_ru = [k for k in langs["en"] if k not in langs["ru"]]
missing_es = [k for k in langs["en"] if k not in langs["es"]]
print(f"keys: {len(langs['en'])}, missing ru: {missing_ru}, missing es: {missing_es}")
