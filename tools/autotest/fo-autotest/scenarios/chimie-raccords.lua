-- Scénario greffé du lot DA-CHIMIE (4/11) : les 4 MACHINES DE CHIMIE à fluides (vapocraqueur, reformeur, électrolyseur,
-- colonne d'extraction) dans leurs 4 DIRECTIONS, EN MARCHE, avec un VRAI tuyau posé sur CHAQUE boîte de fluide (nord compris).
--   & "<racine>\fo-autotest.bat" nopause 400 chimie-raccords "<source>"     (contrôles, sans images)
--   py -3.9 -B tools/autotest/banc.py --captures --qui DA-CHIMIE -- 400 chimie-raccords "<source>"   (captures)
-- Grille : une rangée par machine, une colonne par direction (nord, est, sud, ouest), recette à fluides posée à la création
-- (un assembleur sans recette ignore la direction, F91), fluides et objets d'entrée insérés par script, alimentation
-- invisible du mod de test : les machines TRAVAILLENT (lueur, lumière, halo du vapocraqueur).
-- Contrôles : raccords du moteur (get_pipe_connections) = positions des boîtes du prototype tournées dans le sens horaire
-- (celles des brides rendues : tools/render/pieces/chimie/repere.py) ; un tuyau posé et RACCORDÉ à chaque boîte ; machines en
-- marche au tick 300. Captures : chaque rangée au zoom 2 de jour et de nuit, la grille au zoom 1 de jour et de nuit.
-- Table : fo-shots/chimie-raccords-sites.tsv.

local X0, Y0 = 3200, 3000
local PAS_X, PAS_Y = 7, 10

local MACHINES = {
  { nom = "fo-steam-cracker", court = "craqueur", recette = "fo-steam-cracking", objets = {} },
  { nom = "fo-reformer", court = "reformeur", recette = "fo-methane-reforming", objets = {} },
  { nom = "fo-electrolyzer", court = "electrolyseur", recette = "fo-water-electrolysis", objets = {} },
  { nom = "fo-extraction-column", court = "colonne", recette = "fo-solvent-extraction",
    objets = { { name = "fo-rare-earth-concentrate", count = 200 } } },
}
local DIRS = {
  { "nord", defines.direction.north, 0 }, { "est", defines.direction.east, 1 },
  { "sud", defines.direction.south, 2 }, { "ouest", defines.direction.west, 3 },
}

--- Position (relative) d'un raccord du prototype « nord » tournée de q quarts de tour horaires.
local function tourne(x, y, q)
  for _ = 1, q do x, y = -y, x end
  return x, y
end

return {
  description = "DA-CHIMIE : 4 machines de chimie x 4 directions en marche, un vrai tuyau a chaque boite de fluide",
  base = nil,
  check_tick = 300,
  shots_delay = 330,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    ctx.prepare_area(X0 - 10, Y0 - 12, X0 + 4 * PAS_X + 6, Y0 + 4 * PAS_Y + 6, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 150, Y0 - 150 }, { X0 + 200, Y0 + 200 } } })) do
      en.destroy()
    end
    local src = ctx.power(X0 + 12, Y0 + 20)
    ctx.check(src ~= nil, "alimentation invisible du mod de test", src and "posee" or "prototypes absents")
    local ok_pos, ok_tuy, detail = 0, 0, {}
    for j, mc in ipairs(MACHINES) do
      game.forces.player.recipes[mc.recette].enabled = true
      -- raccords du prototype (orientation nord) : positions de référence
      local ref = {}
      for _, fbp in ipairs(game.entity_prototypes[mc.nom].fluidbox_prototypes) do
        for _, pc in ipairs(fbp.pipe_connections) do
          local q = pc.positions[1]
          ref[#ref + 1] = { x = q.x, y = q.y, kind = fbp.production_type }
        end
      end
      for i, d in ipairs(DIRS) do
        local px, py = X0 + (i - 1) * PAS_X + 0.5, Y0 + (j - 1) * PAS_Y + 0.5
        local m = s.create_entity({ name = mc.nom, position = { px, py }, direction = d[2], force = "player",
          recipe = mc.recette })
        local site = { mc = mc, dir = d[1], m = m, x = px, y = py, tuyaux = {}, conn = {}, entrees = {}, sorties = {},
          tuyaux_sortie = {} }
        st.sites[#st.sites + 1] = site
        if m then
          for _, it in ipairs(mc.objets) do m.insert(it) end
          -- fluides d'entrée : plein de chaque boîte d'entrée de la recette
          local rec = game.recipe_prototypes[mc.recette]
          local fl = {}
          for _, ing in ipairs(rec.ingredients) do
            if ing.type == "fluid" then fl[#fl + 1] = ing.name end
          end
          local k = 0
          for b = 1, #m.fluidbox do
            local proto = m.fluidbox.get_prototype(b)
            if proto.production_type == "input" then
              k = k + 1
              if fl[k] then
                m.fluidbox[b] = { name = fl[k], amount = 900 }
                site.entrees[#site.entrees + 1] = { b, fl[k] }
              end
            else
              site.sorties[#site.sorties + 1] = b
            end
            for _, pc in ipairs(m.fluidbox.get_pipe_connections(b)) do
              local t = s.create_entity({ name = "pipe", position = pc.target_position, force = "player" })
              if t then
                site.tuyaux[#site.tuyaux + 1] = t
                if proto.production_type ~= "input" then site.tuyaux_sortie[#site.tuyaux_sortie + 1] = t end
              end
              site.conn[#site.conn + 1] = { x = pc.target_position.x - px, y = pc.target_position.y - py }
            end
          end
          -- positions attendues : prototype tourné de d[3] quarts de tour
          local trouve = 0
          for _, r in ipairs(ref) do
            local ex, ey = tourne(r.x, r.y, d[3])
            for _, c in ipairs(site.conn) do
              if math.abs(c.x - ex) < 0.01 and math.abs(c.y - ey) < 0.01 then trouve = trouve + 1 break end
            end
          end
          if trouve == #ref and #site.conn == #ref then ok_pos = ok_pos + 1 end
          -- chaque tuyau posé est raccordé (le moteur voit la boîte de la machine au bout)
          local relie = 0
          for b = 1, #m.fluidbox do
            for _, pc in ipairs(m.fluidbox.get_pipe_connections(b)) do
              if pc.target then relie = relie + 1 end
            end
          end
          if relie == #ref and #site.tuyaux == #ref then ok_tuy = ok_tuy + 1 end
          detail[#detail + 1] = string.format("%s %s : %d/%d raccords a leur place, %d/%d tuyaux relies", mc.court, d[1],
            trouve, #ref, relie, #ref)
        else
          detail[#detail + 1] = mc.court .. " " .. d[1] .. " : non posee"
        end
      end
    end
    ctx.check(ok_pos == 16, "raccords du moteur = boites du prototype tournees (brides rendues)", ok_pos .. " / 16 ; "
      .. table.concat(detail, " ; "))
    ctx.check(ok_tuy == 16, "un vrai tuyau relie a chaque boite de fluide, 4 directions", ok_tuy .. " / 16")
  end,

  -- Un script ne remplit pas une entrée au-delà de sa limite d'insertion (F221 : environ 2 fabrications) : les entrées sont
  -- remplies et les sorties (boîtes et tuyaux) vidées toutes les 30 ticks, pour que les machines TRAVAILLENT aux captures.
  tick = function(ctx, e)
    if e.tick % 30 ~= 0 then return end
    for _, c in ipairs(ctx.state().sites or {}) do
      local m = c.m
      if m and m.valid then
        for _, en in ipairs(c.entrees) do m.fluidbox[en[1]] = { name = en[2], amount = 900 } end
        for _, b in ipairs(c.sorties) do m.fluidbox[b] = nil end
        for _, t in ipairs(c.tuyaux_sortie) do
          if t.valid then t.fluidbox[1] = nil end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local marche, ko = 0, {}
    -- noms des statuts (liste triée : aucun ordre de pairs)
    local noms_statut = {}
    local cles = {}
    for k in pairs(defines.entity_status) do cles[#cles + 1] = k end
    table.sort(cles)
    for _, k in ipairs(cles) do noms_statut[defines.entity_status[k]] = k end
    local function boites(m)
      local t = {}
      for b = 1, #m.fluidbox do
        local f = m.fluidbox[b]
        t[#t + 1] = f and string.format("%s %.0f", f.name, f.amount) or "vide"
      end
      return table.concat(t, ", ")
    end
    for _, c in ipairs(st.sites) do
      if c.m and c.m.valid and c.m.status == defines.entity_status.working then
        marche = marche + 1
      else
        ko[#ko + 1] = c.mc.court .. " " .. c.dir .. (c.m and c.m.valid and (" (" .. tostring(noms_statut[c.m.status] or c.m.status)
          .. " ; " .. boites(c.m) .. ")") or "")
      end
    end
    ctx.check(marche == 16, "machines en marche au tick 300", marche .. " / 16" ..
      (#ko > 0 and (" ; a l'arret : " .. table.concat(ko, ", ")) or ""))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tmachine\tnuit\tzoom\tx\ty" }
    for j, mc in ipairs(MACHINES) do
      local cx = X0 + 1.5 * PAS_X + 0.5
      local cy = Y0 + (j - 1) * PAS_Y + 0.5 - 1.5
      for _, nuit in ipairs({ false, true }) do
        local nm = string.format("%s-z2-%s", mc.court, nuit and "nuit" or "jour")
        add(nm, cx, cy, 2, nuit and 0.5 or 0, { res = { math.ceil((4 * PAS_X + 1) * 64), math.ceil(9.5 * 64) },
          info = false, aa = true })
        L[#L + 1] = string.format("%s\t%s\t%d\t2\t%.2f\t%.2f", nm, mc.court, nuit and 1 or 0, cx, cy)
      end
    end
    local cx, cy = X0 + 1.5 * PAS_X + 0.5, Y0 + 1.5 * PAS_Y - 1
    for _, nuit in ipairs({ false, true }) do
      local nm = string.format("grille-z1-%s", nuit and "nuit" or "jour")
      add(nm, cx, cy, 1, nuit and 0.5 or 0, { res = { math.ceil((4 * PAS_X + 2) * 32), math.ceil((4 * PAS_Y + 6) * 32) },
        info = false, aa = true })
      L[#L + 1] = string.format("%s\ttoutes\t%d\t1\t%.2f\t%.2f", nm, nuit and 1 or 0, cx, cy)
    end
    game.write_file("fo-shots/chimie-raccords-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
