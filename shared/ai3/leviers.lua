--[[
  Lot LEVIERS « les leviers de capitalisation autres que poser des machines » (demande du DC, 27/10, vers 21 h 30) :
  « la recherche des drones pour augmenter la vitesse de construction et la précision des améliorations, peut-être que
  c'est aussi une manière de capitaliser. Il faudrait définir plein de conditions différentes de comment capitaliser en
  quelles circonstances en fonction du gain que ça peut apporter » ; et, si tous les points de ressources sont pris ou
  trop dangereux, « c'est peut-être plus rentable de ajouter des modules de vitesse à des fours ou des modules de
  productivité à des foreuses ».

  CATALOGUE de leviers LUS DANS LES DONNÉES (aucun nom du jeu ici : anti-échelle, tests/iag_test.lua §8). Règle PURE,
  appelée par shared/ai3/capitalisation.lua (Ca.options, Ca.apply, Ca.decide). Deux sortes d'option, qui entrent dans le
  MÊME choix glouton que les machines (retour T = coût ÷ gain, budget, bras) :

    « modules »  insérer des modules dans des machines DÉJÀ POSÉES (fours, assembleurs, foreuses) qui ont des emplacements
                 libres. Données : effets de chaque module (vitesse, productivité, énergie, en centièmes), emplacements et
                 effets permis de chaque machine, recettes permises. Barème D-17 de MOD-1 (shared/content/module_mult.lua) :
                 facteurs de vitesse, de productivité et d'énergie MULTIPLIÉS, énergie au plafond comprise. Gain = sortie
                 de plus que la demande absorbe (ou 25 % d'avance), valeur de l'objet × part de l'étage, moins l'énergie
                 de plus ; une vitesse de plus exige l'entrée de plus (minerai livré, ingrédient couvert) ; coût = modules
                 (MU) + pose (PNJ-s).
    « techno »   une recherche à effet (R.LEVER_EFFECT de reglages.lua : productivité des foreuses, vitesse ou productivité
                 des laboratoires, vitesse du travail des PNJ), chiffrée sur la capacité qu'elle augmente. Coût = packs et
                 secondes de laboratoire (MU), retard = temps de recherche aux laboratoires posés ; gain = capacité de plus
                 × valeur, ou bras gagnés quand la construction est le goulot.

  CIRCONSTANCES (res.repli) : un gisement est « pris ou dangereux » quand aucune place libre ne reste sur un gisement
  sûr (couverts, dangereux, interdits, épuisés, tous comptés) ; une ressource sans gisement connu est « absente » ; la
  construction est « goulot » quand les bras libres manquent ou que le budget de bras est épuisé. Le repli n'est pas une
  règle de plus : quand l'extraction n'a plus d'option, ce sont ces leviers qui ont le meilleur retour, et le compte
  rendu dit POURQUOI (chiffres, aucune horloge : même entrée, même sortie).

  Déterminisme : listes triées, entiers du barème de MOD-1, aucun temps mesuré.
]]

local MM = require("shared.content.module_mult")
local R = require("shared.ai3.reglages")

local Lv = {}

Lv.REPLI_REFUS = 3        -- refus de leviers gardés dans le compte rendu du repli
-- Retour accepté (min) quand l'extraction de la chaîne n'a plus aucune place : sans autre investissement pour la même
-- demande, un levier qui se rembourse avant la durée de vie d'un gisement (Ca.H_LIFE) vaut mieux que rien ; sous menace,
-- divisé comme T_max (Ca.THREAT_DIV). Hors repli : T_max du caractère, comme les machines.
Lv.REPLI_TMAX = nil       -- nil : Ca.H_LIFE
Lv.POSE_PER_MODULE = nil  -- nil : la pose d'un module compte comme celle d'une entité (work_of de la règle)

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function set_of(list)
  local s = {}
  for _, v in ipairs(list or {}) do s[v] = true end
  return s
end

local function fmt(x)
  if x == nil then return "-" end
  if x ~= x then return "nan" end
  if x == math.huge then return "inf" end
  if math.abs(x) >= 100 then return string.format("%.0f", x) end
  return string.format("%.2f", x)
end

---------------------------------------------------------------------------------------------------
-- Données : Lv.build(lv, dump, D) -> D.lv
---------------------------------------------------------------------------------------------------
--- lv = {
---   modules = { [objet] = { effects = { speed = cts, productivity = cts, consumption = cts, pollution = cts },
---                           limit = { recette, … } (absente : toutes) } }   (centièmes ENTIERS, MM.runtime_cents)
---   slots = { [entité] = { n = emplacements, allowed = { [effet] = vrai } } }
---   techs = { [technologie] = { { type = …, modifier = … }, … } } }
--- dump.techs[t] : count, time, ingredients { {pack, n} }, prerequisites (relevé de la règle).
function Lv.build(lv, dump, D)
  local L = { equip = {}, cand = {}, slots = {}, techs = {}, tech_list = {}, all_techs = (dump and dump.techs) or {} }
  if type(lv) ~= "table" then return L end
  for _, name in ipairs(sorted_keys(lv.equip)) do
    local m = lv.equip[name]
    local e = {}
    local keys = {}
    for _, ef in ipairs(sorted_keys(m.effects)) do
      local v = m.effects[ef]
      if v and v ~= 0 then
        e[ef] = v
        keys[#keys + 1] = ef
      end
    end
    L.equip[name] = { name = name, eff = e, keys = keys, limit = m.limit and set_of(m.limit) or nil }
    -- candidat : un module qui augmente la vitesse ou la productivité
    if (e.speed or 0) > 0 or (e.productivity or 0) > 0 then L.cand[#L.cand + 1] = name end
  end
  for _, ent in ipairs(sorted_keys(lv.slots)) do
    local s = lv.slots[ent]
    if (s.n or 0) > 0 then L.slots[ent] = { n = s.n, allowed = s.allowed or {} } end
  end
  for _, t in ipairs(sorted_keys(lv.techs)) do
    local effs = {}
    for _, e in ipairs(lv.techs[t]) do
      local kind = R.LEVER_EFFECT[e.type]
      if kind and (e.modifier or 0) > 0 then effs[#effs + 1] = { kind = kind, modifier = e.modifier, type = e.type } end
    end
    local spec = (dump.techs or {})[t]
    if #effs > 0 and spec and spec.enabled ~= false and not spec.hidden then
      L.techs[t] = { effects = effs, count = spec.count or 1, time = spec.time or 1, ingredients = spec.ingredients or {},
        prerequisites = spec.prerequisites or {} }
      L.tech_list[#L.tech_list + 1] = t
    end
  end
  return L
end

---------------------------------------------------------------------------------------------------
-- Modules : facteurs (barème D-17)
---------------------------------------------------------------------------------------------------
--- Liste des effets (centièmes) des modules posés `mods` = { [objet] = nombre } plus `extra` modules `add` : la forme
--- attendue par MM.complements.
local function effect_list(L, mods, add, add_n)
  local list = {}
  for _, nm in ipairs(sorted_keys(mods)) do
    local m = L.equip[nm]
    if m then
      for _ = 1, mods[nm] do list[#list + 1] = { speed = m.eff.speed, consumption = m.eff.consumption, productivity = m.eff.productivity } end
    end
  end
  if add then
    local m = L.equip[add]
    for _ = 1, add_n or 0 do list[#list + 1] = { speed = m.eff.speed, consumption = m.eff.consumption, productivity = m.eff.productivity } end
  end
  return list
end

--- Facteurs (centièmes) d'une liste de modules : vitesse, productivité, énergie.
local function factors_of(list)
  if #list == 0 then return 100, 100, 100 end
  local c = MM.complements(list)
  return c.speed.t, c.productivity.t, c.consumption.t
end

--- Facteurs d'un groupe de machines posées (vitesse, productivité) en rapport à 1 : le plan les applique aux machines
--- qui portent déjà des modules. Sans module : 1, 1.
function Lv.factors(D, g)
  local L = D.lv
  if not (L and g.mods and next(g.mods)) then return 1, 1 end
  local s, p = factors_of(effect_list(L, g.mods))
  return s / 100, p / 100
end

function Lv.sig(mods)
  local parts = {}
  for _, nm in ipairs(sorted_keys(mods)) do parts[#parts + 1] = nm .. "*" .. mods[nm] end
  return #parts > 0 and table.concat(parts, "+") or "-"
end

---------------------------------------------------------------------------------------------------
-- Circonstances
---------------------------------------------------------------------------------------------------
--- État des gisements d'une ressource dans le plan : places libres sur un gisement sûr et non couvert.
local function sites_state(Ca, ctx, plan, k)
  local memo = ctx.lv_sites[k]
  if memo then return memo end
  local deps = ctx.dep_by_res[k] or {}
  local d = Ca.H.best_drill(ctx, k)
  local st = { total = #deps, danger = 0, forbid = 0, covered = 0, dead = 0, free_sites = 0, free_places = 0 }
  for _, f in ipairs(deps) do
    local why = Ca.usable(ctx, f, "couvrir")
    if why then
      if f.danger then st.danger = st.danger + 1 else st.forbid = st.forbid + 1 end
    elseif plan.dead[tostring(f.id)] then
      st.dead = st.dead + 1
    elseif d then
      local _, free, kappa = Ca.deposit_state(ctx, plan, f, d)
      if free > 0 and kappa < Ca.KAPPA then
        st.free_sites = st.free_sites + 1
        st.free_places = st.free_places + free
      else
        st.covered = st.covered + 1
      end
    else
      st.forbid = st.forbid + 1
    end
  end
  st.blocked = st.free_places == 0
  if st.total == 0 then
    st.text = "aucun gisement connu de " .. k
    st.absent = true
  else
    st.text = string.format("%d gisement(s) de %s : %d couvert(s), %d dangereux, %d interdit(s), %d epuise(s), 0 place libre",
      st.total, k, st.covered, st.danger, st.forbid, st.dead)
  end
  ctx.lv_sites[k] = st
  return st
end

--- Ressources brutes derrière un objet (recettes choisies du besoin).
local function raws_of(ctx, req, item, out, seen)
  if seen[item] then return out end
  seen[item] = true
  if ctx.D.res[item] then
    out[item] = true
    return out
  end
  local r = req.rec[item]
  if r then
    for _, ing in ipairs(r.ingredients) do
      if not ing.fluid then raws_of(ctx, req, ing.name, out, seen) end
    end
  end
  return out
end

--- Repli de l'objet : ressources brutes bloquées derrière lui (liste triée de { resource, text }), ou nil.
local function repli_of(Ca, ctx, plan, req, item)
  local raws = sorted_keys(raws_of(ctx, req, item, {}, {}))
  local blocked = {}
  for _, k in ipairs(raws) do
    local st = sites_state(Ca, ctx, plan, k)
    if st.blocked then blocked[#blocked + 1] = { resource = k, text = st.text, absent = st.absent or nil } end
  end
  if #blocked == 0 then return nil end
  return blocked
end

--- Retour accepté d'un levier : celui du caractère, ou, en repli, l'horizon Ca.H_LIFE (jamais en dessous du caractère).
function Lv.tmax(Ca, ctx, blocked)
  if not blocked then return ctx.ch.tmax end
  local h = (Lv.REPLI_TMAX or Ca.H_LIFE) / (ctx.threat and Ca.THREAT_DIV or 1)
  return math.max(ctx.ch.tmax, h)
end

local function repli_text(blocked)
  local parts = {}
  for _, b in ipairs(blocked) do parts[#parts + 1] = b.text end
  return "repli : " .. table.concat(parts, " ; ")
end

--- La construction est-elle le goulot ? (bras libres épuisés ou budget de bras vide)
local function build_bottleneck(ctx)
  if not ctx.labor_limited then return false end
  local free = ctx.input.idle or 0
  return free < 1 or ctx.labor <= 0
end

---------------------------------------------------------------------------------------------------
-- Modules dans les machines posées
---------------------------------------------------------------------------------------------------
local function filled_count(mods)
  local n = 0
  for _, nm in ipairs(sorted_keys(mods)) do n = n + mods[nm] end
  return n
end

--- Un module peut-il aller dans cette machine (effets permis) pour cette recette ?
local function module_fits(L, m, slots, recipe)
  for _, ef in ipairs(m.keys) do
    if slots.allowed[ef] ~= true then return false end
  end
  if recipe and m.limit and not m.limit[recipe] then return false end
  return true
end

local function group_options(Ca, ctx, plan, req, g, is_drill, out)
  local D, L, H = ctx.D, ctx.D.lv, Ca.H
  local ent = is_drill and D.drill_by[g.entity] or D.maker_by[g.entity]
  local sl = L.slots[g.entity]
  if not ent or not sl or (g.n or 0) <= 0 then return end
  local mods = g.mods or {}
  local free = sl.n - filled_count(mods)
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
  local Ri = req.R[item] or 0
  if Ri <= 0 then return end
  local kind_name = is_drill and ("foreuse " .. g.entity) or (g.entity .. "/" .. tostring(g.recipe))
  local key = string.format("equiper:%s:%s:%s:%s", g.entity, tostring(is_drill and g.resource or g.recipe), where,
    Lv.sig(mods))
  if Ca.taken(plan, key) then return end
  -- Où : au QG, ou sur un gisement (déplacement, danger, épuisement).
  local f = nil
  if where ~= Ca.HQ then
    for _, dd in ipairs(ctx.deposits) do if tostring(dd.id) == where then f = dd end end
    if ctx.threat then H.refuse(ctx, key, "equiper", item, "menace : leviers du QG seulement") return end
    if f then
      local why = Ca.usable(ctx, f, "equiper")
      if why then H.refuse(ctx, key, "equiper", item, "gisement " .. where .. " : " .. why) return end
    end
    if plan.dead[where] then return end
  end
  local def = Ri - (plan.N[item] or 0) - (ctx.stock[item] or 0) / Ca.H_STOCK
  local stock_i = (ctx.stock[item] or 0) / Ca.H_STOCK
  local lead_room = math.max(0, Ca.LEAD * Ri - (plan.N[item] or 0) - stock_i)
  if def <= Ca.EPS and lead_room <= Ca.EPS then return end
  local ce = ctx.input.can_exec
  local base_list = effect_list(L, mods)
  local s_o, p_o, e_o = factors_of(base_list)
  local n_g = g.n
  local rho1, in_unit
  if is_drill then
    rho1 = Ca.drill_per_min(D, ent, item)
  else
    rho1 = Ca.out_per_min(ent, r, item)
  end
  -- Entrées de chaque machine (par minute) pour la part de vitesse : un module de vitesse n'ajoute rien sans l'entrée.
  local ins = {}
  if not is_drill then
    for _, ing in ipairs(r.ingredients) do
      if not ing.fluid then ins[#ins + 1] = { name = ing.name, per = Ca.in_per_min(ent, r, ing.name) } end
    end
  end
  local blocked = repli_of(Ca, ctx, plan, req, item)
  local wf = D.packs[item] and ctx.w_rech or ctx.w_cap
  -- Part de l'étage : 1. Un module s'ajoute à une chaîne qui EXISTE déjà (machines posées, entrée livrée) : toute la valeur
  -- de la sortie de plus lui revient, contrairement à une machine neuve dont la valeur se partage avec son amont (Ca.share).
  local sh = 1
  local va = D.mu[item] or 0
  local best, best_mk = nil, nil
  local reasons = {} -- raison de refus de chaque module essayé (une clé d'ordre, plusieurs modules : on garde toutes les raisons)
  for _, nm in ipairs(L.cand) do
    local m = L.equip[nm]
    if module_fits(L, m, sl, (not is_drill) and r.name or nil) and D.mu[nm] then
      local mk_key = g.entity .. "|" .. tostring(is_drill and g.resource or g.recipe) .. "|" .. Lv.sig(mods) .. "|" .. nm .. "*" .. free
      local fac = ctx.lv_fac[mk_key]
      if not fac then
        local s_n, p_n, e_n = factors_of(effect_list(L, mods, nm, free))
        fac = { s_n, p_n, e_n }
        ctx.lv_fac[mk_key] = fac
      end
      local s_n, p_n, e_n = fac[1], fac[2], fac[3]
      local per_machine = rho1 * (s_n * p_n - s_o * p_o) / 10000  -- sortie de plus par machine (par minute)
      if per_machine > Ca.EPS then
        local obtainable = Ca.obtainable(ctx, nm) and (not ce or not ce("equiper", nm))
        local k_need = math.max(1, math.min(n_g, math.ceil((math.max(def, 0) + lead_room * Ca.AHEAD_PCT / 100) / per_machine - Ca.EPS)))
        local function mk(k)
          local o = { kind = "equiper", key = key, item = item, entity = g.entity, recipe = (not is_drill) and r.name or nil,
            resource = is_drill and g.resource or nil, deposit = (where ~= Ca.HQ) and where or nil, where = where, n = k,
            module = nm, per = free, sig = Lv.sig(mods), depth = (req.depth[item] or 0) + 50, share = sh, tier = "equiper" }
          local items = { { nm, k * free } }
          o.items = items
          o.cost_m, o.unpaid = H.items_mu(ctx, items)
          o.work = H.work_of(ctx, items, f and f.dist or Ca.DIST)
          -- Sortie de plus. La vitesse de plus demande l'entrée de plus : la part servie est bornée par l'entrée libre.
          local frac = 1
          local d_in = {}
          if not is_drill then
            for _, e in ipairs(ins) do
              local dn = k * e.per * (s_n - s_o) / 100
              if dn > Ca.EPS then
                local avail
                if D.res[e.name] then
                  avail = Ca.supply_of(ctx, e.name) - (plan.cons[e.name] or 0)
                else
                  avail = (plan.N[e.name] or 0) + (plan.hand[e.name] or 0) + (ctx.stock[e.name] or 0) / Ca.H_STOCK
                    - (plan.cons[e.name] or 0)
                end
                local fr = math.max(0, math.min(1, avail / dn))
                if fr < frac then frac = fr end
              end
            end
            for _, e in ipairs(ins) do d_in[#d_in + 1] = { e.name, k * e.per * frac * (s_n - s_o) / 100 } end
          end
          local s_eff = s_o + frac * (s_n - s_o)
          local d_out = k * rho1 * (s_eff * p_n - s_o * p_o) / 10000
          if d_out <= Ca.EPS then
            H.refuse(ctx, key, "equiper", item, "l'entree manque : un module de vitesse n'ajouterait rien")
            return nil
          end
          local useful = math.min(d_out, math.max(0, def))
          local extra = math.min(d_out - useful, lead_room) * Ca.AHEAD_PCT / 100
          -- énergie de plus (barème D-17 : le facteur d'énergie des modules posés)
          local dfac = (e_n - e_o) / 100
          local d_kw = k * (ent.kw or 0) * dfac
          local d_fuel = 0
          if (ent.kw or 0) > 0 and D.fuel_kj > 0 then d_fuel = d_kw * 60 / D.fuel_kj end -- combustible équivalent par minute
          if ent.energy == "electric" and ctx.input.power then
            local room_kw = plan.kw_have - plan.kw_used
            if d_kw > room_kw + Ca.EPS then
              H.refuse(ctx, key, "equiper", item, "courant insuffisant (" .. fmt(d_kw) .. " kW de plus)")
              return nil
            end
          end
          o.d_item, o.d_out, o.d_in, o.d_kw, o.d_fuel = item, d_out, d_in, d_kw, d_fuel
          o.rate, o.useful = d_out, useful
          o.gain = (useful + extra) * va * sh * wf - d_fuel * ctx.fuel_mu
          o.factor = { speed = s_n, productivity = p_n, energy = e_n, speed0 = s_o, productivity0 = p_o }
          o.repli = blocked
          o.why = string.format("%d x %s : %d x %s (%s de plus par machine) ; manque %s/min, sortie +%s/min (utile %s), vitesse x%s productivite x%s energie x%s%s",
            k, kind_name, free, nm, fmt(per_machine), fmt(def), fmt(d_out), fmt(useful), MM.factor_text(s_n),
            MM.factor_text(p_n), MM.factor_text(e_n), blocked and (" ; " .. repli_text(blocked)) or " ; sans repli")
          return H.finish(ctx, o, Lv.tmax(Ca, ctx, blocked))
        end
        ctx.refus[key] = nil
        local o = mk(k_need)
        if not o and ctx.refus[key] then reasons[#reasons + 1] = nm .. " : " .. tostring(ctx.refus[key].why) end
        ctx.refus[key] = nil
        if o then
          if obtainable then
            if not best or o.Tq < best.Tq or (o.Tq == best.Tq and nm < best.module) then best, best_mk = o, mk end
          else
            -- Rentable mais pas obtenable : la recherche qui le débloque prend de la valeur.
            ctx.lv_want[nm] = true
            reasons[#reasons + 1] = nm .. " : recherche (retour " .. fmt(o.T) .. " min)"
          end
        end
      end
    end
  end
  if best then
    H.cand(out, best, best_mk)
  elseif #reasons > 0 then
    local keep = {}
    for i = 1, math.min(Lv.REPLI_REFUS, #reasons) do keep[i] = reasons[i] end
    H.refuse(ctx, key, "equiper", item, table.concat(keep, " ; "))
  end
end

local function module_options(Ca, ctx, plan, req, out)
  for _, g in ipairs(ctx.machines) do group_options(Ca, ctx, plan, req, g, false, out) end
  for _, g in ipairs(ctx.drills_in) do group_options(Ca, ctx, plan, req, g, true, out) end
end

---------------------------------------------------------------------------------------------------
-- Recherches à effet
---------------------------------------------------------------------------------------------------
local function tech_options(Ca, ctx, plan, req, out)
  local D, L, H = ctx.D, ctx.D.lv, Ca.H
  if #L.tech_list == 0 then return end
  local bottleneck = build_bottleneck(ctx)
  -- travail de construction ouvert (PNJ-minutes par minute, étalé sur le délai de pose)
  local open_w = 0
  for _, o in ipairs(ctx.open) do open_w = open_w + (o.work_left or 0) end
  local busy = open_w / 60 / math.max(1, ctx.input.lag or Ca.T_LAG)
  local per_pnj = (ctx.Y or 0) / math.max(1, ctx.input.workers or 1)
  local lab_cap_now = math.max(plan.lab_cap, ctx.cap0 or 0, ctx.lab_rate or 0)
  for _, t in ipairs(L.tech_list) do
    local key = "techno:" .. t
    local spec = L.techs[t]
    if not ctx.techs[t] and not Ca.taken(plan, key) then
      local ready = true
      for _, p in ipairs(spec.prerequisites) do if not ctx.techs[p] then ready = false end end
      local cost, unpaid = 0, nil
      for _, ing in ipairs(spec.ingredients) do
        local mu = D.mu[ing[1]]
        if mu == nil or not Ca.obtainable(ctx, ing[1]) then
          ready = false
          unpaid = ing[1]
        else
          cost = cost + ing[2] * spec.count * mu
        end
      end
      cost = cost + spec.count * spec.time * Ca.TIME_MU
      if ready then
        local gain, parts = 0, {}
        local blocked_all = nil
        for _, e in ipairs(spec.effects) do
          local m = e.modifier
          if e.kind == "mine" then
            for _, k in ipairs(D.res_list) do
              local rs = D.res[k]
              local Nk = plan.N[k] or 0
              local Ri = req.R[k] or 0
              if not rs.fluid and Nk > 0 and Ri > 0 then
                local d_ore = m * Nk
                local def = Ri - Nk - (ctx.stock[k] or 0) / Ca.H_STOCK
                local lead_room = math.max(0, Ca.LEAD * Ri - Nk - (ctx.stock[k] or 0) / Ca.H_STOCK)
                local useful = math.min(d_ore, math.max(0, def))
                local extra = math.min(d_ore - useful, lead_room) * Ca.AHEAD_PCT / 100
                local g1 = (useful + extra) * (D.mu[k] or 0) * ctx.w_cap
                if g1 > 0 then
                  gain = gain + g1
                  parts[#parts + 1] = string.format("%s +%s/min", k, fmt(useful + extra))
                  local b = sites_state(Ca, ctx, plan, k)
                  if b.blocked then blocked_all = blocked_all or {} blocked_all[#blocked_all + 1] = { resource = k, text = b.text } end
                end
              end
            end
          elseif e.kind == "lab_speed" and ctx.lab then
            local d_cap = m * plan.lab_cap
            local useful = math.min(d_cap, math.max(0, ctx.u_star - plan.lab_cap), math.max(0, Ca.lab_cap(ctx, plan)))
            if useful > 0 then
              gain = gain + useful * ctx.lab_mu * H.lab_share(ctx) * ctx.w_rech
              parts[#parts + 1] = string.format("laboratoires +%s s/min", fmt(useful))
            end
          elseif e.kind == "lab_prod" and ctx.lab then
            local base = math.min(ctx.u_meas or 0, lab_cap_now)
            if base > 0 then
              gain = gain + m * base * ctx.lab_mu * H.lab_share(ctx) * ctx.w_rech
              parts[#parts + 1] = string.format("recherche +%s s/min", fmt(m * base))
            end
          elseif e.kind == "labor" then
            local g1 = m * busy * per_pnj
            if not bottleneck then g1 = g1 * Ca.AHEAD_PCT / 100 end
            if g1 > 0 then
              gain = gain + g1
              parts[#parts + 1] = string.format("travail +%s PNJ-min/min%s", fmt(m * busy), bottleneck and " (construction goulot)" or "")
            end
          end
        end
        if gain > Ca.EPS then
          local delay = spec.count * spec.time / math.max(Ca.EPS, lab_cap_now)
          local o = { kind = "techno", key = key, item = nil, tech = t, n = 1, depth = 99, where = Ca.HQ, items = {},
            cost_m = 0, work = 0, cost = cost, gain = gain, share = 1, tier = "techno", repli = blocked_all,
            effects = parts }
          o.T = cost / gain + delay
          o.Tq = math.floor(o.T * 1e6 + 0.5)
          o.delay = delay
          local tmax = Lv.tmax(Ca, ctx, blocked_all)
          if o.T <= tmax then
            o.value = Ca.value(o.T, tmax)
            o.why = string.format("recherche %s : %s ; cout %s MU, retard %s min%s", t, table.concat(parts, ", "), fmt(cost),
              fmt(delay), blocked_all and (" ; " .. repli_text(blocked_all)) or "")
            H.cand(out, o, nil)
          else
            H.refuse(ctx, key, "techno", nil, string.format("retour %s min > %s", fmt(o.T), fmt(tmax)))
          end
        end
      elseif unpaid then
        -- packs qu'on ne sait pas faire : pas d'option (la recherche des packs est déjà une affaire de la file)
        H.refuse(ctx, key, "techno", nil, "pack " .. unpaid .. " non obtenable")
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Recherche qui débloque une MEILLEURE MACHINE (lot LEVIERS, demande de l'intégrateur du 28/10)
---------------------------------------------------------------------------------------------------
Lv.UNLOCK_TMAX = nil     -- nil : Ca.H_LIFE. Une meilleure machine se pose sur place : aucun site à trouver, l'horizon d'un
                         -- gisement (60 min) borne le retour, retard de la recherche compris.

--- Technologies à faire (la technologie et ses prérequis non faits) et leur coût en MU (packs + secondes de laboratoire) ;
--- nil et la cause si un pack est introuvable.
local function research_chain(Ca, ctx, t)
  local L, D = ctx.D.lv, ctx.D
  local seen, order = {}, {}
  local function walk(n)
    if seen[n] or ctx.techs[n] then return end
    seen[n] = true
    local spec = L.all_techs[n]
    if spec then
      for _, p in ipairs(spec.prerequisites or {}) do walk(p) end
    end
    order[#order + 1] = n
  end
  walk(t)
  local cost, secs = 0, 0
  for _, n in ipairs(order) do
    local spec = L.all_techs[n]
    if not spec or spec.enabled == false then return nil, "technologie " .. n .. " inconnue ou inactive" end
    for _, ing in ipairs(spec.ingredients or {}) do
      local mu = D.mu[ing[1]]
      if mu == nil or not Ca.obtainable(ctx, ing[1]) then return nil, "pack " .. ing[1] .. " non obtenable" end
      cost = cost + ing[2] * (spec.count or 1) * mu
    end
    cost = cost + (spec.count or 1) * (spec.time or 1) * Ca.TIME_MU
    secs = secs + (spec.count or 1) * (spec.time or 1)
  end
  return { techs = order, cost = cost, secs = secs }
end

--- input.successors = { [machine] = { machines supérieures, vitesse croissante } } (lues aux prototypes par le runtime,
--- shared/ai3/capital.lua : Cap.successors). Pour chaque machine posée dont un successeur n'est PAS encore fabricable, la
--- technologie qui le débloque (D.unlocked_by) est chiffrée : gain = vitesse supérieure x machines posées de la famille, borné
--- par la demande (+ 25 % d'avance, et ce que l'entrée de plus permet), coût = recherche (packs, laboratoire, prérequis) +
--- machines neuves ; retour = coût ÷ gain + retard. Une technologie retenue demande l'OBJET successeur à la recherche
--- (ctx.lv_want : le choix de la technologie lui donne la valeur d'un objet voulu et la chaîne de ses prérequis).
local function unlock_options(Ca, ctx, plan, req)
  local succ = ctx.input.successors
  ctx.lv_unlock = {}
  if not succ then return end
  local D, L = ctx.D, ctx.D.lv
  local by_tech, order = {}, {}
  for _, g in ipairs(ctx.machines) do
    local list = succ[g.entity]
    local E, r = D.maker_by[g.entity], D.recipes[g.recipe]
    if list and E and r and not r.fluid and #r.products > 0 and (g.n or 0) > 0 and not (g.mods and next(g.mods)) then
      local item = r.products[1].name
      local Ri = req.R[item] or 0
      if Ri > 0 then
        for _, sname in ipairs(list) do
          local S = D.maker_by[sname]
          local ready = S == nil or not S.item or D.mu[S.item] == nil or (ctx.stock[S.item] or 0) > 0
          if not ready then
            for _, rn in ipairs(D.producers[S.item] or {}) do
              if Ca.recipe_open(ctx, rn) then ready = true end
            end
          end
          if not ready and S.speed > E.speed then
            local tech
            for _, rn in ipairs(D.producers[S.item] or {}) do
              local tt = D.unlocked_by[rn]
              if tt and not ctx.techs[tt] and not tech then tech = tt end
            end
            if tech then
              local gq = S.speed / E.speed - 1
              local stock_i = (ctx.stock[item] or 0) / Ca.H_STOCK
              local def = Ri - (plan.N[item] or 0) - stock_i
              local lead_room = math.max(0, Ca.LEAD * Ri - (plan.N[item] or 0) - stock_i)
              local d_total = g.n * Ca.out_per_min(E, r, item) * gq
              -- la vitesse de plus exige l'entrée de plus (minerai livré, ingrédient couvert), sinon elle n'est qu'une avance
              local frac = 1
              for _, ing in ipairs(r.ingredients) do
                if not ing.fluid then
                  local dn = g.n * Ca.in_per_min(E, r, ing.name) * gq
                  if dn > Ca.EPS then
                    local avail
                    if D.res[ing.name] then
                      avail = Ca.supply_of(ctx, ing.name) - (plan.cons[ing.name] or 0)
                    else
                      avail = (plan.N[ing.name] or 0) + (plan.hand[ing.name] or 0) + (ctx.stock[ing.name] or 0) / Ca.H_STOCK
                        - (plan.cons[ing.name] or 0)
                    end
                    frac = math.min(frac, math.max(0, math.min(1, avail / dn)))
                  end
                end
              end
              local useful = math.min(d_total * frac, math.max(0, def))
              local extra = math.min(d_total - useful, lead_room) * Ca.AHEAD_PCT / 100
              local wf = D.packs[item] and ctx.w_rech or ctx.w_cap
              local d_fuel = 0
              if D.fuel_kj > 0 then d_fuel = g.n * ((S.kw or 0) - (E.kw or 0)) * 60 / D.fuel_kj end
              local gain = (useful + extra) * (D.mu[item] or 0) * wf - d_fuel * ctx.fuel_mu
              if gain > Ca.EPS then
                local b = by_tech[tech]
                if not b then
                  b = { tech = tech, items = {}, gain = 0, repl = 0, n = 0, parts = {} }
                  by_tech[tech] = b
                  order[#order + 1] = tech
                end
                b.items[S.item] = true
                b.gain = b.gain + gain
                b.repl = b.repl + g.n * D.mu[S.item]
                b.n = b.n + g.n
                b.parts[#b.parts + 1] = string.format("%d x %s -> %s (vitesse x%s, +%s/min de %s)", g.n, g.entity, sname,
                  fmt(S.speed / E.speed), fmt(useful + extra), item)
                break -- le premier successeur non fabricable (le moins rapide) suffit à ce groupe
              end
            end
          end
        end
      end
    end
  end
  local lab_cap = math.max(plan.lab_cap, ctx.cap0 or 0, ctx.lab_rate or 0)
  for _, tech in ipairs(order) do
    local b = by_tech[tech]
    local chain, why = research_chain(Ca, ctx, tech)
    local key = "debloquer:" .. tech
    if not chain then
      ctx.refus[key] = { key = key, kind = "debloquer", why = tostring(why) }
    else
      local cost = chain.cost + b.repl
      local delay = chain.secs / math.max(Ca.EPS, lab_cap)
      local T = cost / b.gain + delay
      local tmax = math.max(ctx.ch.tmax, (Lv.UNLOCK_TMAX or Ca.H_LIFE) / (ctx.threat and Ca.THREAT_DIV or 1))
      local items = sorted_keys(b.items)
      if T <= tmax then
        for _, it in ipairs(items) do ctx.lv_want[it] = true end
        ctx.lv_unlock[#ctx.lv_unlock + 1] = { tech = tech, items = items, chain = chain.techs, gain = b.gain, cost = cost,
          delay = delay, T = T, n = b.n,
          why = string.format("recherche %s (%d technologie(s)) pour %s : %s ; cout %s MU, retard %s min, retour %s min",
            tech, #chain.techs, table.concat(items, ", "), table.concat(b.parts, " ; "), fmt(cost), fmt(delay), fmt(T)) }
      else
        ctx.refus[key] = { key = key, kind = "debloquer", why = string.format("retour %s min > %s", fmt(T), fmt(tmax)) }
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Interface avec la règle
---------------------------------------------------------------------------------------------------
function Lv.prepare(ctx)
  ctx.lv_sites, ctx.lv_fac, ctx.lv_want = {}, {}, {}
end

function Lv.options(Ca, ctx, plan, req, out)
  local L = ctx.D.lv
  if not L then return end
  ctx.lv_sites = {}   -- les places dépendent du plan : refait à chaque passe
  module_options(Ca, ctx, plan, req, out)
  tech_options(Ca, ctx, plan, req, out)
  unlock_options(Ca, ctx, plan, req)
end

--- Applique un ordre « modules » ou « techno » au plan (pour son reste à poser).
function Lv.apply(ctx, plan, o)
  if o.kind == "equiper" then
    local frac = 1
    if o.n_left and o.n and o.n > 0 then frac = o.n_left / o.n end
    if o.d_item and o.d_out then plan.N[o.d_item] = (plan.N[o.d_item] or 0) + o.d_out * frac end
    for _, e in ipairs(o.d_in or {}) do
      if o.where == nil or o.where == "qg" then plan.cons[e[1]] = (plan.cons[e[1]] or 0) + e[2] * frac end
    end
    plan.kw_used = plan.kw_used + (o.d_kw or 0) * frac
    plan.burn = plan.burn + math.max(0, o.d_fuel or 0) * frac
  elseif o.kind == "techno" then
    plan.techno = plan.techno or {}
    plan.techno[o.tech] = true
    local spec = ctx.D.lv.techs[o.tech]
    if spec then
      for _, e in ipairs(spec.effects) do
        if e.kind == "mine" then
          for _, k in ipairs(ctx.D.res_list) do
            if not ctx.D.res[k].fluid and (plan.N[k] or 0) > 0 then plan.N[k] = plan.N[k] * (1 + e.modifier) end
          end
        elseif e.kind == "lab_speed" then
          plan.lab_cap = plan.lab_cap * (1 + e.modifier)
        end
      end
    end
  end
end

--- Compte rendu du repli (res.repli) : ressources bloquées qui ont un besoin, leviers retenus, refus des leviers.
function Lv.repli(Ca, ctx, plan, req, orders)
  local L = ctx.D.lv
  if not L then return nil end
  ctx.lv_sites = {}
  local blocked = {}
  for _, k in ipairs(ctx.D.res_list) do
    local rs = ctx.D.res[k]
    if not rs.fluid and (req.R[k] or 0) > 0 then
      local st = sites_state(Ca, ctx, plan, k)
      if st.blocked then
        blocked[#blocked + 1] = { resource = k, text = st.text, absent = st.absent or nil, demand = req.R[k],
          have = plan.N[k] or 0 }
      end
    end
  end
  if #blocked == 0 then return nil end
  local levers, refus = {}, {}
  for _, o in ipairs(orders) do
    if (o.kind == "equiper" or o.kind == "techno") and o.repli then
      levers[#levers + 1] = { key = o.key, kind = o.kind, T = o.T, why = o.why }
    end
  end
  for _, k in ipairs(sorted_keys(ctx.refus)) do
    local r = ctx.refus[k]
    if (r.kind == "equiper" or r.kind == "techno") and #refus < Lv.REPLI_REFUS then
      refus[#refus + 1] = { key = r.key, why = r.why }
    end
  end
  local none = nil
  if #levers == 0 then
    if #L.cand == 0 then none = "aucun module dans les donnees"
    elseif next(L.slots) == nil then none = "aucune machine a emplacements de modules dans les donnees"
    elseif #ctx.machines + #ctx.drills_in == 0 then none = "aucune machine posee"
    else none = "aucun module ne rapporte assez (voir refus)" end
  end
  local parts = {}
  for _, b in ipairs(blocked) do
    parts[#parts + 1] = string.format("%s : besoin %s/min, fourni %s/min, %s", b.resource, fmt(b.demand), fmt(b.have), b.text)
  end
  local lv_txt = {}
  for _, l in ipairs(levers) do lv_txt[#lv_txt + 1] = string.format("%s (T=%s)", l.key, fmt(l.T)) end
  local text = "repli : " .. table.concat(parts, " | ") .. " -> " ..
    (#levers > 0 and ("leviers " .. table.concat(lv_txt, ", ")) or ("aucun levier : " .. tostring(none)))
  return { blocked = blocked, levers = levers, refus = refus, none = none, text = text }
end

--- Objets (modules) dont la recherche prendrait de la valeur : liste triée.
function Lv.wanted(ctx)
  return sorted_keys(ctx.lv_want or {})
end

return Lv
