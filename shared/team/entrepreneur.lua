--[[
  shared/team/entrepreneur.lua — « entrepreneur » (pansement assumé, 14/11) : règle PURE (Lua 5.2, sans API du jeu).

  Toutes les CFG.period ticks (5 min de jeu), pour chaque équipe (factions et équipe du joueur, liste triée) :
    - des plaques produites depuis le dernier relevé (delta > 0),
    - de la place sur un gisement ouvert (couverture < CFG.cover_max ‰, ou non plein) ou un gisement recensé exploitable,
    - aucun chantier entrepreneur en cours pour l'équipe
  => on déclenche une BANDE du plan de champ (format standard : script/team/migration_champ.lua, begin_band) ; si une bande
  est déjà en vol, on la marque entrepreneur au lieu d'en créer une autre.
  Monopole : un projet marqué spec.entrepreneur ne rend jamais ses objets réservés (script/team/build.lua : pile_family).
  Ouvrier dédié : E.pick_worker (choix déterministe, plus petit numéro vivant, l'ouvrier courant gardé s'il vit).
  Craft groupé (entrepreneur-craft-0716) : la bande passe en tête de f.build.order (E.order_front : réserve au coffre avant les autres),
  son but du cerveau (g.ent) est servi en tête du stock virtuel et met tout son manque en kits d'un coup (shared/ai3/cerveau.lua,
  P.want_kit) ; bilan [FO-ENTREPRENEUR-KIT] (E.kit_report) : déclenchement -> kit complet -> bande posée.
  Lecteurs : script/team/migration_champ.lua (Mig.entrepreneur_scan, Mig.entrepreneur_kit), script/team/build.lua (pile_family), tests/entrepreneur_test.lua.
]]

local E = {}

E.CFG = {
  period = 18000,   -- 5 min de jeu
  cover_max = 850,  -- ‰ : au-dessus, le gisement est jugé plein
  log_max = 200,    -- lignes [FO-ENTREPRENEUR] par équipe au plus
  kit_every = 300,  -- entrepreneur-craft-0716 : suivi du kit complet (ticks), journal [FO-ENTREPRENEUR-KIT]
  head_horizon = 18000, -- entrepreneur-craft-0716 : la tête n'est tenue que si le coût en plaques du manque du kit tient dans la PART
  head_share = 0.5,      -- (head_share) du stock de plaques + débit de l'équipe sur head_horizon ticks (5 min) ; sinon tête rendue, monopole gardé.
                         -- Banc 1 : le kit du joueur (1 298 objets) jamais complet en 18 min affamait toute sa base (5 fours en marche contre 29).
  head_hyst = 0.25,      -- hystérésis : la tête tenue n'est rendue qu'au-delà de (1 + head_hyst) x budget (banc 4 : emerald prise, rendue, reprise
                         -- dans la même minute, budget à 1 % près)
  debit_min = 1200,      -- entrepreneur-craft-0716 : plaques par période (5 min) au moins pour déclencher ou attacher une bande (banc 0720 :
                         -- le joueur, 600 à 1 500 plaques par 5 min, reculait de 6 % avec des bandes entrepreneur trop chères pour lui)
  chain_rate = 350,      -- entrepreneur-continu (0.9.1) : au-delà de ce débit (plaques des fours par minute, toutes plaques), la bande suivante
                         -- est demandée dès la fin de la précédente (relance au pas de kit_every), sans attendre le scan de 5 min
  head_avail = 1.0,     -- part de la MATIÈRE du stock virtuel que la tête prend au cerveau (shared/ai3/cerveau.lua). Banc 3 (0.5) : kits lents
                         -- (azure, 70 objets en 12,6 min sous la tête) ; la porte du budget (head_share) suffit à protéger la base.
}

--- Décision du scan. inp = { delta (plaques produites depuis le relevé), room (place sur un gisement : bool), cover (‰ ou nil),
--- busy (chantier entrepreneur en cours : bool), inflight (une bande du champ est déjà en vol : bool) }.
--- Rend action ("declenche" | "attache" | "refus"), cause (texte).
function E.decide(inp)
  if inp.busy then return "refus", "chantier en cours" end
  if not inp.delta or inp.delta <= 0 then return "refus", "aucune plaque produite" end
  -- entrepreneur-craft-0716 : sous un débit minimal (plaques par période, inp.debit_min), l'équipe n'a pas de quoi payer une bande en monopole
  if inp.debit_min and inp.delta < inp.debit_min then return "refus", "debit sous le minimum" end
  local room = inp.room == true
  if inp.cover ~= nil and inp.cover >= E.CFG.cover_max and not inp.recense then room = false end
  if inp.recense then room = true end
  if not room then return "refus", "aucune place sur un gisement" end
  if inp.inflight then return "attache", "bande deja en vol" end
  return "declenche", "bande demandee"
end

--- entrepreneur-continu (0.9.1) : relance immédiate du scan ? inp = { rate (plaques/min au dernier relevé), busy (chantier entrepreneur
--- vivant), waiting (bande demandée pas encore reconnue), since (ticks depuis le dernier scan) }. Vrai seulement au-delà de CFG.chain_rate,
--- sans chantier ni demande en cours, et au moins kit_every ticks après le dernier scan (pas de rafale).
function E.chain(inp)
  if inp.busy or inp.waiting then return false end
  if not inp.rate or inp.rate < E.CFG.chain_rate then return false end
  return (inp.since or 0) >= E.CFG.kit_every
end

--- Monopole : vrai si le projet (spec) est un chantier entrepreneur : jamais suspendu, jamais rendu, en tête de réservation.
function E.monopoly(spec)
  return spec ~= nil and spec.entrepreneur == true
end

--- Ordre de réservation : les projets entrepreneur passent en tête (tri stable sur le numéro sinon).
--- list = { { id, spec } } ; rend une liste neuve triée.
function E.order(list)
  local out = {}
  for i, x in ipairs(list) do out[i] = x end
  table.sort(out, function(a, b)
    local ea, eb = E.monopoly(a.spec), E.monopoly(b.spec)
    if ea ~= eb then return ea end
    return a.id < b.id
  end)
  return out
end

--- Ouvrier dédié. ids : numéros des PNJ de l'équipe (n'importe quel ordre), alive : { [id] = true }, current : ouvrier attaché ou nil.
--- Rend l'ouvrier (courant s'il vit, sinon le plus petit numéro vivant) ou nil.
function E.pick_worker(ids, alive, current)
  if current ~= nil and alive[current] then return current end
  local best
  for _, id in ipairs(ids) do
    if alive[id] and (best == nil or id < best) then best = id end
  end
  return best
end

--- Filtre de tâche : un ouvrier attaché ne prend que les tâches de son projet ; les autres ne prennent pas les tâches réservées.
function E.task_ok(worker_pid, task_pid, task_reserved_pid)
  if worker_pid ~= nil then return task_pid == worker_pid end
  return task_reserved_pid == nil
end

--- Lot de craft groupé : manquants d'un kit { [objet] = besoin } contre stock { [objet] = n } -> liste triée { { name, n } } (lots entiers).
function E.kit_missing(need, stock)
  local names = {}
  for k in pairs(need) do names[#names + 1] = k end
  table.sort(names)
  local out = {}
  for _, k in ipairs(names) do
    local m = need[k] - (stock[k] or 0)
    if m > 0 then out[#out + 1] = { name = k, n = m } end
  end
  return out
end

--- entrepreneur-craft-0716 : bilan du KIT COMPLET d'une bande. need = { [objet] = n } (pièces pas encore bâties, lues sur le plan du
--- projet), stock = { [objet] = n } réservé au projet (p.stock), missing = liste { { objet, n } } (manque remis au cerveau : craft en tête).
--- Rend { kinds, total, have, craft, complete, text } ; text = « objet stock/besoin » trié, borné à max_items objets (défaut 8).
function E.kit_report(need, stock, missing, max_items)
  local names = {}
  for k in pairs(need or {}) do names[#names + 1] = k end
  table.sort(names)
  local total, have, craft = 0, 0, 0
  local parts = {}
  for _, k in ipairs(names) do
    local n = need[k]
    local h = math.min(n, (stock or {})[k] or 0)
    total, have = total + n, have + h
    if #parts < (max_items or 8) then parts[#parts + 1] = string.format("%s %d/%d", k, h, n) end
  end
  if #names > #parts then parts[#parts + 1] = string.format("+%d autre(s)", #names - #parts) end
  for _, m in ipairs(missing or {}) do craft = craft + (m[2] or 0) end
  return { kinds = #names, total = total, have = have, craft = craft, complete = total > 0 and craft == 0,
    text = table.concat(parts, ", ") }
end

--- entrepreneur-craft-0716 : la bande garde-t-elle la TÊTE (servie avant tout autre projet) ? cost = plaques qu'il faut encore pour fabriquer
--- le manque bloquant du kit (sans la garniture), stock = plaques au coffre, debit = plaques produites par CFG.head_horizon ticks.
--- Vrai si cost <= head_share x (stock + debit) : le kit se paie sur la part de l'équipe qui lui revient ; rend aussi le budget.
--- held : la tête est déjà tenue : elle n'est rendue qu'au-delà de (1 + head_hyst) x budget (hystérésis prise / rendu).
function E.head_budget(cost, stock, debit, held)
  local budget = E.CFG.head_share * ((stock or 0) + math.max(0, debit or 0))
  local lim = held and budget * (1 + E.CFG.head_hyst) or budget
  return (cost or 0) <= lim, budget
end

--- entrepreneur-craft-0716 : GARNITURE d'un plan (charges des pièces pas encore bâties : charbon des coffres de combustible posés garnis).
--- Elle ne bloque pas la pose (build.lua : une pièce sans sa charge est posée vide) : hors du kit bloquant. ents = p.ents. Rend { [objet] = n }.
function E.garnish(ents)
  local out = {}
  for _, e in ipairs(ents or {}) do
    if not e.built and e.item and e.charge and e.charge.item then out[e.charge.item] = (out[e.charge.item] or 0) + (e.charge.count or 0) end
  end
  return out
end

--- entrepreneur-craft-0716 : coupe une liste { { objet, n } } en partie BLOQUANTE et GARNITURE (garnish = { [objet] = n }, ordre gardé).
function E.split_garnish(list, garnish)
  local core, gar = {}, {}
  for _, it in ipairs(list or {}) do
    local g = math.min(it[2] or 0, (garnish or {})[it[1]] or 0)
    if g > 0 then gar[#gar + 1] = { it[1], g } end
    if (it[2] or 0) - g > 0 then core[#core + 1] = { it[1], it[2] - g } end
  end
  return core, gar
end

--- entrepreneur-craft-0716 : besoin sans la garniture (need, garnish = { [objet] = n }) -> table neuve.
function E.need_core(need, garnish)
  local out = {}
  for k, n in pairs(need or {}) do
    local m = n - math.min(n, (garnish or {})[k] or 0)
    if m > 0 then out[k] = m end
  end
  return out
end

--- entrepreneur-craft-0716 : ordre de réservation au coffre (f.build.order) : la bande entrepreneur passe devant tout, sauf les projets
--- qui réparent (rouverts : front[id] vrai). order = liste de numéros, pid = la bande, front = { [id] = vrai }. Rend une liste neuve.
function E.order_front(order, pid, front)
  local out, rest, found = {}, {}, false
  for _, id in ipairs(order) do
    if id == pid then found = true
    elseif front and front[id] then out[#out + 1] = id
    else rest[#rest + 1] = id end
  end
  if not found then return order end
  out[#out + 1] = pid
  for _, id in ipairs(rest) do out[#out + 1] = id end
  return out
end

--- SIMULATION LOGIQUE (modèle jouet, PAS une mesure en jeu). Pas d'une minute.
--- par = { minutes, drills0, furn0, drill_rate, furn_rate (plaques/min), band_drills, band_furn, band_cost (fer),
---         reinvest (part de la production réinvestie), build_min (minutes de pose d'une bande),
---         share (sans entrepreneur : part de la réserve qui reste à la bande, le reste est rendu/partagé à chaque minute),
---         slow (sans entrepreneur : facteur de durée de pose, ouvrier partagé et craft au compte-gouttes) }
--- with : vrai = entrepreneur (monopole, ouvrier dédié, craft groupé).
--- Rend une liste { { t, drills, furn, iron_pm } } à chaque minute (t = 0..minutes).
function E.simulate(par, with)
  local D, F, fund = par.drills0, par.furn0, 0
  local building, left = false, 0
  local out = {}
  local function rate() return math.min(D * par.drill_rate, F * par.furn_rate) end
  out[#out + 1] = { t = 0, drills = D, furn = F, iron_pm = rate() }
  for t = 1, par.minutes do
    local prod = rate()
    if with then
      fund = fund + prod * par.reinvest                -- monopole : rien n'est rendu
    else
      fund = fund * par.share + prod * par.reinvest * par.share -- réserve partagée : une part repart aux autres projets
    end
    if not building and fund >= par.band_cost then
      fund = fund - par.band_cost
      building = true
      left = with and par.build_min or math.ceil(par.build_min * par.slow)
    end
    if building then
      left = left - 1
      if left <= 0 then
        building = false
        D, F = D + par.band_drills, F + par.band_furn
      end
    end
    out[#out + 1] = { t = t, drills = D, furn = F, iron_pm = rate() }
  end
  return out
end

return E
