--[[
  Lot PILE-MALL (retour du DC du 31/10, point 8 : « 6 838 fabrications à la main », aucun mall, aucun stock d'avance). Un MALL est un
  module qui fabrique EN CONTINU les objets de construction répétitifs (tapis, bras, poteaux, foreuses, fours, tourelles,
  munitions) dans des assembleurs, sorties en coffre où les PNJ se servent ; la fabrication à la main ne reste que pour
  l'AMORÇAGE (tant que le module ne tourne pas).

  PUR (aucune API Factorio, AUCUN nom d'objet ni de bâtiment : les objets viennent de la demande mesurée, les rôles du gabarit
  ("assembleur", "coffre_entree"...) sont résolus en entités par le runtime). Testé hors jeu : tests/mall_test.lua.

  Quels objets ? Ceux que la main a dû fabriquer SOUVENT (Ml.note : chaque fois que la demande de fabrication d'un objet passe de
  0 à plus de 0 compte un épisode, l'augmentation entre dans le volume ; fenêtre glissante par moitié toutes les Ml.WINDOW_TICKS
  ticks de jeu, jamais par un temps mesuré) : au moins Ml.MIN_EPISODES épisodes, une recette connue du livre, au plus Ml.MAX_ITEMS objets
  (les plus demandés d'abord, clé en cas d'égalité).
  Combien d'usines par objet ? Ml.machines : le débit demandé (volume / fenêtre) × Ml.LEAD ÷ le débit d'une machine, arrondi au-dessus,
  de 1 à Ml.MACHINES_MAX (« plusieurs usines par objet selon la demande », au lieu d'une seule x1).
  Combien d'avance ? Ml.target : Ml.HORIZON_MIN minutes de demande au coffre de sortie ; Ml.refill : l'assembleur travaille tant que le
  coffre est sous Ml.LOW_PCT % de la cible et s'arrête à Ml.HIGH_PCT % (hystérésis d'ÉTAT, aucune horloge).
  La main : Ml.hand_allowed refuse la fabrication à la main d'un objet dont le mall TOURNE (st.running), sauf au stock nul.
  Déterminisme : listes triées par (volume décroissant, clé), entiers, aucun pairs décisionnel.
]]

local Ml = {}

Ml.MIN_EPISODES = 3        -- demandes distinctes de fabrication à la main avant de dédier un assembleur
Ml.MAX_ITEMS = 8           -- objets d'un mall
Ml.MACHINES_MAX = 4        -- assembleurs par objet
Ml.LEAD = 2                -- capacité = 2 fois le débit demandé (même règle que Ca.LEAD)
Ml.HORIZON_MIN = 10        -- minutes de demande gardées au coffre de sortie
Ml.LOW_PCT, Ml.HIGH_PCT = 50, 100
Ml.WINDOW_TICKS = 10 * 3600 -- la mémoire de la demande est divisée par deux toutes les 10 minutes de jeu
Ml.WINDOW_MIN = 20         -- fenêtre de lecture du débit (deux demi-vies)
Ml.UNIT_RATE_DEFAULT = 6   -- objets par minute d'un assembleur quand l'appelant ne donne pas le débit de la recette

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

function Ml.new()
  return { t0 = 0, use = {}, last = {}, running = {}, on = {}, items = {}, n_items = 0, version = 1 }
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

--- L'assembleur de cet objet doit-il travailler ? Hystérésis d'état (st.on[objet]).
function Ml.refill(st, item, have, target)
  st.on = st.on or {}
  local on = st.on[item] or false
  if have * 100 < target * Ml.LOW_PCT then on = true
  elseif have * 100 >= target * Ml.HIGH_PCT then on = false end
  st.on[item] = on or nil
  return on
end

--- Choix des objets du mall. book : livre (Book:recipe_for) ; opts = { unit = function(objet) -> objets/min d'une machine ou nil,
--- have = { [objet] = n au coffre de sortie } }. Rend la liste triée { { item, rate, machines, target, work } } et la garde dans st.items.
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
    local tgt = Ml.target(rate)
    local have = ((opts.have or {})[c.item]) or 0
    out[#out + 1] = { item = c.item, rate = rate, machines = Ml.machines(rate, unit), target = tgt,
      work = Ml.refill(st, c.item, have, tgt) }
  end
  -- objets sortis de la liste : l'hystérésis est oubliée
  local keep = {}
  for _, it in ipairs(out) do keep[it.item] = true end
  for _, k in ipairs(sorted_keys(st.on)) do if not keep[k] then st.on[k] = nil end end
  st.items, st.n_items = out, #out
  return out
end

--- La fabrication à la main de cet objet est-elle permise ? Pas quand le mall le fabrique en continu (st.running[objet], posé par le
--- runtime quand le module tourne), sauf stock nul (amorçage, ou mall à sec).
function Ml.hand_allowed(st, item, have)
  if not (st and st.running and st.running[item]) then return true end
  return (have or 0) <= 0
end

--- Gabarit du mall : une RANGÉE par objet, une colonne par assembleur. Tous les rôles sont des mots ; le runtime les résout en entités.
---   coffre_entree (ingrédients que les PNJ y déposent) -> inserteur_entree -> assembleur 3x3 -> inserteur_sortie -> coffre_sortie
---   (les PNJ s'y servent) ; un poteau dans la colonne libre entre deux assembleurs. Pas de 4 colonnes et de 7 lignes, origine (0, 0)
---   au coin haut-gauche du premier assembleur de la première rangée.
Ml.PITCH_X, Ml.PITCH_Y = 4, 8
function Ml.layout(items)
  local cells = {}
  for r, it in ipairs(items or {}) do
    local y = (r - 1) * Ml.PITCH_Y + 2
    for c = 1, it.machines do
      local x = (c - 1) * Ml.PITCH_X
      local function add(role, dx, dy, w, h)
        cells[#cells + 1] = { role = role, x = x + dx, y = y + dy, w = w, h = h, row = r, col = c, item = it.item }
      end
      add("coffre_entree", 1, -2, 1, 1)
      add("inserteur_entree", 1, -1, 1, 1)
      add("assembleur", 0, 0, 3, 3)
      add("inserteur_sortie", 1, 3, 1, 1)
      add("coffre_sortie", 1, 4, 1, 1)
      add("poteau", 3, 1, 1, 1)
    end
  end
  return cells
end

--- Emprise du gabarit : { w, h } en tuiles (0, 0 si vide).
function Ml.extent(cells)
  local x1, y1, x2, y2
  for _, c in ipairs(cells or {}) do
    x1 = math.min(x1 or c.x, c.x); y1 = math.min(y1 or c.y, c.y)
    x2 = math.max(x2 or c.x + c.w, c.x + c.w); y2 = math.max(y2 or c.y + c.h, c.y + c.h)
  end
  if not x1 then return { w = 0, h = 0 } end
  return { w = x2 - x1, h = y2 - y1, x = x1, y = y1 }
end

--- Ligne du journal [FO-MALL] (aucune décision ne la lit).
function Ml.describe(st)
  local parts = {}
  for _, it in ipairs(st.items or {}) do
    parts[#parts + 1] = string.format("%s x%d (%.1f/min, cible %d%s%s)", it.item, it.machines, it.rate, it.target,
      it.work and ", travaille" or ", plein", (st.running or {})[it.item] and ", TOURNE" or ", amorcage a la main")
  end
  return string.format("%d objet(s) : %s", #(st.items or {}), #parts > 0 and table.concat(parts, " ; ") or "aucun")
end

return Ml
