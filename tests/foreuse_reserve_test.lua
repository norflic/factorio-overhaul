--[[
  Lot FOREUSES-THERMIQUES, RÉSERVE D'AMORÇAGE du combustible (décision du lead, 7/11 vers 19 h 10 ; exception de SÛRETÉ à la règle du DC
  « Remplacer au fur et à mesure », qu'il peut refuser). Interblocage évité : réseau tombé → foreuses de charbon électriques arrêtées →
  centrale sans charbon → réseau mort. Un avant-poste de COMBUSTIBLE garde ses K dernières thermiques ; K = le plus petit nombre de
  thermiques dont le charbon NET (extrait moins brûlé), sans courant, nourrit UNE chaudière à pleine charge (S.coal_reserve).

  A. Règle pure (shared/team/foreuse_swap.lua) : S.coal_reserve (données vanilla : 3), S.reserve_ok, S.plan avec ctx.reserve (classement,
     choix, coût de l'échange, lectures de place épargnées, n_ready), et « réseau tombé : le charbon continue » joué passe après passe.
  B. Exécutant (script/team/foreuse_swap.lua) sur le monde factice de tests/foreuse_monde.lua : avant-poste de charbon de 6 paires relié par
     une chaîne au réseau de l'équipe ; K lu aux données ; réserve tenue en passe d'un bloc et en tranches ; réseau coupé ensuite : les K
     thermiques restent et nourrissent une chaudière ; thermique détruite entre le plan et l'exécution : réserve relue au moteur.
  Mutants : « réserve ignorée » et ses variantes, dans les deux textes.

  Usage, depuis la racine du mod :   lua5.2 tests/foreuse_reserve_test.lua
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Monde = require("tests.foreuse_monde")

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[FOREUSE-RESERVE] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local PURE = read("shared/team/foreuse_swap.lua")
local SCRIPT = read("script/team/foreuse_swap.lua")
local RA = read("script/team/reserve_amorcage.lua")

local function load_pure(src)
  local fn = load(src, "=foreuse_swap", "t", setmetatable({ require = require }, { __index = _G }))
  if not fn then return nil end
  local okc, mod = pcall(fn)
  return okc and mod or nil
end

-- Données vanilla (lues par l'exécutant aux prototypes et à shared/team/modules.lua) : chaudière 1 800 kW, charbon 4 MJ,
-- thermique 0,25 charbon/s extraits et 150 kW brûlés.
local VAN = { boiler_kw = 1800, fuel_kj = 4000, drill_rate = 0.25, drill_kw = 150 }
local function net_of(d) return d.drill_rate - d.drill_kw / d.fuel_kj end
local function need_of(d) return d.boiler_kw / d.fuel_kj end

---------------------------------------------------------------------------------------------------
-- A. Règle pure
---------------------------------------------------------------------------------------------------
local E = T.drill_electric
local function entry(id, x, o) return { id = id, x = x, y = 10, dir = 0, sink = { x = x - 1, y = 8, w = 2, h = 2 }, o = o } end
--- Un poteau alimenté sur chaque foreuse (zone de 4 tuiles de demi-côté) : toutes les candidates sont « déjà alimentées ».
local function covering(list)
  local poles = {}
  for _, e in ipairs(list) do poles[#poles + 1] = { x = e.x, y = e.y, dist = 4, wire = 7.5, powered = true } end
  return poles
end

local function pure_suite(S)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  -- A1 : K des données vanilla = 3, le plus petit qui nourrit une chaudière
  local k = S.coal_reserve(VAN)
  c("A1 K vanilla = 3", k == 3, tostring(k))
  c("A1 3 thermiques nourrissent une chaudiere, 2 non (K minimal)", 3 * net_of(VAN) >= need_of(VAN) and 2 * net_of(VAN) < need_of(VAN))
  -- A2 à A5 : la donnée change K
  local big = { boiler_kw = 3600, fuel_kj = 4000, drill_rate = 0.25, drill_kw = 150 }
  c("A2 chaudiere de 3 600 kW : K = 5", S.coal_reserve(big) == 5, tostring(S.coal_reserve(big)))
  local prod = { boiler_kw = 1800, fuel_kj = 4000, drill_rate = 0.375, drill_kw = 150 }
  c("A3 productivite +50 % : K = 2", S.coal_reserve(prod) == 2, tostring(S.coal_reserve(prod)))
  c("A4 donnee manquante : K par defaut (3)", S.coal_reserve({ boiler_kw = 1800 }) == 3 and S.coal_reserve(nil) == 3)
  local burn = S.coal_reserve({ boiler_kw = 1800, fuel_kj = 4000, drill_rate = 0.03, drill_kw = 150 })
  c("A4 une thermique brule plus qu'elle n'extrait : toutes gardees, nombre FINI (global)", burn >= 1e9 and burn < math.huge, tostring(burn))
  local m2 = S.coal_reserve({ boiler_kw = 1800, fuel_kj = 4000, drill_rate = 0.25, drill_kw = 150, margin = 2 })
  c("A5 marge 2 : K = 5", m2 == 5, tostring(m2))
  -- A6 : reserve_ok
  c("A6 reserve_ok", S.reserve_ok(4, 3, 1) and not S.reserve_ok(3, 3, 1) and S.reserve_ok(5, 3, 2) and not S.reserve_ok(4, 3, 2)
    and S.reserve_ok(0, nil, 1))
  -- A7 : avant-poste de charbon de 5 thermiques (K = 3) et de fer de 3 : 2 remplacements de charbon, 3 de fer ; refus « reserve charbon »
  local list = {}
  for i = 1, 5 do list[#list + 1] = entry(i, 10 + 4 * i, "c") end
  for i = 6, 8 do list[#list + 1] = entry(i, 10 + 4 * i, "i") end
  local ctx = { poles = covering(list), electric = E, have = 20, obtainable = true, limit = 20, fit_tries = 50,
    reserve = { c = { burners = 5, keep = 3 } } }
  local out, n_ready = S.plan(list, ctx)
  local by = { c = 0, i = 0 }
  for _, r in ipairs(out) do by[r.id <= 5 and "c" or "i"] = by[r.id <= 5 and "c" or "i"] + 1 end
  local held = 0
  for _, rf in ipairs(ctx.refused or {}) do if rf.why == "reserve charbon" then held = held + 1 end end
  c("A7 charbon : 2 remplacements sur 5 (3 gardees)", by.c == 2, tostring(by.c))
  c("A7 fer : les 3 remplacees (pas de reserve)", by.i == 3, tostring(by.i))
  c("A7 3 refus « reserve charbon »", held == 3, tostring(held))
  c("A7 n_ready sans les retenues (5)", n_ready == 5, tostring(n_ready))
  -- A7 bis : limite atteinte avant de voir les retenues : n_ready ne les compte pas quand même (classement)
  local c7 = { poles = covering(list), electric = E, have = 20, obtainable = true, limit = 2, fit_tries = 50,
    reserve = { c = { burners = 5, keep = 3 } } }
  local o7, r7 = S.plan(list, c7)
  c("A7 bis limite 2 : n_ready = 5 (2 de charbon + 3 de fer), retenues hors du compte", #o7 == 2 and r7 == 5, string.format("%d, %s", #o7, tostring(r7)))
  -- A8 : coût de l'échange (iii) : 4 thermiques, K = 3, la seule candidate retirerait aussi une voisine : refus, et hors de n_ready
  local l8 = { entry(1, 14, "c"), entry(2, 18, "c"), entry(3, 22, "c"), entry(4, 26, "c") }
  local c8 = { poles = covering(l8), electric = E, have = 5, obtainable = true, limit = 5, reserve = { c = { burners = 4, keep = 3 } },
    fits = function() return { drills = { 99 }, sinks = {} } end }
  local o8, r8 = S.plan(l8, c8)
  c("A8 echange qui passerait sous la reserve : refuse", #o8 == 0, tostring(#o8))
  c("A8 n_ready sans la retenue (0)", r8 == 0, tostring(r8))
  -- A8 bis : sans échange, la même candidate passe (seul l'échange la retenait)
  local c8b = { poles = covering(l8), electric = E, have = 5, obtainable = true, limit = 5, reserve = { c = { burners = 4, keep = 3 } } }
  local o8b = S.plan(l8, c8b)
  c("A8 sans echange : 1 remplacement", #o8b == 1, tostring(#o8b))
  -- A9 : un avant-poste à la réserve ne dépense AUCUNE lecture de place
  local fits_n = 0
  local l9 = { entry(1, 14, "c"), entry(2, 18, "c"), entry(3, 22, "c") }
  local c9 = { poles = covering(l9), electric = E, have = 5, obtainable = true, limit = 5, reserve = { c = { burners = 3, keep = 3 } },
    fits = function() fits_n = fits_n + 1 return true end }
  local o9 = S.plan(l9, c9)
  c("A9 a la reserve : 0 remplacement, 0 lecture de place", #o9 == 0 and fits_n == 0, string.format("%d, %d", #o9, fits_n))
  -- A9 bis : 5 thermiques, K = 3 ; le premier choix retire aussi une voisine (coût 2) : la suivante est refusée SANS lecture de place
  local fits_b = 0
  local l9b = { entry(1, 14, "c"), entry(2, 18, "c"), entry(3, 22, "c"), entry(4, 26, "c"), entry(5, 30, "c") }
  local c9b = { poles = covering(l9b), electric = E, have = 5, obtainable = true, limit = 5, fit_tries = 50,
    reserve = { c = { burners = 5, keep = 3 } }, fits = function() fits_b = fits_b + 1 return { drills = { 98 }, sinks = {} } end }
  local o9b = S.plan(l9b, c9b)
  c("A9 bis echange de cout 2 puis reserve atteinte : 1 remplacement, 1 seule lecture de place", #o9b == 1 and fits_b == 1,
    string.format("%d, %d", #o9b, fits_b))
  -- A10 : voie de la CHAÎNE (aucun poteau à portée) : 4 thermiques, K = 3 : une seule chaîne
  local P = require("shared.team.plan")
  local l10 = { entry(1, 14, "c"), entry(2, 18, "c"), entry(3, 22, "c"), entry(4, 26, "c") }
  local src = { { x = 20.5, y = 30.5, dist = 2.5, wire = 7.5, powered = true } }
  local c10 = { poles = src, electric = E, have = 5, obtainable = true, limit = 5, pole = { supply = 2.5, wire = 7.5 }, chain = P.pole_chain,
    chain_max = 6, tries = 10, reserve = { c = { burners = 4, keep = 3 } },
    free_for = function(e, box) return function(x, y)
      if S.overlap({ x = x, y = y, w = 1, h = 1 }, box) or S.overlap({ x = x, y = y, w = 1, h = 1 }, e.sink) then return false end
      return true end end }
  local o10, _, nc10 = S.plan(l10, c10)
  c("A10 chaine : 1 remplacement sur 4 (3 gardees)", #o10 == 1 and #(o10[1].poles or {}) > 0, tostring(#o10))
  c("A10 n_chain sans les retenues (1)", nc10 == 1, tostring(nc10))
  -- A11 : RÉSEAU TOMBÉ, LE CHARBON CONTINUE. 12 thermiques de charbon, passes jusqu'à ce que plus rien ne change ; puis le courant tombe :
  -- les électriques s'arrêtent, il reste les thermiques. Avec la réserve : charbon net >= une chaudière. Témoin sans réserve : 0, interblocage.
  local function run_until_stable(with_reserve)
    local burners = {}
    for i = 1, 12 do burners[#burners + 1] = entry(i, 10 + 4 * i, "c") end
    for _ = 1, 20 do
      local cx = { poles = covering(burners), electric = E, have = 2, obtainable = true, limit = 2,
        reserve = with_reserve and { c = { burners = #burners, keep = S.coal_reserve(VAN) } } or nil }
      local o = S.plan(burners, cx)
      if #o == 0 then break end
      local gone = {}
      for _, r in ipairs(o) do gone[r.id] = true end
      local keep = {}
      for _, b in ipairs(burners) do if not gone[b.id] then keep[#keep + 1] = b end end
      burners = keep
    end
    return #burners
  end
  local left = run_until_stable(true)
  c("A11 reseau tombe : le charbon continue (thermiques gardees : charbon net >= une chaudiere)",
    left == 3 and left * net_of(VAN) >= need_of(VAN), string.format("%d thermiques, %.3f/s contre %.3f/s", left, left * net_of(VAN), need_of(VAN)))
  local left0 = run_until_stable(false)
  c("A11 temoin sans reserve : 0 thermique, plus de charbon sans courant (l'interblocage)", left0 == 0, tostring(left0))
  return res
end

local function run_pure(src)
  local S = load_pure(src)
  if not S then return { { "module pur illisible", false } } end
  local okr, res = pcall(pure_suite, S)
  if not okr then return { { "suite pure : " .. tostring(res), false } } end
  return res
end

---------------------------------------------------------------------------------------------------
-- B. Exécutant, sur le monde factice
---------------------------------------------------------------------------------------------------
local PROTO = Monde.PROTO
PROTO["coal"] = { type = "resource", w = 1, mineable_properties = { mining_time = 1 }, fuel_value = 4e6, name = "coal", tile_width = 1, tile_height = 1 }

--- Avant-poste de charbon (numéro 3) de `n` paires (thermique + coffre en fer), espacées de 4 tuiles (la 3 x 3 tient sans échange) ; source
--- de l'équipe à 20 tuiles (chaîne de poteaux).
local function build_coal(n)
  return function(W)
    for x = 0, 44 do for y = 4, 20 do W.add("coal", x + 0.5, y + 0.5, 0) end end
    local hq = W.add("fo-team-chest", 20.5, 60.5, 0, { force = "player" })
    hq.surface = W.surface
    local o = { id = 3, kind = "coal", pos = { x = 20, y = 10 }, drill_list = {}, sinks = {}, drills = 0 }
    for i = 0, n - 1 do
      local x = 10 + 4 * i
      local d = W.add("burner-mining-drill", x, 10, 0, { force = "player" })
      d.inv.fuel.coal = 5
      local s = W.add("iron-chest", x - 0.5, 8.5, 0, { force = "player" })
      o.drill_list[#o.drill_list + 1] = d
      o.sinks[#o.sinks + 1] = s
      o.drills = o.drills + 1
    end
    local src = W.add("small-electric-pole", 20.5, 30.5, 0, { force = "player", source = true })
    return hq, { [3] = o }, src
  end
end

local function standing(R)
  local b, e = 0, 0
  for _, d in ipairs(R.f.outposts[3].drill_list) do
    if d.valid and d.name == T.DRILL then b = b + 1 end
    if d.valid and d.name == T.DRILL_ELECTRIC then e = e + 1 end
  end
  return b, e
end
local function logged(R, pat)
  for _, l in ipairs(R.W.logs) do if l:find(pat, 1, true) then return true end end
  return false
end

local function script_suite(text)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local saved_speed = PROTO["burner-mining-drill"].mining_speed
  PROTO["burner-mining-drill"].mining_speed = 0.25
  -- B1 à B3 : 6 paires, K = 3 lu aux données ; passe d'un bloc
  local R = Monde.fresh(text, false, nil, build_coal(6))
  Monde.play(R, 4)
  local b, e = standing(R)
  c("B1 bloc : 3 thermiques gardees, 3 electriques posees", b == 3 and e == 3, string.format("%d thermiques, %d electriques", b, e))
  c("B2 journal [FO-FOREUSES-RESERVE] : 3 gardees", logged(R, "[FO-FOREUSES-RESERVE] player : 3 thermique(s) gardee(s)"))
  c("B3 refus « reserve charbon » comptes", ((R.f.swap.why or {})["reserve charbon"] or 0) > 0)
  -- B4 : tranches de 5 unités, même résultat ; au dernier plan, plus aucun candidat compté (ni n_ready ni n_chain : rien à fabriquer d'avance)
  local Rs = Monde.fresh(text, true, 5, build_coal(6))
  local last = {}
  Rs.hook = function(Q)
    local p = Q.f.swap and Q.f.swap.pass
    if p and p.phase ~= "releve" and p.phase ~= "plan" then last = { t0 = p.t0, n = (p.n_ready or 0) + (p.n_chain or 0) } end
  end
  Monde.play(Rs, 4)
  local bs, es = standing(Rs)
  c("B4 tranches : 3 thermiques gardees, 3 electriques", bs == 3 and es == 3, string.format("%d, %d", bs, es))
  c("B4 dernier plan : aucun candidat compte (reserve hors de n_ready et n_chain)", last.n == 0 and (last.t0 or 0) >= T.swap.every,
    string.format("t0 %s, candidats %s", tostring(last.t0), tostring(last.n)))
  -- B5 : RÉSEAU TOMBÉ : la source coupée, les 3 thermiques restent (deux passes de plus) et leur charbon nourrit une chaudière
  for _, x in ipairs(R.W.ents) do if x.source then x.source = nil end end
  R.f.swap.next, R.f.swap.retry = 0, {} -- deux passes de plus, rejouées pour de bon (play repart du tick 0)
  Monde.play(R, 2)
  local b5 = standing(R)
  local burners_ok = 0
  for _, d in ipairs(R.f.outposts[3].drill_list) do if d.valid and d.name == T.DRILL and d.burner then burners_ok = burners_ok + 1 end end
  c("B5 reseau tombe : le charbon continue (3 thermiques, charbon net >= une chaudiere)",
    b5 == 3 and burners_ok == 3 and burners_ok * net_of(VAN) >= need_of(VAN), string.format("%d thermiques", b5))
  -- B6 : thermique détruite ENTRE le plan et l'exécution (tranches) : 4 paires, K = 3, la candidate du plan est refusée à l'exécution
  local R6 = Monde.fresh(text, true, 5, build_coal(4))
  local killed = false
  R6.hook = function(Q)
    local p = Q.f.swap and Q.f.swap.pass
    if not killed and p and p.phase == "remplacer" and p.k == 1 and p.out and p.out[1] then
      for _, d in ipairs(Q.f.outposts[3].drill_list) do
        if not killed and d.valid and d.unit_number ~= p.out[1].id then d.valid = false killed = true end
      end
    end
  end
  Monde.play(R6, 1)
  local b6, e6 = standing(R6)
  c("B6 thermique detruite apres le plan : reserve relue au moteur, aucun remplacement", killed and b6 == 3 and e6 == 0
    and ((R6.f.swap.why or {})["reserve charbon"] or 0) > 0, string.format("detruite %s, %d thermiques, %d electriques", tostring(killed), b6, e6))
  -- B7 : K suit la DONNÉE : thermique deux fois plus lente (0,125/s) : 0,45 / (0,125 - 0,0375) = 5,14, soit 6 : aucune des 6 remplacée
  PROTO["burner-mining-drill"].mining_speed = 0.125
  local R7 = Monde.fresh(text, false, nil, build_coal(6))
  Monde.play(R7, 3)
  local b7, e7 = standing(R7)
  c("B7 K lu aux donnees (6) : les 6 thermiques gardees", b7 == 6 and e7 == 0 and logged(R7, "[FO-FOREUSES-RESERVE] player : 6 thermique(s)"),
    string.format("%d, %d", b7, e7))
  PROTO["burner-mining-drill"].mining_speed = saved_speed
  return res
end

local function run_script(text)
  local okr, res = pcall(script_suite, text)
  if not okr then
    PROTO["burner-mining-drill"].mining_speed = nil
    return { { "suite de l'executant : " .. tostring(res), false } }
  end
  return res
end

for _, r in ipairs(run_pure(PURE)) do check(r[1], r[2], r[3]) end
for _, r in ipairs(run_script(SCRIPT)) do check(r[1], r[2], r[3]) end

---------------------------------------------------------------------------------------------------
-- Mutants : chacun doit faire tomber au moins un contrôle
---------------------------------------------------------------------------------------------------
local CR = SCRIPT:find("\r\n", 1, true) and "\r\n" or "\n"
local MUT = {
  { "pur", "reserve ignoree (classement et choix)", {
      { "    if rv and quota[e.o] <= 0 then", "    if false then" },
      { "    return not S.reserve_ok(left[e.o], rv.keep, cost)", "    return false" } } },
  { "pur", "reserve ignoree au classement (n_ready compte les retenues)", { { "    if rv and quota[e.o] <= 0 then", "    if false then" } } },
  { "pur", "reserve ignoree au choix (echange)", { { "    return not S.reserve_ok(left[e.o], rv.keep, cost)", "    return false" } } },
  { "pur", "cout de l'echange oublie", { { "local function cost_of(ex) return 1 + ((ex and ex.drills) and #ex.drills or 0) end", "local function cost_of(ex) return 1 end" } } },
  { "pur", "reserve_ok sans le cout", { { "return (burners or 0) - (cost or 1) >= keep", "return (burners or 0) >= keep" } } },
  { "pur", "charbon brule par la thermique oublie", { { "local net = rate - dkw / kj", "local net = rate" } } },
  { "pur", "arrondi par defaut", { { "return math.max(1, math.ceil(margin * (bkw / kj) / net - EPS))", "return math.max(1, math.floor(margin * (bkw / kj) / net))" } } },
  { "pur", "toutes gardees : infini dans global", { { "  if net <= EPS then return S.RESERVE_ALL end", "  if net <= EPS then return math.huge end" } } },
  { "pur", "n_ready compte les retenues du choix", { { "return out, #ready - held_ready, #chained - held_chain", "return out, #ready, #chained - held_chain" } } },
  { "pur", "lecture de place avant la reserve", { { "    if reserve_blocks(r.e, 1) then", "    if false then" } } },
  { "script", "reserve ignoree a l'execution", { { "    if not S.reserve_ok(live, pass.keep, 1 + ((r.exchange and r.exchange.drills) and #r.exchange.drills or 0)) then",
      "    if false then" } } },
  { "script", "releve qui ne compte pas les thermiques", { { "        if fuel and d.valid and d.name == T.DRILL then pass.burners[oid] = (pass.burners[oid] or 0) + 1 end",
      "        if false then end" } } },
  { "script", "plan sans reserve", { { "    fits = fits_for(f, surface, refs), reserve = reserve }", "    fits = fits_for(f, surface, refs) }" } } },
  { "ra", "K par defaut au lieu des donnees", { { "  return S.coal_reserve(d), d", "  return S.coal_reserve(nil), d" } } },
  { "ra", "avant-poste de combustible jamais reconnu", { { "  return sp ~= nil and (sp.resource == T.fuel or sp.product == T.fuel)", "  return false" } } },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local src = (m[1] == "pur" and PURE) or (m[1] == "ra" and RA) or SCRIPT
  local found = true
  for _, rp in ipairs(m[3]) do
    local a, z = src:find(rp[1], 1, true)
    if not a then found = false break end
    src = src:sub(1, a - 1) .. rp[2] .. src:sub(z + 1)
  end
  if not found then
    kept[#kept + 1] = m[2] .. " (motif introuvable)"
  else
    local res
    if m[1] == "pur" then res = run_pure(src)
    elseif m[1] == "ra" then
      -- module léger mutant, servi par require à l'exécutant (puis le vrai module rendu)
      local real = package.loaded["script.team.reserve_amorcage"]
      package.loaded["script.team.reserve_amorcage"] = assert(load(src, "=reserve_amorcage_mutant"))()
      res = run_script(SCRIPT)
      package.loaded["script.team.reserve_amorcage"] = real
    else res = run_script(src) end
    local seen
    for _, r in ipairs(res) do if not r[2] then seen = r[1] break end end
    if seen then
      refused = refused + 1
      print(string.format("[FOREUSE-RESERVE] mutant « %s » refuse par : %s", m[2], seen))
    else
      kept[#kept + 1] = m[2]
    end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[FOREUSE-RESERVE] mutants refuses %d/%d", refused, #MUT))
print(string.format("[FOREUSE-RESERVE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
