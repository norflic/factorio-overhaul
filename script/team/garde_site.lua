--[[
  Lot PERIMETRE2 « garde des sites », côté RUNTIME (règle pure : shared/team/garde_site.lua ; diagnostic et proposition :
  fo-logs/2026-11-04_PERIMETRE2/RAPPORT.md ; accord du lead et QCM du DC du 4/11 18 h 05 « Oui, enceinte et avant-postes »). Votre équipe.

    - on_entity_died : un bâtiment de votre équipe détruit près d'un avant-poste : la vague (unités ennemies à 30 tuiles) est notée au site.
    - on_player_mined_entity / on_robot_mined_entity : un mur retiré par le JOUEUR sur une tuile d'un segment de murs de l'équipe (index par
      tuile des projets spec.enceinte, tenu par les seuls projets nouveaux : aucun parcours) : tuile RENDUE au joueur pour toujours
      (f.build.walls_released), pièce abandonnée (e.dropped) : jamais reposée ni replanifiée. Un mur du joueur hors de ces tuiles : rien retenu.
    - Build.wall_mask (crochet posé ici, lu par plan_enceinte de script/team/build.lua) : tuiles jamais murées : rendues, ou dans l'usine du
      joueur (à moins de Gs.PLAYER_GAP tuiles d'un bâtiment de la force qui n'est pas à l'équipe). Build.wall_veto (crochet de revive_one) :
      la même règle REVÉRIFIÉE au moment de poser le fantôme d'un mur (le joueur a pu bâtir depuis le plan) : pièce abandonnée.
    - Build.outpost_walls (crochet, appelé par Build.space_step toutes les 30 s) : anneau de murs autour d'un avant-poste ATTAQUÉ, segment par
      segment, payé en pierre (murs fabriqués par la machinerie de l'enceinte), réparé comme l'enceinte. Avant-poste disparu : son anneau est
      oublié (ni réparé ni rouvert, chantier annulé) ; avant-poste agrandi : l'ancien anneau est jeté et refait autour de la nouvelle emprise.
    - Gd.view (Team.view) : le site à servir (G1) et le budget (G2 : fer accordé par DEPENSES, sinon repli) ; écrit f.team.depenses.defense_want.
      DEPENSES : Dep.defense(f, tick) -> (accord, info) ; repli quand le module manque, rend autre chose qu'une table, info.etat ~= "actif"
      (éteint, périmé), ou, sans info, une table vide ; l'accordé est DÉBITÉ de ce que la garde en dépense (Dep.debit s'il existe, sinon un
      compte local remis à zéro à chaque émission : info.tick, à défaut toutes les Gd.DEP_TTL).
    - Gd.place (tâche « fortify » du poste « garde ») : le groupe, par Outposts.fortify_at (propriétaire « garde<site> », ravitaillement par
      les tâches « refill » existantes). Gd.on_lost : porteur tué -> site au repos.
  Journal [FO-PERIMETRE] : une ligne par cause. État f.garde (nombres, chaînes, tables simples ; créé dans un événement, jamais à on_load).
  Déterminisme : listes triées, aucun `pairs` dans une décision, aucun temps mesuré.
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local P = require("shared.team.plan")
local Fr = require("shared.team.front")
local Gs = require("shared.team.garde_site")
local Outposts = require("script.faction.outposts")
local Build = require("script.team.build")
local Rsv = require("script.ai3.reserve")
local Stock = require("script.team.stock")
local Enc = require("shared.team.enceinte")
-- Budget de DEPENSES (lot parallèle, pas encore dans main) : chargé au CHARGEMENT du fichier (F24) ; absent ou d'une autre forme : repli.
local okDep, Dep = pcall(require, "script.ai3.depenses")
if not (okDep and type(Dep) == "table" and type(Dep.defense) == "function") then Dep = nil end

local Gd = {}

--- Bancs hors jeu seulement : remplace le module DEPENSES lu au chargement (nil : repli).
function Gd.set_dep(d) Dep = d end

Gd.OID = "garde"
Gd.PLAN_EVERY = 600      -- ticks : le site à servir est recalculé au plus aussi souvent (et après chaque pose)
Gd.CALM_R = Fr.CALM_R    -- tuiles : pas de pose tant qu'un ennemi est plus près du groupe
Gd.REST = 7200           -- ticks : repos d'un site après une pose nulle
Gd.LOGS = 150            -- lignes [FO-PERIMETRE] au plus
Gd.DEP_TTL = 3 * 3600    -- ticks : sans tick d'émission de DEPENSES, son accord est tenu pour neuf toutes les 3 min (son seuil de péremption)

local function iron_key() return T.outposts.iron.product end

--- G3 pour votre équipe : enceinte (T.enceinte_joueur) ou, pour un banc, f.garde_g3 (interface fo-garde, g3) ; jamais au banc témoin.
function Gd.g3(f) return f.is_player == true and not f.garde_temoin and (T.enceinte_joueur == true or f.garde_g3 == true) end
--- Murs des avant-postes attaqués : T.garde_walls_on, ou f.garde_g3 pour un banc ; jamais au banc témoin.
function Gd.walls_on(f) return f.is_player == true and not f.garde_temoin and (T.garde_walls_on == true or f.garde_g3 == true) end
local function stone_key() return T.outposts.stone and T.outposts.stone.product or nil end

local function state(f)
  local st = f.garde
  if not st then
    st = { waves = {}, rest = {}, picks = {}, logs = 0, poses = 0, walls = { segs = {}, claimed = {}, rings = {}, done = {} } }
    f.garde = st
  end
  return st
end

local function glog(f, st, text)
  st.logs = st.logs + 1
  if st.logs <= Gd.LOGS then log("[FO-PERIMETRE] " .. (f.key or "player") .. " : " .. text) end
end

--- Accord de DEPENSES pour la matière `key`, DÉBITÉ de ce que la garde en a déjà dépensé depuis son émission ; nil = repli : module absent,
--- réponse d'une autre forme, info.etat autre que « actif » (éteint, périmé), ou, sans info, table vide (forme de corr-depenses2 : vide =
--- éteint, périmé ou rien d'accordé ; le plancher de 2 000 et les 30 % bornent alors le repli).
function Gd.grant(f, tick, key)
  if not (Dep and key) then return nil end
  local st = state(f)
  local g, info = Dep.defense(f, tick)
  if type(g) ~= "table" then return nil end
  if type(info) == "table" and info.etat ~= nil then
    if info.etat ~= "actif" then return nil end
  elseif next(g) == nil then
    return nil
  end
  local v = tonumber(g[key]) or 0
  if type(Dep.debit) == "function" then return math.max(0, v) end -- DEPENSES tient lui-même le débit
  local emis = type(info) == "table" and tonumber(info.tick) or nil
  emis = emis or ("t" .. math.floor(tick / Gd.DEP_TTL))
  local d = st.dep
  if not d or d.emis ~= emis then
    d = { emis = emis, spent = {} }
    st.dep = d
  end
  return math.max(0, v - (d.spent[key] or 0))
end

--- Dépense de la garde sur l'accord de DEPENSES : débitée tout de suite (jamais dépensée deux fois entre deux émissions).
function Gd.debit(f, key, qty)
  if not (Dep and key and qty and qty > 0) then return end
  local st = state(f)
  if type(Dep.debit) == "function" then
    Dep.debit(f, "defense", key, qty)
  elseif st.dep then
    st.dep.spent[key] = (st.dep.spent[key] or 0) + qty
  end
end

--- Une entité de la force du joueur est-elle à votre équipe ? (propriétaire, adoptée, tuile réservée par le plan directeur, coffre, PNJ)
function Gd.team_owned(f, ent)
  if ent.type == "character" then return true end
  if f.hq and f.hq.valid and ent == f.hq then return true end
  local u = ent.unit_number
  if u then
    local o = State.owner(u)
    if o and o.f == f.id then return true end
    if f.adopt and f.adopt.units and f.adopt.units[u] then return true end
  end
  local b = f.build
  if b and b.occ then
    local p = ent.position
    if b.occ[P.tkey(math.floor(p.x), math.floor(p.y))] then return true end
  end
  return false
end

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

---------------------------------------------------------------------------------------------------
-- Vagues vues aux avant-postes
---------------------------------------------------------------------------------------------------
local function on_died(e)
  local ent, killer = e.entity, e.force
  if not (T.garde_site_on and ent and ent.valid and ent.force and killer) then return end
  local force = ent.force
  if force.name ~= "player" or killer.name == force.name or force.get_cease_fire(killer) then return end
  local f = State.faction("player")
  if not (f and f.outposts and not f.eliminated) then return end
  if ent.type == "character" or not Gd.team_owned(f, ent) then return end
  local pos = ent.position
  local best, bid
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    if o and o.pos then
      local d = (o.pos.x - pos.x) ^ 2 + (o.pos.y - pos.y) ^ 2
      if d <= 40 * 40 and (best == nil or d < best) then best, bid = d, oid end
    end
  end
  if not bid then return end
  local n = 0
  for _, u in ipairs(ent.surface.find_entities_filtered({ position = pos, radius = 30, type = "unit" })) do
    if u.valid and u.force.name ~= force.name and not force.get_cease_fire(u.force) then n = n + 1 end
  end
  local st = state(f)
  local w = st.waves[bid]
  local grew
  if w and Gs.wave_live(w.tick, e.tick) then
    grew = n > w.n
    if grew then w.n = n end
    w.tick = e.tick
  else
    st.waves[bid] = { n = n, tick = e.tick }
    grew = true
  end
  st.plan_tick = nil
  if grew then Gd.note_wave(f, st, bid, n, e.tick) end
end
Events.on(defines.events.on_entity_died, on_died)

---------------------------------------------------------------------------------------------------
-- Mesure du plancher de 2 000 fer (demande du lead, 5/11) : LECTURE SEULE, aucune décision ne lit st.meas ni st.last_budget
---------------------------------------------------------------------------------------------------
Gd.MEAS_LOGS = 120 -- lignes « vague » au plus

local function meas(st)
  local m = st.meas
  if not m then
    m = { plans = 0, zero = 0, why = {}, zero_min = 0, last_min = -1, waves = 0, wave_low = 0, wave_iron = {}, loss = {}, wlogs = 0 }
    st.meas = m
  end
  return m
end

--- Budget de la garde rendu par le planificateur à cette pensée (plan.garde : avant-poste choisi, permis, source, raison, fer compté).
function Gd.after_plan(f, pg, tick)
  if not (pg and f.is_player and f.garde) then return end
  local st = f.garde
  local m = meas(st)
  m.plans = m.plans + 1
  st.last_budget = { allowed = pg.allowed, source = pg.source, why = pg.why, iron = pg.iron, tick = tick, key = pg.key }
  if (pg.allowed or 0) == 0 then
    m.zero = m.zero + 1
    local w = pg.why or "?"
    m.why[w] = (m.why[w] or 0) + 1
    local mn = math.floor(tick / 3600)
    if mn ~= m.last_min then
      m.last_min = mn
      m.zero_min = m.zero_min + 1
    end
  end
end

--- Une vague nouvelle (ou plus grosse) à un avant-poste : fer au stock à ce moment.
function Gd.note_wave(f, st, oid, n, tick)
  local m = meas(st)
  local iron = Stock.count(f, iron_key())
  m.waves = m.waves + 1
  if iron < Gs.RICH_IRON then m.wave_low = m.wave_low + 1 end
  if #m.wave_iron < 400 then m.wave_iron[#m.wave_iron + 1] = iron end
  if m.wlogs < Gd.MEAS_LOGS then
    m.wlogs = m.wlogs + 1
    local lb = st.last_budget
    log(string.format("[FO-PERIMETRE] player : vague a l'avant-poste %s (%d ennemis) a %.1f min, fer au stock %d ; dernier budget de la garde : %s",
      tostring(oid), n, tick / 3600, iron, lb and string.format("%d tourelle(s) (%s, fer compte %d) a %.1f min", lb.allowed or 0, tostring(lb.why),
        lb.iron or 0, (lb.tick or 0) / 3600) or "aucun"))
  end
end

--- Une perte SENSIBLE à l'avant-poste `oid` : le groupe y était-il complet, voulu mais budget à 0 (et pourquoi), ou en attente ? (lecture seule)
function Gd.loss_class(f, oid, surface)
  local st = f.garde
  if not (st and T.garde_site_on and f.is_player) or f.garde_temoin then return "sans garde" end
  local o = oid and f.outposts and f.outposts[oid]
  if not (o and o.pos) then return "hors avant-poste" end
  local d = (st.dirs and st.dirs[oid]) or (st.vdir and st.vdir[oid])
  if not d then return "jamais vu par la garde" end
  local g = Gs.spots({ x = o.pos.x, y = o.pos.y }, d.nx, d.ny)
  local have = surface.count_entities_filtered({ position = g, radius = Gs.ACCEPT, force = f.force, type = R.TURRET_TYPES })
  local w = st.waves[oid]
  local want = Gs.want((w and Gs.wave_live(w.tick, game.tick)) and w.n or 0)
  if have >= want then return "groupe complet" end
  local lb = st.last_budget
  if lb and (lb.allowed or 0) == 0 then return "budget 0 (" .. tostring(lb.why or lb.source) .. ")" end
  return "groupe en attente"
end

function Gd.note_loss(f, cls)
  local st = f.garde
  if not st then return end
  local m = meas(st)
  m.loss[cls] = (m.loss[cls] or 0) + 1
end

--- Ligne du relevé de 5 min ([FO-PERTE], script/team/perte_log.lua) : de quoi juger le plancher sur données.
function Gd.meas_line(f, tick)
  local st = f.garde
  if not (st and f.is_player) then return end
  local m = meas(st)
  local why, loss = {}, {}
  for _, k in ipairs(State.sorted_keys(m.why)) do why[#why + 1] = k .. " " .. m.why[k] end
  for _, k in ipairs(State.sorted_keys(m.loss)) do loss[#loss + 1] = k .. " " .. m.loss[k] end
  local ir = {}
  for i, v in ipairs(m.wave_iron) do ir[i] = v end
  table.sort(ir)
  log(string.format("[FO-PERTE] player garde a %.1f min | plans avec groupe voulu %d, budget 0 : %d (%s), minutes avec budget 0 : %d | vagues %d, fer au stock : median %s, min %s, max %s, sous 2 000 : %d | pertes sensibles aux avant-postes : %s",
    tick / 3600, m.plans, m.zero, #why > 0 and table.concat(why, ", ") or "-", m.zero_min, m.waves, #ir > 0 and tostring(ir[math.floor((#ir + 1) / 2)]) or "-",
    #ir > 0 and tostring(ir[1]) or "-", #ir > 0 and tostring(ir[#ir]) or "-", m.wave_low, #loss > 0 and table.concat(loss, ", ") or "aucune"))
end

---------------------------------------------------------------------------------------------------
-- Murs rendus au joueur, usine du joueur
---------------------------------------------------------------------------------------------------
--- Index tuile -> projets de murs de l'équipe (spec.enceinte et spec.walls : enceinte, îlots, avant-postes), tenu à jour par les seuls projets
--- créés depuis le dernier appel (b.next_id croît) : aucun parcours de tous les murs à chaque démontage.
local function wall_index(st, b)
  local wi = st.widx
  if not wi then
    wi = { upto = 1, tiles = {} }
    st.widx = wi
  end
  local last = (b.next_id or 1) - 1
  for id = wi.upto, last do
    local p = b.projects[id]
    if p and p.spec and p.spec.enceinte and type(p.spec.walls) == "table" then
      for _, w in ipairs(p.spec.walls) do
        local k = P.tkey(w[1], w[2])
        local l = wi.tiles[k]
        if l then l[#l + 1] = id else wi.tiles[k] = { id } end
      end
    end
  end
  if last + 1 > wi.upto then wi.upto = last + 1 end
  return wi
end

local function on_mined(e)
  local ent = e.entity
  if not (ent and ent.valid and (ent.type == "wall" or ent.type == "gate") and ent.force and ent.force.name == "player") then return end
  local f = State.faction("player")
  local b = f and f.build
  if not b or f.garde_temoin then return end
  local tx, ty = math.floor(ent.position.x), math.floor(ent.position.y)
  local k = P.tkey(tx, ty)
  local st = state(f)
  local pids = wall_index(st, b).tiles[k]
  if not pids then return end -- mur du joueur hors des tuiles de l'équipe : rien à retenir
  b.walls_released = b.walls_released or {}
  if b.walls_released[k] then return end
  b.walls_released[k] = true
  local hit = 0
  for _, pid in ipairs(pids) do
    local p = b.projects[pid]
    for _, pe in ipairs(p and p.ents or {}) do
      if pe.wall and not pe.dropped and math.floor(pe.x) == tx and math.floor(pe.y) == ty then
        pe.built, pe.dropped = true, true
        p.dropped = (p.dropped or 0) + 1
        hit = hit + 1
      end
    end
  end
  glog(f, st, string.format("mur retire par le joueur en (%d, %d) a %.1f min : tuile rendue au joueur pour toujours (%d piece(s) de mur de l'equipe abandonnee(s), jamais reposee(s))",
    tx, ty, game.tick / 3600, hit))
end
Events.on(defines.events.on_player_mined_entity, on_mined)
Events.on(defines.events.on_robot_mined_entity, on_mined)

--- Crochet de plan_enceinte (script/team/build.lua) : rend une fonction (tx, ty) -> raison ou nil, pour les tuiles jamais murées.
function Gd.wall_mask(f, surface, areas)
  local b = f.build
  local released = b and b.walls_released or {}
  local boxes = {}
  if f.is_player then
    local g = Gs.PLAYER_GAP
    for _, a in ipairs(areas or {}) do
      for _, ent in ipairs(surface.find_entities_filtered({ area = { { a[1] - g, a[2] - g }, { a[3] + g, a[4] + g } }, force = f.force })) do
        if ent.valid and not Gd.team_owned(f, ent) then
          local bb = ent.bounding_box
          boxes[#boxes + 1] = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
        end
      end
    end
  end
  return function(tx, ty)
    if released[P.tkey(tx, ty)] then return "rendue" end
    if #boxes > 0 and Gs.in_player_zone(tx, ty, boxes) then return "joueur" end
    return nil
  end
end
Build.wall_mask = function(f, surface, areas)
  if not Gd.g3(f) then return nil end
  return Gd.wall_mask(f, surface, areas)
end

--- Crochet de revive_one (script/team/build.lua), au moment de poser le fantôme d'un mur de l'équipe : la tuile est-elle devenue interdite
--- depuis le plan (rendue au joueur, ou usine du joueur à moins de Gs.PLAYER_GAP tuiles) ? Rend la raison ou nil. Votre équipe, murs allumés.
Build.wall_veto = function(f, surface, e)
  if not (Gd.g3(f) or Gd.walls_on(f)) then return nil end
  local tx, ty = math.floor(e.x), math.floor(e.y)
  return Gd.wall_mask(f, surface, { { tx, ty, tx + 1, ty + 1 } })(tx, ty)
end

---------------------------------------------------------------------------------------------------
-- G3 : murs des avant-postes attaqués
---------------------------------------------------------------------------------------------------
local function outpost_box(f, surface, o, oid)
  local x0, y0, x1, y1
  for _, ent in ipairs(surface.find_entities_filtered({ position = o.pos, radius = 40, force = f.force })) do
    local u = ent.valid and ent.unit_number
    local ow = u and State.owner(u)
    if ow and ow.f == f.id and ow.oid == oid then
      local bb = ent.bounding_box
      local a, c = math.floor(bb.left_top.x), math.floor(bb.left_top.y)
      local d, g = math.ceil(bb.right_bottom.x) - 1, math.ceil(bb.right_bottom.y) - 1
      x0, y0 = x0 and math.min(x0, a) or a, y0 and math.min(y0, c) or c
      x1, y1 = x1 and math.max(x1, d) or d, y1 and math.max(y1, g) or g
    end
  end
  if not x0 then return nil end
  return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

--- Oublie l'anneau de l'avant-poste `oid` (disparu, ou agrandi) : ses segments quittent la réparation, leur chantier est annulé, ou, s'il
--- n'est plus annulable (rouvert, en chantier), ses murs non posés sont abandonnés ; leurs tuiles sont rendues. Rend le nombre de segments.
local function drop_ring(f, st, oid, why, tick)
  local h, b = st.walls, f.build
  local n, had = 0, h.rings[oid] ~= nil or h.done[oid] ~= nil
  for i = #h.segs, 1, -1 do
    local sg = h.segs[i]
    if sg.oid == oid then
      table.remove(h.segs, i)
      n = n + 1
      local p = b and b.projects[sg.pid]
      if p and p.state ~= "refuse" and p.state ~= "fini" and not Build.cancel(f, sg.pid, why) then
        for _, pe in ipairs(p.ents or {}) do
          if pe.wall and not pe.built then
            pe.built, pe.dropped = true, true
            p.dropped = (p.dropped or 0) + 1
          end
        end
      end
      for _, w in ipairs(sg.walls or {}) do h.claimed[Gs.tkey(w[1], w[2])] = nil end
    end
  end
  h.rings[oid], h.done[oid] = nil, nil
  h.cur_s, h.cur_e = nil, nil
  if had or n > 0 then
    glog(f, st, string.format("murs de l'avant-poste %s oublies (%s) : %d segment(s) retire(s) de la reparation a %.1f min", tostring(oid), why, n, tick / 3600))
  end
  return n
end

function Gd.walls_step(f, surface, tick, ctx)
  if not (Gd.walls_on(f) and f.outposts and f.hq_pos) then return end
  local st = state(f)
  local h = st.walls
  local b = f.build
  -- avant-poste retiré (outposts.lua, ruines.lua) : son anneau n'est plus ni réparé ni rouvert (les PNJ n'y retournent pas mourir, F239, F251)
  local gone = {}
  for _, t in ipairs({ h.rings, h.done, st.waves }) do
    for _, oid in ipairs(State.sorted_keys(t)) do if f.outposts[oid] == nil then gone[oid] = true end end
  end
  for _, sg in ipairs(h.segs) do if f.outposts[sg.oid] == nil then gone[sg.oid] = true end end
  for _, oid in ipairs(State.sorted_keys(gone)) do
    drop_ring(f, st, oid, "avant-poste disparu", tick)
    st.waves[oid] = nil
    if st.dirs then st.dirs[oid] = nil end
    st.picks[oid] = nil
  end
  for i = #h.segs, 1, -1 do
    local p = b.projects[h.segs[i].pid]
    if not p or p.state == "refuse" then
      local sg = table.remove(h.segs, i)
      local why = p and p.reason or "projet perdu"
      if p == nil or why == "materiaux" or why == "place" then
        for _, w in ipairs(sg.walls or {}) do h.claimed[Gs.tkey(w[1], w[2])] = nil end
        h.retry = tick + 5 * 3600
      end
      h.cur_s, h.cur_e = nil, nil
      glog(f, st, string.format("murs de l'avant-poste %s : segment refuse (%s) a %.1f min", tostring(sg.oid), tostring(why), tick / 3600))
    end
  end
  ctx.repair(h)
  for _, sg in ipairs(h.segs) do
    local p = b.projects[sg.pid]
    if p and p.state ~= "fini" and p.state ~= "refuse" then return end -- un segment à la fois
  end
  if tick < (h.retry or 0) then return end
  local equiv = ctx.equiv()
  local cap = Enc.segment_cap(equiv)
  local sk = stone_key()
  local g_stone = Gd.grant(f, tick, sk) -- pierre accordée par DEPENSES (débitée) ; nil : repli, le plafond de l'enceinte seul
  if g_stone ~= nil then cap = math.min(cap, math.floor(g_stone / Gs.WALL_ITEMS)) end
  for _, oid in ipairs(State.sorted_keys(st.waves)) do
    local w = st.waves[oid]
    local o = f.outposts[oid]
    if o and o.pos and Gs.wave_live(w.tick, tick) then
      local ring = h.rings[oid]
      local box = outpost_box(f, surface, o, oid)
      -- avant-poste AGRANDI hors de son anneau : l'ancien anneau est jeté (ses murs restent, plus réparés), un nouveau suit la nouvelle emprise
      if ring and box and (box.x0 < ring.box.x0 or box.y0 < ring.box.y0 or box.x1 > ring.box.x1 or box.y1 > ring.box.y1) then
        drop_ring(f, st, oid, "avant-poste agrandi", tick)
        ring = nil
      end
      if not ring and box then
        ring = { box = box }
        h.rings[oid] = ring
      end
      if ring and not h.done[oid] then
        local rr = Gs.ring(ring.box, f.hq_pos)
        local mask = Gd.wall_mask(f, surface, { { rr.box[1], rr.box[2], rr.box[3], rr.box[4] } })
        local seg, why = Gs.next_segment(rr, h.claimed, cap, function(tx, ty) return mask(tx, ty) ~= nil end)
        if seg then
          local tiles = {}
          for _, t in ipairs(seg.walls) do tiles[#tiles + 1] = { t.tx, t.ty } end
          local id, rwhy = ctx.request({ enceinte = true, ilot = "ap" .. tostring(oid), walls = tiles, side = seg.side, prio = ctx.prio,
            domain = "infrastructures" })
          if id then
            for _, t in ipairs(seg.walls) do h.claimed[Gs.tkey(t.tx, t.ty)] = true end
            h.segs[#h.segs + 1] = { pid = id, n = #tiles, side = seg.side, oid = oid, walls = tiles }
            if g_stone ~= nil then Gd.debit(f, sk, #tiles * Gs.WALL_ITEMS) end
            glog(f, st, string.format("murs de l'avant-poste %s attaque (vague %d) : segment %s de %d murs demande (projet %d), porte de %d tuiles cote %s, stock equivalent %d murs a %.1f min",
              tostring(oid), w.n, seg.side, #tiles, id, Gs.GATE, tostring(rr.gate), equiv, tick / 3600))
          else
            glog(f, st, string.format("murs de l'avant-poste %s : segment non demande (%s) a %.1f min", tostring(oid), tostring(rwhy), tick / 3600))
            h.retry = tick + 5 * 3600
          end
          return
        elseif why == "complet" then
          h.done[oid] = true
          glog(f, st, string.format("murs de l'avant-poste %s complets a %.1f min", tostring(oid), tick / 3600))
        elseif why == "stock" then
          if not h.poor then
            h.poor = true
            glog(f, st, string.format("murs de l'avant-poste %s attendus : plafond %d murs (stock equivalent %d) a %.1f min", tostring(oid), cap, equiv, tick / 3600))
          end
          return
        end
      end
    end
  end
end
Build.outpost_walls = function(f, surface, tick, ctx) return Gd.walls_step(f, surface, tick, ctx) end

---------------------------------------------------------------------------------------------------
-- G1 et G2 : groupes de tourelles
---------------------------------------------------------------------------------------------------
local function held(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      local o = State.owner(id)
      if o and type(o.oid) == "string" and o.oid:sub(1, #Gd.OID) == Gd.OID then n = n + 1 end
    end
  end
  return n
end

local function threats_near(f, surface, site)
  local out = {}
  local fm = f.front_mem
  if fm and fm.mem and fm.mem.cells then
    for _, c in ipairs(Fr.top(fm.mem, 64, 1)) do out[#out + 1] = { x = c.x, y = c.y, w = c.score } end
  end
  local nests = surface.find_entities_filtered({ position = site, radius = 64, force = "enemy", type = "unit-spawner" })
  local list = {}
  for _, e in ipairs(nests) do if e.valid then list[#list + 1] = { x = e.position.x, y = e.position.y } end end
  table.sort(list, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  for _, n in ipairs(list) do out[#out + 1] = { x = n.x, y = n.y, w = 500 } end
  return out
end

--- Coûts d'un mur : briques (premier ingrédient de la recette du mur, T.wall) et pierre par brique (T.smelter_inputs), et si la FORCE a la
--- recette (relecture D4 : rien n'est fondu avant que le mur soit recherché) ; nil sans recette.
local function wall_costs(f)
  local rec = game.recipe_prototypes[T.wall]
  local ing = rec and rec.ingredients[1]
  if not (ing and ing.type == "item") then return nil end
  local si = T.smelter_inputs[ing.name]
  if not si then return nil end
  local fo = game.forces[f.force]
  local fr = fo and fo.recipes[T.wall]
  return { brick = ing.name, per = ing.amount, stone = si[1], stone_per = si[2], enabled = fr ~= nil and fr.enabled == true }
end

--- G3 (essai 3) : briques à fondre de la PIERRE QUI DORT pour l'anneau de votre équipe (b.enc_need, écrit par Build.space_step quand
--- l'enceinte est voulue et pas payée en entier) et les murs des avant-postes attaqués : { item, n, deficit, stone } ou nil. Règle bornée
--- (Gs.bricks, relecture D2 à D4) : mur recherché, besoin couvert, pierre libre qui paie TOUT ce qui manque, au plus Gs.BRICKS_MAX par demande ;
--- versée au planificateur comme FONTE seule (jamais un manque : aucune extraction, relecture D1). Chaque changement de raison va au journal.
function Gd.bricks_want(f, tick, outpost_walls)
  local st = state(f)
  local need = 0
  local en = f.build and f.build.enc_need
  if Gd.g3(f) and en and tick - (en.tick or -1e9) <= 2 * Enc.CHECK_TICKS then need = need + (en.walls or 0) end
  if Gd.walls_on(f) then need = need + (outpost_walls or 0) end
  local c = need > 0 and wall_costs(f) or nil
  local n, why, equiv, stone, covered = 0, need > 0 and "pas de recette" or "rien", 0, 0, false
  if c then
    equiv = Stock.count(f, T.wall) + math.floor(Stock.count(f, c.brick) / math.max(1, c.per))
    local g = Gd.grant(f, tick, c.stone)
    if g ~= nil then
      stone, covered = g, true
    else
      local inp = Rsv.input(f, tick)
      stone, covered = inp and (inp.free[c.stone] or 0) or 0, inp ~= nil and inp.covered == true
    end
    n, why = Gs.bricks({ enabled = c.enabled, need = need, equiv = equiv, per = c.per, stone_per = c.stone_per, stone = stone, covered = covered,
      tick = tick, ep_start = st.bricks_ep, retry = st.bricks_retry })
  end
  if why == "ok" then
    st.bricks_ep = st.bricks_ep or tick
  elseif why == "delai" then
    st.bricks_ep, st.bricks_retry = nil, tick + Gs.BRICKS_RETRY
  elseif why ~= "attente" then
    st.bricks_ep = nil
  end
  if why ~= st.bricks_why and need > 0 then
    glog(f, st, string.format("briques des murs : %s (murs voulus %d, au stock %d, pierre libre %d, besoin %s) a %.1f min", why == "ok"
      and (n .. " a fondre") or ("aucune : " .. why), need, equiv, stone, covered and "couvert" or "non couvert", tick / 3600))
  end
  st.bricks_why = need > 0 and why or nil
  if n <= 0 then return nil end
  return { item = c.brick, n = n, deficit = need - equiv, stone = stone }
end

local function free_iron(f, tick)
  local inp = Rsv.input(f, tick)
  if not inp then return 0 end
  return inp.covered and (inp.free[iron_key()] or 0) or 0
end

function Gd.view(f, fortify_open)
  if not (T.garde_site_on and f.is_player) or f.garde_temoin or f.eliminated or not (f.hq and f.hq.valid and f.hq_pos) then return nil end
  local tick = game.tick
  local st = state(f)
  local busy = fortify_open and fortify_open[Gd.OID] or false
  if st.view and st.plan_tick and tick - st.plan_tick < Gd.PLAN_EVERY then
    st.view.busy = busy
    return st.view
  end
  st.plan_tick = tick
  local surface = f.hq.surface
  local rest = {}
  for _, k in ipairs(State.sorted_keys(st.rest)) do
    if st.rest[k] > tick then rest[k] = true else st.rest[k] = nil end
  end
  local sites, missing = {}, 0
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o and o.pos and (o.drills or 0) > 0 then
      local w = st.waves[oid]
      local wave = (w and Gs.wave_live(w.tick, tick)) and w.n or 0
      -- le GROUPE est du côté des attaques : « déjà là » = tourelles à moins de Gs.ACCEPT de son centre (pas les tourelles éparses du site)
      -- direction FIGÉE dès la première pose (banc lot-dc : la direction suivait la mémoire du front et le groupe changeait de place)
      local fixed = st.dirs and st.dirs[oid]
      local nx, ny
      if fixed then nx, ny = fixed.nx, fixed.ny else nx, ny = Gs.dir({ x = o.pos.x, y = o.pos.y }, threats_near(f, surface, o.pos), f.hq_pos) end
      local g = Gs.spots({ x = o.pos.x, y = o.pos.y }, nx, ny)
      st.vdir = st.vdir or {}
      st.vdir[oid] = { nx = nx, ny = ny } -- (mesure du plancher seulement : Gd.loss_class)
      local have = surface.count_entities_filtered({ position = g, radius = Gs.ACCEPT, force = f.force, type = R.TURRET_TYPES })
      local want = Gs.want(wave)
      if have < want then missing = missing + (want - have) end
      sites[#sites + 1] = { key = oid, x = o.pos.x, y = o.pos.y, have = have, want = want, wave = wave, w = o.drills, nx = nx, ny = ny, gx = g.x, gy = g.y }
    end
  end
  local pick, served, total = Gs.pick(sites, rest)
  local g_iron, free = Gd.grant(f, tick, iron_key()), free_iron(f, tick)
  -- demande écrite pour DEPENSES (lue par sa règle quand elle est là ; sans elle, inoffensive)
  local walls_wanted = 0
  for _, oid in ipairs(State.sorted_keys(st.waves)) do
    local w = st.waves[oid]
    if Gs.wave_live(w.tick, tick) and not st.walls.done[oid] then walls_wanted = walls_wanted + 60 end
  end
  f.team.depenses = f.team.depenses or { on = true }
  f.team.depenses.defense_want = Gs.want_table(iron_key(), missing, Gs.UNIT_IRON, stone_key(), walls_wanted)
  local out = { busy = busy, held = held(f), granted = g_iron, free = free, served = served, total = total }
  out.bricks = Gd.bricks_want(f, tick, walls_wanted)
  if pick then
    local nx, ny = pick.nx, pick.ny
    local g = { x = pick.gx, y = pick.gy }
    local calm = surface.find_nearest_enemy({ position = g, max_distance = Gd.CALM_R, force = f.force }) == nil
    if calm then
      st.picks[pick.key] = { nx = nx, ny = ny, want = pick.want }
      out.pick = { key = pick.key, x = g.x, y = g.y, have = pick.have, want = pick.want, wave = pick.wave }
      local sig = pick.key .. ":" .. pick.have .. ":" .. pick.want
      if st.last_sig ~= sig then
        st.last_sig = sig
        glog(f, st, string.format("groupe voulu a l'avant-poste %s (vague vue %d) : %d tourelle(s) a %d tuiles du groupe sur %d, groupe en (%.0f, %.0f) cote (%.2f, %.2f) ; budget : fer %s, accorde par DEPENSES %s, libre hors besoin %d, garde vivante %d ; sites servis %d sur %d a %.1f min",
          tostring(pick.key), pick.wave, pick.have, Gs.ACCEPT, pick.want, g.x, g.y, nx, ny, tostring(Stock.count(f, iron_key())),
          g_iron == nil and "absent, eteint ou perime (repli 30 %)" or tostring(g_iron), free, out.held, served, total, tick / 3600))
      end
    end
  end
  st.view = out
  return out
end

function Gd.place(f, surface, task, carrier)
  local st = state(f)
  local tick = game.tick
  st.plan_tick = nil
  local key = task.garde
  local o = key and f.outposts and f.outposts[key]
  local pk = key and st.picks[key]
  if not (o and o.pos and pk) then
    glog(f, st, string.format("pose : avant-poste %s disparu a %.1f min", tostring(key), tick / 3600))
    return 0
  end
  local site = { x = o.pos.x, y = o.pos.y }
  local g, spots = Gs.spots(site, pk.nx, pk.ny)
  local have = surface.count_entities_filtered({ position = g, radius = Gs.ACCEPT, force = f.force, type = R.TURRET_TYPES })
  local count = math.min(task.items[1][2], math.max(0, (pk.want or Gs.GROUP_MIN) - have))
  if count <= 0 then
    glog(f, st, string.format("pose : avant-poste %s deja garde (%d tourelle(s)) a %.1f min", tostring(key), have, tick / 3600))
    return 0
  end
  local n = Outposts.fortify_at(f, surface, Gd.OID .. tostring(key), spots, count, carrier, function(pos) return Gs.accepts(g, pos.x, pos.y) end)
  st.poses = st.poses + n
  -- fer payé sur l'accord de DEPENSES : débité dès la pose (la vue suivante, avant la prochaine émission, ne le redonne pas)
  if n > 0 and st.view and st.view.granted ~= nil then Gd.debit(f, iron_key(), n * Gs.UNIT_IRON) end
  if n == 0 then st.rest[key] = tick + Gd.REST end
  if n > 0 then
    st.dirs = st.dirs or {}
    if not st.dirs[key] then st.dirs[key] = { nx = pk.nx, ny = pk.ny } end -- le groupe garde sa place
  end
  glog(f, st, string.format("pose de %d tourelle(s) sur %d en groupe a l'avant-poste %s, autour de (%.0f, %.0f) a %.1f min (cumul %d)%s", n, count,
    tostring(key), g.x, g.y, tick / 3600, st.poses, n == 0 and " : aucune place, site au repos 2 min" or ""))
  return n
end

--- Banc témoin : la garde des sites, les murs des avant-postes et l'enceinte de votre équipe éteints pour cette partie (état de la sauvegarde :
--- f.garde_temoin), comme la 0.6.50 ; à appeler à l'init du banc, après la pose du coffre. Rend vrai si l'équipe existe.
remote.add_interface("fo-garde", {
  temoin = function()
    local f = State.faction("player")
    if not f then return false end
    f.garde_temoin = true
    log(string.format("[FO-PERIMETRE] player : banc temoin, garde des sites, murs et enceinte de l'equipe eteints (tick %d)", game.tick))
    return true
  end,
  -- Banc de G3 : enceinte de votre équipe et murs des avant-postes attaqués ALLUMÉS pour cette partie (f.garde_g3), défauts inchangés.
  g3 = function()
    local f = State.faction("player")
    if not f then return false end
    f.garde_g3 = true
    log(string.format("[FO-PERIMETRE] player : banc G3, enceinte de l'equipe et murs des avant-postes allumes (tick %d)", game.tick))
    return true
  end,
})

function Gd.on_lost(f, key, cause)
  local st = state(f)
  local tick = game.tick
  if key then st.rest[key] = tick + T.lethal_ticks end
  st.plan_tick = nil
  glog(f, st, string.format("PNJ tue en allant garder l'avant-poste %s (%s) a %.1f min ; site au repos %.0f min", tostring(key), tostring(cause),
    tick / 3600, T.lethal_ticks / 3600))
end

return Gd
