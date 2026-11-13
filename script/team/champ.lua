--[[
  Lot CHAMP, côté RUNTIME (règle pure : shared/team/champ.lua ; contrôle : shared/team/champ_verif.lua). Retour du DC du 2/11 : « ça ne
  fait pas le comment mais dit OK, on met ce pattern là et puis on verra bien » ; « tout le champ on le remplace, on fout des rangées de
  foreuses électriques [...] des rangées de N fours justement en fonction du débit ».

  Deux services, lus par script/team/migration_champ.lua (la migration d'un avant-poste de paires thermiques, par BANDES) :
    - Champ.frame(f, surface, o) : plan ENTIER du gisement de l'avant-poste `o` (lu au moteur : tuiles du gisement, eau, bâtiments,
      tuiles réservées par d'autres projets ; caractéristiques lues aux prototypes) ; rend le cadre figé (axe, phase, sortie, bords,
      décalages des rangées), les bandes dans l'ordre de pose (celles qui portent des paires d'abord, puis la plus proche du QG) et le
      journal [FO-CHAMP] du plan (contrôle de shared/team/champ_verif.lua : couverture, courant, tapis, fonderie) ;
    - Champ.band(f, surface, o, frame, pr) : la bande `pr` seule, au même cadre (entités nommées, emprise, paires recouvertes).
  Et le planificateur du site « champ » du plan directeur (Build.SITES.champ, spec.champ = { oid, pr, frame }) : la bande devient un
  projet ordinaire (réserve au coffre, défrichage, fantômes, PNJ bâtisseurs, fils, coffres de combustible remplis, coffres de sortie
  vidés), raccordé au réseau par une chaîne de poteaux quand aucun poteau alimenté n'est à portée.
  Noms : T (foreuse électrique, réceptacle de l'avant-poste, combustible), D (bras, coffre, poteaux), convoyeurs débloqués (Conv).
  Déterminisme : listes triées, aucun `pairs` dans une décision ; rien dans global ici (le cadre est gardé par la migration).
]]

local T = require("shared.team.config")
local D = require("shared.team.petrole_donnees")
local P = require("shared.team.plan")
local Ch = require("shared.team.champ")
local Cv = require("shared.team.champ_verif")
local Sa = require("shared.team.champ_saut") -- lot FONDERIE : découpe d'une bande trop grosse en projets liés
local Cd = require("shared.team.champ_dedupe") -- lot COMBUSTIBLE-MIGRATION : une pièce n'est écartée que si le détenteur de sa tuile porte la même (règle pure)
local Rv = require("shared.team.ravitaillement") -- lot COMBUSTIBLE : fours du champ ravitaillés à la main (Rv.field_burners)
local Ln = require("shared.team.champ_lien") -- revue-fonderie (point 7) : lecteur des projets liés du réseau du charbon
local LB = require("script.team.ligne_bande") -- lot RACCORD-BANDE 2 : ligne de poteaux d'une bande lointaine
local Ra = require("shared.team.champ_raccord") -- lot FONDERIE : tous les poteaux d'une bande rejoignent le réseau alimenté
local Storage = require("script.core.storage")
local Events = require("script.core.events")
local Db = require("shared.team.debit")
local Paires = require("shared.team.pose_paires")
local State = require("script.faction.state")
local Build = require("script.team.build")
local Stock = require("script.team.stock") -- lot COMBUSTIBLE : combustible au coffre du QG, au journal [FO-CHAMP-COMBUSTIBLE]
local Conv = require("script.team.convoyeurs")
local Fal = require("script.team.falaise") -- lot OBSTACLES : emprise réelle des falaises
local Profiler = require("script.core.profiler") -- lot PERF3 : portées fines (mesure seulement)
local Gens = require("script.team.generateurs") -- lot X10-S4 : registre des génératrices (plus de recherche sur toute la surface)

local Champ = {}

Champ.SIB_R = 64 -- tuiles : deux avant-postes du même minerai plus proches sont sur le même gisement (un seul champ)

Champ.CFG = {
  radius = 96,      -- tuiles autour de l'avant-poste où le gisement est lu
  side = 8,         -- foreuses par côté et par groupe au plus (une bande coûte ce que sa fonderie coûte : la suivante l'agrandit)
  margin_v = 10,    -- tuiles lues en travers au-delà du gisement
  margin_u = 120,   -- tuiles lues le long de l'axe au-delà du gisement (fonderies)
  chain_r = 160,    -- tuiles : poteau alimenté le plus loin cherché pour raccorder une bande
  chain_far = 480,  -- (lot FONDERIE) seconde recherche quand rien n'est vu à chain_r (chaîne de 64 poteaux au plus, P.pole_chain)
  logs = 40,        -- lignes [FO-CHAMP] au plus par équipe
  charge = 40,      -- combustible posé avec chaque coffre de combustible d'une fonderie (deux fours de pierre : 15 min)
  drill_rank = 7,   -- rang de pose des foreuses du champ (P.sort_build : après les tapis, rang 5)
  -- lot FONDERIE
  coal_r = 192,     -- tuiles autour du champ où le gisement de charbon de la colonne est cherché (320 au lot3 : des tracés de centaines de
                    -- tuiles faisaient attendre les bandes ; le tracé est désormais plafonné, Co.ROUTE_MAX)
  cut_wait = 5 * 3600, -- lot COMBUSTIBLE-MIGRATION : attente au plus (ticks) d'un réseau du charbon dont le tronc est coupé par un autre projet, avant de l'accepter
  cut_poll = 600,   -- lot UPS-2 : pendant cette attente, un essai de plan toutes les 10 s au lieu de chaque passe (Cd.next_try ; la fin de l'attente reste au même tick)
  coal_prio = 52,   -- priorité du projet « réseau du charbon » d'un côté du champ : celle des bandes (Mg.CFG.prio). À 80 (alimentation d'une
                    -- centrale, lot4-20261020), emerald était en retard dès 30 min (14 fours sur 59, 2 735 plaques qui dorment, 10 PNJ contre 18)
  -- (3/11, lot4 et lot5 : 6 projets séparés du réseau du charbon sur 24 jamais finis : bande refusée après la demande du réseau, matières jamais
  -- réunies, tâches jamais prises ; leurs bandes, finies, restaient sans charbon) : le réseau du charbon est posé par la PREMIÈRE BANDE de son
  -- côté, dans son projet (une bande ne produit pas sans lui ; la migration attend ses plaques). Taille bornée : charbon à coal_r tuiles au plus,
  -- tracé à Co.ROUTE_MAX. Vrai : projet séparé (code gardé, éteint).
  coal_project = false,
  band_max = 400,   -- (lot FONDERIE) entités d'un projet de bande au plus : au-delà, ses réseaux du charbon vont dans des projets LIÉS (Sa.split)
                    -- 0.6.76 (directive du DC : on pose ce qu'on a) : 800 -> 400. Mesure (123456789, fo-logs/2026-11-09_V0675-B et V0676-B) : la bande -30 du
                    -- joueur, 299 pieces propres + 421 pieces du reseau de charbon = 720 <= 800, non scindee, attend 627 tapis et 1 081 plaques de 24 a 86 min,
                    -- 0 bande finie en 90 min. A 400, le reseau de charbon part en projet LIE (Sa.split) et la bande de 299 pieces se paie seule.
  coal_window = 28, -- demi-côté de la fenêtre lue autour de sa tuile la plus proche (shared/team/champ_colonne.lua, Co.WINDOW = 24)
  route_margin = 24,-- tuiles lues autour du champ et du charbon pour le tracé (eau, bâtiments, souterrains)
  charge_tete = 200,-- charbon posé avec le coffre de tête d'une colonne SANS voie de charbon (24 fours de pierre : 6 min)
  amorce = 5,       -- charbon posé avec chaque four d'une colonne (une fois) : la limite d'insertion d'un bras (mesurée, banc-2) ; sans elle,
                    -- les fours se garnissent un à un depuis la tête et la queue attend plusieurs minutes
}

local function sorted_keys(t) return State.sorted_keys(t or {}) end

-- Lot FONDERIE : colonne à tapis seulement pour une PARTIE NEUVE dont le réglage de carte est allumé. La marque `neuve` n'est posée qu'à la
-- création de la partie (on_init) ; une sauvegarde d'avant le lot reçoit l'espace par on_configuration_changed, SANS la marque : réglage
-- éteint pour elle, comportement 0.6.41 (fonderie à coffres), rien ne change.
Champ.SETTING = "fo-war-fonderie-tapis"
Storage.declare("fonderie", function() return { neuve = false } end)
local function fonderie_ns()
  local ok, s = pcall(Storage.ns, "fonderie") -- (table persistante sans espace `fo` : moteur simulé des bancs hors jeu) -> éteint
  return ok and s or nil
end
function Champ.tapis()
  local s = fonderie_ns()
  if not (s and s.neuve) then return false end
  local ok, on = pcall(function() return settings.global[Champ.SETTING].value end)
  return ok and on == true
end
local function say_tapis()
  local s = fonderie_ns()
  log(string.format("[FO-FONDERIE] fonderie des champs a tapis : %s (partie %s)", Champ.tapis() and "oui" or "non",
    (s and s.neuve) and "creee avec le lot" or "d'avant le lot : fonderie a coffres gardee"))
end
Events.on_init(function() local s = fonderie_ns(); if s then s.neuve = true end; say_tapis() end)
Events.on_configuration_changed(say_tapis)
Build.TAPIS = Champ.tapis -- lu par script/team/build.lua (saut d'une foreuse de bande), sans require circulaire

-- Lot CHAMP (ordres « couvrir / ouvrir » de la capitalisation) : un champ se pose sur un avant-poste (f.outposts) ou sur un gisement SANS
-- avant-poste demandé par la capitalisation (f.migration.fields, numéros à partir de FIELD_BASE : jamais ceux d'un avant-poste).
Champ.FIELD_BASE = 100000

--- La cible d'un champ par son numéro : l'avant-poste, ou le gisement de la capitalisation, ou nil. Lecture seule.
function Champ.target(f, id)
  if id == nil or not f then return nil end
  local o = f.outposts and f.outposts[id]
  if o then return o end
  local ms = f.migration
  return ms and ms.fields and ms.fields[id] or nil
end

local function say(f, text)
  f.champ_logs = (f.champ_logs or 0) + 1
  if f.champ_logs > Champ.CFG.logs then return end
  log(string.format("[FO-CHAMP] %s : %s a %.1f min", f.key or "player", text, game.tick / 3600))
end
Champ.say = say

---------------------------------------------------------------------------------------------------
-- Lectures
---------------------------------------------------------------------------------------------------
local function enabled(f, item)
  local force = game.forces[f.force]
  local r = force and force.recipes[item]
  return r ~= nil and r.enabled == true
end

--- Lot FONDERIE : pièce de logistique la moins chère (vitesse de tapis, puis nom) d'un type de prototype (« splitter »,
--- « underground-belt ») dont la recette de l'objet est débloquée pour la force : { name, maxd } ou nil. Aucun nom écrit ici.
local function logistic(f, typ)
  local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = typ } })
  local list = {}
  for name, pr in pairs(protos) do
    local items = pr.items_to_place_this
    if items and items[1] and not pr.has_flag("hidden") then
      list[#list + 1] = { name = name, speed = pr.belt_speed or 0, item = items[1].name, maxd = pr.max_underground_distance,
        w = pr.tile_width, h = pr.tile_height }
    end
  end
  table.sort(list, function(a, b) if a.speed ~= b.speed then return a.speed < b.speed end return a.name < b.name end)
  for _, x in ipairs(list) do if enabled(f, x.item) then return x end end
  return nil
end

--- Caractéristiques lues aux prototypes, et les noms : (data, names) ou nil, raison.
function Champ.data(f, kind)
  local spec = T.outposts[kind]
  if not spec then return nil, "avant-poste inconnu" end
  local dp = game.entity_prototypes[T.DRILL_ELECTRIC]
  local rp = game.entity_prototypes[spec.resource]
  if not (dp and rp and dp.mining_drill_radius and rp.mineable_properties) then return nil, "foreuse ou minerai" end
  local size = dp.tile_width
  local reach = math.floor((2 * dp.mining_drill_radius - size) / 2 + 0.5)
  local force = game.forces[f.force]
  local prod = force and force.mining_drill_productivity_bonus or 0
  local rate = dp.mining_speed / (rp.mineable_properties.mining_time or 1) * (1 + prod)
  local pole
  for _, n in ipairs(D.POLES) do
    local pp = game.entity_prototypes[n]
    if pp and not pole and enabled(f, n) then pole = { name = n, proto = pp } end
  end
  if not pole then
    local n = D.POLES[#D.POLES]
    pole = { name = n, proto = game.entity_prototypes[n] }
  end
  if not pole.proto then return nil, "poteau" end
  local usable = Conv.usable(f)
  local belts, bnames = {}, {}
  for _, bt in ipairs(Conv.belts()) do
    if usable(bt.name) then belts[#belts + 1] = { lane = Db.lane_capacity(bt.speed) }; bnames[#bnames + 1] = bt.name end
  end
  if #belts == 0 then return nil, "tapis" end
  local data = {
    drill = { size = size, reach = reach, rate = rate },
    pole = { reach = math.floor(pole.proto.supply_area_distance - 0.5 + 1e-6), wire = pole.proto.max_wire_distance },
    belts = belts,
  }
  local names = { drill = T.DRILL_ELECTRIC, pole = pole.name, belts = bnames, arm = D.ARM, chest = D.CHEST, fuel = T.fuel,
    resource = spec.resource, cats = dp.resource_categories or {} } -- (lot MELANGE : catégories de ressources que la foreuse sait miner)
  local fp = game.entity_prototypes[spec.sink]
  if fp and fp.type == "furnace" then
    local rec = game.recipe_prototypes[spec.product]
    local per = 1
    for _, ing in ipairs(rec and rec.ingredients or {}) do if ing.name == spec.resource then per = ing.amount end end
    if not (rec and rec.energy and rec.energy > 0) then return nil, "recette du four" end
    data.furnace = { size = fp.tile_width, rate = (fp.crafting_speed or 1) * per / rec.energy, fuel = fp.burner_prototype ~= nil }
    -- lot FONDERIE : charbon brûlé par un four (énergie du prototype, pouvoir du combustible) : taille de la ligne de charbon
    if data.furnace.fuel then
      local cp = game.item_prototypes[T.fuel]
      local eu = (fp.energy_usage or 0) * 60
      if cp and cp.fuel_value and cp.fuel_value > 0 and eu > 0 then data.furnace.fuel_rate = eu / cp.fuel_value end
    end
    names.furnace = spec.sink
  end
  local ap = game.entity_prototypes[D.ARM]
  data.inserter = { rate = ap and ap.inserter_rotation_speed and ap.inserter_rotation_speed * 60 or 0.83 }
  -- lot FONDERIE : colonne à tapis pour un cadre NEUF, réglage allumé (Champ.tapis) ; éteint, un cadre neuf reste la fonderie à coffres
  -- (0.6.41). Répartiteur et souterrain SEULEMENT si leur recette est débloquée ; leurs noms sont lus même éteint (lecture seule) : un cadre
  -- déjà en colonne (réglage éteint en cours de partie) rejoue ses bandes avec eux
  if Champ.tapis() then data.design = "colonne" end
  local sp, ug = logistic(f, T.LOGISTIC_TYPES.splitter), logistic(f, T.LOGISTIC_TYPES.underground)
  data.logistics = { splitter = sp ~= nil, underground = ug and ug.maxd and ug.maxd >= 2 and ug.maxd or nil }
  names.splitter, names.underground = sp and sp.name, ug and ug.name
  if sp then P.declare_size(sp.name, sp.w or 2, sp.h or 1, true) end
  if ug then P.declare_size(ug.name, 1, 1) end
  local cr = game.entity_prototypes[T.outposts.coal.resource]
  if cr and cr.mineable_properties then
    data.coal_rate = dp.mining_speed / (cr.mineable_properties.mining_time or 1) * (1 + prod)
  end
  -- emprises des pièces pour le plan directeur (P.tiles_of) : lues aux prototypes
  for _, n in ipairs({ names.drill, names.pole, names.arm, names.chest, names.furnace or names.drill }) do
    local pp = game.entity_prototypes[n]
    if pp then P.declare_size(n, pp.tile_width, pp.tile_height) end
  end
  return data, names
end

--- Lot FONDERIE : tuiles de charbon du gisement le plus proche du champ (fenêtre autour de la tuile la plus proche de `pos`, triées) et
--- leur boîte, ou nil.
local function coal_tiles(surface, pos)
  local res = T.outposts.coal.resource
  local found = surface.find_entities_filtered({ position = pos, radius = Champ.CFG.coal_r, name = res })
  local best, bd
  for _, r in ipairs(found) do
    if r.valid then
      local d = (r.position.x - pos.x) ^ 2 + (r.position.y - pos.y) ^ 2
      if not bd or d < bd or (d == bd and (r.position.x < best.x or (r.position.x == best.x and r.position.y < best.y))) then
        best, bd = { x = r.position.x, y = r.position.y }, d
      end
    end
  end
  if not best then return nil end
  -- (lot FONDERIE, lot2-20261020) jusqu'à 3 gisements : fenêtres autour de la tuile la plus proche, puis de la plus proche hors des fenêtres
  -- déjà prises (le plus proche peut être couvert par les paires thermiques de l'équipe : la règle pure garde celui qui porte le plus)
  local W = Champ.CFG.coal_window
  local cand = {}
  for _, r in ipairs(found) do
    if r.valid then cand[#cand + 1] = { x = r.position.x, y = r.position.y, d = (r.position.x - pos.x) ^ 2 + (r.position.y - pos.y) ^ 2 } end
  end
  table.sort(cand, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  local centers = {}
  for _, c in ipairs(cand) do
    if #centers >= 3 then break end
    local inside = false
    for _, k in ipairs(centers) do if math.abs(c.x - k.x) <= W and math.abs(c.y - k.y) <= W then inside = true end end
    if not inside then centers[#centers + 1] = c end
  end
  local list = {}
  for _, c in ipairs(cand) do
    local keep = false
    for _, k in ipairs(centers) do if math.abs(c.x - k.x) <= W and math.abs(c.y - k.y) <= W then keep = true end end
    if keep then list[#list + 1] = { math.floor(c.x), math.floor(c.y) } end
  end
  table.sort(list, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  local flat = {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, t in ipairs(list) do
    flat[#flat + 1] = t[1]; flat[#flat + 1] = t[2]
    x0, y0, x1, y1 = math.min(x0, t[1]), math.min(y0, t[2]), math.max(x1, t[1]), math.max(y1, t[2])
  end
  return flat, { x0, y0, x1, y1 }
end

--- Tuiles (liste plate) du gisement de l'avant-poste : composante connexe des tuiles de minerai autour de son centre.
local function ore_tiles(surface, o)
  local res = T.outposts[o.kind].resource
  local raw = {}
  for _, r in ipairs(surface.find_entities_filtered({ position = o.pos, radius = Champ.CFG.radius, name = res })) do
    if r.valid then raw[#raw + 1] = { x = r.position.x, y = r.position.y } end
  end
  local comp = Paires.nearest_component(raw, Paires.GAP, o.pos) -- lot COUT-600 : = component(sorted(...)) sans trier les gisements voisins
  local out = {}
  for _, t in ipairs(comp) do out[#out + 1] = math.floor(t.x); out[#out + 1] = math.floor(t.y) end
  return out
end

local function add_box(set, e, what)
  local bb = e.bounding_box
  for x = math.floor(bb.left_top.x + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1 do
    for y = math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.y - 0.01) - 1 do set[Ch.key(x, y)] = what or true end
  end
end

--- Tuiles NÔTRES (libres pour le plan) : paires de l'avant-poste et de ses voisins du même minerai sur le gisement (Champ.SIB_R), et
--- entités des bandes déjà demandées pour lui.
local function mine_of(f, o)
  local mine = {}
  local r2 = Champ.SIB_R * Champ.SIB_R
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local q = f.outposts[oid]
    if q == o or (q.kind == o.kind and (q.pos.x - o.pos.x) ^ 2 + (q.pos.y - o.pos.y) ^ 2 <= r2) then
      for _, l in ipairs({ q.drill_list or {}, q.sinks or {} }) do
        for _, e in ipairs(l) do if e.valid then add_box(mine, e) end end
      end
    end
  end
  local b = f.build
  for _, pid in ipairs(b and b.order or {}) do
    local p = b.projects[pid]
    if p and p.spec and p.spec.champ and p.spec.champ.oid == o.id then
      for _, e in ipairs(p.ents) do for _, t in ipairs(P.tiles_of(e)) do mine[Ch.key(t[1], t[2])] = true end end
    end
  end
  return mine
end

--- Lot MELANGE (retour du DC du 3/11 : « les minerais de charbon prennent la place des minerais de fer sur les convoyeurs ») : tuiles
--- d'une AUTRE ressource que la foreuse sait miner (catégorie lue au prototype), dans le rectangle ; { [Ch.key] = true }, nombre.
local CAT = {} -- mémoire LOCALE (prototypes seulement)
local function category(name)
  local c = CAT[name]
  if c == nil then
    local pp = game.entity_prototypes[name]
    c = pp and pp.resource_category or false
    CAT[name] = c
  end
  return c
end
Champ.category = category

--- Rend les tuiles d'une AUTRE ressource minable (lot MELANGE), leur nombre et, lot TAMPON-MINERAI, TOUTES les tuiles de ressource lues
--- (n'importe quel nom ou catégorie : le même minerai d'un AUTRE gisement compris), où aucune fonderie ne se pose (Sm.forbidden).
local function foreign_in(surface, res, cats, x0, y0, x1, y1)
  local out, n, all = {}, 0, {}
  for _, r in ipairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1 + 1, y1 + 1 } }, type = "resource" })) do
    if r.valid then
      local k = Ch.key(math.floor(r.position.x), math.floor(r.position.y))
      all[k] = true
      local c = r.name ~= res and category(r.name)
      if c and cats[c] and not out[k] then out[k] = true; n = n + 1 end
    end
  end
  return out, n, all
end

--- Tuiles où rien ne se pose dans le rectangle : eau, bâtiments (arbres et rochers exceptés : défrichés), tuiles réservées par un
--- autre projet du plan directeur ; les tuiles `mine` restent libres.
local function blocked_in(f, surface, x0, y0, x1, y1, mine, soft_out, occ_libre)
  local blocked = {}
  for _, t in ipairs(surface.find_tiles_filtered({ area = { { x0, y0 }, { x1, y1 } }, collision_mask = "water-tile" })) do
    blocked[Ch.key(math.floor(t.position.x), math.floor(t.position.y))] = "eau"
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, collision_mask = "object-layer" })) do
    local soft = e.type == "tree" or e.type == "simple-entity" or (e.force.name == "neutral" and e.type ~= "cliff")
    if not soft and e.type ~= "resource" and e.type ~= "cliff" then add_box(blocked, e, e.name) end
    -- lot FONDERIE : arbres et rochers (défrichables) relevés à part : le tracé du charbon les évite
    if soft and soft_out and (e.type == "tree" or e.type == "simple-entity") then add_box(soft_out, e) end
  end
  -- lot OBSTACLES : une falaise bloque son emprise RÉELLE (orientation), pas la boîte générique de bounding_box (shared/team/falaise.lua)
  Fal.mark(surface, x0, y0, x1, y1, function(tx, ty) blocked[Ch.key(tx, ty)] = "cliff" end)
  Fal.mark_learned(f.build and f.build.hard, function(tx, ty) blocked[Ch.key(tx, ty)] = "cliff" end)
  local occ = f.build and f.build.occ or {}
  local cor = Build.couloirs(f) -- lot ÉTAGE 5 : la bande ne se pose pas sur un couloir d'accès d'avant-poste
  for x = math.floor(x0), math.ceil(x1) do
    for y = math.floor(y0), math.ceil(y1) do
      local k = P.tkey(x, y)
      if occ[k] and not blocked[Ch.key(x, y)] and not (occ_libre and occ_libre(x, y, occ[k])) then blocked[Ch.key(x, y)] = "reserve" end -- occ_libre : le mall ouvre à la chaîne les tuiles que ses rangées n'utilisent jamais
      if cor[k] and not blocked[Ch.key(x, y)] then
        blocked[Ch.key(x, y)] = "couloir"
        if f.stats then f.stats.couloir_champ = (f.stats.couloir_champ or 0) + 1 end -- revue (B3)
      end
    end
  end
  return blocked
end

--- Spec de la règle pure pour l'avant-poste `o` : (spec, names) ou nil, raison.
local function spec_of(f, surface, o, frame, only)
  local data, names = Champ.data(f, o.kind)
  if not data then return nil, names end
  local ore = ore_tiles(surface, o)
  if #ore < 2 then return nil, "gisement epuise" end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for i = 1, #ore - 1, 2 do
    x0, x1 = math.min(x0, ore[i]), math.max(x1, ore[i])
    y0, y1 = math.min(y0, ore[i + 1]), math.max(y1, ore[i + 1])
  end
  local axis = frame and frame.axis or ((y1 - y0 > x1 - x0) and "y" or "x")
  local mu, mv = Champ.CFG.margin_u, Champ.CFG.margin_v
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  if axis == "x" then x0, x1, y0, y1 = x0 - mu, x1 + mu, y0 - mv, y1 + mv else x0, x1, y0, y1 = x0 - mv, x1 + mv, y0 - mu, y1 + mu end
  -- lot FONDERIE : un cadre NEUF d'un four à combustible lit aussi le gisement de charbon le plus proche, et la boîte lue va jusqu'à lui
  -- (le tracé du charbon ne passe que sur des tuiles lues) ; une bande seule rejoue le réseau gardé dans le cadre
  local coal, ugs
  if not frame and data.design == "colonne" and data.furnace and data.furnace.fuel and data.coal_rate then
    local box
    coal, box = coal_tiles(surface, { x = cx, y = cy })
    if box then
      local m = Champ.CFG.route_margin
      x0, y0, x1, y1 = math.min(x0, box[1] - m), math.min(y0, box[2] - m), math.max(x1, box[3] + m), math.max(y1, box[4] + m)
    end
  end
  local mine = mine_of(f, o)
  local soft = coal and {} or nil
  -- lot MELANGE : autres ressources minables autour du gisement (une foreuse se pose au plus côté + portée hors du minerai)
  local ox0, oy0, ox1, oy1 = math.huge, math.huge, -math.huge, -math.huge
  for i = 1, #ore - 1, 2 do
    ox0, ox1 = math.min(ox0, ore[i]), math.max(ox1, ore[i])
    oy0, oy1 = math.min(oy0, ore[i + 1]), math.max(oy1, ore[i + 1])
  end
  local fm = data.drill.size + 2 * data.drill.reach + 1
  -- F500 : relevées aussi sur tout le rectangle lu (x0..x1, y0..y1), où la fonderie se place : aucun four sur un autre gisement
  local foreign, nforeign, resources = foreign_in(surface, names.resource, names.cats, math.min(ox0 - fm, x0), math.min(oy0 - fm, y0),
    math.max(ox1 + fm, x1), math.max(oy1 + fm, y1))
  Profiler.fstart("champ:blocked")
  -- lot COMBUSTIBLE-MIGRATION : les tuiles que le cadre de cet avant-poste a retenues pour son réseau du charbon reporté lui restent libres
  local blocked = blocked_in(f, surface, x0, y0, x1, y1, mine, soft, function(_, _, owner) return Cd.own(owner, o.id) end)
  Profiler.fstop("champ:blocked")
  local spec = {
    ore = ore, blocked = blocked, mine = mine, soft = soft, foreign = foreign, nforeign = nforeign, resources = resources,
    drill = data.drill, pole = data.pole, belts = data.belts, furnace = data.furnace, inserter = data.inserter,
    target = f.hq_pos, max_side = Champ.CFG.side,
    design = data.design, logistics = data.logistics,
    window = { x0, y0, x1, y1 }, -- lot FONDERIE-BOUT : tuiles lues (obstacles connus) ; une colonne ailleurs ne sort pas de ce rectangle
  }
  if coal then
    spec.coal = { tiles = coal, rate = data.coal_rate }
    -- lot MELANGE : autres ressources minables autour du charbon lu (la ligne de foreuses de charbon n'en mine aucune : du fer ou de la
    -- pierre sur la voie de charbon la bouchent comme le charbon bouchait la voie de minerai)
    local cx0, cy0, cx1, cy1 = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #coal - 1, 2 do
      cx0, cx1 = math.min(cx0, coal[i]), math.max(cx1, coal[i])
      cy0, cy1 = math.min(cy0, coal[i + 1]), math.max(cy1, coal[i + 1])
    end
    spec.coal.foreign, spec.coal.nforeign = foreign_in(surface, T.outposts.coal.resource, names.cats, cx0 - fm, cy0 - fm, cx1 + fm, cy1 + fm)
    ugs = {}
    for _, e in ipairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = T.LOGISTIC_TYPES.underground })) do
      ugs[#ugs + 1] = { math.floor(e.position.x), math.floor(e.position.y) }
    end
    table.sort(ugs, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
    spec.ug_tiles = ugs
  end
  if frame then
    local fr = {}
    for _, k in ipairs(sorted_keys(frame)) do fr[k] = frame[k] end
    fr.only = only
    spec.frame = fr
  end
  return spec, names
end

---------------------------------------------------------------------------------------------------
-- Plans
---------------------------------------------------------------------------------------------------
local FRAME_PENDING = {} -- lot COUT-600 : { f, plan, spec, journal } des cadres dont la vérification attend sa pensée (Champ.flush)

--- Plan entier : (cadre, ordre des bandes { pr }, plan) ou nil, raison. Journal : une ligne [FO-CHAMP] par plan (écrite par Champ.flush).
function Champ.frame(f, surface, o)
  if f.build and f.build.occ then Cd.clear(f.build.occ, o.id) end -- lot COMBUSTIBLE-MIGRATION : un cadre refait libère les tuiles retenues par l'ancien
  Profiler.fstart("champ:frame-spec")
  local spec, names = spec_of(f, surface, o, nil, nil)
  Profiler.fstop("champ:frame-spec")
  if not spec then return nil, names end
  Profiler.dump("champ-frame", { spec = spec, cfg = Ch.CFG }) -- lot PERF3 : entrées du plan, bancs de détail seulement
  Profiler.fstart("champ:frame-plan")
  local plan, why = Ch.plan(spec)
  Profiler.fstop("champ:frame-plan")
  if not plan then return nil, why end
  -- Lot CC-SAUT (F515, mandat du DC du 10/11, 22 h 20) : le cadre figé fixe la place de la colonne de fours de TOUTES ses bandes futures (rejouée sans
  -- recherche) ; ses tuiles hors ressource sont retenues au plan dès maintenant, sous le marqueur du cadre (Cd.frame_tiles) : libres pour les projets de
  -- cet avant-poste, évitées par tous les autres (lignes de poteaux comprises). Avant, seules celles du réseau du charbon reporté l'étaient : la ligne de
  -- poteaux de l'avant-poste, planifiée entre la demande de la bande et son plan, prenait la place figée de sa colonne et la bande ENTIÈRE était refusée
  -- (référence 0.6.91, graine 314159265, joueur : projet 3 à 8,2 min, 17 foreuses ; puis le projet 19, 34 foreuses). Le minerai reste libre.
  if f.build and f.build.occ then
    local res = {}
    for i = 1, #spec.ore - 1, 2 do res[Ch.key(spec.ore[i], spec.ore[i + 1])] = true end
    local function is_res(x, y)
      local k = Ch.key(x, y)
      return res[k] or (spec.foreign and spec.foreign[k]) or false
    end
    local nres = Cd.reserve(f.build.occ, Cd.frame_tiles(plan.ents, is_res), o.id, P.tkey)
    if nres > 0 then
      log(string.format("[FO-CHAMP] %s : avant-poste %d : %d tuile(s) du cadre fige retenue(s) au plan (cadre:%d : colonnes, coffres, poteaux et tapis hors ressource des bandes futures) a %.1f min",
        f.key or "player", o.id, nres, o.id, game.tick / 3600))
    end
  end
  -- lot COUT-600 : la vérification du plan (Cv.verify : 0,2 M d'instructions à l'ordinaire, 4,7 M sur un champ de 600 %) ne sert qu'à la ligne de
  -- journal [FO-CHAMP] ci-dessous : elle part dans une pensée à part (Champ.flush), le plan et l'ordre des bandes sont rendus tout de suite
  -- ce qui occupe le gisement (hors de nos paires) : cause des tuiles que le champ ne couvre pas
  local why, keys = {}, {}
  for i = 1, #spec.ore - 1, 2 do
    local k = Ch.key(spec.ore[i], spec.ore[i + 1])
    local w = spec.blocked[k]
    if w and not spec.mine[k] then
      w = tostring(w)
      if not why[w] then why[w] = 0; keys[#keys + 1] = w end
      why[w] = why[w] + 1
    end
  end
  table.sort(keys)
  local occ = {}
  for _, w in ipairs(keys) do occ[#occ + 1] = w .. " " .. why[w] end
  -- ordre : bandes qui portent des paires de l'avant-poste (le plus de paires d'abord), puis la plus proche du QG en travers
  local hv = (plan.axis == "x") and f.hq_pos.y or f.hq_pos.x
  local pairs_in = {}
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid then
      local v = (plan.axis == "x") and d.position.y or d.position.x
      for _, bd in ipairs(plan.bands) do
        if v >= bd.pr and v < bd.pr + plan.pitch then pairs_in[bd.pr] = (pairs_in[bd.pr] or 0) + 1 end
      end
    end
  end
  local order = {}
  -- lot BANDE-GELEE : une bande sans groupe dont les foreuses attendent une fonderie (bd.orphans, lot COUPLAGE) reste dans l'ordre : demandée
  -- seule (Champ.band), elle reçoit sa colonne si elle trouve sa place alors, sinon elle est écartée comme toute bande vide ; elle passe APRÈS
  -- les bandes à fonderie (graine 123456789, scarlet : une telle bande demandée la première, refusée, retardait tout le champ)
  for _, bd in ipairs(plan.bands) do
    if #bd.groups > 0 or bd.orphans > 0 then
      order[#order + 1] = { pr = bd.pr, n = pairs_in[bd.pr] or 0, d = math.abs(bd.b - hv), wait = #bd.groups == 0 }
    end
  end
  table.sort(order, function(a, b)
    if a.wait ~= b.wait then return b.wait end
    if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
    if a.n ~= b.n then return a.n > b.n end
    if a.d ~= b.d then return a.d < b.d end
    return a.pr < b.pr
  end)
  local prs, with = {}, 0
  for _, it in ipairs(order) do prs[#prs + 1] = it.pr; if it.n > 0 then with = with + 1 end end
  -- lot FONDERIE : motif, charbon de chaque côté (voie ou coffre de tête, et pourquoi), souterrains et répartiteurs posés
  local cs = {}
  for _, c in ipairs(plan.stats.coal or {}) do
    cs[#cs + 1] = string.format("cote %s %s%s", c.side > 0 and "+" or "-", c.voie and "voie de charbon" or "coffre de tete",
      c.why and (" (" .. c.why .. ")") or "")
  end
  -- (lot COUT-600 : la ligne du plan est écrite tout de suite, comme avant, sans le résultat de Cv.verify ; ce résultat suit sur sa propre ligne,
  -- écrite par Champ.flush avec log seul : say compte les lignes dans f.champ_logs (global), un compte écrit en différé ferait diverger une
  -- partie rechargée de la même partie continuée)
  say(f, string.format("avant-poste %d (%s) : plan du champ, %d bande(s) (%d avec des paires), axe %s, sortie %s ; %d foreuses, %d fours, %d poteaux, %d tapis ; %s",
    o.id, o.kind, #prs, with, plan.axis, plan.exit > 0 and "+" or "-", plan.stats.drills, plan.stats.furnaces,
    plan.stats.poles, plan.stats.belts, "verification du plan : ligne suivante") .. string.format(" ; gisement occupe (hors paires) : %s", #occ > 0 and table.concat(occ, ", ") or "rien")
    .. string.format(" ; fonderie %s, %d souterrain(s), %d repartiteur(s)%s", plan.design or "a coffres", plan.stats.undergrounds or 0,
      plan.stats.splitters or 0, #cs > 0 and (", " .. table.concat(cs, ", ")) or "")
    .. string.format(" ; colonnes posees ailleurs %d, tapis collecteurs seuls %d, foreuses sans fonderie non posees %d%s", plan.stats.away or 0, plan.stats.bare or 0, plan.stats.orphans or 0,
      plan.stats.away_why and (" (" .. plan.stats.away_why .. ")") or "")
    .. string.format(" ; autres ressources minables autour : %d tuile(s) du champ, %d de la ligne de charbon", spec.nforeign or 0,
      spec.coal and spec.coal.nforeign or 0))
  -- (revue-fonderie, 3/11) réseau du charbon calculé dans l'autre ordre des côtés : moins de coffres de tête
  if plan.order_swapped then
    log(string.format("[FO-CHAMP] %s : avant-poste %d : reseau du charbon calcule cote %s d'abord : coffres de tete %d -> %d, foreuses du champ %d -> %d a %.1f min",
      f.key or "player", o.id, plan.exit > 0 and "-" or "+", plan.order_swapped.chests, Ch.head_chests(plan), plan.order_swapped.drills, Ch.field_drills(plan),
      game.tick / 3600))
  end
  -- lot FONDERIE (3/11, décision du lead) : refuser aurait coûté plus de la moitié des foreuses du champ : ce cadre garde ses colonnes au
  -- coffre de tête (0.6.42)
  if plan.coffre_cost then
    log(string.format("[FO-CHAMP] %s : cadre a coffres : refus coutait %d %% du champ (avant-poste %d, %d colonne(s) sans voie de charbon) a %.1f min",
      f.key or "player", plan.coffre_cost, o.id, plan.coffre_cols or 0, game.tick / 3600))
  end
  -- lot FONDERIE (3/11, 0.6.43) : colonnes refusées faute de voie de charbon (plus aucun coffre de tête à remplir)
  for _, x in ipairs(plan.refused or {}) do
    -- (hors du plafond des lignes [FO-CHAMP] de say : un refus se voit toujours)
    log(string.format("[FO-CHAMP] %s : colonne refusee : pas de voie de charbon (avant-poste %d, bande %d, cote %s : %s) a %.1f min", f.key or "player",
      o.id, x.pr, x.side > 0 and "+" or "-", tostring(x.why), game.tick / 3600))
  end
  FRAME_PENDING[#FRAME_PENDING + 1] = { f = f, plan = plan, spec = spec, oid = o.id, kind = o.kind }
  return plan.frame, prs, plan
end

--- Lot COUT-600 : UNE vérification de cadre en attente de l'équipe `f` (la plus ancienne) : Cv.verify puis la ligne de journal [FO-CHAMP]. À appeler à
--- chaque pensée de la migration du champ (Mig.think) et avant un nouveau plan : un coût de vérification par appel, jamais celui du plan. Les attentes
--- sont LOCALES (jamais dans global) : un chargement de sauvegarde les perd, et seule la ligne de journal manque (Champ.flush n'écrit rien dans global ;
--- c'est l'appelant, par un drapeau de global, qui décide de la pensée à part). Rend vrai si une vérification a eu lieu.
function Champ.flush(f)
  for i, it in ipairs(FRAME_PENDING) do
    if it.f == f then
      table.remove(FRAME_PENDING, i)
      Profiler.fstart("champ:frame-verify")
      local rep = Cv.verify(it.plan, it.spec)
      Profiler.fstop("champ:frame-verify")
      log(string.format("[FO-CHAMP] %s : avant-poste %d (%s) : verification du plan : %s a %.1f min", f.key or "player", it.oid, tostring(it.kind), Cv.line(rep),
        game.tick / 3600))
      return true
    end
  end
  return false
end

--- Lot FONDERIE : vrai si une bande du champ de `o` a déjà été demandée au plan directeur (un cadre d'avant le lot, sans `design`, n'est
--- rejoué que dans ce cas ; sinon il est replanifié en colonne).
function Champ.has_band(f, o)
  local b = f.build
  for _, pid in ipairs(b and b.order or {}) do
    local p = b.projects[pid]
    if p and p.spec and p.spec.champ and p.spec.champ.oid == o.id then return true end
  end
  return false
end

--- Entités nommées d'un plan (bande seule) : ents { name, x, y, dir, role }, quais, outs, emprise { tuiles }.
local function named(plan, names, coal_side, exclude)
  local ents, quais, outs = {}, {}, {}
  local design = plan.design
  for _, e in ipairs(plan.ents) do
    local name
    -- (projet séparé) la bande ne porte pas les pièces communes du réseau du charbon ; le projet du réseau ne porte qu'elles
    local skip
    if coal_side then skip = e.coalnet ~= coal_side
    else skip = (Champ.CFG.coal_project and e.coalnet ~= nil) or (exclude ~= nil and e.coalnet ~= nil and exclude[e.coalnet] == true) end
    if skip then goto continue end
    if e.kind == "foreuse" then name = names.drill
    elseif e.kind == "tapis" then name = names.belts[e.belt or 1]
    elseif e.kind == "poteau" then name = names.pole
    elseif e.kind == "four" then name = names.furnace
    elseif e.kind == "bras" then name = names.arm
    elseif e.kind == "coffre" then name = names.chest
    elseif e.kind == "souterrain" then name = names.underground -- lot FONDERIE
    elseif e.kind == "repartiteur" then name = names.splitter end
    if name then
      local role = (e.kind == "coffre" and e.role == "sortie") and "sortie" or ("champ-" .. e.kind)
      -- lot FONDERIE : le réseau du charbon (ligne de foreuses, tracé, tronc, dérivations) a son rôle : ses foreuses arrêtées quand la
      -- voie de charbon est pleine ne comptent pas parmi les foreuses figées du champ ([FO-CHAMP-ETAT])
      if e.role == "charbon" and e.kind ~= "coffre" then role = "champ-charbon" end
      -- (revue-fonderie) `common` : pièce du réseau du charbon COMMUN à un côté (posée par la première bande de ce côté) ; lue par le tri par
      -- rôle des pièces écartées (Build.SITES.champ), jamais copiée au projet (plan_project ne copie que ses champs)
      local ent = { name = name, x = e.x, y = e.y, dir = e.dir, role = role, type = e.ug, common = e.coalnet ~= nil or nil }
      if e.kind == "four" and design == "colonne" and plan.fuelled then ent.charge = { item = names.fuel, count = Champ.CFG.amorce } end
      if e.kind == "coffre" and e.role == "combustible" then
        -- coffre de tête d'une colonne (lot FONDERIE) : un seul pour toute la colonne, posé mieux garni
        ent.charge = { item = names.fuel, count = (design == "colonne") and Champ.CFG.charge_tete or Champ.CFG.charge }
      end
      -- les foreuses se posent en DERNIER (après poteaux, fours, bras, coffres et tapis : rangs 1 à 6 de P.sort_build) : une foreuse posée
      -- avant son tapis et sa fonderie remplit le tapis de minerai qui ne va nulle part (mesuré : 12 foreuses figées sur un chantier de
      -- 18 min, scarlet, graine 20261020)
      if e.kind == "foreuse" then ent.rank = Champ.CFG.drill_rank end
      ents[#ents + 1] = ent
      if e.kind == "coffre" and e.role == "combustible" then quais[#quais + 1] = { x = e.x, y = e.y, item = names.fuel, flow = e.need } end -- lot FONDERIE-BLOC : débit du quai
      if e.kind == "coffre" and e.role == "sortie" then outs[#outs + 1] = { x = e.x, y = e.y } end
    end
    ::continue::
  end
  return ents, quais, outs
end

--- La bande `pr` seule : { ents, quais, outs, tiles (liste plate de son emprise), plan } ou nil, raison.
function Champ.band(f, surface, o, frame, pr, coal_side)
  Profiler.fstart("champ:band-spec")
  local spec, names = spec_of(f, surface, o, frame, { [pr] = true })
  Profiler.fstop("champ:band-spec")
  if not spec then return nil, names end
  Profiler.dump("champ-band", { spec = spec, cfg = Ch.CFG }) -- lot PERF3 : entrées du plan, bancs de détail seulement
  Profiler.fstart("champ:band-plan")
  local plan, why = Ch.plan(spec)
  Profiler.fstop("champ:band-plan")
  if not plan then return nil, why end
  if #plan.ents == 0 then
    local at = plan.stats.no_smelter_at
    local cause = ""
    if at then
      local es = surface.find_entities_filtered({ area = { { at.x - 0.5, at.y - 0.5 }, { at.x + 0.5, at.y + 0.5 } }, limit = 3 })
      local names = {}
      for _, e in ipairs(es) do names[#names + 1] = e.name .. (e.force and (" " .. e.force.name) or "") end
      table.sort(names)
      local why_tile = spec.blocked and spec.blocked[Ch.key(math.floor(at.x), math.floor(at.y))] -- « eau », « cliff », « reserve », « couloir » ou le nom du bâtiment
      cause = string.format(" ; 1re tuile prise (%.1f, %.1f), %s, %s : %s, relevee « %s »", at.x, at.y, at.fixed and "place du cadre figé" or "1re place essayee", at.side > 0 and "cote +" or "cote -",
        #names > 0 and table.concat(names, ", ") or "aucune entite visible", tostring(why_tile))
    end
    return nil, string.format("bande vide : %d foreuse(s) possibles sur ses rangees, %d groupe(s) sans place de fonderie%s", plan.stats.band_drills or 0,
      plan.stats.no_smelter or 0, cause)
  end
  -- (lot FONDERIE, lot6-123456789 : une bande de 1 026 entités portait les deux réseaux du charbon) : au-delà de band_max, les réseaux les plus
  -- gros sont reportés dans des projets liés à la bande (script/team/migration_champ.lua les demande juste après elle)
  local exclude, defer = nil, {}
  if not coal_side and not Champ.CFG.coal_project then
    local own, by = 0, {}
    for _, e in ipairs(plan.ents) do if e.coalnet then by[e.coalnet] = (by[e.coalnet] or 0) + 1 else own = own + 1 end end
    local shared = {}
    for _, sd in ipairs({ -1, 1 }) do if by[sd] then shared[#shared + 1] = { sd, by[sd] } end end
    defer = Sa.split(own, shared, Champ.CFG.band_max)
    if #defer > 0 then exclude = {}; for _, sd in ipairs(defer) do exclude[sd] = true end end
  end
  local ents, quais, outs = named(plan, names, coal_side, exclude)
  if coal_side and #ents == 0 then return nil, "reseau du charbon vide" end
  -- lot COMBUSTIBLE-MIGRATION : pièces du réseau du charbon REPORTÉ dans des projets liés (pas encore planifiés) : leurs tuiles, retenues par Build.SITES.champ
  local deferred_tiles = {}
  for _, sd in ipairs(defer) do
    for _, e in ipairs((named(plan, names, sd, nil))) do
      for _, t in ipairs(P.tiles_of(e)) do deferred_tiles[#deferred_tiles + 1] = { t[1], t[2] } end
    end
  end
  local tiles = {}
  for _, e in ipairs(ents) do for _, t in ipairs(P.tiles_of(e)) do tiles[#tiles + 1] = t[1]; tiles[#tiles + 1] = t[2] end end
  return { ents = ents, quais = quais, outs = outs, tiles = tiles, plan = plan, names = names, spec = spec, defer = defer, deferred_tiles = deferred_tiles }
end

---------------------------------------------------------------------------------------------------
-- Site « champ » du plan directeur
---------------------------------------------------------------------------------------------------
--- Poteau alimenté le plus proche (réseau d'une génératrice de l'équipe), ou nil.
local function powered_pole(f, surface, x, y, radius)
  local powered = Gens.networks(surface, f.force, "generator") -- lot X10-S4 : registre des génératrices
  local best, bd
  for _, e in ipairs(surface.find_entities_filtered({ position = { x, y }, radius = radius or Champ.CFG.chain_r, type = "electric-pole", force = f.force })) do
    if e.electric_network_id and powered[e.electric_network_id] then
      local d = (e.position.x - x) ^ 2 + (e.position.y - y) ^ 2
      if not bd or d < bd or (d == bd and (e.position.x < best.x or (e.position.x == best.x and e.position.y < best.y))) then
        best, bd = { x = e.position.x, y = e.position.y }, d
      end
    end
  end
  return best
end
Champ.powered_pole = powered_pole

Build.SITES = Build.SITES or {}
LB.install(Build)
--- Lot FONDERIE : raccorde TOUTES les composantes des poteaux de `ents` (projet d'une bande ou d'un réseau du charbon) à un poteau alimenté
--- (Ra.connect). Ajoute les poteaux de liaison à `ents` ; rend (poteaux posés, nil, nil, composantes) ou (nil, raison, attente).
local function raccord_tous(f, surface, bd, ents, cx, cy, proj, o)
  local wire = bd.spec.pole.wire
  local own = {}
  for _, e in ipairs(ents) do if e.name == bd.names.pole then own[#own + 1] = { x = e.x, y = e.y } end end
  if #own == 0 then return 0, nil, nil, 0 end
  local powered = Gens.networks(surface, f.force, "generator") -- lot X10-S4 : registre des génératrices
  local targets = {}
  for _, e in ipairs(surface.find_entities_filtered({ position = { cx, cy }, radius = Champ.CFG.chain_far, type = "electric-pole", force = f.force })) do
    if e.valid and e.electric_network_id and powered[e.electric_network_id] then targets[#targets + 1] = { x = e.position.x, y = e.position.y } end
  end
  table.sort(targets, function(a, c) if a.x ~= c.x then return a.x < c.x end return a.y < c.y end)
  local _, nc = Ra.components(own, wire)
  if #targets == 0 then return nil, "aucun reseau alimente a " .. Champ.CFG.chain_far .. " tuiles (attente)", true end
  -- boîte lue : les poteaux du projet et, pour chacun, le poteau alimenté le plus proche (là où passent les chaînes)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  local function grow(x, y) x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y) end
  for _, q in ipairs(own) do
    grow(q.x, q.y)
    local best, bd2
    for _, t in ipairs(targets) do
      local d2 = (q.x - t.x) ^ 2 + (q.y - t.y) ^ 2
      if not bd2 or d2 < bd2 then best, bd2 = t, d2 end
    end
    grow(best.x, best.y)
  end
  -- lot RACCORD-BANDE : chaîne par paliers (Ra.tiered_chain : boîte étroite, autour, à travers le minerai), la lecture du moteur n'est faite qu'au
  -- premier besoin de chaque marge
  local hull = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local blocked_by = {}
  local function blocked_of(margin)
    local bl = blocked_by[margin]
    if not bl then
      bl = blocked_in(f, surface, math.floor(x0) - margin, math.floor(y0) - margin, math.ceil(x1) + margin, math.ceil(y1) + margin, bd.spec.mine, nil,
        bd.occ_libre or function(_, _, owner) return o ~= nil and Cd.own(owner, o.id) end)
      blocked_by[margin] = bl
    end
    return function(tx, ty) return bl[Ch.key(tx, ty)] ~= nil end
  end
  local used = {}
  for _, e in ipairs(ents) do for _, t in ipairs(P.tiles_of(e)) do used[Ch.key(t[1], t[2])] = true end end
  local ore = {}
  for i = 1, #bd.spec.ore - 1, 2 do ore[Ch.key(bd.spec.ore[i], bd.spec.ore[i + 1])] = true end
  -- (comme le raccord 0.6.41) une chaîne ne passe sur le minerai que dans les rangées de SA bande, sauf dernier palier
  local b1 = bd.plan.bands[1]
  local v0, v1 = b1 and b1.pr or 0, b1 and (b1.pr + bd.plan.pitch) or -1
  local axis_x = bd.plan.axis == "x"
  local tier_used = {}
  -- lot RACCORD-BANDE 2 : le réseau alimenté est à plus de LB.LINE_FAR tuiles (partie neuve 0.6.72 : 163 à 281) : aucun palier local n'y mènera, la ligne de
  -- poteaux est demandée tout de suite (coût d'un palier épargné)
  local nearest = proj and Ra.nearest(own, targets) or nil
  if nearest and nearest.d > LB.LINE_FAR then
    local ok, why = LB.ensure(f, surface, proj, nearest, wire, bd.names.pole, game.tick)
    if ok then
      proj.rtier, proj.far_poll = nil, LB.POLL
      return nil, why, "loin"
    end
  end
  -- un palier par essai quand le projet est connu (coût d'un essai = celui d'une recherche, ~5 ms) : proj.rtier = palier du prochain essai
  local only = proj and (proj.rtier or 1) or nil
  local prm = { tier = only, hull = hull, reach = wire, pole_chain = P.pole_chain, blocked = blocked_of, used = used, key = Ch.key,
    ore = function(tx, ty) return ore[Ch.key(tx, ty)] == true end,
    rows = function(tx, ty) local v = axis_x and ty or tx return v >= v0 and v <= v1 end }
  local added, fails = Ra.connect(own, targets, wire, function(a, b)
    local ch, tier = Ra.tiered_chain(a, b, prm)
    for _, c in ipairs(ch or {}) do used[Ch.key(math.floor(c.x), math.floor(c.y))] = true end
    if ch and tier ~= Ra.TIERS[1].name then tier_used[tier] = (tier_used[tier] or 0) + 1 end
    return ch
  end)
  for _, nm in ipairs({ Ra.TIERS[2].name, Ra.TIERS[3].name }) do
    if tier_used[nm] then say(f, string.format("raccord de bande : %d chaine(s) de poteaux trouvee(s) %s (la boite etroite n'en donnait aucune)", tier_used[nm], nm)) end
  end
  -- lot RACCORD-BANDE, diagnostic (journal seulement) : pourquoi le palier n'a trouvé aucune chaîne (terrain le long du segment et dans la boîte)
  if #fails > 0 then
    local fl = fails[1]
    local t = Ra.TIERS[only or #Ra.TIERS]
    if fl and fl.to and t then
      local free, box, blk = Ra.tier_free(prm, t)
      local st = Ra.segment_stats(fl.at, fl.to, box, { blocked_now = function(tx, ty) return blk(tx, ty) end, ore = prm.ore, used = used, key = Ch.key }, free)
      say(f, string.format("raccord de bande refuse, palier « %s » : composante de %d poteau(x) en (%.0f, %.0f), cible la plus proche en (%.0f, %.0f) a %.0f tuiles ; segment %d points : %d occupes, %d de minerai, %d deja pris, %d libres ; boite %d x %d : %d%% de tuiles libres",
        t.name, fl.n, fl.at.x, fl.at.y, fl.to.x, fl.to.y, fl.d or 0, st.seg, st.seg_blocked, st.seg_ore, st.seg_used, st.seg_free,
        box.x1 - box.x0 + 1, box.y1 - box.y0 + 1, st.box > 0 and math.floor(100 * st.box_free / st.box) or 0))
      if bd.occ_libre then -- mall : de quoi sont faites les tuiles bloquées de la plus grande boîte lue (journal seulement)
        local widest, wm, tally, ks, parts = nil, nil, {}, {}, {}
        for m, bl in pairs(blocked_by) do if not wm or m > wm then widest, wm = bl, m end end
        for _, why in pairs(widest or {}) do tally[why] = (tally[why] or 0) + 1 end
        for k in pairs(tally) do ks[#ks + 1] = tostring(k) end
        table.sort(ks)
        for _, k in ipairs(ks) do parts[#parts + 1] = k .. "=" .. tally[k] end
        say(f, "raccord du mall : tuiles bloquees (marge " .. tostring(wm) .. ") : " .. table.concat(parts, ", "))
      end
    end
  end
  -- lot RACCORD-BANDE 2 : le réseau alimenté est LOIN (partie neuve 0.6.72 : 163 à 281 tuiles) : après le dernier palier, une LIGNE de poteaux, projet
  -- à part (une par avant-poste, partagée par ses bandes) ; la bande attend sa ligne au lieu d'être refusée
  if #fails > 0 and proj and (not only or only >= #Ra.TIERS) and fails[1].to and (fails[1].d or 0) > LB.LINE_MIN then
    local ok, why = LB.ensure(f, surface, proj, fails[1], wire, bd.names.pole, game.tick)
    if ok then
      proj.rtier, proj.far_poll = nil, LB.POLL
      return nil, why, "loin"
    end
  end
  if #fails > 0 and only and only < #Ra.TIERS then
    proj.rtier = only + 1
    return nil, string.format("raccord de bande : palier « %s » sans chaine jusqu'au reseau alimente, palier « %s » au prochain essai",
      Ra.TIERS[only].name, Ra.TIERS[only + 1].name), true
  end
  if #fails > 0 then
    local n = 0
    for _, x in ipairs(fails) do n = n + x.n end
    local d = fails[1] and fails[1].d
    return nil, string.format("%d composante(s) de poteaux (%d poteaux) sans chaine jusqu'au reseau alimente (%s, %s, %s essayes%s)", #fails, n,
      Ra.TIERS[1].name, Ra.TIERS[2].name, Ra.TIERS[3].name, d and string.format(" ; plus proche cible a %.0f tuiles", d) or "")
  end
  for _, c in ipairs(added) do ents[#ents + 1] = { name = bd.names.pole, x = c.x, y = c.y, dir = 0, role = "liaison" } end
  return #added, nil, nil, nc
end
Champ._raccord_tous = raccord_tous -- (lot X10-S4) appel direct du micro-banc x10-s4-ombre (script/team/generateurs.lua) ; aucun autre usage

Build.SITES.champ = function(f, surface, p, h)
  local cs = p.spec.champ
  local o = cs and Champ.target(f, cs.oid)
  if not o then return nil, "champ: avant-poste perdu" end
  -- (lot FONDERIE) un réseau du charbon LIÉ à sa bande attend qu'elle soit planifiée, et se refuse si elle l'est : jamais d'orphelin
  if cs.link then
    local lp = f.build.projects[cs.link]
    if not lp or lp.state == "refuse" then return nil, "champ: bande liee absente ou refusee" end
    if #(lp.ents or {}) == 0 then return nil, "champ: bande liee pas encore planifiee", true end
  end
  local bd, why = Champ.band(f, surface, o, cs.frame, cs.pr, cs.coal)
  if not bd then return nil, "champ: " .. tostring(why) end
  local b = f.build
  -- poteaux d'une bande voisine déjà demandée (rangée partagée, même place sur le treillis) : déjà au plan, pas deux fois
  local ents = {}
  local dropped = 0
  local dropped_by, holders, drop_roles = {}, {}, {} -- (revue-fonderie, 3/11) pièces écartées : plus en silence (journal ci-dessous)
  -- lot COMBUSTIBLE-MIGRATION : ce que le détenteur d'une tuile y porte (index par projet, lu une fois) ; une pièce n'est écartée que si c'est la même
  -- (Cd.verdict) ; une pièce du réseau du charbon en conflit coupe le tronc : le réseau est refusé plus bas, avec la cause
  local hidx, cut, cut_by = {}, 0, {}
  local function held_ent(q, tk)
    local idx = hidx[q]
    if not idx then
      idx = {}
      local pq = b.projects[q]
      for _, he in ipairs(pq and pq.ents or {}) do
        for _, t in ipairs(P.tiles_of(he)) do idx[P.tkey(t[1], t[2])] = he end
      end
      hidx[q] = idx
    end
    return idx[tk]
  end
  for _, e in ipairs(bd.ents) do
    local taken = false
    local held = {}
    for _, t in ipairs(P.tiles_of(e)) do
      local tk = P.tkey(t[1], t[2])
      local q = b.occ[tk]
      if q and q ~= p.id and not Cd.own(q, o.id) then taken = true; holders[tostring(q)] = true; held[#held + 1] = { pid = q, ent = held_ent(q, tk) } end
    end
    if taken then
      if Cd.cuts_trunk(Cd.verdict(e, held), e.role == "champ-charbon") then
        cut = cut + 1
        cut_by[tostring(held[1].pid)] = (cut_by[tostring(held[1].pid)] or 0) + 1
      end
      dropped = dropped + 1
      dropped_by[e.name] = (dropped_by[e.name] or 0) + 1
      -- (revue-fonderie) tri par rôle ; le charbon commun à part
      local rk = tostring(e.role) .. ((e.role == "champ-charbon") and (e.common and " (commun)" or " (propre a la bande)") or "")
      drop_roles[rk] = drop_roles[rk] or {}
      drop_roles[rk][e.name] = (drop_roles[rk][e.name] or 0) + 1
    else
      ents[#ents + 1] = e
    end
  end
  if dropped > 0 then
    local parts, hs = {}, {}
    for _, n in ipairs(sorted_keys(dropped_by)) do parts[#parts + 1] = n .. " " .. dropped_by[n] end
    for _, h in ipairs(sorted_keys(holders)) do hs[#hs + 1] = tostring(h) end
    log(string.format("[FO-CHAMP] %s : projet %d (bande %s, avant-poste %d) : %d piece(s) ecartee(s), leurs tuiles deja au plan du ou des projet(s) %s : %s a %.1f min",
      f.key or "player", p.id, tostring(cs.pr), o.id, dropped, table.concat(hs, ","), table.concat(parts, ", "), game.tick / 3600))
    -- (revue-fonderie) une ligne par rôle
    for _, rk in ipairs(sorted_keys(drop_roles)) do
      local np, n = {}, 0
      for _, nm in ipairs(sorted_keys(drop_roles[rk])) do np[#np + 1] = nm .. " " .. drop_roles[rk][nm]; n = n + drop_roles[rk][nm] end
      log(string.format("[FO-CHAMP] %s : projet %d (bande %s) : pieces ecartees du role %s : %d (%s)", f.key or "player", p.id, tostring(cs.pr), rk, n,
        table.concat(np, ", ")))
    end
  end
  -- lot COMBUSTIBLE-MIGRATION : le réseau du charbon REPORTÉ de cette bande n'est planifié que plus tard : ses tuiles sont retenues dès maintenant (Cd.reserve), pour que les
  -- projets planifiés entre-temps (bande de cuivre du projet 11, 0,2 min avant le réseau du projet 9) les évitent
  if not cs.coal and bd.deferred_tiles and #bd.deferred_tiles > 0 then
    local n = Cd.reserve(b.occ, bd.deferred_tiles, o.id, P.tkey)
    if n > 0 then
      log(string.format("[FO-CHAMP] %s : projet %d (bande %s, avant-poste %d) : %d tuile(s) du reseau du charbon reporte retenue(s) au plan pour lui (cadre:%d) a %.1f min",
        f.key or "player", p.id, tostring(cs.pr), o.id, n, o.id, game.tick / 3600))
    end
  end
  -- lot COMBUSTIBLE-MIGRATION : une pièce du réseau du charbon dont la tuile est au plan d'un autre projet qui n'y porte PAS la même pièce coupe le
  -- tronc : le réseau attend (CUT_WAIT : le détenteur peut disparaître, ou le plan se relire) puis est accepté tel quel, avec la ligne [FO-CHAMP] « TRONC COUPE »
  if cut > 0 then
    b.champ_cut = b.champ_cut or {}
    local ck = tostring(o.id) .. ":" .. tostring(cs.coal or ("b" .. tostring(cs.pr)))
    local t0 = b.champ_cut[ck] or game.tick
    b.champ_cut[ck] = t0
    local hs2 = {}
    for _, h in ipairs(sorted_keys(cut_by)) do hs2[#hs2 + 1] = h .. " (" .. cut_by[h] .. ")" end
    local waiting = game.tick - t0 < Champ.CFG.cut_wait
    b.champ_cut_say = b.champ_cut_say or {}
    local said = waiting and "attend" or "accepte"
    if b.champ_cut_say[ck] ~= said then -- (une ligne par changement : pas à chaque relecture du plan)
    b.champ_cut_say[ck] = said
    log(string.format("[FO-CHAMP] %s : projet %d (reseau du charbon, bande %s) : TRONC COUPE : %d piece(s) du reseau du charbon sur des tuiles du projet %s, que son plan occupe d'une AUTRE piece (nom, role ou direction) ; %s a %.1f min",
      f.key or "player", p.id, tostring(cs.pr), cut, table.concat(hs2, ", "),
      waiting and string.format("le reseau attend (au plus %.0f min depuis %.1f min)", Champ.CFG.cut_wait / 3600, t0 / 3600) or "attente finie : reseau accepte tel quel", game.tick / 3600))
    end
    if waiting then
      p.plan_after = Cd.next_try(game.tick, t0, Champ.CFG.cut_wait, Champ.CFG.cut_poll) -- lot UPS-2 : pas un plan complet à chaque passe pendant l'attente
      return nil, string.format("champ: reseau du charbon coupe (%d piece(s) en conflit avec le projet %s)", cut, hs2[1] or "?"), true
    end
  end
  -- raccord au réseau : un poteau alimenté à portée d'un poteau de la bande, sinon une chaîne de poteaux
  -- (lot FONDERIE) les poteaux du réseau du charbon (loin, vers le gisement de charbon) ne comptent pas : le raccord part de la bande
  local poles = {}
  for _, e in ipairs(ents) do if e.name == bd.names.pole and e.role ~= "champ-charbon" then poles[#poles + 1] = e end end
  if #poles == 0 then for _, e in ipairs(ents) do if e.name == bd.names.pole then poles[#poles + 1] = e end end end
  local wire = bd.spec.pole.wire
  local cx, cy = 0, 0
  for _, e in ipairs(poles) do cx, cy = cx + e.x, cy + e.y end
  if #poles > 0 then cx, cy = cx / #poles, cy / #poles end
  local net, chain_n, comps = nil, 0, nil
  if Champ.tapis() then
    -- lot FONDERIE (3/11, ENERGIE4, lot7bis-20261020 : colonne de 16 à 20 poteaux à 101 tuiles du réseau, foreuses de charbon à 65 tuiles,
    -- jamais raccordées) : TOUTES les composantes des poteaux du projet rejoignent un poteau ALIMENTÉ (shared/team/champ_raccord.lua) ;
    -- les poteaux d'une bande voisine (déjà au plan, retirés ci-dessus) ne comptent pas : son projet peut ne jamais finir
    local n_r, why_r, wait_r, nc = raccord_tous(f, surface, bd, ents, cx, cy, p, o)
    if not n_r then return nil, "champ: " .. why_r, wait_r end
    chain_n, comps, net = n_r, nc, true
  else
  net = powered_pole(f, surface, cx, cy)
  if net then
    local start, sd
    for _, e in ipairs(poles) do
      local d = (e.x - net.x) ^ 2 + (e.y - net.y) ^ 2
      if not sd or d < sd then start, sd = e, d end
    end
    if start and sd > wire * wire then
      local x0, y0 = math.floor(math.min(start.x, net.x)) - 8, math.floor(math.min(start.y, net.y)) - 8
      local x1, y1 = math.ceil(math.max(start.x, net.x)) + 8, math.ceil(math.max(start.y, net.y)) + 8
      local blocked = blocked_in(f, surface, x0, y0, x1, y1, bd.spec.mine)
      local used = {}
      for _, e in ipairs(ents) do for _, t in ipairs(P.tiles_of(e)) do used[Ch.key(t[1], t[2])] = true end end
      local ore = {}
      for i = 1, #bd.spec.ore - 1, 2 do ore[Ch.key(bd.spec.ore[i], bd.spec.ore[i + 1])] = true end
      -- la chaîne ne passe sur le minerai que dans les rangées de SA bande (les autres bandes du champ gardent leur place)
      local b1 = bd.plan.bands[1]
      local v0, v1 = b1 and b1.pr or 0, b1 and (b1.pr + bd.plan.pitch) or -1
      local function free(x, y)
        local tx, ty = math.floor(x), math.floor(y)
        local k = Ch.key(tx, ty)
        local v = (bd.plan.axis == "x") and ty or tx
        return not blocked[k] and not used[k] and (not ore[k] or (v >= v0 and v <= v1))
      end
      local chain = P.pole_chain({ x = start.x, y = start.y }, net, wire, false, free, nil)
      if not chain then return nil, "champ: aucune chaine de poteaux jusqu'au reseau" end
      for _, c in ipairs(chain) do ents[#ents + 1] = { name = bd.names.pole, x = c.x, y = c.y, dir = 0, role = "liaison" }; chain_n = chain_n + 1 end
    end
  end
  end
  -- Garde (3/11, verif-guide 1618033988 sur 0.6.40 : « real number expected got inf » en find_tiles_filtered, jeu arrêté à 44 min) : une bande dont toutes
  -- les pièces sont déjà au plan n'a plus d'entité ; sa boîte serait (+inf, -inf).
  if #ents == 0 then return nil, "champ: aucune entite a poser pour cette bande" end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(ents) do
    x0, y0 = math.min(x0, math.floor(e.x)), math.min(y0, math.floor(e.y))
    x1, y1 = math.max(x1, math.floor(e.x)), math.max(y1, math.floor(e.y))
  end
  local masks = h.read_masks(x0 - 2, y0 - 2, x1 + 3, y1 + 3)
  local nd, nf = 0, 0
  for _, e in ipairs(ents) do
    if e.name == bd.names.drill then nd = nd + 1 elseif e.name == bd.names.furnace then nf = nf + 1 end
  end
  say(f, string.format("projet %d : %s du champ de l'avant-poste %d (%s) : %d foreuses, %d fours, %d entites (%d deja au plan), raccord %s",
    p.id, cs.coal and string.format("reseau du charbon cote %s (bande %d)", cs.coal > 0 and "+" or "-", cs.pr) or ("bande " .. cs.pr),
    o.id, o.kind, nd, nf, #ents, dropped, net and (chain_n > 0 and (chain_n .. " poteau(x)") or "a portee") or "aucun reseau alimente vu")
    .. (comps and string.format(" (%d composante(s) de poteaux, toutes jointes au reseau alimente)", comps) or ""))
  return { key = "champ:" .. o.id .. ":" .. (cs.coal and ("charbon" .. cs.coal) or cs.pr), box = { x0, y0, x1, y1 }, ents = ents, quais = bd.quais,
    outs = bd.outs, masks = masks }
end

---------------------------------------------------------------------------------------------------
-- État des champs (journal)
---------------------------------------------------------------------------------------------------
Champ.REPORT_EVERY = 5 * 3600 -- une ligne [FO-CHAMP-ETAT] par équipe toutes les 5 min

--- Une ligne par équipe : bandes par état (et ce qui manque à celles qui attendent leurs matières), foreuses et fours des bandes, coffres
--- de sortie (plaques qui attendent la collecte) et de combustible. Lecture seule (entités relues au moteur).
--- Revue-fonderie (point 7, 3/11) : lecteur des projets LIÉS du réseau du charbon (Ln.decide) : bande absente ou refusée, le projet lié
--- encore annulable est annulé (plus d'orphelin) ; bande vivante dont tous les projets liés d'un côté sont refusés, il est redemandé (au
--- plus Ln.MAX_TRIES). Appelé par Champ.report (son horloge). Rend (annulés, redemandés).
function Champ.links_step(f, tick)
  local b = f.build
  if not b then return 0, 0 end
  local items = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    local cs = q and q.spec and q.spec.champ
    if cs and cs.link and cs.coal then
      local band = b.projects[cs.link]
      items[#items + 1] = { id = pid, state = q.state, band = cs.link, side = cs.coal, band_state = band and band.state or nil }
    end
  end
  if #items == 0 then return 0, 0 end
  local acts = Ln.decide(items)
  local nc, nr = 0, 0
  for _, id in ipairs(acts.cancel) do
    if Build.cancel(f, id, "champ: bande liee absente ou refusee") then
      nc = nc + 1
      log(string.format("[FO-CHAMP] %s : projet lie %d (reseau du charbon) annule : sa bande est absente ou refusee a %.1f min", f.key or "player", id, tick / 3600))
    end
  end
  for _, id in ipairs(acts.rerequest) do
    local old = b.projects[id]
    local spec = {}
    for _, k in ipairs(sorted_keys(old.spec)) do spec[k] = old.spec[k] end
    local cs = {}
    for _, k in ipairs(sorted_keys(old.spec.champ)) do cs[k] = old.spec.champ[k] end
    spec.champ = cs
    local nid = Build.request(f, spec)
    nr = nr + 1
    log(string.format("[FO-CHAMP] %s : projet lie %d (reseau du charbon cote %s, bande %d) refuse (%s) : redemande, projet %s a %.1f min", f.key or "player", id,
      cs.coal > 0 and "+" or "-", cs.link, tostring(old.reason), tostring(nid), tick / 3600))
  end
  return nc, nr
end

--- Lot COMBUSTIBLE : seul écrivain de o.champ_burners (lu par Outposts.burners : état, besoin et tournée de l'avant-poste). `fours` = fours à
--- brûleur des bandes relevés par Champ.report, par champ. Un four à sec entre dans la liste de son avant-poste, il y reste tant qu'il est debout
--- (Rv.field_burners). Un champ sans avant-poste (gisement de la capitalisation, f.migration.fields) n'a pas de tournée : compté au journal.
function Champ.field_burners(f, fours, tick)
  local parts, orphans = {}, 0
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local fo = fours[oid]
    local prev = {}
    for _, e in ipairs(o.champ_burners or {}) do if e.valid then prev[e.unit_number] = true end end
    local list, dry = {}, 0
    for _, r in ipairs(fo and fo.rows or {}) do if r.dry then dry = dry + 1 end end
    for _, id in ipairs(Rv.field_burners(prev, fo and fo.rows or {})) do list[#list + 1] = fo.ents[id] end
    o.champ_burners = list
    if #list > 0 then parts[#parts + 1] = string.format("avant-poste %s (%s) %d four(s) dont %d a sec", tostring(oid), tostring(o.kind), #list, dry) end
  end
  for _, oid in ipairs(sorted_keys(fours)) do
    if not f.outposts[oid] then
      for _, r in ipairs(fours[oid].rows) do if r.dry then orphans = orphans + 1 end end
    end
  end
  if #parts > 0 or orphans > 0 then
    log(string.format("[FO-CHAMP-COMBUSTIBLE] %s min %.0f | fours de champ ravitailles a la main : %s ; fours a sec d'un champ sans avant-poste (aucune tournee) %d ; %s au coffre du QG %d",
      f.key or "player", tick / 3600, #parts > 0 and table.concat(parts, ", ") or "aucun", orphans, T.fuel, Stock.count(f, T.fuel)))
  end
end

function Champ.report(f, surface, tick)
  local b = f.build
  if not b then return end
  Champ.links_step(f, tick) -- (revue-fonderie, point 7)
  do -- lot COMBUSTIBLE-MIGRATION : un cadre sans projet de champ vivant (bande refusée ou annulée, réseau du charbon jamais demandé) libère ses tuiles retenues
    local alive = {}
    for _, pid in ipairs(b.order) do
      local q = b.projects[pid]
      local qc = q and q.spec and q.spec.champ
      if qc and q.state ~= "refuse" then alive[qc.oid] = true end
    end
    for _, oid in ipairs(Cd.dead(Cd.owners(b.occ), alive)) do
      local n = Cd.clear(b.occ, oid)
      log(string.format("[FO-CHAMP] %s : cadre de l'avant-poste %d sans projet de champ vivant : %d tuile(s) retenue(s) pour son reseau du charbon liberee(s) a %.1f min", f.key or "player", oid, n, tick / 3600))
    end
  end
  local st, miss, ids = {}, {}, {}
  local d = { n = 0, run = 0, stuck = 0, nopow = 0 }
  local fu = { n = 0, run = 0, noin = 0, nofuel = 0, full = 0 }
  local out = { n = 0, sum = 0, max = 0, due = 0 }
  local fuel = { n = 0, min = nil }
  local cds = { n = 0, d = 0, stuck = 0, fini = 0, ids = {} } -- lot COUPLAGE : bandes culs-de-sac
  local bad = {} -- bandes finies dont une pièce manque au terrain (détruite) ou dont des foreuses sont figées : détail par projet
  local lost_all = {} -- s42 causal : pièces manquantes des bandes finies, par rôle, toutes bandes (lu par script/ai3/causal_rt.lua)
  local S = defines.entity_status
  local tapis_on, nopow_logs = Champ.tapis(), 0
  local vlogs = 0 -- lot COMBUSTIBLE-MIGRATION : lignes [FO-CHAMP-VOIE] de ce relevé
  local fours = {} -- lot COMBUSTIBLE : fours à brûleur debout par champ { [oid] = { rows = { { id, dry } }, ents = { [id] = entité } } }
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.spec and p.spec.champ then
      ids[#ids + 1] = pid
      -- (lot CHAMP : raison d'une bande en réserve ET d'une bande refusée ou annulée, coupée à 40 caractères)
      local key = p.state .. (((p.state == "reserve" or p.state == "refuse") and p.reason) and (":" .. tostring(p.reason):sub(1, 40)) or "")
      st[key] = (st[key] or 0) + 1
      if p.state == "reserve" then
        for _, m in ipairs(p.missing or {}) do miss[m[1]] = (miss[m[1]] or 0) + (m[2] or 0) end
      end
      local pd = { lost = {}, stuck = 0, noin = 0, armoff = 0, fn = 0, fnofuel = 0, dn = 0, run = 0, ffull = 0 } -- (s41 zone-aveugle : run, ffull)
      -- s40 champ p4 : UNE recherche au moteur par pièce et par relevé (les trois boucles ci-dessous relisaient la même pièce jusqu'à trois
      -- fois : état, voie de charbon, sans courant) ; `found[i]` : l'entité valide de la pièce i, ou false ; mêmes lignes de journal
      local found = {}
      local function ent_of(i, e)
        local c = found[i]
        if c == nil then
          local ent = surface.find_entity(e.name, { e.x, e.y })
          c = (ent and ent.valid) and ent or false
          found[i] = c
        end
        return c or nil
      end
      for i, e in ipairs(p.ents) do
        if e.built and not e.skipped and not e.dropped and p.state == "fini" and not (e.role == "champ-foreuse" or e.role == "champ-four") then
          local ent = ent_of(i, e)
          if not (ent and ent.valid) then pd.lost[e.role or "?"] = (pd.lost[e.role or "?"] or 0) + 1
          elseif e.role == "champ-bras" and (ent.status == S.no_power or ent.status == S.low_power) then pd.armoff = pd.armoff + 1 end
        end
        if e.built and not e.skipped and not e.dropped and (e.role == "champ-foreuse" or e.role == "champ-four") then
          local ent = ent_of(i, e)
          if not (ent and ent.valid) and p.state == "fini" then pd.lost[e.role] = (pd.lost[e.role] or 0) + 1 end
          if ent and ent.valid then
            local s = ent.status
            if e.role == "champ-foreuse" then
              d.n = d.n + 1
              pd.dn = pd.dn + 1
              if s == S.working then d.run = d.run + 1; pd.run = pd.run + 1 elseif s == S.waiting_for_space_in_destination then d.stuck = d.stuck + 1; pd.stuck = pd.stuck + 1
              elseif s == S.no_power or s == S.low_power then d.nopow = d.nopow + 1 end
            else
              fu.n = fu.n + 1
              pd.fn = pd.fn + 1
              if s == S.no_fuel then pd.fnofuel = pd.fnofuel + 1 elseif s == S.full_output then pd.ffull = pd.ffull + 1 elseif s == S.working then pd.run = pd.run + 1 end
              if ent.burner and ent.unit_number then -- lot COMBUSTIBLE : un four à brûleur du champ, à sec ou non (règle Rv.field_burners)
                local fo = fours[p.spec.champ.oid]
                if not fo then fo = { rows = {}, ents = {} }; fours[p.spec.champ.oid] = fo end
                fo.rows[#fo.rows + 1] = { id = ent.unit_number, dry = s == S.no_fuel }
                fo.ents[ent.unit_number] = ent
              end
              if s == S.working then fu.run = fu.run + 1 elseif s == S.no_ingredients then fu.noin = fu.noin + 1; pd.noin = pd.noin + 1
              elseif s == S.no_fuel then fu.nofuel = fu.nofuel + 1 elseif s == S.full_output then fu.full = fu.full + 1 end
            end
          end
        end
      end
      -- s41 zone-aveugle : ce relevé EST la lecture de la bande par l'équipe ; il la garde (seul écrivain de p.champ_read, règle Rv.field_read),
      -- lue par la vue « Cerveau » (script/debug/lecture.lua) : avant, rien n'était conservé et la bande était « jamais lue »
      p.champ_read = Rv.field_read(pd.fn + pd.dn, pd.run, pd.fnofuel, pd.ffull, tick)
      -- lot COMBUSTIBLE-MIGRATION : état de la VOIE DE CHARBON du projet (tapis posés, avec du charbon, vides ; foreuses du charbon) et fours sans combustible
      -- de sa bande : lecture seule, une ligne par projet qui porte du charbon ou des fours, 8 lignes au plus par relevé (cause des fours à sec des fins de partie)
      if vlogs < 8 then
        local planned, belts, withc, empty, dr, drun, dstuck = 0, 0, 0, 0, 0, 0, 0
        for i, e in ipairs(p.ents) do
          if e.role == "champ-charbon" and not e.skipped and not e.dropped then
            planned = planned + 1
            if e.built then
              local ent = ent_of(i, e)
              if ent and ent.valid then
                local pr = ent.prototype -- (un tapis a une vitesse de tapis, une foreuse une vitesse de minage : lus au prototype, aucun nom écrit)
                if pr.belt_speed ~= nil and ent.get_max_transport_line_index() > 0 then
                  belts = belts + 1
                  local n = ent.get_transport_line(1).get_item_count() + ent.get_transport_line(2).get_item_count()
                  if n > 0 then withc = withc + 1 else empty = empty + 1 end
                elseif pr.mining_speed ~= nil then
                  dr = dr + 1
                  if ent.status == S.working then drun = drun + 1 elseif ent.status == S.waiting_for_space_in_destination then dstuck = dstuck + 1 end
                end
              end
            end
          end
        end
        if planned > 0 or pd.fn > 0 then
          vlogs = vlogs + 1
          log(string.format("[FO-CHAMP-VOIE] %s min %.0f | projet %d (%s, %s) : voie de charbon : %d pieces au plan, tapis poses %d (avec du charbon %d, vides %d), foreuses de charbon %d (en marche %d, bloquees sortie pleine %d) ; fours de la bande %d, sans combustible %d",
            f.key or "player", tick / 3600, pid, p.state, p.spec.champ.coal and ("reseau du charbon cote " .. (p.spec.champ.coal > 0 and "+" or "-")) or ("bande " .. tostring(p.spec.champ.pr)),
            planned, belts, withc, empty, dr, drun, dstuck, pd.fn, pd.fnofuel))
        end
      end
      -- lot FONDERIE (3/11) : consommateurs électriques posés SANS courant, chantier compris (lot7bis-20261020 : 15 à 22 bras hors réseau
      -- de 50 à 130 min, vus par aucun relevé)
      if tapis_on then
        local cons, off, at, at_net = 0, 0, nil, nil
        for i, e in ipairs(p.ents) do
          if e.built and not e.skipped and (e.role == "champ-bras" or e.role == "champ-foreuse" or e.role == "champ-charbon") then
            local ent = ent_of(i, e)
            if ent and ent.valid and ent.prototype.electric_energy_source_prototype then
              cons = cons + 1
              if ent.status == S.no_power then
                off = off + 1
                if not at then at, at_net = { x = e.x, y = e.y }, ent.electric_network_id end
              end
            end
          end
        end
        if off > 0 and nopow_logs < 4 then
          nopow_logs = nopow_logs + 1
          -- lot COURANT-BANDE (V0675-A, graine 1618033988, 47 et 57 min) : le statut « no_power » vaut aussi quand le réseau est joint mais ne produit
          -- rien (centrale détruite, chaudière à sec) : on lit d'abord le réseau du consommateur contre les réseaux à génératrice, puis sa
          -- production ; le poteau alimenté le plus proche n'est cherché que si le réseau n'est PAS joint (Ra.cause_sans_courant, règle pure)
          local live = Gens.networks(surface, f.force, "generator")
          local kw, dist = 0, nil
          if at_net and live[at_net] then
            for _, g in ipairs(Gens.list(surface, f.force, "generator")) do
              if g.electric_network_id == at_net then kw = kw + (g.energy_generated_last_tick or 0) * 60 / 1000 end
            end
          elseif at_net then
            local np = powered_pole(f, surface, at.x, at.y, Champ.CFG.chain_far)
            dist = np and math.sqrt((np.x - at.x) ^ 2 + (np.y - at.y) ^ 2) or nil
          end
          log(string.format("[FO-FONDERIE] bande sans courant : %s min %.0f, projet %d (%s, bande %s, %s) : %d consommateur(s) sans courant sur %d, %s",
            f.key or "player", tick / 3600, pid, p.state, tostring(p.spec.champ.pr), p.spec.champ.coal and "reseau du charbon" or "bande", off, cons,
            Ra.cause_sans_courant(at_net, live, kw, dist, Champ.CFG.chain_far)))
        end
      end
      -- lot COUPLAGE (règle 2 du DC, 12/11 : une bande n'est pas finie tant que son tapis ne nourrit pas une fonderie) : bande à foreuses
      -- posées SANS four ni coffre de sortie (tapis collecteur arrêté dans l'herbe), lecture seule
      if pd.dn > 0 and pd.fn == 0 and #(p.outs or {}) == 0 and not p.spec.champ.coal then
        cds.n, cds.d, cds.stuck = cds.n + 1, cds.d + pd.dn, cds.stuck + pd.stuck
        if p.state == "fini" then cds.fini = cds.fini + 1 end
        if #cds.ids < 6 then cds.ids[#cds.ids + 1] = string.format("p%d %s %d/%d", pid, p.state, pd.stuck, pd.dn) end
      end
      local lk = sorted_keys(pd.lost)
      for _, k in ipairs(lk) do lost_all[k] = (lost_all[k] or 0) + pd.lost[k] end
      if (#lk > 0 or pd.stuck > 0 or pd.armoff > 0) and #bad < 4 then
        local lt = {}
        for _, k in ipairs(lk) do lt[#lt + 1] = k .. " " .. pd.lost[k] end
        bad[#bad + 1] = string.format("p%d bande %s : figees %d, fours sans entree %d, bras sans courant %d, pieces manquantes [%s]", pid,
          tostring(p.spec.champ.pr), pd.stuck, pd.noin, pd.armoff, table.concat(lt, ", "))
      end
      for _, o in ipairs(p.outs or {}) do
        local c = surface.find_entity(D.CHEST, { o.x, o.y })
        if c and c.valid then
          local n = c.get_inventory(defines.inventory.chest).get_item_count()
          out.n, out.sum, out.max = out.n + 1, out.sum + n, math.max(out.max, n)
          if n >= (o.at or Build.COLLECT_AT) then out.due = out.due + 1 end
        end
      end
      for _, q in ipairs(p.quais or {}) do
        local c = surface.find_entity(D.CHEST, { q.x, q.y })
        if c and c.valid then
          local n = c.get_item_count(q.item)
          fuel.n, fuel.min = fuel.n + 1, math.min(fuel.min or n, n)
        end
      end
    end
  end
  Champ.field_burners(f, fours, tick)
  local rd = { d = d, fu = fu, lost = lost_all } -- s42 causal : les comptes du relevé, rendus à l'audit des causes
  if #ids == 0 then return rd end
  log(string.format("[FO-COUPLAGE] %s min %.0f | bandes a foreuses sans four ni coffre de sortie %d (finies %d), foreuses %d dont figees %d%s",
    f.key or "player", tick / 3600, cds.n, cds.fini, cds.d, cds.stuck, #cds.ids > 0 and (" : " .. table.concat(cds.ids, ", ")) or ""))
  local parts, mparts = {}, {}
  for _, k in ipairs(sorted_keys(st)) do parts[#parts + 1] = k .. " " .. st[k] end
  local mk = sorted_keys(miss)
  table.sort(mk, function(a, c) if miss[a] ~= miss[c] then return miss[a] > miss[c] end return a < c end)
  for i, k in ipairs(mk) do if i <= 5 then mparts[#mparts + 1] = k .. " " .. miss[k] end end
  log(string.format("[FO-CHAMP-ETAT] %s min %.0f | bandes %d (%s)%s | foreuses %d (marche %d, figees %d, sans courant %d) | fours %d (marche %d, sans entree %d, sans combustible %d, sortie pleine %d) | coffres de sortie %d (plaques %d, max %d, %d au seuil de collecte) | coffres de combustible %d (charbon min %s)",
    f.key or "player", tick / 3600, #ids, table.concat(parts, ", "), #mparts > 0 and (" ; manque " .. table.concat(mparts, ", ")) or "",
    d.n, d.run, d.stuck, d.nopow, fu.n, fu.run, fu.noin, fu.nofuel, fu.full, out.n, out.sum, out.max, out.due, fuel.n, tostring(fuel.min or "-"))
    .. (#bad > 0 and (" | " .. table.concat(bad, " ; ")) or ""))
  -- Lot CUMUL (13/11, demande du DC : « vérifiez bien vos chiffres ») : cumuls du MOTEUR depuis le début de la partie, les
  -- mêmes compteurs que la fenêtre de production du jeu (item_production_statistics : entrée = extrait ou produit, sortie =
  -- consommé), pour que la partie du DC et le banc se comparent ligne à ligne. Lecture seule.
  local cum = {}
  pcall(function()
    local stats = game.forces[f.force].item_production_statistics
    for _, k in ipairs(sorted_keys(T.outposts)) do
      local o = T.outposts[k]
      if o.resource ~= o.product then
        cum[#cum + 1] = string.format("%s extrait %d consomme %d", o.resource, stats.get_input_count(o.resource), stats.get_output_count(o.resource))
      end
      cum[#cum + 1] = string.format("%s produit %d consomme %d", o.product, stats.get_input_count(o.product), stats.get_output_count(o.product))
    end
  end)
  log(string.format("[FO-CUMUL] %s min %.0f | %s", f.key or "player", tick / 3600, table.concat(cum, " ; ")))
  return rd
end

return Champ
