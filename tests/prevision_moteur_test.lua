--[[
  Lot PREVISION : banc HORS JEU du RUNTIME de l'estimateur unique (script/ai3/prevision.lua) sur le moteur simulé, guerre de 4
  factions. Le moteur simulé n'a ni nids ni pollution par défaut : ce banc lui donne un prototype de nid (result_units, coût en
  pollution, vitesse), des réglages de carte, une tourelle qui tire (attack_parameters) et une émission aux fours. Il prouve :
    1. un nid CONNU (carte du danger de l'équipe) dont la case n'est pas polluée : aucune vague, aucun cadre ;
    2. la pollution l'atteint : vague prévue au QG, cadre « preparer » (lignes de la pile et du front), alerte de l'armée,
       journal [FO-PREVISION] (ÉTAT, DECIDE) ; un nid JAMAIS VU ne compte pas (comme le joueur) ;
    3. aucune horloge : 20 relevés plus tard, la menace inchangée garde le cadre ; la pollution retombe : cadre fermé ;
    4. défense induite pour la capitalisation (Prev.capi_defense) ;
    5. coupure de banc (war_option « prevision » = false) : aucun relevé, aucune ligne ;
    6. global sérialisable ; deux passages identiques (journal compris).
  Limite (critique §4) : le modèle des biters du moteur simulé est celui de la règle : ce banc prouve la PLOMBERIE, pas la
  précision (bancs en moteur réel prev-vague, prev-ombre : non joués par ce lot).
  Lancement : lua5.2 tests/prevision_moteur_test.lua (depuis la racine du mod).
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
  for _, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di = 1, 12 do
        local a = di * 0.5236
        out[#out + 1] = { x = hx + math.cos(a) * r, y = hy + math.sin(a) * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function prepare_world()
  local P = W().prototypes
  rawset(P, "fo-test-nest", { type = "unit-spawner", max_health = 350, spawn_cooldown = { min = 360, max = 150 },
    result_units = { { unit = "small-biter", spawn_points = { { evolution_factor = 0, weight = 1 } } } } })
  P["small-biter"].pollution_to_join_attack = 4
  P["small-biter"].speed = 0.2
  P["gun-turret"].attack_parameters = { cooldown = 6, range = 18, damage_modifier = 1,
    ammo_type = { category = "bullet", action = { type = "direct", action_delivery = { type = "instant",
      target_effects = { { type = "damage", damage = { amount = 5, type = "physical" } } } } } } }
  P["stone-furnace"].emissions_per_second = 2 / 60
  game.map_settings = { unit_group = { min_group_gathering_time = 3600, max_group_gathering_time = 3 * 3600, max_unit_group_size = 200 },
    enemy_evolution = { enabled = true, time_factor = 0.000004, pollution_factor = 0.0000009 },
    pollution = { enabled = true, diffusion_ratio = 0.02 } }
  game.forces.enemy.evolution_factor = 0.1
  local s = game.surfaces[1]
  s.find_enemy_units = function(pos, radius, force)
    local out = {}
    for _, e in ipairs(W().entities) do
      if e.valid and e.type == "unit" and e.force and e.force.name == "enemy" then
        local dx, dy = e._x - pos.x, e._y - pos.y
        if dx * dx + dy * dy <= radius * radius then out[#out + 1] = e end
      end
    end
    return out
  end
end

local function prev_lines(from)
  local out = {}
  for i = from or 1, #W().logs do
    local l = W().logs[i]
    if l:find("[FO-PREVISION]", 1, true) then out[#out + 1] = l end
  end
  return out
end

local function run(off)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  M.command("fo-war", "start 4 100 10 320")
  prepare_world()
  M.run_ticks(600)
  local St = require("script.faction.state")
  local Prev = require("script.ai3.prevision")
  local C = require("script.ai3.comportement")
  local Pc = require("shared.ai3.prevision_choix")
  if off then St.war().settings.prevision = false end
  local f = St.war().factions[1]
  local s = game.surfaces[1]
  local out = { hq = { x = f.hq_pos.x, y = f.hq_pos.y } }
  -- Fours du QG (pollueurs), et un nid connu de l'équipe à 100 tuiles au nord.
  for i = 1, 6 do s.create_entity({ name = "stone-furnace", position = { x = f.hq_pos.x - 20 + i * 2, y = f.hq_pos.y + 20 }, force = f.force }) end
  -- Coffre : deux tourelles et des équipements de soldat (payés : la défense réunissable et les recrues hors budget de fer).
  f.hq.insert({ name = "gun-turret", count = 2 })
  f.hq.insert({ name = "submachine-gun", count = 10 })
  f.hq.insert({ name = "firearm-magazine", count = 100 })
  local t = C.team(f)
  require("shared.ai3.danger").mark_seen(t.map, f.hq_pos.x, f.hq_pos.y - 100, "spawner", nil, game.tick)
  W().pollution = 0
  local n0 = #W().logs
  if f.prevision then f.prevision.t = nil end
  local st = Prev.think(f, game.tick)
  out.off_nil = st == nil
  if off then
    out.lines_off = #prev_lines(n0)
    return out
  end
  out.calm_w5 = st.view.sites[1].w5
  out.calm_rows = Prev.pile_rows(f)
  out.calm_alert = st.pc.alert
  out.calm_known = st.est.known
  -- La pollution atteint le nid connu.
  W().pollution = 200
  f.prevision.t = nil
  st = Prev.think(f, game.tick + 1)
  local qg = st.view.sites[1]
  out.w5, out.d, out.eta = qg.w5, qg.d, qg.eta
  out.prep = st.pc.sites.qg.prep
  out.rows = Prev.pile_rows(f)
  local Front = require("script.team.front")
  out.front = Front.prevu(f)
  out.alert, out.need = st.pc.alert, st.pc.army_need
  out.lines = prev_lines(n0)
  out.lines_all = prev_lines(1)
  out.insurm = st.pc.sites.qg.insurm
  out.capi = Prev.capi_defense(f)
  -- Un nid JAMAIS VU (pas dans les cartes de l'équipe) n'ajoute rien.
  s.create_entity({ name = "fo-test-nest", position = { x = f.hq_pos.x + 120, y = f.hq_pos.y }, force = "enemy" })
  f.prevision.t = nil
  st = Prev.think(f, game.tick + 2)
  out.w5_unseen = st.view.sites[1].w5
  -- Aucune horloge : 20 relevés, menace inchangée.
  local still = true
  for i = 1, 20 do
    st = Prev.think(f, game.tick + 3 + i * 3600)
    if not st.pc.sites.qg.prep then still = false end
  end
  out.still = still
  -- La pollution retombe : le nid ne reçoit plus rien.
  W().pollution = 0
  st = Prev.think(f, game.tick + 30 * 3600)
  out.closed = not st.pc.sites.qg.prep and Prev.pile_rows(f) == nil
  out.ser = pcall(M.serialize, global)
  out.all_lines = prev_lines(n0)
  out.pc_ok = Pc ~= nil
  return out
end

section("Branchement (moteur simulé, guerre de 4 factions)")
local r = run(false)
check(r.calm_known >= 1 and r.calm_w5 == 0 and r.calm_rows == nil and not r.calm_alert,
  "nid connu dont la case n'est pas polluée : aucune vague, aucun cadre, aucune alerte")
check(r.w5 > r.d and r.eta and r.eta <= 5, string.format("pollution au nid : vague imminente au-dessus de la défense (%d PV contre %d, échéance %.2f min)", r.w5 or 0, r.d or 0, r.eta or -1))
check(r.prep and r.rows and r.rows[1].id == "qg" and r.rows[1].want > r.rows[1].have, "cadre « preparer » du QG (pile), tourelles en pièces")
check(r.front and r.front[1].key == "prev:qg", "lignes « tourelles d'avance » du front")
check(r.alert and r.need > 0, "armée en alerte, besoin estimé (" .. tostring(r.need) .. ")")
local has_state, has_open = false, false
for _, l in ipairs(r.lines_all) do if l:find(" ETAT evo ", 1, true) then has_state = true end end
for _, l in ipairs(r.lines) do if l:find("DECIDE : PREPARER qg ouvert", 1, true) then has_open = true end end
check(has_state and has_open, "journal [FO-PREVISION] : état et décision lisibles")
check(r.capi and r.capi.hp_per_emit > 0 and r.capi.turret_value > 0, "défense induite pour la capitalisation (C12)")
check(math.abs(r.w5_unseen - r.w5) < 1e-6, "un nid JAMAIS VU n'ajoute rien (comme le joueur)")
check(r.still, "aucune horloge : 20 relevés plus tard, la menace inchangée garde le cadre")
check(r.closed, "pollution retombée : cadre fermé, aucune ligne de pile")
check(r.ser, "global sérialisable")

section("Coupure de banc")
local o = run(true)
check(o.off_nil and o.lines_off == 0, "war_option « prevision » = false : aucun relevé, aucune ligne")

section("Déterminisme")
local r2 = run(false)
local same = #r2.all_lines == #r.all_lines
for i = 1, math.min(#r.all_lines, #r2.all_lines) do if r.all_lines[i] ~= r2.all_lines[i] then same = false end end
check(same and r2.need == r.need and r2.w5 == r.w5, "deux passages identiques (journal compris)")

print(string.format("[PREVISION-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
