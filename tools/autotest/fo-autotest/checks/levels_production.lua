--[[
  Contrôles GREFFÉS au banc « content » (lot V3-T4) : LA PRODUCTION SUIT LA SURFACE, MESURÉE en moteur réel.
  Format : tools/autotest/README.md §4 ; listé dans checks/index.lua. Le même module sert au scénario greffé
  « t4-production » (scenarios/t4-production.lua), qui le joue seul et mesure EN PLUS la pollution par objet
  (statistiques de pollution du jeu : dans le banc content, d'autres greffons font tourner des machines de même nom).

  Q-T2-2, réponse du Directeur Créatif (22/10, 21 h 12) : « QT22 ah ouais non du coup, l'idée est vraiment d'avoir
  un idle massif en fait, des coûts qui augmentent évidemment, mais ça typiquement c'est pas possible donc A ».
  Règle (shared/levels/config.lua, L.stat_value) : statistique(n) = v1 × m(n) × R(n), R(n) = (côté(n)/côté(1))².

  Ce qui est joué (zone du greffon : 128 × 96 tuiles), sans bras ni tapis : le script nourrit chaque machine à
  chaque tick (minerai, plaques, charbon, chargeurs) et vide ses sorties, pour mesurer la machine SEULE :
    - fours en acier aux niveaux 1, 6 (2×2), 7 (3×3) et 30 (6×6) : minerai de fer → plaques ;
    - machines d'assemblage aux niveaux 1, 6 (3×3), 7 (4×4) et 30 (6×6) : engrenages ;
    - foreuses électriques aux niveaux 1, 6 (3×3), 7 (4×4) et 30 (6×6), minerai sous toute leur zone ;
    - mitrailleuses 1 (2×2) et 30 (6×6), tourelles laser 1 et 30 : chacune tire sur une cible (une tourelle laser 30
      sans courant, 5 350 PV, d'une force ennemie à part : 14 coups du plus gros tir mesuré), soignée à chaque tick ;
      dégâts relevés avant chaque soin.
  Fenêtre de mesure : ticks T0 à T1 (40 s). Production = Δ(products_finished + crafting_progress) pour les machines,
  objets sortis + Δ(mining_progress) pour les foreuses ; cartouches consommées pour la mitrailleuse (tirs = cartouches
  ÷ ammo_consumption_modifier du prototype).
  Première version (commit f86f2fb) : la CADENCE des tourelles suivait la surface ; ce greffon a mesuré que la
  mitrailleuse plafonne à 30 tirs/s (RD_LOG E56) : ce sont désormais les dégâts par tir, et un tir coûte R cartouches.
  Scénario t4-production SEUL (correction du lot, E58) : assembleur 30 avec 2 modules de vitesse 10 (plafond d'une
  fabrication par tick, F3), foreuse 30 avec 3 modules de vitesse 10 dans un coffre vidé et sur un tapis express, et
  six tourelles (mitrailleuses 1 et 30, lourde, chargeurs au tungstène ; lasers 1 et 30, laser lourd) contre un blindé
  « colosse » (résistance physique FIXE 26 et 78 %), comparées à la formule de résistance du moteur.
  Valeurs attendues : prototypes chargés (crafting_speed, mining_speed, cooldown), recettes du jeu (énergie) et config
  (L.stat_value, L.area_ratio) : jamais une copie.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
local ARS = require("__factorio-overhaul__/shared/content/arsenal")

local M = {}

M.T0, M.T1 = 300, 2700
-- Seconde fenêtre, scénario t4-production seul (E58) : même durée, après la mesure de pollution.
M.X0, M.X1 = M.T1 + 60, M.T1 + 60 + (M.T1 - M.T0)
local FORCE, TARGET = "fo-lv-prod", "fo-lv-prod-cible"
local FU, AS, DR, GUN, LZ = LV.by_key.furnace, LV.by_key.assembler, LV.by_key.drill, LV.by_key.gun, LV.by_key.laser
local LEVELS = { 1, 6, 7, 30 }
local AMMO = "firearm-magazine"

local function make_forces()
  local f = game.forces[FORCE] or game.create_force(FORCE)
  local t = game.forces[TARGET] or game.create_force(TARGET)
  f.recipes["iron-gear-wheel"].enabled = true
  -- Paix avec toutes les autres forces (ordre trié), guerre seulement entre la force des tourelles et la cible.
  local names = {}
  for name in pairs(game.forces) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    if name ~= FORCE and name ~= TARGET then
      for _, x in ipairs({ f, t }) do
        x.set_cease_fire(name, true)
        game.forces[name].set_cease_fire(x, true)
      end
    end
  end
  f.set_cease_fire(t, false)
  t.set_cease_fire(f, true)
  return f, t
end

--- Centre d'un bâtiment carré de côté `side` dont le coin nord-ouest est la tuile (x, y).
local function center(x, y, side) return { x = x + side / 2, y = y + side / 2 } end

local function put(s, f, family, n, x, y)
  local side = LV.footprint(family, n)
  return s.create_entity({ name = LV.name(family, n), position = center(x, y, side), force = f, raise_built = true })
end

---------------------------------------------------------------------------------------------------
-- Installation
---------------------------------------------------------------------------------------------------
function M.setup(ctx)
  local z, s = ctx.zone, ctx.surface()
  local st = ctx.state()
  local f = make_forces()
  local x0, y0 = z.x0, z.y0
  ctx.power(x0 + 64, y0 + 40, f)
  st.m = {}
  local made = 0
  -- Fours (rangée y0 + 4), assembleurs (y0 + 18), foreuses (y0 + 34) : coin nord-ouest de chaque bâtiment tous les
  -- 16 tuiles.
  for i, n in ipairs(LEVELS) do
    local x = x0 + 4 + 16 * (i - 1)
    local fu = put(s, f, FU, n, x, y0 + 4)
    if fu then made = made + 1 end
    st.m[#st.m + 1] = { kind = "furnace", family = "furnace", n = n, e = fu }
    local as = put(s, f, AS, n, x, y0 + 18)
    if as then
      as.set_recipe("iron-gear-wheel")
      made = made + 1
    end
    st.m[#st.m + 1] = { kind = "assembler", family = "assembler", n = n, e = as }
    -- Foreuse : minerai sous toute sa zone d'extraction (rayon du prototype), puis la foreuse, puis un coffre au dépôt.
    local side = LV.footprint(DR, n)
    local c = center(x, y0 + 36, side)
    local r = game.entity_prototypes[LV.name(DR, n)].mining_drill_radius
    for tx = math.floor(c.x - r), math.ceil(c.x + r) - 1 do
      for ty = math.floor(c.y - r), math.ceil(c.y + r) - 1 do
        s.create_entity({ name = "iron-ore", position = { tx + 0.5, ty + 0.5 }, amount = 1000000 })
      end
    end
    local dr = s.create_entity({ name = LV.name(DR, n), position = c, force = f, raise_built = true })
    local chest = dr and s.create_entity({ name = "steel-chest", position = dr.drop_position, force = f })
    if dr and chest then made = made + 1 end
    st.m[#st.m + 1] = { kind = "drill", family = "drill", n = n, e = dr, chest = chest }
  end
  -- Tourelles (rangée y0 + 62) : niveau 1 et 30 de chaque famille, chacune devant SA cible (bord nord 4 tuiles au sud
  -- de la tourelle), assez loin des autres cibles (portée du niveau 30 : 27,25 et 33,25). Correction (défaut 19 du
  -- correcteur) : la cible était une mitrailleuse de 400 PV, à 5 % près du coup du laser 30 (381,6) ; c'est une
  -- tourelle laser 30 sans courant (5 350 PV), contrôlée ci-dessous contre le plus gros coup des prototypes.
  local spots = { { GUN, 1, 6 }, { GUN, 30, 42 }, { LZ, 1, 78 }, { LZ, 30, 114 } }
  local tside = LV.footprint(LZ, 30)
  for _, sp in ipairs(spots) do
    local fam, n, dx = sp[1], sp[2], sp[3]
    local side = LV.footprint(fam, n)
    local c = center(x0 + dx - side / 2, y0 + 62 - side / 2, side)
    local t = s.create_entity({ name = LV.name(fam, n), position = c, force = f, raise_built = true })
    local target = s.create_entity({ name = LV.name(LZ, 30), position = { c.x, c.y + side / 2 + 4 + tside / 2 }, force = TARGET })
    if t and target then made = made + 1 end
    if t and fam == GUN then t.insert({ name = AMMO, count = 50 }) end
    st.m[#st.m + 1] = { kind = "turret", family = fam.key, n = n, e = t, target = target, inserted = 0, damage = 0,
      ammo = fam == GUN and AMMO or nil }
  end
  ctx.check(made == 16, "V3-T4 : 4 fours, 4 assembleurs, 4 foreuses (niveaux 1, 6, 7, 30) et 4 tourelles (1 et 30) poses",
    made .. " / 16")
  -- L'expérience de cadence E56 (mitrailleuses aux délais 2,67 ; 1,5 ; 0,96 ; 0,67 tick : 22,5 puis 30 tirs/s au plus)
  -- a été jouée par la première version de ce greffon (commit f86f2fb, journaux fo-logs\2026-10-22_V3T4\02_...).
  if ctx.solo then M.setup_extras(ctx, s, f) end
end

---------------------------------------------------------------------------------------------------
-- Scénario t4-production seul (E58) : plafonds du moteur avec modules, tapis, blindés
---------------------------------------------------------------------------------------------------
M.EXTRA = { x0 = 588, y0 = 352, x1 = 868, y1 = 520 }
M.SPEED10 = "fo-speed-module-10"
M.ARMORED = "fo-armored-colossal-biter"
M.TUNGSTEN = "fo-tungsten-rounds-magazine"

function M.setup_extras(ctx, s, f)
  local st = ctx.state()
  local X = M.EXTRA
  ctx.prepare_area(X.x0, X.y0, X.x1, X.y1, "grass-1")
  for _, en in ipairs(s.find_entities_filtered({ area = { { X.x0 - 64, X.y0 - 64 }, { X.x1 + 64, X.y1 + 64 } }, force = "enemy" })) do
    if en.valid then en.destroy() end
  end
  ctx.power(760, 420, f)
  local made = 0
  -- 1. Assembleur 30 (6×6) avec 2 modules de vitesse 10 : 9,96 × (1 + 2 × 2,4) / 0,5 s = 115,5 engrenages/s demandés.
  local as = put(s, f, AS, 30, 700, 362)
  if as then
    as.set_recipe("iron-gear-wheel")
    if as.get_module_inventory().insert({ name = M.SPEED10, count = 2 }) == 2 then made = made + 1 end
  end
  st.m[#st.m + 1] = { kind = "assembler", family = "assembler", n = 30, e = as, extra = "modules" }
  -- 2 et 3. Foreuses 30 avec 3 modules de vitesse 10 : 7,8 × (1 + 3 × 2,4) = 63,96 minerais/s demandés ; l'une
  -- dépose dans un coffre vidé à chaque tick, l'autre sur un tapis express de 10 tuiles vers l'est, vidé à son bout.
  for i, mode in ipairs({ "chest", "belt" }) do
    local side = LV.footprint(DR, 30)
    local c = center(720 + 28 * (i - 1), 362, side)
    local r = game.entity_prototypes[LV.name(DR, 30)].mining_drill_radius
    for tx = math.floor(c.x - r), math.ceil(c.x + r) - 1 do
      for ty = math.floor(c.y - r), math.ceil(c.y + r) - 1 do
        s.create_entity({ name = "iron-ore", position = { tx + 0.5, ty + 0.5 }, amount = 1000000 })
      end
    end
    local dr = s.create_entity({ name = LV.name(DR, 30), position = c, force = f, raise_built = true })
    local m = { kind = "drill", family = "drill", n = 30, e = dr, extra = mode }
    if dr and dr.get_module_inventory().insert({ name = M.SPEED10, count = 3 }) == 3 then
      local p = dr.drop_position
      if mode == "chest" then
        m.chest = s.create_entity({ name = "steel-chest", position = p, force = f })
        if m.chest then made = made + 1 end
      else
        m.belt = {}
        for k = 0, 9 do
          m.belt[#m.belt + 1] = s.create_entity({ name = "express-transport-belt", position = { math.floor(p.x) + k + 0.5, math.floor(p.y) + 0.5 },
            direction = defines.direction.east, force = f })
        end
        if #m.belt == 10 then made = made + 1 end
      end
    end
    st.m[#st.m + 1] = m
  end
  -- 4. Six tourelles contre un blindé « colosse » chacune (unité inactive, force cible, soignée à chaque tick), 44 tuiles
  -- entre deux tourelles (portée du laser 30 : 33,25). Mitrailleuses au tungstène (40 dégâts physiques).
  local row = {
    { "gun", LV.name(GUN, 1), 2, M.TUNGSTEN }, { "gun", LV.name(GUN, 30), 6, M.TUNGSTEN }, { "gun", "fo-heavy-gun-turret", 3, M.TUNGSTEN },
    { "laser", LV.name(LZ, 1), 2 }, { "laser", LV.name(LZ, 30), 6 }, { "laser", "fo-heavy-laser-turret", 3 },
  }
  for i, r in ipairs(row) do
    local x = 600 + 44 * (i - 1)
    local c = { x = x + (r[3] % 2 == 1 and 0.5 or 0), y = 430 + (r[3] % 2 == 1 and 0.5 or 0) }
    local t = s.create_entity({ name = r[2], position = c, force = f })
    local target = s.create_entity({ name = M.ARMORED, position = { x + 0.5, 430 + r[3] / 2 + 6 }, force = TARGET })
    if target then target.active = false end
    if t and r[4] then t.insert({ name = r[4], count = 50 }) end
    if t and target then made = made + 1 end
    st.m[#st.m + 1] = { kind = "turret", family = r[1], n = r[2], e = t, target = target, inserted = 0, damage = 0, ammo = r[4], extra = "armored", side = r[3] }
  end
  -- 5. Cartouches par tir (ammo_consumption_modifier = R) aux quatre tailles d'agrandissement : mitrailleuses 7 (3×3),
  -- 13 (4×4), 19 (5×5) et 25 (6×6), chargeurs ordinaires, chacune devant sa cible (tourelle laser 30 sans courant).
  for i, n in ipairs({ 7, 13, 19, 25 }) do
    local side = LV.footprint(GUN, n)
    local c = center(600 + 44 * (i - 1) - math.floor(side / 2), 490 - math.floor(side / 2), side)
    local t = put(s, f, GUN, n, 600 + 44 * (i - 1) - math.floor(side / 2), 490 - math.floor(side / 2))
    local target = s.create_entity({ name = LV.name(LZ, 30), position = { math.floor(c.x), math.floor(c.y + side / 2) + 4 + 3 }, force = TARGET })
    if t then t.insert({ name = AMMO, count = 50 }) end
    if t and target then made = made + 1 end
    st.m[#st.m + 1] = { kind = "turret", family = "gun", n = "ammo-" .. n, level = n, e = t, target = target, inserted = 0, damage = 0, ammo = AMMO, extra = "ammo", side = side }
  end
  ctx.check(made == 13, "V3-T4 (E58) : assembleur 30 et 2 foreuses 30 avec modules de vitesse 10 (coffre, tapis express), 6 tourelles face a un blinde, 4 mitrailleuses 7, 13, 19, 25 poses",
    made .. " / 13")
end

---------------------------------------------------------------------------------------------------
-- Chaque tick : nourrir, vider, soigner les cibles ; relevés à T0 et T1
---------------------------------------------------------------------------------------------------
local function top_up(inv, name, want)
  local have = inv.get_item_count(name)
  if have < want then inv.insert({ name = name, count = want - have }) end
end

--- Cartouches dans la tourelle : (chargeurs − 1) × taille + cartouches du chargeur entamé.
local function rounds(t, ammo)
  local inv = t.get_inventory(defines.inventory.turret_ammo)
  local size = game.item_prototypes[ammo or AMMO].magazine_size
  local total = 0
  for i = 1, #inv do
    local stack = inv[i]
    if stack.valid_for_read then total = total + (stack.count - 1) * size + stack.ammo end
  end
  return total
end

local function produced(m)
  local e = m.e
  if m.kind == "drill" then return (m.out or 0) + (e.mining_progress or 0) end
  return e.products_finished + e.crafting_progress
end

function M.tick(ctx, tick)
  local st = ctx.state()
  if not st.m or st.closed then return end
  for _, m in ipairs(st.m) do
    local e = m.e
    -- Mesures du scénario seul (E58) : à l'arrêt pendant la première fenêtre (la pollution par nom d'entité y est
    -- mesurée : une foreuse 30 de plus la fausserait), puis seconde fenêtre de même durée, X0 à X1.
    local w0, w1 = M.T0, M.T1
    if m.extra then
      w0, w1 = M.X0, M.X1
      if e and e.valid then e.active = tick >= M.T1 end
    end
    local in_window = tick > w0 and tick <= w1
    if e and e.valid then
      if m.kind == "furnace" then
        top_up(e.get_inventory(defines.inventory.fuel), "coal", 20)
        top_up(e.get_inventory(defines.inventory.furnace_source), "iron-ore", 40)
        e.get_inventory(defines.inventory.furnace_result).clear()
      elseif m.kind == "assembler" then
        top_up(e.get_inventory(defines.inventory.assembling_machine_input), "iron-plate", 80)
        e.get_inventory(defines.inventory.assembling_machine_output).clear()
      elseif m.kind == "drill" and m.chest and m.chest.valid then
        local got = m.chest.get_item_count("iron-ore")
        if got > 0 then
          m.chest.get_inventory(defines.inventory.chest).clear()
          m.out = (m.out or 0) + got
        end
      elseif m.kind == "drill" and m.belt then
        -- Tapis express : on vide la DERNIÈRE tuile (ses deux voies) ; le reste du tapis transporte au débit du moteur.
        local last = m.belt[#m.belt]
        if last and last.valid then
          for line = 1, 2 do
            local tl = last.get_transport_line(line)
            local got = tl.get_item_count("iron-ore")
            if got > 0 then
              tl.clear()
              m.out = (m.out or 0) + got
            end
          end
        end
      elseif m.kind == "turret" then
        local tg = m.target
        if tg and tg.valid then
          local lost = tg.prototype.max_health - tg.health
          if in_window then m.damage = m.damage + lost end
          tg.health = tg.prototype.max_health
        end
        if m.ammo then
          local inv = e.get_inventory(defines.inventory.turret_ammo)
          local have = inv.get_item_count(m.ammo)
          if have < 30 then
            local put_n = inv.insert({ name = m.ammo, count = 50 - have })
            if in_window then m.inserted = m.inserted + put_n end
          end
        end
      end
      if tick == w0 then
        if m.kind == "turret" then
          m.r0 = m.ammo and rounds(e, m.ammo) or 0
        else
          m.p0 = produced(m)
        end
      elseif tick == w1 then
        if m.kind == "turret" then
          m.r1 = m.ammo and rounds(e, m.ammo) or 0
          m.target_ok = m.target ~= nil and m.target.valid
        else
          m.p1 = produced(m)
        end
      end
    end
  end
  if tick == M.T0 and ctx.solo then
    st.pol0 = M.pollution()
  elseif tick == M.T1 and ctx.solo then
    st.pol1 = M.pollution()
  end
  if tick == (ctx.solo and M.X1 or M.T1) then st.closed = true end
end

--- Pollution émise depuis le début de la partie, par nom d'entité mesuré (statistiques du jeu).
function M.pollution()
  local out = {}
  local stats = game.pollution_statistics
  for _, fam in ipairs({ FU, AS, DR }) do
    for _, n in ipairs({ 1, 30 }) do
      local name = LV.name(fam, n)
      out[name] = stats.get_input_count(name)
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Vérification
---------------------------------------------------------------------------------------------------
local function by(st, family, n)
  for _, m in ipairs(st.m or {}) do if m.family == family and m.n == n then return m end end
end

--- Cartouches consommées par seconde d'une mitrailleuse dans sa fenêtre.
local function rounds_of(m, secs)
  if not (m and m.r0 and m.r1 and m.ammo) then return nil end
  return (m.r0 + m.inserted * game.item_prototypes[m.ammo].magazine_size - m.r1) / secs
end

--- Tirs par seconde d'une mitrailleuse : dégâts mesurés ÷ dégâts d'un tir (chargeur ordinaire, 5 × damage_modifier ;
--- cible sans résistance). Les cartouches ne le disent plus : un tir en prend jusqu'à ammo_consumption_modifier, mais
--- seulement sur le chargeur entamé (RD_LOG E58).
local function shots_of(m, secs)
  if not (m and m.e and m.e.valid) then return nil end
  return (m.damage / secs) / (5 * m.e.prototype.attack_parameters.damage_modifier)
end

--- Cartouches réellement prises par tir, chargeur de `mag` : chaque tir prend min(modificateur, reste du chargeur).
local function model_per_shot(mod, mag)
  local left, shots = mag, 0
  while left > 1e-9 and shots < 1000 do
    left = left - math.min(mod, left)
    shots = shots + 1
  end
  return mag / shots
end

--- Statistique attendue au niveau n : L.stat_value sur la valeur du prototype du niveau 1 (jeu chargé).
local function want_stat(family, key, v1, n)
  for _, s in ipairs(family.stats) do
    if s.path[#s.path] == key then return LV.stat_value(family, s, v1, n) end
  end
end

function M.verify(ctx)
  local st = ctx.state()
  local secs = (M.T1 - M.T0) / 60
  ctx.check(st.closed == true, "V3-T4 : fenetre de mesure jouee (ticks " .. M.T0 .. " a " .. M.T1 .. ", " .. secs .. " s)")
  -- 1. Prototypes chargés = règle de la config (vitesses, dégâts, cadence inchangée, débit d'entrée du laser).
  local bad, seen = {}, 0
  local P = game.entity_prototypes
  for _, n in ipairs(LEVELS) do
    local cs = want_stat(FU, "crafting_speed", P[FU.base].crafting_speed, n)
    if math.abs(P[LV.name(FU, n)].crafting_speed - cs) > 1e-6 * cs then bad[#bad + 1] = "four " .. n end
    local ca = want_stat(AS, "crafting_speed", P[AS.base].crafting_speed, n)
    if math.abs(P[LV.name(AS, n)].crafting_speed - ca) > 1e-6 * ca then bad[#bad + 1] = "assembleur " .. n end
    local md = want_stat(DR, "mining_speed", P[DR.base].mining_speed, n)
    if math.abs(P[LV.name(DR, n)].mining_speed - md) > 1e-6 * md then bad[#bad + 1] = "foreuse " .. n end
    seen = seen + 3
  end
  for _, fam in ipairs({ GUN, LZ }) do
    local dm = want_stat(fam, "damage_modifier", P[fam.base].attack_parameters.damage_modifier or 1, 30)
    if math.abs(P[LV.name(fam, 30)].attack_parameters.damage_modifier - dm) > 1e-6 * dm then bad[#bad + 1] = fam.key .. " 30 degats" end
    if P[LV.name(fam, 30)].attack_parameters.cooldown ~= P[fam.base].attack_parameters.cooldown then bad[#bad + 1] = fam.key .. " 30 cadence" end
    seen = seen + 2
  end
  local ac = want_stat(GUN, "ammo_consumption_modifier", P[GUN.base].attack_parameters.ammo_consumption_modifier or 1, 30)
  if math.abs((P[LV.name(GUN, 30)].attack_parameters.ammo_consumption_modifier or 1) - ac) > 1e-6 * ac then bad[#bad + 1] = "gun 30 cartouches par tir" end
  seen = seen + 1
  local lz30 = by(st, "laser", 30)
  local lz1 = by(st, "laser", 1)
  local flow_ok = lz30 and lz30.e and lz30.e.valid and lz1 and lz1.e and lz1.e.valid
    and math.abs(lz30.e.electric_input_flow_limit / lz1.e.electric_input_flow_limit
      - want_stat(LZ, "input_flow_limit", 1, 30)) < 1e-3
  if not flow_ok then bad[#bad + 1] = "laser 30 debit d'entree" end
  seen = seen + 1
  ctx.check(#bad == 0, "V3-T4 : prototypes charges = regle de surface (vitesses, degats, cartouches par tir, cadence inchangee, debit d'entree du laser)",
    #bad > 0 and table.concat(bad, ", ") or string.format("%d valeurs ; four 30 : %.2f ; assembleur 30 : %.2f ; foreuse 30 : %.2f ; mitrailleuse 30 : degats x %.2f, %g cartouches par tir, delai %g ticks ; laser 30 : degats x %.2f, %.0f kW",
      seen, P[LV.name(FU, 30)].crafting_speed, P[LV.name(AS, 30)].crafting_speed, P[LV.name(DR, 30)].mining_speed,
      P[LV.name(GUN, 30)].attack_parameters.damage_modifier, P[LV.name(GUN, 30)].attack_parameters.ammo_consumption_modifier or 1,
      P[LV.name(GUN, 30)].attack_parameters.cooldown,
      P[LV.name(LZ, 30)].attack_parameters.damage_modifier, lz30 and lz30.e.valid and lz30.e.electric_input_flow_limit * 60 / 1000 or -1))
  -- Cibles (défaut 19 du correcteur) : PV de la cible ≥ 5 × le plus gros coup des prototypes mesurés (chargeur
  -- ordinaire × dégâts de la mitrailleuse 30 ; 10 × dégâts du laser 30 par coup de faisceau), toutes encore là à la fin.
  local hit_gun = 5 * P[LV.name(GUN, 30)].attack_parameters.damage_modifier -- chargeur ordinaire : 5 dégâts (vanilla)
  local hit_lz = 10 * P[LV.name(LZ, 30)].attack_parameters.damage_modifier
  local tgt_hp = P[LV.name(LZ, 30)].max_health
  local all_there = true
  for _, m in ipairs(st.m or {}) do
    if m.kind == "turret" and not m.extra and not m.target_ok then all_there = false end
  end
  ctx.check(all_there and tgt_hp >= 5 * math.max(hit_gun, hit_lz),
    "V3-T4 : cibles des tourelles a PV larges (>= 5 fois le plus gros coup) et toutes encore la a la fin de la mesure",
    string.format("cible %s : %d PV ; plus gros coup : mitrailleuse 30 %.1f, laser 30 %.1f (marge x %.1f)", LV.name(LZ, 30), tgt_hp, hit_gun, hit_lz,
      tgt_hp / math.max(1e-9, hit_gun, hit_lz)))
  -- 2. Machines : production MESURÉE = théorie (± 2 %), et production par tuile croissante (1 ≤ 6 < 7 ≤ 30).
  local specs = {
    { FU, "furnace", "four", function(p) return p.crafting_speed / game.recipe_prototypes["iron-plate"].energy end },
    { AS, "assembler", "assembleur", function(p) return p.crafting_speed / game.recipe_prototypes["iron-gear-wheel"].energy end },
    { DR, "drill", "foreuse", function(p) return p.mining_speed / P["iron-ore"].mineable_properties.mining_time end },
  }
  st.rates = {}
  for _, sp in ipairs(specs) do
    local fam, key, label, theory = sp[1], sp[2], sp[3], sp[4]
    local parts, ok_rate, tiles = {}, true, {}
    for _, n in ipairs(LEVELS) do
      local m = by(st, key, n)
      local rate = m and m.p0 and m.p1 and (m.p1 - m.p0) / secs
      local th = theory(P[LV.name(fam, n)])
      local side = LV.footprint(fam, n)
      if not rate or math.abs(rate / th - 1) > 0.02 then ok_rate = false end
      tiles[n] = rate and rate / (side * side) or 0
      st.rates[key .. n] = rate
      parts[#parts + 1] = string.format("n%d %dx%d : %.3f/s (theorie %.3f), %.4f/tuile", n, side, side, rate or -1, th, tiles[n])
    end
    ctx.check(ok_rate, "V3-T4 : " .. label .. " : production mesuree = theorie du prototype (+/- 2 %) aux niveaux 1, 6, 7, 30",
      table.concat(parts, " ; "))
    local grows = tiles[1] > 0 and tiles[6] >= tiles[1] and tiles[7] > tiles[6] and tiles[30] > tiles[7]
    ctx.check(grows, "V3-T4 : " .. label .. " : production PAR TUILE mesuree croissante (n1 <= n6 < n7 < n30) : la grande vaut au moins les petites",
      string.format("n30 / n1 par tuile : x %.2f ; par batiment : x %.2f", tiles[30] / tiles[1],
        (st.rates[key .. 30] or 0) / math.max(1e-9, st.rates[key .. 1] or 1e-9)))
  end
  -- 3. Mitrailleuse : cadence mesurée (dégâts ÷ dégâts d'un tir) INCHANGÉE (10 tirs/s au niveau 1 comme au 30 : le
  --    moteur plafonne la cadence, E56) ; les dégâts par tir portent la règle, et chaque tir coûte environ R cartouches
  --    (correction, défaut 1 du correcteur) : cartouches PAR DÉGÂT = courbe d'avant (1 / m(30) du niveau 1) × le
  --    facteur du chargeur (10 cartouches par tir pour R = 9 : × 1,11 ; RD_LOG E58). Puis DPS mesuré = dégâts × R.
  local g1, g30 = by(st, "gun", 1), by(st, "gun", 30)
  local shots1, shots30 = shots_of(g1, secs), shots_of(g30, secs)
  ctx.check(shots1 and shots30 and shots1 > 0 and math.abs(shots30 / shots1 - 1) <= 0.03,
    "V3-T4 : mitrailleuse 30 (6x6) : cadence mesuree inchangee (les degats par tir portent la regle)",
    string.format("niveau 1 : %.2f tirs/s ; niveau 30 : %.2f tirs/s (cartouches : %.2f/s et %.2f/s)", shots1 or -1, shots30 or -1,
      rounds_of(g1, secs) or -1, rounds_of(g30, secs) or -1))
  do
    local r1, r30 = rounds_of(g1, secs), rounds_of(g30, secs)
    local d1, d30 = g1 and g1.damage / secs or 0, g30 and g30.damage / secs or 0
    local m30
    for _, s in ipairs(GUN.stats) do if s.path[#s.path] == "damage_modifier" then m30 = LV.apply_stat(s, 1, 30) end end
    local per1, per30 = r1 and d1 > 0 and r1 / d1, r30 and d30 > 0 and r30 / d30
    local mag = game.item_prototypes[AMMO].magazine_size
    local mod30 = P[LV.name(GUN, 30)].attack_parameters.ammo_consumption_modifier or 1
    local factor = model_per_shot(mod30, mag) / LV.area_ratio(GUN, 30)
    ctx.check(per1 and per30 and math.abs(per30 / per1 * m30 / factor - 1) <= 0.05 and factor >= 0.8 and factor <= 1.12,
      "V3-T4 : mitrailleuse 30 : cartouches PAR DEGAT mesurees = courbe d'avant x facteur du chargeur (+/- 5 % ; facteur entre 0,8 et 1,12) : la 6x6 use a peu pres autant que les 9 petites",
      string.format("niveau 1 : %.4f cartouche par degat ; niveau 30 : %.4f (x %.3f ; courbe d'avant 1/%.2f = %.3f, facteur du chargeur %.3f : %.3f attendu) ; cartouches/s x %.2f (R = %d, %.4g par tir au prototype)",
        per1 or -1, per30 or -1, (per30 or 0) / math.max(1e-12, per1 or 0), m30, 1 / m30, factor, factor / m30,
        (r30 or 0) / math.max(1e-9, r1 or 0), LV.area_ratio(GUN, 30), mod30))
  end
  for _, fam in ipairs({ GUN, LZ }) do
    local a, b = by(st, fam.key, 1), by(st, fam.key, 30)
    local d1, d30 = a and a.damage / secs or 0, b and b.damage / secs or 0
    local s1, s30 = LV.footprint(fam, 1), LV.footprint(fam, 30)
    local want = want_stat(fam, "damage_modifier", 1, 30)
    ctx.check(d1 > 0 and d30 / (s30 * s30) >= d1 / (s1 * s1) and math.abs(d30 / d1 / want - 1) <= 0.05,
      "V3-T4 : " .. fam.key .. " 30 : DPS mesure = degats x m(30) x R(30) (+/- 5 %), DPS par tuile au-dessus du niveau 1",
      string.format("niveau 1 : %.1f/s ; niveau 30 : %.1f/s (x %.2f, attendu x %.2f) ; par tuile %.2f -> %.2f",
        d1, d30, d30 / math.max(1e-9, d1), want, d1 / (s1 * s1), d30 / (s30 * s30)))
  end
  -- 4. (scénario t4-production seul) Pollution PAR OBJET : celle de la courbe d'avant (× 1/m(30) du niveau 1), la
  --    surface s'annule (émissions × R pour une production × R).
  if ctx.solo then
    local parts, ok = {}, st.pol0 ~= nil and st.pol1 ~= nil
    for _, sp in ipairs(specs) do
      local fam, key = sp[1], sp[2]
      local function per_item(n)
        local name = LV.name(fam, n)
        local pol = (st.pol1 and st.pol0) and (st.pol1[name] - st.pol0[name]) or 0
        return pol / math.max(1e-9, (st.rates[key .. n] or 0) * secs), pol
      end
      local p1, q1 = per_item(1)
      local p30, q30 = per_item(30)
      local m30
      for _, s in ipairs(fam.stats) do
        local k = s.path[#s.path]
        if k == "crafting_speed" or k == "mining_speed" then m30 = LV.apply_stat(s, 1, 30) end
      end
      if not (q1 > 0 and q30 > 0 and math.abs((p30 / p1) * m30 - 1) <= 0.05) then ok = false end
      parts[#parts + 1] = string.format("%s : %.4f -> %.4f par objet (x %.3f, attendu 1/%.2f = %.3f)", sp[3], p1, p30, p30 / math.max(1e-12, p1), m30, 1 / m30)
    end
    ctx.check(ok, "V3-T4 : pollution PAR OBJET mesuree (statistiques du jeu) = celle de la courbe d'avant (1/m(30) du niveau 1, +/- 5 %)",
      table.concat(parts, " ; "))
    M.verify_extras(ctx, st, P)
  end
end

--- Dégâts d'un coup après une résistance { decrease, percent } (formule du moteur 1.1 : au-delà de la part fixe,
--- (dégâts − fixe) × (1 − %) ; sinon 1 / (2 − (dégâts − fixe)) × (1 − %)). percent du runtime : fraction (0 à 1).
local function after_resist(d, r)
  if not r then return d end
  local pct = r.percent or 0
  if pct > 1 then pct = pct / 100 end
  local x = d - (r.decrease or 0)
  if x >= 1 then return x * (1 - pct) end
  return 1 / (2 - x) * (1 - pct)
end

--- Scénario t4-production seul (E58) : plafonds du moteur avec modules, tapis express, tourelles contre un blindé.
function M.verify_extras(ctx, st, P)
  local secs = (M.X1 - M.X0) / 60
  local function ext(kind, extra)
    for _, m in ipairs(st.m or {}) do if m.kind == kind and m.extra == extra then return m end end
  end
  local sp10 = game.item_prototypes[M.SPEED10].module_effects.speed.bonus
  -- a. Assembleur 30 + 2 modules de vitesse 10, engrenages (0,5 s) : 115,5 fabrications/s demandées.
  local am = ext("assembler", "modules")
  local a_rate = am and am.p0 and am.p1 and (am.p1 - am.p0) / secs
  local a_th = P[LV.name(AS, 30)].crafting_speed * (1 + 2 * sp10) / game.recipe_prototypes["iron-gear-wheel"].energy
  ctx.check(a_rate and math.abs(a_rate - math.min(60, a_th)) <= 0.02 * math.min(60, a_th),
    "V3-T4 (E58) : assembleur 30 + 2 modules de vitesse 10 : production mesuree = min(60/s, theorie) (plafond d'une fabrication par tick, F3) : la 6x6 vaut alors moins que les 4 machines 3x3 qu'elle remplace",
    string.format("mesure %.2f/s ; theorie %.2f/s (vitesse %.2f x %.2f) ; bonus de vitesse lu %.2f ; 4 machines 3x3 du meme niveau : %.1f/s",
      a_rate or -1, a_th, P[LV.name(AS, 30)].crafting_speed, 1 + 2 * sp10, am and am.e and am.e.valid and am.e.speed_bonus or -1,
      4 * math.min(60, a_th / 4)))
  -- b. Foreuse 30 + 3 modules de vitesse 10 dans un coffre vidé à chaque tick : 63,96 minerais/s demandés.
  local dc = ext("drill", "chest")
  local d_rate = dc and dc.p0 and dc.p1 and (dc.p1 - dc.p0) / secs
  local d_th = P[LV.name(DR, 30)].mining_speed * (1 + 3 * sp10) / P["iron-ore"].mineable_properties.mining_time
  ctx.check(d_rate and math.abs(d_rate - d_th) <= 0.02 * d_th,
    "V3-T4 (E58) : foreuse 30 + 3 modules de vitesse 10, sortie dans un coffre : minage mesure = theorie (+/- 2 %), au-dela de 60/s : pas de plafond d'un resultat par tick pour une foreuse",
    string.format("mesure %.2f/s ; theorie %.2f/s", d_rate or -1, d_th))
  -- c. Même foreuse, sortie sur un tapis express (un seul point de dépôt).
  local db = ext("drill", "belt")
  local b_rate = db and db.p0 and db.p1 and (db.p1 - db.p0) / secs
  -- Une voie de tapis express : vitesse (tuiles par tick) × 60 × 4 objets par tuile = 22,5/s.
  local lane = P["express-transport-belt"].belt_speed * 60 * 4
  ctx.check(b_rate and b_rate <= 1.01 * lane and b_rate >= 0.95 * lane and b_rate < 0.5 * d_th,
    "V3-T4 (E58) : foreuse 30 + 3 modules de vitesse 10, sortie sur un tapis express : limitee a UNE voie (un seul point de depot) : la 6x6 avec modules vaut alors moins que les petites (chacune sur sa voie)",
    string.format("mesure %.2f/s ; une voie express : %.2f/s ; coffre : %.2f/s ; theorie %.2f/s", b_rate or -1, lane, d_rate or -1, d_th))
  -- d. Tourelles contre un blindé « colosse » : DPS mesuré = formule de résistance du moteur (± 5 %, ou ± 1/s : la
  --    régénération de l'unité, 0,1 PV par tick, est rendue entre deux soins) ; DPS par tuile journalisé.
  local res = game.entity_prototypes[M.ARMORED].resistances or {}
  local tungsten
  for _, a in ipairs(ARS.ammo) do if a.name == M.TUNGSTEN then tungsten = a.damage.physical end end
  local parts, ok = {}, true
  for _, m in ipairs(st.m or {}) do
    if m.extra == "armored" then
      local p = m.e and m.e.valid and m.e.prototype
      local ap = p and p.attack_parameters
      local meas = m.damage / secs
      local want = 0
      if ap then
        local per_s = 60 / ap.cooldown
        if m.family == "gun" then
          want = per_s * after_resist(tungsten * ap.damage_modifier, res.physical)
        else
          want = per_s * after_resist(10 * ap.damage_modifier, res.laser)
        end
      end
      if not (m.target_ok and want > 0 and math.abs(meas - want) <= math.max(0.05 * want, 1)) then ok = false end
      parts[#parts + 1] = string.format("%s %dx%d : %.1f/s (formule %.1f), %.2f/tuile", m.n, m.side, m.side, meas, want, meas / (m.side * m.side))
    end
  end
  ctx.check(ok and #parts == 6,
    "V3-T4 (E58) : 6 tourelles contre un blinde colosse (physique 26 fixe, 78 %) : DPS mesure = formule de resistance du moteur (+/- 5 %)",
    table.concat(parts, " ; "))
  -- e. Cartouches par tir mesurées (cartouches/s ÷ tirs/s, tirs = DPS ÷ dégâts d'un tir) aux 4 tailles, comparées au
  --    modèle « un tir ne prend que sur le chargeur entamé » : chaque tir consomme min(cartouches par tir du prototype,
  --    cartouches restantes du chargeur), chargeurs de 10 ; et rapportées à R (facteur entre 0,8 et 1,12).
  local mag = game.item_prototypes[AMMO].magazine_size
  local aparts, aok, an = {}, true, 0
  local all = {}
  for _, m in ipairs(st.m or {}) do if m.extra == "ammo" then all[#all + 1] = m end end
  local g30 = by(st, "gun", 30)
  if g30 then all[#all + 1] = { level = 30, e = g30.e, damage = g30.damage, r0 = g30.r0, r1 = g30.r1, inserted = g30.inserted, ammo = g30.ammo, first = true } end
  for _, m in ipairs(all) do
    local ws = m.first and (M.T1 - M.T0) / 60 or secs
    local p = m.e and m.e.valid and m.e.prototype
    local ap = p and p.attack_parameters
    local rps = rounds_of(m, ws)
    local shots = ap and (m.damage / ws) / (5 * ap.damage_modifier)
    local per = rps and shots and shots > 0 and rps / shots
    local modv = ap and (ap.ammo_consumption_modifier or 1) or 1
    local want = model_per_shot(modv, mag)
    an = an + 1
    local fct = (per or 0) / LV.area_ratio(GUN, m.level)
    if not (per and math.abs(per / want - 1) <= 0.03) or fct < 0.79 or fct > 1.13 then aok = false end
    aparts[#aparts + 1] = string.format("niveau %d (R %.2f, %g par tir au prototype) : %.2f tirs/s, %.2f cartouches/s, %.3f par tir (modele %.3f ; par degat x %.3f de la courbe d'avant)",
      m.level, LV.area_ratio(GUN, m.level), modv, shots or -1, rps or -1, per or -1, want,
      (per or 0) / math.max(1e-9, LV.area_ratio(GUN, m.level)))
  end
  ctx.check(aok and an == 5,
    "V3-T4 (E58) : cartouches par tir mesurees = modele 'un tir ne prend que sur le chargeur entame' (+/- 3 %) et entre 0,8 et 1,12 x R, mitrailleuses 7, 13, 19, 25, 30",
    table.concat(aparts, " ; "))
end

function M.shots(ctx, add)
  local z = ctx.zone
  add("machines", z.x0 + 34, z.y0 + 24, 0.9, 0)
  add("tourelles", z.x0 + 60, z.y0 + 64, 0.6, 0)
end

-- Crochets du banc content.
return {
  module = M,
  setup = function(ctx)
    ctx.prepare_zone("grass-1")
    M.setup(ctx)
  end,
  tick = function(ctx, e) M.tick(ctx, e.tick) end,
  verify = M.verify,
  shots = M.shots,
}
