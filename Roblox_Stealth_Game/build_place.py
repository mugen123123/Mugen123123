"""Packs the scripts into SilentContract.rbxlx so it can be opened in Roblox Studio.
Run again after editing anything in src/:  python3 build_place.py
"""
from pathlib import Path

here = Path(__file__).parent
ref = 0


def item(cls, name, children="", source=None):
    global ref
    ref += 1
    props = f'<string name="Name">{name}</string>'
    if source is not None:
        safe = source.replace("]]>", "]]]]><![CDATA[>")
        props += f'<ProtectedString name="Source"><![CDATA[{safe}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{ref}"><Properties>{props}</Properties>{children}</Item>\n'


def read(path):
    return (here / path).read_text(encoding="utf-8")


body = (
    item("Workspace", "Workspace")
    + item("ReplicatedStorage", "ReplicatedStorage",
           item("ModuleScript", "StealthConfig", source=read("src/shared/StealthConfig.lua")))
    + item("ServerScriptService", "ServerScriptService",
           item("Script", "StealthServer", source=read("src/server/StealthServer.server.lua"))
           + item("ModuleScript", "StealthProps", source=read("src/server/StealthProps.lua")))
    + item("StarterPlayer", "StarterPlayer",
           item("StarterPlayerScripts", "StarterPlayerScripts",
                item("LocalScript", "StealthClient", source=read("src/client/StealthClient.client.lua"))
                + item("LocalScript", "StealthMenu", source=read("src/client/StealthMenu.client.lua"))))
)
(here / "SilentContract.rbxlx").write_text(f'<roblox version="4">\n{body}</roblox>\n', encoding="utf-8")
print("wrote SilentContract.rbxlx")
