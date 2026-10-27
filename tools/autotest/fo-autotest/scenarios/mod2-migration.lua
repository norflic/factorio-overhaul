-- Scénario greffé du lot MOD-2 (25/10) : MIGRATION d'une partie 0.4.19 (modules multipliés, SANS recettes par lots)
-- vers les recettes par lots. Double source SEULEMENT (tools/autotest/README.md §1.1) :
--   $env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-25_MOD2\src-0.4.19"     (= git archive 90f7518 + feuilles D-6)
--   & "<racine>\fo-autotest.bat" nopause 600 mod2-migration "<source MOD-2>"
--   $env:FO_CREATE_SRC = $null
-- À la création (0.4.19) : machines rapides posées avec leurs modules (balise de complément de MOD-1), recherche du
-- béton et du soufre faite ; une machine SANS courant garde 100 plaques. Au chargement par MOD-2 :
-- on_configuration_changed → lots activés pour les recettes déjà actives, machines recensées, chacune basculée au lot
-- que demande sa vitesse ; contenu gardé.

local X, Y = 8000, 8000
local P10 = "fo-speed-module-10"
local WA, WB = 200, 500

local CAS = {
  { id = "M1-niveau30-34xP10", m = "fo-lvl-assembler-30", rec = "iron-gear-wheel", mods = 34, dx = 0, lot = 100, feed = "iron-plate" },
  { id = "M2-am2-5xP10", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = 5, dx = 12, lot = 10 },
  { id = "M3-am2-beton-5xP10", m = "assembling-machine-2", rec = "concrete", mods = 5, dx = 20, lot = 1 },
  -- Lot MOD-3 (D-17) : 3 × P10 = × 9,26 (9,3 /s) : lot 1 (lot 10 avant D-17, × 74,09). Les autres lots sont inchangés.
  { id = "M4-chimie-acide-3xP10", m = "chemical-plant", rec = "sulfuric-acid", mods = 3, dx = 28, lot = 1 },
  { id = "M5-am2-sans-module", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = 0, dx = 36, lot = 1 },
}

local function input(m) return m.get_inventory(defines.inventory.assembling_machine_input) end

local function lot_of(m)
  local r = m.get_recipe()
  local name = r and r.name or ""
  local k = name:match("^fo%-lot(%d+)%-")
  return k and tonumber(k) or 1, name
end

return {
  description = "MOD-2 : migration d'une partie 0.4.19 (modules multiplies) vers les recettes par lots",
  base = nil,
  check_tick = 550,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local f = game.forces.player
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.check(game.recipe_prototypes["fo-lot10-iron-gear-wheel"] == nil, "carte creee SANS les recettes par lots (source 0.4.19)",
      tostring(game.recipe_prototypes["fo-lot10-iron-gear-wheel"] ~= nil))
    f.technologies["concrete"].researched = true
    f.technologies["sulfur-processing"].researched = true
    ctx.prepare_area(X - 12, Y - 12, X + 60, Y + 40, "grass-1")
    ctx.power(X + 20, Y)
    st.cas = {}
    for _, c in ipairs(CAS) do
      local m = s.create_entity({ name = c.m, position = { X + c.dx, Y }, force = f, raise_built = true })
      m.set_recipe(c.rec)
      local inv = m.get_module_inventory()
      for _ = 1, c.mods do inv.insert({ name = P10, count = 1 }) end
      pcall(remote.call, "fo-modules", "refresh", m, true)
      st.cas[#st.cas + 1] = { c = c, m = m, n = 0 }
    end
    -- Machine SANS courant (hors de la zone du poteau) : 100 plaques à l'entrée, gardées par la bascule.
    ctx.prepare_area(X + 200, Y - 12, X + 220, Y + 12, "grass-1")
    local nc = s.create_entity({ name = "assembling-machine-2", position = { X + 210, Y }, force = f, raise_built = true })
    nc.set_recipe("iron-gear-wheel")
    for _ = 1, 5 do nc.get_module_inventory().insert({ name = P10, count = 1 }) end
    pcall(remote.call, "fo-modules", "refresh", nc, true)
    st.nc = nc
    st.nc_put = input(nc).insert({ name = "iron-plate", count = 100 })
    ctx.log("creation : " .. #st.cas .. " machines rapides ; sans courant : " .. st.nc_put .. " plaques a l'entree")
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    local c1 = st.cas[1]
    if c1 and c1.m.valid then
      local m = c1.m
      local inv = input(m)
      local k = inv.get_item_count("iron-plate")
      if k < 100000 then inv.insert({ name = "iron-plate", count = 100000 - k }) end
      local out = m.get_output_inventory()
      local nb = out.get_item_count()
      if nb > 0 then out.clear() end
      if t > WA and t <= WB then c1.n = c1.n + nb end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local f = game.forces.player
    if not st.pret then
      ctx.fail("scenario pret", "init interrompue")
      return
    end
    ctx.check(ctx.has("fo-lots", "state"), "mod charge avec les recettes par lots (MOD-2)")
    ctx.check(f.recipes["fo-lot10-iron-gear-wheel"].enabled and f.recipes["fo-lot100-iron-gear-wheel"].enabled
      and f.recipes["fo-lot10-concrete"].enabled and f.recipes["fo-lot10-sulfuric-acid"].enabled
      and not f.recipes["fo-lot10-processing-unit"].enabled,
      "lots actives a la mise a jour pour les recettes deja actives (et seulement elles)",
      "processing-unit actif ? " .. tostring(f.recipes["processing-unit"].enabled))
    local bad = {}
    for _, c in ipairs(st.cas) do
      local k, name = lot_of(c.m)
      ctx.log(string.format("MESURE %s : vitesse %.3f ; recette %s (lot %d, attendu %d)", c.c.id, c.m.crafting_speed, name, k, c.c.lot))
      if k ~= c.c.lot then bad[#bad + 1] = c.c.id .. " lot " .. k .. " (attendu " .. c.c.lot .. ")" end
    end
    ctx.check(#bad == 0, "chaque machine au lot que demande sa vitesse apres la mise a jour", table.concat(bad, " ; "))
    local c1 = st.cas[1]
    local secs = (WB - WA) / 60
    local want = c1.m.crafting_speed / 0.5
    ctx.log(string.format("MESURE M1 apres mise a jour : %d engrenages en %.0f s = %.1f /s (voulu %.1f ; 60 avant)", c1.n, secs, c1.n / secs, want))
    ctx.check(math.abs(c1.n / secs - want) <= 0.02 * want, "M1 : debit voulu apres la mise a jour (et non 60 /s)", string.format("%.1f /s", c1.n / secs))
    local nc = st.nc
    local k, name = lot_of(nc)
    local plates = input(nc).get_item_count("iron-plate")
    ctx.check(k == 10 and plates == st.nc_put and st.nc_put == 100, "machine sans courant : basculee au lot 10, ses 100 plaques gardees",
      name .. " ; " .. plates .. " plaques")
    local stats = remote.call("fo-lots", "stats")
    ctx.log("STATS " .. serpent.line(stats))
  end,
}
