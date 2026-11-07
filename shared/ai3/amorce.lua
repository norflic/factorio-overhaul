--[[
  Lot VIDEO L7 « amorce et retrait » (docs/VIDEO_AUTOMATISATION.md §6 L7 ; TODO_VIDEO V51 à V56, C11). Étend le mall (shared/ai3/mall.lua,
  Ml) sans le modifier :
    (a) GRAINE : la liste de matériel des Am.K prochains projets du plan directeur (bâtiments à poser, moins ce que le stock a déjà)
        entre comme demande de départ du mall (Ml.want, source « amorce »), dès la 1re pensée, sans attendre Ml.MIN_EPISODES épisodes
        de fabrication à la main (V52, V53 : le capital qui fabrique le capital d'abord). La graine ne dépasse jamais la liste de
        matériel : son débit est le manque ÷ Am.HORIZON_MIN, et la barre du coffre de sortie (Id.barre, 10 min) le ramène au manque ;
        elle n'écrase jamais une demande plus forte d'une autre source.
    (b) RETRAIT : la main est retirée dès la PREMIÈRE production OBSERVÉE d'une machine (V54, V55 ; M38 via L5), et le reste (verrou),
        même quand la machine s'arrête ensuite parce que sa sortie est pleine (Ml.set_running, lui, se relit chaque minute) ; jamais
        à la pose d'un module qui ne produit pas encore ; jamais à stock nul (invariant de mall.lua l.18). Le verrou tombe si plus
        aucun module ne produit l'objet (`alive`).
    (c) COMPTEUR D'AMORCE : cumul par objet de ce que la main a fourni avant la 1re production (V56, M39) ; gardé après le retrait
        (jamais remis à zéro) : c'est ce qui dimensionne un vrai kit de départ (C11). Ligne [FO-AMORCE] par objet au retrait.

  PUR : aucune API du jeu, aucun nom d'objet (anti-échelle de tests/iag_test.lua §8). État dans st.amorce (sérialisable, aucune
  fonction). Déterminisme : listes triées, entiers, ticks de jeu, aucune horloge mesurée. Testé hors jeu : tests/amorce_test.lua.
]]

local Am = {}

Am.K = 3              -- projets du plan directeur dont la liste de matériel sert de graine
Am.HORIZON_MIN = 10   -- le manque de la graine doit être couvert en 10 minutes de jeu (même horizon que Ml.HORIZON_MIN)
Am.SRC = "amorce"     -- source de la demande notée par Ml.want

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function state(st)
  st.amorce = st.amorce or { seed = {}, hand = {}, since = {}, done = {} }
  local a = st.amorce
  a.seed, a.hand, a.since, a.done = a.seed or {}, a.hand or {}, a.since or {}, a.done or {}
  return a
end

--- Liste de matériel des K premiers projets d'une file (ordre de la file) : projets = { { bom = { [objet] = n } } } ; rend
--- { [objet] = n } (somme) et la liste triée des objets.
function Am.bom(projets, k)
  k = k or Am.K
  local sum = {}
  for i = 1, math.min(k, #(projets or {})) do
    local b = projets[i].bom or {}
    for _, it in ipairs(sorted_keys(b)) do
      local n = math.floor(b[it] or 0)
      if n > 0 then sum[it] = (sum[it] or 0) + n end
    end
  end
  return sum, sorted_keys(sum)
end

--- (a) La graine. projets : file du plan directeur (les K premiers comptent) ; have = { [objet] = stock } ; book : livre (recipe_for) ;
--- Ml : la règle du mall (injectée : aucun require croisé). Rend la liste triée { { item, need, rate } } des objets semés.
function Am.seed(st, tick, projets, have, book, Ml)
  local a = state(st)
  local sum, items = Am.bom(projets, Am.K)
  local out = {}
  a.seed = {}
  for _, it in ipairs(items) do
    local need = sum[it] - math.floor((have or {})[it] or 0)
    if need > 0 and book and book.recipe_for and book:recipe_for(it) ~= nil then -- la demande reste après le retrait de la main
      local rate = need / Am.HORIZON_MIN
      local cur = st.want and st.want[it]
      local fresh = cur and (tick - (cur.tick or 0) <= Ml.WANT_TTL)
      if not (fresh and cur.src ~= Am.SRC and (cur.rate or 0) >= rate) then
        Ml.want(st, tick, it, rate, Am.SRC)
      end
      a.seed[it] = need
      out[#out + 1] = { item = it, need = need, rate = rate }
    end
  end
  return out
end

--- (b) et (c) Relevé d'une minute : flows[objet] = { made, hand } (tout ce qui est produit, dont la main) ; alive = { [objet] = vrai }
--- les objets qu'un module posé du plan directeur fabrique (nil : non relu, le verrou ne tombe pas). Cumule la main des objets
--- suivis tant que leur machine n'a rien produit ; pose le verrou à la 1re production d'une machine. Rend la liste triée des
--- retraits de cette minute { { item, hand, tick } } (journal [FO-AMORCE]).
function Am.observe(st, tick, flows, alive)
  local a = state(st)
  local track = {}
  for _, it in ipairs(st.items or {}) do track[it.item] = true end
  for _, k in ipairs(sorted_keys(st.want)) do track[k] = true end
  for _, k in ipairs(sorted_keys(a.seed)) do track[k] = true end
  for _, k in ipairs(sorted_keys(a.hand)) do track[k] = true end
  local retraits = {}
  for _, it in ipairs(sorted_keys(track)) do
    local fl = (flows or {})[it]
    local hand = fl and math.floor(fl.hand or 0) or 0
    local machine = fl and ((fl.made or 0) - (fl.hand or 0)) or 0
    if a.done[it] then
      if alive and not alive[it] then a.done[it] = nil end -- plus aucun producteur : la main revient (le compteur reste)
    elseif machine > 0 then
      a.done[it] = tick
      retraits[#retraits + 1] = { item = it, hand = a.hand[it] or 0, tick = tick }
    elseif hand > 0 then
      a.hand[it] = (a.hand[it] or 0) + hand
      a.since[it] = a.since[it] or tick
    end
  end
  return retraits
end

--- La main est-elle permise ? Refusée dès la 1re production observée (verrou), ou quand le mall tourne (Ml.hand_allowed) ; toujours
--- permise à stock nul.
function Am.hand_allowed(st, item, have, Ml)
  if (have or 0) <= 0 then return true end
  local a = st and st.amorce
  if a and a.done and a.done[item] then return false end
  return Ml.hand_allowed(st, item, have)
end

--- Ml.filter_crafts avec le verrou d'amorce : retire les fabrications à la main que le producteur assure, sous la priorité `urgent`.
function Am.filter_crafts(st, tasks, stock, urgent, Ml)
  local out = {}
  for _, t in ipairs(tasks or {}) do
    if t.kind ~= "craft" or (t.prio or 0) >= urgent or Am.hand_allowed(st, t.item, (stock or {})[t.item], Ml) then out[#out + 1] = t end
  end
  return out
end

--- Compteur d'amorce d'un objet (objets fournis à la main avant la 1re production).
function Am.supplied(st, item)
  return (st and st.amorce and st.amorce.hand and st.amorce.hand[item]) or 0
end

--- Ligne du journal [FO-AMORCE] d'un retrait (aucune décision ne la lit).
function Am.describe(r, st)
  local since = st and st.amorce and st.amorce.since and st.amorce.since[r.item]
  return string.format("%s : main retiree a la 1re production (tick %d) ; %d fourni(s) a la main avant%s", r.item, r.tick, r.hand,
    since and string.format(" (depuis le tick %d, %.1f min)", since, (r.tick - since) / 3600) or "")
end

return Am
