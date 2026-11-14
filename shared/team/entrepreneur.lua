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
  Lecteurs : script/team/migration_champ.lua (Mig.entrepreneur_scan), script/team/build.lua (pile_family), tests/entrepreneur_test.lua.
]]

local E = {}

E.CFG = {
  period = 18000,   -- 5 min de jeu
  cover_max = 850,  -- ‰ : au-dessus, le gisement est jugé plein
  log_max = 200,    -- lignes [FO-ENTREPRENEUR] par équipe au plus
}

--- Décision du scan. inp = { delta (plaques produites depuis le relevé), room (place sur un gisement : bool), cover (‰ ou nil),
--- busy (chantier entrepreneur en cours : bool), inflight (une bande du champ est déjà en vol : bool) }.
--- Rend action ("declenche" | "attache" | "refus"), cause (texte).
function E.decide(inp)
  if inp.busy then return "refus", "chantier en cours" end
  if not inp.delta or inp.delta <= 0 then return "refus", "aucune plaque produite" end
  local room = inp.room == true
  if inp.cover ~= nil and inp.cover >= E.CFG.cover_max and not inp.recense then room = false end
  if inp.recense then room = true end
  if not room then return "refus", "aucune place sur un gisement" end
  if inp.inflight then return "attache", "bande deja en vol" end
  return "declenche", "bande demandee"
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
