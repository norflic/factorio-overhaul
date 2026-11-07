--[[
  Lot VIDEO-TRACES, partie a (G34) : journal [FO-RANG] du rang de la décision.
    §1 Rg.chain_signature : stable pour un même résultat, change si un rang change, si un objet entre ou sort ;
    §2 Rg.text_chain : ligne au format attendu, sur un résultat réel de Rg.chain (pas un jouet) ;
    §3 script/ai3/rang_trace.lua : deux décisions de MÊME signature = une ligne ; une signature changée = une ligne de plus ;
       un seul relevé par faction et par signature (deux factions = deux lignes) ;
    §4 mutants (chacun doit être vu) : un sur la règle pure (signature), trois sur le journal.
  Usage : lua5.2 tests/rang_trace_test.lua   (depuis la racine du mod). Le journal est testé avec un Storage et un log simulés.
]]

package.path = "./?.lua;" .. package.path
local Rg = require("shared.ai3.rang")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[FO-RANG-TEST] ECHEC : " .. msg) end
end

-- Relevé jouet : o1 brut ; a <- o1 ; b <- a ; c <- a, b ; d <- o1 (rang 1) . Recette choisie = la seule de chaque objet.
local function dataset(extra)
  local recipes = {
    a = { name = "a", ingredients = { { name = "o1", amount = 1 } } },
    b = { name = "b", ingredients = { { name = "a", amount = 1 } } },
    c = { name = "c", ingredients = { { name = "a", amount = 1 }, { name = "b", amount = 1 } } },
    d = { name = "d", ingredients = { { name = "o1", amount = 2 } } },
  }
  if extra then recipes.a = { name = "a", ingredients = { { name = "o1", amount = 1 }, { name = "e", amount = 1 } } } end
  local D = { res = { o1 = true }, recipes = recipes }
  local pick = function(i) if recipes[i] then return recipes[i] end return nil, "aucune recette" end
  return D, pick
end

local D, pick = dataset(false)
local R = Rg.chain(D, pick, { "c", "d" })
local S = Rg.chain_signature(R)

-- §1 signature
check(Rg.chain_signature(Rg.chain(D, pick, { "c", "d" })) == S, "§1 même résultat, même signature")
check(Rg.chain_signature(R) == S, "§1 signature déterministe sur un second appel")
local D2, pick2 = dataset(true)
local R2 = Rg.chain(D2, pick2, { "c", "d" })
check(Rg.chain_signature(R2) ~= S, "§1 une recette qui ajoute un objet (e) change la signature")
local Rrank = Rg.chain(D, pick, { "c", "d" })
Rrank.rank = setmetatable({ d = 5 }, { __index = Rrank.rank })
check(Rg.chain_signature(Rrank) ~= S, "§1 un rang changé change la signature")

-- §2 texte
local line = Rg.text_chain(R, "F1")
check(line:match("^%[FO%-RANG%] F1 : 5 objets, 4 recettes choisies, 0 sans recette ou a fluide, rangs 0 a 3 %(") ~= nil,
  "§2 en-tête : objets, recettes, rangs (texte : " .. line .. ")")
check(line:find("0:1 1:2 2:1 3:1", 1, true) ~= nil or line:find("0:1 ", 1, true) ~= nil, "§2 répartition par rang présente")
check(line:find("cycles 0 []", 1, true) ~= nil, "§2 aucun cycle dans ce relevé")
local R_fluid = Rg.chain({ res = { o1 = true }, recipes = {} }, function() return nil, "aucune recette" end, { "x" })
check(Rg.text_chain(R_fluid, "F2"):find("1 sans recette ou a fluide", 1, true) ~= nil, "§2 un objet sans recette est compté")

-- §3 journal, avec Storage et log simulés (note(f, R, tick) : R = rang de la décision, J.ctx.rang)
local function run_trace(src)
  local store = { rang_trace = { sig = {} } }
  local lines = {}
  package.loaded["script.core.storage"] = { declare = function() end, ns = function(n) return store[n] end }
  _G.log = function(s) lines[#lines + 1] = s end
  local chunk = assert(load(src, "@script/ai3/rang_trace.lua"))
  return chunk(), lines, store
end
local SRC = assert(io.open("script/ai3/rang_trace.lua", "rb")):read("*a")
local M, lines = run_trace(SRC)
check(M ~= nil and M.note ~= nil, "§3 module chargé")
local f1 = { key = "F1" }
check(M.note(f1, R, 3600) == true, "§3 première décision : une ligne")
check(M.note(f1, R, 7200) == false, "§3 même signature : pas de ligne")
check(M.note(f1, R, 9000) == false, "§3 même signature, troisième décision : pas de ligne")
check(#lines == 1, "§3 une seule ligne jusqu'ici (" .. #lines .. ")")
check(M.note(f1, R2, 10800) == true, "§3 signature changée : une ligne de plus")
check(M.note(f1, R2, 12600) == false, "§3 retour au même résultat : même signature, pas de ligne")
check(#lines == 2 and lines[2]:find(" a 3.0 min", 1, true) ~= nil, "§3 deux lignes, la seconde horodatée à 3,0 min")
check(M.note(f1, nil, 14400) == false, "§3 décision sans rang : rien")
check(M.note({ key = "F2" }, R, 3600) == true and #lines == 3, "§3 deux factions : une ligne chacune")

-- §4 mutants
local function mutate(src, a, b)
  local i, j = src:find(a, 1, true)
  if not i then return nil end
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
local MUT = {
  { "journal sans mémoire (toujours une ligne)", SRC, "if sigs[key] == sig then return false end", "if false then return false end" },
  { "mémoire jamais mise à jour", SRC, "sigs[key] = sig\n", "" },
  { "mémoire écrasée par faction (une seule clé)", SRC, 'local key = tostring(f.key or "player")', 'local key = "any"' },
}
local caught = 0
for _, m in ipairs(MUT) do
  local src = mutate(m[2], m[3], m[4])
  if src == nil then fail = fail + 1; print("[FO-RANG-TEST] ECHEC : mutant absent (" .. m[1] .. ")")
  else
    local Mm, ml = run_trace(src)
    local n = 0
    if Mm then
      n = (Mm.note({ key = "F1" }, R, 3600) and 1 or 0) + (Mm.note({ key = "F1" }, R, 7200) and 1 or 0)
      n = n + (Mm.note({ key = "F2" }, R, 7200) and 1 or 0)
    end
    if n ~= 2 or #ml ~= 2 then caught = caught + 1 else fail = fail + 1; print("[FO-RANG-TEST] ECHEC : mutant survivant (" .. m[1] .. ")") end
  end
end
-- mutant de la règle pure : la signature ignore les rangs
local rang_src = assert(io.open("shared/ai3/rang.lua", "rb")):read("*a")
local mut_sig = mutate(rang_src, 'local s = i .. "=" .. tostring(res.rank[i]) .. ";"', 'local s = i .. ";"')
if mut_sig then
  local chunk = load(mut_sig, "@shared/ai3/rang.lua")
  local Rm = chunk()
  local Rr = Rg.chain(D, pick, { "c", "d" })
  Rr.rank = setmetatable({ d = 5 }, { __index = Rr.rank })
  if Rm.signature(Rr) == Rm.signature(R) then caught = caught + 1 else fail = fail + 1; print("[FO-RANG-TEST] ECHEC : mutant survivant (signature sans rang)") end
else fail = fail + 1; print("[FO-RANG-TEST] ECHEC : mutant signature absent") end
check(caught == 4, "§4 quatre mutants refusés")

print(string.format("[FO-RANG-TEST] BILAN : %d OK, %d ECHEC(S) (mutants refusés %d sur 4)", pass, fail, caught))
if fail > 0 then os.exit(1) end
