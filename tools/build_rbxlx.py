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

def item(cls, name, source=None, children="", extra=""):
    props = '<string name="Name">%s</string>' % escape(name) + extra
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

baseplate = item("Part", "Baseplate", None, "", (
    '<bool name="Anchored">true</bool>'
    '<Vector3 name="size"><X>2048</X><Y>4</Y><Z>2048</Z></Vector3>'
    '<CoordinateFrame name="CFrame"><X>255</X><Y>-12</Y><Z>255</Z>'
    '<R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>'
    '<int name="Color3uint8">4285098345</int>'))
parts = [
    item("Workspace", "Workspace", None, baseplate),
    item("Lighting", "Lighting", None, "", '<float name="Brightness">2</float><float name="ClockTime">14</float>'),
    item("ReplicatedStorage", "ReplicatedStorage", None, folder("shared", "Shared")),
    item("ServerScriptService", "ServerScriptService", None, folder("server", "Server")),
    item("StarterPlayer", "StarterPlayer", None,
         item("StarterPlayerScripts", "StarterPlayerScripts", None, folder("client", "Client"))),
]
xml = '<roblox version="4">' + "".join(parts) + "</roblox>"
(root / "Eclipse.rbxlx").write_text(xml)
print("Eclipse.rbxlx written,", len(xml) // 1024, "KB")
