#!/usr/bin/env python3
"""Flattens the pure modules (src/shared + src/server/Logic + tests) into .stage/ and rewrites
Roblox-style require(a.b.C) into require("./C") so they run under the standalone `luau` CLI.
Usage: python3 tools/stage_tests.py && luau .stage/test_all.lua
"""
import re, shutil, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
stage = root / ".stage"
if stage.exists():
    shutil.rmtree(stage)
stage.mkdir()

REQ = re.compile(r"require\(([\w.:]+)\)")

def rewrite(text: str) -> str:
    return REQ.sub(lambda m: 'require("./%s")' % m.group(1).split(".")[-1], text)

names = set()
for src in [root / "src" / "shared", root / "src" / "server" / "Logic", root / "tests"]:
    for f in sorted(src.glob("*.lua")):
        if f.name == "Shared.lua":
            continue  # replaced by stub below
        assert f.name not in names, "duplicate module name " + f.name
        names.add(f.name)
        txt = f.read_text()
        # `script.Parent.X` already collapses to X through the regex
        txt = rewrite(txt)
        if f.name != "shim.lua":
            lines = txt.split("\n")
            hdr = 'local Color3, Random = require("./shim").Color3, require("./shim").Random'
            idx = 1 if lines[0].startswith("--!") else 0
            lines.insert(idx, hdr)
            txt = "\n".join(lines)
        (stage / f.name).write_text(txt)

stub = ["--!nonstrict", "return {"]
for mod in ["Config","Creatures","Machines","Research","Prestige","Quests","Formulas","Stats","Monetization"]:
    stub.append('\t%s = require("./%s"),' % (mod, mod))
stub.append("}")
(stage / "Shared.lua").write_text("\n".join(stub) + "\n")
print("staged", len(names) + 1, "modules ->", stage)
