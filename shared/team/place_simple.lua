--[[
  Lot TV-PLACE, point C07 (docs/TODO_VIDEO.md l.302 : « placement of stuff as "dumb" as possible. The "smarter" the algorithm gets, the
  higher the likelihood of a really nasty … bug … deep into the run »). Règle PURE, testée hors jeu : tests/place_simple_test.lua.

  Le problème. place_module (script/team/build.lua) classe les lots par distance, n'en essaie que 8, écarte ceux qui ont déjà échoué deux fois
  (`bad`) et pose le gabarit avec une marge d'une tuile et des options (tête vers le gisement, bras en éventail, couverture visée). Quand
  tout cela échoue, le treillis GRANDIT (Build.grow) : de nouveaux lots à relever, des rues à ouvrir, des minutes de plus avant la pose.

  La règle la plus petite qui marche, essayée AVANT de faire grandir le treillis, une fois par projet :
    1. les lots sont pris dans l'ordre de la SPIRALE du treillis (couronne, puis distance au QG, puis j, puis i : l'ordre de
       P.lots_within) : l'emplacement ne dépend que de la grille, jamais d'un classement ni d'un score (la vidéo : « la position est une
       fonction du nombre de méga-tuiles »), donc rien à désynchroniser ;
    2. les états de lots permis par la sorte de module sont CONSERVÉS (une fabrique ne va pas sur un gisement, ni sur un lot en bord de
       gisement ; shared/team/lot_minerai.lua, shared/team/sonde_lot.lua) ;
    3. le compteur d'échecs `bad` n'écarte plus un lot (il ne comptait que les échecs d'un autre gabarit) ; les lots PRIS restent exclus ;
    4. aucune option : marge 0, ni tête, ni éventail, ni couverture (Ps.fit_opts) ;
    5. au plus Ps.MAX_LOTS lots (le relevé d'un lot est le coût ; les masques sont gardés par tick), puis le treillis grandit comme avant.
  Elle ne vaut ni pour la centrale (rive) ni pour les foreuses (gisement) : leurs règles sont les leurs.
  Déterminisme : tri total (couronne, d², j, i, clé), aucun `pairs`.
]]

local Ps = {}

Ps.MAX_LOTS = 6 -- lots essayés au plus par le repli simple
Ps.MARGIN = 0   -- tuiles de marge autour du gabarit (le plan ordinaire en garde 1)

--- Un lot peut-il recevoir un gabarit de ces états ? (mêmes états que le plan ordinaire, sans le compteur d'échecs `bad`)
--- l = { state, reason, used, out, edge } ; states = ensemble d'états (peut porter `no_edge` et `eau`).
function Ps.eligible(l, states)
  if type(l) ~= "table" or type(states) ~= "table" then return false end
  local ok = states[l.state] or (states.eau and l.state == "refuse" and l.reason == "eau")
  if not ok then return false end
  if l.used and l.state ~= "gisement" then return false end -- un lot pris n'est pas offert (un gisement sert plusieurs lignes)
  if l.out and (l.state == "libre" or l.state == "defricher") then return false end -- hors du contour de l'enceinte
  if states.no_edge and l.edge then return false end -- lot en bord de gisement
  return true
end

local function ring(l) return math.max(math.abs(l.i), math.abs(l.j)) end

--- Ordre total de la spirale : couronne, puis distance au QG (carré), puis j, puis i, puis clé.
local function before(a, b)
  local ra, rb = ring(a), ring(b)
  if ra ~= rb then return ra < rb end
  local da, db = a.i * a.i + a.j * a.j, b.i * b.i + b.j * b.j
  if da ~= db then return da < db end
  if a.j ~= b.j then return a.j < b.j end
  if a.i ~= b.i then return a.i < b.i end
  return tostring(a.k) < tostring(b.k)
end

--- Clés des lots du repli simple, dans l'ordre de la spirale, Ps.MAX_LOTS au plus. lots = liste de { k, i, j, state, reason, used, out, edge }.
--- Sélection des `max` premiers par insertion (361 lots au rayon 9, 6 retenus : pas de tri complet).
function Ps.order(lots, states, max)
  max = max or Ps.MAX_LOTS
  local top = {}
  for _, l in ipairs(lots or {}) do
    if Ps.eligible(l, states) and not (l.i == 0 and l.j == 0) then
      local n = #top
      if n < max or before(l, top[n]) then
        local pos = n + 1
        while pos > 1 and before(l, top[pos - 1]) do pos = pos - 1 end
        table.insert(top, pos, l)
        if #top > max then top[#top] = nil end
      end
    end
  end
  local out = {}
  for i, l in ipairs(top) do out[i] = l.k end
  return out
end

--- Options de P.fit (script/team/build.lua, place_module) du repli simple : la marge seule.
function Ps.fit_opts()
  return { margin = Ps.MARGIN, nobad = true }
end

return Ps
