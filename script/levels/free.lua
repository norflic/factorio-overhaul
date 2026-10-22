--[[
  Niveaux : bouton « LIBÉRER LA PLACE » et AGRANDISSEMENT EN ATTENTE (lot V3-T3 ; Q-T2-1, réponse du Directeur
  Créatif le 22/10 à 21 h 06 : « QT21 option B » : « On garde la règle, et j'ajoute un bouton "libérer la place". Il
  marque les gêneurs à démonter par les robots et pose des fantômes pour les reconstruire décalés. »).

  La règle Q24 ne change pas : sans clic, refus « no-room » et contour, comme avant. Au clic (panneau « Évolution »,
  ou interface distante levels_free_room pour le banc) :
    1. la scène autour des positions candidates est relevée (entités et tuiles, données simples ; même critère de gêne
       que Levels.room : Levels.blocks) ; la règle de décalage PURE (shared/levels/clear.lua, C.plan) dit, pour chaque
       candidate, quoi démonter et où reposer chaque gêneur ; C.choose retient la candidate du contour si son plan est
       COMPLET, sinon la première autre candidate (ordre « la plus facile à libérer ») dont le plan est complet ;
    2. AUCUN plan complet (un gêneur qu'on ne sait pas reposer : bâtiment voisin, falaise, véhicule, autre force, eau,
       carré réservé par une autre demande…) : REFUS, rien n'est marqué, aucun fantôme ; les gêneurs sont montrés en
       violet au sol et listés avec leur position [gps] (correction V3-T3, défauts 10 et 17) ;
    3. sinon, tout ou rien : chaque gêneur est MARQUÉ à démonter (order_deconstruction, force du bâtiment, le joueur
       comme dernier utilisateur) : robots de construction, ou le joueur à la main ; le mod ne détruit jamais un
       gêneur, aucun objet n'est perdu ; un FANTÔME (entity-ghost, sans expiration) le reconstruit décalé, même nom,
       même orientation, MÊMES RÉGLAGES (copy_settings : filtres et mode d'un bras, conditions de circuit, demandes d'un
       coffre de demande, barre d'un coffre ; taille de pile imposée d'un bras ; moteur réel, essai E58) ; une marque ou
       un fantôme refusé par le moteur annule TOUT ce qui a été posé (fantômes d'abord, puis marques : F103) ;
    4. la condition Q16 et le COÛT doivent être réunis au clic (seul le motif « no-room » ouvre le bouton : correction,
       défaut 10) ; une DEMANDE d'agrandissement est gardée (global, liste ordonnée, nombres seulement) et vérifiée
       toutes les Free.PERIOD ticks (liste vide : rien d'autre qu'un test) ; dès que la place de CETTE candidate est
       libre, l'amélioration se fait (Levels.start, paiement à ce moment-là) ; coût qui manque entre-temps : message,
       la demande attend ; au-delà de Free.TTL ticks, elle expire ; pendant l'attente, le contour, les gêneurs marqués
       et les places des fantômes sont redessinés à chaque vérification (correction, défaut 16) ;
    5. « Annuler » (ou l'expiration, ou le bâtiment disparu) REMET L'USINE COMME AVANT (correction, défaut 11) : les
       fantômes du mod encore fantômes sont retirés ; ceux déjà construits sont marqués à démonter ; les marques du mod
       encore posées sont annulées ; chaque gêneur déjà démonté reçoit un fantôme à sa place et à son orientation
       D'ORIGINE, avec ses réglages (place prise : c'est dit, avec sa position). Rien d'autre n'est touché.
  Déterminisme : tout se passe dans des événements ; scène triée (y, x, nom, numéro) ; demandes dans l'ordre de
  création ; aucune décision pilotée par un temps mesuré. global : la liste des demandes ne garde QUE des nombres
  (positions, numéros d'unité, index de surface, de force, de joueur, ticks, directions, et l'indice d'un nom de
  prototype) ; les noms de prototypes, nécessaires pour reposer un gêneur à l'identique, sont gardés une fois chacun
  dans levels_free.names (liste ordonnée de chaînes, jamais l'ordre de pairs). Aucune entité, aucune fonction.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local Foot = require("shared.levels.footprint")
local Clear = require("shared.levels.clear")
local Levels = require("script.levels.levels")

local Free = {}

--- Période de vérification des demandes (ticks).
Free.PERIOD = 60
--- Durée de vie d'une demande (ticks) : 30 minutes de jeu.
Free.TTL = 108000
--- Marge de la scène autour des candidates (tuiles) : bosse de convoyeur, liaisons de murs, fils de poteau.
Free.REACH = 4
--- Marge de recherche des POTEAUX (zone d'alimentation, règle 4 de clear.lua) : un poteau plus loin n'est pas vu.
Free.POLE_REACH = 12
--- Au plus tant de lignes dans un message.
Free.MAX_LIST = 12

-- Demandes, NOMBRES SEULEMENT : list = { { id, unit, surface (index), x, y, level, next, box = { x0, y0, x1, y1 },
-- force (index), player (index ou nil), tick, expire, marks, ghosts, warned } } ;
-- marks = { { u (numéro d'unité ; nil pour un arbre ou un rocher), x, y, n (indice du nom dans names), d (direction),
-- g (groupe), nat (1 : arbre, rocher : rien à reposer) } } ; ghosts = { { u, x, y, n, d, g, m (indice de la marque
-- qu'il remplace, 0 : aucune : liaison de mur, tuile de bosse en plus) } }.
-- names : noms de prototypes, une fois chacun, dans l'ordre d'arrivée (chaînes ; hors de la liste des demandes).
Storage.declare("levels_free", function()
  return { list = {}, next = 0, names = {}, stats = { requests = 0, refused = 0, done = 0, cancelled = 0, expired = 0, gone = 0,
    marked = 0, ghosts = 0, unmarked = 0, ghosts_removed = 0, unbuilt = 0, restored = 0, restore_blocked = 0, aborted = 0 } }
end)

local function F() return Storage.ns("levels_free") end

local function stat(k, n)
  local s = F().stats
  s[k] = (s[k] or 0) + (n or 1)
end

--- Indice d'un nom de prototype dans levels_free.names (ajouté s'il manque).
local function intern(name)
  local st = F()
  st.names = st.names or {}
  for i, n in ipairs(st.names) do
    if n == name then return i end
  end
  st.names[#st.names + 1] = name
  return #st.names
end

local function name_of(i)
  local names = F().names
  return names and names[i] or nil
end

--- Demande en cours pour ce bâtiment (numéro d'unité), ou nil.
function Free.request_of(entity)
  if not (entity and entity.valid and entity.unit_number) then return nil end
  for _, r in ipairs(F().list) do
    if r.unit == entity.unit_number then return r end
  end
  return nil
end

-- Crochet de script/levels/levels.lua (Levels.preview) : toute décision vise le carré libéré tant qu'une demande attend
-- (correction V3-T3, défauts 5 et 24).
Levels.pending_box = function(entity)
  local r = Free.request_of(entity)
  if not r then return nil end
  return { x0 = r.box.x0, y0 = r.box.y0, x1 = r.box.x1, y1 = r.box.y1 }
end

---------------------------------------------------------------------------------------------------
-- Retrouver une entité (global ne garde que des données simples)
---------------------------------------------------------------------------------------------------
--- Entité marquée par le mod : même position, même nom, même numéro (un arbre, un rocher : même nom, sans numéro ;
--- correction V3-T3, défaut 9 : un cadavre ou un débris à la même position ne compte plus).
local function find_rec(surface, rec)
  if not surface then return nil end
  local name = name_of(rec.n)
  for _, e in ipairs(surface.find_entities_filtered({ position = { rec.x, rec.y }, name = name })) do
    if e.valid and e.type ~= "entity-ghost" and e.unit_number == rec.u and math.abs(e.position.x - rec.x) < Clear.TOL
        and math.abs(e.position.y - rec.y) < Clear.TOL then
      return e
    end
  end
  return nil
end

local function find_ghost(surface, rec)
  if not surface then return nil end
  for _, g in ipairs(surface.find_entities_filtered({ position = { rec.x, rec.y }, type = "entity-ghost" })) do
    if g.valid and g.unit_number == rec.u then return g end
  end
  return nil
end

--- Entité CONSTRUITE à partir d'un fantôme du mod (revive : nouveau numéro, essai E58) : même nom, même position, même
--- direction, même force ; jamais une des entités d'origine encore là (`keep` : numéros à exclure).
local function find_built(surface, g, force, keep)
  if not surface then return nil end
  local name = name_of(g.n)
  for _, e in ipairs(surface.find_entities_filtered({ position = { g.x, g.y }, name = name, force = force })) do
    if e.valid and not (e.unit_number and keep[e.unit_number]) and math.abs(e.position.x - g.x) < Clear.TOL
        and math.abs(e.position.y - g.y) < Clear.TOL and (e.direction or 0) == (g.d or 0) then
      return e
    end
  end
  return nil
end

local function find_building(req)
  local surface = game.surfaces[req.surface]
  if not surface then return nil end
  for _, e in ipairs(surface.find_entities_filtered({ position = { req.x, req.y } })) do
    if e.valid and e.unit_number == req.unit then return e end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------------------------------
local function player_of(req_or_index)
  local index = req_or_index
  if type(req_or_index) == "table" then index = req_or_index.player end
  local p = index and game.get_player(index)
  if p and p.valid then return p end
  return nil
end

local function tell(req, msg)
  local p = player_of(req)
  if p and p.connected then
    p.print(msg)
    return
  end
  local force = game.forces[req.force]
  if force then force.print(msg) end
end

--- « a×2 b … » (étiquettes de texte enrichi du moteur), dans l'ordre d'arrivée trié, au plus Free.MAX_LIST sortes.
local function count_text(tags)
  local count, keys = {}, {}
  for _, n in ipairs(tags) do
    if not count[n] then count[n] = 0; keys[#keys + 1] = n end
    count[n] = count[n] + 1
  end
  table.sort(keys)
  local parts = {}
  for i, k in ipairs(keys) do
    if i > Free.MAX_LIST then parts[#parts + 1] = "…" break end
    parts[#parts + 1] = count[k] > 1 and (k .. "×" .. count[k]) or k
  end
  return table.concat(parts, " ")
end

--- « [entity=a] [gps=x,y] … » : chaque élément AVEC sa position (correction V3-T3, défaut 16), au plus Free.MAX_LIST.
local function where_text(list)
  local parts = {}
  for i, s in ipairs(list) do
    if i > Free.MAX_LIST then parts[#parts + 1] = "…" break end
    local tag = s.tile and ("[tile=" .. s.name .. "]") or ("[entity=" .. s.name .. "]")
    parts[#parts + 1] = tag .. " [gps=" .. s.x .. "," .. s.y .. "]"
  end
  return table.concat(parts, " ")
end

---------------------------------------------------------------------------------------------------
-- Scène (données simples pour shared/levels/clear.lua)
---------------------------------------------------------------------------------------------------
local NON_BLOCKING = Levels.NON_BLOCKING

local function has_object_layer(e)
  local m = e.prototype.collision_mask
  return m and m["object-layer"] and true or false
end

--- Numéros d'unité réservés par les AUTRES demandes en attente sur cette surface (entités qu'elles ont marquées,
--- fantômes qu'elles ont posés), et leurs carrés (correction V3-T3, défaut 1).
local function reservations(surface_index, except_unit)
  local units, boxes = {}, {}
  for _, r in ipairs(F().list) do
    if r.surface == surface_index and r.unit ~= except_unit then
      boxes[#boxes + 1] = { x0 = r.box.x0, y0 = r.box.y0, x1 = r.box.x1, y1 = r.box.y1 }
      for _, m in ipairs(r.marks) do if m.u then units[m.u] = true end end
      for _, g in ipairs(r.ghosts) do if g.u then units[g.u] = true end end
    end
  end
  return units, boxes
end

--- Relève la scène sur la zone `area` ({x0, y0, x1, y1}) : tout ce qui gênerait le nouveau prototype (Levels.blocks,
--- même critère que Levels.room : défauts 2 et 20), tout ce qui touche la couche des objets (place d'un fantôme), les
--- fantômes (obstacles), et les poteaux jusqu'à Free.POLE_REACH (zone d'alimentation) ; sauf le bâtiment, les
--- personnages, unités et objets au sol. Triée (y, x, nom, numéro). Renvoie recs (pour Clear.plan), ents (entités du
--- moteur, même index ; jamais gardées dans global) et les tuiles d'eau de la zone.
local function relever(entity, area, layers, reserved_units)
  local surface = entity.surface
  local found, seen = {}, {}
  local function take(e)
    local key = e.unit_number or (e.name .. "@" .. e.position.x .. "," .. e.position.y)
    if seen[key] then return end
    seen[key] = true
    found[#found + 1] = e
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { area.x0, area.y0 }, { area.x1, area.y1 } } })) do
    if e.valid and e ~= entity and not NON_BLOCKING[e.type]
        and (e.type == "entity-ghost" or Levels.blocks(entity, e, layers) or has_object_layer(e)) then
      take(e)
    end
  end
  local R = Free.POLE_REACH
  for _, e in ipairs(surface.find_entities_filtered({ area = { { area.x0 - R, area.y0 - R }, { area.x1 + R, area.y1 + R } }, type = "electric-pole" })) do
    if e.valid and e ~= entity then take(e) end
  end
  table.sort(found, function(a, b)
    local pa, pb = a.position, b.position
    if pa.y ~= pb.y then return pa.y < pb.y end
    if pa.x ~= pb.x then return pa.x < pb.x end
    if a.name ~= b.name then return a.name < b.name end
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)
  local recs, ents = {}, {}
  local force = entity.force
  for i, e in ipairs(found) do
    local bb = e.bounding_box
    local p = e.position
    local foreign = e.force ~= force and e.force.name ~= "neutral"
    local r = { id = i, name = e.name, type = e.type, x = p.x, y = p.y, dir = e.direction or 0, foreign = foreign,
      box = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y } }
    r.kind = Clear.kind(e.type, foreign)
    if e.type ~= "entity-ghost" then
      r.marked = e.to_be_deconstructed()
      r.powered = e.type ~= "electric-pole" and e.prototype.electric_energy_source_prototype ~= nil
    end
    if e.unit_number and reserved_units[e.unit_number] then r.reserved = true end
    if e.type == "inserter" then
      local pp, dp = e.pickup_position, e.drop_position
      r.pick, r.drop = { x = pp.x, y = pp.y }, { x = dp.x, y = dp.y }
    elseif e.type == "electric-pole" then
      r.reach = e.prototype.max_wire_distance
      r.supply = e.prototype.supply_area_distance
      r.wires = {}
      local nb = e.neighbours
      for _, n in ipairs((nb and nb.copper) or {}) do
        if n.valid then r.wires[#r.wires + 1] = { x = n.position.x, y = n.position.y, reach = n.prototype.max_wire_distance } end
      end
    end
    local defs = e.type ~= "entity-ghost" and e.circuit_connection_definitions
    if defs and #defs > 0 then r.wired = true end
    recs[i], ents[i] = r, e
  end
  -- Tuiles d'eau de la zone : aucun fantôme n'y est posé.
  local tiles = {}
  for y = area.y0, area.y1 - 1 do
    for x = area.x0, area.x1 - 1 do
      local t = surface.get_tile(x, y)
      if t.collides_with("water-tile") then tiles[#tiles + 1] = { x = x, y = y, name = t.name } end
    end
  end
  return recs, ents, tiles
end

--- Identifiant de la scène d'une gêne relevée par Levels.room (même nom, même position).
local function scene_id(recs, g)
  for _, r in ipairs(recs) do
    if r.name == g.name and math.abs(r.x - g.x) < 1e-6 and math.abs(r.y - g.y) < 1e-6 then return r.id end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Dessin
---------------------------------------------------------------------------------------------------
local COLOR = {
  box = { r = 1, g = 0.55, b = 0.1, a = 0.9 },     -- orange : le carré visé
  mark = { r = 1, g = 0.9, b = 0.1, a = 0.9 },     -- jaune : marqué à démonter
  ghost = { r = 0.3, g = 0.8, b = 1, a = 0.9 },    -- bleu clair : place d'un fantôme
  signal = { r = 0.75, g = 0.2, b = 1, a = 0.95 }, -- violet : à retirer à la main (le rouge est l'icône du moteur)
  tile = { r = 0.45, g = 0.1, b = 0.6, a = 0.35 },
}

local function drawer(entity, player, ttl)
  local surface = entity.surface
  local players = (player and player.valid) and { player.index } or nil
  local forces = (not players) and { entity.force.name } or nil
  return function(b, color, width, filled, grow)
    local m = grow or 0
    rendering.draw_rectangle({ color = color, width = width, filled = filled, left_top = { b.x0 - m, b.y0 - m },
      right_bottom = { b.x1 + m, b.y1 + m }, surface = surface, time_to_live = ttl, players = players, forces = forces })
  end
end

--- Au clic : orange le carré ; plan accepté : jaune les gêneurs marqués, bleu clair les places des fantômes ; refus :
--- violet les gêneurs signalés (correction V3-T3, défaut 19 : le rouge est celui de l'icône de démontage du moteur).
local function draw_plan(entity, B, plan, recs, player, ttl, signals)
  local rect = drawer(entity, player, ttl)
  rect(B, COLOR.box, 3, false)
  if plan then
    -- Marques un peu plus larges que leur boîte : un fantôme posé sur la même tuile (convoyeur tourné) reste visible.
    for _, id in ipairs(plan.marks) do
      local r = recs[id]
      if r then rect(r.box, COLOR.mark, 2, false, 0.08) end
    end
    for _, g in ipairs(plan.ghosts) do rect(g.box, COLOR.ghost, 2, false) end
  end
  for _, s in ipairs(signals or {}) do
    if s.box then
      rect(s.box, COLOR.signal, 3, false, 0.05)
    elseif s.tile then
      rect({ x0 = s.x, y0 = s.y, x1 = s.x + 1, y1 = s.y + 1 }, COLOR.tile, 1, true)
    end
  end
end

--- Pendant l'attente (à chaque vérification, correction V3-T3, défaut 16) : le carré, les gêneurs du mod encore
--- marqués, les places des fantômes du mod encore à construire. Positions relues dans global, boîtes sur les entités.
local function draw_pending(e, req, player)
  local rect = drawer(e, player, Free.PERIOD + 2)
  rect(req.box, COLOR.box, 3, false)
  local surface = e.surface
  for _, m in ipairs(req.marks) do
    local x = find_rec(surface, m)
    if x and x.to_be_deconstructed() then
      local bb = x.bounding_box
      rect({ x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }, COLOR.mark, 2, false, 0.08)
    end
  end
  for _, g in ipairs(req.ghosts) do
    local gh = find_ghost(surface, g)
    if gh then
      local bb = gh.bounding_box
      rect({ x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }, COLOR.ghost, 2, false)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Réglages d'un gêneur reposé (correction V3-T3, défauts 3 et 14 ; moteur réel, essai E58)
---------------------------------------------------------------------------------------------------
--- Recopie les réglages de `src` (entité ou fantôme du même nom) sur le fantôme `gh` : copy_settings (filtres et mode
--- d'un bras, conditions de circuit, demandes d'un coffre de demande, barre d'un coffre) ; la taille de pile imposée
--- d'un bras, que copy_settings ne recopie pas (E58), est posée à part. Renvoie false si le moteur a refusé.
local function copy_into(gh, src)
  if not (gh and gh.valid and src and src.valid) then return true end
  local sname = src.type == "entity-ghost" and src.ghost_name or src.name
  if sname ~= gh.ghost_name then return true end
  local ok = pcall(function() gh.copy_settings(src) end)
  local stype = src.type == "entity-ghost" and src.ghost_type or src.type
  if stype == "inserter" then
    local n = src.inserter_stack_size_override
    if n and n > 0 then gh.inserter_stack_size_override = n end
  end
  return ok
end

---------------------------------------------------------------------------------------------------
-- Libérer la place
---------------------------------------------------------------------------------------------------
--- Carré de tuiles d'une boîte { x0, y0, x1, y1 } en carte, ou d'un rectangle de Levels.room.
local function box_copy(b) return { x0 = b.x0, y0 = b.y0, x1 = b.x1, y1 = b.y1 } end

--- Signaux d'un plan en données simples (nom, position, boîte, motif) pour les messages et le dessin.
local function signal_list(plan, recs)
  local out = {}
  for _, s in ipairs(plan and plan.signals or {}) do
    if s.id and recs[s.id] then
      local r = recs[s.id]
      out[#out + 1] = { name = r.name, x = r.x, y = r.y, box = r.box, why = s.why }
    elseif s.tile then
      out[#out + 1] = { name = s.tile.name, tile = true, x = s.tile.x, y = s.tile.y, why = s.why }
    elseif s.missing then
      out[#out + 1] = { name = s.missing.name, x = s.missing.x, y = s.missing.y, box = s.missing.box, why = s.why }
    else
      out[#out + 1] = { name = "?", x = 0, y = 0, why = s.why }
    end
  end
  return out
end

--- Lance « libérer la place » pour `entity` (opts.player : joueur qui clique, ou nil pour le banc ; opts.dry : rien
--- n'est posé, le plan est seulement calculé : banc). Renvoie une table de données simples : { ok, reason, id, box,
--- marks = { {name, x, y} }, ghosts = { {name, x, y, dir} }, signalled = { {name, x, y, why} }, warnings = { why },
--- wired, links, candidate (rang de la candidate retenue), tried (candidates essayées) }. reason : "pending"
--- (demande créée), "dry" (plan calculé, rien posé), "room-free" (la place est déjà libre : améliorer suffit),
--- "already" (une demande existe), "blocked" (aucune candidate libérable sans démonter à la main), "too-many",
--- "engine-refused" (marque ou fantôme refusé par le moteur : tout est retiré), ou le motif d'aperçu qui empêche
--- tout agrandissement (« max », « cc-too-low », « no-resources »…).
function Free.free_room(entity, opts)
  opts = opts or {}
  if not (entity and entity.valid) then return { ok = false, reason = "invalid" } end
  local family, level = L.parse(entity.name)
  if not family then return { ok = false, reason = "not-levelable" } end
  if Free.request_of(entity) then return { ok = false, reason = "already" } end
  local player = opts.player and opts.player.valid and opts.player or nil
  local info = Levels.preview(entity, player, true)
  if not info then return { ok = false, reason = "not-levelable" } end
  local room = info.room
  if not room then return { ok = false, reason = info.reason or "no-resize" } end
  if room.chosen then return { ok = false, reason = "room-free" } end
  -- Correction V3-T3 (défaut 10) : seul le motif « no-room » (tout le reste réuni : condition Q16, COÛT) ouvre le
  -- bouton ; un coût qui manque ferait déplacer les bras pour un bâtiment qui ne grandirait pas. Le banc peut
  -- demander le plan seul (opts.dry) quel que soit le motif.
  if info.reason ~= "no-room" and not opts.dry then return { ok = false, reason = info.reason } end
  local cands = room.candidates or {}
  if #cands == 0 then return { ok = false, reason = "no-target" } end

  -- Scène : réunion des candidates, plus la marge.
  local area = { x0 = cands[1].box.x0, y0 = cands[1].box.y0, x1 = cands[1].box.x1, y1 = cands[1].box.y1 }
  for _, c in ipairs(cands) do
    area.x0, area.y0 = math.min(area.x0, c.box.x0), math.min(area.y0, c.box.y0)
    area.x1, area.y1 = math.max(area.x1, c.box.x1), math.max(area.y1, c.box.y1)
  end
  area = { x0 = area.x0 - Free.REACH, y0 = area.y0 - Free.REACH, x1 = area.x1 + Free.REACH, y1 = area.y1 + Free.REACH }
  local new_name = L.name(family, level + 1)
  local proto = game.entity_prototypes[new_name]
  local layers = Levels.mask_layers(proto and proto.collision_mask)
  local surface, force = entity.surface, entity.force
  local res_units, res_boxes = reservations(surface.index, entity.unit_number)
  local recs, ents, area_tiles = relever(entity, area, layers, res_units)
  local bb = entity.bounding_box
  local old_rect = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
  local electric = proto and proto.electric_energy_source_prototype ~= nil
  local connector = L.name(L.by_key.wall, 1)

  local plans = {}
  local function plan_of(i)
    if plans[i] ~= nil then return plans[i] or nil end
    local c = cands[i]
    local rect = Foot.collision_rect(c.box)
    -- Carré réservé par une autre demande, ou fantôme d'une autre demande sous le futur bâtiment : exclue.
    for _, b in ipairs(res_boxes) do
      if Foot.overlap(rect, b) then plans[i] = false return nil end
    end
    for _, r in ipairs(recs) do
      if r.kind == "ghost" and r.reserved and Foot.overlap(rect, r.box) then plans[i] = false return nil end
    end
    local blockers, missing = {}, {}
    for _, g in ipairs(c.entities or {}) do
      local id = scene_id(recs, g)
      if id then blockers[#blockers + 1] = id else missing[#missing + 1] = { name = g.name, x = g.x, y = g.y, box = g.box } end
    end
    local moved = {}
    for _, m in ipairs(c.moved or {}) do
      local id = scene_id(recs, m)
      if id then
        for _, pt in ipairs(room.points or {}) do
          if pt.entity == m then
            moved[#moved + 1] = { id = id, old = { x = pt.x, y = pt.y }, new = { x = c.x + pt.rel.x, y = c.y + pt.rel.y } }
            break
          end
        end
      else
        missing[#missing + 1] = { name = m.name, x = m.x, y = m.y, box = m.box }
      end
    end
    local p = Clear.plan({
      new_box = c.box, old_rect = old_rect, scene = recs, blockers = blockers, moved = moved, tiles = c.tiles,
      area_tiles = area_tiles, connector = connector, reserved_boxes = res_boxes, missing = missing,
      powered_box = electric and rect or nil,
    })
    plans[i] = p
    return p
  end
  local ci, plan, shown = Clear.choose(cands, room.target_index or 1, plan_of)
  local tried = 0
  for i = 1, #cands do if plans[i] ~= nil then tried = tried + 1 end end

  if not plan then
    -- REFUS (correction V3-T3, défauts 10, 12 et 17) : rien n'est marqué, aucun fantôme, aucune demande.
    local tgt = room.target or cands[1]
    local sig = signal_list(shown, recs)
    local reason = (shown and shown.too_many) and "too-many" or "blocked"
    if opts.dry then
      return { ok = false, reason = reason, box = box_copy(tgt.box), signalled = sig, tried = tried, marks = {}, ghosts = {}, warnings = {} }
    end
    stat("refused")
    draw_plan(entity, tgt.box, nil, recs, player, Levels.CONTOUR_TTL, sig)
    local req = { player = player and player.index or nil, force = force.index }
    tell(req, { "fo-levels-taille.free-blocked", "[entity=" .. entity.name .. "]", where_text(sig) })
    log("[FO-LEVELS] liberer la place REFUSE : " .. entity.name .. " en " .. entity.position.x .. ", " .. entity.position.y .. " ; "
      .. tried .. " candidate(s) essayee(s), aucune liberable ; candidate du contour : " .. #sig .. " gene(s) a retirer a la main")
    return { ok = false, reason = reason, box = box_copy(tgt.box), signalled = sig, tried = tried, marks = {}, ghosts = {}, warnings = {} }
  end
  local B = cands[ci].box
  if opts.dry then
    local gl = {}
    for _, g in ipairs(plan.ghosts) do gl[#gl + 1] = { name = g.name, x = g.x, y = g.y, dir = g.dir } end
    local ml = {}
    for _, id in ipairs(plan.marks) do ml[#ml + 1] = { name = recs[id].name, x = recs[id].x, y = recs[id].y } end
    return { ok = true, reason = "dry", box = box_copy(B), candidate = ci, tried = tried, marks = ml, ghosts = gl, signalled = {}, warnings = {} }
  end

  -- Exécution, TOUT OU RIEN : marques de tous les groupes, puis fantômes ; un refus du moteur retire tout (fantômes
  -- d'abord, puis marques : F103).
  local st = F()
  local req = { id = st.next + 1, unit = entity.unit_number, surface = surface.index,
    x = entity.position.x, y = entity.position.y, level = level, next = level + 1,
    box = box_copy(B), force = force.index, player = player and player.index or nil,
    tick = game.tick, expire = game.tick + Free.TTL, marks = {}, ghosts = {} }
  local out = { ok = true, reason = "pending", id = req.id, box = req.box, candidate = ci, tried = tried, marks = {}, ghosts = {},
    signalled = {}, warnings = {}, wired = 0, links = {}, settings_failed = 0 }
  local marked_ents, ghost_ents, mark_index = {}, {}, {}
  local function abort(what)
    for k = #ghost_ents, 1, -1 do
      if ghost_ents[k].valid then ghost_ents[k].destroy() end
    end
    for k = #marked_ents, 1, -1 do
      if marked_ents[k].valid then marked_ents[k].cancel_deconstruction(force, player) end
    end
    stat("aborted")
    log("[FO-LEVELS] liberer la place ANNULE par le moteur (" .. what .. ") : " .. entity.name .. " ; rien n'est resté")
    return { ok = false, reason = "engine-refused", box = req.box, marks = {}, ghosts = {}, signalled = { { name = what, x = 0, y = 0, why = "moteur" } }, warnings = {} }
  end
  for gi, G in ipairs(plan.groups) do
    for _, id in ipairs(G.marks) do
      local e, r = ents[id], recs[id]
      if not (e and e.valid) or e.to_be_deconstructed() then return abort("marque : " .. r.name) end
      if not e.order_deconstruction(force, player) then return abort("marque : " .. r.name) end
      marked_ents[#marked_ents + 1] = e
      req.marks[#req.marks + 1] = { u = e.unit_number, x = e.position.x, y = e.position.y, n = intern(e.name),
        d = e.direction or 0, g = gi, nat = (r.kind == "natural") and 1 or nil }
      mark_index[id] = #req.marks
      out.marks[#out.marks + 1] = { name = e.name, x = e.position.x, y = e.position.y }
      if r.wired then out.wired = out.wired + 1 end
    end
  end
  for gi, G in ipairs(plan.groups) do
    for _, g in ipairs(G.ghosts) do
      local gh = surface.create_entity({ name = "entity-ghost", inner_name = g.name, position = { g.x, g.y }, direction = g.dir,
        force = force, player = player, expires = false })
      if not (gh and gh.valid) then return abort("fantome : " .. g.name) end
      ghost_ents[#ghost_ents + 1] = gh
      if g.of and ents[g.of] and not copy_into(gh, ents[g.of]) then out.settings_failed = out.settings_failed + 1 end
      req.ghosts[#req.ghosts + 1] = { u = gh.unit_number, x = gh.position.x, y = gh.position.y, n = intern(g.name), d = gh.direction or 0,
        g = gi, m = (g.of and mark_index[g.of]) or 0 }
      out.ghosts[#out.ghosts + 1] = { name = g.name, x = gh.position.x, y = gh.position.y, dir = gh.direction }
      if not g.of then out.links[#out.links + 1] = { name = g.name, x = gh.position.x, y = gh.position.y } end
    end
  end
  for _, w in ipairs(plan.warnings) do out.warnings[#out.warnings + 1] = w.why end
  st.next = req.id
  st.list[#st.list + 1] = req
  stat("requests")
  stat("marked", #req.marks)
  stat("ghosts", #req.ghosts)
  draw_plan(entity, B, plan, recs, player, Levels.CONTOUR_TTL, nil)
  -- Messages : ce qui est marqué, posé ; objets en plus à fournir ; liaisons de mur ; fils de circuit.
  local side = L.footprint(family, level + 1)
  tell(req, { "fo-levels-taille.free-started", "[entity=" .. entity.name .. "]", side .. "×" .. side, #req.marks, #req.ghosts })
  local extra, have = {}, {}
  for _, m in ipairs(out.marks) do have[m.name] = (have[m.name] or 0) + 1 end
  for _, g in ipairs(out.ghosts) do
    if (have[g.name] or 0) > 0 then have[g.name] = have[g.name] - 1 else extra[#extra + 1] = "[entity=" .. g.name .. "]" end
  end
  if #extra > 0 then tell(req, { "fo-levels-taille.free-items", count_text(extra) }) end
  if #out.links > 0 then tell(req, { "fo-levels-taille.free-wall-links", #out.links, where_text(out.links) }) end
  if #out.warnings > 0 then tell(req, { "fo-levels-taille.free-wall-open" }) end
  if out.wired > 0 then tell(req, { "fo-levels-taille.free-wired", out.wired }) end
  log("[FO-LEVELS] liberer la place : " .. entity.name .. " en " .. req.x .. ", " .. req.y .. " -> carre " .. B.x0 .. "," .. B.y0
    .. " a " .. B.x1 .. "," .. B.y1 .. " (candidate " .. ci .. ", " .. tried .. " essayee(s)) ; " .. #req.marks .. " marque(s), "
    .. #req.ghosts .. " fantome(s), " .. #out.links .. " liaison(s), " .. #extra .. " objet(s) en plus, " .. #out.warnings .. " avertissement(s)")
  return out
end

---------------------------------------------------------------------------------------------------
-- Annuler, expirer, finir : l'usine est remise comme avant
---------------------------------------------------------------------------------------------------
--- Boîte de collision (carte) du prototype `name` posé en (x, y), direction d (boîte tournée d'un quart pour est et
--- ouest).
local function proto_box(name, x, y, d)
  local p = game.entity_prototypes[name]
  if not p then return nil end
  local cb = p.collision_box
  local x0, y0, x1, y1 = cb.left_top.x, cb.left_top.y, cb.right_bottom.x, cb.right_bottom.y
  if d == 2 or d == 6 then x0, y0, x1, y1 = -y1, x0, -y0, x1 end
  return { x0 = x + x0, y0 = y + y0, x1 = x + x1, y1 = y + y1 }
end

--- La place d'origine `box` est-elle reprenable par un fantôme ? Ce qui la touche (chevauchement strict, F96) ne doit
--- pas rester : un fantôme y est refusé (sauf ceux de `ignore`, numéros d'unité), une entité seulement si elle est
--- marquée à démonter (elle part) ; les entités sans couche des objets (décor, cadavre) ne comptent pas.
local function place_free(surface, box, ignore)
  for _, o in ipairs(surface.find_entities_filtered({ area = { { box.x0, box.y0 }, { box.x1, box.y1 } } })) do
    if o.valid and not NON_BLOCKING[o.type] and o.type ~= "resource" then
      local ob = o.bounding_box
      local r = { x0 = ob.left_top.x, y0 = ob.left_top.y, x1 = ob.right_bottom.x, y1 = ob.right_bottom.y }
      if Foot.overlap(box, r) then
        if o.type == "entity-ghost" then
          if not (o.unit_number and ignore[o.unit_number]) then return false end
        elseif not o.to_be_deconstructed() and has_object_layer(o) then
          return false
        end
      end
    end
  end
  return true
end

local function ent_box(e)
  local bb = e.bounding_box
  return { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
end

--- Retire la demande d'indice i et REMET L'USINE COMME AVANT (correction V3-T3, défaut 11 ; remplace « un groupe
--- commencé est gardé entier », qui reconstruisait un bras décalé pour un bâtiment qui ne grandissait plus) :
---   a. fantômes du mod déjà CONSTRUITS (revive : nouveau numéro, E58) : l'entité construite est marquée à démonter ;
---   b. chaque gêneur déjà démonté a une place d'origine : contrôlée (place_free) ; sa source de réglages est un de ses
---      fantômes décalés (de préférence un qui ne recouvre aucune place d'origine) ou l'entité construite ;
---   c. fantômes du mod encore fantômes qui ne servent pas de source, ou qui recouvrent une place d'origine : retirés ;
---   d. fantômes d'ORIGINE posés (même nom, place et orientation d'origine), réglages recopiés ;
---   e. fantômes sources restants retirés ;
---   f. marques du mod encore posées : annulées, en DERNIER (F103 : annuler la marque d'une entité sous un fantôme
---      retire ce fantôme ; un fantôme décalé posé sur une tuile marquée disparaîtrait avant qu'on lise ses réglages).
---      Aucun fantôme d'origine n'est posé sur une entité dont la marque est annulée (deux entités d'origine ne se
---      chevauchent pas).
--- Rien d'autre n'est touché : seulement les marques, fantômes et entités construites de CETTE demande. Place
--- d'origine prise : comptée et dite (position [gps]) ; l'objet n'est pas perdu (inventaire du robot ou du joueur).
--- Renvoie { unmarked, removed, unbuilt, restored, blocked }.
local function rollback(i, why)
  local st = F()
  local req = table.remove(st.list, i)
  local surface = game.surfaces[req.surface]
  local force = game.forces[req.force]
  local player = player_of(req)
  local res = { unmarked = 0, removed = 0, unbuilt = 0, restored = 0, blocked = 0 }
  if not (surface and force) then return res end
  local present, keep = {}, {}
  for k, m in ipairs(req.marks) do
    local e = find_rec(surface, m)
    present[k] = e
    if e and e.unit_number then keep[e.unit_number] = true end
  end
  -- Places d'origine des gêneurs déjà démontés.
  local origin = {}
  for k, m in ipairs(req.marks) do
    if not present[k] and not m.nat then
      local name = name_of(m.n)
      origin[k] = { name = name, box = name and proto_box(name, m.x, m.y, m.d) or nil }
    end
  end
  -- a. et b. Fantômes : encore fantômes, ou construits (marqués à démonter) ; sources de réglages.
  local ghosts, sources = {}, {}
  for _, g in ipairs(req.ghosts) do
    local gh = find_ghost(surface, g)
    local src = gh
    if gh then
      ghosts[#ghosts + 1] = gh
    else
      local built = find_built(surface, g, force, keep)
      if built then
        src = built
        if not built.to_be_deconstructed() and built.order_deconstruction(force, player) then res.unbuilt = res.unbuilt + 1 end
      end
    end
    local k = g.m or 0
    local o = origin[k]
    if src and o and req.marks[k].n == g.n then
      -- Recouvre-t-il une place d'origine (la sienne ou celle d'un autre gêneur démonté) ?
      local covers = false
      local sb = ent_box(src)
      for kk = 1, #req.marks do
        local oo = origin[kk]
        if oo and oo.box and Foot.overlap(sb, oo.box) then covers = true end
      end
      local cur = sources[k]
      if not cur or (cur.covers and not covers) then sources[k] = { e = src, covers = covers } end
    end
  end
  -- c. Fantômes du mod retirés, sauf les sources qui ne recouvrent aucune place d'origine (gardées jusqu'en e).
  local keep_src = {}
  for k = 1, #req.marks do
    local s = sources[k]
    if s and not s.covers and s.e.valid and s.e.type == "entity-ghost" then keep_src[s.e.unit_number] = true end
  end
  for _, gh in ipairs(ghosts) do
    if gh.valid and not keep_src[gh.unit_number] then
      gh.destroy({ raise_destroy = true })
      res.removed = res.removed + 1
    end
  end
  -- d. Fantômes d'origine.
  local blocked_list = {}
  for k, m in ipairs(req.marks) do
    local o = origin[k]
    if o then
      local ok = o.box ~= nil and place_free(surface, o.box, keep_src)
      local gh = ok and surface.create_entity({ name = "entity-ghost", inner_name = o.name, position = { m.x, m.y }, direction = m.d,
        force = force, player = player, expires = false }) or nil
      if gh and gh.valid then
        local s = sources[k]
        if s and s.e.valid then copy_into(gh, s.e) end
        res.restored = res.restored + 1
      else
        res.blocked = res.blocked + 1
        blocked_list[#blocked_list + 1] = { name = o.name or "?", x = m.x, y = m.y }
      end
    end
  end
  -- e. Sources restantes retirées.
  for _, gh in ipairs(ghosts) do
    if gh.valid then
      gh.destroy({ raise_destroy = true })
      res.removed = res.removed + 1
    end
  end
  -- f. Marques du mod annulées (en dernier : F103).
  for k = 1, #req.marks do
    local e = present[k]
    if e and e.valid and e.to_be_deconstructed() then
      e.cancel_deconstruction(force, player)
      res.unmarked = res.unmarked + 1
    end
  end
  stat("unmarked", res.unmarked)
  stat("ghosts_removed", res.removed)
  stat("unbuilt", res.unbuilt)
  stat("restored", res.restored)
  stat("restore_blocked", res.blocked)
  stat(why == "expired" and "expired" or (why == "gone" and "gone" or "cancelled"))
  local key = why == "expired" and "free-expired" or (why == "gone" and "free-gone" or "free-cancelled")
  tell(req, { "fo-levels-taille." .. key, res.unmarked, res.removed })
  if res.restored > 0 or res.unbuilt > 0 then tell(req, { "fo-levels-taille.free-restored", res.restored, res.unbuilt }) end
  if res.blocked > 0 then tell(req, { "fo-levels-taille.free-restore-blocked", res.blocked, where_text(blocked_list) }) end
  log("[FO-LEVELS] liberer la place : demande " .. req.id .. " retiree (" .. tostring(why) .. ") : " .. res.unmarked
    .. " marque(s) annulee(s), " .. res.removed .. " fantome(s) retire(s), " .. res.unbuilt .. " construit(s) remis a demonter, "
    .. res.restored .. " remis a l'origine, " .. res.blocked .. " place(s) prise(s)")
  return res
end

--- Annule la demande de `entity` (bouton « Annuler », interface distante). Renvoie le bilan, ou nil sans demande.
function Free.cancel(entity, why)
  if not (entity and entity.valid) then return nil end
  for i, r in ipairs(F().list) do
    if r.unit == entity.unit_number then return rollback(i, why or "cancelled") end
  end
  return nil
end

--- Une demande : "wait" (place encore prise, ou coût qui manque), "done", ou retirée (annulée, expirée, disparue).
local function step(i)
  local st = F()
  local req = st.list[i]
  local e = find_building(req)
  if not e then
    rollback(i, "gone")
    return "gone"
  end
  local _, lv = L.parse(e.name)
  if lv and lv >= req.next then
    -- Amélioré par une autre voie (bouton « Améliorer », touche U : le crochet Levels.pending_box les a menés au
    -- carré libéré) : demande accomplie.
    table.remove(st.list, i)
    stat("done")
    return "done"
  end
  if game.tick >= req.expire then
    rollback(i, "expired")
    return "expired"
  end
  local player = player_of(req)
  local payer = (player and player.connected) and player or nil
  -- Attente : recensement Q16 EN CACHE (centre seulement ; Levels.census_cached) ; la décision (Levels.start) le refait
  -- en entier.
  local info = Levels.preview(e, payer, false, { box = req.box })
  if not (info and info.room and #info.room.candidates > 0) then
    -- Plus de changement d'emprise, ou le carré demandé n'est plus une position permise (bâtiment changé) : retirée.
    rollback(i, "gone")
    return "gone"
  end
  if not info.room.chosen then
    draw_pending(e, req, payer)
    return "wait"
  end
  if info.ok then
    local ok, reason, _, new = Levels.start(e, payer, { box = req.box })
    if ok then
      -- La demande a pu suivre le bâtiment (crochet on_replaced) : retrouvée par son identifiant.
      for k, r in ipairs(st.list) do
        if r.id == req.id then table.remove(st.list, k) break end
      end
      stat("done")
      tell(req, { "fo-levels-taille.free-done", "[entity=" .. new.name .. "]", new.position.x, new.position.y })
      log("[FO-LEVELS] liberer la place : demande " .. req.id .. " accomplie : " .. new.name .. " en " .. new.position.x .. ", " .. new.position.y)
      return "done"
    end
    info.reason = reason
    if reason == "no-room" then
      draw_pending(e, req, payer)
      return "wait"
    end
  end
  if info.reason == "max" or info.reason == "not-levelable" then
    rollback(i, "gone")
    return "gone"
  end
  -- Coût qui manque (ou autre motif passager : condition Q16…) : un message, la demande attend (jusqu'à expiration).
  if not req.warned then
    req.warned = game.tick
    if info.reason == "no-resources" then
      tell(req, { "fo-levels-taille.free-no-resources", "[entity=" .. e.name .. "]" })
    else
      tell(req, { "fo-levels-taille.free-waiting", "[entity=" .. e.name .. "]" })
    end
  end
  draw_pending(e, req, payer)
  return "wait"
end

--- Vérifie toutes les demandes, dans l'ordre de création. Liste vide : rien d'autre que ce test. Renvoie le nombre de
--- demandes accomplies.
function Free.check()
  local list = F().list
  if #list == 0 then return 0 end
  local done = 0
  local ids = {}
  for _, r in ipairs(list) do ids[#ids + 1] = r.id end
  for _, id in ipairs(ids) do
    local cur = F().list
    for i, r in ipairs(cur) do
      if r.id == id then
        if step(i) == "done" then done = done + 1 end
        break
      end
    end
  end
  return done
end

Events.on_nth_tick(Free.PERIOD, function()
  Free.check()
end)

--- Point d'entrée « testable sans joueur » demandé pour le lot, aussi sous le nom Levels.free_room.
Levels.free_room = Free.free_room

-- Le bâtiment remplacé (amélioration, migration) est une NOUVELLE entité : la demande la suit.
table.insert(Levels.on_replaced, function(old_unit, new)
  for _, r in ipairs(F().list) do
    if r.unit == old_unit then
      r.unit = new.unit_number
      r.x, r.y = new.position.x, new.position.y
    end
  end
end)

--- État des demandes, en données simples (interface distante, banc).
function Free.status()
  local st = F()
  local out = { stats = {}, requests = {} }
  local keys = {}
  for k in pairs(st.stats) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do out.stats[k] = st.stats[k] end
  for _, r in ipairs(st.list) do
    local e = find_building(r)
    out.requests[#out.requests + 1] = { id = r.id, unit = r.unit, name = e and e.name or nil, x = r.x, y = r.y, next = r.next,
      box = box_copy(r.box), marks = #r.marks, ghosts = #r.ghosts, tick = r.tick, expire = r.expire, warned = r.warned }
  end
  return out
end

return Free
