--[[
  Lot C1-COUT (CHANTIER 1 du DC, 15/11) : test hors jeu.
  Partie 0.9.4 du DC : la bande -18 du champ de fer a demandé 216 tapis rapides (fast-transport-belt 216/216), le chantier a attendu
  21,8 min sans rien poser ; la cause : `belt_for` (shared/team/champ.lua) prenait le plus lent tapis qui porte les foreuses du groupe
  sur une voie, donc le tapis rapide au-delà de ~15 foreuses par côté.

    §1 plan de champ : TOUS les tapis et souterrains des bandes (et de leur fonderie en colonne) sont du tapis de BASE (premier de
       spec.belts) même quand l'ancienne règle aurait pris un tapis plus rapide ; le contrôle (Cv.verify) compte ces voies à part
       (rep.saturated, règle du DC), sans « débit court » ; cadre figé : même règle ;
    §2 verrou des améliorations (shared/team/verrou_gisements.lua) : grand gisement par minerai, 80 % (R.COVER_HIGH), verdict « plein »,
       danger, petits gisements, minerais hors champs, déterminisme ;
    §3 remplacements du capital (Cap.replace_candidates) : ctx.rang_hold retire les tapis et les bras (rang) HORS zone Maj + Z ; la zone
       du joueur et les autres machines restent ;
    §4 branchements runtime (Vgr.hold sur relevé simulé, et les trois portes : Conv.step, Capital, rétrofit des bras) ;
    §5 MUTANTS : chaque coupe retirée (texte du module modifié puis rechargé) est vue.
  Usage : lua5.2 tests/c1_cout_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[C1-COUT] ECHEC : " .. msg) end
  return cond
end
local function say(s) print("[C1-COUT] " .. s) end
local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
--- Recharge le module `name` (chemin `path`) avec `old` remplacé par `new` (une seule occurrence exigée). Rend le module muté.
local function mutant(name, path, old, new)
  local src = read(path)
  local i, j = src:find(old, 1, true)
  assert(i, "mutant : motif introuvable dans " .. path)
  assert(not src:find(old, j + 1, true), "mutant : motif en double dans " .. path)
  local saved = package.loaded[name]
  local m = assert(load(src:sub(1, i - 1) .. new .. src:sub(j + 1), "=" .. name .. "-mutant", "t"))()
  package.loaded[name] = saved
  return m
end

---------------------------------------------------------------------------------------------------
-- §1 Plan de champ : tapis de base
---------------------------------------------------------------------------------------------------
local Ch = require("shared.team.champ")
local Cv = require("shared.team.champ_verif")

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function rect(x0, y0, w, h)
  local out = {}
  for x = x0, x0 + w - 1 do for y = y0, y0 + h - 1 do out[#out + 1] = x; out[#out + 1] = y end end
  return out
end
local function spec_of(ore, frame)
  return { ore = ore, blocked = {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = { size = 2, rate = 0.3125, fuel = true }, inserter = { rate = 0.83 },
    target = { x = 1000, y = 0 }, design = "colonne", frame = frame }
end

--- Indice du tapis que l'ANCIENNE règle aurait pris (le plus lent qui porte le groupe sur une voie).
local function old_index(sp, p, g)
  local need = p.fuelled and g.drills or g.per_side
  for i, bt in ipairs(sp.belts) do if Ch.lane_drills(bt.lane, sp.drill.rate) >= need then return i end end
  return #sp.belts
end

local function judge_plan(C, label)
  local ore = rect(0, 0, 120, 40)
  local sp = spec_of(ore)
  local p, why = C.plan(sp)
  if not check(p ~= nil, label .. " : plan rendu (" .. tostring(why) .. ")") then return false end
  local groups, faster, not_base = 0, 0, 0
  for _, bd in ipairs(p.bands) do
    for _, g in ipairs(bd.groups) do
      groups = groups + 1
      if old_index(sp, p, g) > 1 then faster = faster + 1 end
      if g.belt ~= 1 then not_base = not_base + 1 end
    end
  end
  local belts, wrong = 0, 0
  for _, e in ipairs(p.ents) do
    if (e.kind == "tapis" or e.kind == "souterrain") and e.belt ~= nil then
      belts = belts + 1
      if e.belt ~= 1 then wrong = wrong + 1 end
    end
  end
  say(string.format("%s : %d groupe(s), %d que l'ancienne regle aurait mis au tapis rapide, %d tapis/souterrains, %d hors base",
    label, groups, faster, belts, wrong))
  local ok = check(faster > 0, label .. " : le cas du DC est reproduit (groupes au-delà du tapis de base : " .. faster .. ")")
  ok = check(not_base == 0, label .. " : chaque groupe au tapis de base (" .. not_base .. " hors base)") and ok
  ok = check(belts > 0 and wrong == 0, label .. " : chaque tapis et souterrain des bandes au tapis de base (" .. wrong .. "/" .. belts .. ")") and ok
  return ok, p, sp
end

say("§1 plan de champ")
local ok1, p1, sp1 = judge_plan(Ch, "champ 120 x 40, trois tapis")
if p1 then
  local rep = Cv.verify(p1, sp1)
  check(rep.starved == 0, "§1 contrôle : aucun débit court (" .. rep.starved .. ")")
  check((rep.saturated or 0) > 0, "§1 contrôle : voies au tapis de base comptées à part (" .. tostring(rep.saturated) .. ")")
  check(p1.belt_rule == "base", "§1 le plan déclare la règle du tapis de base")
  -- cadre figé (une bande seule) : même règle
  local fr = {}
  for k, v in pairs(p1.frame) do fr[k] = v end
  fr.only = { [p1.bands[1].pr] = true }
  local pf = Ch.plan(spec_of(rect(0, 0, 120, 40), fr))
  local bad = 0
  for _, e in ipairs(pf and pf.ents or {}) do if (e.kind == "tapis" or e.kind == "souterrain") and e.belt and e.belt ~= 1 then bad = bad + 1 end end
  check(pf ~= nil and bad == 0, "§1 cadre figé : bande replanifiée au tapis de base (" .. bad .. " hors base)")
  -- déterminisme
  local p2 = Ch.plan(spec_of(rect(0, 0, 120, 40)))
  local same = p2 and #p2.ents == #p1.ents
  if same then for i, e in ipairs(p1.ents) do local f = p2.ents[i]; if e.kind ~= f.kind or e.x ~= f.x or e.y ~= f.y or e.belt ~= f.belt then same = false end end end
  check(same, "§1 déterminisme : même plan deux fois")
end

---------------------------------------------------------------------------------------------------
-- §2 Verrou des améliorations (règle pure)
---------------------------------------------------------------------------------------------------
say("§2 verrou des grands gisements")
local Vg = require("shared.team.verrou_gisements")
local BIG = { fer = true, cuivre = true, charbon = true } -- noms de test (le runtime lit les données)
local function deps(list)
  local t = {}
  for _, d in ipairs(list) do t[d.id] = d end
  return t
end
local function run_vg(V)
  local res = {}
  local h, why = V.hold(deps({
    { id = 1, resource = "fer", tiles = 2000, covered = 1700 },
    { id = 2, resource = "fer", tiles = 400, covered = 0 }, -- pas le plus grand du fer : ignoré
    { id = 3, resource = "cuivre", tiles = 1000, covered = 900 },
    { id = 4, resource = "charbon", tiles = 900, covered = 300 }, -- 33 % : retient
    { id = 5, resource = "pierre", tiles = 5000, covered = 0 }, -- minerai hors champs
  }), BIG, { small = 300 })
  res.short = h
  res.why = why
  res.full = V.hold(deps({ { id = 4, resource = "charbon", tiles = 900, covered = 300, full = true } }), BIG, { small = 300 })
  res.covered = V.hold(deps({ { id = 1, resource = "fer", tiles = 2000, covered = 1600 }, { id = 3, resource = "cuivre", tiles = 1000, covered = 800 } }), BIG, { small = 300 })
  res.edge = V.hold(deps({ { id = 1, resource = "fer", tiles = 2000, covered = 1599 } }), BIG, { small = 300 })
  res.small = V.hold(deps({ { id = 6, resource = "fer", tiles = 300, covered = 0 } }), BIG, { small = 300 })
  res.danger = V.hold(deps({ { id = 7, resource = "fer", tiles = 3000, covered = 0, danger = true } }), BIG, { small = 300 })
  res.nilcov = V.hold(deps({ { id = 8, resource = "cuivre", tiles = 800 } }), BIG, { small = 300 })
  res.empty = V.hold({}, BIG, { small = 300 })
  res.biggest = V.hold(deps({ { id = 9, resource = "fer", tiles = 3000, covered = 2900 }, { id = 10, resource = "fer", tiles = 2999, covered = 0 } }), BIG, { small = 300 })
  return res
end
local function judge_vg(r, tag)
  local ok = check(r.short == true, tag .. "charbon à 33 % : retenu")
  ok = check(type(r.why) == "string" and r.why:find("charbon 300/900", 1, true) ~= nil, tag .. "la cause nomme le gisement retenu (" .. tostring(r.why) .. ")") and ok
  ok = check(r.full == false, tag .. "gisement « plein » (plus de place) : permis") and ok
  ok = check(r.covered == false, tag .. "fer et cuivre à 80 % : permis") and ok
  ok = check(r.edge == true, tag .. "fer à 79,95 % : retenu") and ok
  ok = check(r.small == false, tag .. "petit gisement (au plus Ca.GIANT_SMALL tuiles) : ignoré") and ok
  ok = check(r.danger == false, tag .. "gisement en danger : ignoré (pas accessible)") and ok
  ok = check(r.nilcov == true, tag .. "couverture pas encore relue : retenu") and ok
  ok = check(r.empty == false, tag .. "aucun gisement recensé : permis") and ok
  ok = check(r.biggest == false, tag .. "seul le plus grand gisement d'un minerai est jugé") and ok
  return ok
end
judge_vg(run_vg(Vg), "§2 ")

---------------------------------------------------------------------------------------------------
-- §3 Remplacements du capital
---------------------------------------------------------------------------------------------------
say("§3 remplacements du capital")
local L = require("shared.levels.config")
local Cap = require("shared.ai3.capital")
local MP = {
  ta = { type = "transport-belt", group = "belt", w = 1, h = 1, energy = "none", cats = {}, speed = 0.03, item = "ia", rang = true },
  tb = { type = "transport-belt", group = "belt", w = 1, h = 1, energy = "none", cats = {}, speed = 0.06, item = "ib", rang = true },
  b1 = { type = "inserter", group = "ins", w = 1, h = 1, energy = "electric", cats = {}, speed = 0.014, item = "j1", reach = "r", rang = true },
  b2 = { type = "inserter", group = "ins", w = 1, h = 1, energy = "electric", cats = {}, speed = 0.04, item = "j2", reach = "r", rang = true },
  f1 = { type = "furnace", group = "fur", w = 2, h = 2, energy = "burner", cats = {}, speed = 1, item = "k1" },
  f2 = { type = "furnace", group = "fur", w = 2, h = 2, energy = "burner", cats = {}, speed = 2, item = "k2" },
}
local CC = L.by_key.command
local function census()
  local c = { list = {}, center = { id = 1, name = L.name(CC, 1) }, machines = {} }
  local id = 10
  for _, n in ipairs({ "ta", "b1", "f1" }) do
    for i = 1, 4 do id = id + 1; c.machines[#c.machines + 1] = { id = id, name = n, working = true, block = "p1", x = 100 + i, y = 0 } end
    for i = 1, 3 do id = id + 1; c.machines[#c.machines + 1] = { id = id, name = n, working = true, block = "p1", x = i, y = 0 } end -- dans la zone
  end
  return c
end
local function ctx(hold)
  return { mproto = function(n) return MP[n] end, machines = { "ta", "tb", "b1", "b2", "f1", "f2" }, proto = function() return nil end,
    stock = { ib = 50, j2 = 50, k2 = 50 }, unit_cost = function() return 3 end, weights = {}, cc_level = 3,
    zones = { { x = 2, y = 0, r = 3 } }, rang_hold = hold }
end
local function kinds(C, hold)
  local rc = C.replace_candidates(L, census(), ctx(hold))
  local out = { zone = {}, free = {} }
  for _, c in ipairs(rc) do
    local t = c.zone and out.zone or out.free
    t[c.replace.from] = (t[c.replace.from] or 0) + c.replace.n
  end
  return out
end
local function judge_cap(C, tag)
  local open, held = kinds(C, false), kinds(C, true)
  local ok = check(open.free.ta == 4 and open.free.b1 == 4 and open.free.f1 == 4, tag .. "sans verrou : tapis, bras et fours hors zone candidats")
  ok = check(held.free.ta == nil and held.free.b1 == nil, tag .. "verrou : aucun tapis ni bras hors zone (" .. tostring(held.free.ta) .. ", " .. tostring(held.free.b1) .. ")") and ok
  ok = check(held.free.f1 == 4, tag .. "verrou : les fours restent candidats") and ok
  ok = check(held.zone.ta == 3 and held.zone.b1 == 3, tag .. "verrou : la zone Maj + Z du joueur n'est pas retenue") and ok
  return ok
end
judge_cap(Cap, "§3 ")

---------------------------------------------------------------------------------------------------
-- §4 Branchements runtime
---------------------------------------------------------------------------------------------------
say("§4 branchements runtime")
do
  local logs = {}
  _G.log = function(s) logs[#logs + 1] = s end
  _G.game = { tick = 36000, entity_prototypes = { ["stone-furnace"] = { type = "furnace" }, ["iron-chest"] = { type = "container" } } }
  package.loaded["script.team.verrou_gisements"] = nil
  local Vgr = require("script.team.verrou_gisements")
  local T = require("shared.team.config")
  local f = { key = "player", team = { capi = { deps = {} } } }
  local o = T.outposts
  -- un grand gisement de chaque minerai des champs, 10 % couvert ; un minerai dont le puits n'est pas un four ni le combustible : ignoré
  local id = 0
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    id = id + 1
    f.team.capi.deps[id] = { id = id, resource = o[kind].resource, tiles = 1000, covered = 100 }
  end
  local h = Vgr.hold(f)
  check(h == true and #logs == 1 and logs[1]:find("[FO-VERROU-GISEMENTS]", 1, true) ~= nil, "§4 relevé à 10 % : retenu, une ligne au journal")
  Vgr.hold(f)
  check(#logs == 1, "§4 journal seulement au changement d'état")
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local oo = o[kind]
    local fp = game.entity_prototypes[oo.sink]
    local d
    for _, x in pairs(f.team.capi.deps) do if x.resource == oo.resource then d = x end end
    if (fp and fp.type == "furnace") or oo.resource == T.fuel then d.covered = 800 end
  end
  local h2, why2 = Vgr.hold(f)
  check(h2 == false and #logs == 2, "§4 minerais des champs couverts à 80 % (le minerai à coffre ignoré) : permis (" .. tostring(why2) .. ")")
  check(Vgr.hold({ key = "x", team = {} }) == false, "§4 équipe sans relevé : pas retenue")
  _G.game, _G.log = nil, nil
  -- portes : chaque améliorateur automatique lit le verrou ; l'ordre explicite (zone) passe
  local b = read("script/team/build.lua")
  check(b:find("Vgr.hold(f)", 1, true) ~= nil and b:find("Conv.step(f, surface, tick)", 1, true) ~= nil, "§4 build.lua : Conv.step derrière le verrou")
  local c = read("script/ai3/capital.lua")
  check(c:find("rang_hold = ", 1, true) ~= nil, "§4 capital.lua : ctx.rang_hold posé")
  check(c:find("not zone and Capital.rang_held(f, d.replace)", 1, true) ~= nil, "§4 capital.lua : AMELIO-CONTINUE retient un tapis ou un bras hors zone")
  local r = read("script/team/box_upgrade_rt.lua")
  check(r:find("arms_held", 1, true) ~= nil, "§4 box_upgrade_rt.lua : bras du rétrofit retenus")
end

---------------------------------------------------------------------------------------------------
-- §6 Lot n099-amelio (retour du DC sur la 0.9.8 : « pas de phase d'amélioration massive, qui devrait être automatique une fois que le
-- budget le permet ») : banc N098-INT2, graine 4251870853, carte à 600 % : le verrou a tenu de 1,7 à 90 min pour les cinq équipes
-- (tapis montés 0/220 chez azure à 88,8 min, logistics-2 fini à 20,4 min) parce qu'aucun gisement de 2000 à 5000 tuiles n'atteint
-- 80 % en 90 min, alors que la pose n'attendait jamais le budget (1 refus « budget » dans la partie, épargne de 30 000 MU et plus).
-- Règle : un grand gisement court ne retient que si sa pose ATTEND LE BUDGET (d.budget_ok faux ou absent : la dernière décision de la
-- capitalisation a refusé couvrir:/ouvrir: de ce gisement pour le budget, ou pas encore de décision).
---------------------------------------------------------------------------------------------------
say("§6 verrou levé quand la pose n'attend pas le budget")
local function run_amelio(V)
  local r = {}
  -- relevé d'azure à 88,8 min (journal [FO-CAPI-COUV] de N098-INT2) ; le cuivre 4974 n'a jamais été ouvert
  local azure = {
    { id = 11, resource = "fer", tiles = 3052, covered = 871, budget_ok = true },
    { id = 12, resource = "cuivre", tiles = 4974, covered = 0, budget_ok = true },
    { id = 13, resource = "charbon", tiles = 2991, covered = 508, budget_ok = true },
  }
  r.paid = V.hold(deps(azure), BIG, { small = 300 })
  azure[2].budget_ok = nil -- la pose du cuivre attend le budget
  local h, why = V.hold(deps(azure), BIG, { small = 300 })
  r.waiting, r.why = h, why
  azure[2].budget_ok = false
  r.waiting_false = V.hold(deps(azure), BIG, { small = 300 })
  -- un petit gisement qui attend le budget ne retient pas (seul le plus grand de chaque minerai est jugé)
  r.small_wait = V.hold(deps({ { id = 14, resource = "fer", tiles = 3052, covered = 871, budget_ok = true },
    { id = 15, resource = "fer", tiles = 900, covered = 0 } }), BIG, { small = 300 })
  return r
end
local function judge_amelio(r, tag)
  local ok = check(r.paid == false, tag .. "grands gisements courts dont la pose est payée : permis (montée massive des tapis et des bras)")
  ok = check(r.waiting == true, tag .. "pose du cuivre 0/4974 en attente du budget : retenu") and ok
  ok = check(type(r.why) == "string" and r.why:find("cuivre 0/4974", 1, true) ~= nil and r.why:find("fer", 1, true) == nil,
    tag .. "la cause ne nomme que le gisement qui attend (" .. tostring(r.why) .. ")") and ok
  ok = check(r.waiting_false == true, tag .. "budget_ok = false : retenu") and ok
  ok = check(r.small_wait == false, tag .. "petit gisement en attente, grand payé : permis") and ok
  return ok
end
judge_amelio(run_amelio(Vg), "§6 ")
do -- le producteur du drapeau : la capitalisation marque le refus pour le budget et le recopie sur les gisements recensés
  local sh = read("shared/ai3/capitalisation.lua")
  check(sh:find("ctx.refus[o.key].budget = true", 1, true) ~= nil, "§6 shared capitalisation : refus pour le budget marqué (budget = true)")
  local rt = read("script/ai3/capitalisation.lua")
  check(rt:find("d.budget_ok = not starved[", 1, true) ~= nil, "§6 script capitalisation : budget_ok posé sur chaque gisement recensé")
  check(rt:find("budget_ok = (old and old.budget_ok)", 1, true) ~= nil, "§6 script capitalisation : budget_ok gardé au recensement (pas de bascule)")
end

-- §5 Mutants
---------------------------------------------------------------------------------------------------
say("§5 mutants")
local function quiet(fn)
  local p0, f0 = pass, fail
  local saved_print = print
  print = function() end
  local ok = fn()
  print = saved_print
  pass, fail = p0, f0
  return ok
end
do -- coupe 1 retirée : l'ancienne règle du tapis (le plus lent qui porte le groupe)
  local M = mutant("shared.team.champ", "shared/team/champ.lua", "return 1 -- C1-COUT : tapis de base",
    "local spec = s.spec; local need_lane = s.fuelled and (#g.n + #g.s) or math.max(#g.n, #g.s); for i, bt in ipairs(spec.belts) do if Ch.lane_drills(bt.lane, spec.drill.rate) >= need_lane then return i end end; return #spec.belts")
  check(not quiet(function() return judge_plan(M, "mutant") end), "§5 mutant « ancienne règle du tapis » vu")
end
do -- coupe 2 : le seuil de couverture ignoré
  local M = mutant("shared.team.verrou_gisements", "shared/team/verrou_gisements.lua", "covered < cover * tiles", "covered < 0")
  check(not quiet(function() return judge_vg(run_vg(M), "") end), "§5 mutant « seuil de 80 % ignoré » vu")
  local M2 = mutant("shared.team.verrou_gisements", "shared/team/verrou_gisements.lua", "(d.tiles or 0) > (b.tiles or 0)", "(d.tiles or 0) < (b.tiles or 0)")
  check(not quiet(function() return judge_vg(run_vg(M2), "") end), "§5 mutant « plus petit gisement jugé » vu")
end
do -- lot n099-amelio : l'attente du budget ignorée (règle d'avant : la seule couverture retient)
  local M = mutant("shared.team.verrou_gisements", "shared/team/verrou_gisements.lua", "and not d.budget_ok", "")
  check(not quiet(function() return judge_amelio(run_amelio(M), "") end), "§5 mutant « attente du budget ignorée » vu")
end
do -- coupe 3 : le verrou du capital retiré
  local M = mutant("shared.ai3.capital", "shared/ai3/capital.lua", "if ctx.rang_hold then", "if false then")
  check(not quiet(function() return judge_cap(M, "") end), "§5 mutant « verrou du capital retiré » vu")
  local M2 = mutant("shared.ai3.capital", "shared/ai3/capital.lua",
    "if not (p and p.rang) or (has_zones and Co.upgrade_rank(ctx.zones, m.x, m.y) == 0) then kept[#kept + 1] = m end",
    "if not (p and p.rang) then kept[#kept + 1] = m end")
  check(not quiet(function() return judge_cap(M2, "") end), "§5 mutant « zone Maj + Z retenue aussi » vu")
end

print(string.format("[C1-COUT] Resultat : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
