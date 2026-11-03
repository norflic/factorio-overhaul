--[[
  Lot CHARBON3 (Q4, 3/11) : une TOURNÉE PROCHE du QG n'est plus refusée pour les MARQUES D'UNE VAGUE PASSÉE.

  Constat (journal 0.6.43N, partie du guide sur la graine 1618033988, 35 à 52 min) : l'avant-poste de charbon 2 de votre équipe, en
  (11, -26), à 33 tuiles du QG (7, 7), a 26 foreuses sur 26 à sec et 1 802 charbons dans ses coffres ; sa tournée vise (9, -18), à 25
  tuiles du QG. La porte (script/ai3/comportement.lua, M.gate) la refuse en continu, « attend (but) » puis « attend (bloque) », avec
  un danger de 2 500, 1 700, 900, 810, 729, 656 au but, AUCUNE mort de l'heure sur la route. Ces nombres sont exactement :
    - 900 = D.MOBILE_CAP : la case MOBILE du but (unités vues par un regard, attaque subie : shared/ai3/danger.lua add_mobile), plafonnée,
      qui perd 10 % par minute (810, 729, 656, 590) : il faut 4 min sans nouvelle vue pour passer sous le seuil de 600 ;
    - + 800 par MEUTE (menace « pack », fixe à décroissance rapide, posée quand un PNJ recule devant un groupe : 1 700, 2 500).
  Aucune menace permanente (ver, nid, tourelle adverse) ni mort n'y est pour quelque chose : ce sont les marques des vagues de
  déchiqueteurs qui attaquent l'avant-poste (le plus gros pollueur de la base, 26 foreuses à combustible) ou passent devant. Chaque
  nouvelle vue les remet au plafond (toutes les 1,5 à 6 min dans cette partie) : la tournée reste fermée 17 min. Rien ne les efface
  hors du mode survie (D.forget_mobile n'est appelé qu'en survie ; un PNJ à moins de 32 tuiles du QG ne regarde pas). L'exemption de
  COMPAGNONS-ACTIFS (shared/team/actif.lua) ne retire que les MORTS anciennes, l'escalade est interdite vers un but au-dessus du seuil,
  et la règle de famine (shared/team/famine.lua) ne joue qu'en survie et compte une meute comme une menace fixe.
  NB : la ligne citée par la revue, « tache service vers (57, -17) … danger 900 », est la tournée de l'avant-poste de PIERRE 3 (62, -17),
  pas celle du charbon ; le mécanisme est le même.

  Règle (même principe que la PEUR du DC, 29/10 : « la peur c'est bien, mais pour fuir si jamais ils se font attaquer. Mais sinon il
  faut revenir, il faut agir ») : une tournée (V.KINDS) dont le but est à moins de V.NEAR_R tuiles du QG, refusée pour le danger de la
  route ou du but (V.WHY : jamais pour des morts), est REJUGÉE par la même porte (D.gate) SANS les marques de vague vues il y a
  V.QUIET ticks ou plus (cases mobiles et meutes : la vague est passée) ; les menaces permanentes et les marques FRAÎCHES (vague en
  cours) restent comptées. Le PNJ part avec le risque accepté (comme une escalade) et garde ses réflexes (arrêt, demi-tour, fuite).
  PUR : aucune API Factorio, aucun nom d'objet.
]]
local D = require("shared.ai3.danger")
local Ac = require("shared.team.actif")

local V = {}

V.KINDS = { service = true }                       -- tournées d'avant-poste (ravitaillement, collecte)
V.WHY = { but = true, bloque = true, marque = true } -- refus de la porte pour le DANGER (route ou but), jamais pour des morts
V.NEAR_R = 64     -- tuiles : but « dans le rayon du QG défendu » (deux fois M.HOME_SAFE, où un PNJ ne regarde même plus)
V.QUIET = Ac.FEAR_TICKS -- 1 min sans nouvelle vue : la vague est passée (même délai que la peur des morts, arbitrage du 29/10)
V.SKIP = 6        -- tuiles : début de route exclu (le PNJ peut déjà être près d'une marque), comme M.plan

--- La règle s'applique-t-elle à ce refus ? `kind` genre de tâche, `why` raison du refus (D.gate), `hq` et `goal` positions.
function V.applies(kind, why, hq, goal)
  if not (V.KINDS[kind] and V.WHY[why] and hq and goal) then return false end
  local dx, dy = goal.x - hq.x, goal.y - hq.y
  return dx * dx + dy * dy <= V.NEAR_R * V.NEAR_R
end

--- Danger des MENACES en (x, y) (morts de PNJ exclues, comme la porte « au calme »), en deux parts : `kept` (menaces permanentes,
--- marques de vague fraîches) et `stale` (marques de vague vues il y a `quiet` ticks ou plus : meutes, case mobile). Mêmes tests et
--- mêmes poids que D.danger_exact : kept + stale = fixed + mobile de D.exact_parts (tests/vague_test.lua).
function V.split(map, x, y, tick, quiet)
  quiet = quiet or V.QUIET
  local kept, stale = 0, 0
  for _, t in ipairs(map.threats or {}) do
    local K = D.KINDS[t.k] or D.KINDS.unit
    local r = t.r + D.EXACT_MARGIN
    local dx, dy = t.x - x, t.y - y
    if dx * dx + dy * dy <= r * r then
      local w = math.floor(K.w * (K.fast and D.dec10(tick - t.t) or D.dec2(tick - t.t)) / 1000)
      if K.fast and tick - t.t >= quiet then stale = stale + w else kept = kept + w end
    end
  end
  local c = map.cells and map.cells[D.key(D.cell(x), D.cell(y))]
  if c then
    local m = math.floor(c.m * D.dec10(tick - c.t) / 1000)
    if tick - c.t >= quiet then stale = stale + m else kept = kept + m end
  end
  return kept, stale
end

--- Entrée de la porte (D.gate) sans les marques de vague passée : `info` entrée d'origine, `p` position du PNJ, `pts` échantillons de
--- la route (R.samples), `goal` but, `B` seuil. Rend la nouvelle entrée et le nombre de points (route et but) qui portaient une marque
--- de vague passée.
function V.info(info, map, p, pts, goal, tick, B, quiet)
  local mx, n_stale = 0, 0
  local skip2 = V.SKIP * V.SKIP
  for _, q in ipairs(pts or {}) do
    local dx, dy = q.x - p.x, q.y - p.y
    if dx * dx + dy * dy > skip2 then
      local k, s = V.split(map, q.x, q.y, tick, quiet)
      if k > mx then mx = k end
      if s > 0 then n_stale = n_stale + 1 end
    end
  end
  local kg, sg = V.split(map, goal.x, goal.y, tick, quiet)
  if sg > 0 then n_stale = n_stale + 1 end
  return { blocked = (info.blocked and mx >= B) or false, max_d = mx, goal_d = kg, deaths = info.deaths or 0, far = info.far }, n_stale
end

--- Porte rejugée : rend décision, raison (D.gate), nombre de points aux marques passées, entrée rejugée. Sans marque passée : « wait »
--- (rien à rejuger, la décision d'origine tient).
function V.gate(info, map, p, pts, goal, tick, ctx, quiet)
  local i2, ns = V.info(info, map, p, pts, goal, tick, ctx.B, quiet)
  if ns == 0 then return "wait", nil, 0, i2 end
  local d, w = D.gate(i2, ctx)
  return d, w, ns, i2
end

return V
