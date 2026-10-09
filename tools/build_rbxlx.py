#!/usr/bin/env python3
"""Builds Eclipse.rbxlx (open directly in Roblox Studio, no Rojo needed) from src/."""
import pathlib
from xml.sax.saxutils import escape

root = pathlib.Path(__file__).resolve().parent.parent
n = 0
def ref():
    global n
    n += 1
    return "RBX%d" % n

def cdata(s):
    return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def item(cls, name, source=None, children=""):
    props = '<string name="Name">%s</string>' % escape(name)
    if source is not None:
        props += '<ProtectedString name="Source">%s</ProtectedString>' % cdata(source)
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>' % (cls, ref(), props, children)

def node(path):
    if path.is_dir():
        kids = "".join(node(c) for c in sorted(path.iterdir()) if c.is_dir() or c.suffix == ".lua")
        return item("Folder", path.name, None, kids)
    name, cls = path.name, "ModuleScript"
    if name.endswith(".server.lua"):
        cls, name = "Script", name[:-11]
    elif name.endswith(".client.lua"):
        cls, name = "LocalScript", name[:-11]
    else:
        name = name[:-4]
    return item(cls, name, path.read_text())

def folder(src, name):
    p = root / "src" / src
    return item("Folder", name, None, "".join(node(c) for c in sorted(p.iterdir()) if c.is_dir() or c.suffix == ".lua"))

parts = [
    item("Workspace", "Workspace"),
    item("Lighting", "Lighting"),
    item("ReplicatedStorage", "ReplicatedStorage", None, folder("shared", "Shared")),
    item("ServerScriptService", "ServerScriptService", None, folder("server", "Server")),
    item("StarterPlayer", "StarterPlayer", None,
         item("StarterPlayerScripts", "StarterPlayerScripts", None, folder("client", "Client"))),
]
xml = '<roblox version="4">' + "".join(parts) + "</roblox>"
(root / "Eclipse.rbxlx").write_text(xml)
print("Eclipse.rbxlx written,", len(xml) // 1024, "KB")
