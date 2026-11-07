# Lot DEPENSES2 : tableau compact de la sonde (usage : py -3.9 -B tools/autotest/depenses_diag_tableau.py <archive> [...], depuis la racine du mod).
import sys, importlib.util
spec = importlib.util.spec_from_file_location("dd", "tools/autotest/depenses_diag.py"); dd = importlib.util.module_from_spec(spec); spec.loader.exec_module(dd)
for p in sys.argv[1:]:
    D, capi, rsv, pile, mun, dfn, real = dd.parse(p)
    print("==", p.split("/")[-1])
    print("  eq       min | dort: plaques matieres packs munit inter | labos techs/10' | tourelles a_sec munit/tour coffre_munit soldats | capi depense/10' dispo")
    for eq in sorted(set(k[0] for k in D)):
        for t in (30, 45, 59):
            C, L, A = D.get((eq, t, "C")), D.get((eq, t, "L")), D.get((eq, t, "A"))
            if not C: continue
            dor = {f: dd.dormant_fam(D, eq, t, f) for f in dd.FAMS}
            Lp = D.get((eq, t - 10, "L")) or D.get((eq, t - 9, "L"))
            done10 = (dd.g(L, "faites") - dd.g(Lp, "faites")) if (L and Lp) else -1
            key = "votre equipe" if eq == "player" else eq
            cp = [c for c in capi if c[0] in (eq, key) and t - 10 < c[1] <= t]
            mu = [x for x in mun if x[0] in (eq, key) and t - 10 < x[1] <= t]
            f = lambda x: "-" if x is None else "%d" % x
            print("  %-8s %2d | %6s %6s %5s %5s %5s | %d %2d | %3d %d %5.1f %4s %3d | %5.0f %6.0f" % (eq, t, f(dor["plaques"]), f(dor["matieres"]), f(dor["packs"]), f(dor["munitions"]), f(dor["intermediaires"]),
                dd.g(L, "labos"), done10, dd.g(A, "tourelles"), dd.g(A, "a_sec"), (mu[-1][4] if mu else -1), (str(mu[-1][5]) if mu else "-"), dd.g(A, "soldats"),
                sum(c[2] for c in cp), (cp[-1][3] if cp else 0)))
