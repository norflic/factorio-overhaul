-- s49 opti : empreintes des plans de v0.7.107 (avant l'optimisation), tests/perf_champ_bench.lua
-- lot C1-COUT (15/11) : empreintes refaites, seul le tapis change (belt = 1, tapis de base ; plan.belt_rule = "base") : sans les champs
-- belt et belt_rule, les empreintes sont identiques avant (83761e6d) et apres la coupe, sur toutes ces specs.
return {
  ["petit"] = 1269820902,
  ["ellipse 45x30"] = 1772277250,
  ["ellipse 45x30 axe y"] = 1563091711,
  ["riviere disque 40"] = 1796304021,
  ["emerald charbon sans voie"] = 145706757,
  ["foret 55x25"] = 1499801455,
  -- s52 mesure : specs réelles de la carte du DC (tests/fixtures/champ_*_dc.lua), empreintes du code de release-0.6.77 (avant s52)
  ["dc joueur fer 1"] = 475887205,
  ["dc emerald fer 3"] = 1366661709,
}
