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
V.FIRST_TICKS = 18000 -- 5 min au plus (coordinateur, 15/11 : 10 -> 5) : une alimentation de centrale qui attend sa matière réserve AVANT les projets neufs (build.lua Build.alim_first)
V.COOL_TICKS = 7200   -- 2 min : pause de la croissance après un refus du plan quand la demande nominale manque (au lieu de C.COOL, 10 min)

--- Projet EXEMPTÉ de la priorité de matière d'une alimentation de centrale (build.lua Build.alim_first) ? sp = spec du projet, reopened =
--- p.reopened (0 ou nil : neuf), plant = le projet est une centrale de l'équipe, monopoly = chantier entrepreneur (shared/team/entrepreneur.lua
--- E.monopoly). Lot C3-BOUCLE (partie du DC 0.9.4, 15/11) : la bande que l'entrepreneur tient n'était PAS exemptée ; [FO-VAPEUR] « projet 39
--- (alimentation de la centrale 24) attend sa matiere a 25.4 min » puis projet 56 à 38.8 min : la bande 30 (kit 235/236, 1 bras à fabriquer)
--- et la bande 35 (kit complet à 38.9 min) restaient « reserve:vapeur » 5 min chacune, leurs manques effacés (p.missing = {} : le dernier
--- bras jamais fabriqué), seule bande de champ en vol de l'équipe : 10 min sans pose sur 30. Le monopole est « jamais suspendu ».
function V.exempt(sp, reopened, plant, monopoly)
  sp = sp or {}
  if sp.alim or sp.alimquai or sp.raccord or sp.enceinte or sp.liaison or sp.plant or plant then return true end
  if reopened and reopened ~= 0 then return true end
  return monopoly == true
end

--- Lot P2-ENERGIE (pilier 2 du DC, 15/11 : « l'électricité ne doit jamais brider la croissance minière ») : la priorité de matière d'une
--- alimentation de centrale (build.lua Build.alim_first, « reserve:vapeur ») ne vaut que si l'énergie MANQUE : centrale saturée (C.observe),
--- chaudières à sec (Sante.coal_short) ou demande nominale au-delà de la capacité et des chantiers (missing_kw > 0, V.missing_kw). Mesuré
--- (référence INTEG-096-a, carte du DC, graine 123456789) : à 28,7 et 37,8 min, 5 400 puis 7 200 kW de capacité pour 2 254 et 4 780 kW
--- produits, la bande 10 (252 pièces) et la liaison 13 (320) gelées « reserve:vapeur » 5 min chacune pour une alimentation qui n'avait rien
--- d'urgent ; à 20,8 min (chaudières à sec) la priorité reste. Rend vrai si la priorité s'applique.
function V.energy_short(saturated, dry, missing_kw)
  if saturated == true or dry == true then return true end
  return type(missing_kw) == "number" and missing_kw > 0
end

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

-- 6. MATIÈRE LIMITANTE (V.raw_of, V.competes) : le gel de la priorité de l'alimentation ne retient que les projets dont la matière qui leur reste
--    à prendre partage une matière PREMIÈRE (objet sans recette, lu aux recettes) avec ce qui manque encore à l'alimentation (le fer,
--    typiquement) ; un projet qui ne prend que de la pierre ou du bois passe. ingredients(item) rend la liste triée des ingrédients-objets de la
--    recette qui le fabrique (nil : matière première).
V.RAW_DEPTH = 6

--- Ensemble des matières premières de `item` ({ [nom] = true }) ; `memo` (table) garde les réponses.
function V.raw_of(item, ingredients, memo, depth)
  memo = memo or {}
  if memo[item] then return memo[item] end
  depth = depth or 0
  local out = {}
  local ings = (depth < V.RAW_DEPTH) and ingredients(item) or nil
  if not ings or #ings == 0 then
    out[item] = true
  else
    memo[item] = out -- (cycle : vide pendant le calcul)
    for _, ing in ipairs(ings) do
      for k in next, V.raw_of(ing, ingredients, memo, depth + 1) do out[k] = true end
    end
  end
  memo[item] = out
  return out
end

--- Le projet qui veut `want` ({ [objet] = n }) dispute-t-il une matière première à ce qui manque à l'alimentation (`lack` = { { objet, n } }) ?
--- Rend vrai et la matière (première en ordre de nom), ou faux.
function V.competes(want, lack, ingredients, memo)
  local short = {}
  for _, it in ipairs(lack or {}) do
    if (it[2] or 0) > 0 then for k in next, V.raw_of(it[1], ingredients, memo) do short[k] = true end end
  end
  local names = {}
  for k, n in next, want or {} do if (n or 0) > 0 then names[#names + 1] = k end end
  table.sort(names)
  for _, k in ipairs(names) do
    local raws = {}
    for r in next, V.raw_of(k, ingredients, memo) do raws[#raws + 1] = r end
    table.sort(raws)
    for _, r in ipairs(raws) do if short[r] then return true, r end end
  end
  return false
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
