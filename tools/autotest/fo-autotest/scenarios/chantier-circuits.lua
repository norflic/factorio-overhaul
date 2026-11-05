--[[
  Lot AGEBLOCAGE, étage « circuits des chantiers » (règle de méthode du 5/11 : le défaut reproduit en moins de 5 000 ticks AVANT tout
  banc long). Une faction à 4 ouvriers (réglage fo-war-workers, celui du guide) reçoit au coffre du fer, du cuivre, des engrenages,
  des tapis, des poteaux et des coffres, mais AUCUN circuit, AUCUN bras et AUCUN assembleur. Au tick 600, une rangée d'engrenages est
  demandée par le chemin des ordres « chaîne » de la capitalisation (fo-ind, row) : le chantier attend en réserve:matériaux des objets
  qui exigent des circuits (assembleurs, bras), alors que fer et cuivre sont libres au coffre.
  Contrôles (finish) :
    1. le chantier a été demandé ;
    2. des circuits sont fabriqués : le chantier ne manque plus d'objet à circuits au tick final, ou il a quitté la réserve ;
    3. le chantier a quitté « reserve » avant le tick final (CHECK_TICK, soit 4 800 ticks, 80 s de jeu).
  Journal : [FO-CHANTIER-CIRCUITS] (ce banc) ; côté mod : [FO-BRAS], [FO-IA1D], [FO-BLOQUE].
  Lancement (par la file) : banc.py --out <archive> --qui AGEBLOCAGE -- 5000 chantier-circuits <source>
]]

local ROW_TICK, CHECK_TICK = 600, 4800

local STOCK = {
  { "iron-plate", 3000 }, { "copper-plate", 3000 }, { "iron-gear-wheel", 400 }, { "coal", 400 }, { "stone", 200 },
  { "stone-brick", 200 }, { "transport-belt", 200 }, { "small-electric-pole", 60 }, { "iron-chest", 30 }, { "wood", 100 },
}

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function newest_project(ctx, key, after)
  local rep = ctx.remote("fo-ia1d", "report", key)
  local best
  for _, p in ipairs((rep and rep.projects) or {}) do
    if (p.created or 0) >= after and (not best or p.id > best.id) then best = p end
  end
  return best
end

local function circuit_parts(missing)
  -- objets qui EXIGENT des circuits (lu dans les recettes du jeu) et le circuit lui-même
  local out = {}
  for _, m in ipairs(missing or {}) do
    local name = m[1]
    local r = game.recipe_prototypes[name]
    local needs = name == "electronic-circuit"
    for _, ing in ipairs((r and r.ingredients) or {}) do
      if ing.name == "electronic-circuit" then needs = true end
    end
    if needs then out[#out + 1] = name .. " " .. m[2] end
  end
  return out
end

return {
  description = "AGEBLOCAGE etage chantiers : 4 ouvriers, chantier en reserve qui attend des circuits, fer et cuivre libres",
  check_tick = CHECK_TICK,

  init = function(ctx)
    local st = ctx.state()
    st.t = {}
    ctx.check(ctx.call("war_setting", "fo-war-workers", 4) == 4, "reglage fo-war-workers = 4 (plafond du guide)")
    ctx.call("war_setting", "fo-war-industrie", true)
    ctx.call("war_setting", "fo-war-ia3e", true)
    ctx.call("war_setting", "fo-war-capi", true)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
    ctx.check(ok == true, "difficulte Paisible", tostring(ok))
    ctx.check(ctx.call("war_start", 2, 0, 4) == true, "guerre lancee : 2 factions, 4 ouvriers")
    local on = remote.interfaces["fo-bras"] and remote.call("fo-bras", "set", true)
    ctx.log("sonde [FO-BRAS] allumee : " .. tostring(on))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 300 then
      local tm = teams(ctx)
      st.key = tm[1] and tm[1].key
      ctx.check(st.key ~= nil, "faction relevee")
      if not st.key then return end
      local force = game.forces["fo-" .. st.key] or game.forces[st.key]
      if force and force.technologies["automation"] then force.technologies["automation"].researched = true end
      local put = ctx.remote("fo-ind", "stock", st.key, STOCK)
      ctx.check(put ~= nil, st.key .. " : fer, cuivre et pieces sans circuit poses au coffre")
    end
    if st.key and e.tick == ROW_TICK then
      local id, info = ctx.remote("fo-ind", "row", st.key, "iron-gear-wheel", 30)
      st.row = id
      ctx.check(id ~= nil, st.key .. " : rangee d'engrenages demandee (" .. tostring(info) .. ")")
      ctx.log("rangee demandee : " .. tostring(info))
    end
    if st.row and e.tick > ROW_TICK and e.tick % 300 == 0 then
      local p = newest_project(ctx, st.key, ROW_TICK - 60)
      if p then
        st.pid = p.id
        st.last = { tick = e.tick, state = p.state, reason = p.reason, built = p.built, total = p.total, circ = circuit_parts(p.missing) }
        if p.state ~= "reserve" and not st.left then st.left = e.tick end
        local miss = {}
        for _, m in ipairs(p.missing or {}) do miss[#miss + 1] = m[1] .. " " .. m[2] end
        ctx.log(string.format("tick %d : projet %d %s (%s) %d/%d ; manque [%s] ; a circuits [%s]", e.tick, p.id, tostring(p.state),
          tostring(p.reason), p.built or 0, p.total or 0, table.concat(miss, ", "), table.concat(st.last.circ, ", ")))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.row ~= nil, "le chantier a ete demande")
    local last = st.last or {}
    ctx.check(st.pid ~= nil, "le projet du chantier est releve")
    ctx.check(st.left ~= nil or #(last.circ or {}) == 0,
      "des circuits sont fabriques : plus d'objet a circuits en manque, ou chantier sorti de la reserve (" .. table.concat(last.circ or {}, ", ") .. ")")
    ctx.check(st.left ~= nil, "le chantier quitte « reserve » avant le tick " .. CHECK_TICK .. " (" .. tostring(st.left) .. ")")
  end,
}
