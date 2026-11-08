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

local Lec = {}

Lec.ENT_MAX = 120      -- entités comptées au plus par zone et par relevé
Lec.DECISIONS_MAX = 24
Lec.OUTPOST_ENTS = 60  -- foreuses et réceptacles lus au plus pour l'emprise d'un avant-poste
local MACHINE_TYPES = { "furnace", "assembling-machine", "lab", "mining-drill", "pumpjack", "boiler", "generator" }
local ALL_TYPES = { "furnace", "assembling-machine", "lab", "mining-drill", "pumpjack", "boiler", "generator", "inserter" }
local IS_MACHINE = {}
for _, t in ipairs(MACHINE_TYPES) do IS_MACHINE[t] = true end

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
  if spec.liaison then return "liaison" end
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
          prio = p.prio }
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
  local machines, aux, n = {}, { courant = 0 }, 0
  for _, r in ipairs(rect_list) do
    local found = surface.find_entities_filtered({ area = { { r[1], r[2] }, { r[3], r[4] } }, force = force_name, type = ALL_TYPES })
    for _, e in ipairs(found) do
      if e.valid and n < cap then
        local pos = e.position
        -- F96 : une entité qui TOUCHE seulement le bord de la zone n'en fait pas partie
        if pos.x > r[1] and pos.x < r[3] and pos.y > r[2] and pos.y < r[4] and (filter_fn == nil or filter_fn(e)) then
          local cause = Zn.cause_of_status(status_name(e.status))
          if IS_MACHINE[e.type] then
            machines[cause] = (machines[cause] or 0) + 1
            n = n + 1
          elseif cause == "courant" then
            aux.courant = aux.courant + 1
          end
        end
      end
    end
  end
  return machines, aux, n
end

--- Relève l'état réel de la zone `z` (table du recensement) et y écrit : machines, aux, color, cause, ratio, n, top, mtick.
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
  local machines, aux, n = {}, { courant = 0 }, 0
  if z.state == "fini" and #rects > 0 then machines, aux, n = count_entities(surface, f.force, rects, nil, Lec.ENT_MAX) end
  z.machines, z.aux = machines, aux
  local r = Zn.classify({ state = z.state, machines = machines, aux = aux })
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
  local st = f.team and f.team.ia3e
  for _, l in ipairs(st and st.logs or {}) do rows[#rows + 1] = { tick = l.tick, kind = "module", text = tostring(l.text) } end
  local cap = f.team and f.team.capital
  if cap then
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
