-- Lot ROBOTS-JEU (3/11) : le Bourdon FABRIQUÉ, sans joueur. Prototypes (objet, relais, recette au Portique, technologie), puis le relais posé par
-- script (raise_built : même gestionnaire que la pose à la main) : refusé à l'âge 12 (objet rendu au sol), 3 Bourdons admis à l'âge 15, le
-- quatrième refusé (plafond de géants : un Bourdon compte pour un géant).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui ROBOTS-JEU -- 300 bourdon-fabrique <source>
local X, Y = 9000, -3000
local OBJET, RELAIS, RECETTE, TECHNO = "fo-bourdon-item", "fo-bourdon-pose", "fo-robot-make-bourdon", "fo-robot-bourdon"

local function poser(ctx, k)
  local s = ctx.surface()
  s.create_entity({ name = RELAIS, position = { X + 90 * k, Y }, force = "player", raise_built = true })
end

local function bourdons()
  return #game.surfaces[1].find_entities_filtered({ name = "fo-bourdon", area = { { X - 100, Y - 100 }, { X + 500, Y + 100 } } })
end

local function au_sol(k)
  local n = 0
  for _, e in ipairs(game.surfaces[1].find_entities_filtered({ type = "item-entity", area = { { X + 90 * k - 6, Y - 6 }, { X + 90 * k + 6, Y + 6 } } })) do
    if e.stack.valid_for_read and e.stack.name == OBJET then n = n + e.stack.count end
  end
  return n
end

return {
  description = "ROBOTS-JEU : le Bourdon fabrique au Portique, pose par le relais, plafond de geants",
  check_tick = 260,

  init = function(ctx)
    ctx.prepare_area(X - 60, Y - 60, X + 460, Y + 60, "dry-dirt")
    local s = ctx.surface()
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X - 200, Y - 200 }, { X + 600, Y + 200 } } })) do en.destroy() end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 10 then
      local it = game.item_prototypes[OBJET]
      ctx.check(it ~= nil and it.place_result ~= nil and it.place_result.name == RELAIS, "l'objet pose le relais (jamais le spider-vehicle)",
        it and it.place_result and it.place_result.name or "absent")
      local r = game.recipe_prototypes[RECETTE]
      ctx.check(r ~= nil and r.category == "fo-robots-4" and r.products[1].name == OBJET, "recette au Portique (fo-robots-4)", r and r.category or "absente")
      local tp = game.technology_prototypes[TECHNO]
      local ouvre = false
      for _, ef in ipairs(tp and tp.effects or {}) do if ef.type == "unlock-recipe" and ef.recipe == RECETTE then ouvre = true end end
      ctx.check(tp ~= nil and ouvre and tp.prerequisites["fo-robot-gantry-crowned"] ~= nil, "technologie : ouvre la recette, apres le Couronne",
        tp and "ok" or "absente")
      remote.call("fo-robots", "set_age", "player", 12)
      poser(ctx, 0)
    end
    if t == 40 then
      ctx.check(bourdons() == 0 and au_sol(0) == 1, "age 12 : refuse, objet rendu au sol", bourdons() .. " Bourdon(s), " .. au_sol(0) .. " objet(s) au sol")
      remote.call("fo-robots", "set_age", "player", 15)
      for k = 1, 3 do poser(ctx, k) end
    end
    if t == 60 then
      st.trois = bourdons()
      ctx.check(st.trois == 3, "age 15 : 3 Bourdons descendent (3 geants admis)", st.trois .. " / 3")
      local relais = #game.surfaces[1].find_entities_filtered({ name = RELAIS })
      ctx.check(relais == 0, "aucun relais ne reste", relais)
      poser(ctx, 4)
    end
    if t == 80 then
      ctx.check(bourdons() == 3 and au_sol(4) == 1, "le quatrieme est refuse (plafond de geants)", bourdons() .. " Bourdon(s), " .. au_sol(4) .. " objet(s) au sol")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.trois == 3 and bourdons() == 3, "les 3 Bourdons sont toujours la", tostring(st.trois) .. " -> " .. bourdons())
  end,
}
