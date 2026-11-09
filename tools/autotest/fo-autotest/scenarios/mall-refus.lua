--[[
  Micro-banc « mall-refus » du lot MALL : le plantage « cell nil » (carte à 600 %, graine 271828182, 57 min). Séquence : une rangée reçoit deux sections coup sur coup (la seconde en attente), la première est
  refusée au plan (eau posée sur son emprise) ; ses cellules et celles de la seconde sont rendues. Attendu : pas de plantage, la seconde section est annulée (ou refusée proprement), la rangée n'a plus de cellule.
  Lancement : py -3.9 -B <banc.py> --out <archive> --qui mall -- 900 mall-refus <source>
]]

local TAG = "FO-MALL-REFUS"
local SECT = { x0 = 20, y0 = -48, x1 = 84, y1 = 16, dir = 2, ext = 0 }
local KIT = { machine = "assembling-machine-2", bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", poteau = "small-electric-pole", coffre = "iron-chest" }

local function demandes(n)
  return { { item = "iron-gear-wheel", recipe = "iron-gear-wheel", machine = KIT.machine, machines = n, solides = { "iron-plate" }, rate = 30 } }
end

local function report(ctx) return ctx.remote("fo-mall", "report", "player") end

return {
  description = "MALL : section precedente refusee pendant un allongement (plantage cell nil)",
  base = nil,
  check_tick = 800,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    s.request_to_generate_chunks({ 40, 0 }, 7)
    s.force_generate_chunk_requests()
    local tiles = {}
    for y = -60, 30 do for x = 0, 100 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
    s.set_tiles(tiles, true)
    for _, e in ipairs(s.find_entities_filtered({ area = { { 0, -60 }, { 100, 30 } }, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
      if e.valid then e.destroy() end
    end
    for _, r in ipairs({ "assembling-machine-2", "long-handed-inserter", "inserter", "transport-belt", "iron-chest", "iron-gear-wheel" }) do game.forces.player.recipes[r].enabled = true end
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "sect", SECT) ~= nil, "secteur impose")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "force_pret", true) == true, "etat S force (banc)")
    ctx.check(ctx.remote("fo-mall", "set_param", "player", "sans_raccord", true) == true, "sans raccord (banc)")
    st.t0 = game.tick
    st.phase = "offre"
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    if st.phase == "offre" and t >= 60 then
      local id1 = ctx.remote("fo-mall", "offre", "player", demandes(2), KIT)
      local id2 = ctx.remote("fo-mall", "offre", "player", demandes(4), KIT)
      ctx.check(id1 ~= nil and id2 ~= nil and id1 ~= id2, "deux sections demandees coup sur coup", tostring(id1) .. " / " .. tostring(id2))
      st.id1, st.id2 = id1, id2
      local rep = report(ctx)
      local x, y = rep.rep.ox + 1, rep.rep.oy + 3 -- une tuile de la première cellule
      ctx.surface().set_tiles({ { name = "water", position = { x, y } } }, true)
      st.phase = "suivi"
    end
    if t % 60 ~= 0 or st.phase ~= "suivi" then return end
    ctx.remote("fo-mall", "minute", "player", {}, {}, e.tick)
    if t % 120 == 0 then
      local rep = report(ctx)
      local r = rep and rep.rows and rep.rows[1]
      local parts = {}
      for _, q in ipairs(r and r.projects or {}) do parts[#parts + 1] = string.format("%d[%d-%d]:%s(%s)", q.id, q.from, q.to, tostring(q.state), tostring(q.reason)) end
      ctx.log(string.format("[%s] t=%d cellules=%s arret=%s projets %s", TAG, t, tostring(r and r.cells), tostring(r and r.stop), table.concat(parts, " ")))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local rep = report(ctx)
    local r = rep and rep.rows and rep.rows[1]
    ctx.check(r ~= nil, "la rangee existe")
    if not r then return end
    ctx.check(r.cells == 0, "toutes les cellules sont rendues", tostring(r.cells))
    local p1, p2
    for _, q in ipairs(r.projects) do
      if q.id == st.id1 then p1 = q end
      if q.id == st.id2 then p2 = q end
    end
    ctx.check(p1 ~= nil and p1.state == "refuse" and tostring(p1.reason):find("eau", 1, true) ~= nil, "la premiere section est refusee sur l'eau", tostring(p1 and p1.reason))
    ctx.check(p2 ~= nil and p2.state == "refuse", "la seconde section est refusee ou annulee", tostring(p2 and p2.state) .. " : " .. tostring(p2 and p2.reason))
    ctx.log(string.format("[%s] BILAN-FAITS : cellules %d ; section 1 %s (%s) ; section 2 %s (%s)", TAG, r.cells, tostring(p1 and p1.state), tostring(p1 and p1.reason), tostring(p2 and p2.state), tostring(p2 and p2.reason)))
  end,
}
