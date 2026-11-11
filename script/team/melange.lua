--[[
  Lot MELANGE, côté RUNTIME (règle pure : shared/team/melange.lua). Retour du DC du 3/11 (2 h 30 de jeu) : « dans cette zone il est
  possible qu'il y ait 2 minerais ou plus [...] lorsque le four a environ 5 de charbon, il n'est plus mis dedans, et les minerais de
  charbon prennent la place des minerais de fer sur les convoyeurs, et peu à peu, plus de minerai de fer n'arrive ».

  Les plans neufs ne posent plus de foreuse sur une zone mêlée (shared/team/champ.lua, spec.foreign). Pour les bandes DÉJÀ posées, un
  relevé par équipe toutes les Run.EVERY ticks (appelé par script/team/migration_champ.lua, Mig.think) :
    - foreuses des bandes du champ (rôle « champ-foreuse ») : zone relue au moteur (ressources dont le CENTRE est à moins du rayon du
      prototype, catégories que la foreuse sait miner) ; zone mêlée -> foreuse retirée, rendue au stock (modules compris), pièce marquée
      e.dropped (jamais reposée par le relevé de reconstruction) ; zone saine -> e.mel_ok (une zone ne se mêle jamais après coup) ;
    - tapis des bandes (rôle « champ-tapis ») : objets étrangers au minerai de la bande relevés et rendus au stock ; bande « encombrée »
      quand l'étranger y est majoritaire.
  Journal : [FO-MELANGE] (événements, plafonnés) et [FO-MELANGE-ETAT] (cumuls, toutes les Run.REPORT_EVERY ticks).
  Déterminisme : projets dans l'ordre de b.order, pièces dans l'ordre du plan, noms triés ; aucun `pairs` dans une décision.
]]

local Mel = require("shared.team.melange")
local Stock = require("script.team.stock")
local State = require("script.faction.state")
local T = require("shared.team.config")
local Champ = require("script.team.champ")
local Zone = require("script.team.zone_melee") -- lot MELANGE2 : lecture de la zone au moteur (sans cycle de require)

local Run = {}

Run.EVERY = 2 * 3600        -- ticks entre deux relevés d'une équipe
Run.REPORT_EVERY = 5 * 3600 -- une ligne [FO-MELANGE-ETAT] par équipe
Run.LOGS = 60               -- lignes [FO-MELANGE] au plus par équipe
Run.REMOVE = true           -- foreuse dont la zone est mêlée : retirée

local PROD = {} -- mémoire LOCALE (prototypes seulement) : produits d'une ressource
local function products(res)
  local t = PROD[res]
  if t == nil then
    t = {}
    local rp = game.entity_prototypes[res]
    local mp = rp and rp.mineable_properties
    for _, pr in ipairs(mp and mp.products or {}) do if pr.name then t[pr.name] = true end end
    PROD[res] = t
  end
  return t
end

local function st_of(f)
  local s = f.melange
  if not s then
    s = { next = 0, report_next = 0, logs = 0, checked = 0, mixed = 0, removed = 0, passes = 0, jams = 0, items = 0, by = {} }
    f.melange = s
  end
  return s
end

local function say(f, s, text)
  s.logs = s.logs + 1
  if s.logs > Run.LOGS then return end
  log(string.format("[FO-MELANGE] %s : %s a %.1f min", f.key or "player", text, game.tick / 3600))
end

local function names_line(list)
  local t = {}
  for _, it in ipairs(list) do t[#t + 1] = it[1] .. " " .. it[2] end
  return table.concat(t, ", ")
end

--- Lot MELANGE : zone d'une foreuse `name` (prototype) posée au centre (x, y), ressource visée `res` -> "ok" | "melange", étrangers.
--- Lecteur : script/team/foreuse_swap.lua (une foreuse électrique de 5 × 5 à la place d'une thermique de 2 × 2). Lecture seule.
--- (lot MELANGE2 : la lecture vit dans script/team/zone_melee.lua, que script/faction/outposts.lua charge sans cycle)
function Run.zone_at(surface, name, x, y, res)
  return Zone.verdict(surface, name, x, y, res)
end

local function zone_of(surface, ent, res)
  return Zone.zone_at(surface, ent.prototype, ent.position.x, ent.position.y, res)
end

local function item_of(e, ent)
  if e.item then return e.item end
  local its = ent.prototype.items_to_place_this
  return its and its[1] and its[1].name or e.name
end

--- Retire la foreuse : modules au stock, entité détruite sans événement, objet rendu au stock.
local function take_back(f, ent, item)
  local inv = ent.get_inventory(defines.inventory.mining_drill_modules)
  if inv then
    local c = inv.get_contents()
    for _, name in ipairs(State.sorted_keys(c)) do Stock.insert(f, name, c[name]) end
    inv.clear()
  end
  if ent.unit_number then State.disown(ent.unit_number) end
  ent.destroy()
  if item then Stock.insert(f, item, 1) end
end

--- Objets étrangers relevés d'une voie : rendus au stock (le reste, si le stock refuse, posé au sol près du QG, jamais sur un tapis).
local function clear_line(f, line, clear, s)
  local n = 0
  for _, it in ipairs(clear) do
    -- Lot STOCKAGE-VITAL (objets au sol, 7/11) : seulement ce que le stock prend (le reste reste sur le tapis, rien au sol du QG)
    local room = Stock.room and Stock.room(f, it[1])
    local want = room and math.min(it[2], room) or it[2]
    local got = want > 0 and line.remove_item({ name = it[1], count = want }) or 0
    if got > 0 then
      local put = Stock.insert(f, it[1], got)
      if put < got and f.hq and f.hq.valid then -- dernier recours, marqué à ramasser (Stock.pick_ground)
        f.hq.surface.spill_item_stack(f.hq.position, { name = it[1], count = got - put }, true, f.force, false)
      end
      s.by[it[1]] = (s.by[it[1]] or 0) + got
      n = n + got
    end
  end
  return n
end

--- Ressource de la bande du projet `p` (avant-poste ou gisement du champ), gardée sur le projet si la cible se perd.
local function resource_of(f, p)
  local o = Champ.target(f, p.spec.champ.oid)
  local sp = o and o.kind and T.outposts[o.kind]
  if sp and sp.resource then p.mel_res = sp.resource end
  return p.mel_res
end

--- Un projet de bande : foreuses à zone mêlée retirées, tapis relevés. `res` : ressource visée.
local function project(f, surface, s, pid, p, res)
  -- B1 (MELANGE2) : le PRODUIT de la ressource (plaques) est admis sur les tapis de la bande ; la colonne à tapis le porte sur le sien
  local made = {}
  for _, k in ipairs(T.OUTPOST_ORDER) do
    if T.outposts[k].resource == res then made[#made + 1] = T.outposts[k].product end
  end
  -- lot FONDERIE (colonne à tapis, 0.6.42) : la colonne porte le charbon sur sa seconde voie ; il n'est pas étranger sur ses tapis
  local carried
  local fr = p.spec.champ.frame
  if fr and fr.design == "colonne" then
    carried = {}
    local cs = T.outposts.coal
    for _, name in ipairs(State.sorted_keys(cs and products(cs.resource) or {})) do carried[#carried + 1] = name end
    if T.fuel then carried[#carried + 1] = T.fuel end
  end
  local items = Mel.belt_items(products(res), made, carried)
  local tot, lines = {}, {}
  local removed0 = s.removed
  for _, e in ipairs(p.ents) do
    if e.built and not e.dropped and e.role == "champ-foreuse" and e.mel_ok ~= e.name then
      local ent = surface.find_entity(e.name, { e.x, e.y })
      if ent and ent.valid and Mel.needs_check(e.mel_ok, ent.name) then
        s.checked = s.checked + 1
        local v, list = zone_of(surface, ent, res)
        if v == "ok" then
          e.mel_ok = ent.name -- point 40 : retenu par NOM d'entité, relu quand le nom change
        else
          s.mixed = s.mixed + 1
          local what = "laissee"
          if Run.REMOVE then
            take_back(f, ent, item_of(e, ent))
            e.dropped, e.melange = true, game.tick
            s.removed = s.removed + 1
            what = "retiree, rendue au stock"
          end
          say(f, s, string.format("projet %s bande %s : foreuse en (%.1f, %.1f) sur une zone melee (%s ; cible %s) : %s", tostring(pid),
            tostring(p.spec.champ.pr), e.x, e.y, names_line(list), res, what))
        end
      end
    elseif e.built and e.role == "champ-tapis" then
      local ent = surface.find_entity(e.name, { e.x, e.y })
      if ent and ent.valid then
        for i = 1, ent.get_max_transport_line_index() do
          local line = ent.get_transport_line(i)
          local c = line.get_contents()
          local has = false
          for _, name in ipairs(State.sorted_keys(c)) do
            tot[name] = (tot[name] or 0) + c[name]
            if not items[name] then has = true end
          end
          if has then lines[#lines + 1] = { line = line, c = c } end
        end
      end
    end
  end
  -- lot MELANGE2 (revue du 3/11) : une bande dont le relevé vient de retirer la DERNIÈRE foreuse reste « finie » avec 0 production ; rien ne
  -- la répare (journal seulement, aucun autre traitement)
  if s.removed > removed0 then
    local left = 0
    for _, e in ipairs(p.ents) do
      if e.role == "champ-foreuse" and not e.dropped then left = left + 1 end
    end
    if left == 0 then
      s.emptied = (s.emptied or 0) + 1
      say(f, s, string.format("projet %s bande %s : bande videe, toutes ses foreuses retirees (zone melee), plus aucune production", tostring(pid),
        tostring(p.spec.champ.pr)))
    end
  end
  if #lines > 0 then
    local v = Mel.belt_verdict(tot, items)
    local got = 0
    for _, l in ipairs(lines) do got = got + clear_line(f, l.line, Mel.belt_verdict(l.c, items).clear, s) end
    s.items = s.items + got
    if v.majority then s.jams = s.jams + 1 end
    say(f, s, string.format("projet %s bande %s : tapis %s (minerai %d, etranger %d : %s) ; %d objet(s) releve(s) au stock", tostring(pid),
      tostring(p.spec.champ.pr), v.majority and "ENCOMBRE" or "pollue", v.target, v.foreign, names_line(v.clear), got))
  end
end

--- Lot MELANGE2 (revue du 3/11, « NON COUVERT » n° 2) : foreuses d'un GABARIT du plan directeur (parties `foreuses` d'un projet, posées
--- avant la règle de 0.6.42 ou par une sauvegarde plus ancienne) : zone relue au moteur contre la ressource de la partie, foreuse à
--- zone mêlée retirée comme celles des bandes du champ. Le projet garde sa pièce (e.dropped) : jamais reposée par la reconstruction.
--- La foreuse est cherchée par position et TYPE (le nom change quand un niveau la grandit : fo-lvl-drill-N).
local function gabarit(f, surface, s, pid, p)
  for _, e in ipairs(p.ents) do
    local part = e.part and p.parts and p.parts[e.part]
    if e.built and not e.dropped and part and part.kind == "foreuses" and part.ore and not e.role then
      local ents = surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.5, type = "mining-drill", limit = 1 })
      local ent = ents[1]
      if ent and ent.valid and Mel.needs_check(e.mel_ok, ent.name) then
        s.checked = s.checked + 1
        local v, list = zone_of(surface, ent, part.ore)
        if v == "ok" then
          e.mel_ok = ent.name -- point 40 : relu quand un niveau agrandit la foreuse (nom change) (comme les bandes du champ : une seule lecture ; risque R2 de la revue, le niveau qui agrandit la zone, noté)
        else
          s.mixed = s.mixed + 1
          local what = "laissee"
          if Run.REMOVE then
            take_back(f, ent, item_of(e, ent))
            e.dropped, e.melange = true, game.tick
            s.removed = s.removed + 1
            what = "retiree, rendue au stock"
          end
          say(f, s, string.format("projet %s gabarit %s : foreuse en (%.1f, %.1f) sur une zone melee (%s ; cible %s) : %s", tostring(pid),
            tostring(part.key), e.x, e.y, names_line(list), part.ore, what))
        end
      end
    end
  end
end

function Run.pass(f, surface, tick)
  local b = f.build
  if not (b and b.order) then return end
  local s = st_of(f)
  if tick < s.next then return end
  s.next = tick + Run.EVERY
  s.passes = s.passes + 1
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    local res = p and p.spec and p.spec.champ and p.ents and resource_of(f, p)
    if res then project(f, surface, s, pid, p, res)
    elseif p and p.ents and p.parts and not (p.spec and p.spec.champ) then gabarit(f, surface, s, pid, p) end
  end
  if tick >= s.report_next then
    s.report_next = tick + Run.REPORT_EVERY
    local by = {}
    for _, name in ipairs(State.sorted_keys(s.by)) do by[#by + 1] = name .. " " .. s.by[name] end
    log(string.format("[FO-MELANGE-ETAT] %s min %.0f | releves %d | foreuses verifiees %d, zones melees %d, retirees %d | bandes videes %d | tapis encombres %d (bande x releve), objets etrangers releves %d (%s)",
      f.key or "player", tick / 3600, s.passes, s.checked, s.mixed, s.removed, s.emptied or 0, s.jams, s.items, #by > 0 and table.concat(by, ", ") or "rien"))
  end
end

--- Banc en moteur réel (scénario melange-banc) : le même relevé sur des entités données, une équipe fictive dont le stock est le coffre
--- `hq`. args = { hq, resource, colonne = bool, gabarit = bool, drills = { LuaEntity }, belts = { LuaEntity } } -> cumuls { checked, mixed, removed, items, jams, by }.
if remote and remote.add_interface then remote.add_interface("fo-melange", {
  releve = function(args)
    local f = { key = "melange-banc", hq = args.hq, build = { order = {}, projects = {} } }
    local ents = {}
    for _, d in ipairs(args.drills or {}) do
      if d.valid then
        -- gabarit (lot MELANGE2) : pièces d'une partie `foreuses`, sans rôle ; bande du champ : rôle « champ-foreuse »
        ents[#ents + 1] = { name = d.name, x = d.position.x, y = d.position.y, built = true, role = (not args.gabarit) and "champ-foreuse" or nil,
          part = args.gabarit and 1 or nil }
      end
    end
    for _, t in ipairs(args.belts or {}) do
      if t.valid then ents[#ents + 1] = { name = t.name, x = t.position.x, y = t.position.y, built = true, role = "champ-tapis" } end
    end
    local p = { spec = { champ = { oid = -1, pr = "banc", frame = args.colonne and { design = "colonne" } or nil } }, ents = ents, mel_res = args.resource, state = "fini" }
    local s = st_of(f)
    if args.gabarit then
      p.spec = {}
      p.parts = { { kind = "foreuses", ore = args.resource, key = "banc" } }
      gabarit(f, args.hq.surface, s, "banc", p)
    else
      project(f, args.hq.surface, s, "banc", p, args.resource)
    end
    return { checked = s.checked, mixed = s.mixed, removed = s.removed, items = s.items, jams = s.jams, by = s.by, emptied = s.emptied or 0 }
  end,
}) end -- (hors jeu, les bancs simulés n'ont pas `remote`)

return Run
