"""P0.4: compares the RSK_P04_*.txt snapshots (Zomboid/Lua). Usage: python compare.py <Zomboid/Lua folder>
For each consecutive "save -> load" pair it checks that items (ID, type, position) and ModData keys match,
and that the collectibles found list (COLLECT, ModData RSK_Collect) is kept (CA3).
RSK_ ModData tables and COLLECT keys may appear on a load with ProjectInventory on (the mod creates and
fills them): reported, not counted as differences. Anything disappearing is a difference.
Also reports weight differences > 0.01."""
import pathlib, sys

def load(p):
    head, items, mod, w, col = {}, set(), set(), {}, set()
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        k, _, v = line.partition("|")
        if k in ("LABEL", "MOD_ProjectInventory_ATTIVA", "RSK_LUA_PRESENTE"): head[k] = v
        elif k == "ITEM": items.add(v)
        elif k in ("GMODDATA", "PMODDATA"): mod.add(k + ":" + v)
        elif k == "COLLECT": col.add(v)
        elif k == "WEIGHT":
            path, _, val = v.rpartition("|"); w[path] = float(val)
    return head, items, mod, w, col

def main():
    d = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    files = sorted(d.glob("RSK_P04_*.txt"), key=lambda f: int(f.name.split("_")[2]))
    if not files: print("nessuna istantanea"); return 1
    snaps = [(f, *load(f)) for f in files]
    fail = 0
    for f, h, items, mod, w, col in snaps:
        rsk = sorted(m for m in mod if ":RSK_" in m)
        print(f"{f.name}: {h.get('LABEL')} mod={h.get('MOD_ProjectInventory_ATTIVA')} oggetti={len(items)} modData={len(mod)} trovati={len(col)}" + (f" RSK_={rsk}" if rsk else ""))
    for (fa, ha, ia, ma, wa, ca), (fb, hb, ib, mb, wb, cb) in zip(snaps, snaps[1:]):
        if not (ha.get("LABEL") == "save" and hb.get("LABEL") == "load"): continue
        print(f"\n== {fa.name} -> {fb.name} (mod {ha.get('MOD_ProjectInventory_ATTIVA')} -> {hb.get('MOD_ProjectInventory_ATTIVA')})")
        lost, new = sorted(ia - ib), sorted(ib - ia)
        mlost, mnew = sorted(ma - mb), sorted(mb - ma)
        modOn = hb.get("MOD_ProjectInventory_ATTIVA") == "true"
        expected = [m for m in mnew if modOn and ":RSK_" in m]
        mnew = [m for m in mnew if m not in expected]
        clost, cnew = sorted(ca - cb), sorted(cb - ca)
        cexpected = cnew if modOn else []
        cnew = [] if modOn else cnew
        wd = [(k, wa[k], wb.get(k)) for k in wa if wb.get(k) is None or abs(wa[k] - wb[k]) > 0.01]
        ok = not (lost or new or mlost or mnew or clost or cnew)
        fail += not ok
        print("  ESITO:", "OK" if ok else "DIFFERENZE")
        for name, lst in (("oggetti spariti", lost), ("oggetti nuovi", new), ("ModData spariti", mlost), ("ModData nuovi", mnew),
                          ("trovati persi (CA3)", clost), ("trovati nuovi a mod spenta", cnew), ("pesi diversi", wd),
                          ("attesi: ModData RSK_ creati dalla mod", expected), ("attesi: trovati aggiunti dalla mod", cexpected)):
            if lst: print(f"  {name} ({len(lst)}):", *lst[:15], sep="\n    ")
    return 1 if fail else 0

if __name__ == "__main__":
    sys.exit(main())
