--[[
  Lot TV-PLACE : micro-banc en moteur réel (2 500 ticks) des quatre points « sonde et place » du plan directeur des équipes de PNJ
  (docs/TODO_VIDEO.md G37, G38, C07 ; G57 a son banc hors jeu, tests/sites10_test.lua, sur surface fictive).
  Deux variantes qui ne diffèrent que par les quatre réglages : tv-place (allumés, défaut) et tv-place-temoin (éteints : le plan d'avant).

  Terrain : un carré de 280 x 280 tuiles autour de l'origine, vidé puis posé en herbe. Un disque de fer (rayon 5) centré en (71, 0) : le lot
  (3, 0) [72, 96) porte la majeure partie du fer (gisement), le lot (2, 0) [44, 68) n'en a que 8 tuiles mais la sonde de 30 x 30 [41, 71) en
  voit 35 : lot en BORD de gisement (G37). Des arbres tous les 5 tuiles sur x dans [-53, -14), y dans [-53, 53) : les lots (-1, j) sont « à
  défricher » (G38). Coffre d'équipe VIDE (aucune matière : les projets restent planifiés en « reserve », les PNJ sont libres de couper).
  Deux demandes à t = 300 : R1 = engrenages (4 x 7, « fabrique ») avec `near` = centre du lot (2, 0), R2 = engrenages à 6 ensembles (23 x 7 : tient
  dans un lot de 24 avec une marge de 0, pas avec une marge de 1 : C07).
  Attendu (variante allumée) : lot (2, 0) en bord de gisement ; R1 ailleurs que dans (2, 0) ; R2 planifiée par le repli simple ; au moins un lot
  défriché d'avance (4 quarts) puis relevé « libre », ses arbres coupés. Variante témoin : aucun bord, R1 dans (2, 0), R2 sans place, aucun
  défrichage préventif.
  Lancement : banc.py ... -- 2500 tv-place <source> ; journal : [FO-TV-PLACE] / [FO-TV-PLACE-TEMOIN].
]]

local HALF = 140
local T_REQUEST = 300
local CHECK = 2400
local SETTINGS = { "fo-war-sonde-30", "fo-war-sites-10", "fo-war-defrichage-prev", "fo-war-place-simple" }
local TREES = { "tree-01", "tree-02", "tree-03", "tree-04", "tree-05", "tree-06", "tree-07", "tree-08", "tree-09" }

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

local function shape(ctx)
  local s = ctx.surface()
  local c = { x = 0, y = 0 }
  s.request_to_generate_chunks({ c.x, c.y }, 6)
  s.force_generate_chunk_requests()
  local area = { { c.x - HALF, c.y - HALF }, { c.x + HALF, c.y + HALF } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = c.y - HALF, c.y + HALF - 1 do for x = c.x - HALF, c.x + HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
  -- disque de fer, rayon 5, centré en (71, 0)
  for dy = -5, 5 do
    for dx = -5, 5 do
      if dx * dx + dy * dy <= 25 then s.create_entity({ name = "iron-ore", position = { 71 + dx + 0.5, dy + 0.5 }, amount = 4000 }) end
    end
  end
  local n = 0
  local k = 0
  for x = -53, -15, 5 do
    for y = -53, 52, 5 do
      local name = TREES[(k % #TREES) + 1]
      k = k + 1
      if s.can_place_entity({ name = name, position = { x + 0.5, y + 0.5 } }) and s.create_entity({ name = name, position = { x + 0.5, y + 0.5 } }) then n = n + 1 end
    end
  end
  return c, n
end

local function trees_in(s, r)
  return s.count_entities_filtered({ area = { { r[1], r[2] }, { r[3], r[4] } }, type = { "tree", "simple-entity" } })
end

return function(on)
  return {
    description = "TV-PLACE : sonde 30 x 30, defrichage preventif 50 x 50, repli de placement simple (" .. (on and "regles allumees" or "temoin, regles eteintes") .. ")",
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      local c, n_trees = shape(ctx)
      st.c, st.trees0 = c, n_trees
      ctx.log("terrain : " .. n_trees .. " arbre(s) poses, disque de fer en (71, 0)")
      ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
      for _, name in ipairs(SETTINGS) do
        if not on then ctx.check(ctx.call("war_setting", name, false) == false, "temoin : " .. name .. " eteint") end
      end
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { c.x + 0.5, c.y + 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose (vide)")
      if not chest then return end
      st.chest = chest
      ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = false, radius = 3 }) == true, "plan directeur active")
      st.t0 = game.tick
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local t = e.tick - st.t0
      if t == T_REQUEST then
        st.r1 = ctx.remote("fo-ia1d", "request", "player", { gen = "gears", args = { 2 }, near = { x = 56, y = 0 } })
        st.r2 = ctx.remote("fo-ia1d", "request", "player", { gen = "gears", args = { 6 } })
        ctx.log(string.format("demandes : R1 (engrenages x2, pres du lot 2:0) %s, R2 (engrenages x6, 23 x 7) %s", tostring(st.r1), tostring(st.r2)))
      end
      if t > 0 and t % 600 == 0 then
        local rep = ctx.remote("fo-ia1d", "place", "player", "report")
        if rep then
          local kv = {}
          for _, k in ipairs(sorted_keys(rep.counters)) do kv[#kv + 1] = k .. "=" .. rep.counters[k] end
          ctx.log(string.format("t=%d | bords [%s] | ouvert %s | finis [%s] | compteurs %s", t, table.concat(rep.edges, " "), tostring(rep.open),
            table.concat(rep.done, " "), table.concat(kv, " ")))
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      ctx.check(st.t0 ~= nil, "banc initialise")
      if not st.t0 then return end
      local rep = ctx.remote("fo-ia1d", "place", "player", "report")
      ctx.check(rep ~= nil, "rapport du lot TV-PLACE")
      if not rep then return end
      local r = ctx.remote("fo-ia1d", "report", "player")
      local lay = ctx.remote("fo-ia1d", "layout", "player")
      local function project(id) for _, p in ipairs(r.projects) do if p.id == id then return p end end return nil end
      local p1, p2 = project(st.r1), project(st.r2)
      local function lot_of(p) return p and p.parts and p.parts[1] and p.parts[1].lot or nil end
      ctx.log(string.format("R1 : etat %s lot %s ; R2 : etat %s lot %s (%s)", tostring(p1 and p1.state), tostring(lot_of(p1)), tostring(p2 and p2.state),
        tostring(lot_of(p2)), tostring(p2 and p2.reason)))
      local edge20 = false
      for _, k in ipairs(rep.edges) do if k == "2:0=iron-ore" then edge20 = true end end
      local c = rep.counters
      if on then
        -- G37
        ctx.check(edge20, "G37 : le lot 2:0 est en bord de gisement (fer) : " .. table.concat(rep.edges, " "))
        ctx.check(#rep.edges == 1, "G37 : un seul lot en bord de gisement (" .. #rep.edges .. ")")
        ctx.check(lot_of(p1) ~= nil and lot_of(p1) ~= "2:0", "G37 : la fabrique R1, demandee pres du lot 2:0, est posee ailleurs (" .. tostring(lot_of(p1)) .. ")")
        -- C07
        ctx.check(lot_of(p2) ~= nil, "C07 : R2 (23 x 7) est planifiee (" .. tostring(lot_of(p2)) .. ")")
        ctx.check((c.simple_ok or 0) >= 1, "C07 : le repli simple a pose R2 (simple_ok=" .. tostring(c.simple_ok) .. ")")
        -- G38
        ctx.check((c.prev_done or 0) >= 1, "G38 : au moins un lot defriche d'avance (prev_done=" .. tostring(c.prev_done) .. ")")
        ctx.check((c.prev_cut or 0) >= 20, "G38 : des arbres coupes par les taches preventives (prev_cut=" .. tostring(c.prev_cut) .. ")")
        local done = rep.done[1]
        local zone_ok, state_ok = false, false
        if done then
          for _, l in ipairs(lay.lots) do
            if (l.i .. ":" .. l.j) == done then
              local z = { l.x0 - 13, l.y0 - 13, l.x1 + 13, l.y1 + 13 }
              local left = trees_in(s, z)
              zone_ok = left <= 3
              state_ok = l.state == "libre" or l.state == "occupe"
              ctx.log(string.format("lot %s defriche d'avance : %d arbre(s) restant(s) dans la zone de 50 x 50, etat %s", done, left, tostring(l.state)))
            end
          end
        end
        ctx.check(zone_ok, "G38 : la zone de 50 x 50 du premier lot defriche est quasi vide d'arbres")
        ctx.check(state_ok, "G38 : le lot defriche d'avance est releve libre (ou deja pris)")
      else
        ctx.check(not edge20 and #rep.edges == 0, "temoin : aucun lot en bord de gisement")
        ctx.check(lot_of(p1) == "2:0", "temoin : R1 est posee dans le lot 2:0 (" .. tostring(lot_of(p1)) .. ")")
        ctx.check((c.simple_ok or 0) == 0 and (c.simple_ko or 0) == 0, "temoin : aucun repli simple")
        ctx.check((c.prev_lots or 0) == 0, "temoin : aucun defrichage preventif")
        ctx.log("temoin : R2 " .. tostring(lot_of(p2) or "sans place"))
      end
    end,
  }
end
