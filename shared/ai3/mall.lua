--[[
  Lot PILE-MALL (retour du DC du 31/10, point 8 : « 6 838 fabrications à la main », aucun mall, aucun stock d'avance). Un MALL est un
  module qui fabrique EN CONTINU les objets de construction répétitifs (tapis, bras, poteaux, foreuses, fours, tourelles,
  munitions) dans des assembleurs, sorties en coffre où les PNJ se servent ; la fabrication à la main ne reste que pour
  l'AMORÇAGE (tant que le module ne tourne pas).

  PUR (aucune API Factorio, AUCUN nom d'objet ni de bâtiment : les objets viennent de la demande mesurée). Testé hors jeu :
  tests/mall_test.lua.

  Quels objets ? Ceux que la main a dû fabriquer SOUVENT (Ml.note : chaque fois que la demande de fabrication d'un objet passe de
  0 à plus de 0 compte un épisode, l'augmentation entre dans le volume ; fenêtre glissante par moitié toutes les Ml.WINDOW_TICKS
  ticks de jeu, jamais par un temps mesuré) : au moins Ml.MIN_EPISODES épisodes, une recette connue du livre, au plus Ml.MAX_ITEMS objets
  (les plus demandés d'abord, clé en cas d'égalité).
  Combien d'usines par objet ? Ml.machines : le débit demandé (volume / fenêtre) × Ml.LEAD ÷ le débit d'une machine, arrondi au-dessus,
  de 1 à Ml.MACHINES_MAX (« plusieurs usines par objet selon la demande », au lieu d'une seule x1).
  Combien d'avance ? Ml.target : Ml.HORIZON_MIN minutes de demande au coffre de sortie, que la BARRE du coffre borne (shared/ai3/
  industrie.lua, Id.barre ; F95 : la barre limite aussi `insert`) : la machine s'arrête seule quand le coffre est plein, aucun script par tick.
  La main : Ml.hand_allowed refuse la fabrication à la main d'un objet dont le mall TOURNE (st.running, Ml.set_running), sauf au stock nul.
  Chaîne complète : Ml.note (cerveau) -> Ml.decide -> Ml.sinks (puits de la capitalisation, script/ai3/capitalisation.lua) -> ordre « chaîne »
  -> plan directeur -> machines -> Ml.set_running -> Ml.filter_crafts (cerveau).
  Lot INDUSTRIE I6 : le mall ne se limite plus à ce que la main fabrique. Ml.want note la demande d'une autre source (refus « manque sous
  une demi-machine » de la capitalisation, ingrédient d'un dépliage) ; Ml.sources rend la demande entière (main + autres) à la règle du
  choix (shared/ai3/industrie.lua), qui décide du patron (rangée ou bloc partagé) et du nombre de copies selon le besoin. Le gabarit
  d'une rangée de coffres (Ml.layout) et l'hystérésis du coffre (Ml.refill, un script par pensée) sont RETIRÉS : le gabarit est celui du
  lot I5 (shared/team/patrons.lua) et la réserve est le coffre de sortie.
  Déterminisme : listes triées par (volume décroissant, clé), entiers, aucun pairs décisionnel.
]]

local Ml = {}

Ml.MIN_EPISODES = 3        -- demandes distinctes de fabrication à la main avant de dédier un assembleur
Ml.MAX_ITEMS = 40          -- objets suivis (8 avant le lot INDUSTRIE I6 : la demande décide, pas un plafond écrit)
Ml.MACHINES_MAX = 64       -- assembleurs par objet (4 avant I6) ; au-delà d'un module, l'objet est servi par plusieurs modules
Ml.LEAD = 2                -- capacité = 2 fois le débit demandé (même règle que Ca.LEAD)
Ml.HORIZON_MIN = 10        -- minutes de demande gardées au coffre de sortie (la barre du coffre : Id.barre)
Ml.WINDOW_TICKS = 10 * 3600 -- la mémoire de la demande est divisée par deux toutes les 10 minutes de jeu
Ml.WINDOW_MIN = 20         -- fenêtre de lecture du débit (deux demi-vies)
Ml.UNIT_RATE_DEFAULT = 6   -- objets par minute d'un assembleur quand l'appelant ne donne pas le débit de la recette
Ml.WANT_TTL = 10 * 3600    -- une demande notée par Ml.want s'éteint si personne ne la renouvelle en 10 minutes de jeu

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

function Ml.new()
  return { t0 = 0, use = {}, last = {}, running = {}, want = {}, items = {}, n_items = 0, version = 2 }
end

--- Note la demande de fabrication à la main de cette pensée : now = { [objet] = quantité en cours de demande }. Épisode = passage
--- de 0 à plus de 0 ; le volume reçoit l'augmentation (une demande ré-émise à l'identique à chaque pensée ne compte qu'une fois).
function Ml.note(st, tick, now)
  st.use, st.last = st.use or {}, st.last or {}
  if tick - (st.t0 or 0) >= Ml.WINDOW_TICKS then
    for _, k in ipairs(sorted_keys(st.use)) do
      local u = st.use[k]
      u.n, u.episodes = math.floor(u.n / 2), math.floor(u.episodes / 2)
      if u.n <= 0 or u.episodes <= 0 then st.use[k] = nil end
    end
    st.t0 = tick
  end
  for _, k in ipairs(sorted_keys(now)) do
    local n = math.floor(now[k] or 0)
    local prev = st.last[k] or 0
    if n > prev then
      local u = st.use[k] or { n = 0, episodes = 0 }
      u.n = u.n + (n - prev)
      if prev == 0 then u.episodes = u.episodes + 1 end
      st.use[k] = u
    end
    st.last[k] = n > 0 and n or nil
  end
  for _, k in ipairs(sorted_keys(st.last)) do
    if now[k] == nil then st.last[k] = nil end
  end
  return st
end

--- Assembleurs pour un débit demandé (objets par minute) : de 1 à Ml.MACHINES_MAX.
function Ml.machines(rate, unit)
  unit = (unit and unit > 0) and unit or Ml.UNIT_RATE_DEFAULT
  local n = math.ceil(((rate or 0) * Ml.LEAD) / unit - 1e-9)
  if n < 1 then n = 1 end
  if n > Ml.MACHINES_MAX then n = Ml.MACHINES_MAX end
  return n
end

--- Cible de stock au coffre de sortie (objets).
function Ml.target(rate)
  return math.max(1, math.ceil((rate or 0) * Ml.HORIZON_MIN - 1e-9))
end

--- Choix des objets du mall. book : livre (Book:recipe_for) ; opts = { unit = function(objet) -> objets/min d'une machine ou nil,
--- have = { [objet] = n au coffre de sortie } }. Rend la liste triée { { item, rate, machines, target, have } } et la garde dans st.items.
function Ml.decide(st, book, opts)
  opts = opts or {}
  local cands = {}
  for _, k in ipairs(sorted_keys(st.use)) do
    local u = st.use[k]
    if u.episodes >= Ml.MIN_EPISODES and u.n > 0 and book and book.recipe_for and book:recipe_for(k) ~= nil then
      cands[#cands + 1] = { item = k, n = u.n }
    end
  end
  table.sort(cands, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.item < b.item
  end)
  local out = {}
  for i = 1, math.min(#cands, Ml.MAX_ITEMS) do
    local c = cands[i]
    local rate = c.n / Ml.WINDOW_MIN
    local unit = opts.unit and opts.unit(c.item) or nil
    out[#out + 1] = { item = c.item, rate = rate, machines = Ml.machines(rate, unit), target = Ml.target(rate),
      have = ((opts.have or {})[c.item]) or 0 }
  end
  st.items, st.n_items = out, #out
  return out
end

--- Lot INDUSTRIE I6 : note la demande d'un objet que la main ne fabrique pas (refus « manque sous une demi-machine » de la
--- capitalisation, ingrédient d'un dépliage…). `rate` : objets par minute ; renouvelée à chaque pensée par l'appelant, elle s'éteint
--- d'elle-même après Ml.WANT_TTL ticks de jeu (état d'ÉTAT, aucune horloge mesurée).
function Ml.want(st, tick, item, rate, src)
  if type(item) ~= "string" or type(rate) ~= "number" or rate <= 0 then return false end
  st.want = st.want or {}
  st.want[item] = { rate = rate, tick = tick, src = src or "?" }
  return true
end

--- Demande entière du mall, pour la règle du choix : la main (volume ÷ fenêtre, au moins Ml.MIN_EPISODES épisodes) et les demandes
--- notées par Ml.want encore fraîches. Liste triée { { item, rate, src } } (une ligne par source et par objet).
function Ml.sources(st, tick)
  local out = {}
  for _, k in ipairs(sorted_keys(st and st.use)) do
    local u = st.use[k]
    if u.episodes >= Ml.MIN_EPISODES and u.n > 0 then out[#out + 1] = { item = k, rate = u.n / Ml.WINDOW_MIN, src = "main" } end
  end
  for _, k in ipairs(sorted_keys(st and st.want)) do
    local w = st.want[k]
    if tick - (w.tick or 0) <= Ml.WANT_TTL then
      out[#out + 1] = { item = k, rate = w.rate, src = w.src }
    else
      st.want[k] = nil
    end
  end
  return out
end

--- La fabrication à la main de cet objet est-elle permise ? Pas quand le mall le fabrique en continu (st.running[objet], posé par le
--- runtime quand le module tourne), sauf stock nul (amorçage, ou mall à sec).
function Ml.hand_allowed(st, item, have)
  if not (st and st.running and st.running[item]) then return true end
  return (have or 0) <= 0
end

--- Le maillon vers les usines (relecture) : la demande du mall devient un PUITS de la capitalisation (Ca.decide, input.sinks) ; ses ordres
--- « chaîne » (plusieurs machines selon le débit, Ca.CHAIN_LEAD) sont posés par l'exécutant existant (plan directeur). Liste triée par
--- Ml.decide : déterministe.
function Ml.sinks(st)
  local out = {}
  for _, it in ipairs((st and st.items) or {}) do
    if it.rate > 0 then out[#out + 1] = { item = it.item, rate = it.rate, want = it.rate } end
  end
  return out
end

--- « Le mall tourne » se lit sur la production des MACHINES de la dernière minute (flows[objet] = { made, hand } : tout ce qui est
--- produit, dont la main). Une machine arrêtée rend la main (aucun blocage) : c'est un état mesuré, pas une horloge.
function Ml.set_running(st, flows)
  local run = {}
  for _, it in ipairs(st.items or {}) do
    local fl = (flows or {})[it.item]
    if fl and (fl.made or 0) - (fl.hand or 0) > 0 then run[it.item] = true end
  end
  -- lot INDUSTRIE I6 : un objet du bloc de mall (demande notée par Ml.want) tourne lui aussi
  for _, k in ipairs(sorted_keys(st.want)) do
    local fl = (flows or {})[k]
    if fl and (fl.made or 0) - (fl.hand or 0) > 0 then run[k] = true end
  end
  st.running = run
  return run
end

--- Retire de `tasks` les fabrications à la main que le mall assure (Ml.hand_allowed), sous la priorité `urgent` (défense et réparations
--- gardent la main). Rend une liste neuve, dans le même ordre.
function Ml.filter_crafts(st, tasks, stock, urgent)
  local out = {}
  for _, t in ipairs(tasks or {}) do
    if t.kind ~= "craft" or (t.prio or 0) >= urgent or Ml.hand_allowed(st, t.item, (stock or {})[t.item]) then out[#out + 1] = t end
  end
  return out
end

--- Ligne du journal [FO-MALL] (aucune décision ne la lit).
function Ml.describe(st)
  local parts = {}
  for _, it in ipairs(st.items or {}) do
    parts[#parts + 1] = string.format("%s x%d (%.1f/min, cible %d%s)", it.item, it.machines, it.rate, it.target,
      (st.running or {})[it.item] and ", TOURNE" or ", amorcage a la main")
  end
  return string.format("%d objet(s) : %s", #(st.items or {}), #parts > 0 and table.concat(parts, " ; ") or "aucun")
end

return Ml
