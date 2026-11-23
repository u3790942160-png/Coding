#!/usr/bin/env python3
"""Bundle src/NN_name.lua into one loadstring-able Luau file and syntax check it."""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "dist", "ollie_tf.lua")

HEADER = """--[[
	olliE / Lord's Court  --  Touch Football toolkit
	Built from src/ by tools/build.py. Edit the modules, not this file.

	Ground truth note: this build ships with NO Touch Football offsets,
	remote names or instance paths. Every game specific value is unset in
	the cfg module and is either discovered by the resolver at runtime or
	filled in by hand on the CONFIG tab. A feature whose value is still
	unset prints one line and disables itself. Nothing else stops.
]]

local __src, __cache = {}, {}
local __LOADING = newproxy and newproxy(false) or {}

local function _R(name)
	local hit = __cache[name]
	if hit ~= nil then
		if hit == __LOADING then
			error("[olliE] dependency cycle at module: " .. tostring(name), 2)
		end
		return hit
	end
	local factory = __src[name]
	if factory == nil then
		error("[olliE] missing module: " .. tostring(name), 2)
	end
	__cache[name] = __LOADING
	local value = factory(_R)
	if value == nil then
		error("[olliE] module returned nil: " .. tostring(name), 2)
	end
	__cache[name] = value
	return value
end

"""

FOOTER = """
if rawget(_G, "LC_TEST") then _G.LC_R = _R end

local ok, err = pcall(function()
	_R("main").Start()
end)
if not ok then
	warn("[olliE] boot failed: " .. tostring(err))
	local notified = pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "olliE", Text = tostring(err), Duration = 8,
		})
	end)
	if not notified then print("[olliE] boot failed: " .. tostring(err)) end
end
"""


def collect():
    files = sorted(f for f in os.listdir(SRC) if re.match(r"^\d\d_.*\.lua$", f))
    mods = []
    for fname in files:
        path = os.path.join(SRC, fname)
        with open(path, "r", encoding="utf-8") as fh:
            body = fh.read()
        m = re.search(r"^--\s*@module\s+([A-Za-z0-9_]+)\s*$", body, re.M)
        if not m:
            sys.exit("no -- @module header in " + fname)
        mods.append((m.group(1), fname, body))
    return mods


def bundle(mods):
    parts = [HEADER]
    for name, fname, body in mods:
        parts.append('-- ===== %s  (src/%s) =====\n' % (name, fname))
        parts.append('__src["%s"] = function(_R)\n' % name)
        parts.append(body.rstrip("\n"))
        parts.append("\nend\n\n")
    parts.append(FOOTER)
    return "".join(parts)


def syntax_check(text, label):
    try:
        from lupa import LuaRuntime
    except ImportError:
        return None, "lupa not installed, no syntax check run"
    rt = LuaRuntime(unpack_returned_tuples=True)
    try:
        rt.compile(text)
        return True, "parsed clean"
    except Exception as exc:
        return False, "%s: %s" % (label, exc)


def main():
    mods = collect()
    out = bundle(mods)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    failures = []
    for name, fname, body in mods:
        wrapped = "local _R = ... \n" + body
        ok, msg = syntax_check(wrapped, fname)
        if ok is False:
            failures.append(msg)

    ok, msg = syntax_check(out, "bundle")
    if ok is False:
        failures.append(msg)

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(out)

    lines = out.count("\n") + 1
    print("modules : %d" % len(mods))
    print("output  : %s" % OUT)
    print("size    : %d bytes, %d lines" % (len(out.encode("utf-8")), lines))
    if ok is None:
        print("syntax  : SKIPPED (%s)" % msg)
    elif failures:
        print("syntax  : FAILED")
        for f in failures:
            print("   " + f)
        sys.exit(1)
    else:
        print("syntax  : all %d modules + bundle parsed clean" % len(mods))


if __name__ == "__main__":
    main()
