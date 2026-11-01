--[[
  Lot RB-FLUIDE (1/11) : une faction fabrique son PREMIER robot sans que le banc lui donne la technologie. Base : rb_faction_common.lua.
  Ce que le banc donne (une partie de 45 min, comme rb-fluide-sonde) : les recherches de la chaine du petrole jusqu'au pack chimique, des
  packs rouges, verts et militaires au coffre (le laboratoire du QG les mange), l'atelier et les pieces du plan directeur, la vitesse du
  laboratoire x4 (la recherche de 10 unites de 30 s dure sinon 18 000 ticks). Ce que le banc NE donne PAS : la technologie des robots.
  Chaine attendue, tout par le MOD :
    (1) la faction VEUT le kit du premier robot (Fa.wanted) -> la recherche de sa technologie est choisie par le cerveau ;
    (2) la technologie est faite par le laboratoire ; (3) la demande de kits est notee au mall ; (4) cellule seule, module fini ;
    (5) un kit devient une unite, soldat de la faction (Military.adopt) : le robot SORT DE L'USINE.
  Temoin : l'autre faction n'a pas de packs au coffre : elle ne fait pas la recherche (pas de robot).
  Comme ind_mall_common.lua, le BANC ravive les fantomes du module et garnit ses quais d'entree (le temps des PNJ).
  Lancement : banc.py --out <archive> --qui RB-FLUIDE -- <ticks> rb-fluide <source>    (plus de 10 000 ticks : voir le rapport)
]]

local KIT = "fo-robot-kit-steam-trotter"
local WORKSHOP = "fo-robot-workshop"
local TECH = "fo-robot-automata"
local CHECK = 22000

local TECHS = { "automation", "logistic-science-pack", "steel-processing", "military-science-pack", "engine", "electronics", "fast-inserter",
  "automation-2", "fluid-handling", "oil-processing", "sulfur-processing", "plastics", "advanced-electronics", "chemical-science-pack" }

local PARTS = {
  { WORKSHOP, 4 }, { "automation-science-pack", 100 }, { "logistic-science-pack", 100 }, { "military-science-pack", 100 },
  { "assembling-machine-1", 12 }, { "assembling-machine-2", 24 }, { "inserter", 80 }, { "long-handed-inserter", 40 },
  { "fast-inserter", 30 }, { "wood", 200 }, { "transport-belt", 300 }, { "iron-chest", 30 }, { "wooden-chest", 10 }, { "small-electric-pole", 60 },
  { "medium-electric-pole", 40 }, { "copper-plate", 800 }, { "stone-brick", 300 }, { "coal", 400 },
}

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function module_ents(ctx, key, id)
  local lay = ctx.remote("fo-ia1d", "layout", key)
  local out = {}
  for _, e in ipairs(lay and lay.ents or {}) do
    if e.pid == id then out[#out + 1] = e end
  end
  return out
end

return {
  description = "RB-FLUIDE : une faction recherche la technologie du premier robot, la fait, fabrique un robot (technologie NON donnee)",
  check_tick = CHECK,

  init = function(ctx)
    local function set_setting(n, v)
      local r = ctx.call("war_setting", n, v)
      ctx.check(r == v, "reglage " .. n .. " = " .. tostring(v), tostring(r))
    end
    set_setting("fo-war-industrie", true)
    set_setting("fo-war-ia3e", true)
    set_setting("fo-war-capi", true)
    set_setting("fo-war-workers", 30)
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
    ctx.check(ctx.call("war_fund", 20000) == 2, "2 factions financees")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 400 then
      local tm = teams(ctx)
      st.key, st.control, st.force = tm[1] and tm[1].key, tm[2] and tm[2].key, tm[1] and tm[1].force
      st.cforce = tm[2] and tm[2].force
      if not st.key then ctx.fail("deux factions relevees") return end
      for _, name in ipairs({ st.force, st.cforce }) do
        local f = game.forces[name]
        for _, tn in ipairs(TECHS) do f.technologies[tn].researched = true end
        f.laboratory_speed_modifier = 3 -- x4
      end
      local f = game.forces[st.force]
      ctx.check(not f.technologies[TECH].researched and f.technologies["engine"].researched,
        st.key .. " : recherches de 45 min faites, technologie des robots NON faite (le banc ne la donne pas)")
      local put = ctx.remote("fo-ind", "stock", st.key, PARTS)
      ctx.check(put ~= nil and (put[WORKSHOP] or 0) >= 1 and (put["automation-science-pack"] or 0) >= 50, st.key .. " : atelier, packs et pieces au coffre")
      -- le temoin n'a pas de packs : il ne peut rien chercher
      ctx.check(ctx.remote("fo-ind", "stock", st.control, { { "iron-chest", 4 } }) ~= nil, st.control .. " : temoin sans packs")
    end
    if not st.key then return end
    -- (1) la recherche du premier robot est choisie par le cerveau
    if t % 300 == 0 and t >= 600 and not st.chosen then
      local s = ctx.remote("fo-iag", "status", st.key)
      for _, h in ipairs(s and s.history or {}) do
        if h.tech == TECH then
          st.chosen = t
          ctx.log(string.format("la recherche %s est choisie par le cerveau (valeur %s) au tick %d", TECH, tostring(h.value), t))
        end
      end
    end
    if t % 300 == 0 and t >= 600 and not st.done_tech and game.forces[st.force].technologies[TECH].researched then
      st.done_tech = t
      ctx.log("technologie " .. TECH .. " faite au tick " .. t)
    end
    if st.done_tech and not st.hastened and t % 60 == 0 then
      if ctx.remote("fo-ind", "hasten", st.key) == true then st.hastened = t end
    end
    if t % 120 == 0 and st.done_tech and not st.done_fini then
      local s0 = ctx.remote("fo-ind", "status", st.key)
      local b0 = s0 and s0.blocs and s0.blocs[1]
      if b0 and (b0.state == "fantomes" or b0.state == "chantier" or b0.state == "raccordement" or b0.state == "fini") then
        local s1 = ctx.surface()
        local ents = module_ents(ctx, st.key, b0.id)
        st.revived = (st.revived or 0) + (ctx.remote("fo-ind", "revive", st.key, b0.id) or 0)
        if not st.powered then
          for _, en in ipairs(ents) do
            if not st.powered and en.name:find("electric%-pole") then
              local real = s1.find_entity(en.name, { en.x, en.y })
              if real and real.valid then
                for _, d in ipairs({ { 2, 2 }, { -2, 2 }, { 2, -2 }, { -2, -2 }, { 3, 0 }, { 0, 3 }, { -3, 0 }, { 0, -3 } }) do
                  if not st.powered and ctx.power(real.position.x + d[1], real.position.y + d[2], real.force.name) then st.powered = true end
                end
              end
            end
          end
        end
        if b0.state == "fini" then
          st.done_fini = t
          for _, q in ipairs(b0.quais or {}) do
            local ch = s1.find_entity("iron-chest", { q.x, q.y })
            if ch and ch.valid then ch.insert({ name = q.item, count = 600 }) end
          end
          ctx.log(string.format("module %d FINI au tick %d (%d fantome(s) ravives par le banc)", b0.id, t, st.revived or 0))
        end
      end
    end
    if t % 1200 == 0 and t >= 1200 then
      local v = ctx.remote("fo-robots-faction", "view", st.key)
      ctx.log(string.format("tick %d : technologie %s, ateliers %s, points de robots %s, soldats %s", t,
        tostring(game.forces[st.force].technologies[TECH].researched), tostring(v and v.workshops), tostring(v and v.robots), tostring(v and v.by_unit)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.key then return end
    ctx.check(st.chosen ~= nil, st.key .. " : (1) la recherche des robots est choisie par le cerveau (aucune donnee du banc)", tostring(st.chosen))
    ctx.check(st.done_tech ~= nil, st.key .. " : (2) la technologie des robots est faite par le laboratoire", tostring(st.done_tech))
    local s = ctx.remote("fo-ind", "status", st.key)
    local b = s and s.blocs[1]
    ctx.check(b ~= nil and b.kind == "seul" and b.items[1] == KIT, "(4) le module est une cellule seule du kit", b and (b.kind .. " " .. tostring(b.items[1])) or "aucun module")
    ctx.check(b ~= nil and b.state == "fini", "(4) la cellule est finie", b and (tostring(b.state) .. " " .. tostring(b.reason)) or "aucun module")
    local etat = ctx.remote("fo-robots", "state", st.force)
    ctx.check(etat ~= nil and etat.stats.created >= 1 and #etat.units >= 1, "(5) un kit est devenu une unite de la faction : le robot sort de l'usine",
      etat and string.format("creees %d, unites %d", etat.stats.created, #etat.units) or "etat absent")
    local un = etat and etat.units[1]
    local vue = un and ctx.remote("fo-robots", "faction_view", un)
    ctx.check(vue ~= nil and vue.listed == true and vue.kind == "soldier" and vue.garrison >= 1, "(5) le robot est un soldat de la faction (inscrit, garnison)",
      vue and string.format("inscrit %s, genre %s, garnison %s", tostring(vue.listed), tostring(vue.kind), tostring(vue.garrison)) or "aucune vue")
    local vc = ctx.remote("fo-robots-faction", "view", st.control)
    ctx.check(vc ~= nil and vc.workshops == 0 and vc.robots == 0 and not game.forces[st.cforce].technologies[TECH].researched,
      "temoin (sans packs) : pas de recherche des robots, aucun atelier, aucun robot")
    local ok, why = ctx.remote("fo-robots", "check")
    ctx.check(ok == true and etat.stats.create_failed == 0, "registre coherent, aucun echec de creation", tostring(why))
  end,
}
