--[[
  Lot CC-MAIN (mandat de 10 h du DC, 10/11 22 h 20, chantier B §4 « bannissement du minage manuel ») : test hors jeu.
  Défaut (partie 0.6.88 du DC, graine 1732508881, fo-logs/2026-11-10_PLAYTEST-0688/factorio-complet.log) : à 72,7 et 84,6 min, 14 tâches
  « ia3:mine:iron-ore:1..14 » du cerveau (shared/ai3/projets.lua, appoint par les PNJ sans tâche) font piocher le fer à une douzaine de PNJ
  du joueur, alors que 50 foreuses électriques dorment au coffre en phase mid : [FO-ZERO-IDLE] « 50 foreuse(s) electrique(s) dorment au
  coffre : thermique interdite (arbre de decision, phase mid) ». La garde unique du minage à la main (Mi.hand_verdict) laissait passer
  (manque mesuré `short`) : l'exclusion mutuelle de l'arbre de décision (Dt.thermal_allowed) n'y était jamais lue (classe A1).
    §1 la règle pure : électriques qui dorment = jamais de minage à la main (manque, survie, combustible compris) ; seule la crise passe ;
    §2 la cause vient de Dt.thermal_allowed (même règle que les paires thermiques) ;
    §3 Elec.hand_blocked (moteur, prototypes simulés) : ressource extractible seulement, bois exclu, verdict périmé ignoré ;
    §4 câblage : worker (toutes les tâches « mine ») et fond (poles.lua) lisent la même règle ;
    §5 rejeu de l'état du DC à 84,6 min ;
    §6 mutants.
  Usage : lua5.2 tests/cc_main_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[CC-MAIN] ECHEC : " .. name) end
end

local SRC_MI = read("shared/team/main_inventaire.lua")
local SRC_EL = read("script/team/electrique.lua")
local Dt = require("shared.team.decision_tree")

local function load_src(src, name)
  local fn = load(src, "=" .. name, "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

--- Moteur simulé minimal pour script/team/electrique.lua : prototypes d'une foreuse électrique (catégorie « basic-solid »), de deux
--- ressources (fer : basic-solid ; pétrole : basic-fluid) et d'un arbre (pas une ressource).
local function with_engine(fn)
  local saved_game, saved_stock, saved_log = rawget(_G, "game"), package.loaded["script.team.stock"], rawget(_G, "log")
  local protos = {
    ["electric-mining-drill"] = { type = "mining-drill", resource_categories = { ["basic-solid"] = true } },
    ["iron-ore"] = { type = "resource", resource_category = "basic-solid",
      mineable_properties = { products = { { name = "iron-ore", type = "item" } } } },
    ["crude-oil"] = { type = "resource", resource_category = "basic-fluid",
      mineable_properties = { products = { { name = "crude-oil", type = "fluid" } } } },
    ["tree-01"] = { type = "tree", mineable_properties = { products = { { name = "wood", type = "item" } } } },
  }
  _G.game = {
    entity_prototypes = protos,
    get_filtered_entity_prototypes = function(filters)
      local out = {}
      for n, p in pairs(protos) do
        if p.type == filters[1].type then out[n] = p end
      end
      return out
    end,
  }
  _G.log = function() end
  package.loaded["script.team.stock"] = { count = function() return 0 end, contents = function() return {} end }
  local Elec = load_src(SRC_EL, "electrique")
  local ok, err = pcall(fn, Elec)
  _G.game, _G.log = saved_game, saved_log
  package.loaded["script.team.stock"] = saved_stock
  if not ok then error(err) end
end

local CAUSE = "50 foreuse(s) electrique(s) dorment au coffre : thermique interdite (arbre de decision, phase mid)"

--- §1 et §5 : vérifications de la règle pure (rejouées sur chaque mutant de main_inventaire.lua).
local function suite_mi(Mi)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  if not Mi then c("module lisible", false) return res end
  local ok, why = Mi.hand_verdict({ stock = 0, count = 50, short = 600, electrique = CAUSE })
  c("§1 manque mesuré + électriques qui dorment : refus", ok == false and why == "electrique")
  ok = Mi.hand_verdict({ stock = 0, count = 50, survie = true, electrique = CAUSE })
  c("§1 survie + électriques qui dorment : refus", ok == false)
  ok = Mi.hand_verdict({ stock = 0, count = 50, fuel = true, electrique = CAUSE })
  c("§1 combustible + électriques qui dorment : refus", ok == false)
  ok, why = Mi.hand_verdict({ stock = 0, count = 50, crisis = true, electrique = CAUSE })
  c("§1 crise de banc : passe", ok == true and why == "crise")
  ok, why = Mi.hand_verdict({ stock = 0, count = 50, short = 600 })
  c("§1 sans électriques qui dorment : la règle d'avant (manque)", ok == true and why == "manque")
  ok, why = Mi.hand_verdict({ stock = 500, count = 50 })
  c("§1 sans électriques : stock couvre, refus d'avant", ok == false and why == "stock")
  ok = Mi.hand_verdict({ stock = 0, count = 50, survie = true })
  c("§1 sans électriques : survie exemptée comme avant", ok == true)
  ok = Mi.hand_verdict({ stock = 0, count = 50, short = 600, electrique = false })
  c("§1 électrique = faux (pas une cause) : règle d'avant", ok == true)
  -- §5 rejeu : joueur, 84,6 min, tâche ia3:mine:iron-ore:9, coffre 0, manque 600 (r.n), 50 foreuses électriques au coffre, phase mid
  local dt_ok, dt_why = Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 50 })
  ok, why = Mi.hand_verdict({ stock = 0, count = 50, short = 600, electrique = (not dt_ok) and dt_why or nil })
  c("§5 état du DC à 84,6 min : la pioche est refusée", ok == false and why == "electrique")
  return res
end

for _, r in ipairs(suite_mi(load_src(SRC_MI, "mi"))) do check(r[1], r[2]) end

-- §2 la cause est celle de l'arbre de décision (une seule règle d'exclusion mutuelle)
do
  local ok, why = Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 50 })
  check("§2 phase mid + 50 au coffre : exclusion", ok == false and why == CAUSE)
  check("§2 phase early : pas d'exclusion", (Dt.thermal_allowed({ phase = "early", elec_drill_stock = 50 })) == true)
  check("§2 rien au coffre : pas d'exclusion", (Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 0 })) == true)
end

--- §3 Elec.hand_blocked au moteur simulé (rejoué sur chaque mutant de electrique.lua).
local function suite_el(Elec)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  if not (Elec and Elec.hand_blocked) then c("Elec.hand_blocked existe", false) return res end
  local tick = 300000
  local f = { key = "player", elec = { v = { on = true, tick = tick - 60, phase = "mid", elec_drill_stock = 50 } } }
  c("§3 fer extractible, électriques qui dorment : cause", Elec.hand_blocked(f, tick, "iron-ore") == CAUSE)
  c("§3 bois sans drapeau : pas extractible par la foreuse", Elec.hand_blocked(f, tick, "wood") == nil)
  c("§3 fluide hors catégorie de la foreuse : pas bloqué", Elec.hand_blocked(f, tick, "crude-oil") == nil)
  local early = { key = "x", elec = { v = { on = true, tick = tick - 60, phase = "early", elec_drill_stock = 50 } } }
  c("§3 phase early : pas bloqué", Elec.hand_blocked(early, tick, "iron-ore") == nil)
  local empty = { key = "x", elec = { v = { on = true, tick = tick - 60, phase = "mid", elec_drill_stock = 0 } } }
  c("§3 aucune foreuse au coffre : pas bloqué", Elec.hand_blocked(empty, tick, "iron-ore") == nil)
  local stale = { key = "x", elec = { v = { on = true, tick = tick - 3 * Elec.TTL, phase = "mid", elec_drill_stock = 50 } } }
  c("§3 verdict périmé : comportement d'avant", Elec.hand_blocked(stale, tick, "iron-ore") == nil)
  local off = { key = "x", elec = { v = { on = false, tick = tick - 60, phase = "mid", elec_drill_stock = 50 } } }
  c("§3 règle éteinte : comportement d'avant", Elec.hand_blocked(off, tick, "iron-ore") == nil)
  c("§3 sans état électrique : nil", Elec.hand_blocked({ key = "x" }, tick, "iron-ore") == nil)
  return res
end

with_engine(function(Elec) for _, r in ipairs(suite_el(Elec)) do check(r[1], r[2]) end end)

-- §4 câblage : toutes les tâches « mine » (sur:, fond:, ia3:) passent par la même garde, et le fond la lit aussi
local W = read("script/team/worker.lua")
local P = read("script/team/poles.lua")
check("§4 worker : électrique lu au verdict",
  W:find("electrique = Elec.hand_blocked(f, tick, task.resource)", 1, true) ~= nil)
check("§4 worker : require du module électrique", W:find('local Elec = require("script.team.electrique")', 1, true) ~= nil)
check("§4 worker : code d'échec suit la raison", W:find('task.fail = task.fail or ("main:" .. why)', 1, true) ~= nil)
check("§4 fond (poles) : même règle", P:find("electrique = Elec.hand_blocked(f, tick, m[1])", 1, true) ~= nil)
check("§4 fond (poles) : require du module électrique", P:find('local Elec = require("script.team.electrique")', 1, true) ~= nil)
check("§4 electrique.lua : cause lue à l'arbre de décision", SRC_EL:find("Dt.thermal_allowed({ phase = v.phase, elec_drill_stock = v.elec_drill_stock })", 1, true) ~= nil)
check("§4 aucun nom d'objet du jeu dans la règle pure", not SRC_MI:find("iron%-ore") and not SRC_MI:find("electric%-mining"))

-- §6 mutants : chaque coupe faussée doit faire échouer au moins une vérification
local MUT_MI = {
  { "électrique ignoré", 'if type(a.electrique) == "string" then return false, "electrique" end', "" },
  { "survie avant l'électrique", 'if type(a.electrique) == "string" then return false, "electrique" end',
    'if a.survie then return true, "survie" end if type(a.electrique) == "string" then return false, "electrique" end' },
  { "manque avant l'électrique", 'if type(a.electrique) == "string" then return false, "electrique" end',
    'if num(a.short) > 0 then return true, "manque" end if type(a.electrique) == "string" then return false, "electrique" end' },
  { "crise plus exemptée", 'if a.crisis then return true, "crise" end', "" },
}
local MUT_EL = {
  { "catégorie de la foreuse ignorée", "if not drillable(item) then return nil end", "" },
  { "verdict périmé accepté", "if not (v and v.on and tick - (v.tick or -math.huge) <= Elec.TTL) then return nil end\n  local dt_ok",
    "if not v then return nil end\n  local dt_ok" },
  { "arbre de décision ignoré", "if dt_ok then return nil end", "" },
}
for _, m in ipairs(MUT_MI) do
  local s, n = SRC_MI:gsub(m[2]:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  local caught = false
  if n == 0 then caught = false else
    for _, r in ipairs(suite_mi(load_src(s, "mi-mutant"))) do if not r[2] then caught = true break end end
  end
  check("§6 mutant (règle pure) vu : " .. m[1] .. (n == 0 and " [motif absent]" or ""), n > 0 and caught)
end
for _, m in ipairs(MUT_EL) do
  local s, n = SRC_EL:gsub(m[2]:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  local caught = false
  if n > 0 then
    local saved = SRC_EL
    SRC_EL = s
    with_engine(function(Elec) for _, r in ipairs(suite_el(Elec)) do if not r[2] then caught = true break end end end)
    SRC_EL = saved
  end
  check("§6 mutant (moteur) vu : " .. m[1] .. (n == 0 and " [motif absent]" or ""), n > 0 and caught)
end

print(string.format("[CC-MAIN] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
if bad > 0 then os.exit(1) end
