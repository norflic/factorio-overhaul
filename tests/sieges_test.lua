--[[
  Lot VIDEO-SIEGES (C4 et C5 de fo-logs/2026-11-07_VIDEO-COUVERTURE/DIAG_CONSO.md, §1 M3 et M5, §3). Règles 9 et 10 de
  shared/ai3/emplacements.lua et leur branchement (script/ai3/capitalisation.lua : Capi.slots, Capi.arbitre).
  Partie du DC (minute 256) : 5 emplacements sur 5 tenus par des modules « en réserve » qui s'affament (48 annulations en 4 h 16), les
  cinq chaînes manquent toutes des mêmes assembleurs 2, le siège va aux pignons et aux courroies alors que les circuits débloqueraient.
  CRITÈRES (écrits avant le code) :
    S4.1 un module en réserve dont rien n'avance depuis Em.STALL (10 min) libère son emplacement, comme un module figé ; un tick
         de moins, non ; un manque qui BAISSE ou un changement d'états est un progrès (l'horloge repart) ; sans horloge (sauvegarde
         d'avant) la règle 1 reste ; au plus Em.STALLED_FREE hors du compte ;
    S4.2 Capi.slots (moteur simulé) lit le manque des modules en réserve et pose l'horloge ;
    S5.1 deux chaînes dont les manques d'ouverture se recoupent à plus de 50 % (coefficient de recouvrement) ne s'ouvrent pas ensemble :
         ni avec une chaîne ouverte, ni avec une chaîne de la même décision ; exactement 50 % passe ; ni une extraction ni des packs ;
    S5.2 le siège va d'abord au produit qui débloque le manque, puis au moins couvert, puis à l'ordre rendu ; seules les places des
         ordres « module » changent (Capi.arbitre) ;
    S5.3 la partie du DC : cinq chaînes, des assembleurs 2 qui manquent à toutes : aucune ne s'ouvre à côté des ouvertes ; neuves, une
         seule, les circuits (le moins couvert) ;
    S5.4 déterminisme, 14 mutants refusés.
  Usage : lua5.2 tests/sieges_test.lua   (depuis la racine du mod ; environ 10 s)
]]
package.path = "./?.lua;" .. package.path
local Em0 = require("shared.ai3.emplacements")

local pass, fail, quiet = 0, 0, false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[SIEGES] ECHEC : " .. msg) end
  end
end
local MIN = 3600

local function set(...)
  local t = {}
  for _, k in ipairs({ ... }) do t[k] = true end
  return t
end
local function keys_of(l)
  local t = {}
  for _, c in ipairs(l) do t[#t + 1] = c.key or c end
  return table.concat(t, ",")
end

local function pure(Em)
  local p0, f0 = pass, fail
  local T = 100 * MIN
  -- S4.1 horloge de la matière
  local t, n, s = Em.mat_tick(nil, nil, nil, { "reserve" }, 10, T)
  check(t == T and n == 10 and s == "reserve", "S4.1 premier tick en matière : l'horloge démarre")
  local t2 = Em.mat_tick(t, n, s, { "reserve" }, 10, T + 5 * MIN)
  check(t2 == T, "S4.1 rien n'avance : l'horloge ne bouge pas")
  local t3 = Em.mat_tick(t, n, s, { "reserve" }, 12, T + 5 * MIN)
  check(t3 == T, "S4.1 un manque qui GRANDIT n'est pas un progrès")
  local t4 = Em.mat_tick(t, n, s, { "reserve" }, 7, T + 5 * MIN)
  check(t4 == T + 5 * MIN, "S4.1 un manque qui BAISSE est un progrès : l'horloge repart")
  local t5 = Em.mat_tick(t, n, s, { "plan" }, 10, T + 5 * MIN)
  check(t5 == T + 5 * MIN, "S4.1 un changement d'état (plan -> réserve) est un progrès")
  check(Em.mat_tick(t, n, s, { "chantier" }, 0, T + 5 * MIN) == nil, "S4.1 hors matière (chantier) : pas d'horloge")
  -- classe
  local function mod(states, mat, pile) return { key = "a", states = states, progress_tick = 0, opened = 0, mat_tick = mat, pile_tick = pile } end
  check(Em.class(mod({ "reserve" }, T - 10 * MIN), T) == "fige", "S4.1 réserve sans progrès depuis 10 min : figée")
  check(Em.class(mod({ "reserve" }, T - 10 * MIN + 1), T) == "matiere", "S4.1 un tick de moins : elle tient son emplacement")
  check(Em.class(mod({ "reserve" }, nil), T) == "matiere", "S4.1 sans horloge (sauvegarde d'avant) : règle 1, elle tient son emplacement")
  check(Em.class(mod({ "attente" }, T - 30 * MIN), T) == "fige", "S4.1 un module jamais planifié depuis 30 min : figé aussi")
  check(Em.class(mod({ "reserve" }, T - 30 * MIN, T - 6 * MIN), T) == "pile", "S4.1 la suspension par la pile passe avant")
  local building = mod({ "chantier" }, T - 30 * MIN)
  building.progress_tick = T - MIN
  check(Em.class(building, T) == "actif", "S4.1 l'horloge de matière ne concerne pas un chantier qui avance")
  -- emplacements : trois réserves bloquées
  local mods = { mod({ "reserve" }, T - 12 * MIN), mod({ "reserve" }, T - 12 * MIN), mod({ "reserve" }, T - 12 * MIN) }
  mods[1].key, mods[2].key, mods[3].key = "m1", "m2", "m3"
  local sl = Em.slots({ base = 3, plates = {}, mods = mods, tick = T })
  check(sl.free_stalled == Em.STALLED_FREE and sl.counted == 1 and sl.room == 2 and not sl.busy,
    "S4.1 3 réserves bloquées : 2 hors du compte (au plus Em.STALLED_FREE), 1 compte, 2 places libres (" .. sl.why .. ")")
  local fresh = {}
  for i = 1, 3 do fresh[i] = mod({ "reserve" }, T - 2 * MIN) fresh[i].key = "f" .. i end
  local sl2 = Em.slots({ base = 3, plates = {}, mods = fresh, tick = T })
  check(sl2.counted == 3 and sl2.busy and sl2.free_stalled == 0, "S4.1 3 réserves récentes : elles tiennent les 3 places")

  -- S5.1 recouvrement
  check(Em.overlap(set("a", "b"), set("a", "b", "c")) == 100, "S5.1 le petit ensemble est dans le grand : 100 %")
  check(Em.overlap(set("a", "b"), set("a", "x")) == 50, "S5.1 un sur deux : 50 %")
  check(Em.overlap(set("a"), set("x")) == 0 and Em.overlap({}, set("a")) == 0 and Em.overlap(nil, nil) == 0, "S5.1 disjoints ou vides : 0")
  local function ch(key, miss, extra)
    local c = { key = key, kind = "chaine", miss = miss }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
  end
  local open = { { key = "open1", miss = set("am2", "belt") } }
  local _, ref = Em.arbitrate({ ch("c1", set("am2")) }, open)
  check(ref.c1 and ref.c1:find("open1", 1, true), "S5.1 une chaîne qui manque des mêmes assembleurs que l'ouverte n'ouvre pas")
  local _, ref2 = Em.arbitrate({ ch("c1", set("am2", "x")) }, { { key = "o", miss = set("am2", "y") } })
  check(next(ref2) == nil, "S5.1 exactement 50 % passe (la borne est stricte)")
  local _, ref3 = Em.arbitrate({ ch("c1", set("am2", "x", "z")) }, { { key = "o", miss = set("am2", "y", "z") } })
  check(ref3.c1 ~= nil, "S5.1 deux sur trois (67 %) : refusée")
  local _, ref4 = Em.arbitrate({ ch("c1", set("am2")), ch("c2", set("am2")) }, {})
  check(ref4.c2 ~= nil and ref4.c1 == nil, "S5.1 deux chaînes neuves du même manque : une seule (la première en siège)")
  local _, ref5 = Em.arbitrate({ { key = "e", kind = "couvrir", miss = set("am2") }, { key = "p", kind = "packs", miss = set("am2") } }, open)
  check(next(ref5) == nil, "S5.1 une extraction ou des packs ne sont jamais refusés par le recoupement")
  local _, ref6 = Em.arbitrate({ ch("c1", {}) }, open)
  check(next(ref6) == nil, "S5.1 aucun manque d'ouverture : rien à recouper")
  local _, ref7 = Em.arbitrate({ ch("c1", set("x")) }, open)
  check(next(ref7) == nil, "S5.1 manques disjoints : elle ouvre")

  -- S5.2 ordre des sièges
  local keys, _, sorted = Em.arbitrate({
    { key = "a", kind = "couvrir", miss = {}, unblocks = false, theta = 0.2 },
    { key = "b", kind = "chaine", miss = {}, unblocks = false, theta = 0.9 },
    { key = "c", kind = "packs", miss = {}, unblocks = true, theta = 1.5 },
    { key = "d", kind = "chaine", miss = {}, unblocks = true, theta = 0.4 },
    { key = "e", kind = "chaine", miss = {}, unblocks = false } }, {})
  check(keys_of(sorted) == "d,c,a,b,e" and table.concat(keys, ",") == "d,c,a,b,e",
    "S5.2 celui qui débloque d'abord, le moins couvert d'abord, sans mesure en dernier (" .. keys_of(sorted) .. ")")
  local _, _, s2 = Em.arbitrate({ { key = "x", kind = "chaine", miss = {}, theta = 0.5 }, { key = "y", kind = "chaine", miss = {}, theta = 0.5 } }, {})
  check(keys_of(s2) == "x,y", "S5.2 à égalité : l'ordre rendu")

  -- S5.3 la partie du DC
  local am2 = set("assembling-machine-2")
  local dc = {
    ch("chaine:iron-gear-wheel", am2, { theta = 0.9, unblocks = true }),
    ch("chaine:transport-belt", am2, { theta = 1.1, unblocks = true }),
    ch("chaine:electronic-circuit", am2, { theta = 0.487, unblocks = true }) }
  local k1, r1 = Em.arbitrate(dc, { { key = "chaine:inserter", miss = set("assembling-machine-2", "transport-belt") } })
  check(#k1 == 0 and r1["chaine:electronic-circuit"] and r1["chaine:iron-gear-wheel"] and r1["chaine:transport-belt"],
    "S5.3 des chaînes sont ouvertes et manquent des mêmes assembleurs 2 : aucune ne s'ouvre")
  local k2, r2, s3 = Em.arbitrate(dc, {})
  check(table.concat(k2, ",") == "chaine:electronic-circuit" and r2["chaine:iron-gear-wheel"] and r2["chaine:transport-belt"],
    "S5.3 neuves : une seule s'ouvre, les circuits (le moins couvert), pas les pignons ni les courroies (" .. table.concat(k2, ",") .. ")")
  local k3 = Em.arbitrate({ dc[3], dc[1], dc[2] }, {})
  check(table.concat(k3, ",") == "chaine:electronic-circuit", "S5.4 l'ordre d'entrée est sans effet")
  return pass - p0, fail - f0
end

local _, BASE = pure(Em0)

-- Moteur simulé : Capi.slots et Capi.arbitre
do
  local M = require("tests.mock_engine")
  local F = require("tests.iag_fixture")
  local Ca = require("shared.ai3.capitalisation")
  local function W() return M.world() end
  M.new_world({ patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  M.load_mod()
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  local ok, err = pcall(M.run_ticks, 2 * MIN)
  check(ok, "moteur simulé : 2 min sans erreur (" .. tostring(err) .. ")")
  local f = global.fo.war.factions[1]
  local cs = f and f.team and f.team.capi
  local Capi = require("script.ai3.capitalisation")
  check(cs ~= nil, "moteur simulé : état de capitalisation")
  if cs then
    local st = f.team.ia3e
    local tick = game.tick
    local open0, mods0 = #cs.open, #st.mods
    local function inject(id, key, kind, state, missing)
      st.mods[#st.mods + 1] = { id = id, product = "produit-test", state = state, missing = missing or {}, built = 0, total = 4, capi = key }
      cs.open[#cs.open + 1] = { key = key, kind = kind, exec = "module", mod_ids = { id }, product = "produit-test", n = 4,
        opened = tick, progress_tick = tick, missing = missing or {} }
      return cs.open[#cs.open]
    end
    -- S4.2 : l'horloge de la matière
    local rec = inject(9201, "chaine:affame", "chaine", "reserve", { { "assembling-machine-2", 3 }, { "transport-belt", 23 } })
    local sl = Capi.slots(f, cs, {}, tick)
    check(rec.mat_tick == tick and rec.mat_n == 26 and sl.free_stalled == 0, "S4.2 première pensée : horloge posée, manque 26, emplacement tenu")
    local sl2 = Capi.slots(f, cs, {}, tick + 9 * MIN)
    check(rec.mat_tick == tick and sl2.free_stalled == 0, "S4.2 9 min sans progrès : encore tenu")
    local sl3 = Capi.slots(f, cs, {}, tick + 10 * MIN)
    check(sl3.free_stalled == 1 and sl3.keys_stalled[1] == "chaine:affame", "S4.2 10 min sans progrès : emplacement libéré (" .. sl3.why .. ")")
    st.mods[#st.mods].missing = { { "assembling-machine-2", 2 }, { "transport-belt", 23 } }
    Capi.slots(f, cs, {}, tick + 10 * MIN)
    check(rec.mat_tick == tick + 10 * MIN, "S4.2 un objet de moins à réunir : progrès, l'horloge repart")
    -- S5 : Capi.arbitre
    local D = Ca.data(F.dump(), {})
    local AM2 = "assembling-machine-2"
    local function order(key, kind, item, theta_made)
      return { key = key, kind = kind, item = item, items = { { AM2, 1 } } }
    end
    local res = { R = { ["iron-gear-wheel"] = 100, ["transport-belt"] = 100, ["electronic-circuit"] = 100, ["iron-ore"] = 100 },
      orders = { order("chaine:iron-gear-wheel", "chaine", "iron-gear-wheel"), { key = "couvrir:fer", kind = "couvrir", resource = "iron-ore", item = "iron-ore" },
        order("chaine:transport-belt", "chaine", "transport-belt"), order("chaine:electronic-circuit", "chaine", "electronic-circuit") } }
    local input = { data = D, flows = { ["iron-gear-wheel"] = { made = 90 }, ["transport-belt"] = { made = 110 }, ["electronic-circuit"] = { made = 48.7 }, ["iron-ore"] = { made = 20 } } }
    local view = { stock = {} }
    while #cs.open > open0 do table.remove(cs.open) end
    while #st.mods > mods0 do table.remove(st.mods) end
    local out, why = Capi.arbitre(f, cs, res, input, view, tick)
    local seq = {}
    for _, o in ipairs(out) do seq[#seq + 1] = o.key end
    check(table.concat(seq, ",") == "couvrir:fer,chaine:electronic-circuit,chaine:iron-gear-wheel,chaine:transport-belt",
      "S5.2 Capi.arbitre : le moins couvert d'abord (minerai θ 0,2, circuits 0,49, pignons 0,9, courroies 1,1) (" .. table.concat(seq, ",") .. ")")
    check(why["chaine:iron-gear-wheel"] and why["chaine:transport-belt"] and not why["chaine:electronic-circuit"] and not why["couvrir:fer"],
      "S5.3 Capi.arbitre : pignons et courroies, du même manque, n'ouvrent pas")
    check(res.orders[1].key == "chaine:iron-gear-wheel", "S5.2 res.orders n'est pas modifié")
    inject(9202, "chaine:inserter", "chaine", "reserve", { { AM2, 4 } })
    local out2, why2 = Capi.arbitre(f, cs, res, input, view, tick)
    check(why2["chaine:electronic-circuit"] ~= nil, "S5.3 Capi.arbitre : une chaîne ouverte manque des mêmes assembleurs 2 : aucune chaîne neuve n'ouvre")
    local stocked = Capi.arbitre(f, cs, res, input, { stock = { [AM2] = 5 } }, tick)
    local _, why3 = Capi.arbitre(f, cs, res, input, { stock = { [AM2] = 5 } }, tick)
    check(next(why3) == nil, "S5.3 Capi.arbitre : les assembleurs 2 sont au coffre, rien à recouper")
    Capi.ARBITRE = false
    local off, offw = Capi.arbitre(f, cs, res, input, view, tick)
    Capi.ARBITRE = true
    check(off == res.orders and offw == nil, "S5.4 réglage éteint : les ordres tels quels")
    while #cs.open > open0 do table.remove(cs.open) end
    while #st.mods > mods0 do table.remove(st.mods) end
  end
end

-- Mutants (source de shared/ai3/emplacements.lua)
local fh = assert(io.open("shared/ai3/emplacements.lua", "rb"))
local SRC = fh:read("*a")
fh:close()
local MUT = {
  { "réserve figée : jamais", [[    if m and type(m.mat_tick) == "number" and type(tick) == "number" and tick - m.mat_tick >= Em.STALL then return "fige" end
]], "" },
  { "réserve figée : dès la première pensée", "tick - m.mat_tick >= Em.STALL then return \"fige\"", "tick - m.mat_tick >= 0 then return \"fige\"" },
  { "horloge : un manque qui baisse n'est pas un progrès", " or (type(prev_n) == \"number\" and n < prev_n) then return tick, n, s end", " then return tick, n, s end" },
  { "horloge : un changement d'état n'est pas un progrès", "prev_s ~= s or ", "" },
  { "horloge : repart à chaque pensée", "  return prev_t, n, s\nend", "  return tick, n, s\nend" },
  { "recouvrement : le plus grand ensemble", "local m = math.min(na, nb)", "local m = math.max(na, nb)" },
  { "recouvrement : borne large", "Em.overlap(c.miss, o.miss) > Em.OVERLAP_MAX", "Em.overlap(c.miss, o.miss) >= Em.OVERLAP_MAX" },
  { "recouvrement : seuil à 100 %", "Em.OVERLAP_MAX = 50 ", "Em.OVERLAP_MAX = 100 " },
  { "arbitre : les chaînes ouvertes ignorées", "for _, o in ipairs(open or {}) do sets[#sets + 1]", "for _, o in ipairs({}) do sets[#sets + 1]" },
  { "arbitre : les chaînes de la décision ne comptent pas", "      if c.kind == \"chaine\" and next(c.miss or {}) ~= nil then sets[#sets + 1] = { key = c.key, miss = c.miss } end\n", "" },
  { "arbitre : toute sorte d'ordre refusée", "    if c.kind == \"chaine\" then\n      for _, o in ipairs(sets)", "    if true then\n      for _, o in ipairs(sets)" },
  { "arbitre : débloquer ne compte pas", "    if (a.unblocks and true or false) ~= (b.unblocks and true or false) then return a.unblocks and true or false end\n", "" },
  { "arbitre : le plus couvert d'abord", "if ta ~= tb then return ta < tb end", "if ta ~= tb then return ta > tb end" },
  { "arbitre : l'ordre rendu inversé à égalité", "return pos[a] < pos[b]", "return pos[a] > pos[b]" },
}
local caught = 0
check(BASE == 0, "mutants jugés sur une batterie pure verte")
for _, mu in ipairs(BASE == 0 and MUT or {}) do
  local s, e = SRC:find(mu[2], 1, true)
  if not s or SRC:find(mu[2], e + 1, true) then
    check(false, "mutant mal formé : " .. mu[1])
  else
    local Em = assert(load(SRC:sub(1, s - 1) .. mu[3] .. SRC:sub(e + 1), "=emplacements-mutant"))()
    local p0, f0 = pass, fail
    quiet = true
    local ok, err = pcall(pure, Em)
    quiet = false
    local fails = fail - f0
    pass, fail = p0, f0
    local hit = (not ok) or fails > 0
    if hit then caught = caught + 1 end
    check(hit, "mutant NON refusé : " .. mu[1])
    print(string.format("[SIEGES] mutant « %s » : %s", mu[1], ok and (fails .. " contrôle(s) en échec") or ("plantage " .. tostring(err):sub(1, 80))))
  end
end
check(caught == #MUT, string.format("mutants : %d refusés sur %d", caught, #MUT))

print(string.format("[SIEGES] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
