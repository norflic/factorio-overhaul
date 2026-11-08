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

local RT = {}

RT.ENABLED = true       -- tests seulement (mutants) : faux = la disposition du stock est éteinte
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

--- Nom du statut d'une machine (unité) : defines.entity_status inversé, ou nil hors du jeu. Lecture seule.
local STATUS_NAMES = nil
function RT.status_of(unit)
  if not (game and defines and game.get_entity_by_unit_number) then return nil end
  if not STATUS_NAMES then
    STATUS_NAMES = {}
    for name, id in pairs(defines.entity_status) do STATUS_NAMES[id] = name end
  end
  local e = game.get_entity_by_unit_number(unit)
  if not (e and e.valid) then return nil end
  return STATUS_NAMES[e.status]
end

RT.SAMPLE = 6 -- unités lues par groupe (statut)

--- Copie légère des groupes du relevé avec g.run : unités échantillonnées, unités qui travaillent, cause d'arrêt (statut le plus
--- fréquent parmi les autres, à égalité le premier par nom). Sans lecture de statut (c.status nil ou rendu nil) : pas de g.run.
local function with_run(list, status)
  local out = {}
  for _, g in ipairs(list or {}) do
    local copy = {}
    for k, x in pairs(g) do copy[k] = x end
    local sampled, working, causes = 0, 0, {}
    for i, u in ipairs(g.units or {}) do
      if i > RT.SAMPLE then break end
      local s = status(u.u)
      if s ~= nil then
        sampled = sampled + 1
        if s == "working" then working = working + 1 else causes[s] = (causes[s] or 0) + 1 end
      end
    end
    if sampled > 0 then
      local stop, best = nil, 0
      for _, name in ipairs(sorted_keys(causes)) do
        if causes[name] > best then stop, best = name, causes[name] end
      end
      copy.run = { sampled = sampled, working = working, stop = stop }
    end
    out[#out + 1] = copy
  end
  return out
end

local function undone_count(rec)
  local done = {}
  for _, u in ipairs(rec.done or {}) do done[u] = true end
  local n = 0
  for _, t in ipairs(rec.targets or {}) do if not done[t.u] then n = n + 1 end end
  return n, done
end

--- Entretien des ordres de stock ouverts : si le coffre ne couvre plus ce qui reste à poser (un autre lot a pris des modules), les
--- machines en trop sortent de l'ordre (les dernières) au lieu de faire FABRIQUER le module : l'ordre finit avec ce qu'il a posé.
function RT.maintain(f, cs, tick, c)
  for _, rec in ipairs(cs.open or {}) do
    if rec.exec == "equiper" and rec.stock and (rec.n_left or 0) > 0 then
      local left, done = undone_count(rec)
      local have = c.count(rec.module)
      local fit = math.floor(have / math.max(1, rec.per or 1))
      if left > fit then
        local keep, seen = {}, 0
        for _, t in ipairs(rec.targets) do
          if done[t.u] then keep[#keep + 1] = t
          else
            seen = seen + 1
            if seen <= fit then keep[#keep + 1] = t end
          end
        end
        say(f, c.minutes(f, tick), string.format("retire %d machine(s) de l'ordre %s : %d %s au coffre pour %d a poser (stock pris ailleurs)",
          left - fit, rec.key, have, tostring(rec.module), left * (rec.per or 1)))
        rec.targets = keep
        rec.n, rec.n_left = #keep, fit
        rec.missing = {}
      end
    end
  end
end


--- Une disposition du stock par relevé des machines (cs.scan.tick change une fois par minute). `c` = {
---   Ca, D                     la règle pure de la capitalisation et ses données
---   count(item)               modules et ingrédients au coffre (Stock.count de l'équipe)
---   minutes(f, tick)          minutes de jeu de l'équipe
---   held(cs, clé, tick)       raison d'un repli, ou nil          hold(cs, clé, raison, tick)
---   power()                   Capi.power_input(...) : { have_kw, used_kw } ou état fermé (lu une fois par relevé)
---   threat                    vrai sous menace
---   status(unité)            nom du statut de la machine (défaut RT.status_of) : une machine arrêtée ne reçoit rien }
function RT.think(f, cs, tick, c)
  if not RT.ENABLED or not cs.scan then return 0 end
  RT.maintain(f, cs, tick, c)
  if cs.ms_scan == cs.scan.tick then return 0 end
  cs.ms_scan = cs.scan.tick
  local D, Ca = c.D, c.Ca
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
  if total <= 0 then return 0 end
  for _, rec in ipairs(cs.open or {}) do
    taken[rec.key] = true
    if rec.exec == "equiper" and rec.module then
      committed[rec.module] = (committed[rec.module] or 0) + (rec.n_left or 0) * (rec.per or 1)
    end
  end
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
  local orders, refus, info = Ms.plan(Ca, D, { stock = stock, committed = committed,
    machines = with_run(cs.scan.machines, c.status or RT.status_of), drills = with_run(cs.scan.drills, c.status or RT.status_of),
    short = short, supply = supply, taken = taken, held = function(key) return c.held(cs, key, tick) end, power_room_kw = room,
    threat = c.threat, danger = danger })
  if info.free_total <= 0 then
    local sig = "reserve:" .. total
    if cs.ms_low ~= sig then
      cs.ms_low = sig
      say(f, mn, string.format("refus : %d module(s) au coffre, tous promis a des ordres ouverts ou sous la reserve de %d par sorte", total, Ms.RESERVE))
    end
    return 0
  end
  cs.ms_low = nil
  local n = 0
  for _, o in ipairs(orders) do
    local is_drill = o.resource ~= nil
    local g = nil
    for _, cand in ipairs(is_drill and cs.scan.drills or cs.scan.machines) do
      local where = is_drill and (cand.deposit ~= nil and tostring(cand.deposit) or Ca.HQ) or (cand.where or Ca.HQ)
      if Ms.key(cand, is_drill, where) == o.key then g = cand break end
    end
    local targets = {}
    for _, u in ipairs(g and g.units or {}) do
      if #targets < o.n then targets[#targets + 1] = { x = u.x, y = u.y, u = u.u, entity = g.entity } end
    end
    if #targets > 0 then
      table.sort(targets, function(a, b) return a.u < b.u end)
      local rec = { key = o.key, kind = "equiper", item = o.item, resource = o.resource, deposit = o.deposit, entity = o.entity, n = #targets,
        n_left = #targets, where = o.where, value = Ca.V_MIN, opened = tick, progress_tick = tick, missing = {}, why = o.why,
        exec = "equiper", module = o.module, per = o.per, targets = targets, done = {}, inserted = 0, stock = true,
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
