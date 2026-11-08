--[[
  Lot PERF4 (tt:repair). Demande du lead du 7/11 vers 11 h 55 : « Mesure le coût ajouté PAR ÉVÉNEMENT et le nombre d'événements par
  tick dans un vrai combat ». Le correctif 03c5c8dc élargit aux TOURELLES le filtre moteur de on_entity_damaged du mod.

  Ce banc COMPTE les événements on_entity_damaged par tick, par type d'entité touchée, dans deux combats réels joués sur une carte
  neuve. Le mod n'est pas touché : le comptage passe par le filtre et le gestionnaire du mod de TEST (control.lua, PLUGIN.damaged).
    A. Vague de biters sur une ligne de tourelles, force fo-perf4-ligne, hostile aux biters :
       - 24 tourelles en deux rangs de 12, chacune armée de 10 chargeurs ;
       - un mur de 49 pierres devant ; 9 poteaux derrière ;
       - 3 vagues de 60 biters (30 petits, 20 moyens, 10 gros), lancées 40 tuiles à l'est aux ticks 120, 720 et 1 320, en attaque de
         zone sur la ligne.
    B. Salve de zone de la Tournesol (âge 14, zone 75), comme le banc xp-zone, sur une base MIXTE dense de la force fo-perf4-base
       (sans munitions, sans riposte) :
       - une tourelle toutes les 8 tuiles ;
       - un poteau au milieu de chaque maille ;
       - un anneau de murs au rayon 66 ;
       - des lampes ailleurs, toutes les 2 tuiles.
  Journal [FO-PERF4-COMBAT] :
    - une ligne par scène et par seconde où il y a des coups ;
    - à la fin, un bilan par scène : ticks actifs, événements par tick actif (moyenne, max), total par type, part des tourelles.
  Le temps n'est PAS lu ici. Le coût par événement se mesure à part, sous --seul et après la partie du DC : même banc, sources
  corr-abimes contre essai-0656 (filtre sans tourelles), écart de scriptUpdate sur les ticks de combat, divisé par les événements
  de tourelle.
  Lancement (comptage, sans images) :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui PERF4 -- 2400 perf4-combat <source>
]]

local CHECK = 2300
local XA, YA = 8000, -3000   -- scène A : la ligne (x de la ligne avant)
local XB, YB = 12000, -3000  -- scène B : la Tournesol ; base centrée en XB + 50
local CXB, RB = XB + 50, 70
local WAVES = { 120, 720, 1320 }
local WAVE = { { "small-biter", 30 }, { "medium-biter", 20 }, { "big-biter", 10 } }

local TYPES = { "ammo-turret", "electric-turret", "fluid-turret", "turret", "artillery-turret", "wall", "gate", "electric-pole", "lamp",
  "boiler", "generator", "offshore-pump", "assembling-machine", "furnace", "lab", "mining-drill", "container", "inserter",
  "transport-belt", "pipe", "radar", "roboport" }
local TURRET = { ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true }

-- Comptes en tables LOCALES (phase --benchmark seulement : la carte est rejouée depuis la sauvegarde de --create ; jamais lus par
-- une décision).
local cur_tick, cur = -1, { A = 0, B = 0 }
local sec = { A = {}, B = {} }        -- [type] = n dans la seconde en cours
local sec_max = { A = 0, B = 0 }
local tot = { A = {}, B = {} }        -- [type] = n sur la scène
local act = { A = 0, B = 0 }          -- ticks avec au moins un événement
local mx = { A = 0, B = 0 }
local n_all = { A = 0, B = 0 }

local function close_tick()
  for _, k in ipairs({ "A", "B" }) do
    local n = cur[k]
    if n > 0 then
      act[k] = act[k] + 1
      if n > mx[k] then mx[k] = n end
      if n > sec_max[k] then sec_max[k] = n end
    end
    cur[k] = 0
  end
end

local S = {
  description = "PERF4 : evenements on_entity_damaged par tick dans un vrai combat (vague de biters sur des tourelles, salve d'un geant)",
  check_tick = CHECK,
  damaged_filter = {},
}
for _, t in ipairs(TYPES) do S.damaged_filter[#S.damaged_filter + 1] = { filter = "type", type = t } end

function S.damaged(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local t = e.tick
  if t ~= cur_tick then
    close_tick()
    cur_tick = t
  end
  local k = ent.position.x < 10000 and "A" or "B"
  local ty = ent.type
  cur[k] = cur[k] + 1
  n_all[k] = n_all[k] + 1
  sec[k][ty] = (sec[k][ty] or 0) + 1
  tot[k][ty] = (tot[k][ty] or 0) + 1
end

local function parts(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  local out, tur = {}, 0
  for _, k in ipairs(keys) do
    out[#out + 1] = k .. "=" .. t[k]
    if TURRET[k] then tur = tur + t[k] end
  end
  return table.concat(out, ", "), tur
end

local function force(name)
  return game.forces[name] or game.create_force(name)
end

local function ligne(s)
  local f = force("fo-perf4-ligne")
  game.forces.enemy.set_cease_fire(f, false)
  f.set_cease_fire(game.forces.enemy, false)
  local n = 0
  for row = 0, 1 do
    for k = 0, 11 do
      local t = s.create_entity({ name = "gun-turret", position = { XA - row * 3, YA - 18 + k * 3 }, force = f })
      if t then
        t.insert({ name = "firearm-magazine", count = 10 })
        n = n + 1
      end
    end
  end
  for y = -24, 24 do s.create_entity({ name = "stone-wall", position = { XA + 4.5, YA + y + 0.5 }, force = f }) end
  for k = 0, 8 do s.create_entity({ name = "small-electric-pole", position = { XA - 7.5, YA - 24 + k * 6 + 0.5 }, force = f }) end
  return n
end

local function base_mixte(s)
  local f = force("fo-perf4-base")
  local n = { tur = 0, pole = 0, wall = 0, lamp = 0 }
  for ix = -RB, RB, 2 do
    for iy = -RB, RB, 2 do
      local d2 = ix * ix + iy * iy
      if d2 <= RB * RB and not (math.abs(ix) <= 3 and math.abs(iy) <= 3) then
        local x, y = CXB + ix, YB + iy
        local name
        if ix % 8 == 0 and iy % 8 == 0 then
          name = "gun-turret"
        elseif ix % 8 == 4 and iy % 8 == 4 then
          name = "small-electric-pole"
        elseif d2 >= 64 * 64 and d2 <= 66 * 66 then
          name = "stone-wall"
        else
          name = "small-lamp" -- (x + 0,5, y + 0,5) : jamais sous une tourelle (2 × 2 centrée sur un nœud de la maille de 8)
        end
        if name then
          local p = name == "gun-turret" and { x, y } or { x + 0.5, y + 0.5 }
          local e = s.create_entity({ name = name, position = p, force = f })
          if e then
            local key = (name == "gun-turret" and "tur") or (name == "small-electric-pole" and "pole") or (name == "stone-wall" and "wall") or "lamp"
            n[key] = n[key] + 1
          end
        end
      end
    end
  end
  return f, n
end

S.init = function(ctx)
  local s = ctx.surface()
  s.freeze_daytime = true
  s.daytime = 0
  game.map_settings.enemy_expansion.enabled = false
  ctx.prepare_area(XA - 30, YA - 40, XA + 70, YA + 40, "dry-dirt")
  ctx.prepare_area(XB - 20, YB - RB - 10, CXB + RB + 10, YB + RB + 10, "dry-dirt")
  for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { XA - 120, YA - 200 }, { CXB + 200, YB + 200 } } })) do
    en.destroy()
  end
  local st = ctx.state()
  st.turrets_a = ligne(s)
  local base, n = base_mixte(s)
  -- la Tournesol, comme xp-zone : sa force frappe la base, la base ne riposte pas, les biters l'ignorent
  local fname = "fo-perf4-geant"
  local g = force(fname)
  base.set_cease_fire(g, true)
  g.set_cease_fire(base, false)
  game.forces.enemy.set_cease_fire(g, true)
  g.set_cease_fire(game.forces.enemy, true)
  game.forces.enemy.set_cease_fire(base, true)
  base.set_cease_fire(game.forces.enemy, true)
  if remote.interfaces["fo-robots"] and remote.interfaces["fo-robots"].set_age then remote.call("fo-robots", "set_age", fname, 15) end
  st.g = s.create_entity({ name = "fo-xp-tournesol", position = { XB, YB }, force = g, raise_built = true })
  ctx.check(st.turrets_a == 24, "scene A : 24 tourelles armees posees", st.turrets_a)
  ctx.check(st.g ~= nil and st.g.valid, "scene B : la Tournesol se pose")
  ctx.log(string.format("scene B : base mixte de %d tourelles, %d poteaux, %d murs, %d lampes dans %d tuiles", n.tur, n.pole, n.wall,
    n.lamp, RB))
end

S.tick = function(ctx, e)
  local t = e.tick
  for _, w in ipairs(WAVES) do
    if t == w then
      local s = ctx.surface()
      local grp = s.create_unit_group({ position = { XA + 40, YA }, force = "enemy" })
      local n = 0
      for _, spec in ipairs(WAVE) do
        for i = 1, spec[2] do
          local pos = s.find_non_colliding_position(spec[1], { XA + 40 + (i % 6) * 2, YA - 12 + (i % 13) * 2 }, 10, 0.5)
          local u = pos and s.create_entity({ name = spec[1], position = pos, force = "enemy" })
          if u then
            grp.add_member(u)
            n = n + 1
          end
        end
      end
      grp.set_command({ type = defines.command.attack_area, destination = { XA, YA }, radius = 30,
        distraction = defines.distraction.by_anything })
      grp.start_moving()
      ctx.log(string.format("t%d : vague de %d biters lancee sur la ligne", t, n))
    end
  end
  if t % 60 == 0 then
    close_tick()
    cur_tick = -1
    for _, k in ipairs({ "A", "B" }) do
      local p, tur = parts(sec[k])
      if p ~= "" then
        local n = 0
        for _, v in pairs(sec[k]) do n = n + v end
        ctx.log(string.format("%s t%d : %d evenement(s) en 60 ticks (tourelles %d), au plus %d par tick ; %s", k, t, n, tur, sec_max[k], p))
      end
      sec[k], sec_max[k] = {}, 0
    end
  end
end

S.finish = function(ctx)
  close_tick()
  local st = ctx.state()
  for _, k in ipairs({ "A", "B" }) do
    local p, tur = parts(tot[k])
    local n = n_all[k]
    ctx.log(string.format("BILAN scene %s : %d evenement(s) sur %d tick(s) actif(s), %.2f par tick actif, au plus %d par tick ; tourelles %d (%.0f %%) ; %s",
      k, n, act[k], act[k] > 0 and n / act[k] or 0, mx[k], tur, n > 0 and 100 * tur / n or 0, p))
  end
  ctx.check(n_all.A > 0, "scene A : la vague touche la ligne", n_all.A)
  ctx.check(n_all.B > 0, "scene B : la salve touche la base", n_all.B)
  ctx.check(st.g and st.g.valid, "scene B : la Tournesol est toujours la")
end

return S
