--[[
  Lot ARMEE-ANTICIPATION : banc HORS JEU du branchement (script/ai3/soldats.lua, pass) sur le moteur simulé, guerre de 4 factions :
    1. sans menace : patrouilles par paires (comportement d'avant) ;
    2. vague en approche (8 déchiqueteurs à 60 tuiles du QG, hors du rayon de 48 de la menace du QG) : alerte f.armee, besoin
       estimé, TOUS les soldats libres au même point de regroupement (plus de patrouilles), vue de l'équipe (army_alert,
       army_need lus par le planificateur) ;
    3. ennemi DANS le rayon du QG : TOUS les soldats en défense (régression du lot FUITE b390ad3 : `threat` indéfini, la défense
       du QG ne partait plus) ;
    4. fuite devant un ver ou un nid : aucune alerte de 4 soldats ; devant une unité : alerte ;
    5. recrues de l'alerte (la faction s'arme avant la première perte) ; global sérialisable ; déterminisme de la décision.
  Le moteur simulé ne cherche pas les ennemis : find_nearest_enemy et find_enemy_units sont remplacés ici par une recherche réelle
  sur ses entités (force « enemy »).
  Lancement : lua5.2 tests/armee_moteur_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function enemies_near(pos, r, want)
  local out = {}
  for _, e in ipairs(W().entities) do
    if e.valid and e.force and e.force.name == "enemy" and (not want or e.type == want) then
      local dx, dy = e._x - pos.x, e._y - pos.y
      if dx * dx + dy * dy <= r * r then out[#out + 1] = e end
    end
  end
  return out
end

local function enemy_search()
  local s = game.surfaces[1]
  s.find_nearest_enemy = function(t)
    assert(t.position and t.max_distance and t.force, "find_nearest_enemy : arguments")
    local best, bd
    for _, e in ipairs(enemies_near(t.position, t.max_distance)) do
      local dx, dy = e._x - t.position.x, e._y - t.position.y
      local dd = dx * dx + dy * dy
      if not bd or dd < bd then best, bd = e, dd end
    end
    return best
  end
  s.find_enemy_units = function(pos, radius, force)
    assert(pos and radius and force, "find_enemy_units : arguments")
    return enemies_near(pos, radius, "unit")
  end
end

local function roles(f, per)
  local n, pts = {}, {}
  for id, s in pairs(f.soldiers) do
    if s.entity and s.entity.valid and not s.group then
      local ps = per[id]
      local r = ps and ps.role or "aucun"
      n[r] = (n[r] or 0) + 1
    end
  end
  return n
end

local function run()
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  M.command("fo-war", "start 4 100 10 320")
  enemy_search()
  M.run_ticks(600)
  local St = require("script.faction.state")
  local Military = require("script.faction.military")
  local SD = require("script.ai3.soldats")
  local C = require("script.ai3.comportement")
  local A = require("shared.ai3.armee")
  local f = global.fo.war.factions[1]
  local s = game.surfaces[1]
  local made = Military.train(f, s, "rifleman", 13)
  local out = { made = made, hq_y = f.hq_pos.y }

  local t = C.team(f)
  t.escorts = {}
  SD.pass(f, game.tick)
  out.calm = roles(f, t.sd.per)

  -- Vague en approche : 8 déchiqueteurs à 60 tuiles au nord du QG (poids 200 / 75 chacun dans le moteur simulé).
  for i = 1, 8 do s.create_entity({ name = "small-biter", position = { x = f.hq_pos.x + i * 2, y = f.hq_pos.y - 60 }, force = "enemy" }) end
  if f.armee then f.armee.t = nil end
  t.escorts = {}
  SD.pass(f, game.tick)
  out.alert = A.alert_on(f.armee, game.tick)
  out.need = f.armee and f.armee.need
  out.threat = f.armee and f.armee.threat
  out.muster = f.armee and f.armee.muster
  out.wave = roles(f, t.sd.per)
  local pts = {}
  for id, ps in pairs(t.sd.per) do
    if ps.role == "muster" then pts[ps.key] = true end
  end
  local npts = 0
  for _ in pairs(pts) do npts = npts + 1 end
  out.muster_points = npts
  local Team = require("script.team.team")
  local ok_v, view = pcall(Team.view, f, game.tick)
  out.view_ok, out.view_alert, out.view_need = ok_v, ok_v and view.army_alert, ok_v and view.army_need
  if not ok_v then print("  (Team.view : " .. tostring(view) .. ")") end

  -- Ennemi DANS le rayon de la menace du QG (48 tuiles) : tous en défense.
  local b = s.create_entity({ name = "small-biter", position = { x = f.hq_pos.x + 20, y = f.hq_pos.y }, force = "enemy" })
  t.escorts = {}
  SD.pass(f, game.tick + 1)
  out.hq = roles(f, t.sd.per)
  b.destroy()

  -- Fuite devant un ver ou un nid : pas d'alerte ; devant une unité : alerte.
  local ep = { x = f.hq_pos.x + 30, y = f.hq_pos.y + 30 }
  out.alert_worm = C.on_alert(f, ep, "worm", game.tick)
  out.alert_nest = C.on_alert(f, { x = ep.x + 40, y = ep.y }, "spawner", game.tick)
  out.alert_unit = C.on_alert(f, { x = ep.x - 40, y = ep.y }, "unit", game.tick)

  -- Recrues de l'alerte : la faction joue 5 min avec la vague en approche ; son coffre a de quoi équiper 40 soldats (le moteur
  -- simulé ne fabrique pas assez vite pour ce contrôle : on prouve la DÉCISION, pas l'économie).
  f.hq.insert({ name = "submachine-gun", count = 40 })
  f.hq.insert({ name = "firearm-magazine", count = 400 })
  out.s0 = f.soldiers_count
  M.run_ticks(5 * 3600)
  out.s1 = f.soldiers_count
  out.still = A.alert_on(f.armee, game.tick)
  out.ser = pcall(M.serialize, global)
  return out
end

section("Branchement (moteur simulé, guerre de 4 factions)")
local r = run()
check(r.made == 13, "13 soldats équipés (" .. tostring(r.made) .. ")")
check((r.calm.patrol or 0) > 0 and (r.calm.muster or 0) == 0, "sans menace : patrouilles, aucun regroupement")
check(r.alert, "vague en approche : alerte (f.armee)")
check(r.threat and math.abs(r.threat - 8 * 200 / 75) < 1e-6, "menace estimée = poids des 8 déchiqueteurs (" .. tostring(r.threat) .. ")")
local A = require("shared.ai3.armee")
check(r.need == A.need(8 * 200 / 75, 1), "besoin estimé (" .. tostring(r.need) .. ")")
check(r.muster and r.muster.y < r.hq_y and r.hq_y - r.muster.y <= A.MUSTER_R + 1e-6, "regroupement entre le QG et la vague (au nord, à 20 tuiles au plus)")
check((r.wave.muster or 0) >= 13 and (r.wave.patrol or 0) == 0 and (r.wave.guard or 0) == 0,
  string.format("tous les soldats libres regroupés (regroupement %d, patrouille %d, garde %d)", r.wave.muster or 0, r.wave.patrol or 0, r.wave.guard or 0))
check(r.muster_points == 1, "un seul point de regroupement (" .. r.muster_points .. ")")
check(r.view_ok and r.view_alert == true and r.view_need == r.need, "vue de l'équipe : army_alert et army_need lus par le planificateur")
check((r.hq.defense or 0) >= 13, "ennemi dans le rayon du QG : tous en défense (" .. tostring(r.hq.defense) .. ", régression b390ad3)")
check(r.alert_worm == false and r.alert_nest == false, "fuite devant un ver ou un nid : aucune alerte de 4 soldats")
check(r.alert_unit == true, "fuite devant une unité : alerte")
check(r.s1 > r.s0, string.format("alerte : la faction s'arme (soldats %d -> %d)", r.s0, r.s1))
check(r.ser, "global sérialisable")

section("Déterminisme")
local r2 = run()
check(r2.need == r.need and r2.s1 == r.s1 and r2.muster.x == r.muster.x and r2.muster.y == r.muster.y,
  "deux passages identiques (besoin, regroupement, recrues)")

print(string.format("[ARMEE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
