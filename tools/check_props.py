#!/usr/bin/env python3
"""Heuristic API check: verifies property names used in UI.* helper calls / UI.new / Instance.new blocks
exist on the Roblox classes (uses API-Dump.json). Usage: check_props.py API-Dump.json"""
import json, re, sys, pathlib

api = json.load(open(sys.argv[1]))
classes = {c["Name"]: c for c in api["Classes"]}

def props(cls):
    out = set()
    while cls:
        c = classes.get(cls)
        if not c: break
        for m in c["Members"]:
            if m["MemberType"] in ("Property",):
                out.add(m["Name"])
        cls = c.get("Superclass")
    return out

HELPERS = {  # helper -> class, extra custom keys it understands
    "UI.frame": ("Frame", set()), "UI.card": ("Frame", set()),
    "UI.label": ("TextLabel", set()), "UI.button": ("TextButton", {"color", "textColor"}),
    "UI.scroll": ("ScrollingFrame", set()),
}
src = pathlib.Path("src")
bad = 0
def table_after(text, idx):
    """returns the first {...} table literal starting at/after idx whose open brace is the call's last arg"""
    return None

def keys_of(tbl):
    keys = []; depth = 0; i = 0; n = len(tbl)
    cur = ""
    while i < n:
        ch = tbl[i]
        if ch in "{([": depth += 1
        elif ch in "})]": depth -= 1
        elif ch == '"' or ch == "'":
            j = i + 1
            while j < n and tbl[j] != ch:
                j += 2 if tbl[j] == "\\" else 1
            i = j
        elif depth == 1:
            m = re.match(r"([A-Za-z_]\w*)\s*=(?!=)", tbl[i:])
            if m and (i == 0 or not (tbl[i-1].isalnum() or tbl[i-1] in "_.")):
                keys.append(m.group(1)); i += len(m.group(0)) - 1
        i += 1
    return keys

def find_calls(text, name):
    for m in re.finditer(re.escape(name) + r"\(", text):
        # scan the argument list to its closing paren, collect top-level table literals
        i = m.end(); depth = 1; start = None; tables = []
        while i < len(text) and depth > 0:
            ch = text[i]
            if ch in '"\'':
                j = i + 1
                while text[j] != ch: j += 2 if text[j] == "\\" else 1
                i = j
            elif ch in "([{":
                if ch == "{" and depth == 1: start = i
                depth += 1
            elif ch in ")]}":
                depth -= 1
                if ch == "}" and depth == 1 and start is not None:
                    tables.append(text[start:i+1]); start = None
            i += 1
        yield m.start(), text[m.end():i], tables

for f in sorted(src.rglob("*.lua")):
    text = f.read_text()
    line = lambda pos: text.count("\n", 0, pos) + 1
    for helper, (cls, custom) in HELPERS.items():
        valid = props(cls) | custom
        for pos, args, tables in find_calls(text, helper):
            # for UI.button the props table is the last table arg; for others the only one
            if not tables: continue
            tbl = tables[-1]
            for k in keys_of(tbl):
                if k not in valid:
                    print(f"{f}:{line(pos)}: {helper} unknown property '{k}' on {cls}"); bad += 1
    for pos, args, tables in find_calls(text, "UI.new"):
        m = re.match(r'\s*"(\w+)"', args)
        if not m: continue
        cls = m.group(1)
        if cls not in classes:
            print(f"{f}:{line(pos)}: unknown class {cls}"); bad += 1; continue
        valid = props(cls)
        if tables:
            for k in keys_of(tables[0]):
                if k not in valid:
                    print(f"{f}:{line(pos)}: UI.new {cls} unknown property '{k}'"); bad += 1
    for m in re.finditer(r'Instance\.new\("(\w+)"\)', text):
        if m.group(1) not in classes:
            print(f"{f}:{line(m.start())}: unknown class {m.group(1)}"); bad += 1
    # property assignments on locals created via Instance.new in same file are not tracked (heuristic)
print("property check:", "OK" if bad == 0 else f"{bad} problems")
sys.exit(1 if bad else 0)
