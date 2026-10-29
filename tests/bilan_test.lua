--[[
  Lot BILAN « production moins consommation » : banc HORS JEU de la règle pure (shared/ai3/bilan.lua) et de son
  branchement dans le cerveau par besoins (shared/ai3/projets.lua P.supply, shared/ai3/cerveau.lua).
    §1 règle : sous-production durable (N relevés), sur-production (stock qui monte), bruit sous MIN_RATE, hystérésis,
       stock qui monte = pas de sous-production (les mains des PNJ comblent), premier relevé sans niveau ;
    §2 pondération : bornes, gravité, jamais d'urgence, fabrication seulement en hausse ;
    §3 branchement : le cas du DC (ai3_cerveau_test §1) avec et sans pondération : le minage d'un objet en
       sous-production pèse plus, un objet en sur-production moins, sans pondération le plan est identique à l'ancien ;
       aucun besoin AJOUTÉ par la pondération (mêmes clés de tâches) ;
    §4 état : nombres et chaînes seulement, borné à MAX_ITEMS, déterminisme, journal ;
    §5 mutants : chaque règle retirée est vue ; aucun nom du jeu dans les fichiers du lot.
  Lancement : lua5.2 tests/bilan_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local B = require("shared.ai3.buts")
local C = require("shared.ai3.cerveau")
local Bi = require("shared.ai3.bilan")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local MIN = Bi.PERIOD
-- Rejoue des relevés : suite de lignes { [objet] = {prod, cons, stock} } à MIN d'intervalle.
local function run(series)
  local b = Bi.new()
  for i, rows in ipairs(series) do Bi.update(b, (i - 1) * MIN, rows) end
  return b
end
local function repeat_rows(n, f)
  local out = {}
  for i = 1, n do out[i] = f(i) end
  return out
end

---------------------------------------------------------------------------------------------------
section("1. Règle")
---------------------------------------------------------------------------------------------------
-- Sous-production : consomme 30/min, produit 10/min, stock constant.
local sous = run(repeat_rows(5, function() return { x = { prod = 10, cons = 30, stock = 100 } } end))
check(Bi.level(sous, "x") == "sous", "bilan −20/min, stock plat, 5 relevés : sous-production durable")
local w = Bi.weights(sous)
check(w.x and w.x > 0 and w.x <= Bi.BONUS, "sous-production : pondération positive bornée (" .. tostring(w.x) .. ")")
-- Durable seulement après SOUS_N relevés avec pente (le 1er n'en a pas).
local s1 = run(repeat_rows(1, function() return { x = { prod = 0, cons = 30, stock = 0 } } end))
check(Bi.level(s1, "x") == nil, "un seul relevé : aucun niveau")
local sN = run(repeat_rows(Bi.SOUS_N, function() return { x = { prod = 0, cons = 30, stock = 0 } } end))
check(Bi.level(sN, "x") == nil, "SOUS_N relevés (le premier sans pente) : pas encore durable")
local sN1 = run(repeat_rows(Bi.SOUS_N + 1, function() return { x = { prod = 0, cons = 30, stock = 0 } } end))
check(Bi.level(sN1, "x") == "sous", "SOUS_N + 1 relevés : durable")
-- Gravité : produire la moitié de ce qu'on consomme pèse moins que ne rien produire.
local half = run(repeat_rows(6, function() return { x = { prod = 15, cons = 30, stock = 0 } } end))
local none = run(repeat_rows(6, function() return { x = { prod = 0, cons = 30, stock = 0 } } end))
check(Bi.weights(half).x < Bi.weights(none).x and Bi.weights(none).x == Bi.BONUS,
  "gravité : plus le déficit est grand, plus l'objet pèse")
-- Bruit : bilan −1/min, sous MIN_RATE.
local bruit = run(repeat_rows(8, function() return { x = { prod = 10, cons = 11, stock = 5 } } end))
check(Bi.level(bruit, "x") == nil and next(Bi.weights(bruit)) == nil, "bilan −1/min : bruit, aucun niveau")
-- Stock qui monte (les mains des PNJ comblent) : ni sous (malgré un bilan machines négatif) ni sur.
local mains = run(repeat_rows(8, function(i) return { x = { prod = 0, cons = 30, stock = i * 20 } } end))
check(Bi.level(mains, "x") == nil, "bilan machines négatif mais stock qui monte de 20/min : aucun niveau")
-- Sur-production : le stock monte, les machines produisent plus qu'elles ne consomment.
local sur = run(repeat_rows(6, function(i) return { x = { prod = 40, cons = 10, stock = i * 30 } } end))
check(Bi.level(sur, "x") == "sur" and Bi.weights(sur).x == -Bi.MALUS,
  "stock +30/min, bilan +30 : sur-production, pondération négative")
-- Stock plat avec bilan positif : ni sur ni sous (les machines stockent ailleurs).
local plat = run(repeat_rows(6, function() return { x = { prod = 40, cons = 10, stock = 50 } } end))
check(Bi.level(plat, "x") == nil, "bilan positif mais stock plat : aucun niveau")
-- Hystérésis : un relevé contraire isolé ne fait pas disparaître le niveau.
local hyst = run(repeat_rows(6, function() return { x = { prod = 0, cons = 30, stock = 0 } } end))
Bi.update(hyst, 6 * MIN, { x = { prod = 30, cons = 30, stock = 0 } })
check(Bi.level(hyst, "x") == "sous", "un relevé équilibré isolé : le niveau « sous » tient")
for i = 7, 11 do Bi.update(hyst, i * MIN, { x = { prod = 30, cons = 30, stock = 0 } }) end
check(Bi.level(hyst, "x") == nil, "des relevés équilibrés de suite : le niveau disparaît")
-- Relevé trop tôt : ignoré.
local early = run(repeat_rows(2, function() return { x = { prod = 0, cons = 30, stock = 0 } } end))
check(Bi.update(early, 1 * MIN + 10, { x = { prod = 0, cons = 30, stock = 0 } }) == false, "relevé avant PERIOD : ignoré")
-- Un objet qui disparaît des lignes disparaît de l'état.
Bi.update(early, 10 * MIN, { y = { prod = 1, cons = 0, stock = 0 } })
check(early.items.x == nil and early.items.y ~= nil, "objet absent du relevé : retiré de l'état")
-- Valeurs absurdes (nil, NaN) : jamais d'erreur.
local ok = pcall(function()
  local b = Bi.new()
  Bi.update(b, 0, { x = { prod = 0 / 0 }, y = {} })
  Bi.update(b, MIN, { x = {}, y = { stock = 3 } })
end)
check(ok, "lignes incomplètes ou NaN : pas d'erreur")

---------------------------------------------------------------------------------------------------
section("2. Pondération")
---------------------------------------------------------------------------------------------------
check(Bi.clamp(50, nil) == 50 and Bi.clamp(50, 0) == 50, "sans pondération : priorité inchangée")
check(Bi.clamp(50, 8) == 58 and Bi.clamp(82, 8) == 85, "hausse bornée à PRIO_MAX")
check(Bi.clamp(93, 8) == 93, "une hausse ne fait pas descendre une tâche d'amorçage (93)")
check(Bi.clamp(50, -5) == 45 and Bi.clamp(22, -5) == 20 and Bi.clamp(10, -5) == 10,
  "baisse bornée à PRIO_MIN, sans remonter une tâche basse")
check(Bi.craft(50, 8) == 58 and Bi.craft(85, 8) == 89 and Bi.craft(90, 8) == 90 and Bi.craft(95, 8) == 95,
  "fabrication : hausse bornée à 89, urgences (90+) intactes")
check(Bi.craft(50, -5) == 50 and Bi.craft(50, nil) == 50, "fabrication : jamais de baisse")

---------------------------------------------------------------------------------------------------
section("3. Branchement dans le cerveau (cas du DC d'ai3_cerveau_test §1)")
---------------------------------------------------------------------------------------------------
local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 10,
    workers_max = 30, workers_idle = 10, threatened = false, open = {}, workers_wanted = 10, no_research = true,
    ladder = T.player_ladder, hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, drills)
  return { id = id, kind = kind, drills = drills, full = false, turrets = 1, coal_needed = 0, fuel_low = false,
    output = 50, idle_ticks = 0, has_task = false, has_fortify = false }
end
local function dc_view()
  return view({ is_player = true, stock = { stone = 600, coal = 800, ["firearm-magazine"] = 60 },
    outposts = { op(1, "stone", 2) }, sites = { coal = 1, iron = 1, copper = 0, stone = 1 }, done = { stone = true } })
end
local function think(bilan)
  return C.think(dc_view(), book, C.new_state(0), { tick = 0, is_player = true, weights = B.weights({}, nil),
    reach = { ["iron-ore"] = 150, stone = 40, coal = 80 }, bilan = bilan })
end
local function sig(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do out[#out + 1] = t.key .. "@" .. t.prio end
  return table.concat(out, ";")
end
local function keyset(plan)
  local ks = {}
  for _, t in ipairs(plan.tasks) do ks[#ks + 1] = t.key end
  table.sort(ks)
  return table.concat(ks, ";")
end
local function prio_of(plan, pred)
  local best = nil
  for _, t in ipairs(plan.tasks) do if pred(t) and (not best or t.prio > best) then best = t.prio end end
  return best
end
local mine_iron = function(t) return t.kind == "mine" and t.resource == "iron-ore" end
local base = think(nil)
check(sig(base) == sig(think({})), "pondération vide : plan identique à l'ancien cerveau (clés et priorités)")
local p0 = prio_of(base, mine_iron)
check(p0 ~= nil, "cas du DC : du minerai de fer est miné (" .. tostring(p0) .. ")")
local pu = prio_of(think({ ["iron-ore"] = 8, ["iron-plate"] = 8 }), mine_iron)
check(pu and p0 and pu >= p0 and pu <= 93, "minerai de fer en sous-production : priorité de minage >= (" .. tostring(p0) .. " -> " .. tostring(pu) .. ")")
local pl = prio_of(think({ ["iron-ore"] = -5, ["iron-plate"] = -5 }), mine_iron)
check(pl and p0 and pl <= p0, "minerai de fer en sur-production : priorité de minage <= (" .. tostring(p0) .. " -> " .. tostring(pl) .. ")")
-- Aucun besoin ajouté : mêmes clés de tâches avec une pondération sur des objets quelconques, même absents.
local noisy = think({ ["objet-inconnu"] = 8, ["iron-plate"] = 8, ["iron-ore"] = 8, ["stone"] = -5 })
check(keyset(noisy) == keyset(base), "la pondération n'ajoute ni ne retire aucune tâche (mêmes clés)")
local urgent_before, urgent_after = 0, 0
for _, t in ipairs(base.tasks) do if t.prio >= 90 then urgent_before = urgent_before + 1 end end
for _, t in ipairs(noisy.tasks) do if t.prio >= 90 then urgent_after = urgent_after + 1 end end
check(urgent_before == urgent_after, "aucune tâche ne devient une urgence par pondération (" .. urgent_before .. " -> " .. urgent_after .. ")")
-- Fabrication : un objet fabriqué à la main pèse plus quand il est en sous-production.
local craft_key, craft_item = nil, nil
for _, t in ipairs(base.tasks) do
  if t.kind == "craft" and t.prio < 85 then craft_key, craft_item = t.key, t.item break end
end
if check(craft_key ~= nil, "le plan du DC contient une fabrication à pondérer") then
  local function prio_key(plan)
    for _, t in ipairs(plan.tasks) do if t.key == craft_key then return t.prio end end
    return nil
  end
  local pb = prio_key(base)
  local pw = prio_key(think({ [craft_item] = 8 }))
  check(pw and pw == math.min(89, pb + 8), "fabrication en sous-production : +8, plafond 89 (" .. pb .. " -> " .. tostring(pw) .. ")")
  check(prio_key(think({ [craft_item] = -5 })) == pb, "fabrication en sur-production : priorité inchangée (jamais de baisse)")
end
check(sig(think({ ["iron-ore"] = 8 })) == sig(think({ ["iron-ore"] = 8 })), "même entrée, même plan")

---------------------------------------------------------------------------------------------------
section("4. État, borne, journal")
---------------------------------------------------------------------------------------------------
local function deep_ok(t, seen)
  seen = seen or {}
  if seen[t] then return true end
  seen[t] = true
  for k, v in pairs(t) do
    local tk, tv = type(k), type(v)
    if tk ~= "string" and tk ~= "number" then return false end
    if tv == "table" then
      if getmetatable(v) ~= nil or not deep_ok(v, seen) then return false end
    elseif tv ~= "string" and tv ~= "number" and tv ~= "boolean" then return false end
  end
  return true
end
check(deep_ok(sous), "état : nombres et chaînes seulement")
local many = {}
for i = 1, Bi.MAX_ITEMS * 2 do many["o" .. string.format("%03d", i)] = { prod = i, cons = 0, stock = 0 } end
local bm = Bi.new()
Bi.update(bm, 0, many)
local n = 0
for _ in pairs(bm.items) do n = n + 1 end
check(n == Bi.MAX_ITEMS and bm.items["o128"] ~= nil and bm.items["o001"] == nil,
  "état borné à MAX_ITEMS, les plus actifs gardés (" .. n .. ")")
local jb = run(repeat_rows(6, function(i)
  return { a = { prod = 0, cons = 30, stock = 0 }, b = { prod = 40, cons = 10, stock = i * 30 } }
end))
check(Bi.log_due(jb, 5 * MIN) == true and Bi.log_due(jb, 5 * MIN + 100) == false, "journal : une ligne toutes les 5 minutes")
local line = Bi.format("player", 5 * MIN, jb)
check(line:find("[FO-BILAN] player", 1, true) and line:find("sous [a:-30.0/min]", 1, true) and line:find("sur [b:+30.0/min]", 1, true)
  and line:find("ponderes 2", 1, true), "ligne [FO-BILAN] : " .. line)
check(Bi.log_due(Bi.new(), 10 * MIN) == false, "journal : rien avant le premier relevé")

---------------------------------------------------------------------------------------------------
section("5. Mutants et anti-échelle")
---------------------------------------------------------------------------------------------------
local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local src = read("shared/ai3/bilan.lua")
local function load_bi(text) return assert(load(text, "=bilan_mut", "t"))() end
local function level_of(m, series)
  local b = {}
  b = m.new()
  for i, rows in ipairs(series) do m.update(b, (i - 1) * MIN, rows) end
  return m.level(b, "x")
end
local series_sous = repeat_rows(6, function() return { x = { prod = 0, cons = 30, stock = 0 } } end)
local series_sur = repeat_rows(6, function(i) return { x = { prod = 40, cons = 10, stock = i * 30 } } end)
local series_mains = repeat_rows(8, function(i) return { x = { prod = 0, cons = 30, stock = i * 20 } } end)
local series_bruit = repeat_rows(8, function() return { x = { prod = 10, cons = 11, stock = 5 } } end)
local function basic_ok(m)
  return level_of(m, series_sous) == "sous" and level_of(m, series_sur) == "sur"
    and level_of(m, series_mains) == nil and level_of(m, series_bruit) == nil
end
check(basic_ok(load_bi(src)), "témoin nul : la règle rechargée passe les quatre séries")
local function mutant(name, from, to, good)
  local a, b = src:find(from, 1, true)
  if not a then check(false, "mutant « " .. name .. " » : motif introuvable") return end
  local m = load_bi(src:sub(1, a - 1) .. to .. src:sub(b + 1))
  check(not good(m), "mutant « " .. name .. " » détecté")
end
mutant("sous sans condition de stock", " and slope < Bi.MIN_RATE", "", basic_ok)
mutant("sur sans condition de bilan", " and e.b >= 0", "", basic_ok)
mutant("bruit non filtré", "e.b <= -Bi.MIN_RATE", "e.b <= -0.01", basic_ok)
mutant("sous immédiat", "if e.n >= Bi.SOUS_N then", "if e.n >= 1 then", function(m)
  return level_of(m, repeat_rows(2, function() return { x = { prod = 0, cons = 30, stock = 0 } } end)) == nil
end)
mutant("sans hystérésis", "math.max(0, e.n - 1)", "0", function(m)
  local b = m.new()
  for i = 1, 6 do m.update(b, (i - 1) * MIN, { x = { prod = 0, cons = 30, stock = 0 } }) end
  m.update(b, 6 * MIN, { x = { prod = 30, cons = 30, stock = 0 } })
  return m.level(b, "x") == "sous"
end)
mutant("pente non rapportée au temps", "(stock - prev.s) * Bi.PERIOD / dt", "(stock - prev.s)", function(m)
  local b = m.new()
  m.update(b, 0, { x = { prod = 0, cons = 30, stock = 0 } })
  m.update(b, 2 * MIN, { x = { prod = 0, cons = 30, stock = 30 } }) -- +15 par minute
  return b.items.x.d == 15
end)
mutant("urgence franchissable", "Bi.CRAFT_MAX = 89", "Bi.CRAFT_MAX = 120", function(m) return m.craft(85, 8) == 89 end)
mutant("baisse sans plancher", "math.max(Bi.PRIO_MIN, p)", "p", function(m) return m.clamp(22, -5) == 20 end)
mutant("amorçage rabaissé", "return math.max(prio, math.min(Bi.PRIO_MAX, p))", "return math.min(Bi.PRIO_MAX, p)",
  function(m) return m.clamp(93, 8) == 93 end)
-- Branchement retiré : sans la ligne de P.supply, la pondération de récolte ne change plus rien.
do
  local psrc = read("shared/ai3/projets.lua")
  check(psrc:find("prio = Bi.clamp(prio, bilan[item])", 1, true) ~= nil, "P.supply applique la pondération de récolte")
  local csrc = read("shared/ai3/cerveau.lua")
  check(csrc:find("bilan = ctx.bilan", 1, true) ~= nil and csrc:find("Bi.craft(t.prio, ctx.bilan[t.item])", 1, true) ~= nil,
    "le cerveau passe la pondération à P.supply et aux fabrications")
  local rsrc = read("script/ai3/cerveau.lua")
  check(rsrc:find("Bilan.think(f, view, tick)", 1, true) ~= nil and rsrc:find("bilan = bilan,", 1, true) ~= nil,
    "Ia3.plan lit le bilan et le met au contexte de la pensée")
end
-- Anti-échelle : aucun nom du jeu dans les deux fichiers du lot (hors commentaires).
for _, path in ipairs({ "shared/ai3/bilan.lua", "script/ai3/bilan.lua" }) do
  local text = read(path):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local hit = nil
  for _, name in ipairs({ "iron", "copper", "coal", "stone", "plate", "ore", "gear", "wood", "steel", "circuit" }) do
    if text:find(name, 1, true) then hit = name break end
  end
  check(hit == nil, "aucun nom du jeu dans " .. path .. (hit and (" (" .. hit .. ")") or ""))
end

print(string.format("[BILAN] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
