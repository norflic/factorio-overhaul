--[[
  N104-ERREURS, côté RUNTIME : relevé des FAITS d'une équipe, une fois par minute, pour le journal d'erreurs de partie
  (règle pure : shared/debug/erreurs_partie.lua ; lignes [FO-ERREUR-PARTIE] et [FO-ERREUR-BILAN]). Un INSTRUMENT : aucune décision
  d'IA ne lit ce module ni son état (namespace « erreurs », écrit ici seulement). Vit dans le MOD : la partie réelle du DC l'écrit aussi.

  Branchement : l'étape E6 de la pensée (bus d'étapes, script/team/team.lua TT.e6) appelle ErrP.think ; la sonde ne travaille qu'une
  fois par E.PERIOD et par équipe. Les faits sont LUS dans l'état que le mod tient déjà :
    capitalisation (f.team.capi.res, épargne st.bank, capacités à 0 cs.zero), vapeur (f.build.vapeur), bilan (f.team.ia3.bilan),
    besoin évalué (f.team.ia3.noyau), projets sans progrès (f.build.noprog), relevé du champ (Champ.report -> ErrP.note_champ),
    postes de défense (defense_log -> ErrP.note_def), pertes à refaire (f.recon.lost) ;
  et deux relevés propres, bornés :
    - morts des entités de l'équipe (on_entity_died, jamais la force « enemy ») par case de chunk : vagues (Sa.T), pièces, PV perdus,
      tourelles de la case à la première vague (un count_entities_filtered à la création de la case) ;
    - tapis chargés sans sortie : un balayage TOURNANT des pièces de tapis posées (au plus Bilan.READ_MAX lectures par passe, le même
      budget de lectures par minute que le bilan), classés par la règle du scénario (E.cul_classe), coupures par un poteau comprises.
  Coût : aucun scan de surface par tick ; une passe par minute et par équipe ; tout est protégé (pcall) : une erreur de la sonde
  écrit une ligne et ne touche jamais la partie.
]]

local Storage = require("script.core.storage")
local Events = require("script.core.events")
local State = require("script.faction.state")
local Bilan = require("script.ai3.bilan")
local E = require("shared.debug.erreurs_partie")
local Bi = require("shared.ai3.bilan")
local Rs = require("shared.ai3.reserve")
local V = require("shared.team.vapeur")
local Sa = require("shared.team.secteur_attaque")
local Rc = require("shared.team.reconstruction")
local P = require("shared.team.plan")

local ErrP = {}

ErrP.ENABLED = true
-- Constantes posées par leurs modules (script/ai3/capitalisation.lua) : alerte d'une capacité à 0, période du relevé, plafond des lignes.
ErrP.EXT = {}

Storage.declare("erreurs", function() return { t = {} } end)

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  return ks
end

local function team_state(key)
  local ns = Storage.ns("erreurs")
  if not ns then return nil end
  local t = ns.t[key]
  if not t then
    t = { st = E.new(), morts = {}, culs = {}, cur = { i = 1, j = 1 }, chev = {} }
    ns.t[key] = t
  end
  return t
end

local function team_of_force(name)
  local f = State.by_force(name)
  if f then return f end
  local pf = State.faction("player")
  if pf and (pf.force or "player") == name then return pf end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Morts par case de chunk (vagues)
---------------------------------------------------------------------------------------------------
local MOBILE = { character = true, unit = true, car = true, ["spider-vehicle"] = true, locomotive = true, ["cargo-wagon"] = true,
  ["fluid-wagon"] = true, ["artillery-wagon"] = true, ["combat-robot"] = true, ["construction-robot"] = true, ["logistic-robot"] = true }
local TURRETS = sorted_keys(Sa.TURRET_TYPES)
local CHUNK = 32

local function turrets_in(surface, force, cx, cy)
  return surface.count_entities_filtered({ area = { { cx * CHUNK, cy * CHUNK }, { (cx + 1) * CHUNK, (cy + 1) * CHUNK } }, type = TURRETS,
    force = force })
end

local function on_died(e)
  if not ErrP.ENABLED then return end
  local ent = e.entity
  if not (ent and ent.valid) or MOBILE[ent.type] then return end
  local f = team_of_force(ent.force.name)
  if not f then return end
  local t = team_state(tostring(f.key or "player"))
  if not t then return end
  local p = ent.position
  local cx, cy = math.floor(p.x / CHUNK), math.floor(p.y / CHUNK)
  local ck = cx .. ":" .. cy
  local m = t.morts[ck]
  if not m then
    local ok, n = pcall(turrets_in, ent.surface, ent.force, cx, cy)
    m = { cx = cx, cy = cy, x = p.x, y = p.y, vagues = 0, perdus = 0, pv = 0, t0 = ok and n or 0 }
    t.morts[ck] = m
  end
  if not m.last or e.tick - m.last > Sa.T then m.vagues = m.vagues + 1 end
  m.last = e.tick
  m.perdus = m.perdus + 1
  m.pv = m.pv + (ent.prototype.max_health or 0)
  m.par = e.force and e.force.name or m.par
end
-- (protégé : une erreur de la sonde ne doit jamais toucher la partie ; dite une fois)
local died_err = false
Events.on_died(function(e)
  local ok, err = pcall(on_died, e)
  if not ok and not died_err then
    died_err = true
    log(string.format("%s ERREUR de la sonde des morts (aucun effet sur la partie) : %s", E.TAG, tostring(err)))
  end
end, { ennemi = false })

---------------------------------------------------------------------------------------------------
-- Notes des relevés existants (lecture seule de leurs comptes)
---------------------------------------------------------------------------------------------------
--- Relevé du champ (script/team/champ.lua, Champ.report) : comptes des foreuses et des fours, bandes au cadre posé sans foreuse.
local function note_champ_(f, rd, tick, every)
  if not (ErrP.ENABLED and rd) then return end
  local t = team_state(tostring(f.key or "player"))
  if not t then return end
  local d, fu = rd.d or {}, rd.fu or {}
  local vides = {}
  for i, v in ipairs(rd.vides or {}) do
    if i > 8 then break end
    vides[i] = { pid = v.pid, x = v.x, y = v.y, cadre = v.cadre }
  end
  t.champ = { tick = tick, every = every or E.PERIOD, stuck = d.stuck or 0, nopow = d.nopow or 0, nofuel = fu.nofuel or 0,
    at_stuck = d.at_stuck, at_nopow = d.at_nopow, at_nofuel = fu.at_nofuel, vides = vides }
end

--- Postes de défense (script/team/defense_log.lua) : tourelles posées et voulues par poste.
local function note_def_(f, posts, tick)
  if not (ErrP.ENABLED and posts) then return end
  local t = team_state(tostring(f.key or "player"))
  if not t or (t.def and tick - t.def.tick < E.PERIOD) then return end
  local out = {}
  for i, p in ipairs(posts) do
    if i > 8 then break end
    out[i] = { post = tostring(p.id), have = p.have or 0, want = p.want or 0 }
  end
  t.def = { tick = tick, posts = out }
end

function ErrP.note_champ(...) pcall(note_champ_, ...) end
function ErrP.note_def(...) pcall(note_def_, ...) end

---------------------------------------------------------------------------------------------------
-- Tapis chargés sans sortie (balayage tournant)
---------------------------------------------------------------------------------------------------
local DIRV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
local BELT_T = { ["transport-belt"] = true, ["underground-belt"] = true }
local ptype = {} -- type du prototype par nom (cache LOCAL : le même chez tous les pairs, jamais lu par une décision)
local function type_of(name)
  local v = ptype[name]
  if v == nil then
    local pr = game.entity_prototypes[name]
    v = pr and pr.type or false
    ptype[name] = v
  end
  return v or nil
end

local function items_on(b)
  return b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count()
end

--- Vrai si une pièce de TRANSPORT est au plan, non posée, sur la tuile (x, y) (détenteur de la tuile : b.occ).
local function unbuilt_at(b, x, y)
  local occ = b.occ and b.occ[P.tkey(math.floor(x), math.floor(y))]
  local q = type(occ) == "number" and b.projects[occ] or nil
  if not q then return false, occ end
  local tx, ty = math.floor(x), math.floor(y)
  for _, e in ipairs(q.ents or {}) do
    if not e.built and not e.dropped and math.floor(e.x) == tx and math.floor(e.y) == ty and BELT_T[type_of(e.name) or ""] then return true, occ end
  end
  return false, occ
end

local function takers(surface, force, b)
  local tiles, cur, n = {}, b, 0
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  while cur and n < 64 do
    local tx, ty = math.floor(cur.position.x), math.floor(cur.position.y)
    local k = tx .. ":" .. ty
    if tiles[k] then break end
    tiles[k] = true
    x0, y0, x1, y1 = math.min(x0, tx), math.min(y0, ty), math.max(x1, tx), math.max(y1, ty)
    local ins = cur.belt_neighbours.inputs
    if #ins == 0 and cur.type == "underground-belt" and cur.belt_to_ground_type == "output" then cur = cur.neighbours else cur = ins[1] end
    n = n + 1
  end
  local c = 0
  for _, i in ipairs(surface.find_entities_filtered({ area = { { x0 - 3, y0 - 3 }, { x1 + 4, y1 + 4 } }, type = "inserter", force = force })) do
    local q = i.pickup_position
    if tiles[math.floor(q.x) .. ":" .. math.floor(q.y)] then c = c + 1 end
  end
  return c
end

--- Classe d'un tapis posé (nil : il a une sortie, ou il n'est pas chargé).
local function belt_class(f, surface, pid, ent)
  local b = f.build
  local ug = ent.type == "underground-belt"
  local d = DIRV[ent.direction] or DIRV[0]
  local x, y = ent.position.x, ent.position.y
  if ug and ent.belt_to_ground_type == "input" then
    if ent.neighbours ~= nil or items_on(ent) < 6 then return nil end
    local pending = false
    for i = 1, (ent.prototype.max_underground_distance or 0) do
      if unbuilt_at(b, x + d[1] * i, y + d[2] * i) then pending = true break end
    end
    return E.cul_classe({ suite_a_poser = pending, souterrain_seul = true }), items_on(ent)
  end
  if #ent.belt_neighbours.outputs > 0 then return nil end
  local n = items_on(ent)
  if n < 6 then return nil end
  local fx, fy = x + d[1], y + d[2]
  local pole = surface.find_entities_filtered({ position = { fx, fy }, radius = 0.4, type = "electric-pole", force = ent.force, limit = 1 })[1]
  if pole then
    local after = surface.find_entities_filtered({ position = { fx + d[1], fy + d[2] }, radius = 0.4, type = { "transport-belt", "underground-belt" },
      force = ent.force, limit = 1 })[1]
    if after and after.direction == ent.direction then return "coupe", n end
  end
  local pending, occ = unbuilt_at(b, fx, fy)
  return E.cul_classe({ suite_a_poser = pending, preneurs = takers(surface, ent.force, ent), occ_suiv = occ, propre = pid }), n
end

local function scan_belts(f, surface, t, budget)
  local b = f.build
  if not (b and b.order and b.projects) or budget <= 0 then return end
  local steps, reads = 0, 0
  local cur = t.cur
  while reads < budget and steps < budget * 20 do
    steps = steps + 1
    local pid = b.order[cur.i]
    if pid == nil then cur.i, cur.j = 1, 1 break end
    local p = b.projects[pid]
    local e = p and p.ents and p.ents[cur.j]
    if not e then
      cur.i, cur.j = cur.i + 1, 1
    else
      cur.j = cur.j + 1
      if e.built and not e.dropped and not e.skipped and BELT_T[type_of(e.name) or ""] then
        reads = reads + 1
        local k = string.format("%d,%d", math.floor(e.x), math.floor(e.y))
        local ent = surface.find_entity(e.name, { e.x, e.y })
        local cl, n = nil, 0
        if ent and ent.valid and ent.force.name == (f.force or "player") then cl, n = belt_class(f, surface, pid, ent) end
        if cl == "impasse" or cl == "souterrain_ampute" or cl == "coupe" then
          if t.culs[k] or #sorted_keys(t.culs) < 64 then t.culs[k] = { classe = cl, x = e.x, y = e.y, n = n } end
        else
          t.culs[k] = nil
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Relevé des faits
---------------------------------------------------------------------------------------------------
local CFG = nil -- seuils (E.seuils), calculés au premier relevé : constantes du mod, les mêmes chez tous les pairs

local function first_unbuilt(p)
  local built = 0
  local x, y
  for _, e in ipairs(p.ents or {}) do
    if e.built then built = built + 1 elseif not x and not e.dropped then x, y = e.x, e.y end
  end
  return built, x, y
end

local function facts_of(f, surface, t, tick)
  local facts = {}
  local cs = f.team and f.team.capi
  local r = cs and cs.res
  if r then
    facts.capi = { Y = r.Y, spent = r.spent, budget = r.budget, bank = cs.st and cs.st.bank or 0, s = r.s, delta = r.delta, alpha = r.alpha }
  end
  local b = f.build
  local v = b and b.vapeur
  if v and tick - (v.tick or 0) <= 2 * V.EVERY then
    facts.elec = { demand = v.demand, cap = v.cap, fed = v.fed, boilers = v.boilers }
  end
  local ia3 = f.team and f.team.ia3
  local bl = ia3 and ia3.bilan
  if bl and bl.items then
    facts.sous = {}
    for _, k in ipairs(sorted_keys(bl.items)) do
      if Bi.level(bl, k) == "sous" then facts.sous[#facts.sous + 1] = { k, bl.items[k].b, bl.items[k].d } end
    end
  end
  local no = ia3 and ia3.noyau
  if no and not no.covered and no.tick and tick - no.tick <= Rs.FRESH_TICKS then
    facts.besoins = {}
    for _, k in ipairs(sorted_keys(no.missing)) do
      local e = bl and bl.items and bl.items[k]
      facts.besoins[#facts.besoins + 1] = { k, no.missing[k], e and e.p or 0 }
    end
  end
  if b and b.projects then
    facts.bloques, facts.chevauchements = {}, {}
    for _, pid in ipairs(sorted_keys(b.noprog)) do
      local rec, p = b.noprog[pid], b.projects[pid]
      if p and rec and rec.since then
        local age = (tick - rec.since) / 3600
        if age >= CFG.stall then
          local built, x, y = first_unbuilt(p)
          facts.bloques[#facts.bloques + 1] = { pid = pid, age = age, built = built, total = #(p.ents or {}), x = x, y = y,
            cause = p.bloc_cause or p.state, kind = p.spec and (p.spec.key or p.spec.gen) or "?" }
        end
      end
    end
    for _, pid in ipairs(b.order or {}) do
      local p = b.projects[pid]
      if p and p.state == "refuse" and not t.chev[pid] then
        local n, dropped, x, y = #(p.ents or {}), 0, nil, nil
        for _, e in ipairs(p.ents or {}) do
          if e.dropped then dropped = dropped + 1; x, y = x or e.x, y or e.y end
        end
        t.chev[pid] = true
        if n > 0 and dropped == n then facts.chevauchements[#facts.chevauchements + 1] = { pid = pid, x = x, y = y, dropped = dropped, total = n } end
      end
    end
  end
  local za = ErrP.EXT.zero_alert
  if cs and cs.zero and za then
    facts.zero = {}
    for _, label in ipairs(sorted_keys(cs.zero)) do
      local n = cs.zero[label] or 0
      if n >= za then facts.zero[#facts.zero + 1] = { label, n * (ErrP.EXT.couv_every or E.PERIOD) / 3600 } end
    end
  end
  local ch = t.champ
  if ch and tick - ch.tick <= 2 * (ch.every or E.PERIOD) then
    facts.champ = ch
    facts.vides = ch.vides
  end
  facts.culs = {}
  for _, k in ipairs(sorted_keys(t.culs)) do facts.culs[#facts.culs + 1] = t.culs[k] end
  local s = f.recon
  if s and s.lost then
    local by = {}
    for _, k in ipairs(sorted_keys(s.lost)) do
      local rr = s.lost[k]
      if rr.x and rr.tick then
        local ck = math.floor(rr.x / CHUNK) .. ":" .. math.floor(rr.y / CHUNK)
        local g = by[ck]
        if not g then g = { ck = ck, x = rr.x, y = rr.y, n = 0, age = 0 }; by[ck] = g end
        g.n = g.n + 1
        local age = (tick - rr.tick) / 3600
        if age > g.age then g.age, g.x, g.y = age, rr.x, rr.y end
      end
    end
    facts.pertes = {}
    for _, ck in ipairs(sorted_keys(by)) do facts.pertes[#facts.pertes + 1] = by[ck] end
  end
  facts.attaques = {}
  local force = f.force or "player"
  local asked = 0
  for _, ck in ipairs(sorted_keys(t.morts)) do
    local m = t.morts[ck]
    if tick - (m.last or 0) > Rc.RESET then
      t.morts[ck] = nil
    elseif m.vagues >= 2 and asked < 8 then
      asked = asked + 1
      local ok, n = pcall(turrets_in, surface, force, m.cx, m.cy)
      facts.attaques[#facts.attaques + 1] = { ck = ck, x = m.x, y = m.y, vagues = m.vagues, perdus = m.perdus, pv = m.pv, t0 = m.t0,
        t1 = ok and n or m.t0, par = m.par }
    end
  end
  local mk = sorted_keys(t.morts)
  while #mk > Sa.MAX do -- mémoire bornée : la case la plus anciennement touchée sort
    local old, ot = nil, math.huge
    for _, ck in ipairs(mk) do if (t.morts[ck].last or 0) < ot then old, ot = ck, t.morts[ck].last or 0 end end
    t.morts[old] = nil
    mk = sorted_keys(t.morts)
  end
  if t.def and tick - t.def.tick <= 2 * E.PERIOD then facts.defense = t.def.posts end
  return facts
end

--- Étape E6 de la pensée d'une équipe : relevé, épisodes, lignes ; une fois par E.PERIOD.
function ErrP.think(f, surface, tick)
  if not ErrP.ENABLED then return end
  local key = tostring(f.key or "player")
  local t = team_state(key)
  if not t then return end
  -- Balayage des tapis ÉTALÉ sur les pensées : Bilan.READ_MAX lectures par E.PERIOD, au prorata des ticks écoulés (pas de pic par minute)
  local budget = math.min(Bilan.READ_MAX, math.floor(Bilan.READ_MAX * (tick - (t.scan_t or tick)) / E.PERIOD))
  t.scan_t = tick
  if budget > 0 and surface and surface.valid then
    local ok_s, err_s = pcall(scan_belts, f, surface, t, budget)
    if not ok_s and not t.err_said then t.err_said = true; log(string.format("%s %s ERREUR du balayage des tapis : %s", E.TAG, key, tostring(err_s))) end
  end
  if tick < (t.next or 0) then return end
  t.next = tick + E.PERIOD
  local ok, err = pcall(function()
    CFG = CFG or E.seuils({ cap = ErrP.EXT.cap })
    local facts = facts_of(f, surface, t, tick)
    local minute = math.floor(tick / 3600 + 0.5)
    if t.st.minute and minute <= t.st.minute then minute = t.st.minute + 1 end
    for _, line in ipairs(E.step(t.st, key, minute, E.conds(facts, CFG), CFG)) do log(line) end
    log(E.bilan(t.st, key, minute))
  end)
  if not ok and not t.err_said then
    t.err_said = true
    log(string.format("%s %s ERREUR de la sonde (aucun effet sur la partie) : %s", E.TAG, key, tostring(err)))
  end
end

return ErrP
