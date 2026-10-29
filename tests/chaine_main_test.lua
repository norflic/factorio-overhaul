--[[
  Lot FOURS : test hors jeu de la règle pure shared/team/chaine_main.lua (tournée de fonte utile).
    §1 force brute : smelt_worth contre une référence écrite à part, sur une grille de situations ;
    §2 raisons et cas limites ; §3 filter_tasks ; §4 généralisation (noms changés, déterminisme, aucun nom du jeu) ;
    §5 mutants : chaque ligne de décision altérée est vue (au moins 8).
  Usage : lua5.2 tests/chaine_main_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/chaine_main.lua")

local ok_n, fail_n = 0, 0
local function check(cond, label)
  if cond then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("ECHEC : " .. label) end
end

local function load_mod(src)
  local fn = load(src, "=chaine_main", "t")
  if not fn then return nil end
  local ok, mod = pcall(fn)
  if not ok or type(mod) ~= "table" then return nil end
  return mod
end

local INPUTS = { ["p-fer"] = { "m-fer", 1 }, ["p-cuivre"] = { "m-cuivre", 1 }, ["p-acier"] = { "p-fer", 5 } }

-- Référence écrite à part, sans réutiliser le module.
local function ref_worth(a)
  local smelt, inputs, stock = a.smelt or {}, a.inputs, a.stock or {}
  local total, any = 0, false
  for p, n in pairs(smelt) do
    total = total + n
    local inp = inputs[p]
    if inp and (stock[inp[1]] or 0) >= inp[2] then any = true end
  end
  local thr = a.collect_min or 1
  if total > 0 and total < thr then thr = total end
  if thr < 1 then thr = 1 end
  if (a.output or 0) >= thr then return true end
  if a.fuel_low and (a.fuel_stock == nil or a.fuel_stock >= 1) then return true end
  if any and (a.free == nil or a.free > 0) then return true end
  for item, n in pairs(a.loads or {}) do
    local ratio
    for _, inp in pairs(inputs) do
      if inp[1] == item and (not ratio or inp[2] < ratio) then ratio = inp[2] end
    end
    if n > 0 and ratio and (stock[item] or 0) >= ratio then
      if not inputs[item] then return true end
      for p, q in pairs(smelt) do
        if inputs[p] and inputs[p][1] == item and q > 0 then return true end
      end
    end
  end
  return false
end

local function grid(f)
  local demands = { {}, { ["p-fer"] = 10 }, { ["p-cuivre"] = 4 }, { ["p-fer"] = 10, ["p-cuivre"] = 4 }, { ["p-acier"] = 2 },
    { ["p-inconnu"] = 3 }, { ["p-fer"] = 3 } }
  local stocks = { {}, { ["m-fer"] = 0 }, { ["m-fer"] = 1 }, { ["m-fer"] = 50 }, { ["m-cuivre"] = 1 },
    { ["m-fer"] = 3, ["m-cuivre"] = 3 }, { ["p-fer"] = 4 }, { ["p-fer"] = 5 } }
  local loadss = { nil, {}, { ["m-fer"] = 1 }, { ["p-fer"] = 2 }, { ["m-cuivre"] = 3, ["m-fer"] = 0 } }
  for _, d in ipairs(demands) do
    for _, s in ipairs(stocks) do
      for _, out in ipairs({ 0, 1, 3, 9, 10, 40 }) do
        for _, low in ipairs({ false, true }) do
          for _, fs in ipairs({ -1, 0, 5 }) do
            for _, free in ipairs({ -1, 0, 2 }) do
              for li = 1, 5 do
                f({ smelt = d, inputs = INPUTS, stock = s, output = out, fuel_low = low, collect_min = 10,
                  fuel_stock = fs >= 0 and fs or nil, free = free >= 0 and free or nil, loads = loadss[li] })
              end
            end
          end
        end
      end
    end
  end
end

-- Suite sur un module C ; rend (échecs, contrôles).
local function suite(C, report)
  local bad, n = 0, 0
  local function t(cond, label)
    n = n + 1
    if not cond then
      bad = bad + 1
      if report then report(label) end
    end
  end
  -- §1 force brute
  local cases, diff = 0, 0
  grid(function(a)
    cases = cases + 1
    local w = C.smelt_worth(a)
    if (w and true or false) ~= ref_worth(a) then diff = diff + 1 end
  end)
  t(cases >= 4000 and diff == 0, "§1 force brute : " .. cases .. " cas, " .. diff .. " écart(s) avec la référence")
  -- §2 raisons
  local w, r = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = { ["m-fer"] = 9 }, output = 0, free = 2 })
  t(w and r == "minerai", "§2 minerai au coffre et four libre : tournée, raison minerai")
  w, r = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = { ["m-fer"] = 9 }, output = 0, free = 0 })
  t(not w and r == "fours-occupes", "§2 minerai mais tous les fours chargés : pas de tournée")
  w, r = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = {}, output = 0, free = 3 })
  t(not w and r == "rien", "§2 aucun minerai, rien à vider : tournée à vide refusée")
  w, r = C.smelt_worth({ smelt = { ["p-fer"] = 50 }, inputs = INPUTS, stock = {}, output = 12, free = 0, collect_min = 10 })
  t(w and r == "sortie", "§2 12 plaques en sortie (seuil 10) : tournée, même sans minerai ni four libre")
  w = C.smelt_worth({ smelt = { ["p-fer"] = 50 }, inputs = INPUTS, stock = {}, output = 4, free = 0, collect_min = 10 })
  t(not w, "§2 4 plaques en sortie (seuil 10) et demande de 50 : on attend (pas de passage pour 4 plaques)")
  w = C.smelt_worth({ smelt = { ["p-fer"] = 3 }, inputs = INPUTS, stock = {}, output = 3, free = 0, collect_min = 10 })
  t(w, "§2 demande de 3 plaques et 3 en sortie : le seuil s'abaisse à la demande, tournée")
  w = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = {}, output = 4, free = 0, collect_min = 10 })
  t(not w, "§2 sans demande, 4 plaques en sortie : pas de tournée")
  w, r = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = {}, output = 0, fuel_low = true, fuel_stock = 7 })
  t(w and r == "combustible", "§2 four sans combustible et du charbon au coffre : tournée")
  w = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = {}, output = 0, fuel_low = true, fuel_stock = 0 })
  t(not w, "§2 four sans combustible mais coffre sans charbon : tournée à vide refusée")
  w = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = { ["m-fer"] = 9 }, output = 0 })
  t(w, "§2 fours libres inconnus (nil) : on suppose qu'un four est libre")
  w = C.smelt_worth({ smelt = { ["p-acier"] = 2 }, inputs = INPUTS, stock = { ["p-fer"] = 4 }, output = 0, free = 1 })
  t(not w, "§2 quantité d'entrée par produit : 4 plaques ne font pas un acier (5 requis)")
  w = C.smelt_worth({ smelt = { ["p-acier"] = 2 }, inputs = INPUTS, stock = { ["p-fer"] = 5 }, output = 0, free = 1 })
  t(w, "§2 5 plaques de fer font un acier : tournée")
  w = C.smelt_worth({ smelt = { ["p-inconnu"] = 2 }, inputs = INPUTS, stock = { ["m-fer"] = 99 }, output = 0, free = 1 })
  t(not w, "§2 produit sans entrée connue : ignoré")
  w, r = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = { ["m-fer"] = 30 }, output = 0, free = 0, loads = { ["m-fer"] = 2 } })
  t(w and r == "complement", "§2 deux fours tombés au tiers avec du minerai au coffre : tournée de complément")
  w = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = { ["m-fer"] = 30 }, output = 0, free = 0, loads = { ["m-fer"] = 0 } })
  t(not w, "§2 aucun four à compléter : pas de tournée")
  w = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = {}, output = 0, free = 0, loads = { ["m-fer"] = 2 } })
  t(not w, "§2 four à compléter mais coffre sans minerai : tournée à vide refusée")
  w = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = { ["p-fer"] = 90 }, output = 0, free = 0, loads = { ["p-fer"] = 2 } })
  t(not w, "§2 plaques d'un four d'acier sans demande d'acier : pas de complément (la plaque est rare)")
  w = C.smelt_worth({ smelt = { ["p-acier"] = 4 }, inputs = INPUTS, stock = { ["p-fer"] = 90 }, output = 0, free = 0, loads = { ["p-fer"] = 2 } })
  t(w, "§2 plaques d'un four d'acier avec demande d'acier : complément")
  w = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = {}, output = 0, free = 0, collect_min = 0 })
  t(not w, "§2 seuil de sortie nul et sortie vide : jamais de tournée")
  w = C.smelt_worth({ smelt = {}, inputs = { aa = { "mm", 2 }, bb = { "mm", 5 } }, stock = { mm = 3 }, output = 0, free = 0,
    loads = { mm = 1 } })
  t(w, "§2 une entrée de deux produits : la plus petite quantité par fabrication décide (3 >= 2)")
  -- §3 filter_tasks
  local mine = { key = "mine:x", kind = "mine", prio = 45 }
  local smelt = { key = "smelt", kind = "smelt", prio = 60, smelt = { ["p-fer"] = 8, ["p-cuivre"] = 4 } }
  local out, dropped = C.filter_tasks({ mine, smelt }, { inputs = INPUTS, stock = {}, output = 0, free = 4 })
  t(#out == 1 and out[1] == mine and dropped == 1, "§3 tournée à vide retirée, autre tâche passée telle quelle")
  out, dropped = C.filter_tasks({ mine, smelt }, { inputs = INPUTS, stock = { ["m-fer"] = 9 }, output = 0, free = 4 })
  t(#out == 2 and dropped == 0 and out[2] ~= smelt, "§3 tournée utile gardée, copiée")
  t(out[2].smelt["p-fer"] == 8 and out[2].smelt["p-cuivre"] == nil, "§3 seul le produit dont le minerai attend est gardé")
  t(smelt.smelt["p-cuivre"] == 4, "§3 la tâche d'origine n'est pas modifiée")
  out = C.filter_tasks({ mine, smelt }, { inputs = INPUTS, stock = {}, output = 25, free = 0, collect_min = 10 })
  t(#out == 2 and next(out[2].smelt) == nil, "§3 sortie à vider sans minerai : tournée gardée, aucun produit")
  out = C.filter_tasks(nil, { inputs = INPUTS })
  t(#out == 0, "§3 liste absente : vide")
  return bad, n
end

local C = load_mod(SRC)
assert(C, "chaine_main.lua ne se charge pas")
local fails = {}
local bad, nchecks = suite(C, function(l) fails[#fails + 1] = l end)
for _, l in ipairs(fails) do print("ECHEC : " .. l) end
check(bad == 0, "§1 à §3 : la suite entière passe (" .. bad .. " échec(s) sur " .. nchecks .. ")")
ok_n = ok_n + nchecks - bad

-- §4 généralisation
check(not SRC:find("iron") and not SRC:find("coal") and not SRC:find("stone") and not SRC:find("copper"), "§4 aucun nom du jeu dans la règle")
do
  local I2 = { ["zz"] = { "aa", 2 }, ["yy"] = { "zz", 3 } }
  local w1 = C.smelt_worth({ smelt = { zz = 4 }, inputs = I2, stock = { aa = 2 }, output = 0, free = 1 })
  local w2 = C.smelt_worth({ smelt = { zz = 4 }, inputs = I2, stock = { aa = 1 }, output = 0, free = 1 })
  check(w1 and not w2, "§4 autres noms et autres quantités : mêmes décisions")
  local a1, a2 = {}, {}
  for _ = 1, 3 do
    local _, r1 = C.smelt_worth({ smelt = { zz = 4, yy = 2 }, inputs = I2, stock = { aa = 4, zz = 6 }, output = 0, free = 1, loads = { aa = 1, zz = 1 } })
    a1[#a1 + 1] = r1
  end
  for _ = 1, 3 do
    local _, r2 = C.smelt_worth({ smelt = { yy = 2, zz = 4 }, inputs = I2, stock = { zz = 6, aa = 4 }, output = 0, free = 1, loads = { zz = 1, aa = 1 } })
    a2[#a2 + 1] = r2
  end
  check(table.concat(a1, ",") == table.concat(a2, ","), "§4 déterminisme : ordre de construction des tables sans effet")
end

-- §5 mutants
local MUTANTS = {
  { 'if (a.output or 0) >= threshold then return true, "sortie", kept end', 'if (a.output or 0) > threshold then return true, "sortie", kept end', "seuil de sortie strict" },
  { "if total > 0 and total < threshold then threshold = total end", "", "seuil abaissé à la demande retiré" },
  { "if threshold < 1 then threshold = 1 end", "if threshold < 0 then threshold = 0 end", "seuil minimal 0 (tournée pour une sortie vide)" },
  { 'if a.fuel_low and (a.fuel_stock == nil or a.fuel_stock >= 1) then', 'if a.fuel_low then', "charbon du coffre non regardé" },
  { 'a.fuel_stock == nil or a.fuel_stock >= 1', 'a.fuel_stock ~= nil and a.fuel_stock >= 1', "stock de charbon inconnu = absent" },
  { 'if next(kept) ~= nil and (a.free == nil or a.free > 0) then', 'if next(kept) ~= nil then', "four libre non regardé" },
  { 'a.free == nil or a.free > 0', 'a.free ~= nil and a.free > 0', "fours libres inconnus = aucun" },
  { 'if inp and ((stock and stock[inp[1]]) or 0) >= inp[2] then out[p] = smelt[p] end', 'if inp and ((stock and stock[inp[1]]) or 0) >= 1 then out[p] = smelt[p] end', "quantité d'entrée par produit ignorée" },
  { 'and ((stock and stock[item]) or 0) >= ratio', '', "stock de l'entrée à compléter non regardé" },
  { 'and (not (inputs and inputs[item]) or demanded(smelt, inputs, item)) then', 'then', "complément d'un produit intermédiaire sans demande" },
  { 'if n and n > 0 and ratio', 'if n and ratio', "four à compléter : nombre nul accepté" },
  { "c.smelt = kept", "c.smelt = t.smelt", "produits sans minerai gardés dans la tournée" },
  { 'if inp[1] == item and (not best or inp[2] < best) then best = inp[2] end', 'if inp[1] == item then best = inp[2] end', "plus petit rapport non retenu" },
}
-- (le mutant « inp[1] == item » ci-dessus est écrit sur la ligne exacte de la source)
local detected = 0
for _, m in ipairs(MUTANTS) do
  local i, j = SRC:find(m[1], 1, true)
  local seen = false
  if not i then
    print("ECHEC : mutant introuvable dans la source : " .. m[3])
  else
    local msrc = SRC:sub(1, i - 1) .. m[2] .. SRC:sub(j + 1)
    local M = load_mod(msrc)
    if not M then
      seen = true
    else
      local ok, b = pcall(suite, M, nil)
      seen = (not ok) or b > 0
    end
  end
  if seen then detected = detected + 1 else print("ECHEC : mutant NON vu : " .. m[3]) end
  check(seen, "§5 mutant vu : " .. m[3])
end
check(detected == #MUTANTS and #MUTANTS >= 8, "§5 " .. detected .. "/" .. #MUTANTS .. " mutants refusés")

print(string.format("[FOURS-CHAINE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
