--[[
  Lot REBUILD-RAPIDE : test hors jeu (règle pure shared/team/rebuild_rapide.lua, mutants ; exécutants script/team/rebuild_sweep.lua,
  script/team/rebuild_rapide.lua et script/team/front.lua en moteur simulé réduit ; branchements de script/team/build.lua et
  script/team/reconstruction.lua relus dans la source).
  Retour du DC (29/10 vers 22 h, 0.6.18) : reconstruction en ~10 min de jeu, production principale et poteaux refaits trop tard, cellule
  réattaquée sans nouvelles tourelles chez une équipe riche, pas de foreuse thermique de secours sans cuivre.
  Usage : lua5.2 tests/rebuild_rapide_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local logs = {}
function log(s) logs[#logs + 1] = s end
local function logged(pat)
  for _, l in ipairs(logs) do if l:find(pat) then return l end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- 1. Règle pure (et mutants)
---------------------------------------------------------------------------------------------------
local SRC = read("shared/team/rebuild_rapide.lua")
local function load_rule(src)
  local fn, err = load(src, "=rebuild_rapide", "t")
  if not fn then return nil, err end
  local ok, m = pcall(fn)
  if not ok then return nil, m end
  return m
end

local Fr = require("shared.team.front")
local Rc = require("shared.team.reconstruction")

local function suite(Rr)
  local ok, bad = 0, {}
  local function c(cond, m) if cond then ok = ok + 1 else bad[#bad + 1] = m end end

  -- (a) liste chaude
  local st = {}
  local e1, e2 = { built = true }, { built = true }
  c(Rr.hot_add(st, 3, 7, e1, 100) == true and e1.miss == 100 and e1.died_t == 100, "pièce tuée : inscrite, marquée absente à sa mort")
  c(Rr.hot_add(st, 3, 7, e1, 150) == false and #st.hot == 1, "même pièce : pas de doublon")
  e2.miss = 40
  c(Rr.hot_add(st, 3, 8, e2, 160) == true and e2.miss == 40, "première absence déjà vue par le curseur : date gardée")
  c(Rr.hot_add(st, 3, 9, { built = false }, 160) == false, "pièce non bâtie (déjà rouverte) : rien")
  c(Rr.hot_add(st, 3, 10, { built = true, wall = true }, 160) == false and Rr.hot_add(st, 3, 11, { built = true, gave_up = true }, 160) == false,
    "mur d'enceinte ou pièce abandonnée : rien")
  local big = {}
  for i = 1, Rr.HOT_MAX + 3 do Rr.hot_add(big, 1, i, { built = true }, i) end
  c(#big.hot == Rr.HOT_MAX and big.hot_full == 3, "liste chaude bornée (" .. #big.hot .. ")")
  Rr.hot_set_list(st, { st.hot[2] })
  c(#st.hot == 1 and st.hot_set["3:8"] and not st.hot_set["3:7"], "liste chaude remplacée, clés refaites")
  c(Rr.partial_go({ reopened = 1, reopened_tick = 5 }) == true, "projet rouvert daté : chantier sans toute la matière")
  c(Rr.partial_go({ reopened = 2, reopened_tick = 5, finished = 9 }) == false,
    "lot FUITES-PILE : pas d'agrandissement d'une ligne réparée une fois : pas de chantier sans toute la matière")
  c(Rr.partial_go({ reopened = 1 }) == false and Rr.partial_go({}) == false and Rr.partial_go(nil) == false,
    "mur d'enceinte rouvert sans date, projet neuf : tout-ou-rien comme avant")
  -- relecture : budget de la liste chaude (rotation) et lot de chantier sans aucun objet au coffre
  local nx = Rr.hot_next({ { 1, 5 }, { 1, 6 } }, { { 1, 2 } })
  c(#nx == 3 and nx[1][2] == 5 and nx[2][2] == 6 and nx[3][2] == 2, "liste chaude : les pièces non relues passent en tête de la passe suivante")
  c(type(Rr.HOT_PER_PASS) == "number" and Rr.HOT_PER_PASS >= 1 and Rr.HOT_PER_PASS < Rr.HOT_MAX, "liste chaude : budget de lectures par passe")
  local inv = { tapis = 0, bras = 2 }
  local function have(it) return inv[it] or 0 end
  c(Rr.batch_ready({ "tapis", "bras" }, have) == true, "lot de chantier : un objet au coffre suffit au voyage")
  c(Rr.batch_ready({ "tapis", "four" }, have) == false and Rr.batch_ready({}, have) == false, "lot de chantier : rien au coffre, pas de voyage")

  -- (b) ordre
  c(Rr.project_rank({ gen = "steam" }) == 1 and Rr.project_rank({ gen = "smelter" }) == 2 and Rr.project_rank({ gen = "drills" }) == 2
    and Rr.project_rank({ gen = "simple" }) == 3 and Rr.project_rank(nil) == 3, "rangs : alimentation, production principale, le reste")
  local reo = { reopened = 1, reopened_tick = 1 }
  local function proj(gen) return { reopened = 1, reopened_tick = 1, spec = { gen = gen } } end
  c(Rr.project_prio(proj("steam"), 85) == Rr.PRIO_POWER and Rr.project_prio(proj("smelter"), 85) == Rr.PRIO_MAIN
    and Rr.project_prio(proj("simple"), 85) == 85, "projet rouvert : centrale, puis fonderie, puis le reste à sa priorité")
  c(Rr.project_prio({ spec = { gen = "smelter" } }, 85) == 85, "projet NEUF : priorité inchangée (ce n'est pas une reconstruction)")
  c(Rr.project_prio(proj("smelter"), 89) == 89, "jamais sous la priorité de base")
  local pole = { infra = true, value = Rc.pole_value(3) }
  local boiler = { infra = true, value = Rc.INFRA_VALUE }
  local drill = { kind = "drill", value = 3 }
  local lab = { value = 8 }
  local pb, pp, pd, pl = Rr.registry_prio(boiler, 84), Rr.registry_prio(pole, 75), Rr.registry_prio(drill, 73), Rr.registry_prio(lab, 78)
  c(pb > pp and pp > pd and pd > pl and pl == 78, "registre : énergie > poteau > champ de minerai > le reste (" .. pb .. ", " .. pp .. ", " .. pd .. ", " .. pl .. ")")
  c(pb < 90 and Rr.PRIO_MAIN > 85, "sous l'urgence et les tourelles (90), au-dessus d'une fin de chantier ordinaire (85)")
  c(Rr.PRIO_POLE > Rr.project_prio(proj("smelter"), 85), "poteaux AVANT la production principale")
  c(reo ~= nil, "")

  -- (c) vagues, richesse, renfort
  local fs = {}
  c(Rr.wave_note(fs, "1,1", 1000) == 1, "première mort : vague 1")
  c(Rr.wave_note(fs, "1,1", 1000 + Rr.WAVE_GAP) == 1, "morts rapprochées : même vague")
  c(Rr.wave_note(fs, "1,1", 1000 + 2 * Rr.WAVE_GAP + 1) == 2, "après un calme de plus de 30 s : deuxième vague")
  c(Rr.wave_note(fs, "1,1", 1000 + 2 * Rr.WAVE_GAP + 2 + Rr.WAVE_FORGET) == 1, "après 30 min sans mort : les vagues sont oubliées")
  c(Rr.wave_note(nil, "x", 1) == nil and Rr.wave_note(fs, nil, 1) == nil, "sans mémoire ou sans cellule : rien")
  Rr.wave_note(fs, "2,2", 10)
  c(Rr.wave_prune(fs, 10 + Rr.WAVE_FORGET + 1) == 1 and fs.waves["2,2"] == nil and fs.waves["1,1"] ~= nil, "oubli des vagues anciennes")
  c(Rr.rich(600, 30, 150, 30) == true and Rr.rich(599, 30, 150, 30) == false and Rr.rich(8000, 29, 150, 30) == false,
    "riche : fer >= 4 × le plancher et cuivre au plancher")
  local cells = { { key = "a", cx = 0, cy = 0, score = 300, x = 1, y = 1 }, { key = "b", cx = 1, cy = 0, score = 300, x = 20, y = 1 } }
  local waves = { a = { n = 2, last = 5000 }, b = { n = 1, last = 5000 } }
  local out, boosted = Rr.boost(cells, waves, true, 5000, Fr.want, Fr.BASE, Fr.PER_TURRET)
  c(boosted.a and not boosted.b and out[1].rich and Fr.want(out[1].score) == Fr.want(300) + Rr.RICH_EXTRA and out[2] == cells[2],
    "riche et réattaquée : une tourelle de plus ; attaquée une seule fois : inchangée")
  c(cells[1].score == 300, "la liste du front n'est pas modifiée (copie)")
  local out2, b2 = Rr.boost(cells, waves, false, 5000, Fr.want, Fr.BASE, Fr.PER_TURRET)
  c(out2[1] == cells[1] and next(b2) == nil, "pas riche : rien ne change")
  local _, b3 = Rr.boost(cells, waves, true, 5000 + Rr.WAVE_FORGET + 1, Fr.want, Fr.BASE, Fr.PER_TURRET)
  c(next(b3) == nil, "vagues trop anciennes : rien ne change")
  c(Rr.cap_placed(16, true) == 16 - Rr.RICH_CAP and Rr.cap_placed(16, false) == 16 and Rr.cap_placed(3, true) == 0 and Rr.RICH_CAP > 0,
    "plafond d'équipe du front : des places de plus pour une équipe riche seulement")
  c(Rr.rich_count(5, 1, 16) == 4 and Rr.rich_count(5, 1, 2) == 2 and Rr.rich_count(2, 3, 16) == 0, "tout le manque d'un coup, sous le plafond")

  -- (d) foreuse thermique de secours
  local e = { name = "elec", built = false }
  c(Rr.subst_due(e, "elec", false, true) == true, "électrique ni au coffre ni fabricable, combustion disponible : remplacée")
  c(Rr.subst_due(e, "elec", true, true) == false, "électrique disponible : pas de remplacement")
  c(Rr.subst_due(e, "elec", false, false) == false, "combustion indisponible aussi : la pièce attend")
  c(Rr.subst_due({ name = "elec", built = true }, "elec", false, true) == false and Rr.subst_due({ name = "autre" }, "elec", false, true) == false
    and Rr.subst_due({ name = "elec", subst = {} }, "elec", false, true) == false, "pièce bâtie, autre pièce ou déjà remplacée : rien")
  c(Rr.revert_due({ subst = {} }, 1) == true and Rr.revert_due({ subst = {} }, 0) == false and Rr.revert_due({}, 5) == false,
    "retour à l'électrique seulement quand l'objet est au coffre")
  local function size_of(name) if name == "tapis" then return 1, 1 end if name == "four" then return 2, 2 end return nil end
  local drill_e = { name = "elec", x = 10.5, y = 10.5, dir = 0 }
  local ents = { drill_e, { name = "tapis", x = 10.5, y = 8.5, dir = 0 } }
  local bx, by = Rr.subst_center(ents, drill_e, 3, { 0, -1.85 }, { size = 2, drop = { -0.5, -1.3 } }, size_of)
  c(bx == 11 and by == 10, "foreuse de secours : dans l'ancienne emprise, dépose sur le même tapis (" .. tostring(bx) .. ", " .. tostring(by) .. ")")
  local drill_s = { name = "elec", x = 10.5, y = 10.5, dir = 4 }
  local bx2, by2 = Rr.subst_center({ drill_s }, drill_s, 3, { 0, -1.85 }, { size = 2, drop = { -0.5, -1.3 } }, size_of)
  c(bx2 == 10 and by2 == 11, "sans pièce au point de dépôt : la tuile du dépôt sert de réceptacle (sud) (" .. tostring(bx2) .. ", " .. tostring(by2) .. ")")
  local sink = Rr.sink_box({ drill_e, { name = "four", x = 11, y = 8 } }, drill_e, { 0, -1.85 }, size_of)
  c(sink.w == 2 and sink.x == 11, "réceptacle : la pièce du plan qui contient le point de dépôt")
  return ok, bad
end

local Rr0 = load_rule(SRC)
check(Rr0 ~= nil, "la règle se charge")
local okn, bad0 = suite(Rr0)
for _, m in ipairs(bad0) do check(false, m) end
pass = pass + okn

local MUTANTS = {
  { "liste chaude sans date de mort", "if not e.miss then e.miss = tick end", "" },
  { "liste chaude avec doublons", "if st.hot_set[key] then return false end", "" },
  { "liste chaude sans borne", "if #st.hot >= Rr.HOT_MAX then", "if false then" },
  { "pièces non relues oubliées", "for _, h in ipairs(later or {}) do out[#out + 1] = h end", "" },
  { "pièces non relues en queue", "  for _, h in ipairs(later or {}) do out[#out + 1] = h end\n  for _, h in ipairs(kept or {}) do out[#out + 1] = h end",
    "  for _, h in ipairs(kept or {}) do out[#out + 1] = h end\n  for _, h in ipairs(later or {}) do out[#out + 1] = h end" },
  { "voyage même sans rien au coffre", "if (have(it) or 0) >= 1 then return true end\n  end\n  return false", "if (have(it) or 0) >= 1 then return true end\n  end\n  return true" },
  -- (lot FUITES-PILE : Rr.partial_go = Sw.rebuilding ; la règle de la date vit dans shared/team/rebuild_sweep.lua, mutée par rebuild_sweep_test)
  { "mur rouvert sans date en partiel", "return Sw.rebuilding(p)", "return (p and (p.reopened or 0) > 0) or false" },
  { "agrandissement en partiel (ancienne règle)", "return Sw.rebuilding(p)", "return (p and (p.reopened or 0) > 0 and p.reopened_tick ~= nil) or false" },
  { "réserve partielle jamais", "return Sw.rebuilding(p)", "return false" },
  { "centrale non prioritaire", "if g and Rr.POWER_GENS[g] then return 1 end", "" },
  { "fonderie non prioritaire", "if rank == 2 then return math.max(base, Rr.PRIO_MAIN) end", "" },
  { "projet neuf relevé", "if not Rr.partial_go(p) then return base end", "" },
  { "poteau = énergie", "Rc.is_pole_value(r) and Rr.PRIO_POLE or Rr.PRIO_POWER", "Rr.PRIO_POWER" },
  { "champ de minerai oublié", "if r and (r.kind == \"drill\" or r.kind == \"sink\") then return math.max(base, Rr.PRIO_MAIN) end", "" },
  { "priorité sous la base", "return math.max(base, Rr.PRIO_MAIN) end\n  return base", "return Rr.PRIO_MAIN end\n  return base" },
  { "chaque mort est une vague", "if not w.last or tick - w.last > Rr.WAVE_GAP then w.n = w.n + 1 end", "w.n = w.n + 1" },
  { "vagues jamais oubliées", "if w.last and tick - w.last > Rr.WAVE_FORGET then w.n = 0 end", "" },
  { "riche sans cuivre", "and (copper or 0) >= (floor_cu or 0)", "" },
  { "réattaquée dès une vague", "w.n >= Rr.WAVES", "w.n >= 1" },
  { "renfort même pauvre", "if rich and w and", "if w and" },
  { "renfort sans tourelle de plus", "local target = want(c.score) + Rr.RICH_EXTRA", "local target = want(c.score)" },
  { "plafond relevé même pauvre", "if not rich then return placed or 0 end", "" },
  { "renfort au-delà des places", "math.min((want or 0) - (have or 0), left or 0)", "(want or 0) - (have or 0)" },
  { "secours même avec l'électrique", "return (not elec_ok) and burner_ok and true or false", "return burner_ok and true or false" },
  { "retour sans objet au coffre", "(have_elec or 0) >= 1", "(have_elec or 0) >= 0" },
  { "réceptacle du plan ignoré", "if sink then return sink end", "" },
  { "secours tourné dans le mauvais sens", "local vx, vy = S.rotate(e.dir or 0, drop[1], drop[2])", "local vx, vy = drop[1], drop[2]" },
}
local refused = 0
for _, mu in ipairs(MUTANTS) do
  local a, b = SRC:find(mu[2], 1, true)
  if not a then
    fail = fail + 1 print("  ECHEC : mutant introuvable : " .. mu[1])
  else
    local M = load_rule(SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1))
    local caught = not M
    if M then
      local okc, _, b2 = pcall(suite, M)
      caught = (not okc) or #b2 > 0
    end
    if caught then refused = refused + 1 else fail = fail + 1 print("  ECHEC : mutant survivant : " .. mu[1]) end
  end
end
pass = pass + refused
print(string.format("[REBUILD-RAPIDE] mutants refusés : %d sur %d", refused, #MUTANTS))

---------------------------------------------------------------------------------------------------
-- 2. Relevé : la pièce tuée est rouverte dans les secondes qui suivent (et pas pendant l'attaque)
---------------------------------------------------------------------------------------------------
local R = require("shared.ai3.reglages")
check(R.REBUILD_SWEEP == true, "relevé allumé par défaut")
local PROTO = {
  drill = { type = "mining-drill" }, belt = { type = "transport-belt" }, asm = { type = "assembling-machine" },
  ["foreuse-e"] = { type = "mining-drill", items_to_place_this = { { name = "obj-foreuse-e" } } },
  ["foreuse-c"] = { type = "mining-drill", items_to_place_this = { { name = "obj-foreuse-c" } } },
}
game = { tick = 0, entity_prototypes = PROTO }
local Sweep = require("script.team.rebuild_sweep")
local Sw = require("shared.team.rebuild_sweep")

local present = {}
local enemy = nil
local surface = {
  count_entities_filtered = function(a) return present[a.position[1] .. "," .. a.position[2]] and 1 or 0 end,
  find_nearest_enemy = function(a)
    if enemy and math.abs(enemy.x - a.position.x) <= a.max_distance and math.abs(enemy.y - a.position.y) <= a.max_distance then return { valid = true } end
    return nil
  end,
}
local function team(name, n, gen)
  local q = { id = 1, state = "fini", ents = {}, spec = { gen = gen or "smelter" } }
  for i = 1, n do
    q.ents[i] = { name = "belt", x = i, y = 500, built = true, item = "item-belt" }
    present[i .. ",500"] = true
  end
  return { key = name, force = name, build = { order = { 1 }, projects = { [1] = q } } }, q
end

do
  -- Projet de 1 000 pièces : le curseur (Sw.SLICE par passe) mettait 10 passes pour revenir sur la pièce 900, puis 10 de plus.
  local f, q = team("scarlet", 1000)
  local fc, qc = team("temoin", 1000)
  for _, ff in ipairs({ f, fc }) do Sweep.step(ff, surface, 300) end
  present["900,500"] = nil
  check(Sweep.note_died(f, { x = 900, y = 500 }, 400) == true, "mort d'une pièce du plan : trouvée et inscrite")
  check(Sweep.note_died(f, { x = 9000, y = 500 }, 400) == false, "mort hors du plan : rien")
  local tick, reopened_at, temoin_at = 300, nil, nil
  for _ = 1, 20 do
    tick = tick + 300
    if Sweep.step(f, surface, tick) > 0 and not reopened_at then reopened_at = tick end
    if Sweep.step(fc, surface, tick) > 0 and not temoin_at then temoin_at = tick end
  end
  check(reopened_at and reopened_at - 400 <= Sw.CALM + 300, "liste chaude : rouverte au plus 15 s après sa mort (" .. tostring(reopened_at and (reopened_at - 400) / 60) .. " s)")
  check(not q.ents[900].built and q.state == "reserve", "pièce rouverte, projet en réserve")
  print(string.format("[REBUILD-RAPIDE] piece 900 sur 1000 : rouverte %.0f s apres sa mort avec la liste chaude, %s s avec le curseur seul",
    (reopened_at - 400) / 60, temoin_at and string.format("%.0f", (temoin_at - 400) / 60) or "plus de 100"))
  check(temoin_at == nil or temoin_at - 400 >= 5 * (reopened_at - 400), "témoin (curseur seul) : au moins 5 fois plus lent")
  check(logged("%[FO%-REBUILD%-RAPIDE%] scarlet : projet 1 %(smelter%), 1 piece%(s%) rouverte%(s%)") ~= nil, "journal : délai de détection et rang")
  check(#f.build.sweep.hot == 0, "pièce rouverte : sortie de la liste chaude")
  -- refaite : délai total au journal
  q.state, q.etat_next = "fini", 0
  Sweep.step(f, surface, tick + 300)
  check(logged("%[FO%-REBUILD%-RAPIDE%] scarlet : projet 1 %(smelter%) refait") ~= nil and q.rr_died == nil, "projet refini : délai total au journal")
end

do
  -- Pas pendant l'attaque : un ennemi sur place retient la pièce dans la liste chaude, elle est rouverte dès qu'il part.
  local f, q = team("azur", 50)
  Sweep.step(f, surface, 300)
  present["20,500"] = nil
  Sweep.note_died(f, { x = 20, y = 500 }, 400)
  enemy = { x = 25, y = 500 }
  local n = Sweep.step(f, surface, 400 + Sw.CALM + 10)
  check(n == 0 and q.ents[20].built and #f.build.sweep.hot == 1, "ennemi sur place : pas de réouverture, la pièce reste chaude")
  enemy = nil
  n = Sweep.step(f, surface, 400 + Sw.CALM + 310)
  check(n == 1 and not q.ents[20].built, "ennemi parti : rouverte à la passe suivante (5 s)")
  -- revenue en place avant la seconde vue : sort de la liste, rien rouvert
  local f2, q2 = team("emerald", 10)
  Sweep.step(f2, surface, 300)
  Sweep.note_died(f2, { x = 3, y = 500 }, 400)
  Sweep.step(f2, surface, 700)
  check(#f2.build.sweep.hot == 0 and q2.ents[3].built and q2.ents[3].miss == nil, "pièce revue en place : sortie de la liste chaude, rien rouvert")
end

do
  -- Relecture : une attaque massive tenue par l'ennemi ne coûte pas plus de Rr.HOT_PER_PASS lectures (liste chaude) par passe ; rotation.
  local Rr1 = require("shared.team.rebuild_rapide")
  local nk = Rr1.HOT_PER_PASS + 50
  local f, q = team("ambre", nk + Sw.SLICE + 10)
  Sweep.step(f, surface, 300)
  for i = 1, nk do present[i .. ",500"] = nil Sweep.note_died(f, { x = i, y = 500 }, 400) end
  enemy = { x = 1, y = 500 }
  local calls = 0
  local count0 = surface.count_entities_filtered
  surface.count_entities_filtered = function(a) calls = calls + 1 return count0(a) end
  -- curseur placé hors des pièces tuées (aucune lecture du curseur sur elles)
  f.build.sweep.pi, f.build.sweep.ei = 1, nk + 1
  Sweep.step(f, surface, 700)
  local hot_calls = calls - math.min(Sw.SLICE, #q.ents - nk)
  check(hot_calls <= Rr1.HOT_PER_PASS and #f.build.sweep.hot == nk, "liste chaude : au plus " .. Rr1.HOT_PER_PASS .. " lectures par passe (" .. hot_calls .. "), aucune pièce perdue")
  check(f.build.sweep.hot[1][2] == Rr1.HOT_PER_PASS + 1, "liste chaude : les pièces non relues passent en tête")
  enemy = nil
  local opened = 0
  for t = 1, 6 do opened = opened + Sweep.step(f, surface, 700 + Sw.CALM + 300 * t) end
  check(opened == nk and #f.build.sweep.hot == 0, "ennemi parti : toutes les pièces chaudes rouvertes (" .. opened .. " sur " .. nk .. ")")
  surface.count_entities_filtered = count0
end

---------------------------------------------------------------------------------------------------
-- 3. Foreuse thermique de secours (script/team/rebuild_rapide.lua)
---------------------------------------------------------------------------------------------------
local T = require("shared.team.config")
PROTO[T.DRILL_ELECTRIC] = { type = "mining-drill", items_to_place_this = { { name = T.DRILL_ELECTRIC } } }
PROTO[T.DRILL] = { type = "mining-drill", items_to_place_this = { { name = T.DRILL } } }
local added = {}
package.loaded["script.team.board"] = { add = function(_, tasks) for _, t in ipairs(tasks) do added[#added + 1] = t end return #tasks end }
local stock = {}
local mined = 0
package.loaded["script.team.stock"] = {
  count = function(_, item) return stock[item] or 0 end,
  inventories = function() return { { valid = true } } end,
}
local RrRt = require("script.team.rebuild_rapide")
local Rr = require("shared.team.rebuild_rapide")
local P = require("shared.team.plan")
local book
book = {
  handcraftable = function(_, item) return item == T.DRILL_ELECTRIC end,
  plan = function(_, list, avail)
    -- l'électrique demande une matière absente tant que `copper` est faux
    if list[1][1] == T.DRILL_ELECTRIC and not book.copper then return { raw = { cuivre = 1 }, uses = {}, crafts = {} } end
    return { raw = {}, uses = { [list[1][1]] = list[1][2] }, crafts = { { list[1][1], list[1][2] } } }
  end,
}
do
  local burner_ent = { valid = true, mine = function() mined = mined + 1 return true end }
  local gh_destroyed = 0
  local surf = {
    find_entities_filtered = function(a) return a.ghost_name and { { valid = true, destroy = function() gh_destroyed = gh_destroyed + 1 end } } or {} end,
    find_entity = function(name) return name == T.DRILL and burner_ent or nil end,
    find_nearest_enemy = function() return nil end,
  }
  local q = { id = 7, state = "chantier", reopened = 1, reopened_tick = 10, spec = { gen = "smelter" }, stock = {}, ents = {
    { name = T.DRILL_ELECTRIC, item = T.DRILL_ELECTRIC, x = 10.5, y = 10.5, dir = 0, built = false, ghosted = true },
    { name = "belt", item = "item-belt", x = 10.5, y = 8.5, dir = 0, built = true },
  } }
  local f = { key = "scarlet", force = "scarlet", hq = { valid = true, surface = surf }, build = { order = { 7 }, projects = { [7] = q }, sweep = {} } }
  P.declare_size("belt", 1, 1)
  local free = { [T.DRILL] = 2 }
  stock = { [T.DRILL] = 2 }
  local ns, nr = RrRt.drill_swap(f, book, free, 1000)
  local e = q.ents[1]
  check(ns == 1 and nr == 0 and e.name == T.DRILL and e.item == T.DRILL and e.subst and e.subst.name == T.DRILL_ELECTRIC,
    "sans cuivre : la foreuse électrique du projet rouvert devient une foreuse à combustion au plan")
  check(e.x == 11 and e.y == 10 and e.ghosted == false and gh_destroyed == 1, "posée dans l'ancienne emprise, dépôt sur le même tapis, ancien fantôme retiré")
  check(logged("%[FO%-REBUILD%-RAPIDE%] scarlet : projet 7 : foreuse electrique introuvable") ~= nil, "journal : substitution thermique")
  -- avec du cuivre : l'électrique est fabriquée, puis la pièce y revient quand l'objet est au coffre
  e.built = true
  q.state = "fini"
  book.copper = true
  added = {}
  RrRt.drill_swap(f, book, free, 2000)
  check(e.subst ~= nil and added[1] and added[1].item == T.DRILL_ELECTRIC and added[1].prio == Rr.PRIO_MAIN,
    "cuivre revenu : l'objet électrique est fabriqué, la foreuse à combustion produit en attendant")
  free[T.DRILL_ELECTRIC], stock[T.DRILL_ELECTRIC] = 1, 1
  ns, nr = RrRt.drill_swap(f, book, free, 3000)
  check(nr == 1 and mined == 1 and e.subst == nil and e.name == T.DRILL_ELECTRIC and e.x == 10.5 and e.y == 10.5 and not e.built,
    "objet électrique au coffre : foreuse à combustion reprise au coffre, la pièce électrique est rouverte à sa place")
  check(q.state == "reserve" and q.reopened == 2, "projet fini : rouvert par la règle du relevé")
  -- projet NEUF (pas une reconstruction) : jamais de substitution
  local q2 = { id = 8, state = "chantier", spec = { gen = "smelter" }, stock = {}, ents = {
    { name = T.DRILL_ELECTRIC, item = T.DRILL_ELECTRIC, x = 30.5, y = 10.5, dir = 0, built = false } } }
  local f2 = { key = "azur", force = "azur", hq = { valid = true, surface = surf }, build = { order = { 8 }, projects = { [8] = q2 }, sweep = {} } }
  book.copper = false
  RrRt.drill_swap(f2, book, { [T.DRILL] = 2 }, 1000)
  check(q2.ents[1].subst == nil and q2.ents[1].name == T.DRILL_ELECTRIC, "projet neuf : la foreuse électrique attend son objet (pas de substitution)")
end

---------------------------------------------------------------------------------------------------
-- 4. Front : cellule réattaquée chez une équipe riche (script/team/front.lua)
---------------------------------------------------------------------------------------------------
do
  local handlers = {}
  package.loaded["script.core.events"] = { on = function(id, fn) handlers[id] = fn end }
  defines = { events = { on_entity_died = 1 } }
  local team_f
  package.loaded["script.faction.state"] = {
    sorted_keys = function(t) local k = {} for key in next, t do k[#k + 1] = key end table.sort(k) return k end,
    owner = function() return nil end,
    faction = function() return nil end,
    by_force = function(fn) return fn == "scarlet" and team_f or nil end,
  }
  package.loaded["script.faction.outposts"] = { fortify_at = function() return 0 end }
  local Front = require("script.team.front")
  local died = handlers[1]
  check(died ~= nil, "le front s'abonne à on_entity_died")
  local surf = {
    find_entities_filtered = function() return {} end,
    count_entities_filtered = function() return 1 end,
    find_nearest_enemy = function() return nil end,
  }
  PROTO[T.turret] = { turret_range = 18 }
  team_f = { key = "scarlet", force = "scarlet", hq = { valid = true, surface = surf }, turrets = {}, hq_pos = { x = 0, y = 0 } }
  local function kill(x, y, tick)
    died({ entity = { valid = true, type = "transport-belt", force = { name = "scarlet", get_cease_fire = function() return false end },
      position = { x = x, y = y } }, force = { name = "enemy" }, tick = tick })
  end
  -- vague 1 : 3 tapis
  for i = 1, 3 do kill(100 + i, 100, 1000 + i) end
  stock = { [T.outposts.iron.product] = 8000, [T.outposts.copper.product] = 200 }
  game.tick = 1100
  local v1 = Front.view(team_f, {})
  local want1 = Fr.want(300)
  check(v1.pick and v1.pick.count == math.min(want1, Fr.BATCH), "une vague : règle du front (" .. tostring(v1.pick and v1.pick.count) .. " par voyage)")
  -- vague 2, après un calme
  kill(102, 101, 1000 + Rr.WAVE_GAP + 500)
  game.tick = 1000 + Rr.WAVE_GAP + 600
  local v2 = Front.view(team_f, {})
  check(v2.pick and v2.pick.want == math.min(Fr.CELL_CAP, Fr.want(400) + Rr.RICH_EXTRA) and v2.pick.count == v2.pick.want,
    "réattaquée chez une équipe riche : une tourelle de plus, tout le manque d'un coup (" .. tostring(v2.pick and v2.pick.count) .. ")")
  check(logged("%[FO%-REBUILD%-RAPIDE%] scarlet : cellule .- reattaquee %(2 vagues%)") ~= nil, "journal : cellule riche et réattaquée")
  stock = { [T.outposts.iron.product] = 100, [T.outposts.copper.product] = 200 }
  local v3 = Front.view(team_f, {})
  check(v3.pick and v3.pick.count == math.min(Fr.want(400), Fr.BATCH), "même cellule, équipe PAUVRE : la règle du front (2 par voyage)")
  -- plafond d'équipe atteint (16 tourelles du front ailleurs) : pauvre, rien ; riche, la cellule réattaquée est servie
  local owners_front = {}
  package.loaded["script.faction.state"].owner = function(u) return owners_front[u] end
  for i = 1, Fr.TEAM_CAP do
    team_f.turrets[i] = { valid = true, position = { x = 5000 + 50 * i, y = 5000 } }
    owners_front[i] = { oid = "front" .. i }
  end
  local v4 = Front.view(team_f, {})
  check(v4.pick == nil, "plafond d'équipe atteint, équipe pauvre : rien (règle du front)")
  stock = { [T.outposts.iron.product] = 8000, [T.outposts.copper.product] = 200 }
  local v5 = Front.view(team_f, {})
  check(v5.pick and v5.pick.count >= 1, "plafond d'équipe atteint, équipe RICHE : la cellule réattaquée reçoit ses tourelles (" .. tostring(v5.pick and v5.pick.count) .. ")")
end

---------------------------------------------------------------------------------------------------
-- 5. Branchements relus dans la source (lecteur de chaque état écrit)
---------------------------------------------------------------------------------------------------
local BUILD = read("script/team/build.lua")
do
  local r = BUILD:find("if reserve(f, p) then", 1, true)
  local g = r and BUILD:find("elseif Rr.partial_go(p) and not (p.spec.degel and not p.degele) then", r, true)
  local m = g and BUILD:find('p.reason, p.reserve_next = "materiaux", tick + 60', g, true)
  check(r and g and m and r < g and g < m, "build.lua : un projet rouvert repart sans toute sa matière (après la réserve, avant l'attente « materiaux »)")
end
check(BUILD:find("prio = Rr.project_prio(p, finish_prio(p.prio))", 1, true) ~= nil, "build.lua : tâches d'un projet rouvert à leur rang")
check(BUILD:find("if not free or Rr.batch_ready(bt.main, have) then", 1, true) ~= nil and BUILD:find("batch_tasks(f, p, tasks, free_of)", 1, true) ~= nil,
  "build.lua : un lot d'un projet rouvert sans aucun objet au coffre n'envoie pas de PNJ")
check(read("script/team/rebuild_sweep.lua"):find("Rr.hot_set_list(st, Rr.hot_next(later, keep))", 1, true) ~= nil, "rebuild_sweep.lua : budget et rotation de la liste chaude")
check(BUILD:find("if e.subst then bump(need, T.fuel, Rr.SUBST_FUEL) end", 1, true) ~= nil
  and BUILD:find("if e.subst then bump(bt.items, T.fuel, Rr.SUBST_FUEL) end", 1, true) ~= nil
  and BUILD:find("if e.subst and inv.get_item_count(T.fuel) >= 1 then", 1, true) ~= nil, "build.lua : combustible réservé, porté et mis dans la foreuse de secours")
local RECON = read("script/team/reconstruction.lua")
check(RECON:find("Sweep.note_died(f, pos, e.tick)", 1, true) ~= nil, "reconstruction.lua : la mort d'une pièce du plan entre dans la liste chaude")
check(RECON:find("prio = Rr.registry_prio(batch[1], Rc.task_prio(batch[1].value))", 1, true) ~= nil, "reconstruction.lua : registre à son rang")
check(RECON:find("RrRt.drill_swap(f, book, free, tick)", 1, true) ~= nil, "reconstruction.lua : foreuse de secours à chaque pensée")
for _, file in ipairs({ "shared/team/rebuild_rapide.lua", "script/team/rebuild_rapide.lua" }) do
  local src = read(file)
  local inside = false
  for line in src:gmatch("[^\n]+") do
    if line:find("^%s*function") or line:find("^%s*local function") then inside = true end
    if inside and line:find("require%(") and not line:find("^local") then check(false, file .. " : require hors du chargement : " .. line) end
  end
  check(not src:find("global%."), file .. " : jamais global")
  check(not src:find("[^i]pairs%("), file .. " : aucun pairs (clés triées)")
end

print(string.format("[REBUILD-RAPIDE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
