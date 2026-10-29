--[[
  Lot MAINS-CHAINE : test hors jeu de la règle pure shared/team/chaine_main.lua et de son branchement dans le travail de fond
  (shared/team/fond.lua).
    §1 force brute : smelt_worth contre une référence écrite à part, sur toutes les combinaisons d'une grille (demande, stock,
       sortie, combustible, fours libres) ;
    §2 filter_tasks : tournée à vide retirée, tournée utile gardée (copiée, produits sans minerai retirés), autres tâches intactes,
       entrée non modifiée ;
    §3 mine_candidates : minerai en écart 0 écarté tant qu'une ressource manque, liste intacte si rien ne manque ;
    §4 branchement dans Fond.candidates (minage de fond et tournée de fond sans four libre) ;
    §5 généralisation : noms d'objets changés, mêmes décisions ; déterminisme ; aucun nom du jeu dans la règle ;
    §6 mutants : chaque ligne de décision retirée ou inversée est vue (au moins 15).
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

---------------------------------------------------------------------------------------------------
-- Référence (écrite à part, sans réutiliser le module) : une tournée est utile si une sortie attend, si un four manque de
-- combustible, ou si du minerai attend pour un produit demandé et qu'un four n'est pas connu comme occupé.
---------------------------------------------------------------------------------------------------
local function ref_worth(a)
  if (a.output or 0) > 0 then return true end
  if a.fuel_low then return true end
  local any = false
  for p, _ in pairs(a.smelt or {}) do
    local inp = a.inputs[p]
    if inp and ((a.stock or {})[inp[1]] or 0) >= inp[2] then any = true end
  end
  if not any then return false end
  if a.free ~= nil and a.free <= 0 then return false end
  return true
end

local function grid(f)
  local demands = { {}, { ["p-fer"] = 10 }, { ["p-cuivre"] = 4 }, { ["p-fer"] = 10, ["p-cuivre"] = 4 }, { ["p-acier"] = 2 },
    { ["p-inconnu"] = 3 } }
  local stocks = { {}, { ["m-fer"] = 0 }, { ["m-fer"] = 1 }, { ["m-fer"] = 50 }, { ["m-cuivre"] = 1 },
    { ["m-fer"] = 3, ["m-cuivre"] = 3 }, { ["p-fer"] = 4 }, { ["p-fer"] = 5 } }
  for _, d in ipairs(demands) do
    for _, s in ipairs(stocks) do
      for _, out in ipairs({ 0, 1, 40 }) do
        for _, low in ipairs({ false, true }) do
          for _, free in ipairs({ -1, 0, 1, 4 }) do
            f({ smelt = d, inputs = INPUTS, stock = s, output = out, fuel_low = low, free = free >= 0 and free or nil })
          end
        end
      end
    end
  end
end

local function run_brute(C, label)
  local n, bad = 0, 0
  grid(function(a)
    n = n + 1
    local w = C.smelt_worth(a)
    if (w and true or false) ~= ref_worth(a) then bad = bad + 1 end
  end)
  return n, bad
end

local C = load_mod(SRC)
assert(C, "chaine_main.lua ne se charge pas")

local n, bad = run_brute(C)
check(n >= 1000 and bad == 0, "§1 force brute : " .. n .. " cas, " .. bad .. " écart(s) avec la référence")

-- raisons
do
  local w, r = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = { ["m-fer"] = 9 }, output = 0, free = 2 })
  check(w and r == "minerai", "§1 minerai au coffre et four libre : tournée, raison minerai")
  w, r = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = { ["m-fer"] = 9 }, output = 0, free = 0 })
  check(not w and r == "fours-occupes", "§1 minerai mais tous les fours occupés : pas de tournée")
  w, r = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = {}, output = 0, free = 3 })
  check(not w and r == "rien", "§1 aucun minerai, rien à vider : tournée à vide refusée")
  w, r = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = {}, output = 7, free = 0 })
  check(w and r == "sortie", "§1 sortie à vider : tournée même sans minerai ni four libre")
  w, r = C.smelt_worth({ smelt = {}, inputs = INPUTS, stock = {}, output = 0, fuel_low = true })
  check(w and r == "combustible", "§1 four sans combustible : tournée")
  w = C.smelt_worth({ smelt = { ["p-fer"] = 5 }, inputs = INPUTS, stock = { ["m-fer"] = 9 }, output = 0 })
  check(w, "§1 fours libres inconnus (nil) : on suppose qu'un four est libre")
  w = C.smelt_worth({ smelt = { ["p-acier"] = 2 }, inputs = INPUTS, stock = { ["p-fer"] = 4 }, output = 0, free = 1 })
  check(not w, "§1 quantité d'entrée par produit : 4 plaques ne font pas un acier (5 requis)")
  w = C.smelt_worth({ smelt = { ["p-acier"] = 2 }, inputs = INPUTS, stock = { ["p-fer"] = 5 }, output = 0, free = 1 })
  check(w, "§1 5 plaques de fer font un acier : tournée")
  w = C.smelt_worth({ smelt = { ["p-inconnu"] = 2 }, inputs = INPUTS, stock = { ["m-fer"] = 99 }, output = 0, free = 1 })
  check(not w, "§1 produit sans entrée connue : ignoré")
end

---------------------------------------------------------------------------------------------------
-- §2 filter_tasks
---------------------------------------------------------------------------------------------------
do
  local mine = { key = "mine:x", kind = "mine", prio = 45 }
  local smelt = { key = "smelt", kind = "smelt", prio = 60, smelt = { ["p-fer"] = 8, ["p-cuivre"] = 4 } }
  local tasks = { mine, smelt }
  local out, dropped = C.filter_tasks(tasks, { inputs = INPUTS, stock = {}, output = 0, free = 4 })
  check(#out == 1 and out[1] == mine and dropped == 1, "§2 tournée à vide retirée, autre tâche passée telle quelle (même table)")
  out, dropped = C.filter_tasks(tasks, { inputs = INPUTS, stock = { ["m-fer"] = 10 }, output = 0, free = 4 })
  check(#out == 2 and dropped == 0, "§2 minerai de fer au coffre : tournée gardée")
  check(out[2] ~= smelt and out[2].key == "smelt" and out[2].prio == 60, "§2 la tournée gardée est une COPIE qui garde clé et priorité")
  check(out[2].smelt["p-fer"] == 8 and out[2].smelt["p-cuivre"] == nil, "§2 seul le produit dont le minerai attend est gardé")
  check(smelt.smelt["p-cuivre"] == 4, "§2 la tâche d'entrée n'est pas modifiée")
  out = C.filter_tasks(tasks, { inputs = INPUTS, stock = {}, output = 12, free = 0 })
  check(#out == 2 and next(out[2].smelt) == nil, "§2 sortie à vider : tournée gardée, sans demande de minerai")
  out = C.filter_tasks({}, { inputs = INPUTS, stock = {} })
  check(#out == 0, "§2 liste vide")
  out = C.filter_tasks(nil, { inputs = INPUTS, stock = {} })
  check(#out == 0, "§2 liste absente")
end

---------------------------------------------------------------------------------------------------
-- §3 mine_candidates
---------------------------------------------------------------------------------------------------
do
  local function L(a) return a end
  local list = L({ { res = "c", gap = 0, i = 1, ore = false }, { res = "o", gap = 0, i = 2, ore = true },
    { res = "o2", gap = 300, i = 3, ore = true } })
  local out = C.mine_candidates(list)
  local names = {}
  for _, m in ipairs(out) do names[#names + 1] = m.res end
  check(table.concat(names, ",") == "c,o2", "§3 minerai en écart 0 écarté, non-minerai en écart 0 gardé (« " .. table.concat(names, ",") .. " »)")
  local all0 = L({ { res = "c", gap = 0, i = 1, ore = false }, { res = "o", gap = 0, i = 2, ore = true } })
  check(C.mine_candidates(all0) == all0 and #all0 == 2, "§3 rien ne manque : liste intacte (pas de chômage de fond)")
  local only = L({ { res = "o", gap = 10, i = 1, ore = true } })
  check(#C.mine_candidates(only) == 1, "§3 minerai en manque : gardé")
  check(#C.mine_candidates({}) == 0, "§3 liste vide")
end

---------------------------------------------------------------------------------------------------
-- §4 branchement dans Fond.candidates
---------------------------------------------------------------------------------------------------
local function fond_run(view, free, ctx)
  package.loaded["shared.team.fond"] = nil
  local F = require("shared.team.fond")
  return F, F.candidates(view, free, ctx)
end
do
  local T = require("shared.team.config")
  local view = { outposts = {}, sites = {}, smelters = 4, stock = {}, incoming = {} }
  local function kinds(c)
    local ks = {}
    for _, t in ipairs(c.extraction) do ks[#ks + 1] = t.kind .. ":" .. (t.resource or "") end
    return table.concat(ks, " ")
  end
  local ore = T.smelter_inputs["iron-plate"][1]
  local free = { [ore] = 400, coal = 0, stone = 0, ["copper-ore"] = 0 }
  local _, c = fond_run(view, free, { keys = {}, mine_left = 8 })
  local s = kinds(c)
  check(not s:find("mine:" .. ore, 1, true), "§4 fond : le minerai de fer en écart 0 n'est pas miné quand charbon, pierre et cuivre manquent (« " .. s .. " »)")
  check(s:find("smelt:", 1, true) ~= nil, "§4 fond : 400 minerais au coffre et des fours : tournée de fond")
  view.smelters_free = 0
  _, c = fond_run(view, { [ore] = 400, coal = 0, stone = 0, ["copper-ore"] = 0 }, { keys = {}, mine_left = 8 })
  check(not kinds(c):find("smelt:", 1, true), "§4 fond : aucun four libre, pas de tournée de fond")
  view.smelters_free = nil
  -- tout est plein : le fond continue de miner (comme avant)
  _, c = fond_run(view, { [ore] = 400, coal = 900, stone = 900, ["copper-ore"] = 900 }, { keys = {}, mine_left = 4 })
  local n_mine = 0
  for _, t in ipairs(c.extraction) do if t.kind == "mine" then n_mine = n_mine + 1 end end
  check(n_mine == 4, "§4 fond : tout est plein, 4 minages comme avant (" .. n_mine .. ")")
end

---------------------------------------------------------------------------------------------------
-- §5 généralisation, déterminisme, aucun nom du jeu
---------------------------------------------------------------------------------------------------
do
  local NEW = { ["zz-1"] = { "aa-1", 2 }, ["zz-2"] = { "aa-2", 1 } }
  local a = { smelt = { ["zz-1"] = 3 }, inputs = NEW, stock = { ["aa-1"] = 2 }, output = 0, free = 1 }
  check(C.smelt_worth(a) == true, "§5 noms changés : minerai suffisant, tournée")
  a.stock["aa-1"] = 1
  check(C.smelt_worth(a) == false, "§5 noms changés : minerai insuffisant (2 requis), pas de tournée")
  local ta = { { key = "smelt", kind = "smelt", smelt = { ["zz-1"] = 1, ["zz-2"] = 1 } } }
  local o1 = C.filter_tasks(ta, { inputs = NEW, stock = { ["aa-1"] = 9, ["aa-2"] = 9 }, free = 1 })
  local o2 = C.filter_tasks(ta, { inputs = NEW, stock = { ["aa-1"] = 9, ["aa-2"] = 9 }, free = 1 })
  check(o1[1].smelt["zz-1"] == 1 and o1[1].smelt["zz-2"] == 1 and o2[1].smelt["zz-2"] == 1, "§5 déterminisme : deux appels, même sortie")
  local code = SRC:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local noms = { "iron", "copper", "coal", "stone", "plate", "ore", "steel", "furnace" }
  local trouve = {}
  for _, w in ipairs(noms) do
    if code:find('"[%w%-]*' .. w .. '[%w%-]*"') then trouve[#trouve + 1] = w end
  end
  check(#trouve == 0, "§5 aucun nom d'objet du jeu dans la règle (trouvé : " .. table.concat(trouve, ",") .. ")")
  check(not code:find("[^%w_]pairs%(") or code:find("sorted_keys"), "§5 pas de pairs dans une décision (seulement pour trier)")
end

---------------------------------------------------------------------------------------------------
-- §6 mutants
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "sortie ignorée", "if (a.output or 0) > 0 then return true", "if (a.output or 0) > 9999 then return true" },
  { "sortie < 0", "if (a.output or 0) > 0 then return true", "if (a.output or 0) >= 0 then return true" },
  { "combustible ignoré", "if a.fuel_low then return true", "if false then return true" },
  { "combustible inversé", "if a.fuel_low then return true", "if not a.fuel_low then return true" },
  { "four libre ignoré", "(a.free == nil or a.free > 0)", "true" },
  { "four libre à 0 accepté", "a.free > 0)", "a.free >= 0)" },
  { "free nil refusé", "(a.free == nil or a.free > 0)", "(a.free ~= nil and a.free > 0)" },
  { "toujours utile", "return false, \"rien\", kept", "return true, \"rien\", kept" },
  { "minerai non regardé", "next(kept) ~= nil and (a.free", "true and (a.free" },
  { "seuil du stock > au lieu de >=", "(stock and stock[inp[1]]) or 0) >= inp[2]", "(stock and stock[inp[1]]) or 0) > inp[2]" },
  { "seuil du stock ignoré", "(stock and stock[inp[1]]) or 0) >= inp[2]", "(stock and stock[inp[1]]) or 0) >= 0" },
  { "quantité par produit ignorée", ") >= inp[2] then out[p]", ") >= 1 then out[p]" },
  { "tous les produits gardés", "if inp and ((stock and stock[inp[1]]) or 0) >= inp[2] then out[p] = smelt[p] end",
    "if inp then out[p] = smelt[p] end" },
  { "tournée à vide gardée", "if worth then\n        local c = {}", "if true then\n        local c = {}" },
  { "tournée utile retirée", "if worth then\n        local c = {}", "if not worth then\n        local c = {}" },
  { "produits non filtrés dans la copie", "c.smelt = kept", "c.smelt = t.smelt" },
  { "tâche d'entrée modifiée", "local c = {}\n        for _, k in ipairs(sorted_keys(t)) do c[k] = t[k] end", "local c = t" },
  { "autres tâches retirées", "      out[#out + 1] = t\n    end\n  end\n  return out, dropped",
    "    end\n  end\n  return out, dropped" },
  { "décompte des retraits", "dropped = dropped + 1", "dropped = dropped + 0" },
  { "minerai en écart 0 gardé", "if not (m.ore and m.gap <= 0) then", "if true then" },
  { "tout écart 0 écarté", "if not (m.ore and m.gap <= 0) then", "if not (m.gap <= 0) then" },
  { "écart > 0 écarté", "if not (m.ore and m.gap <= 0) then", "if not (m.ore and m.gap > 0) then" },
  { "chômage de fond quand tout est plein", "  if not need then return list end", "  if not need then return {} end" },
  { "manque jamais vu", "if m.gap > 0 then need = true break end", "if m.gap > 1e9 then need = true break end" },
  { "minerai marqué par défaut", "if not (m.ore and m.gap <= 0) then", "if not (m.gap <= 0) then" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local src, cnt = SRC:gsub(m[2]:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (m[3]:gsub("%%", "%%%%")), 1)
  local seen = false
  if cnt ~= 1 then
    seen = false
    kept[#kept + 1] = m[1] .. " (motif absent du source : mutant mal écrit)"
  else
    local M = load_mod(src)
    if not M then
      seen = true -- ne charge plus : refusé par le chargement
    else
      local _, nb = run_brute(M)
      local _, bb = run_brute(M)
      if bb > 0 then seen = true end
      -- §2 et §3 : rejoué sur le mutant
      if not seen then
        local tk = { { key = "smelt", kind = "smelt", smelt = { ["p-fer"] = 8, ["p-cuivre"] = 4 } }, { key = "m", kind = "mine" } }
        local ok1, o1, d1 = pcall(M.filter_tasks, tk, { inputs = INPUTS, stock = {}, output = 0, free = 4 })
        if not ok1 or #o1 ~= 1 or d1 ~= 1 then seen = true end
        local ok2, o2 = pcall(M.filter_tasks, tk, { inputs = INPUTS, stock = { ["m-fer"] = 10 }, output = 0, free = 4 })
        if not ok2 or #o2 ~= 2 or o2[1].smelt == nil or o2[1].smelt["p-cuivre"] ~= nil or o2[1] == tk[1] then seen = true end
        if tk[1].smelt["p-cuivre"] ~= 4 then seen = true end
        local list = { { res = "c", gap = 0, i = 1, ore = false }, { res = "o", gap = 0, i = 2, ore = true },
          { res = "o2", gap = 300, i = 3, ore = true } }
        local ok3, r3 = pcall(M.mine_candidates, list)
        local names = {}
        if ok3 then for _, x in ipairs(r3) do names[#names + 1] = x.res end end
        if not ok3 or table.concat(names, ",") ~= "c,o2" then seen = true end
        local all0 = { { res = "c", gap = 0, i = 1, ore = false }, { res = "o", gap = 0, i = 2, ore = true } }
        local ok4, r4 = pcall(M.mine_candidates, all0)
        if not ok4 or #r4 ~= 2 then seen = true end
        -- sortie seule, sans minerai : la tournée reste
        local ok5, o5 = pcall(M.filter_tasks, tk, { inputs = INPUTS, stock = {}, output = 5, free = 0 })
        if not ok5 or #o5 ~= 2 then seen = true end
      end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(#kept == 0, "§6 mutants NON refusés : " .. table.concat(kept, " ; "))
check(refused >= 15, "§6 au moins 15 mutants refusés (" .. refused .. " sur " .. #MUTANTS .. ")")
print(string.format("[MAINS-CHAINE] mutants refusés : %d sur %d", refused, #MUTANTS))

print(string.format("[MAINS-CHAINE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
