--[[
  Lot LEVIERS : recherches à effet choisies par la capitalisation en moteur réel. Chaque faction a tous les prérequis des
  recherches « productivité des foreuses », « vitesse des laboratoires » et « vitesse du travail » déjà faits (script du banc),
  des packs au coffre, un laboratoire, une demande de plaques et tous ses gisements interdits (fo-capi block_sites) : la
  construction de capacité n'a plus d'option, le repli doit chiffrer les recherches à effet.
  Attendus : (1) un ordre « techno » est décidé (fo-capi status : ouvert ou fini, champ tech) ; (2) le choix de la technologie
  de la faction (fo-iag status, historique) retient une de ces recherches à effet.
  Lancement : banc.py --out <archive> --qui LEVIERS -- 43300 leviers-techno <source>.
]]
local MIN = 3600
local T_END = 43200
local LEVER_TYPES = { ["mining-drill-productivity-bonus"] = true, ["laboratory-speed"] = true, ["worker-robot-speed"] = true,
  ["laboratory-productivity"] = true }

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function factions(ctx)
  local out = {}
  for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

local function lever_techs(force)
  local out = {}
  for _, name in ipairs(sorted_keys(force.technologies)) do
    local t = force.technologies[name]
    if t.enabled and not t.research_unit_count_formula then
      for _, e in ipairs(t.effects) do
        if LEVER_TYPES[e.type] then out[name] = e.type end
      end
    end
  end
  return out
end

local function close_prereqs(force, names)
  local seen, stack = {}, {}
  for n in pairs(names) do stack[#stack + 1] = n end
  while #stack > 0 do
    local n = table.remove(stack)
    local t = force.technologies[n]
    for _, p in ipairs(sorted_keys(t.prerequisites)) do
      if not seen[p] then
        seen[p] = true
        stack[#stack + 1] = p
      end
    end
  end
  return seen
end

return {
  description = "LEVIERS : recherches a effet choisies par le repli (prerequis faits, sites interdits)",
  base = nil,
  check_tick = T_END,

  init = function(ctx)
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-recruit-idle-max", 60) == 60, "frein par le travail leve")
    ctx.check(ctx.call("war_setting", "fo-war-workers", 30) == 30, "30 ouvriers")
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", true) == true, "automatisation allumee")
    ctx.check(ctx.call("war_setting", "fo-war-capi", true) == true, "capitalisation allumee")
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "Paisible")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee (2 factions)")
    ctx.check(ctx.call("war_fund", 2500) == 2, "2 factions financees")
    ctx.state().seen = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 300 then
      for _, row in ipairs(factions(ctx)) do
        local force = game.forces[row.force]
        local lv = lever_techs(force)
        local pre = close_prereqs(force, lv)
        local n = 0
        for _, name in ipairs(sorted_keys(pre)) do
          if not lv[name] and not force.technologies[name].researched then
            force.technologies[name].researched = true
            n = n + 1
          end
        end
        local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
        if hq then
          local inv = hq.get_inventory(defines.inventory.chest)
          for _, it in ipairs({ { "automation-science-pack", 300 }, { "logistic-science-pack", 300 }, { "chemical-science-pack", 100 },
            { "lab", 2 } }) do
            if game.item_prototypes[it[1]] then inv.insert({ name = it[1], count = it[2] }) end
          end
        end
        ctx.remote("fo-capi", "block_sites", row.key, true)
        ctx.remote("fo-capi", "bench_sink", row.key, "iron-plate", 600)
        local names = {}
        for _, k in ipairs(sorted_keys(lv)) do names[#names + 1] = k end
        ctx.log(string.format("%s : %d prerequis faits ; recherches a effet %s", row.key, n, table.concat(names, " ")))
        st.seen[row.key] = { lever = lv }
      end
    end
    if e.tick > 300 and e.tick % 1200 == 0 then
      for _, row in ipairs(factions(ctx)) do
        local r = st.seen[row.key]
        if r then
          local cs = ctx.remote("fo-capi", "status", row.key)
          for _, rec in ipairs(cs and cs.open or {}) do
            if rec.kind == "techno" and rec.tech and not r.order then
              r.order = rec.tech
              r.order_tick = e.tick
              ctx.log(string.format("ordre %s : recherche a effet %s (%s) a t=%d", row.key, rec.tech, tostring(r.lever[rec.tech]), e.tick))
            end
          end
          for _, d in ipairs(cs and cs.done or {}) do
            if d.kind == "techno" and not r.done then
              r.done = d.key
              ctx.log(string.format("ordre %s fini : %s %s", row.key, d.key, d.state))
            end
          end
          local g = ctx.remote("fo-iag", "status", row.key)
          for _, h in ipairs(g and g.history or {}) do
            if r.lever[h.tech] and not r.chosen then
              r.chosen = h.tech
              r.chosen_tick = h.tick
              ctx.log(string.format("choix de la technologie %s : %s a t=%d (valeur %s)", row.key, h.tech, h.tick, tostring(h.value)))
            end
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local any_order, any_chosen = false, false
    for _, key in ipairs(sorted_keys(st.seen)) do
      local r = st.seen[key]
      ctx.log(string.format("%s : ordre techno %s, technologie a effet choisie %s", key, tostring(r.order), tostring(r.chosen)))
      if r.order then any_order = true end
      if r.chosen then any_chosen = true end
    end
    ctx.check(any_order, "un ordre de recherche a effet decide (au moins une faction)")
    ctx.check(any_chosen, "la recherche a effet est choisie par le choix de la technologie (au moins une faction)")
  end,
}
