--[[
  Lot TV-ARCHI, tranche 1 (V23 de docs/TODO_VIDEO.md l.89 : enveloppe commune d'avance ; règle pure shared/team/quartiers.lua) : runtime.
  Champ de script/team/build.lua (Build.Quartiers), pas une locale : le bloc principal de build.lua est à 199 locales.

    Qr.step(f, tick, H)          E2 (Build.think, après space_step) : suivi des quartiers demandés, puis toutes les Qr.CHECK ticks la décision
                                 (Q.decide) ; une ouverture = un projet « quartier » du plan directeur (H.request). Journal [FO-ENVELOPPE].
    Qr.plan(f, surface, p, H)    plan du projet « quartier » (appelé par plan_project de build.lua, comme un raccord) : poteau au lot du pôle,
                                 2 coffres de dépôt, liaison au réseau par la fin de plan commune (plan_finish : plan_power, points d'appui),
                                 puis tous les arbres et rochers du lot du pôle en obstacles (défrichage du lot entier). Les rues vers le
                                 quartier sont défrichées par street_clear_tasks de build.lua, qui lit p.parts[1] (rien à ajouter).
  Réglage de carte fo-war-enveloppe (settings/tv_archi.lua, allumé par défaut). Éteint ou absent (moteur simulé des tests) : rien n'est lu,
  rien n'est écrit (f.build.quartiers n'est pas créé), aucun projet : le plan directeur d'avant à l'identique. Un quartier déjà demandé
  continue son chantier (projet ordinaire du plan directeur).
  État : f.build.quartiers = { known = { [clé "I:J"] = { I, J, lot, pid, refus, open } }, next, why, logs } (nombres, chaînes, tables).
]]

local Q = require("shared.team.quartiers")
local P = require("shared.team.plan")
local T = require("shared.team.config") -- noms lus dans T (registre §8 bis de tests/iag_test.lua) : coffre du stock, petit poteau
local Registry = require("script.companion.registry")
local State = require("script.faction.state")
local Enc = require("shared.team.enceinte") -- tranche 3 : menaces connues (Enc.known_threats, règle pure)
local RegT = require("script.team.registre_types") -- lot UPS : registre des machines par force et par type (plus de recherche sur toute la surface)

local Qr = {}

Qr.SETTING = "fo-war-enveloppe"
Qr.CHECK = 1800        -- ticks entre deux décisions (comme la croissance du treillis, shared/team/enceinte.lua E.CHECK_TICKS)
Qr.PRIO = 35           -- priorité du projet (sous les modules, 55 ; au-dessus du fond, 18 à 24)
Qr.CLEAR_MAX = 400     -- arbres et rochers au plus mis en obstacles dans le lot du pôle
Qr.LOGS = 60           -- lignes [FO-ENVELOPPE] au plus, par équipe
Qr.DEPOT = T.annex.kinds[1].item -- le coffre des annexes du stock (32 cases)
Qr.DEPOTS = 2
local TREES = { "tree", "simple-entity" }
Qr.AMMO = 20           -- tranche 3 : chargeurs posés avec la tourelle du pôle (charge du chantier, réservée au coffre)
Qr.OID = "quartier"    -- tranche 3 : poste des tourelles du pôle (State.own : « quartier<clé> », groupe de ravitaillement de Outposts.turret_groups)
P.declare_size(T.turret, 2, 2) -- emprise de la tourelle du pôle, connue dès le chargement (comme le mur, build.lua)

function Qr.on()
  local ok, s = pcall(function() return settings.global[Qr.SETTING] end)
  return ok and s ~= nil and s.value == true
end

local function say(f, st, text)
  st.logs = (st.logs or 0) + 1
  if st.logs <= Qr.LOGS then log(text) end
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- PNJ sans tâche et sans fabrication de fond (même compte que Worker.idle_count, script/team/worker.lua : pas de require, worker.lua
--- requiert build.lua).
local function idle_count(f)
  local n = 0
  -- s40 ups-team p43 : un COMPTE (somme sans effet de bord, indépendante de l'ordre) : plus de liste triée refaite à chaque relevé
  for id in pairs(f.engineers or {}) do
    local a = Registry.get(id)
    if a and not a.task and not a.bg then n = n + 1 end
  end
  return n
end

--- Ticks de plan des modules posés dans un lot du treillis (projets du plan directeur).
local function module_starts(b)
  local out = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    local pt = p and p.parts and p.parts[1]
    if p and p.started and pt and pt.kind == "module" and type(pt.lot) == "string" and b.lots[pt.lot] then out[#out + 1] = p.started end
  end
  return out
end

--- Tranche 3 : la tourelle du pôle d'un quartier fini est inscrite à l'équipe (f.turrets, State.own, poste « quartier<clé> ») : les
--- tournées de ravitaillement existantes (Outposts.turret_groups : groupe à la position de la tourelle) la gardent armée. Refait à chaque
--- pensée (tourelle reposée par la reconstruction : nouveau numéro).
local function register_turret(f, p, k)
  if not f.turrets then return 0 end
  local surface = f.hq and f.hq.valid and f.hq.surface
  if not surface then return 0 end
  local n = 0
  for _, e in ipairs(p.ents) do
    if e.role == "tourelle" then
      local t = surface.find_entity(e.name, { e.x, e.y })
      if t and t.valid and t.force.name == f.force and t.unit_number and not f.turrets[t.unit_number] then
        f.turrets[t.unit_number] = t
        State.own(t, f.id, "turret", Qr.OID .. k)
        n = n + 1
      end
    end
  end
  return n
end

--- Suivi des quartiers demandés : ouverture (projet fini), refus (projet refusé, disparu ou bloqué sans reprise).
local function follow(f, st, tick)
  local b = f.build
  for _, k in ipairs(sorted_keys(st.known)) do
    local kn = st.known[k]
    if kn.pid then
      local p = b.projects[kn.pid]
      if p and p.state == "fini" then
        kn.turrets = (kn.turrets or 0) + register_turret(f, p, k)
        if not kn.open then
          kn.open = tick
          local wired = 0
          for _, e in ipairs(p.ents) do if e.name:find("electric%-pole") then wired = wired + 1 end end
          say(f, st, string.format("[FO-ENVELOPPE] %s : quartier %s OUVERT a %.1f min (projet %d, pole au lot %s : %d poteau(x), %d coffre(s) de depot, %d tourelle(s) inscrite(s), %d obstacle(s) defriche(s))",
            f.key or "player", k, tick / 3600, p.id, tostring(kn.lot), wired, Qr.DEPOTS, kn.turrets or 0, #(p.obstacles or {})))
        end
      elseif not p or p.state == "refuse" or (p.state == "bloque" and not p.retry_at) then
        say(f, st, string.format("[FO-ENVELOPPE] %s : quartier %s refuse a %.1f min (projet %s : %s)", f.key or "player", k, tick / 3600,
          tostring(kn.pid), p and tostring(p.reason) or "disparu"))
        kn.pid, kn.open, kn.refus = nil, nil, (kn.refus or 0) + 1
      end
    end
  end
end

--- E2 (Build.think). `H` = { request = Build.request }.
function Qr.step(f, tick, H)
  local b = f.build
  if not b then return end
  if not Qr.on() then
    -- réglage éteint en cours de partie : les dépôts des quartiers déjà ouverts restent tenus (ou vidés au QG, fo-war-quartiers éteint)
    if b.quartiers then Qr.depots(f, tick) end
    return
  end
  local st = b.quartiers
  if not st then
    st = { known = {}, next = 0, logs = 0 }
    b.quartiers = st
  end
  follow(f, st, tick)
  Qr.depots(f, tick) -- tranche 2 (V91) : objets des dépôts des quartiers ouverts (rien si fo-war-quartiers est éteint)
  if tick < (st.next or 0) then return end
  st.next = tick + Qr.CHECK
  local open, busy = {}, false
  for _, k in ipairs(sorted_keys(st.known)) do
    local kn = st.known[k]
    if kn.open then open[k] = true elseif kn.pid then busy = true end
  end
  local pl = b.plant and b.projects[b.plant]
  local need, taken = Q.need(module_starts(b), tick)
  local pile = f.team and f.team.ia3 and f.team.ia3.pile
  local s = {
    on = true, plant = pl ~= nil and pl.state == "fini", busy = busy, free = Q.free_open(b.lots, open), need = need,
    idle = idle_count(f), hold = (pile and pile.hold) and true or false,
    survie = (f.team and f.team.survie and f.team.survie.on == true) or false,
  }
  local menaces = 0
  if s.plant and not s.busy and s.free < s.need then
    local m = f.ai3f and f.ai3f.m -- tranche 3 : nids et vers connus (carte de connaissance) ; votre équipe sans carte : aucune menace
    s.cands, menaces = Q.candidates(b.lots, st.known, Enc.known_threats(m and m.s, b.lat, Enc.THREAT_RANGE), b.lat)
  end
  local d = Q.decide(s)
  if d.open then
    local c = d.open
    -- pile = « upgrade » (R3) : une retenue de la pile suspend sa réserve au coffre (Build.reserve_suspended), comme un module neuf
    local id = H.request(f, { quartier = { I = c.I, J = c.J, lot = c.hub, key = c.key }, prio = Qr.PRIO, domain = "infrastructures",
      pole = pl and pl.spec and pl.spec.pole or nil, pile = "upgrade" })
    if id then
      local kn = st.known[c.key] or { I = c.I, J = c.J, refus = 0 }
      kn.pid, kn.lot, kn.asked = id, c.hub, tick
      st.known[c.key] = kn
      st.why = nil
      say(f, st, string.format("[FO-ENVELOPPE] %s : decision a %.1f min : quartier %s ouvert d'avance (projet %d, pole au lot %s, %d lot(s) libre(s) de plus) ; lots libres des quartiers ouverts %d < besoin %d (%d module(s) en %d min) ; %d PNJ inactif(s)",
        f.key or "player", tick / 3600, c.key, id, c.hub, c.free, s.free, s.need, taken, Q.WINDOW / 3600, s.idle))
    end
  elseif d.why ~= st.why then
    st.why = d.why
    say(f, st, string.format("[FO-ENVELOPPE] %s : a %.1f min, pas d'ouverture : %s (lots libres des quartiers ouverts %d, besoin %d, %d module(s) en %d min, %d PNJ inactif(s), %d quartier(s) ouvert(s), %d ecarte(s) pour une menace a %d tuiles)",
      f.key or "player", tick / 3600, d.why, s.free, s.need, taken, Q.WINDOW / 3600, s.idle, #sorted_keys(open), menaces, Q.THREAT_R))
  end
end

local function passable(b)
  return function(key) local s = b.segs[key]; return s ~= nil and s.state ~= "ferme" and s.state ~= "inconnu" end
end

--- Plan du projet « quartier » : (true) ou (false, raison[, attendre]). `H` = { read_masks(x0, y0, x1, y1), reserve_tiles(b, p, ents),
--- finish(f, surface, p, masks, is_plant), add_obstacle(p, o), free_spot(b, masks, x, y, trees) } (fonctions locales de build.lua).
function Qr.plan(f, surface, p, H)
  local b = f.build
  local q = p.spec.quartier
  local l = q and b.lots[q.lot]
  if not Q.usable(l) then return false, "quartier: lot du pole pris ou inutilisable" end
  local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
  local masks = H.read_masks(x0 - 8, y0 - 8, x1 + 8, y1 + 8)
  -- poteau et coffres de dépôt en ligne (3 tuiles libres : ni eau, ni falaise, ni bâti ; les arbres seront coupés), au plus près du
  -- centre du lot (anneaux de Chebyshev, puis y, puis x)
  local cx, cy = x0 + P.HALF, y0 + P.HALF
  local spot
  for r = 0, P.HALF - 3 do
    for dy = -r, r do
      for dx = -r, r do
        if not spot and math.max(math.abs(dx), math.abs(dy)) == r then
          local tx, ty = cx + dx, cy + dy
          local ok = tx >= x0 + 1 and tx + 2 < x1 - 1 and ty >= y0 + 1 and ty < y1 - 1
          for k = 0, 2 do ok = ok and masks.free(tx + k, ty) end
          if ok then spot = { tx, ty } end
        end
      end
    end
    if spot then break end
  end
  if not spot then return false, "quartier: aucune place pour le poteau et les coffres" end
  local pole = p.spec.pole or T.swap.poles[1] -- le poteau de la centrale, sinon le petit poteau (sa recette est ouverte au départ)
  local ents = { { name = pole, x = spot[1] + 0.5, y = spot[2] + 0.5, dir = 0, part = 1, role = "quartier" } }
  for k = 1, Qr.DEPOTS do
    ents[#ents + 1] = { name = Qr.DEPOT, x = spot[1] + k + 0.5, y = spot[2] + 0.5, dir = 0, part = 1, role = "depot" }
  end
  -- tranche 3 : une tourelle au pôle (2 × 2 sous le poteau et les coffres), posée garnie (charge) quand le coffre a la tourelle et ses
  -- chargeurs ; sinon le quartier s'ouvre sans elle (rien ne l'attend : écrit au journal)
  local turret = false
  local ammo = T.turret_ammo
  if H.count and H.count(T.turret) >= 1 and H.count(ammo) >= Qr.AMMO then
    local ok = spot[2] + 3 < y1 - 1
    for dy = 2, 3 do for dx = 0, 1 do ok = ok and masks.free(spot[1] + dx, spot[2] + dy) end end
    if ok then
      ents[#ents + 1] = { name = T.turret, x = spot[1] + 1, y = spot[2] + 3, dir = 0, part = 1, role = "tourelle", charge = { item = ammo, count = Qr.AMMO } }
      turret = true
    end
  end
  if not H.reserve_tiles(b, p, ents) then return false, "place" end
  p.parts[1] = { kind = "quartier", key = "quartier", lot = q.lot, ox = x0, oy = y0, w = P.LOT, h = P.LOT, power = true }
  p.counted = true -- un quartier n'est pas un module : finish_project ne le compte ni aux modules ni aux projets finis
  l.used = p.id
  local ok, why, wait = H.finish(f, surface, p, masks, false)
  if not ok then return false, why, wait end
  -- défrichage du lot ENTIER du pôle (G38) : chaque arbre et rocher devient un obstacle, rattaché au point d'appui de sa rue
  local pass = passable(b)
  local found = surface.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = TREES })
  local list = {}
  for _, t in ipairs(found) do list[#list + 1] = { x = t.position.x, y = t.position.y } end
  table.sort(list, function(a, c) if a.y ~= c.y then return a.y < c.y end return a.x < c.x end)
  local n = 0
  for _, t in ipairs(list) do
    if n >= Qr.CLEAR_MAX then break end
    local tx, ty = math.floor(t.x), math.floor(t.y)
    local a = P.anchor_for(b.lat, tx + 0.5, ty + 0.5, pass)
    local ax, ay
    if a then ax, ay = a.x, a.y else ax, ay = math.floor(tx / 8) * 8 + 4, math.floor(ty / 8) * 8 + 4 end
    local fx, fy = H.free_spot(b, masks, ax, ay, nil)
    if (fx - tx) * (fx - tx) + (fy - ty) * (fy - ty) > P.BUILD_DISTANCE * P.BUILD_DISTANCE then fx, fy = H.free_spot(b, masks, tx, ty, nil) end
    H.add_obstacle(p, { x = tx + 0.5, y = ty + 0.5, anchor = string.format("%s%g:%g", a and "" or "c", fx, fy), ax = fx, ay = fy })
    n = n + 1
  end
  local links = 0
  for _, e in ipairs(p.ents) do if e.role ~= "quartier" and e.role ~= "depot" and e.name:find("electric%-pole") then links = links + 1 end end
  local st = b.quartiers or { logs = 0 }
  say(f, st, string.format("[FO-ENVELOPPE] %s : projet %d planifie (quartier %s, lot %s) : poteau %s en (%.1f, %.1f), %d coffre(s) de depot, %s, %d poteau(x) de liaison au reseau, %d arbre(s) ou rocher(s) du lot a defricher (%d trouve(s))",
    f.key or "player", p.id, tostring(q.key), tostring(q.lot), pole, ents[1].x, ents[1].y, Qr.DEPOTS,
    turret and ("1 tourelle et " .. Qr.AMMO .. " chargeurs") or "sans tourelle (coffre sans tourelle ou sans chargeurs, ou pas de place)", links, n, #list))
  return true
end

---------------------------------------------------------------------------------------------------
-- Tranche 2 (V91) : DÉPÔT du quartier. Réglage fo-war-quartiers (settings/tv_archi.lua) ; éteint ou absent : rien ne change.
--   Qr.depots(f, tick)          (dans Qr.step) les coffres du pôle d'un quartier OUVERT deviennent les quais de son projet, aux objets les
--                               plus demandés par les quais des modules du quartier (Q.depot_items) : quai_tasks de build.lua les remplit
--                               depuis le QG (tournées de quais existantes, rien de neuf).
--   Qr.route(f, surface, tasks) (Build.think, avant Board.add) une tournée « remplir » d'un quai d'un module du quartier prend AU DÉPÔT
--                               quand il a tout le lot (Q.depot_serves) : ia1d.depot = position du coffre, task.items retiré (le marché
--                               ne demande rien au stock du QG), task.depot_items = le lot. Programme : script/team/worker.lua.
--   Qr.depot_step(...)          étapes « take_depot » et « put_depot » du programme (worker.lua, run_steps).
---------------------------------------------------------------------------------------------------
Qr.SETTING_DEPOT = "fo-war-quartiers"
Qr.QLOG_EVERY = 5 * 3600

function Qr.depots_on()
  local ok, s = pcall(function() return settings.global[Qr.SETTING_DEPOT] end)
  return ok and s ~= nil and s.value == true
end

--- Quartier OUVERT (clé) du lot `lk`, et son projet ; nil sinon.
local function open_hub(b, lk)
  local st = b.quartiers
  local l = st and lk and b.lots[lk]
  if not l then return nil end
  local I, J = Q.of_lot(l.i, l.j)
  local kn = st.known[Q.key(I, J)]
  local hp = kn and kn.open and kn.pid and b.projects[kn.pid]
  if hp and hp.state == "fini" then return hp, Q.key(I, J) end
  return nil
end

function Qr.depots(f, tick)
  local b = f.build
  local st = b.quartiers
  if not st then return end
  if not Qr.depots_on() then
    -- fo-war-quartiers éteint (en cours de partie) : plus aucun objet demandé aux dépôts ; ce qu'ils tiennent est vidé au QG (collecte),
    -- rien ne reste bloqué hors du stock. Sans quartier ouvert : rien.
    for _, k in ipairs(sorted_keys(st.known)) do
      local kn = st.known[k]
      local hp = kn.open and kn.pid and b.projects[kn.pid]
      if hp and hp.state == "fini" and (#(hp.quais or {}) > 0 or #(hp.outs or {}) == 0) then
        local outs = {}
        for _, e in ipairs(hp.ents) do if e.role == "depot" then outs[#outs + 1] = { x = e.x, y = e.y, at = 1 } end end
        hp.quais, hp.outs = {}, outs
      end
    end
    return
  end
  -- demande par quartier ouvert : quais des modules (finis ou en chantier) de ses lots
  local want = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    local pt = p and p.parts and p.parts[1]
    if p and not p.spec.quartier and (p.state == "fini" or p.state == "chantier") and pt and type(pt.lot) == "string" then
      local hp, qk = open_hub(b, pt.lot)
      if hp then
        want[qk] = want[qk] or {}
        for _, q in ipairs(p.quais or {}) do want[qk][q.item] = (want[qk][q.item] or 0) + 1 end
      end
    end
  end
  for _, k in ipairs(sorted_keys(st.known)) do
    local kn = st.known[k]
    local hp = kn.open and kn.pid and b.projects[kn.pid]
    if hp and hp.state == "fini" then
      local items = Q.depot_items(want[k] or {}, Qr.DEPOTS)
      local surface = f.hq and f.hq.valid and f.hq.surface
      -- chaque objet garde le coffre qui le tient déjà (sinon le premier coffre libre) ; un coffre qui tient un objet qu'on ne lui demande
      -- plus (Q.depot_stale) est VIDÉ au QG (sortie du projet, collecte de out_tasks au premier objet) et n'est pas rempli entre-temps
      local chests, contents = {}, {}
      for _, e in ipairs(hp.ents) do
        if e.role == "depot" then
          local c = surface and surface.find_entity(Qr.DEPOT, { e.x, e.y })
          chests[#chests + 1] = e
          contents[#chests] = (c and c.valid) and c.get_inventory(defines.inventory.chest).get_contents() or {}
        end
      end
      local owner, taken = {}, {}
      for _, it in ipairs(items) do
        for i = 1, #chests do
          if not owner[it] and not taken[i] and (contents[i][it] or 0) > 0 then owner[it], taken[i] = i, true end
        end
      end
      for _, it in ipairs(items) do
        for i = 1, #chests do if not owner[it] and not taken[i] then owner[it], taken[i] = i, true end end
      end
      local quais, outs = {}, {}
      for i, e in ipairs(chests) do
        local mine
        for _, it in ipairs(items) do if owner[it] == i then mine = it end end
        if Q.depot_stale(contents[i], { mine }) then
          outs[#outs + 1] = { x = e.x, y = e.y, at = 1 }
        elseif mine then
          quais[#quais + 1] = { x = e.x, y = e.y, item = mine }
        end
      end
      hp.quais, hp.outs = quais, outs
      kn.stale = #outs
    end
  end
  if tick >= (st.qlog_next or 0) then
    st.qlog_next = tick + Qr.QLOG_EVERY
    local parts = {}
    for _, k in ipairs(sorted_keys(st.known)) do
      local kn = st.known[k]
      local hp = kn.open and kn.pid and b.projects[kn.pid]
      if hp then
        local its = {}
        for _, q in ipairs(hp.quais or {}) do its[#its + 1] = q.item end
        parts[#parts + 1] = k .. "[" .. table.concat(its, " ") .. ((kn.stale or 0) > 0 and (" ; " .. kn.stale .. " a vider") or "") .. "]"
      end
    end
    if #parts > 0 then
      say(f, st, string.format("[FO-QUARTIER] %s minute %.0f : depots %s ; taches « remplir » des quartiers ouverts emises au depot %d fois, au QG %d fois ; collectes deposees au depot %d fois (depuis le debut, une emission par pensee)",
        f.key or "player", tick / 3600, table.concat(parts, " "), st.served or 0, st.from_qg or 0, st.collected or 0))
    end
  end
end

function Qr.route(f, surface, tasks)
  local b = f.build
  if not (b and b.quartiers and surface and Qr.depots_on()) then return end
  local st = b.quartiers
  for _, t in ipairs(tasks) do
    local j = t.ia1d
    -- collecte d'un module du quartier dont un produit est demandé par le dépôt (Q.collect_to_depot) : le PNJ passe par le dépôt, y laisse
    -- ces produits, et rentre au QG avec le reste (programme de worker.lua : sortie -> dépôt -> QG)
    if j and j.mode == "collect" and not j.depot then
      local p = b.projects[j.pid]
      local pt = p and not p.spec.quartier and p.parts and p.parts[1]
      local hp = pt and type(pt.lot) == "string" and open_hub(b, pt.lot)
      if hp then
        local products = sorted_keys(p.outflow)
        local items = {}
        for _, dq in ipairs(hp.quais or {}) do items[#items + 1] = dq.item end
        if Q.collect_to_depot(products, items) then
          local list
          for _, dq in ipairs(hp.quais or {}) do
            if not list and Q.collect_to_depot(products, { dq.item }) then
              j.depot = { x = dq.x, y = dq.y }
              list = { { dq.item, 0 } }
            end
          end
          t.depot_items = list
          st.collected = (st.collected or 0) + 1
        end
      end
    end
    if j and j.mode == "fill" and type(t.items) == "table" and #t.items == 1 then
      local p = b.projects[j.pid]
      local pt = p and not p.spec.quartier and p.parts and p.parts[1]
      local hp = pt and type(pt.lot) == "string" and open_hub(b, pt.lot)
      if hp then
        local item, need = t.items[1][1], t.items[1][2]
        local served = false
        for _, dq in ipairs(hp.quais or {}) do
          if not served and dq.item == item then
            local chest = surface.find_entity(Qr.DEPOT, { dq.x, dq.y })
            if chest and chest.force.name == f.force and Q.depot_serves(chest.get_item_count(item), need) then
              j.depot = { x = dq.x, y = dq.y }
              t.depot_items, t.items = t.items, nil
              served = true
            end
          end
        end
        if served then st.served = (st.served or 0) + 1 else st.from_qg = (st.from_qg or 0) + 1 end
      end
    end
  end
end

--- Étape du programme d'un PNJ : « take_depot » prend `items` ({ {objet, n} }) au coffre de dépôt en `pos` ; « put_depot » y remet ce
--- qu'il porte de ces objets. Rend vrai si la prise a rapporté quelque chose (put_depot : toujours vrai).
function Qr.depot_step(f, kind, pos, items, inv)
  local surface = f.hq and f.hq.valid and f.hq.surface
  local chest = surface and pos and surface.find_entity(Qr.DEPOT, { pos.x, pos.y })
  if not (chest and inv) then return kind == "put_depot" end
  local any = false
  for _, it in ipairs(items or {}) do
    if kind == "take_depot" then
      local n = math.min(it[2], chest.get_item_count(it[1]))
      if n > 0 then
        local got = chest.remove_item({ name = it[1], count = n })
        local put = got > 0 and inv.insert({ name = it[1], count = got }) or 0
        if put < got then chest.insert({ name = it[1], count = got - put }) end
        if put > 0 then any = true end
      end
    else
      local n = inv.get_item_count(it[1])
      if n > 0 then
        local put = chest.insert({ name = it[1], count = n })
        if put > 0 then inv.remove({ name = it[1], count = put }) end
      end
      any = true
    end
  end
  return any or kind == "put_depot"
end

--- BANCS SEULEMENT (interface distante fo-ia1d.quartiers, scénario greffé tv-archi) :
---   "report"           { on, why, logs, known = { { key, pid, lot, open, refus, state, obstacles, ents } } } ;
---   "now"              la décision suivante a lieu à la prochaine pensée (st.next = 0) ;
---   "bench_build", pid les entités planifiées du projet `pid` posées par script (le banc tient le rôle des PNJ bâtisseurs : le plan
---                      directeur les voit « déjà là » à la pose des fantômes) ; les arbres ne sont PAS touchés. Rend le nombre posé.
function Qr.remote(f, cmd, arg)
  local b = f and f.build
  if not b then return nil end
  local st = b.quartiers
  if cmd == "report" then
    local out = { on = Qr.on(), why = st and st.why, logs = st and st.logs or 0, known = {} }
    for _, k in ipairs(sorted_keys(st and st.known)) do
      local kn = st.known[k]
      local p = kn.pid and b.projects[kn.pid]
      out.known[#out.known + 1] = { key = k, pid = kn.pid, lot = kn.lot, open = kn.open, refus = kn.refus or 0, state = p and p.state,
        reason = p and p.reason, obstacles = p and #(p.obstacles or {}) or 0, ents = p and #(p.ents or {}) or 0, turrets = kn.turrets or 0,
        quais = p and #(p.quais or {}) or 0, outs = p and #(p.outs or {}) or 0 }
    end
    return out
  elseif cmd == "now" then
    if st then st.next = 0 end
    return st ~= nil
  elseif cmd == "bench_build" then
    local p = b.projects[arg]
    local surface = f.hq and f.hq.valid and f.hq.surface
    if not (p and surface) then return 0 end
    local n = 0
    for _, e in ipairs(p.ents) do
      if not e.built then
        local found = surface.find_entities_filtered({ name = e.name, position = { e.x, e.y }, radius = 0.3, force = f.force, limit = 1 })[1]
        local made = not found and surface.create_entity({ name = e.name, position = { e.x, e.y }, direction = e.dir, force = f.force, recipe = e.recipe })
        if made then
          RegT.note(made) -- lot UPS : pose sans événement, notée au registre des machines
          n = n + 1
        end
      end
    end
    return n
  end
  return nil
end

return Qr
