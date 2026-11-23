#!/usr/bin/env python3
"""Boot dist/ollie_tf.lua inside a mock Roblox runtime and report."""
import os, sys
from lupa import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def read(p):
    with open(os.path.join(ROOT, p), "r", encoding="utf-8") as fh:
        return fh.read()

def main():
    rt = LuaRuntime(unpack_returned_tuples=False)
    g = rt.globals()

    mock = rt.execute(read("tools/mock_roblox.lua"))
    g["_MOCK"] = mock

    harness = rt.execute(read("tools/harness.lua"))
    bundle = read("dist/ollie_tf.lua")

    try:
        harness["Run"](bundle)
        results = harness["RunMobile"](bundle)
    except Exception as exc:
        print("harness crashed: %s" % exc)
        return 1

    rows = []
    i = 1
    while True:
        row = results[i]
        if row is None:
            break
        rows.append((row["name"], bool(row["ok"]), row["detail"] or ""))
        i += 1

    width = max(len(r[0]) for r in rows) if rows else 10
    failed = 0
    for name, ok, detail in rows:
        mark = "pass" if ok else "FAIL"
        if not ok:
            failed += 1
        line = "  [%s] %-*s %s" % (mark, width, name, detail)
        print(line.rstrip())

    print("")
    print("%d checks, %d failed" % (len(rows), failed))

    warnings = g["_MOCK"]["warnings"]
    if warnings is not None:
        seen = []
        j = 1
        while True:
            w = warnings[j]
            if w is None:
                break
            seen.append(w)
            j += 1
        if seen:
            print("")
            print("lua warnings (%d):" % len(seen))
            uniq = []
            for w in seen:
                if w not in uniq:
                    uniq.append(w)
            for w in uniq[:20]:
                print("   " + w)
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
