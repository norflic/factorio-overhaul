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
    - mitrailleuses 1 (2×2) et 30 (6×6), tourelles laser 1 et 30 : chacune tire sur une cible (une mitrailleuse sans
      munitions d'une force ennemie à part), soignée à chaque tick ; dégâts relevés avant chaque soin.
  Fenêtre de mesure : ticks T0 à T1 (40 s). Production = Δ(products_finished + crafting_progress) pour les machines,
  objets sortis + Δ(mining_progress) pour les foreuses ; cadence de la mitrailleuse = cartouches consommées.
  Première version (commit f86f2fb) : la CADENCE des tourelles suivait la surface ; ce greffon a mesuré que la
  mitrailleuse plafonne à 30 tirs/s (RD_LOG E56) : ce sont désormais les dégâts par tir.
  Valeurs attendues : prototypes chargés (crafting_speed, mining_speed, cooldown), recettes du jeu (énergie) et config
  (L.stat_value, L.area_ratio) : jamais une copie.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")

local M = {}

M.T0, M.T1 = 300, 2700
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
  -- Tourelles (rangée y0 + 62) : niveau 1 et 30 de chaque famille, chacune devant SA cible (6 tuiles au sud), assez
  -- loin des autres cibles (portée du niveau 30 : 27,25 et 33,25).
  local spots = { { GUN, 1, 6 }, { GUN, 30, 42 }, { LZ, 1, 78 }, { LZ, 30, 114 } }
  for _, sp in ipairs(spots) do
    local fam, n, dx = sp[1], sp[2], sp[3]
    local side = LV.footprint(fam, n)
    local c = center(x0 + dx - side / 2, y0 + 62 - side / 2, side)
    local t = s.create_entity({ name = LV.name(fam, n), position = c, force = f, raise_built = true })
    local target = s.create_entity({ name = "gun-turret", position = { c.x, c.y + side / 2 + 4 }, force = TARGET })
    if t and target then made = made + 1 end
    if t and fam == GUN then t.insert({ name = AMMO, count = 50 }) end
    st.m[#st.m + 1] = { kind = "turret", family = fam.key, n = n, e = t, target = target, inserted = 0, damage = 0 }
  end
  ctx.check(made == 16, "V3-T4 : 4 fours, 4 assembleurs, 4 foreuses (niveaux 1, 6, 7, 30) et 4 tourelles (1 et 30) poses",
    made .. " / 16")
  -- L'expérience de cadence E56 (mitrailleuses aux délais 2,67 ; 1,5 ; 0,96 ; 0,67 tick : 22,5 puis 30 tirs/s au plus)
  -- a été jouée par la première version de ce greffon (commit f86f2fb, journaux fo-logs\2026-10-22_V3T4\02_...).
end

---------------------------------------------------------------------------------------------------
-- Chaque tick : nourrir, vider, soigner les cibles ; relevés à T0 et T1
---------------------------------------------------------------------------------------------------
local function top_up(inv, name, want)
  local have = inv.get_item_count(name)
  if have < want then inv.insert({ name = name, count = want - have }) end
end

--- Cartouches dans la tourelle : (chargeurs − 1) × taille + cartouches du chargeur entamé.
local function rounds(t)
  local inv = t.get_inventory(defines.inventory.turret_ammo)
  local size = game.item_prototypes[AMMO].magazine_size
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
  local in_window = tick > M.T0 and tick <= M.T1
  for _, m in ipairs(st.m) do
    local e = m.e
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
      elseif m.kind == "turret" then
        local tg = m.target
        if tg and tg.valid then
          local lost = tg.prototype.max_health - tg.health
          if in_window then m.damage = m.damage + lost end
          tg.health = tg.prototype.max_health
        end
        if m.family == "gun" then
          local inv = e.get_inventory(defines.inventory.turret_ammo)
          local have = inv.get_item_count(AMMO)
          if have < 30 then
            local put_n = inv.insert({ name = AMMO, count = 50 - have })
            if in_window then m.inserted = m.inserted + put_n end
          end
        end
      end
      if tick == M.T0 then
        if m.kind == "turret" then
          m.r0 = m.family == "gun" and rounds(e) or 0
        else
          m.p0 = produced(m)
        end
      elseif tick == M.T1 then
        if m.kind == "turret" then
          m.r1 = m.family == "gun" and rounds(e) or 0
        else
          m.p1 = produced(m)
        end
      end
    end
  end
  if tick == M.T0 and ctx.solo then
    st.pol0 = M.pollution()
  elseif tick == M.T1 then
    if ctx.solo then st.pol1 = M.pollution() end
    st.closed = true
  end
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

--- Tirs par seconde mesurés d'une mitrailleuse (cartouches consommées dans la fenêtre).
local function shots_of(m, secs)
  if not (m and m.r0 and m.r1) then return nil end
  return (m.r0 + m.inserted * game.item_prototypes[AMMO].magazine_size - m.r1) / secs
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
  local lz30 = by(st, "laser", 30)
  local lz1 = by(st, "laser", 1)
  local flow_ok = lz30 and lz30.e and lz30.e.valid and lz1 and lz1.e and lz1.e.valid
    and math.abs(lz30.e.electric_input_flow_limit / lz1.e.electric_input_flow_limit
      - want_stat(LZ, "input_flow_limit", 1, 30)) < 1e-3
  if not flow_ok then bad[#bad + 1] = "laser 30 debit d'entree" end
  seen = seen + 1
  ctx.check(#bad == 0, "V3-T4 : prototypes charges = regle de surface (vitesses, degats, cadence inchangee, debit d'entree du laser)",
    #bad > 0 and table.concat(bad, ", ") or string.format("%d valeurs ; four 30 : %.2f ; assembleur 30 : %.2f ; foreuse 30 : %.2f ; mitrailleuse 30 : degats x %.2f, delai %g ticks ; laser 30 : degats x %.2f, %.0f kW",
      seen, P[LV.name(FU, 30)].crafting_speed, P[LV.name(AS, 30)].crafting_speed, P[LV.name(DR, 30)].mining_speed,
      P[LV.name(GUN, 30)].attack_parameters.damage_modifier, P[LV.name(GUN, 30)].attack_parameters.cooldown,
      P[LV.name(LZ, 30)].attack_parameters.damage_modifier, lz30 and lz30.e.valid and lz30.e.electric_input_flow_limit * 60 / 1000 or -1))
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
  -- 3. Mitrailleuse : cadence mesurée (cartouches) INCHANGÉE (10 tirs/s au niveau 1 comme au 30 : le moteur plafonne
  --    la cadence, E56) ; les dégâts par tir portent la règle. Puis DPS mesuré = dégâts × R, par tuile au-dessus du 1.
  local shots1, shots30 = shots_of(by(st, "gun", 1), secs), shots_of(by(st, "gun", 30), secs)
  ctx.check(shots1 and shots30 and shots1 > 0 and math.abs(shots30 / shots1 - 1) <= 0.03,
    "V3-T4 : mitrailleuse 30 (6x6) : cadence mesuree inchangee (les degats par tir portent la regle)",
    string.format("niveau 1 : %.2f tirs/s ; niveau 30 : %.2f tirs/s", shots1 or -1, shots30 or -1))
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
  end
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
