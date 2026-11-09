--[[
  Micro-banc « mall-rangee » du lot MALL (tranche 2, 9/11) : la rangée du mall contre le moteur réel. Chaîne : demande directe (remote fo-mall offre) -> projet du plan directeur
  (site « mall », tête + cellules du motif asm-miroir-2e-coffres) -> PNJ -> quais servis par le coffre d'équipe -> tapis -> machines -> coffres de sortie.
  Critère lu en FONCTION : objets fabriqués (products_finished, compteurs du mod), objets dans les coffres de sortie, tapis purs.
  Puis : allongement (arbre sur la cellule neuve, défriché), arrêt devant l'eau (cause écrite).

  Terrain : carré d'herbe autour de (40, 0). Votre équipe : coffre d'équipe en (0, 0), 8 PNJ, plan directeur seul. Secteur imposé (remote fo-mall set_param sect) :
  (20, -40)-(84, 24), croissance vers l'est.
  Courant : le banc ajoute une interface électrique et un poteau à côté de la tête dès que la section est finie (sans_raccord : le raccord au réseau, déjà prouvé en
  partie par le champ, n'est pas l'objet de ce banc).
  Lancement : py -3.9 -B <banc.py> --out <archive> --qui mall -- 11000 mall-rangee <source>
]]

local TAG = "FO-MALL-RANGEE"
local SECT = { x0 = 20, y0 = -40, x1 = 84, y1 = 24, dir = 2, ext = 16 }
local KIT = { machine = "assembling-machine-1", bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", poteau = "small-electric-pole", coffre = "iron-chest" }

-- Objets demandés (recettes du jeu, ingrédients lus aux prototypes)
local DEMANDE = {
  { item = "transport-belt", recipe = "transport-belt", machines = 2 },
  { item = "inserter", recipe = "inserter", machines = 2 },
  { item = "iron-chest", recipe = "iron-chest", machines = 2 },
  { item = "pipe", recipe = "pipe", machines = 2 },
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
    { "iron-plate", 3000 }, { "copper-plate", 1000 }, { "iron-gear-wheel", 1200 }, { "electronic-circuit", 800 }, { "coal", 100 },
    { "assembling-machine-1", 24 }, { "inserter", 80 }, { "long-handed-inserter", 40 }, { "transport-belt", 300 }, { "small-electric-pole", 60 }, { "iron-chest", 40 },
  }) do
    local n = chest.insert({ name = it[1], count = it[2] })
    if n ~= it[2] then log(string.format("[FO-MALL-RANGEE] STOCK INCOMPLET : %s, %d sur %d (coffre plein)", it[1], n, it[2])) end
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

--- Case monde de la cellule i de la rangée j, tuile canonique (cx, cy) (via le repère du mod rendu par report).
local function world(rep, i, cy, cx)
  local x = (i - 1) * 4 + (cx or 0) + 0.5
  local y = (cy or 0) + 0.5
  return math.floor(x + rep.ox), math.floor(y + rep.oy)
end

return {
  description = "MALL T2 : rangee du mall, production lue aux compteurs, allongement, eau",
  base = nil,
  check_tick = 10800,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    shape(ctx)
    for _, r in ipairs({ "assembling-machine-1", "long-handed-inserter", "electric-mining-drill", "pipe", "inserter", "transport-belt", "iron-chest" }) do
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
      ctx.log(string.format("[%s] t=%d phase=%s rangees=%d cellules=%s fabriques=%s coffres=%s machines=%s stop=%s projets %s", TAG, t, tostring(st.phase), rep and rep.rows and #rep.rows or 0,
        row and row.cells or "-", rep and rep.fab and rep.fab.made or "-", rep and rep.fab and rep.fab.chests or "-", rep and rep.fab and rep.fab.machines or "-", row and tostring(row.stop) or "-", table.concat(parts, " ")))
    end
    if st.phase == "demande" and t >= 120 then
      local id = ctx.remote("fo-mall", "offre", "player", demandes(), KIT)
      ctx.check(id ~= nil, "projet de la premiere rangee demande", tostring(id))
      st.phase = "premier"
    elseif st.phase == "premier" and row and row.projects[1] and row.projects[1].state == "fini" then
      -- courant du banc : interface et poteau reliés à la tête (2 tuiles à l'ouest du poteau nord de la tête, x = −3.5 + ox)
      local hx = rep.rep.ox - 3.5
      local hy = rep.rep.oy + 4.5
      local p2 = s.create_entity({ name = "small-electric-pole", position = { hx - 4, hy - 1 }, force = "player" })
      local eei = s.create_entity({ name = "electric-energy-interface", position = { hx - 6, hy - 1 }, force = "player" })
      ctx.check(p2 ~= nil and eei ~= nil, "courant du banc pose")
      if eei then eei.electric_buffer_size = 1e9; eei.power_production = 1e9 / 60; eei.power_usage = 0; eei.energy = 1e9; st.eei = eei end
      st.phase, st.t_first = "production", t
      ctx.log(string.format("[%s] section 1 finie a t=%d : courant pose", TAG, t))
    elseif st.phase == "production" and t >= st.t_first + 1200 then
      st.prod_before = rep.fab
      ctx.check((rep.fab and rep.fab.made or 0) > 0, "la rangee fabrique (compteur) : " .. tostring(rep.fab and rep.fab.made))
      -- arbre sur la cellule à venir (cellule 5, tuile de machine) : défriché
      local tx, ty = world(rep.rep, 5, 3, 0)
      s.create_entity({ name = "tree-01", position = { tx + 0.5, ty + 0.5 } })
      st.tree = { x = tx + 0.5, y = ty + 0.5 }
      local id = ctx.remote("fo-mall", "offre", "player", demandes({ ["transport-belt"] = 2, ["iron-chest"] = 2 }), KIT)
      ctx.check(id ~= nil, "allongement demande", tostring(id))
      st.phase, st.t_grow = "allonge", t
    elseif st.phase == "allonge" and row and row.projects[#row.projects].state == "fini" and row.cells >= 5 then
      st.t_allonge = t
      ctx.log(string.format("[%s] allongement fini a t=%d : %d cellules", TAG, t, row.cells))
      -- eau sur la cellule suivante : refus attendu
      local i = row.cells + 1
      local tiles = {}
      for cx = 0, 3 do for cy = 0, 13 do local tx, ty = world(rep.rep, i, cy, cx); tiles[#tiles + 1] = { name = "water", position = { tx, ty } } end end
      s.set_tiles(tiles, true)
      local id = ctx.remote("fo-mall", "offre", "player", demandes({ ["transport-belt"] = 4 }), KIT)
      ctx.check(id ~= nil, "second allongement demande (terrain interdit)", tostring(id))
      st.phase = "eau"
    elseif st.phase == "eau" and row then
      local lastq = row.projects[#row.projects]
      if row.stop or (lastq and lastq.state == "refuse") then
        st.t_eau = t
        st.phase = "fin"
        ctx.log(string.format("[%s] arret eau : stop=%s, cellules=%d", TAG, tostring(row.stop), row.cells))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local rep = report(ctx)
    local row = rep and rep.rows and rep.rows[1]
    ctx.check(row ~= nil, "une rangee existe")
    if not row then return end
    local fab = rep.fab or {}
    ctx.check((fab.machines or 0) > 6, "plus de 6 machines en ligne (au-dela de la borne du lot) : " .. tostring(fab.machines))
    ctx.check((fab.made or 0) > 0, "objets fabriques : " .. tostring(fab.made))
    ctx.check((fab.chests or 0) > 0, "objets dans les coffres de sortie : " .. tostring(fab.chests))
    ctx.check(fab.run == nil or fab.made > (st.prod_before and st.prod_before.made or 0), "la rangee produit encore apres l'allongement")
    -- pureté : lire chaque tapis de la rangée (2 lignes) : aucun objet hors voies
    local allowed = {}
    for _, v in ipairs(row.voies) do allowed[v] = true end
    local bad, seen = 0, 0
    for _, b in ipairs(s.find_entities_filtered({ area = { { SECT.x0, SECT.y0 }, { SECT.x1 + SECT.ext, SECT.y1 } }, name = "transport-belt" })) do
      for i = 1, 2 do
        for name, n in pairs(b.get_transport_line(i).get_contents()) do
          seen = seen + n
          if not allowed[name] then bad = bad + 1; ctx.log(string.format("[%s] IMPUR : %s x%d sur le tapis (%.1f, %.1f)", TAG, name, n, b.position.x, b.position.y)) end
        end
      end
    end
    ctx.check(seen > 0, "les tapis portent des objets : " .. seen)
    ctx.check(bad == 0, "tapis purs (0 objet hors voies)", tostring(bad))
    -- l'arbre est défriché, la machine de la cellule 5 existe
    local tr = st.tree and s.find_entities_filtered({ position = { st.tree.x, st.tree.y }, radius = 0.5, type = "tree" })[1]
    ctx.check(st.tree ~= nil and tr == nil, "l'arbre sur la cellule neuve est defriche")
    if st.tree then
      local a = s.find_entities_filtered({ area = { { st.tree.x - 3, st.tree.y - 3 }, { st.tree.x + 3, st.tree.y + 3 } }, name = KIT.machine })
      ctx.check(#a >= 1, "une machine pose a la place de l'arbre (" .. #a .. ")")
    end
    ctx.check(st.t_eau ~= nil, "la rangee s'arrete devant l'eau : cause ecrite (" .. tostring(row.stop) .. ")")
    ctx.check(tostring(row.stop):find("eau", 1, true) ~= nil, "cause d'arret : eau : " .. tostring(row.stop))
    ctx.log(string.format("[%s] BILAN-FAITS : machines %s, fabriques %s, coffres %s, cellules %d, stop %s", TAG, tostring(fab.machines), tostring(fab.made), tostring(fab.chests), row.cells, tostring(row.stop)))
  end,
}
