-- Lot REMPLISSAGE : règle pure de la charge des fours du QG (shared/team/charge.lua) + mutants.
-- Lancement (depuis la racine du mod) : lua5.2 tests/charge_test.lua
package.path = "./?.lua;" .. package.path

local function read(p)
  local fh = assert(io.open(p, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local SRC = read("shared/team/charge.lua")

local function load_charge(src)
  local f = load(src, "charge_mutant", "t")
  if not f then return nil end
  local ok, C = pcall(f)
  if not ok then return nil end
  return C
end

-- Produits du jeu de base, DONNÉES du test (la règle n'en connaît aucun) : vitesse 1, durées en ticks.
local function specs()
  return {
    ["iron-plate"] = { input = "iron-ore", per = 1, ticks = 192, cap = 50 },
    ["copper-plate"] = { input = "copper-ore", per = 1, ticks = 192, cap = 50 },
    ["steel-plate"] = { input = "iron-plate", per = 5, ticks = 960, cap = 100 },
    ["stone-brick"] = { input = "stone", per = 2, ticks = 192, cap = 50 },
  }
end
local EMPTY = { n = 0, fuel = 0, out = 0, out_cap = 0, crafting = false }
local function furnace(t)
  local f = { item = nil, n = 0, fuel = 14, out = 0, out_cap = 0, crafting = false }
  for k, v in pairs(t or {}) do f[k] = v end
  return f
end

local function suite(C)
  local pass, fail, msgs = 0, 0, {}
  local function check(ok, msg)
    if ok then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = msg end
  end
  local S = specs()

  -- 1. Cible : 10 minutes de fonte, bornées par la pile, en multiples de la recette.
  check(C.target(S["iron-plate"]) == 50, "cible minerai = pile de 50 (10 min = 188 minerais)")
  check(C.target(S["steel-plate"]) == 100, "cible acier = pile de 100 plaques (multiple de 5)")
  check(C.target(S["stone-brick"]) == 50, "cible brique = pile de 50 pierres")
  check(C.target({ input = "x", per = 5, ticks = 960, cap = 98 }) == 95, "pile non multiple : arrondie en dessous (95)")
  check(C.target({ input = "x", per = 1, ticks = 192, cap = 50 }, { horizon = 960 }) == 5, "horizon court : 5 fabrications")
  check(C.target({ input = "x", per = 5, ticks = 960, cap = 100 }, { horizon = 100 }) == 5, "jamais moins d'une fabrication")
  check(C.target({ input = "x", per = 5, ticks = 960, cap = 3 }) == 5, "pile plus petite que la recette : une fabrication")
  check(C.target({ input = "x", per = 1, ticks = 192, cap = 5000 }, { horizon = 1920 }) == 10, "horizon respecté quand la pile est large")

  -- 2. Combustible : 10 minutes au débit du four.
  check(C.fuel_target(2667, 50) == 14, "combustible : 36000 / 2667 = 14 charbons")
  check(C.fuel_target(100, 50) == 50, "combustible borné par la pile")
  check(C.fuel_target(1e9, 50) == 1, "combustible : au moins 1")
  check(C.fuel_missing(3, 14) == 11 and C.fuel_missing(20, 14) == 0 and C.fuel_missing(nil, 4) == 4, "combustible manquant")

  -- 2 bis. Prise et répartition du combustible.
  check(C.fuel_take({ 5, 5 }, 14, 10, 1000) == 18, "combustible : stock large, cible 14 pour deux fours à 5 (18)")
  check(C.fuel_take({ 5, 5 }, 14, 10, 20) == 10, "combustible : stock 20 -> part de 10 (plancher de recharge à 10 : 10)")
  check(C.fuel_take({ 5, 5 }, 14, 10, 6) == 6, "combustible : jamais plus que le stock")
  check(C.fuel_take({ 5, 5 }, 14, 10, 0) == 0, "combustible : coffre sans charbon")
  check(C.fuel_take({ 14, 14 }, 14, 10, 1000) == 0, "combustible : fours pleins")
  check(C.fuel_take({ 12, 2 }, 14, 10, 30) == 15 or C.fuel_take({ 12, 2 }, 14, 10, 30) == 14, "combustible : part du stock 15 pour un manque total de 14")
  check(C.fuel_take({ 0, 0, 0, 0 }, 3, 10, 1000) == 12, "cible sous le plancher : jamais au-dessus de la cible")
  local fa = C.fuel_distribute({ 5, 5, 12 }, 14, 15)
  check(fa[1] + fa[2] + fa[3] == 15 and fa[3] == 0 and fa[1] >= 7 and fa[2] >= 7, "répartition au plus vide d'abord (15 charbons)")
  fa = C.fuel_distribute({ 13, 14 }, 14, 50)
  check(fa[1] == 1 and fa[2] == 0, "jamais au-dessus de la cible")
  check(C.fuel_distribute({ 0 }, 14, 0)[1] == 0, "porteur sans charbon")

  -- 3. Assignation.
  local fs = { furnace(), furnace(), furnace(), furnace() }
  local a = C.assign(fs, { "iron-plate" }, S)
  local nload = 0
  for i = 1, 4 do if a.loads[i] and a.loads[i].room == 50 and a.loads[i].item == "iron-ore" then nload = nload + 1 end end
  check(nload == 4, "4 fours vides : 4 charges de 50 minerais")
  local a2 = C.assign(fs, { "iron-plate", "steel-plate" }, S)
  check(a2.loads[1].product == "iron-plate" and a2.loads[2].product == "steel-plate" and a2.loads[3].product == "iron-plate"
    and a2.loads[4].product == "steel-plate", "deux produits : à tour de rôle")
  check(a2.loads[2].room == 100 and a2.loads[1].room == 50, "pièce par produit")
  check(next(C.assign(fs, {}, S).loads) == nil, "aucun produit demandé : aucune charge")
  -- four garni sous le seuil : complété ; au-dessus : laissé
  local g = C.assign({ furnace({ item = "iron-ore", n = 10, crafting = true }), furnace({ item = "iron-ore", n = 30, crafting = true }) },
    { "iron-plate" }, S)
  check(g.loads[1] and g.loads[1].room == 40, "four à 10/50 : complété de 40")
  check(g.loads[2] == nil, "four à 30/50 (au-dessus de la moitié) : laissé")
  check(C.assign({ furnace({ item = "iron-ore", n = 10, crafting = true }) }, { "copper-plate" }, S).loads[1] == nil,
    "four garni d'un produit non demandé : jamais mélangé")
  -- complément en multiples de la recette
  local g2 = C.assign({ furnace({ item = "iron-plate", n = 7, crafting = true }) }, { "steel-plate" }, S)
  check(g2.loads[1] and g2.loads[1].room == 90 and g2.loads[1].room % 5 == 0, "acier à 7/100 : complément multiple de 5 (90)")
  -- sous-chargé à l'arrêt : repris puis rechargé ; en marche : intact
  local r = C.assign({ furnace({ item = "iron-plate", n = 3, crafting = false }) }, { "steel-plate" }, S)
  check(r.reclaim[1] and r.loads[1] and r.loads[1].room == 100, "acier à 3 plaques à l'arrêt : repris et rechargé en entier")
  local r2 = C.assign({ furnace({ item = "iron-plate", n = 3, crafting = true }) }, { "steel-plate" }, S)
  check(not r2.reclaim[1], "sous-chargé mais en marche : pas repris")
  local r3 = C.assign({ furnace({ item = "iron-ore", n = 3, crafting = false }) }, { "iron-plate" }, S)
  check(not r3.reclaim[1], "minerai (recette à 1) : jamais repris")

  -- 4. Répartition.
  local lf = C.assign(fs, { "iron-plate" }, S)
  local d = C.distribute(lf, { ["iron-ore"] = 1000 })
  local tot = 0
  for i = 1, 4 do tot = tot + (d[i] and d[i].n or 0) end
  check(tot == 200 and d[1].n == 50, "stock large : 50 chacun")
  d = C.distribute(lf, { ["iron-ore"] = 90 })
  tot = 0
  for i = 1, 4 do tot = tot + (d[i] and d[i].n or 0) end
  check(tot == 90 and d[1].n >= 22 and d[1].n <= 23 and d[4].n >= 22, "stock juste : réparti à égalité (90 / 4)")
  local ls = C.assign({ furnace(), furnace(), furnace() }, { "steel-plate" }, S)
  d = C.distribute(ls, { ["iron-plate"] = 17 })
  tot = 0
  for i = 1, 3 do tot = tot + (d[i] and d[i].n or 0) end
  check(tot == 15, "acier : 17 plaques = 3 fabrications de 5 (multiple de la recette)")
  check((d[1] and d[1].n or 0) % 5 == 0 and (d[2] and d[2].n or 0) % 5 == 0, "chaque part est un multiple de 5")
  d = C.distribute(ls, { ["iron-plate"] = 3 })
  check(next(d) == nil, "moins d'une fabrication : rien")
  d = C.distribute(lf, {})
  check(next(d) == nil, "porteur vide : rien")
  -- jamais plus que la place
  local small = C.assign({ furnace({ item = "iron-ore", n = 20, crafting = true }) }, { "iron-plate" }, S)
  d = C.distribute(small, { ["iron-ore"] = 1000 })
  check(d[1].n == 30, "jamais plus que la place du four (50 - 20)")

  -- 5. Prise au coffre.
  local t = C.take(lf, { ["iron-plate"] = 1000 }, { ["iron-ore"] = 1000 })
  check(t["iron-ore"] == 200, "stock 1000, demande 1000 : tout ce que les 4 fours acceptent (200)")
  t = C.take(lf, { ["iron-plate"] = 1000 }, { ["iron-ore"] = 240 })
  check(t["iron-ore"] == 120, "part du stock : la moitié de 240")
  t = C.take(lf, { ["iron-plate"] = 1000 }, { ["iron-ore"] = 30 })
  check(t["iron-ore"] == 30, "stock plus petit que le plancher (40) : tout le stock")
  t = C.take(lf, { ["iron-plate"] = 1000 }, { ["iron-ore"] = 60 })
  check(t["iron-ore"] == 40, "plancher de 10 fabrications par four (4 x 10) au-dessus de la part (30)")
  t = C.take(lf, { ["iron-plate"] = 70 }, { ["iron-ore"] = 1000 })
  check(t["iron-ore"] == 70, "demande de 70 plaques : 70 minerais")
  t = C.take(lf, { ["iron-plate"] = 5 }, { ["iron-ore"] = 1000 })
  check(t["iron-ore"] == 40, "petite demande : le plancher de 40 (4 x 10)")
  t = C.take(ls, { ["steel-plate"] = 100 }, { ["iron-plate"] = 2000 })
  check(t["iron-plate"] == 300, "acier : 3 fours x 100 plaques")
  t = C.take(ls, { ["steel-plate"] = 4 }, { ["iron-plate"] = 2000 })
  check(t["iron-plate"] == 150 and t["iron-plate"] % 5 == 0, "acier, demande de 4 : plancher 3 x 50")
  t = C.take(ls, { ["steel-plate"] = 100 }, { ["iron-plate"] = 4 })
  check(t["iron-plate"] == nil, "moins d'une fabrication au coffre : rien")
  t = C.take(ls, { ["steel-plate"] = 100 }, { ["iron-plate"] = 400 }, { share = 0.25 })
  check(t["iron-plate"] == 150, "part réglable (25 % de 400 = 100, plancher 150)")
  check(next(C.take(C.assign(fs, {}, S), {}, { ["iron-ore"] = 100 })) == nil, "rien à charger : rien à prendre")

  -- 6. Tournée justifiée.
  local due = C.due({ furnace({ item = "iron-ore", n = 45, crafting = true, fuel = 14 }) }, S, { ["iron-ore"] = 500 }, 14)
  check(not due.products["iron-plate"] and not due.fuel and not due.out, "four plein, combustible plein, sortie vide : rien à faire")
  due = C.due({ furnace({ item = "iron-ore", n = 10, crafting = true }) }, S, { ["iron-ore"] = 500 }, 14)
  check(due.products["iron-plate"], "four sous la moitié et minerai au coffre : justifiée")
  due = C.due({ furnace({ item = "iron-ore", n = 10, crafting = true }) }, S, { ["iron-ore"] = 0 }, 14)
  check(not due.products["iron-plate"], "pas de minerai au coffre : pas de tournée pour le fer")
  due = C.due({ furnace() }, S, { ["stone"] = 5 }, 14)
  check(due.products["stone-brick"] and not due.products["iron-plate"], "four vide et pierre : briques seulement")
  due = C.due({ furnace({ item = "iron-plate", n = 4, crafting = false }) }, S, { ["iron-plate"] = 100 }, 14)
  check(due.products["steel-plate"], "four sous-chargé à l'arrêt : justifiée")
  due = C.due({ furnace({ item = "iron-ore", n = 50, crafting = true, fuel = 4 }) }, S, {}, 14)
  check(due.fuel, "combustible sous la moitié de la cible : justifiée")
  due = C.due({ furnace({ item = "iron-ore", n = 50, crafting = true, fuel = 7 }) }, S, {}, 14)
  check(not due.fuel, "combustible à la moitié exactement : pas encore")
  due = C.due({ furnace({ item = "iron-ore", n = 50, crafting = true, out = 30, out_cap = 100 }) }, S, {}, 14)
  check(due.out, "sortie à 30 % de la pile : justifiée")
  due = C.due({ furnace({ item = "iron-ore", n = 50, crafting = true, out = 5, out_cap = 100 }) }, S, {}, 14)
  check(not due.out, "sortie à 5 % : pas encore")
  due = C.due({ furnace({ item = "iron-ore", n = 10, crafting = true }) }, S, { ["iron-ore"] = 37 }, 14)
  check(due.products["iron-plate"] == 37, "fabrications au coffre rendues (37 minerais = 37 fabrications)")
  due = C.due({ furnace({ item = "iron-ore", n = 50, crafting = true, fuel = 4 }) }, S, {}, 14, nil, 3)
  check(not due.fuel, "combustible bas mais presque rien au coffre (3 < 5) : la tournée reviendrait à vide")
  due = C.due({ furnace({ item = "iron-ore", n = 50, crafting = true, fuel = 4 }) }, S, {}, 14, nil, 40)
  check(due.fuel, "combustible bas et du charbon au coffre : justifiée")
  local ready = function(n) return { products = { ["iron-plate"] = n }, fuel = false, out = false } end
  check(C.visit_due(ready(3), { ["iron-plate"] = 50 }, false) == false, "3 fabrications au coffre pour une demande de 50 : pas la peine")
  check(C.visit_due(ready(10), { ["iron-plate"] = 50 }, false) == true, "10 fabrications au coffre : la peine (plancher de main)")
  check(C.visit_due(ready(3), { ["iron-plate"] = 2 }, false) == true, "petite demande (2) couverte par le coffre : oui")
  check(C.visit_due(ready(1), { ["iron-plate"] = 2 }, false) == false, "1 fabrication pour une demande de 2 : pas encore")
  check(C.visit_due(nil, {}, false) == true, "vue sans relevé : ancien comportement")
  check(C.visit_due({ products = {}, fuel = false, out = false }, { ["iron-plate"] = 50 }, false) == false, "demande sans place : non")
  check(C.visit_due({ products = { ["iron-plate"] = true }, fuel = false, out = false }, { ["iron-plate"] = 50 }, false) == true, "demande avec place : oui")
  check(C.visit_due({ products = { ["iron-plate"] = true }, fuel = false, out = false }, { ["copper-plate"] = 50 }, false) == false,
    "place pour un autre produit : non")
  check(C.visit_due({ products = { ["iron-plate"] = true }, fuel = false, out = false }, { ["iron-plate"] = 0 }, false) == false,
    "demande nulle : non")
  check(C.visit_due({ products = {}, fuel = true, out = false }, {}, false) and C.visit_due({ products = {}, fuel = false, out = true }, {}, false),
    "combustible ou sortie : oui")
  check(C.visit_due({ products = {}, fuel = false, out = false }, {}, true) == false, "urgence sans combustible au coffre (due.fuel faux) : non")

  -- 7. Simulation de 10 minutes : passages d'un porteur (au plus un toutes les 300 ticks), 4 fours à minerai.
  local function simulate(C, lead)
    local fsim = {}
    for i = 1, 4 do fsim[i] = furnace({ item = "iron-ore", n = 0, fuel = 14 }) end
    local visits, produced = 0, 0
    local stock = { ["iron-ore"] = 100000 }
    local last = -9999
    for tick = 0, 36000, 60 do
      -- 60 ticks de fonte
      for _, f in ipairs(fsim) do
        if f.n > 0 then
          f.crafting = true
          local made = math.min(f.n, 60 / 192)
          f.acc = (f.acc or 0) + made
          local whole = math.floor(f.acc)
          if whole > 0 then f.acc = f.acc - whole; f.n = f.n - whole; f.out = f.out + whole; produced = produced + whole end
        else
          f.crafting = false
        end
        f.out_cap = 100
      end
      local dd = C.due(fsim, S, stock, 14)
      if C.visit_due(dd, { ["iron-plate"] = 1000 }, false) and tick - last >= 300 then
        last = tick
        visits = visits + 1
        for _, f in ipairs(fsim) do f.out = 0 end
        local asg = C.assign(fsim, { "iron-plate" }, S)
        local give = C.distribute(asg, { ["iron-ore"] = C.take(asg, { ["iron-plate"] = 1000 }, stock)["iron-ore"] or 0 })
        for i, g in pairs(give) do fsim[i].item = g.item; fsim[i].n = fsim[i].n + g.n end
      end
    end
    return visits, produced
  end
  local v, p = simulate(C)
  -- ancien comportement : un passage toutes les 300 ticks tant que quelque chose attend (120 en 10 minutes)
  if SIM_VERBOSE then print("[CHARGE] simulation 10 min : " .. v .. " passage(s), " .. p .. " plaque(s)") end
  check(v > 0 and v <= 60, "simulation 10 min : au plus la moitié des 120 passages de la base (" .. v .. ")")
  check(p >= 4 * 36000 / 192 * 0.7, "simulation 10 min : 4 fours produisent au moins 70 % du nominal (" .. p .. ")")

  -- 8. Déterminisme : ordre d'insertion des produits sans effet.
  local S2 = {}
  for _, k in ipairs({ "stone-brick", "steel-plate", "copper-plate", "iron-plate" }) do S2[k] = specs()[k] end
  local a3 = C.assign(fs, { "iron-plate", "steel-plate" }, S2)
  check(a3.loads[1].product == a2.loads[1].product and a3.loads[2].room == a2.loads[2].room, "ordre d'insertion des produits sans effet")
  local t1 = C.take(lf, { ["iron-plate"] = 70 }, { ["iron-ore"] = 1000 })
  local t2 = C.take(lf, { ["iron-plate"] = 70 }, { ["iron-ore"] = 1000 })
  check(t1["iron-ore"] == t2["iron-ore"], "deux appels, même résultat")
  return pass, fail, msgs
end

SIM_VERBOSE = true
local C = load_charge(SRC)
assert(C, "shared/team/charge.lua ne se charge pas")
local pass, fail, msgs = suite(C)
SIM_VERBOSE = false
for _, m in ipairs(msgs) do print("[CHARGE] ECHEC : " .. m) end

-- Règle pure : aucun nom d'objet du jeu dans le fichier (hors commentaires).
do
  local code = SRC:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local bad = {}
  for _, n in ipairs({ "iron", "copper", "steel", "stone", "coal", "furnace", "plate", "brick", "ore" }) do
    if code:find(n, 1, true) then bad[#bad + 1] = n end
  end
  if #bad == 0 then pass = pass + 1 else fail = fail + 1 print("[CHARGE] ECHEC : noms d'objets dans la règle : " .. table.concat(bad, ",")) end
  if not code:find("require", 1, true) then pass = pass + 1 else fail = fail + 1 print("[CHARGE] ECHEC : la règle requiert un module") end
end

-- Mutants : chacun DOIT faire échouer la suite.
local MUTANTS = {
  { "pile ignorée", "  if n > cap then n = cap end\n  if n < per then n = per end\n  return n", "  if n < per then n = per end\n  return n" },
  { "horizon ignoré", "local n = math.ceil(P.horizon / math.max(1, spec.ticks)) * per", "local n = spec.cap" },
  { "multiple de la recette ignoré", "local cap = multiple(math.max(per, spec.cap or per), per)", "local cap = spec.cap or per" },
  { "combustible sans pile", "  if cap and n > cap then n = cap end\n  if n < 1 then n = 1 end", "  if n < 1 then n = 1 end" },
  { "reprise du sous-chargé retirée", "res.reclaim[i] = true\n      item, n = nil, 0", "item, n = item, n" },
  { "sous-chargé en marche repris", "and not f.crafting and ratio[item] ~= nil", "and ratio[item] ~= nil" },
  { "four garni jamais complété", "if n < P.low * target then", "if false then" },
  { "four garni toujours complété", "if n < P.low * target then", "if n < target then" },
  { "produit non demandé chargé", "if p and wanted[p] then", "if p then" },
  { "complément hors multiple", "local room = multiple(target - n, spec.per)", "local room = target - n" },
  { "répartition au-delà de la place", "if a >= per and given[i] + per <= assign.loads[i].room then", "if a >= per then" },
  { "répartition au-delà du porteur", "if a >= per and given[i] + per <= assign.loads[i].room then", "if given[i] + per <= assign.loads[i].room then" },
  { "part du stock ignorée", "local want = math.min(room, dem, math.floor(P.share * s))", "local want = math.min(room, dem, s)" },
  { "demande ignorée", "local want = math.min(room, dem, math.floor(P.share * s))", "local want = math.min(room, math.floor(P.share * s))" },
  { "plancher retiré", "    want = math.max(want, base)\n", "" },
  { "stock dépassé", "want = multiple(math.min(want, room, s), per)", "want = multiple(math.min(want, room), per)" },
  { "tournée sans matière au coffre", "if (stock[spec.input] or 0) >= spec.per then", "if true then" },
  { "tournée toujours justifiée", "if due == nil then return true end", "if due == nil then return true end\n  if true then return true end" },
  { "sortie ignorée", "if (f.out or 0) > 0 and (f.out or 0) >= P.out_due * math.max(1, f.out_cap or 0) then due.out = true end", "" },
  { "combustible ignoré", "if fuel_target and (f.fuel or 0) < P.fuel_low * fuel_target and (fuel_stock == nil or fuel_stock >= P.fuel_min) then due.fuel = true end", "" },
  { "matière insuffisante suffit", "if have == true or have >= math.min(P.base_fabs, d) then return true end", "return true" },
  { "combustible sans stock", "and (fuel_stock == nil or fuel_stock >= P.fuel_min) then due.fuel = true end", "then due.fuel = true end" },
  { "combustible sans plancher", "local want = math.max(floor_n, math.min(full, math.floor(P.share * s)))", "local want = math.min(full, math.floor(P.share * s))" },
  { "combustible sans part", "local want = math.max(floor_n, math.min(full, math.floor(P.share * s)))", "local want = math.max(floor_n, full)" },
  { "combustible au-dessus de la cible", "if level[i] < target and (best == nil", "if (best == nil" },
  { "combustible au plus plein d'abord", "level[i] < level[best]) then best = i end", "level[i] > level[best]) then best = i end" },
  { "visite sans demande", "if d > 0 and have then", "if have then" },
  { "tour de rôle des produits retiré", "k = k % #products + 1", "k = 1" },
}
local killed, survived = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    survived[#survived + 1] = m[1] .. " (motif absent)"
  else
    local C2 = load_charge(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local ok2, f2 = false, 1
    if C2 then
      ok2, f2 = pcall(function() local _, ff = suite(C2) return ff end)
    end
    if (not C2) or (not ok2) or f2 > 0 then killed = killed + 1 else survived[#survived + 1] = m[1] end
  end
end
if #survived == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[CHARGE] ECHEC : mutants survivants : " .. table.concat(survived, " ; "))
end
print(string.format("[CHARGE] mutants refusés : %d sur %d", killed, #MUTANTS))
print(string.format("[CHARGE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
