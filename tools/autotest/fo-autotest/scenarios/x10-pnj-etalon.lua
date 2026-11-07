--[[
  Lot X10-CHEMINS, étalonnage E-CH2 (fo-logs/2026-11-07_X10/CHEMINS_CRITERES.md §4) : ce que coûte au MOTEUR un personnage
  « fo-companion » (corps des PNJ), PAR ÉTAT. Sur la sauvegarde du DC, figer les 58 PNJ retire 0,26 ms d'entityUpdate et 0,047 ms de
  particleUpdate (M1) : quel état coûte quoi ? Mod de test seulement : N personnages posés et pilotés par le scénario, aucun PNJ du mod.

  Zone préparée (carte de banc) : une moitié NUE et une moitié DENSE (rangées de coffres en fer, couloirs de 2 tuiles).
  Phases de PHASE_T ticks, dans l'ordre :
    fige          active = false (destructible = false) ;
    debout        actifs, immobiles ;
    marche-nu     marche est-ouest dans la moitié nue (sens changé toutes les FLIP ticks) ;
    marche-dense  la même marche dans les couloirs de la moitié dense ;
    minage        minage d'une tuile de minerai de fer posée sous chacun ;
    tir           shooting_state « shooting_enemies » posé, pistolet et chargeurs, aucune cible ;
    fabrication   file de fabrication (roues dentées) ;
    fige2         active = false de nouveau (dérive de la série) ;
    aucun         personnages retirés (base du calcul).
  Une ligne « PHASE <rang>:<nom> debut T0 fin T1 persos N » par phase : tools/autotest/x10_chemins_etalon.py --persos en tire des
  µs d'entityUpdate et de particleUpdate par personnage et par état (phase moins « aucun », divisé par N). Mesure de TEMPS : --seul
  seulement, avec l'accord du lead.
    py -3.9 -B tools/autotest/banc.py --seul --qui X10-CHEMINS --out "<racine>\fo-logs\2026-11-07_X10\E-CH2-<n>"
       -- 2800 x10-pnj-etalon <source>
]]

local BODY = "fo-companion"
local N = 60
local X0, Y0 = -600, 600          -- coin de la zone (loin du départ de la carte)
local W, H = 96, 64               -- moitié nue : y de Y0 à Y0 + 31 ; moitié dense : y de Y0 + 32 à Y0 + 63
local SETUP_END = 120
local PHASE_T, FLIP = 290, 48
local PHASES = { "fige", "debout", "marche-nu", "marche-dense", "minage", "tir", "fabrication", "fige2", "aucun" }
local CHECK = 2780

local function G() global.x10p = global.x10p or { ids = {} } return global.x10p end

local S = {
  description = "X10-CHEMINS E-CH2 : cout d'un personnage fo-companion par etat (entityUpdate, particleUpdate)",
  check_tick = CHECK,
}

local function chars()
  local out = {}
  local s = game.surfaces[1]
  for _, e in ipairs(s.find_entities_filtered({ area = { { X0, Y0 }, { X0 + W, Y0 + H } }, name = BODY })) do out[#out + 1] = e end
  table.sort(out, function(a, b) return a.unit_number < b.unit_number end)
  return out
end

local function open_spot(k) -- moitié nue : 6 rangées de 10, espacées de 4 tuiles
  return { x = X0 + 20 + (k % 10) * 6 + 0.5, y = Y0 + 4 + math.floor(k / 10) * 4 + 0.5 }
end

local function dense_spot(k) -- couloir r (0 à 9), 6 personnages par couloir
  local r, c = math.floor(k / 6), k % 6
  return { x = X0 + 20 + c * 10 + 0.5, y = Y0 + 32 + 3 * r + 1.5 }
end

S.init = function(ctx)
  local s = ctx.surface()
  ctx.prepare_area(X0, Y0, X0 + W, Y0 + H, "grass-1")
  -- Moitié dense : rangées de coffres en fer à y = Y0 + 32 + 3 r (r = 0 à 10), de X0 + 10 à X0 + 90 ; couloirs entre elles.
  local chests = 0
  for r = 0, 10 do
    for x = X0 + 10, X0 + 89 do
      if s.create_entity({ name = "iron-chest", position = { x + 0.5, Y0 + 32 + 3 * r + 0.5 }, force = "neutral" }) then chests = chests + 1 end
    end
  end
  local made = 0
  for k = 0, N - 1 do
    local p = open_spot(k)
    local e = s.create_entity({ name = BODY, position = p, force = "player" })
    if e then
      made = made + 1
      e.destructible = false
    end
  end
  ctx.check(made == N and chests > 800, "personnages et coffres poses", string.format("%d personnages, %d coffres", made, chests))
  local g = G()
  g.i, g.t0 = 1, SETUP_END
  g.ready = true
end

local function set_walk(list, dir)
  local d = dir and defines.direction.east or defines.direction.west
  for _, e in ipairs(list) do
    if e.valid then e.walking_state = { walking = true, direction = d } end
  end
end

local function enter(name, list, s)
  for k, e in ipairs(list) do
    if e.valid then
      e.walking_state = { walking = false, direction = defines.direction.east }
      e.shooting_state = { state = defines.shooting.not_shooting, position = e.position }
      e.mining_state = { mining = false }
      if name == "fige" or name == "fige2" then
        e.active = false
      else
        e.active = true
      end
      if name == "marche-dense" then e.teleport(dense_spot(k - 1)) end
      if name == "marche-nu" or name == "minage" or name == "tir" or name == "fabrication" or name == "debout" then e.teleport(open_spot(k - 1)) end
      if name == "minage" then
        local p = e.position
        local tp = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
        s.create_entity({ name = "iron-ore", position = tp, amount = 100000 })
        e.update_selected_entity(tp)
        e.mining_state = { mining = true, position = tp }
      elseif name == "tir" then
        e.insert({ name = "pistol", count = 1 })
        e.insert({ name = "firearm-magazine", count = 10 })
        e.shooting_state = { state = defines.shooting.shooting_enemies, position = { x = e.position.x + 6, y = e.position.y } }
      elseif name == "fabrication" then
        e.insert({ name = "iron-plate", count = 400 })
        pcall(function() e.begin_crafting({ count = 100, recipe = "iron-gear-wheel" }) end)
      end
    end
  end
  if name == "marche-nu" or name == "marche-dense" then set_walk(list, true) end
  if name == "aucun" then
    for _, e in ipairs(list) do if e.valid then e.destroy() end end
  end
end

S.tick = function(ctx, e)
  local g = G()
  if not g.ready or g.done then return end
  local t = e.tick
  if t < g.t0 then return end
  local name = PHASES[g.i]
  if t == g.t0 then
    local list = chars()
    g.n = #list
    enter(name, list, ctx.surface())
    g.mined0 = 0
  end
  local rel = t - g.t0
  if (name == "marche-nu" or name == "marche-dense") and rel > 0 and rel % FLIP == 0 then
    set_walk(chars(), (rel / FLIP) % 2 == 0)
  end
  if name == "minage" and rel % 30 == 15 then
    for _, c in ipairs(chars()) do
      if c.valid then
        local p = c.position
        local tp = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
        c.update_selected_entity(tp)
        c.mining_state = { mining = true, position = tp }
      end
    end
  end
  if rel == PHASE_T - 1 then
    local list = chars()
    local active, crafting, ore = 0, 0, 0
    for _, c in ipairs(list) do
      if c.active then active = active + 1 end
      if c.crafting_queue_size > 0 then crafting = crafting + 1 end
      ore = ore + c.get_item_count("iron-ore")
    end
    ctx.log(string.format("PHASE %d:%s debut %d fin %d persos %d actifs %d en-fabrication %d minerai %d", g.i, name, g.t0, t, g.n or 0,
      active, crafting, ore))
    g.i = g.i + 1
    g.t0 = t + 1
    if g.i > #PHASES then g.done = true end
  end
end

S.finish = function(ctx)
  local g = G()
  ctx.check(g.done == true, "toutes les phases jouees avant la fin", tostring(g.i))
end

return S
