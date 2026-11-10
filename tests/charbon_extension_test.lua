-- Lot CHARBON-EXTENSION (F486) : la bascule électrique ne ferme plus la thermique du COMBUSTIBLE quand des brûleurs vitaux sont à sec.
-- Panel CAP-P-D (graine 314159265) : 46,1 min « électrique possible : thermique refusée », 'extraction:coal' bloqué « electrique:coal »
-- de 46,2 à 68 min ; les foreuses électriques de charbon nourrissent la centrale par tapis, pas le coffre des brûleurs : 23/35 à sec à 60/75 min.
package.path = "./?.lua;" .. package.path
local E = require("shared.team.electrique")
local n_ok, n_ko = 0, 0
local function check(c, msg) if c then n_ok = n_ok + 1 else n_ko = n_ko + 1; print("ECHEC : " .. msg) end end
local base = { on = true, el_live = 2, obtainable = true, plants = 1, poles = true, healthy = true, res_live = 2 }
local function with(t) local r = {} for k, v in pairs(base) do r[k] = v end for k, v in pairs(t) do r[k] = v end return r end
-- 1. le cas mesuré : combustible, brûleurs vitaux à sec : thermique permise
local ok, why = E.thermal(with({ fuel = true, burners_dry = 23 }))
check(ok == true, "1a : combustible, 23 brûleurs vitaux à sec : thermique permise (" .. tostring(why) .. ")")
-- 2. gardes : rien ne change ailleurs
check(E.thermal(with({ fuel = true, burners_dry = 0 })) == false, "2a : combustible, aucun brûleur à sec : refusée comme avant")
check(E.thermal(with({ fuel = false, burners_dry = 23 })) == false, "2b : minerai qui n'est pas le combustible : refusée comme avant")
check(E.thermal(with({ fuel = true })) == false, "2c : brûleurs à sec non lus : refusée comme avant")
check(E.thermal(with({ fuel = true, burners_dry = 23, phase = "late", elec_drill_stock = 5, res_live = 2 })) ==
  E.thermal(with({ fuel = false, phase = "late", elec_drill_stock = 5, res_live = 2 })), "2d : l'arbre de décision (électriques au coffre) garde la main")
-- 3. mutants : la règle doit refuser chaque variante fausse
local src = assert(io.open("shared/team/electrique.lua", "rb")):read("*a")
local function survivors(mut)
  local s2 = mut(src); if s2 == src then return -1 end
  local chunk = load(s2, "mut", "t", setmetatable({ require = require }, { __index = _G })); if not chunk then return -1 end
  local ok2, M = pcall(chunk); if not ok2 or type(M) ~= "table" then return -1 end
  local a = M.thermal(with({ fuel = true, burners_dry = 23 }))
  local b = M.thermal(with({ fuel = true, burners_dry = 0 }))
  local c = M.thermal(with({ fuel = false, burners_dry = 23 }))
  return (a == true and b == false and c == false) and 1 or 0
end
check(survivors(function(s) return (s:gsub("if s%.fuel and %(num%(s%.burners_dry%) or 0%) > 0 then", "if false then")) end) == 0, "3a : mutant « exemption absente » refusé")
check(survivors(function(s) return (s:gsub("if s%.fuel and %(num%(s%.burners_dry%) or 0%) > 0 then", "if (num(s.burners_dry) or 0) > 0 then")) end) == 0, "3b : mutant « tout minerai » refusé")
check(survivors(function(s) return (s:gsub("if s%.fuel and %(num%(s%.burners_dry%) or 0%) > 0 then", "if s.fuel then")) end) == 0, "3c : mutant « sans mesure » refusé")
check(survivors(function(s) return (s:gsub("if s%.fuel and %(num%(s%.burners_dry%) or 0%) > 0 then", "if s.fuel and (num(s.burners_dry) or 0) >= 0 then")) end) == 0, "3d : mutant « seuil à zéro » refusé")
-- 4. câblage : le verdict publie les brûleurs vitaux à sec et les passe à la règle
local rt = assert(io.open("script/team/electrique.lua", "rb")):read("*a")
check(rt:find("burners_dry = v.burners_dry", 1, true) ~= nil, "4a : inputs() passe burners_dry")
check(rt:find("v.burners_dry = ", 1, true) ~= nil, "4b : Elec.think mesure burners_dry")
print(string.format("[CHARBON-EXTENSION] BILAN : %d OK, %d ECHEC(S)", n_ok, n_ko))
if n_ko > 0 then os.exit(1) end
