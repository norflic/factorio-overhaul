-- Scénario greffé du lot BITERS-JEU (3/11) : chaque NOUVEAU biter en jeu (souches du lot BI-V1) apparaît, marche, attaque, meurt et laisse
-- son corps, sans erreur. 12 moucherons (essaim, paliers 1 à 12) et 4 écraseurs (paliers 6, 8, 10, 12), un couloir chacun, une tourelle
-- sans munitions au bout. Plus : tables de ponte des nids (écraseur rare dans le nid de déchiqueteurs dès 0,78 ; nid d'essaim) et coup de
-- zone de l'écraseur (un mur, et derrière lui une tourelle à moins de 3 tuiles).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui BITERSJEU -- 1100 biters-banc <source>
-- Le nid de déchiqueteurs vanilla est `biter-spawner` ; celui de l'essaim, `fo-swarm-nest` (E.nest_name).
local X0, Y0 = 4600, 3200
local TN = { "small", "medium", "big", "behemoth", "colossal", "titan", "apex", "primordial", "ancestral", "abyssal", "cataclysmic", "eternal" }
local ECR = { 6, 8, 10, 12 }
local PV_ECR = { [6] = 72000, [8] = 450000, [10] = 2160000, [12] = 9900000 }   -- PLAN §5 ter (palier × 3, 3 000 PV au palier 4)
local LONG = 14                       -- tuiles entre l'unité et sa cible
local T_MARCHE, T_MORT, T_CORPS, TICK = 240, 800, 860, 1000

local function couloirs()
  local L = {}
  for p = 1, 12 do L[#L + 1] = { nom = "fo-swarm-" .. TN[p] .. "-biter", y = Y0 + (p - 1) * 6 } end
  for i, p in ipairs(ECR) do L[#L + 1] = { nom = "fo-crusher-" .. TN[p] .. "-biter", y = Y0 + 72 + (i - 1) * 16, palier = p } end
  return L
end

local function points(proto)
  local out = {}
  for _, r in ipairs(proto.result_units or {}) do out[r.unit] = r.spawn_points end
  return out
end

return {
  description = "BITERS-JEU : moucherons et ecraseurs apparaissent, marchent, attaquent, meurent ; tables de ponte ; coup de zone",
  base = nil,
  check_tick = TICK,

  init = function(ctx)
    local s, st = ctx.surface(), ctx.state()
    local P = game.entity_prototypes
    ctx.prepare_area(X0 - 8, Y0 - 8, X0 + 40, Y0 + 150, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 120, Y0 - 120 }, { X0 + 160, Y0 + 270 } } })) do en.destroy() end
    game.forces.enemy.set_cease_fire("player", false)
    game.forces.player.set_cease_fire("enemy", false)

    -- Prototypes et chiffres
    local manque = {}
    for _, c in ipairs(couloirs()) do if not P[c.nom] or not P[c.nom .. "-corpse"] then manque[#manque + 1] = c.nom end end
    ctx.check(#manque == 0, "16 nouveaux biters et leurs corps existent", table.concat(manque, " "))
    local pv_faux = {}
    for _, p in ipairs(ECR) do
      local pr = P["fo-crusher-" .. TN[p] .. "-biter"]
      if not pr or math.abs(pr.max_health - PV_ECR[p]) > 1 then pv_faux[#pv_faux + 1] = p .. "=" .. tostring(pr and pr.max_health) end
    end
    ctx.check(#pv_faux == 0, "PV des ecraseurs : 72 k, 450 k, 2,16 M, 9,9 M", table.concat(pv_faux, " "))

    -- Tables de ponte
    local nid = points(P["biter-spawner"])
    local rares, tot = 0, 0
    for _, p in ipairs(ECR) do
      local sp = nid["fo-crusher-" .. TN[p] .. "-biter"]
      if sp then
        tot = tot + 1
        local ok = true
        for _, pt in ipairs(sp) do
          if pt.weight > 0.05 + 1e-6 or (pt.weight > 0 and pt.evolution_factor < 0.78 - 1e-6) then ok = false end
        end
        if ok then rares = rares + 1 end
      end
    end
    ctx.check(tot == 4 and rares == 4, "le nid de dechiqueteurs pond les 4 ecraseurs, rares (poids <= 0,05) et des 0,78", rares .. "/" .. tot)
    local essaim = P["fo-swarm-nest"] and points(P["fo-swarm-nest"]) or {}
    local n_essaim = 0
    for p = 1, 12 do if essaim["fo-swarm-" .. TN[p] .. "-biter"] then n_essaim = n_essaim + 1 end end
    ctx.check(n_essaim == 12, "le nid d'essaim pond les 12 moucherons", n_essaim)

    -- Couloirs : unité à l'ouest, tourelle sans munitions à l'est
    st.c = {}
    for _, c in ipairs(couloirs()) do
      local cible = s.create_entity({ name = "gun-turret", position = { X0 + LONG + 1, c.y }, force = "player" })
      local u = s.create_entity({ name = c.nom, position = { X0, c.y + 0.5 }, force = "enemy" })
      if u and cible then
        u.set_command({ type = defines.command.attack, target = cible, distraction = defines.distraction.none })
      end
      st.c[#st.c + 1] = { nom = c.nom, u = u, cible = cible, x0 = u and u.position.x, pv0 = cible and cible.health, pos = u and u.position }
    end
    local poses = 0
    for _, c in ipairs(st.c) do if c.u and c.cible then poses = poses + 1 end end
    ctx.check(poses == 16, "16 biters poses face a leur cible", poses)

    -- Arène du coup de zone : écraseur titan contre un mur, tourelle à 2,5 tuiles derrière
    local ax, ay = X0 + 30, Y0 + 140
    st.murs = {}
    for dy = -4, 4 do st.murs[#st.murs + 1] = s.create_entity({ name = "stone-wall", position = { ax + 0.5, ay + dy + 0.5 }, force = "player" }) end
    st.derriere = s.create_entity({ name = "gun-turret", position = { ax + 3, ay }, force = "player" })
    st.brute = s.create_entity({ name = "fo-crusher-titan-biter", position = { ax - 9, ay + 0.5 }, force = "enemy" })
    if st.brute then st.brute.set_command({ type = defines.command.attack, target = st.murs[5], distraction = defines.distraction.none }) end
    st.pv_derriere = st.derriere and st.derriere.health
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == T_MARCHE then
      local ko = {}
      for _, c in ipairs(st.c) do
        local d = (c.u and c.u.valid) and (c.u.position.x - c.x0) or -1
        c.marche = d
        if d < 2 then ko[#ko + 1] = c.nom .. "=" .. string.format("%.1f", d) end
      end
      ctx.check(#ko == 0, "chaque biter a marche vers sa cible (>= 2 tuiles au tick " .. T_MARCHE .. ")", table.concat(ko, " "))
    elseif e.tick == T_MORT then
      local ko = {}
      for _, c in ipairs(st.c) do
        local touche = c.cible and ((not c.cible.valid) or c.cible.health < c.pv0)
        if not touche then ko[#ko + 1] = c.nom end
      end
      ctx.check(#ko == 0, "chaque biter a blesse sa cible", table.concat(ko, " "))
      local vivants, morts = 0, 0
      for _, c in ipairs(st.c) do
        if c.u and c.u.valid then
          vivants = vivants + 1
          c.pos = c.u.position
          c.u.die()
          if not c.u.valid then morts = morts + 1 end
        end
      end
      ctx.check(vivants == 16 and morts == 16, "16 biters vivants au tick " .. T_MORT .. ", tous morts par die()", vivants .. " / " .. morts)
    elseif e.tick == T_CORPS then
      local s, ko = ctx.surface(), {}
      for _, c in ipairs(st.c) do
        local n = c.pos and s.count_entities_filtered({ name = c.nom .. "-corpse", position = c.pos, radius = 4 }) or 0
        if n < 1 then ko[#ko + 1] = c.nom end
      end
      ctx.check(#ko == 0, "chaque biter mort laisse son corps", table.concat(ko, " "))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local casses = 0
    for _, m in ipairs(st.murs) do if not m.valid then casses = casses + 1 end end
    ctx.check(casses >= 2, "l'ecraseur casse plusieurs murs d'un coup", casses)
    local pv = st.derriere and st.derriere.valid and st.derriere.health or 0
    ctx.check(st.pv_derriere and pv < st.pv_derriere, "le coup de zone touche la tourelle derriere le mur", pv .. " / " .. tostring(st.pv_derriere))
  end,
}
