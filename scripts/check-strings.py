#!/usr/bin/env python3
"""コードの String(localized: "…") と stages.json のヒントが、Localizable.xcstrings に英語つきで入っているかを確かめる。
使い方: python3 scripts/check-strings.py   （足りないものがあれば exit 1）"""
import glob, json, re, sys

cat = json.load(open("App/Resources/Localizable.xcstrings", encoding="utf-8"))["strings"]
JA = re.compile(r"[぀-ヿ一-鿿]")


def literal_keys(src):
    """String(localized: "…") のリテラルを、カタログのキーの形（差しこみは %@）にする"""
    for m in re.finditer(r'String\(localized: "', src):
        i, buf, depth = m.end(), "", 0
        while True:
            c = src[i]
            if c == "\\" and src[i + 1] == "(":
                j, d = i + 2, 1
                while d:
                    if src[j] == "(": d += 1
                    elif src[j] == ")": d -= 1
                    j += 1
                buf += "%@"; i = j; continue
            if c == "\\":
                buf += {"n": "\n", '"': '"', "'": "'", "\\": "\\"}[src[i + 1]]; i += 2; continue
            if c == '"': break
            buf += c; i += 1
        yield buf


missing = []
for f in sorted(glob.glob("App/Sources/**/*.swift", recursive=True)):
    src = open(f, encoding="utf-8").read()
    for key in literal_keys(src):
        if "%@" in key:
            key = key.replace("%", "%%").replace("%%@", "%@")
        unit = cat.get(key, {}).get("localizations", {}).get("en", {}).get("stringUnit", {})
        if not unit.get("value"):
            missing.append(f"{f}: {key!r}")
        elif JA.search(unit["value"]):
            missing.append(f"{f}: 英語に日本語が残っている {key!r}")
for s in json.load(open("App/Resources/stages.json", encoding="utf-8")):
    if s.get("hint") and not cat.get(s["hint"], {}).get("localizations", {}).get("en"):
        missing.append(f"stages.json {s['id']}: {s['hint']!r}")
for key, v in cat.items():
    if "en" not in v.get("localizations", {}):
        missing.append(f"カタログ: 英語がない {key!r}")
if missing:
    print("英語が足りない:", *missing, sep="\n- ")
    sys.exit(1)
print(f"OK: {len(cat)} 件すべてに英語がある")
