--[[
  Lot VAPEUR (14/11, P0 énergie ; constat du DC : « les chaudières et machines à vapeur de son équipe ne sont pas reliées au charbon »).
  PUR : aucune API Factorio, aucun nom d'objet (les puissances viennent des prototypes, lus par script/team/vapeur.lua). Testé hors jeu
  par tests/vapeur_test.lua.

  1. DEMANDE NOMINALE (V.demand_kw) : somme, sur les entités électriques POSÉES par la force, de leur puissance maximale (consommation
     maximale + ponction à vide, lues aux prototypes) : ce que la base tirerait si tout tournait. Ce n'est pas la mesure (une base à
     l'arrêt faute de courant ne « demande » rien à la mesure : c'est le piège d'une croissance pilotée par la production mesurée).
  2. CAPACITÉ NOMINALE (V.capacity_kw) : le plus petit de la puissance des machines à vapeur et de celle des chaudières (une machine
     sans chaudière, ou l'inverse, ne produit rien).
  3. EXTENSION (V.missing_kw) : la centrale s'étend dès que la demande nominale × V.MARGIN dépasse la capacité nominale bâtie + celle des
     chantiers de centrale ouverts, AVANT toute baisse de tension (exigence du DC : demande nominale + 30 %). Rend les kW manquants (> 0)
     ou 0.
  4. ALIMENTATION (V.fed_share) : part des chaudières qui ont du combustible ; une centrale « automatisée » reçoit son charbon par un tapis
     depuis des foreuses (projet d'alimentation, script/team/build.lua plan_alim).
]]
local V = {}

V.MARGIN = 1.3      -- marge de la demande nominale (DC : + 30 %)
V.EVERY = 3600      -- ticks entre deux relevés [FO-VAPEUR] (1 min)
V.LOGS = 90         -- lignes [FO-VAPEUR] au plus par équipe (90 min de partie)

local function pos(x) return (type(x) == "number" and x == x and x > 0 and x < math.huge) and x or 0 end

--- Demande nominale (kW) : rows = { { count = n, kw = puissance max d'une entité } }. Ordre sans effet (somme).
function V.demand_kw(rows)
  local kw = 0
  for _, r in ipairs(rows or {}) do kw = kw + pos(r.count) * pos(r.kw) end
  return kw
end

--- Capacité nominale (kW) : gen_kw = machines à vapeur, boiler_kw = chaudières (nil : inconnue, la capacité des machines seule).
function V.capacity_kw(gen_kw, boiler_kw)
  gen_kw = pos(gen_kw)
  if boiler_kw == nil then return gen_kw end
  return math.min(gen_kw, pos(boiler_kw))
end

--- kW manquants (0 si la capacité suffit) : demande × V.MARGIN − (capacité bâtie + chantiers ouverts).
function V.missing_kw(demand_kw, cap_kw, pending_kw)
  local need = pos(demand_kw) * V.MARGIN
  local have = pos(cap_kw) + pos(pending_kw)
  if need <= have then return 0 end
  return need - have
end

--- Part (0 à 1) des chaudières alimentées ; nil sans chaudière.
function V.fed_share(fed, total)
  if not total or total <= 0 then return nil end
  return math.min(1, pos(fed) / total)
end

-- 5. LOTS ÉCARTÉS (V.skip_lots, V.mark_skip) : un lot de charbon dont le TAPIS jusqu'à la centrale a échoué (« aucun chemin », « trop long »,
--    « trop loin », tapis impur) est écarté V.SKIP_TICKS pour les projets d'alimentation de l'équipe : le prochain essai prend le lot de
--    charbon suivant au lieu de retomber sur le même (partie du DC : « trop long » ×5 sur la même centrale d'emerald, à la main 60 min).
V.SKIP_TICKS = 54000 -- 15 min
V.SKIP_MAX = 16      -- lots écartés gardés au plus (les plus anciens sortent)

--- Liste `cands` (éléments { k = clé du lot, ... }) sans les lots écartés encore valides à `tick` ; ordre gardé.
function V.skip_lots(cands, skip, tick)
  if not skip then return cands end
  local out = {}
  for _, c in ipairs(cands or {}) do
    local u = skip[c.k]
    if not (u and u > (tick or 0)) then out[#out + 1] = c end
  end
  return out
end

--- Écarte le lot `k` jusqu'à tick + V.SKIP_TICKS ; purge les échus, garde au plus V.SKIP_MAX lots (clés triées : déterministe).
function V.mark_skip(skip, k, tick)
  if k == nil then return skip end
  skip = skip or {}
  skip[k] = (tick or 0) + V.SKIP_TICKS
  local keys = {}
  for key, u in pairs(skip) do
    if u <= (tick or 0) then skip[key] = nil else keys[#keys + 1] = key end
  end
  table.sort(keys, function(a, b)
    if skip[a] ~= skip[b] then return skip[a] < skip[b] end
    return tostring(a) < tostring(b)
  end)
  for i = 1, #keys - V.SKIP_MAX do skip[keys[i]] = nil end
  return skip
end

--- Ligne de journal [FO-VAPEUR]. ev = { team, tick, demand, cap, pending, missing, fed, boilers, auto, plants, sat, hand }.
function V.line(ev)
  return string.format("[FO-VAPEUR] %s : a %.1f min : demande nominale %.0f kW (x%.1f = %.0f), capacite %.0f kW (+%.0f en chantier)%s ; chaudieres alimentees %d/%d, centrales nourries par foreuses %d/%d%s ; charge (production / capacite des centrales) %s",
    tostring(ev.team or "player"), (ev.tick or 0) / 3600, pos(ev.demand), V.MARGIN, pos(ev.demand) * V.MARGIN, pos(ev.cap), pos(ev.pending),
    pos(ev.missing) > 0 and string.format(", manque %.0f kW : EXTENSION", ev.missing) or ", suffisante",
    ev.fed or 0, ev.boilers or 0, ev.auto or 0, ev.plants or 0,
    (ev.hand and ev.hand ~= "") and (" ; a la main : " .. ev.hand) or "",
    ev.sat and string.format("%.0f %%", ev.sat * 100) or "?")
end

return V
