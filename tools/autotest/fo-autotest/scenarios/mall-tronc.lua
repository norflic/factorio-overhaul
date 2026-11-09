--[[
  Micro-banc « mall-tronc » du lot MALL (tranche 3, 9/11) : le TRONC du mall contre le moteur réel. Chaîne : demande directe (remote fo-mall offre) -> projet (têtes de ligne, lignes, prises, amenée,
  cellules) -> PNJ -> coffres de tête -> bras -> LIGNE du tronc -> répartiteur -> amenée -> tapis de rangée -> machines -> coffres de sortie. Aucune tête de quais sur la rangée.
  Critères en FONCTION : objets fabriqués (products_finished), plaques vues sur l'amenée, ligne vivante après la prise (le flux continue vers la rangée 2 quand elle arrive).
  Lancement : py -3.9 -B <banc.py> --out <archive> --qui mall -- 12000 mall-tronc <source>
]]

local TAG = "FO-MALL-TRONC"
local SECT = { x0 = 20, y0 = -48, x1 = 84, y1 = 16, dir = 2, ext = 0 }
local KIT = { machine = "assembling-machine-2", bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", poteau = "small-electric-pole", coffre = "iron-chest",
  repartiteur = "splitter", souterrain = "underground-belt" }

local DEMANDE = {
  { item = "iron-gear-wheel", recipe = "iron-gear-wheel", machines = 4 },
  { item = "iron-stick", recipe = "iron-stick", machines = 2 },
  { item = "copper-cable", recipe = "copper-cable", machines = 2 },
}

local function demandes(extra)
  local out = {}
  for _, d in ipairs(DEMANDE) do
    local sol = {}
    for _, ing in ipairs(game.recipe_prototypes[d.recipe].ingredients) do
      if ing.type == "item" then sol[#sol + 1] = ing.name end
    end
    table.sort(sol)
    out[#out + 1] = { item = d.item, recipe = d.recipe, machine = KIT.machine, machines = d.machines + ((extra or {})[d.item] or 0), solides = sol, rate = 30 }
  end
  return out
end

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 3200 }, { "copper-plate", 3200 },
    { "assembling-machine-2", 24 }, { "inserter", 80 }, { "long-handed-inserter", 40 }, { "transport-belt", 400 }, { "small-electric-pole", 60 }, { "iron-chest", 40 }, { "splitter", 20 }, { "underground-belt", 20 },
  }) do
    local n = chest.insert({ name = it[1], count = it[2] })
    if n ~= it[2] then log(string.format("[%s] STOCK INCOMPLET : %s, %d sur %d", TAG, it[1], n, it[2])) end
  end
end

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 40, 0 }, 7)
  s.force_generate_chunk_requests()
  for _, e in ipairs(s.find_entities_filtered({ area = { { -60, -90 }, { 160, 90 } }, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -90, 89 do for x = -60, 159 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
end

local function report(ctx) return ctx.remote("fo-mall", "report", "player") end

return {
  description = "MALL T3 : tronc, prises, rangee alimentee sans quai, production lue aux compteurs",
  base = nil,
  check_tick = 11800,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    shape(ctx)
    for _, r in ipairs({ "assembling-machine-2", "long-handed-inserter", "inserter", "transport-belt", "iron-chest", "splitter", "underground-belt", "iron-stick", "copper-cable", "iron-gear-wheel" }) do
      game.forces.player.recipes[r].enabled = true
    end
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    stock_chest(chest)
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "sect", SECT) ~= nil, "secteur impose")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "force_pret", true) == true, "etat S force (banc)")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "sans_raccord", true) == true, "sans raccord au reseau (banc)")
    st.t0 = game.tick
    st.phase = "demande"
    st.log_next = 0
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local s = ctx.surface()
    local t = e.tick - st.t0
    if st.eei and st.eei.valid then st.eei.energy = 1e9 end
    if t % 60 ~= 0 then return end
    ctx.remote("fo-mall", "minute", "player", {}, {}, e.tick)
    local rep = report(ctx)
    local row = rep and rep.rows and rep.rows[1]
    if t >= st.log_next then
      st.log_next = t + 600
      local parts = {}
      for _, q in ipairs(row and row.projects or {}) do
        local miss = {}
        for _, m in ipairs(q.missing or {}) do miss[#miss + 1] = tostring(m[1]) .. " x" .. tostring(m[2]) end
        parts[#parts + 1] = string.format("%d[%d-%d]:%s(%s){%s}", q.id, q.from, q.to, tostring(q.state), tostring(q.reason), table.concat(miss, ","))
      end
      ctx.log(string.format("[%s] t=%d phase=%s rangees=%d cellules=%s fabriques=%s coffres=%s machines=%s projets %s", TAG, t, tostring(st.phase), rep and rep.rows and #rep.rows or 0,
        row and row.cells or "-", rep and rep.fab and rep.fab.made or "-", rep and rep.fab and rep.fab.chests or "-", rep and rep.fab and rep.fab.machines or "-", table.concat(parts, " ")))
    end
    if st.phase == "demande" and t >= 120 then
      local id = ctx.remote("fo-mall", "offre", "player", demandes(), KIT)
      ctx.check(id ~= nil, "projet de la rangee du tronc demande", tostring(id))
      st.phase = "premier"
    elseif st.phase == "premier" and row and row.projects[1] and row.projects[1].state == "fini" then
      -- courant du banc : un poteau et une interface près de la tête des lignes (poteau de la ligne 1 en (-8,5 ; -1,5), repère absolu)
      local hx = rep.rep.ox - 8.5
      local hy = rep.rep.oy - 1.5
      local p2 = s.create_entity({ name = "small-electric-pole", position = { hx - 4, hy }, force = "player" })
      local eei = s.create_entity({ name = "electric-energy-interface", position = { hx - 6, hy }, force = "player" })
      ctx.check(p2 ~= nil and eei ~= nil, "courant du banc pose")
      if eei then eei.electric_buffer_size = 1e9; eei.power_production = 1e9 / 60; eei.power_usage = 0; eei.energy = 1e9; st.eei = eei end
      st.phase, st.t_first = "production", t
      ctx.log(string.format("[%s] section 1 finie a t=%d", TAG, t))
    elseif st.phase == "production" and t >= st.t_first + 1500 then
      st.prod1 = rep.fab
      ctx.log(string.format("[%s] apres 1500 ticks : fabriques %s", TAG, tostring(rep.fab and rep.fab.made)))
      local id2 = ctx.remote("fo-mall", "offre", "player", demandes({ ["iron-gear-wheel"] = 2 }), KIT)
      ctx.check(id2 ~= nil, "allongement demande (" .. tostring(id2) .. ")")
      st.phase = "fin"
    end
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local rep = report(ctx)
    local row = rep and rep.rows and rep.rows[1]
    ctx.check(row ~= nil, "une rangee existe")
    if not row then return end
    local fab = rep.fab or {}
    ctx.check((fab.machines or 0) >= 6, "machines posees : " .. tostring(fab.machines))
    ctx.check((fab.made or 0) > 0, "objets fabriques : " .. tostring(fab.made))
    ctx.check((fab.chests or 0) > 0, "objets dans les coffres de sortie : " .. tostring(fab.chests))
    -- l'amenée porte du fer, venu du tronc (x = −3 canonique, y = 6)
    local tx = rep.rep.ox - 3 + 0.5
    local ty = rep.rep.oy + 6 + 0.5
    local b = s.find_entity("transport-belt", { tx, ty })
    local n = 0
    local got = {}
    if b then
      for i = 1, 2 do for name, c in pairs(b.get_transport_line(i).get_contents()) do n = n + c; got[#got + 1] = name .. " x" .. c end end
    end
    ctx.check(b ~= nil, "un tapis d'amenee existe a l'endroit attendu")
    ctx.log(string.format("[%s] amenee en (%.1f, %.1f) : %d objets {%s}", TAG, tx, ty, n, table.concat(got, ",")))
    ctx.check(n > 0, "l'amenee porte des objets (" .. n .. ")")
    -- pureté : rangées en voies déclarées
    local allowed = {}
    for _, r in ipairs(rep.rows) do for _, v in ipairs(r.voies) do allowed[v] = true end end
    local bad, seen = 0, 0
    for _, belt in ipairs(s.find_entities_filtered({ area = { { SECT.x0, SECT.y0 }, { SECT.x1, SECT.y1 } }, name = { "transport-belt", "underground-belt", "splitter" } })) do
      local nb = (belt.type == "splitter") and 8 or 2
      for i = 1, nb do
        local ok, line = pcall(belt.get_transport_line, i)
        if ok and line then
          for name, c in pairs(line.get_contents()) do
            seen = seen + c
            if not allowed[name] then bad = bad + 1; ctx.log(string.format("[%s] IMPUR : %s x%d sur (%.1f, %.1f)", TAG, name, c, belt.position.x, belt.position.y)) end
          end
        end
      end
    end
    ctx.check(seen > 0, "les tapis portent des objets : " .. seen)
    ctx.check(bad == 0, "tapis purs (0 objet hors voies)", tostring(bad))
    ctx.log(string.format("[%s] BILAN-FAITS : rangees %d, cellules %d, machines %s, fabriques %s, coffres %s", TAG, #rep.rows, row.cells, tostring(fab.machines), tostring(fab.made), tostring(fab.chests)))
  end,
}
