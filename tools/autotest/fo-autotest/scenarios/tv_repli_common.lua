--[[
  Lot TV-REPLI (docs/TODO_VIDEO.md C07) : repli de placement simple d'un module sans lot (shared/team/repli_place.lua,
  script/team/repli_place.lua ; partie commune des scénarios tv-repli et tv-repli-temoin).
  Terrain : carré de 160 x 160 tuiles autour de (0, 0) vidé et mis en herbe, un gisement de fer ; coffre d'équipe garni ; plan directeur
  de votre équipe au rayon MAXIMAL (5 : le treillis ne peut plus grandir) ; interrupteur de banc no_lots (remote fo-ia1d set_option) : AUCUN
  lot du treillis n'est candidat, comme si les huit lots essayés étaient tous refusés. Demande au tick 120 : une fonderie de fer (3
  fours, sans alimentation). Attendu :
    repli allumé  : le projet est planifié (pas refusé), sa première partie a le lot « repli », ses entités existent en fantômes (ghosts_ahead : le chantier
                    des PNJ dure plus que ce micro-banc) ; la ligne [FO-REPLI-PLACE] est au journal (lue à l'archive : grep) ;
    repli éteint (témoin) : le projet est refusé (« pas de lot »), aucune partie, aucune ligne [FO-REPLI-PLACE].
  Lancement : banc.py --out <archive> --qui TV-REPLI -- 2500 tv-repli <source> (et tv-repli-temoin).
]]
local T_REQUEST = 120
local CHECK = 2450
local HALF = 80


--- Contrôles du projet de la demande, faits dès que le plan est sorti de l'état « plan » (ou à la fin du banc).
local function verify(ctx, on, TAG, proj, rep)
  local st = ctx.state()
  ctx.log(TAG .. string.format("projet %d : %s%s, %d/%d entites, %d partie(s), rayon %d", proj.id, proj.state,
    proj.reason and (" (" .. proj.reason .. ")") or "", proj.built or 0, proj.total or 0, #(proj.parts or {}), rep.radius or -1))
  local s = ctx.surface()
  if on then
    ctx.check(proj.state ~= "refuse" and proj.state ~= "bloque", "repli allume : le projet n'est ni refuse ni bloque : " .. tostring(proj.state))
    local part = proj.parts and proj.parts[1]
    ctx.check(part ~= nil and part.lot == "repli", "repli allume : la premiere partie porte le lot « repli »", part and tostring(part.lot) or "aucune partie")
    ctx.check((proj.total or 0) > 0, "repli allume : des entites planifiees", tostring(proj.total))
    if part then
      -- fantomes ou batiments sur l'emprise de la partie
      local found = #s.find_entities_filtered({ area = { { part.x, part.y }, { part.x + part.w, part.y + part.h } }, force = "player",
        name = { "stone-furnace", "entity-ghost" } })
      ctx.check(found > 0, "repli allume : des fours ou des fantomes sur l'emprise de la partie", tostring(found))
      ctx.log(TAG .. string.format("partie %s lot %s en (%d, %d) %dx%d rotation %d ; %d four(s)/fantome(s) sur l'emprise", part.kind, tostring(part.lot),
        part.x, part.y, part.w, part.h, part.rotation or 0, found))
    end
  else
    ctx.check(proj.state == "refuse" or proj.state == "bloque" or #(proj.parts or {}) == 0, "temoin (repli eteint) : le projet n'est pas planifie : " .. tostring(proj.state))
    ctx.check(not (proj.parts and proj.parts[1] and proj.parts[1].lot == "repli"), "temoin : aucune partie de repli")
  end
end

return function(on)
  local TAG = on and "[FO-TV-REPLI] " or "[FO-TV-REPLI-TEMOIN] "
  return {
    description = "TV-REPLI : repli de placement simple " .. (on and "allume" or "eteint (temoin)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      s.request_to_generate_chunks({ 0, 0 }, 6)
      s.force_generate_chunk_requests()
      local area = { { -HALF, -HALF }, { HALF, HALF } }
      for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
        if e.valid then e.destroy() end
      end
      local tiles = {}
      for y = -HALF, HALF - 1 do for x = -HALF, HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
      s.set_tiles(tiles, true)
      for dy = -8, 8 do
        for dx = -8, 8 do
          if dx * dx + dy * dy <= 64 then s.create_entity({ name = "iron-ore", position = { 40 + dx + 0.5, -20 + dy + 0.5 }, amount = 3000 }) end
        end
      end
      local a = ctx.call("war_setting", "fo-war-ia3e", false)
      ctx.check(a == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)", tostring(a))
      local r = ctx.call("war_setting", "fo-war-repli-place", on)
      ctx.check(r == on, "reglage fo-war-repli-place " .. (on and "allume" or "eteint"), tostring(r))
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      for _, it in ipairs({ { "iron-plate", 2000 }, { "coal", 1500 }, { "stone-furnace", 30 }, { "transport-belt", 200 }, { "inserter", 60 },
        { "medium-electric-pole", 40 }, { "iron-chest", 20 }, { "pistol", 10 }, { "firearm-magazine", 200 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
      local ok = ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 5 })
      ctx.check(ok == true, "plan directeur active au rayon maximal (5)")
      ctx.check(ctx.remote("fo-ia1d", "set_option", "player", "no_lots", true) == true, "interrupteur de banc no_lots pose")
      st.t0 = game.tick
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local t = e.tick - st.t0
      if t == T_REQUEST then
        st.id = ctx.remote("fo-ia1d", "request", "player", { gen = "smelter", args = { "stone-furnace", "iron-ore", 3 } })
        ctx.log(TAG .. "demande : fonderie de fer, projet " .. tostring(st.id))
      end
      -- le plan se fait sur plusieurs passes (relevés des masques au budget) : on contrôle dès que le projet n'est plus « plan »
      if t > T_REQUEST and t % 30 == 0 and st.id and not st.checked then
        local rep = ctx.remote("fo-ia1d", "report", "player")
        if not rep then return end
        st.rep = rep
        for _, p in ipairs(rep.projects) do
          if p.id == st.id and (p.state ~= "plan" or #(p.parts or {}) > 0) then
            st.checked = true
            st.t_plan = t
            local ok, err = pcall(verify, ctx, on, TAG, p, rep)
            if not ok then ctx.check(false, "controle du projet : erreur", tostring(err)) end
          end
        end
      end
    end,
    finish = function(ctx)
      local st = ctx.state()
      ctx.check(st.id ~= nil, "la demande a rendu un numero de projet", tostring(st.id))
      if not st.checked then
        -- le plan n'est jamais sorti de l'etat « plan » avant la fin : controle sur le dernier releve
        local rep = ctx.remote("fo-ia1d", "report", "player") or st.rep
        local proj
        for _, p in ipairs(rep and rep.projects or {}) do if p.id == st.id then proj = p end end
        ctx.check(proj ~= nil, "le projet est au releve")
        if on then ctx.check(false, "le plan n'a pas fini avant la fin du banc", proj and tostring(proj.state) or "-") end -- le temoin peut rester « plan » (nouvel essai sans fin)
        if proj then verify(ctx, on, TAG, proj, rep) end
      end
    end,
  }
end
