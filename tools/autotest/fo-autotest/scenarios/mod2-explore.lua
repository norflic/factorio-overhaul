-- Scénario greffé du lot MOD-2 (25/10) : EXPLORATION du moteur pour les recettes par lots (E151). Aucun contrôle du
-- mod : des mesures (lignes « MESURE ») qui fixent les règles de la bascule.
--   & "<racine>\fo-autotest.bat" nopause 1500 mod2-explore "<source>"
-- Questions : set_recipe sur un lot caché et désactivé ; ce que rend set_recipe (entrée, sortie, fabrication en
-- cours) ; fluide gardé ou non ; capacité d'insertion par script de l'entrée (lot 1, 10, 100 ; lente, rapide) ;
-- sortie au-delà d'une pile ; fluide à la capacité de la boîte et au-delà ; crafting_speed relu après la balise ;
-- débit d'un niveau 30 à 34 × palier 10 nourri par script (lots 1, 10, 100) et par bras (limite logistique).
-- ATTENTION : les cellules X1 à X8 ont été mesurées AVANT la bascule automatique (passes 2 et 3, archives
-- fo-logs\2026-10-25_MOD2\explore2, explore3) ; avec le mod complet, les machines posées avec raise_built sont suivies
-- et changent seules de lot : seules les cellules X9 (machines NON suivies, passe 4, explore4) restent lisibles.

local X0, Y0 = 6000, 6000
local CHECK = 1400
local WA, WB = 700, 1300
local P10 = "fo-speed-module-10"

local function mods(m, name, n)
  local inv = m.get_module_inventory()
  local k = 0
  for _ = 1, n do k = k + inv.insert({ name = name, count = 1 }) end
  pcall(remote.call, "fo-modules", "refresh", m, true)
  return k
end

local function line(ctx, txt) ctx.log("MESURE " .. txt) end

local STATUS = {}
for k, v in pairs(defines.entity_status) do STATUS[v] = k end
local function status(m) return STATUS[m.status] or tostring(m.status) end

local function input(m) return m.get_inventory(defines.inventory.assembling_machine_input) end

local function box(m)
  local t = {}
  for i = 1, #m.fluidbox do
    local f = m.fluidbox[i]
    t[#t + 1] = f and (f.name .. "=" .. string.format("%.3f", f.amount)) or "vide"
  end
  return table.concat(t, ",")
end

local function feed(m, item, want)
  local inv = input(m)
  local k = inv.get_item_count(item)
  if k < want then return inv.insert({ name = item, count = want - k }) end
  return 0
end

return {
  description = "MOD-2 : exploration du moteur (lots : set_recipe, insertion, sortie, fluide, debit, bras)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    game.map_settings.enemy_expansion.enabled = false
    local f = game.forces.player
    for _, r in ipairs({ "iron-gear-wheel", "iron-stick", "concrete" }) do f.recipes[r].enabled = true end
    f.stack_inserter_capacity_bonus = 11
    f.inserter_stack_size_bonus = 2
    ctx.prepare_area(X0 - 20, Y0 - 20, X0 + 220, Y0 + 120, "grass-1")
    ctx.power(X0 + 40, Y0 + 30)
    ctx.power(X0 + 100, Y0 + 80)
    local lot = game.recipe_prototypes["fo-lot10-iron-gear-wheel"]
    line(ctx, "lot10 engrenage : prototype " .. tostring(lot ~= nil) .. " ; cache " .. tostring(lot and lot.hidden)
      .. " ; energie " .. tostring(lot and lot.energy) .. " ; active pour la force " .. tostring(f.recipes["fo-lot10-iron-gear-wheel"].enabled)
      .. " ; ingredients " .. serpent.line(lot and lot.ingredients) .. " ; produits " .. serpent.line(lot and lot.products))
    local n = 0
    for name in pairs(game.recipe_prototypes) do if name:sub(1, 6) == "fo-lot" then n = n + 1 end end
    line(ctx, "lots charges : " .. n)

    -- X1 : set_recipe sur un lot désactivé.
    local a = s.create_entity({ name = "assembling-machine-2", position = { X0, Y0 }, force = f, raise_built = true })
    a.set_recipe("iron-gear-wheel")
    local ok, err = pcall(function() return a.set_recipe("fo-lot10-iron-gear-wheel") end)
    line(ctx, "X1 set_recipe lot desactive : pcall " .. tostring(ok) .. " " .. serpent.line(err) .. " ; recette "
      .. tostring(a.get_recipe() and a.get_recipe().name))
    st.x1 = a

    -- X2 : machines rapides (assembleur 2, 5 × palier 10) pour la reprise au changement (entrée, sortie, en cours).
    local b = s.create_entity({ name = "assembling-machine-2", position = { X0 + 10, Y0 }, force = f, raise_built = true })
    b.set_recipe("iron-gear-wheel")
    mods(b, P10, 5)
    st.x2 = b
    local b2 = s.create_entity({ name = "assembling-machine-2", position = { X0 + 10, Y0 + 10 }, force = f, raise_built = true })
    b2.set_recipe("fo-lot10-iron-gear-wheel")
    mods(b2, P10, 5)
    st.x2b = b2

    -- X4 : capacité d'insertion par script, lots 1, 10, 100, lente (sans module) et rapide (niveau 30, 34 × P10).
    st.ins = {}
    local i = 0
    for _, lv in ipairs({ { "assembling-machine-2", 0 }, { "fo-lvl-assembler-30", 34 } }) do
      for _, k in ipairs({ 1, 10, 100 }) do
        i = i + 1
        local px = X0 + 20 + i * 10
        local m = s.create_entity({ name = lv[1], position = { px, Y0 }, force = f, raise_built = true })
        if lv[2] > 0 then mods(m, P10, lv[2]) end
        m.set_recipe(k == 1 and "iron-gear-wheel" or ("fo-lot" .. k .. "-iron-gear-wheel"))
        st.ins[#st.ins + 1] = { m = m, k = k, lv = lv[1] }
      end
    end

    -- X3 : sortie au-delà d'une pile (baguettes × 100 : 200 pour une pile de 100), sortie NON vidée.
    local c = s.create_entity({ name = "fo-lvl-assembler-30", position = { X0, Y0 + 20 }, force = f, raise_built = true })
    mods(c, P10, 34)
    c.set_recipe("fo-lot100-iron-stick")
    st.x3 = c

    -- X5 : débit, niveau 30 à 34 × P10 nourri par script, sortie vidée à chaque tick : lots 1, 10, 100.
    st.deb = {}
    for j, k in ipairs({ 1, 10, 100 }) do
      local m = s.create_entity({ name = "fo-lvl-assembler-30", position = { X0 + 10 + j * 10, Y0 + 20 }, force = f, raise_built = true })
      mods(m, P10, 34)
      m.set_recipe(k == 1 and "iron-gear-wheel" or ("fo-lot" .. k .. "-iron-gear-wheel"))
      st.deb[#st.deb + 1] = { m = m, k = k, n = 0 }
    end

    -- X6 : fluide. Béton × 1, × 10 (1 000 eau = capacité de la boîte), × 100 (10 000) ; tuyau infini d'eau.
    st.flu = {}
    for j, k in ipairs({ 1, 10, 100 }) do
      local px, py = X0 + j * 10, Y0 + 40
      local m = s.create_entity({ name = "assembling-machine-2", position = { px, py }, force = f, raise_built = true })
      mods(m, P10, 5)
      m.set_recipe(k == 1 and "concrete" or ("fo-lot" .. k .. "-concrete"))
      local pipe = s.create_entity({ name = "infinity-pipe", position = { m.position.x, m.position.y - 2 }, force = f })
      if pipe then pipe.set_infinity_pipe_filter({ name = "water", percentage = 1 }) end
      st.flu[#st.flu + 1] = { m = m, k = k, n = 0, pipe = pipe }
    end
    -- Fluide gardé au changement : béton × 1, boîte remplie par script (150 d'eau), sans tuyau.
    local g = s.create_entity({ name = "assembling-machine-2", position = { X0 + 50, Y0 + 40 }, force = f, raise_built = true })
    g.set_recipe("concrete")
    st.x6g = g

    -- X9 (passe 4) : machines NON suivies (sans raise_built : aucune bascule automatique). Écriture directe du compte
    -- d'une pile d'entrée et de sortie au-delà de la limite d'insertion ; boîte à fluide écrite au-delà de sa capacité ;
    -- descente 10 -> 1 en pleine fabrication : ce que le moteur remet lui-même dans l'entrée.
    st.x9 = {}
    for j, rec in ipairs({ "iron-gear-wheel", "concrete", "fo-lot10-iron-gear-wheel" }) do
      local m = s.create_entity({ name = "assembling-machine-2", position = { X0 + 80 + j * 6, Y0 + 40 }, force = f })
      m.set_recipe(rec)
      st.x9[j] = m
    end
    for _ = 1, 5 do st.x9[3].get_module_inventory().insert({ name = P10, count = 1 }) end

    -- X7 : crafting_speed relu juste après la pose des modules (balise du complément).
    local h = s.create_entity({ name = "assembling-machine-2", position = { X0 + 70, Y0 + 40 }, force = f, raise_built = true })
    h.set_recipe("iron-gear-wheel")
    st.x7 = h

    -- X8 : bras. Niveau 30, 34 × P10, engrenage × 100 ; ouest et nord : bras empileurs depuis des coffres infinis de
    -- plaques ; est et sud : bras empileurs vers des coffres vidés à chaque tick.
    local m = s.create_entity({ name = "fo-lvl-assembler-30", position = { X0 + 100, Y0 + 80 }, force = f, raise_built = true })
    mods(m, P10, 34)
    m.set_recipe("fo-lot100-iron-gear-wheel")
    local bb = m.bounding_box
    local x1, y1 = math.floor(bb.left_top.x + 0.5), math.floor(bb.left_top.y + 0.5)
    local x2, y2 = math.floor(bb.right_bottom.x + 0.5), math.floor(bb.right_bottom.y + 0.5)
    local ins, outs = {}, {}
    local function arm(px, py, dx, dy, src)
      -- (px, py) : case du bras ; (dx, dy) : vers la machine.
      local chest = s.create_entity({ name = "iron-chest", position = { px - dx, py - dy }, force = f })
      local ins_e = s.create_entity({ name = "stack-inserter", position = { px, py }, force = f })
      if src then
        chest.insert({ name = "iron-plate", count = 1000 })
        ins_e.pickup_position = { px - dx, py - dy }
        ins_e.drop_position = { px + dx, py + dy }
        ins[#ins + 1] = { i = ins_e, c = chest, n = 0 }
      else
        ins_e.pickup_position = { px + dx, py + dy }
        ins_e.drop_position = { px - dx, py - dy }
        outs[#outs + 1] = { i = ins_e, c = chest }
      end
    end
    for x = x1 + 0.5, x2 - 0.5 do
      arm(x, y1 - 0.5, 0, 1, true)
      arm(x, y2 + 0.5, 0, -1, false)
    end
    for y = y1 + 0.5, y2 - 0.5 do
      arm(x1 - 0.5, y, 1, 0, true)
      arm(x2 + 0.5, y, -1, 0, false)
    end
    st.x8 = { m = m, ins = ins, outs = outs, n = 0, side = x2 - x1 }
    line(ctx, "X8 niveau 30 : cote " .. (x2 - x1) .. " ; bras entrants " .. #ins .. ", sortants " .. #outs
      .. " ; capacite des bras empileurs " .. tostring(f.stack_inserter_capacity_bonus + 1))
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    local fen = t > WA and t <= WB
    -- X2 : reprise au changement (tick 200 : rempli au tick 100, non vidé).
    local b = st.x2
    if t == 100 and b and b.valid then input(b).insert({ name = "iron-plate", count = 150 }) end
    -- X2b : lot 10 rempli, sortie non vidée, puis retour au lot 1 (tick 300).
    local b2 = st.x2b
    if b2 and b2.valid then
      if t >= 10 and t < 300 then feed(b2, "iron-plate", 2000) end
      if t == 300 then
        local before_in = input(b2).get_contents()
        local before_out = b2.get_output_inventory().get_contents()
        local prog = b2.crafting_progress
        local ret = b2.set_recipe("iron-gear-wheel")
        line(ctx, "X2b set_recipe 10 -> 1 : entree " .. serpent.line(before_in) .. " sortie " .. serpent.line(before_out)
          .. " progression " .. string.format("%.4f", prog) .. " statut avant " .. tostring(st.x2b_st) .. " ; rendu " .. serpent.line(ret)
          .. " ; apres : entree " .. serpent.line(input(b2).get_contents()) .. " sortie " .. serpent.line(b2.get_output_inventory().get_contents())
          .. " progression " .. string.format("%.4f", b2.crafting_progress))
        local r1 = input(b2).insert({ name = "iron-plate", count = 5000 })
        local r2 = b2.get_output_inventory().insert({ name = "iron-gear-wheel", count = 5000 })
        line(ctx, "X2b apres : insertion entree " .. r1 .. " / 5000 ; insertion sortie " .. r2 .. " / 5000")
      end
      if t == 299 then st.x2b_st = status(b2) end
    end
    if t == 103 and b and b.valid then
      local before_in = input(b).get_contents()
      local before_out = b.get_output_inventory().get_contents()
      local prog, bon = b.crafting_progress, b.bonus_progress
      local ret = b.set_recipe("fo-lot10-iron-gear-wheel")
      line(ctx, "X2 set_recipe 1 -> 10 : entree " .. serpent.line(before_in) .. " sortie " .. serpent.line(before_out)
        .. " progression " .. string.format("%.4f", prog) .. " ; rendu " .. serpent.line(ret) .. " ; apres : entree "
        .. serpent.line(input(b).get_contents()) .. " sortie " .. serpent.line(b.get_output_inventory().get_contents())
        .. " progression " .. string.format("%.4f", b.crafting_progress) .. " recette " .. b.get_recipe().name)
      local r1 = input(b).insert({ name = "iron-plate", count = 5000 })
      local r2 = b.get_output_inventory().insert({ name = "iron-gear-wheel", count = 5000 })
      line(ctx, "X2 apres : insertion entree " .. r1 .. " / 5000 ; insertion sortie " .. r2 .. " / 5000 (engrenage, pile 100)")
    end
    -- X4 : capacité d'insertion par script (une fois, tick 5).
    if t == 5 or t == 200 then
      for _, c in ipairs(st.ins) do
        if t == 200 then input(c.m).clear() c.m.get_output_inventory().clear() end
        local m = c.m
        local r = input(m).insert({ name = "iron-plate", count = 100000 })
        local o = m.get_output_inventory().insert({ name = "iron-gear-wheel", count = 100000 })
        line(ctx, string.format("X4 tick %d %s lot %d vitesse %.3f : entree acceptee %d plaques ; sortie acceptee %d engrenages", t, c.lv, c.k,
          m.crafting_speed, r, o))
      end
    end
    -- X3 : sortie non vidée, entrée nourrie.
    local c3 = st.x3
    if c3 and c3.valid then
      feed(c3, "iron-plate", 2000)
      if t % 50 == 0 and t <= 600 then
        line(ctx, "X3 baguettes x100, tick " .. t .. " : sortie " .. c3.get_output_inventory().get_item_count() .. " ; fini "
          .. c3.products_finished .. " ; statut " .. status(c3))
      end
    end
    -- X5 : débit nourri par script.
    for _, c in ipairs(st.deb) do
      local m = c.m
      feed(m, "iron-plate", 100000)
      local out = m.get_output_inventory()
      local nb = out.get_item_count()
      if nb > 0 then out.clear() end
      if fen then c.n = c.n + nb end
      if t == WA then c.pf0 = m.products_finished end
      if t == WB then c.pf1 = m.products_finished end
    end
    -- X6 : fluide.
    for _, c in ipairs(st.flu) do
      local m = c.m
      local inv = input(m)
      if inv.get_item_count("stone-brick") < 1000 then inv.insert({ name = "stone-brick", count = 1000 }) end
      if inv.get_item_count("iron-ore") < 100 then inv.insert({ name = "iron-ore", count = 100 }) end
      local out = m.get_output_inventory()
      local nb = out.get_item_count()
      if nb > 0 then out.clear() end
      if fen then c.n = c.n + nb end
      if t == 300 or t == 600 then
        line(ctx, string.format("X6 beton lot %d tick %d : boite %s ; capacite %s ; fini %d ; statut %s", c.k, t, box(m),
          tostring(#m.fluidbox > 0 and m.fluidbox.get_capacity(1)), m.products_finished, status(m)))
      end
    end
    local g = st.x6g
    if g and g.valid then
      if t == 50 then
        input(g).insert({ name = "stone-brick", count = 10 })
        input(g).insert({ name = "iron-ore", count = 1 })
        g.fluidbox[1] = { name = "water", amount = 150 }
        line(ctx, "X6g tick 50 : boite " .. box(g))
      end
      if t == 53 then
        local before = box(g)
        local prog = g.crafting_progress
        local ret = g.set_recipe("fo-lot10-concrete")
        line(ctx, "X6g set_recipe beton 1 -> 10 : avant boite " .. before .. " progression " .. string.format("%.4f", prog)
          .. " ; rendu " .. serpent.line(ret) .. " ; apres boite " .. box(g) .. " entree " .. serpent.line(input(g).get_contents()))
      end
      if t == 54 then
        local fb = g.fluidbox[1]
        if fb then
          fb.amount = fb.amount + 100
          g.fluidbox[1] = fb
        end
        line(ctx, "X6g tick 54 : 100 d'eau rendue par script : boite " .. box(g) .. " capacite " .. g.fluidbox.get_capacity(1))
      end
      if t == 56 then line(ctx, "X6g tick 56 : boite " .. box(g)) end
    end
    -- X9 : écritures directes et descente en pleine fabrication.
    local x9 = st.x9
    if x9 and t == 395 then
      input(x9[1]).insert({ name = "iron-plate", count = 100 })
      x9[1].get_output_inventory().insert({ name = "iron-gear-wheel", count = 100 })
    end
    if x9 and t >= 300 and t < 400 then feed(x9[3], "iron-plate", 2000) end
    if x9 and t == 400 then
      local m = x9[1]
      local inv = input(m)
      local c0 = inv[1].valid_for_read and inv[1].count or -1
      local ok1, e1 = pcall(function() inv[1].count = c0 + 300 end)
      local c1 = inv[1].valid_for_read and inv[1].count or -1
      local r1 = inv.insert({ name = "iron-plate", count = 10 })
      local out = m.get_output_inventory()
      local o0 = out[1].valid_for_read and out[1].count or -1
      local ok2, e2 = pcall(function() out[1].count = o0 + 150 end)
      local o1 = out[1].valid_for_read and out[1].count or -1
      line(ctx, string.format("X9 pile d'entree (plaques, pile 100) : %d -> ecriture %d : %s %s -> relu %d ; insert 10 ensuite : %d ; pile de sortie (engrenages) %d -> ecriture %d : %s %s -> relu %d",
        c0, c0 + 300, tostring(ok1), tostring(e1), c1, r1, o0, o0 + 150, tostring(ok2), tostring(e2), o1))
      local g = x9[2]
      local ok3, e3 = pcall(function() g.fluidbox[1] = { name = "water", amount = 5000 } end)
      line(ctx, string.format("X9 boite (beton, capacite %s) ecrite a 5000 : %s %s -> relu %s", tostring(g.fluidbox.get_capacity(1)),
        tostring(ok3), tostring(e3), box(g)))
      local h3 = x9[3]
      local before = input(h3).get_contents()
      local prog = h3.crafting_progress
      local ret = h3.set_recipe("iron-gear-wheel")
      line(ctx, "X9 descente 10 -> 1 en fabrication : entree avant " .. serpent.line(before) .. " progression "
        .. string.format("%.4f", prog) .. " ; rendu " .. serpent.line(ret) .. " ; entree apres " .. serpent.line(input(h3).get_contents())
        .. " ; sortie " .. serpent.line(h3.get_output_inventory().get_contents()))
    end
    if x9 and t == 460 then
      local m = x9[1]
      line(ctx, "X9 tick 460 : entree " .. serpent.line(input(m).get_contents()) .. " sortie " .. serpent.line(m.get_output_inventory().get_contents())
        .. " statut " .. status(m) .. " ; beton boite " .. box(x9[2]))
    end
    -- X7 : vitesse relue.
    local h = st.x7
    if h and h.valid then
      if t == 400 then
        local v0 = h.crafting_speed
        local inv = h.get_module_inventory()
        for _ = 1, 5 do inv.insert({ name = P10, count = 1 }) end
        local v1 = h.crafting_speed
        pcall(remote.call, "fo-modules", "refresh", h, true)
        local v2 = h.crafting_speed
        st.x7v = { v0, v1, v2 }
      end
      if t == 401 then
        line(ctx, string.format("X7 crafting_speed : avant %.4f ; modules poses (meme tick) %.4f ; balise reecrite (meme tick) %.4f ; tick suivant %.4f",
          st.x7v[1], st.x7v[2], st.x7v[3], h.crafting_speed))
      end
    end
    -- X8 : bras.
    local x8 = st.x8
    if x8 and x8.m.valid then
      for _, o in ipairs(x8.ins) do
        local inv = o.c.get_inventory(defines.inventory.chest)
        local k = inv.get_item_count("iron-plate")
        if k < 1000 then
          inv.insert({ name = "iron-plate", count = 1000 - k })
          if fen then o.n = o.n + 1000 - k end
        end
      end
      for _, o in ipairs(x8.outs) do
        local inv = o.c.get_inventory(defines.inventory.chest)
        local nb = inv.get_item_count()
        if nb > 0 then inv.clear() end
        if fen then x8.n = x8.n + nb end
      end
      if t % 100 == 0 then
        line(ctx, "X8 tick " .. t .. " : entree " .. input(x8.m).get_item_count("iron-plate") .. " ; sortie "
          .. x8.m.get_output_inventory().get_item_count() .. " ; fini " .. x8.m.products_finished .. " ; statut " .. status(x8.m))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local secs = (WB - WA) / 60
    for _, c in ipairs(st.deb or {}) do
      line(ctx, string.format("X5 niveau 30, 34 x P10, lot %d : vitesse %.3f ; %d engrenages en %.0f s = %.2f /s ; lots finis %d = %.2f /s",
        c.k, c.m.crafting_speed, c.n, secs, c.n / secs, (c.pf1 or 0) - (c.pf0 or 0), ((c.pf1 or 0) - (c.pf0 or 0)) / secs))
    end
    for _, c in ipairs(st.flu or {}) do
      line(ctx, string.format("X6 beton lot %d : %d betons en %.0f s = %.2f /s ; boite %s", c.k, c.n, secs, c.n / secs, box(c.m)))
    end
    if st.x8 then
      local per = {}
      for _, o in ipairs(st.x8.ins) do per[#per + 1] = string.format("%.1f", o.n / secs) end
      line(ctx, "X8 bras entrants, plaques/s par bras : " .. table.concat(per, " ; "))
      line(ctx, string.format("X8 bras : %d engrenages en %.0f s = %.2f /s (%d bras entrants, %d sortants)", st.x8.n, secs,
        st.x8.n / secs, #st.x8.ins, #st.x8.outs))
    end
    ctx.check(true, "exploration terminee")
  end,
}
