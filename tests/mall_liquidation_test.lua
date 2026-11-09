--[[
  Lot MALL-LIQUIDATION : contrôle hors jeu de la règle pure « le stock de machines qui dort paie une section de mall » (shared/team/mall_liquidation.lua),
  mutants compris ; contrôle textuel du câblage dans script/team/mall_rangee.lua (allongement au surplus : la liquidation passe AVANT la règle du débit).
  Usage : lua5.2 tests/mall_liquidation_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end

local SRC = "shared/team/mall_liquidation.lua"
local Ml = require("shared.team.mall_liquidation")

-- une section de rangée : 8 machines, 16 bras, 40 tapis, 4 poteaux (liste triée par nom, objets opaques)
local SECTION = { { "bras", 16, false }, { "machine", 8, true }, { "poteau", 4, false }, { "tapis", 40, false } }

local function cas(M)
  local out = {}
  out.trente = { M.surplus({ machine = 30, bras = 100, tapis = 500, poteau = 20 }, SECTION) }   -- 30 × 0,8 = 24 : 3 sections
  out.neuf = { M.surplus({ machine = 9, bras = 100, tapis = 500, poteau = 20 }, SECTION) }      -- 9 × 0,8 = 7,2 < 8 : non
  out.dix = { M.surplus({ machine = 10, bras = 100, tapis = 500, poteau = 20 }, SECTION) }      -- 10 × 0,8 = 8 : une section
  out.vide = { M.surplus({}, SECTION) }
  out.sans_tapis = { M.surplus({ machine = 30 }, SECTION) }                                     -- tapis, bras, poteaux absents : on pose ce qu'on a
  out.que_tapis = { M.surplus({ bras = 1000, tapis = 1000, poteau = 1000 }, SECTION) }           -- aucune machine au coffre : non
  out.sans_machine = { M.surplus({ machine = 30 }, { { "bras", 16, false } }) }                  -- section sans machine : non
  out.mesure_dc = { M.surplus({ machine = 3952 }, SECTION) }                                    -- la mesure du DC à 90 min : 3952 × 0,8 / 8 = 395 sections
  out.nul = { M.surplus(nil, SECTION) }
  return out
end

local KEYS = { "trente", "neuf", "dix", "vide", "sans_tapis", "que_tapis", "sans_machine", "mesure_dc", "nul" }
local function sig(o)
  local parts = {}
  for _, k in ipairs(KEYS) do parts[#parts + 1] = k .. "=" .. tostring(o[k][1]) .. ":" .. tostring(o[k][2]) .. ":" .. tostring(o[k][3]) end
  return table.concat(parts, " ")
end

---------------------------------------------------------------------------------------------------
-- §1 la règle
---------------------------------------------------------------------------------------------------
local o = cas(Ml)
check(Ml.RESERVE_PCT == 0.20, "§1 réserve de sécurité : 20 %")
check(o.trente[1] == true and o.trente[2] == 3 and o.trente[3] == "machine", "§1 30 machines au coffre, section de 8 : vrai, 3 sections (" .. tostring(o.trente[1]) .. ":" .. tostring(o.trente[2]) .. ":" .. tostring(o.trente[3]) .. ")")
check(o.neuf[1] == false and o.neuf[2] == 0, "§1 9 machines : 7,2 hors réserve < 8 : faux (" .. tostring(o.neuf[3]) .. ")")
check(o.dix[1] == true and o.dix[2] == 1, "§1 10 machines : 8 hors réserve : une section")
check(o.vide[1] == false, "§1 stock vide : faux")
check(o.sans_tapis[1] == true and o.sans_tapis[2] == 3, "§1 tapis, bras, poteaux manquants mais machines présentes : vrai (elles se fabriquent)")
check(o.que_tapis[1] == false and tostring(o.que_tapis[3]):find("machine", 1, true), "§1 des tapis sans machine : faux")
check(o.sans_machine[1] == false, "§1 section sans pièce machine : faux")
check(o.mesure_dc[1] == true and o.mesure_dc[2] == 395, "§1 mesure du DC (3952 au coffre) : 395 sections payables (" .. tostring(o.mesure_dc[2]) .. ")")
check(o.nul[1] == false, "§1 données absentes : faux, pas d'erreur")
check(Ml.dormant({ x = 9 }, "x") == 7 and Ml.dormant({ x = 10 }, "x") == 8 and Ml.dormant({}, "x") == 0, "§1 dormant : entier hors réserve")
-- deux pièces machine : la plus serrée borne
local ok2, n2, p2 = Ml.surplus({ ma = 100, mb = 20 }, { { "ma", 8, true }, { "mb", 8, true } })
check(ok2 == true and n2 == 2 and p2 == "mb", "§1 deux pièces machine : la plus serrée borne (" .. tostring(n2) .. " " .. tostring(p2) .. ")")

---------------------------------------------------------------------------------------------------
-- §2 déterminisme : deux passes, même signature ; la table d'entrée n'est pas modifiée
---------------------------------------------------------------------------------------------------
local ref = sig(o)
check(sig(cas(Ml)) == ref, "§2 deux passes identiques")
check(#SECTION == 4 and SECTION[2][1] == "machine" and SECTION[2][2] == 8, "§2 la section donnée n'est pas modifiée")

---------------------------------------------------------------------------------------------------
-- §3 mutants : chaque mutant doit changer au moins un verdict
---------------------------------------------------------------------------------------------------
local function lire(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local source = lire(SRC)
local function mutant(nom, de, vers)
  local s, n = source:gsub(de, vers, 1)
  check(n == 1, "§3 mutant " .. nom .. " : motif trouvé dans la source")
  local chunk = assert(load(s, "=" .. nom))
  local M = chunk()
  check(sig(cas(M)) ~= ref, "§3 mutant « " .. nom .. " » détecté")
end
mutant("réserve ignorée", "Ml%.RESERVE_PCT = 0%.20", "Ml.RESERVE_PCT = 0")
mutant("machine non exigée (toute pièce compte)", "if machine and par_section > 0 then", "if par_section > 0 then")
mutant("une section payable n'est pas exigée", "if n < 1 then return false", "if n < 0 then return false")
mutant("réserve dans le mauvais sens", "n %* %(1 %- Ml%.RESERVE_PCT%)", "n * (1 + Ml.RESERVE_PCT)")

---------------------------------------------------------------------------------------------------
-- §4 câblage : script/team/mall_rangee.lua (allongement au surplus) appelle la liquidation AVANT la règle du débit
---------------------------------------------------------------------------------------------------
local rangee = lire("script/team/mall_rangee.lua")
check(rangee:find('require("shared.team.mall_liquidation")', 1, true), "§4 mall_rangee.lua charge shared/team/mall_liquidation.lua")
check(rangee:find("Liq.surplus(libre, section)", 1, true), "§4 la règle lit le stock libre donné par mall_libre (industrie.lua), pas une nouvelle lecture d'entités")
check(rangee:find('e.role == "mall-machine_asm" then machines[item_of(e.name)] = true', 1, true), "§4 la pièce machine est lue au rôle des entités de la section finie (aucun nom en dur)")
local a = rangee:find("local dormant, au_coffre, machine = stock_dormant(b, r, libre)", 1, true)
local c = rangee:find("else cible = Ma.cible(#r.cells, parts[r.j] or {}, flow, libre, conso, Mr.MAX_CELLS) end", 1, true)
check(a and c and a < c, "§4 la liquidation est évaluée AVANT Ma.cible, et Ma.cible ne tourne que sans stock dormant")
check(rangee:find("section de plus PAYEE PAR LE STOCK DORMANT", 1, true), "§4 journal [FO-MALL] : « section de plus PAYEE PAR LE STOCK DORMANT »")
check(not rangee:find("Ma.cible(#r.cells, parts[r.j] or {}, flow, libre, conso, Mr.MAX_CELLS)\n          local d = cible", 1, true), "§4 l'ancien appel direct a disparu")
-- les gardes gardées : place de la rangée, pas d'autre section ouverte, dernière section finie
check(rangee:find("and #r.cells < Mr.MAX_CELLS then\n          -- lot MALL-LIQUIDATION", 1, true), "§4 garde de place (Mr.MAX_CELLS) conservée devant la liquidation")
check(rangee:find("if not ouvert then", 1, true), "§4 garde « aucune section ouverte » conservée")
check(rangee:find('if not (p and p.state == "fini" and p.ents) then return nil end', 1, true), "§4 les pièces viennent de la DERNIÈRE SECTION FINIE")
-- aucun nom d'objet du jeu dans la règle
for _, nom in ipairs({ "assembling%-machine", "inserter", "transport%-belt", "iron%-plate", "electric%-mining%-drill" }) do
  check(not source:find(nom), "§4 la règle ne nomme pas « " .. nom:gsub("%%", "") .. " »")
end

print(string.format("[MALL-LIQUIDATION] %d OK, %d ECHEC", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
