#!/usr/bin/env python3
"""Bundle src/core.lua + src/ui.lua into a single loadable script.

Executors run one file, so the two modules are wrapped in immediately invoked
functions and chained: core is built first, the interface receives it as its
vararg, and Core.start() runs last so the interface is listening before saved
features are restored.

    python3 build.py            # writes dist/VeltrexHub.lua
"""

from pathlib import Path

ROOT = Path(__file__).parent
SRC = ROOT / "src"
OUT = ROOT / "dist" / "VeltrexHub.lua"

HEADER = """--!nocheck
--[==[
	Veltrex Hub
	===========
	Generated file — do not edit directly.
	Sources: src/core.lua (logic) and src/ui.lua (interface).
	Rebuild with: python3 build.py

	The original release mixed its interface into the logic; this build keeps
	the two apart. core.lua creates no GUI at all, ui.lua contains no gameplay
	behaviour, and they talk through Core's event bus.
]==]

if _G.Veltrex and _G.Veltrex.unload then
	pcall(_G.Veltrex.unload)
	task.wait(0.1)
end
"""

FOOTER = """
--==============================================================================
-- Entry point
--==============================================================================

_G.Veltrex = {
	Core   = VeltrexCore,
	UI     = VeltrexUI,
	unload = function() VeltrexUI.unload() end,
}

-- Interface first, so it is subscribed before Core restores saved features.
VeltrexCore.start()
"""


def module(name: str, path: Path, args: str = "") -> str:
    body = path.read_text(encoding="utf-8").rstrip()
    return (
        f"\n--==============================================================================\n"
        f"-- {name} (from {path.relative_to(ROOT)})\n"
        f"--==============================================================================\n\n"
        f"local {name} = (function(...)\n{body}\nend)({args})\n"
    )


def main() -> None:
    parts = [HEADER]
    parts.append(module("VeltrexCore", SRC / "core.lua"))
    parts.append(module("VeltrexUI", SRC / "ui.lua", "VeltrexCore"))
    parts.append(FOOTER)

    bundle = "".join(parts)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(bundle, encoding="utf-8")

    lines = bundle.count("\n") + 1
    print(f"wrote {OUT.relative_to(ROOT)} ({lines} lines, {len(bundle) / 1024:.1f} KB)")


if __name__ == "__main__":
    main()
