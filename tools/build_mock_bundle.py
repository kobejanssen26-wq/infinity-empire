#!/usr/bin/env python3
"""Packs src/ (following default.project.json's mapping) into a Lua table so tests/mock_roblox.lua
can recreate the Instance tree and execute the real scripts under a mocked Roblox runtime."""
import pathlib, json

root = pathlib.Path(__file__).resolve().parent.parent
out = root / ".stage"
out.mkdir(exist_ok=True)

def node(path: pathlib.Path):
    if path.is_dir():
        kids = [node(c) for c in sorted(path.iterdir()) if c.is_dir() or c.suffix == ".lua"]
        return {"name": path.name, "class": "Folder", "children": kids}
    name = path.name
    cls = "ModuleScript"
    if name.endswith(".server.lua"):
        cls, name = "Script", name[: -len(".server.lua")]
    elif name.endswith(".client.lua"):
        cls, name = "LocalScript", name[: -len(".client.lua")]
    else:
        name = name[: -len(".lua")]
    return {"name": name, "class": cls, "source": path.read_text(), "children": []}

def lua(v, indent=0):
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            if k == "source":
                assert "]=====]" not in x
                parts.append("source=[=====[\n%s]=====]" % x)
            else:
                parts.append("%s=%s" % (k, lua(x)))
        return "{" + ",".join(parts) + "}"
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v) + "}"
    return json.dumps(v)

tree = {}
for key, folder in (("shared", "Shared"), ("server", "Server"), ("client", "Client")):
    n = node(root / "src" / key)
    n["name"] = folder  # matches default.project.json instance names
    tree[key] = n
(out / "bundle.lua").write_text("return " + lua(tree) + "\n")
print("bundle written")
