--[[
  OUVRIERS d'équipe : agents riches (corps "character") qui exécutent les tâches du cerveau d'équipe.
  Ils marchent, minent à la main, fabriquent (file de fabrication du personnage), portent des objets,
  posent des bâtiments, ravitaillent foreuses, fours et tourelles, et se défendent avec leur arme.

  Une tâche devient un PROGRAMME d'étapes (sérialisable), exécuté par la machine "worker" :
     idle ──(tâche)──▶ step ◀──▶ walk / craft / mine ──(fin)──▶ idle
  Étapes : home (rentrer au QG et y déposer ce qu'on porte), take (prendre au QG), goto, act (action sur
  place : poser un avant-poste, ravitailler...), craft (fabrications successives), mine.
  Une tâche qui échoue rend ce qui a été pris (étape home finale) et rend la main au cerveau.
]]

local FSM = require("script.core.fsm")
local T = require("shared.team.config")
local Scale = require("shared.team.scale")
local Registry = require("script.companion.registry")
local Render = require("script.companion.render")
local Brain = require("script.companion.brain")
local Nav = require("script.agents.nav")
local State = require("script.faction.state")
local Ar = require("shared.team.arrivee") -- lot C4 PLATEAU 3 : tournée arrivée malgré un chemin refusé (règle pure)
local Acc = require("shared.team.acces_champ") -- lot NAV2 : point d'accès atteignable depuis l'extérieur du champ (règle pure)
local Co = require("shared.team.couloir") -- lot ÉTAGE 5 : le bâtiment qui ferme la dernière issue d'un accès (journal [FO-NAV-ACCES])
local Rc = require("shared.team.repli_chemin") -- lot CHARBON3 (B2) : essais de marche d'un PNJ (règle pure)
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local AmRt = require("script.ai3.amorce_rt") -- lot VIDEO-COUVERTURE (C3) : remise directe aux modules en réserve avant le coffre
local Mu = require("shared.team.munitions") -- lot MUNITIONS (revue M3) : prise bornée de la munition de base (Mu.split_take)
local Ra = require("shared.team.rearmement") -- lot REARMEMENT : emplacement des munitions complété au dépôt au QG (règle pure)
local Da = require("shared.team.danger_actif") -- lot CORR-RALLIEMENT (tenue) : coffre de dépôt hors de portée pendant « away » (Da.safe_chest)
local Tj = require("script.team.tourelle_journal") -- lot TOURELLE-JOURNAL : minage refusé sous une tourelle, journal [FO-TOURELLE-RETIREE]
local Outposts = require("script.faction.outposts")
local Sites = require("script.faction.sites")
local Board = require("script.team.board")
local Poles = require("script.team.poles") -- lot IA1-b : fin de tâche (O.settle), durées mesurées
local Tokens = require("script.team.tokens") -- lot IA1-b : jetons de travail globaux
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")
local Foot = require("shared.levels.footprint")
local Build = require("script.team.build") -- lot IA1-d : plan directeur, construction par fantômes, marche par les rues
local GardeCentrale = require("script.team.garde_centrale") -- lot CENTRALE-GARDE : tourelles armées autour de la centrale
local Locomotion = require("script.companion.locomotion")
local Re = require("shared.ai3.reaction") -- lot FUITE : tâches de défense exemptées du rappel
local Equip = require("script.team.equiper") -- lot LEVIERS : modules insérés dans les machines posées
local Harvest = require("script.team.harvest") -- lot KIT : entités qui donnent un objet miné à la main (minerai, arbres)
local Charge = require("shared.team.charge_four") -- lot FOURS : quantité emportée pour remplir les fours à la pile
local Front = require("script.team.front") -- lot DEFENSE-FRONT : tourelles posées là où les pièces tombent
local Ilots = require("script.team.ilots") -- lot ILOTS-MURS : tourelles posées dans l'emprise d'un îlot isolé
local DefStock = require("script.team.defense_stock") -- lot DEFENSE-STOCK : tourelles du coffre posées en groupes
local Recon = require("script.team.reconstruction") -- lot COUVERTURE : pièces détruites refaites (tâche « rebuild »)
local Mi = require("shared.team.main_inventaire") -- lot MAIN-INVENTAIRE : minage à la main, inventaire plein, minerai au sol
local Elec = require("script.team.electrique") -- lot CC-MAIN : pas de pioche sur ce que les foreuses électriques du coffre extraient
local Sorties = require("script.team.sorties") -- lot CHARBON-MAIN : la ressource qui dort dans les coffres des avant-postes bruts
local Src = require("script.team.sources") -- lot MINAGE-MAIN : ce qui dort dans les coffres de SORTIE (fonderies), tournée « fetch »
local CB = require("shared.team.craft_bg") -- lot CRAFT-PARALLELE : fabrication en arrière-plan (règles pures, bilan [FO-CRAFT])
local Fp = require("shared.team.fabrication_place") -- lot POSE-PERDUE : fabrication sur place, une recette à la fois, file vide entre deux
local Tp = require("shared.team.tri_proches") -- lot CERVEAU-CENTRAL (P1) : tri des tuiles de minage, positions lues une fois
local Sp = require("shared.team.spirale") -- EFFONDREMENT : filet de recul de la recrue gratuite (mort rapide d'une recrue gratuite)
local Events = require("script.core.events") -- EFFONDREMENT : parade du kit offert (mort d'un PNJ, corps rendu)
local Storage = require("script.core.storage")

local Worker = {}
Worker.BUILD_LOGS = 30 -- lot SCALE-COMPLET : lignes [FO-AVANT-POSTE] au plus par équipe (f.stats.build_logs)

-- Lot CRAFT-PARALLELE (retour du DC du 29/10) : la file de fabrication du personnage avance pendant que le PNJ fait autre chose.
-- Faux : l'ancien comportement (le PNJ attend au QG, état « craft », que sa file soit vide ; tests : mutant « bloquant »).
Worker.CRAFT_BG = true

Worker.DANGER_RADIUS = 40 -- lot IA1-b : rayon « nid ou ver » qui écarte un minage ou une garde de fond
Worker.SAFE_HOME = 24     -- lot IA-V2 : une perte à moins de 24 tuiles du QG ne rappelle personne (le QG est défendu)
-- Lot IA3-k : crochets des comportements visibles (script/ai3/comportement.lua, qui s'y branche) : sense (regard, peur,
-- réaction), leg (point de passage), gate (porte d'une tâche), nav_failed (point de passage injoignable). nil : rien.
Worker.hook = nil

local MACHINE = "worker"
local HOME_RADIUS = 6
local MAX_STEPS_PER_THINK = 6
local MINE_TIMEOUT = 90 * 60
-- Lot KIT : UN SEUL mineur par tuile de minerai. Relevé en moteur réel (graine 1618033988, kit égal, banc kit-diag) : les
-- ouvriers qui minent EN MÊME TEMPS la même tuile (la plus proche du QG, la même pour tous) ne rendent presque rien : 3
-- mineurs de charbon sur la tuile (324, 303), 0 charbon chacun en 91 s ; 2 mineurs de fer, un seul rapporte (44 sur 50).
-- Les factions n'ayant plus de stock de départ, tout l'amorçage (pierre des fours, charbon, fer) en dépendait : 10 minutes
-- sans fonte. Chaque tâche de minage réserve donc sa tuile (f.team.mine_claims, dans `global` via la faction) jusqu'à la
-- fin du minage, ou CLAIM_TTL ticks si l'ouvrier meurt ou renonce. File d'âges pour l'élagage (aucun `pairs`).
local CLAIM_TTL = MINE_TIMEOUT + 3600
Worker.CLAIM_TILES = true -- faux : l'ancien comportement (tests : mutant « sans réservation »)
Worker.CLAIM_SLACK = 8    -- tuiles : écart de distance au QG toléré entre la première tuile libre et la tuile réservée évitée

--- Lot KIT : l'entité à miner = celle qui est SUR la tuile visée (la plus proche de la cible), pas la première rendue par une
--- recherche de rayon 2,5 : le moteur la rend dans un ordre quelconque, et une tuile à 2 tuiles de la cible est hors de
--- portée de l'ouvrier arrêté à 1,5 tuile de l'autre côté (relevé en moteur réel, kit égal : les mineurs d'un même gisement
--- rendaient 44 ou 0 sur 50 en 91 s, au hasard de la tuile rendue ; le charbon d'Azur, graine 1618033988, 0 huit fois de suite).
-- Lot TOURELLE-JOURNAL : types qui ne bloquent pas le minage d'une tuile (ce ne sont pas des bâtiments ; le moteur ne les sélectionne pas à la
-- place de la ressource) : PNJ et unités qui passent, corps, objets au sol, fantômes, effets.
local MINE_IGNORE = { character = true, unit = true, corpse = true, ["character-corpse"] = true, ["item-entity"] = true, ["entity-ghost"] = true,
  ["tile-ghost"] = true, sticker = true, ["flying-text"] = true, ["highlight-box"] = true, ["smoke-with-trigger"] = true, projectile = true,
  stream = true, beam = true, explosion = true, ["particle-source"] = true, fire = true, ["speech-bubble"] = true }

--- Lot TOURELLE-JOURNAL : le bâtiment qui recouvre la tuile de la ressource `r` (nil : tuile libre). `free` : types qui ne comptent pas
--- (ressources, arbres récoltables : Harvest.free_types).
local function covering(surface, r, free)
  local rp = r.position
  for _, x in ipairs(surface.find_entities_filtered({ area = { { rp.x - 0.1, rp.y - 0.1 }, { rp.x + 0.1, rp.y + 0.1 } }, type = free,
    invert = true, limit = 8 })) do
    if x.valid and not MINE_IGNORE[x.type] then return x end
  end
  return nil
end

--- Rend la ressource à miner et, si des tuiles ont été écartées parce qu'un bâtiment les recouvre (lot TOURELLE-JOURNAL), le premier de ces
--- bâtiments (journal). `free` nil : aucune tuile écartée (ancien comportement). Sans tuile écartée, le choix est celui d'avant, à l'identique :
--- premier rendu par le moteur (hors Harvest.applies), sinon le plus proche de la cible (égalités : x puis y croissants, premier rendu).
local function mining_entity(surface, target, names, f, free)
  if not names or #names == 0 then return nil end -- rien à récolter (Harvest.names vide) : jamais de recherche sans nom
  local cover
  if not Harvest.applies(f) then
    for _, r in ipairs(surface.find_entities_filtered({ position = target, radius = 2.5, name = names, limit = 16 })) do
      local c = free and covering(surface, r, free)
      if not c then return r, cover end
      cover = cover or c
    end
    return nil, cover
  end
  -- La plus proche de la cible parmi `list` dont la tuile est libre (égalités : x puis y croissants, premier rendu).
  local function pick(list)
    local out = {} -- tuiles écartées (indices de `list`)
    for _ = 1, #list do
      local best, bd, bi
      for i, r in ipairs(list) do
        if not out[i] then
          local dx, dy = r.position.x - target.x, r.position.y - target.y
          local d = dx * dx + dy * dy
          if not best or d < bd or (d == bd and (r.position.x < best.position.x or (r.position.x == best.position.x and r.position.y < best.position.y))) then
            best, bd, bi = r, d, i
          end
        end
      end
      if not best then break end
      local c = free and covering(surface, best, free)
      if not c then return best end
      cover = cover or c
      out[bi] = true
    end
    return nil
  end
  local list = surface.find_entities_filtered({ position = target, radius = 0.9, name = names, limit = 8 })
  local best = #list > 0 and pick(list) or nil
  -- Rayon 2,5 : aucune ressource à 0,9 tuile (comme avant), ou (lot TOURELLE-JOURNAL) toutes recouvertes par un bâtiment.
  if not best then best = pick(surface.find_entities_filtered({ position = target, radius = 2.5, name = names, limit = 16 })) end
  return best, cover
end

local function claims_of(f)
  local t = f.team
  t.mine_claims = t.mine_claims or { by_tile = {}, order = {} }
  return t.mine_claims
end

local function tile_key(p) return math.floor(p.x) .. "," .. math.floor(p.y) end

--- La tuile est-elle réservée par un autre minage en cours ?
local function tile_claimed(f, p, tick)
  if not Worker.CLAIM_TILES or not Harvest.applies(f) then return false end
  local c = claims_of(f).by_tile[tile_key(p)]
  return c ~= nil and tick - c < CLAIM_TTL
end

local function claim_tile(f, p, tick)
  if not Harvest.applies(f) then return end
  local cl = claims_of(f)
  local key = tile_key(p)
  cl.by_tile[key] = tick
  cl.order[#cl.order + 1] = { key, tick }
  -- élagage : les plus anciennes réservations échues (ticks croissants dans la file)
  while #cl.order > 0 and tick - cl.order[1][2] >= CLAIM_TTL do
    local old = table.remove(cl.order, 1)
    if cl.by_tile[old[1]] == old[2] then cl.by_tile[old[1]] = nil end
  end
end

local function release_tile(f, p)
  if p and Harvest.applies(f) then claims_of(f).by_tile[tile_key(p)] = nil end
end
local CRAFT_TIMEOUT = 5 * 60 * 60
local DEFENSE_PERIOD = 60
local DEFENSE_RADIUS = 18

local function set(agent, state, tick) FSM.set(MACHINE, agent, state, tick) end

local function faction_of(agent)
  return agent.faction and State.faction(agent.faction) or nil
end

local function main_inv(agent) return agent.entity.get_main_inventory() end

-- Place de chacun au QG. Moteur réel (session 4) : tous les ouvriers rentraient au MÊME point ; empilés,
-- leurs départs suivants se chevauchaient et 150 demandes de chemin échouaient « départ bloqué » (tournées
-- perdues, plaques de fer bloquées dans les fours). Chaque ouvrier a sa case.
-- Lot IA1-a : 64 cases en TABLE CONSTANTE (Scale.HOME_SLOTS ; 16 cases calculées par cos/sin avant), et une
-- case ATTRIBUÉE à chaque PNJ (la première libre, rendue à sa disparition) au lieu de « id modulo 16 » : à
-- 30 PNJ, deux PNJ ne partagent plus une case (F27). Une case couverte par un bâtiment, un arbre ou de l'eau
-- est marquée « bloquée » (contrôle à la fondation, puis 2 cases par pensée d'équipe, à tour de rôle) : un
-- PNJ dont la case se bloque en reçoit une autre au prochain retour. Au-delà de 64 PNJ vivants (ou de cases
-- libres), les cases se partagent (id modulo 64) : réglage maximal 60.
local SLOTS = Scale.HOME_SLOTS

local function slot_tables(f)
  f.slot_owner = f.slot_owner or {}
  f.slot_bad = f.slot_bad or {}
  return f.slot_owner, f.slot_bad
end

local function release_slot(f, agent)
  local i = agent.slot
  if not i then return end
  local owner = slot_tables(f)
  if owner[i] == agent.id then owner[i] = nil end
  agent.slot = nil
end

local function home_slot(agent, f)
  local owner, bad = slot_tables(f)
  local i = agent.slot
  if not i or bad[i] or (owner[i] ~= nil and owner[i] ~= agent.id) then
    if i and owner[i] == agent.id then owner[i] = nil end
    i = Scale.free_slot(bad, owner)
    if i then owner[i] = agent.id end
    agent.slot = i
  end
  local o = SLOTS[i or ((agent.id - 1) % #SLOTS + 1)]
  return { x = f.home_spot.x + o[1], y = f.home_spot.y + o[2] }
end

--- Une case est-elle praticable ? Ni eau, ni entité de la couche des objets (bâtiments, arbres, rochers) sous
--- la boîte d'un corps (0,4 × 0,4, marge 0,1) ; les personnages ne comptent pas (couche des joueurs seule).
local function slot_ok(surface, p)
  local area = { { p.x - 0.5, p.y - 0.5 }, { p.x + 0.5, p.y + 0.5 } }
  if surface.count_tiles_filtered({ area = area, collision_mask = "water-tile", limit = 1 }) > 0 then return false end
  -- Correction IA1-a (mineur 9 de la vérification) : la recherche par zone rend aussi une entité qui TOUCHE
  -- seulement la case (F96, intervalles fermés) ; seul un chevauchement strict la bloque (Foot.overlap).
  local r = { x0 = area[1][1], y0 = area[1][2], x1 = area[2][1], y1 = area[2][2] }
  for _, e in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "object-layer" })) do
    local b = e.bounding_box
    if Foot.overlap(r, { x0 = b.left_top.x, y0 = b.left_top.y, x1 = b.right_bottom.x, y1 = b.right_bottom.y }) then
      return false
    end
  end
  return true
end

--- Revalide `count` cases du QG à tour de rôle (toutes si count = nil : fondation). O(count).
function Worker.check_slots(f, surface, count)
  local _, bad = slot_tables(f)
  local n = #SLOTS
  local k = count or n
  for _ = 1, k do
    local i = (f.slot_cursor or 0) % n + 1
    f.slot_cursor = i
    local o = SLOTS[i]
    bad[i] = not slot_ok(surface, { x = f.home_spot.x + o[1], y = f.home_spot.y + o[2] }) or nil
  end
end

local function dist2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

---------------------------------------------------------------------------------------------------
-- Transferts avec le stock (QG)
---------------------------------------------------------------------------------------------------
-- Lot STOCKAGE-VITAL : le dépôt d'un PNJ au QG est le seul appelant de Stock.insert soumis à la réserve des vitales (ce qui est refusé
-- reste en poche, rien n'est perdu).
local DEPOSIT_OPTS = { reserve = true }
-- Lot CORR-RALLIEMENT (tenue) : `chest` = un coffre du stock précis, hors de portée pendant « away » (sans la réserve des vitales ; note de
-- revue-0659 : un coffre sûr qui serait le QG la contournerait) ; sans `chest`, le stock comme avant.
local function deposit_inventory(f, inv, keep, chest, kits)
  local contents = inv.get_contents()
  local names = {}
  for name in pairs(contents) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local n = contents[name] - (keep and keep[name] or 0)
    if n > 0 then n = n - AmRt.deliver(f, inv, name, n, kits and kits[name]) end -- C3 : ce qu'un module en réserve attend lui est remis AVANT le coffre
    if n > 0 and chest then
      local put = chest.insert({ name = name, count = n })
      if put > 0 then inv.remove({ name = name, count = put }) f.team.delivered[name] = (f.team.delivered[name] or 0) + put end
      n = 0
    end
    -- Lot STOCK-QG : un brut ou un déclassé que le stock n'accueille plus (plafond de rapatriement) n'entre pas : il est retiré de la poche
    -- (jamais gardé en poche : un PNJ chargé de ce qu'on lui refuse est un PNJ perdu)
    if n > 0 and not chest and Stock.cap_room then
      local room = Stock.cap_room(f, name)
      if room and n > room then
        local gone = inv.remove({ name = name, count = n - room })
        if gone > 0 then
          n = n - gone
          Stock.note_cap_drop(f, name, gone)
        end
      end
    end
    if n > 0 then
      local moved = Stock.insert(f, name, n, DEPOSIT_OPTS)
      if moved > 0 then
        inv.remove({ name = name, count = moved })
        f.team.delivered[name] = (f.team.delivered[name] or 0) + moved
      end
    end
  end
end

--- Dépose au QG tout ce que l'ouvrier porte, sauf son arme et ses munitions de défense.
--- Moteur réel (session 4) : un personnage range lui-même les armes et munitions qu'il FABRIQUE dans ses
--- emplacements d'arme et de munitions (3 × 200 chargeurs) ; en ne vidant que l'inventaire principal, les
--- chargeurs et mitraillettes fabriqués pour l'équipe disparaissaient dans les poches des ouvriers (des
--- milliers de plaques de fer par partie, armée et défense bloquées).
local KEEP_GUN = { [T.worker_gun] = 1 }
local KEEP_AMMO = { [T.worker_ammo] = T.worker_ammo_keep }

-- Lot CRAFT-PARALLELE : ingrédients d'UNE fabrication de chaque recette ({ {objet, n}, ... }, fluides exclus), relus des
-- prototypes (contenu fixe pendant une partie ; cache du module, jamais dans `global`).
local INGREDIENTS = {}
local function ingredients_of(name)
  local v = INGREDIENTS[name]
  if v == nil then
    v = {}
    local rp = game.recipe_prototypes[name]
    for _, ing in ipairs(rp and rp.ingredients or {}) do
      if ing.type ~= "fluid" then v[#v + 1] = { ing.name, ing.amount } end
    end
    INGREDIENTS[name] = v
  end
  return v
end

--- Lot REARMEMENT : plancher de la défense pour le rechargement des armes (Ra.floor) : la réserve minimale de munitions, ou la part urgente
--- des tourelles de l'équipe (chargeurs qui leur manquent jusqu'à la cible ordinaire, Outposts.turret_groups) : les tourelles d'abord.
local function rearm_floor(f)
  local urgent = 0
  for _, g in ipairs(Outposts.turret_groups(f)) do urgent = urgent + (g.missing_base or 0) end
  -- QG en péril (f.team.s1.was, pensée d'avant) : la réserve sur la menace reçue (f.team.s1.reserve_said, Sq.ammo_reserve) entre au plancher
  local s1 = f.team and f.team.s1
  return Ra.floor(T.ammo_min, urgent, s1 ~= nil and s1.was == true, s1 and s1.reserve_said or 0)
end

-- EFFONDREMENT, parade du KIT OFFERT (décision du lead, 7/11 vers 19 h 05 ; règle pure : Sp.kit_take, shared/team/spirale.lua) :
-- le kit d'une recrue au kit OFFERT (effectif de départ, recrue gratuite sous l'effectif de départ) est retiré de son corps à sa mort,
-- au plus 1 pistolet et les chargeurs non payés, détruits (jamais rendus au coffre) ; la cargaison du corps reste.
-- Fait moteur (micro-banc kit-cadavre, 9ee2b12d, 7/11 19:20) : pendant on_entity_died, les inventaires armes et munitions du
-- personnage sont DÉJÀ vides (remove rend 0) ; on_post_entity_died rend l'unit_number et le character-corpse (corpses), dont
-- l'inventaire character_corpse se vide par script. D'où deux temps : la mort note le kit (units → dead), le corps rendu le retire.
--   units[unit] = { fid, ammo = chargeurs offerts, paid = chargeurs payés reçus au réarmement } (recrue au kit offert, vivante) ;
--   dead[unit]  = la même fiche, plus tick (mort notée, corps pas encore rendu ; oubliée après Sp.KIT_TTL) ;
--   taken[fid]  = { gun, ammo } retirés depuis le début (journal [FO-KIT-OFFERT]).
-- Une recrue SANS arme (unarmed) n'a pas de fiche : rien d'offert à retirer. Les PNJ recrutés avant cette version n'en ont pas non plus.
Storage.declare("kit_offert", function() return { units = {}, dead = {}, taken = {} } end)

local function kit_ns() return Storage.ns("kit_offert") end

--- Recrue au kit offert : fiche ouverte (appelé par Worker.recruit après la pose du kit).
local function kit_give(f, e)
  local ns = kit_ns()
  if ns and e and e.valid and e.unit_number then
    ns.units[e.unit_number] = { fid = f.id, ammo = T.worker_ammo_keep, paid = 0 }
  end
end

--- Chargeurs PAYÉS (pris au coffre) remis à un PNJ au kit offert : jamais retirés de son corps.
local function kit_paid(e, n)
  local ns = kit_ns()
  local k = ns and e and e.valid and e.unit_number and ns.units[e.unit_number]
  if k then k.paid = k.paid + n end
end

--- Lot REARMEMENT : au dépôt au QG, l'emplacement des munitions d'un PNJ ARMÉ (pistolet en main) est complété jusqu'à la dotation
--- (T.worker_ammo_keep) avec des chargeurs du coffre au-dessus du plancher (Ra.take). Avant : jamais (seul le recrutement le remplissait).
--- Compte : f.team.rearm = { n = rechargements, mags = chargeurs } (journal [FO-REARMEMENT], Worker.rearm_report).
local function rearm(agent, f)
  if not T.rearm_on then return end
  local e = agent.entity
  local guns = e.get_inventory(defines.inventory.character_guns)
  if not (guns and guns.get_item_count(T.worker_gun) > 0) then return end
  local ammo = e.get_inventory(defines.inventory.character_ammo)
  if not ammo then return end
  local slot = ammo.get_item_count(T.worker_ammo)
  if slot >= T.worker_ammo_keep then return end -- (emplacement plein : ni registre ni tourelles relus à chaque dépôt)
  -- Stock LIBRE du registre (Stock.free_view : ce que les tâches n'ont pas réservé, tourelles neuves et fabrications comprises), pas le compte
  -- brut du coffre : un rechargement ne fait jamais échouer une prise réservée.
  local free = Stock.free_view and Stock.free_view(f, game.tick) or nil
  local stock = free and (free[T.worker_ammo] or 0) or Stock.count(f, T.worker_ammo)
  local n = Ra.take(slot, T.worker_ammo_keep, stock, rearm_floor(f))
  if n <= 0 then return end
  local got = Stock.remove(f, T.worker_ammo, n)
  local put = got > 0 and ammo.insert({ name = T.worker_ammo, count = got }) or 0
  if put < got then Stock.insert(f, T.worker_ammo, got - put) end
  if put > 0 then
    f.team.rearm = f.team.rearm or { n = 0, mags = 0 }
    f.team.rearm.n, f.team.rearm.mags = f.team.rearm.n + 1, f.team.rearm.mags + put
    kit_paid(e, put) -- EFFONDREMENT : chargeurs payés, jamais retirés du corps d'une recrue au kit offert
  end
end

--- Lot KITS-VOLES : les pièces des KITS que le PNJ porte (travaux en arrière-plan, tâche en cours), par objet : { [objet] = { { pids, n } } },
--- dans l'ordre des travaux. Lues par la remise directe (amorce_rt) : la part d'un kit va aux projets pour lesquels il a été fabriqué (task.pids, P.want_kit).
local function kits_of(agent)
  local out, tasks, seen = {}, {}, {}
  for _, j in ipairs(agent.bg and agent.bg.jobs or {}) do tasks[#tasks + 1] = j.task seen[j.task] = true end
  if agent.task and not seen[agent.task] then tasks[#tasks + 1] = agent.task end
  for _, t in ipairs(tasks) do
    for _, w in ipairs(t.kit or {}) do
      out[w[1]] = out[w[1]] or {}
      out[w[1]][#out[w[1]] + 1] = { pids = t.pids, n = w[2] }
    end
  end
  return out
end

local function deposit_all(agent, f, chest)
  if not (f.hq and f.hq.valid) then return end
  local e = agent.entity
  deposit_inventory(f, main_inv(agent), nil, chest, kits_of(agent))
  local guns = e.get_inventory(defines.inventory.character_guns)
  if guns then deposit_inventory(f, guns, KEEP_GUN, chest) end
  local ammo = e.get_inventory(defines.inventory.character_ammo)
  if ammo then deposit_inventory(f, ammo, KEEP_AMMO, chest) end
  local armor = e.get_inventory(defines.inventory.character_armor)
  if armor then deposit_inventory(f, armor, nil, chest) end
  rearm(agent, f) -- lot REARMEMENT : après le dépôt (la dotation de 10 n'est jamais reprise : deposit et bg_absorb s'arrêtent à KEEP_AMMO)
end

--- Prend au QG la liste { {objet, n} }. Renvoie true si tout a été pris.
local function take(agent, f, list)
  local inv = main_inv(agent)
  local all = true
  for _, it in ipairs(list) do
    local want = it[2]
    local n = math.min(want, Stock.count(f, it[1]))
    if n > 0 then
      local got = Stock.remove(f, it[1], n)
      local put = inv.insert({ name = it[1], count = got })
      if put < got then Stock.insert(f, it[1], got - put) end
      if put < want then all = false end
    else
      all = false
    end
  end
  return all
end

---------------------------------------------------------------------------------------------------
-- Programmes
---------------------------------------------------------------------------------------------------
--- Point d'accès d'un avant-poste : là où l'ouvrier se tenait en le construisant (atteignable par
--- construction). Moteur réel (session 4) : viser le centre du gisement, désormais couvert de foreuses,
--- faisait échouer le pathfinder (« but occupé ») et les tournées d'entretien.
-- Lot NAV2 : types qui bougent (ne ferment pas un champ) ; recalcul au plus toutes les ACC_TTL ticks si le nombre de bâtiments ne change pas.
-- (porte : ouverte aux PNJ de sa force, le pathfinder la traverse)
local ACC_MOVING = { character = true, unit = true, car = true, ["spider-vehicle"] = true, gate = true }
local ACC_TTL = 7200
local ACC_LOGS = 12
--- Lot NAV2 : point d'accès ATTEIGNABLE (shared/team/acces_champ.lua). Banc nav2-marge : le point d'accès finit dans une poche fermée
--- par les paires jointives des agrandissements, le pathfinder n'y va pas (0 chemin sur 8, avec ou sans marge) ; le but de la marche
--- devient la tuile libre atteignable depuis l'extérieur la plus proche. Règle coupée (f.team.acces_off, bancs témoins) : 0.6.42.
local function access(o, f)
  local base = o.access or o.pos
  if not f or (f.team and f.team.acces_off) then return base end
  local own = {}
  for _, list in ipairs({ o.drill_list, o.sinks, o.turret_list }) do
    for _, e in ipairs(list or {}) do if e.valid then own[#own + 1] = e end end
  end
  if #own == 0 then return base end
  local tick = game.tick
  local c = o.acces_cache
  if c and c.n == #own and c.bx == base.x and c.by == base.y and tick - c.t < ACC_TTL then return { x = c.p.x, y = c.p.y } end
  local own_boxes = {}
  for i, e in ipairs(own) do
    local bb = e.bounding_box
    own_boxes[i] = { bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y }
  end
  local surface = own[1].surface
  -- Suite NAV2 (champs passés à l'électrique) : script/team/gisement.lua retire de o.drill_list les foreuses à combustion remplacées ; les
  -- foreuses électriques, tapis et poteaux du champ n'y sont pas. Le rectangle couvre aussi les bâtiments de l'ÉQUIPE à Acc.FIELD_RADIUS
  -- du centre de l'avant-poste (sinon son bord tombe dans le champ et la poche n'est pas vue).
  for _, e in ipairs(surface.find_entities_filtered({ position = o.pos, radius = Acc.FIELD_RADIUS, force = own[1].force, collision_mask = "player-layer" })) do
    if e.valid and not ACC_MOVING[e.type] then
      local bb = e.bounding_box
      own_boxes[#own_boxes + 1] = { bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y }
    end
  end
  local rect = Acc.rect(own_boxes, base, Acc.MARGIN)
  local area = { { rect[1], rect[2] }, { rect[3] + 1, rect[4] + 1 } }
  local boxes, ents = {}, {}
  for _, e in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "player-layer" })) do
    if e.valid and not ACC_MOVING[e.type] then
      local bb = e.bounding_box
      boxes[#boxes + 1] = { bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y }
      ents[#boxes] = e
    end
  end
  local tiles = {}
  for _, t in ipairs(surface.find_tiles_filtered({ area = area, collision_mask = "water-tile" })) do
    tiles[#tiles + 1] = { x = t.position.x, y = t.position.y }
  end
  local r = Acc.reach(boxes, tiles, base, rect)
  local was = c and c.moved
  o.acces_cache = { n = #own, t = tick, bx = base.x, by = base.y, p = { x = r.x, y = r.y }, moved = r.moved,
    side = math.max(rect[3] - rect[1], rect[4] - rect[2]) + 1 }
  if r.moved and f.stats then
    f.stats.acces_moved = (f.stats.acces_moved or 0) + 1
    if f.stats.acces_moved <= ACC_LOGS then
      -- Lot ÉTAGE 5 (accord du lead) : à la fermeture (ou quand le champ a changé), le bâtiment le plus récent, à 10 tuiles au plus de l'accès,
      -- dont le retrait seul rouvre l'accès (Co.closer) : celui qui ferme la DERNIÈRE issue. Un seul relevé de plus par ligne de journal.
      local closer = "-"
      if not was or not c or c.n ~= #own then
        local order = {}
        for i, e in ipairs(ents) do
          local bb = boxes[i]
          local cx, cy = (bb[1] + bb[3]) / 2, (bb[2] + bb[4]) / 2
          if (cx - base.x) ^ 2 + (cy - base.y) ^ 2 <= 100 then order[#order + 1] = i end
        end
        table.sort(order, function(i, j)
          local ui, uj = ents[i].unit_number or -1, ents[j].unit_number or -1
          if ui ~= uj then return ui > uj end
          return i < j
        end)
        local k = Co.closer(boxes, tiles, base, rect, order)
        local e = k and ents[k]
        closer = e and string.format("%s n. %s en (%.1f,%.1f) %s", e.name, tostring(e.unit_number), e.position.x, e.position.y,
          e.force.name == own[1].force.name and "de l'equipe" or e.force.name) or "aucun seul"
      end
      log(string.format("[FO-NAV-ACCES] %s : avant-poste %d %s : acces (%.1f,%.1f) ferme par le champ (%d batiment(s)), but deplace en (%.1f,%.1f) a %.1f tuile(s), %d tuile(s) atteignable(s), derniere issue fermee par %s (n. %d) a %.1f min",
        tostring(f.key), o.id or 0, tostring(o.kind), base.x, base.y, #own, r.x, r.y, math.sqrt((r.x - base.x) ^ 2 + (r.y - base.y) ^ 2), r.reached,
        closer, f.stats.acces_moved, tick / 3600))
    end
  end
  return { x = r.x, y = r.y }
end
--- Lot IA1-d : programme d'une tâche du plan directeur (script/team/build.lua). build : prise au stock du chantier,
--- point d'appui, ravivages ; clear : défrichage sur place ; fill : remplir un quai ; collect : vider un quai de sortie.
local function ia1d_program(task)
  local j = task.ia1d
  local at = { x = j.ax, y = j.ay }
  if j.mode == "build" then
    -- Lot CHANTIERS-FANTOMES : tournée de points d'appui (script/team/build.lua batch_tasks, shared/team/tournee_pose.lua) : une prise,
    -- puis marche et pose de point en point, un seul retour.
    if j.tour and #j.tour > 0 then
      local steps = { { "home" }, { "take_res", j.pid, task.items } }
      for i, a in ipairs(j.tour) do
        steps[#steps + 1] = { "goto", { x = a.ax, y = a.ay }, 1 }
        steps[#steps + 1] = { "ia1d", i }
      end
      steps[#steps + 1] = { "home" }
      return steps
    end
    return { { "home" }, { "take_res", j.pid, task.items }, { "goto", at, 1 }, { "ia1d" }, { "home" } }
  elseif j.mode == "fill" and j.depot then -- lot TV-ARCHI (V91) : quai d'un quartier servi par son dépôt (script/team/quartiers.lua, Qr.route)
    return { { "goto", j.depot, 2 }, { "take_depot", j.depot, task.depot_items }, { "goto", at, 1 }, { "ia1d" }, { "goto", j.depot, 2 },
      { "put_depot", j.depot, task.depot_items } }
  elseif j.mode == "collect" and j.depot then -- lot TV-ARCHI (V91) : produits demandés par le dépôt du quartier laissés au passage
    return { { "goto", at, 1 }, { "ia1d" }, { "goto", j.depot, 2 }, { "put_depot", j.depot, task.depot_items }, { "home" } }
  elseif j.mode == "fill" or j.mode == "amorce" then -- amorce : lot ENERGIE (2/11), charbon versé dans les chaudières à sec
    return { { "home" }, { "take", task.items, strict = true }, { "goto", at, 1 }, { "ia1d" }, { "home" } }
  elseif j.mode == "clear" or j.mode == "collect" then
    return { { "goto", at, 1 }, { "ia1d" }, { "home" } }
  end
  return nil
end

--- Construit le programme d'une tâche au moment où un ouvrier la prend. Renvoie steps ou nil (impossible).
function Worker.program(f, task, surface, tick)
  local k = task.kind
  if task.ia1d then return ia1d_program(task) end
  if k == "craft" then
    return { { "home" }, { "take", task.uses, strict = true }, { "craft", task.steps }, { "home" } }
  elseif k == "build" then
    local site = Sites.find(f, surface, tick, T.outposts[task.outpost_kind].resource)
    if not site then return nil end
    -- Lot IA1-b2 (défendre d'abord, votre équipe) : un site gardé par un nid ou un ver (apparu depuis la prospection)
    -- n'est pas tenté : le constructeur y mourait (essai 9, graine 314159265 : 4 constructeurs tués par des vers à
    -- 421-429 tuiles, un seul avant-poste en 60 min). Le site est écarté comme injoignable.
    if f.is_player and surface.count_entities_filtered({ position = site, radius = Worker.DANGER_RADIUS, force = "enemy",
      type = { "unit-spawner", "turret" }, limit = 1 }) > 0 then
      Sites.mark_unreachable(site, tick)
      return nil
    end
    -- Lot IA1-b2 (D-18, décision de l'orchestrateur), votre équipe : sans tourelle possible, aucun site au-delà de
    -- T.site_max_noturret tuiles ; et un site dont le CHEMIN (segment depuis le QG, un point tous les 32 tuiles) passe à
    -- moins de Worker.DANGER_RADIUS tuiles d'un nid ou d'un ver est écarté (graine 314159265 : sites à 585 tuiles derrière
    -- une ceinture de vers, 4 constructeurs tués vers 425 tuiles). Les vers des chunks pas encore générés ne se voient
    -- pas : la limite de distance couvre ce cas.
    if f.is_player then
      local force = game.forces[f.force]
      local rec = force and force.recipes and force.recipes["gun-turret"]
      local turret_ok = Stock.count(f, "gun-turret") > 0 or (rec ~= nil and rec.enabled)
      local d2 = dist2(site, f.hq_pos)
      local bad = (not turret_ok) and d2 > T.site_max_noturret * T.site_max_noturret
      if not bad then
        local d = math.sqrt(d2)
        local steps = math.floor(d / 32)
        for k = 1, steps do
          local q = { x = f.hq_pos.x + (site.x - f.hq_pos.x) * k / (steps + 1), y = f.hq_pos.y + (site.y - f.hq_pos.y) * k / (steps + 1) }
          if surface.count_entities_filtered({ position = q, radius = Worker.DANGER_RADIUS, force = "enemy",
            type = { "unit-spawner", "turret" }, limit = 1 }) > 0 then
            bad = true
            break
          end
        end
      end
      if bad then
        Sites.mark_unreachable(site, tick)
        f.stats.site_refused = (f.stats.site_refused or 0) + 1
        return nil
      end
      -- Prudence par zone : un site près d'une perte récente attend (rendu à la réserve).
      if Poles.near_loss(f, site, tick) then
        f.prospects = f.prospects or {}
        if Sites.room_for(f, site.resource) then table.insert(f.prospects, 1, site) end
        return nil
      end
    end
    Sites.claim(f, site)
    task.site = site
    return { { "home" }, { "take", task.items, strict = true }, { "goto", site, 5 }, { "act", "build" }, { "home" } }
  elseif k == "extend" then
    local o = f.outposts[task.outpost]
    if not o then return nil end
    if task.onsite then -- lot AUTO-FINANCEMENT (DC 9/11) : plaques prises dans les fours de l'avant-poste, paires fabriquées sur place, puis posées
      return { { "home" }, { "take", task.items, strict = true }, { "goto", access(o, f), 3 }, { "act", "autofinancement" },
        { "craft_now", task.onsite.crafts, task.onsite.ticks, "auto-financement" }, { "act", "extend" }, { "home" } }
    end
    return { { "home" }, { "take", task.items, strict = true }, { "goto", access(o, f), 3 }, { "act", "extend" }, { "home" } }
  elseif k == "rebuild" then
    return Recon.program(f, task)
  elseif k == "repair" then
    return Recon.repair_program(f, task)
  elseif k == "repare" then
    return Recon.repair_program(f, task) -- lot PD-REPARATION : autres bâtiments, même programme que « repair »
  elseif k == "garrison" then
    -- Lot IA1-b (fond du pôle Territoire) : garde d'un avant-poste ou du QG ; le PNJ tire sur ce qui approche
    -- (autodéfense, rayon DEFENSE_RADIUS) pendant task.wait ticks, puis rentre.
    local pos
    if task.post == "hq" then
      pos = f.home_spot
    else
      local o = f.outposts[task.post]
      pos = o and access(o, f)
    end
    if not pos then return nil end
    return { { "goto", pos, 6 }, { "wait", task.wait or 3600 }, { "home" } }
  elseif k == "salvage" then
    -- Lot IA2-b (F209) : démontage des réceptacles orphelins d'un avant-poste perdu.
    return { { "home" }, { "goto", task.pos, 4 }, { "act", "salvage" }, { "home" } }
  elseif k == "service" then
    local o = f.outposts[task.outpost]
    if not o then return nil end
    local need = Outposts.coal_needed(o, f.team and f.team.flux_fill) -- lot FLUX : remplissage selon le coffre
    local steps = { { "home" } }
    -- Lot CHARBON-MAIN : un avant-poste de combustible à sec dont les sorties ne couvrent pas le ravitaillement reçoit le complément du coffre
    -- (avant : jamais, il ne repartait plus une fois à sec avec des coffres vides ; règle coupée : le comportement de 0.6.41).
    local carry = need
    if o.kind == "coal" then carry = 0 end
    if Sorties.on(f) then carry = Sorties.carry_fuel(f, o, need) end
    if carry > 0 then steps[#steps + 1] = { "take", { { T.fuel, carry } } } end
    steps[#steps + 1] = { "goto", access(o, f), 3 }
    steps[#steps + 1] = { "act", "service" }
    steps[#steps + 1] = { "home" }
    return steps
  elseif k == "refill" then
    local pos = task.group == "hq" and f.home_spot or Outposts.group_pos(f, task.group)
    if not pos then return nil end
    local o = task.group ~= "hq" and f.outposts[tonumber(task.group:sub(2))]
    if o then pos = access(o, f) end
    local ammo = Outposts.ammo_name(f.tech, f) -- lot MUNITIONS : la meilleure munition fabricable de l'équipe (f.team.ammo_item)
    if Board.market(f) then
      -- Lot IA3-b : prise BORNÉE au manque réel du groupe (avant : 200 + 200 chargeurs, `ammo` valant déjà
      -- « firearm-magazine », soit jusqu'à 400 chargeurs sortis du coffre pendant la tournée : la matière promise aux
      -- tâches strictes, tourelles comprises, n'y était plus). Réservée au libre ensuite (Board.reserve_soft).
      local _, by_key = Outposts.turret_groups(f)
      local g = by_key[task.group]
      local need = 0
      local target = Outposts.ammo_target(f) -- lot MUNITIONS : au plein de la cible de l'équipe
      local best = Outposts.rank_of(ammo)
      for _, t in ipairs(g and g.list or {}) do
        local inv = t.valid and t.get_inventory(defines.inventory.turret_ammo)
        local have = inv and inv.get_item_count() or 0
        local r = t.valid and Outposts.ammo_rank(t) or 0
        if r > 0 and r < best then need = need + target -- (lot MUNITIONS : tourelle à ÉCHANGER contre la meilleure munition : la cible entière)
        elseif have < target then need = need + target - have end
      end
      if need <= 0 then return nil end
      -- Lot MUNITIONS : la tournée porte au plus ce que le planificateur lui a donné (task.count : la part urgente avant les recrues, le
      -- surplus de la cible riche après elles) ; la munition choisie d'abord, la munition de base en complément (prise non stricte).
      if type(task.count) == "number" and task.count > 0 and task.count < need then need = task.count end
      -- (revue M3 : la munition de base seulement pour ce que le coffre n'a pas de la choisie ; avant : need de chacune)
      local take_c, take_b = Mu.split_take(need, Stock.count(f, ammo), ammo == T.turret_ammo)
      local list = {}
      if take_c > 0 then list[#list + 1] = { ammo, take_c } end
      if take_b > 0 then list[#list + 1] = { T.turret_ammo, take_b } end
      if #list == 0 then return nil end
      return { { "home" }, { "take", list }, { "goto", pos, 6 }, { "act", "refill" }, { "home" } }
    end
    return { { "home" }, { "take", { { ammo, 200 }, { "firearm-magazine", 200 } } }, { "goto", pos, 6 }, { "act", "refill" }, { "home" } }
  elseif k == "fortify" then
    -- Lot IA1-b2 : tourelles du QG (défendre d'abord), posées sans quitter le QG.
    if task.outpost == "hq" then return { { "home" }, { "take", task.items, strict = true }, { "act", "fortify" }, { "home" } } end
    -- Lot CENTRALE-GARDE : la centrale finie ; on va jusqu'à son centre (lot ILOTS-MURS : l'îlot aussi)
    if task.outpost == "plant" or task.outpost == "ilot" then
      if not task.pos then return nil end
      return { { "home" }, { "take", task.items, strict = true }, { "goto", task.pos, 5 }, { "act", "fortify" }, { "home" } }
    end
    -- Lot DEFENSE-FRONT : la cellule du front ; on va jusqu'à son centre
    if task.outpost == "front" or task.outpost == "reserve" then -- (lot DEFENSE-STOCK : le lieu de la réserve, même trajet)
      if not task.pos then return nil end
      return { { "home" }, { "take", task.items, strict = true }, { "goto", task.pos, 5 }, { "act", "fortify" }, { "home" } }
    end
    local o = f.outposts[task.outpost]
    if not o then return nil end
    return { { "home" }, { "take", task.items, strict = true }, { "goto", access(o, f), 3 }, { "act", "fortify" }, { "home" } }
  elseif k == "smelters" then
    return { { "home" }, { "take", task.items, strict = true }, { "act", "smelters" }, { "home" } }
  elseif k == "smelt" then
    local list = {}
    local products = {}
    for p in pairs(task.smelt or {}) do products[#products + 1] = p end
    table.sort(products)
    if Outposts.four_rule(f) then
      -- Lot FOURS (remarque 12 du DC) : le porteur prend de quoi remplir chaque four à charger jusqu'à sa pile
      -- (shared/team/charge_four.lua : place, part du stock, borne par la demande pour une entrée qui est elle-même un produit).
      local by_item = {}
      -- Lot BRIQUES : un produit sans four reçoit le four repris à une autre entrée (Outposts.smelt_release) ; le porteur emporte aussi son entrée.
      local rel = Outposts.smelt_release(f, task.smelt, function(item) return Stock.count(f, item) end)
      for _, l in ipairs(Outposts.smelt_loads(f, products, nil, rel)) do
        local g = by_item[l.item]
        if not g then
          g = { room = 0, loads = 0, ratio = l.ratio }
          by_item[l.item] = g
        end
        g.room = g.room + l.room
        g.loads = g.loads + 1
      end
      for _, item in ipairs(State.sorted_keys(by_item)) do
        local g = by_item[item]
        local demand
        if T.smelter_inputs[item] then
          demand = 0
          for _, p in ipairs(products) do
            local inp = T.smelter_inputs[p]
            if inp and inp[1] == item then demand = demand + (task.smelt[p] or 0) end
          end
        end
        local n = Charge.carry({ room = g.room, stock = Stock.count(f, item), ratio = g.ratio, loads = g.loads, demand_crafts = demand })
        if n > 0 then list[#list + 1] = { item, n } end
      end
    else
      for _, p in ipairs(products) do
        local input = T.smelter_inputs[p]
        -- Lot SCALE : la fournée suit le nombre de fours (données nommées et justifiées de shared/team/config.lua :
        -- T.smelt_per_furnace entrées par four, au moins T.smelt_trip_min) : une fonderie agrandie (shared/ai3/bras.lua,
        -- Br.smelters) n'est pas limitée par une tournée de 20 minerais.
        local per_trip = math.max(T.smelt_trip_min, T.smelt_per_furnace * #Outposts.smelters(f))
        if input then list[#list + 1] = { input[1], math.min(input[2] * per_trip, input[2] * task.smelt[p]) } end
      end
    end
    if Outposts.four_rule(f) then
      -- Lot FOURS : combustible pour les fours tombés au tiers de T.smelter_fuel_to (part du stock, plancher de 10 par four).
      local fl = Outposts.smelter_fuel_loads(f)
      local room = 0
      for _, l in ipairs(fl) do room = room + l.room end
      local n = Charge.carry({ room = room, stock = Stock.count(f, T.fuel), ratio = 1, loads = #fl })
      if n > 0 then list[#list + 1] = { T.fuel, n } end
    else
      list[#list + 1] = { T.fuel, Outposts.coal_needed_for(Outposts.smelters(f)) }
    end
    return { { "home" }, { "take", list }, { "act", "smelt" }, { "home" } }
  elseif k == "fetch" then
    return Src.program(f, task) -- lot MINAGE-MAIN : vider une sortie qui dort (plaques d'une fonderie), puis le dépôt au QG
  elseif k == "equiper" then
    return Equip.program(f, task) -- lot LEVIERS
  elseif k == "mine" then
    -- Lot MAIN-INVENTAIRE : pas de minage à la main quand les coffres (QG + annexes) couvrent déjà la tâche, jamais de combustible
    -- à la main quand un coffre en a (retour du DC du 31/10 : minage de charbon seul de la 3e à la 7e heure, coffres garnis).
    do
      local ok, why = Mi.hand_verdict({ stock = Stock.count(f, task.resource), count = task.count, fuel = task.resource == T.fuel,
        survie = task.survie, crisis = task.crisis, short = task.short }) -- PURGE-MINE : Elec.hand_blocked supprimé (la pioche sort de la file à l'ère électrique)
      if not ok then
        f.stats.main_refus = f.stats.main_refus or {}
        local last = f.stats.main_refus[task.resource]
        if not last or tick - last >= 3600 then
          f.stats.main_refus[task.resource] = tick
          log(string.format("[FO-MAIN] %s : minage a la main de '%s' REFUSE (%s) : %d en coffre pour %d demande(s), tache %s, a %.1f min",
            f.key or "?", tostring(task.resource), why, Stock.count(f, task.resource), task.count or 0, tostring(task.key), tick / 3600))
        end
        task.fail = task.fail or ("main:" .. why) -- (« main:stock » comme avant ; « main:electrique » : lot CC-MAIN)
        return nil
      end
      -- Lot CHARBON-MAIN (retour du DC du 3/11 : « des milliers de charbons réunis dans les coffres [des foreuses] et ils minent à la main
      -- juste à côté ») : jamais à la main ce qui attend dans les coffres de sortie d'un avant-poste brut sûr ; sa tournée est une urgence
      -- au planificateur (shared/team/sorties_main.lua, Sm.fetch_prio). Survie comprise ; seule une crise injectée par un banc passe.
      local ok2, why2, dormant, tours = Sorties.hand_ok(f, task.resource, tick, task.crisis)
      if not ok2 then
        f.stats.main_sorties = (f.stats.main_sorties or 0) + 1
        f.stats.main_refus = f.stats.main_refus or {}
        local key = "sorties:" .. tostring(task.resource)
        local last = f.stats.main_refus[key]
        if not last or tick - last >= 3600 then
          f.stats.main_refus[key] = tick
          log(string.format("[FO-MAIN] %s : minage a la main de '%s' REFUSE (%s) : %d dans les coffres de sortie des avant-postes, tache %s, a %.1f min (refus %d) ; tournees {%s}",
            f.key or "?", tostring(task.resource), why2, dormant, tostring(task.key), tick / 3600, f.stats.main_sorties, tours or ""))
        end
        task.fail = task.fail or "main:sorties"
        return nil
      end
      -- Lot MINAGE-MAIN (retour du DC du 8/11, 0.6.65 : « ils minent à la main du fer et du cuivre alors qu'ils ont des milliers de plaques dans
      -- les coffres de la fonderie ») : jamais à la main ce qu'une sortie de la force tient ou produit (registre : shared/team/sources.lua) ;
      -- la tournée « fetch » va le chercher. Survie comprise ; seule une crise injectée par un banc passe.
      local ok3, why3, text3 = Src.hand_ok(f, task.resource, tick, task.crisis, nil, task.survie)
      if not ok3 then
        f.stats.main_sources = (f.stats.main_sources or 0) + 1
        f.stats.main_refus = f.stats.main_refus or {}
        local key3 = "sources:" .. tostring(task.resource)
        local last3 = f.stats.main_refus[key3]
        if not last3 or tick - last3 >= 3600 then
          f.stats.main_refus[key3] = tick
          log(string.format("[FO-MAIN] %s : minage a la main de '%s' REFUSE (sources: %s) : %s, tache %s, a %.1f min (refus %d)",
            f.key or "?", tostring(task.resource), tostring(why3), text3, tostring(task.key), tick / 3600, f.stats.main_sources))
        end
        task.fail = task.fail or "main:sources"
        return nil
      end
    end
    -- Lot IA1-b : 256 tuiles au lieu de 64 (essai 2 du banc ia1-poles : les 64 tuiles les plus proches d'un gisement
    -- exploité sont toutes sous des foreuses ; le minage échouait sans raison écrite). Au plus 40 tuiles contrôlées.
    -- Lot IA1-b2 (R-QCM-25c (c)) : task.radius (minage de fond de votre équipe : près du coffre, T.near_mine).
    local names = Harvest.names_for(f, task.resource, task.trees)
    if #names == 0 then return nil end -- lot KIT : un objet sans entité récoltable ne se mine pas à la main
    local res = surface.find_entities_filtered({ position = f.hq_pos, radius = task.radius or 96, name = names, limit = 256 }) -- lot KIT : minerai = l'entité du même nom, bois = arbres
    -- Lot CERVEAU-CENTRAL (P1) : même ordre (distance au QG, puis x, puis y), positions lues une fois (shared/team/tri_proches.lua).
    Tp.sort(res, f.hq_pos, dist2)
    -- Tuile LIBRE : sous un four ou une foreuse (avant-poste détruit, restes), l'ouvrier sélectionnait le
    -- bâtiment et ne minait rien (moteur réel, E16 it. 11 : 4 minerais livrés en 50 min).
    local best, first_free, free_d
    local stride = math.max(1, math.floor(#res / 40))
    for i = 1, #res, stride do
      local r = res[i]
      local p = r.position
      local busy = surface.count_entities_filtered({
        area = { { p.x - 0.5, p.y - 0.5 }, { p.x + 0.5, p.y + 0.5 } }, type = Harvest.free_types(task.resource, f, task.trees), invert = true, limit = 1,
      })
      -- Lot IA1-b : un minage de FOND ne va pas miner à moins de 40 tuiles d'un nid ou d'un ver (morts des PNJ).
      -- Lot IA-V2 : les minages du cerveau par besoins et du manque de plaques aussi (task.prudent) : moteur réel,
      -- ia3c-default graine 20261020, Ambre, 28 PNJ tués en minage à la main près d'un nid à 35 tuiles de son QG.
      -- Lot KIT : une autre ressource sur la même tuile (cristal sur du charbon) : le moteur sélectionne l'autre, rien ne vient
      if busy == 0 and Harvest.foreign_resource(surface, p, task.resource, f) then busy = 1 end
      -- Lot SURVIE-PENURIE : un minage du mode survie (task.danger_radius, shared/team/survie.lua) tolère un nid ou un ver plus proche
      -- (30 tuiles au lieu de 40) : « hors du danger immédiat », sans quoi un QG encerclé de nids ne trouve plus aucune tuile.
      if busy == 0 and (task.fond or task.prudent) and surface.count_entities_filtered({ position = p, radius = task.danger_radius or Worker.DANGER_RADIUS,
        force = "enemy", type = { "unit-spawner", "turret" }, limit = 1 }) > 0 then
        busy = 1
      end
      -- Lot IA1-b2 : prudence par zone (votre équipe) : pas de minage de fond près d'une perte récente.
      -- Lot IA-V2 : les minages du cerveau par besoins aussi (task.prudent) : moteur réel, ia1b2-guide graine 1618033988,
      -- 7e3e4ad : 8 PNJ tués en minage à la main à 51-57 tuiles du QG en 40 min (0.4.30 : 1), recrues de survie payées
      -- en fer, fer à 0 à 40 min, munitions épuisées, coffre perdu à 45 min.
      if busy == 0 and (task.fond or task.prudent) and f.is_player and Poles.near_loss(f, p, tick) then busy = 1 end
      -- Lot KIT : la première tuile libre ET non réservée ; à défaut, la première libre (comme avant le lot)
      if busy == 0 then
        if not first_free then
          first_free = r
          free_d = math.sqrt(dist2(p, f.hq_pos))
        end
        if not tile_claimed(f, p, tick) then best = r break end
        -- Lot KIT : on évite les tuiles réservées en restant près de la première tuile libre (au plus CLAIM_SLACK tuiles plus
        -- loin du QG) : sans cette borne, beaucoup de mineurs simultanés (minage de fond de votre équipe) s'éloignaient jusqu'au
        -- bout de la liste, chez les nids (moteur réel : pnj-reduit et verif-guide graine 1618033988, avant-postes du joueur).
        if math.sqrt(dist2(p, f.hq_pos)) > free_d + Worker.CLAIM_SLACK then break end
      end
    end
    best = best or first_free
    if best then claim_tile(f, best.position, tick) end
    -- Lot IA3-f (constat du DC, 25/10 vers 18 h 45) : rien à portée du coffre : gisement CONNU et sûr plus loin (carte de
    -- connaissance, crochet posé par script/ai3/exploration.lua ; sinon il demande une exploration). Pas pour le fond.
    -- Lot STOCKAGE-VITAL : récolte d'un coffre urgent (shared/team/fond.lua, F.annex_urgent) : le coffre est fabriqué SUR PLACE avec la
    -- matière récoltée, avant le retour (un stock plein refuserait le bois au dépôt ; le coffre, lui, est posé en annexe au dépôt).
    local function mine_steps()
      local steps = { { "home" }, { "goto", task.target, 1.5 }, { "mine", task.resource, task.count } }
      local tc = task.then_craft
      if tc then steps[#steps + 1] = { "craft_now", tc.crafts, tc.ticks, tc.item } end
      steps[#steps + 1] = { "home" }
      return steps
    end
    local far = not best and not task.fond and Worker.far_mine and Worker.far_mine(f, task, surface, tick)
    if far then
      task.target = far
      return mine_steps()
    end
    if not best then
      -- Lot KIT (diagnostic) : un minage à la main sans tuile libre ni sûre à portée (au plus une ligne par ressource et par
      -- minute) ; sans stock de départ, une faction qui ne trouve pas de charbon ne fond rien.
      f.stats.mine_none = f.stats.mine_none or {}
      local last = f.stats.mine_none[task.resource]
      if not last or tick - last >= 3600 then
        f.stats.mine_none[task.resource] = tick
        log(string.format("[FO-TEAM] %s : minage a la main de '%s' sans tuile libre ni sure (rayon %d, %d entite(s) trouvee(s)) a %.1f min (tache %s : fond %s, prudent %s, sure %s)",
          f.key or "?", tostring(task.resource), task.radius or 96, #res, tick / 3600, tostring(task.key), tostring(task.fond == true), tostring(task.prudent == true), tostring(task.safe == true)))
      end
      return nil
    end
    task.target = { x = best.position.x, y = best.position.y }
    return mine_steps()
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Actions sur place
---------------------------------------------------------------------------------------------------
local ACTS = {}

--- Lot MAIN-INVENTAIRE : ramasse les piles de `item` tombées au sol autour du mineur (le moteur lâche le minerai quand
--- l'inventaire est plein, ou quand le mineur s'éloigne). Rend le nombre ramassé.
local function pick_ground(agent, item)
  local e = agent.entity
  local inv = main_inv(agent)
  local ents = e.surface.find_entities_filtered({ name = "item-on-ground", position = e.position, radius = Mi.PICK_RADIUS,
    limit = Mi.PICK_LIMIT })
  local stacks = {}
  for i, ent in ipairs(ents) do
    local st = ent.valid and ent.stack or nil
    if st and st.valid_for_read and st.name == item then
      stacks[#stacks + 1] = { i = i, n = st.count, d2 = dist2(ent.position, e.position), x = ent.position.x, y = ent.position.y }
    end
  end
  if #stacks == 0 then return 0 end
  local picked = 0
  for _, i in ipairs((Mi.pick_plan(stacks, inv.get_insertable_count(item)))) do
    local ent = ents[i]
    if ent.valid then
      local n = ent.stack.count
      local put = inv.insert({ name = item, count = n })
      if put == n then
        ent.destroy()
        picked = picked + n
      elseif put > 0 then
        inv.remove({ name = item, count = put })
      end
    end
  end
  return picked
end

ACTS.build = function(agent, f, task, surface, tick)
  local o = Outposts.build(f, surface, task.outpost_kind, task.site, main_inv(agent))
  if not o then
    Sites.release(task.site)
    Sites.mark_unreachable(task.site, tick)
    task.site_used = true
    f.stats.build_fail = (f.stats.build_fail or 0) + 1
    return false
  end
  local p = agent.entity.position
  o.access = { x = p.x, y = p.y }
  Build.couloirs_reset(f) -- lot ÉTAGE 5 : le couloir de ce nouvel accès vaut dès ce tick
  task.site_used = true
  f.stats.built = (f.stats.built or 0) + 1
  -- Lot SCALE-COMPLET : origine et distance de chaque NOUVEL avant-poste (partie du DC, 0.6.18 : l'avant-poste de charbon n° 5
  -- d'Écarlate, à 157 tuiles, n'était lisible que par [FO-TOUR-POSE]) : qui l'a demandé (fond ou projet du cerveau), et le plus
  -- proche avant-poste du même type qui avait encore des places. Worker.BUILD_LOGS lignes au plus par équipe.
  if (f.stats.build_logs or 0) < Worker.BUILD_LOGS then
    f.stats.build_logs = (f.stats.build_logs or 0) + 1
    local d_new = math.sqrt((o.pos.x - f.hq_pos.x) ^ 2 + (o.pos.y - f.hq_pos.y) ^ 2)
    local d_room, n_room = nil, 0
    for _, oid in ipairs(State.sorted_keys(f.outposts)) do
      local q = f.outposts[oid]
      if q ~= o and q.kind == o.kind and not q.full and not q.migr and (q.drills or 0) < T.max_drills(q.kind) then
        n_room = n_room + 1
        local d = math.sqrt((q.pos.x - f.hq_pos.x) ^ 2 + (q.pos.y - f.hq_pos.y) ^ 2)
        if d_room == nil or d < d_room then d_room = d end
      end
    end
    log(string.format("[FO-AVANT-POSTE] %s : avant-poste %d %s bati a %d tuiles du QG a %.1f min, demande par %s ; avant-postes %s avec des places : %d%s",
      f.key or "?", o.id, o.kind, math.floor(d_new), tick / 3600, task.fond and "le fond" or (task.why and ("le projet " .. tostring(task.why)) or ("la tache " .. tostring(task.key))),
      o.kind, n_room, d_room and string.format(" (le plus proche a %d tuiles)", math.floor(d_room)) or ""))
  end
  -- Lot IA1-b2 (défendre d'abord) : les tourelles portées avec la construction sont posées sur place, à la même visite.
  local inv = main_inv(agent)
  local nt = inv.get_item_count("gun-turret")
  if nt > 0 then
    local put = Outposts.fortify(f, surface, o, nt, inv)
    f.stats.defend_built = (f.stats.defend_built or 0) + put
  end
  return true
end

ACTS.extend = function(agent, f, task, surface)
  local o = f.outposts[task.outpost]
  if not o then return false end
  local n = Outposts.extend(f, surface, o, main_inv(agent))
  f.stats.extended = (f.stats.extended or 0) + n
  if task.onsite then
    log(string.format("[FO-AUTOFINANCEMENT] %s : avant-poste %s : %d paire(s) posee(s) avec %d %s pris(es) sur place par le PNJ %s a %.1f min",
      f.key or "player", tostring(task.outpost), n, task.onsite.taken or 0, tostring(task.onsite.item), tostring(agent.id), game.tick / 3600))
  end
  return true
end

--- Lot AUTO-FINANCEMENT : les plaques du kit sont prises dans les sorties de l'avant-poste lui-même (Outposts.take_output) ; rien de pris : la
--- tâche échoue avec ce motif (la sortie a été vidée entre la pensée et l'arrivée).
ACTS.autofinancement = function(agent, f, task, surface)
  local o = f.outposts[task.outpost]
  if not (o and task.onsite) then return false end
  local taken = Outposts.take_output(o, main_inv(agent), task.onsite.item, task.onsite.n)
  task.onsite.taken = taken
  f.stats.autofinance = (f.stats.autofinance or 0) + taken
  if taken <= 0 then
    log(string.format("[FO-AUTOFINANCEMENT] %s : avant-poste %s : aucune %s dans les sorties a l'arrivee du PNJ %s (voulu %d) a %.1f min",
      f.key or "player", tostring(task.outpost), tostring(task.onsite.item), tostring(agent.id), task.onsite.n or 0, game.tick / 3600))
    return false
  end
  return true
end

ACTS.service = function(agent, f, task, surface, tick)
  local o = f.outposts[task.outpost]
  if not o then return false end
  local n = Outposts.service(o, main_inv(agent), tick, f.team and f.team.flux_fill, Stock.skip_fn and Stock.skip_fn(f),
    { key = f.key or "player", stock = function() return Stock.count(f, T.fuel) end }) -- lot BLOCAGE-COMBUSTIBLE : journal [FO-RAVITAILLEMENT]
  f.stats.serviced = (f.stats.serviced or 0) + 1
  f.team.collected = (f.team.collected or 0) + n
  return true
end

ACTS.salvage = function(agent, f, task)
  local n = Outposts.salvage(f, task.orphan, main_inv(agent))
  return n > 0
end

ACTS.refill = function(agent, f, task)
  local n = Outposts.refill_group(f, task.group, main_inv(agent))
  f.stats.refilled = (f.stats.refilled or 0) + n
  return n > 0
end

ACTS.fortify = function(agent, f, task, surface)
  if task.outpost == "reserve" then -- lot DEFENSE-STOCK : tourelles du coffre en groupe
    local n = DefStock.place(f, surface, task, main_inv(agent))
    f.stats.reserve_fortified = (f.stats.reserve_fortified or 0) + n
    return n > 0
  end
  if task.outpost == "front" then
    local n = Front.place(f, surface, task, main_inv(agent))
    if task.defend then f.stats.defend_fortified = (f.stats.defend_fortified or 0) + n end
    return n > 0
  end
  if task.outpost == "plant" then
    local n = GardeCentrale.place(f, surface, task, main_inv(agent))
    if task.defend then f.stats.defend_fortified = (f.stats.defend_fortified or 0) + n end
    return n > 0
  end
  if task.outpost == "ilot" then -- lot ILOTS-MURS
    local n = Ilots.place(f, surface, task, main_inv(agent))
    if task.defend then f.stats.defend_fortified = (f.stats.defend_fortified or 0) + n end
    return n > 0
  end
  -- Lot IA1-b2 : « hq » = autour du QG (tourelles du groupe « hq », Outposts.turret_groups).
  local o = task.outpost == "hq" and { pos = f.hq_pos } or f.outposts[task.outpost]
  if not o then return false end
  local n = Outposts.fortify(f, surface, o, task.items[1][2], main_inv(agent))
  if task.defend then f.stats.defend_fortified = (f.stats.defend_fortified or 0) + n end
  return n > 0
end

ACTS.smelters = function(agent, f, task, surface)
  local n = Outposts.place_smelters(f, surface, task.count, main_inv(agent))
  return n > 0
end

ACTS.equiper = Equip.act -- lot LEVIERS
ACTS.fetch = Src.act -- lot MINAGE-MAIN

ACTS.rebuild = function(agent, f, task, surface) return Recon.act(agent, f, task, surface) end -- lot COUVERTURE
ACTS.repair = function(agent, f, task, surface) return Recon.repair_act(agent, f, task, surface) end -- lot RECONSTRUIRE
ACTS.repare = ACTS.repair -- lot PD-REPARATION : même acte (santé remise au maximum, gratuit)

ACTS.smelt = function(agent, f, task)
  Outposts.service_smelters(f, main_inv(agent), task.smelt)
  return true
end

---------------------------------------------------------------------------------------------------
-- Exécution des étapes
---------------------------------------------------------------------------------------------------
--- Un chantier abandonné avant la pose (stock pris entre-temps...) rend son site à la réserve.
local function return_site(f, task)
  if task and task.site and not task.site_used then
    Sites.release(task.site)
    f.prospects = f.prospects or {}
    -- Lot IA2-c : dans les bornes de la réserve (Sites.room_for) : pendant le chantier, la prospection a pu la
    -- remplir de nouveau (moteur simulé, tests/valeur_test.lua : 4 sites de charbon, 13 en tout).
    if Sites.room_for(f, task.site.resource) then table.insert(f.prospects, 1, task.site) end
    task.site_used = true
  end
end

--- Lot CHANTIERS-FANTOMES (12/11) : bilan des tâches de pose du plan (kind « ghost ») en moteur réel. Par tâche : temps par étape
--- (départ au QG, prise à la réserve, marche, pose, retour, retour après échec), objets du lot, objets portés, pièces posées, pensées
--- bloquées par les jetons. Journal [FO-GHOST] (30 tâches par équipe) et [FO-GHOST-BILAN] (toutes les 5 min de jeu, cumul par équipe).
local GH_LOGS = 30
local GH_KEYS = { "t_depart", "t_prise", "t_marche", "t_pose", "t_retour", "t_echec" }
local function gh_phase(agent, tick)
  local g = agent.task and agent.task.gt
  if not g then return end
  local failed = agent.failed and true or false
  if g.pc == agent.pc and g.failed == failed then return end
  if g.lab then g[g.lab] = (g[g.lab] or 0) + (tick - g.pt) end
  g.pc, g.failed, g.pt = agent.pc, failed, tick
  local s = agent.steps and agent.steps[agent.pc]
  if failed then g.lab = "t_echec"
  elseif not s then g.lab = nil
  elseif s[1] == "home" then g.lab = agent.pc == 1 and "t_depart" or "t_retour"
  elseif s[1] == "take_res" then g.lab = "t_prise"
  elseif s[1] == "goto" then g.lab = "t_marche"
  elseif s[1] == "ia1d" then g.lab = "t_pose"
  else g.lab = "t_" .. tostring(s[1]) end
end

local function gh_finish(agent, f, task, ok, tick)
  local g = task and task.gt
  if not g then return end
  if g.lab then g[g.lab] = (g[g.lab] or 0) + (tick - g.pt) end
  g.lab = nil
  local b = f.build
  if not (b and b.stats) then return end
  local st = b.stats.gh
  if not st then st = { n = 0, ok = 0, built = 0, lot = 0, took = 0, tok = 0, zero = 0, total = 0, fails = {}, logs = 0, last = tick } b.stats.gh = st end
  st.n, st.ok = st.n + 1, st.ok + (ok and 1 or 0)
  st.built, st.lot, st.took, st.tok = st.built + (g.built or 0), st.lot + (g.n or 0), st.took + (g.took or 0), st.tok + (g.tok or 0)
  if (g.built or 0) == 0 then st.zero = st.zero + 1 end
  st.total = st.total + (tick - g.t0)
  for _, k in ipairs(GH_KEYS) do st[k] = (st[k] or 0) + (g[k] or 0) end
  if not ok then local r = tostring(task.fail or "?") st.fails[r] = (st.fails[r] or 0) + 1 end
  local function sec(v) return (v or 0) / 60 end
  if st.logs < GH_LOGS then
    st.logs = st.logs + 1
    log(string.format("[FO-GHOST] %s : tache %s %s en %.0f s par le PNJ %s a %.1f min : lot %d piece(s), %d objet(s) porte(s), %d posee(s), %d pensee(s) sans jeton, %.0f tuiles du QG ; depart %.0f s, prise %.0f s, marche %.0f s, pose %.0f s, retour %.0f s, retour d'echec %.0f s%s",
      f.key or "player", tostring(task.key), ok and "FINIE" or "ECHEC", sec(tick - g.t0), tostring(agent.id), tick / 3600, g.n or 0, g.took or 0,
      g.built or 0, g.tok or 0, g.d or 0, sec(g.t_depart), sec(g.t_prise), sec(g.t_marche), sec(g.t_pose), sec(g.t_retour), sec(g.t_echec),
      ok and "" or (" (" .. tostring(task.fail) .. ")")))
  end
  if tick - st.last >= 18000 then
    st.last = tick
    local fl = {}
    local ks = {}
    for k in pairs(st.fails) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do fl[#fl + 1] = k .. " " .. st.fails[k] end
    local tt = math.max(1, st.total)
    log(string.format("[FO-GHOST-BILAN] %s a %.1f min : %d tache(s) ghost (%d finies, %d sans pose), %d piece(s) posee(s) (%.2f par tache) sur %d au lot, %d objet(s) porte(s) ; %.1f PNJ-min ; temps : depart %d %%, prise %d %%, marche %d %%, pose %d %%, retour %d %%, retour d'echec %d %% ; %d pensee(s) sans jeton ; echecs {%s}",
      f.key or "player", tick / 3600, st.n, st.ok, st.zero, st.built, st.built / math.max(1, st.n), st.lot, st.took, st.total / 3600,
      math.floor(100 * (st.t_depart or 0) / tt), math.floor(100 * (st.t_prise or 0) / tt), math.floor(100 * (st.t_marche or 0) / tt),
      math.floor(100 * (st.t_pose or 0) / tt), math.floor(100 * (st.t_retour or 0) / tt), math.floor(100 * (st.t_echec or 0) / tt), st.tok,
      table.concat(fl, ", ")))
  end
end

local function finish(agent, f, ok, tick)
  local task = agent.task
  gh_finish(agent, f, task, ok, tick)
  agent.task = nil
  agent.steps = nil
  Board.release(f, agent) -- lot IA3-b : réservation non prise rendue au libre
  if task then
    agent.last_project = task.project -- lot IA3-b : continuité de la place de marché
    if not ok then return_site(f, task) end
    Board.finish(f, task, ok, tick)
    Poles.task_done(f, task, ok, tick)
  end
  -- Lot IA1-b : fin de tâche, la destination différée devient le pôle (avant la tâche suivante).
  Poles.settle(f, agent, tick)
  set(agent, "idle", tick)
end

--- Échec : on rapporte au QG ce qu'on porte, puis la tâche est rendue.
local function abort(agent, f, tick, reason)
  -- Lot BANDE-FIN-TAPIS (F475) : objets d'une tâche de chantier pris à la réserve du projet (take_res) : rendus à cette réserve, pas au coffre
  -- (le retour au QG les donnait d'abord à un autre module en réserve) ; un PNJ tué ne passe pas ici
  local t = agent.task
  if t and t.took and t.ia1d and t.ia1d.mode == "build" and agent.entity and agent.entity.valid then
    Build.restore_reserved(f, t.ia1d.pid, t.items, main_inv(agent))
  end
  if agent.task then agent.task.fail = reason end
  agent.failed = true
  agent.steps = { { "home" } }
  agent.pc = 1
  set(agent, "step", tick)
end
Worker.abort = abort -- lot IA3-k : demi-tour et fuite

--- Lot ETAGE4 : bail échu d'une tâche (shared/team/bail.lua, appelé par script/team/bail.lua). 1re fois : abandon (programme « rentrer »,
--- la machine repart de l'étape : une marche ou un état sans issue est remis à zéro) ; encore sans progrès au bail suivant (il ne peut même
--- pas rentrer : enfermé, état sans issue) : DÉGAGÉ, téléporté près du QG (comme le secours de l'étape « home »), dépôt, et la tâche finit en
--- échec. Rend "abandon" | "degage".
--- Place près de `center` pour le personnage `e` : sans bâtiment (find_non_colliding_position) ni fantôme sur la case (F293). Centres essayés
--- dans un ordre fixe : `center`, puis 8 à 3 tuiles et 8 à 6 tuiles. Aucune sans fantôme : la première place sans bâtiment ; aucune : nil.
local GHOST_RING = { { 0, 0 }, { 3, 0 }, { 0, 3 }, { -3, 0 }, { 0, -3 }, { 3, 3 }, { -3, 3 }, { -3, -3 }, { 3, -3 },
  { 6, 0 }, { 0, 6 }, { -6, 0 }, { 0, -6 }, { 6, 6 }, { -6, 6 }, { -6, -6 }, { 6, -6 } }
function Worker.ghost_free_spot(e, center)
  local s = e.surface
  local first
  for _, o in ipairs(GHOST_RING) do
    local spot = s.find_non_colliding_position(e.name, { x = center.x + o[1], y = center.y + o[2] }, 20, 0.5)
    if spot then
      first = first or spot
      if s.count_entities_filtered({ type = "entity-ghost", limit = 1,
        area = { { spot.x - 0.5, spot.y - 0.5 }, { spot.x + 0.5, spot.y + 0.5 } } }) == 0 then
        return spot
      end
    end
  end
  return first
end

--- Revue du lead (m5) : le motif d'un abandon antérieur (fuite, danger) est gardé ; « bail » seulement s'il n'y en avait pas.
--- Accord du lead (F293) : la place du dégagement est libre de bâtiments (find_non_colliding_position) ET de fantômes (un personnage debout
--- sur l'emprise d'un fantôme en empêche le ravivage) : Worker.ghost_free_spot.
function Worker.release_stuck(agent, f, tick)
  local task = agent.task
  if task and not task.bailed then
    task.bailed = true
    local why = task.fail
    abort(agent, f, tick, "bail")
    if why then task.fail = why end
    return "abandon"
  end
  local e = agent.entity
  if e and e.valid then
    if agent.nav then Nav.stop(agent, tick) end
    local spot = f.hq and f.hq.valid and Worker.ghost_free_spot(e, home_slot(agent, f))
    if spot then
      e.teleport(spot)
      f.stats.rescued = (f.stats.rescued or 0) + 1
      deposit_all(agent, f)
    end
  end
  if task then task.fail = task.fail or "bail" end
  agent.failed = nil
  finish(agent, f, false, tick)
  return "degage"
end

---------------------------------------------------------------------------------------------------
-- Lot CRAFT-PARALLELE : fabrication en arrière-plan
---------------------------------------------------------------------------------------------------
-- Chaîne : run_steps, étape « craft » -> to_background (un TRAVAIL de agent.bg.jobs ; la tâche « craft » reste PRISE au tableau à
-- son nom) -> le PNJ est rendu à « idle » et prend une autre tâche (Board.claim ; la place de marché, board.lua, crochet
-- Board.bg_view, lui refuse CB.EXCLUDED et une fabrication de plus au-delà de CB.MAX_JOBS ; lot FABRIQUE : plus de borne de durée,
-- sa file avance pendant la tâche) -> à chaque pensée, quel que soit l'état (defend), bg_tick lance l'étape suivante quand la file du
-- personnage est vide (travaux dans l'ordre) -> travail entièrement fabriqué : job.ready -> dépôt au coffre au prochain passage au
-- QG (étape « home », ou sur place s'il est au QG sans tâche) -> bg_close_job (Board.finish, Poles.task_done : la tâche se termine
-- comme avant, à la livraison). Les ingrédients des étapes pas encore lancées sont gardés HORS de la poche (bg.hold) : ni le dépôt
-- au QG ni une tâche qui vide la poche (Outposts.service_smelters charge TOUT le combustible porté) ne les prennent ; ils reviennent
-- dans l'inventaire principal juste avant begin_crafting (F29 : un intermédiaire arme ou munitions fabriqué va dans son
-- emplacement, begin_crafting ne l'y trouve pas : il est repris au-delà de la dotation KEEP_GUN / KEEP_AMMO). Un seul lecteur de
-- agent.bg : ce bloc (Board.bg_view et Worker.crafting en sont des vues). Écrit seulement par to_background, bg_tick et
-- bg_close_job.

local SLOT_KEEP -- { {inventaire, dotation gardée}, ... } : construit à la première utilisation (defines lu en événement)

--- Met en réserve (bg.hold) les ingrédients des étapes pas encore lancées qui sont en poche (inventaire principal, puis armes et
--- munitions au-delà de la dotation du PNJ).
local function bg_absorb(agent, bg)
  SLOT_KEEP = SLOT_KEEP or { { defines.inventory.character_guns, KEEP_GUN }, { defines.inventory.character_ammo, KEEP_AMMO } }
  local e = agent.entity
  local need = CB.keep_jobs(bg.jobs, ingredients_of)
  local hold = bg.hold
  local main = e.get_main_inventory()
  for _, item in ipairs(State.sorted_keys(need)) do
    local want = need[item] - (hold[item] or 0)
    if want > 0 then
      local got = main.get_item_count(item) > 0 and main.remove({ name = item, count = want }) or 0
      for _, s in ipairs(SLOT_KEEP) do
        if got >= want then break end
        local inv = e.get_inventory(s[1])
        local spare = inv and (inv.get_item_count(item) - (s[2][item] or 0)) or 0
        if spare > 0 then got = got + inv.remove({ name = item, count = math.min(spare, want - got) }) end
      end
      if got > 0 then hold[item] = (hold[item] or 0) + got end
    end
  end
end

--- Rend la réserve à l'inventaire principal (avant begin_crafting, ou à la fin). `spill` : ce qui n'entre pas tombe au sol.
local function bg_release(agent, bg, spill)
  local e = agent.entity
  local main = e.get_main_inventory()
  for _, item in ipairs(State.sorted_keys(bg.hold)) do
    local n = bg.hold[item]
    local put = n > 0 and main.insert({ name = item, count = n }) or 0
    if put < n and spill then
      e.surface.spill_item_stack(e.position, { name = item, count = n - put }, true, e.force, false)
      put = n
    end
    bg.hold[item] = put < n and (n - put) or nil
  end
end

--- Bilan [FO-CRAFT] de l'équipe si la fenêtre est échue (PNJ qui fabriquent en arrière-plan ET travaillent).
local function bg_report(f, tick)
  local w = CB.window(f.team)
  if not CB.due(w, tick) then return end
  local live, live_work = 0, 0
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    if a and a.bg then
      live = live + 1
      if a.task then live_work = live_work + 1 end
    end
  end
  log(CB.report_line(f.key or (f.is_player and "player") or f.id, tick, w, live, live_work))
  CB.reset(w, tick)
end

--- Fin d'un travail en arrière-plan : livré (ok) ou perdu (cause : « delai », « ingredients », « mort »). Dernier travail fini :
--- la réserve revient en poche (déposée au prochain passage au QG ; PNJ mort : perdue avec ce qu'il portait, F253).
local function bg_close_job(agent, f, job, ok, tick, cause)
  local bg = agent.bg
  if not bg then return end
  for k, j in ipairs(bg.jobs) do
    if j == job then
      table.remove(bg.jobs, k)
      break
    end
  end
  local alive = cause ~= "mort" and agent.entity and agent.entity.valid
  if #bg.jobs == 0 then
    agent.bg = nil
    if alive then bg_release(agent, bg, true) end
  elseif not ok and alive then
    bg_release(agent, bg, false) -- la part du travail perdu ressort de la réserve ; celle des autres y retourne
    bg_absorb(agent, bg)
  end
  if not (f and f.team) then return end
  local task = job.task
  local w = CB.window(f.team)
  w.bg_ticks = w.bg_ticks + (tick - job.at)
  w.work_ticks = w.work_ticks + (job.work or 0)
  if ok then
    w.done = w.done + 1
    w.delay_ticks = w.delay_ticks + (tick - (job.ready_tick or tick))
    f.stats.crafted = (f.stats.crafted or 0) + 1
    -- Lot POSE-PAR-LOTS : un kit de fabrication d'un projet (shared/ai3/kit_lot.lua) est livré au coffre ; durée = de la prise à la livraison
    if task.kit then
      f.stats.kits_livres = (f.stats.kits_livres or 0) + 1
      if f.stats.kits_livres <= 300 then
        local parts = {}
        for _, wk in ipairs(task.kit) do parts[#parts + 1] = string.format("%s x%d", tostring(wk[1]), wk[2] or 0) end
        log(string.format("[FO-LOTS-KIT] %s : kit LIVRE %s (projet %s '%s') : %s ; %d fabrication(s) en %.0f s de la prise a la livraison (%.0f s de fabrication) par le PNJ %d a %.1f min",
          f.key or (f.is_player and "player") or tostring(f.id), tostring(task.key), tostring(task.ia3), tostring(task.why), table.concat(parts, ", "),
          #job.list, (tick - job.at) / 60, (job.ready_tick and job.t0 and (job.ready_tick - job.t0) or 0) / 60, agent.id, tick / 3600))
      end
    end
  else
    w.failed = w.failed + 1
    w.causes[cause] = (w.causes[cause] or 0) + 1
    task.fail = task.fail or "fabrication"
    log(string.format("[FO-CRAFT] %s : fabrication en arriere-plan de %s x%d (PNJ %d, etape %d/%d) perdue : %s, a %.1f min",
      f.key or (f.is_player and "player") or tostring(f.id), tostring(task.item), task.count or 0, agent.id, job.i, #job.list,
      cause, tick / 3600))
  end
  Board.finish(f, task, ok, tick)
  -- Relecture : durée mesurée de la prise à la FIN DE LA FABRICATION (comme avant ce lot, où le PNJ rentrait aussitôt) ; l'attente
  -- de la livraison (le PNJ fait autre chose) gonflerait org.dur.craft, donc la demande du pôle (O.demand_from_tasks).
  Poles.task_done(f, task, ok, ok and job.ready_tick or tick)
  bg_report(f, tick)
end

--- Travaux livrés au dépôt (étape « home » ou dépôt sur place) : tous les travaux entièrement fabriqués.
local function bg_deliver(agent, f, tick)
  local bg = agent.bg
  if not bg then return end
  local done = {}
  for _, j in ipairs(bg.jobs) do if j.ready then done[#done + 1] = j end end
  for _, j in ipairs(done) do bg_close_job(agent, f, j, true, tick) end
end

--- Avance la fabrication en arrière-plan (appelé à chaque pensée du PNJ, par defend) : étape suivante lancée quand la file est
--- vide (les intermédiaires de l'étape précédente sont alors en poche), délai, fin d'un travail, dépôt au QG sans tâche.
local function bg_tick(agent, tick)
  local bg = agent.bg
  local e = agent.entity
  if not (e and e.valid) then return end
  local f = faction_of(agent)
  if not (f and f.team) then return end
  local dt = tick - (bg.last or tick)
  bg.last = tick
  if agent.task and dt > 0 then
    for _, j in ipairs(bg.jobs) do j.work = (j.work or 0) + dt end
  end
  local cur -- travail en cours de fabrication (lancé, pas fini) ; nxt : premier travail qui a encore une étape à lancer
  local nxt
  for _, j in ipairs(bg.jobs) do
    if not j.ready and not cur and j.t0 then cur = j end
    if not nxt and j.i <= #j.list then nxt = j end
  end
  if e.crafting_queue_size > 0 then
    -- Relecture : file occupée SANS travail lancé (restes d'un travail clos au délai) : le premier travail qui attend a son délai
    -- compté de là (bg.wait0) ; sans quoi une file bloquée le garderait pris au tableau pour toujours (Board.incoming le compte :
    -- le cerveau ne le redemanderait plus) et le PNJ exclu des gardes, avant-postes et explorations.
    local late, since = cur, cur and cur.t0
    if not cur then
      bg.wait0 = bg.wait0 or tick
      late, since = nxt, bg.wait0
    end
    if late and tick - since > CRAFT_TIMEOUT then
      bg.wait0 = nil
      bg_close_job(agent, f, late, false, tick, "delai")
      return
    end
    bg_absorb(agent, bg) -- intermédiaires sortis de la file depuis la pensée précédente
    return
  end
  bg.wait0 = nil
  -- File vide : tout travail entièrement lancé est fabriqué.
  for _, j in ipairs(bg.jobs) do
    if not j.ready and j.i > #j.list then j.ready, j.ready_tick = true, tick end
  end
  if nxt then
    local c = nxt.list[nxt.i]
    bg_release(agent, bg, false)
    nxt.t0 = nxt.t0 or tick
    local n = e.begin_crafting({ count = c.runs, recipe = c.recipe, silent = true })
    if n < c.runs then
      f.stats.craft_fail = (f.stats.craft_fail or 0) + 1
      if n == 0 then
        bg_close_job(agent, f, nxt, false, tick, "ingredients")
        return
      end
    end
    nxt.i = nxt.i + 1
    bg_absorb(agent, bg)
  end
  -- Au QG et sans tâche : dépôt sur place (avec une tâche, son étape « home » déposera : ses objets ne partent pas au coffre).
  if agent.bg and not agent.task and f.hq and f.hq.valid and dist2(e.position, home_slot(agent, f)) <= HOME_RADIUS * HOME_RADIUS then
    local any = false
    for _, j in ipairs(agent.bg.jobs) do if j.ready then any = true break end end
    if any then
      deposit_all(agent, f)
      bg_deliver(agent, f, tick)
    end
  end
end

--- Vue de la fabrication en arrière-plan pour la porte de la place de marché (script/team/board.lua) : nil sans fabrication ;
--- sinon { full = plus de place pour une fabrication (CB.MAX_JOBS) }.
Board.bg_view = function(agent)
  local bg = agent.bg
  if not bg then return nil end
  return { full = #bg.jobs >= CB.MAX_JOBS }
end

--- Le PNJ peut-il passer sa tâche « craft » en arrière-plan (réglage, place de marché, place parmi ses travaux) ?
--- Relecture : place de marché ÉTEINTE (réglage fo-war-ia3-marche) : ancien chemin, car la porte Board.bg_view (gardes,
--- avant-postes, MAX_JOBS) n'existe que dans claim_market ; la prise classique (O.pick_task) donnerait
--- à un PNJ qui fabrique une garde de 5 min ou un avant-poste lointain, produits en poche.
local function bg_room(agent, f)
  return Worker.CRAFT_BG and agent.task ~= nil and f ~= nil and Board.market(f)
    and not (agent.bg and #agent.bg.jobs >= CB.MAX_JOBS)
end

--- Étape « craft » : la fabrication passe en arrière-plan, le PNJ est rendu au tableau (sa tâche « craft » reste prise à son nom).
--- `list` = étapes de la tâche, `i` = première étape pas encore lancée, `t0` = début de la fabrication (délai CRAFT_TIMEOUT ; nil :
--- au lancement de sa première étape, derrière les travaux déjà là).
local function to_background(agent, f, list, i, t0, tick)
  local task = agent.task
  local job = { task = task, list = list, i = i, t0 = t0, at = tick }
  if agent.bg then
    agent.bg.jobs[#agent.bg.jobs + 1] = job
  else
    agent.bg = { jobs = { job }, hold = {}, last = tick }
  end
  agent.task, agent.steps, agent.pc, agent.failed = nil, nil, nil, nil
  agent.craft_i, agent.craft_started, agent.craft_place = nil, nil, nil
  agent.last_project = task.project
  Board.release(f, agent) -- réservation non prise rendue au libre (comme finish)
  local w = CB.window(f.team)
  w.started = w.started + 1
  Poles.settle(f, agent, tick)
  set(agent, "idle", tick)
  bg_tick(agent, tick) -- première étape lancée tout de suite si la file est libre (le PNJ est au QG, matières en poche)
end

--- Lot FUITE : les PNJ au travail à moins de `radius` tuiles de `p` (défaut Poles.LOSS_RADIUS) rentrent au QG (tâche
-- abandonnée, « danger »), sauf `except` et les tâches de défense (Re.recall_exempt) ; rend leur nombre. Appelé à la mort
-- d'un PNJ (lieu de la perte) et à la FUITE d'un autre (lieu de la menace) : on n'attend plus la première perte.
Worker.RECALL_RADIUS = Poles.LOSS_RADIUS
function Worker.recall_near(f, p, radius, tick, except)
  local r2 = (radius or Worker.RECALL_RADIUS) ^ 2
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    local at = a and a.task
    local e = a and a.entity
    -- Lot DANGER-ACTIF (relecture du lead, 5/11) : un ouvrier ARMÉ n'est pas rappelé : il défend (Re.decide, Re.SITE_RATIO), comme le veut le DC (19 h 12).
    local armed = e and e.valid and Worker.hook and Worker.hook.has_ammo and Worker.hook.has_ammo(e)
    if armed and a ~= except and at and not at.fail and dist2(e.position, p) <= r2 then
      f.stats.recall_armed_kept = (f.stats.recall_armed_kept or 0) + 1
    elseif a ~= except and at and e and e.valid and not Re.recall_exempt(at.kind, at.defend)
      and not at.fail and dist2(e.position, p) <= r2 then
      -- Lot MAIN-INVENTAIRE : le service des fours du QG (charbon, sortie, relance) reste prioritaire après une attaque.
      if Mi.keep_working(at.kind, dist2(e.position, f.hq_pos)) then
        f.stats.main_gardes = (f.stats.main_gardes or 0) + 1
        if f.stats.main_gardes <= 5 then
          log(string.format("[FO-MAIN] %s : service des fours (%s) GARDE malgre le rappel, PNJ a %.0f tuiles du QG, a %.1f min",
            f.key or "?", tostring(at.kind), math.sqrt(dist2(e.position, f.hq_pos)), tick / 3600))
        end
      else
        abort(a, f, tick, "danger")
        n = n + 1
      end
    end
  end
  f.stats.danger_recalls = (f.stats.danger_recalls or 0) + n
  return n
end

local function goto_step(agent, pos, radius, tick)
  local e = agent.entity
  local p = e.position
  if dist2(p, pos) <= (radius + 1) * (radius + 1) then return true end
  -- Lot IA1-a : but OCCUPÉ (F28 : 128 échecs « but occupé » en 60 min dans ia0-normal, journal archivé du
  -- 21/10) : un point d'accès couvert depuis par une foreuse, une case du QG sous un four, un autre PNJ.
  -- Le but devient le point libre le plus proche (test seulement, aucune entité posée : F26).
  local surface = e.surface
  Profiler.fstart("worker:goal_free")
  local placeable = surface.can_place_entity({ name = e.name, position = pos })
  Profiler.fstop("worker:goal_free")
  if not placeable then
    Profiler.fstart("worker:goal_free")
    local free = surface.find_non_colliding_position(e.name, pos, radius + 6, 0.5)
    Profiler.fstop("worker:goal_free")
    if free then
      pos = free
      local f = faction_of(agent)
      if f and f.stats then f.stats.goal_moved = (f.stats.goal_moved or 0) + 1 end
      if dist2(p, pos) <= (radius + 1) * (radius + 1) then return true end
    end
  end
  -- Lot IA1-d : dans le plan directeur, marche par les rues (tronçons OUVERTS, points de passage en Manhattan, sans
  -- pathfinder) ; un PNJ bloqué (aucun progrès pendant 2 pensées) est rendu au PathService (agent.street_off).
  local fb = faction_of(agent)
  if fb and fb.build and not agent.street_off then
    Profiler.start("build:route")
    local wp = Build.street_route(fb, p, pos)
    Profiler.stop("build:route")
    if wp then
      local path = {}
      for i, w in ipairs(wp) do path[i] = { position = w } end
      agent.walk_radius = radius
      agent.goal = pos
      Locomotion.set_path(agent, path)
      agent.last_x, agent.last_y, agent.last_check = p.x, p.y, tick
      agent.stuck = 0
      agent.nav = "moving"
      agent.street_walk = true
      Locomotion.start(agent)
      Build.note_walk(fb, "start")
      set(agent, "walk", tick)
      return false
    end
  end
  agent.walk_radius = radius
  local H = Worker.hook -- lot IA3-k : itinéraire par points de passage (danger, variation)
  if H then
    Profiler.fstart("ia3k:leg")
    local w, wr = H.leg(agent, pos, radius, tick)
    Profiler.fstop("ia3k:leg")
    if w then pos, radius = w, wr end
  end
  Profiler.fstart("nav:go")
  Nav.go(agent, pos, tick, { radius = radius })
  Profiler.fstop("nav:go")
  set(agent, "walk", tick)
  return false
end

--- Lot CORR-RALLIEMENT (tenue, 7/11) : état « away » de l'équipe (QG débordé) par le crochet de script/ai3/comportement.lua ; nil sans crochet.
local function away_state(f, tick)
  local H = Worker.hook
  return H and H.away_state and H.away_state(f, tick) or nil
end

--- Relecture revue-0659 (7/11) : borne de l'attente d'un PNJ CHARGÉ à l'étape « home » pendant « away » quand aucun coffre n'est sûr ;
--- ensuite il garde son sac et passe à la suite. = SD.SHELTER_TICKS (script/ai3/soldats.lua, sans require : le test vérifie l'égalité).
Worker.AWAY_WAIT_TICKS = 600

--- Le PNJ porte-t-il quelque chose que deposit_all déposerait (tout, sauf son arme et sa dotation de munitions) ? Sans `pairs` : comptes
--- totaux de chaque inventaire, moins ce qui est gardé.
local function has_deposit(agent)
  local e = agent.entity
  local function over(inv, keep_name, keep_n)
    if not inv then return false end
    local kept = keep_name and math.min(keep_n, inv.get_item_count(keep_name)) or 0
    return inv.get_item_count() > kept
  end
  return over(main_inv(agent)) or over(e.get_inventory(defines.inventory.character_guns), T.worker_gun, 1)
    or over(e.get_inventory(defines.inventory.character_ammo), T.worker_ammo, T.worker_ammo_keep)
    or over(e.get_inventory(defines.inventory.character_armor))
end

--- Coffre du stock (QG, puis annexes) le plus proche du PNJ et HORS de portée de la menace `w` (Da.safe_chest), ou nil.
local function safe_stock_chest(f, agent, w)
  local chests = {}
  if f.hq and f.hq.valid then chests[1] = f.hq end
  for _, e in ipairs(Stock.annexes(f)) do chests[#chests + 1] = e end
  local ps = {}
  for i, c in ipairs(chests) do ps[i] = c.position end
  local i = Da.safe_chest(ps, agent.entity.position, w)
  return i and chests[i] or nil
end

--- Lot CORR-RALLIEMENT (tenue, demande du lead, 8/11) : ligne [FO-TENUE] pour que le DC lise en jeu pourquoi un PNJ ne rentre pas. Une ligne
--- par équipe quand un compteur de f.team.tenue a changé, au plus une par minute de jeu (les changements de la minute sont repris par la
--- ligne suivante : « depuis la ligne précédente »). `w` = l'état « away » (menace, atteinte).
local function tenue_log(f, st, w, tick)
  if st.last_log and tick - st.last_log < 3600 then return end
  local ds, dk, da, dd = st.skip - (st.l_skip or 0), st.kept - (st.l_kept or 0), st.abort - (st.l_abort or 0), st.safe - (st.l_safe or 0)
  if ds + dk + da + dd == 0 then return end
  st.last_log, st.l_skip, st.l_kept, st.l_abort, st.l_safe = tick, st.skip, st.kept, st.abort, st.safe
  log(string.format("[FO-TENUE] %s minute %.1f : QG deborde (menace en (%.0f, %.0f), atteinte %.0f tuiles) : les PNJ ne rentrent pas au QG ; "
    .. "%d depot(s) dans un coffre hors de portee, %d etape(s) « rentrer » sautee(s) (sac vide), %d sac(s) garde(s) apres %d ticks "
    .. "d'attente (aucun coffre hors de portee), %d tache(s) abandonnee(s) (elles exigent le QG) ; depuis la ligne precedente : +%d, +%d, +%d, +%d",
    tostring(f.key), tick / 3600, w.x or 0, w.y or 0, w.reach or 0, st.safe, st.skip, st.kept, Worker.AWAY_WAIT_TICKS, st.abort, dd, ds, dk, da))
end

local function run_steps(agent, tick)
  local f = faction_of(agent)
  if not f or not (f.hq and f.hq.valid) then return end
  local surface = agent.entity.surface
  for _ = 1, MAX_STEPS_PER_THINK do
    gh_phase(agent, tick) -- lot CHANTIERS-FANTOMES : temps par étape des tâches de pose
    local step = agent.steps and agent.steps[agent.pc]
    if not step then
      local ok = not agent.failed
      agent.failed = nil
      finish(agent, f, ok, tick)
      return
    end
    local kind = step[1]
    local away = kind == "home" and away_state(f, tick) or nil
    if away then
      -- Lot CORR-RALLIEMENT (tenue, 7/11 ; RAPPORT EFFONDREMENT §12) : QG débordé (« away ») : pas de retour au QG. Dépôt dans le coffre du stock le
      -- plus proche HORS de portée de la menace.
      -- Relecture revue-0659 (7/11) : l'attente sans coffre sûr n'avait pas de sortie bornée et, presque tout programme commençant par « home »,
      -- ARRÊTAIT TOUTE L'ÉQUIPE tant qu'un campeur débordait le QG. Désormais (critères : CRITERES.md EFFONDREMENT, « TENUE, correction ») :
      --   (a) rien à déposer : l'étape est sautée (début de tâche, retour après un dépôt, fin) ;
      --   (c) à déposer, aucun coffre sûr : attente au plus Worker.AWAY_WAIT_TICKS, puis le PNJ GARDE son sac et passe à la suite ;
      --   (b) l'étape suivante exige le QG (« take ») : la tâche est abandonnée (raison « away », pause courte de la peur, shared/team/actif.lua).
      local carry = has_deposit(agent)
      local chest = carry and safe_stock_chest(f, agent, away) or nil
      local st = f.team and f.team.tenue
      if f.team and not st then st = { skip = 0, kept = 0, abort = 0, safe = 0 } f.team.tenue = st end
      if st and not st.safe then st.safe = 0 end -- (sauvegarde d'avant la ligne [FO-TENUE])
      if chest then
        agent.away_wait = nil
        if not goto_step(agent, chest.position, 2, tick) then return end
        deposit_all(agent, f, chest)
        if st then st.safe = st.safe + 1 end
      elseif carry then
        agent.away_wait = agent.away_wait or tick
        if tick - agent.away_wait < Worker.AWAY_WAIT_TICKS then return end
        agent.away_wait = nil
        if st then st.kept = st.kept + 1 end
      else
        agent.away_wait = nil
        if st then st.skip = st.skip + 1 end
      end
      agent.pc = agent.pc + 1
      local nxt = agent.steps[agent.pc]
      if nxt and nxt[1] == "take" then
        if st then st.abort = st.abort + 1 tenue_log(f, st, away, tick) end
        abort(agent, f, tick, "away")
        return
      end
      if st then tenue_log(f, st, away, tick) end
    elseif kind == "home" then
      agent.away_wait = nil
      if not goto_step(agent, home_slot(agent, f), 1, tick) then return end
      deposit_all(agent, f)
      bg_deliver(agent, f, tick) -- lot CRAFT-PARALLELE : produits des travaux finis livrés (déposés juste au-dessus)
      agent.pc = agent.pc + 1
    elseif kind == "take" then
      -- Lot IA3-b : une tâche avec réservation (registre) prend exactement sa réservation, rien de plus.
      local all
      Stock.ctx = agent.task and ((agent.task.kind or "?") .. ":" .. tostring(agent.task.key or "?"):sub(1, 28)) or nil -- diagnostic DEFENSE-AP
      if agent.resa_id then all = Board.take_reserved(f, agent, main_inv(agent), step[2])
      else all = take(agent, f, step[2]) end
      Stock.ctx = nil
      if agent.task then agent.task.took = true end -- lot IA1-b : objets pris (stock libre du fond)
      if step.strict and not all then
        abort(agent, f, tick, (agent.task and agent.task.preempted) and "preempte" or "stock")
        return
      end
      agent.pc = agent.pc + 1
    elseif kind == "wait" then
      agent.wait_until = tick + (step[2] or 0)
      set(agent, "wait", tick)
      return
    elseif kind == "craft_now" then
      -- Lot STOCKAGE-VITAL : fabrication sur place avec ce que le PNJ porte (coffre urgent après sa récolte, paires de l'auto-financement) ;
      -- jamais derrière une fabrication en arrière-plan (sa file est à elle : rien n'est lancé, le bois rentre au QG).
      -- Lot POSE-PERDUE (banc 0.6.75 A : « 0 paire(s) posee(s) avec 41 iron-plate pris(es) sur place », [FO-EXTEND] « objets ») : les recettes
      -- partaient toutes dans le même tick ; le produit final, dont les ingrédients étaient encore en file (pas dans l'inventaire), n'était
      -- jamais mis en file (30 fabrications sur 38 : 15 + 15 + 0). État « craft_now » : une recette à la fois, file vide entre deux (Fp.avance),
      -- comme l'état « craft » ; la durée estimée par la pensée (step[3]) ne sert plus de minuterie.
      local e = agent.entity
      if agent.bg or e.crafting_queue_size > 0 then
        f.stats.stock_craft_logs = (f.stats.stock_craft_logs or 0) + 1
        if f.stats.stock_craft_logs <= 40 then
          log(string.format("[FO-STOCKAGE] %s : coffre urgent %s fabrique sur place par le PNJ %s : rien de lance (file de fabrication occupee) a %.1f min",
            f.key or "player", tostring(step[4]), tostring(agent.id), (tick - (f.started or 0)) / 3600))
        end
        agent.pc = agent.pc + 1
      else
        agent.craft_place = { i = 1, n = 0, t0 = tick }
        set(agent, "craft_now", tick)
        return
      end
    elseif kind == "goto" then
      if not goto_step(agent, step[2], step[3] or 4, tick) then return end
      agent.street_off = nil -- lot IA1-d : le repli vers le PathService ne vaut que pour ce trajet
      agent.pc = agent.pc + 1
    elseif kind == "take_depot" or kind == "put_depot" then
      -- Lot TV-ARCHI (V91) : prise au dépôt du quartier, puis retour du reste au même dépôt (script/team/quartiers.lua, Qr.depot_step)
      local ok = Build.Quartiers.depot_step(f, kind, step[2], step[3], main_inv(agent))
      if agent.task then agent.task.took = true end
      if not ok then
        abort(agent, f, tick, "stock")
        return
      end
      agent.pc = agent.pc + 1
    elseif kind == "take_res" then
      -- Lot IA1-d : objets réservés au chantier (retirés du coffre à la réservation : personne ne les arrache)
      local all = Build.take_reserved(f, step[2], step[3], main_inv(agent))
      if agent.task then agent.task.took = true end
      local g = agent.task and agent.task.gt
      if g then -- lot CHANTIERS-FANTOMES : objets du lot portés au départ
        local n = 0
        for _, it in ipairs(step[3]) do n = n + math.min(it[2], main_inv(agent).get_item_count(it[1])) end
        g.took = n
      end
      if not all then
        local any = false
        for _, it in ipairs(step[3]) do if main_inv(agent).get_item_count(it[1]) > 0 then any = true break end end
        if not any then
          abort(agent, f, tick, "stock")
          return
        end
      end
      agent.pc = agent.pc + 1
    elseif kind == "ia1d" then
      local j = agent.task and agent.task.ia1d
      if not j then
        abort(agent, f, tick, "chantier")
        return
      end
      agent.ia1d = { pid = j.pid, mode = j.mode, anchor = j.anchor, idx = j.idx, seg = j.seg, rect = j.rect, ax = j.ax, ay = j.ay }
      local a = step[2] and j.tour and j.tour[step[2]] -- lot CHANTIERS-FANTOMES : point d'appui de la tournée
      if a then agent.ia1d.anchor, agent.ia1d.ax, agent.ia1d.ay = a.anchor, a.ax, a.ay end
      set(agent, "ia1d", tick)
      return
    elseif kind == "act" then
      Trace.log("act", step[2], f.key)
      local fn = ACTS[step[2]]
      local pn = Profiler.fine() and ("act:" .. tostring(step[2])) or nil
      if pn then Profiler.fstart(pn) end
      local ok = fn and fn(agent, f, agent.task, surface, tick)
      if pn then Profiler.fstop(pn) end
      if not ok then
        abort(agent, f, tick, step[2])
        return
      end
      agent.pc = agent.pc + 1
    elseif kind == "craft" then
      -- Lot CRAFT-PARALLELE : en arrière-plan, derrière ses autres travaux s'il en a ; au-delà de CB.MAX_JOBS (hors place de
      -- marché seulement, qui ne lui en donne pas plus), ancien chemin : le PNJ attend que sa file se vide.
      if bg_room(agent, f) then
        to_background(agent, f, step[2], 1, nil, tick)
        return
      end
      agent.craft_i = 1
      agent.craft_started = tick
      set(agent, "craft", tick)
      return
    elseif kind == "mine" then
      agent.mine_started = tick
      agent.mine_base = agent.entity.get_item_count(step[2])
      -- Lot MAIN-INVENTAIRE : le minerai déjà au sol près de la tuile passe avant le minage (la base est prise AVANT : il compte dans got).
      do
        local sol = pick_ground(agent, step[2])
        local f = faction_of(agent)
        if f and sol > 0 and (f.stats.main_logs or 0) < 40 then
          f.stats.main_logs = (f.stats.main_logs or 0) + 1
          log(string.format("[FO-MAIN] %s : %d %s ramasse(s) au sol en arrivant a %.1f min", f.key or "?", sol, tostring(step[2]), tick / 3600))
        end
      end
      set(agent, "mine", tick)
      return
    else
      agent.pc = agent.pc + 1
    end
  end
end

--- Autodéfense : un ouvrier armé tire sur l'ennemi le plus proche (déchiqueteurs, autres factions).
--- Lot IA3-k : rend true quand le crochet « sense » a pris la main (la pensée de l'état s'arrête là).
local function defend(agent, tick)
  if agent.bg then bg_tick(agent, tick) end -- lot CRAFT-PARALLELE : la file avance quel que soit l'état (marche, minage, pose)
  local H = Worker.hook
  Profiler.fstart("ia3k:sense")
  local took = H and H.sense(agent, tick) or false
  Profiler.fstop("ia3k:sense")
  if tick - (agent.defense_tick or 0) < DEFENSE_PERIOD then return took end
  agent.defense_tick = tick
  local e = agent.entity
  Profiler.fstart("worker:defend")
  -- Lot CERVEAU-CENTRAL (P2) : le regard de cette pensée (M.sense) n'a rien vu dans un disque qui contient celui-ci : la recherche
  -- rendrait nil (25,4 % des recherches au moteur simulé, 4 factions × 30 PNJ) ; elle est sautée, même suite.
  local p = e.position
  local enemy = nil
  if not (H and H.look_clear and H.look_clear(agent.id, tick, p, DEFENSE_RADIUS)) then
    enemy = e.surface.find_nearest_enemy({ position = p, max_distance = DEFENSE_RADIUS, force = e.force })
  end
  Profiler.fstop("worker:defend")
  if enemy and e.get_item_count(T.worker_ammo) + e.get_item_count("piercing-rounds-magazine") > 0 then
    e.shooting_state = { state = defines.shooting.shooting_enemies, position = enemy.position }
    agent.shooting = true
    local f = faction_of(agent)
    if f then f.stats.worker_shots = (f.stats.worker_shots or 0) + 1 end
  elseif agent.shooting then
    e.shooting_state = { state = defines.shooting.not_shooting, position = e.position }
    agent.shooting = nil
  end
  return took
end

FSM.define(MACHINE, {
  idle = {
    think = function(agent, tick)
      if defend(agent, tick) then return end
      local f = faction_of(agent)
      if not f or f.eliminated then return end
      -- Lot IA1-b : une prise de tâche coûte des jetons de travail (budget par tick pour tout le mod).
      if not Tokens.take(f, tick, Tokens.COST_CLAIM) then return end
      -- Lot PERF (correction après revue) : la prise de tâche entière (réclamer, programmer, juger, rendre) est comptée et
      -- mesurée SELON SON ISSUE (« idle:sans-tache », « idle:sans-programme », « idle:refus », « idle:depart ») ; la
      -- porte seule aussi (« gate:accepte », « gate:refus »). Mode fin du profileur seulement (mesure, jamais décision).
      Profiler.fmark("idle")
      Profiler.fstart("board:claim")
      local task = Board.claim(f, agent, tick)
      Profiler.fstop("board:claim")
      if not task then
        -- Rien à faire : rentrer au QG (et y déposer) plutôt que rester au loin. Lot CORR-RALLIEMENT (tenue) : pas pendant « away » (QG débordé).
        if dist2(agent.entity.position, home_slot(agent, f)) > 3 * 3 and not agent.nav and not away_state(f, tick) then
          agent.task, agent.steps, agent.pc = nil, { { "home" } }, 1
          set(agent, "step", tick)
        end
        Profiler.fcredit("idle", "idle:sans-tache")
        return
      end
      Stock.note_claim(f, main_inv(agent), tick) -- lot STOCKAGE-VITAL : prise de tâche avec la poche pleine (compteur, aucune décision)
      Profiler.fstart("worker:program")
      local steps = Worker.program(f, task, agent.entity.surface, tick)
      Profiler.fstop("worker:program")
      if not steps then
        task.fail = task.fail or "programme" -- lot IA1-b : raison écrite (minerai introuvable, avant-poste disparu)
        Board.release(f, agent) -- lot IA3-b : réservation rendue
        Board.finish(f, task, false, tick)
        Poles.task_done(f, task, false, tick)
        Profiler.fcredit("idle", "idle:sans-programme")
        return
      end
      -- Lot IA3-k : porte de la tâche (trajet dangereux : escorte ou attente).
      local H = Worker.hook
      Profiler.fstart("ia3k:gate")
      Profiler.fmark("gate")
      local gate_ok = not H or H.gate(f, agent, task, steps, tick)
      Profiler.fcredit("gate", gate_ok and "gate:accepte" or "gate:refus")
      Profiler.fstop("ia3k:gate")
      if not gate_ok then
        return_site(f, task)
        task.fail = task.fail or "danger"
        Board.release(f, agent) -- lot IA3-b : réservation rendue (comme un programme introuvable)
        Board.finish(f, task, false, tick)
        Poles.task_done(f, task, false, tick)
        Profiler.fcredit("idle", "idle:refus")
        return
      end
      Profiler.fstart("board:reserve")
      Board.reserve_soft(f, agent, task, steps, tick) -- lot IA3-b : prises larges bornées au libre (réglage allumé)
      Profiler.fstop("board:reserve")
      agent.task, agent.steps, agent.pc, agent.failed = task, steps, 1, nil
      if task.kind == "ghost" and task.ia1d then -- lot CHANTIERS-FANTOMES : mesure de la tâche de pose (gh_phase, gh_finish)
        local j = task.ia1d
        local hq = f.hq_pos
        task.gt = { t0 = tick, pt = tick, pc = 0, n = j.n or 0,
          d = (hq and j.ax) and math.sqrt((j.ax - hq.x) ^ 2 + (j.ay - hq.y) ^ 2) or 0 }
      end
      agent.walk_retries = 0 -- lot CHARBON3 (B2) : essais de marche comptés par tâche (Rc.walk_fail)
      agent.mine_trips = nil -- lot MAIN-INVENTAIRE : voyages de dépôt comptés par tâche
      set(agent, "step", tick)
      Profiler.fcredit("idle", "idle:depart")
    end,
  },
  step = {
    think = function(agent, tick)
      if defend(agent, tick) then return end
      run_steps(agent, tick)
    end,
  },
  -- Lot IA1-d : travail sur place du plan directeur (ravivages, défrichage, quais) : script/team/build.lua.
  ia1d = {
    think = function(agent, tick)
      -- Correction PC-INVALIDE (plantage bail.lua:72, azure, 87,8 min) : une réaction (demi-tour ou fuite, Worker.abort) qui part
      -- pendant cette pensée remet le programme à `{ home }` (pc = 1). Ne pas continuer le travail après elle : le retour
      -- « again » retirait alors 1 à pc et laissait pc = 0 (aucune étape). Une simple HALTE (M.sense rend vrai sans changer le
      -- programme) ne lâche pas le chantier : le job reste, et la pensée suivante reprend le travail.
      local steps0, pc0 = agent.steps, agent.pc
      if defend(agent, tick) then
        if agent.steps ~= steps0 or agent.pc ~= pc0 then agent.ia1d = nil end
        return
      end
      local f = faction_of(agent)
      if not f then return end
      Profiler.start("build:work")
      local r = Build.work(agent, f, tick)
      Profiler.stop("build:work")
      if r == "more" then return end
      local job = agent.ia1d
      agent.ia1d = nil
      -- Lot CHANTIERS-FANTOMES : dans une tournée, un point d'appui sans pose (pièces déjà posées, objet absent du sac, point inaccessible)
      -- est passé ; la tournée n'échoue que si elle n'a rien posé du tout à son dernier point.
      local cur0 = steps0 and pc0 and steps0[pc0]
      local tour = cur0 and cur0[1] == "ia1d" and cur0[2] and agent.task and agent.task.ia1d and agent.task.ia1d.tour
      if tour and agent.steps == steps0 and agent.pc == pc0 then
        agent.task.tour_done = (agent.task.tour_done or 0) + (job and job.done or 0)
        if r == "fail" and (cur0[2] < #tour or agent.task.tour_done > 0) then r = "done" end
      end
      if r == "again" then
        -- refaire la marche vers le point d'appui (étape précédente), depuis la position atteinte. Seulement si le programme
        -- est resté le même et que l'étape courante est bien ce travail, avec une étape avant (pc > 1) : sinon rien à refaire.
        local cur = steps0 and pc0 and steps0[pc0]
        if agent.steps == steps0 and agent.pc == pc0 and pc0 > 1 and cur and cur[1] == "ia1d" then
          agent.pc = pc0 - 1
          set(agent, "step", tick)
        else
          abort(agent, f, tick, "chantier")
        end
        return
      end
      if r == "done" then
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
      else
        abort(agent, f, tick, "chantier")
      end
    end,
  },
  -- Lot IA1-b : attente sur place (garnison) ; l'autodéfense tourne.
  wait = {
    think = function(agent, tick)
      if defend(agent, tick) then return end
      if tick >= (agent.wait_until or 0) then
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
      end
    end,
  },
  -- Lot POSE-PERDUE : fabrication sur place (étape « craft_now ») : une recette du plan à la fois, la suivante quand la file est vide
  -- (ses ingrédients sont alors dans l'inventaire) ; l'autodéfense tourne. Le journal [FO-STOCKAGE] s'écrit à la fin, avec le compte réel.
  craft_now = {
    think = function(agent, tick)
      if defend(agent, tick) then return end
      local e = agent.entity
      local step = agent.steps[agent.pc]
      local st = agent.craft_place
      local r = Fp.avance(e, step[2], st, tick, CRAFT_TIMEOUT)
      if r == "fini" or r == "delai" then
        local f = faction_of(agent)
        if f then
          f.stats.stock_craft_logs = (f.stats.stock_craft_logs or 0) + 1
          if f.stats.stock_craft_logs <= 40 then
            log(string.format("[FO-STOCKAGE] %s : coffre urgent %s fabrique sur place par le PNJ %s : %s a %.1f min", f.key or "player",
              tostring(step[4]), tostring(agent.id),
              st.n > 0 and string.format("%d fabrication(s) lancee(s) l'une apres l'autre, %s en %.1f s", st.n,
                r == "fini" and "file vide" or "delai echu", (tick - st.t0) / 60) or "rien de lance (matiere absente)",
              (tick - (f.started or 0)) / 3600))
          end
        end
        agent.craft_place = nil
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
      end
    end,
  },
  walk = {
    think = function(agent, tick)
      if defend(agent, tick) then return end
      Profiler.fstart("nav:think")
      Nav.think(agent, tick)
      Profiler.fstop("nav:think")
    end,
    exit = function(agent, tick) if agent.nav then Nav.stop(agent, tick) end end,
    on = {
      nav_arrived = function(agent, tick)
        agent.walk_retries = 0 -- lot CHARBON3 (B2) : une arrivée remet les essais de marche à zéro (Rc.walk_fail)
        if agent.street_walk then
          agent.street_walk = nil
          local fa = faction_of(agent)
          if fa then Build.note_walk(fa, "ok") end
        end
        set(agent, "step", tick)
      end,
      nav_failed = function(agent, tick)
        local f = faction_of(agent)
        -- Lot IA1-d : PNJ bloqué dans une rue : rendu au PathService pour la suite de ce trajet (compté).
        if agent.street_walk then
          agent.street_walk = nil
          agent.street_off = true
          if f then Build.note_walk(f, "stuck") end
        end
        local reason = agent.nav_fail or "no_path"
        -- Lot C4 PLATEAU 3 : tournée, agrandissement ou fortification dont le chemin échoue alors que le PNJ est déjà dans l'avant-poste :
        -- l'acte n'a besoin d'aucune distance (shared/team/arrivee.lua), la tâche continue au lieu d'être abandonnée
        local nst = agent.steps and agent.steps[agent.pc]
        if f and nst and nst[1] == "goto" and agent.task and Ar.KINDS[agent.task.kind] and agent.entity.valid then
          local o = f.outposts[agent.task.outpost]
          local ep = agent.entity.position
          if o and Ar.arrived(agent.task.kind, Outposts.nearest_d2(o, ep.x, ep.y)) then
            f.stats.nav_arrived = (f.stats.nav_arrived or 0) + 1
            if f.stats.nav_arrived <= 12 then
              log(string.format("[FO-NAV-ARRIVE] %s : %s, chemin refuse (%s) mais le PNJ est a %d tuile(s) d'un batiment de l'avant-poste %s : la tache continue (n. %d) a %.1f min",
                f.key, tostring(agent.task.key), reason, math.floor(math.sqrt(Outposts.nearest_d2(o, ep.x, ep.y)) + 0.5), tostring(o.kind), f.stats.nav_arrived, tick / 3600))
            end
            agent.walk_retries = 0
            agent.pc = agent.pc + 1
            set(agent, "step", tick)
            return
          end
        end
        local H = Worker.hook -- lot IA3-k : un point de passage injoignable ne fait pas échouer la tâche
        if H and H.nav_failed(agent, tick) then set(agent, "step", tick) return end
        local again
        again, agent.walk_retries = Rc.walk_fail(agent.walk_retries, reason) -- lot CHARBON3 (B2) : règle pure, remise à 0 à l'abandon
        if f then f.stats.nav_fail = (f.stats.nav_fail or 0) + 1 end
        if again then
          set(agent, "step", tick) -- nouvel essai depuis la position atteinte
          return
        end
        local step = agent.steps and agent.steps[agent.pc]
        -- Lot IA1-d : un défricheur ou un bâtisseur arrêté en route travaille là où il est (il s'ouvre le chemin vers son
        -- point d'appui, script/team/build.lua)
        if step and step[1] == "goto" and agent.task and agent.task.ia1d
          and (agent.task.ia1d.mode == "clear" or agent.task.ia1d.mode == "build") then
          agent.pc = agent.pc + 1
          set(agent, "step", tick)
          return
        end
        if step and step[1] == "home" then
          -- Ne jamais rester égaré : rappel au QG (le dépôt se fait à l'arrivée).
          local e = agent.entity
          local spot = f and e.surface.find_non_colliding_position(e.name, home_slot(agent, f), 20, 0.5)
          if spot then
            e.teleport(spot)
            if f then f.stats.rescued = (f.stats.rescued or 0) + 1 end
          end
          set(agent, "step", tick)
          return
        end
        if f and agent.task and agent.task.site and not agent.task.site_used then
          Sites.release(agent.task.site)
          Sites.mark_unreachable(agent.task.site, tick)
          agent.task.site_used = true
        end
        if f and Profiler.enabled() and agent.entity.valid then
          local p = agent.entity.position
          log(string.format("[FO-TEAM] %s : ouvrier %d, chemin introuvable (%s) depuis (%d,%d) pour %s",
            f.key, agent.id, reason, math.floor(p.x), math.floor(p.y), agent.task and agent.task.key or "?"))
        end
        -- Lot C4 PLATEAU 3 (diagnostic) : pourquoi une tournée d'avant-poste ne trouve pas son chemin (6 lignes au plus par équipe)
        if f and agent.task and (agent.task.kind == "service" or agent.task.kind == "extend") and agent.goal and agent.entity.valid
          and (f.stats.nav_diag or 0) < 6 then
          f.stats.nav_diag = (f.stats.nav_diag or 0) + 1
          local sf, g, p = agent.entity.surface, agent.goal, agent.entity.position
          local o = f.outposts[agent.task.outpost]
          local near, parts = {}, {}
          for _, e in ipairs(sf.find_entities_filtered({ position = g, radius = 8 })) do near[e.type] = (near[e.type] or 0) + 1 end
          for _, k in ipairs(State.sorted_keys(near)) do parts[#parts + 1] = k .. "=" .. near[k] end
          local free = sf.find_non_colliding_position("character", g, 6, 0.5)
          local gw = sf.count_tiles_filtered({ position = g, radius = 8, collision_mask = "water-tile" })
          log(string.format("[FO-NAV-SERVICE] %s : %s, PNJ en (%d,%d), but (%d,%d) a %d tuiles, avant-poste %s en (%d,%d) acces %s, place libre a 6 tuiles du but : %s, eau %d tuile(s), entites a 8 tuiles : %s a %.1f min",
            f.key, tostring(agent.task.key), p.x, p.y, g.x, g.y, math.floor(math.sqrt((p.x - g.x) ^ 2 + (p.y - g.y) ^ 2)),
            o and o.kind or "?", o and o.pos.x or 0, o and o.pos.y or 0, (o and o.access) and "pose" or "defaut",
            free and string.format("oui (%d,%d)", free.x, free.y) or "NON", gw, table.concat(parts, " "), tick / 3600))
        end
        -- Suite NAV2 (diagnostic seul) : fortification en échec de chemin : qui, quelle cible, but déplacé ou non par la règle (8 lignes au
        -- plus par équipe). Partie lot-271828182 : 40 refus « fortify » contre 12 au témoin, cause non lue.
        if f and agent.task and agent.task.kind == "fortify" and agent.entity.valid and (f.stats.nav_fort or 0) < 8 then
          f.stats.nav_fort = (f.stats.nav_fort or 0) + 1
          local p, g = agent.entity.position, agent.goal or { x = 0, y = 0 }
          local tgt = agent.task.outpost
          local o = type(tgt) == "number" and f.outposts[tgt] or nil
          local c = o and o.acces_cache
          log(string.format("[FO-NAV-FORTIFY] %s : ouvrier %d, %s (%s), cible %s%s, PNJ en (%d,%d), but (%.1f,%.1f) a %d tuiles, raison %s, but deplace par la regle : %s (rectangle %s) a %.1f min",
            f.key, agent.id, tostring(agent.task.key), tostring(agent.task.why or agent.task.from or "-"), tostring(tgt), o and (" " .. tostring(o.kind)) or "",
            p.x, p.y, g.x, g.y, math.floor(math.sqrt((p.x - g.x) ^ 2 + (p.y - g.y) ^ 2)), tostring(reason),
            c and (c.moved and "oui" or "non") or "sans calcul", c and tostring(c.side) or "-", tick / 3600))
        end
        abort(agent, f, tick, "chemin")
      end,
    },
  },
  craft = {
    think = function(agent, tick)
      if defend(agent, tick) then return end
      local e = agent.entity
      -- Lot CRAFT-PARALLELE : PNJ d'une sauvegarde 0.6.18 arrêté en pleine fabrication : il passe en arrière-plan à sa pensée
      -- (étape en cours, file déjà lancée gardée ; bg_tick attend qu'elle se vide).
      local fb = faction_of(agent)
      if fb and fb.team and bg_room(agent, fb) and agent.steps and agent.steps[agent.pc] then
        to_background(agent, fb, agent.steps[agent.pc][2], agent.craft_i or 1, agent.craft_started or tick, tick)
        return
      end
      if e.crafting_queue_size > 0 then
        if tick - agent.craft_started > CRAFT_TIMEOUT then
          abort(agent, faction_of(agent), tick, "fabrication")
        end
        return
      end
      local step = agent.steps[agent.pc]
      local list = step[2]
      local c = list[agent.craft_i]
      if not c then
        local f = faction_of(agent)
        if f then f.stats.crafted = (f.stats.crafted or 0) + 1 end
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
        return
      end
      local n = e.begin_crafting({ count = c.runs, recipe = c.recipe, silent = true })
      if n < c.runs then
        local f = faction_of(agent)
        if f then f.stats.craft_fail = (f.stats.craft_fail or 0) + 1 end
        if n == 0 then
          abort(agent, f, tick, "fabrication")
          return
        end
      end
      agent.craft_i = agent.craft_i + 1
    end,
  },
  mine = {
    think = function(agent, tick)
      if defend(agent, tick) then return end
      local e = agent.entity
      local step = agent.steps[agent.pc]
      local item, count = step[2], step[3]
      local got = e.get_item_count(item) - (agent.mine_base or 0)
      local target = agent.task and agent.task.target
      local f = faction_of(agent)
      local res, cover
      if target then
        res, cover = mining_entity(e.surface, target, Harvest.names_for(f, item, agent.task and agent.task.trees), f,
          Harvest.free_types(agent.task and agent.task.resource or item, f, agent.task and agent.task.trees))
      end
      -- Lot TOURELLE-JOURNAL (7/11, DC : « très fortes chances que ce soit les pnj qui les aient prises ») : update_selected_entity(position),
      -- plus bas, sélectionne ce que la souris survolerait ; une TOURELLE posée sur la tuile de minerai (par le joueur après la création de la
      -- tâche, ou sous le repli à 2,5 tuiles de mining_entity) serait minée puis portée au coffre (votre équipe a la force du joueur). Une tuile
      -- couverte par une tourelle n'est jamais minée : le minage finit comme sans minerai, et c'est écrit.
      -- (relevé en moteur réel, script/team/harvest.lua Harvest.foreign_resource : sous un cristal posé sur du charbon, le moteur sélectionnait
      -- l'AUTRE entité et le PNJ la minait : 2 cristaux au coffre, 0 charbon.) Deux gardes, pour TOUT bâtiment (lead, 7/11) :
      --   1. une tuile dont le centre est recouvert par un bâtiment (ni ressource, ni arbre récoltable, ni corps, ni objet au sol) est
      --      écartée par mining_entity, qui prend la tuile libre suivante dans le même ordre (sans tuile écartée : choix d'avant à l'identique) ;
      --      plus aucune tuile libre : pas de minage ;
      --   2. la ressource est sélectionnée ELLE-MÊME (LuaControl.selected, en écriture) et relue : une autre sélection, pas de minage.
      -- Refus : le minage finit comme sans minerai ; ligne [FO-TOURELLE-RETIREE] « minage refuse : selection = <nom> » (une par seconde au plus).
      local function who() return "PNJ " .. tostring(agent.id) .. " (" .. tostring(f and f.key or "?") .. ", minage a la main)" end
      if not res and cover then
        Tj.mine_refused(cover, who(), item, "batiment sur la tuile de minerai, aucune tuile libre a portee")
      elseif res then
        local rp = res.position
        e.selected = res
        local sel = e.selected
        if not (sel and sel.valid and sel.name == res.name and math.abs(sel.position.x - rp.x) < 0.01 and math.abs(sel.position.y - rp.y) < 0.01) then
          Tj.mine_refused(sel, who(), res.name, "la selection n'est pas la ressource visee")
          res = nil
        end
      end
      -- Lot MAIN-INVENTAIRE : inventaire plein -> on dépose l'utile au coffre puis on revient finir (au lieu de laisser le moteur
      -- lâcher le minerai au sol) ; en fin de minage, le minerai tombé au sol autour du mineur est ramassé.
      local over = got >= count or not res or tick - agent.mine_started > MINE_TIMEOUT
      local act = over and "finish" or Mi.inventory_action({ room = main_inv(agent).get_insertable_count(item), got = got,
        count = count, trips = agent.mine_trips or 0 })
      if act ~= "continue" then
        e.mining_state = { mining = false }
        local picked = pick_ground(agent, item)
        got = got + picked
        if act == "deposit" and got >= count then act = "finish" end
        if f and picked > 0 and (f.stats.main_logs or 0) < 40 then
          f.stats.main_logs = (f.stats.main_logs or 0) + 1
          log(string.format("[FO-MAIN] %s : %d %s ramasse(s) au sol autour du mineur a %.1f min", f.key or "?", picked, tostring(item), tick / 3600))
        end
        if act == "deposit" then
          agent.mine_trips = (agent.mine_trips or 0) + 1
          if f then
            f.stats.mined = (f.stats.mined or 0) + got
            if (f.stats.main_logs or 0) < 40 then
              f.stats.main_logs = (f.stats.main_logs or 0) + 1
              log(string.format("[FO-MAIN] %s : inventaire plein (%d/%d %s), depot au coffre puis retour (voyage %d) a %.1f min",
                f.key or "?", got, count, tostring(item), agent.mine_trips, tick / 3600))
            end
          end
          agent.steps[agent.pc] = { "home" }
          table.insert(agent.steps, agent.pc + 1, { "goto", target, 1.5 })
          table.insert(agent.steps, agent.pc + 2, { "mine", item, count - got })
          set(agent, "step", tick)
          return
        end
        -- Lot KIT (mesure, journal seul) : rendement de chaque minage à la main, pour la part des minages à 0 sur N.
        if f then
          log(string.format("[FO-MINAGE] %s min=%.2f %s got=%d/%d dt=%.1f %s sol=%d cle=%s coffre=%d", f.key or "?", tick / 3600, tostring(item), got, count,
            (tick - (agent.mine_started or tick)) / 60, got >= count and "complet" or (res and "delai" or "sans-entite"), picked,
            tostring(agent.task and agent.task.key), Stock.count(f, item)))
        end
        if f and agent.task then release_tile(f, agent.task.target) end -- lot KIT : la tuile est rendue
        if f then f.stats.mined = (f.stats.mined or 0) + got end
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
        return
      end
      e.mining_state = { mining = true, position = res.position } -- (ressource déjà sélectionnée plus haut : e.selected = res)
    end,
  },
})

FSM.observe(MACHINE, function(agent) Render.state_changed(agent) end)

--- Recrute un ouvrier équipé de son kit (déjà retiré du stock), ou SANS arme (secours : unarmed).
--- free = kit OFFERT (effectif de départ, lot IA1-a) : jamais rendu au coffre quand on renvoie l'équipe.
function Worker.recruit(f, surface, tick, unarmed, free)
  -- Lot IA1-a : la recrue naît sur SA case (la première libre), pas au point de rassemblement : 8 recrues
  -- posées au même point se gênaient au départ (essai court du banc ia1-scale : 15 % d'échecs « départ bloqué »).
  local owner, bad = slot_tables(f)
  local i = Scale.free_slot(bad, owner)
  local o = i and SLOTS[i]
  local at = o and { x = f.home_spot.x + o[1], y = f.home_spot.y + o[2] } or f.home_spot
  local agent = Registry.spawn(surface, at, f.force, nil, {
    machine = MACHINE, faction = f.id, behavior = "worker", color = f.color,
  })
  if not agent then return nil end
  if i then
    owner[i] = agent.id
    agent.slot = i
  end
  local e = agent.entity
  if not unarmed then
    e.get_inventory(defines.inventory.character_guns).insert({ name = T.worker_gun, count = 1 })
    e.get_inventory(defines.inventory.character_ammo).insert({ name = T.worker_ammo, count = T.worker_ammo_keep })
  end
  if free or unarmed then agent.free_kit = true end
  if free and not unarmed then kit_give(f, e) end -- EFFONDREMENT : kit offert, retiré du corps à la mort (parade du kit)
  f.engineers[agent.id] = true
  f.engineers_count = f.engineers_count + 1
  home_slot(agent, f) -- case attribuée dès le recrutement (lot IA1-a)
  Brain.attach(agent, tick, "idle")
  return agent
end

--- Lot CRAFT-PARALLELE : le PNJ a-t-il une fabrication en arrière-plan (file en cours ou produits pas encore déposés) ?
function Worker.crafting(agent) return agent.bg ~= nil end

--- Lot REARMEMENT : journal de MESURE [FO-REARMEMENT], toutes les 5 min par équipe (aucune décision ne le lit) : PNJ, armés (pistolet),
--- armés à emplacement VIDE, rechargements et chargeurs depuis le début, plancher, chargeurs au coffre.
function Worker.rearm_report(f, tick)
  if not (f and f.team) or tick - (f.team.rearm_log or -1000000) < 5 * 3600 then return end
  f.team.rearm_log = tick
  local n, gun, empty = 0, 0, 0
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    local e = a and a.entity
    if e and e.valid then
      n = n + 1
      local guns = e.get_inventory(defines.inventory.character_guns)
      if guns and guns.get_item_count(T.worker_gun) > 0 then
        gun = gun + 1
        local ammo = e.get_inventory(defines.inventory.character_ammo)
        if not ammo or ammo.is_empty() then empty = empty + 1 end
      end
    end
  end
  local r = f.team.rearm or { n = 0, mags = 0 }
  log(string.format("[FO-REARMEMENT] %s minute %.1f | PNJ %d, armes %d, arme vide %d ; rechargements %d (%d chargeurs) depuis le debut ; " ..
    "plancher %d, coffre %d chargeur(s), regle %s", tostring(f.key or "?"), tick / 3600, n, gun, empty, r.n, r.mags,
    (f.hq and f.hq.valid) and rearm_floor(f) or 0, (f.hq and f.hq.valid) and Stock.count(f, T.worker_ammo) or 0,
    T.rearm_on and "rechargement" or "avant"))
end

function Worker.idle_count(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    -- Lot CRAFT-PARALLELE : un PNJ sans tâche qui fabrique en arrière-plan n'est pas inactif pour le frein des recrues (avant ce lot,
    -- il était dans sa tâche « craft » : même compte). Cohérence : effet propre non séparé du bruit des graines au moteur simulé.
    if a and not a.task and not a.bg then n = n + 1 end
  end
  return n
end

function Worker.counts(f)
  local states = {}
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a then
      local key = a.task and a.task.kind or a.state
      states[key] = (states[key] or 0) + 1
    end
  end
  return states
end

-- EFFONDREMENT, parade du kit offert : 1. la mort note la fiche du kit (le personnage est encore valide, ses inventaires déjà vides) ;
-- les fiches oubliées (mort sans corps rendu) partent après Sp.KIT_TTL.
Events.on_died(function(e)
  local ent = e.entity
  local ns = kit_ns()
  -- hors de l'intérêt déclaré (personnage d'une force autre que « enemy ») : rien, pas même la purge (lot MORTS, tests/morts_test.lua P3)
  if not (ns and ent and ent.valid and ent.unit_number and ent.type == "character" and ent.force.name ~= "enemy") then return end
  local tick = e.tick or game.tick
  local old = {}
  for u, d in pairs(ns.dead) do if tick - d.tick > Sp.KIT_TTL then old[#old + 1] = u end end
  table.sort(old)
  for _, u in ipairs(old) do ns.dead[u] = nil end
  local k = ns.units[ent.unit_number]
  if not k then return end
  ns.units[ent.unit_number] = nil
  ns.dead[ent.unit_number] = { fid = k.fid, ammo = k.ammo, paid = k.paid, tick = tick }
end, { types = { "character" }, ennemi = false })

-- 2. le corps rendu (on_post_entity_died) : le kit offert en est retiré (Sp.kit_take), détruit ; la cargaison reste.
-- Le bus (events.lua) ne filtre pas ; le FILTRE MOTEUR est posé ici, à on_init et on_load (comme script/team/reparation.lua) : le
-- moteur ne lève plus l'événement que pour les personnages (relecture de revue-0657, accord du lead, 7/11). LIMITE : tout autre abonné du
-- bus à on_post_entity_died ne verrait plus, lui aussi, que les personnages (noté dans script/core/events.lua).
Events.on(defines.events.on_post_entity_died, function(e)
  local u = e.unit_number
  if not u then return end
  local ns = kit_ns()
  local d = ns and ns.dead[u]
  if not d then return end
  ns.dead[u] = nil
  for _, c in ipairs(e.corpses or {}) do
    if c.valid and c.type == "character-corpse" then
      local inv = c.get_inventory(defines.inventory.character_corpse)
      if inv and inv.valid then
        local present = { gun = inv.get_item_count(T.worker_gun), ammo = inv.get_item_count(T.worker_ammo) }
        local gun, ammo = Sp.kit_take({ gun = 1, ammo = d.ammo }, present, d.paid)
        if gun > 0 then gun = inv.remove({ name = T.worker_gun, count = gun }) end
        if ammo > 0 then ammo = inv.remove({ name = T.worker_ammo, count = ammo }) end
        local tk = ns.taken[d.fid] or { gun = 0, ammo = 0 }
        ns.taken[d.fid] = tk
        tk.gun, tk.ammo = tk.gun + gun, tk.ammo + ammo
        local f = State.faction(d.fid)
        log(Sp.kit_text({ key = f and (f.key or "player") or tostring(d.fid), unit = u, gun = gun, ammo = ammo, kept = present.ammo - ammo,
          total_gun = tk.gun, total_ammo = tk.ammo, minutes = (e.tick or game.tick) / 3600 }))
      end
      break
    end
  end
end)
Worker.KIT_POST_FILTER = { { filter = "type", type = "character" } }
local function kit_post_filter() script.set_event_filter(defines.events.on_post_entity_died, Worker.KIT_POST_FILTER) end
Events.on_init(kit_post_filter)
Events.on_load(kit_post_filter)

Registry.on_removed(function(agent)
  -- EFFONDREMENT (parade du kit offert) : un PNJ renvoyé (sans mort) n'a plus de fiche ; mort, sa fiche est déjà passée à `dead`
  local kns = kit_ns()
  if kns and agent.unit then kns.units[agent.unit] = nil end
  if not agent.faction then return end
  local f = State.faction(agent.faction)
  if not f or not f.engineers[agent.id] then return end
  release_slot(f, agent)
  Board.release(f, agent) -- lot IA3-b : réservation d'un PNJ disparu rendue au libre (ce qu'il portait est perdu, F253)
  f.engineers[agent.id] = nil
  f.engineers_count = (f.engineers_count or 1) - 1
  if f.stats then f.stats.engineers_lost = (f.stats.engineers_lost or 0) + 1 end
  -- EFFONDREMENT (filet de recul, décision du DC, 7/11 vers 16 h 56) : une recrue GRATUITE (agent.free_born, posé en E4) TUÉE moins de
  -- Sp.RECUL_VITE ticks après son arrivée double l'attente de la suivante (shared/team/spirale.lua) ; un renvoi (sans cause) ne compte pas.
  if f.is_player and f.team and agent.free_born and agent.death_cause then
    local now = game.tick
    f.team.recul = Sp.recul_death(f.team.recul, agent.free_born, now)
    if now - agent.free_born < Sp.RECUL_VITE then
      log(Sp.recul_text({ key = f.key or "player", age = now - agent.free_born, wait = f.team.recul.wait, minutes = now / 3600 }))
    end
  end
  -- Lot IA1-b2 (mesure) : PNJ TUÉ (cause connue) : tâche, distance au QG, cause ; tués par les ennemis comptés à part.
  if agent.death_cause and f.stats then
    if agent.death_cause:find("/enemy:", 1, true) then f.stats.lost_enemy = (f.stats.lost_enemy or 0) + 1 end
    local p = agent.death_pos
    local d = (p and f.hq_pos) and math.floor(math.sqrt(dist2(p, f.hq_pos))) or -1
    local t = agent.task
    log(string.format("[FO-TEAM] %s : PNJ %d tue (%s) a %d tuiles du QG, tache %s%s, %.1f min ; position %s, poste %s", f.key or "player",
      agent.id, agent.death_cause, d, t and t.kind or "aucune", (t and t.fond) and " (fond)" or "",
      game.tick / 3600, p and string.format("(%d, %d)", math.floor(p.x), math.floor(p.y)) or "inconnue",
      t and t.outpost ~= nil and tostring(t.outpost) or "aucun"))
    -- Lot CENTRALE-GARDE : porteur tué en allant poser les tourelles de la centrale : pause de la garde (comme un avant-poste meurtrier)
    if t and t.kind == "fortify" and t.outpost == "plant" then GardeCentrale.on_lost(f, agent.id, agent.death_cause) end
    -- Lot DEFENSE-FRONT : porteur tué en allant renforcer une cellule du front : la cellule se repose (T.lethal_ticks)
    if t and t.kind == "fortify" and t.outpost == "front" then Front.on_lost(f, t.cell_key, agent.death_cause) end
    if t and t.kind == "fortify" and t.outpost == "reserve" then DefStock.on_lost(f, t.cell_key, agent.death_cause) end -- lot DEFENSE-STOCK
    if t and t.kind == "fortify" and t.outpost == "ilot" then Ilots.on_lost(f, agent.id, agent.death_cause) end -- lot ILOTS-MURS
    -- Lot SCALE (correction après revue) : QG OCCUPÉ par les biters (factions) : T.hq_lethal_deaths PNJ tués par la force
    -- « enemy » à moins de Worker.SAFE_HOME tuiles du QG en moins de T.hq_lethal_window : plus de recrue pendant
    -- T.hq_lethal_ticks (script/team/team.lua, view.hold_recruits). Dates gardées : les T.hq_lethal_deaths dernières.
    if not f.is_player and agent.death_cause:find("/enemy:", 1, true) and p and f.hq_pos
      and dist2(p, f.hq_pos) <= Worker.SAFE_HOME * Worker.SAFE_HOME then
      local hd = f.hq_deaths or {}
      f.hq_deaths = hd
      hd[#hd + 1] = game.tick
      while #hd > T.hq_lethal_deaths do table.remove(hd, 1) end
      if #hd >= T.hq_lethal_deaths and hd[#hd] - hd[1] <= T.hq_lethal_window
        and not (f.hq_lethal_tick and game.tick - f.hq_lethal_tick < T.hq_lethal_ticks) then
        f.hq_lethal_tick = game.tick
        f.stats.hq_lethal = (f.stats.hq_lethal or 0) + 1
        log(string.format("[FO-TEAM] %s : QG occupe par les biters (%d PNJ tues a moins de %d tuiles en %.1f min) : aucune recrue pendant %d min, a %.1f min",
          f.key or "?", #hd, Worker.SAFE_HOME, (hd[#hd] - hd[1]) / 3600, T.hq_lethal_ticks / 3600, game.tick / 3600))
      end
    end
    -- Lot IA1-b2 (défendre d'abord) : l'avant-poste vers lequel allait le PNJ tué devient MEURTRIER (date gardée) : le
    -- cerveau n'y envoie plus personne pendant T.lethal_ticks, sauf pour y poser des tourelles.
    local oid = t and (t.outpost or (type(t.post) == "number" and t.post) or nil)
    if not oid and t and type(t.group) == "string" and t.group:sub(1, 1) == "o" then oid = tonumber(t.group:sub(2)) end
    local o = oid and f.outposts and f.outposts[oid]
    if o then o.lethal_tick = game.tick end
    -- Lot IA-V2 (même banc : PNJ tués par vagues, 4 à 6 au même endroit en moins d'une minute, chacun pendant que les
    -- autres continuaient à miner) : votre équipe, PNJ tué loin du QG : les autres PNJ au travail à moins de
    -- Poles.LOSS_RADIUS tuiles du lieu de la perte rentrent au QG (tâche abandonnée, « danger »), sauf la défense.
    if f.is_player and p and f.hq_pos and dist2(p, f.hq_pos) > Worker.SAFE_HOME * Worker.SAFE_HOME then
      Worker.recall_near(f, p, Poles.LOSS_RADIUS, game.tick, nil)
    end
    -- Constructeur de votre équipe tué : les sites connus à moins de 64 tuiles du lieu de la mort sont écartés (les vers
    -- n'existent qu'une fois leur chunk généré, à l'approche : la vérification du site avant le départ ne les voit pas ;
    -- essai 10, graine 314159265 : 4 constructeurs tués au même endroit).
    if f.is_player and t and t.kind == "build" and p then
      for _, s in ipairs(f.prospects or {}) do
        if dist2(s, p) <= 64 * 64 then Sites.mark_unreachable(s, game.tick) end
      end
    end
  end
  if agent.task then
    if agent.task.site and not agent.task.site_used then
      Sites.release(agent.task.site)
      Sites.mark_unreachable(agent.task.site, game.tick)
    end
    Board.finish(f, agent.task, false, game.tick)
  end
  -- Lot CRAFT-PARALLELE : PNJ disparu (tué, renvoyé) avec une fabrication en arrière-plan : la tâche « craft » est rendue (échec).
  if agent.bg then
    local jobs = {}
    for k, j in ipairs(agent.bg.jobs) do jobs[k] = j end
    for _, j in ipairs(jobs) do bg_close_job(agent, f, j, false, game.tick, "mort") end
  end
end)

Worker._has_deposit = has_deposit -- tests hors jeu seulement (tests/ia3k_moteur_test.lua, tenue : C3)
Worker._mining_entity = mining_entity -- tests hors jeu seulement (tests/tourelle_journal_test.lua, lot TOURELLE-JOURNAL)

return Worker
