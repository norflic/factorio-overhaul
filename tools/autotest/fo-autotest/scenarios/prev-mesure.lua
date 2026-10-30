--[[
  Lot PREVISION-CALIB (30/10) : MESURE en moteur réel de la mécanique des nids que le modèle de la prévision suppose
  (shared/ai3/prevision.lua : Pv.ABS, Pv.PROP « par minute » ? Pv.CYCLES ? cadence des unités envoyées, taille des groupes).
  Banc COURT (7 500 ticks), aucune faction : quatre zones loin de tout, sur de l'herbe, évolution 0.
    A  : un biter-spawner, pollution INJECTÉE dans sa case (300 toutes les 60 ticks : case très polluée) ;
    A' : la même injection, SANS nid (témoin : diffusion et absorption du sol identiques ; A' − A = ce que le nid absorbe) ;
    B  : un spitter-spawner, injection FAIBLE (5 toutes les 600 ticks, soit 30/min) ;
    C  : un biter-spawner sans pollution (témoin : unités de garde nées sans attaque).
  Mesures toutes les 600 ticks : pollution des cases, statistiques de pollution du moteur par nom de nid (absorption), unités
  vues autour de chaque nid (numéros distincts), groupes (numéro, membres au plus). Les temps de rassemblement sont mis à 30 s
  (min = max) pour voir partir les groupes dans la durée du banc. Journal : [FO-PREV-MESURE].
  Lancement : `py -3.9 -B tools/autotest/banc.py --out <archive> --qui PREVISION-CALIB -- 7500 prev-mesure <source>`.
]]

local BX, BY = 3200, 3200
-- Zones à 1 500 tuiles l'une de l'autre ; tout ennemi à moins de CLEAR tuiles est retiré avant la pose (passage 1 : des nids
-- naturels voisins absorbaient le nuage et formaient leurs propres groupes).
local CLEAR = 500
-- Passage 2 (injection de 300 toutes les 60 ticks) : le nuage gagnait des nids naturels hors du rayon nettoyé et leurs
-- groupes marchaient vers le point d'injection. Passage 3 : injections FAIBLES (nuage local, sous min_to_diffuse au voisinage).
local ZONES = {
  { key = "A", dx = 0, nests = { { "biter-spawner", 0, 0 } }, inj = 1, every = 60 },
  { key = "B", dx = 1500, nests = { { "spitter-spawner", 0, 0 } }, inj = 2, every = 60 },
  { key = "C", dx = 3000, nests = { { "biter-spawner", 0, 0 } }, inj = 0, every = 600 },
  { key = "D", dx = 4500, nests = { { "biter-spawner", 0, 0 }, { "biter-spawner", 32, 0 }, { "biter-spawner", 0, 32 },
    { "biter-spawner", 32, 32 } }, inj = 1, every = 60, cells = { { 0, 0 }, { 32, 0 }, { 0, 32 }, { 32, 32 } } },
}
-- Rassemblement fixe (min = max) : un groupe reste ouvert presque tout le banc, pour voir si l'apport d'UN nid à un groupe
-- croît sans fin (débit × temps, ce que suppose le modèle) ou plafonne.
local GATHER = 6000
local T0, T1 = 120, 7200

local function center(z) return BX + z.dx + 16, BY + 16 end

local function stat(name)
  local ps = game.pollution_statistics
  local i = ps.input_counts[name] or 0
  local o = ps.output_counts[name] or 0
  return i, o
end

return {
  description = "PREVISION-CALIB : mesure de l'absorption des nids et des unites envoyees (moteur reel)",
  check_tick = 7300,

  init = function(ctx) end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == 60 then
      game.forces.enemy.evolution_factor = 0
      local ug = game.map_settings.unit_group
      ug.min_group_gathering_time = GATHER
      ug.max_group_gathering_time = GATHER
      st.z = {}
      for _, z in ipairs(ZONES) do
        local x, y = center(z)
        ctx.prepare_area(x - 80, y - 80, x + 80, y + 80, "grass-1")
        for _, en in ipairs(s.find_entities_filtered({ position = { x, y }, radius = CLEAR, force = "enemy" })) do
          if en.valid then en.destroy() end
        end
        local zs = { key = z.key, units = {}, nu = 0, groups = {}, gmax = {}, ingroup = 0, n = 0 }
        for _, nd in ipairs(z.nests) do
          if s.create_entity({ name = nd[1], position = { x + nd[2], y + nd[3] }, force = "enemy" }) then zs.n = zs.n + 1 end
        end
        zs.ok = zs.n == #z.nests
        st.z[z.key] = zs
      end
      local p = game.entity_prototypes["biter-spawner"]
      local cd = p and p.spawn_cooldown
      local ms = game.map_settings.pollution
      ctx.log(string.format("prototype biter-spawner : spawn_cooldown min %s max %s, possedees %s ; pollution : diffusion %s, min_to_diffuse %s, ageing %s, consommation %s",
        tostring(cd and cd.min), tostring(cd and cd.max), tostring(p and p.max_count_of_owned_units), tostring(ms.diffusion_ratio),
        tostring(ms.min_to_diffuse), tostring(ms.ageing), tostring(ms.enemy_attack_pollution_consumption_modifier)))
      st.i0 = {}
      for _, n in ipairs({ "biter-spawner", "spitter-spawner" }) do
        local i, o = stat(n)
        st.i0[n] = { i, o }
      end
    end
    if not st.z then return end
    if e.tick >= T0 and e.tick <= T1 then
      for _, z in ipairs(ZONES) do
        if z.inj > 0 and (e.tick - T0) % z.every == 0 then
          local x, y = center(z)
          for _, c in ipairs(z.cells or { { 0, 0 } }) do s.pollute({ x + c[1], y + c[2] }, z.inj) end
        end
      end
    end
    if e.tick % 60 == 0 and e.tick > 60 then
      for _, z in ipairs(ZONES) do
        local zs = st.z[z.key]
        local x, y = center(z)
        local ing = 0
        for _, u in ipairs(s.find_entities_filtered({ position = { x, y }, radius = 120, type = "unit" })) do
          if u.valid then
            local id = u.unit_number
            if id and not zs.units[id] then zs.units[id] = true; zs.nu = zs.nu + 1 end
            local g = u.unit_group
            if g and g.valid then
              ing = ing + 1
              local gn = g.group_number
              local m = #g.members
              if not zs.gmax[gn] then zs.groups[#zs.groups + 1] = gn end
              if (zs.gmax[gn] or 0) < m then zs.gmax[gn] = m end
            end
          end
        end
        if ing > zs.ingroup then zs.ingroup = ing end
      end
    end
    if e.tick % 600 == 0 and e.tick > 60 then
      local parts = {}
      for _, z in ipairs(ZONES) do
        local zs = st.z[z.key]
        local x, y = center(z)
        local gs = {}
        for _, gn in ipairs(zs.groups) do gs[#gs + 1] = gn .. ":" .. zs.gmax[gn] end
        parts[#parts + 1] = string.format("%s c=%.1f unites=%d groupes[%s]", z.key, s.get_pollution({ x, y }), zs.nu, table.concat(gs, ","))
      end
      local bi, bo = stat("biter-spawner")
      local si, so = stat("spitter-spawner")
      local tot_in, tot_out = 0, 0
      for _, v in pairs(game.pollution_statistics.input_counts) do tot_in = tot_in + v end
      for _, v in pairs(game.pollution_statistics.output_counts) do tot_out = tot_out + v end
      ctx.log(string.format("tick %d | %s | stats biter-spawner in %.1f out %.1f ; spitter-spawner in %.1f out %.1f ; total in %.1f out %.1f",
        e.tick, table.concat(parts, " | "), bi - st.i0["biter-spawner"][1], bo - st.i0["biter-spawner"][2],
        si - st.i0["spitter-spawner"][1], so - st.i0["spitter-spawner"][2], tot_in, tot_out))
      if e.tick == 3600 or e.tick == 7200 then
        local names = {}
        for n, v in pairs(game.pollution_statistics.output_counts) do names[#names + 1] = n .. "=" .. string.format("%.1f", v) end
        table.sort(names)
        ctx.log("sorties de pollution par nom : " .. table.concat(names, " ; "))
        names = {}
        for n, v in pairs(game.pollution_statistics.input_counts) do names[#names + 1] = n .. "=" .. string.format("%.1f", v) end
        table.sort(names)
        ctx.log("entrees de pollution par nom : " .. table.concat(names, " ; "))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local ok = st.z and st.z.A.ok and st.z.B.ok and st.z.C.ok and st.z.D.ok
    ctx.check(ok, "nids poses dans les zones A, B, C, D")
    if not ok then return end
    local s = ctx.surface()
    local bi, bo = stat("biter-spawner")
    local si, so = stat("spitter-spawner")
    ctx.check(true, "mesure faite (chiffres au journal, lus par le rapport)",
      string.format("biter-spawner in %.1f out %.1f, spitter-spawner in %.1f out %.1f ; unites A %d B %d C %d D %d ; dans un groupe au plus A %d B %d C %d D %d",
        bi - st.i0["biter-spawner"][1], bo - st.i0["biter-spawner"][2], si - st.i0["spitter-spawner"][1], so - st.i0["spitter-spawner"][2],
        st.z.A.nu, st.z.B.nu, st.z.C.nu, st.z.D.nu, st.z.A.ingroup, st.z.B.ingroup, st.z.C.ingroup, st.z.D.ingroup))
  end,
}
