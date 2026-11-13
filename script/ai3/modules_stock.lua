--[[
  Lot MODULES-POSES : côté RUNTIME de la règle pure shared/ai3/modules_stock.lua (disposition du stock de modules). Appelé UNE
  fois par pensée par Capi.think_tail (script/ai3/capitalisation.lua), qui lui passe son contexte `c` (lectures du stock, du
  courant, des replis) : ce fichier ne lit ni le coffre ni le moteur lui-même (testable avec des tables simples).

  Chaîne : stock de modules au coffre (au-delà d'une petite réserve et de ce que les ordres ouverts se sont promis) → règle pure
  (machines classées : objet en manque d'abord, puis sortie de plus par module) → ordre « equiper » (même forme que celui du
  levier, avec stock = vrai) ajouté à cs.open → tâche postée par Capi.think_tail comme tout ordre « equiper » → un PNJ prend les
  modules au coffre (étape « take » stricte), marche, insère (Equip.act), recalcule la balise (Mult.refresh). RIEN n'est posé sans
  le travail d'un PNJ. La seule porte est la pile « survivre » (un module possédé n'a aucun coût d'opportunité en matière).

  Journal [FO-MODULES] (une ligne par ordre ouvert, par machine traitée — script/team/equiper.lua — et par refus, chacun avec sa
  cause) : « <équipe> : ordre|retire|refus ... : <cause> a <minutes> min ». Les refus ne sont écrits qu'une fois par (clé, cause).
  Déterminisme : listes triées de la règle pure, aucun pairs, aucun temps mesuré. Données de `global` : nombres et chaînes.
]]

local Ms = require("shared.ai3.modules_stock")
local Pi = require("shared.ai3.pile")
local Roi = require("shared.ai3.modules_roi")

local RT = {}

RT.ENABLED = true       -- tests seulement (mutants) : faux = la disposition du stock est éteinte
RT.ROI = true           -- lot S42 MODULES-ROI : la passe choisit productivité ou vitesse par machine (shared/ai3/modules_roi.lua), pose partielle,
                        -- sans réserve, et demande des modules à la fabrication ; faux (tests de l'ancienne règle) = Ms.plan seul
RT.SAID_MAX = 200       -- refus déjà écrits gardés (au-delà : la liste repart de zéro)

local function say(f, minutes, text)
  log(string.format("[FO-MODULES] %s : %s a %.1f min", f.key or "player", text, minutes))
end

--- Porte : la pile « survivre » suspend la pose ; rien d'autre (rang inférieur ou égal : la pose est une tâche à faible priorité).
function RT.gate(f)
  local st = f and f.team and f.team.ia3 and f.team.ia3.pile
  return Ms.gate(st ~= nil and st.hold == true and st.top == Pi.SURVIVRE)
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Nom du statut d'une machine d'un groupe du relevé (entité du groupe à la position de l'unité), ou nil hors du jeu. Lecture seule.
--- (game.get_entity_by_unit_number n'existe pas en 1.1.91 : banc modules-poses du 8/11, 12 h 42.)
-- (Table des noms posée UNE fois, en CHAMP du module et non en local de module : règle de tests/upvalue_gc_test.lua, F403.)
RT.status_names = nil
function RT.status_of(f, g, u)
  if not (defines and f and f.hq and f.hq.valid) then return nil end
  if not RT.status_names then
    local names = {}
    for name, id in pairs(defines.entity_status) do names[id] = name end
    RT.status_names = names
  end
  local list = f.hq.surface.find_entities_filtered({ position = { u.x, u.y }, name = g.entity, force = f.force, limit = 1 })
  local e = list[1]
  if not (e and e.valid) then return nil end
  return RT.status_names[e.status], RT.load_of(e, g)
end

--- Lot S42 MODULES-ROI : charge d'une machine de fabrication (lecture seule) : { in_full = la fabrication SUIVANTE est déjà servie
--- (chaque ingrédient solide de la recette en cours est dans l'inventaire d'entrée), out_empty = l'inventaire de sortie est vide }.
--- Nil pour une foreuse, sans recette, ou si le moteur refuse une lecture (aucune charge lue : l'état reste « tourne »).
function RT.load_of(e, g)
  if g.resource ~= nil or not RT.ROI then return nil end
  local ok, ld = pcall(function()
    local r = e.get_recipe()
    local out = e.get_output_inventory()
    local inp = e.get_inventory(defines.inventory.assembling_machine_input)
    if not (r and out and inp) then return nil end
    local full = true
    for _, ing in ipairs(r.ingredients) do
      if ing.type == "item" and inp.get_item_count(ing.name) < ing.amount then full = false end
    end
    return { in_full = full, out_empty = out.is_empty() }
  end)
  return ok and ld or nil
end

RT.SAMPLE = 12 -- unités lues par groupe (statut) : les premières cibles d'un ordre (Ms.BATCH_MAX)

--- Copie légère des groupes du relevé avec g.run : unités échantillonnées, unités qui travaillent, cause d'arrêt (statut le plus
--- fréquent parmi les autres, à égalité le premier par nom). Sans lecture de statut (c.status nil ou rendu nil) : pas de g.run.
local function with_run(list, status)
  local out = {}
  for _, g in ipairs(list or {}) do
    local copy = {}
    for k, x in pairs(g) do copy[k] = x end
    local sampled, working, starved, causes = 0, 0, 0, {}
    local units = {}
    local units_in, short_in, full, bott, loads = {}, 0, 0, 0, 0 -- lot S42 MODULES-ROI : attente d'entrées, sortie pleine, goulot observé
    for i, u in ipairs(g.units or {}) do
      local s, ld = nil, nil
      if i <= RT.SAMPLE then s, ld = status(g, u) end
      if s == "item_ingredient_shortage" then
        short_in = short_in + 1
        units_in[#units_in + 1] = u
      elseif s == "full_output" or s == "waiting_for_space_in_destination" then
        full = full + 1
      elseif s == "working" and type(ld) == "table" then
        loads = loads + 1
        if ld.in_full and ld.out_empty then bott = bott + 1 end
      end
      -- une unité échantillonnée qui ne travaille pas ne reçoit pas de module (banc 3 : 3 assembleurs « item_ingredient_shortage » équipés
      -- parce que le 4e du groupe travaillait) ; les unités non lues restent des cibles
      if s == nil or s == "working" then units[#units + 1] = u end
      if s ~= nil then
        sampled = sampled + 1
        if s == "working" then working = working + 1 else causes[s] = (causes[s] or 0) + 1 end
        if s == "low_power" or s == "no_power" or s == "not_plugged_in_electric_network" then starved = starved + 1 end
      end
    end
    copy.units = units
    if sampled > 0 then
      local stop, best = nil, 0
      for _, name in ipairs(sorted_keys(causes)) do
        if causes[name] > best then stop, best = name, causes[name] end
      end
      copy.run = { sampled = sampled, working = working, starved = starved, stop = stop,
        short_in = short_in, full = full, bott = bott, loads = loads }
      copy.units_in = units_in
    end
    out[#out + 1] = copy
  end
  return out
end

--- Entretien des ordres de stock ouverts, à chaque pensée (après le suivi, avant que le cerveau lise les manques) : un ordre de stock ne
--- fait JAMAIS fabriquer de module. Le suivi (follow) écrit un manque dès que le coffre est sous le besoin ; or le coffre baisse
--- aussi quand le PNJ prend les modules de la tâche (banc 3, 8/11 : il a vu 5 modules « de reste » pendant que 15 étaient en route).
--- Le manque est donc effacé ; une tâche sans module au coffre n'est pas postée (Capi.think_tail) et l'ordre finit par le délai
--- d'ordre sans progrès (échec, repli).
function RT.maintain(f, cs, tick, c)
  for _, rec in ipairs(cs.open or {}) do
    if rec.exec == "equiper" and rec.stock and rec.missing and #rec.missing > 0 then rec.missing = {} end
  end
end

--- Une disposition du stock par relevé des machines (cs.scan.tick change une fois par minute). `c` = {
---   Ca, D                     la règle pure de la capitalisation et ses données
---   count(item)               modules et ingrédients au coffre (Stock.count de l'équipe)
---   minutes(f, tick)          minutes de jeu de l'équipe
---   held(cs, clé, tick)       raison d'un repli, ou nil          hold(cs, clé, raison, tick)
---   power()                   Capi.power_input(...) : { have_kw, used_kw } ou état fermé (lu une fois par relevé)
---   threat                    vrai sous menace
---   status(groupe, unité)    nom du statut de la machine (défaut RT.status_of) : une machine arrêtée ne reçoit rien }
function RT.think(f, cs, tick, c)
  if not RT.ENABLED or not cs.scan then return 0 end
  RT.maintain(f, cs, tick, c)
  if cs.ms_scan == cs.scan.tick then return 0 end
  cs.ms_scan = cs.scan.tick
  local D, Ca = c.D, c.Ca
  local status = c.status or function(g, u) return RT.status_of(f, g, u) end
  if not (D and D.lv and #D.lv.cand > 0) then return 0 end
  local mn = c.minutes(f, tick)
  local ok, why = RT.gate(f)
  if not ok then
    if cs.ms_gate ~= why then
      cs.ms_gate = why
      say(f, mn, "refus : " .. why)
    end
    return 0
  end
  cs.ms_gate = nil
  local stock, committed, taken, total = {}, {}, {}, 0
  for _, nm in ipairs(D.lv.cand) do
    stock[nm] = c.count(nm)
    total = total + stock[nm]
  end
  -- Lot S42 MODULES-ROI : sans module au coffre la passe continue seulement si l'équipe sait en fabriquer un (souhait de fabrication)
  local can_make = false
  if RT.ROI and total <= 0 and c.craftable then
    for _, nm in ipairs(D.lv.cand) do
      if c.craftable(nm) then can_make = true break end
    end
  end
  if total <= 0 and not can_make then return 0 end
  local fab_open = 0 -- ordres de fabrication (non « stock ») ouverts, levier compris
  for _, rec in ipairs(cs.open or {}) do
    taken[rec.key] = true
    if rec.exec == "equiper" and rec.module then
      committed[rec.module] = (committed[rec.module] or 0) + (rec.n_left or 0) * (rec.per or 1)
      if not rec.stock then fab_open = fab_open + 1 end
    end
  end
  if total <= 0 and fab_open > 0 then return 0 end -- rien à poser et une fabrication déjà ouverte : aucun relevé de statut
  local danger = {}
  for _, id in ipairs(sorted_keys(cs.deps)) do danger[id] = cs.deps[id].danger and true or nil end
  local memo = {}
  local flows = cs.flows or {}
  local function supply(item)
    local m = memo[item]
    if m == nil then
      m = ((flows[item] or {}).made or 0) > 0 or c.count(item) > 0
      memo[item] = m
    end
    return m
  end
  local room = nil
  local p = c.power and c.power() or nil
  if p and type(p.have_kw) == "number" and type(p.used_kw) == "number" then room = p.have_kw - p.used_kw end
  local short = (f.team.ia3 and (f.team.ia3.short_core or f.team.ia3.short)) or {}
  local views_m, views_d = with_run(cs.scan.machines, status), with_run(cs.scan.drills, status)
  local view = { stock = stock, committed = committed,
    machines = views_m, drills = views_d,
    short = short, supply = supply, taken = taken, held = function(key) return c.held(cs, key, tick) end, power_room_kw = room,
    threat = c.threat, danger = danger }
  local orders, refus, info, wants
  if RT.ROI then
    view.made = function(item) return ((flows[item] or {}).made or 0) > 0 end
    view.craftable = c.craftable
    view.max_wants = (fab_open > 0) and 0 or nil -- un seul ordre de fabrication de modules ouvert à la fois par équipe
    orders, refus, info, wants = Roi.plan(Ca, D, view)
    for _, w in ipairs(wants) do orders[#orders + 1] = w end
  else
    orders, refus, info = Ms.plan(Ca, D, view)
  end
  if info.free_total <= 0 and #orders == 0 and total > 0 then
    local sig = "reserve:" .. total
    if cs.ms_low ~= sig then
      cs.ms_low = sig
      say(f, mn, string.format("refus : %d module(s) au coffre, tous promis a des ordres ouverts ou sous la reserve de %d par sorte", total, RT.ROI and Roi.RESERVE or Ms.RESERVE))
    end
    return 0
  end
  cs.ms_low = nil
  local n = 0
  for _, o in ipairs(orders) do
    local is_drill = o.resource ~= nil
    local g = nil
    for _, cand in ipairs(is_drill and views_d or views_m) do
      local where = is_drill and (cand.deposit ~= nil and tostring(cand.deposit) or Ca.HQ) or (cand.where or Ca.HQ)
      if Ms.key(cand, is_drill, where) == o.key then g = cand break end
    end
    local targets = {}
    for _, u in ipairs(o.units or (g and g.units) or {}) do
      if #targets < o.n then targets[#targets + 1] = { x = u.x, y = u.y, u = u.u, entity = g.entity } end
    end
    if #targets > 0 then
      table.sort(targets, function(a, b) return a.u < b.u end)
      local rec = { key = o.key, kind = "equiper", item = o.item, resource = o.resource, deposit = o.deposit, entity = o.entity, n = #targets,
        n_left = #targets, where = o.where, value = Ca.V_MIN, opened = tick, progress_tick = tick, missing = {}, why = o.why,
        exec = "equiper", module = o.module, per = o.per, targets = targets, done = {}, inserted = 0, stock = o.stock,
        d_item = o.d_item, d_out = o.d_out, d_in = o.d_in, d_kw = o.d_kw, d_fuel = o.d_fuel, sig = o.sig,
        announced = { d_out = o.d_out, item = o.d_item, factor = o.factor } }
      if #targets < o.n and o.n > 0 then
        local k = #targets / o.n
        rec.d_out, rec.d_kw, rec.d_fuel = (o.d_out or 0) * k, (o.d_kw or 0) * k, (o.d_fuel or 0) * k
        rec.d_in = {}
        for _, e in ipairs(o.d_in or {}) do rec.d_in[#rec.d_in + 1] = { e[1], e[2] * k } end
        rec.announced.d_out = rec.d_out
      end
      cs.open[#cs.open + 1] = rec
      cs.orders = (cs.orders or 0) + 1
      cs.stats = cs.stats or {}
      cs.stats.equiper = (cs.stats.equiper or 0) + 1
      n = n + 1
      say(f, mn, string.format("ordre %s : %d x %s dans %d machine(s) %s/%s@%s (%s)", o.key, o.per * #targets, o.module, #targets,
        o.entity, tostring(o.recipe or o.resource), o.where, o.why))
    end
  end
  cs.ms_said = cs.ms_said or {}
  if (cs.ms_said_n or 0) > RT.SAID_MAX then cs.ms_said, cs.ms_said_n = {}, 0 end
  for _, r in ipairs(refus) do
    local sig = r.key .. "|" .. tostring(r.module) .. "|" .. tostring(r.why)
    if not cs.ms_said[sig] then
      cs.ms_said[sig] = true
      cs.ms_said_n = (cs.ms_said_n or 0) + 1
      say(f, mn, string.format("refus %s%s : %s", r.key, r.module and (" (" .. r.module .. ")") or "", tostring(r.why)))
    end
  end
  return n
end

return RT
