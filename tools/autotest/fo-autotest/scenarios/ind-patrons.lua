-- Scénario greffé du lot INDUSTRIE I5 (31/10) : LES PATRONS (shared/team/patrons.lua) contre le moteur réel. 3 000 ticks :
--   & "<racine>\fo-autotest.bat" nopause 3000 ind-patrons "<source>"
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui IND-I5 -- 3000 ind-patrons <source>
-- Chaque forme est posée à partir du gabarit que rend la règle (recettes, machines et kit LUS dans le jeu : remote « fo-iag »
-- lecture, prototypes), garnie, puis on regarde qu'elle FABRIQUE :
--   - formes de la cellule : 1 à 6 et 8 entrées solides (aucune recette à 7 dans le jeu : forme prouvée hors jeu seulement),
--     sorties tapis, coffre (barre comprise) et unité, rangées de plusieurs machines, plusieurs produits (coffre seul),
--     fluides en entrée (machine TOURNÉE : F91, recette et direction lues dans le moteur), machines à niveaux du mod ;
--   - un bloc de mall : des recettes différentes sur 4 voies communes (P.groups sur les recettes du jeu).
-- Contrôle au tick 2 900 (le banc rejoue 3 000 ticks).
-- Alimentation : les tapis d'entrée sont remplis par le script (insert_at_back, comme un coffre infini) ; un tuyau nourricier
-- est remis plein à chaque tick ; l'électricité vient d'une interface vanilla reliée par un poteau d'arène au poteau de
-- raccordement du gabarit (le gabarit se sert de ses PROPRES poteaux) ; les sorties en tapis sont comptées puis vidées à chaque
-- tick, les machines d'unité sont vidées toutes les 60 ticks (le balayage du lot ROBOTS).
-- Contrôles par forme : modèle sans erreur (M.check), entités toutes créées, prise et dépôt de chaque bras = ceux du modèle,
-- recette et direction de la machine lues, au moins une fabrication, le produit arrive au bout (tapis, coffre, machine), aucune
-- machine sans courant. Barre : un coffre à la barre atteinte ne reçoit plus rien (F95).

local M = require("__factorio-overhaul__/shared/team/modules")
local PA = require("__factorio-overhaul__/shared/team/patrons")

local FORCE = "player"
local X0, Y0 = 5000, 5000
local SLOT = 28
local COLS = 6
local BUF = 1e8
local TOL = 0.1

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function dist(a, b) local dx, dy = a.x - b.x, a.y - b.y; return math.sqrt(dx * dx + dy * dy) end

---------------------------------------------------------------------------------------------------
-- Données du jeu → gabarit
---------------------------------------------------------------------------------------------------
local function amount_of(p)
  if p.amount then return p.amount end
  return ((p.amount_min or 0) + (p.amount_max or 0)) / 2 * (p.probability or 1)
end

local function recipe_table(rn)
  local r = game.recipe_prototypes[rn]
  local ing, prod = {}, {}
  for _, i in ipairs(r.ingredients) do ing[#ing + 1] = { type = i.type, name = i.name, amount = i.amount } end
  for _, p in ipairs(r.products) do prod[#prod + 1] = { type = p.type, name = p.name, amount = amount_of(p) } end
  return { name = rn, category = r.category, energy = r.energy, ingredients = ing, products = prod }
end

--- Déclare au modèle une machine du jeu qu'il ne connaît pas (le « résolveur » du plan §1).
local function ensure_machine(name)
  -- une machine du modèle (dont les niveaux du mod) n'est pas redéclarée ; une machine déclarée ici gagne ses catégories
  if M.spec(name) and not (M.BASE[name] and M.BASE[name].declared) then return true end
  local p = game.entity_prototypes[name]
  if not p or not p.crafting_categories then return false end
  -- l'entrée du relevé de lecture (lot I4), refaite d'après le prototype : mêmes champs que cat.fab[recette].machines[i]
  local boxes = {}
  for _, fb in ipairs(p.fluidbox_prototypes or {}) do
    local pc = fb.pipe_connections and fb.pipe_connections[1]
    local pos = pc and pc.positions and pc.positions[1]
    boxes[#boxes + 1] = { type = fb.production_type, conns = { [0] = pos and { { pos.x or pos[1], pos.y or pos[2] } } or {} } }
  end
  local entry = { entity = name, type = p.type, speed = p.crafting_speed, w = p.tile_width, h = p.tile_height,
    energy = p.burner_prototype and "burner" or "electric", boxes = boxes }
  local def = PA.def_machine(entry, sorted_keys(p.crafting_categories))
  def.usage_kw = (p.energy_usage or 0) * 60 / 1000
  PA.declare(M, name, def)     -- une machine du modèle n'est pas touchée ; une déclarée gagne les catégories
  return true
end

local function item_entity(item) local it = game.item_prototypes[item]; return it and it.place_result and it.place_result.name or item end

local function kit_of(info)
  local ki = info.kit_items
  -- le kit lu (lot I4), refait d'après les prototypes, déclaré par P.declare_kit
  local function piece(item)
    local name = item_entity(item)
    local p = game.entity_prototypes[name]
    local pk = p.inserter_pickup_position
    local reach = pk and math.floor(math.max(math.abs(pk.x or pk[1] or 0), math.abs(pk.y or pk[2] or 0)) + 0.5) or nil
    return { entity = name, reach = reach, rot = p.inserter_rotation_speed, energy = p.burner_prototype and "burner" or "electric",
      slots = (p.type == "container") and p.get_inventory_size(defines.inventory.chest) or nil,
      supply = p.supply_area_distance, wire = p.max_wire_distance }
  end
  local kit, why = PA.declare_kit(M, { bras = piece(ki.bras), bras_long = piece(ki.bras_long), tapis = piece(ki.tapis), coffre = piece(ki.coffre),
    poteau = piece(ki.poteau) })
  if not kit then error("kit lu refusé : " .. tostring(why)) end
  kit.tuyau = "pipe"
  return kit
end

---------------------------------------------------------------------------------------------------
-- Choix des formes (recettes lues dans le jeu, jamais écrites ici)
---------------------------------------------------------------------------------------------------
--- La recette la moins chargée (somme des quantités d'ingrédients, puis durée) parmi celles qui passent `filt` : 3 000 ticks
--- ne laissent pas le temps de livrer 150 objets à un bras.
local function load_of(rn)
  local r = game.recipe_prototypes[rn]
  local n = 0
  for _, i in ipairs(r.ingredients) do n = n + i.amount end
  return n, r.energy
end

local function pick(info, filt)
  local best, bn, be
  for _, rn in ipairs(sorted_keys(info.fab)) do
    local f = info.fab[rn]
    if f.patronnable and filt(f, rn) and rn:sub(1, 6) ~= "fo-i5-" then
      local n, e = load_of(rn)
      if not best or n < bn - 1e-9 or (math.abs(n - bn) <= 1e-9 and e < be - 1e-9) then best, bn, be = rn, n, e end
    end
  end
  return best
end

local STATUS = {}
for k, v in pairs(defines.entity_status) do STATUS[v] = k end

--- Diagnostic d'une forme qui n'a rien fabriqué : machines, ingrédients reçus, tapis d'entrée.
local function diag(P)
  local out = {}
  for _, m in ipairs(P.machines) do
    if m.ent.valid then
      local inv = m.ent.get_inventory(defines.inventory.assembling_machine_input)
      local c = inv and inv.get_contents() or {}
      local parts = {}
      for _, k in ipairs(sorted_keys(c)) do parts[#parts + 1] = k .. "=" .. c[k] end
      out[#out + 1] = string.format("%s %s statut %s, reçu {%s}", m.recipe, m.ent.name, tostring(STATUS[m.ent.status]), table.concat(parts, ","))
    end
  end
  local ins = {}
  for k, v in pairs(P.counts) do if k:sub(1, 3) == "in:" then ins[#ins + 1] = k .. "=" .. v end end
  table.sort(ins)
  out[#out + 1] = "livré aux tapis {" .. table.concat(ins, ",") .. "}"
  -- bras : statut et ce qu'ils tiennent
  local arms = {}
  for _, e in pairs(P.ents) do
    if e.valid and e.type == "inserter" then
      local held = e.held_stack
      local what = (held and held.valid_for_read) and (held.name .. "x" .. held.count) or "-"
      arms[#arms + 1] = string.format("%s@%.0f,%.0f %s %s", e.name:sub(1, 4), e.position.x - P.ox, e.position.y - P.oy, tostring(STATUS[e.status]), what)
    end
  end
  table.sort(arms)
  out[#out + 1] = "bras {" .. table.concat(arms, " | ") .. "}"
  for _, f in ipairs(P.feeds) do
    if f.ent.valid then
      local l1, l2 = f.ent.get_transport_line(1).get_contents(), f.ent.get_transport_line(2).get_contents()
      out[#out + 1] = string.format("tête de tapis @%.0f,%.0f voie1 %s voie2 %s", f.ent.position.x - P.ox, f.ent.position.y - P.oy, serpent.line(l1), serpent.line(l2))
    end
  end
  return table.concat(out, " ; ")
end

--- Première machine d'assemblage de la liste d'une recette que le modèle sait poser (la plus lente d'abord).
local function machine_for(f)
  for _, mn in ipairs(f.machines) do
    local p = game.entity_prototypes[mn]
    if p and p.type == "assembling-machine" and ensure_machine(mn) and M.spec(mn).kind == "assembler" and not (M.spec(mn).burner_kw) then return mn end
  end
  return nil
end

local function forms_list(info, kit)
  local forms = {}
  local function add(label, f) f.label = label; forms[#forms + 1] = f end
  local function solid(n, extra)
    return pick(info, function(f) return f.s == n and f.fluides_in == 0 and f.fluides_out == 0 and f.produits == 1 and machine_for(f) ~= nil and (not extra or extra(f)) end)
  end
  local by_s = {}
  for s = 1, 8 do by_s[s] = solid(s) end
  local function cell(label, s, sortie, n, barre, pre)
    local rn = by_s[s]
    if not rn then return end
    -- la seule recette à 8 entrées du jeu demande 150 objets d'une matière : 3 000 ticks ne la fabriquent pas (forme « partielle » :
    -- les 8 matières doivent toutes être arrivées dans la machine) ; la forme à 8 se joue en entier sur la copie jetable
    add(label, { kind = "cell", recipe = rn, machine = machine_for(info.fab[rn]), sortie = sortie, n = n or 1, barre = barre or 0, pre = pre, s = s,
      partial = (load_of(rn) > 60) or nil })
  end
  cell("s1-tapis", 1, "tapis")
  cell("s1-coffre", 1, "coffre")
  cell("s1-unite", 1, "unite")
  cell("s1-rangee3", 1, "tapis", 3)
  cell("s2-tapis", 2, "tapis")
  cell("s2-coffre-rangee2", 2, "coffre", 2)
  cell("s3-tapis", 3, "tapis")
  cell("s3-coffre", 3, "coffre")
  cell("s4-tapis", 4, "tapis")
  cell("s4-unite", 4, "unite")
  cell("s5-coffre", 5, "coffre")
  cell("s5-unite", 5, "unite")
  cell("s6-coffre", 6, "coffre")
  cell("s7-coffre", 7, "coffre")
  cell("s8-coffre", 8, "coffre")
  cell("s8-unite", 8, "unite")
  -- la barre : coffre déjà plein à la barre, le bras ne doit rien y ajouter (F95)
  cell("s2-barre", 2, "coffre", 1, 1, true)
  -- plusieurs produits : coffre seul
  local multi = pick(info, function(f) return f.fluides_in == 0 and f.fluides_out == 0 and f.produits >= 2 and f.s <= 4 and machine_for(f) ~= nil end)
  if multi then
    add("multi-produits-coffre", { kind = "cell", recipe = multi, machine = machine_for(info.fab[multi]), sortie = "coffre", n = 1, barre = 0, s = info.fab[multi].s })
  end
  -- fluides en entrée (machine tournée) : une recette à un fluide et un solide, une à deux fluides
  local function fluid_form(label, nfl, sortie, smin, smax)
    local rn = pick(info, function(f) return f.fluides_in == nfl and f.fluides_out == 0 and f.produits == 1 and f.s >= smin and f.s <= smax end)
    if not rn then return end
    local f = info.fab[rn]
    local need = {}
    for _, mn in ipairs(f.machines) do
      local p = game.entity_prototypes[mn]
      if p and p.type == "assembling-machine" and ensure_machine(mn) and M.spec(mn).boxes then
        local nin = 0
        for _, b in ipairs(M.spec(mn).boxes) do if b.io == "in" then nin = nin + 1 end end
        if nin >= nfl and not M.spec(mn).burner_kw then need[#need + 1] = mn end
      end
    end
    if #need == 0 then return end
    add(label, { kind = "cell", recipe = rn, machine = need[1], sortie = sortie, n = 1, barre = 0, fluid = true, s = f.s })
  end
  fluid_form("fluide1-coffre", 1, "coffre", 1, 1)
  fluid_form("fluide1-unite", 1, "unite", 1, 1)
  fluid_form("fluide2-tapis", 2, "tapis", 0, 1)
  return forms
end

--- Le bloc de mall : les recettes du jeu rangées par P.groups sur une machine connue ; le plus gros bloc.
local BLOC_MACHINE = "assembling-machine-1"
local function bloc_form(info)
  local objets, recs = {}, {}
  for _, rn in ipairs(sorted_keys(info.fab)) do
    local f = info.fab[rn]
    local r = game.recipe_prototypes[rn]
    if f.patronnable and f.fluides_in == 0 and f.fluides_out == 0 and f.produits == 1 and f.s >= 1 and f.s <= 4 and r.energy <= 3 then
      local mn
      for _, m in ipairs(f.machines) do if m == BLOC_MACHINE then mn = m; break end end
      if mn then
        local rt = recipe_table(rn)
        local sol = {}
        for _, i in ipairs(rt.ingredients) do sol[#sol + 1] = i.name end
        objets[#objets + 1] = { name = rt.products[1].name, solides = sol, machine = mn, recette = rn }
        recs[rn] = rt
      end
    end
  end
  local cap = PA.bloc_max(M, BLOC_MACHINE)
  local gr = PA.groups(objets, { max = cap })
  local best
  for _, bl in ipairs(gr.blocs) do
    if bl.classe == BLOC_MACHINE and (not best or #bl.objets > #best.objets) then best = bl end
  end
  if not best then return nil end
  local by_item = {}
  for _, o in ipairs(objets) do by_item[o.name] = o end
  local rl = {}
  for _, nm in ipairs(best.objets) do rl[#rl + 1] = by_item[nm].recette end
  return { label = "bloc-mall", kind = "bloc", machine = BLOC_MACHINE, recipes = rl, barre = 4, s = 0, ngroupes = #gr.blocs, nseuls = #gr.seuls }
end

--- Formes de la copie jetable (tools/autotest/ind/jetable_patrons.py) : une machine de 11 de côté, recettes à 5, 7 et 8 entrées.
local function jetable_forms(info)
  local out = {}
  if not (game.entity_prototypes["fo-i5-onze"] and ensure_machine("fo-i5-onze")) then return out end
  for _, c in ipairs({ { 5, "coffre" }, { 5, "unite" }, { 7, "coffre" }, { 7, "unite" }, { 8, "coffre" }, { 8, "unite" } }) do
    local rn = "fo-i5-r" .. c[1]
    if info.fab[rn] and info.fab[rn].patronnable then
      out[#out + 1] = { label = "onze-s" .. c[1] .. "-" .. c[2], kind = "cell", recipe = rn, machine = "fo-i5-onze", sortie = c[2], n = 1, barre = 0, s = c[1] }
    end
  end
  return out
end

local function level_forms(info)
  local out = {}
  local rn = pick(info, function(f) return f.s == 3 and f.fluides_in == 0 and f.fluides_out == 0 and f.produits == 1 end)
  if not rn then return out end
  for _, lv in ipairs({ 1, 7, 13, 19, 30 }) do
    local mn = "fo-lvl-assembler-" .. lv
    if game.entity_prototypes[mn] then
      local ok = false
      for _, m in ipairs(info.fab[rn].machines) do if m == mn then ok = true end end
      if ok and ensure_machine(mn) then
        out[#out + 1] = { label = "niveau-" .. lv, kind = "cell", recipe = rn, machine = mn, sortie = "coffre", n = 1, barre = 0, s = 3 }
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Gabarit d'une forme (pur, refait à la demande : aucun gabarit gardé dans global)
---------------------------------------------------------------------------------------------------
local function gabarit_of(form, kit)
  if form.kind == "bloc" then
    local recs = {}
    for i, rn in ipairs(form.recipes) do recs[i] = recipe_table(rn) end
    return PA.bloc(M, form.machine, recs, kit, form.barre)
  end
  return PA.cellule(M, form.machine, recipe_table(form.recipe), form.sortie, form.n, kit, form.barre)
end

local function slot_origin(i)
  local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
  return X0 + col * SLOT, Y0 + row * SLOT
end

local function place_pole(s, x, y, force)
  for r = 0, 6 do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local p = { x = math.floor(x) + dx + 0.5, y = math.floor(y) + dy + 0.5 }
          if s.can_place_entity({ name = "medium-electric-pole", position = p, force = force }) then
            return s.create_entity({ name = "medium-electric-pole", position = p, force = force })
          end
        end
      end
    end
  end
  return nil
end

--- Pose la forme `i` ; renvoie la fiche (données simples et entités) gardée dans l'état du scénario.
local function build(ctx, st, i, form, kit)
  local s = ctx.surface()
  local sx, sy = slot_origin(i)
  local ox, oy = sx + 3, sy + 3
  local force = FORCE
  local P = { label = form.label, kind = form.kind, ox = ox, oy = oy, fails = {}, sinks = {}, feeds = {}, fluids = {}, counts = {}, machines = {},
    form = form, s = form.s }
  st.P[i] = P
  local g, why = gabarit_of(form, kit)
  if not g then
    P.fails[#P.fails + 1] = "gabarit refusé : " .. tostring(why)
    return
  end
  local errs = M.check(g)
  P.model_errors = #errs
  P.first_error = errs[1]
  P.nominal = g.nominal
  P.w, P.h = g.w, g.h
  local inst = M.instantiate(g, 0, ox, oy)
  local ents = {}
  for j, e in ipairs(inst.entities) do
    local sp = M.spec(e.name)
    local ent = s.create_entity({ name = e.name, position = e.position, direction = e.direction, force = force,
      recipe = (sp.kind == "assembler" or sp.kind == "furnace") and e.recipe or nil })
    ents[j] = ent
    if not ent then
      P.fails[#P.fails + 1] = "création refusée : " .. e.name .. " en " .. serpent.line(e.position)
    elseif sp.kind == "assembler" then
      P.machines[#P.machines + 1] = { ent = ent, recipe = e.recipe, dir = g.entities[j].dir, idx = j }
    end
  end
  P.ents = ents
  P.n_ents, P.n_model = 0, #inst.entities
  for j = 1, #inst.entities do if ents[j] then P.n_ents = P.n_ents + 1 end end
  -- prise et dépôt des bras
  P.arms, P.arms_bad = 0, 0
  for j, e in ipairs(g.entities) do
    local sp = M.spec(e.name)
    if ents[j] and sp.kind == "inserter" then
      P.arms = P.arms + 1
      local px, py = M.rot(e.dir, 0, -sp.reach)
      local dx, dy = M.rot(e.dir, 0, sp.reach + 0.2)
      local pp, dp = ents[j].pickup_position, ents[j].drop_position
      if dist(pp, { x = ox + e.x + px, y = oy + e.y + py }) > TOL or dist(dp, { x = ox + e.x + dx, y = oy + e.y + dy }) > TOL then
        P.arms_bad = P.arms_bad + 1
      end
    end
  end
  -- fils du modèle
  for _, w in ipairs(M.wires(g)) do
    local a, b = ents[w[1]], ents[w[2]]
    if a and b then a.connect_neighbour(b) end
  end
  -- ports : entrées (tapis, tuyau), sorties (tapis, coffre, machine d'unité)
  for pi, p in ipairs(g.ports) do
    local ent = ents[p.ent]
    if ent then
      if p.kind == "tapis" and p.io == "in" then
        P.feeds[#P.feeds + 1] = { ent = ent, lanes = p.lanes }
      elseif p.kind == "tapis" and p.io == "out" then
        P.sinks[#P.sinks + 1] = { ent = ent, pi = pi }
      elseif p.kind == "tuyau" and p.io == "in" then
        P.fluids[#P.fluids + 1] = { ent = ent, fluid = p.fluid }
      elseif p.kind == "quai" and p.io == "out" then
        if p.unite then
          P.unit = true
        else
          P.chests = P.chests or {}
          P.chests[p.ent] = P.chests[p.ent] or { ent = ent, items = {}, bar = p.bar }
          table.insert(P.chests[p.ent].items, p.item)
        end
      end
    end
  end
  -- barre des coffres, éventuellement chargés jusqu'à la barre
  for _, ci in ipairs(sorted_keys(P.chests or {})) do
    local c = P.chests[ci]
    if c.bar then
      local inv = c.ent.get_inventory(defines.inventory.chest)
      inv.set_bar(c.bar + 1)
      c.stack = game.item_prototypes[c.items[1]].stack_size
      if form.pre then
        c.pre = c.stack * c.bar
        inv.insert({ name = c.items[1], count = c.pre })
      end
    end
  end
  -- électricité : poteau d'arène relié au poteau de raccordement, interface au bout
  local pole = g.power_pole and ents[g.power_pole]
  if pole then
    local best, bestd
    for x = ox - 4, ox + g.w + 3 do
      for y = oy - 4, oy + g.h + 3 do
        local inside = x >= ox - 1 and x < ox + g.w + 1 and y >= oy - 1 and y < oy + g.h + 1
        if not inside then
          local pt = { x = x + 0.5, y = y + 0.5 }
          local d = dist(pt, pole.position)
          if d <= 8.5 and (not bestd or d < bestd - 1e-9) then best, bestd = pt, d end
        end
      end
    end
    local ap = best and place_pole(s, best.x, best.y, force)
    if ap then
      ap.connect_neighbour(pole)
      local px, py = ap.position.x, ap.position.y
      local sxv = (px >= ox + g.w / 2) and 1 or -1
      for _, t in ipairs({ { px + 2 * sxv, py }, { px, py + 2 }, { px, py - 2 }, { px - 2 * sxv, py } }) do
        if not P.eei and s.can_place_entity({ name = "electric-energy-interface", position = t, force = force }) then
          local eei = s.create_entity({ name = "electric-energy-interface", position = t, force = force })
          if eei then
            eei.electric_buffer_size = BUF
            eei.power_production = 0
            eei.power_usage = 0
            eei.energy = BUF
            P.eei = eei
          end
        end
      end
    end
    if not P.eei then P.fails[#P.fails + 1] = "alimentation d'arène impossible" end
  else
    P.fails[#P.fails + 1] = "gabarit sans poteau de raccordement"
  end
  for _, m in ipairs(P.machines) do m.base = m.ent.products_finished end
end

local function tick_all(st, tick)
  for _, P in ipairs(st.P) do
    if P.ents then
      if P.eei and P.eei.valid then P.eei.energy = BUF end
      for _, f in ipairs(P.feeds) do
        if f.ent.valid then
          for l = 1, 2 do
            local it = f.lanes[l]
            if it then
              local line = f.ent.get_transport_line(l)
              if line.can_insert_at_back() and line.insert_at_back({ name = it, count = 1 }) then
                P.counts["in:" .. it] = (P.counts["in:" .. it] or 0) + 1
              end
            end
          end
        end
      end
      for _, f in ipairs(P.fluids) do
        if f.ent.valid then
          local cur = f.ent.fluidbox[1]
          if not cur or cur.amount < 90 then f.ent.fluidbox[1] = { name = f.fluid, amount = 100 } end
        end
      end
      for _, sk in ipairs(P.sinks) do
        if sk.ent.valid then
          for l = 1, 2 do
            local line = sk.ent.get_transport_line(l)
            local c = line.get_contents()
            for _, it in ipairs(sorted_keys(c)) do
              P.counts["out:" .. it] = (P.counts["out:" .. it] or 0) + c[it]
              local key = "lane:" .. l .. ":" .. it
              P.counts[key] = (P.counts[key] or 0) + c[it]
            end
            line.clear()
          end
        end
      end
      if P.unit and tick % 60 == 0 then
        for _, m in ipairs(P.machines) do
          if m.ent.valid then
            local out = m.ent.get_output_inventory()
            local c = out.get_contents()
            for _, it in ipairs(sorted_keys(c)) do
              P.counts["unite:" .. it] = (P.counts["unite:" .. it] or 0) + c[it]
              out.remove({ name = it, count = c[it] })
            end
          end
        end
      end
    end
  end
end

return {
  description = "I5 : les patrons (cellule, rangée, bloc de mall) posés, garnis et en marche dans le moteur",
  base = nil,
  check_tick = 2900,

  init = function(ctx)
    ctx.prepare_area(X0 - 4, Y0 - 4, X0 + COLS * SLOT + 4, Y0 + 7 * SLOT + 4, "concrete")
    game.map_settings.enemy_expansion.enabled = false
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 5 then
      st.P = {}
      local ok, info = pcall(remote.call, "fo-iag", "lecture")
      if not (ok and type(info) == "table") then
        st.no_info = tostring(info)
        return
      end
      st.info_summary = info.line
      local kit = kit_of(info)
      st.kit = kit
      local forms = forms_list(info, kit)
      for _, lf in ipairs(level_forms(info)) do forms[#forms + 1] = lf end
      for _, jf in ipairs(jetable_forms(info)) do forms[#forms + 1] = jf end
      local bf = bloc_form(info)
      if bf then forms[#forms + 1] = bf end
      st.bloc_info = bf and { n = #bf.recipes, groupes = bf.ngroupes, seuls = bf.nseuls } or nil
      st.forms = forms
      for i, f in ipairs(forms) do build(ctx, st, i, f, kit) end
    elseif e.tick > 5 and st.P then
      tick_all(st, e.tick)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if st.no_info then ctx.fail("la lecture du catalogue répond (fo-iag, lecture)", st.no_info); return end
    ctx.log("FAIT " .. tostring(st.info_summary))
    ctx.log("FAIT kit " .. serpent.line(st.kit))
    if st.bloc_info then ctx.log(string.format("FAIT bloc de mall : %d recettes du jeu rangées par P.groups (%d bloc(s) en tout, %d recette(s) seule(s))",
      st.bloc_info.n, st.bloc_info.groupes, st.bloc_info.seuls)) end
    local wanted_s = {}
    local got_s = {}
    for _, f in ipairs(st.forms or {}) do if f.s and f.s > 0 then got_s[f.s] = true end end
    for s = 1, 8 do wanted_s[#wanted_s + 1] = s end
    local missing = {}
    for _, s in ipairs(wanted_s) do if not got_s[s] then missing[#missing + 1] = s end end
    for _, f in ipairs(st.forms or {}) do
      if f.kind == "cell" and f.s and f.s >= 5 and f.sortie == "coffre" and not f.refus_vu then
        f.refus_vu = true
        local g, why = PA.cellule(M, f.machine, recipe_table(f.recipe), "tapis", 1, st.kit, 0)
        ctx.check(g == nil and why and why:find("sortie en coffre ou en unité", 1, true) ~= nil,
          "refus écrit : " .. f.s .. " entrées en tapis de sortie", tostring(why))
        break
      end
    end
    ctx.log("FAIT formes de 1 à 8 entrées sans recette dans le jeu (donc non jouées en moteur) : " .. (#missing > 0 and table.concat(missing, ",") or "aucune"))
    local n_ok_forms = 0
    for i, P in ipairs(st.P or {}) do
      local label = P.label
      local f = P.form
      if #P.fails > 0 then
        ctx.fail("forme " .. label .. " : posée", table.concat(P.fails, " ; "))
      else
        local bad = {}
        if P.model_errors ~= 0 then bad[#bad + 1] = "modèle : " .. tostring(P.first_error) end
        if P.n_ents ~= P.n_model then bad[#bad + 1] = "entités créées " .. P.n_ents .. "/" .. P.n_model end
        if P.arms_bad ~= 0 then bad[#bad + 1] = P.arms_bad .. " bras hors du modèle (prise ou dépôt)" end
        -- machines : recette et direction lues, en marche, au moins une fabrication
        local made = 0
        for _, m in ipairs(P.machines) do
          if not m.ent.valid then
            bad[#bad + 1] = "machine détruite"
          else
            local rec = m.ent.get_recipe()
            if not (rec and rec.name == m.recipe) then bad[#bad + 1] = "recette lue " .. tostring(rec and rec.name) .. " au lieu de " .. tostring(m.recipe) end
            if m.ent.direction ~= m.dir then bad[#bad + 1] = "direction lue " .. m.ent.direction .. " au lieu de " .. m.dir end
            if m.ent.status == defines.entity_status.no_power then bad[#bad + 1] = "machine sans courant" end
            made = made + (m.ent.products_finished - (m.base or 0))
            if f.partial then
              -- un seul bras sert un tapis de deux matières : il peut en livrer une avant l'autre ; chaque TAPIS doit avoir livré
              local inv = m.ent.get_inventory(defines.inventory.assembling_machine_input)
              local lack = {}
              for _, fd in ipairs(P.feeds) do
                local got = false
                for l = 1, 2 do if fd.lanes[l] and inv.get_item_count(fd.lanes[l]) > 0 then got = true end end
                if not got and m.ent.products_finished - (m.base or 0) < 1 then lack[#lack + 1] = tostring(fd.lanes[1]) .. "/" .. tostring(fd.lanes[2]) end
              end
              if #lack > 0 then bad[#bad + 1] = "tapis sans aucune livraison à la machine : " .. table.concat(lack, " ; ") end
            elseif m.ent.products_finished - (m.base or 0) < 1 and not f.pre then
              bad[#bad + 1] = "une machine n'a rien fabriqué (" .. tostring(STATUS[m.ent.status]) .. ")"
            end
          end
        end
        -- arrivée du produit
        local arrived = 0
        for _, k in ipairs(sorted_keys(P.counts)) do
          if k:sub(1, 4) == "out:" or k:sub(1, 6) == "unite:" then arrived = arrived + P.counts[k] end
        end
        local in_chests = 0
        for _, ci in ipairs(sorted_keys(P.chests or {})) do
          local c = P.chests[ci]
          local inv = c.ent.get_inventory(defines.inventory.chest)
          for _, it in ipairs(c.items) do in_chests = in_chests + inv.get_item_count(it) end
          if c.pre then
            -- à la barre : le bras n'a rien ajouté
            local cnt = inv.get_item_count(c.items[1])
            if cnt ~= c.pre then bad[#bad + 1] = "barre : le coffre est passé de " .. c.pre .. " à " .. cnt end
          end
        end
        if not f.pre and not f.partial then
          if f.sortie == "tapis" and arrived < 1 then bad[#bad + 1] = "rien au bout du tapis de sortie" end
          if f.sortie == "unite" and arrived < 1 then bad[#bad + 1] = "rien dans la machine d'unité" end
          if (f.sortie == "coffre" or f.kind == "bloc") and in_chests < 1 then bad[#bad + 1] = "rien dans les coffres" end
        elseif f.pre then
          -- la barre : la machine a fabriqué, le coffre n'a pas bougé
          if made < 1 then bad[#bad + 1] = "barre : la machine n'a rien fabriqué" end
        end
        -- fluides : la machine tournée porte bien le fluide de la recette
        if f.fluid then
          for _, m in ipairs(P.machines) do
            local fb = m.ent.fluidbox
            local seen = false
            for k = 1, #fb do if fb[k] and fb[k].amount > 0 then seen = true end end
            if not seen then bad[#bad + 1] = "aucun fluide dans la machine" end
          end
        end
        if #bad == 0 then
          n_ok_forms = n_ok_forms + 1
          ctx.ok("forme " .. label, string.format("%s / %s : %dx%d, %d entités, %d fabrication(s), arrivé %d, coffres %d", tostring(f.recipe or "bloc"),
            tostring(f.machine), P.w, P.h, P.n_ents, made, arrived, in_chests))
        else
          ctx.fail("forme " .. label, table.concat(bad, " ; "))
          ctx.log("FAIT diag " .. label .. " (recette " .. tostring(f.recipe) .. ") : " .. diag(P))
        end
      end
    end
    ctx.check(n_ok_forms == #(st.P or {}) and n_ok_forms > 0, "toutes les formes posées fabriquent", n_ok_forms .. " sur " .. #(st.P or {}))
  end,
}
