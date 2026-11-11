--[[
  Lot MODULES-POSES (8/11, demande du DC sur la partie 0.6.65) : « ils ont 50 modules de vitesse dans les coffres et [...] ils se
  bougeraient pas le derrière pour les poser [...] dans les usines d'assemblage. Alors que 50 modules de vitesse, ça quand même
  boosterait pas mal la productivité. »

  POURQUOI cette règle (diagnostic, journaux fo-logs/2026-11-07_PARTIE-DC-0658 et 2026-11-08_MESURE-DC) : le levier « equiper » de
  shared/ai3/leviers.lua décide s'il faut FABRIQUER des modules : il compte chaque module à plein prix (aucune remise pour un module
  déjà au coffre) et ne vaut que par le manque de l'objet (retour 67 min > 28 min, « l'entrée manque »). Un module DÉJÀ possédé n'a
  aucun coût d'opportunité en matière : seul le trajet d'un PNJ compte. Cette règle est la DISPOSITION DU STOCK : ce qui dépasse
  une petite réserve est posé, par bloc, là où il rapporte le plus. Elle ne fabrique rien et ne remplace pas le levier.

  Règle PURE (Lua pur, aucune API du jeu, aucun nom d'objet : tests/iag_test.lua anti-échelle ; lue hors jeu par
  tests/modules_stock_test.lua). Entrée : le relevé des prototypes (D, Ca.data), le relevé des machines et foreuses (groupes de la
  capitalisation : entité, recette ou ressource, lieu, modules posés, unités), le stock des modules, ce qui est déjà promis à des
  ordres ouverts, les manques de l'équipe. Sortie : des ordres de la MÊME forme que ceux du levier (kind « equiper »,
  champs lus par script/ai3/capitalisation.lua et script/team/equiper.lua), plus le compte rendu des refus (cause écrite).

  Classement (listes triées, aucun pairs décisionnel, aucun temps mesuré) :
    1. classe : 1 = la machine fait un objet qui MANQUE (manque propre du cerveau), 2 = foreuse qui tourne, 3 = autre machine qui
       tourne. Une machine ARRÊTÉE (relevé de statut du runtime : aucune unité échantillonnée ne travaille, g.run) ne reçoit rien :
       un module posé sur une machine qui attend l'entrée ou la place n'ajoute pas de débit ;
    2. sortie de plus par module posé (barème D-17 : vitesse, productivité et énergie MULTIPLIÉES), décroissante ;
    3. clé de l'ordre, puis nom du module (égalité exacte).
  Contrôles d'honnêteté : un module n'est jamais proposé à une machine qui ne l'accepte pas (effet non permis, recette hors de la
  liste du module, aucun emplacement libre) ; un module de vitesse n'est proposé que si chaque entrée solide de la recette est
  servie (sinon il n'ajouterait rien) ; le courant de plus ne dépasse pas la marge lue (machine électrique) ; hors du QG : ni sous
  menace ni sur un gisement dangereux ; une clé en repli (refus récent) attend.
]]

local Lv = require("shared.ai3.leviers")

local Ms = {}

Ms.RESERVE = 4          -- modules gardés au coffre par sorte (réparations, remplacements ; « au-delà d'une petite réserve »)
Ms.MAX_ORDERS = 3       -- ordres ouverts par décision (un groupe de machines par ordre)
Ms.UNREAD_BATCH = 4     -- machines par ordre quand la marge de courant n'est pas lue (réseau sans manque observé)
Ms.BATCH_MAX = 12       -- machines par ordre (deux tâches de Equip.BATCH = 6)
Ms.EPS = 1e-9
Ms.CLASS_SHORT = 1      -- l'objet de la machine manque
Ms.CLASS_DRILL = 2      -- foreuse qui TOURNE (demande du DC : « sur les foreuses, évidemment ») : la vitesse de plus a un débouché
Ms.CLASS_PLAIN = 3      -- machine qui tourne, objet non en manque

local function fmt(x)
  if x == nil then return "-" end
  if x ~= x then return "nan" end
  if math.abs(x) >= 100 then return string.format("%.0f", x) end
  return string.format("%.2f", x)
end

--- Modules disponibles pour la disposition : stock − promis aux ordres ouverts − réserve (jamais négatif).
function Ms.available(stock, committed, reserve)
  local n = (stock or 0) - (committed or 0) - (reserve or Ms.RESERVE)
  if n < 0 then return 0 end
  return math.floor(n)
end

--- Cause d'arrêt global (porte de la pile) : vrai si rien ne doit être posé. `top_survive` : le sommet de la pile est « survivre ».
function Ms.gate(top_survive)
  if top_survive then return false, "pile survivre : le QG ou l'effectif de depart passe avant" end
  return true, nil
end

local function group_key(g, is_drill, where)
  return string.format("equiper:%s:%s:%s:%s", g.entity, tostring(is_drill and g.resource or g.recipe), where, Lv.sig(g.mods or {}))
end
Ms.key = group_key

--- Disposition du stock.
--- v = {
---   stock = { [module] = n }       modules au coffre
---   committed = { [module] = n }   modules déjà promis à des ordres ouverts (levier compris)
---   reserve = n | nil              réserve par sorte (Ms.RESERVE)
---   machines, drills = groupes du relevé { entity, recipe | resource, where | deposit, n, mods, sig, units }
---   short = { [objet] = n }        manques du cerveau (> 0 : l'objet manque)
---   supply = function(objet) -> vrai si l'objet est servi (flux mesuré ou stock), ou table { [objet] = vrai }
---   taken = { [clé] = vrai }       clés d'ordres ouverts      held = function(clé) -> raison | nil
---   power_room_kw = nombre | nil   marge de courant (nil : non lue ; alors g.run.starved doit être 0, UNREAD_BATCH machines au plus)
---   threat = vrai | nil            danger = { [lieu] = vrai }
---   max_orders = n | nil }
---   (chaque groupe peut porter g.run = { sampled, working, starved, stop } : unités échantillonnées, unités qui travaillent, cause d'arrêt)
--- Rend (ordres, refus, info) : ordres au format du levier + stock = true ; refus = { { key, module, why } } triés ;
--- info = { avail = { [module] = n }, stock_total, free_total }.
function Ms.plan(Ca, D, v)
  local L = D and D.lv
  local orders, refus = {}, {}
  local info = { avail = {}, stock_total = 0, free_total = 0 }
  if not (L and #L.cand > 0) then return orders, refus, info end
  local avail = {}
  for _, nm in ipairs(L.cand) do
    local have = (v.stock or {})[nm] or 0
    info.stock_total = info.stock_total + have
    avail[nm] = Ms.available(have, (v.committed or {})[nm], v.reserve)
    info.avail[nm] = avail[nm]
    info.free_total = info.free_total + avail[nm]
  end
  if info.free_total <= 0 then return orders, refus, info end
  local taken, short = v.taken or {}, v.short or {}
  local supply = v.supply
  local function served(item)
    if type(supply) == "function" then return supply(item) and true or false end
    if type(supply) == "table" then return supply[item] == true end
    return true
  end
  local opts = {}
  local function refuse(key, nm, why) refus[#refus + 1] = { key = key, module = nm, why = why } end

  local function consider(g, is_drill)
    local ent = is_drill and D.drill_by[g.entity] or D.maker_by[g.entity]
    local sl = L.slots[g.entity]
    if not ent or not sl or (g.n or 0) <= 0 then return end
    local free = sl.n - Lv.filled(g.mods or {})
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
    local key = group_key(g, is_drill, where)
    if taken[key] then return end
    if g.run and (g.run.sampled or 0) > 0 and (g.run.working or 0) == 0 then
      refuse(key, nil, "machine arretee : " .. tostring(g.run.stop or "sans travail"))
      return
    end
    local nunits = #(g.units or {})
    if nunits <= 0 then return end
    if where ~= Ca.HQ then
      if v.threat then refuse(key, nil, "menace : machines du QG seulement") return end
      if (v.danger or {})[where] then refuse(key, nil, "lieu " .. where .. " dangereux") return end
    end
    local held = v.held and v.held(key) or nil
    if held then refuse(key, nil, held) return end
    local rho1 = is_drill and Ca.drill_per_min(D, ent, item) or Ca.out_per_min(ent, r, item)
    local reasons = {}
    local made = false
    for _, nm in ipairs(L.cand) do
      local m = L.equip[nm]
      if avail[nm] >= free then
        if not Lv.fits(L, m, sl, (not is_drill) and r.name or nil) then
          reasons[#reasons + 1] = nm .. " : effet ou recette non permis"
        else
          local s0, p0, e0, s1, p1, e1 = Lv.factors_after(D, g.mods, nm, free)
          local per_machine = rho1 * (s1 * p1 - s0 * p0) / 10000
          if per_machine <= Ms.EPS then
            reasons[#reasons + 1] = nm .. " : aucun gain de sortie"
          else
            local ok_in = true
            if (not is_drill) and s1 > s0 then
              for _, ing in ipairs(r.ingredients) do
                if not ing.fluid and not served(ing.name) then ok_in = false reasons[#reasons + 1] = nm .. " : l'entree " .. ing.name .. " manque (vitesse inutile)" break end
              end
            end
            if ok_in then
              made = true
              local d_kw = (ent.kw or 0) * (e1 - e0) / 100
              opts[#opts + 1] = { g = g, is_drill = is_drill, item = item, r = r, ent = ent, where = where, key = key, nm = nm, free = free,
                units = nunits, per_machine = per_machine, class = (short[item] or 0) > 0 and Ms.CLASS_SHORT or (is_drill and Ms.CLASS_DRILL or Ms.CLASS_PLAIN),
                gain_module = per_machine / free, d_kw = d_kw, s0 = s0, p0 = p0, e0 = e0, s1 = s1, p1 = p1, e1 = e1, rho1 = rho1 }
            end
          end
        end
      end
    end
    if not made and #reasons > 0 then
      local keep = {}
      for i = 1, math.min(3, #reasons) do keep[i] = reasons[i] end
      refuse(key, nil, table.concat(keep, " ; "))
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

  local used, room = {}, v.power_room_kw
  local max_orders = v.max_orders or Ms.MAX_ORDERS
  for _, o in ipairs(opts) do
    if #orders >= max_orders then break end
    if not used[o.key] and avail[o.nm] >= o.free then
      local k = math.min(o.units, Ms.BATCH_MAX, math.floor(avail[o.nm] / o.free))
      local why = nil
      if o.ent.energy == "electric" and o.d_kw > Ms.EPS then
        if room == nil then
          -- Capacité de la centrale non lue (votre équipe, centrale du joueur ; arène de banc) : on ne l'invente pas. Le réseau doit se
          -- porter bien (aucune unité échantillonnée en manque de courant) et la pose avance par petits pas, remesurés à chaque relevé.
          local run = o.g.run
          if not run or (run.sampled or 0) == 0 then
            why = "courant non lu et statut des machines non lu"
            k = 0
          elseif (run.starved or 0) > 0 then
            why = "courant non lu et reseau en manque (" .. tostring(run.stop or "low_power") .. ")"
            k = 0
          else
            k = math.min(k, Ms.UNREAD_BATCH)
          end
        else
          local fit = math.floor((room + Ms.EPS) / o.d_kw)
          if fit < k then k = fit end
          if k < 1 then why = "courant insuffisant (" .. fmt(o.d_kw) .. " kW de plus par machine, marge " .. fmt(room) .. ")" end
        end
      end
      if k >= 1 then
        used[o.key] = true
        avail[o.nm] = avail[o.nm] - k * o.free
        if room ~= nil and o.ent.energy == "electric" and o.d_kw > 0 then room = room - k * o.d_kw end
        local d_in = {}
        if not o.is_drill then
          for _, ing in ipairs(o.r.ingredients) do
            if not ing.fluid then
              d_in[#d_in + 1] = { ing.name, k * Ca.in_per_min(o.ent, o.r, ing.name) * (o.s1 - o.s0) / 100 }
            end
          end
        end
        local d_fuel = 0
        if (o.ent.kw or 0) > 0 and (D.fuel_kj or 0) > 0 then d_fuel = k * o.d_kw * 60 / D.fuel_kj end
        local g = o.g
        orders[#orders + 1] = {
          kind = "equiper", key = o.key, item = o.item, entity = g.entity, recipe = (not o.is_drill) and o.r.name or nil,
          resource = o.is_drill and g.resource or nil, deposit = (o.where ~= Ca.HQ) and o.where or nil, where = o.where, n = k,
          module = o.nm, per = o.free, sig = Lv.sig(g.mods or {}), tier = "equiper", stock = true, class = o.class,
          d_item = o.item, d_out = k * o.per_machine, d_in = d_in, d_kw = k * o.d_kw, d_fuel = d_fuel,
          factor = { speed = o.s1, productivity = o.p1, energy = o.e1, speed0 = o.s0, productivity0 = o.p0 },
          why = string.format("stock : %d x %s : %d x %s (%s de plus par machine) ; %s ; vitesse x%s productivite x%s",
            k, g.entity .. "/" .. tostring(o.is_drill and g.resource or g.recipe), o.free, o.nm, fmt(o.per_machine),
            o.class == Ms.CLASS_SHORT and ("l'objet " .. o.item .. " manque") or (o.class == Ms.CLASS_DRILL and "foreuse qui tourne" or "machine qui tourne, objet non en manque"),
            fmt(o.s1 / 100), fmt(o.p1 / 100)) }
      elseif why then
        refuse(o.key, o.nm, why)
      end
    end
  end
  if #orders == 0 and #refus == 0 then
    refuse("-", nil, "aucune pose possible : aucune machine a emplacements libres, ou moins de modules disponibles que d'emplacements d'une machine")
  end
  table.sort(refus, function(a, b)
    if a.key ~= b.key then return a.key < b.key end
    return tostring(a.module) < tostring(b.module)
  end)
  return orders, refus, info
end

return Ms
