--[[
  Lot IA3-k (B5, C4, C5 escorte) : les SOLDATS entre deux attaques, en moteur réel. Guerre de 2 factions (30 soldats,
  4 ouvriers). Caractère forcé (interface « fo-ia3k ») : Écarlate AGRESSIVE (agressivité 1 400, prudence 800), Azur
  PACIFIQUE (agressivité 700, prudence 1 200).
  Au tick 18 000, pour chaque faction : un petit ver est posé à 30 tuiles de son premier avant-poste, du côté du QG (les
  tournées vers lui deviennent dangereuses : escorte attendue), et un nid avec un petit ver à 110 tuiles du QG, à l'opposé
  de l'avant-poste ; les deux sont MARQUÉS sur la carte de la faction (comme vus par un éclaireur).
  Mesures au tick 108 000 (30 min) : part du temps des soldats « sans ordre » hors repos (B5 : <= 20 %), part des
  patrouilles (C4 : l'agressive patrouille plus), nettoyage lancé par l'agressive et nid détruit, escortes demandées et
  prêtes. Journal : [FO-IA3K-SOLDATS].
]]

local CHECK = 108000
local PLACE = 18000

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

return {
  description = "IA3-k B5, C4 : soldats occupes, patrouille selon le caractere, escorte, nettoyage",
  check_tick = CHECK,

  init = function(ctx)
    ctx.check(ctx.call("war_setting", "fo-war-ia3-comportement", true) == true, "reglage fo-war-ia3-comportement allume")
    ctx.check(ctx.call("war_start", 2, 30, 4) == true, "guerre lancee : 2 factions, 30 soldats, 4 ouvriers")
    ctx.call("profiler", true)
    ctx.check(ctx.remote("fo-ia3k", "set_character", "scarlet", 800, 1400) == true, "Ecarlate forcee agressive")
    ctx.check(ctx.remote("fo-ia3k", "set_character", "azure", 1200, 700) == true, "Azur forcee pacifique")
    ctx.state().placed = {}
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
    local s = ctx.surface()
    if t == PLACE then
      local poi = ctx.call("points_of_interest")
      for _, f in ipairs(poi.factions or {}) do
        local o = f.outposts[1]
        local rec = { key = f.key, hq = f.hq }
        if o then
          local dx, dy = f.hq.x - o.pos.x, f.hq.y - o.pos.y
          local L = math.sqrt(dx * dx + dy * dy)
          if L > 1 then
            local w = { x = o.pos.x + 30 * dx / L, y = o.pos.y + 30 * dy / L }
            local p = s.find_non_colliding_position("small-worm-turret", w, 10, 0.5)
            if p and s.create_entity({ name = "small-worm-turret", position = p, force = "enemy" }) then
              ctx.remote("fo-ia3k", "mark", f.key, p.x, p.y, "worm", 25)
              rec.worm = { x = p.x, y = p.y }
            end
            local n = { x = f.hq.x + 110 * dx / L, y = f.hq.y + 110 * dy / L }
            local pn = s.find_non_colliding_position("biter-spawner", n, 16, 1)
            if pn and s.create_entity({ name = "biter-spawner", position = pn, force = "enemy" }) then
              ctx.remote("fo-ia3k", "mark", f.key, pn.x, pn.y, "spawner", 30)
              local pw = s.find_non_colliding_position("small-worm-turret", { x = pn.x + 5, y = pn.y + 5 }, 10, 0.5)
              if pw and s.create_entity({ name = "small-worm-turret", position = pw, force = "enemy" }) then
                ctx.remote("fo-ia3k", "mark", f.key, pw.x, pw.y, "worm", 25)
              end
              rec.nest = { x = pn.x, y = pn.y }
            end
          end
        end
        st.placed[#st.placed + 1] = rec
        ctx.log(string.format("%s : ver pres de l'avant-poste %s, nid a 110 tuiles %s", f.key,
          rec.worm and string.format("(%d, %d)", math.floor(rec.worm.x), math.floor(rec.worm.y)) or "NON POSE",
          rec.nest and string.format("(%d, %d)", math.floor(rec.nest.x), math.floor(rec.nest.y)) or "NON POSE"))
      end
    end
    if t % 18000 == 0 and t > 0 then
      for _, key in ipairs({ "scarlet", "azure" }) do
        local v = ctx.remote("fo-ia3k", "status", key)
        local m = v and v.soldiers
        if m then
          local active = m.total - m.rest - (m.far or 0)
          ctx.log(string.format("minute %d %s : passages soldats %d, sans ordre %d (%.1f %% hors repos), repos %d, groupes du chef %d, egares %d, roles %s",
            math.floor(t / 3600), key, m.total, m.idle, active > 0 and 100 * m.idle / active or 0, m.rest, m.group, m.far or 0,
            (function() local o = {} for _, r in ipairs({ "patrol", "guard", "escort", "clear", "defense" }) do o[#o + 1] = r .. "=" .. tostring(m.roles[r] or 0) end return table.concat(o, " ") end)()))
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local res = {}
    for _, key in ipairs({ "scarlet", "azure" }) do
      local v = ctx.remote("fo-ia3k", "status", key)
      local m = v and v.soldiers or { total = 0, idle = 0, rest = 0, group = 0, roles = {} }
      local sv = v and v.stats or {}
      local active = m.total - m.rest - (m.far or 0)
      local pat, gua = m.roles.patrol or 0, m.roles.guard or 0
      res[key] = { idle = active > 0 and m.idle / active or 1, patrol = (pat + gua) > 0 and pat / (pat + gua) or 0,
        clear_ops = sv.clear_ops or 0, cleared = sv.cleared or 0, escort = (sv.gate or {}).escort or 0, ready = sv.escort_ready or 0,
        wait = (sv.gate or {}).wait or 0, labels = sv.labels or {} }
      ctx.log(string.format("FAIT %s : sans ordre %.1f %% du temps hors repos, patrouille %.0f %% (patrouille + garde), nettoyages %d (finis %d), porte escorte %d / attente %d, escortes pretes %d",
        key, 100 * res[key].idle, 100 * res[key].patrol, res[key].clear_ops, res[key].cleared, res[key].escort, res[key].wait, res[key].ready))
    end
    for _, rec in ipairs(st.placed) do
      if rec.nest then
        local n = s.count_entities_filtered({ position = rec.nest, radius = 12, type = "unit-spawner", force = "enemy" })
        rec.nest_left = n
        ctx.log(string.format("FAIT %s : nid a 110 tuiles %s", rec.key, n == 0 and "DETRUIT" or "encore la"))
      end
    end
    ctx.check(res.scarlet.idle <= 0.2 and res.azure.idle <= 0.2, "B5 : soldats sans ordre <= 20 % du temps hors repos (deux factions)",
      string.format("%.1f %% et %.1f %%", 100 * res.scarlet.idle, 100 * res.azure.idle))
    ctx.check(res.scarlet.patrol > res.azure.patrol, "C4 : la faction agressive patrouille plus que la pacifique",
      string.format("%.0f %% contre %.0f %%", 100 * res.scarlet.patrol, 100 * res.azure.patrol))
    ctx.check(res.scarlet.clear_ops >= 1, "C4 : la faction agressive lance un nettoyage du nid proche", res.scarlet.clear_ops)
    local sc_nest = nil
    for _, rec in ipairs(st.placed) do if rec.key == "scarlet" then sc_nest = rec.nest_left end end
    ctx.check(sc_nest == 0, "C4 : le nid proche d'Ecarlate est detruit", tostring(sc_nest))
    ctx.check(res.scarlet.escort + res.azure.escort >= 1 and res.scarlet.ready + res.azure.ready >= 1,
      "C5 : des tournees vers l'avant-poste menace partent escortees (escortes demandees et pretes)",
      string.format("demandees %d, pretes %d", res.scarlet.escort + res.azure.escort, res.scarlet.ready + res.azure.ready))
    local lab = (res.scarlet.labels.patrouille or 0) + (res.scarlet.labels.garde or 0)
    ctx.check(lab > 0, "D1 : etats des soldats affiches (patrouille, garde)", lab)
  end,
}
