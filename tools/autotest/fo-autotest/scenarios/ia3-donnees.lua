--[[
  Lot IA3-0 (revue M13) : les DONNÉES hors jeu du cerveau sont-elles celles du moteur ?
    1. chaque technologie de tests/fixtures/tech_ai3_final.lua (export `harness.lua --dump-techs`, coûts FINAUX du mod)
       contre game.technology_prototypes : unités, durée d'une unité, packs, prérequis, recettes débloquées ; et aucune
       technologie finie du jeu absente de la fixture ;
    2. recettes ACTIVES d'une force neuve contre la règle déduite hors jeu (« active au départ = aucune technologie ne
       la débloque », docs/IA3_CERVEAU.md §7) : écarts comptés et nommés.
  Lancement : `fo-autotest.bat nopause 120 ia3-donnees <source>`. Journal : [FO-IA3-DONNEES].
]]

local TF = require("__factorio-overhaul__/tests/fixtures/tech_ai3_final")

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

return {
  description = "IA3-0 : fixture des technologies finales et recettes actives contre le moteur",
  check_tick = 60,

  init = function(ctx)
    game.create_force("ia3-donnees")
  end,

  finish = function(ctx)
    local protos = game.technology_prototypes
    local bad, examples, n = 0, {}, 0
    local function note(msg)
      bad = bad + 1
      if #examples < 6 then examples[#examples + 1] = msg end
    end
    for _, name in ipairs(sorted_keys(TF)) do
      n = n + 1
      local f, p = TF[name], protos[name]
      if not p then
        note(name .. " absente du jeu")
      else
        if p.research_unit_count ~= f.count then note(string.format("%s : unites %s / %s", name, tostring(p.research_unit_count), f.count)) end
        if math.abs(p.research_unit_energy - f.time * 60) > 1e-6 then
          note(string.format("%s : ticks par unite %s / %s", name, tostring(p.research_unit_energy), f.time * 60))
        end
        local ing = {}
        for _, i in ipairs(p.research_unit_ingredients) do ing[i.name] = i.amount end
        for _, i in ipairs(f.ingredients) do
          if ing[i[1]] ~= i[2] then note(name .. " : pack " .. i[1]) end
          ing[i[1]] = nil
        end
        if next(ing) then note(name .. " : pack en trop dans le jeu") end
        local pre = {}
        for k in pairs(p.prerequisites) do pre[k] = true end
        for _, q in ipairs(f.prerequisites) do
          if not pre[q] then note(name .. " : prerequis " .. q) end
          pre[q] = nil
        end
        if next(pre) then note(name .. " : prerequis en trop dans le jeu") end
        local unl = {}
        for _, e in ipairs(p.effects) do if e.type == "unlock-recipe" then unl[e.recipe] = true end end
        for _, r in ipairs(f.unlocks) do
          if not unl[r] then note(name .. " : recette " .. r) end
          unl[r] = nil
        end
        if next(unl) then note(name .. " : recette debloquee en trop dans le jeu") end
      end
    end
    local missing = 0
    for _, name in ipairs(sorted_keys(protos)) do
      local p = protos[name]
      if not TF[name] and p.research_unit_count_formula == nil then missing = missing + 1 end
    end
    ctx.log(string.format("FAIT fixture : %d technologies comparees, %d ecart(s) ; technologies finies du jeu absentes de la fixture : %d",
      n, bad, missing))
    for _, e in ipairs(examples) do ctx.log("FAIT ecart : " .. e) end
    ctx.check(bad == 0 and missing == 0, "fixture des technologies finales = prototypes du moteur", bad .. " ecart(s), " .. missing .. " absente(s)")

    -- Recettes actives d'une force neuve contre la règle déduite.
    local unlocked = {}
    for _, name in ipairs(sorted_keys(TF)) do for _, r in ipairs(TF[name].unlocks) do unlocked[r] = true end end
    local force = game.forces["ia3-donnees"]
    local on_not_free, free_not_on, total, ex = 0, 0, 0, {}
    for _, name in ipairs(sorted_keys(game.recipe_prototypes)) do
      local r = force.recipes[name]
      total = total + 1
      local deduced = not unlocked[name]
      if r.enabled and not deduced then
        on_not_free = on_not_free + 1
        if #ex < 4 then ex[#ex + 1] = "active mais debloquee par une technologie : " .. name end
      elseif deduced and not r.enabled and not r.hidden then
        free_not_on = free_not_on + 1
        if #ex < 8 then ex[#ex + 1] = "inactive sans technologie qui la debloque : " .. name end
      end
    end
    ctx.log(string.format("FAIT recettes d'une force neuve : %d ; actives alors qu'une technologie les debloque : %d ; ni actives ni debloquees par une technologie (non cachees) : %d",
      total, on_not_free, free_not_on))
    for _, e in ipairs(ex) do ctx.log("FAIT " .. e) end
    ctx.check(on_not_free == 0, "aucune recette active au depart qu'une technologie debloquerait", on_not_free)
  end,
}
