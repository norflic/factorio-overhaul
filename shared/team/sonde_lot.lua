--[[
  Lot TV-PLACE, point G37 (docs/TODO_VIDEO.md l.214 : « Sonde : 30 × 30 au décalage +2 », source : le gist lit la place AVANT de choisir).
  Règle PURE (aucune API du jeu, aucun nom d'objet), testée hors jeu : tests/sonde_lot_test.lua.

  Lecture du point. Le treillis garde ses lots de 24 × 24 (P.LOT) et son pas de 28 : seule la zone SONDÉE autour d'un lot grandit. Elle
  passe de 24 × 24 à 30 × 30, centrée sur le lot (3 tuiles de chaque côté : la rue de 4 voisine et 1 tuile au-delà ; le « +2 » de la vidéo
  est l'ancrage monde x × 48 + 2 de SON treillis, que le nôtre remplace, G55). Le relevé de CLASSEMENT d'un lot (eau, falaises, bâtiments,
  nids) reste sur les 24 × 24 : un voisin ne doit pas refuser le lot. La sonde large ne lit que le MINERAI.

  Ce qu'elle décide. Un lot qui n'a pas assez de minerai à lui (il n'est donc pas « gisement ») mais dont la sonde de 30 × 30 passe les
  seuils de shared/team/lot_minerai.lua est « en BORD de gisement » : une fabrique qui s'y poserait boucherait l'accès des foreuses au
  gisement voisin (« ne lance jamais une construction au hasard qui viendrait écraser un gisement de minerai précieux sur le chemin de
  croissance », Directeur Créatif). Il reste ouvert à la fonte (qui va au minerai) et à l'extraction ; Sl.allows le refuse aux autres.
  Déterminisme : aucun hasard, aucun `pairs` décisionnel.
]]

local Lm = require("shared.team.lot_minerai")

local Sl = {}

Sl.SIZE = 30 -- côté de la sonde, en tuiles (G37)
Sl.KIND_EDGE_OK = { extraction = true, fonte = true, energie = true } -- sortes admises sur un lot en bord de gisement (l'énergie va sur une rive, jamais sur un lot libre : sans effet)

--- Marge de chaque côté pour passer d'un lot de largeur `w` à la sonde (entier, jamais négatif : un lot déjà plus large que la sonde reste tel quel).
function Sl.margin(w)
  local m = math.floor((Sl.SIZE - (w or 0)) / 2)
  if m < 0 then m = 0 end
  return m
end

--- Rectangle sondé autour d'un lot [x0, x1) × [y0, y1) : x0, y0, x1, y1 (tuiles).
function Sl.rect(x0, y0, x1, y1)
  local mx, my = Sl.margin(x1 - x0), Sl.margin(y1 - y0)
  return x0 - mx, y0 - my, x1 + mx, y1 + my
end

--- Lot en bord de gisement ? `inner` : relevé du lot (res, amount), `wide` : relevé de la sonde de 30 × 30 (res, amount), `seuils` :
--- shared/team/lot_minerai_seuils.lua (nil : défaut de 24 tuiles). Rend (minerai, tuiles dans la sonde, tuiles dans le lot) ou nil quand le
--- lot est lui-même de minerai (c'est alors un « gisement », pas un bord) ou que la sonde ne voit rien qui passe un seuil.
function Sl.edge(inner, wide, seuils)
  if not wide then return nil end
  if Lm.role(inner or {}, seuils) == "minerai" then return nil end
  local role, main = Lm.role(wide, seuils)
  if role ~= "minerai" then return nil end
  local n_wide = (wide.res and wide.res[main]) or 0
  local n_in = (inner and inner.res and inner.res[main]) or 0
  if n_wide <= n_in then return nil end -- rien de plus au-delà du lot : pas un bord
  return main, n_wide, n_in
end

--- Une sorte de module peut-elle aller sur un lot ? `edge` : minerai du bord (nil : lot ordinaire). Sorte inconnue : refus (garde fermée).
function Sl.allows(edge, kind)
  if not Lm.KINDS[kind] then return false, "sorte inconnue (garde fermee)" end
  if edge and not Sl.KIND_EDGE_OK[kind] then
    return false, "lot en bord de gisement reserve a l'extraction et a la fonte"
  end
  return true
end

--- États de lots d'une sorte, copies de Lm.states_for, avec la marque `no_edge` sur chaque ensemble de lots libres quand la sorte n'a pas droit
--- aux lots en bord de gisement (fabrique) : build.lua:candidates écarte alors les lots dont la marque `edge` est posée.
function Sl.states_for(kind)
  local out = Lm.states_for(kind)
  if kind == "fabrique" then
    for _, set in ipairs(out) do
      if set.libre or set.defricher then set.no_edge = true end
    end
  end
  return out
end

return Sl
