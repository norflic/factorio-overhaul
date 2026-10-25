-- Scénario greffé « ia1-diag » (lot IA1-e1, docs/EQUIPES_PNJ.md §6.1 à §6.3, §16 ; RD_LOG E166, E167 proposées).
-- Arène de modules d'IA1-c (shared/team/modules.lua) : les trois cas de P.ARENA (shared/team/production.lua), chacun
-- posé par une force à part, alimenté par le script (tapis d'entrée remplis voie par voie ; le fer du module B
-- ÉTRANGLÉ à 40 % du besoin par un seau à jetons), électricité par le poteau de test (fo-autotest-power-*).
-- Les débits sont LUS par les statistiques de chaque force (LuaForce.item_production_statistics : get_input_count
-- pour la production, get_output_count pour la consommation, get_flow_count sur 10 min en recoupement) ; les machines
-- témoins (celles de la recette de sortie) sont relevées toutes les 600 ticks (status, inventaire d'entrée).
-- Phase 1 (5 min d'échauffement, 10 min de mesure) : diagnostic du moteur (débits lus) et du modèle (débits calculés,
-- P.model_module), même fonction pure P.diagnose ; contrôles : verdicts, ingrédient manquant, choix identique, écarts
-- chiffrés, retour sur investissement de chaque option journalisé (lignes OPTION).
-- Phase 2 : le choix est APPLIQUÉ (A : module reconstruit au gabarit de l'option retenue ; B : l'amont renforcé du
-- déficit chiffré ; C : rien), puis 5 min d'échauffement et 10 min de mesure : gain mesuré contre gain prédit,
-- nouveaux verdicts du moteur et du modèle.
-- Le livre de recettes du jeu (game.recipe_prototypes) est comparé recette par recette au livre hors jeu
-- (tests/fixtures/recipes_ia1e.lua, normalisation du harness) : le test hors jeu tourne sur les vraies recettes.
-- Lancement : `fo-autotest.bat nopause 108100 ia1-diag <source>` (environ 1 min).

local M = require("__factorio-overhaul__/shared/team/modules")
local P = require("__factorio-overhaul__/shared/team/production")
local FIX = require("__factorio-overhaul__/tests/fixtures/recipes_ia1e")

local X0, Y0 = -3200, 1600
local GAP = 160                -- modules éloignés : le poteau de test couvre 64 tuiles
local WARM1 = 18000            -- 5 min
local CHECK1 = WARM1 + 36000   -- 10 min de mesure
local WARM2 = CHECK1 + 18000
local CHECK2 = WARM2 + 36000
local SAMPLE = 600
local TOL_MODEL = 0.05         -- débit mesuré à ±5 % du modèle
local TOL_GAIN = 0.10          -- gain mesuré à ±10 % du gain prédit
local TOL_STATS = 0.02         -- statistiques de 10 min contre compteurs, et contre la sortie comptée par le script

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k)
  return k
end

local function pct(a, b) return b ~= 0 and string.format("%+.2f %%", 100 * (a - b) / b) or "n/d" end

--- Livre du jeu, sous la forme du harness (P.book) : noms triés.
local function game_book_src()
  local src = {}
  local names = {}
  for name in pairs(game.recipe_prototypes) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local r = game.recipe_prototypes[name]
    src[name] = { category = r.category, energy = r.energy, hidden = r.hidden, ingredients = r.ingredients, products = r.products }
  end
  return src, #names
end

--- Comparaison au livre hors jeu (normalisation du harness : quantité, ou moyenne min/max, probabilité ignorée).
local function compare_books(src)
  local bad, order = {}, 0
  local function amount(x)
    return x.amount or ((x.amount_min and x.amount_max) and (x.amount_min + x.amount_max) / 2) or 1
  end
  local function key_list(list)
    local out = {}
    for _, x in ipairs(list or {}) do out[#out + 1] = (x.type or "item") .. ":" .. x.name .. ":" .. string.format("%.6g", amount(x)) end
    return out
  end
  local n = 0
  for _, name in ipairs(sorted_keys(FIX)) do
    n = n + 1
    local f, g = FIX[name], src[name]
    if not g then bad[#bad + 1] = name .. " absente du jeu"
    else
      if f.category ~= g.category then bad[#bad + 1] = name .. " catégorie" end
      if math.abs(f.energy - g.energy) > 1e-9 then bad[#bad + 1] = name .. " durée " .. g.energy end
      if (f.hidden == true) ~= (g.hidden == true) then bad[#bad + 1] = name .. " cachée" end
      for _, side in ipairs({ "ingredients", "products" }) do
        local a, b = key_list(f[side]), key_list(g[side])
        local same_order = table.concat(a, "|") == table.concat(b, "|")
        table.sort(a)
        table.sort(b)
        if table.concat(a, "|") ~= table.concat(b, "|") then bad[#bad + 1] = name .. " " .. side
        elseif not same_order then order = order + 1 end
      end
    end
  end
  return n, bad, order
end

--- Gabarit courant d'un module (recalculé : aucun gabarit gardé dans global).
local function gabarit(R)
  local g = M.get(R.key)
  if R.kind == "agrandir" then g = M.extend(g, R.n)
  elseif R.kind == "ameliorer" or R.kind == "remplacer" then g = M.upgrade_plan(g, R.n).g end
  return g
end

local function build(ctx, st, R, g, ox, oy)
  local s = ctx.surface()
  local inst, why = M.instantiate(g, 0, ox, oy)
  if not inst then R.fails[#R.fails + 1] = "instanciation : " .. tostring(why); return end
  local recipe = P.recipe_for(st.book_fix, R.item)
  local ents = {}
  for j, e in ipairs(inst.entities) do
    local sp = M.spec(e.name)
    local ent = s.create_entity({ name = e.name, position = e.position, direction = e.direction, force = R.force,
      recipe = (sp.kind == "assembler") and e.recipe or nil })
    if not ent then R.fails[#R.fails + 1] = "création refusée : " .. e.name
    else
      ents[j] = ent
      R.all[#R.all + 1] = ent
      if sp.kind == "assembler" and e.recipe == recipe then R.wit[#R.wit + 1] = ent end
    end
  end
  for _, w in ipairs(M.wires(g)) do
    local a, b = ents[w[1]], ents[w[2]]
    if a and b then a.connect_neighbour(b) end
  end
  for _, p in ipairs(g.ports) do
    local ent = ents[p.ent]
    if ent and p.kind == "tapis" and p.io == "in" then R.src[#R.src + 1] = { ent = ent, lanes = { p.lanes[1], p.lanes[2] } }
    elseif ent and p.kind == "tapis" and p.io == "out" then R.sink[#R.sink + 1] = ent end
  end
  R.n_ents = (R.n_ents or 0) + #g.entities
  R.recipe = recipe
end

local function setup_module(ctx, st, R)
  R.all, R.src, R.sink, R.wit, R.fails, R.n_ents = {}, {}, {}, {}, {}, 0
  local g = gabarit(R)
  build(ctx, st, R, g, R.ox, R.oy)
  if R.kind == "construire" then build(ctx, st, R, g, R.ox, R.oy + g.h + 6) end
  R.inputs = {}
  for _, it in ipairs(sorted_keys(g.inputs or {})) do R.inputs[it] = g.inputs[it] end
end

local function destroy_module(R)
  for i = 1, #R.all do if R.all[i].valid then R.all[i].destroy() end end
  R.all, R.src, R.sink, R.wit = {}, {}, {}, {}
end

local function feed(st)
  for _, R in ipairs(st.R) do
    for _, sr in ipairs(R.src) do
      if sr.ent.valid then
        for l = 1, 2 do
          local it = sr.lanes[l]
          if it then
            local line = sr.ent.get_transport_line(l)
            local share = R.feed[it] or 1
            if share >= 1 then
              if line.can_insert_at_back() and line.insert_at_back({ name = it, count = 1 }) then R.fed[it] = (R.fed[it] or 0) + 1 end
            else
              -- seau à jetons : (besoin au nominal × part) objets/s, réparti sur les voies qui portent l'objet
              local lanes = 0
              for _, s2 in ipairs(R.src) do for l2 = 1, 2 do if s2.lanes[l2] == it then lanes = lanes + 1 end end end
              local key = it .. "@" .. l
              R.bucket[key] = math.min(4, (R.bucket[key] or 0) + (R.inputs[it] or 0) * share / 60 / math.max(1, lanes))
              if R.bucket[key] >= 1 and line.can_insert_at_back() and line.insert_at_back({ name = it, count = 1 }) then
                R.bucket[key] = R.bucket[key] - 1
                R.fed[it] = (R.fed[it] or 0) + 1
              end
            end
          end
        end
      end
    end
    for _, sk in ipairs(R.sink) do
      if sk.valid then
        for l = 1, 2 do
          local line = sk.get_transport_line(l)
          local c = line.get_contents()
          for _, it in ipairs(sorted_keys(c)) do R.out[it] = (R.out[it] or 0) + c[it] end
          line.clear()
        end
      end
    end
  end
end

local function shortage_status(st)
  return st == defines.entity_status.item_ingredient_shortage or st == defines.entity_status.no_ingredients
    or st == defines.entity_status.fluid_ingredient_shortage
end

--- Un relevé = un tour sur TOUTES les machines témoins du module : un ingrédient « manque » à ce relevé s'il manque à
--- au moins une d'elles (essai 1 : sur une ligne affamée, le premier assembleur prend tout le fer et le second manque
--- toujours ; compté machine par machine, le manque ne valait que 50 % des lectures, au ras du seuil).
local function sample(st)
  for _, R in ipairs(st.R) do
    local rec = game.recipe_prototypes[R.recipe]
    local W = R.witness
    local lack, full, any = {}, false, false
    for _, w in ipairs(R.wit) do
      if w.valid then
        any = true
        local status = w.status
        local sname = tostring(status)
        for _, k in ipairs(sorted_keys(defines.entity_status)) do if defines.entity_status[k] == status then sname = k end end
        W.status[sname] = (W.status[sname] or 0) + 1
        if status == defines.entity_status.full_output then full = true end
        if shortage_status(status) then
          local inv = w.get_inventory(defines.inventory.assembling_machine_input)
          for _, ing in ipairs(rec.ingredients) do
            if ing.type == "item" and inv.get_item_count(ing.name) < ing.amount then lack[ing.name] = true end
          end
        end
      end
    end
    if any then
      W.samples = W.samples + 1
      W.readings = (W.readings or 0) + #R.wit
      if full then W.output_full = W.output_full + 1 end
      for _, it in ipairs(sorted_keys(lack)) do W.shortage[it] = (W.shortage[it] or 0) + 1 end
    end
  end
end

local function snapshot(st, phase)
  for _, R in ipairs(st.R) do
    local f = game.forces[R.force]
    local stats = f.item_production_statistics
    local snap = { prod = stats.get_input_count(R.item), out = R.out[R.item] or 0, cons = {}, fed = {} }
    for _, it in ipairs(sorted_keys(R.inputs)) do snap.cons[it] = stats.get_output_count(it); snap.fed[it] = R.fed[it] or 0 end
    R.snap = R.snap or {}
    R.snap[phase] = snap
    R.witness = { samples = 0, shortage = {}, output_full = 0, status = {} }
  end
end

--- Mesure d'une fenêtre : module pour P.diagnose_one, plus les recoupements des statistiques.
local function measure(st, R, idx, a, b, g)
  local f = game.forces[R.force]
  local stats = f.item_production_statistics
  local s0 = R.snap[idx]
  local minutes = (b - a) / 3600
  local prod = (stats.get_input_count(R.item) - s0.prod) / minutes
  local flow10 = stats.get_flow_count({ name = R.item, input = true, precision_index = defines.flow_precision_index.ten_minutes })
  local out = ((R.out[R.item] or 0) - s0.out) / minutes
  local inputs = {}
  for _, it in ipairs(sorted_keys(R.inputs)) do
    inputs[#inputs + 1] = { item = it, measured_per_min = (stats.get_output_count(it) - s0.cons[it]) / minutes,
      fed_per_min = ((R.fed[it] or 0) - s0.fed[it]) / minutes }
  end
  local W = R.witness
  return { id = R.id, g = g, item = R.item, demand_per_min = R.demand, measured_per_min = prod, inputs = inputs,
    witness = { samples = W.samples, shortage = W.shortage, output_full = W.output_full } }, flow10, out
end

local function ctx_diag(st)
  return { values = st.values, max_level = P.ARENA_MAX_LEVEL, free_lots = 1, book = st.book }
end

local function log_diag(ctx, phase, source, d)
  ctx.log(string.format("DIAG\t%s\t%s\t%s\t%s\tmesure %.3f/min\tnominal %.3f/min\tobjectif %.3f/min\tratio %.4f\tdeficit %.3f/min (%.4f)\tmanque %s (%.2f)\tsortie pleine %.2f",
    phase, source, d.id, d.verdict, d.measured_per_min, d.nominal_per_min, d.demand_per_min, d.ratio, d.deficit_per_min,
    d.deficit_ratio, tostring(d.lacking), d.lack_share or 0, d.full_share or 0))
  for _, o in ipairs(d.options or {}) do
    ctx.log(string.format("OPTION\t%s\t%s\t%s\t%s\t%s\tcout %.3f MU\tajout %.3f/min\tutile %.3f/min\tgain %.3f MU/min\tT %.4f min\tscore %.4f%s",
      phase, source, d.id, o.kind, o.label, o.cost_mu, o.added_per_min, o.useful_per_min, o.gain_mu_per_min, o.roi_min, o.score,
      o.lost_mu and string.format("\tperte estimee %.3f MU", o.lost_mu) or ""))
  end
  for _, r in ipairs(d.refused or {}) do ctx.log(string.format("REFUS\t%s\t%s\t%s\t%s\t%s", phase, source, d.id, r.kind, tostring(r.reason))) end
  if d.choice then ctx.log(string.format("CHOIX\t%s\t%s\t%s\t%s\t%s\tT %.4f min", phase, source, d.id, d.choice.kind, d.choice.label, d.choice.roi_min)) end
  if d.upstream then
    local parts = {}
    for _, p in ipairs(d.upstream.plan or {}) do parts[#parts + 1] = string.format("%s %s %.3f → %d", p.item, p.machine, p.machines or 0, p.machines_ceil or 0) end
    ctx.log(string.format("AMONT\t%s\t%s\t%s\t%s\tbesoin %.3f/min\tlivre %.3f/min\tdeficit %.3f/min\tplan %s", phase, source, d.id,
      d.upstream.item, d.upstream.need_per_min, d.upstream.supplied_per_min, d.upstream.deficit_per_min, table.concat(parts, " ; ")))
  end
end

--- Phase de mesure : diagnostic du moteur et du modèle, recoupements ; rend les diagnostics.
local function phase_check(ctx, st, phase, idx, a, b)
  local eng, mod = {}, {}
  for i, R in ipairs(st.R) do
    local g = gabarit(R)
    local m, flow10, out = measure(st, R, idx, a, b, g)
    local model = P.model_module({ id = R.id, key = R.key, item = R.item, demand_per_min = R.demand, feed = R.feed }, g)
    if R.kind == "construire" then model.measured_per_min = 2 * model.measured_per_min; m.g = g end
    eng[i] = P.diagnose_one(m, ctx_diag(st))
    mod[i] = P.diagnose_one(model, ctx_diag(st))
    log_diag(ctx, phase, "moteur", eng[i])
    log_diag(ctx, phase, "modele", mod[i])
    -- statistiques : moyenne de 10 min du moteur, compteurs, sortie comptée par le script
    local ok_stats = math.abs(flow10 - m.measured_per_min) <= TOL_STATS * m.measured_per_min
      and math.abs(out - m.measured_per_min) <= TOL_STATS * m.measured_per_min
    local ins = {}
    for _, x in ipairs(m.inputs) do ins[#ins + 1] = string.format("%s consommé %.2f/min, livré %.2f/min", x.item, x.measured_per_min, x.fed_per_min) end
    ctx.log(string.format("STATS\t%s\t%s\tproduction %.4f/min (compteurs)\t%.4f/min (get_flow_count 10 min, %s)\tsortie du port %.4f/min (%s)\t%s",
      phase, R.id, m.measured_per_min, flow10, pct(flow10, m.measured_per_min), out, pct(out, m.measured_per_min), table.concat(ins, " ; ")))
    ctx.check(ok_stats, phase .. " " .. R.id .. " : statistiques de la force (compteurs, moyenne de 10 min) = sortie du module à ±2 %",
      string.format("%.2f / %.2f / %.2f par min", m.measured_per_min, flow10, out))
    ctx.check(math.abs(eng[i].measured_per_min - mod[i].measured_per_min) <= TOL_MODEL * mod[i].measured_per_min,
      phase .. " " .. R.id .. " : débit lu à ±5 % du modèle", string.format("moteur %.2f/min, modèle %.2f/min (%s)",
        eng[i].measured_per_min, mod[i].measured_per_min, pct(eng[i].measured_per_min, mod[i].measured_per_min)))
    local stt = {}
    for _, k in ipairs(sorted_keys(R.witness.status)) do stt[#stt + 1] = k .. ":" .. R.witness.status[k] end
    ctx.log(string.format("TEMOINS\t%s\t%s\t%d relevés de %d machine(s)\tstatus par lecture %s", phase, R.id, R.witness.samples,
      #R.wit, table.concat(stt, " ")))
  end
  return eng, mod
end

local function choice_text(c) return c and (c.kind .. "@" .. tostring(c.n)) or "aucun" end

return {
  description = "ia1-diag : solveur et diagnostic (IA1-e1) sur l'arene de modules d'IA1-c, debits lus par les statistiques de force, choix applique et mesure",
  base = nil,
  check_tick = CHECK2,
  shots_delay = 600,

  init = function(ctx)
    local st = ctx.state()
    game.map_settings.pollution.enabled = false
    game.map_settings.enemy_expansion.enabled = false
    -- 1. livre du jeu contre livre hors jeu
    local src, n_game = game_book_src()
    local n_fix, bad, order = compare_books(src)
    ctx.check(#bad == 0 and n_fix == n_game, "livre du jeu = livre hors jeu (tests/fixtures/recipes_ia1e.lua) : " .. n_fix .. " recettes au livre, " .. n_game .. " au jeu",
      table.concat(bad, " | ") .. (order > 0 and (" ; ordre différent (même contenu) : " .. order) or ""))
    ctx.log("livre : " .. n_game .. " recettes au jeu, " .. order .. " liste(s) d'ingrédients ou de produits dans un autre ordre (contenu identique)")
    st.book = P.book(src)
    st.book_fix = P.book(FIX)
    st.values = P.values(st.book)
    local vfix = P.values(st.book_fix)
    local vdiff, vdiff_arena = {}, {}
    local arena_items = {}
    for _, c in ipairs(P.ARENA) do
      local g = M.get(c.key)
      arena_items[c.item] = true
      for _, e in ipairs(g.entities) do arena_items[e.name] = true end
      for _, it in ipairs(sorted_keys(g.inputs or {})) do arena_items[it] = true end
      local ex = g.extensions and g.extensions[1]
      if ex then for _, e in ipairs(M.extend(g, ex.max).entities) do arena_items[e.name] = true end end
    end
    for _, k in ipairs(sorted_keys(vfix)) do
      if math.abs((st.values[k] or -1) - vfix[k]) > 1e-9 then
        vdiff[#vdiff + 1] = k
        if arena_items[k] then vdiff_arena[#vdiff_arena + 1] = k end
      end
    end
    ctx.check(#vdiff_arena == 0 and math.abs(st.values["iron-plate"] - 1) < 1e-12 and math.abs(st.values["iron-gear-wheel"] - 2) < 1e-12,
      "valeurs MU du jeu = valeurs hors jeu pour l'arène (plaque de fer 1 MU, engrenage 2)", table.concat(vdiff_arena, ", "))
    ctx.log("valeurs MU : " .. #vdiff .. " écart(s) jeu / hors jeu, hors arène (probabilités ignorées par le livre hors jeu) : " .. table.concat(vdiff, ", "))
    -- 2. machines du jeu contre P.machine
    local mbad = {}
    for _, name in ipairs({ "assembling-machine-2" }) do
      local p = game.entity_prototypes[name]
      local m = P.machine(name)
      if p.crafting_speed and math.abs(p.crafting_speed - m.speed) > 1e-9 then mbad[#mbad + 1] = name .. " vitesse " .. p.crafting_speed end
      if p.type == "assembling-machine" then
        local kw = p.energy_usage * 60 / 1000
        local drain = p.electric_energy_source_prototype.drain * 60 / 1000
        if math.abs(kw - m.usage_kw) > 1e-6 or math.abs(drain - m.drain_kw) > 1e-6 then mbad[#mbad + 1] = string.format("%s %.3f kW + %.3f kW", name, kw, drain) end
      end
    end
    ctx.check(#mbad == 0, "assembleur 2 du jeu = P.machine (0,75 ; 150 kW + 5 kW de ponction)", table.concat(mbad, " | "))
    -- 3. arène
    st.R = {}
    for i, c in ipairs(P.ARENA) do
      local ox, oy = X0 + (i - 1) * GAP, Y0
      ctx.prepare_area(ox - 12, oy - 12, ox + 40, oy + 40, "grass-1")
      local fname = "fo-ia1d-" .. string.lower(c.id)
      local force = game.forces[fname] or game.create_force(fname)
      force.set_cease_fire("enemy", true)
      game.forces.enemy.set_cease_fire(force, true)
      for _, rn in ipairs(M.recipe_names()) do if force.recipes[rn] then force.recipes[rn].enabled = true end end
      local R = { id = c.id, key = c.key, item = c.item, demand = c.demand_per_min, feed = {}, force = fname, ox = ox, oy = oy,
        fed = {}, out = {}, bucket = {}, witness = { samples = 0, shortage = {}, output_full = 0, status = {} } }
      for _, it in ipairs(sorted_keys(c.feed)) do R.feed[it] = c.feed[it] end
      setup_module(ctx, st, R)
      ctx.power(ox - 4.5, oy - 4.5, fname)
      st.R[i] = R
    end
    local fails = {}
    for _, R in ipairs(st.R) do for _, f in ipairs(R.fails) do fails[#fails + 1] = R.id .. " : " .. f end end
    ctx.check(#fails == 0, "arène posée : " .. #st.R .. " modules (engrenages, circuits verts, engrenages), forces séparées", table.concat(fails, " | "))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.R then return end
    feed(st)
    local t = e.tick
    if t == WARM1 then snapshot(st, 1) end
    if t == WARM2 then snapshot(st, 2) end
    if t % SAMPLE == 0 and ((t > WARM1 and t <= CHECK1) or (t > WARM2 and t <= CHECK2)) then sample(st) end
    if t == CHECK1 then
      local eng, mod = phase_check(ctx, st, "phase1", 1, WARM1, CHECK1)
      local A, B, C = 1, 2, 3
      ctx.check(eng[A].verdict == "capacite" and mod[A].verdict == "capacite", "phase1 A : manque de capacité détecté (moteur et modèle)",
        string.format("moteur %s (%.1f/min pour %.0f voulus), modèle %s", eng[A].verdict, eng[A].measured_per_min, eng[A].demand_per_min, mod[A].verdict))
      local ce, cmo = eng[A].choice, mod[A].choice
      ctx.check(ce and cmo and ce.kind == cmo.kind and ce.n == cmo.n, "phase1 A : choix du moteur = choix du calcul hors jeu",
        string.format("moteur %s (score %.4f, T %.4f min), modèle %s (score %.4f, T %.4f min) ; écarts score %s, T %s", choice_text(ce), ce and ce.score or 0,
          ce and ce.roi_min or 0, choice_text(cmo), cmo and cmo.score or 0, cmo and cmo.roi_min or 0,
          (ce and cmo) and pct(ce.score, cmo.score) or "n/d", (ce and cmo) and pct(ce.roi_min, cmo.roi_min) or "n/d"))
      local roi_ok = #(eng[A].options or {}) >= 2
      for _, o in ipairs(eng[A].options or {}) do if not (o.roi_min > 0 and o.roi_min < math.huge and o.cost_mu > 0) then roi_ok = false end end
      ctx.check(roi_ok, "phase1 A : retour sur investissement chiffré pour chaque option (coût MU ÷ gain MU/min)", #(eng[A].options or {}) .. " options")
      ctx.check(eng[B].verdict == "affame" and mod[B].verdict == "affame" and eng[B].lacking == "iron-plate" and mod[B].lacking == "iron-plate"
        and (eng[B].lack_share or 0) >= 0.9,
        "phase1 B : module affamé détecté, le fer manque chez les témoins à 90 % des relevés ou plus (moteur et modèle)",
        string.format("moteur %s ratio %.3f manque %s (%.2f des relevés), modèle %s", eng[B].verdict, eng[B].ratio, tostring(eng[B].lacking), eng[B].lack_share or 0, mod[B].verdict))
      local ue, um = eng[B].upstream, mod[B].upstream
      ctx.check(ue and um and ue.item == "iron-plate" and math.abs(ue.deficit_per_min - um.deficit_per_min) <= 0.1 * um.deficit_per_min and eng[B].options == nil,
        "phase1 B : on traite l'amont (déficit de fer chiffré à ±10 % du modèle), aucune option en aval",
        string.format("moteur %.2f/min, modèle %.2f/min (%s)", ue and ue.deficit_per_min or -1, um and um.deficit_per_min or -1,
          (ue and um) and pct(ue.deficit_per_min, um.deficit_per_min) or "n/d"))
      ctx.check(eng[C].verdict == "ok" and mod[C].verdict == "ok", "phase1 C : témoin à l'aise (moteur et modèle)", eng[C].verdict .. " / " .. mod[C].verdict)
      -- appliquer : A reconstruit au gabarit de l'option retenue ; B : amont renforcé du déficit chiffré
      local RA, RB = st.R[A], st.R[B]
      st.pred = { a_before = eng[A].measured_per_min, a_added = ce and ce.added_per_min or 0, a_kind = ce and ce.kind,
        b_share = ue and (ue.need_per_min / (RB.inputs["iron-plate"] * 60)) or 1 }
      if ce then
        destroy_module(RA)
        RA.kind, RA.n = ce.kind, ce.n
        setup_module(ctx, st, RA)
        ctx.log(string.format("APPLIQUE\tA\t%s\t%s\t%d entités posées\tgain prédit %.3f/min", ce.kind, ce.label, RA.n_ents, ce.added_per_min))
        ctx.check(#RA.fails == 0 and #RA.all == RA.n_ents, "phase2 A : module reconstruit au gabarit choisi (" .. ce.label .. ")", table.concat(RA.fails, " | "))
      end
      if ue then
        RB.feed["iron-plate"] = st.pred.b_share
        ctx.log(string.format("APPLIQUE\tB\tamont\tfer livré à %.4f du besoin nominal (%.3f/min)", st.pred.b_share, ue.need_per_min))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pred then ctx.check(false, "phase2 : phase 1 non jouée"); return end
    local eng, mod = phase_check(ctx, st, "phase2", 2, WARM2, CHECK2)
    local gained = eng[1].measured_per_min - st.pred.a_before
    ctx.check(st.pred.a_added > 0 and math.abs(gained - st.pred.a_added) <= TOL_GAIN * st.pred.a_added,
      "phase2 A : gain mesuré = gain prédit par l'option à ±10 %",
      string.format("%s : prédit %+.2f/min, mesuré %+.2f/min (%s)", tostring(st.pred.a_kind), st.pred.a_added, gained, pct(gained, st.pred.a_added)))
    ctx.check(eng[1].verdict == mod[1].verdict, "phase2 A : nouveau verdict du moteur = modèle (" .. eng[1].verdict .. ")",
      string.format("moteur %s (déficit %.1f %%), modèle %s (déficit %.1f %%)", eng[1].verdict, 100 * eng[1].deficit_ratio, mod[1].verdict, 100 * mod[1].deficit_ratio))
    ctx.check(eng[2].verdict == "ok" and eng[2].ratio >= 0.9 and mod[2].verdict == "ok", "phase2 B : amont renforcé, le module revient à son nominal",
      string.format("ratio %.3f, verdict moteur %s, modèle %s", eng[2].ratio, eng[2].verdict, mod[2].verdict))
    ctx.check(eng[3].verdict == "ok", "phase2 C : témoin toujours à l'aise", eng[3].verdict)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    for _, R in ipairs(st.R or {}) do add("ia1-diag-" .. R.id, R.ox + 12, R.oy + 6, 1.0, 0) end
  end,
}
