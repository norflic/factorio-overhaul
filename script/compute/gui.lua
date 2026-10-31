--[[
  Lot CALCUL-V2 (30/10) : le panneau du centre de calcul (gui.relative, à droite de l'interface du centre, ancré aux
  seuls centres). La v1 n'avait aucune interface : le DC ne voyait pas son calcul en jeu.
  Montre la dernière fenêtre de mesure (script/compute/compute.lua) : calcul, puissance et satisfaction, chaleur contre
  refroidissement, baies posées, facteur limitant, calcul et bonus de recherche de la force.
  Aucun état de jeu : l'interface se refait depuis Storage à chaque fenêtre (60 ticks) pour les joueurs qui ont un centre
  ouvert ; joueurs dans l'ordre du moteur (game.connected_players).
]]

local Gui = {}

local NAME = "fo_calcul_panel"
local CENTERS = { "fo-data-center", "fo-data-center-2" }
local IS_CENTER = { ["fo-data-center"] = true, ["fo-data-center-2"] = true }

local function fmt(x, d) return string.format("%." .. (d or 0) .. "f", x or 0) end

local function panel(player)
  local root = player.gui.relative
  local f = root[NAME]
  if f and f.valid then return f end
  f = root.add({ type = "frame", name = NAME, direction = "vertical", caption = { "fo-calcul.titre" },
    anchor = { gui = defines.relative_gui_type.assembling_machine_gui, position = defines.relative_gui_position.right,
               names = CENTERS } })
  for _, key in ipairs({ "calcul", "puissance", "chaleur", "baies", "limite", "force" }) do
    local l = f.add({ type = "label", name = key })
    l.style.single_line = false
    l.style.maximal_width = 260
  end
  return f
end

local function fill(player, Compute, ent)
  local f = panel(player)
  local ev = Compute.center(ent)
  local st = Compute.state(ent.force.name)
  if not ev then
    f.calcul.caption = { "fo-calcul.calcul", "…" }
    return
  end
  local c = ev.counts or {}
  f.calcul.caption = { "fo-calcul.calcul", fmt(ev.compute, 1) }
  f.puissance.caption = { "fo-calcul.puissance", fmt(ev.kw / 1000, 2), fmt((ev.e or 0) * 100) }
  f.chaleur.caption = { "fo-calcul.chaleur", fmt(ev.heat), fmt(ev.cooling) }
  f.baies.caption = { "fo-calcul.baies", tostring(c.cpu or 0), tostring(c.gpu or 0), tostring(c.quantum or 0),
                      tostring(c.memory or 0), tostring(c.storage or 0), tostring(c.network or 0), tostring(c.cooling or 0) }
  f.limite.caption = { "fo-calcul.limite", { "fo-calcul.limite-" .. (ev.limit or "none") } }
  f.force.caption = { "fo-calcul.force", fmt(st.rate, 1), fmt(st.bonus * 100) }
end

--- Panneau d'un joueur qui ouvre un centre.
function Gui.show(player, Compute, ent)
  if not (player and player.valid and ent and ent.valid) then return end
  fill(player, Compute, ent)
end

--- Rafraîchit le panneau des joueurs connectés qui ont un centre ouvert.
function Gui.refresh_all(Compute)
  for _, player in ipairs(game.connected_players) do
    local ent = player.opened
    if ent and player.opened_gui_type == defines.gui_type.entity and ent.valid and IS_CENTER[ent.name] then
      fill(player, Compute, ent)
    end
  end
end

return Gui
