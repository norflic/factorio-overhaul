--[[
  Lot PAVAGE-PREUVE (11/11) : mesure du PAVAGE des gisements par les IA en partie réelle (base "default", la vraie guerre
  à 4 factions), et captures de chaque gisement mesuré en session avec images. Banc de MESURE : rien n'est écrit dans la
  partie, aucune décision de l'IA n'est touchée.

  Usage : scenarios/pavage-photo.lua (T = 30 min), scenarios/pavage-photo-60.lua (T = 60 min) :
    return require("scenarios/pavage_common")(T_MINUTES)
  Mesures aux minutes 10, 20, ... jusqu'à T (journal seulement) ; captures au tick T (session avec images).

  Par équipe (remote fo-ia1 « teams », QG = fo-faction-hq de sa force, sinon fo-team-chest) et par gisement : grappe de
  tuiles de ressource SOLIDE (produit de minage de type item : fer, cuivre, charbon, pierre, ... ; le pétrole est exclu)
  contiguës (8 voisins, même ressource), dont au moins une tuile est à moins de RAYON tuiles du QG. Ligne :
    [FO-PAVAGE-PREUVE] gisement minute=M equipe=K ressource=R n=I tuiles=N centre=x,y boite=x0,y0,x1,y1 tronque=0|1
      foreuses_elec=E foreuses_comb=B foreuses_autres_equipes=O couvertes=C couverture=P% interdites=X
      interdits=nom:n,nom:n tapis_sur=T sortie_tapis=oui|non sortie=x,y fin_chaine=x,y minerai_sortie=Q
      etats=working:a,waiting_for_space_in_destination:b,... capture=pav-K-R-I.png
  Définitions (lues aux prototypes, aucun nom en dur sauf le QG pour trouver l'équipe) :
   - foreuse : type mining-drill de la force de l'équipe ; « sur le gisement » = au moins une tuile du gisement dans sa
     zone de minage (position ± mining_drill_radius, centre de tuile dedans) ; électrique = electric_energy_source_prototype,
     à brûleur = burner_prototype ;
   - couverte : tuile du gisement dans la zone de minage d'au moins une foreuse de l'équipe ; couverture = couvertes / tuiles ;
   - interdite : entité de la force de l'équipe dont le type n'est ni mining-drill, ni electric-pole, ni transport-belt,
     underground-belt, splitter, ni un corps ou un véhicule (character, unit, car, spider-vehicle, matériel roulant),
     ni un fantôme ou une demande d'objets, et dont la boîte de collision touche (intérieur) une tuile du gisement ;
     règle du DC : tolérance 0 ;
   - sortie par tapis : depuis chaque tapis (transport-belt, underground-belt, splitter) de l'équipe posé sur une tuile du
     gisement, on suit les sorties (belt_neighbours.outputs, et la paire d'un souterrain d'entrée) ; « oui » si l'on atteint
     un tapis hors de la boîte du gisement élargie de MARGE tuiles. `sortie` = premier tapis atteint dehors, `fin_chaine` =
     dernier tapis de cette chaîne, `minerai_sortie` = objets sur le premier tapis dehors (les deux voies).
  Lignes « equipe » : QG, nombre de gisements, petites grappes ignorées (< MIN_TILES tuiles). Lignes « capture » : nom,
  centre, zoom. Sans joueur (banc sans images) : mesures seulement.
]]

local RAYON = 200      -- tuiles : gisements à moins de RAYON du QG (au moins une tuile)
local QUERY = 400      -- demi-côté de la zone lue autour du QG (au-delà, le gisement est dit « tronqué »)
local MIN_TILES = 10   -- grappes plus petites : comptées à part, non mesurées
local MARGE = 2        -- tuiles autour de la boîte : un tapis au-delà est « hors du gisement »
local SHOT_W, SHOT_H = 1920, 1080
local SUB_ZOOM = 0.4   -- gros plans quand la vue d'ensemble tombe sous MIN_ZOOM
local MIN_ZOOM = 0.25
local SUB_MAX = 6
local TAG = "[FO-PAVAGE-PREUVE] "

local PASSE = {        -- types tolérés sur le minerai
  ["mining-drill"] = true, ["electric-pole"] = true,
  ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true,
}
local IGNORE = {       -- pas des bâtiments
  character = true, unit = true, car = true, ["spider-vehicle"] = true, locomotive = true, ["cargo-wagon"] = true,
  ["fluid-wagon"] = true, ["artillery-wagon"] = true, ["entity-ghost"] = true, ["tile-ghost"] = true,
  ["item-request-proxy"] = true, corpse = true, ["character-corpse"] = true, projectile = true, explosion = true,
  ["combat-robot"] = true, ["construction-robot"] = true, ["logistic-robot"] = true, ["item-entity"] = true,
  ["flying-text"] = true, ["highlight-box"] = true, smoke = true, fire = true, sticker = true, beam = true,
  stream = true, ["particle-source"] = true, ["speech-bubble"] = true,
}
local BELT = { ["transport-belt"] = true, ["underground-belt"] = true, splitter = true }

local function K(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end

local STATUS
local function status_name(st)
  if not STATUS then
    STATUS = {}
    for k, v in pairs(defines.entity_status) do STATUS[v] = k end
  end
  return STATUS[st] or tostring(st)
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function kv(t)
  local out = {}
  for _, k in ipairs(sorted_keys(t)) do out[#out + 1] = k .. ":" .. t[k] end
  return #out > 0 and table.concat(out, ",") or "-"
end

local function solid(proto)
  local mp = proto.mineable_properties
  if not (mp and mp.minable and mp.products and mp.products[1]) then return false end
  for _, p in ipairs(mp.products) do if p.type == "fluid" then return false end end
  return true
end

local function hq_of(s, force)
  return s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
    or s.find_entities_filtered({ name = "fo-team-chest", force = force, limit = 1 })[1]
end

--- Grappes de ressource solide autour de `c`. Rend { {name, tiles = {k = true}, list = {{x,y}}, x0,y0,x1,y1, tronque}, ... }
--- triées (ressource, puis distance au QG), et le nombre de petites grappes ignorées.
local function clusters(s, c)
  local area = { { c.x - QUERY, c.y - QUERY }, { c.x + QUERY, c.y + QUERY } }
  local by = {}       -- name -> { k -> {x, y} }
  local solid_of = {}
  for _, r in ipairs(s.find_entities_filtered({ area = area, type = "resource" })) do
    local n = r.name
    if solid_of[n] == nil then solid_of[n] = solid(r.prototype) end
    if solid_of[n] then
      local x, y = math.floor(r.position.x), math.floor(r.position.y)
      by[n] = by[n] or {}
      by[n][K(x, y)] = { x, y }
    end
  end
  local qx0, qy0, qx1, qy1 = math.floor(c.x - QUERY), math.floor(c.y - QUERY), math.floor(c.x + QUERY) - 1, math.floor(c.y + QUERY) - 1
  local out, small = {}, 0
  local R2 = RAYON * RAYON
  for _, name in ipairs(sorted_keys(by)) do
    local map, seen = by[name], {}
    local seeds = {}
    for k, p in pairs(map) do
      local dx, dy = p[1] + 0.5 - c.x, p[2] + 0.5 - c.y
      if dx * dx + dy * dy <= R2 then seeds[#seeds + 1] = p end
    end
    table.sort(seeds, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
    for _, sp in ipairs(seeds) do
      local sk = K(sp[1], sp[2])
      if not seen[sk] then
        seen[sk] = true
        local cl = { name = name, tiles = {}, list = {}, x0 = sp[1], y0 = sp[2], x1 = sp[1], y1 = sp[2], tronque = false }
        local stack = { sp }
        while #stack > 0 do
          local p = stack[#stack]; stack[#stack] = nil
          local x, y = p[1], p[2]
          cl.tiles[K(x, y)] = true
          cl.list[#cl.list + 1] = p
          if x < cl.x0 then cl.x0 = x end; if x > cl.x1 then cl.x1 = x end
          if y < cl.y0 then cl.y0 = y end; if y > cl.y1 then cl.y1 = y end
          if x <= qx0 or x >= qx1 or y <= qy0 or y >= qy1 then cl.tronque = true end
          for dx = -1, 1 do
            for dy = -1, 1 do
              local nk = K(x + dx, y + dy)
              if not seen[nk] and map[nk] then seen[nk] = true; stack[#stack + 1] = map[nk] end
            end
          end
        end
        if #cl.list >= MIN_TILES then
          local sx, sy = 0, 0
          for _, p in ipairs(cl.list) do sx, sy = sx + p[1] + 0.5, sy + p[2] + 0.5 end
          cl.cx, cl.cy = sx / #cl.list, sy / #cl.list
          local dx, dy = cl.cx - c.x, cl.cy - c.y
          cl.d2 = dx * dx + dy * dy
          out[#out + 1] = cl
        else
          small = small + 1
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    if a.d2 ~= b.d2 then return a.d2 < b.d2 end
    return a.x0 * 100000 + a.y0 < b.x0 * 100000 + b.y0
  end)
  return out, small
end

local function in_box_tiles(cl, bb)
  -- tuiles dont l'intérieur touche la boîte bb
  local eps = 1 / 256
  local tx0, ty0 = math.floor(bb.left_top.x + eps), math.floor(bb.left_top.y + eps)
  local tx1, ty1 = math.floor(bb.right_bottom.x - eps), math.floor(bb.right_bottom.y - eps)
  for x = tx0, tx1 do
    for y = ty0, ty1 do
      if cl.tiles[K(x, y)] then return true end
    end
  end
  return false
end

local function belt_outputs(b)
  local out = {}
  local ok, nb = pcall(function() return b.belt_neighbours end)
  if ok and nb and nb.outputs then for _, o in ipairs(nb.outputs) do out[#out + 1] = o end end
  if b.type == "underground-belt" and b.belt_to_ground_type == "input" then
    local okn, n = pcall(function() return b.neighbours end)
    if okn and n and n.valid then out[#out + 1] = n end
  end
  return out
end

local function belt_items(b)
  local n = 0
  for i = 1, 2 do
    local ok, line = pcall(b.get_transport_line, i)
    if ok and line then n = n + line.get_item_count() end
  end
  return n
end

--- Mesure d'un gisement pour une force. Rend la table des champs (journal et captures).
local function measure(s, force, cl)
  local m = { elec = 0, comb = 0, autres = 0, couvertes = 0, interdits = {}, n_interdits = 0, tapis_sur = 0,
    sortie = false, etats = {} }
  local R = 12 -- marge de recherche des foreuses (rayon de minage maximal raisonnable)
  local area = { { cl.x0 - R, cl.y0 - R }, { cl.x1 + 1 + R, cl.y1 + 1 + R } }
  local covered = {}
  local drills = s.find_entities_filtered({ area = area, type = "mining-drill" })
  table.sort(drills, function(a, b) return a.unit_number < b.unit_number end)
  for _, d in ipairs(drills) do
    local r = d.prototype.mining_drill_radius or 0
    local px, py = d.position.x, d.position.y
    local hit = {}
    for x = math.floor(px - r - 0.5), math.floor(px + r - 0.5) do
      for y = math.floor(py - r - 0.5), math.floor(py + r - 0.5) do
        if x + 0.5 >= px - r and x + 0.5 <= px + r and y + 0.5 >= py - r and y + 0.5 <= py + r then
          local k = K(x, y)
          if cl.tiles[k] then hit[#hit + 1] = k end
        end
      end
    end
    if #hit > 0 then
      if d.force.name == force then
        local p = d.prototype
        if p.electric_energy_source_prototype then m.elec = m.elec + 1 elseif p.burner_prototype then m.comb = m.comb + 1 end
        for _, k in ipairs(hit) do covered[k] = true end
        local sn = status_name(d.status)
        m.etats[sn] = (m.etats[sn] or 0) + 1
      else
        m.autres = m.autres + 1
      end
    end
  end
  for _ in pairs(covered) do m.couvertes = m.couvertes + 1 end
  -- entités interdites sur le minerai
  local ents = s.find_entities_filtered({ area = { { cl.x0 - 8, cl.y0 - 8 }, { cl.x1 + 9, cl.y1 + 9 } }, force = force })
  local belts_on = {}
  for _, e in ipairs(ents) do
    local t = e.type
    if BELT[t] then
      if cl.tiles[K(math.floor(e.position.x), math.floor(e.position.y))] then belts_on[#belts_on + 1] = e end
    elseif not PASSE[t] and not IGNORE[t] then
      if in_box_tiles(cl, e.bounding_box) then
        m.interdits[e.name] = (m.interdits[e.name] or 0) + 1
        m.n_interdits = m.n_interdits + 1
      end
    end
  end
  m.tapis_sur = #belts_on
  table.sort(belts_on, function(a, b) return a.unit_number < b.unit_number end)
  -- sortie par tapis : on suit les sorties depuis chaque tapis du gisement
  local bx0, by0, bx1, by1 = cl.x0 - MARGE, cl.y0 - MARGE, cl.x1 + 1 + MARGE, cl.y1 + 1 + MARGE
  local function outside(e)
    local p = e.position
    return p.x < bx0 or p.x > bx1 or p.y < by0 or p.y > by1
  end
  local visited = {}
  for _, b0 in ipairs(belts_on) do
    if m.sortie then break end
    if not visited[b0.unit_number] then
      local queue, head = { b0 }, 1
      visited[b0.unit_number] = true
      while head <= #queue and not m.sortie do
        local b = queue[head]; head = head + 1
        for _, o in ipairs(belt_outputs(b)) do
          if o.valid and o.unit_number and not visited[o.unit_number] and BELT[o.type] then
            visited[o.unit_number] = true
            if outside(o) then
              m.sortie = true
              m.sortie_pos = o.position
              m.minerai_sortie = belt_items(o)
              -- fin de la chaîne : on suit la première sortie jusqu'au bout (au plus 4 000 tapis)
              local cur, seen2, steps = o, { [o.unit_number] = true }, 0
              while steps < 4000 do
                local nx
                for _, o2 in ipairs(belt_outputs(cur)) do
                  if o2.valid and o2.unit_number and not seen2[o2.unit_number] and BELT[o2.type] then nx = o2 break end
                end
                if not nx then break end
                seen2[nx.unit_number] = true
                cur, steps = nx, steps + 1
              end
              m.fin_pos = cur.position
              m.fin_long = steps
              break
            end
            queue[#queue + 1] = o
          end
        end
        if #queue > 20000 then break end
      end
    end
  end
  return m
end

local function safe(s) return (tostring(s):gsub("[^%w%-_]", "_")) end

--- Ligne « gisement ». `phase` : « T » (mesure au tick T, et aux minutes 10, 20...) ou « capture » (même gisement re-mesuré au
--- tick même de sa capture, session avec images : les IA construisent pendant les quelques centaines de ticks entre T et la
--- capture ; c'est cette ligne qui décrit l'image).
local function log_gisement(phase, tick, key, cl, n, m, file)
  local tiles = #cl.list
  log(TAG .. string.format("gisement minute=%d phase=%s tick=%d equipe=%s ressource=%s n=%d tuiles=%d centre=%.1f,%.1f distance_qg=%.0f boite=%d,%d,%d,%d tronque=%d"
    .. " foreuses_elec=%d foreuses_comb=%d foreuses_autres_equipes=%d couvertes=%d couverture=%.1f%% interdites=%d interdits=%s"
    .. " tapis_sur=%d sortie_tapis=%s sortie=%s fin_chaine=%s minerai_sortie=%s etats=%s capture=%s",
    math.floor(tick / 3600), phase, tick, key, cl.name, n, tiles, cl.cx, cl.cy, math.sqrt(cl.d2), cl.x0, cl.y0, cl.x1 + 1, cl.y1 + 1, cl.tronque and 1 or 0,
    m.elec, m.comb, m.autres, m.couvertes, 100 * m.couvertes / tiles, m.n_interdits, kv(m.interdits),
    m.tapis_sur, m.sortie and "oui" or "non",
    m.sortie_pos and string.format("%.1f,%.1f", m.sortie_pos.x, m.sortie_pos.y) or "-",
    m.fin_pos and string.format("%.1f,%.1f(%d)", m.fin_pos.x, m.fin_pos.y, m.fin_long or 0) or "-",
    tostring(m.minerai_sortie or "-"), kv(m.etats), file or "-"))
end

-- Gisements photographiés (nom de capture sans .png -> { force, clé, grappe, n }) : hors de `global` (grappes volumineuses) ;
-- rempli au tick T, lu pendant les captures de la même session.
local CACHE = {}

return function(T_MIN)
  local MIN = 3600
  local T = T_MIN * MIN
  local MEASURES = {}
  for m = 10, T_MIN, 10 do MEASURES[#MEASURES + 1] = m * MIN end
  if MEASURES[#MEASURES] ~= T then MEASURES[#MEASURES + 1] = T end
  local IS_MEASURE = {}
  for _, t in ipairs(MEASURES) do IS_MEASURE[t] = true end

  -- Les captures sont mises dans la LISTE du pilote (shots.lua, crochet `shots`) : elles sont prises quelques ticks après
  -- la mesure (T + shots_delay - T, puis une toutes les 10 ticks, jeu à ×1) et le pilote vérifie chaque PNG (code 0).
  -- Fichier : fo-shots/NNN-pav-<équipe>-<ressource>-<n>.png (NNN : rang dans la liste).
  local function shoot(ctx, p, file, x, y, zoom)
    local st = ctx.state()
    st.plan = st.plan or {}
    st.plan[#st.plan + 1] = { name = file:gsub("%.png$", ""), x = x, y = y, zoom = zoom }
    log(TAG .. string.format("capture fichier=%s centre=%.1f,%.1f zoom=%.3f tick_mesure=%d", file, x, y, zoom, game.tick))
  end

  local function run_all(ctx, tick, p)
    local st = ctx.state()
    local s = ctx.surface()
    local minute = tick / MIN
    local rows = remote.call("fo-ia1", "teams") or {}
    local shots = 0
    for _, row in ipairs(rows) do
      local force = row.force
      local hq = force and hq_of(s, force)
      if not hq then
        log(TAG .. string.format("equipe minute=%d equipe=%s force=%s qg=absent", minute, tostring(row.key), tostring(force)))
      else
        local c = hq.position
        local cls, small = clusters(s, c)
        local fc = game.forces[force]
        local nd = s.count_entities_filtered({ force = force, type = "mining-drill" })
        local ntech = 0
        if fc then for _, te in pairs(fc.technologies) do if te.researched then ntech = ntech + 1 end end end
        log(TAG .. string.format("equipe minute=%d equipe=%s force=%s qg=%.1f,%.1f gisements=%d petites_grappes=%d foreuses_equipe=%d tech=%d",
          minute, row.key, force, c.x, c.y, #cls, small, nd, ntech))
        local idx = {}
        for _, cl in ipairs(cls) do
          idx[cl.name] = (idx[cl.name] or 0) + 1
          local n = idx[cl.name]
          local m = measure(s, force, cl)
          local file = string.format("pav-%s-%s-%d.png", safe(row.key), safe(cl.name), n)
          log_gisement("T", tick, row.key, cl, n, m, tick == T and file or nil)
          if tick == T then
            local w, h = cl.x1 + 1 - cl.x0 + 8, cl.y1 + 1 - cl.y0 + 8
            local zoom = math.min(SHOT_W / (w * 32), SHOT_H / (h * 32))
            zoom = math.max(0.08, math.min(1.5, zoom))
            local mx, my = (cl.x0 + cl.x1 + 1) / 2, (cl.y0 + cl.y1 + 1) / 2
            shoot(ctx, p, file, mx, my, zoom)
            CACHE[(file:gsub("%.png$", ""))] = { force = force, key = row.key, cl = cl, n = n }
            shots = shots + 1
            if zoom < MIN_ZOOM then
              local vw, vh = SHOT_W / (32 * SUB_ZOOM), SHOT_H / (32 * SUB_ZOOM)
              local nx, ny = math.ceil(w / vw), math.ceil(h / vh)
              local k = 0
              for j = 1, ny do
                for i = 1, nx do
                  if k < SUB_MAX then
                    k = k + 1
                    local sx = cl.x0 - 4 + (i - 0.5) * (w / nx)
                    local sy = cl.y0 - 4 + (j - 0.5) * (h / ny)
                    shoot(ctx, p, string.format("pav-%s-%s-%d-gros-plan-%d.png", safe(row.key), safe(cl.name), n, k), sx, sy, SUB_ZOOM)
                  end
                end
              end
            end
          end
        end
      end
    end
    st.measured = (st.measured or 0) + 1
    st.last_rows = #rows
  end

  return {
    description = string.format("PAVAGE-PREUVE : pavage des gisements par les IA (guerre default), mesures toutes les 10 min, captures a %d min", T_MIN),
    base = "default",
    check_tick = T + 300,
    shots_delay = T + 400,

    tick = function(ctx, e)
      local p = game.connected_players[1]
      if p then
        local want = (e.tick >= T - 120) and 1 or 8
        if game.speed ~= want then game.speed = want end
      end
      -- Session avec images : le pilote (shots.lua, appelé après ce crochet dans le même on_tick) prend la capture
      -- gs.list[gs.i] à ce tick : on re-mesure son gisement au même tick.
      local gs = global.shots
      if p and gs and not gs.finished and not gs.flush_at and e.tick >= (gs.next or math.huge) then
        -- liste pas encore construite : elle l'est à ce tick et sa première capture est prise aussitôt (plan[1])
        local plan = ctx.state().plan
        local sp = gs.list and gs.list[gs.i] or (not gs.list and plan and plan[1]) or nil
        local c = sp and CACHE[sp.name]
        if c then
          local ok, err = pcall(function()
            log_gisement("capture", e.tick, c.key, c.cl, c.n, measure(ctx.surface(), c.force, c.cl), sp.name .. ".png")
          end)
          if not ok then ctx.state().erreur = tostring(err); log(TAG .. "ERREUR " .. tostring(err)) end
        end
      end
      if IS_MEASURE[e.tick] then
        local ok, err = pcall(run_all, ctx, e.tick, p)
        if not ok then
          ctx.state().erreur = tostring(err)
          log(TAG .. "ERREUR " .. tostring(err))
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      ctx.check(st.erreur == nil, "aucune erreur Lua dans la mesure", st.erreur or "")
      ctx.check((st.measured or 0) == #MEASURES, "mesures faites", tostring(st.measured or 0) .. "/" .. #MEASURES)
      ctx.check((st.last_rows or 0) >= 1, "au moins une equipe", tostring(st.last_rows or 0))
      ctx.check(#(st.plan or {}) >= 1, "captures prevues", tostring(#(st.plan or {})))
    end,

    -- Captures prévues au tick T (shoot) ; le pilote les prend à partir de T + 400.
    shots = function(ctx, add)
      for _, sp in ipairs(ctx.state().plan or {}) do
        add(sp.name, sp.x, sp.y, sp.zoom, 0, { res = { SHOT_W, SHOT_H }, info = true, aa = true })
      end
    end,
  }
end
