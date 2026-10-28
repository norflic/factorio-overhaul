--[[
  Lot RECON (28/10) : CONNAISSANCE des rivales par une faction. PUR (aucune API Factorio ; testé hors jeu par
  tests/recon_test.lua).

  Réponse du Directeur Créatif : « les factions ne peuvent viser QUE ce qu'elles ont reconnu : elles ne peuvent pas
  viser un avant-poste qui n'a pas été vu, parce qu'elles ne savent pas s'il y a des gens ; peut-être qu'elles ont
  apporté un soldat quand même, si ça peut faire l'exploration ».

  Ce qu'une faction sait d'UNE rivale : k = { hq = { x, y, t } | nil, posts = { { x, y, t }, ... } } (nombres seulement,
  rangé dans global par script/faction/chef.lua : f.chef.seen[id].k). Un point n'y entre que s'il a été VU (yeux du
  chef, carte de connaissance de l'équipe, éclaireur) ; il en sort quand un regard POSTÉRIEUR sur son emplacement ne
  le retrouve pas (détruit, R.prune).

  Statut d'une rivale (R.status) :
    inconnue : rien vu ;
    perimee  : le regard le plus récent date de plus de R.FRESH ticks : la position peut avoir changé, elle doit être
               revérifiée par un éclaireur avant tout assaut ;
    fraiche  : vue il y a R.FRESH ticks ou moins : seule une rivale fraîche peut être ATTAQUÉE.

  Éclaireur soldat (R.want, R.gap, R.size) : la faction envoie un soldat chercher une rivale inconnue, ou revérifier une
  position périmée, quand aucune cible fraîche n'existe. Aucun nom de prototype, aucune trigonométrie, aucun hasard :
  itérations triées, entiers.
]]

local R = {}

R.FRESH = 20 * 3600       -- une rivale vue il y a plus longtemps est « périmée » (entre RELOOK.moving 10 min et SEEN_TTL 30 min)
R.MERGE_DIST = 24         -- deux avant-postes vus à moins de 24 tuiles sont le même (foreuses d'un même chantier)
R.MAX_POSTS = 12          -- avant-postes retenus par rivale ; les plus anciens sont oubliés d'abord
R.GAP = 4 * 3600          -- délai entre deux éclaireurs de reconnaissance (agressivité 1 000) ; ÷ agressivité
R.GAP_MIN = 3600
R.LOSS_CAP = 4            -- doublement du délai à chaque éclaireur perdu (F235), 2^4 au plus
R.SIZE_MAX = 7            -- +2 soldats par perte récente (comme Vision.scout_policy), 7 au plus
R.THREAT_MAX = 300        -- au-delà (pour mille), la garnison reste au QG
R.RESERVE = 4             -- soldats gardés au QG en plus de l'éclaireur

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

function R.new() return { posts = {} } end

--- Un regard a VU un point de la rivale. kind : "hq" ou "post". Un avant-poste à moins de R.MERGE_DIST d'un point
--- déjà connu le rafraîchit (date seulement) ; sinon il est ajouté (R.MAX_POSTS au plus, le plus ancien oublié).
function R.sight(k, kind, x, y, t)
  x, y = math.floor(x), math.floor(y)
  if kind == "hq" then
    if not k.hq or t >= k.hq.t then k.hq = { x = x, y = y, t = t } end
    return
  end
  local p = { x = x, y = y }
  local m2 = R.MERGE_DIST * R.MERGE_DIST
  for _, e in ipairs(k.posts) do
    if d2(e, p) <= m2 then
      if t > e.t then e.t = t end
      return
    end
  end
  k.posts[#k.posts + 1] = { x = x, y = y, t = t }
  if #k.posts > R.MAX_POSTS then
    local worst = 1
    for i = 2, #k.posts do
      local a, b = k.posts[i], k.posts[worst]
      if a.t < b.t or (a.t == b.t and (a.x < b.x or (a.x == b.x and a.y < b.y))) then worst = i end
    end
    table.remove(k.posts, worst)
  end
end

--- Fusion de regards : list = { { kind, x, y, t }, ... } (déjà triée par l'appelant).
function R.merge(k, list)
  for _, s in ipairs(list or {}) do R.sight(k, s.kind, s.x, s.y, s.t) end
end

--- Oubli : retire tout point `e` pour lequel covered(e) est vrai (un regard POSTÉRIEUR à e.t a couvert son emplacement
--- sans le retrouver : détruit). À appeler APRÈS la fusion des regards de ce tour (les points revus ont alors t à jour).
function R.prune(k, covered)
  local n = 0
  if k.hq and covered(k.hq) then k.hq = nil; n = n + 1 end
  local keep = {}
  for _, e in ipairs(k.posts) do
    if covered(e) then n = n + 1 else keep[#keep + 1] = e end
  end
  k.posts = keep
  return n
end

function R.known(k) return k ~= nil and (k.hq ~= nil or #k.posts > 0) end

--- Tick du regard le plus récent (nil : rien vu).
function R.last(k)
  if not k then return nil end
  local t = k.hq and k.hq.t or nil
  for _, e in ipairs(k.posts) do if not t or e.t > t then t = e.t end end
  return t
end

function R.age(k, tick)
  local t = R.last(k)
  return t and (tick - t) or nil
end

--- "inconnue" | "perimee" | "fraiche".
function R.status(k, tick)
  local t = R.last(k)
  if not t then return "inconnue" end
  if tick - t <= R.FRESH then return "fraiche" end
  return "perimee"
end

function R.fresh(k, tick) return R.status(k, tick) == "fraiche" end

--- Points FRAIS : avant-postes (liste) et QG (ou nil).
local function fresh_points(k, tick)
  local posts = {}
  for _, e in ipairs(k.posts) do if tick - e.t <= R.FRESH then posts[#posts + 1] = e end end
  local hq = k.hq and tick - k.hq.t <= R.FRESH and k.hq or nil
  return posts, hq
end

--- Point visé : un avant-poste FRAIS choisi par `point_fn(liste, hq, from)` (shared/faction/chef.lua, C.target_point :
--- périphérie d'abord), sinon le QG frais. nil si rien de frais : on ne vise jamais ce qu'on n'a pas vu.
function R.aim(k, tick, from, point_fn)
  if not k then return nil end
  local posts, hq = fresh_points(k, tick)
  if #posts > 0 then
    local p = point_fn(posts, hq, from)
    if p then return { x = p.x, y = p.y } end
  end
  if hq then return { x = hq.x, y = hq.y } end
  return nil
end

--- Dernier point connu (le plus récemment vu ; égalités : QG, puis x, y), même périmé : destination de la
--- revérification par un éclaireur.
function R.last_point(k)
  if not k then return nil end
  local best
  local function better(e, isq)
    if not best then return true end
    if e.t ~= best.t then return e.t > best.t end
    if isq ~= best.hq then return isq end
    if e.x ~= best.x then return e.x < best.x end
    return e.y < best.y
  end
  if k.hq then best = { x = k.hq.x, y = k.hq.y, t = k.hq.t, hq = true } end
  for _, e in ipairs(k.posts) do
    if better(e, false) then best = { x = e.x, y = e.y, t = e.t, hq = false } end
  end
  return best and { x = best.x, y = best.y } or nil
end

---------------------------------------------------------------------------------------------------
-- Éclaireur soldat
---------------------------------------------------------------------------------------------------
--- Délai avant le prochain éclaireur : R.GAP ÷ agressivité (pour mille, 500 au plus bas), doublé par perte récente.
function R.gap(aggressiveness, losses)
  local g = math.floor(R.GAP * 1000 / math.max(500, aggressiveness or 1000))
  for _ = 1, math.min(losses or 0, R.LOSS_CAP) do g = g * 2 end
  if g < R.GAP_MIN then g = R.GAP_MIN end
  return g
end

--- Taille de l'éclaireur : un soldat, +2 par perte récente (une patrouille qui riposte), R.SIZE_MAX au plus.
function R.size(losses)
  return math.min(1 + 2 * (losses or 0), R.SIZE_MAX)
end

--- Un éclaireur doit-il partir ? c = { recon (demande du chef ou nil), tick, next_at, busy (éclaireur en cours),
--- garrison, size, threat, survive }. Renvoie (oui, raison).
function R.want(c)
  if not c.recon then return false, "rien a chercher" end
  if c.busy then return false, "eclaireur en cours" end
  if c.survive then return false, "survie" end
  if (c.threat or 0) > R.THREAT_MAX then return false, "menace" end
  if c.tick < (c.next_at or 0) then return false, "delai" end
  if (c.garrison or 0) < (c.size or 1) + R.RESERVE then return false, "garnison" end
  return true, "ok"
end

return R
