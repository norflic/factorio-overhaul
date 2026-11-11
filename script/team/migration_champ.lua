--[[
  Lot MIGRATION-CHAMP (retour du DC du 29/10 en jouant la 0.6.16) : « les foreuses thermiques, elles mettent directement dans des
  fours [...] l'idéal, ça serait du coup de revoir l'organisation du champ, en tout cas de parties du champ qui, par exemple, sont sur
  thermique, c'est pas optimal, on met de l'électrique à la place, on enlève les fours ceux qui sont directement sur les ressources, on
  place des foreuses à la place » ; « on veut des rangées de foreuses ». Règle pure : shared/team/migration_champ.lua.

  Tâche de FOND, une pensée toutes les CFG.every ticks par équipe, UN avant-poste à la fois. Un avant-poste de PAIRES foreuse thermique +
  four (celui de T.outposts dont le réceptacle est un four) est migré PAR PARTIES. Pour chaque partie :
    1. (veille)   l'équipe a le plan directeur, un réseau qui produit, l'objet de foreuse électrique, des plaques libres, aucun ennemi à
                  CFG.safe tuiles : la règle choisit une partie du champ (paires voisines d'un même lot de gisement du treillis dont le
                  retrait libère la place d'une ligne de foreuses) ;
    2. (projet)   une demande au PLAN DIRECTEUR (Build.request) : la fonderie à tapis de 0.6.17 (gabarit « smelter », voie de minerai servie
                  par une ligne de foreuses électriques et un collecteur, poteaux, fantômes, PNJ bâtisseurs), dimensionnée à la production
                  de la partie (spec.fixe, spec.paires) et placée près du champ ; les tuiles de la partie comptent comme LIBRES au plan
                  (spec.degel : script/team/build.lua, THAW). Le champ continue de produire pendant que le projet attend ses matières ;
    3. (retrait)  quand le projet a ses matières (état « reserve », raison « degel »), la partie est RETIRÉE (foreuses, fours, contenus
                  rendus au stock) si aucun ennemi n'est à CFG.safe tuiles et s'il reste une paire debout (ou si une ligne neuve a déjà
                  produit), puis le plan reprend (p.degele) : défrichage, fantômes, chantier ;
    4. (chantier) la partie suivante ne démarre que lorsque la ligne neuve a PRODUIT (produits finis de ses fours).
  Une demande annulée ou refusée avant le retrait ne coûte rien. Aucun objet retiré n'est perdu (ce qui ne tient pas au coffre est
  répandu au sol du QG). Le registre de reconstruction n'est pas autorisé à refaire une paire thermique de l'avant-poste migré.

  Journal : [FO-MIGRATION] par étape et par cause (une ligne par changement de cause, au plus CFG.logs lignes courantes par équipe).
  État : f.migration = { next, logs, o = { [id d'avant-poste] = { stage, fails, noop, done, produced, pid, ids, t0, ... } }, cur } :
  nombres, booléens, chaînes et listes de nombres ; jamais d'entité ni de fonction. o.migr (avant-poste) : "en cours", "partiel", "fini".
  Lecteurs : Outposts.extend et Outposts.reopen (pas d'agrandissement thermique), Outposts.status (plus de tournée d'un champ migré),
  script/team/foreuse_swap.lua (pas de remplacement sur place pendant la migration), script/team/build.lua (THAW, porte « degel »).
]]

local T = require("shared.team.config")
local Mod = require("shared.team.modules")
local P = require("shared.team.plan")
local D = require("shared.team.automatisation_donnees")
local Mg = require("shared.team.migration_champ")
local Mp = require("shared.team.mega_pose") -- lot MEGA-FONDERIE (A2) : bandes en avance d'un gisement à méga-fonderie décidée (règle pure)
local Rb = require("shared.team.migration_retour") -- lot AZURE : retour en arrière d'une bande qui n'aboutit pas (règle pure)
local Th = require("shared.team.thermique") -- lot THERMIQUE : couvert, balayage, protection, ordre, créneaux (règle pure)
local Mc = require("shared.team.migration_combustible") -- lot COMBUSTIBLE-MIGRATION : plancher du combustible (générateurs + brûleurs), retrait permis, stock bas (règle pure)
local Rc = require("shared.team.reconstruction")
local Gens = require("script.team.generateurs") -- lot X10-S4 : registre des génératrices (plus de recherche sur toute la surface)
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Build = require("script.team.build")
local Champ = require("script.team.champ") -- lot CHAMP : la partie migrée est une BANDE du champ en rangées (shared/team/champ.lua), hors du treillis
local Melange = require("script.team.melange") -- lot MELANGE : foreuses des bandes sur une zone mêlée, tapis encombrés d'un autre minerai
local Ra = require("script.team.reserve_amorcage") -- lot FOREUSES-THERMIQUES : réserve d'amorçage du combustible (module léger)
local Sw = require("shared.team.foreuse_swap") -- (Sw.reserve_keepers : les K gardées d'un retrait de masse)
local PileRt = require("script.team.pile") -- lot THERMIQUE5 : porte de la pile pour le départ d'une bande neuve pendant une retenue

local Profiler = require("script.core.profiler") -- lot X10-S0 : portees fines (mesure seulement)
local AdRt = require("script.ai3.anti_dispersion") -- lot IA-GARDE : garde anti-dispersion (shared/ai3/anti_dispersion.lua)
local Mig = {}

local CFG = Mg.CFG
-- Lot CHAMP : règles de la migration en BANDES du champ (la règle de shared/team/migration_champ.lua, ces seuils changés) :
--   min_pairs 1    une seule paire suffit (un avant-poste neuf de paires passe au champ dès que le courant et les objets le permettent) ;
--   keep_pairs 0   la bande qui remplace les paires produit plus qu'elles : un petit avant-poste n'est plus bloqué par la garde
--                  (« garde » annulait la demande : un champ d'une seule bande ne migrait jamais) ;
--   EXT_PLATES     une bande SANS paire (agrandissement du champ) n'est demandée que si la plaque du champ est sous ce stock libre.
local CHAMP_CFG = {}
for _, k in ipairs(State.sorted_keys(CFG)) do CHAMP_CFG[k] = CFG[k] end
CHAMP_CFG.min_pairs, CHAMP_CFG.keep_pairs = 1, 0
-- gate_wait 90 min, retry 3 min : une bande qui attend ses matières (tapis, bras, poteaux à fabriquer) n'est plus annulée au bout de 30 min
-- pour être redemandée 15 min plus tard, réserve rendue entre les deux (mesuré, partie de 150 min, graine 20261020 : deux bandes d'Azure
-- annulées « matieres » à 52 et 68 min, la suivante demandée à 87 min : 35 min sans bande)
CHAMP_CFG.gate_wait, CHAMP_CFG.retry = 90 * 3600, 3 * 3600
CHAMP_CFG.pause = 5 * 3600 -- lot RACCORD-BANDE : une bande du champ abandonnée sur des refus du plan repart d'un état neuf après 5 min (au lieu de CFG.revive : 30 min)
CHAMP_CFG.block_max = 15 * 3600 -- une bande bloquée (fantôme refusé) est laissée au plan après 15 min : la suivante part (step_build)
-- Lot THERMIQUE5 (revue du 3/11, cause 4) : une bande d'un minerai porté BRUT au coffre (charbon, pierre) n'exige plus de plaques de fer libres
-- (Th.min_plates) : la demande fait fabriquer ses matières (Mig.projects) ; Azure 20261020 ne demandait ni charbon ni pierre de 41 à 150 min
local CHAMP_RAW_CFG = {}
for _, k in ipairs(State.sorted_keys(CHAMP_CFG)) do CHAMP_RAW_CFG[k] = CHAMP_CFG[k] end
CHAMP_RAW_CFG.min_plates = Th.min_plates(true, CHAMP_CFG.min_plates)
CHAMP_CFG.min_plates = Th.min_plates(false, CHAMP_CFG.min_plates)
local EXT_PLATES = 3000

--- Lot SATURATION (directive du DC du 9/11) : pièces d'une bande planifiée, par nom : { { name, n, machine } } (machine : rôle de foreuse ou de
--- four du plan du champ). Nombres, chaînes et booléens seulement : gardé dans l'état de la migration (st.band_need) pour la porte des bandes en
--- avance sans replanifier la bande.
local function band_list(bd)
  local count, mach, names = {}, {}, {}
  for _, e in ipairs(bd and bd.ents or {}) do
    if not count[e.name] then names[#names + 1] = e.name end
    count[e.name] = (count[e.name] or 0) + 1
    local r = tostring(e.role or "")
    if r:find("foreuse", 1, true) or r:find("four", 1, true) then mach[e.name] = true end
  end
  table.sort(names)
  local list = {}
  for _, nm in ipairs(names) do list[#list + 1] = { name = nm, n = count[nm], machine = mach[nm] == true } end
  return list
end

--- Fer (matières premières du livre) qu'il reste à FABRIQUER pour la bande `bd` une fois ses pièces déjà au stock `free` retirées (lot SATURATION :
--- avant, la bande entière était comptée, stock dormant compris), et l'état de saturation. nil si le livre ne sait pas le dire.
local function band_iron(book, bd, free)
  if not (book and bd and bd.ents) then return nil end
  local sat = Mp.saturation(band_list(bd), free)
  if #sat.net == 0 then return 0, sat end
  local ok, raw = pcall(function() return book:raw_cost(sat.net) end)
  local iron = ok and raw and raw[T.outposts.iron.product] or nil
  if iron == nil then return nil, sat end
  return math.max(0, iron), sat
end
local FURNACE_INVENTORIES = { "furnace_source", "furnace_result", "fuel" }
local CHEST_INVENTORIES = { "chest" }

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function name_of(f) return f.key or "player" end

--- Ligne de journal. `force` : lignes d'étape terminale, comptées à part (jamais coupées par le plafond des lignes courantes).
local function say(f, ms, text, force)
  if force then
    ms.logs_f = (ms.logs_f or 0) + 1
    if ms.logs_f > 120 then return end -- (lot CHAMP : 40 avant ; le devenir de chaque bande est forcé, champ_bandes.py le lit)
  else
    ms.logs = ms.logs + 1
    if ms.logs > CFG.logs then return end
  end
  log("[FO-MIGRATION] " .. name_of(f) .. " : " .. text)
end

--- Une raison d'attente n'est écrite qu'à son changement.
local function say_why(f, ms, st, key, text, force)
  if st.why_last == key then return end
  st.why_last = key
  say(f, ms, text, force)
end

--- Lot CHAMP : plusieurs champs migrent EN MÊME TEMPS (créneaux ms.cur, ms.cur2 et, depuis THERMIQUE, ms.cur3, de minerais différents) ;
--- ms.cur reste le créneau lu par les autres modules (script/team/pile.lua, Mig.project).
-- Lot THERMIQUE : trois créneaux au plus (Th.CFG.slots), un seul par minerai (Th.free_slot) : le fer, le cuivre, le charbon et la pierre avancent
-- ensemble (avant : deux créneaux, charbon et pierre jamais migrés).
local SLOTS = { "cur", "cur2", "cur3" }
local function claim(ms, id)
  for _, s in ipairs(SLOTS) do
    if not ms[s] then ms[s] = id; return end
  end
end
local function release(ms, id)
  local kept = {}
  for _, s in ipairs(SLOTS) do
    if ms[s] ~= nil and ms[s] ~= id then kept[#kept + 1] = ms[s] end
    ms[s] = nil
  end
  for i, v in ipairs(kept) do ms[SLOTS[i]] = v end
end

---------------------------------------------------------------------------------------------------
-- Lectures
---------------------------------------------------------------------------------------------------
local function is_furnace_kind(kind)
  local spec = T.outposts[kind]
  local proto = spec and game.entity_prototypes[spec.sink]
  return proto ~= nil and proto.type == "furnace"
end

--- Lot THERMIQUE : un avant-poste dont le réceptacle est un COFFRE (charbon, pierre) passe aussi par le champ, en mode coffres (bras tapis -> coffre
--- de sortie, shared/team/champ.lua). Les ordres de la capitalisation (Mig.takes) restent aux avant-postes à fours.
local function is_champ_kind(kind)
  local spec = T.outposts[kind]
  local proto = spec and game.entity_prototypes[spec.sink]
  return proto ~= nil and (proto.type == "furnace" or proto.type == "container")
end

local function box_of(e)
  local p = e.prototype
  return { x = e.position.x, y = e.position.y, w = p.tile_width or 1, h = p.tile_height or 1 }
end

--- Paires foreuse thermique + four VIVANTES de l'avant-poste, et les entités par numéro. Rien n'est écrit.
local function survey(o)
  local drills, sinks, ents = {}, {}, {}
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid and d.name == T.DRILL and d.unit_number then
      local b = box_of(d)
      drills[#drills + 1] = { id = d.unit_number, x = b.x, y = b.y, dir = d.direction, w = b.w, h = b.h }
      ents[d.unit_number] = d
    end
  end
  for _, s in ipairs(o.sinks or {}) do
    if s.valid and (s.type == "furnace" or s.type == "container") and s.unit_number then
      local b = box_of(s)
      sinks[#sinks + 1] = { id = s.unit_number, x = b.x, y = b.y, w = b.w, h = b.h }
      ents[s.unit_number] = s
    end
  end
  return Mg.match(drills, sinks, T.drill_drop), ents
end

--- Lot CHAMP : avant-postes du MÊME minerai sur le même gisement que `o` (centre à moins de Champ.SIB_R tuiles), triés par numéro.
--- Un champ se planifie une fois pour tout le gisement : leurs paires sont retirées sous les bandes comme celles de `o`.
--- Lot CHAMP : la position `p` est-elle dans la boîte du gisement d'un champ sans avant-poste (Mig.want, marge CFG.want_margin) ?
local function in_box(box, p)
  local m = Mg.CFG.want_margin
  return p.x >= box[1] - m and p.x <= box[3] + m and p.y >= box[2] - m and p.y <= box[4] + m
end

local function siblings(f, o)
  local out = {}
  local r2 = Champ.SIB_R * Champ.SIB_R
  -- un gisement sans avant-poste (o.box) n'a pour voisins que ce qui est dans SA boîte : à 64 tuiles, un avant-poste d'un gisement voisin
  -- serait pris pour le même gisement et ne migrerait plus (« son gisement est le champ de... »)
  local function near(q)
    if o.box then return in_box(o.box, q.pos) end
    if q.box then return in_box(q.box, o.pos) end
    return (q.pos.x - o.pos.x) ^ 2 + (q.pos.y - o.pos.y) ^ 2 <= r2
  end
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local q = f.outposts[oid]
    if q ~= o and q.kind == o.kind and near(q) then out[#out + 1] = q end
  end
  -- gisements sans avant-poste demandés par la capitalisation (Mig.want) : voisins eux aussi (un seul champ par gisement)
  local fields = f.migration and f.migration.fields
  for _, fid in ipairs(sorted_keys(fields)) do
    local q = fields[fid]
    if q ~= o and q.kind == o.kind and near(q) then out[#out + 1] = q end
  end
  return out
end

--- Paires de `o` et de ses voisins du même gisement (lot CHAMP), comme survey(o).
local function survey_field(f, o)
  local all = { drill_list = {}, sinks = {} }
  for _, q in ipairs({ o, table.unpack(siblings(f, o)) }) do
    for _, d in ipairs(q.drill_list or {}) do all.drill_list[#all.drill_list + 1] = d end
    for _, x in ipairs(q.sinks or {}) do all.sinks[#all.sinks + 1] = x end
  end
  return survey(all)
end

--- Lots de gisement du treillis qui portent des paires (clé du lot posée sur chaque paire) : { [clé] = { x0, y0, x1, y1 } }.
local function lots_of(f, o, list)
  local b = f.build
  local ore = T.outposts[o.kind].resource
  local rects = {}
  for _, pr in ipairs(list) do
    local i, j = P.lot_of(b.lat, pr.drill.x, pr.drill.y)
    if i then
      local key = P.lot_key(i, j)
      local l = b.lots[key]
      if l and l.state == "gisement" and l.res == ore then
        pr.lot = key
        if not rects[key] then
          local x0, y0, x1, y1 = P.lot_rect(b.lat, i, j)
          rects[key] = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
        end
      end
    end
  end
  return rects
end

--- Méthode du plan directeur qui fond le produit de l'avant-poste (données de l'exécutant : aucun nom écrit ici).
local function method_of(kind)
  local product = T.outposts[kind] and T.outposts[kind].product
  for _, m in ipairs(D.METHODS) do
    if m.gen == "smelter" and m.feed == "tapis" and m.product == product then return m end
  end
  return nil
end

--- Cadences de la règle (gabarits de modules.lua) pour la méthode `m`, ou nil.
local function rates_of(m)
  local ore = m.args[2]
  local plate = Mod.PLATE_OF[ore]
  local g1 = Mod.GEN.smelter(m.args[1], ore, 1)
  local dg = Mod.GEN.drills(ore, 1)
  local bsp, esp = Mod.spec(T.DRILL), Mod.spec(T.DRILL_ELECTRIC)
  if not (plate and g1 and g1.nominal and g1.nominal[plate] and dg and bsp and esp) then return nil end
  local row_cap = g1.nominal[plate]
  return { burner = bsp.speed, electric = esp.speed, row_cap = row_cap, furnace = row_cap / 2,
    pairs_max = dg.extensions and dg.extensions[1] and dg.extensions[1].max or 1 }
end

local function line_of(ore)
  return function(n)
    local g = Mod.GEN.drills(ore, n)
    if g then return g.w, g.h end
    return nil
  end
end

--- Un réseau qui produit (centrale du plan finie, aucune pièce perdue, production > 0 : script/team/reseau_vivant.lua).
local function power_ok(b)
  return b.sante ~= nil and b.sante.healthy == true
end

local function enemy_near(f, surface, x, y)
  return surface.find_nearest_enemy({ position = { x = x, y = y }, max_distance = CFG.safe, force = f.force }) ~= nil
end

--- Le plan a-t-il posé une entité sur une tuile de la partie (tuiles `thaw`, liste plate) ?
local function uses_thaw(p, thaw)
  local set = {}
  for i = 1, #thaw - 1, 2 do set[P.tkey(thaw[i], thaw[i + 1])] = true end
  for _, e in ipairs(p.ents or {}) do
    for _, t in ipairs(P.tiles_of(e)) do
      if set[P.tkey(t[1], t[2])] then return true end
    end
  end
  return false
end

--- Produits finis des fours de la ligne neuve (au plus 24 fours lus), et (lot THERMIQUE6) vrai si la ligne produit EN CE MOMENT (un four
--- au moins en marche ; bande à coffres : au moins deux foreuses en marche, ou toutes si elle n'en a qu'une).
local function made_by(f, surface, p)
  local n, seen, live = 0, 0, false
  local drills, working = 0, 0
  for _, e in ipairs(p.ents or {}) do
    local proto = game.entity_prototypes[e.name]
    if e.built and proto and proto.type == "furnace" then
      if seen < 24 then
        seen = seen + 1
        local found = surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.6, type = "furnace", force = f.force })
        local fe = found[1]
        if fe and fe.valid then
          n = n + fe.products_finished
          if fe.status == defines.entity_status.working then live = true end
        end
      end
    elseif e.built and e.role == "champ-foreuse" and drills < 24 then
      drills = drills + 1
      local de = surface.find_entity(e.name, { e.x, e.y })
      if de and de.valid and de.status == defines.entity_status.working then working = working + 1 end
    end
  end
  -- lot THERMIQUE : une bande de COFFRES (charbon, pierre) n'a pas de four qui compte ses produits : elle produit quand ses foreuses minent
  -- (au moins deux en marche, ou toutes si elle n'en a qu'une)
  if seen == 0 and drills > 0 and working >= math.min(2, drills) then n, live = CFG.produce_min, true end
  return n, live
end

---------------------------------------------------------------------------------------------------
-- Retrait d'une partie
---------------------------------------------------------------------------------------------------
--- Rend `n` objets au stock ; ce qui ne tient pas est répandu au sol du QG (jamais perdu). Lot STOCKAGE-VITAL (objets au sol, 7/11 : 1 327
--- copper-plate rendues à un stock plein dans la partie du DC, 1 168 au sol) : DERNIER RECOURS seulement, contents_fit est vérifié avant
--- chaque retrait ; le reste est marqué à ramasser (force de l'équipe) et Stock.pick_ground le reprend dès que le stock a la place.
local function give(f, surface, name, n)
  local put = Stock.insert(f, name, n)
  if put < n then surface.spill_item_stack(f.hq_pos, { name = name, count = n - put }, true, f.force, false) end
end

--- Lot STOCKAGE-VITAL (objets au sol, 7/11) : le contenu des paires `ids` de `list` (toutes si nil) tient-il au stock ? Carburant et objet
--- de la foreuse, inventaires et objet du four ou du coffre (un puits partagé compté une fois), comme retire() les rend. Faux : le retrait
--- attend (ligne [FO-MIGRATION] au plus une par minute et par équipe), rien n'est répandu.
local function contents_fit(f, ids, list, ents, tick)
  if not Stock.can_take then return true end
  local byid, want, seen = {}, {}, {}
  for _, pr in ipairs(list) do byid[pr.id] = pr end
  local function add(inv)
    if not inv then return end
    local c = inv.get_contents()
    for _, name in ipairs(sorted_keys(c)) do want[#want + 1] = { name, c[name] } end
  end
  local n = 0
  for _, id in ipairs(ids or {}) do
    local pr = byid[id]
    if pr then
      local d, s = ents[pr.id], ents[pr.sink_id]
      if d and d.valid then
        add(d.get_fuel_inventory())
        want[#want + 1] = { d.name, 1 }
        n = n + 1
      end
      if s and s.valid and not seen[pr.sink_id] then
        seen[pr.sink_id] = true
        for _, inv_name in ipairs(s.type == "furnace" and FURNACE_INVENTORIES or CHEST_INVENTORIES) do add(s.get_inventory(defines.inventory[inv_name])) end
        want[#want + 1] = { s.name, 1 }
      end
    end
  end
  local ok, need, empty = Stock.can_take(f, want)
  if ok then return true end
  tick = tick or (game and game.tick) or 0
  if not f.migr_full_log or tick - f.migr_full_log >= 3600 then
    f.migr_full_log = tick
    log(string.format("[FO-MIGRATION] %s : retrait de %d paire(s) remis : le stock ne tient pas leur contenu (%d case(s) neuve(s), %d vide(s)), rien au sol",
      name_of(f), n, need or 0, empty or 0))
  end
  return false
end

--- Vide un inventaire dans le stock (le surplus qui ne tient pas est répandu au sol du QG). Rend le nombre d'objets repris.
local function empty_into_stock(f, surface, inv, got)
  if not inv then return 0 end
  local c = inv.get_contents()
  local n = 0
  for _, name in ipairs(sorted_keys(c)) do
    local count = c[name]
    give(f, surface, name, count)
    got[name] = (got[name] or 0) + count
    n = n + count
  end
  return n
end

--- Retire les paires `st.ids` encore debout : l'ancienne n'est plus « possédée » AVANT d'être retirée (sinon on_entity_destroyed compterait
--- une perte d'avant-poste), contenus et objets rendus au stock. Rend (paires retirées, objets rendus { [nom] = n }).
local function retire(f, surface, o, st, list, ents)
  -- lot STOCKAGE-VITAL (objets au sol, 7/11) : rien n'est retiré si le contenu des paires ne tient pas au stock (4e valeur : vrai)
  if not contents_fit(f, st.ids, list, ents) then return 0, {}, {}, true end
  local byid = {}
  for _, pr in ipairs(list) do byid[pr.id] = pr end
  local got, removed, gone_drills, gone_sinks = {}, 0, {}, {}
  local undo, sink_info = {}, {} -- lot AZURE : paires retirées (positions et types), reposées par rollback() si la bande n'aboutit pas
  -- lot CHAMP : à qui appartient chaque foreuse (l'avant-poste ou un voisin du même gisement), lu AVANT le retrait
  local owners = st.frame and { o, table.unpack(siblings(f, o)) } or { o }
  local owner_of, rem = {}, {}
  for i, q in ipairs(owners) do
    rem[i] = 0
    for _, d in ipairs(q.drill_list or {}) do if d.valid and d.unit_number then owner_of[d.unit_number] = i end end
  end
  for _, id in ipairs(st.ids) do
    local pr = byid[id]
    if pr then
      local d, s = ents[pr.id], ents[pr.sink_id]
      if s and s.valid and not sink_info[pr.sink_id] then sink_info[pr.sink_id] = { name = s.name, x = s.position.x, y = s.position.y } end
      if d and d.valid then
        local oi0 = owner_of[d.unit_number]
        undo[#undo + 1] = { name = d.name, x = d.position.x, y = d.position.y, dir = d.direction, oid = (owners[oi0 or 1] or o).id, sink = sink_info[pr.sink_id] }
        empty_into_stock(f, surface, d.get_fuel_inventory(), got)
        State.disown(d.unit_number)
        give(f, surface, d.name, 1)
        got[d.name] = (got[d.name] or 0) + 1
        gone_drills[d.unit_number] = true
        local oi = owner_of[d.unit_number]
        if oi then rem[oi] = rem[oi] + 1 end
        d.destroy()
        removed = removed + 1
      end
      if s and s.valid and not gone_sinks[pr.sink_id] then
        -- (lot THERMIQUE : un coffre de charbon ou de pierre ne se vide pas comme un four)
        for _, inv_name in ipairs(s.type == "furnace" and FURNACE_INVENTORIES or CHEST_INVENTORIES) do
          empty_into_stock(f, surface, s.get_inventory(defines.inventory[inv_name]), got)
        end
        State.disown(s.unit_number)
        give(f, surface, s.name, 1)
        got[s.name] = (got[s.name] or 0) + 1
        gone_sinks[pr.sink_id] = true
        s.destroy()
      end
    end
  end
  -- lot CHAMP : les voisins du même gisement perdent aussi les paires retirées sous la bande
  for i, q in ipairs(owners) do
    local keep_d, keep_s = {}, {}
    for _, d in ipairs(q.drill_list or {}) do
      if d.valid and not (d.unit_number and gone_drills[d.unit_number]) then keep_d[#keep_d + 1] = d end
    end
    for _, s in ipairs(q.sinks or {}) do
      if s.valid and not (s.unit_number and gone_sinks[s.unit_number]) then keep_s[#keep_s + 1] = s end
    end
    q.drill_list, q.sinks = keep_d, keep_s
    q.drills = math.max(0, (q.drills or 0) - rem[i])
    q.ext_dead = nil
  end
  return removed, got, undo
end

local function items_text(got)
  local out = {}
  for _, name in ipairs(sorted_keys(got)) do out[#out + 1] = got[name] .. " " .. name end
  return #out > 0 and table.concat(out, ", ") or "rien"
end

--- Le registre de reconstruction ne refait pas une paire thermique de l'avant-poste que l'on migre.
local function purge_recon(f, o)
  local s = f.recon
  if not (s and s.lost) then return 0 end
  local n = 0
  for _, k in ipairs(sorted_keys(s.lost)) do
    local r = s.lost[k]
    if r.oid == o.id and (r.kind == "drill" or r.kind == "sink") then
      Rc.done(s, k)
      n = n + 1
    end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Lot THERMIQUE : lectures pour la règle pure shared/team/thermique.lua (« on REMPLACE les thermiques par l'électrique »)
---------------------------------------------------------------------------------------------------
--- Cadences (ore/s) d'une foreuse thermique et d'une foreuse électrique sur le minerai de `kind`, lues aux prototypes ; nil si illisibles.
local function rates_of_kind(f, kind)
  local spec = T.outposts[kind]
  local rp = spec and game.entity_prototypes[spec.resource]
  local bp, ep = game.entity_prototypes[T.DRILL], game.entity_prototypes[T.DRILL_ELECTRIC]
  if not (rp and rp.mineable_properties and bp and ep and bp.mining_speed and ep.mining_speed) then return nil end
  local mt = rp.mineable_properties.mining_time or 1
  local force = game.forces and game.forces[f.force]
  local prod = force and force.mining_drill_productivity_bonus or 0
  return bp.mining_speed / mt * (1 + prod), ep.mining_speed / mt * (1 + prod)
end

--- Lot THERMIQUE5 : la foreuse à combustion a-t-elle du combustible (au réservoir ou en train de brûler) ?
local function has_fuel(d)
  local inv = d.get_fuel_inventory()
  if inv and not inv.is_empty() then return true end
  local bu = d.burner
  return bu ~= nil and (bu.remaining_burning_fuel or 0) > 0
end

--- Foreuses thermiques debout d'un avant-poste (ou d'un gisement voulu), et celles qui ont du combustible (lot THERMIQUE5 : une paire à sec
--- n'extrait rien, Th.supply).
local function thermal_count(o)
  local n, fueled = 0, 0
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid and d.name == T.DRILL then
      n = n + 1
      if has_fuel(d) then fueled = fueled + 1 end
    end
  end
  return n, fueled
end

--- Lot THERMIQUE5 : nom de l'état moteur s'il est de ceux qui COUVRENT (Th.COVERING_STATUS : en marche, sortie pleine), sinon nil ; table lue
--- une fois (defines ne change pas en partie). Lot THERMIQUE6 : la décision est Th.drill_counts (sortie pleine seulement si la bande produit).
local covering_name
local function status_name(status)
  if not covering_name then
    covering_name = {}
    for _, k in ipairs(Th.COVERING_STATUS) do
      local v = defines.entity_status[k]
      if v ~= nil then covering_name[v] = k end
    end
  end
  return covering_name[status]
end

--- Fer d'une foreuse électrique (matières premières du livre), lu une fois : le livre est fait des recettes, qui ne changent pas en partie.
local drill_cost_cache
local function drill_cost(book)
  if drill_cost_cache == nil and book then
    local ok, raw = pcall(function() return book:raw_cost({ { T.DRILL_ELECTRIC, 1 } }) end)
    drill_cost_cache = (ok and raw and raw[T.outposts.iron.product]) or 0
  end
  return drill_cost_cache or 0
end

--- Foreuses électriques EN MARCHE des bandes du champ `oid` (posées) (une bande qui ne mine pas ne couvre rien : sortie bouchée, courant coupé).
local function working_of(f, surface, oid)
  local b = f.build
  local n, nfini = 0, 0
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    -- (lot THERMIQUE5, priorité 0 : seule une bande FINIE au plan couvre, Th.band_covers ; avant, toute bande comptait ses foreuses posées et en
    -- marche, et l'amorce d'une bande en chantier faisait balayer les dernières paires : Scarlet, INTEG-0643N)
    -- (lot THERMIQUE6, essai 3 : une bande bloquée dont les fours ont produit couvre aussi ; la sortie pleine ne compte que si elle produit)
    -- (lot THERMIQUE7, essai 4 : toute bande est jugée à sa PRODUCTION, quel que soit son état au plan, Th.band_covers ; elle compte aussi comme
    -- « finie » pour la règle B ; une bande qui n'a jamais produit ne couvre rien)
    local mine = p and p.spec and p.spec.champ and p.spec.champ.oid == oid and not p.spec.champ.coal
    local made, live = 0, false
    if mine then made, live = made_by(f, surface, p) end
    if mine and Th.band_covers(p.state, made >= CFG.produce_min, live) then
      nfini = nfini + 1 -- (règle B : bande qui produit)
      for _, e in ipairs(p.ents or {}) do
        if e.built and e.role == "champ-foreuse" then
          local de = surface.find_entity(e.name, { e.x, e.y })
          if de and de.valid and Th.drill_counts(status_name(de.status), live) then n = n + 1 end
        end
      end
    end
  end
  return n, nfini
end

--- Combustible (ore/s) que brûlent les générateurs de la force à cet instant : plancher du minerai CRITIQUE (le charbon de la centrale).
local function fuel_burn(f, surface)
  local proto = game.item_prototypes and game.item_prototypes[T.fuel]
  local value = proto and proto.fuel_value or 0
  if value <= 0 then return 0 end
  local watts = 0
  -- Lot X10-S4 : registre des génératrices ; somme dans l'ordre des unit_number, au lieu de l'ordre du moteur (à l'arrondi près ;
  -- fo-logs/2026-11-07_X10/S4_CRITERES.md §2)
  for _, g in ipairs(Gens.list(surface, f.force, "generator")) do
    if g.valid then watts = watts + (g.energy_generated_last_tick or 0) * 60 end
  end
  return watts / value
end
Mig._fuel_burn = fuel_burn -- (lot X10-S4) appel direct du micro-banc x10-s4-ombre (script/team/generateurs.lua) ; aucun autre usage

--- Lot COMBUSTIBLE-MIGRATION : brûleurs de l'équipe (foreuses à brûleur et fours des avant-postes) regroupés par puissance de combustion,
--- { { kw, n } } dans l'ordre des noms ; et énergie d'un objet de combustible (kJ). Lus aux données (Mod.spec, prototype), aucun nom écrit ici.
local function burner_groups(f)
  local by, names = {}, {}
  local function add(e)
    if e.valid then
      local sp = Mod.spec(e.name)
      local kw = sp and sp.burner_kw
      if kw and kw > 0 then
        if not by[e.name] then by[e.name] = { kw = kw, n = 0 }; names[#names + 1] = e.name end
        by[e.name].n = by[e.name].n + 1
      end
    end
  end
  for _, oid in ipairs(sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    for _, d in ipairs(o.drill_list or {}) do if d.valid and d.burner then add(d) end end
    for _, s in ipairs(o.sinks or {}) do if s.valid and s.type == "furnace" then add(s) end end
  end
  table.sort(names)
  local out = {}
  for _, n in ipairs(names) do out[#out + 1] = by[n] end
  return out
end

local function fuel_kj()
  local proto = game.item_prototypes and game.item_prototypes[T.fuel]
  return proto and (proto.fuel_value or 0) / 1000 or 0
end

--- Plancher du combustible de l'équipe (objets/s) : générateurs mesurés + brûleurs à pleine cadence (Mc.floor).
local function fuel_floor(f, surface)
  return Mc.floor(fuel_burn(f, surface), burner_groups(f), fuel_kj())
end

--- Gisements de la force pour la règle pure : un par propriétaire de champ (les voisins du même gisement lui sont rattachés), un par
--- avant-poste ou gisement voulu sinon. Rend (liste, par numéro).
local function build_fields(f, surface, ms, free)
  local fields, byid = {}, {}
  local targets = {}
  for _, oid in ipairs(sorted_keys(f.outposts)) do targets[#targets + 1] = f.outposts[oid] end
  for _, fid in ipairs(sorted_keys(ms.fields)) do targets[#targets + 1] = ms.fields[fid] end
  for _, o in ipairs(targets) do
    if is_champ_kind(o.kind) then
      local th, el = rates_of_kind(f, o.kind)
      local st = ms.o[o.id]
      local framed = (st and st.frame and not st.abandoned) and true or false
      local sib = siblings(f, o)
      local subsumed = false
      if not framed then
        for _, q in ipairs(sib) do
          local sq = ms.o[q.id]
          if sq and sq.frame and not sq.abandoned then subsumed = true end
        end
      end
      if th and not subsumed then
        local n, nf = thermal_count(o)
        if framed then
          for _, q in ipairs(sib) do
            local a, b2 = thermal_count(q)
            n, nf = n + a, nf + b2
          end
        end
        -- (lot THERMIQUE5 : fueled = paires avec combustible, l'extraction thermique de Th.supply ; pairs = paires à retirer)
        local w, nfini = 0, 0
        if framed then w, nfini = working_of(f, surface, o.id) end
        local fl = { id = o.id, res = o.kind, pairs = n, fueled = nf, th_rate = th, el_rate = el, working = w, fini = nfini,
          busy = (st and st.stage == "projet") and true or false, wanted = (st and (st.want_until or 0) > game.tick) and true or false,
          have = free[T.outposts[o.kind].product] or 0, framed = framed }
        fields[#fields + 1] = fl
        byid[o.id] = fl
      end
    end
  end
  return fields, byid
end

--- Contexte de la règle pure : courant, fer libre, stock de chaque minerai (son produit), minerai critique (le combustible) et son plancher.
local function th_context(f, surface, b, free, book)
  local ctx = { power = power_ok(b), iron = free[T.outposts.iron.product] or 0, drill_cost = drill_cost(book), floor = {}, stock = {}, critical = {} }
  local burn
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    ctx.stock[kind] = free[spec.product] or 0
    if spec.resource == T.fuel then
      burn = burn or fuel_burn(f, surface)
      ctx.critical[kind], ctx.floor[kind] = true, burn
    end
  end
  return ctx
end

---------------------------------------------------------------------------------------------------
-- Étapes
---------------------------------------------------------------------------------------------------
local function new_state()
  return { stage = "veille", fails = 0, noop = 0, done = 0, produced = 0, retry = 0 }
end

--- Fin du suivi d'un avant-poste (état final posé sur l'avant-poste) ; la pensée suivante passe au suivant.
local function finish(f, ms, o, st, how, text)
  st.stage, st.pid, st.ids, st.undo, st.pg, st.cool, st.rollbacks = "veille", nil, nil, nil, nil, nil, 0
  if st.frame then -- lot CHAMP : les voisins du même gisement suivent (plus de paire posée par eux sur le champ)
    for _, q in ipairs(siblings(f, o)) do
      q.migr, q.full, q.full_by = (how == "abandon") and nil or how, how ~= "abandon", (how ~= "abandon") and "migration" or nil
    end
  end
  if how == "abandon" then
    st.abandoned = true
    st.abandoned_at = game.tick -- lot MIGRATION-DECLENCHE : reprise d'un état neuf après CFG.revive (start_next)
    o.migr = nil
    o.full = false
    o.full_by = nil
  else
    o.migr = how -- "fini" ou "partiel"
    o.full = true
    o.full_by = "migration"
  end
  release(ms, o.id)
  say(f, ms, string.format("%s [equipe : %d demande(s), %d paire(s) retiree(s), %d ligne(s) neuve(s) ont produit]", text, ms.requests or 0, ms.retired or 0,
    ms.lines or 0), true)
end

--- Demande échouée (avant ou après un retrait) : nouvel essai plus tard, abandon après CFG.max_fails échecs de suite.
local function failed(f, ms, o, st, tick, why)
  st.fails = st.fails + 1
  -- lot RACCORD-BANDE : la CAUSE du refus du plan (raison du projet) au journal, pas seulement « refuse »
  local pj = st.pid and f.build and f.build.projects[st.pid]
  local cause = pj and pj.reason and (" : " .. tostring(pj.reason)) or ""
  st.retry = tick + (st.frame and CHAMP_CFG.retry or CFG.retry) -- (lot CHAMP : une bande annulée est redemandée sous 3 min)
  -- lot MIGRATION-DECLENCHE : le plan a REFUSÉ cette partie (ex. « tapis des foreuses (minerai) ») : elle est écartée des choix suivants
  -- (Mg.pick_band, ctx.skip) et une AUTRE partie est essayée sous une minute (la même était redemandée 3 fois à 15 min d'écart, puis abandon)
  if why == "refuse" and st.band_key then
    st.bad = st.bad or {}
    if #st.bad < CFG.max_bad then st.bad[#st.bad + 1] = st.band_key end
    st.retry = tick + CFG.retry_refuse
  end
  st.band_key = nil
  st.stage, st.pid, st.ids, st.gate_t0, st.t_done = "veille", nil, nil, nil, nil
  st.undo, st.pg, st.cool, st.rollbacks = nil, nil, nil, 0 -- lot AZURE
  release(ms, o.id)
  if st.done == 0 and st.produced == 0 then o.migr, o.full, o.full_by = nil, false, nil end -- rien de migré : l'avant-poste est rendu en attendant
  if st.fails >= CFG.max_fails then
    local pause = st.done == 0 and st.frame ~= nil and why == "refuse"
    finish(f, ms, o, st, (st.done > 0) and "partiel" or "abandon",
      string.format("avant-poste %d : migration %s apres %d echec(s) de suite (%s%s), %d partie(s) migree(s)%s", o.id,
        (st.done > 0) and "arretee" or "abandonnee", st.fails, tostring(why), cause, st.done,
        pause and string.format(" ; reprise dans %.0f min", CHAMP_CFG.pause / 3600) or ""))
    if pause and st.abandoned then st.pause = CHAMP_CFG.pause end -- lot RACCORD-BANDE : pause courte (start_next)
  else
    say(f, ms, string.format("avant-poste %d : partie annulee (%s%s), echec %d/%d, nouvel essai a %.1f min", o.id, tostring(why), cause, st.fails,
      CFG.max_fails, st.retry / 3600), st.frame ~= nil) -- (lot CHAMP : forcée pour une bande du champ)
  end
end

--- Lot FONDERIE (projet séparé, 3/11) : le réseau du charbon de chaque côté d'une bande (ligne de foreuses, tracé, tronc) est un projet À PART,
--- demandé avant la première bande en voie de ce côté, à la priorité d'une alimentation. (Extrait de begin_band au lot MEGA-FONDERIE A2 : les
--- bandes en avance le demandent aussi ; le texte et l'ordre des demandes sont inchangés.)
local function coal_projects(f, ms, o, st, bd, pr)
  st.coal_req = st.coal_req or {}
  for _, bo in ipairs(Champ.CFG.coal_project and bd.plan.bands or {}) do
    for _, g in ipairs(bo.groups or {}) do
      local sk = tostring(g.side)
      local old = st.coal_req[sk]
      if old and not (f.build and f.build.projects[old]) then st.coal_req[sk] = nil end
      if g.mode == "voie" and not st.coal_req[sk] then
        local cid = Build.request(f, { site = "champ", champ = { oid = o.id, pr = pr, frame = st.frame, coal = g.side }, near = { x = o.pos.x, y = o.pos.y },
          prio = Champ.CFG.coal_prio, domain = "infrastructures", lazy_clear = true })
        if cid then
          st.coal_req[sk] = cid
          say(f, ms, string.format("%s %d (%s) : reseau du charbon cote %s demande, projet %d (avant la bande %d)", o.field and "gisement" or "avant-poste",
            o.id, o.kind, g.side > 0 and "+" or "-", cid, pr), true)
        end
      end
    end
  end
end

--- Lot FONDERIE : réseaux du charbon reportés (bande au-delà de Champ.CFG.band_max) : projets LIÉS à la bande `id`, demandés juste après elle.
local function defer_projects(f, ms, o, st, bd, pr, id)
  for _, sd in ipairs(bd.defer or {}) do
    local cid = Build.request(f, { site = "champ", champ = { oid = o.id, pr = pr, frame = st.frame, coal = sd, link = id }, near = { x = o.pos.x, y = o.pos.y },
      prio = CFG.prio, domain = "production", lazy_clear = true })
    say(f, ms, string.format("%s %d (%s) : reseau du charbon cote %s reporte dans le projet lie %s (bande %d, projet %d)", o.field and "gisement" or "avant-poste",
      o.id, o.kind, sd > 0 and "+" or "-", tostring(cid), pr, id), true)
  end
end

--- Lot CHAMP : la bande suivante du champ de l'avant-poste `o` (cadre figé au premier appel), demandée au plan directeur comme un SITE
--- (Build.SITES.champ, script/team/champ.lua). Les paires dont une tuile est sous la bande sont celles que le dégel retire. Rend vrai si la
--- demande est partie.
--- Lot IA-GARDE : une bande de l'avant-poste `o` peut-elle partir (garde anti-dispersion, famille « sur-stockage ») ?
local function garde_band(f, o, tick)
  local sorte = AdRt.sorte_type(o.kind)
  if sorte ~= "brut" then return true end
  return (AdRt.permet(f, "surstock", { sorte = sorte, manque = AdRt.manque(f, T.outposts[o.kind].product) }, tick))
end

local function begin_band(f, surface, ms, o, st, list, tick, free)
  st.rollbacks = 0 -- lot AZURE (revue A2) : le compte des retours en arrière est PAR BANDE
  -- lot FONDERIE : un cadre d'une sauvegarde d'avant le lot (fonderie à coffres) dont AUCUNE bande n'a été demandée est replanifié en
  -- colonne à tapis ; dès qu'une bande est posée ou demandée, le cadre garde son motif (les bandes voisines partagent leurs rangées)
  if Champ.tapis() and st.frame and st.frame.design == nil and not Champ.has_band(f, o) then st.frame, st.order, st.done_pr = nil, nil, nil end
  if not st.frame then
    -- lot COUT-600 : un seul cadre planifié par passe de Mig.think (le drapeau est levé par le premier ; une autre avant-poste attend la passe suivante)
    if ms.verify_due then st.retry = tick; return false end
    local frame, order = Champ.frame(f, surface, o)
    if not frame then
      st.fails, st.retry = st.fails + 1, tick + CFG.retry
      say_why(f, ms, st, "champ:" .. tostring(order), string.format("avant-poste %d : pas de plan de champ (%s), essai %d/%d", o.id, tostring(order), st.fails, CFG.max_fails))
      if st.fails >= CFG.max_fails then st.abandoned, st.abandoned_at = true, tick end
      return false
    end
    st.frame, st.order, st.done_pr = frame, order, {}
    -- lot COUT-600 : le plan du cadre (5 à 12 M d'instructions sur un champ de 600 %) ne partage plus sa pensée avec la première bande (jusqu'à
    -- 1 M) : celle-ci part à la pensée suivante de la migration (st.retry = ce tick : aucune attente de plus)
    st.retry = tick
    ms.verify_due = true -- lu par Mig.think (drapeau de global : la pensée suivante est celle de la vérification, même après un chargement)
    return false
  end
  -- Lot IA-GARDE (règle du DC, 11/11) : sous 2 colonnes de fonderie automatisées et 6 assembleurs actifs, une bande d'un minerai BRUT (charbon,
  -- pierre) n'est demandée que si sa matière manque par rapport au besoin (partie du DC 0.6.96 : 46 foreuses de charbon du joueur, bandes 4, 7
  -- et 21, de 12 à 30 min, pour 10 foreuses de fer) ; les paires thermiques en place continuent de produire.
  if not garde_band(f, o, tick) then
    st.retry = tick + CFG.retry
    say_why(f, ms, st, "anti-dispersion", string.format("avant-poste %d (%s) : bande retenue par la garde anti-dispersion (minerai brut sans manque mesure)", o.id, o.kind))
    return false
  end
  local bad = {}
  for _, k in ipairs(st.bad or {}) do bad[k] = true end
  for _, k in ipairs(st.stopped or {}) do bad[k] = true end -- lot AZURE : bandes parquées (réserve définitive), jamais relancées
  local product = T.outposts[o.kind].product
  local pr
  for _, x in ipairs(st.order) do
    if not pr and not st.done_pr[tostring(x)] and not bad[x] and not (st.prot and st.prot[x]) and not (st.ahead and st.ahead[tostring(x)]) then pr = x end
  end
  if not pr and st.prot then
    -- lot THERMIQUE : toutes les bandes restantes ont été retenues par la protection : on les redemande, la coupe attendra au dégel
    st.prot = nil
    for _, x in ipairs(st.order) do
      if not pr and not st.done_pr[tostring(x)] and not bad[x] and not (st.ahead and st.ahead[tostring(x)]) then pr = x end
    end
  end
  if not pr and st.ahead then
    -- lot MEGA-FONDERIE (A2) : des bandes en avance sont encore au plan : le champ n'est pas « posé » tant qu'elles ne le sont pas
    st.retry = tick + CFG.retry
    return false
  end
  if not pr then
    -- lot THERMIQUE5 (revue du 3/11, cause 2) : l'ordre épuisé ne déclare plus « fini » un champ qui porte encore des paires (Th.order_end) ;
    -- rien de migré : le cadre est refait après CFG.revive au lieu d'un abandon (qui rouvrait l'avant-poste aux brûleurs)
    local how = Th.order_end(#list, st.done, st.produced)
    if how == "replanifier" then
      local empty = #st.order == 0
      st.frame, st.order, st.done_pr, st.prot, st.bad = nil, nil, nil, nil, nil
      st.retry = tick + CFG.revive
      say_why(f, ms, st, "replan", string.format("avant-poste %d : %s, %d paire(s) restent : cadre refait dans %.0f min", o.id,
        empty and "aucune bande ne tient sur le gisement (occupe : voir [FO-CHAMP])" or "aucune bande retenue", #list, CFG.revive / 3600), true)
      return false
    end
    finish(f, ms, o, st, how, (#st.order == 0)
      and string.format("avant-poste %d : aucune bande ne tient sur le gisement (occupe : voir [FO-CHAMP]), les paires restent", o.id)
      or string.format("avant-poste %d : champ pose (%d bande(s) produisent)%s", o.id, st.produced,
        #list > 0 and string.format(", %d paire(s) hors des bandes : %s", #list, how) or ""))
    return false
  end
  local bd, why = Champ.band(f, surface, o, st.frame, pr)
  if not bd then
    st.bad = st.bad or {}
    st.bad[#st.bad + 1] = pr
    st.retry = tick + CFG.retry_refuse
    say(f, ms, string.format("avant-poste %d : bande %d ecartee (%s)", o.id, pr, tostring(why)))
    return false
  end
  -- paires sous la bande : retirées au dégel
  local under = {}
  for i = 1, #bd.tiles - 1, 2 do under[P.tkey(bd.tiles[i], bd.tiles[i + 1])] = true end
  local ids, thaw = {}, {}
  for _, pr2 in ipairs(list) do
    local t = Mg.tiles({ Mg.box(pr2.drill), Mg.box(pr2.sink) })
    local hit = false
    for i = 1, #t - 1, 2 do if under[P.tkey(t[i], t[i + 1])] then hit = true end end
    if hit then
      ids[#ids + 1] = pr2.id
      for i = 1, #t do thaw[#thaw + 1] = t[i] end
    end
  end
  table.sort(ids)
  -- lot THERMIQUE : un minerai ne perd pas ses paires sous une bande tant que l'approvisionnement qui reste n'atteint pas son plancher ou qu'il
  -- reste sans source (dernière source, centrale) : cette bande-là est mise de côté et une bande sans paire (ou moins chargée) passe devant, de
  -- sorte que l'électrique PRODUISE avant qu'une paire parte (mesuré, 1re mesure : 45 à 57 attentes « protege » de 10 min sinon)
  -- Lot THERMIQUE2 : seulement pour le minerai CRITIQUE (le charbon de la centrale). Un minerai ordinaire part comme sur main : sa première bande
  -- est toujours sur sa dernière source, et la mettre de côté retardait toute l'électrification (champ-longue 20261020 : bande de cuivre d'Azure
  -- « mise de cote (derniere-source) » à 18,9 min, demandée sur main à la même minute ; première divergence des deux parties).
  local ctx = (#ids > 0 and free) and th_context(f, surface, f.build, free, nil) or nil
  if ctx and ctx.critical[o.kind] then
    do
      local fields, byid = build_fields(f, surface, ms, free)
      local fl = byid[o.id]
      if fl then
        local ok, cwhy = Th.cut_ok(fl, fields, #ids * fl.th_rate, ctx)
        if not ok then
          st.prot = st.prot or {}
          st.prot[pr] = true
          st.retry = tick + CFG.retry_refuse
          say_why(f, ms, st, "prot:" .. pr, string.format("avant-poste %d : bande %d mise de cote (%d paire(s) dessous, %s) : une bande sans paire passe devant",
            o.id, pr, #ids, tostring(cwhy)), true)
          return false
        end
      end
    end
  end
  -- une bande voulue par la capitalisation (Mig.want) n'attend pas que la plaque manque : la règle a déjà jugé l'agrandissement rentable
  local wanted = (st.want_until or 0) > tick
  -- lot SATURATION (DC 9/11) : une bande dont les foreuses et les fours DORMENT déjà au coffre n'attend ni que la plaque manque, ni qu'une
  -- capitalisation la veuille : le stock dormant est la décision (mesuré : 52 à 68 foreuses électriques et 104 à 170 fours au coffre à 90 min,
  -- champ du joueur à 48 % ; fo-logs/2026-11-09_VOIE-AVANT-FOURS)
  st.band_need = band_list(bd)
  local sat = Mp.saturation(st.band_need, free)
  if sat.starts and #ids == 0 then
    say_why(f, ms, st, "dormant:" .. pr, string.format("avant-poste %d : bande %d PAYEE PAR LE STOCK DORMANT (%d machine(s) sur %d au coffre, seuil %d %%, %d piece(s) a fabriquer) : elle part sans attendre que %s manque",
      o.id, pr, sat.dormant, sat.want, Mp.CFG.start_pct, #sat.net, product), true)
  end
  if #ids == 0 and (free[product] or 0) >= EXT_PLATES and not wanted and not sat.starts then
    say_why(f, ms, st, "ext:" .. pr, string.format("avant-poste %d : bande %d sans paire en attente (%d %s libres, agrandissement sous %d)", o.id, pr,
      free[product] or 0, product, EXT_PLATES))
    st.retry = tick + CFG.retry
    return false
  end
  local cx, cy, n = 0, 0, 0
  for _, e in ipairs(bd.ents) do cx, cy, n = cx + e.x, cy + e.y, n + 1 end
  cx, cy = cx / math.max(1, n), cy / math.max(1, n)
  -- la bande porte sa plaque (spec.product) et la famille d'investissement de la pile « capi » (shared/ai3/pile.lua) : pendant une retenue,
  -- elle avance pour une plaque d'un cadre ouvert ou qui manque, comme un module de la capitalisation (avant : « migration », rang améliorer,
  -- jamais d'exception : 4 à 6 refus par équipe et par heure, réserve rendue à chaque refus)
  -- lot FONDERIE (projet séparé, 3/11) : le réseau du charbon d'un côté (ligne de foreuses, tracé, tronc) est un projet À PART, demandé avant
  -- la première bande en voie de ce côté, à la priorité d'une alimentation : aucune bande n'attend des centaines de pièces qui ne sont pas
  -- les siennes (lot3-20261020 : 1 161 entités pour une bande, « en attente (matières) » jusqu'à la fin)
  coal_projects(f, ms, o, st, bd, pr)
  local spec = { site = "champ", champ = { oid = o.id, pr = pr, frame = st.frame }, near = { x = o.pos.x, y = o.pos.y }, prio = CFG.prio,
    domain = "production", lazy_clear = true, pile = ((st.want_until or 0) > tick) and "couverture" or "capi", product = product }
  if #ids > 0 then spec.degel = { oid = o.id, tiles = thaw } end
  local id, rwhy = Build.request(f, spec)
  if not id then
    st.fails, st.retry = st.fails + 1, tick + CFG.retry
    say_why(f, ms, st, "req:" .. tostring(rwhy), string.format("avant-poste %d : demande au plan impossible (%s)", o.id, tostring(rwhy)))
    return false
  end
  -- lot FONDERIE : réseaux du charbon reportés (bande au-delà de Champ.CFG.band_max) : projets LIÉS à la bande, demandés juste après elle
  defer_projects(f, ms, o, st, bd, pr, id)
  st.stage, st.pid, st.ids, st.t0, st.band_key = "projet", id, ids, tick, pr
  st.cx, st.cy, st.gate_t0, st.why_last, st.retired = cx, cy, nil, nil, nil
  o.migr, o.full, o.full_by = "en cours", true, "migration"
  for _, q in ipairs(siblings(f, o)) do q.migr, q.full, q.full_by = "en cours", true, "migration" end -- même gisement : plus de paire de plus
  claim(ms, o.id)
  ms.requests = (ms.requests or 0) + 1
  local nd, nf = 0, 0
  for _, e in ipairs(bd.plan.ents) do if e.kind == "foreuse" then nd = nd + 1 elseif e.kind == "four" then nf = nf + 1 end end
  say(f, ms, string.format("%s %d (%s) : bande %d du champ demandee, projet %d : %d foreuse(s) electrique(s), %d four(s), %d paire(s) thermique(s) dessous (%s), %d paire(s) ailleurs%s",
    o.field and "gisement" or "avant-poste", o.id, o.kind, pr, id, nd, nf, #ids, table.concat(ids, ","), #list - #ids,
    wanted and " (voulue par la capitalisation)" or ""), true)
  return true
end

--- Choisit une partie et la demande au plan. Rend vrai si la demande est partie.
local function begin_part(f, surface, ms, o, st, list, rects, tick)
  local m = method_of(o.kind)
  local rates = m and rates_of(m)
  if not rates then
    st.abandoned, st.sans_gabarit = true, true -- abandon définitif (lot MIGRATION-DECLENCHE : jamais repris)
    say(f, ms, string.format("avant-poste %d : pas de gabarit de fonderie pour %s, migration impossible", o.id, tostring(o.kind)), true)
    return false
  end
  local skip = {}
  for _, k in ipairs(st.bad or {}) do skip[k] = true end
  local band, why = Mg.pick_band(list, { rects = rects, toward = f.hq_pos, produced = st.produced > 0,
    line = line_of(m.args[2]), rates = rates, skip = skip })
  if not band then
    if why == "vide" then
      finish(f, ms, o, st, "fini", string.format("avant-poste %d : champ migre en entier (%d partie(s), %d ligne(s) ont produit)", o.id,
        st.done, st.produced))
    elseif st.done > 0 and (why == "place" or why == "gabarit" or why == "treillis" or why == "garde") then
      finish(f, ms, o, st, "partiel", string.format("avant-poste %d : %d paire(s) restent (%s), %d partie(s) migree(s)", o.id, #list, why, st.done))
    else
      st.fails = st.fails + 1
      st.retry = tick + CFG.retry
      if st.fails >= CFG.max_fails then
        st.abandoned = true
        st.abandoned_at = tick -- lot MIGRATION-DECLENCHE : reprise d'un état neuf après CFG.revive
        say(f, ms, string.format("avant-poste %d : aucune partie ne libere assez de place (%s), %d paire(s) : migration abandonnee", o.id,
          why, #list), true)
      else
        say_why(f, ms, st, "pick:" .. tostring(why), string.format("avant-poste %d : pas de partie a migrer (%s), %d paire(s), essai %d/%d",
          o.id, why, #list, st.fails, CFG.max_fails))
      end
    end
    return false
  end
  local spec = { gen = m.gen, args = { m.args[1], m.args[2], 1 }, feed = m.feed, rate = band.rate, near = { x = o.pos.x, y = o.pos.y },
    prio = CFG.prio, domain = "production", fixe = true, paires = band.pairs, degel = { oid = o.id, tiles = band.thaw, zone = band.zone },
    pile = "migration" } -- lot FUITES-PILE : famille de la pile (réserve au coffre suspendue pendant une retenue, sauf en chantier)
  local id, rwhy = Build.request(f, spec)
  if not id then
    st.fails = st.fails + 1
    st.retry = tick + CFG.retry
    say_why(f, ms, st, "req:" .. tostring(rwhy), string.format("avant-poste %d : demande au plan impossible (%s)", o.id, tostring(rwhy)))
    return false
  end
  st.stage, st.pid, st.ids, st.t0, st.band_key = "projet", id, band.ids, tick, band.key
  st.cx, st.cy, st.gate_t0, st.why_last, st.retired = band.cx, band.cy, nil, nil, nil
  o.migr, o.full, o.full_by = "en cours", true, "migration"
  claim(ms, o.id)
  ms.requests = (ms.requests or 0) + 1
  say(f, ms, string.format("avant-poste %d (%s) : partie %d demandee : %d paire(s) thermique(s) %s (lot %s), projet %d : fonderie de %d rangee(s) "
    .. "et ligne de %d paire(s) de foreuses electriques visees, %.0f plaques/min (la partie en livrait %.1f/s), %d paire(s) restent debout",
    o.id, o.kind, st.done + 1, band.n, table.concat(band.ids, ","), band.lot, id, band.rows, band.pairs, band.rate,
    band.n * math.min(rates.burner, rates.furnace), #list - band.n))
  return true
end

--- Relecture MIGRATION-DECLENCHE : paires de la partie, y compris celles REFAITES par la reconstruction pendant l'attente des matières
--- (nouveaux numéros d'unité, mêmes tuiles). Le registre n'est plus purgé en étape « projet » : une paire tuée puis refaite sur la
--- partie doit être retirée elle aussi, sinon elle occupe les tuiles promises au plan (`thaw`) et la ligne neuve ne se pose pas
--- (build.lua ne libère rien au dégel). Rend les numéros triés et le nombre de paires ajoutées. Lecture seule.
local function part_ids(st, list, thaw)
  local set, ids = {}, {}
  for _, id in ipairs(st.ids or {}) do
    if not set[id] then set[id] = true; ids[#ids + 1] = id end
  end
  local tset = {}
  for i = 1, #(thaw or {}) - 1, 2 do tset[P.tkey(thaw[i], thaw[i + 1])] = true end
  local added = 0
  for _, pr in ipairs(list) do
    if not set[pr.id] then
      local t = Mg.tiles({ Mg.box(pr.drill) })
      local inside = #t > 0
      for i = 1, #t - 1, 2 do
        if not tset[P.tkey(t[i], t[i + 1])] then inside = false; break end
      end
      if inside then set[pr.id] = true; ids[#ids + 1] = pr.id; added = added + 1 end
    end
  end
  table.sort(ids)
  return ids, added
end

local park, leave_band -- lot AZURE : définis plus bas (réserve définitive d'une bande, sortie du suivi)
--- Projet demandé : attend le plan et les matières ; au moment du « degel », retire la partie.
local function step_project(f, surface, ms, o, st, tick, free, book)
  local b = f.build
  local p = b.projects[st.pid]
  local env = { now = tick }
  local list, ents
  if Rb.cooling(st.cool, tick) then -- lot AZURE : bande remise en réserve par un retour en arrière : le champ produit, pas de retrait avant la fin de la pause
    say_why(f, ms, st, "retour", string.format("avant-poste %d : bande du projet %d en reserve apres un retour en arriere, retrait possible a %.1f min",
      o.id, st.pid, st.cool / 3600), true)
    return
  end
  if p and p.state == "reserve" and p.reason == "degel" then
    st.gate_t0 = st.gate_t0 or tick
    if st.frame then list, ents = survey_field(f, o) else list, ents = survey(o) end
    local ids, added = part_ids(st, list, p.spec and p.spec.degel and p.spec.degel.tiles)
    if added > 0 then
      st.ids = ids
      say(f, ms, string.format("avant-poste %d : %d paire(s) refaite(s) par la reconstruction sur la partie du projet %d : retirees avec elle",
        o.id, added, st.pid), true)
    end
    local present = 0
    local alive = {}
    for _, pr in ipairs(list) do alive[pr.id] = true end
    for _, id in ipairs(st.ids) do if alive[id] then present = present + 1 end end
    env.total, env.present, env.produced = #list, present, st.produced > 0
    env.enemy = enemy_near(f, surface, st.cx, st.cy) or enemy_near(f, surface, o.pos.x, o.pos.y)
    env.uses = uses_thaw(p, p.spec.degel.tiles)
    env.gate_age = tick - st.gate_t0
    -- lot THERMIQUE : protection. Couper les paires de la partie laisse-t-il assez du minerai (le charbon de la centrale, la dernière source d'un
    -- minerai) ? Sinon la coupe attend (un pont de stock, ou une bande qui produit ailleurs) ; un minerai ordinaire ne bloque jamais plus de
    -- Th.CFG.protect_wait, un minerai critique n'est jamais coupé sous son plancher (la demande est annulée après Th.CFG.critical_wait).
    -- Lot THERMIQUE2 : la retenue ne vaut plus que pour le minerai CRITIQUE (un minerai ordinaire est coupé comme sur main).
    local ctx = (st.frame and env.present > 0 and free) and th_context(f, surface, b, free, book) or nil
    if ctx and ctx.critical[o.kind] then
      local fields, byid = build_fields(f, surface, ms, free)
      local fl = byid[o.id]
      if fl then
        local ok, cwhy = Th.cut_ok(fl, fields, env.present * fl.th_rate, ctx)
        -- lot COMBUSTIBLE-MIGRATION : le plancher de Th.cut_ok ne lit que les générateurs ; le retrait des paires d'une bande de combustible exige que la
        -- bande soit constructible maintenant (matières réservées : l'état « degel » ; pas d'ennemi) et que le stock plus ce qui reste couvrent le manque
        -- (brûleurs de l'équipe compris) pendant tout le chantier (Mc.cut_ok). Sinon la coupe attend, paires en place (Th.verdict : annulée après 20 min).
        do
          local rest = 0
          for _, g in ipairs(fields) do
            if g.res == fl.res then
              local a, c2 = Th.supply(g)
              rest = rest + a + c2
            end
          end
          rest = math.max(0, rest - env.present * fl.th_rate)
          local floor = fuel_floor(f, surface)
          if not b.opts.no_combustible then -- (réglage de banc no_combustible : la règle d'avant, témoin des bancs)
            ok, cwhy = Mc.cut_ok({ fuel = true, ready = not env.enemy, rest = rest, floor = floor, stock = ctx.stock[o.kind] or 0 })
          end
          st.mc_logs = (st.mc_logs or 0) + 1
          if st.mc_logs <= 3 or st.mc_why ~= cwhy then
            st.mc_why = cwhy
            say(f, ms, string.format("avant-poste %d (%s) : coupe des %d paire(s) du projet %d : %s (plancher du combustible %.2f/s dont bruleurs de l'equipe, reste %.2f/s, stock %d, chantier %d min)",
              o.id, o.kind, env.present, st.pid, tostring(cwhy), floor, rest, ctx.stock[o.kind] or 0, Mc.CFG.build_s / 60), true)
          end
        end
        local verdict = Th.verdict(ok, ctx.critical[o.kind], env.gate_age)
        if verdict ~= "retirer" then
          env.hold = verdict
          say_why(f, ms, st, "hold:" .. tostring(cwhy), string.format("avant-poste %d : coupe des %d paire(s) du projet %d retenue par la protection (%s, %s)",
            o.id, env.present, st.pid, tostring(cwhy), verdict), true)
        end
      end
    end
  end
  local act, why = Mg.gate(st, p, env, st.frame and CHAMP_CFG or nil)
  if act == "attendre" then
    say_why(f, ms, st, "gate:" .. why, string.format("avant-poste %d : projet %d en attente (%s)%s", o.id, st.pid, why,
      why == "ennemi" and string.format(", ennemi a moins de %d tuiles, rien n'est retire", CFG.safe) or ""))
    return
  end
  -- lot AZURE (revue A1) : une bande REMISE EN RÉSERVE par un retour en arrière a des entités bâties et des fantômes dans le monde ; Build.cancel
  -- vide p.ents sans les retirer (elles seraient orphelines) : elle attend ses matières, sans annulation (le retour suivant ou le suivi la clôt)
  if act == "annuler" and p and (st.rollbacks or 0) > 0 then
    for _, e in ipairs(p.ents or {}) do
      if e.built then
        -- (revue R1 : l'attente est BORNÉE ; sinon le créneau du minerai reste pris pour toujours)
        if Rb.wait_over(tick - st.t0, (st.frame and CHAMP_CFG or CFG).gate_wait) then
          park(f, ms, o, st, p, tick, "attente-" .. tostring(why))
          leave_band(f, ms, o, st, tick)
          return
        end
        say_why(f, ms, st, "entamee:" .. why, string.format("avant-poste %d : bande du projet %d entamee (retour en arriere fait), jamais annulee : elle attend (%s)", o.id, st.pid, tostring(why)), true)
        return
      end
    end
  end
  if act == "annuler" or act == "echec" then
    if p and act == "annuler" then Build.cancel(f, st.pid, "migration: " .. why) end
    failed(f, ms, o, st, tick, why)
    return
  end
  -- "retirer" ou "passer" : le plan reprend (p.degele)
  if act == "retirer" then
    if not list then if st.frame then list, ents = survey_field(f, o) else list, ents = survey(o) end end
    local removed, got, undo, full = retire(f, surface, o, st, list, ents)
    if full then -- lot STOCKAGE-VITAL : le stock ne tient pas le contenu des paires ; la partie attend au même stade, rien au sol
      say_why(f, ms, st, "stock-plein", string.format("avant-poste %d : projet %d : retrait remis, le stock ne tient pas le contenu des paires", o.id, st.pid), true)
      return
    end
    local purged = purge_recon(f, o)
    st.retired = removed
    local packed, lost = Rb.pack(undo)
    st.undo, st.pg, st.cool, st.undo_lost = packed, nil, nil, lost -- lot AZURE (lost : paires au-delà de la borne, dites au journal) : de quoi revenir en arrière (borné) ; le suivi du progrès repart
    ms.retired = (ms.retired or 0) + removed
    say(f, ms, string.format("avant-poste %d : partie retiree, projet %d : %d foreuse(s) thermique(s) et leurs fours repris au stock (%s), %d paire(s) restent "
      .. "debout, %d piece(s) du registre de reconstruction ecartee(s)", o.id, st.pid, removed, items_text(got), math.max(0, #list - removed), purged), true)
  else
    if Th.noop_counts(st.ids) then st.noop = st.noop + 1 end -- lot THERMIQUE5 : une bande sans paire n'avait rien à libérer
    st.retired = 0
    say(f, ms, string.format("avant-poste %d : projet %d : le plan n'a pas besoin de la place de la partie (%s), rien n'est retire", o.id, st.pid, why), true)
  end
  if p then p.degele, p.reserve_next = true, nil end
  st.stage, st.t_degel, st.why_last = "chantier", tick, nil
end

---------------------------------------------------------------------------------------------------
-- Lot AZURE : retour en arrière (règle pure : shared/team/migration_retour.lua)
---------------------------------------------------------------------------------------------------
--- Recette dépliable d'un objet (règle Rb.plan) : produits par fabrication et ingrédients-objets ; nil si inconnue ou à fluide.
local function recipe_of(name)
  local r = game.recipe_prototypes and game.recipe_prototypes[name]
  if not r then return nil end
  local out
  for _, pd in ipairs(r.products or {}) do if pd.name == name then out = pd.amount or 1 end end
  local ings = {}
  for _, ing in ipairs(r.ingredients or {}) do
    if ing.type and ing.type ~= "item" then return nil end
    ings[#ings + 1] = { name = ing.name, amount = ing.amount }
  end
  return out and { out = out, ingredients = ings } or nil
end

--- Ce qu'il faut prendre au stock pour reposer une foreuse (et un four si `sink`) : les objets rendus au retrait ont pu être dépensés depuis, ils sont
--- refaits de leurs ingrédients (Rb.plan). Écrit le plan dans `u.plan` (champ de ce passage, jeté avec st.undo) ; rend vrai si tout est là.
local function afford(f, u, sink)
  local have = function(n) return Stock.count(f, n) end
  local ok, used = Rb.plan(u.name, 1, have, recipe_of)
  if not ok then return false end
  if sink then
    local ok2, used2 = Rb.plan(sink.name, 1, function(n) return have(n) - (used[n] or 0) end, recipe_of)
    if not ok2 then return false end
    for _, k in ipairs(sorted_keys(used2)) do used[k] = (used[k] or 0) + used2[k] end
  end
  u.plan = used
  return true
end

--- Repose les paires gardées par retire() sur leurs positions (foreuse thermique + four, pris au stock, combustible compris) quand les tuiles
--- sont libres. Rend (reposées, tuiles prises, sans objet).
local function repose(f, surface, st)
  local placed, busy, noitem = 0, 0, 0
  local force = f.force
  for _, u in ipairs(st.undo or {}) do
    local o = Champ.target(f, u.oid)
    local sk = u.sink
    local sink_ent = sk and surface.find_entity(sk.name, { sk.x, sk.y }) or nil
    if sink_ent and not (sink_ent.valid and sink_ent.force.name == force) then sink_ent = nil end
    local need_sink = sk ~= nil and sink_ent == nil
    if not o then
      busy = busy + 1 -- avant-poste perdu depuis
    elseif not (surface.can_place_entity({ name = u.name, position = { u.x, u.y }, direction = u.dir, force = force })
        and (not need_sink or surface.can_place_entity({ name = sk.name, position = { sk.x, sk.y }, force = force }))) then
      busy = busy + 1
    elseif not afford(f, u, need_sink and sk or nil) then
      noitem = noitem + 1
    else
      local s2 = sink_ent
      if need_sink then s2 = surface.create_entity({ name = sk.name, position = { sk.x, sk.y }, force = force }) end
      local d = ((not sk) or s2) and surface.create_entity({ name = u.name, position = { u.x, u.y }, direction = u.dir, force = force }) or nil
      if d then
        for _, n in ipairs(sorted_keys(u.plan or {})) do Stock.remove(f, n, u.plan[n]) end
        local burners = { d }
        if need_sink and s2 then
          State.own(s2, f.id, "sink", o.id)
          o.sinks[#o.sinks + 1] = s2
          if s2.type == "furnace" then burners[#burners + 1] = s2 end
        end
        for _, bu in ipairs(burners) do
          local n = math.min(T.fuel_per_burner, Stock.count(f, T.fuel))
          if n > 0 then bu.get_fuel_inventory().insert({ name = T.fuel, count = Stock.remove(f, T.fuel, n) }) end
        end
        State.own(d, f.id, "drill", o.id)
        o.drill_list[#o.drill_list + 1] = d
        o.drills = (o.drills or 0) + 1
        placed = placed + 1
      else
        if need_sink and s2 and s2.valid then s2.destroy() end
        busy = busy + 1
      end
    end
  end
  return placed, busy, noitem
end

--- Réserve DÉFINITIVE d'une bande (décision du DC, QCM-4/11-REGLEB : « Réserve, plus de nouvel essai ») : le projet n'est plus avancé (dormant : état
--- « bloque » sans reprise, jamais annulé : ses entités bâties restent en place), sa matière est rendue au coffre, ses pièces non bâties oublient leurs refus
--- et leurs fantômes (R2), et la bande n'est plus choisie par begin_band ni par la capitalisation (st.stopped). Les paires sont déjà reposées.
function park(f, ms, o, st, p, tick, why)
  local built, total = 0, 0
  if p and p.state ~= "fini" and p.state ~= "refuse" then
    p.state, p.reason, p.retry_at, p.degele, p.reserve_next, p.parked = "bloque", "retour en arriere : reserve, plus de nouvel essai", nil, nil, nil, true
    for _, e in ipairs(p.ents or {}) do
      total = total + 1
      if e.built then built = built + 1 else e.ghosted, e.fails, e.npc_blocks = nil, 0, 0 end
    end
    Build.give_back(f, p)
  end
  if st.band_key then
    st.stopped = st.stopped or {}
    if #st.stopped < 40 then st.stopped[#st.stopped + 1] = st.band_key end
  end
  log(Rb.park_line({ team = name_of(f), outpost = o.id, pid = st.pid, why = why, minute = tick / 3600, built = built, total = total }))
end

--- Sortie de la bande de ce suivi : le créneau du minerai est libéré, la suivante peut partir. Hors cadre (migration du treillis), la clé d'une partie
--- porte les numéros de ses paires, qui changent quand elles sont reposées : la bande parquée ne serait pas reconnue, donc la migration de cet
--- avant-poste s'arrête (« partiel ») au lieu de la relancer.
function leave_band(f, ms, o, st, tick)
  if not st.frame then
    finish(f, ms, o, st, "partiel", string.format("avant-poste %d : bande du projet %s parquee en reserve (treillis, sans cadre) : migration arretee, %d partie(s) migree(s)",
      o.id, tostring(st.pid), st.done))
    return
  end
  st.stage, st.pid, st.ids, st.t_done, st.gate_t0, st.why_last, st.block_t0 = "veille", nil, nil, nil, nil, nil, nil
  st.rollbacks, st.cool, st.undo, st.pg = 0, nil, nil, nil
  st.retry = tick + Rb.CFG.cool
  release(ms, o.id)
end

--- Retour en arrière : les paires retirées reviennent (tuiles libres), puis la bande attend en réserve (pause Rb.CFG.cool, retrait possible
--- ensuite) ou, au dernier retour (`final`, ou Rb.CFG.max_rollbacks atteint), le CALLER la parque (park). Rend "reserve" ou "parquer".
--- (Revue du 4/11, A1 : jamais Build.cancel ici. Il vide p.ents sans retirer les entités bâties ni les fantômes du monde : une bande à
--- 246/575 devenait orpheline, et il rend faux pour un projet rouvert ou gardé, alors que l'état avait déjà été forcé.)
local function rollback(f, surface, ms, o, st, p, tick, why, final)
  local undo_n = #(st.undo or {})
  local placed, busy, noitem = repose(f, surface, st)
  ms.restored = (ms.restored or 0) + placed
  st.rollbacks = (st.rollbacks or 0) + 1
  local nxt = Rb.after(st.rollbacks, final)
  log(Rb.line({ team = name_of(f), outpost = o.id, pid = st.pid, why = why, minute = tick / 3600, undo = undo_n, placed = placed, busy = busy,
    items = noitem, n = st.rollbacks, next = nxt, lost = st.undo_lost }))
  st.undo, st.pg = nil, nil
  if nxt == "parquer" then return "parquer" end -- (st.retired reste : Th.stop_state ferme l'avant-poste aux brûleurs, revue A6)
  st.retired = 0
  if p then
    p.state, p.reason, p.degele, p.reserve_next, p.retry_at = "reserve", "materiaux", nil, nil, nil
    for _, e in ipairs(p.ents or {}) do
      if not e.built then e.ghosted, e.fails, e.npc_blocks = nil, 0, 0 end -- (les paires reposées ont pu recouvrir les fantômes)
    end
  end
  st.stage, st.gate_t0, st.t_degel, st.why_last, st.t0 = "projet", nil, nil, nil, tick
  st.cool = tick + Rb.CFG.cool
  return "reserve"
end

--- Chantier de la ligne neuve : la partie suivante attend qu'elle ait produit.
local function step_build(f, surface, ms, o, st, tick)
  local b = f.build
  local p = b.projects[st.pid]
  local env = { now = tick, made = 0 }
  -- Lot CHAMP : une bande BLOQUÉE (fantôme refusé : une tourelle de l'équipe posée depuis sur son emprise ; mesuré, banc final-lot-20261020,
  -- azure projet 6, 41 entités bâties sur 42) gardait le créneau 90 min, puis arrêtait TOUT le champ (Mg.watch « abandonner ») : 40 paires
  -- de fer restées thermiques. Après CHAMP_CFG.block_max, elle est laissée au plan (qui peut encore la finir), comptée comme posée, et la
  -- bande suivante part.
  if st.frame then
    if p and p.state == "bloque" and not (st.undo and #st.undo > 0) then -- (revue A4 : avec des paires retirées, le retour en arrière décide d'abord)
      st.block_t0 = st.block_t0 or tick
      if tick - st.block_t0 > CHAMP_CFG.block_max then
        if st.band_key then st.done_pr[tostring(st.band_key)] = true end
        say(f, ms, string.format("avant-poste %d : bande %s du projet %d bloquee depuis %.0f min (%s) : laissee au plan, bande suivante", o.id,
          tostring(st.band_key), st.pid, (tick - st.block_t0) / 3600, tostring(p.reason)), true)
        st.stage, st.pid, st.ids, st.t_done, st.gate_t0, st.why_last, st.block_t0 = "veille", nil, nil, nil, nil, nil, nil
        st.undo, st.pg = nil, nil -- lot AZURE : la bande reste au plan (elle peut encore finir) : pas de retour en arrière pour elle
        st.retry = tick
        release(ms, o.id)
        return
      end
    else
      st.block_t0 = nil
    end
  end
  if p and p.state == "fini" then
    st.t_done = st.t_done or tick
    env.made = made_by(f, surface, p)
  end
  local act, why = Mg.watch(st, p, env)
  -- lot AZURE : chantier sans progrès depuis 15 min, ou abandon : les paires retirées reviennent (la ligne n'a rien produit)
  if act ~= "produit" and st.undo and #st.undo > 0 then
    if p then
      local nb = 0
      for _, e in ipairs(p.ents or {}) do if e.built then nb = nb + 1 end end
      st.pg = Rb.progress(st.pg, nb, tick)
    end
    local ab = (act == "abandonner" or act == "perdu")
    local nb_built, nb_total = 0, 0
    for _, e in ipairs(p and p.ents or {}) do
      nb_total = nb_total + 1
      if e.built then nb_built = nb_built + 1 end
    end
    -- lot COMBUSTIBLE-MIGRATION : une bande de combustible retirée pendant que le stock de combustible ne tient plus Mc.CFG.horizon s du plancher est reposée au seuil court
    local fuel_low = false
    local ospec = T.outposts[o.kind]
    if ospec and ospec.resource == T.fuel and not (f.build and f.build.opts and f.build.opts.no_combustible) then fuel_low = Mc.low(Stock.count(f, T.fuel), fuel_floor(f, surface)) end
    local dec, rwhy = Rb.decide({ undo = #st.undo, produced = false, state = p and p.state or nil, stalled = Rb.stalled(st.pg, tick), abandon = ab,
      built = nb_built, total = nb_total, fuel_low = fuel_low }) -- (9/11 : une bande bâtie à 90 % ou plus est finie, pas reposée)
    if rwhy == "presque-finie" then
      say_why(f, ms, st, "presque-finie", string.format("avant-poste %d : projet %d bati a %d/%d, sans progres : on le finit (pas de retour en arriere)", o.id, st.pid,
        nb_built, nb_total), true)
    end
    if dec == "retour" then
      local res = rollback(f, surface, ms, o, st, p, tick, rwhy, ab)
      if res == "reserve" then return end
      -- deuxième retour ou abandon : réserve définitive (décision du DC), jamais Build.cancel ; la suivante part
      park(f, ms, o, st, p, tick, rwhy)
      if not ab then
        leave_band(f, ms, o, st, tick)
        return
      end
      -- abandon ou projet perdu : le suivi ferme l'avant-poste ci-dessous (« partiel » : des paires ont été retirées, Th.stop_state)
    end
  end
  if act == "produit" then
    st.undo, st.pg, st.rollbacks, st.cool = nil, nil, 0, nil
    if (st.retired or 0) > 0 then
      st.done = st.done + 1
      -- comptabilité : les paires retirées comptent de nouveau comme foreuses de l'avant-poste (leur production est celle de la ligne neuve) ;
      -- lecteurs : le bilan de capacité du cerveau (view.outposts[].drills), les ordres de la capitalisation (o.drills >= cible)
      o.drills = (o.drills or 0) + st.retired
      o.migr_credit = (o.migr_credit or 0) + st.retired
    end
    st.produced = st.produced + 1
    st.fails = 0
    if st.frame and st.band_key then st.done_pr[tostring(st.band_key)] = true end -- lot CHAMP : bande posée et qui produit
    ms.lines = (ms.lines or 0) + 1
    say(f, ms, string.format("avant-poste %d : la ligne neuve du projet %d produit (%d produits finis), partie %d terminee en %.1f min", o.id, st.pid,
      env.made, st.done, (tick - st.t0) / 3600), true)
    st.stage, st.pid, st.ids, st.t_done, st.gate_t0, st.why_last = "veille", nil, nil, nil, nil, nil
    st.retry = tick
    release(ms, o.id)
    if st.noop >= CFG.max_noop then
      finish(f, ms, o, st, (st.done > 0) and "partiel" or "abandon",
        string.format("avant-poste %d : %d ligne(s) posee(s) sans liberer la place voulue : migration arretee, %d partie(s) migree(s)", o.id, st.noop, st.done))
    end
    return
  end
  if act == "abandonner" then
    -- le projet du plan reste au plan (il peut aboutir) ; la migration ne va pas plus loin. Rien produit encore : l'avant-poste redevient extensible
    -- (lot THERMIQUE5 : sauf si des paires ont déjà été retirées, Th.stop_state : « abandon » y reposait des brûleurs)
    finish(f, ms, o, st, Th.stop_state(st.done, st.produced, st.retired),
      string.format("avant-poste %d : la ligne du projet %d n'aboutit pas (%s, %.0f min depuis le retrait) : migration arretee, %d partie(s) migree(s)",
        o.id, st.pid, tostring(why), (tick - st.t_degel) / 3600, st.done))
    return
  end
  if act == "perdu" then
    release(ms, o.id)
    finish(f, ms, o, st, "abandon", string.format("avant-poste %d : la ligne du projet %d est perdue apres le retrait (%s) : migration abandonnee, "
      .. "l'avant-poste redevient extensible", o.id, st.pid, why))
    return
  end
  if p and p.state == "fini" and tick - st.t_done > CFG.fini_wait then
    say_why(f, ms, st, "fini:" .. why, string.format("avant-poste %d : ligne finie du projet %d, pas encore de produit fini (%d)", o.id, st.pid, env.made), st.frame ~= nil)
  elseif tick - st.t_degel > CFG.build_warn then
    say_why(f, ms, st, "lent:" .. tostring(why), string.format("avant-poste %d : chantier lent, projet %d a %s depuis %.0f min", o.id, st.pid, tostring(why),
      (tick - st.t_degel) / 3600), st.frame ~= nil)
  end
end

---------------------------------------------------------------------------------------------------
-- Lot THERMIQUE : balayage des paires thermiques d'un gisement COUVERT, et part électrique par minerai (journal [FO-THERMIQUE])
---------------------------------------------------------------------------------------------------
-- Retour du DC du 2/11 : « on REMPLACE les thermiques par l'électrique ; on voit bien les rangées de foreuses sur un ou 2 gisements (pas tous) ».
-- Mesuré (150 min, main 0.6.37) : des paires restent sur des gisements dont une bande produit (paires hors des bandes : bords, tuiles
-- occupées, foreuses sans four). Règle : shared/team/thermique.lua (Th.sweep). Un gisement doit être COUVERT à deux relevés de suite (une bande
-- bouchée un instant ne fait pas retirer ses paires).
local SWEEP_EVERY = 3600     -- 1 min entre deux relevés
local SWEEP_CONFIRM = 2      -- relevés de suite « couvert » avant de retirer
local REPORT_EVERY = 5 * 3600 -- une ligne [FO-THERMIQUE] par équipe toutes les 5 min
local REPORT_LOGS = 150      -- lignes [FO-THERMIQUE] au plus par équipe

--- Paires thermiques du gisement de `o` (appariées) PLUS les foreuses thermiques sans four (four détruit) : rend (liste de paires pour retire(),
--- entités, propriétaires).
local function sweep_list(f, o)
  local list, ents = survey_field(f, o)
  local matched = {}
  for _, pr in ipairs(list) do matched[pr.id] = true end
  local owners = { o }
  for _, q in ipairs(siblings(f, o)) do owners[#owners + 1] = q end
  for _, q in ipairs(owners) do
    for _, d in ipairs(q.drill_list or {}) do
      if d.valid and d.name == T.DRILL and d.unit_number and not matched[d.unit_number] then
        matched[d.unit_number] = true
        list[#list + 1] = { id = d.unit_number, drill = box_of(d) }
        ents[d.unit_number] = d
      end
    end
  end
  return list, ents, owners
end

--- Lot FOREUSES-THERMIQUES, RÉSERVE D'AMORÇAGE (décision du lead, 7/11 ; exception de sûreté) : réseau tombé, les chaudières ne brûlent plus,
--- le plancher lu au débit des générateurs (fuel_burn) tombe à 0 et Th.cut_ok laisse couper toutes les paires de charbon (champ3, 7/11,
--- déduit). Un avant-poste de COMBUSTIBLE garde ses K dernières thermiques (Ra.keep, Sw.coal_reserve : une chaudière à pleine charge sans
--- courant), quel que soit le débit lu. Rend les numéros retirables (ordre gardé) et le nombre retenu.
local function reserve_filter(f, owners, ids)
  local hold, keep = {}, nil
  for _, q in ipairs(owners or {}) do
    if Ra.fuel_outpost(q) then
      keep = keep or (Ra.keep(f))
      local mine = {}
      for _, d in ipairs(q.drill_list or {}) do if d.valid and d.name == T.DRILL and d.unit_number then mine[#mine + 1] = d.unit_number end end
      for _, u in ipairs(Sw.reserve_keepers(mine, keep)) do hold[u] = true end
    end
  end
  local out = {}
  for _, id in ipairs(ids) do if not hold[id] then out[#out + 1] = id end end
  return out, #ids - #out
end

local function sweep(f, surface, ms, free, book, tick)
  if tick < (ms.sweep_next or 0) then return 0 end
  ms.sweep_next = tick + SWEEP_EVERY
  local fields, byid = build_fields(f, surface, ms, free)
  if #fields == 0 then return 0 end
  local ctx = th_context(f, surface, f.build, free, book)
  local gated = {}
  for _, fl in ipairs(fields) do
    local st = ms.o[fl.id]
    if st then st.cov_n = Th.covered(fl) and ((st.cov_n or 0) + 1) or 0 end
    local g = {}
    for _, k in ipairs(sorted_keys(fl)) do g[k] = fl[k] end
    if not st or (st.cov_n or 0) < SWEEP_CONFIRM then g.working = 0 end
    gated[#gated + 1] = g
  end
  local acts, refused = Th.sweep(gated, ctx)
  local swept = 0
  for _, a in ipairs(acts) do
    local o = Champ.target(f, a.id)
    local st = ms.o[a.id]
    if o and st and st.stage ~= "projet" then -- (avant le retrait de sa partie, une bande a besoin de ses paires ; ensuite les restes ne gênent plus)
      local list, ents, owners = sweep_list(f, o)
      local ids = {}
      for _, pr in ipairs(list) do ids[#ids + 1] = pr.id end
      table.sort(ids)
      local held_s
      ids, held_s = reserve_filter(f, owners, ids) -- (balayage : réserve d'amorçage)
      ms.reserve_held = (ms.reserve_held or 0) + held_s
      if #ids > 0 then
        local before = {}
        for i, q in ipairs(owners) do before[i] = q.drills or 0 end
        local fl = byid[a.id]
        local removed, got, _, full = retire(f, surface, o, { ids = ids, frame = true }, list, ents)
        if not full then -- lot STOCKAGE-VITAL : sinon le balayage attend la place au stock (rien compté, rien écrit)
          -- la comptabilité des foreuses de l'avant-poste ne change pas : l'électrique de la bande en tient lieu (comme au retrait d'une bande)
          for i, q in ipairs(owners) do
            q.drills = before[i]
            purge_recon(f, q)
          end
          o.migr_credit = (o.migr_credit or 0) + removed
          ms.retired = (ms.retired or 0) + removed
          ms.swept = (ms.swept or 0) + removed
          swept = swept + removed
          say(f, ms, string.format("gisement de l'avant-poste %d (%s) : %d paire(s) thermique(s) retiree(s) de force, bande electrique productive (%d foreuse(s) en marche, "
            .. "%.2f ore/s contre %.2f ore/s thermique, %d paire(s) avec combustible), repris au stock : %s", o.id, o.kind, removed, fl and fl.working or 0,
            fl and fl.working * fl.el_rate or 0, fl and (Th.supply(fl)) or 0, fl and fl.fueled or 0, items_text(got)), true)
        end
      end
    end
  end
  -- Lot THERMIQUE6, règle B (GO du lead, 3/11 ; le DC : « 35 foreuses thermiques qui ne sont plus alimentées ») : un brûleur À SEC depuis
  -- Th.CFG.dry_wait sur un gisement dont une bande est FINIE est retiré seul (Th.dry_retire), sans exiger « couvert » ; jamais pendant qu'une
  -- bande du champ attend son dégel (« projet »), jamais le charbon de la centrale sous son plancher (Th.cut_ok sans perte). Date par
  -- foreuse ms.dry[numéro], refaite à chaque passage avec les seules foreuses vues (ménage sans `pairs`).
  -- (variante B' : une bande FINIE du MÊME MINERAI dans la force suffit, pas forcément sur ce gisement : les brûleurs à sec sont surtout sur
  -- des gisements sans bande, e3-lot 271828182 : Émeraude fer 50, charbon du joueur 17, pierre 9)
  local done_res = {}
  for _, fl in ipairs(fields) do if (fl.fini or 0) > 0 then done_res[fl.res] = true end end
  local dry = {}
  for _, fl in ipairs(fields) do
    local o = Champ.target(f, fl.id)
    local st = ms.o[fl.id]
    if o and (not st or st.stage ~= "projet") and done_res[fl.res] and (fl.pairs or 0) > (fl.fueled or 0) then
      local prot = not ctx.critical[fl.res] or (Th.cut_ok(fl, fields, 0, ctx))
      local list, ents, owners = sweep_list(f, o)
      local ids = {}
      for _, pr in ipairs(list) do
        local d = ents[pr.id]
        if d and d.valid and not has_fuel(d) then
          dry[pr.id] = (ms.dry and ms.dry[pr.id]) or tick
          if Th.dry_retire(dry[pr.id], tick, true, prot) then ids[#ids + 1] = pr.id end
        end
      end
      table.sort(ids)
      ids = (reserve_filter(f, owners, ids)) -- (retrait à sec : réserve d'amorçage)
      if #ids > 0 then
        local before = {}
        for i, q in ipairs(owners) do before[i] = q.drills or 0 end
        local removed, got, _, full = retire(f, surface, o, { ids = ids, frame = true }, list, ents)
        if not full then -- lot STOCKAGE-VITAL : sinon le retrait à sec attend la place au stock (ms.dry reste)
          for i, q in ipairs(owners) do q.drills = (before)[i]; purge_recon(f, q) end -- (comptabilité inchangée, comme le balayage)
          ms.retired = (ms.retired or 0) + removed
          ms.dry_retired = (ms.dry_retired or 0) + removed
          swept = swept + removed
          log(string.format("[FO-THERMIQUE] %s : brûleur(s) à sec retiré(s) : %d sur le gisement de l'avant-poste %d (%s), à sec depuis %d min au moins, "
            .. "%d bande(s) finie(s) sur ce gisement (une au moins sur ce minerai), %d paire(s) restent ; repris au stock : %s", name_of(f), removed, o.id,
            o.kind, Th.CFG.dry_wait / 3600, fl.fini or 0,
            math.max(0, fl.pairs - removed), items_text(got)))
        end
      end
    end
  end
  ms.dry = dry
  if tick >= (ms.th_report_next or 0) then
    ms.th_report_next = tick + REPORT_EVERY
    ms.th_logs = (ms.th_logs or 0) + 1
    if ms.th_logs <= REPORT_LOGS then
      local parts = {}
      for _, r in ipairs(Th.shares(fields, T.OUTPOST_ORDER)) do
        if r.pairs + r.working > 0 then
          parts[#parts + 1] = string.format("%s %d thermique(s), %d electrique(s) en marche, part %s, %d gisement(s) couvert(s) gardant des paires", r.res, r.pairs,
            r.working, r.share and string.format("%.0f%%", r.share * 100) or "-", r.covered_with_pairs)
        end
      end
      local why = {}
      for _, r in ipairs(refused) do why[#why + 1] = string.format("%d:%s", r.id, r.why) end
      log(string.format("[FO-THERMIQUE] %s min %.0f | %s | refus du balayage : %s | %d paire(s) balayee(s) depuis le debut", name_of(f), tick / 3600,
        #parts > 0 and table.concat(parts, " ; ") or "aucune foreuse", #why > 0 and table.concat(why, ", ") or "aucun", ms.swept or 0))
    end
  end
  return swept > 0 and 1 or 0
end
Mig.sweep = sweep -- (bancs hors jeu : tests/migration_champ_test.lua, section T)

--- Premier avant-poste dont la migration peut partir (lot THERMIQUE : les gisements les plus productifs d'abord, un chantier par minerai).
--- busy = { total, ids = { [numéro] = true }, [minerai] = chantiers en cours } : les créneaux déjà pris.
local function start_next(f, surface, ms, free, obtainable, tick, busy, book, hold)
  local b = f.build
  -- Lot CHAMP : la plaque la plus en manque d'abord (retour du DC du 2/11 : « 57 plaques de cuivre » pour près de 1 000 de fer), puis
  -- le numéro d'avant-poste
  -- Lot CHAMP (ordres « couvrir / ouvrir ») : les champs voulus par la capitalisation d'abord (Mig.want), gisements sans avant-poste compris
  local cand = {}
  local function add(oid, o)
    if is_champ_kind(o.kind) then
      local sq = ms.o[oid]
      local th, el = rates_of_kind(f, o.kind)
      cand[#cand + 1] = { id = oid, res = o.kind, tier = is_furnace_kind(o.kind) and 0 or 1, pairs = thermal_count(o), th_rate = th or 1, el_rate = el or 1, working = 0,
        have = free[T.outposts[o.kind].product] or 0, wanted = (sq and (sq.want_until or 0) > tick) and true or false,
        tiles = o.deposit_tiles or (o.site_info and o.site_info.deposit) or 0 } -- (lot GEANT-D-ABORD : tuiles réelles du gisement, départage de Th.order)
    end
  end
  for _, oid in ipairs(sorted_keys(f.outposts)) do add(oid, f.outposts[oid]) end
  for _, fid in ipairs(sorted_keys(ms.fields)) do add(fid, ms.fields[fid]) end
  cand = Th.order(cand) -- voulus d'abord, puis le plus d'extraction thermique en jeu, puis la plaque la plus en manque, puis le numéro
  local iron_waiting = false -- lot FER-D-ABORD : une bande de plaques attend le stock de fer (Th.iron_waits) : pas de bande brute neuve avant elle
  local burn -- (lot FER-D-ABORD : combustible brûlé par les générateurs, lu une fois par pensée et seulement si une bande de combustible est en jeu)
  for _, it in ipairs(cand) do
    local oid = it.id
    local o = Champ.target(f, oid)
    local st = ms.o[oid]
    if Th.FER_D_ABORD and iron_waiting and (it.tier or 0) == 1 and not it.wanted then
      local spec = T.outposts[o.kind]
      local is_fuel = spec.resource == T.fuel
      local short = false
      if is_fuel then
        burn = burn or fuel_burn(f, surface)
        short = Th.fuel_short(free[spec.product] or 0, burn)
      end
      local held, why_hold = Th.raw_holds({ tier = it.tier, wanted = it.wanted, iron_waiting = iron_waiting, fuel = is_fuel, fuel_short = short,
        since = ms.iron_since, now = tick })
      if held then
        if st then say_why(f, ms, st, "fer-d-abord", string.format("avant-poste %d (%s) : bande brute neuve retenue, une bande de plaques attend le fer", o.id, o.kind)) end
        goto next_outpost
      elseif why_hold == "expire" and ms.iron_note ~= "expire" then
        ms.iron_note = "expire"
        say(f, ms, string.format("fer d'abord : retenue des bandes brutes levee apres %d min sans depart d'une bande de fer (plaques de fer libres : %d)",
          (tick - (ms.iron_since or tick)) / 3600, free[T.outposts.iron.product] or 0), true)
      elseif why_hold == "combustible" and ms.iron_note ~= "combustible" then
        ms.iron_note = "combustible"
        say(f, ms, string.format("fer d'abord : avant-poste %d (%s) non retenu, le combustible manque (stock %d, %.2f/s brules)", o.id, o.kind,
          free[spec.product] or 0, burn or 0), true)
      end
    end
    -- lot THERMIQUE : charbon et pierre n'existent que par le champ (le gabarit de fonderie du treillis ne sait pas poser un coffre)
    if not is_furnace_kind(o.kind) and Champ.data(f, o.kind) == nil then goto next_outpost end
    -- lot CHAMP : un créneau déjà pris : seulement un champ d'un AUTRE minerai (ni l'avant-poste en cours, ni son gisement), lot THERMIQUE : un
    -- seul chantier par minerai, trois au plus (Th.free_slot)
    if busy.total > 0 and (busy.ids[oid] or not Th.free_slot(o.kind, busy) or Champ.data(f, o.kind) == nil) then goto next_outpost end
    -- lot MIGRATION-DECLENCHE : un abandon (échecs de suite, ligne perdue) n'est plus définitif : après CFG.revive, l'avant-poste repart
    -- d'un état neuf (parties refusées oubliées : le champ, le stock et le courant ont changé). L'abandon « pas de gabarit » reste. Un
    -- abandon d'une sauvegarde 0.6.18 (sans date) compte comme daté du tick 0 : repris à la première pensée.
    local since = st and st.abandoned and not st.sans_gabarit and (st.abandoned_at or 0) or nil
    local waited = st and st.pause or CFG.revive -- lot RACCORD-BANDE : pause courte après des refus du plan sur une bande du champ
    if since and tick >= since + waited and o.migr == nil then
      st = new_state()
      ms.o[oid] = st
      say(f, ms, string.format("avant-poste %d (%s) : migration reprise apres abandon (%.0f min)", o.id, o.kind, waited / 3600), true)
    end
    -- lot CHAMP : un voisin d'un gisement déjà planifié par un autre avant-poste n'en planifie pas un second
    local owner
    for _, q in ipairs(siblings(f, o)) do
      local sq = ms.o[q.id]
      if not owner and sq and sq.frame and not sq.abandoned then owner = q end
    end
    if owner then
      if st then say_why(f, ms, st, "champ-de:" .. owner.id, string.format("avant-poste %d (%s) : son gisement est le champ de l'avant-poste %d", o.id, o.kind, owner.id)) end
    elseif not (st and st.abandoned) and o.migr ~= "fini" and o.migr ~= "partiel" then
      st = st or new_state()
      ms.o[oid] = st
      -- lot CHAMP : le champ en bandes quand la règle a ses données (foreuse, tapis débloqué, poteau) ; sinon le treillis comme avant
      local champ = Champ.data(f, o.kind) ~= nil
      local list = champ and survey_field(f, o) or survey(o)
      local rects = champ and {} or lots_of(f, o, list)
      local product = T.outposts[o.kind].product
      local raw = product == T.outposts[o.kind].resource -- (lot THERMIQUE5 : minerai porté brut, sans four)
      local cfg = champ and (raw and CHAMP_RAW_CFG or CHAMP_CFG) or CFG
      local npairs = #list
      if champ and st.frame and npairs == 0 then npairs = 1 end -- bandes sans paire : agrandissement du champ (begin_band)
      if champ and it.wanted and npairs == 0 then npairs = 1 end -- voulu par la capitalisation : un gisement sans paire se pose aussi
      local lattice = champ or next(rects) ~= nil
      -- la recherche d'ennemi (coûteuse) seulement quand le reste est réuni
      local enemy = false
      if npairs >= cfg.min_pairs and lattice and tick >= (st.retry or 0) then enemy = enemy_near(f, surface, o.pos.x, o.pos.y) end
      -- lot CHAMP : la bande coûte surtout du FER (foreuses, bras, tapis) : la garde de stock lit les plaques de fer ; elle lisait la plaque
      -- du champ, et un champ de cuivre ne migrait jamais quand le cuivre manquait (le cas même du DC)
      local plates = champ and (free[T.outposts.iron.product] or 0) or (free[product] or 0)
      local ok, why = Mg.start_ok({ migr = o.migr, plan = true, power = power_ok(b), obtainable = obtainable, plates = plates,
        lattice = lattice, pairs = npairs, enemy = enemy, now = tick, retry = st.retry, abandoned = st.abandoned }, cfg)
      if Th.iron_waits(it.tier, why) then -- lot FER-D-ABORD
        iron_waiting = true
        ms.iron_since, ms.iron_last = Th.iron_clock(ms.iron_since, ms.iron_last, true, tick)
      end
      -- Lot THERMIQUE2 : la garde de fer du lot THERMIQUE (Th.financed : fer libre >= coût des foreuses de remplacement) est retirée : une force
      -- dont le fer est tout consommé ne lançait jamais la bande qui lui rendrait du fer (« migration en veille (fer) », champ-longue 20261020) ;
      -- la garde de plaques de Mg.start_ok (comme sur main) reste.
      -- lot THERMIQUE5 : pendant une retenue de la pile, une bande neuve ne part que si la porte laisse passer sa plaque (comme sa réserve au
      -- plan directeur, Build.reserve_suspended, famille « capi ») ; lu au moment du départ seulement (les causes de veille restent au journal)
      -- décision du DC du 8/11 (« Oui, toujours ») : la bande d'un gisement VOULU par la capitalisation (couvrir, ouvrir) part toujours
      if ok and hold and not Th.pile_permits("partir", true, (PileRt.porte(f, it.wanted and "couverture" or "capi", product))) then
        say_why(f, ms, st, "pile", string.format("avant-poste %d (%s) : bande neuve retenue par la pile, %d paire(s) thermique(s)", o.id, o.kind, #list))
      elseif ok then
        local began
        if champ then began = begin_band(f, surface, ms, o, st, list, tick, free)
        else began = begin_part(f, surface, ms, o, st, list, rects, tick) end
        if began then
          if (it.tier or 0) == 0 then ms.iron_since, ms.iron_last, ms.iron_note = nil, nil, nil end -- lot FER-D-ABORD : une bande de plaques part, l'attente est finie
          return true
        end
      elseif o.migr == "en cours" and (why == "paires" or why == "treillis") and st.done > 0 and not (champ and st.frame) then
        -- plus assez de paires pour une partie de plus : le reste est laissé tel quel
        finish(f, ms, o, st, (#list == 0) and "fini" or "partiel",
          string.format("avant-poste %d : %d paire(s) restent (%s), %d partie(s) migree(s)", o.id, #list, why, st.done))
      elseif why ~= "fait" then
        say_why(f, ms, st, "start:" .. why, string.format("avant-poste %d (%s) : migration en veille (%s), %d paire(s) thermique(s)", o.id, o.kind, why, #list))
      end
    end
    ::next_outpost::
  end
  if not iron_waiting then -- lot FER-D-ABORD : rien n'attend le fer ; l'horloge de retenue s'éteint après cfg.iron_hold_gap
    ms.iron_since, ms.iron_last = Th.iron_clock(ms.iron_since, ms.iron_last, false, tick)
    if ms.iron_since == nil then ms.iron_note = nil end
  end
  return false
end

---------------------------------------------------------------------------------------------------
-- Lot MEGA-FONDERIE (A2) : bandes EN AVANCE d'un gisement à méga-fonderie décidée (règle pure : shared/team/mega_pose.lua)
---------------------------------------------------------------------------------------------------
-- Une bande de plus est demandée au plan directeur pendant que la bande principale du même cadre est déjà au chantier (ses matières
-- réunies). Déclencheur : script/team/mega_fonderie.lua (Mega.think) pose st.mega_par par Mig.want ; décision : Mp.allow (courant, ennemi,
-- plafond de bandes en vol, stock qui PAIE la bande et une marge, pile) ; action : Build.request du même site « champ » que la bande
-- principale ; effet : des bandes qui se bâtissent en parallèle (journal [FO-MIGRATION] « EN AVANCE »). Lecteur de st.ahead : begin_band (ne
-- reprend pas la bande), ahead_reap (la compte posée), Mig.projects (le cerveau fabrique ses matières). État : st.ahead = { [bande] =
-- { pid, t0 } } (nombres seulement). Une bande avec des paires thermiques dessous reste à la voie principale (retrait, dégel, retour arrière).

-- (band_iron : voir en tête du module, lot SATURATION : le fer de la bande est celui qu'il reste à fabriquer une fois le stock dormant pris)

--- Les bandes en avance du champ : posées (fini), bloquées trop longtemps (laissées au plan) ou perdues ; rend le nombre de bandes comptées.
local function ahead_reap(f, ms, o, st, tick)
  local b = f.build
  local n = 0
  for _, k in ipairs(sorted_keys(st.ahead)) do
    local a = st.ahead[k]
    local p = b.projects[a.pid]
    local blocked_for = 0
    if p and p.state == "bloque" then
      a.block_t0 = a.block_t0 or tick
      blocked_for = tick - a.block_t0
    else
      a.block_t0 = nil
    end
    local v = Mp.reap(p and { state = p.state, blocked_for = blocked_for } or nil)
    if v == "posee" or v == "bloquee" then
      st.done_pr[k] = true
      st.produced = st.produced + 1
      ms.lines = (ms.lines or 0) + 1
      st.ahead[k] = nil
      n = n + 1
      say(f, ms, string.format("%s %d (%s) : bande %s EN AVANCE %s (projet %d, %.1f min), %d bande(s) encore en avance", o.field and "gisement" or "avant-poste", o.id,
        o.kind, k, v == "posee" and "posee" or "bloquee, laissee au plan", a.pid, (tick - a.t0) / 3600, #sorted_keys(st.ahead)), true)
    elseif v == "perdue" then
      st.ahead[k] = nil
      say(f, ms, string.format("%s %d (%s) : bande %s EN AVANCE perdue (projet %d disparu ou annule) : elle redevient une bande du cadre", o.field and "gisement" or "avant-poste",
        o.id, o.kind, k, a.pid), true)
    end
  end
  if next(st.ahead) == nil then st.ahead = nil end
  return n
end

--- Une bande de plus en avance pour le champ `o`, si la règle l'autorise. Rend vrai si une demande est partie.
local function ahead_launch(f, surface, ms, o, st, tick, free, book, hold, dormant)
  local b = f.build
  local p = st.pid and b.projects[st.pid]
  local inflight = (p and 1 or 0)
  for _ in ipairs(sorted_keys(st.ahead)) do inflight = inflight + 1 end
  local product = T.outposts[o.kind].product
  -- lot SATURATION : un champ dont les machines de la bande dorment au coffre a le plafond de parallélisme entier, méga-fonderie ou non
  local c = { on = true, power = power_ok(b), crisis = false, enemy = false, pairs_under = 0, inflight = inflight, par_max = st.mega_par or (dormant and Mp.CFG.par_cap) or 1,
    main_ready = p ~= nil and p.state ~= "reserve" and p.state ~= "plan" and p.state ~= "attente", iron = free[T.outposts.iron.product] or 0, band_iron = 1 }
  local function refuse(why)
    say_why(f, ms, st, "avance:" .. why, string.format("%s %d (%s) : pas de bande en avance (%s), %d bande(s) en vol", o.field and "gisement" or "avant-poste", o.id, o.kind, why,
      inflight))
    return false
  end
  local ok, why = Mp.allow(c)
  if not ok then return refuse(why) end -- (les causes sans coût : courant, plafond, matières de la principale ; l'ennemi et le plan viennent après)
  if not garde_band(f, o, tick) then return refuse("anti-dispersion") end -- lot IA-GARDE : même garde que begin_band
  if hold and not Th.pile_permits("partir", true, (PileRt.porte(f, "couverture", product))) then return refuse("pile") end
  c.enemy = enemy_near(f, surface, o.pos.x, o.pos.y)
  ok, why = Mp.allow(c)
  if not ok then return refuse(why) end
  -- la bande à demander : la première du cadre qui n'est ni posée, ni écartée, ni en vol, ni celle de la voie principale
  local bad = {}
  for _, k in ipairs(st.bad or {}) do bad[k] = true end
  for _, k in ipairs(st.stopped or {}) do bad[k] = true end
  local pr
  for _, x in ipairs(st.order) do
    local k = tostring(x)
    if not pr and not st.done_pr[k] and not bad[x] and not (st.prot and st.prot[x]) and not (st.ahead and st.ahead[k]) and x ~= st.band_key then pr = x end
  end
  if not pr then return refuse("aucune bande de plus dans le cadre") end
  local bd, bwhy = Champ.band(f, surface, o, st.frame, pr)
  if not bd then
    st.bad = st.bad or {}
    st.bad[#st.bad + 1] = pr
    say(f, ms, string.format("avant-poste %d : bande %d ecartee en avance (%s)", o.id, pr, tostring(bwhy)))
    return false
  end
  st.band_need = band_list(bd) -- lot SATURATION : la porte des bandes en avance relit le stock dormant sur cette liste
  local list = survey_field(f, o)
  local under = {}
  for i = 1, #bd.tiles - 1, 2 do under[P.tkey(bd.tiles[i], bd.tiles[i + 1])] = true end
  local pairs_under = 0
  for _, pr2 in ipairs(list) do
    local t = Mg.tiles({ Mg.box(pr2.drill), Mg.box(pr2.sink) })
    for i = 1, #t - 1, 2 do
      if under[P.tkey(t[i], t[i + 1])] then pairs_under = pairs_under + 1; break end
    end
  end
  local sat
  c.pairs_under, c.band_iron, sat = pairs_under, nil, nil
  c.band_iron, sat = band_iron(book, bd, free)
  if not c.band_iron then return refuse("cout de la bande illisible") end
  ok, why = Mp.allow(c)
  if not ok then
    st.ahead_retry = tick + 3600 -- (le plan d'une bande est cher : un refus de stock ou de paires se relit dans une minute)
    return refuse(why)
  end
  coal_projects(f, ms, o, st, bd, pr)
  local spec = { site = "champ", champ = { oid = o.id, pr = pr, frame = st.frame }, near = { x = o.pos.x, y = o.pos.y }, prio = CFG.prio,
    domain = "production", lazy_clear = true, pile = "couverture", product = product }
  local id, rwhy = Build.request(f, spec)
  if not id then
    st.ahead_retry = tick + CFG.retry
    return refuse("demande impossible : " .. tostring(rwhy))
  end
  defer_projects(f, ms, o, st, bd, pr, id)
  st.ahead = st.ahead or {}
  st.ahead[tostring(pr)] = { pid = id, t0 = tick }
  ms.requests = (ms.requests or 0) + 1
  st.why_last = nil
  say(f, ms, string.format("%s %d (%s) : bande %d EN AVANCE demandee, projet %d (%d bande(s) en vol sur %d), fer libre %d pour %d (marge d'une bande comprise)%s",
    o.field and "gisement" or "avant-poste", o.id, o.kind, pr, id, inflight + 1, c.par_max, math.floor(c.iron), math.ceil(c.band_iron * (1 + Mp.CFG.margin)),
    (sat and sat.starts) and string.format(" ; PAYEE PAR LE STOCK DORMANT (%d machine(s) sur %d au coffre, seuil %d %%)", sat.dormant, sat.want, Mp.CFG.start_pct) or ""), true)
  return true
end

--- Passage des bandes en avance de tous les champs voulus par une méga-fonderie (st.mega_par). Une demande au plus par passage. Rend 1 si une
--- demande est partie.
local function ahead_step(f, surface, ms, free, book, tick, hold)
  if not free then return 0 end
  local did = 0
  for _, oid in ipairs(sorted_keys(ms.o)) do
    local st = ms.o[oid]
    -- lot SATURATION (DC 9/11) : les machines de la dernière bande planifiée dorment au coffre : le champ a droit aux bandes en avance, méga-fonderie ou non
    local dormant = st.band_need ~= nil and Mp.saturation(st.band_need, free).starts == true
    if (st.mega_par or dormant) and st.frame and not st.abandoned then
      local o = Champ.target(f, oid)
      if o then
        if st.ahead then ahead_reap(f, ms, o, st, tick) end
        if did == 0 and ((st.want_until or 0) > tick or dormant) and tick >= (st.ahead_retry or 0) and st.pid and (st.stage == "projet" or st.stage == "chantier")
          and ahead_launch(f, surface, ms, o, st, tick, free, book, hold, dormant) then did = 1 end
      end
    end
  end
  return did
end

local function ms_of(f)
  local ms = f.migration
  if not ms then
    ms = { next = 0, logs = 0, logs_f = 0, o = {} }
    f.migration = ms
  end
  return ms
end

---------------------------------------------------------------------------------------------------
-- Lot CHAMP : ordres « couvrir / ouvrir » de la capitalisation (script/ai3/capitalisation.lua) passés par le champ
---------------------------------------------------------------------------------------------------
-- Demande du lead (2/11) : « faire passer les ordres couvrir / ouvrir de la capitalisation par le champ pour que ses lignes électriques ne
-- bloquent plus les gisements ». Avant, un tel ordre posait une fonderie à foreuses du TREILLIS (gabarit d'AUTO) dont la ligne de foreuses
-- électriques, son tapis et ses poteaux occupaient le gisement : le champ n'y trouvait plus de bande (mesuré, partie de 150 min, graine
-- 20261020, emerald : « gisement occupe (hors paires) : electric-mining-drill 18, reserve 127 [...] transport-belt 29 », aucune bande).

--- Sorte d'avant-poste (T.outposts) dont le champ sait poser le minerai `resource` aujourd'hui (réceptacle four, foreuse, tapis débloqué,
--- poteau : Champ.data), ou nil.
function Mig.takes(f, resource)
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    if T.outposts[kind].resource == resource and is_furnace_kind(kind) and Champ.data(f, kind) ~= nil then return kind end
  end
  return nil
end

--- Un ordre de la capitalisation veut le gisement recensé `dep` { id, resource, tiles, x0, y0, x1, y1, cx, cy }. La cible (Mg.want_target) :
--- le champ déjà planifié sur ce gisement, sinon l'avant-poste à fours le plus proche du centre, sinon un gisement SANS avant-poste
--- (ms.fields, créé ici si un réseau alimenté est à portée d'une chaîne de poteaux). La cible devient « voulue » (st.want_until) : servie
--- avant les autres (start_next), une paire n'y est pas exigée, une bande sans paire n'attend pas que la plaque manque (begin_band).
--- Rend (numéro de la cible, bandes qui produisent déjà) ou nil, raison.
function Mig.want(f, dep, tick, par)
  local kind = Mig.takes(f, dep.resource)
  if not kind then return nil, "pas de champ pour ce minerai" end
  local ms = ms_of(f)
  ms.fields = ms.fields or {}
  local cands = {}
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local q = f.outposts[oid]
    if q.kind == kind then
      local sq = ms.o[oid]
      cands[#cands + 1] = { id = oid, pos = q.pos, framed = (sq and sq.frame and not sq.abandoned) and true or nil }
    end
  end
  for _, fid in ipairs(sorted_keys(ms.fields)) do
    local q = ms.fields[fid]
    if q.kind == kind then
      local sq = ms.o[fid]
      cands[#cands + 1] = { id = fid, pos = q.pos, field = true, framed = (sq and sq.frame and not sq.abandoned) and true or nil }
    end
  end
  local c = Mg.want_target(cands, dep, CFG.want_margin)
  local o = c and Champ.target(f, c.id)
  if not o then
    -- gisement neuf : sans réseau alimenté à portée d'une chaîne de poteaux, la bande se poserait sans courant
    if not Champ.powered_pole(f, f.hq.surface, dep.cx, dep.cy) then
      return nil, string.format("aucun reseau alimente a moins de %d tuiles", Champ.CFG.chain_r)
    end
    ms.nfield = (ms.nfield or 0) + 1
    local id = Champ.FIELD_BASE + ms.nfield
    o = { id = id, kind = kind, pos = { x = dep.cx, y = dep.cy }, field = true, dep = dep.id, drill_list = {}, sinks = {}, drills = 0,
      box = { dep.x0, dep.y0, dep.x1, dep.y1 }, deposit_tiles = dep.tiles }
    ms.fields[id] = o
    say(f, ms, string.format("gisement %d (%s) : champ voulu par la capitalisation sur %s (%d tuiles), sans avant-poste", id, kind,
      tostring(dep.id), dep.tiles or 0), true)
  end
  if o.migr == "fini" then return nil, "champ deja pose en entier" end
  local st = ms.o[o.id]
  if not st then st = new_state(); ms.o[o.id] = st end
  if st.sans_gabarit then return nil, "champ impossible (gabarit)" end
  -- (un cadre VIDE, « aucune bande ne tient », n'est replanifié qu'après CFG.revive : le plan entier d'un grand gisement coûte cher)
  local wait = (st.order and #st.order == 0) and CFG.revive or CHAMP_CFG.retry
  if st.abandoned and tick >= (st.abandoned_at or 0) + wait then
    -- un champ abandonné (échecs de suite, aucune bande ne tenait) repart : refus et cadre vide oubliés (le gisement a pu changer)
    st.abandoned, st.abandoned_at, st.fails, st.bad = nil, nil, 0, nil
    if st.order and #st.order == 0 then st.frame, st.order = nil, nil end
  end
  if st.abandoned then return nil, "champ abandonne il y a moins de " .. math.floor(wait / 3600) .. " min" end
  if o.migr == "partiel" and st.stage == "veille" then o.migr, st.fails, st.bad = nil, 0, nil end -- arrêté après des échecs : on reprend
  st.want_until = math.max(st.want_until or 0, tick + CFG.want_ttl)
  if par and par >= 1 then st.mega_par = par end -- lot MEGA-FONDERIE (A2) : bandes en vol au plus (Mp.par_max), lu par ahead_step
  return o.id, st.produced
end

--- Suivi d'un ordre de la capitalisation sur le champ `id` (garde la cible « voulue » tant que l'ordre suit). Rend { produced, stage,
--- pid, pstate, reason, built (entités posées du projet en cours), abandoned, migr } ou nil (cible perdue).
function Mig.follow(f, id, tick)
  local ms = f and f.migration
  local o = Champ.target(f, id)
  local st = ms and ms.o and ms.o[id]
  if not (o and st) then return nil end
  st.want_until = math.max(st.want_until or 0, tick + CFG.want_ttl)
  local p = st.pid and f.build and f.build.projects[st.pid]
  local built = 0
  local drills, drills_built = 0, 0 -- lot COURANT-LIBRE : foreuses de la bande (rôle « champ-foreuse »), pour le reste à poser de l'ordre
  if p then
    for _, e in ipairs(p.ents or {}) do
      if e.built then built = built + 1 end
      if e.role == "champ-foreuse" then
        drills = drills + 1
        if e.built then drills_built = drills_built + 1 end
      end
    end
  end
  return { produced = st.produced or 0, stage = st.stage, pid = st.pid, pstate = p and p.state or nil, reason = p and p.reason or nil,
    built = built, abandoned = st.abandoned or nil, migr = o.migr, drills = drills, drills_built = drills_built }
end

--- Une pensée d'équipe. `free` : stock libre ({ [objet] = n }). `hold` : la pile retient l'amélioration (script/team/team.lua) : les bandes
--- déjà demandées avancent et le balayage passe (ils rendent des objets), seul le départ d'une bande neuve est retenu, sauf si la porte de
--- la pile laisse passer sa plaque (lot THERMIQUE5, Th.pile_permits). Rend 1 si une étape a eu lieu, sinon 0.
function Mig.think(f, surface, book, free, tick, hold)
  hold = hold == true
  if not (f and f.outposts and f.hq and f.hq.valid and f.build) then return 0 end
  local ms = ms_of(f)
  if tick < ms.next then return 0 end
  ms.next = tick + CFG.every
  -- lot COUT-600 : la vérification d'un cadre planifié à la pensée d'avant (Champ.flush : jusqu'à 4,7 M d'instructions sur un champ de 600 %) a sa
  -- pensée à elle : rien d'autre ne tourne dans celle-ci
  if ms.verify_due then
    ms.verify_due = nil
    Champ.flush(f) -- (journal seulement : la perte des attentes par un chargement ne change aucune décision)
    return 0
  end
  if tick >= (ms.report_next or 0) then -- lot CHAMP : état des bandes du champ au journal ([FO-CHAMP-ETAT])
    ms.report_next = tick + Champ.REPORT_EVERY
    Profiler.fstart("mig:rapport") -- lot X10-S0 : mesure seulement
    Champ.report(f, surface, tick)
    Profiler.fstop("mig:rapport")
  end
  Profiler.fstart("mig:melange")
  Melange.pass(f, surface, tick) -- (sa propre horloge : Melange.EVERY)
  Profiler.fstop("mig:melange")
  local item = T.DRILL_ELECTRIC
  if not game.entity_prototypes[item] then return 0 end
  local did = 0
  Profiler.fstart("mig:creneaux")
  for _, slot in ipairs(SLOTS) do
    local id = ms[slot]
    if id then
      local o = Champ.target(f, id) -- (lot CHAMP : avant-poste, ou gisement voulu par la capitalisation)
      local st = o and ms.o[id]
      if not (o and st) then
        -- avant-poste perdu en cours de route : le projet du plan, s'il n'a rien retiré, est annulé (les matières rendues)
        local s2 = ms.o[id]
        release(ms, id)
        if s2 and s2.stage == "projet" and s2.pid then Build.cancel(f, s2.pid, "migration: avant-poste perdu") end
        -- lot CHAMP : journal (avant : silencieux ; une bande annulée ainsi paraissait « en attente » jusqu'à la fin du banc)
        if s2 and s2.pid then say(f, ms, string.format("avant-poste %d : avant-poste perdu, projet %d %s", id, s2.pid,
          s2.stage == "projet" and "annule" or "laisse au plan"), true) end
        if s2 then s2.stage, s2.pid = "veille", nil end
      else
        -- lot MIGRATION-DECLENCHE : le registre n'est purgé qu'APRÈS un retrait (étape « chantier ») ; en « projet » rien n'est retiré, et
        -- une paire tuée par une attaque pendant l'attente des matières (30 min au plus) doit être refaite (scarlet, avant-poste 6 : 8 paires
        -- avant la vague, 3 après, demande annulée sans rien migrer)
        if st.stage == "chantier" then purge_recon(f, o) end
        if st.stage == "projet" then step_project(f, surface, ms, o, st, tick, free, book)
        elseif st.stage == "chantier" then step_build(f, surface, ms, o, st, tick)
        else release(ms, id) end
        did = 1
      end
    end
  end
  Profiler.fstop("mig:creneaux")
  -- lot THERMIQUE : balayage des paires thermiques des gisements couverts (une fois par minute) ; lot THERMIQUE5 : aussi pendant une retenue
  Profiler.fstart("mig:balayage")
  if free and Th.pile_permits("balayer", hold) and sweep(f, surface, ms, free, book, tick) > 0 then did = 1 end
  Profiler.fstop("mig:balayage")
  Profiler.fstart("mig:avance")
  if ahead_step(f, surface, ms, free, book, tick, hold) > 0 then did = 1 end -- lot MEGA-FONDERIE (A2)
  Profiler.fstop("mig:avance")
  -- un créneau libre : trois au plus, un seul par minerai (lot THERMIQUE ; lot CHAMP : deux), la migration du treillis (sans cadre) seule
  local busy = { total = 0, ids = {}, key = "iron", stuck = {} } -- (9/11 : key = la plaque clé ; stuck = chantiers bloqués par leurs matières, Th.free_slot)
  for _, slot in ipairs(SLOTS) do
    local id = ms[slot]
    if id then
      local q = Champ.target(f, id)
      busy.total, busy.ids[id] = busy.total + 1, true
      if q then busy[q.kind] = (busy[q.kind] or 0) + 1 end
      local sq = ms.o[id]
      local pq = sq and sq.pid and f.build.projects[sq.pid]
      if q and sq and pq and Th.band_stuck(pq.state, pq.reason, tick - (sq.t0 or tick)) then busy.stuck[q.kind] = (busy.stuck[q.kind] or 0) + 1 end
      if not (ms.o[id] and ms.o[id].frame) then return did end
    end
  end
  if busy.total >= Th.CFG.slots then return did end
  local have = math.min(Stock.count(f, item), free and free[item] or 0)
  local obtainable = have > 0 or book:handcraftable(item)
  Profiler.fstart("mig:depart")
  local started = start_next(f, surface, ms, free or {}, obtainable, tick, busy, book, hold)
  Profiler.fstop("mig:depart")
  return (started or did == 1) and 1 or 0
end

--- Lot MIGRATION-DECLENCHE : numéro du projet du plan directeur de la partie en cours (étapes « projet » et « chantier »), ou nil.
--- Lecteur : script/ai3/automatisation.lua (Auto.think) en fait un projet du cerveau, qui FABRIQUE ses matières manquantes : la réserve
--- de la ligne neuve attendait 30 min sans que personne ne fabrique ses foreuses électriques, bras, tapis (journal du DC, 0.6.18,
--- scarlet : projets 4, 10, 21 et 23 « reserve:materiaux », 0 entité bâtie, annulés). Lecture seule.
function Mig.project(f)
  local ms = f and f.migration
  local st = ms and ms.cur and ms.o and ms.o[ms.cur]
  if st and (st.stage == "projet" or st.stage == "chantier") and st.pid then return st.pid end
  return nil
end

--- Lot CHAMP : projets des DEUX créneaux (étapes « projet » et « chantier ») : { { pid, item } } (item : la plaque que la bande
--- produit, lue par la porte de la pile). Lecteur : script/ai3/automatisation.lua (un but « fabriquer » par créneau ; avant, le second
--- créneau n'avait aucun but et attendait ses matières : 26 min contre 15 pour le premier, azure, graine 20261020). Lecture seule.
function Mig.projects(f)
  local ms = f and f.migration
  local out = {}
  for _, slot in ipairs(SLOTS) do
    local id = ms and ms[slot]
    local st = id and ms.o and ms.o[id]
    local o = id and Champ.target(f, id)
    if st and (st.stage == "projet" or st.stage == "chantier") and st.pid then
      out[#out + 1] = { pid = st.pid, item = st.frame and o and T.outposts[o.kind] and T.outposts[o.kind].product or nil }
    end
  end
  -- lot MEGA-FONDERIE (A2) : les bandes en avance aussi (le cerveau fabrique leurs matières manquantes)
  for _, oid in ipairs(sorted_keys(ms and ms.o)) do
    local st = ms.o[oid]
    local o = st.ahead and Champ.target(f, oid)
    for _, k in ipairs(sorted_keys(st.ahead)) do
      out[#out + 1] = { pid = st.ahead[k].pid, item = o and T.outposts[o.kind] and T.outposts[o.kind].product or nil }
    end
  end
  return out
end

--- Résumé pour les bancs et la fenêtre (lecture seule) : nombres seulement.
function Mig.summary(f)
  local ms = f.migration
  if not ms then return { requests = 0, retired = 0, lines = 0, outposts = 0 } end
  local n = #sorted_keys(ms.o)
  local credit = 0
  for _, oid in ipairs(sorted_keys(f.outposts or {})) do credit = credit + (f.outposts[oid].migr_credit or 0) end
  return { requests = ms.requests or 0, retired = ms.retired or 0, lines = ms.lines or 0, outposts = n, cur = ms.cur, credit = credit, swept = ms.swept or 0 }
end

return Mig
