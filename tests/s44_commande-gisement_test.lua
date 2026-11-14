--[[
  s44 commande-gisement : un gisement désigné n'est plus « rempli » par un avant-poste déjà là, et son site passe les gardes.
  Lancement : lua5.2 tests/s44_commande-gisement_test.lua (racine du mod).
    1. Co.resolve : un avant-poste d'id <= after_oid (déjà posé à l'ordre) ne remplit pas ; un neuf (id > after_oid) remplit ;
       un ordre sans after_oid (sauvegarde d'avant) garde la règle d'avant ;
    2. Co.add garde after_oid ; Co.designated : zone et ressource ;
    3. câblage (sources) : after_oid posé par l'interface, ids passés à la résolution, sonde de la ressource désignée,
       garde de distance R3 contournée pour un site désigné ;
    4. mutant : sans le filtre after_oid, l'ancien avant-poste remplit (le défaut du journal du DC revient).
]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- 1. résolution
local st = Co.new_state()
local id = Co.add(st, { kind = "gisement", x = 0, y = -23, r = 27, resource = "r1", outpost = "k1", tick = 10, after_oid = 5 })
check(st.orders[1].after_oid == 5, "Co.add garde after_oid")
local old = { { kind = "k1", x = 2, y = -20, id = 1 } }
check(#Co.resolve(st, old) == 0, "un avant-poste deja la (id 1 <= 5) ne remplit pas l'ordre")
local new = { { kind = "k1", x = 2, y = -20, id = 1 }, { kind = "k1", x = 5, y = -30, id = 6 } }
local done = Co.resolve(st, new)
check(#done == 1 and done[1] == id, "un avant-poste neuf (id 6 > 5) remplit l'ordre")
check(#Co.resolve(st, { { kind = "k2", x = 5, y = -30, id = 6 } }) == 0, "autre type : pas rempli")
check(#Co.resolve(st, { { kind = "k1", x = 500, y = 500, id = 7 } }) == 0, "hors zone : pas rempli")
local st2 = Co.new_state()
Co.add(st2, { kind = "gisement", x = 0, y = 0, r = 10, resource = "r1", outpost = "k1" })
check(#Co.resolve(st2, old) == 1, "ordre sans after_oid : regle d'avant (rempli par tout avant-poste de la zone)")

-- 2. designated
check(Co.designated({ x = 10, y = -20, resource = "r1" }, st.orders), "site de la zone, meme ressource : designe")
check(not Co.designated({ x = 10, y = -20, resource = "r2" }, st.orders), "autre ressource : pas designe")
check(not Co.designated({ x = 300, y = 300, resource = "r1" }, st.orders), "hors zone : pas designe")
check(not Co.designated({ x = 0, y = 0, resource = "r1" }, nil), "sans ordres : pas designe")

-- 3. câblage
local function src(p) local h = assert(io.open(p, "r")); local s = h:read("*a"); h:close(); return s end
local gui, sites = src("script/gui/commande.lua"), src("script/faction/sites.lua")
check(gui:find("after_oid = f.next_oid or 0", 1, true) ~= nil, "l'interface pose after_oid")
check(gui:find("id = o.id or oid", 1, true) ~= nil, "la resolution recoit les ids d'avant-poste")
check(gui:find("Sites.probe_at(f, e.surface, cx, cy, game.tick, res)", 1, true) ~= nil, "sonde de la ressource designee a la pose")
check(gui:find("Sites.probe_at(f, surface, o.x, o.y, game.tick, o.resource)", 1, true) ~= nil, "sonde de la ressource designee en attente")
check(sites:find("function Sites.probe_at(f, surface, x, y, tick, res)", 1, true) ~= nil, "probe_at accepte la ressource")
check(sites:find("if not res and #f.prospects >= max_prospects(f)", 1, true) ~= nil, "reserve pleine : sonde designee permise")
check(sites:find("not Co.designated(site, f.team and f.team.commande and f.team.commande.orders) and not V.admissible", 1, true) ~= nil,
  "garde R3 contournee pour un site designe")

-- 4. mutant : résolution sans filtre
local saved = Co.resolve
Co.resolve = function(state, outposts)
  local out = {}
  for _, o in ipairs(state.orders) do
    for _, op in ipairs(outposts or {}) do
      if op.kind == o.outpost and Co.inside(o, op.x, op.y, Co.DONE_MARGIN) then out[#out + 1] = o.id break end
    end
  end
  return out
end
check(#Co.resolve(st, old) == 1, "mutant : sans after_oid, l'ancien avant-poste remplit (defaut detecte)")
Co.resolve = saved

print(string.format("s44 commande-gisement : %d OK, %d ECHEC", passes, failures))
if failures > 0 then os.exit(1) end
