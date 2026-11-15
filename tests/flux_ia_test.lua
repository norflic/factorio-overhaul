-- Lot UI-FLUX : règles pures de shared/gui/flux_ia.lua (classement des projets en catégories, synthèse des barres, mm:ss).
-- lua5.2 tests/flux_ia_test.lua
package.path = "./?.lua;" .. package.path
local Fx = require("shared.gui.flux_ia")

local ok, ko = 0, 0
local function check(c, msg)
  if c then ok = ok + 1 else ko = ko + 1 print("  ECHEC : " .. msg) end
end

-- 1. classement par spec
local cases = {
  { { enceinte = true, walls = {} }, "defense", "enceinte" },
  { { gen = "steam", args = { 1 }, plant = true }, "energie", "centrale" },
  { { alim = 3, pole = "x" }, "energie", "alimentation d'une centrale" },
  { { site = "ligne_bande", lg = {} }, "energie", "ligne électrique de bande" },
  { { gen = "labs" }, "recherche", "laboratoires" },
  { { gen = "red_packs" }, "recherche", "paquets rouges" },
  { { site = "mall", mall = {} }, "mall", "mall" },
  { { liaison = { key = "a" } }, "mall", "liaison au bus" },
  { { gen = "smelter", args = { 1, 2, 3 }, feed = true }, "fonderies", "fonderie" },
  { { site = "champ", champ = { oid = 1 } }, "champ", "bande de champ" },
  { { gen = "drills", fixe = true }, "champ", "bande de foreuses" },
  { { rapatriement = {} }, "champ", "rapatriement" },
  { { gen = "circuits" }, "mall", "usine de circuits" },
  { { site = "petrole" }, "mall", "pétrole" },
  { { bench = "collecte" }, nil, "spec sans catégorie" },
}
for _, c in ipairs(cases) do check(Fx.classify(c[1]) == c[2], "classify : " .. c[3] .. " -> " .. tostring(c[2]) .. " (obtenu " .. tostring(Fx.classify(c[1])) .. ")") end
check(Fx.classify(nil) == nil and Fx.classify("x") == nil, "classify : non-table")
-- priorité : une centrale qui porte aussi un gen d'usine reste énergie ; une enceinte reste défense
check(Fx.classify({ gen = "smelter", plant = true }) == "energie", "énergie avant fonderie")
check(Fx.classify({ gen = "drills", enceinte = true }) == "defense", "défense avant champ")
check(Fx.family_cat("recherche") == "recherche" and Fx.family_cat("armee") == "defense" and Fx.family_cat("extraction") == "champ"
  and Fx.family_cat("capital") == nil and Fx.family_cat(nil) == nil, "famille -> catégorie")

-- 2. temps et pourcentages
check(Fx.mmss(0) == "00:00" and Fx.mmss(3600) == "01:00" and Fx.mmss(60 * 125 + 59) == "02:05" and Fx.mmss(nil) == "--:--" and Fx.mmss(-1) == "--:--", "mmss")
check(Fx.pct(1, 3) == 33 and Fx.pct(2, 3) == 67 and Fx.pct(5, 0) == 0 and Fx.pct(nil, 10) == 0, "pct")
check(Fx.active("attente") and Fx.active("chantier") and not Fx.active("fini") and not Fx.active("refuse") and not Fx.active(nil), "active")

-- 3. synthèse
local sm = Fx.summarize({
  tick = 36000, resources = { "iron-plate", "copper-plate", "coal" },
  builds = {
    { cat = "champ", created = 6000, raw = { ["iron-plate"] = 300, ["copper-plate"] = 50 } },
    { cat = "champ", created = 3000, raw = { ["iron-plate"] = 100 } },
    { cat = "energie", created = 9000, raw = { ["iron-plate"] = 200, ["copper-plate"] = 150 } },
    { cat = nil, created = 100, raw = { ["iron-plate"] = 999 } },
  },
  goals = { { cat = "recherche", opened = 12000 }, { cat = "champ", opened = 1000 } },
  extra = { defense = { ["iron-plate"] = 400, stone = 80 }, recherche = { ["copper-plate"] = 100 } },
  free = { ["iron-plate"] = 1000, ["copper-plate"] = 300 },
})
local fe = sm.res["iron-plate"]
check(fe.total == 2000, "fer : total = 300+100+200+400+1000 (obtenu " .. tostring(fe.total) .. ")")
check(#fe.bars == 4 and fe.bars[1].cat == "champ" and fe.bars[1].n == 400 and fe.bars[1].pct == 20, "fer : barre champ 400 = 20 %")
check(fe.bars[2].cat == "energie" and fe.bars[3].cat == "defense" and fe.bars[4].cat == Fx.FREE and fe.bars[4].pct == 50, "fer : ordre fixe, libre en dernier")
check(sm.res["coal"].total == 0 and #sm.res["coal"].bars == 0, "charbon : rien")
check(sm.other == 1, "un projet hors catégorie compté à part")
check(sm.engaged == 400 + 50 + 200 + 150 + 400 + 100, "engagé : hors stock libre, hors matière non suivie (pierre)")
check(sm.cats.champ.count == 2 and sm.cats.champ.since == 36000 - 1000, "champ : le plus ancien lancement (but IA3 à 1000) -> since")
check(sm.cats.energie.since == 27000 and sm.cats.recherche.since == 24000, "énergie 27000 ticks, recherche 24000 (but IA3)")
check(sm.cats.defense.since == nil and sm.cats.defense.pct == Fx.pct(400, sm.engaged), "défense : pas de lancement connu, part du total")
check(sm.cats.mall.n == 0 and sm.cats.mall.pct == 0, "mall vide")
local total_pct = 0
for _, c in ipairs(Fx.CATS) do total_pct = total_pct + sm.cats[c].n end
check(total_pct == sm.engaged, "somme des catégories = engagé")
-- lancement futur (horloge incohérente) : pas de durée négative
local sm2 = Fx.summarize({ tick = 10, resources = { "a" }, builds = { { cat = "mall", created = 50, raw = { a = 1 } } }, free = {} })
check(sm2.cats.mall.since == nil, "lancement dans le futur : since nil")
-- starts
local sm3 = Fx.summarize({ tick = 600, resources = { "a" }, builds = {}, starts = { defense = 120 }, free = {} })
check(sm3.cats.defense.since == 480, "starts connus d'ailleurs")
-- ligne de journal
local ln = Fx.line("player", 10, sm)
check(ln:find("^%[FO%-FLUX%] player minute 10") and ln:find("champ=") and ln:find("defense=") and ln:find("hors categorie 1"), "ligne de journal : " .. ln)

-- 4. mutants : le test doit échouer sur un classement ou un calcul faux
local function mutant(name, f, probe)
  local saved = Fx[name]
  Fx[name] = f
  local failed = not probe()
  Fx[name] = saved
  check(failed, "mutant refusé : " .. name)
end
mutant("classify", function(spec) return spec.gen and "mall" or nil end, function()
  return Fx.classify({ gen = "smelter" }) == "fonderies" and Fx.classify({ gen = "labs" }) == "recherche" end)
mutant("classify", function(spec) if spec.gen == "smelter" then return "fonderies" end if spec.plant then return "fonderies" end return Fx.family_cat("x") end, function()
  return Fx.classify({ gen = "smelter", plant = true }) == "energie" end)
mutant("pct", function(n, t) return t > 0 and math.floor(n * 100 / t) or 0 end, function() return Fx.pct(2, 3) == 67 end)
mutant("mmss", function(t) return string.format("%02d:%02d", math.floor(t / 60), t % 60) end, function() return Fx.mmss(60 * 125 + 59) == "02:05" end)

print(string.format("[FLUX-IA] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
