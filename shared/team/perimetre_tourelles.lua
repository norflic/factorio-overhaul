--[[
  Lot CC-TOURELLES (F489, règle du DC, 10/11/2026) : les tourelles d'un avant-poste se posent sur le PÉRIMÈTRE EXTÉRIEUR du gisement,
  jamais sur le minerai. PUR : aucune API Factorio, aucun nom d'objet ; l'appelant (script/faction/outposts.lua) passe `ore(x, y)`, qui dit
  si l'emprise d'une tourelle en (x, y) recouvre du minerai. Testé hors jeu (tests/perimetre_tourelles_test.lua).

  Avant : les huit emplacements fixes à 7 à 9 tuiles du centre de l'avant-poste (TURRET_OFFSETS) tombaient en plein gisement ; la partie
  du DC (0.6.87, graine 3592985581) montrait des tourelles posées partout sur le charbon et le fer, entre les foreuses.

  Règle (Pm.sites) : chaque emplacement d'avant donne un RAYON depuis le centre, dans sa direction (signe de ses deux décalages) ; on
  avance par pas de `step` tuiles depuis l'emplacement d'avant, jusqu'à `reach` tuiles au plus (distance de Tchebychev) ; le premier point
  hors minerai est l'emplacement du rayon. Un rayon sans bord à portée ne donne rien. Ordre des emplacements d'avant gardé, aucun `pairs`,
  aucun hasard. Rend (emplacements, rayons sans bord).
]]

local Pm = {}

local function sign(v)
  if v > 0 then return 1 elseif v < 0 then return -1 end
  return 0
end

--- offsets : { {dx, dy}, ... } (emplacements d'avant, relatifs au centre) ; cx, cy : centre ; ore(x, y) -> vrai si l'emprise touche du
--- minerai ; step >= 1 ; reach : distance de Tchebychev maximale au centre.
function Pm.sites(offsets, cx, cy, ore, step, reach)
  local out, lost = {}, 0
  step = math.max(1, math.floor(step or 2))
  reach = reach or 0
  for _, o in ipairs(offsets or {}) do
    local sx, sy = sign(o[1]), sign(o[2])
    local found = nil
    local k = 0
    while true do
      local dx, dy = o[1] + sx * k * step, o[2] + sy * k * step
      if math.max(math.abs(dx), math.abs(dy)) > reach then break end
      local x, y = cx + dx, cy + dy
      if not ore(x, y) then found = { x = x, y = y } break end
      if sx == 0 and sy == 0 then break end
      k = k + 1
    end
    if found then out[#out + 1] = found else lost = lost + 1 end
  end
  return out, lost
end

return Pm
