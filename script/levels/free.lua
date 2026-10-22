--[[
  Niveaux : bouton « LIBÉRER LA PLACE » et AGRANDISSEMENT EN ATTENTE (lot V3-T3 ; Q-T2-1, réponse du Directeur
  Créatif le 22/10 à 21 h 06 : « QT21 option B » : « On garde la règle, et j'ajoute un bouton "libérer la place". Il
  marque les gêneurs à démonter par les robots et pose des fantômes pour les reconstruire décalés. »).

  La règle Q24 ne change pas : sans clic, refus « no-room » et contour, comme avant. Au clic (panneau « Évolution »,
  ou interface distante levels_free_room pour le banc) :
    1. la candidate que montre déjà le contour (Levels.room : target, la plus facile à libérer) est retenue ;
    2. la scène autour est relevée (entités et tuiles, données simples), la règle de décalage PURE
       (shared/levels/clear.lua, C.plan) dit quoi démonter et où reposer chaque gêneur ;
    3. chaque gêneur reposable est MARQUÉ à démonter (order_deconstruction, force du bâtiment, le joueur comme
       dernier utilisateur) : les robots de construction le démontent, sinon le joueur le mine à la main ; le mod ne
       détruit jamais un gêneur, aucun objet n'est perdu ; un FANTÔME (entity-ghost, sans expiration) le reconstruit
       décalé, même nom, même orientation, à une place libre ; ce qu'on ne sait pas reposer (bâtiment voisin,
       falaise, autre force, eau…) est SIGNALÉ (message, et rectangle rouge au sol) ;
    4. une DEMANDE d'agrandissement est gardée (global, données simples, liste ordonnée) et vérifiée toutes les
       Free.PERIOD ticks (liste vide : rien d'autre qu'un test) ; dès que la place de CETTE candidate est libre,
       l'amélioration se fait (Levels.start, paiement à ce moment-là : centre puis inventaire du joueur) ; coût qui
       manque : message, la demande attend encore ; au-delà de Free.TTL ticks, elle expire ;
    5. « Annuler » (ou l'expiration, ou le bâtiment disparu) retire la demande, annule les marques posées PAR LE MOD et
       retire les fantômes posés PAR LE MOD, et seulement ceux-là, groupe par groupe : un groupe déjà commencé (un de
       ses gêneurs déjà démonté) est gardé entier (ses fantômes reconstruisent ce qui a été démonté ; sinon le bras
       serait perdu), et c'est dit.
  Déterminisme : tout se passe dans des événements ; scène triée (y, x, nom, numéro) ; demandes dans l'ordre de
  création ; aucune décision pilotée par un temps mesuré ; rien que des nombres et des noms de prototypes dans global
  (aucune référence d'entité : une entité est retrouvée par sa position, son nom et son numéro).
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
--- Marge de la scène autour du nouveau carré (tuiles) : bosse de convoyeur, liaisons de murs, fils de poteau.
Free.REACH = 4
--- Au plus tant de lignes « à retirer à la main » dans un message.
Free.MAX_LIST = 12

-- Demandes, NOMBRES SEULEMENT (consigne du lot) : list = { { id, unit, surface (index), x, y, level, next,
-- box = { x0, y0, x1, y1 }, force (index), player (index ou nil), tick, expire, marks, ghosts, signalled, warned } } ;
-- marks / ghosts = { { u (numéro d'unité ; nil pour un arbre ou un rocher, qui n'en ont pas), x, y, g (groupe) } }.
-- Une entité est retrouvée par sa position et son numéro (un arbre : la seule entité sans numéro à cette position).
Storage.declare("levels_free", function()
  return { list = {}, next = 0, stats = { requests = 0, done = 0, cancelled = 0, expired = 0, gone = 0, marked = 0,
    ghosts = 0, unmarked = 0, ghosts_removed = 0, kept = 0, signalled = 0 } }
end)

local function F() return Storage.ns("levels_free") end

local function stat(k, n)
  local s = F().stats
  s[k] = (s[k] or 0) + (n or 1)
end

local NON_BLOCKING = { character = true, unit = true, ["item-entity"] = true }

--- Demande en cours pour ce bâtiment (numéro d'unité), ou nil.
function Free.request_of(entity)
  if not (entity and entity.valid and entity.unit_number) then return nil end
  for _, r in ipairs(F().list) do
    if r.unit == entity.unit_number then return r end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Retrouver une entité (global ne garde que des données simples)
---------------------------------------------------------------------------------------------------
--- Entité marquée par le mod : même position, même numéro (un arbre, un rocher : la seule entité SANS numéro à cette
--- position, hors fantômes).
local function find_rec(surface, rec)
  if not surface then return nil end
  for _, e in ipairs(surface.find_entities_filtered({ position = { rec.x, rec.y } })) do
    if e.valid and e.type ~= "entity-ghost" and e.type ~= "resource" and e.unit_number == rec.u and math.abs(e.position.x - rec.x) < Clear.TOL
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

--- « [entity=a]×2 [entity=b] … » (texte enrichi du moteur), trié, au plus Free.MAX_LIST sortes.
local function names_text(names)
  local count, keys = {}, {}
  for _, n in ipairs(names) do
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

---------------------------------------------------------------------------------------------------
-- Scène (données simples pour shared/levels/clear.lua)
---------------------------------------------------------------------------------------------------
local function has_object_layer(e)
  local m = e.prototype.collision_mask
  return m and m["object-layer"] and true or false
end

--- Relève la scène autour du carré B : entités (sauf le bâtiment, les personnages, unités et objets au sol, et ce
--- qui ne touche pas la couche des objets : ressources, décors, cadavres), fantômes compris (obstacles), triées. Renvoie
--- recs (pour Clear.plan) et ents (entités du moteur, même index ; jamais gardées dans global).
local function relever(entity, B)
  local surface = entity.surface
  local R = Free.REACH
  local area = { { B.x0 - R, B.y0 - R }, { B.x1 + R, B.y1 + R } }
  local found = {}
  for _, e in ipairs(surface.find_entities_filtered({ area = area })) do
    if e.valid and e ~= entity and not NON_BLOCKING[e.type] and (e.type == "entity-ghost" or has_object_layer(e)) then
      found[#found + 1] = e
    end
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
    if e.type ~= "entity-ghost" then r.marked = e.to_be_deconstructed() end
    if e.type == "inserter" then
      local pp, dp = e.pickup_position, e.drop_position
      r.pick, r.drop = { x = pp.x, y = pp.y }, { x = dp.x, y = dp.y }
    elseif e.type == "electric-pole" then
      r.reach = e.prototype.max_wire_distance
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
  -- Tuiles bloquantes autour (eau, hors carte) : aucun fantôme n'y est posé.
  local tiles = {}
  for y = B.y0 - R, B.y1 + R - 1 do
    for x = B.x0 - R, B.x1 + R - 1 do
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
-- Dessin : contour, gêneurs signalés
---------------------------------------------------------------------------------------------------
--- Contour orange du carré ; au clic seulement (plan) : gêneurs marqués en jaune (les robots les démontent), places des
--- fantômes en bleu clair (où ils seront reconstruits), gêneurs signalés en rouge (à retirer à la main).
local function draw(entity, B, signals, recs, player, ttl, plan)
  local surface = entity.surface
  local players = (player and player.valid) and { player.index } or nil
  local forces = (not players) and { entity.force.name } or nil
  local function rect(x0, y0, x1, y1, color, width, filled)
    rendering.draw_rectangle({ color = color, width = width, filled = filled, left_top = { x0, y0 }, right_bottom = { x1, y1 },
      surface = surface, time_to_live = ttl, players = players, forces = forces })
  end
  rect(B.x0, B.y0, B.x1, B.y1, { r = 1, g = 0.55, b = 0.1, a = 0.9 }, 3, false)
  if plan then
    -- Marques un peu plus larges que leur boîte : un fantôme posé sur la même tuile (convoyeur tourné) reste visible
    -- dedans.
    for _, id in ipairs(plan.marks) do
      local b = recs[id] and recs[id].box
      if b then rect(b.x0 - 0.08, b.y0 - 0.08, b.x1 + 0.08, b.y1 + 0.08, { r = 1, g = 0.9, b = 0.1, a = 0.9 }, 2, false) end
    end
    for _, g in ipairs(plan.ghosts) do
      rect(g.box.x0, g.box.y0, g.box.x1, g.box.y1, { r = 0.3, g = 0.8, b = 1, a = 0.9 }, 2, false)
    end
  end
  for _, s in ipairs(signals or {}) do
    if s.id and recs[s.id] then
      local b = recs[s.id].box
      rect(b.x0, b.y0, b.x1, b.y1, { r = 1, g = 0.1, b = 0.1, a = 0.9 }, 3, false)
    elseif s.tile then
      rect(s.tile.x, s.tile.y, s.tile.x + 1, s.tile.y + 1, { r = 0.6, g = 0.05, b = 0.05, a = 0.35 }, 1, true)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Libérer la place
---------------------------------------------------------------------------------------------------
--- Lance « libérer la place » pour `entity` (opts.player : joueur qui clique, ou nil pour le banc). Renvoie une table
--- de données simples : { ok, reason, id, box, marked, ghosts = { {name, x, y, dir} }, marks = { {name, x, y} },
--- signalled = { {name, x, y, why} }, warnings = { why } }. reason : "pending" (demande créée), "room-free" (la
--- place est déjà libre : améliorer suffit), "already" (une demande existe), "too-many", ou le motif d'aperçu qui
--- empêche tout agrandissement (« max », « cc-too-low »…).
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
  if info.reason ~= "no-room" and info.reason ~= "no-resources" then return { ok = false, reason = info.reason } end
  local target = room.target
  if not target then return { ok = false, reason = "no-target" } end
  local B = target.box
  local recs, ents, area_tiles = relever(entity, B)
  local blockers = {}
  for _, g in ipairs(target.entities or {}) do
    local id = scene_id(recs, g)
    if id then blockers[#blockers + 1] = id end
  end
  local moved = {}
  for _, m in ipairs(target.moved or {}) do
    local id = scene_id(recs, m)
    if id then
      for _, pt in ipairs(room.points or {}) do
        if pt.entity == m then
          moved[#moved + 1] = { id = id, old = { x = pt.x, y = pt.y }, new = { x = target.x + pt.rel.x, y = target.y + pt.rel.y } }
          break
        end
      end
    end
  end
  local bb = entity.bounding_box
  local plan = Clear.plan({
    new_box = B, old_rect = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y },
    scene = recs, blockers = blockers, moved = moved, tiles = target.tiles, area_tiles = area_tiles,
    connector = L.name(L.by_key.wall, 1),
  })
  if plan.too_many then return { ok = false, reason = "too-many" } end

  -- Exécution : marques puis fantômes, groupe par groupe.
  local st = F()
  st.next = (st.next or 0) + 1
  local surface, force = entity.surface, entity.force
  local req = { id = st.next, unit = entity.unit_number, surface = surface.index,
    x = entity.position.x, y = entity.position.y, level = level, next = level + 1,
    box = { x0 = B.x0, y0 = B.y0, x1 = B.x1, y1 = B.y1 }, force = force.index, player = player and player.index or nil,
    tick = game.tick, expire = game.tick + Free.TTL, marks = {}, ghosts = {}, signalled = 0 }
  local out = { ok = true, reason = "pending", id = req.id, box = req.box, marks = {}, ghosts = {}, signalled = {}, warnings = {},
    already = 0, wired = 0 }
  for gi, G in ipairs(plan.groups) do
    -- Tout ou rien, aussi à l'exécution : une marque refusée par le moteur (entité non démontable) annule les marques
    -- déjà posées du groupe, et aucun de ses fantômes n'est posé (il tomberait sur une entité qui reste).
    local done_marks, failed = {}, nil
    for _, id in ipairs(G.marks) do
      local e = ents[id]
      if e and e.valid then
        if e.to_be_deconstructed() then
          out.already = out.already + 1
        elseif e.order_deconstruction(force, player) then
          done_marks[#done_marks + 1] = id
        else
          failed = e
          break
        end
      end
    end
    if failed then
      for _, id in ipairs(done_marks) do ents[id].cancel_deconstruction(force, player) end
      out.signalled[#out.signalled + 1] = { name = failed.name, x = failed.position.x, y = failed.position.y, why = "non demontable" }
      G = { ghosts = {} }
    end
    for _, id in ipairs(failed and {} or done_marks) do
      local e, r = ents[id], recs[id]
      req.marks[#req.marks + 1] = { u = e.unit_number, x = e.position.x, y = e.position.y, g = gi }
      out.marks[#out.marks + 1] = { name = e.name, x = e.position.x, y = e.position.y }
      if r.wired then out.wired = out.wired + 1 end
    end
    for _, g in ipairs(G.ghosts) do
      local gh = surface.create_entity({ name = "entity-ghost", inner_name = g.name, position = { g.x, g.y }, direction = g.dir,
        force = force, player = player, expires = false })
      if gh and gh.valid then
        req.ghosts[#req.ghosts + 1] = { u = gh.unit_number, x = gh.position.x, y = gh.position.y, g = gi }
        out.ghosts[#out.ghosts + 1] = { name = g.name, x = gh.position.x, y = gh.position.y, dir = gh.direction }
      end
    end
  end
  for _, s in ipairs(plan.signals) do
    if s.id then
      local r = recs[s.id]
      out.signalled[#out.signalled + 1] = { name = r.name, x = r.x, y = r.y, why = s.why }
    elseif s.tile then
      out.signalled[#out.signalled + 1] = { name = "tile:" .. s.tile.name, x = s.tile.x, y = s.tile.y, why = s.why }
    else
      out.signalled[#out.signalled + 1] = { name = "?", why = s.why }
    end
  end
  for _, w in ipairs(plan.warnings) do out.warnings[#out.warnings + 1] = w.why end
  req.signalled = #out.signalled
  st.list[#st.list + 1] = req
  stat("requests")
  stat("marked", #req.marks)
  stat("ghosts", #req.ghosts)
  stat("signalled", #out.signalled)
  draw(entity, B, plan.signals, recs, player, Levels.CONTOUR_TTL, plan)
  -- Message : ce qui est marqué, posé, à retirer à la main.
  local sig_names = {}
  for _, s in ipairs(out.signalled) do
    sig_names[#sig_names + 1] = s.name:sub(1, 5) == "tile:" and ("[tile=" .. s.name:sub(6) .. "]") or ("[entity=" .. s.name .. "]")
  end
  local side = L.footprint(family, level + 1)
  tell(req, { "fo-levels-taille.free-started", "[entity=" .. entity.name .. "]", side .. "×" .. side, #req.marks, #req.ghosts })
  if #sig_names > 0 then tell(req, { "fo-levels-taille.free-signalled", names_text(sig_names) }) end
  if #out.warnings > 0 then tell(req, { "fo-levels-taille.free-wall-open" }) end
  if out.wired > 0 then tell(req, { "fo-levels-taille.free-wired", out.wired }) end
  log("[FO-LEVELS] liberer la place : " .. entity.name .. " en " .. req.x .. ", " .. req.y .. " -> carre " .. B.x0 .. "," .. B.y0
    .. " a " .. B.x1 .. "," .. B.y1 .. " ; " .. #req.marks .. " marque(s), " .. #req.ghosts .. " fantome(s), " .. #out.signalled
    .. " signale(s), " .. #out.warnings .. " avertissement(s)")
  return out
end

---------------------------------------------------------------------------------------------------
-- Annuler, expirer, finir
---------------------------------------------------------------------------------------------------
--- Retire la demande d'indice i : annule les marques et retire les fantômes posés par le mod, groupe par groupe ; un
--- groupe déjà commencé (une de ses entités marquées a disparu : démontée) est gardé entier. Renvoie
--- { unmarked, removed, kept }.
local function rollback(i, why)
  local st = F()
  local req = table.remove(st.list, i)
  local surface = game.surfaces[req.surface]
  local force = game.forces[req.force]
  local player = player_of(req)
  local started = {}
  local found = {}
  for k, m in ipairs(req.marks) do
    local e = find_rec(surface, m)
    found[k] = e
    if not e then started[m.g] = true end
  end
  local res = { unmarked = 0, removed = 0, kept = 0 }
  -- Fantômes D'ABORD (moteur réel, 22/10, F103 provisoire) : annuler la marque d'une entité sur laquelle un fantôme a
  -- été posé (convoyeur tourné, bras sur la tuile d'un convoyeur) retire ce fantôme : retirés après, ils n'étaient
  -- plus trouvés ni comptés.
  for _, g in ipairs(req.ghosts) do
    local gh = find_ghost(surface, g)
    if gh then
      if started[g.g] then
        res.kept = res.kept + 1
      else
        gh.destroy({ raise_destroy = true })
        res.removed = res.removed + 1
      end
    end
  end
  for k, m in ipairs(req.marks) do
    local e = found[k]
    if e and e.valid and not started[m.g] and e.to_be_deconstructed() and force then
      e.cancel_deconstruction(force, player)
      res.unmarked = res.unmarked + 1
    end
  end
  stat("unmarked", res.unmarked)
  stat("ghosts_removed", res.removed)
  stat("kept", res.kept)
  stat(why == "expired" and "expired" or (why == "gone" and "gone" or "cancelled"))
  local key = why == "expired" and "free-expired" or (why == "gone" and "free-gone" or "free-cancelled")
  tell(req, { "fo-levels-taille." .. key, res.unmarked, res.removed })
  if res.kept > 0 then tell(req, { "fo-levels-taille.free-kept", res.kept }) end
  log("[FO-LEVELS] liberer la place : demande " .. req.id .. " retiree (" .. tostring(why) .. ") : " .. res.unmarked
    .. " marque(s) annulee(s), " .. res.removed .. " fantome(s) retire(s), " .. res.kept .. " garde(s)")
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
    -- Amélioré par une autre voie (bouton « Améliorer », touche U) une fois la place libre : demande accomplie.
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
    -- Place encore prise (quel que soit l'autre motif : le coût n'est vérifié qu'une fois la place libre). Contour
    -- gardé au sol tant que la demande attend (jusqu'à la vérification suivante).
    draw(e, req.box, nil, nil, payer, Free.PERIOD + 2)
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
    -- Place reprise entre l'aperçu et la décision (aucun cas connu) : la demande attend encore.
    if reason == "no-room" then return "wait" end
  end
  if info.reason == "no-resources" then
    if not req.warned then
      req.warned = game.tick
      tell(req, { "fo-levels-taille.free-no-resources", "[entity=" .. e.name .. "]" })
    end
    draw(e, req.box, nil, nil, payer, Free.PERIOD + 2)
    return "wait"
  end
  rollback(i, "cancelled")
  return "cancelled"
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
      box = { x0 = r.box.x0, y0 = r.box.y0, x1 = r.box.x1, y1 = r.box.y1 }, marks = #r.marks, ghosts = #r.ghosts,
      signalled = r.signalled, tick = r.tick, expire = r.expire, warned = r.warned }
  end
  return out
end

return Free
