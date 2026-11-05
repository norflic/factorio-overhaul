-- Lot DESIGN-MODULES (5/11) : IMAGES des modules des géants en jeu, SUR LA COPIE JETABLE SEULEMENT (tools/autotest/xpm/jetable.py).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 400" --qui DESIGN-MODULES -- 400 xpm-images "<copie>"
-- Demande du lead (5/11) : « le DC doit voir le géant avec ses modules posés et l'effet visible (portée et puissance) en jeu ».
-- De jour, figé à midi. Quatre sites côte à côte, mêmes cibles (3 tourelles sans munition et une cible d'essai, force cible) :
--   A Cairn sans module ; B Cairn avec deux portées III (zone 15 -> 22,5 : anneau violet) ; C Cairn avec deux puissances III (salve x 2 :
--   anneau cramoisi, halo sous le géant) ; D Stylet avec deux portées III, cible seule à 55 tuiles (portée de base 45) : trait de visée.
-- Captures (fo-shots) : les 4 sites juste après leur première salve, puis la fenêtre du Tournesol et du Cairn, grille et modules posés
-- (joueur de la session, player.opened, show_gui).
local C = require("scenarios/xp_commun")

local Y = 6400
local CIBLE = "fo-xpm-cible"
local PU3, PO3 = "fo-xp-module-puissance-3", "fo-xp-module-portee-3"
local SITES = {
  { k = "A", nom = "xpm-cairn-sans-module", geant = "fo-xp-cairn", x = 30000, mods = {}, loin = false },
  { k = "B", nom = "xpm-cairn-2-portee-III", geant = "fo-xp-cairn", x = 30300, mods = { PO3, PO3 }, loin = false },
  { k = "C", nom = "xpm-cairn-2-puissance-III", geant = "fo-xp-cairn", x = 30600, mods = { PU3, PU3 }, loin = false },
  { k = "D", nom = "xpm-stylet-2-portee-III-cible-a-55", geant = "fo-xp-stylet", x = 30900, mods = { PO3, PO3 }, loin = true },
}
local GUI_X = 31300
local T_GUI1, T_GUI2 = 150, 170
local CHECK = 190

local PLAN = {}
local function vue(tick, nom, x, y, zoom) PLAN[#PLAN + 1] = { tick = tick, nom = nom, x = x, y = y, zoom = zoom } end
vue(40, SITES[4].nom, SITES[4].x + 28, Y - 6, 0.28)
vue(72, SITES[1].nom, SITES[1].x + 18, Y - 8, 0.3)
vue(73, SITES[2].nom, SITES[2].x + 18, Y - 8, 0.3)
vue(74, SITES[3].nom, SITES[3].x + 18, Y - 8, 0.3)
vue(76, "xpm-cairn-2-portee-III-proche", SITES[2].x + 30, Y, 0.6)
vue(77, "xpm-cairn-2-puissance-III-proche", SITES[3].x + 30, Y, 0.6)
vue(CHECK + 10, "xpm-fin", SITES[2].x + 18, Y - 8, 0.3)

local function force_site(nom)
  local f = game.forces[nom] or game.create_force(nom)
  local cible = game.forces[C.CIBLE]
  cible.set_cease_fire(f, true)
  f.set_cease_fire(cible, false)
  game.forces.enemy.set_cease_fire(f, true)
  f.set_cease_fire(game.forces.enemy, true)
  remote.call("fo-robots", "set_age", nom, 15)
  return f
end

local function poser(s, nom, pos, f, mods)
  local e = s.create_entity({ name = nom, position = pos, force = f })
  if not e then return nil end
  for _, m in ipairs(mods) do e.grid.put({ name = m }) end
  script.raise_script_built({ entity = e })
  return e
end

local function shot_gui(path, player, position, zoom)
  game.take_screenshot({ path = "fo-shots/" .. path, resolution = { 1600, 900 }, force_render = true, allow_in_replay = true,
    anti_alias = false, player = player, by_player = player, position = position, zoom = zoom, show_gui = true, show_entity_info = false })
end

return {
  description = "DESIGN-MODULES : images des modules des geants (sites A a D, fenetre de la grille)",
  check_tick = CHECK,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    if not (game.entity_prototypes["fo-xp-cairn"] and game.entity_prototypes["fo-xp-cairn"].grid_prototype and game.entity_prototypes[CIBLE]) then
      ctx.fail("modules des geants absents (copie jetable seulement : tools/autotest/xpm/jetable.py)")
      return
    end
    st.pret = true
    C.forces()
    local s = ctx.surface()
    s.freeze_daytime = true
    s.daytime = 0
    ctx.prepare_area(SITES[1].x - 100, Y - 120, GUI_X + 100, Y + 80, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { SITES[1].x - 250, Y - 250 }, { GUI_X + 250, Y + 200 } } })) do en.destroy() end
    local noms = {}
    for _, si in ipairs(SITES) do noms[#noms + 1] = "fo-xpm-i" .. si.k end
    for _, nm in ipairs(noms) do force_site(nm) end
    for _, a in ipairs(noms) do
      for _, b in ipairs(noms) do if a ~= b then game.forces[a].set_friend(game.forces[b], true) end end
    end
    st.g = {}
    for _, si in ipairs(SITES) do
      local f = "fo-xpm-i" .. si.k
      st.g[si.k] = poser(s, si.geant, { si.x, Y }, f, si.mods)
      if si.loin then
        s.create_entity({ name = CIBLE, position = { si.x + 55, Y }, force = C.CIBLE })
      else
        s.create_entity({ name = CIBLE, position = { si.x + 30, Y }, force = C.CIBLE })
        for k = -1, 1 do
          s.create_entity({ name = "gun-turret", position = { si.x + 30 + k * 6, Y + 8 }, force = C.CIBLE })
          s.create_entity({ name = "gun-turret", position = { si.x + 38, Y + k * 8 }, force = C.CIBLE })
        end
        s.create_entity({ name = "gun-turret", position = { si.x + 30, Y + 19 }, force = C.CIBLE }) -- à 19 tuiles : seulement dans la zone agrandie
      end
      ctx.check(st.g[si.k] and st.g[si.k].valid and #st.g[si.k].grid.equipment == #si.mods, "site " .. si.k .. " pose avec " .. #si.mods .. " module(s)")
    end
    -- fenêtres : un Tournesol garni (4 emplacements) et un Cairn, de la force du joueur
    remote.call("fo-robots", "set_age", "player", 15)
    st.tour = poser(s, "fo-xp-tournesol", { GUI_X, Y }, "player", { PU3, PU3, PO3, PO3 })
    st.cairn = poser(s, "fo-xp-cairn", { GUI_X + 60, Y }, "player", { PU3, PO3 })
    ctx.check(st.tour and st.tour.valid and #st.tour.grid.equipment == 4, "Tournesol du joueur garni de 4 modules")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local p = game.players[1]
    if not p then return end
    if e.tick == T_GUI1 - 5 then
      p.teleport({ GUI_X + 8, Y + 6 })
      p.opened = st.tour
    elseif e.tick == T_GUI1 then
      ctx.check(p.opened == st.tour, "fenetre du Tournesol ouverte (grille)", p.opened and p.opened.name or "rien")
      shot_gui("x-xpm-fenetre-tournesol.png", p, { GUI_X, Y - 10 }, 0.5)
    elseif e.tick == T_GUI2 - 5 then
      p.teleport({ GUI_X + 68, Y + 6 })
      p.opened = st.cairn
    elseif e.tick == T_GUI2 then
      ctx.check(p.opened == st.cairn, "fenetre du Cairn ouverte (grille)", p.opened and p.opened.name or "rien")
      shot_gui("x-xpm-fenetre-cairn.png", p, { GUI_X + 60, Y - 10 }, 0.5)
    end
  end,

  finish = function(ctx) end,

  shots = function(ctx, add)
    for i, v in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(v.nom, v.x, v.y, v.zoom, 0, { res = { 1800, 1100 }, cadence = suivant and math.max(1, suivant.tick - v.tick) or nil, aa = true })
    end
  end,
}
