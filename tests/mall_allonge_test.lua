--[[
  Lot MALL : contrôle hors jeu de la règle d'allongement au-delà de la demande (shared/team/mall_allonge.lua), mutants compris.
  Usage : lua5.2 tests/mall_allonge_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end

local Ma = require("shared.team.mall_allonge")

local function cas(M)
  local out = {}
  local B1 = { { item = "a", per_machine = 15 } }
  -- débit 600/min : le mall a droit à 150 ; machine à 15 : 10 machines, 5 cellules de plus
  out.base = { M.cible(2, B1, { a = 600 }, { a = 3000 }, { a = 0 }, 64) }
  -- le fer manque : stock libre sous 5 min de débit
  out.manque = { M.cible(2, B1, { a = 600 }, { a = 2999 }, { a = 0 }, 64) }
  out.juste = { M.cible(2, B1, { a = 600 }, { a = 3000 }, { a = 0 }, 64) }
  -- sans débit
  out.zero = { M.cible(2, B1, { a = 0 }, { a = 9999 }, { a = 0 }, 64) }
  out.absent = { M.cible(2, B1, {}, { a = 9999 }, { a = 0 }, 64) }
  -- le mall boit déjà sa part
  out.bu = { M.cible(2, B1, { a = 600 }, { a = 3000 }, { a = 150 }, 64) }
  out.partiel = { M.cible(2, B1, { a = 600 }, { a = 3000 }, { a = 90 }, 64) }
  -- l'entrée la plus serrée borne
  local B2 = { { item = "a", per_machine = 15 }, { item = "b", per_machine = 30 } }
  out.serre = { M.cible(2, B2, { a = 600, b = 240 }, { a = 3000, b = 1200 }, { a = 0, b = 0 }, 64) }
  -- une entrée sans stock suffit à bloquer
  out.bloque = { M.cible(2, B2, { a = 600, b = 240 }, { a = 3000, b = 1199 }, { a = 0, b = 0 }, 64) }
  -- plafond ; machines impaires : on arrondit à la cellule entière
  out.plafond = { M.cible(2, B1, { a = 6000 }, { a = 30000 }, { a = 0 }, 8) }
  out.impair = { M.cible(2, { { item = "a", per_machine = 50 } }, { a = 600 }, { a = 3000 }, { a = 0 }, 64) }
  out.vide = { M.cible(3, {}, {}, {}, {}, 64) }
  return out
end

local function sig(o)
  local keys = { "base", "manque", "juste", "zero", "absent", "bu", "partiel", "serre", "bloque", "plafond", "impair", "vide" }
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(o[k][1]) .. ":" .. tostring(o[k][2]) end -- (la raison va au journal : elle compte)
  return table.concat(parts, " ")
end

local o = cas(Ma)
check(o.base[1] == 7 and o.base[2] == "surplus", "débit 600, 25 %, machine à 15 : 5 cellules de plus (" .. o.base[1] .. ")")
check(o.manque[1] == 2 and tostring(o.manque[2]):find("stock libre", 1, true), "le fer manque : aucune cellule de plus (" .. tostring(o.manque[2]) .. ")")
check(o.juste[1] == 7, "stock libre exactement à 5 min : allongement permis")
check(o.zero[1] == 2 and o.absent[1] == 2, "sans débit mesuré : rien")
check(o.bu[1] == 2 and tostring(o.bu[2]):find("deja bu", 1, true), "le mall boit déjà sa part : rien")
check(o.partiel[1] == 4, "marge restante 60 : 4 machines, 2 cellules (" .. o.partiel[1] .. ")")
check(o.serre[1] == 2 + 1, "entrée la plus serrée : 60 / 30 = 2 machines, 1 cellule (" .. o.serre[1] .. ")")
check(o.bloque[1] == 2, "une entrée sous sa réserve bloque tout")
check(o.plafond[1] == 8, "plafond respecté")
check(o.impair[1] == 3, "3 machines possibles : 1 cellule entière (" .. o.impair[1] .. ")")
check(o.vide[1] == 3, "rangée sans entrée connue : inchangée")

local ref = sig(o)
local src = assert(io.open("shared/team/mall_allonge.lua", "rb")):read("*a")
local mutants = {
  { "(libre[b.item] or 0) < debit * Ma.RESERVE_MIN", "false", "allonge alors que le fer manque" },
  { "(libre[b.item] or 0) < debit * Ma.RESERVE_MIN", "(libre[b.item] or 0) <= debit * Ma.RESERVE_MIN", "seuil de stock décalé" },
  { "if debit <= 0 then", "if false then", "allonge sans débit" },
  { "if marge <= 0 then", "if false then", "ignore ce que le mall boit déjà" },
  { "debit * Ma.PART - (conso[b.item] or 0)", "debit * Ma.PART", "conso oubliée" },
  { "if not extra or m < extra then extra = m end", "if not extra or m > extra then extra = m end", "entrée la plus large au lieu de la plus serrée" },
  { "math.floor(extra / Ma.PAR_CELLULE)", "extra", "une cellule par machine" },
  { "if n > max_cells then n = max_cells end", "", "plafond oublié" },
}
local vus = 0
for _, m in ipairs(mutants) do
  local i, j = src:find(m[1], 1, true)
  assert(i, "motif introuvable : " .. m[1])
  local code = src:sub(1, i - 1) .. m[2] .. src:sub(j + 1)
  local M2 = assert(load(code, "mutant", "t"))()
  local ok, s = pcall(function() return sig(cas(M2)) end)
  local refuse = (not ok) or s ~= ref
  check(refuse, "mutant vu : " .. m[3])
  if refuse then vus = vus + 1 end
end
print(string.format("[MALL-ALLONGE] mutants refusés : %d/%d", vus, #mutants))
print(string.format("[MALL-ALLONGE] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
