--[[
  Lot DEPENSES (3/11) : le stock qui DORT déclenche des dépenses. Règle PURE (aucune API Factorio, aucun nom d'objet : les produits
  sont des chaînes opaques données par le runtime ; tests/depenses_test.lua).

  Retour du DC (3/11, 0.6.46) : « l'avancement est pas si énorme que ça par rapport aux ressources disponibles [...] Il y a peu de
  dépenses intensives [...] si on a des objectifs tels que la défense et qu'il y a pas d'investissement derrière, compliqué. »
  Mesure (fo-logs/2026-11-03_DEPENSES/CRITERES.md) : à 60 min, 61 à 99 % des plaques libres des factions sont restées 10 min au
  coffre sans servir (partie du DC : 21 547 sur 33 279) ; la capitalisation dépense 0 à 900 MU par 10 min pour 5 000 à 20 000 MU
  libres ; Azur a 5 472 plaques de fer libres et attend 3 engrenages et 2 circuits pour monter sa foreuse (bâtiment de fond sans
  bras libre : rien n'est fabriqué pour lui).

  Règle :
    1. EXCÉDENT d'un produit p = stock libre HORS BESOIN évalué (shared/ai3/reserve.lua) − max(Dp.FLOOR, Dp.H_SEUIL × production de p
       par minute). Un produit dont le besoin évalué n'est pas couvert (manque) n'a aucun excédent : la survie passe d'abord.
    2. Le stock DORT quand l'excédent reste positif Dp.N_DORT ticks d'un seul tenant (horloge `since` par produit) ; seul l'excédent
       d'un produit qui dort se dépense.
    3. Le budget dormant (somme des produits qui dorment) sert dans cet ORDRE : (a) intermédiaires des améliorations (engrenages,
       circuits : le bâtiment de fond peut faire fabriquer son coût sans bras libre), (b) centre, (c) défense (au plus Dp.DEF_PCT %
       du budget : un budget OFFERT, que le périmètre lit), (d) extension de capacité (emplacements de chantier de plus, un par
       Dp.SLOT_PLATES plaques, au plus Dp.SLOTS_MAX).
    4. Jamais sous le plancher : ce qui est offert ne dépasse jamais l'excédent, qui laisse le besoin évalué et Dp.H_SEUIL minutes de
       production au coffre.
    5. Interrupteur : inp.on faux -> rien n'est offert, les horloges sont oubliées.
  Déterminisme : produits parcourus dans l'ordre donné par l'appelant, aucun hasard, aucun temps mesuré ; l'état ne garde que des
  nombres (sauvegarde).
]]

local Dp = {}

Dp.H_SEUIL = 6            -- min de production gardées au coffre au-delà du besoin évalué (tampon)
Dp.FLOOR = 100            -- plaques gardées au moins par produit (plancher de survie absolu, besoin évalué en plus)
Dp.N_DORT = 5 * 3600      -- ticks d'excédent continu avant que le stock « dorme »
Dp.PROD_KEEP = 700        -- ‰ de l'ancienne production gardés à chaque relevé (moyenne glissante)
Dp.DEF_PCT = 30           -- % du budget dormant offert à la défense au plus
Dp.SLOT_PLATES = 1500     -- plaques dormantes par emplacement de chantier de plus
Dp.SLOTS_MAX = 3          -- emplacements de chantier de plus au plus
Dp.ORDER = { "intermediaires", "centre", "defense", "capacite" }

--- État neuf (nombres et tables de nombres seulement).
function Dp.new() return { since = {}, prod = {}, last_tick = nil } end

local function num(x) return type(x) == "number" and x == x and x or 0 end

--- Production lissée d'un produit : made objets en dt ticks -> par minute (Dp.PROD_KEEP ‰ de l'ancienne valeur gardés).
function Dp.smooth(old, made, dt)
  if not dt or dt <= 0 then return num(old) end
  local per_min = num(made) * 3600 / dt
  if old == nil then return per_min end
  return (num(old) * Dp.PROD_KEEP + per_min * (1000 - Dp.PROD_KEEP)) / 1000
end

--- Excédent d'un produit : free (stock libre hors besoin), prod (par minute), missing (besoin non couvert pour ce produit).
function Dp.excess(free, prod, missing)
  if missing then return 0 end
  local keep = math.max(Dp.FLOOR, Dp.H_SEUIL * math.max(0, num(prod)))
  return math.max(0, num(free) - keep)
end

--- Un pas de la règle. st = état (Dp.new), inp = { on, tick, products = { { key, free, made, missing } } (dans l'ordre de
--- l'appelant ; made = objets produits depuis le pas précédent), demands = { intermediaires, centre, defense } (plaques ; nil :
--- pas de demande, sauf défense : nil = Dp.DEF_PCT % du budget) }. Rend st, res = { active, total, per = { [key] = excédent qui
--- dort }, grant = { [tier] = plaques }, upgrade (bool : les intermédiaires d'une amélioration de fond peuvent se fabriquer),
--- slots (emplacements de plus), defense (plaques offertes), why }.
function Dp.step(st, inp)
  st = st or Dp.new()
  st.since = st.since or {}
  st.prod = st.prod or {}
  inp = inp or {}
  local tick = num(inp.tick)
  local res = { active = false, total = 0, per = {}, grant = {}, upgrade = false, slots = 0, defense = 0, why = "" }
  if not inp.on then
    st.since, st.prod, st.last_tick = {}, {}, nil
    res.why = "eteint"
    return st, res
  end
  local dt = st.last_tick and (tick - st.last_tick) or nil
  st.last_tick = tick
  local parts = {}
  for _, p in ipairs(inp.products or {}) do
    local key = tostring(p.key)
    if dt then st.prod[key] = Dp.smooth(st.prod[key], p.made, dt) end
    local exc = Dp.excess(p.free, st.prod[key], p.missing)
    if exc > 0 then
      st.since[key] = st.since[key] or tick
    else
      st.since[key] = nil
    end
    local sleeping = st.since[key] ~= nil and tick - st.since[key] >= Dp.N_DORT
    if sleeping then
      res.per[key] = exc
      res.total = res.total + exc
    end
    parts[#parts + 1] = string.format("%s libre %d prod %.0f/min exces %d%s", key, math.floor(num(p.free)), num(st.prod[key]),
      math.floor(exc), sleeping and " DORT" or (st.since[key] and string.format(" depuis %.1f min", (tick - st.since[key]) / 3600) or ""))
  end
  local left = res.total
  local d = inp.demands or {}
  for _, tier in ipairs(Dp.ORDER) do
    local want
    if tier == "defense" then
      want = d.defense ~= nil and math.max(0, num(d.defense)) or res.total * Dp.DEF_PCT / 100
      want = math.min(want, res.total * Dp.DEF_PCT / 100)
    elseif tier == "capacite" then
      want = left
    else
      want = math.max(0, num(d[tier]))
    end
    local g = math.max(0, math.min(want, left))
    res.grant[tier] = g
    left = left - g
  end
  res.active = res.total > 0
  res.upgrade = res.active and (res.grant.intermediaires or 0) > 0
    and (res.grant.intermediaires or 0) >= math.max(0, num(d.intermediaires)) - 1e-9
  res.slots = math.min(Dp.SLOTS_MAX, math.floor((res.grant.capacite or 0) / Dp.SLOT_PLATES + 1e-9))
  res.defense = math.floor(res.grant.defense or 0)
  res.why = string.format("%s | dort %d plaque(s) | intermediaires %d%s, centre %d, defense %d, capacite %d (+%d emplacement(s))",
    table.concat(parts, " ; "), math.floor(res.total), math.floor(res.grant.intermediaires or 0), res.upgrade and " (amelioration de fond servie)" or "",
    math.floor(res.grant.centre or 0), res.defense, math.floor(res.grant.capacite or 0), res.slots)
  return st, res
end

--- Demande « intermédiaires » d'une amélioration : cost = { {objet, n} } du but en cours ; unit = fonction objet -> plaques (nil :
--- 1 plaque par objet, borne basse). Rend des plaques (0 sans but).
function Dp.cost_plates(cost, unit)
  local s = 0
  for _, it in ipairs(cost or {}) do
    local n = num(it[2])
    local u = unit and unit(it[1]) or 1
    s = s + n * num(u)
  end
  return s
end

return Dp
