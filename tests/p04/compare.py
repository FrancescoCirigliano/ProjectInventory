"""P0.4: compares the RSK_P04_*.txt snapshots (Zomboid/Lua). Usage: python compare.py <Zomboid/Lua folder>
For each consecutive "save -> load" pair it checks that items (ID, type, position) and ModData keys match.
Also reports ModData keys with the RSK_ prefix (expected only after M4) and weight differences > 0.01."""
import pathlib, sys

def load(p):
    head, items, mod, w = {}, set(), set(), {}
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        k, _, v = line.partition("|")
        if k in ("LABEL", "MOD_ProjectInventory_ATTIVA", "RSK_LUA_PRESENTE"): head[k] = v
        elif k == "ITEM": items.add(v)
        elif k in ("GMODDATA", "PMODDATA"): mod.add(k + ":" + v)
        elif k == "WEIGHT":
            path, _, val = v.rpartition("|"); w[path] = float(val)
    return head, items, mod, w

def main():
    d = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    files = sorted(d.glob("RSK_P04_*.txt"), key=lambda f: int(f.name.split("_")[2]))
    if not files: print("nessuna istantanea"); return 1
    snaps = [(f, *load(f)) for f in files]
    fail = 0
    for f, h, items, mod, w in snaps:
        rsk = sorted(m for m in mod if ":RSK_" in m)
        print(f"{f.name}: {h.get('LABEL')} mod={h.get('MOD_ProjectInventory_ATTIVA')} oggetti={len(items)} modData={len(mod)}" + (f" RSK_={rsk}" if rsk else ""))
    for (fa, ha, ia, ma, wa), (fb, hb, ib, mb, wb) in zip(snaps, snaps[1:]):
        if not (ha.get("LABEL") == "save" and hb.get("LABEL") == "load"): continue
        print(f"\n== {fa.name} -> {fb.name} (mod {ha.get('MOD_ProjectInventory_ATTIVA')} -> {hb.get('MOD_ProjectInventory_ATTIVA')})")
        lost, new = sorted(ia - ib), sorted(ib - ia)
        mlost, mnew = sorted(ma - mb), sorted(mb - ma)
        wd = [(k, wa[k], wb.get(k)) for k in wa if wb.get(k) is None or abs(wa[k] - wb[k]) > 0.01]
        ok = not (lost or new or mlost or mnew)
        fail += not ok
        print("  ESITO:", "OK" if ok else "DIFFERENZE")
        for name, lst in (("oggetti spariti", lost), ("oggetti nuovi", new), ("ModData spariti", mlost), ("ModData nuovi", mnew), ("pesi diversi", wd)):
            if lst: print(f"  {name} ({len(lst)}):", *lst[:15], sep="\n    ")
    return 1 if fail else 0

if __name__ == "__main__":
    sys.exit(main())
