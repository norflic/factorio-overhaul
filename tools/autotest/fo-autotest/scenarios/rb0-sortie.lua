-- Scénario greffé du lot RB-0 (31/10), essai E1 : kit de sortie à stack_size = 1 dans une machine (PLAN.md §3).
-- À LANCER SUR LA COPIE JETABLE (tools/autotest/robots/jetable.py) :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB0 -- 1500 rb0-sortie <copie>
--
-- Questions : (1) la machine s'arrête-t-elle d'elle-même quand le kit (pile de 1) occupe la sortie ? Statut ?
--   `products_finished` tient-il ? Reprend-elle quand un script retire le kit ? (2) Un module de productivité
--   (produit en plus) met-il 2 kits dans la case de sortie ? (3) Une recette à ingrédient au-delà d'une pile (200 pierres,
--   pile 50 ; 400 plaques, pile 100 ; 200 cristaux) : `insert` par script, bras empileur depuis un coffre.
--   (4) Un bras de sortie : combien de kits en 1 400 ticks.
-- Sites (copie jetable, zone 1000..1100 x 1000..1040), 6 machines `rb0-atelier` 3x3 de l'est vers l'ouest :
--   M1 kit-a, 100 plaques de fer par script ; M2 kit-a + 2 modules de productivité, bonus_progress forcé à 0,99 ;
--   M3 recette « grand » (200 pierres + 400 plaques), insert par script ; M4 la même, coffre + bras empileur ;
--   M5 recette « cristal » (200 cristaux + 4 cuivre) si l'objet existe ; M6 kit-a avec bras de sortie vers un coffre.

local C = require("scenarios/rb0_common")

local T_RETRAIT = 700
local CHECK = 1500
local X0, Y0 = 1000, 1000
local MY = Y0 + 0.5 -- centre des machines 3x3 (tuile entière + 0,5)
local NOMS = { "rb0-atelier", "rb0-kit", "rb0-kit-b", "rb0-kit-a", "rb0-kit-grand", "rb0-kit-b-cu", "rb0-kit-stone-200", "rb0-kit-iron-plate-300", "rb0-kit-2ing-petit", "rb0-kit-2ing-vanilla" }

-- { ingrédient, quantité, bras } : pile de la pierre 50, de la plaque de fer 100
local VARIANTES = { { "stone", 20, "fast-inserter" }, { "stone", 50, "fast-inserter" }, { "stone", 60, "fast-inserter" },
  { "stone", 100, "fast-inserter" }, { "stone", 200, "fast-inserter" }, { "iron-plate", 100, "fast-inserter" },
  { "iron-plate", 150, "fast-inserter" }, { "iron-plate", 300, "fast-inserter" }, { "stone", 200, "stack-inserter" },
  { "iron-plate", 300, "stack-inserter" } }

-- E1c : deux ingrédients livrés par bras. { id, recette, bras, [coffres : un seul coffre garni des deux, ou un coffre par ingrédient] }
local DEUX = {
  { id = "petit-1coffre", recette = "rb0-kit-2ing-petit", bras = "fast-inserter", coffres = { { { "stone", 200 }, { "iron-plate", 400 } } } },
  { id = "grand-1coffre-fast", recette = "rb0-kit-grand", bras = "fast-inserter", coffres = { { { "stone", 400 }, { "iron-plate", 800 } } } },
  { id = "grand-2coffres-fast", recette = "rb0-kit-grand", bras = "fast-inserter", coffres = { { { "stone", 800 } }, { { "iron-plate", 1500 } } } },
  { id = "grand-2coffres-empileur", recette = "rb0-kit-grand", bras = "stack-inserter", coffres = { { { "stone", 800 } }, { { "iron-plate", 1500 } } } },
  { id = "petit-1coffre-fer-d-abord", recette = "rb0-kit-2ing-petit", bras = "fast-inserter", coffres = { { { "iron-plate", 400 }, { "stone", 200 } } } },
  { id = "petit-2coffres-fast", recette = "rb0-kit-2ing-petit", bras = "fast-inserter", coffres = { { { "stone", 200 } }, { { "iron-plate", 400 } } } },
  { id = "petit-1coffre-VANILLA-am2", recette = "rb0-kit-2ing-vanilla", machine = "assembling-machine-2", bras = "fast-inserter", coffres = { { { "stone", 200 }, { "iron-plate", 400 } } } },
  { id = "grand-1coffre-empileur-fer-d-abord", recette = "rb0-kit-grand", bras = "stack-inserter", coffres = { { { "iron-plate", 800 }, { "stone", 400 } } } },
}

local function sortie_n(m)
  local inv = m.get_output_inventory()
  if not inv then return -1, 0 end
  local n, cases = 0, #inv
  for i = 1, cases do n = n + (inv[i].valid_for_read and inv[i].count or 0) end
  return n, cases
end

local function compte(m, nom) return m.get_item_count(nom) end

return {
  description = "RB-0 E1 : kit de sortie a stack_size = 1, machine pleine, ingredients au-dela d'une pile",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    if not C.exige(ctx, NOMS, "atelier, 2 kits, 3 recettes") then return end
    local s = ctx.surface()
    C.pave(ctx, X0 - 4, Y0 - 12, X0 + 150, Y0 + 56)
    C.sans_ennemis(s, X0 - 8, Y0 - 16, X0 + 156, Y0 + 60)
    ctx.power(X0 + 30, Y0)
    ctx.power(X0 + 90, Y0)
    ctx.power(X0 + 30, Y0 + 20)
    ctx.power(X0 + 90, Y0 + 20)
    ctx.power(X0 + 30, Y0 + 40)
    ctx.power(X0 + 90, Y0 + 40)
    -- bras empileur : capacité de la main (bonus de recherche du joueur) portée à 12
    game.forces.player.stack_inserter_capacity_bonus = 10
    game.forces.player.inserter_stack_size_bonus = 1
    st.m = {}
    local function machine(id, x, recette)
      local m = s.create_entity({ name = "rb0-atelier", position = { x, MY }, force = "player" })
      if m then m.set_recipe(recette) end
      st.m[id] = { e = m, x = x, recette = recette, max_sortie = 0, premier_plein = nil }
      return m
    end
    local m1 = machine("M1", X0 + 4.5, "rb0-kit-a")
    local m2 = machine("M2", X0 + 14.5, "rb0-kit-a")
    local m3 = machine("M3", X0 + 24.5, "rb0-kit-grand")
    local m4 = machine("M4", X0 + 34.5, "rb0-kit-grand")
    local m5 = game.recipe_prototypes["rb0-kit-cristal"] and machine("M5", X0 + 44.5, "rb0-kit-cristal") or nil
    local m6 = machine("M6", X0 + 54.5, "rb0-kit-a")
    -- ingredients
    if m1 then st.m.M1.ins = m1.insert({ name = "iron-plate", count = 100 }) end
    if m2 then
      st.m.M2.ins = m2.insert({ name = "iron-plate", count = 100 })
      local mi = m2.get_module_inventory()
      local mod = game.item_prototypes["productivity-module-3"] and "productivity-module-3" or "productivity-module"
      st.m.M2.modules = mi and mi.insert({ name = mod, count = 2 }) or -1
      st.m.M2.module_nom = mod
    end
    if m3 then
      st.m.M3.pierre = m3.insert({ name = "stone", count = 200 })
      st.m.M3.fer = m3.insert({ name = "iron-plate", count = 400 })
    end
    if m4 then
      local c = s.create_entity({ name = "steel-chest", position = { X0 + 34.5, MY - 3 }, force = "player" })
      c.insert({ name = "stone", count = 400 })
      c.insert({ name = "iron-plate", count = 800 })
      local b = s.create_entity({ name = "stack-inserter", position = { X0 + 34.5, MY - 2 }, force = "player" })
      b.pickup_position = { X0 + 34.5, MY - 3 }
      b.drop_position = { X0 + 34.5, MY - 1 }
      st.m.M4.coffre, st.m.M4.bras = c, b
    end
    if m5 then
      st.m.M5.cristal = m5.insert({ name = "fo-resonance-crystal", count = 200 })
      st.m.M5.cuivre = m5.insert({ name = "copper-plate", count = 4 })
      st.m.M5.pile = game.item_prototypes["fo-resonance-crystal"].stack_size
    end
    if m6 then
      st.m.M6.ins = m6.insert({ name = "iron-plate", count = 400 })
      local c = s.create_entity({ name = "steel-chest", position = { X0 + 54.5, MY + 3 }, force = "player" })
      local b = s.create_entity({ name = "fast-inserter", position = { X0 + 54.5, MY + 2 }, force = "player" })
      b.pickup_position = { X0 + 54.5, MY + 1 }
      b.drop_position = { X0 + 54.5, MY + 3 }
      st.m.M6.coffre, st.m.M6.bras = c, b
    end
    ctx.log("piles : stone=" .. game.item_prototypes["stone"].stack_size .. " iron-plate=" ..
      game.item_prototypes["iron-plate"].stack_size .. " rb0-kit=" .. game.item_prototypes["rb0-kit"].stack_size ..
      " fo-resonance-crystal=" .. tostring(game.item_prototypes["fo-resonance-crystal"] and
      game.item_prototypes["fo-resonance-crystal"].stack_size or "absent"))
    ctx.log(string.format("insert script : M1 fer=%s ; M2 fer=%s modules=%s(%s) ; M3 pierre=%s fer=%s ; M5 cristal=%s cuivre=%s ; M6 fer=%s",
      tostring(st.m.M1 and st.m.M1.ins), tostring(st.m.M2 and st.m.M2.ins), tostring(st.m.M2 and st.m.M2.modules),
      tostring(st.m.M2 and st.m.M2.module_nom), tostring(st.m.M3 and st.m.M3.pierre), tostring(st.m.M3 and st.m.M3.fer),
      tostring(st.m.M5 and st.m.M5.cristal), tostring(st.m.M5 and st.m.M5.cuivre), tostring(st.m.M6 and st.m.M6.ins)))
    -- E1b : un seul ingrédient, quantité N livrée PAR BRAS depuis un coffre qui n'a que lui (rangée sud)
    st.var = {}
    local MY2 = MY + 14
    for i, v in ipairs(VARIANTES) do
      local x = X0 + 4.5 + 10 * (i - 1)
      local nom = "rb0-kit-" .. v[1] .. "-" .. v[2]
      local m = s.create_entity({ name = "rb0-atelier", position = { x, MY2 }, force = "player" })
      if m then m.set_recipe(nom) end
      local c = s.create_entity({ name = "steel-chest", position = { x, MY2 - 3 }, force = "player" })
      c.insert({ name = v[1], count = math.min(v[2] * 4, 1500) })
      local b = s.create_entity({ name = v[3], position = { x, MY2 - 2 }, force = "player" })
      b.pickup_position = { x, MY2 - 3 }
      b.drop_position = { x, MY2 - 1 }
      st.var[i] = { e = m, coffre = c, bras = b, item = v[1], n = v[2], ins = v[3], recette = nom }
    end
    -- E1c : rangée 3 (deux ingrédients)
    st.deux = {}
    local MY3 = MY + 28
    for i, d in ipairs(DEUX) do
      local x = X0 + 4.5 + 12 * (i - 1)
      local m = s.create_entity({ name = d.machine or "rb0-atelier", position = { x, MY3 }, force = "player" })
      if m then m.set_recipe(d.recette) end
      local n = #d.coffres
      for j, contenu in ipairs(d.coffres) do
        local dx = n == 1 and 0 or (j == 1 and -1 or 1)
        local c = s.create_entity({ name = "steel-chest", position = { x + dx, MY3 - 3 }, force = "player" })
        for _, it in ipairs(contenu) do c.insert({ name = it[1], count = it[2] }) end
        local b = s.create_entity({ name = d.bras, position = { x + dx, MY3 - 2 }, force = "player" })
        b.pickup_position = { x + dx, MY3 - 3 }
        b.drop_position = { x + dx, MY3 - 1 }
      end
      st.deux[i] = { e = m, d = d }
    end
    local poses = 0
    for _, id in ipairs({ "M1", "M2", "M3", "M4", "M5", "M6" }) do
      if st.m[id] and st.m[id].e then poses = poses + 1 end
    end
    ctx.check(poses >= 5, "machines posees", poses .. " / " .. (m5 and 6 or 5))
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    -- bonus de productivité forcé juste avant la fin de la première fabrication de M2
    if t == 60 and st.m.M2.e and st.m.M2.e.valid then
      local ok, err = pcall(function() st.m.M2.e.bonus_progress = 0.99 end)
      st.m.M2.bonus_ecrit = ok and "ok" or tostring(err)
    end
    for _, id in ipairs({ "M1", "M2", "M3", "M4", "M5", "M6" }) do
      local r = st.m[id]
      if r and r.e and r.e.valid then
        local n = sortie_n(r.e)
        if n > r.max_sortie then r.max_sortie = n end
        if n >= 1 and not r.premier_plein then r.premier_plein = t end
      end
    end
    if t == 400 or t == 600 or t == CHECK - 1 then
      for _, id in ipairs({ "M1", "M2", "M3", "M4", "M5", "M6" }) do
        local r = st.m[id]
        if r and r.e and r.e.valid then
          local n, cases = sortie_n(r.e)
          ctx.log(string.format("E1 t=%d %s %s : statut=%s sortie=%d/%d case(s) max_sortie=%d produits=%d progres=%.3f " ..
            "fer=%d pierre=%d cuivre=%d cristal=%d", t, id, r.recette, C.statut(r.e), n, cases, r.max_sortie,
            r.e.products_finished, r.e.crafting_progress, compte(r.e, "iron-plate"), compte(r.e, "stone"),
            compte(r.e, "copper-plate"), compte(r.e, "fo-resonance-crystal")))
        end
      end
    end
    if t == 400 then
      local r = st.m.M1
      r.t400 = { statut = C.statut(r.e), n = sortie_n(r.e), produits = r.e.products_finished }
    end
    if t == T_RETRAIT then
      local r = st.m.M1
      local inv = r.e.get_output_inventory()
      local avant = sortie_n(r.e)
      r.retire = inv.remove({ name = "rb0-kit", count = 5 })
      r.avant_retrait = avant
      r.produits_retrait = r.e.products_finished
    end
    if t == T_RETRAIT + 300 then
      local r = st.m.M1
      r.t1000 = { statut = C.statut(r.e), n = sortie_n(r.e), produits = r.e.products_finished }
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local m1, m2, m3, m4, m5, m6 = st.m.M1, st.m.M2, st.m.M3, st.m.M4, st.m.M5, st.m.M6
    -- (1) arrêt à 1
    local t4 = m1.t400
    ctx.log(string.format("E1 (1) M1 tick 400 : statut=%s sortie=%d produits=%d ; retrait tick %d de %s (avant %s) ; tick 1000 : statut=%s sortie=%d produits=%d",
      t4.statut, t4.n, t4.produits, T_RETRAIT, tostring(m1.retire), tostring(m1.avant_retrait), m1.t1000.statut, m1.t1000.n, m1.t1000.produits))
    ctx.check(t4.n == 1 and t4.statut == "full_output", "E1 (1) la machine s'arrete d'elle-meme a 1 kit, statut full_output",
      t4.statut .. " sortie=" .. t4.n)
    ctx.check(t4.produits == 1, "E1 (1) products_finished tient a 1 pendant l'arret", tostring(t4.produits))
    ctx.check(m1.t1000.n == 1 and m1.t1000.produits == 2, "E1 (1) reprise apres retrait du kit par script (2 produits, 1 en sortie)",
      string.format("sortie=%d produits=%d", m1.t1000.n, m1.t1000.produits))
    -- (2) productivité
    ctx.log(string.format("E1 (2) M2 modules=%s(%s) bonus_progress ecrit=%s : max kits en sortie=%d produits=%d",
      tostring(m2.modules), tostring(m2.module_nom), tostring(m2.bonus_ecrit), m2.max_sortie, m2.e.products_finished))
    ctx.check(m2.max_sortie <= 1, "E1 (2) la productivite ne met jamais 2 kits dans la case de sortie de pile 1",
      "max=" .. m2.max_sortie)
    -- (3) ingrédients au-delà d'une pile
    ctx.log(string.format("E1 (3) M3 script : pierre inseree=%s/200 fer insere=%s/400 ; presents fin : pierre=%d fer=%d ; sortie max=%d produits=%d",
      tostring(m3.pierre), tostring(m3.fer), compte(m3.e, "stone"), compte(m3.e, "iron-plate"), m3.max_sortie, m3.e.products_finished))
    ctx.check(m3.pierre == 200 and m3.fer == 400, "E1 (3) insert par script de 200 pierres (pile 50) et 400 plaques (pile 100)",
      string.format("%s / %s", tostring(m3.pierre), tostring(m3.fer)))
    ctx.check(m3.max_sortie >= 1, "E1 (3) la recette a ingredients au-dela d'une pile fabrique", "produits=" .. m3.e.products_finished)
    ctx.log(string.format("E1 (3) M4 bras empileur : presents fin : pierre=%d fer=%d ; coffre pierre=%d fer=%d ; produits=%d",
      compte(m4.e, "stone"), compte(m4.e, "iron-plate"), m4.coffre.get_item_count("stone"), m4.coffre.get_item_count("iron-plate"),
      m4.e.products_finished))
    ctx.check(m4.max_sortie >= 1, "E1 (3) bras empileur : la recette a ingredients au-dela d'une pile fabrique", "produits=" .. m4.e.products_finished)
    if m5 then
      ctx.log(string.format("E1 (3) M5 cristal : insere=%s/200 (pile %s) cuivre=%s ; produits=%d", tostring(m5.cristal),
        tostring(m5.pile), tostring(m5.cuivre), m5.e.products_finished))
      ctx.check(m5.cristal == 200, "E1 (3) 200 cristaux acceptes par insert (pile " .. tostring(m5.pile) .. ")", tostring(m5.cristal))
    else
      ctx.log("E1 (3) M5 : fo-resonance-crystal absent de la copie")
    end
    -- E1b : variantes
    local livres = {}
    for i, v in ipairs(st.var) do
      local presents = v.e and v.e.valid and v.e.get_item_count(v.item) or -1
      local produits = v.e and v.e.valid and v.e.products_finished or -1
      local dans_sortie = v.e and v.e.valid and sortie_n(v.e) or -1
      local reste = v.coffre.get_item_count(v.item)
      ctx.log(string.format("E1b %-24s bras=%-14s : produits=%d sortie=%d ; dans la machine=%d ; coffre=%d/%d ; statut machine=%s bras=%s",
        v.recette, v.ins, produits, dans_sortie, presents, reste, math.min(v.n * 4, 1500), C.statut(v.e), C.statut(v.bras)))
      livres[#livres + 1] = string.format("%s%d%s=%s", v.item == "stone" and "pierre" or "fer", v.n, v.ins == "stack-inserter" and "(empileur)" or "",
        (produits >= 1 or dans_sortie >= 1) and "oui" or "NON")
    end
    ctx.log("E1b livre par bras : " .. table.concat(livres, " "))
    ctx.check(#st.var == #VARIANTES, "E1b variantes de quantite posees", #st.var .. " / " .. #VARIANTES)
    -- E1c
    for _, v in ipairs(st.deux) do
      ctx.log(string.format("E1c %-36s : produits=%d sortie=%d ; dans la machine pierre=%d fer=%d ; statut=%s", v.d.id,
        v.e.products_finished, sortie_n(v.e), v.e.get_item_count("stone"), v.e.get_item_count("iron-plate"), C.statut(v.e)))
    end
    -- (4) bras de sortie
    local k = m6.coffre.get_item_count("rb0-kit")
    ctx.log(string.format("E1 (4) M6 bras de sortie : %d kit(s) au coffre apres %d ticks (recette 2 s : %.1f attendus), produits=%d, statut=%s",
      k, CHECK, (CHECK - 60) / 120, m6.e.products_finished, C.statut(m6.e)))
    ctx.check(k >= 5, "E1 (4) un bras en sortie obtient des kits portables", tostring(k))
  end,
}
