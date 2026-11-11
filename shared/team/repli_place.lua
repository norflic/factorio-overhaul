--[[
  Lot TV-REPLI (docs/TODO_VIDEO.md C07 : « placement of stuff as "dumb" as possible. The "smarter" the algorithm gets, the higher the
  likelihood of a really nasty … bug … deep into the run ») : REPLI DE PLACEMENT SIMPLE d'un module que le plan directeur n'a pu poser
  dans aucun lot du treillis (script/team/build.lua, place_module : 8 lots au plus, marge 1 ; le treillis ne peut plus grandir). RÈGLE
  PURE (aucune API du jeu ; tests/repli_place_test.lua) ; la lecture du terrain et la pose sont dans script/team/repli_place.lua.

  LA RÈGLE, la plus petite qui marche :
    1. des FENÊTRES carrées de P.LOT tuiles (la taille d'un lot : le gabarit y tient comme dans un lot), posées sur une grille de pas
       P.LOT (elles ne se recouvrent pas), en anneaux de Chebyshev autour d'un CENTRE (le QG ; pour une foreuse ou une ressource, le
       gisement), de l'anneau 0 à Rp.RINGS ; dans un anneau, ligne par ligne (y puis x) ; au plus Rp.MAX_WINDOWS lues par appel ;
    2. une fenêtre est ÉCARTÉE sans être lue quand elle est SÛRE-contre : un site écarté par la centrale (danger), un lot voisin refusé
       pour un nid ou une force rivale (« nid », « conteste »), un lot de gisement quand le module n'a pas de ressource (la règle L9 :
       on ne pose pas une fabrique sur le minerai), ou une fenêtre déjà refusée depuis moins de Rp.RETRY ticks (mémoire `bad`) ;
    3. dans la première fenêtre où P.fit trouve une place (mêmes tuiles libres que le plan : ni eau, ni falaise, ni bâtiment, ni
       réservation, ni couloir ; même couverture de minerai pour une foreuse), le module est posé : la PREMIÈRE trouvée gagne, pas de
       comparaison entre fenêtres (le plus près du centre, par construction de l'ordre).
  Rien d'autre : pas de score, pas d'optimisation, pas de mémoire au-delà des fenêtres refusées (nombres et chaînes).

  Déterminisme : l'ordre des fenêtres est fixe (anneau, y, x) ; les causes sont triées ; aucun `pairs` dont l'ordre décide.
]]

local P = require("shared.team.plan")
local M = require("shared.team.modules")

local Rp = {}

local floor, max, abs = math.floor, math.max, math.abs

Rp.STEP = P.LOT       -- pas de la grille des fenêtres (= leur côté : aucun recouvrement)
Rp.SIZE = P.LOT       -- côté d'une fenêtre
Rp.RINGS = 3          -- anneaux de Chebyshev autour du centre (0 à 3 : 49 fenêtres au plus)
Rp.MAX_WINDOWS = 12   -- fenêtres LUES (relevé du terrain) par appel
Rp.RETRY = 3600       -- ticks pendant lesquels une fenêtre refusée n'est pas relue
Rp.LOGS = 40          -- lignes [FO-REPLI-PLACE] au plus par équipe
Rp.MARGIN = 1         -- tuiles libres entre l'emprise et le bord de la fenêtre (comme un lot)
Rp.SKIP_REASONS = { nid = true, conteste = true } -- raisons de refus d'un lot qui écartent une fenêtre sans la lire

--- Clé d'une fenêtre (mémoire des refus).
function Rp.key(rect) return rect.x0 .. "," .. rect.y0 end

--- Fenêtres autour du centre (cx, cy), dans l'ordre : anneau 0 à Rp.RINGS, puis y, puis x. La fenêtre 0 est centrée sur (cx, cy).
function Rp.windows(cx, cy)
  local out = {}
  local half = Rp.SIZE / 2
  for r = 0, Rp.RINGS do
    for dy = -r, r do
      for dx = -r, r do
        if max(abs(dx), abs(dy)) == r then
          local x0 = floor(cx + dx * Rp.STEP - half + 0.5)
          local y0 = floor(cy + dy * Rp.STEP - half + 0.5)
          out[#out + 1] = { x0 = x0, y0 = y0, x1 = x0 + Rp.SIZE, y1 = y0 + Rp.SIZE, ring = r }
        end
      end
    end
  end
  return out
end

--- Une fenêtre refusée récemment ? bad = { [clé] = tick } ou nil.
function Rp.recently_bad(bad, rect, tick)
  local t = bad and bad[Rp.key(rect)]
  return t ~= nil and tick - t < Rp.RETRY
end

--- Point 48 : purge des fenêtres refusées dont le délai RETRY est échu (la table ne grossit plus sans fin). Rend le nombre purgé.
function Rp.purge_bad(bad, tick)
  if not bad then return 0 end
  local n = 0
  for k, t in pairs(bad) do
    if tick - t >= Rp.RETRY then bad[k] = nil; n = n + 1 end
  end
  return n
end

--- Raison d'écarter une fenêtre sans la lire, ou nil. lot_info(tx, ty) -> état, raison du lot du treillis qui contient la tuile (nil
--- sur une rue ou hors du treillis) ; avoided(rect) -> vrai si un site écarté (danger) touche la fenêtre ; `res` : le module a une
--- ressource (il peut aller sur un gisement).
function Rp.skip_reason(rect, ctx)
  if ctx.avoided and ctx.avoided(rect) then return "danger" end
  if ctx.lot_info then
    -- le centre et les quatre coins : les lots que la fenêtre recouvre (une fenêtre de la taille d'un lot en touche au plus 4)
    local pts = { { floor((rect.x0 + rect.x1) / 2), floor((rect.y0 + rect.y1) / 2) }, { rect.x0, rect.y0 }, { rect.x1 - 1, rect.y0 },
      { rect.x0, rect.y1 - 1 }, { rect.x1 - 1, rect.y1 - 1 } }
    local gis = false
    for _, pt in ipairs(pts) do
      local st, why = ctx.lot_info(pt[1], pt[2])
      if st == "refuse" and Rp.SKIP_REASONS[why or ""] then return why end
      if st == "gisement" then gis = true end
    end
    if gis and not ctx.res then return "gisement" end
  end
  return nil
end

--- Cherche une place. g : gabarit ; center = { x, y } ; ctx :
---   tick, bad (table de mémoire, MODIFIÉE : fenêtres refusées), res (ressource ou nil), fopts (options de P.fit à passer : toward,
---   head_toward, fan, cover_min…, copiées), read(rect) -> masks, ores (relevé du terrain ; masks.free(tx, ty)), lot_info, avoided.
--- Rend { g, k, ox, oy, inst, cover, masks, fan, axis, pen, d, rect, ring } ou nil, cause (texte), info { tried, skipped, windows, refused }.
function Rp.pick(g, center, ctx)
  local wins = Rp.windows(center.x, center.y)
  Rp.purge_bad(ctx.bad, ctx.tick)
  local info = { tried = 0, skipped = 0, windows = #wins, refused = {} }
  local function count(why) info.refused[why] = (info.refused[why] or 0) + 1 end
  for _, rect in ipairs(wins) do
    if info.tried >= Rp.MAX_WINDOWS then break end
    local why = Rp.skip_reason(rect, ctx)
    if not why and Rp.recently_bad(ctx.bad, rect, ctx.tick) then why = "deja-refusee" end
    if why then
      info.skipped = info.skipped + 1
      count(why)
    else
      info.tried = info.tried + 1
      local masks, ores = ctx.read(rect)
      local fopts = {}
      for k, v in pairs(ctx.fopts or {}) do fopts[k] = v end -- copie de table : l'ordre n'a aucun effet
      fopts.free, fopts.res = masks.free, masks.res
      fopts.margin = Rp.MARGIN
      fopts.toward = fopts.toward or center
      if ctx.res then fopts.ore = ores; fopts.foreign = ores and ores.foreign or nil end
      if ctx.res and g.gen == "drills" then fopts.axis = ores and ores.axis or nil; fopts.out_toward = true end
      local fit, fwhy = P.fit(g, rect, fopts)
      if fit then
        local r = fit.k == 0 and g or M.rotate(g, fit.k)
        local inst = M.instantiate(r, 0, fit.ox, fit.oy)
        return { g = r, k = fit.k, ox = fit.ox, oy = fit.oy, inst = inst, cover = fit.cover, masks = masks, fan = fopts.fan,
          axis = fopts.axis, pen = fit.pen, d = fit.d, rect = rect, ring = rect.ring }, "ok", info
      end
      count(fwhy or "place")
      if ctx.bad then ctx.bad[Rp.key(rect)] = ctx.tick end
    end
  end
  return nil, Rp.cause(info), info
end

--- Cause d'un échec, en une ligne : fenêtres lues et écartées, refus par raison (triés).
function Rp.cause(info)
  local names = {}
  for k in pairs(info.refused) do names[#names + 1] = k end
  table.sort(names)
  local parts = {}
  for _, k in ipairs(names) do parts[#parts + 1] = k .. " " .. info.refused[k] end
  return string.format("%d fenetre(s) lue(s), %d ecartee(s) sur %d : %s", info.tried, info.skipped, info.windows,
    #parts > 0 and table.concat(parts, ", ") or "aucune")
end

return Rp
