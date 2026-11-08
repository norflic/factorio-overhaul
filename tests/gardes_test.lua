--[[
  Lot 5b « GARDES QUI S'OUVRAIENT SANS MESURE » (fo-logs/2026-11-07_VIDEO-COUVERTURE/W04_GARDES.md, liste n°1 à 6). Banc HORS JEU. Lancement, depuis
  la racine du mod : lua5.2 tests/gardes_test.lua
  Pour chaque garde : (a) le cas où la mesure MANQUE, (b) la décision écrite (fermer, ou rester ouverte avec la raison), (c) le refus écrit qui
  nomme l'entrée, (d) un mutant (le texte de la règle est remplacé : le banc doit échouer).
    1. Pe.site_room      FERMÉE : batis ou open_sites absent = aucune place de chantier
    2. S.admit           FERMÉE si la centrale est FINIE et sa capacité ou sa production non lue ; OUVERTE sans centrale finie (la centrale précède)
    3. B.saturated       OUVERTE : un objet absent du stock vaut 0 (le moteur n'énumère pas les zéros) ; décision écrite, pas de refus
    4. Fx.drop_service   FERMÉE : sorties non mesurées = la tournée est gardée
    5. D.gate            FERMÉE : aucune lecture du danger = « wait / danger non lu » ; un danger lu à 0 reste « go »
    6. Ic.gate           FERMÉE : toute mesure absente nomme l'entrée
  Aucun nom du jeu : des chaînes opaques.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end

--- Charge un module en remplaçant un morceau de son texte (mutant) ; sans `mutate`, le module d'origine.
local function load_mod(path, mutate)
  local src = slurp(path)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. path)
  if not fn then return nil, err end
  return fn()
end

local PATHS = {
  Pe = "shared/ai3/portes_extension.lua", S = "shared/team/sante_centrale.lua", B = "shared/ai3/buts.lua",
  Fx = "shared/team/flux.lua", D = "shared/ai3/danger.lua", Ic = "shared/team/ilots_croissance.lua",
}

local function run(mods)
  local Pe, S, Fx, D, Ic = mods.Pe, mods.S, mods.Fx, mods.D, mods.Ic

  -- 1. Pe.site_room
  do
    local room, limit, why = Pe.site_room(nil, 0)
    check(room == 0 and limit == 0 and why and why:find("batis", 1, true), "1 : modules poses absents : aucune place, la raison nomme batis (" .. tostring(why) .. ")")
    room, limit, why = Pe.site_room(10, nil)
    check(room == 0 and why and why:find("open_sites", 1, true), "1 : chantiers ouverts absents : aucune place, la raison nomme open_sites")
    room, limit, why = Pe.site_room(0 / 0, 0)
    check(room == 0 and why ~= nil, "1 : NaN : aucune place")
    room, limit, why = Pe.site_room(0, 0)
    check(room == 1 and limit == 1 and why == nil, "1 : mesures lues (0, 0) : une place comme avant")
    check(select(1, Pe.site_room(100, 2)) == 3, "1 : 100 modules, 2 ouverts : 3 places comme avant")
    local st = Pe.new()
    local a = { workers = 10, idle = 5, free_tasks = 0, open_sites = 0 } -- batis absent
    local r = Pe.decide(st, a, { { key = "c1", item = "x", n = 1, rank = 3, site = true } })
    check(#r.kept == 0 and #r.refused == 1 and r.refused[1].why:find("batis", 1, true), "1 : un ordre de chantier sans mesure des modules est refuse, ecrit (" .. tostring(r.refused[1] and r.refused[1].why) .. ")")
    local r2 = Pe.decide(Pe.new(), { workers = 10, idle = 5, free_tasks = 0, batis = 0, open_sites = 0 }, { { key = "c1", item = "x", n = 1, rank = 3, site = true } })
    check(#r2.kept == 1, "1 : mesures lues : l'ordre passe comme avant")
    local r3 = Pe.decide(Pe.new(), a, { { key = "d", item = "x", n = 1, rank = 1, site = true } })
    check(#r3.kept == 1, "1 : R0 et R1 ne sont jamais retenus (I2), mesure absente comprise")
  end

  -- 2. S.admit
  do
    local g = {}
    local ok, why = S.admit(g, { plant_done = true, used = 0, committed = 0 }, 700, 100)
    check(ok == false and why:find("capacity", 1, true), "2 : centrale finie, capacite non lue : module retenu, la raison nomme capacity (" .. tostring(why) .. ")")
    ok, why = S.admit(g, { plant_done = true, used = 0, committed = 0 }, 700, 100 + S.GATE_WAIT - 1)
    check(ok == false, "2 : retenu jusqu'a S.GATE_WAIT")
    ok, why = S.admit(g, { plant_done = true, used = 0, committed = 0 }, 700, 100 + S.GATE_WAIT)
    check(ok == true and why == "delai", "2 : jamais de blocage definitif : passe apres S.GATE_WAIT")
    ok, why = S.admit({}, { capacity = 1800, committed = 0 }, 700, 0)
    check(ok == false and why:find("used", 1, true), "2 : capacite lue, production non lue : retenu, la raison nomme used (" .. tostring(why) .. ")")
    ok = S.admit({}, { capacity = 0, used = 0, committed = 0 }, 700, 0)
    check(ok == true, "2 : sans centrale finie (capacite nulle, plant_done absent) : admis (la centrale precede)")
    ok = S.admit({}, { capacity = nil, committed = 0 }, 700, 0)
    check(ok == true, "2 : sans centrale finie (capacite absente, plant_done absent) : admis")
    ok = S.admit({}, { plant_done = true, committed = 0 }, 0, 0)
    check(ok == true, "2 : un module de 0 kW n'a rien a retenir")
    ok = S.admit({}, { capacity = 1800, used = 600, committed = 400 }, 1000, 0)
    check(ok == true, "2 : mesures lues et marge : admis comme avant")
    ok, why = S.admit({}, { capacity = 1800, used = 1200, committed = 0 }, 1100, 100)
    check(ok == false and why:find("au-dela", 1, true), "2 : mesures lues, marge depassee : le refus d'avant")
  end

  -- 3. B.saturated : décision écrite, voir le test de décision plus bas (module chargé à part)
  do
    local B = mods.B
    local s = { stock = {}, need = {}, workers = 8 }
    check(B.saturated(s, "objet-a") == false, "3 : objet absent du stock = 0 : pas sature, l'extraction continue (decision : ouverte, le moteur n'enumere pas les zeros)")
    s.stock["objet-a"] = 1e9
    check(B.saturated(s, "objet-a") == true, "3 : un gros stock lu est sature")
    s.stock["objet-a"] = 0
    check(B.saturated(s, "objet-a") == false, "3 : stock lu a 0 : pas sature")
  end

  -- 4. Fx.drop_service (la règle de retrait est ÉTEINTE par défaut, Fx.ENABLE.keep_drop : elle se joue allumée ; éteinte, elle rend `dropped`)
  do
    Fx.ENABLE.keep_drop = true
    local d, why = Fx.drop_service(nil, true)
    check(d == false and why and why:find("non mesurees", 1, true), "4 : rangee absente : tournee GARDEE, raison ecrite (" .. tostring(why) .. ")")
    d, why = Fx.drop_service({}, true)
    check(d == false and why ~= nil, "4 : rangee sans stuck : gardee")
    d, why = Fx.drop_service({ stuck = 0 / 0 }, true)
    check(d == false and why ~= nil, "4 : stuck NaN : gardee")
    d, why = Fx.drop_service({ stuck = 0 }, true)
    check(d == true and why == nil, "4 : sorties mesurees vides : retiree comme avant")
    d = Fx.drop_service({ stuck = 2 }, true)
    check(d == false, "4 : une sortie pleine : gardee comme avant")
    d, why = Fx.drop_service(nil, false)
    check(d == false and why == nil, "4 : la regle d'avant ne retirait pas : rien a ecrire")
    Fx.ENABLE.keep_drop = false
    check(Fx.drop_service(nil, true) == true, "4 : regle eteinte (defaut du depot) : rend la decision d'avant, inchangee")
  end

  -- 5. D.gate
  do
    local ctx = { B = 600, prudence = 1000, escort_ok = false }
    local d, why = D.gate({}, ctx)
    check(d == "wait" and why == "danger non lu", "5 : aucune lecture du danger : on attend, raison ecrite (" .. tostring(d) .. "/" .. tostring(why) .. ")")
    d, why = D.gate({ far = true }, ctx)
    check(d == "wait" and why == "danger non lu", "5 : seule la distance (aucune lecture du danger) : on attend")
    d, why = D.gate({ deaths = 1 }, { B = 600, escort_ok = true })
    check(d == "escort", "5 : les morts seules sont une lecture : jugees comme avant (escorte)")
    d = D.gate({ blocked = false, deaths = 0, far = false }, ctx)
    check(d == "go", "5 : bloque et morts lus a zero : go comme avant")
    d, why = D.gate(nil, ctx)
    check(d == "wait", "5 : entree absente : on attend")
    d, why = D.gate({ max_d = 0, goal_d = 0, deaths = 0 }, ctx)
    check(d == "go" and why == "sur", "5 : danger LU a 0 : go / sur comme avant")
    d, why = D.gate({ max_d = 0, deaths = 0 }, ctx)
    check(d == "go", "5 : seul max_d lu (a 0) : go comme avant")
    d, why = D.gate({ max_d = 400, goal_d = 0, deaths = 0 }, ctx)
    check(d == "wait" and why == "marque", "5 : danger moyen lu : le refus d'avant")
  end

  -- 6. Ic.gate
  do
    local base = { islands = 1, max = 4, unwalled = 0, unguarded = 0, outside_busy = 0, threatened = false, main_busy = false }
    local function with(t)
      local c = {}
      for k, v in pairs(base) do c[k] = v end
      for k, v in pairs(t) do if v == "nil" then c[k] = nil else c[k] = v end end
      return c
    end
    check(Ic.gate(base) == true, "6 : toutes les mesures lues : ouverte comme avant")
    for _, k in ipairs({ "islands", "max", "unwalled", "unguarded", "outside_busy", "threatened", "main_busy" }) do
      local ok, why = Ic.gate(with({ [k] = "nil" }))
      check(ok == false and why == "mesure absente : " .. k, "6 : " .. k .. " absente : fermee, la raison la nomme (" .. tostring(why) .. ")")
    end
    local ok, why = Ic.gate(with({ unwalled = 0 / 0 }))
    check(ok == false and why:find("unwalled", 1, true), "6 : NaN : fermee")
    ok, why = Ic.gate(with({ threatened = 1 }))
    check(ok == false and why:find("threatened", 1, true), "6 : une menace qui n'est pas un booleen : fermee")
    ok, why = Ic.gate(nil)
    check(ok == false and why:find("info", 1, true), "6 : info absente : fermee")
    ok, why = Ic.gate(with({ threatened = true }))
    check(ok == false and why == "menace", "6 : menace lue : le refus d'avant")
    ok, why = Ic.grow_due(with({ unguarded = "nil", radius = 3, rmax = 12, free = 0, busy = 0, done = 2 }))
    check(ok == false and why:find("unguarded", 1, true), "6 : la croissance au-dela du mur attend aussi (" .. tostring(why) .. ")")
  end
end

local mods = {}
for k, p in pairs(PATHS) do mods[k] = assert(load_mod(p)) end
run(mods)

-- (d) Mutants : le texte d'une règle est remplacé, le banc doit échouer.
local MUTANTS = {
  { "Pe", "place de chantier offerte sur mesure absente", "if b == nil or o == nil then return 0, 0,", "if false then return 0, 0," },
  { "Pe", "mesure absente lue comme 0 (limite 1)", "local b, o = int(batis), int(open_sites)", "local b, o = int(batis) or 0, int(open_sites) or 0" },
  { "Pe", "refus de chantier sans la raison de la mesure", [[if g.site_why then return "bras : " .. g.site_why .. " (aucun chantier de plus sans mesure)" end]], "" },
  { "S", "centrale finie sans capacite lue : admis", "if c.plant_done then return hold(", "if false then return hold(" },
  { "S", "production non lue comptee 0", [[if type(c.used) ~= "number" then return hold("courant : entree absente : used (production)") end]], "c.used = c.used or 0" },
  { "S", "retenue sans fin (S.GATE_WAIT ignore)", [[if tick - st.since >= S.GATE_WAIT then return true, "delai" end
    return false, why]], "return false, why" },
  { "S", "sans centrale finie : retenu (amorcage bloque)", [[    st.since = nil
    return true, nil
  end
  if type(c.used)]], [[    return hold("courant : aucune centrale")
  end
  if type(c.used)]] },
  { "Fx", "rangee absente : tournee retiree", [[if type(o) ~= "table" or type(o.stuck) ~= "number" or o.stuck ~= o.stuck then return false, "sorties non mesurees : tournee gardee" end]], "o = o or {}" },
  { "Fx", "refus sans raison ecrite", [[return false, "sorties non mesurees : tournee gardee" end]], "return false end" },
  { "D", "danger non lu : go", [[if type(info) ~= "table" or (info.max_d == nil and info.goal_d == nil and info.deaths == nil and info.blocked == nil) then]], "if false then" },
  { "D", "danger lu a 0 : wait (amorcage des tournees bloque)", [[(info.max_d == nil and info.goal_d == nil and info.deaths == nil and info.blocked == nil)]], [[(info.max_d == nil or info.goal_d == nil)]] },
  { "Ic", "menace absente : pas de menace", [[if type(info[k]) ~= "boolean" then return false, "mesure absente : " .. k end]], "" },
  { "Ic", "compteur absent lu comme 0", [[if type(v) ~= "number" or v ~= v then return false, "mesure absente : " .. k end]], "" },
  { "Ic", "raison sans l'entree nommee", [["mesure absente : " .. k end
  end
  for _, k in ipairs(Ic.GATE_NUMBERS)]], [["mesure absente" end
  end
  for _, k in ipairs(Ic.GATE_NUMBERS)]] },
  { "B", "objet absent du stock lu comme sature", "local have, thr = s.stock[item] or 0, B.SAT_FACTOR * need", "local have, thr = s.stock[item] or math.huge, B.SAT_FACTOR * need" },
}
local killed = 0
for _, m in ipairs(MUTANTS) do
  local alt = {}
  for k, v in pairs(mods) do alt[k] = v end
  local mod, err = load_mod(PATHS[m[1]], { m[3], m[4] })
  local dead
  if not mod then
    check(false, "mutant '" .. m[2] .. "' : " .. tostring(err))
    dead = false
  else
    alt[m[1]] = mod
    local p0, f0 = passes, failures
    quiet = true
    local okrun = pcall(run, alt)
    local nf = failures - f0
    quiet = false
    passes, failures = p0, f0
    dead = (not okrun) or nf > 0
    print(string.format("   %s : %s", m[2], okrun and (nf .. " controle(s) en echec") or "PLANTAGE"))
  end
  if dead then killed = killed + 1 else check(false, "mutant SURVIVANT : " .. m[2]) end
end
print(string.format("   mutants refuses : %d / %d", killed, #MUTANTS))
check(killed == #MUTANTS, "tous les mutants sont refuses")

print(string.format("[GARDES-5B] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
