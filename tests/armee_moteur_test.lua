--[[
  Lot ARMEE-ANTICIPATION : banc HORS JEU du branchement (script/ai3/soldats.lua, pass) sur le moteur simulé, guerre de 4 factions :
    1. sans menace : patrouilles par paires (comportement d'avant) ;
    2. vague en approche (40 déchiqueteurs à 60 tuiles du QG, VUS par l'œil du QG, hors du rayon de 48 de la menace du QG) :
       alerte f.armee, besoin estimé par l'estimateur unique (lot PREVISION : 8 déchiqueteurs, que les 13 soldats couvrent,
       n'alertent plus : l'alerte naît d'un ÉCART vague / défense), TOUS les soldats libres au même point de regroupement (plus
       de patrouilles), vue de l'équipe (army_alert, army_need lus par le planificateur) ;
    3. ennemi DANS le rayon du QG : TOUS les soldats en défense (régression du lot FUITE b390ad3 : `threat` indéfini, la défense
       du QG ne partait plus) ;
    4. fuite devant un ver ou un nid : aucune alerte de 4 soldats ; devant une unité : alerte ;
    5. recrues de l'alerte (la faction s'arme avant la première perte) ; global sérialisable ; déterminisme de la décision.
  Le moteur simulé ne cherche pas les ennemis : find_nearest_enemy et find_enemy_units sont remplacés ici par une recherche réelle
  sur ses entités (force « enemy »).
  Lot ARMEE-TEST (7/11, fo-logs/2026-11-07_ARMEE-TEST/CRITERES.md) : la vague reste au nord du QG, mais le test ne suppose plus
  que le QG est le premier site touché (l'étalement des pensées des factions fait fonder plus tôt un avant-poste entre les deux) :
  il LIT ce site dans la prévision et contrôle que l'armée se prépare et se rallie pour LUI ; 2 mutants (autre site, PREPARER coupé).
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

local function run(mut)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  -- Mutants (lot ARMEE-TEST, 7/11) : M1 « autre site » (ralliement 40 tuiles à l'est du site), M2 « PREPARER coupé » (seuil
  -- d'ouverture Pc.RHO_IN hors d'atteinte). Chacun doit faire échouer un contrôle de fonction.
  local Pc = require("shared.ai3.prevision_choix")
  local pc_muster, pc_rho = Pc.muster, Pc.RHO_IN -- rendus en fin de passage (le module peut rester chargé d'un passage à l'autre)
  if mut == "autre_site" then
    local o = Pc.muster
    Pc.muster = function(site)
      local m = o(site)
      return m and { x = m.x + 40, y = m.y } or m
    end
  elseif mut == "preparer_coupe" then
    Pc.RHO_IN = 1e12 -- seuil d'ouverture hors d'atteinte : « préparer » ne s'ouvre jamais
  end
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

  -- Lot PREVISION : 8 déchiqueteurs (1 600 PV dans le moteur simulé) contre 13 soldats (13 × 480 PV) : couverts, aucune alerte.
  local few = {}
  for i = 1, 8 do few[i] = s.create_entity({ name = "small-biter", position = { x = f.hq_pos.x + i * 2, y = f.hq_pos.y - 60 }, force = "enemy" }) end
  if f.armee then f.armee.t = nil end
  if f.prevision then f.prevision.t = nil end
  t.escorts = {}
  SD.pass(f, game.tick)
  out.few_alert = A.alert_on(f.armee)
  for _, b in ipairs(few) do b.destroy() end
  -- Équipements au coffre (payés : hors du budget de fer de la prévision) : de quoi équiper 40 soldats.
  f.hq.insert({ name = "submachine-gun", count = 40 })
  f.hq.insert({ name = "firearm-magazine", count = 400 })
  -- Vague en approche : 40 déchiqueteurs à 60 tuiles au nord du QG (200 PV chacun dans le moteur simulé : 8 000 PV).
  for i = 1, 40 do s.create_entity({ name = "small-biter", position = { x = f.hq_pos.x + (i % 10) * 2, y = f.hq_pos.y - 60 - math.floor(i / 10) * 2 }, force = "enemy" }) end
  if f.armee then f.armee.t = nil end
  if f.prevision then f.prevision.t = nil end
  t.escorts = {}
  SD.pass(f, game.tick)
  out.alert = A.alert_on(f.armee)
  out.pc_need = f.prevision and f.prevision.pc and f.prevision.pc.army_need
  out.need = f.armee and f.armee.need
  out.threat = f.armee and f.armee.threat
  out.muster = f.armee and f.armee.muster
  -- Premier site touché selon la prévision (lot ARMEE-TEST) ; sa position relevée sur la faction (QG ou avant-poste)
  local pc = f.prevision and (f.prevision.pc or f.prevision)
  out.first = pc and pc.first
  out.first_w5 = pc and pc.sites and out.first and pc.sites[out.first] and pc.sites[out.first].w5
  if out.first == "qg" then
    out.first_pos = { x = f.hq_pos.x, y = f.hq_pos.y }
  elseif type(out.first) == "string" and out.first:sub(1, 2) == "ap" then
    local o = f.outposts[tonumber(out.first:sub(3))]
    local q = o and (o.access or o.pos)
    out.first_pos = q and { x = q.x, y = q.y } or nil
  end
  out.wave_pos = { x = f.hq_pos.x + 10, y = f.hq_pos.y - 62 } -- centre des 40 déchiqueteurs posés plus haut
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
  -- Relecture : pendant l'alerte, une alerte de défense PRÈS du QG prend toute la force libre (`cond and nil or 0` valait toujours
  -- 0 : personne n'y allait) ; une alerte LOIN du QG (au-delà de Sd.NEAR_HQ) n'envoie personne.
  t.escorts = {}
  SD.pass(f, game.tick + 2)
  out.alert_near = roles(f, t.sd.per)
  local Sd = require("shared.ai3.soldats")
  t.alerts = {}
  out.alert_far_ok = C.on_alert(f, { x = f.hq_pos.x + Sd.NEAR_HQ + 20, y = f.hq_pos.y }, "unit", game.tick)
  t.escorts = {}
  SD.pass(f, game.tick + 3)
  out.alert_far = roles(f, t.sd.per)
  t.alerts = {}

  -- Recrues de l'alerte : la faction joue 5 min avec la vague en approche ; son coffre a de quoi équiper 40 soldats (le moteur
  -- simulé ne fabrique pas assez vite pour ce contrôle : on prouve la DÉCISION, pas l'économie).
  out.s0 = f.soldiers_count
  M.run_ticks(5 * 3600)
  out.s1 = f.soldiers_count
  out.still = A.alert_on(f.armee)
  local logs = 0
  local want = "PREPARER " .. tostring(out.first) .. " ouvert"
  for _, l in ipairs(M.world().logs) do if l:find("[FO-PREVISION]", 1, true) and l:find(want, 1, true) then logs = logs + 1 end end
  out.prep_logs = logs
  out.ser = pcall(M.serialize, global)
  Pc.muster, Pc.RHO_IN = pc_muster, pc_rho
  return out
end

-- Contrôles de FONCTION (lot ARMEE-TEST) : l'armée se prépare pour le site S que la prévision juge premier touché, quel qu'il soit
-- (le QG, ou un avant-poste fondé entre le QG et la vague), et se rallie à 20 tuiles de S au plus, du côté de la vague.
local A0 = require("shared.ai3.armee")
local function prep_ok(r) return r.prep_logs >= 1 end
local function rally_ok(r)
  local s, m, w = r.first_pos, r.muster, r.wave_pos
  if not (s and m) then return false end
  local dx, dy = m.x - s.x, m.y - s.y
  return dx * dx + dy * dy <= (A0.MUSTER_R + 1e-6) ^ 2 and dx * (w.x - s.x) + dy * (w.y - s.y) > 0
end

section("Branchement (moteur simulé, guerre de 4 factions)")
local r = run()
print(string.format("  premier site touché : %s en (%s) ; regroupement (%s)", tostring(r.first),
  r.first_pos and string.format("%.1f, %.1f", r.first_pos.x, r.first_pos.y) or "?",
  r.muster and string.format("%.1f, %.1f", r.muster.x, r.muster.y) or "?"))
check(r.first_pos ~= nil and (r.first_w5 or 0) > 0, "premier site touché : un vrai site de la faction, avec une vague prévue (" .. tostring(r.first) .. ")")
check(r.made == 13, "13 soldats équipés (" .. tostring(r.made) .. ")")
check((r.calm.patrol or 0) > 0 and (r.calm.muster or 0) == 0, "sans menace : patrouilles, aucun regroupement")
check(r.few_alert == false, "8 déchiqueteurs que 13 soldats couvrent : aucune alerte (écart vague / défense, lot PREVISION)")
check(r.alert, "vague en approche : alerte (f.armee)")
check(r.threat and math.abs(r.threat - 40 * 200) < 1e-6, "menace estimée = PV des 40 déchiqueteurs VUS (" .. tostring(r.threat) .. ")")
local A = require("shared.ai3.armee")
check(r.need and r.need == r.pc_need and r.need > 13 and r.need <= 30, "besoin estimé par la prévision, au-delà des 13 soldats, sous le plafond (" .. tostring(r.need) .. ")")
check(prep_ok(r), "journal [FO-PREVISION] : cadre PREPARER ouvert pour le premier site touché, " .. tostring(r.first) .. " (" .. tostring(r.prep_logs) .. ")")
check(rally_ok(r), "regroupement à 20 tuiles au plus du premier site touché, du côté de la vague")
check((r.wave.muster or 0) >= 13 and (r.wave.patrol or 0) == 0 and (r.wave.guard or 0) == 0,
  string.format("tous les soldats libres regroupés (regroupement %d, patrouille %d, garde %d)", r.wave.muster or 0, r.wave.patrol or 0, r.wave.guard or 0))
check(r.muster_points == 1, "un seul point de regroupement (" .. r.muster_points .. ")")
check(r.view_ok and r.view_alert == true and r.view_need == r.need, "vue de l'équipe : army_alert et army_need lus par le planificateur")
check((r.hq.defense or 0) >= 13, "ennemi dans le rayon du QG : tous en défense (" .. tostring(r.hq.defense) .. ", régression b390ad3)")
check(r.alert_worm == false and r.alert_nest == false, "fuite devant un ver ou un nid : aucune alerte de 4 soldats")
check(r.alert_unit == true, "fuite devant une unité : alerte")
check((r.alert_near.defense or 0) >= 13, "alerte près du QG pendant la vague : toute la force libre en défense (" .. tostring(r.alert_near.defense) .. ")")
check(r.alert_far_ok == true and (r.alert_far.defense or 0) == 0 and (r.alert_far.muster or 0) >= 13,
  string.format("alerte loin du QG pendant la vague : personne n'y va, regroupement gardé (défense %d, regroupement %d)",
    r.alert_far.defense or 0, r.alert_far.muster or 0))
check(r.s1 > r.s0, string.format("alerte : la faction s'arme (soldats %d -> %d)", r.s0, r.s1))
check(r.ser, "global sérialisable")

section("Déterminisme")
local r2 = run()
check(r2.need == r.need and r2.s1 == r.s1 and r2.muster.x == r.muster.x and r2.muster.y == r.muster.y,
  "deux passages identiques (besoin, regroupement, recrues)")

section("Mutants (lot ARMEE-TEST) : une armée qui se prépare ailleurs, ou pas du tout, est refusée")
local m1 = run("autre_site")
check(not rally_ok(m1), "M1 autre site : le ralliement hors de 20 tuiles du premier site est vu")
local m2 = run("preparer_coupe")
check(not prep_ok(m2), "M2 PREPARER coupé : l'absence de préparation du premier site est vue")

print(string.format("[ARMEE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
