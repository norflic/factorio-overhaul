-- Scénario greffé du lot QG-JEU (1/11) : LES 16 ÉTATS DU CENTRE / QG EN JEU, côte à côte, avec le vanilla, jour et nuit, au
-- milieu d'une base vivante (convoyeurs chargés, machines en marche, lampes, tourelles). Sur le modèle de f4-foreuses.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui QG-JEU -- 700 qg-galerie <source>                      (contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui QG-JEU --captures --visuel="--no-atlas-cache" -- 700 qg-galerie <source>
-- Grille de 5 rangées (une par emprise : 8×4, 10×5, 12×6, 14×7, 16×8) : l'épave de l'âge 0 et les âges 1 à 15 (un centre
-- par équipe : une force par bâtiment), le QG de faction fo-faction-hq, et à côté de chaque rangée un bâtiment vanilla
-- (épave du vaisseau, raffinerie, roboport, silo). Contrôles : boîtes aux dimensions de l'emprise (L.dims), niveau de chaque
-- centre reconnu, épave remplacée sur place par le niveau 1 (Levels.swap, moteur réel), agrandissement 8×4 → 10×5 refusé
-- quand deux colonnes de murs bloquent toutes les positions (contour, rien payé), puis accepté une fois les murs retirés, le
-- coffre gardé. Captures : une par bâtiment, jour et nuit (zoom 1), et la vue d'ensemble. Table : fo-shots/qg-galerie-sites.tsv.

local LV = require("__factorio-overhaul__/shared/levels/config")
local CC = LV.by_key.command

local X0, Y0 = 3800, 3200
local CELL_W, ROW_H = 32, 24

-- Chaque rangée : cellules { genre, âge ou nom vanilla }. genre : "wreck", "age", "hq", "vanilla".
local ROWS = {
  { { "vanilla", "crash-site-spaceship" }, { "wreck", 0 }, { "age", 1 }, { "age", 2 }, { "age", 3 } },
  { { "vanilla", "oil-refinery" }, { "age", 4 }, { "age", 5 }, { "age", 6 }, { "hq", 0 } },
  { { "vanilla", "roboport" }, { "age", 7 }, { "age", 8 }, { "age", 9 } },
  { { "vanilla", "rocket-silo" }, { "age", 10 }, { "age", 11 }, { "age", 12 } },
  { { "age", 13 }, { "age", 14 }, { "age", 15 } },
}

local function emprise(age)
  local n = math.max(1, age)
  return LV.footprint(CC, n) * LV.aspect(CC), LV.footprint(CC, n)
end

local function force_of(name)
  return game.forces[name] or game.create_force(name)
end

local function stock(inv, family, n)
  for _, c in ipairs(LV.cost(family, n)) do inv.insert({ name = c[1], count = c[2] }) end
end

--- Base vivante autour d'un bâtiment de w × h centré en (cx, cy) : un convoyeur chargé au sud, deux machines en marche,
--- deux lampes, deux tourelles armées au sud.
local function vivant(s, cx, cy, w, h)
  local by = cy + h / 2 + 4.5
  for i = 0, w - 1 do
    local b = s.create_entity({ name = "transport-belt", position = { cx - w / 2 + i + 0.5, by }, direction = defines.direction.east,
      force = "player" })
    if b then
      b.get_transport_line(1).insert_at_back({ name = "iron-plate" })
      b.get_transport_line(2).insert_at_back({ name = "copper-plate" })
    end
  end
  for k, rec in ipairs({ "iron-gear-wheel", "copper-cable" }) do
    local m = s.create_entity({ name = "assembling-machine-2", position = { cx + (k == 1 and -1 or 1) * (w / 2 + 3), cy + 0.5 },
      force = "player" })
    if m then
      m.set_recipe(rec)
      m.get_inventory(defines.inventory.assembling_machine_input).insert({ name = rec == "iron-gear-wheel" and "iron-plate" or "copper-plate", count = 200 })
    end
    s.create_entity({ name = "small-lamp", position = { cx + (k == 1 and -1 or 1) * (w / 2 + 1.5), cy - h / 2 - 0.5 }, force = "player" })
    local t = s.create_entity({ name = "gun-turret", position = { cx + (k == 1 and -1 or 1) * (w / 2 - 1), cy + h / 2 + 1.5 }, force = "player" })
    if t then t.insert({ name = "firearm-magazine", count = 10 }) end
  end
  s.create_entity({ name = "wooden-chest", position = { cx + w / 2 + 1.5, cy + h / 2 + 1.5 }, force = "player" })
end

return {
  description = "QG-JEU : les 16 etats du centre (epave + ages 1 a 15) et le QG de faction en jeu, avec le vanilla, jour et nuit, base vivante",
  base = nil,
  check_tick = 600,
  shots_delay = 620,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.cells = {}
    ctx.prepare_area(X0 - 8, Y0 - 50, X0 + 5 * CELL_W + 8, Y0 + 5 * ROW_H + 10, "red-desert-1")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 150, Y0 - 150 }, { X0 + 400, Y0 + 300 } } })) do
      en.destroy()
    end
    local p1 = ctx.power(X0 + 40, Y0 + 60)
    ctx.power(X0 + 120, Y0 + 60)
    ctx.check(p1 ~= nil, "alimentation invisible du mod de test", p1 and "posee" or "prototypes absents")
    local ok_all, mauvaises = 0, {}
    for r, row in ipairs(ROWS) do
      for c, cell in ipairs(row) do
        local kind, arg = cell[1], cell[2]
        local cx = X0 + (c - 1) * CELL_W + CELL_W / 2
        local w, h
        local name, force
        if kind == "vanilla" then
          local p = game.entity_prototypes[arg]
          local sb = p.selection_box
          w, h = math.ceil(sb.right_bottom.x - sb.left_top.x), math.ceil(sb.right_bottom.y - sb.left_top.y)
          name, force = arg, "player"
        elseif kind == "hq" then
          w, h = 8, 4
          name, force = "fo-faction-hq", "enemy"
        elseif kind == "wreck" then
          w, h = emprise(0)
          name, force = LV.WRECK, "qg-a0"
        else
          w, h = emprise(arg)
          name, force = LV.name(CC, arg), "qg-a" .. arg
        end
        local cy = Y0 + (r - 1) * ROW_H + ROW_H / 2 + ((h % 2 == 1) and 0.5 or 0)
        if kind == "age" or kind == "wreck" then force_of(force) end
        local e = s.create_entity({ name = name, position = { cx, cy }, force = force, raise_built = true })
        local rec = { kind = kind, age = (kind == "age" or kind == "wreck") and arg or nil, name = name, e = e, x = cx, y = cy, w = w,
          h = h, force = force, row = r, col = c }
        st.cells[#st.cells + 1] = rec
        if kind ~= "vanilla" then
          local good = false
          if e and e.valid then
            local sb = e.prototype.selection_box
            good = math.abs((sb.right_bottom.x - sb.left_top.x) - w) < 1e-6 and math.abs((sb.right_bottom.y - sb.left_top.y) - h) < 1e-6
          end
          if good then ok_all = ok_all + 1 else mauvaises[#mauvaises + 1] = name end
        end
        vivant(s, cx, cy, math.max(w, 6), math.max(h, 4))
      end
    end
    -- Bâtiments du jeu : 15 centres + épave + QG de faction = 17.
    ctx.check(ok_all == 17, "16 etats du centre + QG de faction poses, selection a la dimension de l'emprise (8x4 a 16x8, L.dims)",
      ok_all .. " / 17" .. (#mauvaises > 0 and (" ; faux : " .. table.concat(mauvaises, ",")) or ""))
    local lus, faux = 0, {}
    for _, c in ipairs(st.cells) do
      if c.kind == "age" or c.kind == "wreck" then
        local niv = ctx.call("levels_status", c.force).cc_level
        local want = c.kind == "wreck" and 0 or c.age
        -- l'épave n'est pas marquée « épave » par le banc (aucun état du module du centre) : elle compte pour le niveau 1
        if c.kind == "wreck" then want = 1 end
        if niv == want then lus = lus + 1 else faux[#faux + 1] = c.name .. "=" .. tostring(niv) end
      end
    end
    ctx.check(lus == 16, "chaque centre est reconnu a son niveau (l'epave tient la place du niveau 1)", lus .. " / 16"
      .. (#faux > 0 and (" ; " .. table.concat(faux, ",")) or ""))
    -- Épave remplacée sur place (Levels.swap, remplacement rapide moteur), contenu et place gardés.
    local fw = force_of("qg-swap")
    local w0 = s.create_entity({ name = LV.WRECK, position = { X0 + 16, Y0 - 20 }, force = fw, raise_built = true })
    st.swap_old = w0
    st.swap_new = w0 and ctx.call("levels_swap", w0, LV.name(CC, 1)) or nil
    ctx.check(w0 and not w0.valid and st.swap_new and st.swap_new.valid and st.swap_new.name == LV.name(CC, 1)
      and st.swap_new.position.x == X0 + 16 and st.swap_new.position.y == Y0 - 20
      and ctx.call("levels_status", "qg-swap").cc_level == 1,
      "epave -> centre niveau 1 sur place (remplacement rapide, meme boite 8x4), le centre de l'equipe suit",
      st.swap_new and st.swap_new.valid and st.swap_new.name or "pas de nouvelle entite")
    -- Agrandissement 8×4 → 10×5 : deux colonnes de murs bloquent toutes les positions.
    local fu = force_of("qg-up")
    local ux, uy = X0 + 56, Y0 - 20
    local e3 = s.create_entity({ name = LV.name(CC, 3), position = { ux, uy }, force = fu, raise_built = true })
    st.up = e3
    if e3 then
      e3.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 77 })
      stock(e3.get_inventory(defines.inventory.chest), CC, 4)
    end
    st.walls = {}
    for _, wx in ipairs({ ux - 4 - 0.5, ux + 4 + 0.5 }) do
      for wy = uy - 2 - 1, uy + 2 do
        local wl = s.create_entity({ name = "stone-wall", position = { wx, wy + 0.5 }, force = "player" })
        if wl then st.walls[#st.walls + 1] = wl end
      end
    end
    local r1 = e3 and ctx.call("levels_upgrade", e3) or {}
    ctx.check(e3 and e3.valid and not r1.ok and r1.reason == "no-room" and #st.walls == 12,
      "8x4 -> 10x5 refuse faute de place (deux colonnes de murs), centre intact, rien paye", tostring(r1.reason))
    for _, wl in ipairs(st.walls) do if wl.valid then wl.destroy() end end
    local r2 = e3 and e3.valid and ctx.call("levels_upgrade", e3) or {}
    local n4 = r2.entity
    local sb = n4 and n4.valid and n4.prototype.selection_box
    ctx.check(r2.ok and n4 and n4.valid and n4.name == LV.name(CC, 4) and sb and math.abs(sb.right_bottom.x - sb.left_top.x - 10) < 1e-6
      and math.abs(sb.right_bottom.y - sb.left_top.y - 5) < 1e-6 and n4.get_inventory(defines.inventory.chest).get_item_count("iron-plate") == 77
      and ctx.call("levels_status", "qg-up").cc_level == 4,
      "murs retires : 8x4 -> 10x5 par script, selection 10x5, coffre garde (77 plaques), le centre de l'equipe suit",
      tostring(r2.reason) .. (n4 and n4.valid and (" en " .. n4.position.x .. ", " .. n4.position.y) or ""))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local vivants, ko = 0, {}
    for _, c in ipairs(st.cells) do
      if c.e and c.e.valid then vivants = vivants + 1 else ko[#ko + 1] = c.name end
    end
    ctx.check(vivants == #st.cells, "tous les batiments sont encore la au tick 600", vivants .. " / " .. #st.cells
      .. (#ko > 0 and (" ; perdus : " .. table.concat(ko, ",")) or ""))
    local marche, total = 0, 0
    for _, m in ipairs(ctx.surface().find_entities_filtered({ name = "assembling-machine-2",
        area = { { X0, Y0 }, { X0 + 5 * CELL_W, Y0 + 5 * ROW_H } } })) do
      total = total + 1
      if m.status == defines.entity_status.working then marche = marche + 1 end
    end
    ctx.check(total > 0 and marche == total, "la base vivante tourne (machines en marche)", marche .. " / " .. total)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tgenre\tage\tnom\tnuit\tx\ty\tw\th" }
    local W, H = CELL_W * 32, ROW_H * 32
    for _, c in ipairs(st.cells) do
      for _, nuit in ipairs({ false, true }) do
        local nm = string.format("%s-%s-z1-%s", c.kind, c.age and string.format("age%02d", c.age) or c.name, nuit and "nuit" or "jour")
        add(nm, c.x, c.y - 1.5, 1, nuit and 0.5 or 0, { res = { W, H }, info = false, aa = true })
        L[#L + 1] = string.format("%s\t%s\t%s\t%s\t%d\t%.2f\t%.2f\t%d\t%d", nm, c.kind, tostring(c.age or ""), c.name, nuit and 1 or 0, c.x, c.y, c.w, c.h)
      end
    end
    local cx, cy = X0 + 2.5 * CELL_W, Y0 + 2.5 * ROW_H
    add("ensemble-z04-jour", cx, cy, 0.4, 0, { res = { 3840, 2160 }, info = false, aa = true })
    add("ensemble-z04-nuit", cx, cy, 0.4, 0.5, { res = { 3840, 2160 }, info = false, aa = true })
    game.write_file("fo-shots/qg-galerie-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
