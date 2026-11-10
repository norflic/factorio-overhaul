--[[
  F488 (lot CC-TOURELLES, 10/11/2026) : la vue d'avant-poste du cerveau (Team.view, script/team/team.lua) porte le nombre de tourelles
  (`turrets`) et le charbon voulu par ses brûleurs (`coal_needed`). Depuis la 0.6.74 (commit 7577fe67), un commentaire inséré au milieu
  de la ligne du constructeur avait avalé ces deux champs : chaque avant-poste se lisait SANS tourelle (o.turrets nil, lu 0 par
  shared/team/planner.lua), la défense en commandait une de plus sans fin (partie du DC, graine 3592985581 : 95 à 150 tourelles par
  équipe à 90 min, 34 autour du même avant-poste), aucun avant-poste ne s'agrandissait (P.undefended -> extendable) et la réserve de
  charbon des avant-postes valait 0 (planner.lua, fuel_reserve).
  Scène au moteur simulé (tests/mock_engine.lua), VRAIE vue d'une faction :
    §1 un avant-poste de fer avec 3 tourelles, 2 foreuses thermiques et 1 four sans charbon : la vue dit 3 tourelles ;
    §2 la vue dit le charbon que ses brûleurs attendent (Outposts.coal_needed), plus de 0 ;
    §3 le cerveau le tient pour défendu : P.undefended ne le cite pas, aucun poste de défense « fortify » ne lui est fait ;
    §4 sans tourelle, il redevient non défendu (la coupe ne fait pas taire la défense) ;
    §5 la même scène lue deux fois donne la même vue (déterminisme).
  Mutant : le champ remis dans le commentaire (ligne de la 0.6.74) fait échouer §1 à §3.
  Usage : lua5.2 tests/vue_avant_poste_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[VUE-AP] ECHEC : " .. msg) end
  return cond
end
local function W() return M.world() end

M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful" })
M.load_mod()
M.dispatch(W().on_init)
M.command("fo-war", "start 2 30 30 320")
M.run_ticks(60)

local T = require("shared.team.config")
local Team = require("script.team.team")
local Outposts = require("script.faction.outposts")
local P = require("shared.team.planner")

local fac = global.fo.war.factions[1]
assert(fac and fac.hq and fac.hq.valid, "faction de test absente")
local s = fac.hq.surface
local hq = fac.hq.position

local OID = 1
for k in pairs(fac.outposts) do if type(k) == "number" and k >= OID then OID = k + 1 end end
local bx, by = math.floor(hq.x) + 60, math.floor(hq.y) + 0.0
local function put(name, x, y) return s.create_entity({ name = name, position = { x = bx + x, y = by + y }, force = fac.force }) end
local turrets = { put("gun-turret", -6, -6), put("gun-turret", 6, -6), put("gun-turret", 0, 7) }
local drills = { put("burner-mining-drill", -1, 0), put("burner-mining-drill", 2, 0) }
local furnace = put(T.outposts.iron.sink or "stone-furnace", 0, 3)
for _, e in ipairs(turrets) do assert(e and e.valid, "tourelle non posee") end
for _, e in ipairs(drills) do assert(e and e.valid, "foreuse non posee") end
assert(furnace and furnace.valid, "four non pose")
fac.outposts[OID] = { id = OID, kind = "iron", pos = { x = bx, y = by }, drills = #drills, drill_list = drills, sinks = { furnace },
  turret_list = { turrets[1], turrets[2], turrets[3] }, last_service = game.tick }

local function row_of(view)
  for _, o in ipairs(view.outposts or {}) do if o.id == OID then return o end end
  return nil
end

local view = Team.view(fac, game.tick)
local row = row_of(view)
check(row ~= nil, "§0 l'avant-poste de test est dans la vue")
row = row or {}

-- §1
check(row.turrets == 3, "§1 la vue dit 3 tourelles (lu " .. tostring(row.turrets) .. ")")

-- §2
local want_coal = Outposts.coal_needed(fac.outposts[OID], fac.team and fac.team.flux_fill)
check(want_coal > 0, "§2 la scène a des brûleurs à remplir (" .. tostring(want_coal) .. ")")
check(row.coal_needed == want_coal, "§2 la vue dit le charbon voulu " .. tostring(want_coal) .. " (lu " .. tostring(row.coal_needed) .. ")")

-- §3
local dview = {}
for k, v in pairs(view) do dview[k] = v end
dview.defend_first = true
check(T.defend_turrets(row.drills) <= 3, "§3 la règle d'avant demande au plus 3 tourelles pour 2 foreuses")
check(P.undefended(dview)[OID] == nil, "§3 l'avant-poste à 3 tourelles n'est pas « non défendu »")

-- §4
fac.outposts[OID].turret_list = {}
local view0 = Team.view(fac, game.tick)
local row0 = row_of(view0) or {}
check(row0.turrets == 0, "§4 sans tourelle, la vue dit 0 (lu " .. tostring(row0.turrets) .. ")")
local dview0 = {}
for k, v in pairs(view0) do dview0[k] = v end
dview0.defend_first = true
check(P.undefended(dview0)[OID] == true, "§4 sans tourelle, l'avant-poste est non défendu (la défense parle encore)")
fac.outposts[OID].turret_list = { turrets[1], turrets[2], turrets[3] }

-- §5
local r1 = row_of(Team.view(fac, game.tick)) or {}
local r2 = row_of(Team.view(fac, game.tick)) or {}
check(r1.turrets == r2.turrets and r1.coal_needed == r2.coal_needed and r1.turrets == 3, "§5 même vue deux fois")

print(string.format("[VUE-AP] %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
