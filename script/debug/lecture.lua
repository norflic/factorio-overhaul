--[[
  Lot DEBUG-CERVEAU : LECTURE de l'état des équipes pour la vue « Cerveau ». Lecture seule : rien n'est écrit dans l'état des
  décisions (f.build, f.team, f.outposts) ; le seul état écrit est celui de la vue (script/debug/cerveau.lua).
  Les règles (couleur, écart, lignes) sont pures : shared/debug/*.lua.

  Zones recensées (inventaire du 8/11, docs/IA_WORKFLOW.md §2 et §7) :
    - les PROJETS du plan directeur f.build.projects (module, fonderie, laboratoires, centrale, bande du champ, quartier, liaison, raccord,
      enceinte, site) : état de construction p.state, rectangle de p.parts, produit et débits du suivi de l'automatisation (f.team.ia3e.mods) ;
    - les AVANT-POSTES f.outposts (foreuses et fours des sorties) ;
    - le QG (coffre de l'équipe).
  État réel : statuts des machines de la zone relus au moteur (une zone par tranche, jamais plus de Lec.ENT_MAX entités comptées).
  Ce que le cerveau en sait (reads), seulement ce que le code conserve :
    manque   f.team.mq.reads[projet] (courant, quais, date de lecture) et f.team.mq.res.starved (module affamé) ;
    debit    f.team.ia3e.mods[].rate_meas (débit mesuré par l'automatisation, une fois par minute) ;
    sante    b.sante (centrale : relevé toutes les Rv.PERIOD ticks, verdict healthy) ;
    pensee   avant-postes : le cerveau relit leur état à chaque pensée (f.last_think) mais NE GARDE PAS son verdict (verdict « inconnu »).
  Une zone sans aucune de ces lectures (bande du champ, par exemple) est « jamais lue » : c'est ce que dit la vue, sans l'inventer.
  Pièces manquantes (lost) : non relevées en V1 (un remplacement de niveau change le nom des entités, le relevé donnerait de faux manquants).
]]

local State = require("script.faction.state")
local Zn = require("shared.debug.zone")
local Rv = require("script.team.reseau_vivant")
local An = require("script.debug.anneau")
local Am = require("shared.debug.ameliorations")
local Li = require("shared.debug.liens")
local Lg = require("shared.debug.lignes")
local Pn = require("shared.debug.pnj")
local Bl = require("shared.debug.blocs")
local Storage = require("script.core.storage")

local Lec = {}

Lec.ENT_MAX = 120      -- entités comptées au plus par zone et par relevé
Lec.DECISIONS_MAX = 24
Lec.CHAMP_STALE = 5 * 3600 + 2 * 3600 -- s41 zone-aveugle : période du relevé des champs (Champ.REPORT_EVERY) + Ec.STALE
Lec.OUTPOST_ENTS = 60  -- foreuses et réceptacles lus au plus pour l'emprise d'un avant-poste
local MACHINE_TYPES = { "furnace", "assembling-machine", "lab", "mining-drill", "pumpjack", "boiler", "generator" }

local STATUS_NAME -- défini au premier relevé : table locale dérivée de defines (constantes), jamais dans global

local function status_name(v)
  if not STATUS_NAME then
    STATUS_NAME = {}
    for name, value in pairs(defines.entity_status) do STATUS_NAME[value] = name end -- construction d'un index inverse : l'ordre ne compte pas
  end
  return STATUS_NAME[v]
end

local function sorted_keys(t) return State.sorted_keys(t or {}) end

---------------------------------------------------------------------------------------------------
-- Équipes
---------------------------------------------------------------------------------------------------
--- Équipes observables : votre équipe (id "player") puis les factions en vie. { id, f, key }.
function Lec.teams()
  local out = {}
  local p = State.faction("player")
  if p then out[#out + 1] = { id = "player", f = p, key = "player" } end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f then out[#out + 1] = { id = id, f = f, key = tostring(f.key or id) } end
  end
  return out
end

function Lec.team(id)
  if id == nil then id = "player" end
  return State.faction(id)
end

local function surface_of(f)
  if f.hq and f.hq.valid then return f.hq.surface end
  return nil
end
Lec.surface_of = surface_of

---------------------------------------------------------------------------------------------------
-- Recensement des zones (sans appel de scan du moteur)
---------------------------------------------------------------------------------------------------
local function project_kind(p)
  local spec = p.spec or {}
  if spec.champ then return "champ" end
  if spec.liaison or spec.rapatriement then return "liaison" end -- une ligne (Li.lines), pas un bloc
  if spec.quartier then return "quartier" end
  if spec.enceinte then return "enceinte" end
  local part = p.parts and p.parts[1]
  local pk = part and part.kind
  if pk == "raccord" then return "raccord" end
  if pk == "centrale" then return "centrale" end
  if spec.site then return "site" end
  if spec.gen == "labs" then return "labos" end
  if spec.gen == "smelter" or spec.gen == "fonderie" then return "fonderie" end
  return "module"
end

local function project_rect(p)
  local x0, y0, x1, y1
  local function add(ax, ay, bx, by)
    if x0 == nil or ax < x0 then x0 = ax end
    if y0 == nil or ay < y0 then y0 = ay end
    if x1 == nil or bx > x1 then x1 = bx end
    if y1 == nil or by > y1 then y1 = by end
  end
  for _, pt in ipairs(p.parts or {}) do
    if pt.ox and pt.oy and pt.w and pt.h then add(pt.ox, pt.oy, pt.ox + pt.w, pt.oy + pt.h) end
  end
  if x0 == nil then
    for _, e in ipairs(p.ents or {}) do
      if e.x and e.y then add(e.x - 0.5, e.y - 0.5, e.x + 0.5, e.y + 0.5) end
    end
  end
  return x0, y0, x1, y1
end

local function ia3e_mod(f, pid)
  local st = f.team and f.team.ia3e
  for _, m in ipairs(st and st.mods or {}) do
    if m.id == pid then return m end
  end
  return nil
end

--- Squelettes de zone d'une équipe, triés (projets par numéro, avant-postes par numéro, QG). Aucune lecture d'entité.
function Lec.skeletons(f)
  local out = {}
  local b = f.build
  if b then
    for _, pid in ipairs(b.order or {}) do
      local p = b.projects[pid]
      if p and p.state ~= "refuse" then
        local x0, y0, x1, y1 = project_rect(p)
        local m = ia3e_mod(f, pid)
        local spec = p.spec or {}
        local built = 0
        for _, e in ipairs(p.ents or {}) do if e.built then built = built + 1 end end
        out[#out + 1] = { key = "p" .. pid, pid = pid, kind = project_kind(p), state = p.state, reason = p.reason and tostring(p.reason) or nil,
          built = built, total = #(p.ents or {}), x0 = x0, y0 = y0, x1 = x1, y1 = y1,
          product = (m and m.product) or spec.product, rate_nom = (m and m.rate_nom) or nil, rate_meas = (m and m.state == "fini") and m.rate_meas or nil,
          prio = p.prio, io = Bl.io(p.quais, p.outs) }
      end
    end
  end
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    if o and o.pos then
      -- emprise : boîte des foreuses et réceptacles encore valides (au plus Lec.OUTPOST_ENTS lus), marge de 3 tuiles ; à défaut, 12 x 12 autour du site
      local x0, y0, x1, y1
      local seen = 0
      for _, list in ipairs({ o.drill_list or {}, o.sinks or {} }) do
        for _, e in ipairs(list) do
          if seen < Lec.OUTPOST_ENTS and e.valid then
            seen = seen + 1
            local pos = e.position
            if x0 == nil or pos.x < x0 then x0 = pos.x end
            if x1 == nil or pos.x > x1 then x1 = pos.x end
            if y0 == nil or pos.y < y0 then y0 = pos.y end
            if y1 == nil or pos.y > y1 then y1 = pos.y end
          end
        end
      end
      if x0 == nil then x0, y0, x1, y1 = o.pos.x - 3, o.pos.y - 3, o.pos.x + 3, o.pos.y + 3 end
      out[#out + 1] = { key = "o" .. oid, oid = oid, kind = "avant_poste", state = "fini", sub = o.kind, product = nil,
        x0 = x0 - 3, y0 = y0 - 3, x1 = x1 + 3, y1 = y1 + 3, built = o.drills, total = o.drills }
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Relevé de l'état réel d'une zone (UNE zone par appel)
---------------------------------------------------------------------------------------------------
local function count_entities(surface, force_name, rect_list, filter_fn, cap)
  local machines, n = {}, 0
  for _, r in ipairs(rect_list) do
    -- lot DBG-COURANT : les MACHINES seules (règle du DC : « sans courant » seulement si une machine du module en manque) ; un bras hors
    -- portée d'un poteau ne fait plus passer un module qui tourne à plein pour « sans courant » (partie du DC, 0.7.3 : ~15 fausses alertes)
    local found = surface.find_entities_filtered({ area = { { r[1], r[2] }, { r[3], r[4] } }, force = force_name, type = MACHINE_TYPES })
    for _, e in ipairs(found) do
      if e.valid and n < cap then
        local pos = e.position
        -- F96 : une entité qui TOUCHE seulement le bord de la zone n'en fait pas partie
        if pos.x > r[1] and pos.x < r[3] and pos.y > r[2] and pos.y < r[4] and (filter_fn == nil or filter_fn(e)) then
          local cause = Zn.cause_of_status(status_name(e.status))
          machines[cause] = (machines[cause] or 0) + 1
          n = n + 1
        end
      end
    end
  end
  return machines, n
end

--- Relève l'état réel de la zone `z` (table du recensement) et y écrit : machines, color, cause, ratio, n, top, mtick.
function Lec.measure(f, z, tick)
  local surface = surface_of(f)
  z.mtick = tick
  if not surface then
    z.color, z.cause, z.n, z.top = "gris", "inconnu", 0, {}
    return z
  end
  local rects = {}
  local b = f.build
  if z.pid and b and b.projects[z.pid] then
    local p = b.projects[z.pid]
    local any = false
    for _, pt in ipairs(p.parts or {}) do
      if pt.ox and pt.oy and pt.w and pt.h then rects[#rects + 1] = { pt.ox, pt.oy, pt.ox + pt.w, pt.oy + pt.h } any = true end
    end
    if not any and z.x0 then rects[1] = { z.x0, z.y0, z.x1, z.y1 } end
  elseif z.oid and z.x0 then
    rects[1] = { z.x0, z.y0, z.x1, z.y1 }
  end
  local machines, n = {}, 0
  if z.state == "fini" and #rects > 0 then machines, n = count_entities(surface, f.force, rects, nil, Lec.ENT_MAX) end
  z.machines = machines
  local r = Zn.classify({ state = z.state, machines = machines })
  z.color, z.cause, z.ratio, z.n, z.top = r.color, r.cause, r.ratio, r.n, r.top
  z.run = machines[Zn.RUN] or 0
  return z
end

---------------------------------------------------------------------------------------------------
-- Ce que le cerveau en sait
---------------------------------------------------------------------------------------------------
--- Lectures du cerveau sur la zone `z` : liste { src, verdict, why, tick } (voir l'en-tête). Lecture seule.
function Lec.reads(f, z)
  local out = {}
  local t = f.team or {}
  if z.pid then
    local mq = t.mq
    local rd = mq and mq.reads and mq.reads[z.pid]
    if rd then
      -- power == nil : le cerveau n'a trouvé aucune machine à lire (inconnu, refusé par Mq) : jamais « marche » (revue-s, A)
      local verdict = rd.power == false and "arret" or (rd.power == true and "marche" or "inconnu")
      out[#out + 1] = { src = "manque", verdict = verdict, why = verdict == "arret" and "courant" or nil, tick = rd.read_tick }
      for _, s in ipairs(mq.res and mq.res.starved or {}) do
        if s.id == z.pid then
          out[#out] = { src = "manque", verdict = "arret", why = "entree", tick = rd.read_tick }
          break
        end
      end
    end
    local st = t.ia3e
    local m = ia3e_mod(f, z.pid)
    if m and m.state == "fini" and m.rate_meas ~= nil and st and st.last_min ~= nil then
      -- un débit nul pendant la première minute d'un module fini est un artefact de mesure (Auto : made_prev absent) : pas un jugement (revue-s, D)
      local young = m.finished_m ~= nil and st.last_min - m.finished_m < 2
      local verdict = m.rate_meas > 0 and "marche" or (young and "inconnu" or "arret")
      out[#out + 1] = { src = "debit", verdict = verdict, why = verdict == "arret" and "debit_nul" or nil, tick = st.last_min * 3600 }
    end
    -- s41 zone-aveugle : bande du champ, relevé des champs (Champ.report, toutes les Ch.REPORT_EVERY ticks) gardé dans p.champ_read
    local cp = f.build and f.build.projects and f.build.projects[z.pid]
    local cr = cp and cp.champ_read
    if type(cr) == "table" and type(cr.tick) == "number" then
      out[#out + 1] = { src = "champ", verdict = cr.verdict, why = cr.why, tick = cr.tick, stale = Lec.CHAMP_STALE }
    end
    if z.kind == "centrale" and f.build and f.build.sante then
      local sv = f.build.sante
      -- b.sante est créé avec healthy = false avant tout relevé : une lecture n'existe qu'après un relevé réel (revue-s, C). last_why est un
      -- texte libre : jamais traduit, la cause est « autre ».
      local read = sv.healthy == true or (sv.decisions or 0) > 0 or (sv.last_why or "") ~= ""
      if type(sv.next) == "number" and read then
        out[#out + 1] = { src = "sante", verdict = sv.healthy and "marche" or "arret", why = (not sv.healthy) and "autre" or nil, tick = sv.next - Rv.PERIOD }
      end
    end
  elseif z.oid then
    if f.last_think then out[#out + 1] = { src = "pensee", verdict = "inconnu", tick = f.last_think } end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Tâches, décisions, améliorations
---------------------------------------------------------------------------------------------------
--- Refus d'amélioration d'une zone (projet pid) : lignes { famille, cause, tick }, triées par famille. Vide sans le champ.
function Lec.am_refus_rows(f, pid)
  local refus = f.team and f.team.capital and f.team.capital.refus
  local out = {}
  for _, key in ipairs(sorted_keys(type(refus) == "table" and refus or {})) do
    local a = Lg.am_refus(key, refus[key])
    if a and a.pid == pid then out[#out + 1] = a end
  end
  return out
end

--- Lignes enregistrées (quai, bus, piquage, rapatriement) avec leur état réel et la cause d'un refus ou d'une coupure : règle pure shared/debug/liens.lua
--- (lot DEBUG-BLOCS). Copies de nombres et de chaînes ; extrémités = centres des coffres.
function Lec.links(f, extra)
  local b = f.build
  local list = {}
  for _, pid in ipairs(b and b.order or {}) do
    local p = b.projects[pid]
    if p then
      list[#list + 1] = { pid = pid, state = p.state, finished = p.finished, abandoned = p.abandoned, reason = p.reason, spec = p.spec, rap = p.rap }
    end
  end
  for _, d in ipairs(extra or {}) do list[#list + 1] = d end
  return Li.lines(list, { piquage = b and b.piquage, rapatriement = b and b.rapatriement })
end

--- BANC D'IMAGES SEULEMENT (interface distante « demo », jamais allumée par le mod) : lignes FICTIVES entre les vrais blocs d'une équipe, pour contrôler le
--- dessin d'une liaison de quai, d'un piquage en chantier, d'une demande refusée et d'une ligne de rapatriement quand la partie n'en a pas encore.
--- Elles ne sont JAMAIS écrites dans f.build : elles s'ajoutent à la liste lue, rien d'autre.
function Lec.demo_projects(skel)
  local rects = {}
  for _, z in ipairs(skel) do
    if z.x0 and z.y0 and z.x1 and z.y1 and z.kind ~= "liaison" and z.kind ~= "raccord" then rects[#rects + 1] = z end
  end
  if #rects < 2 then return {} end
  local A, B, C = rects[1], rects[2], rects[3] or rects[2]
  local function mid(z) return math.floor((z.y0 + z.y1) / 2) end
  local out = {
    { pid = 9001, state = "fini", spec = { liaison = { key = "demo1", item = "iron-plate", src = { pid = A.pid, x = math.floor(A.x1), y = mid(A) },
      dock = { pid = B.pid, x = math.floor(B.x0), y = mid(B) } } } },
    { pid = 9002, state = "refuse", reason = "DEMO : ennemi a portee de la route", spec = { liaison = { key = "demo2", item = "copper-plate",
      src = { pid = A.pid, x = math.floor(A.x1), y = mid(A) + 2 }, dock = { pid = C.pid, x = math.floor(C.x0), y = mid(C) + 2 } } } },
    { pid = 9003, state = "chantier", spec = { liaison = { key = "demo3", piquage = true, item = "coal", geo = { x = math.floor(A.x0) - 8.5, y = mid(A) - 6.5 },
      dock = { pid = A.pid, x = math.floor(A.x0), y = mid(A) - 3 } } } },
    { pid = 9004, state = "fini", spec = { rapatriement = { key = "demo4", item = "stone-brick", src = { pid = C.pid, x = math.floor(C.x1), y = mid(C) },
      point = { x = math.floor(A.x0), y = mid(A) + 4 } } }, rap = { tampon_x = math.floor(A.x0), tampon_y = mid(A) + 4 } },
  }
  return out
end

--- Agent (PNJ) dont le corps est l'entité `e`, ou nil. Lecture du registre des compagnons.
function Lec.agent_of_entity(e)
  if not (e and e.valid and e.unit_number) then return nil end
  local S = Storage.ns("companion")
  local id = S and S.by_unit and S.by_unit[e.unit_number]
  return id and S.agents[id] or nil
end

--- Agent (PNJ) de numéro `id`, ou nil.
function Lec.agent(id)
  local S = Storage.ns("companion")
  return S and S.agents and S.agents[id] or nil
end

--- Équipe d'un agent (State.faction de agent.faction), ou nil.
function Lec.team_of_agent(agent)
  return agent and agent.faction and State.faction(agent.faction) or nil
end

--- Tâches LIBRES du tableau avec leur pause d'échec et la matière stricte qui leur manque (lecture seule, RIEN n'est réservé) : liste
--- { key, kind, prio, pause, missing = { item, need, free } | nil }, au plus `max` examinées dans l'ordre de la liste du tableau.
function Lec.free_tasks(f, now, max)
  local out = {}
  local board = f.team and f.team.board
  if not board then return out end
  local okb, Board = pcall(require, "script.team.board")
  local okr, R = pcall(require, "shared.ai3.registre")
  local reg = f.team and f.team.reg
  local list = board.list or {}
  for i = 1, #list do
    if #out >= (max or 40) then break end
    local t = list[i]
    if type(t) == "table" and not t.worker and board.tasks and board.tasks[t.key] == t then
      local missing
      if okb and okr and reg then
        for _, it in ipairs(Board.strict_list(t) or {}) do
          local free = R.free(reg, it[1])
          if free < it[2] then missing = { item = it[1], need = it[2], free = free } break end
        end
      end
      out[#out + 1] = { key = t.key, kind = t.kind, prio = t.prio, pause = math.max(0, ((board.cooldown or {})[t.key] or 0) - now), missing = missing }
    end
  end
  return out
end

--- État cognitif d'un PNJ : voir shared/debug/pnj.lua. Lecture seule.
Lec.ZERO_IDLE_CAUSES = { aucun_libre = true, servis = true, stock = true, combustible = true, plein = true, en_cours = true, non_defendu = true,
  menace = true, palier = true, aucune_fonderie = true, autre = true }

function Lec.npc(f, agent, now)
  local out = { id = agent.id, state = Pn.state_word(agent.state), team = tostring(f.key or "player") }
  local org = agent.org
  if type(org) == "table" then out.role, out.pole = org.role, org.pole end
  local t = agent.task
  if t then
    out.task = { key = tostring(t.key), kind = t.kind, prio = t.prio, outpost = t.outpost, pid = t.ia1d and t.ia1d.pid or nil, mode = t.ia1d and t.ia1d.mode or nil,
      resource = t.resource, taken = t.took == true }
  end
  out.steps = Pn.step_rows(agent.steps, agent.pc)
  local free = Lec.free_tasks(f, now, 40)
  out.nexts = Pn.next_rows(free)
  out.explain = Pn.explain({ state = agent.state, has_task = t ~= nil, wait_left = agent.wait_until and (agent.wait_until - now) or nil,
    nav_fail = agent.nav_fail, free = free })
  local e = agent.entity
  if e and e.valid then
    out.x, out.y = e.position.x, e.position.y
    local inv = e.get_main_inventory()
    if inv then
      local c = inv.get_contents()
      local names = {}
      for name in pairs(c) do names[#names + 1] = name end -- tri juste après
      table.sort(names)
      out.carry = {}
      for i, name in ipairs(names) do
        if i > 4 then break end
        out.carry[#out.carry + 1] = { item = name, n = c[name] }
      end
    end
  end
  out.stuck = agent.stuck
  -- l'équipe : PNJ affamés et travail ouvert par la file sûre à la dernière pensée (f.team.org.sur.last, lot INACTIFS, [FO-INACTIF])
  local sl = f.team and f.team.org and f.team.org.sur and f.team.org.sur.last
  if type(sl) == "table" then out.team_sur = { starved = sl.starved, want = sl.want, service = sl.service, mine = sl.mine } end
  -- refus de la porte de comportement a la prise de tache (lot ZERO-IDLE : agent.gate_why, agent.gate_tick ; mot libre du module de comportement, recopie)
  if type(agent.gate_why) == "string" and type(agent.gate_tick) == "number" then
    out.gate = { why = agent.gate_why:sub(1, 40), age = now - agent.gate_tick }
  end
  -- agrandissements non emis pour les PNJ libres (lot ZERO-IDLE : f.team.zero_idle.last, mots fixes)
  local zl = f.team and f.team.zero_idle and f.team.zero_idle.last
  if type(zl) == "table" and Lec.ZERO_IDLE_CAUSES[zl.cause] and type(zl.tick) == "number" and now - zl.tick <= 7200 then
    out.zero_idle = { cause = zl.cause, libres = zl.libres, emis = zl.emis, restes = zl.restes, age = now - zl.tick }
  end
  -- pourquoi des PNJ libres n'ont rien a faire (lot MINAGE-MAIN, f.team.sources.idle = { code, tick, n }, mots fixes) ; au-dela de 2 min : perime, non montre
  local idle = f.team and f.team.sources and f.team.sources.idle
  if type(idle) == "table" and type(idle.tick) == "number" and now - idle.tick <= 7200
      and (idle.code == "matiere" or idle.code == "bloquees" or idle.code == "aucune") then
    out.team_idle = { code = idle.code, n = idle.n, age = now - idle.tick }
  end
  return out
end

--- Quais du piquage d'une zone (projet) : lignes { key, i, verdict, cause, tick }, vide sans piquage.
function Lec.piquage_rows(f, pid)
  local pq = f.build and f.build.piquage
  return Am.piquage_rows(type(pq) == "table" and pq.quais or nil, pid)
end

--- Tâches du tableau, aplaties : { key, kind, mode, prio, taken, pid, outpost }.
function Lec.tasks(f)
  local out = {}
  local board = f.team and f.team.board
  if not board then return out end
  for _, key in ipairs(sorted_keys(board.tasks)) do
    local t = board.tasks[key]
    if type(t) == "table" then
      local first = t.items and t.items[1]
      out[#out + 1] = { key = key, kind = t.kind, mode = t.ia1d and t.ia1d.mode or nil, prio = t.prio, taken = t.worker ~= nil,
        pid = t.ia1d and t.ia1d.pid or nil, outpost = t.outpost, item = type(first) == "table" and type(first[1]) == "string" and first[1] or nil }
    end
  end
  return out
end

local function rec_text(rec)
  local what = tostring(rec.item or rec.resource or rec.entity or "?")
  local left = rec.n_left and rec.n and string.format(" %d/%d", rec.n_left, rec.n) or ""
  local miss = ""
  if rec.missing and #rec.missing > 0 then
    local parts = {}
    for i, m in ipairs(rec.missing) do
      if i > 3 then break end
      parts[#parts + 1] = tostring(m[1]) .. " " .. tostring(m[2])
    end
    miss = " ; manque " .. table.concat(parts, ", ")
  end
  return string.format("%s %s (%s)%s%s", tostring(rec.kind), what, tostring(rec.exec or "?"), left, miss)
end

--- Lignes de « décisions récentes » : { tick, kind, text }, non triées (Lg.decisions trie et coupe).
function Lec.decision_rows(f)
  local rows = {}
  local cs = f.team and f.team.capi
  if cs then
    for _, rec in ipairs(cs.open or {}) do
      rows[#rows + 1] = { tick = rec.opened, kind = "ordre_ouvert", text = rec_text(rec) .. (rec.blocked and (" ; bloque : " .. tostring(rec.blocked)) or "") }
    end
    for _, d in ipairs(cs.done or {}) do
      rows[#rows + 1] = { tick = d.closed, kind = d.state == "fini" and "ordre_fini" or "ordre_echec",
        text = string.format("%s (%s)%s", tostring(d.key), tostring(d.exec), d.why and (" : " .. tostring(d.why)) or "") }
    end
    -- les refus et envois avec leur RAISON viennent de l'anneau (script/debug/anneau.lua) ; un refus que l'anneau ne connaît pas (décidé
    -- avant l'ouverture du mod à jour, ou sorti de l'anneau) n'a pour lui que sa date : dit tel quel
    local in_ring = {}
    for _, e in ipairs(An.get(f.key or "player")) do
      if e.s == "refus" then in_ring[e.k] = true end
    end
    for _, key in ipairs(sorted_keys(cs.refused)) do
      if not in_ring[key] then rows[#rows + 1] = { tick = cs.refused[key], kind = "refus_sans_raison", text = tostring(key) } end
    end
    if cs.repli_text then rows[#rows + 1] = { kind = "repli", text = tostring(cs.repli_text) } end
  end
  for _, e in ipairs(An.get(f.key or "player")) do
    rows[#rows + 1] = { tick = e.t, kind = e.s == "refus" and "refus" or "envoye", text = e.r ~= "" and (e.k .. " : " .. e.r) or e.k }
  end
  -- MINAGE-MAIN : la dernière décision d'approvisionnement par ressource (f.team.sources.dec), mots fixes
  local src = f.team and f.team.sources and f.team.sources.dec
  for _, res in ipairs(sorted_keys(type(src) == "table" and src or {})) do
    local row = Lg.source_row(res, src[res])
    if row then rows[#rows + 1] = row end
  end
  -- DEFENSE-STOCK : les lieux de défense évalués à la dernière pensée (f.defstock.rows), mots fixes, au plus Lg.DEF_MAX
  local ds = f.defstock and f.defstock.rows
  for i, r in ipairs(type(ds) == "table" and ds or {}) do
    if i > Lg.DEF_MAX then break end
    local row = Lg.defense_row(r)
    if row then rows[#rows + 1] = row end
  end
  local st = f.team and f.team.ia3e
  for _, l in ipairs(st and st.logs or {}) do rows[#rows + 1] = { tick = l.tick, kind = "module", text = tostring(l.text) } end
  local cap = f.team and f.team.capital
  if cap then
    -- AMELIORATION : le dernier refus par bloc et famille (f.team.capital.refus), mots fixes
    local refus = type(cap.refus) == "table" and cap.refus or {}
    for _, key in ipairs(sorted_keys(refus)) do
      local row = Lg.am_refus_row(key, refus[key])
      if row then rows[#rows + 1] = row end
    end
    for _, h in ipairs(cap.history or {}) do rows[#rows + 1] = { tick = h.tick, kind = "capital", text = "amélioration " .. tostring(h.key) } end
    if cap.current and cap.current.key then rows[#rows + 1] = { kind = "capital_courant", text = tostring(cap.current.key) } end
  end
  return rows
end

--- Faits donnés à Am.evaluate (shared/debug/ameliorations.lua) : { [clé du catalogue] = { state, why } }.
function Lec.improvement_facts(f)
  local facts = {}
  local cap = f.team and f.team.capital
  if cap and cap.current and cap.current.key then
    facts.niveau = { state = "prevue", why = tostring(cap.current.key) }
  elseif cap and type(cap.refus) == "table" then
    -- aucun choix en cours : le refus le plus récent explique pourquoi (mot fixe traduit)
    local best
    for _, key in ipairs(sorted_keys(cap.refus)) do
      local a = Lg.am_refus(key, cap.refus[key])
      if a and (best == nil or (a.tick or 0) >= (best.tick or 0)) then best = a end
    end
    if best then facts.niveau = { state = "refusee", why = { "fo-dbg-cerveau.am-refus-" .. best.cause } } end
  end
  local b = f.build
  local ln = b and b.liaison
  if ln then
    -- l'état de la liaison est tenu dans b.liaison (script/team/liaison.lua) : seul un projet de liaison ouvert est vu ici
    for _, pid in ipairs(b.order or {}) do
      local p = b.projects[pid]
      if p and p.spec and p.spec.liaison and p.state ~= "fini" and p.state ~= "refuse" then
        facts.liaison = { state = "en_cours", why = tostring(p.state) }
        break
      end
    end
  end
  -- PIQUAGE (lot PIQUAGE) : f.build.piquage.quais, écrit par son seul code ; le champ existe = le mécanisme existe dans cette version. Le charbon est
  -- un quai comme un autre pour lui (même état) : les deux lignes du catalogue qu'il couvre prennent le même fait.
  local pq = b and b.piquage
  if type(pq) == "table" then
    local sum = Am.piquage_summary(pq.quais)
    local why = sum.why and { "fo-dbg-cerveau.pq-ligne", { "fo-dbg-cerveau.pq-verdict-" .. sum.why.verdict }, { "fo-dbg-cerveau.pq-cause-" .. sum.why.cause }, sum.why.n } or nil
    facts.bras_repartiteur = { present = true, state = sum.state, why = why }
    facts.charbon_tapis = { present = true, state = sum.state, why = why }
  end
  local st = f.team and f.team.ia3e
  for _, m in ipairs(st and st.mods or {}) do
    if m.state ~= "fini" and m.state ~= "refuse" then
      facts.machine = { state = "en_cours", why = tostring(m.product) .. " : " .. tostring(m.state) }
      break
    end
  end
  return facts
end

return Lec
