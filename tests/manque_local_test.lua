--[[
  Lot VIDEO-L3 « MANQUE MESURÉ AU CONSOMMATEUR, TRANSIT COMPRIS » : banc HORS JEU de shared/ai3/manque_local.lua. Lancement, depuis
  la racine du mod :
    lua5.2 tests/manque_local_test.lua
  Sections (lettres de docs/VIDEO_AUTOMATISATION.md §6 L3, puis les ajouts du lot) :
    a. un module sans un de ses ingrédients : manque = 1 min de débit nominal ;
    b. ingrédient en route : manque réduit d'autant ; réservation et inventaire de la même tâche comptés UNE fois ;
    c. ingrédient au stock libre : manque net nul, rien à construire ;
    d. sorties pleines : vues (out_all), dormantes tant que leur collecte n'est pas prise ;
    e. tourniquet : 100 modules lus en 4 pensées, ordre stable après sauvegarde et chargement, ajout et retrait ;
    f. module sans courant : aucun manque d'entrée, écrit à part ;
    g. le piège du lot FLUX : une sortie dormante n'est pas disponible ; elle devient une COLLECTE et retient la construction ;
    h. priorité : la collecte hérite de la plus haute priorité qu'elle couvre ; les besoins servis par priorité ;
    i. retenue bornée (Mq.COLLECT_WAIT), horloge remise à zéro par une collecte prise ;
    j. sortie de sûreté inconnue : ni retenue ni collecte ;
    k. lectures périmées ;
    l. fermé par défaut ;
    m. l'excès livré à un module ne couvre pas son voisin ;
    n. le défaut D0/D1 du 7/11 (fer au champ, recrue qui attend, collecte à 52 non servie) ;
    o. déterminisme, état sans fonction ;
    p. coût en INSTRUCTIONS (debug.sethook, jamais os.clock) ;
    r. demande nette (manque de l'objectif) : ne puise pas au stock une seconde fois ;
    s. puits mesurés pour la capitalisation (Mq.sinks) : manques des modules seuls ;
    t. laboratoires (lot VIDEO-COUVERTURE 3, V59, C3.1) : manque de packs d'un module qui consomme la recherche en cours ;
    u. munitions manquantes d'une tourelle (V10, C3.4) : demande « but:<munition> » à la priorité de l'armée ;
    q. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Les objets sont des chaînes opaques (aucun nom du jeu).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end

local PATH = "shared/ai3/manque_local.lua"
local function load_mq(mutate)
  local src = slurp(PATH)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. PATH)
  if not fn then return nil, err end
  return fn()
end

local function ser(v)
  local t = type(v)
  if t == "table" then
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" then return string.format("%.10g", v)
  else return tostring(v) end
end

local function has_function(v, seen)
  seen = seen or {}
  if type(v) == "function" then return true end
  if type(v) ~= "table" or seen[v] then return false end
  seen[v] = true
  for k, x in pairs(v) do if has_function(k, seen) or has_function(x, seen) then return true end end
  return false
end

local function find(list, f) for _, x in ipairs(list or {}) do if f(x) then return x end end return nil end
local function eq(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-6 end
local MIN = 3600

-- Module de « circuits » : 30 câbles/min et 10 plaques/min au nominal.
local function circuit_mod(id, t, have, extra)
  local m = { id = id, power = true, read_tick = t, inputs = { { item = "cable", rate = 30 }, { item = "plaque", rate = 10 } },
    have = have or {} }
  for k, v in pairs(extra or {}) do m[k] = v end
  return m
end

local function run_all(Mq)
  local T0 = 10 * MIN

  section("a. module sans un de ses ingredients")
  do
    local r = Mq.step(Mq.new(), { mods = { circuit_mod(1, T0, { plaque = 10 }) }, stock = {}, sources = {} }, T0)
    check(eq(r.need.cable, 30), "a : manque de cable = 1 min de nominal (" .. tostring(r.need.cable) .. ")")
    check(r.need.plaque == nil, "a : plaques couvertes par l'entree : aucun manque")
    check(eq(r.build.cable, 30) and eq(r.net.cable, -30), "a : a construire 30, net -30 (signal negatif de la video)")
    check(find(r.starved, function(x) return x.id == 1 end) ~= nil, "a : module affame (cable a 0)")
  end

  section("b. ingredient en route, sans double compte")
  do
    local mods = { circuit_mod(1, T0, { plaque = 10 }) }
    local r = Mq.step(Mq.new(), { mods = mods, stock = {}, sources = {},
      transit = { { task = "t1", module = 1, item = "cable", n = 12 } } }, T0)
    check(eq(r.need.cable, 18), "b : 12 en route : manque 18 (" .. tostring(r.need.cable) .. ")")
    check(find(r.starved, function(x) return x.id == 1 end) == nil, "b : en route : pas affame")
    local r2 = Mq.step(Mq.new(), { mods = mods, stock = {}, sources = {},
      transit = { { task = "t1", module = 1, item = "cable", n = 12 }, { task = "t1", module = 1, item = "cable", n = 12 } } }, T0)
    check(eq(r2.need.cable, 18), "b : reservation et inventaire de la MEME tache : comptes une fois (" .. tostring(r2.need.cable) .. ")")
    local r3 = Mq.step(Mq.new(), { mods = mods, stock = {}, sources = {},
      transit = { { task = "t1", module = 1, item = "cable", n = 12 }, { task = "t1", module = 1, item = "cable", n = 8 },
        { task = "t2", module = 1, item = "cable", n = 6 } } }, T0)
    check(eq(r3.need.cable, 12), "b : deux taches 12 et 6 (8 deja porte sur la premiere) : manque 12 (" .. tostring(r3.need.cable) .. ")")
  end

  section("c. ingredient au stock libre")
  do
    local r = Mq.step(Mq.new(), { mods = { circuit_mod(1, T0, { plaque = 10 }) }, stock = { cable = 30 }, sources = {} }, T0)
    check(eq(r.need.cable, 30) and eq(r.net.cable, 0), "c : besoin 30, stock 30 : net nul")
    check(r.build.cable == nil and #r.collect == 0, "c : rien a construire ni a collecter")
  end

  section("d. sorties pleines")
  do
    local src = { id = "s1", items = { plaque = 500 }, read_tick = T0, ok = true, d = 80 }
    local r = Mq.step(Mq.new(), { mods = {}, stock = {}, sources = { src } }, T0)
    check(eq(r.out_all.plaque, 500), "d : sorties vues (out_all 500)")
    check(eq(r.dort.plaque, 500) and r.dispo_sorties.plaque == nil, "d : sans collecte prise : dormantes, pas disponibles")
    local src2 = { id = "s1", items = { plaque = 500 }, read_tick = T0, ok = true, d = 80, collect = "taken" }
    local r2 = Mq.step(Mq.new(), { mods = {}, stock = {}, sources = { src2 } }, T0)
    check(eq(r2.dispo_sorties.plaque, 500) and r2.dort.plaque == nil, "d : collecte prise : disponibles")
    local src3 = { id = "s1", items = { plaque = 500 }, read_tick = T0, ok = true, d = 80, collect = "taken", carry = 200 }
    local r3 = Mq.step(Mq.new(), { mods = {}, stock = {}, sources = { src3 } }, T0)
    check(eq(r3.dispo_sorties.plaque, 200) and eq(r3.dort.plaque, 300), "d : collecte prise de 200 : 200 disponibles, 300 dorment")
  end

  section("e. tourniquet")
  do
    local ids = {}
    for i = 1, 100 do ids[i] = (i % 10 == 0) and ("m-" .. i) or i end
    local st = Mq.new()
    local seen, nseen = {}, 0
    for _ = 1, 4 do
      for _, id in ipairs(Mq.slice(st, ids, 32)) do
        if not seen[id] then seen[id] = true nseen = nseen + 1 end
      end
    end
    check(nseen == 100, "e : 100 modules lus en 4 pensees de 32 (" .. nseen .. ")")
    -- Sauvegarde et chargement : seul le curseur (un id) est gardé.
    local st1 = Mq.new()
    Mq.slice(st1, ids, 32)
    local saved = ser(st1)
    local st2 = load("return " .. ("{cursor=%s,wait={}}"):format(type(st1.cursor) == "string" and string.format("%q", st1.cursor) or tostring(st1.cursor)))()
    check(ser(st2) == saved, "e : etat sauve et recharge identique")
    check(ser(Mq.slice(st1, ids, 32)) == ser(Mq.slice(st2, ids, 32)), "e : meme tranche suivante apres chargement")
    -- Retrait du module courant et ajout d'un module : aucun module sauté.
    local st3 = Mq.new()
    local first = Mq.slice(st3, ids, 32)
    local last = first[#first]
    local ids2 = {}
    for _, id in ipairs(ids) do if id ~= last then ids2[#ids2 + 1] = id end end
    ids2[#ids2 + 1] = 1000
    local nxt = Mq.slice(st3, ids2, 32)
    -- attendu : le premier id de ids2, dans l'ordre des ids (nombres puis chaînes), strictement après le dernier lu
    local function before(a, b) if type(a) ~= type(b) then return type(a) == "number" end return a < b end
    local sorted2 = {}
    for _, id in ipairs(ids2) do sorted2[#sorted2 + 1] = id end
    table.sort(sorted2, before)
    local expect = nil
    for _, id in ipairs(sorted2) do if before(last, id) then expect = id break end end
    check(expect ~= nil and nxt[1] == expect, "e : retrait du dernier lu (" .. tostring(last) .. ") : la tranche suivante reprend au suivant ("
      .. tostring(nxt[1]) .. " contre " .. tostring(expect) .. ")")
    -- Ordre d'entrée sans effet.
    local rev = {}
    for i = #ids, 1, -1 do rev[#rev + 1] = ids[i] end
    local sa, sb = Mq.new(), Mq.new()
    check(ser(Mq.slice(sa, ids, 32)) == ser(Mq.slice(sb, rev, 32)), "e : meme tranche quel que soit l'ordre des ids")
  end

  section("f. module sans courant")
  do
    local m = circuit_mod(1, T0, {})
    m.power = false
    local r = Mq.step(Mq.new(), { mods = { m }, stock = {}, sources = {} }, T0)
    check(r.need.cable == nil and r.need.plaque == nil, "f : sans courant : aucun manque d'entree")
    check(r.no_power[1] == 1 and #r.starved == 0, "f : ecrit a part (no_power), pas affame")
  end

  section("g. piege du lot FLUX : la sortie dormante n'est pas disponible")
  do
    local src = { id = "s1", items = { plaque = 500 }, read_tick = T0, ok = true, d = 80 }
    local want = { key = "recrue", item = "plaque", n = 100, prio = 55 }
    local r = Mq.step(Mq.new(), { mods = {}, wants = { want }, stock = {}, sources = { src } }, T0)
    check(r.dispo_sorties.plaque == nil and eq(r.net.plaque, -100), "g : disponible 0, net -100 : le manque reste vu")
    check(r.build.plaque == nil, "g : la sortie couvre : rien a construire (construction retenue)")
    local a = r.collect[1]
    check(a and a.source == "s1" and eq(a.n, 100) and a.item == "plaque", "g : une COLLECTE de 100 sur s1")
    local src2 = { id = "s1", items = { plaque = 500 }, read_tick = T0, ok = true, d = 80, collect = "taken" }
    local r2 = Mq.step(Mq.new(), { mods = {}, wants = { want }, stock = {}, sources = { src2 } }, T0)
    check(eq(r2.net.plaque, 400) and #r2.collect == 0 and r2.build.plaque == nil, "g : collecte prise : disponible, net +400, aucune action")
  end

  section("h. priorite heritee")
  do
    local src = { id = "s1", items = { plaque = 60 }, read_tick = T0, ok = true, d = 80, task = "collect:12:3" }
    local mods = { { id = 7, power = true, read_tick = T0, inputs = { { item = "plaque", rate = 30 } }, have = {}, prio = 10 } }
    local r = Mq.step(Mq.new(), { mods = mods, wants = { { key = "recrue", item = "plaque", n = 50, prio = 90 } }, stock = {},
      sources = { src } }, T0)
    local a = r.collect[1]
    check(a and eq(a.n, 60) and a.prio == 90 and a.task == "collect:12:3", "h : collecte de 60 a la priorite 90, sur la tache existante")
    check(eq(r.build.plaque, 20), "h : 20 a construire (" .. tostring(r.build.plaque) .. ")")
    local sb = r.short_by[1]
    check(#r.short_by == 1 and sb.key == "m:7" and eq(sb.n, 20), "h : le reste manque au module (prio 10), pas a la recrue (prio 90)")
  end

  section("i. retenue bornee")
  do
    local st = Mq.new()
    local want = { key = "recrue", item = "plaque", n = 100, prio = 55 }
    local function at(t, collect)
      return Mq.step(st, { mods = {}, wants = { want }, stock = {},
        sources = { { id = "s1", items = { plaque = 500 }, read_tick = t, ok = true, d = 80, collect = collect } } }, t)
    end
    local resumed = nil
    for t = MIN, 15 * MIN, MIN do
      local r = at(t)
      if r.build.plaque and not resumed then resumed = t end
    end
    check(resumed == MIN + Mq.COLLECT_WAIT, "i : construction reprise apres Mq.COLLECT_WAIT sans collecte prise (" .. tostring(resumed) .. ")")
    local r = at(16 * MIN)
    check(r.collect[1] and r.collect[1].expired == true and eq(r.build.plaque, 100), "i : collecte encore demandee (echue), construction non retenue")
    at(17 * MIN, "taken")
    local r2 = at(18 * MIN)
    check(r2.build.plaque == nil and r2.collect[1] and r2.collect[1].expired == nil, "i : collecte prise : horloge remise a zero, retenue de nouveau")
    -- Une sortie qui ne sert plus perd son horloge.
    local st2 = Mq.new()
    Mq.step(st2, { wants = { want }, stock = {}, sources = { { id = "s2", items = { plaque = 500 }, read_tick = MIN, ok = true } } }, MIN)
    check(st2.wait.s2 == MIN, "i : horloge posee a la premiere retenue")
    Mq.step(st2, { wants = {}, stock = {}, sources = { { id = "s2", items = { plaque = 500 }, read_tick = 2 * MIN, ok = true } } }, 2 * MIN)
    check(st2.wait.s2 == nil, "i : plus de besoin : horloge effacee")
  end

  section("j. surete inconnue")
  do
    for _, ok in ipairs({ false, "nil" }) do
      local src = { id = "s1", items = { plaque = 500 }, read_tick = T0, d = 80 }
      if ok == false then src.ok = false end
      local r = Mq.step(Mq.new(), { wants = { { key = "recrue", item = "plaque", n = 100, prio = 55 } }, stock = {}, sources = { src } }, T0)
      check(eq(r.build.plaque, 100) and #r.collect == 0, "j : ok = " .. tostring(ok) .. " : ni collecte ni retenue, 100 a construire")
    end
  end

  section("k. lectures perimees")
  do
    local m = circuit_mod(1, T0 - Mq.MAX_AGE - 1, {})
    local src = { id = "s1", items = { cable = 500 }, read_tick = T0 - Mq.MAX_AGE - 1, ok = true }
    local r = Mq.step(Mq.new(), { mods = { m }, stock = {}, sources = { src } }, T0)
    check(r.need.cable == nil and r.out_all.cable == nil, "k : module et sortie perimes : rien compte")
    check(#r.stale == 2, "k : deux lectures perimees ecrites (" .. #r.stale .. ")")
    local m2 = circuit_mod(1, T0 - Mq.MAX_AGE, {})
    local r2 = Mq.step(Mq.new(), { mods = { m2 }, stock = {}, sources = {} }, T0)
    check(eq(r2.need.cable, 30), "k : lecture a Mq.MAX_AGE exactement : comptee")
  end

  section("l. ferme par defaut")
  do
    local m = circuit_mod(1, T0, {})
    m.power = nil
    local r = Mq.step(Mq.new(), { mods = { m }, stock = {}, sources = {} }, T0)
    check(r.need.cable == nil and find(r.refused, function(x) return x.why == "courant inconnu" end), "l : courant inconnu : aucun manque publie")
    local m2 = circuit_mod(2, T0)
    m2.have = nil
    local r2 = Mq.step(Mq.new(), { mods = { m2 }, stock = {}, sources = {} }, T0)
    check(r2.need.cable == nil and find(r2.refused, function(x) return x.why == "entrees non lues" end), "l : entrees non lues : rien")
    local m3 = { id = 3, power = true, read_tick = T0, inputs = { { item = "cable" }, { item = "plaque", rate = 0 / 0 }, { item = "vis", rate = 5 } }, have = {} }
    local r3 = Mq.step(Mq.new(), { mods = { m3 }, stock = {}, sources = {} }, T0)
    check(r3.need.cable == nil and r3.need.plaque == nil and eq(r3.need.vis, 5), "l : debit absent ou invalide : cette entree seule ne publie rien")
    local r4 = Mq.step(Mq.new(), { mods = { circuit_mod(4, T0, { plaque = 10 }) }, stock = {}, sources = {},
      transit = { { module = 4, item = "cable", n = 30 } } }, T0)
    check(eq(r4.need.cable, 30) and find(r4.refused, function(x) return x.id == "transit:4" end), "l : transit sans tache : refuse, non compte")
    local r5 = Mq.step(Mq.new(), { mods = { circuit_mod(5, T0, { plaque = 10 }) }, sources = {} }, T0)
    check(eq(r5.build.cable, 30) and find(r5.refused, function(x) return x.id == "stock" end), "l : stock absent : ecrit, rien de disponible")
    local r6, why6 = Mq.step(Mq.new(), {}, nil)
    check(r6 == nil and why6 ~= nil, "l : tick absent : rien")
    local r7 = Mq.step(Mq.new(), { wants = { { key = "w", item = "plaque" } }, stock = {}, sources = {} }, T0)
    check(r7.need.plaque == nil and #r7.refused == 1, "l : demande sans quantite : refusee")
  end

  section("m. l'exces livre a un module ne couvre pas son voisin")
  do
    local mods = { circuit_mod(1, T0, { plaque = 10 }), circuit_mod(2, T0, { plaque = 10 }) }
    local r = Mq.step(Mq.new(), { mods = mods, stock = {}, sources = {},
      transit = { { task = "t1", module = 1, item = "cable", n = 100 } } }, T0)
    check(eq(r.need.cable, 30), "m : 100 en route vers le module 1 : le module 2 manque toujours de 30 (" .. tostring(r.need.cable) .. ")")
  end

  section("n. defaut D0/D1 du 7/11")
  do
    -- 10 coffres de sortie du champ, 4 353 plaques (journal [FO-CHAMP-ETAT] minute 169) ; fer libre du QG a 0 ; la recrue attend
    -- (« manque iron-plate 1932 », [FO-RESERVE]) ; une collecte a 52 existe, personne ne la prend (0 PNJ libre, 16 taches libres).
    local srcs = {}
    local per = { 585, 560, 540, 500, 470, 430, 400, 380, 300, 188 }
    for i = 1, 10 do srcs[i] = { id = "p12:" .. i, items = { plaque = per[i] }, read_tick = T0, ok = true, d = 120 + i, task = (i == 1) and "collect:12:1" or nil } end
    local r = Mq.step(Mq.new(), { wants = { { key = "recrue", item = "plaque", n = 1932, prio = 55 } }, stock = { plaque = 0 }, sources = srcs }, T0)
    local tot = 0
    for _, p in ipairs(per) do tot = tot + p end
    check(eq(r.out_all.plaque, tot), "n : le fer du champ est VU (" .. tot .. ")")
    check(r.dispo_sorties.plaque == nil, "n : mais pas disponible tant qu'aucune collecte n'est prise")
    check(r.build.plaque == nil, "n : aucune construction pour un fer qui attend au champ")
    local a = r.collect[1]
    check(a and a.task == "collect:12:1" and a.prio == 55, "n : la collecte existante (52) monte a la priorite de la recrue (55)")
    local got = 0
    for _, x in ipairs(r.collect) do got = got + x.n end
    check(eq(got, 1932), "n : collectes jusqu'a couvrir le manque, pas plus (" .. got .. ")")
  end

  section("r. demande nette (manque de l'objectif, deja calcule contre le stock)")
  do
    local r = Mq.step(Mq.new(), { wants = { { key = "but", item = "plaque", n = 300, prio = 50, net = true } }, stock = { plaque = 500 }, sources = {} }, T0)
    check(eq(r.build.plaque, 300), "r : une demande nette ne puise pas au stock (a construire " .. tostring(r.build.plaque) .. ")")
    local r2 = Mq.step(Mq.new(), { wants = { { key = "but", item = "plaque", n = 300, prio = 50 } }, stock = { plaque = 500 }, sources = {} }, T0)
    check(r2.build.plaque == nil, "r : temoin : la meme demande brute est couverte par le stock")
    local r3 = Mq.step(Mq.new(), { wants = { { key = "recrue", item = "plaque", n = 400, prio = 60 }, { key = "but", item = "plaque", n = 300, prio = 50, net = true } },
      stock = { plaque = 500 }, sources = {} }, T0)
    check(eq(r3.build.plaque, 300), "r : la recrue (brute) prend 400 au stock, l'objectif (net) reste a construire (" .. tostring(r3.build.plaque) .. ")")
    local r4 = Mq.step(Mq.new(), { wants = { { key = "but", item = "plaque", n = 300, prio = 50, net = true } }, stock = { plaque = 500 },
      sources = { { id = "s1", items = { plaque = 400 }, read_tick = T0, ok = true, d = 10, task = "c1" } } }, T0)
    check(r4.build.plaque == nil and r4.collect[1] and eq(r4.collect[1].n, 300), "r : une demande nette se couvre par une sortie (collecte de 300)")
  end

  section("s. puits mesures pour la capitalisation (Mq.sinks)")
  do
    local mods = { circuit_mod(1, T0, { plaque = 10 }), circuit_mod(2, T0, {}) }
    local r = Mq.step(Mq.new(), { mods = mods, wants = { { key = "recrue", item = "plaque", n = 50, prio = 60 } }, stock = {}, sources = {} }, T0)
    local base = { { item = "zz-base", rate = 3, want = 3 } }
    local s = Mq.sinks(r, base)
    check(s[1] == base[1], "s : les puits donnes restent en tete, tels quels")
    local by = {}
    for i = 2, #s do by[s[i].item] = s[i] end
    check(by.cable and eq(by.cable.rate, 60) and eq(by.cable.want, 60), "s : cable des 2 modules : 60 par minute (" .. tostring(by.cable and by.cable.rate) .. ")")
    check(by.plaque and eq(by.plaque.rate, 10), "s : plaque du seul module 2 : 10 par minute, sans la recrue (" .. tostring(by.plaque and by.plaque.rate) .. ")")
    check(#s == 3 and s[2].item == "cable" and s[3].item == "plaque", "s : puits mesures tries par objet, apres la base")
    local s0 = Mq.sinks(nil, base)
    check(#s0 == 1 and s0[1] == base[1] and s0 ~= base, "s : sans resultat, la base seule (copie)")
    check(#Mq.sinks(r, nil) == 2, "s : sans base, les seuls puits mesures")
  end

  section("o. determinisme, etat sans fonction")
  do
    local function scene(rev)
      local mods, srcs, tr, wants = {}, {}, {}, {}
      for i = 1, 20 do mods[#mods + 1] = { id = (i % 4 == 0) and ("m" .. i) or i, power = i % 7 ~= 0, read_tick = T0, prio = i % 3,
        inputs = { { item = "o" .. (i % 5), rate = 10 + i }, { item = "o" .. ((i + 2) % 5), rate = 5 } }, have = { ["o" .. (i % 5)] = i } } end
      for i = 1, 12 do srcs[#srcs + 1] = { id = "s" .. i, items = { ["o" .. (i % 5)] = 40 * i }, read_tick = T0, ok = i % 4 ~= 0,
        d = (i * 37) % 11, collect = (i % 5 == 0) and "taken" or nil } end
      for i = 1, 15 do tr[#tr + 1] = { task = "t" .. (i % 6), module = (i % 4 == 0) and ("m" .. i) or i, item = "o" .. (i % 5), n = i } end
      for i = 1, 4 do wants[#wants + 1] = { key = "w" .. i, item = "o" .. i, n = 25 * i, prio = 50 + i } end
      local function maybe(l)
        if not rev then return l end
        local o = {}
        for i = #l, 1, -1 do o[#o + 1] = l[i] end
        return o
      end
      local st = Mq.new()
      local out = {}
      for k = 0, 3 do out[#out + 1] = ser(Mq.step(st, { mods = maybe(mods), sources = maybe(srcs), transit = maybe(tr), wants = maybe(wants),
        stock = { o1 = 30, o3 = 5 } }, T0 + k * MIN)) end
      return table.concat(out, "\n") .. ser(st), st
    end
    local a, st = scene(false)
    local b = scene(true)
    check(a == b, "o : meme rendu et meme etat quel que soit l'ordre des listes")
    check(not has_function(st), "o : etat sans fonction")
  end

  section("p. cout en instructions (debug.sethook)")
  do
    local function instr(fn)
      local c = 0
      debug.sethook(function() c = c + 1 end, "", 1)
      fn()
      debug.sethook()
      return c
    end
    local function scene(nm, ns)
      local mods, srcs, tr = {}, {}, {}
      for i = 1, nm do mods[i] = { id = i, power = true, read_tick = T0, prio = i % 4,
        inputs = { { item = "o" .. (i % 7), rate = 20 }, { item = "o" .. ((i + 1) % 7), rate = 10 }, { item = "o" .. ((i + 3) % 7), rate = 5 } },
        have = { ["o" .. (i % 7)] = 3 } } end
      for i = 1, ns do srcs[i] = { id = "s" .. i, items = { ["o" .. (i % 7)] = 50 * i, ["o" .. ((i + 2) % 7)] = 10 }, read_tick = T0,
        ok = true, d = i } end
      for i = 1, 20 do tr[i] = { task = "t" .. i, module = i, item = "o" .. (i % 7), n = 4 } end
      local w = {}
      for i = 1, 5 do w[i] = { key = "w" .. i, item = "o" .. i, n = 40, prio = 60 } end
      return { mods = mods, sources = srcs, transit = tr, wants = w, stock = { o1 = 100, o2 = 20 } }
    end
    local i32 = instr(function() Mq.step(Mq.new(), scene(32, 16), T0) end)
    local i100 = instr(function() Mq.step(Mq.new(), scene(100, 50), T0) end)
    local ids = {}
    for i = 1, 100 do ids[i] = i end
    local isl = instr(function() Mq.slice(Mq.new(), ids, 32) end)
    if not quiet then
      print(string.format("   Mq.step : %d instructions (32 modules, 16 sorties), %d (100 modules, 50 sorties) ; Mq.slice (100 ids) : %d", i32, i100, isl))
    end
    check(i100 < 1.5e5, "p : 100 modules et 50 sorties sous 1,5 x 10^5 instructions (" .. i100 .. ")")
    check(i100 < 5 * i32, "p : croissance a peu pres lineaire (100/50 contre 32/16)")
    -- Couverture linéaire : un objet, N demandes d'une unité, N sorties d'une unité (chaque demande vide une sortie).
    local function cover(n)
      local w, s = {}, {}
      for i = 1, n do
        w[i] = { key = "w" .. i, item = "o", n = 1, prio = 0 }
        s[i] = { id = i, items = { o = 1 }, read_tick = T0, ok = true, d = i }
      end
      return instr(function() Mq.step(Mq.new(), { wants = w, sources = s, stock = {} }, T0) end)
    end
    local c100, c200 = cover(100), cover(200)
    if not quiet then print(string.format("   couverture : %d instructions pour 100 demandes et 100 sorties, %d pour 200", c100, c200)) end
    check(c200 < 2.6 * c100, "p : couverture lineaire (200 contre 100 : x " .. string.format("%.2f", c200 / c100) .. ")")
  end

  -- Lot VIDEO-COUVERTURE 3 (V59, C3.1) : un module de type « lab » publie son manque de packs.
  section("t. laboratoires (V59, C3.1)")
  do
    -- 2 labos de vitesse 1 + 1 labo de vitesse 2 : vitesse totale 4 ; unité de 30 s ; 1 pack rouge et 1 pack vert par unité.
    local function lab_mod(have, tech, extra)
      local m = { consumes = "research", id = "L1", power = true, read_tick = T0, prio = 60, have = have or {}, speed = 4, tech = tech }
      for k, v in pairs(extra or {}) do m[k] = v end
      return m
    end
    local TECH = { unit_time = 30, ingredients = { { item = "pack-r", n = 1 }, { item = "pack-v", n = 1 } } }
    -- 4 × 60 / 30 = 8 packs par minute de chaque sorte.
    local r = Mq.step(Mq.new(), { mods = { lab_mod({ ["pack-v"] = 8 }, TECH) }, stock = {}, sources = {} }, T0)
    check(eq(r.need["pack-r"], 8), "t : labo a 0 pack rouge, technologie en file : manque de 8/min (" .. tostring(r.need["pack-r"]) .. ")")
    check(eq(r.net["pack-r"], -8) and eq(r.build["pack-r"], 8), "t : manque net signe negatif (-8), a construire 8")
    check(r.need["pack-v"] == nil, "t : packs verts couverts par l'entree : aucun manque")
    check(find(r.starved, function(x) return x.id == "L1" end) ~= nil, "t : labo affame (pack rouge a 0)")
    check(eq((r.by_module.L1 or {})["pack-r"], 8) and (r.by_module.L1 or {})["pack-v"] == nil, "t : le manque de CE module est publie a part (by_module)")
    check((find(r.starved, function(x) return x.id == "L1" end) or {}).consumes == "research", "t : le module affame dit qu'il consomme la recherche")
    check((find(Mq.step(Mq.new(), { mods = { circuit_mod(1, T0, {}) }, stock = {}, sources = {} }, T0).starved, function(x) return x.id == 1 end) or {}).consumes == nil,
      "t : un module ordinaire affame ne porte pas ce champ")
    check(#r.refused == 0, "t : rien de refuse")
    -- labo plein : 0 publie
    local rf = Mq.step(Mq.new(), { mods = { lab_mod({ ["pack-r"] = 8, ["pack-v"] = 20 }, TECH) }, stock = {}, sources = {} }, T0)
    check(rf.need["pack-r"] == nil and rf.need["pack-v"] == nil and next(rf.build) == nil, "t : labo plein : manque nul")
    -- en route (une tache fill vers le labo) : deduit
    local rt = Mq.step(Mq.new(), { mods = { lab_mod({}, TECH) }, stock = {}, sources = {},
      transit = { { task = "t1", module = "L1", item = "pack-r", n = 5 } } }, T0)
    check(eq(rt.need["pack-r"], 3) and eq(rt.need["pack-v"], 8), "t : 5 packs rouges en route : manque 3 (" .. tostring(rt.need["pack-r"]) .. ")")
    -- aucune technologie en file : rien a consommer
    local rn = Mq.step(Mq.new(), { mods = { lab_mod({}, false) }, stock = {}, sources = {} }, T0)
    check(next(rn.need) == nil and #rn.refused == 0, "t : aucune technologie en file : aucun manque, aucun refus")
    -- la vitesse du labo compte : vitesse 2 = moitie
    local r2 = Mq.step(Mq.new(), { mods = { lab_mod({}, TECH, { speed = 2 }) }, stock = {}, sources = {} }, T0)
    check(eq(r2.need["pack-r"], 4), "t : vitesse totale 2 : 4 par minute (" .. tostring(r2.need["pack-r"]) .. ")")
    -- plusieurs packs par unite et unite plus longue : 3 packs, 60 s, vitesse 4 -> 12
    local r3 = Mq.step(Mq.new(), { mods = { lab_mod({}, { unit_time = 60, ingredients = { { item = "pack-r", n = 3 } } }) }, stock = {},
      sources = {} }, T0)
    check(eq(r3.need["pack-r"], 12), "t : 3 packs par unite de 60 s a vitesse 4 : 12 par minute (" .. tostring(r3.need["pack-r"]) .. ")")
    -- garde fermee : technologie non lue, vitesse ou duree invalide, courant inconnu, lecture perimee
    local rc = Mq.step(Mq.new(), { mods = { lab_mod({}, nil, { id = "L2" }), lab_mod({}, TECH, { id = "L3", speed = 0 }),
      lab_mod({}, { unit_time = 0, ingredients = TECH.ingredients }, { id = "L4" }), lab_mod({}, TECH, { id = "L5", power = "?" }),
      lab_mod({}, TECH, { id = "L6", read_tick = T0 - 3 * MIN }) }, stock = {}, sources = {} }, T0)
    check(next(rc.need) == nil, "t : garde fermee : aucun manque publie (" .. ser(rc.need) .. ")")
    check(#rc.refused == 4 and #rc.stale == 1, "t : 4 refus (technologie, vitesse, duree, courant) et 1 lecture perimee (" .. #rc.refused .. ", " .. #rc.stale .. ")")
    local rp = Mq.step(Mq.new(), { mods = { lab_mod({}, TECH, { power = false }) }, stock = {}, sources = {} }, T0)
    check(#rp.no_power == 1 and next(rp.need) == nil, "t : labo sans courant : ecrit a part, aucun manque d'entree")
    -- un module ordinaire n'est pas touche, un labo cote a cote avec lui non plus
    local ro = Mq.step(Mq.new(), { mods = { circuit_mod(1, T0, { plaque = 10 }), lab_mod({}, TECH) }, stock = {}, sources = {} }, T0)
    check(eq(ro.need.cable, 30) and eq(ro.need["pack-r"], 8), "t : un module de circuits et un labo cote a cote")
    -- puits mesures : les packs manquants du labo sont un puits de la capitalisation
    local sk = Mq.sinks(r, {})
    check(#sk == 1 and sk[1].item == "pack-r" and eq(sk[1].rate, 8), "t : puits mesure : 8 packs rouges par minute")
    -- Mq.module : un module ordinaire est rendu tel quel (meme table) ; l'entree n'est pas modifiee
    local plain = circuit_mod(9, T0, {})
    check(Mq.module(plain) == plain, "t : Mq.module rend un module ordinaire tel quel")
    local lm = lab_mod({}, TECH)
    local before = ser(lm)
    local nm = Mq.module(lm)
    check(ser(lm) == before and nm ~= lm and #nm.inputs == 2, "t : Mq.module ne modifie pas son entree")
    check(not has_function(Mq.step(Mq.new(), { mods = { lab_mod({}, TECH) }, stock = {}, sources = {} }, T0)), "t : le resultat ne porte aucune fonction")
  end

  -- Lot VIDEO-COUVERTURE 3 (V10, C3.4) : les munitions manquantes sont un but.
  section("u. munitions (V10, C3.4)")
  do
    local groups = { { key = "hq", due = true, missing = 40, has_task = false }, { key = "o1", due = true, missing = 25, has_task = false },
      { key = "o2", due = true, missing = 100, has_task = true }, { key = "o3", due = false, missing = 30 } }
    local w = Mq.ammo_want(groups, { item = "mag", prio = 90 })
    check(w and w.key == "but:mag" and w.item == "mag" and eq(w.n, 65) and w.prio == 90,
      "u : 40 + 25 chargeurs (le groupe servi par une tournee et celui qui n'est pas du ne comptent pas) : but:mag a 90 (" .. ser(w) .. ")")
    check(Mq.ammo_want({ { key = "hq", due = true, missing = 0 } }, { item = "mag", prio = 90 }) == nil, "u : rien ne manque : pas de demande")
    check(Mq.ammo_want(groups, { item = "mag" }) == nil and Mq.ammo_want(groups, { prio = 90 }) == nil, "u : sans objet ou sans priorite : refuse")
    check(Mq.ammo_want({ { key = "hq", due = "oui", missing = 5 } }, { item = "mag", prio = 90 }) == nil, "u : due non booleen vrai : refuse")
    check(Mq.ammo_want({ { key = "hq", due = true, missing = -5 }, { key = "o", due = true, missing = 0 / 0 } }, { item = "mag", prio = 90 }) == nil,
      "u : manque negatif ou NaN : refuse")
    -- chaine : la demande entre dans Mq.step a la priorite de l'armee, devant une demande de priorite ordinaire, et se couvre par le stock libre
    local wants = { Mq.ammo_want(groups, { item = "mag", prio = 90 }), { key = "but:plaque", item = "plaque", n = 50, prio = 55, net = true } }
    local r = Mq.step(Mq.new(), { mods = {}, wants = wants, stock = { mag = 20 }, sources = {} }, T0)
    check(eq(r.need.mag, 65) and eq(r.build.mag, 45) and eq(r.net.mag, -45), "u : 65 voulus, 20 au stock libre : 45 a construire (net -45)")
    local rs = Mq.step(Mq.new(), { mods = {}, wants = wants, stock = { mag = 65 }, sources = {} }, T0)
    check(rs.build.mag == nil and eq(rs.net.mag, 0), "u : couvert par le stock libre : rien a construire")
    local src = { id = "s1", items = { mag = 30 }, read_tick = T0, ok = true, d = 40 }
    local rc = Mq.step(Mq.new(), { mods = {}, wants = wants, stock = {}, sources = { src } }, T0)
    check(#rc.collect == 1 and rc.collect[1].item == "mag" and rc.collect[1].prio == 90 and eq(rc.collect[1].n, 30),
      "u : des munitions dorment dans une sortie : collecte a la priorite de l'armee (" .. ser(rc.collect) .. ")")
  end
end

local Mq0 = assert(load_mq())
run_all(Mq0)

section("q. mutants")
local MUTANTS = {
  { "transit ignore (double livraison)", { "local way = mt[x.item] or 0", "local way = 0" } },
  { "transit somme (reservation et inventaire comptes deux fois)", { "if cur == nil or n > cur then per[e.module][e.item][e.task] = n end", "per[e.module][e.item][e.task] = (cur or 0) + n" } },
  { "sorties ignorees (D0/D1 restent)", { "      if n and n > 0 then\n        note(it)", "      if false then\n        note(it)" } },
  { "sorties dormantes comptees disponibles (piege FLUX)", { 'if s.collect == "taken" then', "if true then" } },
  { "module sans courant compte comme affame", { "elseif m.power == false then", "elseif false then" } },
  { "retenue sans borne", { "if w ~= nil and tick - w >= Mq.COLLECT_WAIT then", "if false then" } },
  { "besoins servis sans la priorite", { "      if a.prio ~= b.prio then return a.prio > b.prio end\n      return a.key < b.key", "      return a.key < b.key" } },
  { "lecture perimee comptee", { "elseif not fresh(m.read_tick, tick) then", "elseif false then" } },
  { "sortie de surete inconnue collectee (garde ouverte)", { "if s.ok == true then", "if s.ok ~= false then" } },
  { "courant inconnu accepte (garde ouverte)", { 'if type(m.power) ~= "boolean" then', "if false then" } },
  { "tourniquet sans curseur", { "  if st.cursor ~= nil then\n    start = #list + 1", "  if false then\n    start = #list + 1" } },
  { "priorite de la collecte ecrasee par le dernier besoin", { "if nd.prio > a.prio then a.prio = nd.prio end", "a.prio = nd.prio" } },
  { "demande nette qui puise encore au stock (double compte)", { "local q = nd.net and 0 or math.min(n, s_left)", "local q = math.min(n, s_left)" } },
  { "puits avec les demandes hors module (double compte avec input.need)", { 'e.key:sub(1, 2) == "m:"', 'e.key ~= ""' } },
  { "puits donnes perdus", { "for _, s in ipairs(base or {}) do out[#out + 1] = s end", "" } },
  { "labo : technologie non lue prise pour aucune technologie (garde ouverte)", { "  if m.tech == false then", "  if m.tech == false or m.tech == nil then" } },
  { "labo : vitesse ignoree", { "add(per, ing.item, n * speed * 60 / ut)", "add(per, ing.item, n * 60 / ut)" } },
  { "labo : duree de l unite ignoree", { "add(per, ing.item, n * speed * 60 / ut)", "add(per, ing.item, n * speed * 60)" } },
  { "labo : type ignore (module ordinaire)", { "if type(m) ~= \"table\" or m.consumes ~= Mq.RESEARCH then return m end", "do return m end" } },
  { "munitions : tournee deja au tableau comptee", { "if miss and g.due == true and not g.has_task then", "if miss and g.due == true then" } },
  { "munitions : recharge non due comptee", { "if miss and g.due == true and not g.has_task then", "if miss and not g.has_task then" } },
  { "munitions : priorite de l armee perdue", { "return { key = \"but:\" .. o.item, item = o.item, n = n, prio = o.prio }", "return { key = \"but:\" .. o.item, item = o.item, n = n, prio = 0 }" } },
  { "offres relues depuis le debut sans curseur, sans sauter les vides", { "      while i <= #list and list[i].left <= Mq.EPS do i = i + 1 end\n      list.i = i\n      for j = i, #list do\n        local o = list[j]\n        if n <= Mq.EPS then break end\n        if o.left > Mq.EPS then", "      for j = 1, #list do\n        local o = list[j]\n        if n <= Mq.EPS then break end\n        if true then" } },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local mod, err = load_mq(m[2])
  local dead
  if not mod then
    quiet = false
    check(false, "mutant '" .. m[1] .. "' : " .. tostring(err))
    quiet = true
    dead = false
  else
    local p0, f0 = passes, failures
    local okrun, e = pcall(run_all, mod)
    local nf = failures - f0
    dead = (not okrun) or nf > 0
    passes, failures = p0, f0
    quiet = false
    print(string.format("   %s : %s", m[1], (not okrun) and ("PLANTAGE " .. tostring(e)) or (nf .. " controle(s) en echec")))
    quiet = true
  end
  if dead then killed = killed + 1 else
    quiet = false
    check(false, "mutant SURVIVANT : " .. m[1])
    quiet = true
  end
end
quiet = false
print(string.format("   mutants refuses : %d / %d", killed, #MUTANTS))
check(killed == #MUTANTS, "tous les mutants sont refuses")

print(string.format("[MANQUE-LOCAL] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
