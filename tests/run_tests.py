"""Offline checks for OneClickFish: python tests/run_tests.py  (needs `pip install lupa`).

1. every Lua file listed in the .toc compiles (Lua 5.1)
2. release metadata, locale coverage, line endings, no Blizzard frame skin
3. behaviour tests against WoW API stubs, in both languages
"""
import re
import sys
from pathlib import Path

from lupa.lua51 import LuaRuntime

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
ADDON = "OneClickFish"
TESTS = ["test_fish.lua"]

ok = True


def fail(msg):
    global ok
    ok = False
    print(msg)


# ---------------------------------------------------------------- the .toc
meta, files = {}, []
for line in (ROOT / f"{ADDON}.toc").read_text(encoding="utf-8").splitlines():
    m = re.match(r"##\s*([\w-]+):\s*(.*)", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
    elif line.strip() and not line.startswith("#"):
        files.append(ROOT / line.strip().replace("\\", "/"))

# 1. syntax
lua = LuaRuntime(unpack_returned_tuples=True)
compile_file = lua.eval("function(p) local f, err = loadfile(p); return f ~= nil, err end")
for f in files:
    if not f.exists():
        fail(f"the .toc lists a missing file: {f.relative_to(ROOT)}")
        continue
    res = compile_file(str(f).replace("\\", "/"))
    good, err = res if isinstance(res, tuple) else (res, None)
    if not good:
        fail(f"syntax {f.relative_to(ROOT)}: {err}")
listed = {f.resolve() for f in files}
for f in ROOT.glob("*.lua"):
    if f.resolve() not in listed:
        fail(f"not listed in the .toc: {f.relative_to(ROOT)}")
print(f"syntax: {len(files)} files")

# 2a. release metadata: the changelog ends with the version (the release workflow publishes
# the last section of CHANGELOG.md and refuses a tag that does not match)
sections = re.findall(r"^## (\S+)", (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), re.M)
if not sections or sections[-1] != meta.get("Version"):
    fail(f"CHANGELOG.md must end with the section for {meta.get('Version')} (it ends with {sections[-1] if sections else 'nothing'})")
notes = meta.get("Notes", "")
if len(notes) > 256:
    fail(f"the toc Notes double as the CurseForge summary, which takes 256 characters: {len(notes)}")

# 2b. line endings
for f in list(ROOT.glob("*.*")) + list((ROOT / "docs").glob("*.md")) + list((ROOT / "tests").glob("*.*")):
    if f.suffix in (".lua", ".toc", ".md", ".xml", ".py") and b"\r\n" in f.read_bytes():
        fail(f"CRLF in {f.relative_to(ROOT)}")

# 2c. locale coverage: every key the code uses has a zhTW entry; symbolic keys also need English
en_keys, zh_keys, used, prefixes = set(), set(), set(), set()
code_files = []
for f in files:
    src = f.read_text(encoding="utf-8")
    if f.name == "Locales.lua":
        current = None
        for line in src.splitlines():
            m = re.match(r"ns\.locales\.(\w+) = \{", line)
            if m:
                current = m.group(1)
            elif line.startswith("}"):
                current = None
            else:
                k = re.match(r'\s*\["([^"]+)"\]\s*=', line)
                if k and current:
                    (en_keys if current == "enUS" else zh_keys).add(k.group(1))
        used |= set(re.findall(r'\bkey = "([A-Za-z_]+)"', src))
        used |= set(re.findall(r'L\["([^"]+)"\]', src))   # the binding names
    else:
        code_files.append((f, src))

key_re = re.compile(r'L\["([^"]+)"\]')
prefix_re = re.compile(r'"([A-Z_]+_)"\s*\.\.')
helper_re = re.compile(r'\b(?:Bind|Field|Check|Step|Section|Tooltip)\(([^\n]*)')
literal_re = re.compile(r'"([^"\n]*)"')
for f, src in code_files:
    used |= set(key_re.findall(src))
    prefixes |= set(prefix_re.findall(src))
    for m in helper_re.finditer(src):
        for lit in literal_re.findall(m.group(1)):
            # a locale key starts with a capital (or is symbolic); "GameFont..." is not one
            if lit and lit[0].isupper() and not lit.endswith("_") and not lit.startswith("GameFont") and not lit.startswith("ANCHOR"):
                used.add(lit)
known = en_keys | zh_keys
for f, src in code_files:
    used |= {lit for lit in literal_re.findall(src) if lit in known}
for k in sorted(used):
    if k not in zh_keys:
        fail(f"no zhTW for: {k}")
    if re.match(r"[A-Z]+_", k) and k not in en_keys:
        fail(f"symbolic key without English: {k}")
for k in sorted((zh_keys | en_keys) - used):
    if not any(k.startswith(pre) for pre in prefixes):
        fail(f"locale entry never used: {k}")

# 2d. no Blizzard skin: templates and border art (BackdropTemplate is the API, not a look)
banned = ["UIPanelButtonTemplate", "UICheckButtonTemplate", "UIRadioButtonTemplate", "UIPanelCloseButton",
          "UIPanelScrollFrameTemplate", "UI-DialogBox", "UI-Tooltip-Border", "ChatFrameBackground",
          "UI-QuestTitleHighlight", "Arrow-Down-Up", "ReadyCheck-"]
for f, src in code_files:
    for b in banned:
        if b in src:
            fail(f"Blizzard skin asset in {f.relative_to(ROOT)}: {b}")

# 3. behaviour, in both languages
for loc in ("enUS", "zhTW"):
    for test in TESTS:
        lua = LuaRuntime(unpack_returned_tuples=True)
        g = lua.globals()
        g.ROOT = str(ROOT).replace("\\", "/")
        g.HERE = str(HERE).replace("\\", "/")
        g.LOCALE = loc
        failed = lua.execute((HERE / test).read_text(encoding="utf-8"))
        ok = ok and failed == 0

sys.exit(0 if ok else 1)
