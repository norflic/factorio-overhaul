--[[
  Lot CENTRALE (28/10, réponse du DC : « si l'eau n'est pas utilisable, il faut aller plus loin, évidemment. Si on pouvait
  avoir de l'eau [pompe] pour faire de l'électricité, bien ; sinon il faut avoir une centrale plus loin ») : RÈGLES PURES de
  la centrale à distance d'une équipe (Lua pur, testé hors jeu par tests/lointain_test.lua ; la lecture du moteur et la pose
  sont dans script/team/lointain.lua).

  Quand aucune rive du treillis ne tient le gabarit de la pompe, l'équipe cherche l'eau parmi les secteurs de 64 × 64 où ELLE
  en a vu (carte de connaissance, shared/ai3/carte.lua : K.waters ; sous le brouillard, rien d'omniscient), explore s'il n'y
  en a pas, choisit une rive, y pose la centrale et la relie au treillis par une ligne de poteaux.

  Ici : les rives candidates d'un secteur d'eau, le carrefour du treillis où la ligne s'accroche, le nombre de poteaux, les
  règles d'acceptation d'un couloir et d'un site (sûr ou non), le découpage de la ligne en tronçons de travail.

  Déterminisme : tout est trié (distance à `toward`, puis y, puis x) ; aucune dépendance à l'ordre de `pairs` ; entiers et
  opérations IEEE identiques chez tous les pairs.
]]

local L = {}

-- Constantes nommées (réglages du lot, jamais des noms d'objets du jeu).
L.POLL = 1200            -- ticks entre deux passes d'un plan en attente d'eau (20 s)
L.WINDOW = 24            -- côté du rectangle où le gabarit de la centrale est essayé autour d'une rive (= P.LOT)
L.SHORE_GAP = 6          -- deux rives candidates d'un même secteur sont distantes d'au moins 6 tuiles (Chebyshev)
L.SHORES_MAX = 24        -- rives candidates d'un secteur
L.SHORES_PER_PASS = 4    -- rives essayées au moteur par passe de plan (chacune : un relevé de 40 × 40 tuiles)
L.SECTORS_PER_PASS = 2   -- secteurs d'eau examinés par passe
L.SECTOR_MARGIN = 4      -- tuiles autour d'un secteur d'eau où l'on cherche les rives (le lac peut commencer au bord du secteur)
L.MAX_POLES = 90         -- poteaux de ligne au plus (petit poteau : 90 × 7 tuiles = 630 tuiles) ; au-delà, « trop loin »
L.UNSEEN_PCT = 25        -- part des secteurs d'un couloir jamais vus au-delà de laquelle le couloir est refusé
L.GROUP = 4              -- poteaux de ligne consécutifs d'un tronçon de travail (un PNJ, un point d'appui) : au plus 10,5 tuiles du centre
L.GEN_WAIT_MAX = 6       -- passes d'attente de la génération du terrain d'une rive avant de la sauter

local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } -- N, E, S, O

--- Rives d'un secteur. is_water(tx, ty) -> bool ; area = { x0, y0, x1, y1 } (tuiles, x1 et y1 exclus) ; toward = { x, y }.
--- Une rive est une tuile de TERRE dont la voisine et la suivante, dans une des 4 directions, sont de l'eau, et dont la
--- voisine a une voisine latérale en eau aussi (la pompe demande 2 tuiles d'eau devant elle : une mare d'une tuile ou un
--- filet d'eau n'en est pas une). Rend { { x, y, dir (0 N, 2 E, 4 S, 6 O), d } } triées par distance à `toward`, puis y, puis x,
--- espacées d'au moins L.SHORE_GAP, au plus opts.max (défaut L.SHORES_MAX).
function L.shores(is_water, area, toward, opts)
  opts = opts or {}
  local gap = opts.gap or L.SHORE_GAP
  local max = opts.max or L.SHORES_MAX
  local cands = {}
  for ty = area.y0, area.y1 - 1 do
    for tx = area.x0, area.x1 - 1 do
      if not is_water(tx, ty) then
        for di, d in ipairs(DIRS) do
          local x1, y1 = tx + d[1], ty + d[2]
          if is_water(x1, y1) and is_water(tx + 2 * d[1], ty + 2 * d[2])
            and (is_water(x1 - d[2], y1 + d[1]) or is_water(x1 + d[2], y1 - d[1])) then
            cands[#cands + 1] = { x = tx, y = ty, dir = (di - 1) * 2, d = math.abs(tx + 0.5 - toward.x) + math.abs(ty + 0.5 - toward.y) }
            break
          end
        end
      end
    end
  end
  table.sort(cands, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  local out = {}
  for _, c in ipairs(cands) do
    local near = false
    for _, o in ipairs(out) do
      if math.max(math.abs(o.x - c.x), math.abs(o.y - c.y)) < gap then near = true break end
    end
    if not near then
      out[#out + 1] = c
      if #out >= max then break end
    end
  end
  return out
end

--- Rectangle d'essai du gabarit autour d'une rive : { x0, y0, x1, y1 } (x1, y1 exclus), L.WINDOW de côté, centré sur la tuile.
function L.window(x, y)
  local h = L.WINDOW / 2
  return { x0 = x - h, y0 = y - h, x1 = x + h, y1 = y + h }
end

--- Carrefour du treillis où la ligne s'accroche : le carrefour voulu (i, j) ramené dans le carré [−R, R]² évalué.
function L.clamp_node(R, i, j)
  local function c(v) if v < -R then return -R elseif v > R then return R end return v end
  return c(i), c(j)
end

--- Poteaux d'une ligne de longueur `dist` tuiles pour un poteau de portée `reach` (pas = portée − 0,5, comme
--- P.pole_chain) : plancher théorique.
function L.poles_needed(dist, reach)
  local step = reach - 0.5
  if step <= 0 then return math.huge end
  return math.max(0, math.ceil(dist / step - 1e-9))
end

--- Nombre de poteaux que le tracé glouton peut poser au plus (marge de détour : le double du plancher, plus 8).
function L.chain_max(dist, reach)
  local need = L.poles_needed(dist, reach)
  if need == math.huge then return 64 end
  return need * 2 + 8
end

--- Un couloir (K.line_risk) est-il acceptable ? limits = { skip = seuil de danger d'un secteur (K.DANGER.skip) }.
--- Rend ok, raison : aucun nid ni ver sur le couloir, aucun secteur au danger de « sauter », au plus L.UNSEEN_PCT % des
--- secteurs jamais vus. Une ligne ne traverse donc pas de zone de danger connue (les PNJ qui la posent n'ont pas d'escorte).
function L.corridor_ok(info, limits)
  if (info.nests or 0) > 0 then return false, "nid sur le couloir" end
  if (info.risk or 0) >= ((limits and limits.skip) or 900) then return false, "danger" end
  if (info.unseen or 0) * 100 > L.UNSEEN_PCT * math.max(1, info.samples or 1) then return false, "couloir inconnu" end
  return true
end

--- Un site (K.site_inputs) est-il sûr pour une centrale sans garde ? Aucun nid ni ver à K.NEAR, aucun incident récent, hors
--- territoire ennemi.
function L.site_ok(inputs)
  if (inputs.spawners or 0) + (inputs.worms or 0) > 0 then return false, "nids au site" end
  if (inputs.losses or 0) > 0 then return false, "pertes au site" end
  if inputs.enemy_zone then return false, "territoire rival" end
  return true
end

--- Découpe n poteaux consécutifs en tronçons de `size` (défaut L.GROUP) : { { first, last, mid } } (indices 1..n, mid = poteau
--- médian du tronçon, d'où part le point d'appui). Un tronçon de ≤ size poteaux tient à (size − 1) / 2 pas du médian.
function L.groups(n, size)
  size = size or L.GROUP
  local out = {}
  local i = 1
  while i <= n do
    local last = math.min(n, i + size - 1)
    out[#out + 1] = { first = i, last = last, mid = i + math.floor((last - i) / 2) }
    i = last + 1
  end
  return out
end

--- Faut-il laisser un projet NON électrique passer devant une centrale qui attend de l'eau ? (porte de advance :
--- jusqu'ici aucun projet ne se planifiait avant la centrale, et une centrale à explorer peut attendre des minutes.)
--- wait_water : la centrale attend l'eau ; electric : le projet a besoin du réseau.
function L.passes_plant_gate(wait_water, electric)
  return wait_water == true and electric == false
end

--- Une rive dont le fantôme de pompe est refusé est écartée pour de bon (le secteur la saute) et la centrale se replanifie
--- tout de suite à la rive suivante. `cur` : { [secteur] = rives consommées }, `site` : { key, idx }. Rend le nouveau
--- compteur de la rive consommée.
function L.skip_shore(cur, site)
  cur[site.key] = math.max(cur[site.key] or 0, site.idx)
  return cur[site.key]
end

return L
