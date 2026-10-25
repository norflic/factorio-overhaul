--[[
  IA3 « le cerveau des PNJ » : PROTOTYPE PUR (conception, NON BRANCHÉ) du REGISTRE DES RÉSERVATIONS d'une équipe.
  docs/IA3_CERVEAU.md §2.2. Personne ne « s'arrache » les plaques : chaque projet a sa part du stock du QG, un PNJ ne
  prend au coffre que ce que la réservation de SA tâche couvre, et une préemption obéit à des règles écrites.

    stock(o)        lu au coffre à chaque pensée (vérité du moteur) : R.set_stock
    reserve(p, o)   part de o réservée au projet p
    libre(o)      = stock(o) − Σ reserve(p, o)       (jamais négatif : R.check)

  R.new() ; R.open(reg, id, prio, tick) ; R.request(reg, id, needs, tick) -> accordé, manque ;
  R.take(reg, id, item, n) -> n pris (prise STRICTE d'un PNJ) ; R.preempt(reg, id, item, n, tick) -> n repris ;
  R.release(reg, id) ; R.free(reg, item) ; R.effective(reg, id, tick) ; R.check(reg) -> ok, message.
  Projets triés par identifiant (entiers croissants) ; objets parcourus par nom trié ; aucun hasard.
]]

local R = {}

R.PREEMPT_URGENT = 30   -- écart de priorité qui permet de prendre la réservation d'un projet engagé
R.PREEMPT_IDLE = 10     -- écart suffisant si le projet visé n'a encore rien consommé
R.ENGAGED_PCT = 20      -- inertie d'un projet engagé : + 20 % de sa priorité
R.AGING_TICKS = 3600    -- un point de priorité par minute d'attente de matière…
R.AGING_MAX = 20        -- … jusqu'à + 20

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

function R.new()
  return { stock = {}, projects = {}, ids = {} }
end

function R.open(reg, id, prio, tick)
  if reg.projects[id] then return reg.projects[id] end
  local p = { id = id, prio = prio, resa = {}, engaged = false, waiting_since = nil, opened = tick or 0 }
  reg.projects[id] = p
  reg.ids[#reg.ids + 1] = id
  table.sort(reg.ids)
  return p
end

function R.reserved(reg, item)
  local n = 0
  for _, id in ipairs(reg.ids) do n = n + (reg.projects[id].resa[item] or 0) end
  return n
end

function R.free(reg, item)
  local f = (reg.stock[item] or 0) - R.reserved(reg, item)
  return f > 0 and f or 0
end

--- Priorité effective : base + vieillissement (attente de matière) + inertie d'un projet engagé. Entier.
function R.effective(reg, id, tick)
  local p = reg.projects[id]
  local e = p.prio
  if p.waiting_since and tick then
    local age = math.floor((tick - p.waiting_since) / R.AGING_TICKS)
    e = e + (age < R.AGING_MAX and age or R.AGING_MAX)
  end
  if p.engaged then e = e + math.floor(p.prio * R.ENGAGED_PCT / 100) end
  return e
end

--- Ordre de sacrifice : priorité effective croissante, puis identifiant décroissant (le plus récent cède d'abord).
local function victims(reg, tick, except)
  local list = {}
  for _, id in ipairs(reg.ids) do if id ~= except then list[#list + 1] = id end end
  table.sort(list, function(a, b)
    local ea, eb = R.effective(reg, a, tick), R.effective(reg, b, tick)
    if ea ~= eb then return ea < eb end
    return a > b
  end)
  return list
end

--- Vérité du coffre. Si des objets ont disparu (pris par un ennemi, détruits), les réservations les moins
--- prioritaires rétrécissent d'abord.
function R.set_stock(reg, stock, tick)
  reg.stock = {}
  for _, k in ipairs(sorted_keys(stock)) do reg.stock[k] = stock[k] end
  local items = {}
  for _, id in ipairs(reg.ids) do for _, k in ipairs(sorted_keys(reg.projects[id].resa)) do items[k] = true end end
  for _, item in ipairs(sorted_keys(items)) do
    local over = R.reserved(reg, item) - (reg.stock[item] or 0)
    if over > 0 then
      for _, id in ipairs(victims(reg, tick)) do
        local p = reg.projects[id]
        local have = p.resa[item] or 0
        local cut = have < over and have or over
        if cut > 0 then
          p.resa[item] = have - cut
          if p.resa[item] == 0 then p.resa[item] = nil end
          over = over - cut
        end
        if over <= 0 then break end
      end
    end
  end
end

--- Demande d'un projet : besoins NETS { {objet, n}, ... } ; puise seulement dans le LIBRE. Renvoie accordé, manque.
function R.request(reg, id, needs, tick)
  local p = reg.projects[id]
  local granted, short = {}, {}
  for _, it in ipairs(needs) do
    local item, n = it[1], it[2]
    local f = R.free(reg, item)
    local g = f < n and f or n
    if g > 0 then
      p.resa[item] = (p.resa[item] or 0) + g
      granted[#granted + 1] = { item, g }
    end
    if g < n then short[#short + 1] = { item, n - g } end
  end
  if #short > 0 then p.waiting_since = p.waiting_since or tick else p.waiting_since = nil end
  return granted, short
end

--- Prise STRICTE d'un PNJ pour une tâche du projet `id` : jamais plus que la réservation, jamais plus que le coffre.
function R.take(reg, id, item, n)
  local p = reg.projects[id]
  local have = p.resa[item] or 0
  local s = reg.stock[item] or 0
  local t = n
  if have < t then t = have end
  if s < t then t = s end
  if t > 0 then
    p.resa[item] = have - t
    if p.resa[item] == 0 then p.resa[item] = nil end
    reg.stock[item] = s - t
    p.engaged = true
  end
  return t
end

--- Préemption : le projet `id` reprend jusqu'à n objets réservés par des projets MOINS prioritaires, selon les règles :
--- écart ≥ PREEMPT_URGENT, ou ≥ PREEMPT_IDLE si le projet visé n'est pas engagé. Renvoie la quantité reprise et la
--- liste { {projet, n} } des projets préemptés (pour la fenêtre).
function R.preempt(reg, id, item, n, tick)
  local mine = R.effective(reg, id, tick)
  local got, from = 0, {}
  for _, vid in ipairs(victims(reg, tick, id)) do
    if got >= n then break end
    local v = reg.projects[vid]
    local gap = mine - R.effective(reg, vid, tick)
    local allowed = gap >= R.PREEMPT_URGENT or (gap >= R.PREEMPT_IDLE and not v.engaged)
    local have = v.resa[item] or 0
    if allowed and have > 0 then
      local t = have < (n - got) and have or (n - got)
      v.resa[item] = have - t
      if v.resa[item] == 0 then v.resa[item] = nil end
      v.waiting_since = v.waiting_since or tick
      local p = reg.projects[id]
      p.resa[item] = (p.resa[item] or 0) + t
      got = got + t
      from[#from + 1] = { vid, t }
    end
  end
  return got, from
end

--- Projet fini ou abandonné : son reste retourne au libre.
function R.release(reg, id)
  if not reg.projects[id] then return end
  reg.projects[id] = nil
  for i, v in ipairs(reg.ids) do if v == id then table.remove(reg.ids, i) break end end
end

--- Invariants : réservations positives, Σ réservé ≤ stock pour chaque objet.
function R.check(reg)
  local items = {}
  for _, id in ipairs(reg.ids) do
    for _, k in ipairs(sorted_keys(reg.projects[id].resa)) do
      if reg.projects[id].resa[k] <= 0 then return false, "réservation non positive " .. k end
      items[k] = true
    end
  end
  for _, item in ipairs(sorted_keys(items)) do
    if R.reserved(reg, item) > (reg.stock[item] or 0) then
      return false, string.format("%s : réservé %d > stock %d", item, R.reserved(reg, item), reg.stock[item] or 0)
    end
  end
  return true
end

--- Empreinte (déterminisme) : chaîne stable de l'état.
function R.fingerprint(reg)
  local parts = {}
  for _, k in ipairs(sorted_keys(reg.stock)) do parts[#parts + 1] = k .. "=" .. reg.stock[k] end
  for _, id in ipairs(reg.ids) do
    local p = reg.projects[id]
    local r = {}
    for _, k in ipairs(sorted_keys(p.resa)) do r[#r + 1] = k .. "=" .. p.resa[k] end
    parts[#parts + 1] = string.format("#%d:%d:%s:%s:%s", id, p.prio, tostring(p.engaged), tostring(p.waiting_since), table.concat(r, ","))
  end
  return table.concat(parts, ";")
end

return R
