--[[
  Lot PREVISION : les DÉCISIONS tirées de l'estimateur unique (shared/ai3/prevision.lua). PUR (aucune API Factorio, aucun nom
  d'objet), testé hors jeu par tests/prevision_test.lua (mutants compris). La prévision ne pose rien elle-même : elle rend des
  SIGNAUX que lisent la pile (shared/ai3/pile.lua, cadre « preparer »), le front (shared/team/front.lua, tourelles d'avance),
  l'armée (shared/ai3/armee.lua, recrues, regroupement, raid) et la capitalisation (coût de la défense induite).

  Règles (corrections de la critique, fo-logs/2026-10-29_VAGUE9/PREVISION/CRITIQUE.md) :
    * PRÉPARER un site (QG, avant-poste, champ) quand une vague IMMINENTE (échéance pessimiste ≤ Pv.H_COURT) dépasse sa
      défense : ouverture à Pc.RHO_IN (‰ de la défense), fermeture quand la défense atteint la cible W × Pc.MARGE (une seule
      règle, C10) ou quand la vague n'est plus prévue. HYSTÉRÉSIS D'ÉTAT : aucune horloge ne ferme un cadre ;
    * les soldats sont une RÉSERVE MOBILE affectée à UNE vague à la fois (C4) : la « première vague », échéance pessimiste la plus
      courte (puis la plus grosse), gardée tant qu'elle dépasse les tourelles de son site (aucun ping-pong entre directions) ;
    * INSURMONTABLE avec hystérésis (C10) : entrée quand la vague dépasse Pc.INSURM_IN ‰ de la meilleure défense réunissable
      avant l'échéance, sortie quand elle repasse dessous ; un siège qu'on ne peut pas tenir ne retient rien (repli au QG) ;
    * au plus Pc.PREP_MAX cadres retiennent l'amélioration (les plus grands écarts) ; « production d'abord » (le fer ne paie pas
      défense et production, shared/team/priorite.lua) : aucun cadre ne retient (le DC : « si on manque cruellement de
      ressources, l'objectif est justement ces ressources ») ; un cadre sans exécutant (front qui refuse, aucune recrue) ne
      retient pas (C10 : le trou d'exécutant) ;
    * ARMÉE : besoin = ce que les tourelles du site de la première vague ne tiennent pas ÷ valeur d'un soldat, borné par le
      plafond de soldats ET par un BUDGET en rampe selon l'échéance (C2 : Pc.PART_MIN à Pc.PART_MAX ‰ du fer au-dessus de la
      RÉSERVE DE PRODUCTION, C1, jamais prise) ; le besoin ne descend pas tant que l'alerte tient (on ne licencie pas) ;
    * RAID préventif (porte, Pc.raid_gate) : valeur (vague évitée sur Pc.RAID_H min) ÷ coût (soldats engagés) ≥ Pc.RAID_RATIO, et
      aucune AUTRE vague imminente ne dépasse la défense qui reste au QG pendant le raid.
  Entrées triées, entiers et pour-mille, aucun `pairs` décisionnel.
]]

local Pv = require("shared.ai3.prevision")

local Pc = {}

Pc.RHO_IN = 1200        -- ‰ : une vague à 1,2 × la défense ouvre « préparer »
Pc.MARGE = 1100         -- ‰ : défense visée = 1,1 × la vague ; « préparer » se ferme quand elle est atteinte (rho ≤ 909 ‰)
Pc.INSURM_IN = 1200     -- ‰ : vague à 1,2 × la meilleure défense réunissable : insurmontable (sortie : vague ≤ cette défense)
Pc.PREP_MAX = 2         -- cadres « préparer » qui retiennent au plus
Pc.PREP_TURRETS = 5     -- tourelles d'avance demandées au plus par site et par cadre
Pc.PREP_OFFSET = 10     -- tuiles : tourelles d'avance posées à 10 tuiles du centre du site, du côté de la menace
Pc.PART_MIN, Pc.PART_SPAN, Pc.PART_MAX = 300, 400, 700 -- ‰ du fer libre pour les recrues, selon l'échéance (C2)
Pc.RAID_RATIO = 1000    -- ‰ : un raid vaut au moins ce qu'il engage
Pc.RAID_H = 30          -- min : vague évitée comptée sur 30 min
Pc.MUSTER_R = 20        -- tuiles : regroupement à 20 tuiles du site menacé, vers la menace (au plus au tiers de la distance)

local function ceil(x) return math.ceil(x - 1e-9) end

function Pc.new()
  return { sites = {}, first = nil, alert = false, army_need = 0, army_soon = 0, seq = 0 }
end

--- Rapport vague ÷ défense (‰) ; défense nulle et vague non nulle : très grand.
function Pc.rho(w, d)
  if (w or 0) <= 0 then return 0 end
  if (d or 0) <= 0 then return 1000000 end
  return math.floor(1000 * w / d)
end

--- Part (‰) du fer libre pour les recrues selon l'échéance (min) : PART_MIN au loin, PART_MAX au contact (C2).
function Pc.part(eta)
  local e = eta or Pv.H_COURT
  if e < 0 then e = 0 elseif e > Pv.H_COURT then e = Pv.H_COURT end
  local p = Pc.PART_MIN + math.floor(Pc.PART_SPAN * (Pv.H_COURT - e) / Pv.H_COURT)
  if p > Pc.PART_MAX then p = Pc.PART_MAX end
  return p
end

--- Recrues payables : fer au-dessus de la réserve de production × part ÷ fer d'une recrue.
function Pc.affordable(iron, reserve, kit_iron, eta)
  if not kit_iron or kit_iron <= 0 then return 0 end
  local free = (iron or 0) - (reserve or 0)
  if free <= 0 then return 0 end
  return math.floor(free * Pc.part(eta) / 1000 / kit_iron)
end

--- Mise à jour. est = Pv.estimate ; ctx = {
---   soldiers, soldiers_max (0 : votre équipe, pas d'armée), soldier_value (PV), mobile (PV des soldats de l'équipe),
---   turret_value (PV d'une tourelle de plus), turret_stock (tourelles au coffre), iron, reserve (réserve de production, C1),
---   kit_iron (fer d'une recrue), kits_stock (équipements de soldat complets déjà au coffre), turret_iron (fer d'une tourelle
---   garnie), production_first, recruit_ok,
---   front = { [clé du site] = raison du front ("servie", "refus", "plafond", "repos", "pause", nil) } }.
--- Rend st, avec st.events = { { kind, key, ... } } (changements de décision, pour le journal).
function Pc.update(st, est, ctx, tick)
  ctx = ctx or {}
  st.sites = st.sites or {}
  local evs = {}
  local sv = ctx.soldier_value or 0
  local tv = ctx.turret_value or 0
  local mobile = ctx.mobile or 0
  -- 1. Première vague (réserve mobile, C4) : gardée tant qu'elle dépasse les tourelles de son site.
  local first = nil
  local prev = st.first and est.by[st.first]
  if prev and prev.w5 > 0 and prev.w5 * 1000 > Pc.MARGE * prev.d then first = prev end
  if not first then
    for _, o in ipairs(est.sites) do
      if o.w5 > 0 and o.w5 * 1000 > Pc.MARGE * o.d then
        if not first or o.eta < first.eta or (o.eta == first.eta and (o.w5 > first.w5 or (o.w5 == first.w5 and o.key < first.key))) then
          first = o
        end
      end
    end
  end
  local new_first = first and first.key or nil
  if new_first ~= st.first then evs[#evs + 1] = { kind = "premiere", key = new_first, was = st.first } end
  st.first = new_first
  -- Fer libre pour la défense d'avance : tourelles payables au-delà de la réserve de production.
  local turrets_pay = 0
  if (ctx.turret_iron or 0) > 0 then
    turrets_pay = math.max(0, math.floor(((ctx.iron or 0) - (ctx.reserve or 0)) / ctx.turret_iron))
  end
  local recruits_pay = 0
  if (ctx.soldiers_max or 0) > 0 then
    recruits_pay = math.min(math.max(0, ctx.soldiers_max - (ctx.soldiers or 0)),
      (ctx.kits_stock or 0) + Pc.affordable(ctx.iron, ctx.reserve, ctx.kit_iron, first and first.eta))
  end
  -- 2. Sites : hystérésis « préparer », insurmontable, tourelles voulues.
  local open = {}
  for _, o in ipairs(est.sites) do
    local s = st.sites[o.key]
    if not s then
      s = { prep = false, insurm = false }
      st.sites[o.key] = s
    end
    local dtot = o.d + ((first and first.key == o.key) and mobile or 0)
    local rho = Pc.rho(o.w5, dtot)
    s.rho, s.w5, s.w15, s.d, s.dtot, s.eta = rho, o.w5, o.w15, o.d, dtot, o.eta
    s.x, s.y, s.tx, s.ty = o.x, o.y, o.tx, o.ty
    local was = s.prep
    if not was and o.w5 > 0 and o.w5 * 1000 >= Pc.RHO_IN * dtot then
      s.prep = true
    elseif was and (o.w5 <= 0 or dtot * 1000 >= o.w5 * Pc.MARGE) then
      s.prep = false
    end
    -- Insurmontable : meilleure défense réunissable avant l'échéance (réserve mobile entière, tourelles au coffre et payables,
    -- recrues payables).
    local dmax = o.d + mobile + ((ctx.turret_stock or 0) + turrets_pay) * tv + recruits_pay * sv
    local wi = s.insurm
    if not wi and o.w5 > 0 and o.w5 * 1000 >= Pc.INSURM_IN * dmax then s.insurm = true
    elseif wi and o.w5 <= dmax then s.insurm = false end
    if s.insurm ~= (wi or false) then evs[#evs + 1] = { kind = s.insurm and "insurmontable" or "tenable", key = o.key, w5 = o.w5, dmax = dmax } end
    -- Tourelles voulues (pièces, pas PV : journal [FO-PILE] lisible) : le manque jusqu'à la cible, borné.
    s.have = o.turrets or 0
    s.want = s.have
    if s.prep and tv > 0 then
      local miss = o.w5 * Pc.MARGE / 1000 - dtot
      if miss > 0 then s.want = s.have + math.min(Pc.PREP_TURRETS, ceil(miss / tv)) end
    end
    s.front = (ctx.front or {})[o.key]
    if s.prep ~= was then
      evs[#evs + 1] = { kind = s.prep and "ouvert" or "ferme", key = o.key, w5 = o.w5, d = dtot, rho = rho, eta = o.eta,
        have = s.have, want = s.want }
    end
    if s.prep then open[#open + 1] = { key = o.key, rho = rho } end
  end
  -- Sites disparus (avant-poste perdu) : leur état tombe (aucun cadre ne survit à son site).
  local keep = {}
  for _, o in ipairs(est.sites) do keep[o.key] = st.sites[o.key] end
  st.sites = keep
  -- 3. Cadres qui retiennent : au plus PREP_MAX, les plus grands écarts.
  table.sort(open, function(a, b)
    if a.rho ~= b.rho then return a.rho > b.rho end
    return a.key < b.key
  end)
  local retain = {}
  for i = 1, math.min(#open, Pc.PREP_MAX) do retain[open[i].key] = true end
  for _, o in ipairs(est.sites) do
    local s = st.sites[o.key]
    local turret_path = s.want > s.have and not (s.front == "refus" or s.front == "plafond" or s.front == "pause"
      or s.front == "repos") and tv > 0
    local recruit_path = (first and first.key == o.key) and recruits_pay > 0 and ctx.recruit_ok ~= false or false
    s.exec = (turret_path or recruit_path) and true or false
    s.nohold = not (s.prep and retain[o.key] and not s.insurm and not ctx.production_first and s.exec)
    s.why = (not s.prep and "couvert") or (s.insurm and "insurmontable") or (ctx.production_first and "production d'abord")
      or (not s.exec and "sans executant") or (not retain[o.key] and "au-dela de " .. Pc.PREP_MAX) or "imminent"
  end
  -- 4. Armée (factions) : alerte d'ÉTAT (cadre de la première vague ouvert), besoin borné, jamais réduit pendant l'alerte.
  local alert = false
  local need = 0
  if (ctx.soldiers_max or 0) > 0 and first and st.sites[first.key].prep then
    alert = true
    local miss = first.w5 * Pc.MARGE / 1000 - first.d
    need = (miss > 0 and sv > 0) and ceil(miss / sv) or 0
    -- Équipements DÉJÀ au coffre : payés, hors budget ; au-delà, le fer libre au-dessus de la réserve de production, en rampe.
    local cap = math.min(ctx.soldiers_max, (ctx.soldiers or 0) + (ctx.kits_stock or 0)
      + Pc.affordable(ctx.iron, ctx.reserve, ctx.kit_iron, first.eta))
    st.army_cap = cap -- lu par l'armée : le recrutement d'un raid reste sous le même budget
    if need > cap then need = cap end
  else
    st.army_cap = 0
  end
  if alert and st.alert and (st.army_need or 0) > need then need = st.army_need end
  if alert ~= (st.alert or false) or need ~= (st.army_need or 0) then
    evs[#evs + 1] = { kind = "armee", alert = alert, need = need, was = st.army_need or 0, key = first and first.key }
  end
  st.alert, st.army_need = alert, need
  st.insurm_first = (first and st.sites[first.key].insurm) or false
  -- Armée visée à moyen terme (sans priorité de défense) : la vague à 15 min contre les tourelles.
  local soon = 0
  if (ctx.soldiers_max or 0) > 0 and sv > 0 then
    for _, o in ipairs(est.sites) do
      if o.w15 > 0 and o.w15 * 1000 >= Pc.RHO_IN * o.d then
        local n = ceil((o.w15 * Pc.MARGE / 1000 - o.d) / sv)
        if n > soon then soon = n end
      end
    end
    if soon > ctx.soldiers_max then soon = ctx.soldiers_max end
  end
  st.army_soon = soon
  -- Regroupement : UN point, du côté de la première vague (repli au QG si elle est insurmontable : lu par l'armée).
  st.muster_site = first and { x = first.x, y = first.y, tx = first.tx, ty = first.ty } or nil
  st.events = evs
  st.tick = tick
  return st
end

--- Point de regroupement : à MUSTER_R tuiles du site vers la menace (au tiers de la distance au plus) ; le site sans direction.
function Pc.muster(site)
  if not site then return nil end
  if not (site.tx and site.ty) then return { x = site.x, y = site.y } end
  local dx, dy = site.tx - site.x, site.ty - site.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1 then return { x = site.x, y = site.y } end
  local r = Pc.MUSTER_R
  if r > d / 3 then r = d / 3 end
  return { x = site.x + dx / d * r, y = site.y + dy / d * r }
end

--- Lignes « tourelles d'avance » pour le front (C10) : un site en « préparer » qui veut des tourelles et n'est pas insurmontable.
--- { { key = "prev:<site>", site, x, y, have, want } } triées par clé.
function Pc.front_rows(st, keys)
  local out = {}
  for _, k in ipairs(keys or {}) do
    local s = st.sites[k]
    if s and s.prep and not s.insurm and (s.want or 0) > (s.have or 0) then
      local x, y = s.x, s.y
      if s.tx and s.ty then
        local dx, dy = s.tx - s.x, s.ty - s.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d >= 1 then
          local r = math.min(Pc.PREP_OFFSET, d / 2)
          x, y = s.x + dx / d * r, s.y + dy / d * r
        end
      end
      out[#out + 1] = { key = "prev:" .. k, site = k, x = x, y = y, have = s.have, want = s.want }
    end
  end
  return out
end

--- Lignes pour la pile (cadre « preparer ») : { { id, have, want, exec, nohold, why } } triées par clé.
function Pc.pile_rows(st, keys)
  local out = {}
  for _, k in ipairs(keys or {}) do
    local s = st.sites[k]
    if s and s.prep then
      out[#out + 1] = { id = k, have = s.have or 0, want = math.max(s.want or 0, (s.have or 0) + 1), exec = s.exec,
        nohold = s.nohold, why = s.why }
    end
  end
  return out
end

--- Porte du RAID préventif contre un champ. field = { x, y, r (rayon du champ) }, need (soldats), est (Pv.estimate), ctx = {
--- soldier_value, mobile_left (PV des soldats qui restent), hbar } ; st (Pc) pour la première vague. Rend ok, raison, gain, cout.
function Pc.raid_gate(st, est, field, need, ctx)
  ctx = ctx or {}
  local r2 = (field.r or 24) ^ 2
  local gain = 0
  for _, o in ipairs(est.sites or {}) do
    for _, n in ipairs(o.nests) do
      if (n.x - field.x) ^ 2 + (n.y - field.y) ^ 2 <= r2 then gain = gain + n.u end
    end
  end
  local hbar = (est.mix and est.mix.hbar) or ctx.hbar or 0
  gain = gain * hbar * Pc.RAID_H
  local cost = (need or 0) * (ctx.soldier_value or 0)
  if gain <= 0 then return false, "champ sans vague (aucune pollution ne l'atteint)", gain, cost end
  if cost > 0 and gain * 1000 < Pc.RAID_RATIO * cost then return false, "vaut moins qu'il n'engage", gain, cost end
  -- Aucune AUTRE vague imminente ne dépasse les tourelles + les soldats qui restent.
  for _, o in ipairs(est.sites or {}) do
    local other = 0
    for _, n in ipairs(o.nests) do
      if (n.x - field.x) ^ 2 + (n.y - field.y) ^ 2 > r2 then other = other + n.u end
    end
    if other > 0 and o.eta and o.eta <= Pv.H_COURT and o.rate > 0 then
      local w_other = o.w5 * other / o.rate
      if w_other * 1000 >= Pc.RHO_IN * (o.d + (ctx.mobile_left or 0)) then
        return false, "autre vague imminente sur " .. tostring(o.key), gain, cost
      end
    end
  end
  return true, "vaut " .. math.floor(gain) .. " PV evites pour " .. math.floor(cost) .. " engages", gain, cost
end

return Pc
