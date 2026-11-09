--[[
  Lot BOXES (directive du DC du 9/11) : RELEVÉ des boxes d'une équipe (gisement, fonderie, energie, mall) et de leur statut
  (règle pure : shared/team/boxes.lua), une fois par impulsion d'hygiène (script/team/hygiene.lua, tranche 0 : une ligne « lot BOXES »).

  Ce que mesure le relevé, par sorte de box (rien n'est cherché par zone : listes du mod et `find_entity` à une position connue) :
    gisement (un par avant-poste f.outposts[id]) : planned = foreuses au plan des bandes du cadre (st.frame : pièces « champ-foreuse »
      des projets de champ de l'avant-poste, +1 par bande de st.order sans projet : jamais MAXED avant la dernière bande) ; sans cadre :
      planned = built si o.migr == "fini", sinon INCONNU (Bx.UNKNOWN : jamais MAXED) ; built = foreuses vivantes de o.drill_list ;
      powered = celles dont le statut n'est ni no_power, ni low_power, ni no_fuel (une foreuse à combustion est « alimentée » par son
      combustible) ; exhausted = toutes les foreuses vivantes en no_minable_resources, ou plus aucune foreuse et des foreuses retirées
      (o.retired) hors migration ; boîte = emprise des foreuses (± 2 tuiles) ou o.pos ± T.seed_radius.
    fonderie (un par projet de champ « bande » avec au moins une pièce « champ-four ») : planned = pièces du plan (ni skipped ni dropped),
      built = pièces bâties, powered = built moins les consommateurs d'énergie (source électrique ou brûleur au prototype) en défaut
      (no_power, low_power, no_fuel) ; lus seulement sur un projet « fini » (sinon powered = 0) ; exhausted = celui de son gisement.
    energie (la centrale b.plant et b.extra_plants) : planned = pièces du plan, built = pièces bâties, powered = built si le projet est
      « fini » et f.build.sante.healthy == true, sinon 0 (la santé du réseau EST la mesure d'alimentation ; approximation : pas de
      consommateur compté pièce à pièce).
    mall (une par rangée b.mall.rows[j]) : planned = Mr.MAX_CELLS, ou built quand la rangée est arrêtée (r.stop : au bout du secteur) ;
      built = cellules des sections « fini » ; powered = built moins les consommateurs en défaut des projets « fini ».
  Une box MAXED n'est PAS remesurée : seuls ses deux réveils sont lus (épuisement, déblocage) : aucune recherche d'entité pour elle.
  Déblocage : Events.on(on_research_finished) pose f.team.boxes.tech_tick ; à l'impulsion suivante, les recettes activées de la force
  sont comptées par TYPE d'entité posée (Bx.TYPES ; aucun nom) ; une box MAXED dont le compte a grandi passe en UPGRADE_REQUISE,
  levée quand la box change physiquement (planned ou built différents de ceux figés au MAXED).
  État : f.team.boxes = { list = { { kind, id, status, x0, y0, x1, y1, planned, built, powered, at_maxed = { planned, built, recipes } } },
  tick, tech_tick, tech_eval, tech = { [kind] = n } } : nombres, chaînes, booléens, tables.
  Journal : une ligne [FO-BOX] par impulsion (dès qu'il y a au moins une box).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local T = require("shared.team.config")
local Mr = require("shared.team.mall_rangee")
local Bx = require("shared.team.boxes")
local Bur = require("script.team.box_upgrade_rt") -- lot BOX-UPGRADE (DC 9/11) : rétrofit glissant d'une box UPGRADE_REQUISE par impulsion

local Boxes = {}

Boxes.PAD = 2 -- tuiles ajoutées autour de l'emprise d'une box

local function key_of(f) return tostring(f.key or "player") end

--- Clés triées d'une table (le `pairs` ne sert qu'à les ramasser : l'ordre vient du tri).
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Statut « en défaut d'énergie » (sans courant, courant faible, sans combustible).
local function unfed(status)
  local S = defines.entity_status
  return status == S.no_power or status == S.low_power or status == S.no_fuel
end

--- Boîte englobante de positions, ouverte à vide : bb = { x0, y0, x1, y1 } ou nil.
local function grow(bb, x, y)
  if not bb then return { x0 = x, y0 = y, x1 = x, y1 = y } end
  if x < bb.x0 then bb.x0 = x elseif x > bb.x1 then bb.x1 = x end
  if y < bb.y0 then bb.y0 = y elseif y > bb.y1 then bb.y1 = y end
  return bb
end

--- Box écrite : la boîte (rembourrée) et les mesures.
local function make(kind, id, bb, planned, built, powered, exhausted)
  bb = bb or { x0 = 0, y0 = 0, x1 = 0, y1 = 0 }
  return { kind = kind, id = id, x0 = bb.x0 - Boxes.PAD, y0 = bb.y0 - Boxes.PAD, x1 = bb.x1 + Boxes.PAD, y1 = bb.y1 + Boxes.PAD,
    planned = planned, built = built, powered = powered, exhausted = exhausted and true or false }
end

--- Pièces d'un projet : (planned, built, boîte, consommateurs en défaut si `measure`).
local function pieces(surface, p, measure)
  local planned, built, bad, bb = 0, 0, 0, nil
  for _, e in ipairs(p.ents or {}) do
    if not e.skipped and not e.dropped then
      planned = planned + 1
      bb = grow(bb, e.x, e.y)
      if e.built then
        built = built + 1
        if measure then
          local ent = surface.find_entity(e.name, { e.x, e.y })
          if ent and ent.valid and (ent.prototype.electric_energy_source_prototype or ent.prototype.burner_prototype) and unfed(ent.status) then bad = bad + 1 end
        end
      end
    end
  end
  return planned, built, bb, bad
end

--- Foreuses au plan du cadre d'un avant-poste : pièces « champ-foreuse » de ses bandes, +1 par bande de st.order sans projet.
local function frame_planned(b, st, oid)
  local n, seen = 0, {}
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    local c = p and p.spec and p.spec.champ
    if c and c.oid == oid and not c.coal and p.state ~= "refuse" then
      seen[tostring(c.pr)] = true
      for _, e in ipairs(p.ents or {}) do
        if e.role == "champ-foreuse" and not e.skipped and not e.dropped then n = n + 1 end
      end
    end
  end
  for _, pr in ipairs(st.order or {}) do
    if not seen[tostring(pr)] then n = n + 1 end
  end
  return n
end

--- Box gisement d'un avant-poste.
local function gisement(f, o, oid)
  local st = f.migration and f.migration.o and f.migration.o[oid]
  local built, powered, dry, bb = 0, 0, 0, nil
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid then
      built = built + 1
      if not unfed(d.status) then powered = powered + 1 end
      if d.status == defines.entity_status.no_minable_resources then dry = dry + 1 end
      bb = grow(bb, d.position.x, d.position.y)
    end
  end
  local planned = Bx.UNKNOWN
  if st and st.frame and f.build then planned = frame_planned(f.build, st, oid)
  elseif o.migr == "fini" then planned = built end
  if not bb and o.pos then
    local r = (T.seed_radius and T.seed_radius[o.kind]) or 8
    bb = { x0 = o.pos.x - r, y0 = o.pos.y - r, x1 = o.pos.x + r, y1 = o.pos.y + r }
  end
  local exhausted = (built > 0 and dry == built) or (built == 0 and (o.retired or 0) > 0 and o.migr ~= "en cours")
  return make("gisement", oid, bb, planned, built, powered, exhausted)
end

--- Boxes fonderie : un projet de champ « bande » (pas le réseau du charbon) avec au moins une pièce « champ-four ».
local function fonderies(f, surface, out, dry_oid, maxed)
  local b = f.build
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    local c = p and p.spec and p.spec.champ
    if c and not c.coal and p.state ~= "refuse" then
      local four = false
      for _, e in ipairs(p.ents or {}) do if e.role == "champ-four" then four = true break end end
      if four then
        local measure = (p.state == "fini") and not maxed["fonderie:" .. tostring(pid)]
        local planned, built, bb, bad = pieces(surface, p, measure)
        local powered = (p.state == "fini") and (built - bad) or 0
        out[#out + 1] = make("fonderie", pid, bb, planned, built, powered, dry_oid[c.oid] == true)
      end
    end
  end
end

--- Boxes energie : la centrale principale et les centrales de plus.
local function energies(f, out)
  local b = f.build
  local ids = {}
  if b.plant then ids[1] = b.plant end
  for _, id in ipairs(b.extra_plants or {}) do ids[#ids + 1] = id end
  local healthy = b.sante ~= nil and b.sante.healthy == true
  for _, id in ipairs(ids) do
    local p = b.projects[id]
    if p then
      local planned, built, bb = pieces(nil, p, false)
      out[#out + 1] = make("energie", id, bb, planned, built, (p.state == "fini" and healthy) and built or 0, false)
    end
  end
end

--- Boxes mall : une par rangée.
local function malls(f, surface, out, maxed)
  local b = f.build
  local rows = b.mall and b.mall.rows or {}
  for _, r in ipairs(rows) do
    local built, bad, bb, all_done = 0, 0, nil, true
    local measure = not maxed["mall:" .. tostring(r.j)]
    for _, q in ipairs(r.projects or {}) do
      local p = b.projects[q.id]
      if p and p.state == "fini" then
        built = built + (q.to - q.from + 1)
        local _, _, pbb, pbad = pieces(surface, p, measure)
        bad = bad + pbad
        if pbb then bb = grow(grow(bb, pbb.x0, pbb.y0), pbb.x1, pbb.y1) end
      else
        all_done = false
      end
    end
    local planned = (r.stop and all_done) and built or Mr.MAX_CELLS
    out[#out + 1] = make("mall", r.j, bb, planned, built, built - bad, false)
  end
end

--- Recettes activées de la force, comptées par TYPE d'entité posée par un produit (comptage : l'ordre de `pairs` n'a aucun effet).
local function recipes_by_type(force)
  local by = {}
  if not (force and force.recipes) then return by end
  for _, r in pairs(force.recipes) do
    if r.enabled then
      for _, pr in ipairs(r.products or {}) do
        local ip = pr.type == "item" and game.item_prototypes[pr.name]
        local pl = ip and ip.place_result
        if pl then by[pl.type] = (by[pl.type] or 0) + 1 end
      end
    end
  end
  return by
end

--- Comptes par sorte, refaits seulement après une recherche finie (tech_tick) ou au premier relevé.
local function tech_counts(f, bs)
  if bs.tech and bs.tech_eval and (bs.tech_tick or -1) <= bs.tech_eval then return bs.tech end
  local by = recipes_by_type(game and game.forces and game.forces[f.force])
  local t = {}
  for _, k in ipairs(Bx.KINDS) do t[k] = Bx.count_for(k, by) end
  bs.tech, bs.tech_eval = t, bs.tech_tick or 0
  return t
end

--- Statut d'une box mesurée `b` depuis la précédente `prev` (même sorte, même id) et le compte de recettes `n`.
local function decide(b, prev, n)
  local last = prev and prev.status or nil
  local am = prev and prev.at_maxed or nil
  if am and (am.planned ~= b.planned or am.built ~= b.built) then am = nil end -- la box a changé : nouveau cycle
  local tech_new = Bx.tech_new(n, am and am.recipes or nil)
  local status
  if last == Bx.MAXED then status = Bx.wake(last, { exhausted = b.exhausted, tech_new = tech_new })
  else status = Bx.status({ planned = b.planned, built = b.built, powered = b.powered, exhausted = b.exhausted, tech_new = tech_new, last = last }) end
  b.status = status
  if status == Bx.MAXED then b.at_maxed = am or { planned = b.planned, built = b.built, recipes = n }
  elseif status == Bx.UPGRADE_REQUISE then b.at_maxed = am end
  return status
end

--- Relevé de l'équipe `f` au tick `tick` : liste des boxes, statuts, journal [FO-BOX].
function Boxes.releve(f, surface, tick)
  local t = f.team
  if not t then return end
  local bs = t.boxes or {}
  t.boxes = bs
  local prev, maxed = {}, {}
  for _, b in ipairs(bs.list or {}) do
    local k = b.kind .. ":" .. tostring(b.id)
    prev[k] = b
    if b.status == Bx.MAXED then maxed[k] = true end
  end
  local list, dry = {}, {}
  for _, oid in ipairs(sorted_keys(f.outposts or {})) do
    local b = gisement(f, f.outposts[oid], oid)
    if b.exhausted then dry[oid] = true end
    list[#list + 1] = b
  end
  if f.build and f.build.projects then
    fonderies(f, surface, list, dry, maxed)
    energies(f, list)
    malls(f, surface, list, maxed)
  end
  local counts = tech_counts(f, bs)
  local before = {}
  for _, b in ipairs(list) do
    local k = b.kind .. ":" .. tostring(b.id)
    before[k] = prev[k] and prev[k].status or nil
    decide(b, prev[k], counts[b.kind] or 0)
  end
  bs.list, bs.tick = list, tick
  if #list > 0 then
    local c, wakes = Bx.summary(list, before)
    log(Bx.line(key_of(f), tick, c, wakes))
  end
  Bur.impulsion(f, surface, tick) -- lot BOX-UPGRADE (DC 9/11) : une tranche du rétrofit glissant d'UNE box UPGRADE_REQUISE (fonderie, mall)
end

--- Le poteau en (x, y) est-il dans une box MAXED de l'équipe ? (lu par l'audit d'hygiène)
function Boxes.skip_at(f, x, y)
  local bs = f.team and f.team.boxes
  return bs ~= nil and Bx.maxed_at(bs.list, x, y)
end

--- Réveil technologique : une recherche finie marque la force ; l'applicabilité est jugée à l'impulsion suivante.
local function on_research(e)
  local force = e.research and e.research.force
  if not force then return end
  local ids = State.alive()
  if State.faction("player") then ids[#ids + 1] = "player" end
  for _, id in ipairs(ids) do
    local f = State.faction(id)
    if f and f.team and f.force == force.name then
      f.team.boxes = f.team.boxes or {}
      f.team.boxes.tech_tick = e.tick
    end
  end
end

Events.on(defines.events.on_research_finished, on_research)

return Boxes
