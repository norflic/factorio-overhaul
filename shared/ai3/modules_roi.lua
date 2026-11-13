--[[
  Lot S42 MODULES-ROI (chantier 2.2 du DC, partie de 4 h 15 en 0.7.96) : « les modules ne sont posés que partiellement, sans calcul
  de rentabilité ».

  POURQUOI (journal de la partie, lignes [FO-MODULES]) : 11 ordres de pose en 4 h 15 pour 5 équipes. La disposition du stock
  (shared/ai3/modules_stock.lua, Ms.plan) : (1) garde 4 modules par sorte au coffre et (2) exige de quoi remplir TOUS les
  emplacements libres d'une machine avec UNE sorte (38 refus « tous promis ou sous la réserve » avec 1 à 15 modules au coffre) ;
  (3) refuse toute machine arrêtée, y compris celle qui attend ses ingrédients, où la productivité rapporte justement ; (4) classe
  les modules par la seule sortie de plus (vitesse x productivité), sans regarder ce que la vitesse de plus consomme ; (5) ne fait
  jamais fabriquer de module (seul le levier « equiper » le fait, et il refuse « retour 67 min > 28 »).

  Règle PURE (Lua pur, aucune API du jeu, aucun nom d'objet, de recette ni de module : tout vient du relevé des prototypes ;
  listes triées, aucun pairs décisionnel, aucun temps mesuré).

  Roi.choose : pour UNE machine, productivité ou vitesse ? Le gain est compté en valeur de matière par minute (MU, Ca.values :
  le coût en matière brute d'un objet par ses recettes), selon l'état observé de la machine :
    - « sortie » (sortie pleine) ou « arret » : rien, aucun module n'ajoute de débit ;
    - « entrees » (la machine attend ses ingrédients) : le débit est celui des entrées ; la vitesse n'ajoute rien, la productivité
      ajoute (p1 - p0) de sortie sans entrée de plus. Productivité seulement, si la recette est admise par la limitation du module ;
    - « goulot » (la machine tourne, la fabrication suivante est déjà servie, la sortie est vide) : les entrées abondent, elles ne
      coûtent rien de plus : gain = sortie de plus = c x V_sortie x (s1 p1 - s0 p0) ; la vitesse gagne en général ;
    - « tourne » ou état non lu : chaque fabrication de plus PAIE ses entrées : gain net = c x [ (s1 p1 - s0 p0) x V_sortie
      - (s1 - s0) x V_entrees ]. Une recette dont la valeur est surtout de la matière brute (four, circuit, science, intermédiaire
      coûteux) penche vers la productivité ; une recette dont la valeur est surtout du temps de machine penche vers la vitesse.
  La famille est décidée sur les modules du relevé (emplacements libres remplis), PUIS le module est pris au stock dans cette
  famille (pose partielle admise : n = min(libres, disponibles)) ; s'il n'y en a pas, la règle rend un SOUHAIT de fabrication avec
  son retour sur investissement (coût en matière du module / gain par minute).

  Roi.plan : la passe de l'équipe (même forme d'ordres que Ms.plan, lue par script/ai3/modules_stock.lua) : bornée par
  max_orders ordres de BATCH_MAX machines par relevé ; souhaits de fabrication bornés (max_wants, WANT_MODULES modules, retour
  sous HORIZON_MIN).
]]

local Lv = require("shared.ai3.leviers")
local Ms = require("shared.ai3.modules_stock")

local Roi = {}

Roi.PROD = "productivite"
Roi.SPEED = "vitesse"
Roi.EPS = 1e-9
Roi.HORIZON_MIN = 60    -- un souhait de fabrication n'est émis que si le module se rembourse en moins d'une heure de jeu
Roi.WANT_MODULES = 8    -- modules demandés à la fabrication par souhait (au moins une machine entière)
Roi.MAX_WANTS = 1       -- souhaits par relevé
Roi.RESERVE = 0         -- aucun module gardé au coffre : « équiper toutes les machines éligibles à partir du stock »

Roi.S_OUT = "sortie"    -- sortie pleine
Roi.S_IN = "entrees"    -- attend ses ingrédients
Roi.S_NECK = "goulot"   -- tourne, entrées pleines, sortie vide
Roi.S_RUN = "tourne"    -- tourne, charge non lue ou mêlée
Roi.S_STOP = "arret"    -- arrêtée pour une autre cause (courant, recette…)
Roi.S_NONE = "inconnu"  -- statut non lu

local function fmt(x)
  if x == nil then return "-" end
  if x ~= x then return "nan" end
  if x == math.huge then return "inf" end
  if x == -math.huge then return "non admise" end
  if math.abs(x) >= 100 then return string.format("%.0f", x) end
  return string.format("%.2f", x)
end
Roi.fmt = fmt

--- Famille d'un module, lue à ses effets (centièmes) : productivité s'il en donne, sinon vitesse s'il en donne, sinon rien.
function Roi.family(eff)
  if not eff then return nil end
  if (eff.productivity or 0) > 0 then return Roi.PROD end
  if (eff.speed or 0) > 0 then return Roi.SPEED end
  return nil
end

--- Le module va-t-il dans la machine pour cette recette ? (chaque effet non nul permis ; recette dans la limitation s'il y en a une)
function Roi.fits(m, allowed, recipe)
  local keys = {}
  for k, x in pairs(m.eff or {}) do if x and x ~= 0 then keys[#keys + 1] = k end end
  table.sort(keys)
  for _, k in ipairs(keys) do
    if (allowed or {})[k] ~= true then return false end
  end
  if recipe and m.limit and not m.limit[recipe] then return false end
  return true
end

--- État d'un groupe de machines d'après son relevé de statut `run` = { sampled, working, short_in, bott, loads, stop }.
function Roi.state(run)
  if not run or (run.sampled or 0) <= 0 then return Roi.S_NONE end
  if (run.working or 0) > 0 then
    if (run.loads or 0) > 0 and 2 * (run.bott or 0) >= run.loads then return Roi.S_NECK end
    return Roi.S_RUN
  end
  if (run.short_in or 0) > 0 and 2 * run.short_in >= run.sampled then return Roi.S_IN end
  if (run.full or 0) > 0 and 2 * run.full >= run.sampled then return Roi.S_OUT end
  return Roi.S_STOP
end

--- Facteurs additifs (centièmes) par défaut, pour un appel hors du barème du mod : s0, p0, e0, s1, p1, e1.
local function plain_factors(m, n)
  local e = m.eff or {}
  return 100, 100, 100, math.max(20, 100 + n * (e.speed or 0)), 100 + n * (e.productivity or 0), math.max(20, 100 + n * (e.consumption or 0))
end

--- Gain (MU par minute et par machine) de facteurs (s0, p0) → (s1, p1) selon l'état. c = fabrications par minute au facteur 1 ;
--- v_out, v_in = valeur des produits et des ingrédients d'UNE fabrication.
function Roi.gain(state, c, v_out, v_in, s0, p0, s1, p1)
  if state == Roi.S_OUT or state == Roi.S_STOP then return 0 end
  if state == Roi.S_IN then
    if p0 <= 0 then return 0 end
    -- débit fixé par les entrées (c x s0 au plus) : la sortie suit la productivité seule
    return c * (s0 / 100) * v_out * (p1 - p0) / 100
  end
  if state == Roi.S_NECK then return c * v_out * (s1 * p1 - s0 * p0) / 10000 end
  return c * (v_out * (s1 * p1 - s0 * p0) / 10000 - v_in * (s1 - s0) / 100)
end

--- Choix pour UNE machine.
--- mc = {
---   slots, filled             emplacements et modules déjà posés (nombres)
---   allowed = { [effet] = vrai }, recipe = nom | nil (foreuse : nil)
---   c, v_out, v_in            fabrications par minute au facteur 1, valeur (MU) des produits et des ingrédients d'une fabrication
---                             (v_out nil : valeurs non lues ; la limitation des données décide alors)
---   state                     Roi.S_*
---   cands = { { name, eff = { speed, productivity, consumption } (centièmes), limit = { [recette] = vrai } | nil,
---                 have = disponibles au stock, cost = MU | nil, craftable = vrai | nil } }   (ordre libre : retriés par nom)
---   factors = function(nom, n) -> s0, p0, e0, s1, p1, e1 | nil   (barème du mod ; défaut : additif)
---   only = famille imposée | nil }
--- Rend { family, module, n, gain, s0, p0, e0, s1, p1, e1, why } (pose depuis le stock), ou { family, want = { module, n, gain,
--- payback, cost }, why } (rien au stock dans la famille), ou { why } (rien à poser).
function Roi.choose(mc)
  local free = (mc.slots or 0) - (mc.filled or 0)
  if free <= 0 then return { why = "aucun emplacement libre" } end
  local state = mc.state or Roi.S_NONE
  if state == Roi.S_OUT then return { why = "sortie pleine : aucun module n'ajoute de debit" } end
  if state == Roi.S_STOP then return { why = "machine arretee" } end
  local mods = {}
  for _, m in ipairs(mc.cands or {}) do mods[#mods + 1] = m end
  table.sort(mods, function(a, b) return a.name < b.name end)
  local valued = mc.v_out ~= nil and mc.c ~= nil
  local c, v_out, v_in = mc.c or 1, mc.v_out or 1, mc.v_in or 0
  local function eval(m, n)
    local s0, p0, e0, s1, p1, e1
    if mc.factors then s0, p0, e0, s1, p1, e1 = mc.factors(m.name, n) end
    if not s0 then s0, p0, e0, s1, p1, e1 = plain_factors(m, n) end
    return { m = m, n = n, fam = Roi.family(m.eff), gain = Roi.gain(state, c, v_out, v_in, s0, p0, s1, p1),
      s0 = s0, p0 = p0, e0 = e0, s1 = s1, p1 = p1, e1 = e1 }
  end
  -- 1. famille : sur les modules du relevé qui vont dans la machine, emplacements libres remplis
  local full, any_prod, any_fit = {}, false, false
  for _, m in ipairs(mods) do
    local fam = Roi.family(m.eff)
    if fam and (not mc.only or mc.only == fam) and Roi.fits(m, mc.allowed, mc.recipe) then
      any_fit = true
      if fam == Roi.PROD then any_prod = true end
      full[#full + 1] = eval(m, free)
    end
  end
  if not any_fit then return { why = "aucun module admis (effet ou recette non permis)" } end
  local family, why_f
  if state == Roi.S_IN then
    if not any_prod then return { why = "attend ses entrees : la vitesse n'ajouterait rien, productivite non admise" } end
    family, why_f = Roi.PROD, "attend ses entrees : la productivite seule ajoute de la sortie"
  elseif not valued and state ~= Roi.S_NECK then
    family = any_prod and Roi.PROD or Roi.SPEED
    why_f = any_prod and "valeurs non lues : recette admise par la limitation du module" or "valeurs non lues : productivite non admise"
  else
    local best = { [Roi.PROD] = -math.huge, [Roi.SPEED] = -math.huge }
    for _, o in ipairs(full) do
      if o.gain > best[o.fam] then best[o.fam] = o.gain end
    end
    local gp, gs = best[Roi.PROD], best[Roi.SPEED]
    if gp <= Roi.EPS and gs <= Roi.EPS then return { why = "aucun gain (productivite " .. fmt(gp) .. ", vitesse " .. fmt(gs) .. " MU/min)" } end
    if state == Roi.S_NECK then
      -- la machine est le goulot : à gain égal la vitesse
      family = (gp > gs + Roi.EPS) and Roi.PROD or Roi.SPEED
      why_f = string.format("goulot (entrees pleines, sortie vide) : vitesse %s contre productivite %s MU/min", fmt(gs), fmt(gp))
    else
      -- chaque fabrication de plus paie ses entrées : à gain égal la productivité
      family = (gs > gp + Roi.EPS) and Roi.SPEED or Roi.PROD
      why_f = string.format("gain net d'entrees : productivite %s contre vitesse %s MU/min", fmt(gp), fmt(gs))
    end
  end
  -- 2. module : le meilleur de la famille au stock (pose partielle admise), à égalité le premier par nom
  local pick = nil
  for _, m in ipairs(mods) do
    if Roi.family(m.eff) == family and (m.have or 0) >= 1 and Roi.fits(m, mc.allowed, mc.recipe) then
      local o = eval(m, math.min(free, math.floor(m.have)))
      local per = o.gain / o.n
      if o.gain > Roi.EPS and (not pick or per > pick.per + Roi.EPS) then pick = o pick.per = per end
    end
  end
  if pick then
    return { family = family, module = pick.m.name, n = pick.n, gain = pick.gain, s0 = pick.s0, p0 = pick.p0, e0 = pick.e0,
      s1 = pick.s1, p1 = pick.p1, e1 = pick.e1, why = why_f }
  end
  -- 3. rien au stock : souhait de fabrication, le retour le plus court parmi les modules fabricables au coût lu
  local want = nil
  for _, o in ipairs(full) do
    if o.fam == family and o.m.craftable and (o.m.cost or 0) > 0 and o.gain > Roi.EPS then
      local payback = o.n * o.m.cost / o.gain
      if not want or payback < want.payback - Roi.EPS then
        want = { module = o.m.name, n = o.n, gain = o.gain, payback = payback, cost = o.m.cost, s0 = o.s0, p0 = o.p0, e0 = o.e0,
          s1 = o.s1, p1 = o.p1, e1 = o.e1 }
      end
    end
  end
  return { family = family, want = want, why = why_f .. " ; aucun module de cette famille au stock" }
end

--- Valeur (MU) des ingrédients et des produits d'une fabrication de la recette r, d'après mu = { [objet] = MU }. Rend v_in, v_out
--- (nil, nil si un produit n'a pas de valeur ; un ingrédient sans valeur compte 0).
function Roi.values(r, mu)
  local vin, vout, seen = 0, 0, false
  for _, i in ipairs(r.ingredients or {}) do vin = vin + (mu[i.name] or 0) * (i.amount or 0) end
  for _, p in ipairs(r.products or {}) do
    if mu[p.name] then
      vout = vout + mu[p.name] * (p.amount or 0)
      seen = true
    end
  end
  if not seen then return nil, nil end
  return vin, vout
end

--- La passe de l'équipe. `v` : celui de Ms.plan (stock, committed, machines, drills, short, supply, taken, held, power_room_kw,
--- threat, danger, max_orders), plus :
---   reserve = n | nil (Roi.RESERVE)        made = function(objet) -> vrai si l'objet a un débit mesuré | nil
---   craftable = function(module) -> vrai si l'équipe sait le fabriquer | nil          horizon, max_wants, want_modules
---   (g.run porte en plus short_in, full, bott, loads ; g.units_in = unités qui attendent leurs entrées)
--- Rend (ordres, refus, info, souhaits) : ordres au format de Ms.plan (+ family, state) ; souhaits = { { key, module, per, n,
--- payback, gain, entity, recipe, resource, where, item, units, why, … } } triés par retour.
function Roi.plan(Ca, D, v)
  local L = D and D.lv
  local orders, refus, wants = {}, {}, {}
  local info = { avail = {}, stock_total = 0, free_total = 0 }
  if not (L and #L.cand > 0) then return orders, refus, info, wants end
  local avail = {}
  for _, nm in ipairs(L.cand) do
    local have = (v.stock or {})[nm] or 0
    info.stock_total = info.stock_total + have
    avail[nm] = Ms.available(have, (v.committed or {})[nm], v.reserve or Roi.RESERVE)
    info.avail[nm] = avail[nm]
    info.free_total = info.free_total + avail[nm]
  end
  local taken, short, mu = v.taken or {}, v.short or {}, D.mu or {}
  local supply = v.supply
  local function served(item)
    if type(supply) == "function" then return supply(item) and true or false end
    if type(supply) == "table" then return supply[item] == true end
    return true
  end
  local function refuse(key, nm, why) refus[#refus + 1] = { key = key, module = nm, why = why } end
  local opts = {}

  local function consider(g, is_drill)
    local ent = is_drill and D.drill_by[g.entity] or D.maker_by[g.entity]
    local sl = L.slots[g.entity]
    if not ent or not sl or (g.n or 0) <= 0 then return end
    local filled = Lv.filled(g.mods or {})
    local free = sl.n - filled
    if free <= 0 then return end
    local item, r
    if is_drill then
      item = g.resource
      if not item or not D.res[item] or D.res[item].fluid then return end
    else
      r = D.recipes[g.recipe]
      if not r or r.fluid or #r.products == 0 then return end
      item = r.products[1].name
    end
    local where = is_drill and (g.deposit ~= nil and tostring(g.deposit) or Ca.HQ) or (g.where or Ca.HQ)
    local key = Ms.key(g, is_drill, where)
    if taken[key] then return end
    local state = Roi.state(g.run)
    if state == Roi.S_OUT or state == Roi.S_STOP then
      refuse(key, nil, "machine arretee : " .. tostring(g.run and g.run.stop or "sans travail"))
      return
    end
    local units = g.units or {}
    if state == Roi.S_IN then
      units = g.units_in or {}
      -- une machine qui attend ses entrées n'est équipée que si son objet se fabrique vraiment (débit mesuré) : pas de module sur une chaîne morte
      if not (v.made and v.made(item)) then
        refuse(key, nil, "attend ses entrees et aucun debit mesure de " .. tostring(item))
        return
      end
    end
    local nunits = #units
    if nunits <= 0 then return end
    if where ~= Ca.HQ then
      if v.threat then refuse(key, nil, "menace : machines du QG seulement") return end
      if (v.danger or {})[where] then refuse(key, nil, "lieu " .. where .. " dangereux") return end
    end
    local held = v.held and v.held(key) or nil
    if held then refuse(key, nil, held) return end
    local c, v_in, v_out
    if is_drill then
      c = Ca.drill_per_min(D, ent, item)
      v_in, v_out = 0, mu[item]
    else
      c = Ca.crafts_per_min(ent, r)
      v_in, v_out = Roi.values(r, mu)
    end
    local list = {}
    for _, nm in ipairs(L.cand) do
      local m = L.equip[nm]
      list[#list + 1] = { name = nm, eff = m.eff, limit = m.limit, have = avail[nm], cost = mu[nm],
        craftable = (v.craftable and v.craftable(nm)) and true or nil }
    end
    local ch = Roi.choose({ slots = sl.n, filled = filled, allowed = sl.allowed, recipe = (not is_drill) and r.name or nil,
      c = c, v_out = v_out, v_in = v_in, state = state, cands = list,
      factors = function(nm, n) return Lv.factors_after(D, g.mods, nm, n) end })
    local horizon = v.horizon or Roi.HORIZON_MIN
    -- Repli sur le stock : la famille choisie n'a ni module au coffre ni fabrication rentable (aucun souhait, ou retour au-delà de
    -- l'horizon) : un module de l'autre famille qui dort au coffre est posé s'il rapporte dans l'état observé (jamais pour une machine
    -- qui attend ses entrées : la vitesse n'y ajoute rien).
    if ch.family and not ch.module and state ~= Roi.S_IN and not (ch.want and ch.want.payback <= horizon) then
      local alt = Roi.choose({ slots = sl.n, filled = filled, allowed = sl.allowed, recipe = (not is_drill) and r.name or nil,
        c = c, v_out = v_out, v_in = v_in, state = state, cands = list, only = (ch.family == Roi.PROD) and Roi.SPEED or Roi.PROD,
        factors = function(nm, n) return Lv.factors_after(D, g.mods, nm, n) end })
      if alt.module then
        alt.why = "repli sur le stock (" .. ch.family .. " absente du coffre et non rentable a fabriquer) : " .. tostring(alt.why)
        ch = alt
      end
    end
    local sel = ch.module and ch or ch.want
    if not sel then refuse(key, nil, ch.why) return end
    -- la vitesse demande l'entrée de plus : chaque entrée solide doit être servie (sauf goulot observé : elles sont pleines)
    if ch.family == Roi.SPEED and (not is_drill) and state ~= Roi.S_NECK then
      for _, ing in ipairs(r.ingredients) do
        if not ing.fluid and not served(ing.name) then
          refuse(key, sel.module, "l'entree " .. ing.name .. " manque (vitesse inutile)")
          return
        end
      end
    end
    local rho1 = is_drill and c or Ca.out_per_min(ent, r, item)
    local o = { g = g, is_drill = is_drill, item = item, r = r, ent = ent, where = where, key = key, nm = sel.module, per = sel.n,
      units = units, nunits = nunits, state = state, family = ch.family, gain = sel.gain, why_f = ch.why,
      per_machine = rho1 * (sel.s1 * sel.p1 - sel.s0 * sel.p0) / 10000,
      class = (short[item] or 0) > 0 and Ms.CLASS_SHORT or (is_drill and Ms.CLASS_DRILL or Ms.CLASS_PLAIN),
      gain_module = sel.gain / sel.n, d_kw = (ent.kw or 0) * (sel.e1 - sel.e0) / 100,
      s0 = sel.s0, p0 = sel.p0, e0 = sel.e0, s1 = sel.s1, p1 = sel.p1, e1 = sel.e1 }
    if ch.module then
      opts[#opts + 1] = o
    elseif state ~= Roi.S_IN and sel.payback <= horizon then
      -- souhait de fabrication : jamais pour une machine qui attend ses entrées (son débit réel n'est pas lu, le retour serait inventé)
      o.payback, o.cost = sel.payback, sel.cost
      wants[#wants + 1] = o
    else
      refuse(key, sel.module, ch.why .. (state == Roi.S_IN and "" or (" ; retour " .. fmt(sel.payback) .. " min > " .. fmt(horizon))))
    end
  end

  for _, g in ipairs(v.machines or {}) do consider(g, false) end
  for _, g in ipairs(v.drills or {}) do consider(g, true) end

  table.sort(opts, function(a, b)
    if a.class ~= b.class then return a.class < b.class end
    if a.gain_module ~= b.gain_module then return a.gain_module > b.gain_module end
    if a.key ~= b.key then return a.key < b.key end
    return a.nm < b.nm
  end)

  -- Courant de plus : la marge lue borne le nombre de machines ; non lue, petits pas sur un réseau sain (comme Ms.plan).
  local function power_cap(o, k, room)
    if not (o.ent.energy == "electric" and o.d_kw > Roi.EPS) then return k, nil end
    if room == nil then
      local run = o.g.run
      if not run or (run.sampled or 0) == 0 then return 0, "courant non lu et statut des machines non lu" end
      if (run.starved or 0) > 0 then return 0, "courant non lu et reseau en manque (" .. tostring(run.stop or "low_power") .. ")" end
      return math.min(k, Ms.UNREAD_BATCH), nil
    end
    local fit = math.floor((room + Roi.EPS) / o.d_kw)
    if fit < k then k = fit end
    if k < 1 then return 0, "courant insuffisant (" .. fmt(o.d_kw) .. " kW de plus par machine, marge " .. fmt(room) .. ")" end
    return k, nil
  end
  local function order_of(o, k)
    local d_in = {}
    if not o.is_drill then
      for _, ing in ipairs(o.r.ingredients) do
        if not ing.fluid then d_in[#d_in + 1] = { ing.name, k * Ca.in_per_min(o.ent, o.r, ing.name) * (o.s1 - o.s0) / 100 } end
      end
    end
    local d_fuel = 0
    if (o.ent.kw or 0) > 0 and (D.fuel_kj or 0) > 0 then d_fuel = k * o.d_kw * 60 / D.fuel_kj end
    local g = o.g
    return {
      kind = "equiper", key = o.key, item = o.item, entity = g.entity, recipe = (not o.is_drill) and o.r.name or nil,
      resource = o.is_drill and g.resource or nil, deposit = (o.where ~= Ca.HQ) and o.where or nil, where = o.where, n = k,
      module = o.nm, per = o.per, sig = Lv.sig(g.mods or {}), tier = "equiper", stock = true, class = o.class,
      family = o.family, state = o.state, units = o.units, payback = o.payback,
      d_item = o.item, d_out = k * o.per_machine, d_in = d_in, d_kw = k * o.d_kw, d_fuel = d_fuel,
      factor = { speed = o.s1, productivity = o.p1, energy = o.e1, speed0 = o.s0, productivity0 = o.p0 },
      why = string.format("%s : %d x %s : %d x %s (%s, %s ; %s MU/min par machine%s) ; vitesse x%s productivite x%s",
        o.payback and "fabrication" or "stock", k, g.entity .. "/" .. tostring(o.is_drill and g.resource or g.recipe), o.per, o.nm,
        o.family, o.why_f, fmt(o.gain), o.payback and (", retour " .. fmt(o.payback) .. " min") or "",
        fmt(o.s1 / 100), fmt(o.p1 / 100)) }
  end

  local used, room = {}, v.power_room_kw
  local max_orders = v.max_orders or Ms.MAX_ORDERS
  for _, o in ipairs(opts) do
    if #orders >= max_orders then break end
    if not used[o.key] and avail[o.nm] >= 1 then
      -- le stock a pu baisser depuis le choix (ordres précédents de la passe) : la pose par machine suit ce qui reste
      if avail[o.nm] < o.per then
        local s0, p0, e0, s1, p1, e1 = Lv.factors_after(D, o.g.mods, o.nm, avail[o.nm])
        local k0 = avail[o.nm] / o.per
        o.per, o.gain, o.per_machine = avail[o.nm], o.gain * k0, (o.per_machine / math.max(Roi.EPS, o.s1 * o.p1 - o.s0 * o.p0)) * (s1 * p1 - s0 * p0)
        o.d_kw = (o.ent.kw or 0) * (e1 - e0) / 100
        o.s0, o.p0, o.e0, o.s1, o.p1, o.e1 = s0, p0, e0, s1, p1, e1
      end
      local k = math.min(o.nunits, Ms.BATCH_MAX, math.floor(avail[o.nm] / o.per))
      local why
      k, why = power_cap(o, k, room)
      if k >= 1 then
        used[o.key] = true
        avail[o.nm] = avail[o.nm] - k * o.per
        if room ~= nil and o.ent.energy == "electric" and o.d_kw > 0 then room = room - k * o.d_kw end
        orders[#orders + 1] = order_of(o, k)
      elseif why then
        refuse(o.key, o.nm, why)
      end
    end
  end

  -- Souhaits de fabrication : le retour le plus court d'abord, puis la clé.
  table.sort(wants, function(a, b)
    if a.payback ~= b.payback then return a.payback < b.payback end
    if a.key ~= b.key then return a.key < b.key end
    return a.nm < b.nm
  end)
  local out_w = {}
  for _, o in ipairs(wants) do
    if #out_w >= (v.max_wants or Roi.MAX_WANTS) then break end
    local k = math.min(o.nunits, Ms.BATCH_MAX, math.max(1, math.floor((v.want_modules or Roi.WANT_MODULES) / o.per)))
    local why
    k, why = power_cap(o, k, room)
    if k >= 1 then
      local w = order_of(o, k)
      w.stock = nil
      out_w[#out_w + 1] = w
    elseif why then
      refuse(o.key, o.nm, why)
    end
  end

  table.sort(refus, function(a, b)
    if a.key ~= b.key then return a.key < b.key end
    return tostring(a.module) < tostring(b.module)
  end)
  return orders, refus, info, out_w
end

return Roi
