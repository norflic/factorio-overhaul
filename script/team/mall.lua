--[[
  Lot MALL, tranche 1 (docs/MALL.md §2.1, §3, §4 ; directive du DC du 8/11 vers 18 h 30, « centraliser sa production » dans « un
  véritable Mall », décisions D1 à D7 par défaut validées par l'intégrateur le 8/11). Côté RUNTIME de la règle pure
  shared/team/mall_plan.lua (Mp). Factions ET votre équipe : même règle, aucune branche sur f.is_player.

  1. SECTEUR (une fois par équipe, tôt) : relevé du terrain autour du QG par CASES de 8 × 8 tuiles, 2 chunks par passe du plan
     directeur (Build.PULSE), sous le jeton des travaux lourds (script/core/lourd.lua, coût déclaré = chunks lus) ; une case est
     interdite si elle porte de l'eau, du minerai, un bâtiment ou une falaise (masque d'objets), une tuile réservée par un projet (b.occ),
     un couloir d'accès (Build.couloirs), ou si son chunk n'est pas généré. Puis Mp.choose, un essai de Mp.TRIES par passe (coût mesuré :
     tests/mall_plan_test.lua §10). La fenêtre choisie est RÉSERVÉE : ses tuiles libres de b.occ prennent le propriétaire Mall.OCC (-1,
     aucun projet : reserve_tiles, P.fit et les autres poseurs la voient prise) et les lots du treillis entièrement dedans ne sont plus
     candidats (Mall.lot_inside, lu par candidates dans script/team/build.lua). Aucune fenêtre : cause au journal, nouvel essai 10 min
     plus tard.
  2. ÉTAT S (une fois par minute) : S1 centrale qui produit (premier courant, b.plant_watch), S2 une source AUTOMATISÉE finie par plaque
     fondue (bande de champ ou fonderie du plan directeur ; plaques lues dans T.outposts : celles dont le produit n'est pas la ressource) OU
     un débit mesuré de cette plaque d'au moins Mp.S2_PLAQUES_MIN par minute (lot MALL, tranche 2),
     S3 pas de crise (mode survie, QG menacé, pile qui retient), S4 un assembleur dont la recette est débloquée. Journal à chaque
     changement de cause. La tranche 1 ne POSE RIEN : l'état dit seulement quand la tranche 2 poserait.
  Réglage de carte fo-war-mall (settings/mall.lua), allumé par défaut ; absent (moteur simulé, mod d'avant) : éteint. Éteint en cours de
  partie : la réservation est rendue (Mall.release).
  État : f.build.mall = { v, phase, grid (chaînes, le temps du relevé), k, cx0, cy0, nch, try, sect, retry, etat_sig, etat_next, logs }
  (nombres, chaînes, tables ; jamais de fonction ni d'entité). Journal [FO-MALL] (Mall.LOGS lignes au plus par équipe).
  Déterminisme : chunks dans un ordre fixe, cases dans un ordre fixe, prototypes triés par nom, aucun temps mesuré.
]]

local Mp = require("shared.team.mall_plan")
local T = require("shared.team.config")
local P = require("shared.team.plan")

local Mall = {}

Mall.SETTING = "fo-war-mall"
Mall.OCC = -1               -- propriétaire des tuiles du secteur dans b.occ (aucun projet n'a ce numéro)
Mall.CHUNKS_PER_PASS = 2    -- chunks relevés par passe (coût déclaré au jeton des travaux lourds)
Mall.RETRY = 10 * 3600      -- ticks avant un nouvel essai quand aucune fenêtre ne passe
Mall.ETAT_EVERY = 3600      -- ticks entre deux relectures de l'état S
Mall.LOGS = 80              -- lignes [FO-MALL] de ce module au plus, par équipe

local floor = math.floor

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Réglage fo-war-mall (absent : éteint).
function Mall.on()
  local ok, v = pcall(function() return settings.global[Mall.SETTING].value end)
  return ok and v == true
end

local function state(b)
  b.mall = b.mall or { v = 1, phase = "neuf", logs = 0 }
  return b.mall
end

local function say(f, st, text)
  st.logs = (st.logs or 0) + 1
  if st.logs > Mall.LOGS then return end
  log(text)
end

local function who(f) return f.key or "player" end

---------------------------------------------------------------------------------------------------
-- Relevé d'un chunk
---------------------------------------------------------------------------------------------------
local SOFT = { "tree", "simple-entity" }

--- Masques des 16 cases (4 × 4) du chunk (cx, cy), écrits dans la grille.
local function read_chunk(f, surface, st, cx, cy, couloirs)
  local g = st.grid
  local b = f.build
  local C = Mp.CELL
  local per = Mp.CHUNK / C
  local i0 = (cx * Mp.CHUNK - g.gx0) / C
  local j0 = (cy * Mp.CHUNK - g.gy0) / C
  local generated = surface.is_chunk_generated({ cx, cy })
  -- le chunk entier d'abord (4 appels) : une catégorie absente du chunk n'est pas relevée case par case (terrain ouvert : 4 appels en
  -- tout au lieu de 64). (F96 : une recherche par zone rend aussi ce qui TOUCHE la zone : boîtes rentrées d'un centième)
  local has_eau, has_min, has_obj, has_soft = false, false, false, false
  if generated then
    local X0, Y0 = cx * Mp.CHUNK, cy * Mp.CHUNK
    local ca = { { X0 + 0.01, Y0 + 0.01 }, { X0 + Mp.CHUNK - 0.01, Y0 + Mp.CHUNK - 0.01 } }
    has_eau = surface.count_tiles_filtered({ area = ca, collision_mask = "water-tile", limit = 1 }) > 0
    has_min = surface.count_entities_filtered({ area = ca, type = "resource", limit = 1 }) > 0
    local nobj = surface.count_entities_filtered({ area = ca, collision_mask = "object-layer" })
    local nsoft = surface.count_entities_filtered({ area = ca, type = SOFT })
    has_obj, has_soft = nobj > nsoft, nsoft > 0
  end
  for dj = 0, per - 1 do
    local masks = {}
    for di = 0, per - 1 do
      local m = Mp.INCONNU
      if generated then
        local x0, y0 = cx * Mp.CHUNK + di * C, cy * Mp.CHUNK + dj * C
        local area = { { x0 + 0.01, y0 + 0.01 }, { x0 + C - 0.01, y0 + C - 0.01 } }
        local eau = has_eau and surface.count_tiles_filtered({ area = area, collision_mask = "water-tile", limit = 1 }) > 0
        local minerai = has_min and surface.count_entities_filtered({ area = area, type = "resource", limit = 1 }) > 0
        local nobj = (has_obj or has_soft) and surface.count_entities_filtered({ area = area, collision_mask = "object-layer" }) or 0
        local nsoft = has_soft and surface.count_entities_filtered({ area = area, type = SOFT }) or 0
        local bati = nobj > nsoft
        if not bati then
          for ty = y0, y0 + C - 1 do
            for tx = x0, x0 + C - 1 do
              local k = P.tkey(tx, ty)
              if (b.occ[k] and b.occ[k] ~= Mall.OCC) or couloirs[k] then bati = true break end
            end
            if bati then break end
          end
        end
        m = Mp.mask(eau, minerai, bati, false, nsoft > 0)
      end
      masks[di + 1] = m
    end
    Mp.set_run(g, i0, j0 + dj, masks)
  end
end

---------------------------------------------------------------------------------------------------
-- Réservation
---------------------------------------------------------------------------------------------------
--- Réserve les tuiles libres du secteur au nom du mall. Rend le nombre de tuiles prises.
local function reserve(b, s)
  local n = 0
  for ty = s.y0, s.y1 - 1 do
    for tx = s.x0, s.x1 - 1 do
      local k = P.tkey(tx, ty)
      if b.occ[k] == nil then b.occ[k] = Mall.OCC; n = n + 1 end
    end
  end
  return n
end

--- Rend la réservation du secteur (réglage éteint). Rend le nombre de tuiles rendues.
function Mall.release(b)
  local st = b and b.mall
  local s = st and st.sect
  if not s then return 0 end
  local n = 0
  for ty = s.y0, s.y1 - 1 do
    for tx = s.x0, s.x1 - 1 do
      local k = P.tkey(tx, ty)
      if b.occ[k] == Mall.OCC then b.occ[k] = nil; n = n + 1 end
    end
  end
  b.mall = nil
  return n
end

--- Le lot l du treillis est-il entièrement dans le secteur du mall ? (lu par candidates, script/team/build.lua)
function Mall.lot_inside(b, l)
  local s = b and b.mall and b.mall.sect
  if not s then return false end
  local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
  return Mp.inside(s, x0, y0, x1, y1)
end

---------------------------------------------------------------------------------------------------
-- État S
---------------------------------------------------------------------------------------------------
--- Plaques fondues (T.outposts : produit différent de la ressource), triées : { { kind, item, ore } }.
local function plates()
  local out = {}
  for _, kind in ipairs(sorted_keys(T.outposts)) do
    local o = T.outposts[kind]
    if o.product and o.resource and o.product ~= o.resource then out[#out + 1] = { kind = kind, item = o.product, ore = o.resource } end
  end
  return out
end

--- Une source automatisée FINIE de cette plaque : une bande de champ (site « champ ») de son avant-poste, ou une fonderie du plan
--- directeur (gabarit « smelter », minerai en 2e argument).
local function automated(f, pl)
  local b = f.build
  for _, id in ipairs(b.order or {}) do
    local p = b.projects[id]
    if p and p.state == "fini" and p.spec then
      local sp = p.spec
      if sp.site == "champ" and sp.champ then
        local o = f.outposts and f.outposts[sp.champ.oid]
        if o and o.kind == pl.kind then return true end
      elseif sp.gen == "smelter" and sp.args and sp.args[2] == pl.ore then
        return true
      end
    end
  end
  return false
end

--- Réglage fo-war-mall-s2-debit (A/B du seuil de S2 ; absent : allumé).
function Mall.s2_debit()
  local ok, v = pcall(function() return settings.global["fo-war-mall-s2-debit"].value end)
  if not ok then return true end
  return v == true
end

--- Plaques `item` produites par minute par la force (statistiques du moteur) ; 0 sans statistiques.
local function plate_flow(f, item)
  local force = game.forces[f.force]
  local st = force and force.item_production_statistics
  if not st then return 0 end
  return st.get_flow_count({ name = item, input = true, precision_index = defines.flow_precision_index.one_minute }) or 0
end

local function assembler_usable(f)
  local force = game.forces[f.force]
  if not force then return false end
  local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = "assembling-machine" } })
  local names = {}
  for name in pairs(protos) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    for _, it in ipairs(protos[name].items_to_place_this or {}) do
      local r = force.recipes[it.name]
      if r and r.enabled then return true end
    end
  end
  return false
end

local function crise(f)
  local t = f.team or {}
  if t.survie and t.survie.on == true then return "survie" end
  if t.hq_menace and t.hq_menace.crise then return "qg menace" end
  local pile = t.ia3 and t.ia3.pile
  if pile and pile.hold then return "pile R" .. tostring(pile.top) end
  return nil
end

--- Entrées de Mp.etat pour l'équipe (lecture seule).
function Mall.inputs(f)
  local b = f.build
  local pp = b.plant and b.projects[b.plant]
  local inp = { plant = pp ~= nil and pp.state == "fini" and b.plant_watch ~= nil and b.plant_watch.first_power ~= nil, plaques = {} }
  for _, pl in ipairs(plates()) do
    inp.plaques[#inp.plaques + 1] = { item = pl.item, auto = automated(f, pl) or (Mall.s2_debit() and plate_flow(f, pl.item) >= Mp.S2_PLAQUES_MIN) } -- automatisée : un projet fini, ou le débit mesuré
  end
  inp.crise = crise(f)
  inp.asm = assembler_usable(f)
  return inp
end

---------------------------------------------------------------------------------------------------
-- Passe
---------------------------------------------------------------------------------------------------
--- Une passe du plan directeur. h = { couloirs = function(f) -> ensemble de clés, jeton = ordonnanceur des travaux lourds, pulse }.
function Mall.step(h, f, surface, tick)
  local b = f.build
  if not (b and surface and f.hq and f.hq.valid and f.hq_pos) then return end
  if not Mall.on() then
    if b.mall and b.mall.sect then
      local n = Mall.release(b)
      log(string.format("[FO-MALL] %s : reglage eteint : reservation du secteur rendue (%d tuile(s)) a %.1f min", who(f), n, tick / 3600))
    end
    return
  end
  local st = state(b)
  -- 1. secteur
  if st.phase == "aucun" and tick >= (st.retry or 0) then st.phase = "neuf" end
  if st.phase == "neuf" then
    local g, cx0, cy0, nch = Mp.grid_around(f.hq_pos.x, f.hq_pos.y)
    st.grid, st.cx0, st.cy0, st.nch, st.k, st.try = g, cx0, cy0, nch, 0, 1
    st.phase = "lecture"
    say(f, st, string.format("[FO-MALL] %s : SECTEUR recherche : %d chunk(s) a relever autour du QG (%d, %d) a %.1f min", who(f), nch * nch,
      floor(f.hq_pos.x), floor(f.hq_pos.y), tick / 3600))
  elseif st.phase == "lecture" then
    local key = who(f) .. ":mall"
    if not h.jeton or h.jeton.take(tick, key, h.pulse or 5, Mall.CHUNKS_PER_PASS) then
      local cou = h.couloirs and h.couloirs(f) or {}
      local total = st.nch * st.nch
      for _ = 1, Mall.CHUNKS_PER_PASS do
        if st.k >= total then break end
        read_chunk(f, surface, st, st.cx0 + st.k % st.nch, st.cy0 + floor(st.k / st.nch), cou)
        st.k = st.k + 1
      end
      if st.k >= total then st.phase = "choix" end
    end
  elseif st.phase == "choix" then
    local t = Mp.TRIES[st.try]
    local x0, y0, x1, y1 = P.lot_rect(b.lat, 0, 0)
    local s, tally = Mp.choose(st.grid, { size = t.size, radius = t.radius, qx = f.hq_pos.x, qy = f.hq_pos.y,
      keep_out = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 } })
    if s then
      st.sect = s
      st.grid = nil
      st.phase = "choisi"
      local n = reserve(b, s)
      say(f, st, Mp.line_sector(who(f), s, n, tick / 3600))
    elseif st.try < #Mp.TRIES then
      st.try = st.try + 1
    else
      st.grid = nil
      st.phase = "aucun"
      st.retry = tick + Mall.RETRY
      say(f, st, Mp.line_none(who(f), t.radius, tally or {}, tick / 3600, Mall.RETRY / 3600))
    end
  end
  -- 2. état S
  if tick >= (st.etat_next or 0) then
    st.etat_next = tick + Mall.ETAT_EVERY
    local e = Mp.etat(Mall.inputs(f))
    if e.cause ~= st.etat_sig then
      st.etat_sig = e.cause
      say(f, st, Mp.line_etat(who(f), e, st.sect ~= nil, tick / 3600))
    end
    st.pret = e.ok or nil
    st.partiel = e.partiel -- lecteur : Rt.ouvert et Rt.place (script/team/mall_rangee.lua)
  end
end

return Mall
