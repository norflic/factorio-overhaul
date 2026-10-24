--[[
  Niveaux de bâtiments : runtime (session 5 ; 15 époques depuis le lot V2 ; amélioration instantanée et
  condition du centre depuis le lot V2c). Règles : shared/levels/config.lua.

  - Centre de commandement : un par force ; son niveau EST l'époque (1 à 15) ; il plafonne les autres
    bâtiments à 2 × son niveau.
  - Amélioration INSTANTANÉE (Q19 : « si on a les ressources, on améliore, terminé ») : le coût est prélevé
    dans le centre de commandement PUIS dans l'inventaire du joueur (l'usine alimente le centre par
    convoyeurs et inserteurs : la production nourrit la progression), et le bâtiment est aussitôt remplacé
    par le niveau suivant en « remplacement rapide » moteur (contenu, recette, modules, munitions, fils de
    circuit conservés ; santé en proportion ; F39). Plus de durée, plus de bâtiment hors service, plus de
    limite d'ouvriers. Murs : rangée entière possible.
  - Condition du centre (Q16) : pour passer du niveau c à c + 1, chaque famille dont la force possède au
    moins un bâtiment doit en avoir un au niveau min(30, 2c) ; sinon refus « cc-families » (familles qui
    bloquent dans info.blocking, niveau visé dans info.condition_level). Recensement en cache par force pour
    l'affichage, complet pour chaque décision (Levels.census_cached).
  - Sauvegarde 0.4.0 : les chantiers en cours (déjà payés) sont ACHEVÉS au chargement (Levels.finish_legacy_jobs).
  - EMPRISE CROISSANTE (lot V3-T ; Q23, Q24 : « agrandissement sur place si la place autour est libre ; sinon
    l'amélioration est refusée et le contour nécessaire s'affiche ») : quand le niveau suivant a une emprise
    plus grande (table L.footprints), la PLACE est vérifiée AVANT le paiement (Levels.room : tuiles et entités,
    sauf l'ancien bâtiment) ; libre : remplacement PAR SCRIPT à la première position libre de la règle
    (shared/levels/footprint.lua) avec transfert du contenu (Levels.transfer), objets au sol sortis du nouveau
    bâtiment, fantômes recouverts retirés ; aucune libre : refus « no-room », rien de payé, contour de la
    position LA PLUS FACILE À LIBÉRER et de ce qui la bloque dessiné pour une durée limitée (rendering,
    time_to_live : rien dans global). Le panneau dessine aussi, pour son seul joueur, la position retenue (vert)
    ou ce contour (Levels.draw_room). À emprise égale, le remplacement rapide moteur d'avant (F39) est gardé tel
    quel. Sauvegarde d'avant V3-T : les bâtiments dont l'emprise a changé sont réinstallés au chargement
    (Levels.migrate_footprints), sur on_configuration_changed ET, à défaut (sauvegarde rechargée sans
    changement de version), au premier passage du filet on_nth_tick(30).
  - POINTS SERVIS (lot V3-T2, correction) : une position qui ferait sortir le point de dépôt d'une foreuse de son
    coffre (ou de son convoyeur), ou un raccord de tuyau de son tuyau, n'est pas libre (Levels.served_points,
    shared/levels/points.lua) ; le contour montre l'entité servie en jaune.
  - LIBÉRER LA PLACE (lot V3-T3, Q-T2-1 : « QT21 option B ») : script/levels/free.lua (bouton du panneau, demande
    d'agrandissement en attente) ; ici, seulement la restriction d'une décision à une position (Levels.room, only_box ;
    Levels.preview et Levels.start, opts.box). La règle Q24 ne change pas.
  Déterminisme : tout se passe dans des événements ; listes triées (chantiers hérités par numéro, surfaces
  par index), jamais l'ordre de pairs.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local Foot = require("shared.levels.footprint")
local Points = require("shared.levels.points")

local Levels = {}

-- `jobs` et `busy` restent des tables VIDES : ils portaient les chantiers minutés de 0.4.0 (achevés au
-- chargement) et l'interface distante (script/remote.lua, levels_status) les lit encore ; à retirer avec
-- le diff proposé à l'intégrateur. `census` : recensement Q16 en cache, par force (voir plus bas).
Storage.declare("levels", function()
  -- footprints (lot V3-T) : relevé des emprises de la version qui a écrit la sauvegarde (nombres seulement),
  -- comparé à la table au chargement (Levels.migrate_footprints) ; absent dans une sauvegarde d'avant V3-T.
  return { cc = {}, jobs = {}, busy = {}, census = {}, replacing = false, footprints = L.footprint_snapshot(),
           stats = { upgrades = 0, instant = 0, cancelled = 0, lost = 0, census_scans = 0 } }
end)

local function S() return Storage.ns("levels") end

Levels.parse = L.parse

---------------------------------------------------------------------------------------------------
-- Centre de commandement
---------------------------------------------------------------------------------------------------
--- Centre de commandement valide de la force, ou nil.
function Levels.cc(force)
  local rec = S().cc[force.name]
  if rec and rec.valid then return rec end
  return nil
end

function Levels.cc_level(force)
  local cc = Levels.cc(force)
  if not cc then return 0 end
  local _, n = L.parse(cc.name)
  return n or 0
end

--- Ouvriers occupés : toujours 0 depuis Q19 (amélioration instantanée). Gardé pour l'interface distante
--- (script/remote.lua, levels_status) jusqu'à l'intégration du diff proposé.
function Levels.busy(force)
  return 0
end

---------------------------------------------------------------------------------------------------
-- Objets de coût : chaque objet de la table d'indirection doit exister dans le jeu chargé.
-- Cache LOCAL (jamais dans global), dérivé des prototypes, identiques sur tous les clients ; rempli au
-- premier appel pendant un événement (game n'existe pas pendant on_load).
---------------------------------------------------------------------------------------------------
local item_cache = {}

function Levels.item_exists(name)
  local known = item_cache[name]
  if known == nil then
    known = game.item_prototypes[name] ~= nil
    item_cache[name] = known
  end
  return known
end

--- Objets de coût absents du jeu (liste triée ; vide si tout va bien).
function Levels.missing_cost_items()
  local out = {}
  for _, item in ipairs(L.cost_items()) do
    if not Levels.item_exists(item) then out[#out + 1] = item end
  end
  return out
end

local function check_cost_items()
  local miss = Levels.missing_cost_items()
  if #miss > 0 then
    log("[FO-LEVELS] ERREUR : objets de coût absents du jeu : " .. table.concat(miss, ", "))
  else
    log("[FO-LEVELS] " .. #L.cost_items() .. " objets de coût, tous présents ; "
      .. #L.provisional_materials() .. " matériaux d'époque provisoires")
  end
end

Events.on_init(check_cost_items)
Events.on_configuration_changed(check_cost_items)

---------------------------------------------------------------------------------------------------
-- Paiement : centre de commandement d'abord, puis inventaire du joueur.
---------------------------------------------------------------------------------------------------
local function sources(force, player)
  local invs = {}
  local cc = Levels.cc(force)
  if cc then invs[#invs + 1] = cc.get_inventory(defines.inventory.chest) end
  if player and player.valid then
    local m = player.get_main_inventory()
    if m then invs[#invs + 1] = m end
  end
  return invs
end

local function available(invs, item)
  local n = 0
  for _, inv in ipairs(invs) do n = n + inv.get_item_count(item) end
  return n
end

--- Manque pour payer `cost` : liste { {objet, il_manque} } (vide si payable).
local function missing(invs, cost)
  local m = {}
  for _, c in ipairs(cost) do
    local have = available(invs, c[1])
    if have < c[2] then m[#m + 1] = { c[1], c[2] - have } end
  end
  return m
end

--- Prélève `cost` dans `invs`, dans l'ordre (centre, puis joueur). Renvoie le RELEVÉ des retraits effectifs
--- { {inv, objet, quantité} } (correction V3-T, défauts 6 et 17 : le remboursement rend chaque part à
--- l'inventaire qui l'a payée).
local function pay(invs, cost)
  local ledger = {}
  for _, c in ipairs(cost) do
    local left = c[2]
    for _, inv in ipairs(invs) do
      if left <= 0 then break end
      local got = inv.remove({ name = c[1], count = left })
      if got > 0 then ledger[#ledger + 1] = { inv = inv, item = c[1], count = got } end
      left = left - got
    end
  end
  return ledger
end

Levels.sources = sources
Levels.available = available
Levels.pay = pay

---------------------------------------------------------------------------------------------------
-- Condition du centre (Q16) : recensement des familles de la force
---------------------------------------------------------------------------------------------------
-- Listes de noms par famille et par niveau plancher : dérivées de la config seule (identiques sur tous
-- les clients), construites au chargement du module.
local family_names = {}  -- [clé] = { tous les niveaux }
local names_from = {}    -- [clé][niveau] = { niveaux niveau..max }
for _, f in ipairs(L.families) do
  if f.key ~= "command" then
    local all = {}
    for n = 1, f.max do all[n] = L.name(f, n) end
    family_names[f.key] = all
    names_from[f.key] = {}
    for top = 1, f.max do
      local list = {}
      for n = top, f.max do list[#list + 1] = L.name(f, n) end
      names_from[f.key][top] = list
    end
  end
end

local function sorted_surfaces()
  local by_index, idx = {}, {}
  for _, surface in pairs(game.surfaces) do by_index[surface.index] = surface end
  for i in pairs(by_index) do idx[#idx + 1] = i end
  table.sort(idx)
  local out = {}
  for _, i in ipairs(idx) do out[#out + 1] = by_index[i] end
  return out
end

local function exists(surfaces, force, names)
  for _, s in ipairs(surfaces) do
    if s.count_entities_filtered({ force = force, name = names, limit = 1 }) > 0 then return true end
  end
  return false
end

--- Recensement COMPLET de la force pour la condition du centre : census[clé] = { any, top } (L.cc_blockers).
--- Coût : au plus 2 recherches par famille et par surface (12 par surface), SANS zone : sur une grande carte,
--- une famille absente ou sous le niveau visé coûte un balayage de toute la surface (limit = 1 n'arrête qu'au
--- premier bâtiment trouvé). D'où le cache ci-dessous : ce balayage n'est fait qu'à la demande.
function Levels.census(force, top)
  local st = S()
  st.stats.census_scans = (st.stats.census_scans or 0) + 1
  local surfaces = sorted_surfaces()
  local out = {}
  for _, f in ipairs(L.families) do
    if f.key ~= "command" then
      local at_top = exists(surfaces, force, names_from[f.key][math.min(top, f.max)])
      local any = at_top or exists(surfaces, force, family_names[f.key])
      out[f.key] = { any = any, top = at_top }
    end
  end
  return out
end

--- Correction V2c (vérification) : le panneau du centre se rafraîchit toutes les 30 ticks, pour chaque joueur
--- qui l'a ouvert ; avec le recensement complet à chaque aperçu, une base de 60 h aurait payé 12 balayages de
--- surface toutes les 30 ticks (coût en moteur réel non mesuré). Le recensement est donc gardé EN CACHE par
--- force, dans global (même état sur tous les clients) :
---   - une construction d'un bâtiment à niveaux de la force le met à jour EXACTEMENT (any, et top si le
---     niveau atteint le niveau visé) ; une amélioration aussi (le remplacement est une construction) ;
---   - un retrait (minage, mort, destruction par script) l'INVALIDE (la famille peut disparaître) ;
---   - il expire après CENSUS_TTL ticks (filet pour ce qu'aucun événement ne signale : changement de force,
---     clonage, entité créée par un autre mod sans raise_built) ;
---   - une DÉCISION (Levels.start : touche U, bouton, interface distante) refait toujours le recensement
---     complet : le cache ne sert qu'à l'AFFICHAGE du panneau.
--- Au plus un balayage par force et par CENSUS_TTL ticks pendant qu'un panneau du centre reste ouvert, plus un
--- par retrait de bâtiment à niveaux suivi d'un rafraîchissement.
Levels.CENSUS_TTL = 600

function Levels.census_cached(force, top, fresh)
  local st = S()
  st.census = st.census or {}
  local c = st.census[force.name]
  if fresh or not (c and c.top == top and game.tick - c.tick < Levels.CENSUS_TTL) then
    c = { tick = game.tick, top = top, data = Levels.census(force, top) }
    st.census[force.name] = c
  end
  return c.data
end

--- Construction (ou amélioration) d'un bâtiment à niveaux : mise à jour exacte du cache de sa force.
local function census_built(entity, family, n)
  local census = S().census
  local c = census and census[entity.force.name]
  if not c then return end
  local d = c.data[family.key]
  if not d then return end
  d.any = true
  if n >= math.min(c.top, family.max) then d.top = true end
end

--- Retrait d'un bâtiment à niveaux : le cache de sa force est invalidé.
local function census_removed(entity)
  local census = S().census
  if census then census[entity.force.name] = nil end
end

---------------------------------------------------------------------------------------------------
-- Remplacement par le niveau suivant
---------------------------------------------------------------------------------------------------
local function box_size(entity)
  local b = entity.prototype.selection_box
  return b.right_bottom.x - b.left_top.x, b.right_bottom.y - b.left_top.y
end

local function manual_replace(old, name)
  -- Secours si le remplacement rapide échoue : contenus et recette recopiés (fils de circuit perdus).
  local surface, pos, dir, force = old.surface, old.position, old.direction, old.force
  local recipe = old.type == "assembling-machine" and old.get_recipe() or nil
  -- Déterminisme (ARCHITECTURE §2) : inventaires dans l'ordre des index, objets dans l'ordre des noms (ce
  -- qui déborde au sol quand l'inventaire est plein ne dépend d'aucun ordre de pairs).
  local saved = {}
  for i = 1, 10 do
    local inv = old.get_inventory(i)
    if inv and not inv.is_empty() then
      local contents = inv.get_contents()
      local names = {}
      for item in pairs(contents) do names[#names + 1] = item end
      table.sort(names)
      local list = {}
      for _, item in ipairs(names) do list[#list + 1] = { item, contents[item] } end
      saved[#saved + 1] = { index = i, items = list }
    end
  end
  old.destroy({ raise_destroy = false })
  local new = surface.create_entity({ name = name, position = pos, direction = dir, force = force, raise_built = true, create_build_effect_smoke = false })
  if not new then return nil end
  if recipe then new.set_recipe(recipe) end
  for _, rec in ipairs(saved) do
    local inv = new.get_inventory(rec.index)
    for _, it in ipairs(rec.items) do
      local item, count = it[1], it[2]
      local put = inv and inv.insert({ name = item, count = count }) or 0
      if put < count then surface.spill_item_stack(pos, { name = item, count = count - put }, true, force, false) end
    end
  end
  return new
end

---------------------------------------------------------------------------------------------------
-- Emprise croissante (lot V3-T) : place, contour, transfert du contenu, remplacement par script
---------------------------------------------------------------------------------------------------
--- Types qui ne bloquent jamais un agrandissement : le personnage est écarté par le moteur
--- (create_entity{move_stuck_players = true}), une unité se dégage seule, un objet au sol est SORTI du nouveau
--- bâtiment après l'agrandissement (move_ground_items : sinon il resterait hors de portée de ramassage).
--- Tout le reste bloque s'il partage une couche de collision avec le nouveau bâtiment (arbre, rocher, falaise,
--- mur, coffre, véhicule, autre bâtiment…) ; un fantôme (« ghost-layer ») et une ressource (« resource-layer »)
--- n'en partagent aucune.
Levels.NON_BLOCKING = { character = true, unit = true, ["item-entity"] = true }
--- Durée d'affichage du contour d'un refus « no-room » (ticks) : effacé par le moteur, rien dans global.
Levels.CONTOUR_TTL = 300
--- Au plus tant d'entités et de tuiles bloquantes surlignées par refus (lisibilité, coût de rendu).
Levels.CONTOUR_MAX_MARKS = 24

--- Couches d'un masque de collision (dictionnaire couche → true), triées (jamais l'ordre de pairs).
local function mask_layers(mask)
  local out = {}
  for layer in pairs(mask or {}) do out[#out + 1] = layer end
  table.sort(out)
  return out
end

--- Un masque partage-t-il une des couches `layers` ?
local function shares(layers, mask)
  if not mask then return false end
  for _, layer in ipairs(layers) do
    if mask[layer] then return true end
  end
  return false
end

--- `e` bloquerait-il le remplacement de `entity` (masque du nouveau prototype : `layers`) ? Tout sauf l'ancien
--- bâtiment, les types de NON_BLOCKING et ce qui ne partage aucune couche (fantôme, ressource, cadavre).
local function blocks(entity, e, layers)
  return e.valid and e ~= entity and not Levels.NON_BLOCKING[e.type] and shares(layers, e.prototype.collision_mask)
end
-- Lot V3-T3 (correction, défauts 2 et 20) : le relevé de « libérer la place » (script/levels/free.lua) prend
-- EXACTEMENT le même critère de gêne que Levels.room (voiture, char, araignée, wagons, signaux ferroviaires compris).
Levels.mask_layers = mask_layers
Levels.blocks = blocks

--- Clé d'une entité (numéro d'unité ; sinon nom et position) : un même enregistrement par entité (Levels.room).
local function entity_key(e)
  return e.unit_number or (e.name .. "@" .. e.position.x .. "," .. e.position.y)
end

--- Enregistrement d'une gêne (données simples) : boîte de collision sur la carte, nom, type, position.
local function record(e)
  local bb = e.bounding_box
  return { box = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y },
           name = e.name, type = e.type, x = e.position.x, y = e.position.y }
end

--- Carré de tuiles qui représente l'emprise ACTUELLE de `entity` (côté `side`) pour la règle de position.
--- Sur la grille : le carré exact. HORS grille (lot V3-T2 : bâtiment « laissé en place » par une migration, F76 : un
--- côté impair centré sur un coin de tuile, ou l'inverse ; les deux axes à la fois pour un bâtiment carré posé à
--- l'ancienne taille) : le carré de côté side + 1 qui le contient exactement (sa parité est celle de la position).
--- Conséquences : un agrandissement contient toujours la vraie boîte ; à côté égal (amélioration d'un bâtiment hors
--- grille), les 4 positions sur la grille contenues dans ce carré, dans l'ordre de la règle (shared/levels/footprint.lua,
--- cas « côté plus petit ») : le bâtiment est REMIS sur la grille, à une demi-tuile au plus.
function Levels.current_box(entity, side)
  local pos = entity.position
  if not Levels.off_grid(entity, side) then return Foot.tile_box(pos, side) end
  return Foot.tile_box(pos, side + 1)
end

--- Le bâtiment est-il hors de la grille de son côté (laissé en place par une migration) ? Un bâtiment 1×1 ne l'est
--- jamais : le moteur le pose toujours au centre d'une tuile (F41), et aucune famille 1×1 ne change de taille (mur).
function Levels.off_grid(entity, side)
  if side < 2 then return false end
  return not Foot.aligned(entity.position, side)
end

--- Place pour passer `entity` (emprise actuelle : old_side) au prototype `new_name` de côté new_side.
--- Une seule recherche d'entités et une lecture des tuiles sur la réunion des positions candidates (au plus
--- (2b - a)² tuiles : 49 pour 5 → 6) ; la décision est la fonction pure Foot.evaluate. Renvoie
--- { index, chosen, preferred, target, target_index, candidates, from, to, box_old } (chosen = nil : aucune
--- position libre ; target = la candidate à montrer, shared/levels/footprint.lua F.evaluate).
--- Lot V3-T3 : only_box (carré { x0, y0, x1, y1 }) restreint les candidates à ce seul carré (agrandissement en attente
--- d'une demande « libérer la place » : il ne se fait qu'à la position dont la place a été libérée, aucune autre :
--- ailleurs, les fantômes posés pour cette position pourraient tomber sous le bâtiment). Carré absent des candidates :
--- liste vide, chosen = nil, target = nil.
function Levels.room(entity, old_side, new_name, new_side, only_box)
  local surface = entity.surface
  local old_box = Levels.current_box(entity, old_side)
  local cands = Foot.candidates(old_box, new_side)
  if only_box then
    local keep = {}
    for _, c in ipairs(cands) do
      local b = c.box
      if b.x0 == only_box.x0 and b.y0 == only_box.y0 and b.x1 == only_box.x1 and b.y1 == only_box.y1 then keep[#keep + 1] = c end
    end
    cands = keep
  end
  local area = Foot.search_box(old_box, new_side)
  local proto = game.entity_prototypes[new_name]
  local layers = mask_layers(proto and proto.collision_mask)
  -- Tuiles : celles qui entrent en collision avec le masque du nouveau prototype (eau, hors carte…).
  local tiles = {}
  if #layers > 0 then
    for y = area.y0, area.y1 - 1 do
      for x = area.x0, area.x1 - 1 do
        local t = surface.get_tile(x, y)
        for _, layer in ipairs(layers) do
          if t.collides_with(layer) then
            tiles[#tiles + 1] = { x = x, y = y, name = t.name }
            break
          end
        end
      end
    end
  end
  -- Entités qui touchent la zone (moteur : boîte de collision) et partagent une couche, sauf l'ancien bâtiment.
  local blockers, by_key = {}, {}
  if #layers > 0 then
    local found = surface.find_entities_filtered({ area = { { area.x0, area.y0 }, { area.x1, area.y1 } } })
    for _, e in ipairs(found) do
      if blocks(entity, e, layers) then
        local rec = record(e)
        blockers[#blockers + 1] = rec
        by_key[entity_key(e)] = rec
      end
    end
  end
  -- Lot V3-T2 (correction, défauts 1 et 6) : positions qui déplaceraient un point de jeu servi = bloquées.
  local points = Levels.served_points(entity, old_side, new_side, layers, by_key)
  Points.mark(cands, points)
  local res = Foot.evaluate(cands, tiles, blockers, Foot.MARGIN)
  res.from, res.to, res.box_old, res.points = old_side, new_side, old_box, points
  return res
end

--- Types de convoyeurs (1.1.91) : un dépôt de foreuse sur l'un d'eux reste servi par n'importe lequel (Points.mark, alt).
local BELT_LIST = { "transport-belt", "underground-belt", "splitter", "linked-belt", "loader", "loader-1x1" }
local BELT_TYPES = {}
for _, t in ipairs(BELT_LIST) do BELT_TYPES[t] = true end

--- Points de jeu SERVIS de `entity` pour un passage du côté from au côté to (lot V3-T2, correction des défauts 1 et
--- 6 du correcteur ; règle : shared/levels/points.lua) : le point de dépôt d'une foreuse (drop_position) et les
--- raccords de tuyau de ses boîtes à fluide actives (get_pipe_connections : target_position, raccords souterrains
--- exclus), lus sur l'entité, ramenés à l'orientation nord, puis portés à l'ANCIEN côté (from) et au NOUVEAU (to).
--- Un point est servi si une entité qui bloquerait le nouveau bâtiment (blocks) se trouve à l'ancien point (pour un
--- raccord : une entité à boîte à fluide). Migration (le prototype a déjà la nouvelle taille, F76) : les points lus
--- sont ceux du NOUVEAU prototype à l'ancienne position ; l'ancien point est recalculé par la règle (base, puis
--- from). by_key : enregistrements des gênes de Levels.room (même table pour une même entité : pas de doublon dans
--- Foot.evaluate). Renvoie { { rel, box, kind, entity } } (Points.mark).
function Levels.served_points(entity, from, to, layers, by_key)
  local out = {}
  local family, lvl = L.parse(entity.name)
  if not family or #layers == 0 then return out end
  local raw = {}
  if entity.type == "mining-drill" then
    local d = entity.drop_position
    if d then raw[#raw + 1] = { kind = "drop", x = d.x, y = d.y } end
  end
  local fb = entity.fluidbox
  if fb then
    for i = 1, #fb do
      for _, pc in ipairs(fb.get_pipe_connections(i) or {}) do
        if pc.connection_type ~= "underground" and pc.target_position then
          raw[#raw + 1] = { kind = "pipe", x = pc.target_position.x, y = pc.target_position.y }
        end
      end
    end
  end
  if #raw == 0 then return out end
  -- Côté du prototype ACTUEL (table : la boîte de sélection d'un prototype vanilla n'est pas toujours carrée).
  local pos, dir, cur = entity.position, entity.direction or 0, L.footprint(family, lvl)
  local surface = entity.surface
  for _, r in ipairs(raw) do
    local rel = Points.unrotate({ x = r.x - pos.x, y = r.y - pos.y }, dir)
    local t = Points.transpose(rel, family.size, cur, from, to, dir)
    local px, py = pos.x + t.old.x, pos.y + t.old.y
    local found = surface.find_entities_filtered({ area = { { px - 0.01, py - 0.01 }, { px + 0.01, py + 0.01 } } })
    for _, e in ipairs(found) do
      if blocks(entity, e, layers) and (r.kind ~= "pipe" or (e.fluidbox and #e.fluidbox > 0)) then
        local key = entity_key(e)
        local rec = (by_key and by_key[key]) or record(e)
        if by_key then by_key[key] = rec end
        if Points.inside(rec.box, px, py) then
          local pt = { rel = t.new, box = rec.box, kind = r.kind, entity = rec, x = px, y = py }
          -- Dépôt sur un convoyeur : tout convoyeur au nouveau point le sert aussi (même ligne en général).
          if r.kind == "drop" and BELT_TYPES[e.type] then
            local nx, ny = pos.x + t.new.x, pos.y + t.new.y
            local reach = math.abs(to - from) + 1
            pt.alt = {}
            for _, o in ipairs(surface.find_entities_filtered({ area = { { nx - reach, ny - reach }, { nx + reach, ny + reach } },
                type = BELT_LIST })) do
              if o.valid and o ~= e then pt.alt[#pt.alt + 1] = record(o).box end
            end
          end
          out[#out + 1] = pt
          break
        end
      end
    end
  end
  return out
end

--- Ce qui bloque une candidate, en texte court et trié : « [entity=stone-wall]×2 [tile=water]×3 » (texte
--- enrichi du moteur, sans clé de traduction : les icônes suffisent). Vide si rien. Lot V3-T2 : une entité dont
--- un point de jeu servi sortirait (cand.moved) compte comme une gêne (la retirer libère la position).
function Levels.blockers_text(cand)
  if not cand then return "" end
  local count, names = {}, {}
  local function add(tag)
    if not count[tag] then names[#names + 1] = tag; count[tag] = 0 end
    count[tag] = count[tag] + 1
  end
  for _, e in ipairs(cand.entities or {}) do add("[entity=" .. e.name .. "]") end
  for _, e in ipairs(cand.moved or {}) do add("[entity=" .. e.name .. "]") end
  for _, t in ipairs(cand.tiles or {}) do add("[tile=" .. t.name .. "]") end
  table.sort(names)
  local parts = {}
  for _, tag in ipairs(names) do parts[#parts + 1] = count[tag] > 1 and (tag .. "×" .. count[tag]) or tag end
  return table.concat(parts, " ")
end

--- Noms de ce qui bloque une candidate (interface distante, tests) : entités, « point:<nom> » pour une entité dont
--- un point de jeu servi sortirait (lot V3-T2), « tile:<nom> » pour une tuile ; triés.
function Levels.blocker_names(cand)
  local out = {}
  if not cand then return out end
  for _, e in ipairs(cand.entities or {}) do out[#out + 1] = e.name end
  for _, e in ipairs(cand.moved or {}) do out[#out + 1] = "point:" .. e.name end
  for _, t in ipairs(cand.tiles or {}) do out[#out + 1] = "tile:" .. t.name end
  table.sort(out)
  return out
end

--- Contour d'un refus « no-room » : le carré nécessaire (la candidate À MONTRER, room.target : la plus facile
--- à libérer, shared/levels/footprint.lua), chaque entité qui le bloque et chaque tuile qui le bloque, visibles
--- du seul joueur concerné (sinon de la force du bâtiment), effacés par le moteur au bout de `ttl` ticks
--- (Levels.CONTOUR_TTL par défaut). Rien n'est gardé dans global. preview = true (dessin du panneau, répété à
--- chaque rafraîchissement) : non compté dans stats.contours, qui compte les REFUS dessinés.
local function draw_contour(entity, room, player, ttl, preview)
  local st = S()
  local cand = room.target or room.preferred
  if not cand then return end
  local surface = entity.surface
  local players = (player and player.valid) and { player.index } or nil
  local forces = (not players) and { entity.force.name } or nil
  local function rect(x0, y0, x1, y1, color, width, filled)
    rendering.draw_rectangle({
      color = color, width = width, filled = filled, left_top = { x0, y0 }, right_bottom = { x1, y1 },
      surface = surface, time_to_live = ttl or Levels.CONTOUR_TTL, players = players, forces = forces,
    })
  end
  local b = cand.box
  rect(b.x0, b.y0, b.x1, b.y1, { r = 1, g = 0.55, b = 0.1, a = 0.9 }, 3, false)
  local marks = 0
  for _, e in ipairs(cand.entities or {}) do
    if marks >= Levels.CONTOUR_MAX_MARKS then break end
    marks = marks + 1
    rect(e.box.x0, e.box.y0, e.box.x1, e.box.y1, { r = 1, g = 0.1, b = 0.1, a = 0.9 }, 2, false)
  end
  -- Lot V3-T2 : entité servie dont le point de jeu sortirait à cette position (coffre d'une foreuse, tuyau) : jaune.
  for _, e in ipairs(cand.moved or {}) do
    if marks >= Levels.CONTOUR_MAX_MARKS then break end
    marks = marks + 1
    rect(e.box.x0, e.box.y0, e.box.x1, e.box.y1, { r = 1, g = 0.9, b = 0.1, a = 0.9 }, 2, false)
  end
  for _, t in ipairs(cand.tiles or {}) do
    if marks >= Levels.CONTOUR_MAX_MARKS then break end
    marks = marks + 1
    rect(t.x, t.y, t.x + 1, t.y + 1, { r = 0.6, g = 0.05, b = 0.05, a = 0.35 }, 1, true)
  end
  if not preview then st.stats.contours = (st.stats.contours or 0) + 1 end
end
Levels.draw_contour = draw_contour

--- Aperçu de la place pour le PANNEAU (correction V3-T, défauts 2, 7 et 10), visible du seul `player`, effacé
--- par le moteur au bout de `ttl` ticks : place libre → le carré RETENU en vert pâle (où ira le bâtiment, même
--- s'il glisse vers une autre position que la préférée) ; place prise → le contour du refus (draw_contour).
--- Rien dans global, rien de compté.
function Levels.draw_room(entity, room, player, ttl)
  if not (room and player and player.valid) then return end
  local c = room.chosen
  if not c then
    draw_contour(entity, room, player, ttl, true)
    return
  end
  local b = c.box
  rendering.draw_rectangle({
    color = { r = 0.35, g = 0.9, b = 0.35, a = 0.8 }, width = 2, filled = false, left_top = { b.x0, b.y0 },
    right_bottom = { b.x1, b.y1 }, surface = entity.surface, time_to_live = ttl, players = { player.index },
  })
end

local TURRET_TYPES = { ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, turret = true }
local CRAFTER_TYPES = { ["assembling-machine"] = true, furnace = true, ["rocket-silo"] = true }
-- Réglages du circuit d'une foreuse (LuaMiningDrillControlBehavior, 1.1.91), recopiés après les fils.
local DRILL_CB_KEYS = { "circuit_enable_disable", "connect_to_logistic_network", "circuit_read_resources", "resource_read_mode" }

--- Inventaires de `old` versés dans `new`, index par index (1 à 10, comme manual_replace) : d'abord case par
--- case (transfer_stack : la pile entière passe avec ses données, munitions entamées comprises), puis ce qui
--- reste par contenu, dans l'ordre des noms (cases en nombre différent ; moteur simulé). Dernier recours, jamais
--- attendu (le niveau suivant a au moins les cases du précédent) : renversé au pied du bâtiment, compté et
--- journalisé. Renvoie le nombre d'objets renversés.
--- Lot V3-T2 (correction, défaut 3) : filtres des cases recopiés AVANT les objets (une case filtrée n'accepte que
--- son objet), barre rouge (« bar », limite des bras) APRÈS, et seulement si elle limitait l'ancien inventaire
--- (get_bar ≤ nombre de cases) : sinon la nouvelle garde sa barre par défaut (aucune limite) ; recopier l'index d'un
--- inventaire sans limite bornerait le plus grand inventaire du nouveau bâtiment à la taille de l'ancien.
local function inventory_settings(oi, ni, phase)
  if not (oi and ni) then return end
  if phase == "filters" then
    if oi.supports_filters and oi.supports_filters() and ni.supports_filters() and oi.is_filtered() then
      for k = 1, math.min(#oi, #ni) do
        local f = oi.get_filter(k)
        if f and ni.can_set_filter(k, f) then ni.set_filter(k, f) end
      end
    end
  elseif oi.supports_bar and oi.supports_bar() and ni.supports_bar() then
    local bar = oi.get_bar()
    if bar <= #oi then ni.set_bar(bar) end
  end
end

--- Fonctions appelées quand les MODULES ont été versés dans le nouveau bâtiment, avant ses autres inventaires :
--- f(new). Enregistrées au chargement des modules (lot MOD-1 : la balise de complément est posée tout de suite, la
--- machine a déjà sa vitesse multipliée quand ses ingrédients arrivent).
Levels.on_modules_moved = {}

local function transfer_inventories(old, new)
  local spilled = 0
  -- Lot MOD-1 (moteur réel, banc content du 24/10, 21:53) : l'entrée d'une machine RAPIDE est remplie par ses bras
  -- au-delà d'une pile (15 barils vides pour une pile de 10, machine à deux modules multipliés) ; versée par script
  -- dans une machine encore sans modules, elle n'en reprenait que 10 (5 renversés). Les modules passent donc les
  -- premiers, puis les crochets on_modules_moved, puis les autres inventaires dans l'ordre des index.
  local mi = old.get_module_inventory and old.get_module_inventory()
  local first = mi and mi.index or nil
  local order = {}
  if first then order[#order + 1] = first end
  for i = 1, 10 do
    if i ~= first then order[#order + 1] = i end
  end
  for n, i in ipairs(order) do
    if n == 2 and first then
      for _, f in ipairs(Levels.on_modules_moved) do f(new) end
    end
    local oi = old.get_inventory(i)
    inventory_settings(oi, new.get_inventory(i), "filters")
    if oi and not oi.is_empty() then
      local ni = new.get_inventory(i)
      if ni then
        for k = 1, math.min(#oi, #ni) do
          local stack = oi[k]
          if stack.valid_for_read then ni[k].transfer_stack(stack) end
        end
      end
      if not oi.is_empty() then
        local contents = oi.get_contents()
        local names = {}
        for item in pairs(contents) do names[#names + 1] = item end
        table.sort(names)
        for _, item in ipairs(names) do
          local count = contents[item]
          local put = ni and ni.insert({ name = item, count = count }) or 0
          if put < count then put = put + new.insert({ name = item, count = count - put }) end
          if put > 0 then oi.remove({ name = item, count = put }) end
          if put < count then
            new.surface.spill_item_stack(new.position, { name = item, count = count - put }, true, new.force, false)
            spilled = spilled + count - put
            log("[FO-LEVELS] agrandissement : " .. (count - put) .. " " .. item .. " renversé(s) au sol (inventaire " .. i .. " plein)")
          end
        end
      end
    end
    inventory_settings(oi, new.get_inventory(i), "bar")
  end
  return spilled
end

--- Progressions reportées (lot V3-T2) : global.fo.levels.pending[numéro] = { entity, recipe, progress, bonus, tick }
--- (une entité, des nombres et un nom : aucune fonction). Au plus PENDING_TTL ticks d'attente : passé ce délai (machine
--- sans énergie, sans combustible, autre recette), l'entrée est oubliée ; les ingrédients ont déjà été rendus, rien
--- n'est perdu, seule la fraction de fabrication l'est.
Levels.PENDING_TTL = 3600

--- Fabrication en cours de `old` (crafting machine, is_crafting vrai) : ses ingrédients (déjà pris par le moteur au
--- début de la fabrication) sont rendus à `new` (objets dans ses inventaires, fluides dans ses boîtes ; ce qui
--- n'entre pas est renversé au pied et compté), et sa progression est notée pour être reposée dès que `new`
--- fabrique de nouveau la même recette (Levels.resume_progress, au tick suivant en général). Renvoie true si une
--- progression a été notée.
local function resume_later(old, new)
  local recipe = old.get_recipe() or (old.type == "furnace" and old.previous_recipe) or nil
  if not recipe then return false end
  local st = S()
  for _, ing in ipairs(recipe.ingredients) do
    if ing.type == "fluid" then
      -- Correction V3-T2 (défaut 4) : température de l'ancienne boîte qui porte ce fluide, sinon le minimum de la
      -- recette (sans elle, le moteur prend la température par défaut du fluide : une recette à vapeur chaude ne
      -- l'accepterait pas) ; ce qui n'entre pas est COMPTÉ (fluid_lost, interface distante levels_status).
      local temp = ing.minimum_temperature
      local ofb = old.fluidbox
      for k = 1, (ofb and #ofb or 0) do
        local f = ofb[k]
        if f and f.name == ing.name and f.temperature then
          temp = f.temperature
          break
        end
      end
      local put = new.insert_fluid({ name = ing.name, amount = ing.amount, temperature = temp })
      if put < ing.amount - 1e-6 then
        st.stats.fluid_lost = (st.stats.fluid_lost or 0) + (ing.amount - put)
        log("[FO-LEVELS] agrandissement : " .. (ing.amount - put) .. " " .. ing.name .. " de la fabrication en cours non rendu(s) (boîte pleine)")
      end
    else
      local put = new.insert({ name = ing.name, count = ing.amount })
      if put < ing.amount then
        new.surface.spill_item_stack(new.position, { name = ing.name, count = ing.amount - put }, true, new.force, false)
        st.stats.spilled = (st.stats.spilled or 0) + ing.amount - put
        log("[FO-LEVELS] agrandissement : " .. (ing.amount - put) .. " " .. ing.name .. " de la fabrication en cours renversé(s) au sol")
      end
    end
  end
  st.pending = st.pending or {}
  st.pending[new.unit_number] = { entity = new, recipe = recipe.name, progress = old.crafting_progress or 0,
    bonus = old.bonus_progress or 0, tick = game.tick }
  return true
end

--- Repose les progressions notées par resume_later (dans l'ordre des numéros) : machine qui fabrique la même recette
--- → progression et bonus de productivité recopiés, entrée retirée ; machine disparue, autre recette, ou délai
--- dépassé → entrée retirée. Renvoie le nombre de progressions reposées.
--- Une entrée de `pending` (numéro u) : machine qui fabrique → entrée retirée, progression reposée si c'est la même
--- recette (renvoie true) ; machine disparue ou délai dépassé → retirée ; sinon gardée.
local function resume_one(pending, u)
  local rec = pending[u]
  local e = rec.entity
  if not (e and e.valid) then
    pending[u] = nil
  elseif e.is_crafting() then
    pending[u] = nil
    local r = e.get_recipe() or (e.type == "furnace" and e.previous_recipe) or nil
    if r and r.name == rec.recipe then
      e.crafting_progress = rec.progress
      if rec.bonus > 0 then e.bonus_progress = rec.bonus end
      local st = S()
      st.stats.resumed = (st.stats.resumed or 0) + 1
      return true
    end
  elseif game.tick - rec.tick > Levels.PENDING_TTL then
    pending[u] = nil
  end
  return false
end

function Levels.resume_progress()
  local pending = S().pending
  if not pending or next(pending) == nil then return 0 end
  local units = {}
  for u in pairs(pending) do units[#units + 1] = u end
  table.sort(units)
  local done = 0
  for _, u in ipairs(units) do
    if resume_one(pending, u) then done = done + 1 end
  end
  return done
end

--- Transfert COMPLET de `old` vers `new` (nouvelle entité, autre taille, posée par script) : recette, inventaires
--- de tous types (munitions, carburant, entrée, sortie, modules…), fluides, énergie et brûleur, progression de
--- fabrication ou d'extraction, tourelle (cible, victimes, dégâts infligés), dernier utilisateur, fils de circuit
--- et réglages du circuit d'une foreuse. Les points de vie (en proportion) et la direction sont posés par
--- l'appelant. Renvoie { spilled, wires_lost }.
function Levels.transfer(old, new)
  local out = { spilled = 0, wires_lost = 0 }
  -- Recette d'abord : elle fixe ce que les inventaires d'entrée acceptent.
  if old.type == "assembling-machine" then
    local r = old.get_recipe()
    if r then new.set_recipe(r) end
  end
  out.spilled = transfer_inventories(old, new)
  local ofb, nfb = old.fluidbox, new.fluidbox
  if ofb and nfb then
    for i = 1, math.min(#ofb, #nfb) do
      local fluid = ofb[i]
      if fluid then nfb[i] = fluid end
    end
  end
  local energy = old.energy
  if energy and energy > 0 then new.energy = energy end
  local ob, nb = old.burner, new.burner
  if ob and nb then
    if ob.currently_burning then nb.currently_burning = ob.currently_burning end
    nb.remaining_burning_fuel = ob.remaining_burning_fuel
    nb.heat = ob.heat
  end
  -- Progressions : écrites seulement si non nulles (un bâtiment neuf part de 0 ; écrire 0 ne changerait rien).
  local function carry(k)
    local v = old[k]
    if v and v > 0 then new[k] = v end
  end
  if CRAFTER_TYPES[old.type] then
    -- Lot V3-T2 (moteur réel, F83) : une fabrication EN COURS a déjà pris ses ingrédients, et un four neuf ignore
    -- l'écriture de crafting_progress (il ne choisit sa recette qu'à sa mise à jour) : le four agrandi perdait le
    -- minerai de la fusion en cours. D'où : ingrédients de la fabrication en cours RENDUS à la nouvelle machine,
    -- progression reportée au premier tick où elle fabrique de nouveau la même recette (resume_progress).
    local pending = S().pending
    local waiting = pending and old.unit_number and pending[old.unit_number]
    -- Correction V3-T2 (défauts 2 et 15) : la machine a DÉJÀ repris une fabrication (elle a consommé les ingrédients
    -- rendus) avant que resume_progress ne passe (amélioration traitée avant le on_tick du tick suivant) : la
    -- progression notée est reposée d'abord ; c'est alors une fabrication en cours comme une autre (ci-dessous).
    if waiting and old.is_crafting and old.is_crafting() then
      resume_one(pending, old.unit_number)
      waiting = nil
    end
    if waiting then
      -- Machine agrandie de nouveau avant d'avoir repris (deux améliorations dans le même tick) : la progression
      -- notée suit la nouvelle machine (ses ingrédients ont déjà été rendus, une seule fois).
      pending[old.unit_number] = nil
      waiting.entity = new
      pending[new.unit_number] = waiting
      out.resumed = true
    elseif old.is_crafting and old.is_crafting() then
      out.resumed = resume_later(old, new)
    else
      -- Correction V3-T2 (défaut 10) : crafting_progress n'est plus recopiée hors fabrication (F84 : l'écrire sur une
      -- machine à l'arrêt lance une fabrication SANS prendre d'ingrédients) ; le bonus de productivité, si.
      carry("bonus_progress")
    end
  elseif old.type == "mining-drill" then
    carry("mining_progress")
    carry("bonus_mining_progress")
  end
  if TURRET_TYPES[old.type] then
    local kills, dealt = old.kills, old.damage_dealt
    if kills and kills > 0 then new.kills = kills end
    if dealt and dealt > 0 then new.damage_dealt = dealt end
    local target = old.shooting_target
    if target and target.valid then new.shooting_target = target end
  end
  local user = old.last_user
  if user then new.last_user = user end
  -- Fils de circuit : mêmes voisins, mêmes bornes. Un fil trop long pour la nouvelle position est perdu
  -- (compté, journalisé) : le moteur refuse la connexion au-delà de circuit_wire_max_distance.
  local defs = old.circuit_connection_definitions
  if defs then
    for _, d in ipairs(defs) do
      if d.target_entity and d.target_entity.valid and d.target_entity ~= old then
        local ok = new.connect_neighbour({ wire = d.wire, target_entity = d.target_entity,
          source_circuit_id = d.source_circuit_id, target_circuit_id = d.target_circuit_id })
        if not ok then out.wires_lost = out.wires_lost + 1 end
      end
    end
    if out.wires_lost > 0 then
      log("[FO-LEVELS] agrandissement : " .. out.wires_lost .. " fil(s) de circuit trop long(s), perdu(s)")
    end
  end
  if old.type == "mining-drill" then
    local ocb = old.get_control_behavior()
    if ocb then
      local ncb = new.get_or_create_control_behavior()
      for _, k in ipairs(DRILL_CB_KEYS) do ncb[k] = ocb[k] end
      local cc = ocb.circuit_condition
      if cc then ncb.circuit_condition = { condition = cc.condition } end
      local lc = ocb.logistic_condition
      if lc then ncb.logistic_condition = { condition = lc.condition } end
    end
  end
  return out
end

--- Objets au sol (item-entity) dont la boîte touche la boîte de collision `rect` du nouveau bâtiment : sortis
--- à la position libre la plus proche (find_non_colliding_position : l'objet au sol a la couche « item-layer »,
--- présente dans le masque du bâtiment, donc la position rendue est hors du bâtiment) et téléportés (l'objet
--- garde sa pile et ses données). Correction V3-T (défaut 4) : laissé dessous, un objet au milieu d'un 5×5 ou
--- d'un 6×6 serait hors de portée (ramassage à 1 tuile, personnage hors de la boîte). Échec (aucune position,
--- téléport refusé) : laissé en place, compté (ground_left). Renvoie déplacés, laissés.
--- Suite « défense dense » (correction, 22/10) : la recherche par zone du moteur réel rend aussi un objet dont la
--- boîte TOUCHE seulement le bord du bâtiment (intervalles fermés, RD_LOG F96 provisoire, E53) ; un tel objet n'est
--- pas dessous. Il est écarté par le chevauchement STRICT (Foot.overlap, comme remove_ghosts) : sinon il serait
--- poussé pour rien, compté « déplacé », ou compté et journalisé « laissé sous » le bâtiment sans y être.
local function move_ground_items(surface, rect, radius)
  local moved, left = 0, 0
  local items = surface.find_entities_filtered({ area = { { rect.x0, rect.y0 }, { rect.x1, rect.y1 } }, type = "item-entity" })
  for _, it in ipairs(items) do
    local bb = it.valid and it.bounding_box
    if bb and Foot.overlap(rect, { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }) then
      local ok = false
      local to = surface.find_non_colliding_position("item-on-ground", it.position, radius, 0.25)
      if to and not (to.x > rect.x0 and to.x < rect.x1 and to.y > rect.y0 and to.y < rect.y1) then
        ok = it.teleport(to) and true or false
      end
      if ok then moved = moved + 1 else left = left + 1 end
    end
  end
  return moved, left
end

--- Fantômes d'entités (entity-ghost) recouverts par le nouveau bâtiment : retirés, comme le fait le moteur
--- quand on pose un bâtiment à la main (correction V3-T, défaut 5 : sinon les robots tentent sans fin de le
--- construire). Retiré : un fantôme dont la boîte touche `rect` et dont le prototype fantôme partage une couche
--- avec le masque du nouveau bâtiment (`layers`). Les fantômes de TUILES restent (une tuile se pose sous un
--- bâtiment). Renvoie le nombre retiré. Moteur réel 1.1.91 (banc content, greffon levels_taille, 22/10) : le
--- create_entity du nouveau bâtiment retire DÉJÀ lui-même le fantôme de mur recouvert (0 retiré ici) ; ce filet
--- reste pour ce que le banc n'a pas couvert (autres fantômes, autres moteurs simulés) et ne coûte qu'une
--- recherche sur l'emprise.
local function remove_ghosts(surface, rect, layers)
  local removed = 0
  local ghosts = surface.find_entities_filtered({ area = { { rect.x0, rect.y0 }, { rect.x1, rect.y1 } }, type = "entity-ghost" })
  for _, g in ipairs(ghosts) do
    if g.valid then
      local bb = g.bounding_box
      local gp = g.ghost_prototype
      if Foot.overlap(rect, { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y })
          and shares(layers, gp and gp.collision_mask) then
        g.destroy({ raise_destroy = true })
        removed = removed + 1
      end
    end
  end
  return removed
end

--- Remplacement PAR SCRIPT de `entity` par `name` (côté new_side) à la première position libre de la règle
--- (opts.room : place déjà calculée par l'aperçu ; sinon calculée ici). Ordre (F40 tenu) :
---   1. le nouveau bâtiment est créé À CÔTÉ de l'ancien, qui existe encore (create_entity ne vérifie pas la
---      place : c'est Levels.room qui l'a fait), raise_built = true : nos gestionnaires tournent aussitôt ; s'ils
---      le détruisent, create_entity renvoie nil et l'ancien est INTACT (l'appelant rembourse) ;
---   2. tout le contenu passe de l'ancien au nouveau (Levels.transfer), sans rien renverser ;
---   3. les décors du nouveau carré sont retirés, les fantômes d'entités recouverts aussi (comme sous un
---      bâtiment posé à la main), les objets au sol sont sortis du bâtiment ;
---   4. l'ancien est détruit sans événement (comme le remplacement rapide moteur) : son objet disparaît.
--- opts.force (chantiers hérités, déjà payés) : sans position libre, la position À MONTRER (room.target : la
--- plus facile à libérer, jamais dans l'eau s'il existe mieux) est prise quand même (chevauchement toléré,
--- compté) plutôt que de perdre le chantier. Renvoie la nouvelle entité, ou nil et la place (refus, rien n'a
--- changé).
function Levels.resize_replace(entity, name, old_side, new_side, opts)
  opts = opts or {}
  local st = S()
  local room = opts.room or Levels.room(entity, old_side, name, new_side)
  local cand = room.chosen
  if not cand then
    if not opts.force then return nil, room end
    cand = room.target or room.preferred
    st.stats.forced = (st.stats.forced or 0) + 1
    log("[FO-LEVELS] agrandissement forcé (chantier hérité, place prise) : " .. name .. " en "
      .. cand.x .. ", " .. cand.y .. " ; gêne : " .. Levels.blockers_text(cand))
  end
  local surface, force, dir = entity.surface, entity.force, entity.direction
  -- Correction V3-T2 (moteur réel, 22/10) : un assembleur n'est orientable qu'avec une recette à fluide ; créé sans
  -- recette, create_entity ignore la direction (assembleurs tournés vers l'est, le sud ou l'ouest revenus au nord,
  -- tuyau perdu). La recette est donc donnée à la création (Levels.transfer la repose ensuite, sans effet).
  local recipe = entity.type == "assembling-machine" and entity.get_recipe() or nil
  st.replacing = true
  local new = surface.create_entity({
    name = name, position = { x = cand.x, y = cand.y }, direction = dir, force = force, recipe = recipe and recipe.name or nil,
    raise_built = true, create_build_effect_smoke = false, move_stuck_players = true,
  })
  st.replacing = false
  if not (new and new.valid and new.name == name) then
    st.stats.resize_failed = (st.stats.resize_failed or 0) + 1
    if new and new.valid then new.destroy({ raise_destroy = false }) end
    return nil, room
  end
  local moved = Levels.transfer(entity, new)
  st.stats.spilled = (st.stats.spilled or 0) + moved.spilled
  st.stats.wires_lost = (st.stats.wires_lost or 0) + moved.wires_lost
  local b = cand.box
  surface.destroy_decoratives({ area = { { b.x0, b.y0 }, { b.x1, b.y1 } } })
  local rect = Foot.collision_rect(b)
  local gone = remove_ghosts(surface, rect, mask_layers(new.prototype.collision_mask))
  if gone > 0 then st.stats.ghosts_removed = (st.stats.ghosts_removed or 0) + gone end
  local gm, gl = move_ground_items(surface, rect, new_side + 2)
  if gm > 0 then st.stats.ground_moved = (st.stats.ground_moved or 0) + gm end
  if gl > 0 then
    st.stats.ground_left = (st.stats.ground_left or 0) + gl
    log("[FO-LEVELS] agrandissement : " .. gl .. " objet(s) au sol laissé(s) sous " .. name .. " (aucune place libre autour)")
  end
  entity.destroy({ raise_destroy = false })
  -- Correction V3-T2 (moteur réel, 22/10) : le nouveau bâtiment, créé quand l'ancien existait encore, n'est PAS raccordé
  -- aux tuyaux que l'ancien occupait (le raccord du tuyau était pris ; personne ne le refait quand l'ancien disparaît) :
  -- 12 assembleurs sur 12 privés d'eau. update_connections() n'y fait rien ; un téléport sur place les refait
  -- (expérience du banc, checks/levels_points.lua). Puis, pour une foreuse, update_connections() (doc 1.1.91 : zone
  -- d'extraction et cible après un téléport).
  if new.fluidbox and #new.fluidbox > 0 then
    new.teleport(new.position)
    if new.type == "mining-drill" then new.update_connections() end
  end
  st.stats.resized = (st.stats.resized or 0) + 1
  return new, room
end

--- Remet le coût payé (refus après paiement : la nouvelle entité n'a pas pu être créée et l'ancienne est
--- intacte) : chaque part dans l'inventaire QUI L'A PAYÉE, d'après le relevé de pay (correction V3-T, défauts 6
--- et 17 : la part du joueur revient au joueur, celle du centre au centre) ; ce qui n'entre plus (jamais
--- attendu : ces cases viennent d'être vidées ; inventaire disparu) est posé au pied du bâtiment.
local function refund(ledger, entity)
  for _, part in ipairs(ledger) do
    local put = 0
    if part.inv and part.inv.valid ~= false then put = part.inv.insert({ name = part.item, count = part.count }) end
    if put < part.count then
      entity.surface.spill_item_stack(entity.position, { name = part.item, count = part.count - put }, true, entity.force, false)
    end
  end
  local st = S()
  st.stats.refunds = (st.stats.refunds or 0) + 1
end

local function celebrate(entity, family, n)
  local e = L.epoch_of(family, n)
  local c = L.epochs[e].color
  -- Premier niveau d'une époque (et chaque niveau du centre, qui EST l'époque) : on annonce l'époque.
  local text = { "fo-levels.level-up", n }
  if e >= 2 and L.step_of(family, n) == 1 then text = { "fo-epochs.epoch-up", e, { "fo-epochs.name-" .. L.epochs[e].key } } end
  entity.surface.create_entity({ name = "flying-text", position = { entity.position.x, entity.position.y - 1.5 },
    text = text, color = { r = c.r, g = c.g, b = c.b } })
  rendering.draw_light({ sprite = "utility/light_medium", surface = entity.surface, target = entity,
    scale = 2 + box_size(entity), intensity = 1, color = c, time_to_live = 90 })
  entity.surface.play_sound({ path = "utility/research_completed", position = entity.position, volume_modifier = 0.6 })
end

--- Fonctions appelées après chaque remplacement : f(ancien_numéro, nouvelle_entité). Enregistrées au
--- chargement des modules (jamais pendant un événement).
Levels.on_replaced = {}

--- Remplace `entity` par le niveau n de sa famille. Renvoie la nouvelle entité ou nil. Emprise égale : le
--- remplacement rapide moteur (F39), inchangé depuis V2c. Emprise différente (lot V3-T) : remplacement par
--- script (Levels.resize_replace ; opts.room : place calculée par l'aperçu ; opts.force : chantier hérité).
local function replace(entity, family, n, opts)
  local st = S()
  local name = L.name(family, n)
  local old_unit = entity.unit_number
  local ratio = entity.get_health_ratio() or 1
  local was_cc = Levels.cc(entity.force) == entity
  local surface, pos, dir, force = entity.surface, entity.position, entity.direction, entity.force
  local _, cur = L.parse(entity.name)
  local new
  -- Correction V3-T2 (défauts 2 et 15) : progression notée d'une machine qui a DÉJÀ repris une fabrication (amélioration
  -- traitée avant le on_tick qui l'aurait reposée) : reposée maintenant, avant tout remplacement.
  local pend = st.pending
  if pend and old_unit and pend[old_unit] and CRAFTER_TYPES[entity.type] and entity.is_crafting and entity.is_crafting() then
    resume_one(pend, old_unit)
  end
  -- Lot V3-T2 (moteur réel, F86) : un bâtiment HORS grille ne passe jamais par le remplacement rapide moteur, même à
  -- côté égal : create_entity{fast_replace = true} recale la position sur la grille, ne trouve donc pas l'ancien à
  -- remplacer, et pose quand même le nouveau (sans vérifier la place) : deux bâtiments superposés, l'ancien gardé.
  if cur and (L.footprint(family, cur) ~= L.footprint(family, n) or Levels.off_grid(entity, L.footprint(family, cur))) then
    new = Levels.resize_replace(entity, name, L.footprint(family, cur), L.footprint(family, n), opts)
    if not new then return nil end
  else
    st.replacing = true
    new = surface.create_entity({
      name = name, position = pos, direction = dir, force = force,
      fast_replace = true, spill = false, raise_built = true, create_build_effect_smoke = false,
    })
    if not (new and new.valid and new.name == name) then
      if entity.valid then new = manual_replace(entity, name) end
      st.stats.fallback = (st.stats.fallback or 0) + 1
    end
    st.replacing = false
    if not new then return nil end
  end
  new.health = new.prototype.max_health * ratio
  if was_cc then st.cc[force.name] = new end
  -- Lot V3-T2 : progression notée (resume_later) d'une machine remplacée par le moteur avant d'avoir repris : elle
  -- suit la nouvelle (le remplacement par script la déplace déjà dans Levels.transfer).
  local waiting = st.pending and old_unit and st.pending[old_unit]
  if waiting and new.unit_number ~= old_unit then
    st.pending[old_unit] = nil
    waiting.entity = new
    st.pending[new.unit_number] = waiting
  end
  celebrate(new, family, n)
  for _, f in ipairs(Levels.on_replaced) do f(old_unit, new) end
  return new
end

---------------------------------------------------------------------------------------------------
-- Améliorer
---------------------------------------------------------------------------------------------------
--- Coût et autorisation de l'amélioration suivante de `entity` (sans rien changer).
--- Renvoie une table { family, level, next, cost, ok, reason, missing, cc_level, required_cc,
--- condition_level, blocking, unknown, resize, room }. fresh : recensement Q16 complet (décision) ; sinon, le
--- cache (affichage du panneau). Lot V3-T : si le niveau suivant change d'emprise, resize = { from, to } et
--- room = la place (Levels.room) ; sans position libre, refus « no-room », APRÈS les autres motifs (le panneau
--- montre la place dans tous les cas). Lot V3-T3 : opts.box = carré { x0, y0, x1, y1 } : la place n'est cherchée qu'à
--- cette position (Levels.room, only_box ; agrandissement en attente d'une demande « libérer la place »).
function Levels.preview(entity, player, fresh, opts)
  local family, n = L.parse(entity.name)
  if not family then return nil end
  -- Lot V3-T3 (correction, défauts 5 et 24) : tant qu'une demande « libérer la place » attend pour ce bâtiment, TOUTE
  -- décision et tout aperçu (bouton « Améliorer », touche U, rangée, interface distante) ne visent que le carré
  -- libéré : ailleurs, le bâtiment pourrait se poser sur les fantômes du mod. Crochet posé par script/levels/free.lua
  -- (fonction du module, jamais dans global).
  if not (opts and opts.box) and Levels.pending_box then
    local b = Levels.pending_box(entity)
    if b then opts = { box = b } end
  end
  local force = entity.force
  local info = { family = family, level = n, next = n + 1, cc_level = Levels.cc_level(force) }
  if n >= family.max then
    info.ok, info.reason = false, "max"
    return info
  end
  info.cost = L.cost(family, n + 1)
  info.ok, info.reason = L.check(family, n + 1, info.cc_level)
  info.required_cc = L.required_cc(family, n + 1)
  -- Un objet de coût absent du jeu (table d'indirection pointant vers un objet pas encore livré) : on
  -- refuse proprement au lieu de laisser le moteur lever une erreur sur un nom d'objet inconnu.
  local unknown = {}
  for _, c in ipairs(info.cost) do
    if not Levels.item_exists(c[1]) then unknown[#unknown + 1] = c[1] end
  end
  if #unknown > 0 then
    info.unknown = unknown
    info.missing = {}
    info.ok, info.reason = false, "unknown-item"
    return info
  end
  -- Q16 : le centre ne passe au niveau suivant que si chaque famille possédée a un bâtiment au niveau
  -- maximal de l'époque.
  if family.key == "command" then
    info.condition_level = L.cc_condition_level(n)
    info.blocking = L.cc_blockers(Levels.census_cached(force, info.condition_level, fresh))
    if info.ok and #info.blocking > 0 then info.ok, info.reason = false, "cc-families" end
  end
  info.missing = missing(sources(force, player), info.cost)
  if info.ok and #info.missing > 0 then info.ok, info.reason = false, "no-resources" end
  local from, to = L.footprint(family, n), L.footprint(family, n + 1)
  -- Lot V3-T2 : bâtiment hors grille (laissé par une migration) : même à côté égal, il est reposé sur la grille par
  -- script, après vérification de la place (regrid = true).
  local off = Levels.off_grid(entity, from)
  if from ~= to or off then
    info.resize = { from = from, to = to, regrid = off or nil }
    info.room = Levels.room(entity, from, L.name(family, n + 1), to, opts and opts.box)
    if info.ok and not info.room.chosen then info.ok, info.reason = false, "no-room" end
  end
  return info
end

--- Améliore `entity` AUSSITÔT si c'est permis et payable (player facultatif : source de paiement).
--- Renvoie ok, raison, info, nouvelle entité. Raison du succès : "done". Lot V3-T : la place est vérifiée par
--- l'aperçu, donc AVANT le paiement ; refus « no-room » : rien n'est payé, le contour nécessaire est dessiné
--- (visible du joueur, ou de la force sans joueur). Échec du remplacement par script alors que l'ancien
--- bâtiment est intact : le coût est rendu, chaque part à l'inventaire qui l'a payée. Lot V3-T3 : opts.box (voir
--- Levels.preview) : agrandissement en attente d'une demande « libérer la place », à la seule position libérée.
function Levels.start(entity, player, opts)
  if not (entity and entity.valid) then return false, "invalid" end
  -- Décision : recensement Q16 complet, jamais le cache.
  local info = Levels.preview(entity, player, true, opts)
  if not info then return false, "not-levelable" end
  local st = S()
  if not info.ok then
    if info.reason == "no-room" then
      st.stats.room_refused = (st.stats.room_refused or 0) + 1
      draw_contour(entity, info.room, player)
    end
    return false, info.reason, info
  end
  local invs = sources(entity.force, player)
  local ledger = pay(invs, info.cost)
  local new = replace(entity, info.family, info.next, { room = info.room })
  if not new then
    if entity.valid then refund(ledger, entity) end
    return false, "replace-failed", info
  end
  st.stats.upgrades = (st.stats.upgrades or 0) + 1
  return true, "done", info, new
end
Levels.upgrade = Levels.start

--- Murs : améliore tous les murs reliés de même niveau (jusqu'à 400), tant que les ressources suffisent.
function Levels.start_row(entity, player)
  if not (entity and entity.valid) then return 0 end
  local family = L.parse(entity.name)
  if not (family and family.row) then return 0 end
  local surface, name = entity.surface, entity.name
  local seen, queue, list = {}, { entity }, {}
  local function key(p) return math.floor(p.x) .. "," .. math.floor(p.y) end
  seen[key(entity.position)] = true
  while #queue > 0 and #list < 400 do
    local e = table.remove(queue, 1)
    list[#list + 1] = e
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local p = { x = e.position.x + d[1], y = e.position.y + d[2] }
      local k = key(p)
      if not seen[k] then
        seen[k] = true
        local nb = surface.find_entity(name, p)
        if nb and nb.force == entity.force then queue[#queue + 1] = nb end
      end
    end
  end
  local done = 0
  for _, e in ipairs(list) do
    local ok = Levels.start(e, player)
    if not ok then break end
    done = done + 1
  end
  return done
end

---------------------------------------------------------------------------------------------------
-- Sauvegarde 0.4.0 : chantiers minutés en cours
-- Décision V2c : chaque chantier est ACHEVÉ (pas annulé et remboursé). Son coût est déjà payé, et Q19 dit
-- « si on a les ressources, on améliore, terminé » : le joueur retrouve le niveau qu'il a acheté. Annuler
-- obligerait à rembourser le coût entier dans un coffre peut-être plein (objets au sol) puis à relancer à la
-- main. Le chantier d'un centre est achevé lui aussi, sans la condition Q16, qui n'existait pas quand il a
-- été payé. Le bâtiment disparu : chantier perdu (comme en 0.4.0). Une cible hors des niveaux du jeu : le
-- bâtiment est remis en service, chantier perdu (branche défensive, les noms gardent leur sens).
---------------------------------------------------------------------------------------------------
local function undraw_job(job)
  for _, k in ipairs({ "r_bg", "r_fg", "r_text" }) do
    if job[k] and rendering.is_valid(job[k]) then rendering.destroy(job[k]) end
  end
end

--- Achève les chantiers hérités, dans l'ordre des numéros. Renvoie achevés, perdus.
function Levels.finish_legacy_jobs()
  local st = S()
  st.jobs = st.jobs or {}
  local units = {}
  for u in pairs(st.jobs) do units[#units + 1] = u end
  table.sort(units)
  local done, lost = 0, 0
  for _, u in ipairs(units) do
    local job = st.jobs[u]
    st.jobs[u] = nil
    undraw_job(job)
    local family = L.by_key[job.family or ""]
    local entity = job.entity
    if not (entity and entity.valid) then
      lost = lost + 1
    else
      entity.active = true
      local _, n = L.parse(entity.name)
      if family and n and job.to and job.to <= family.max and job.to > n then
        if replace(entity, family, job.to, { force = true }) then done = done + 1 else lost = lost + 1 end
      else
        lost = lost + 1
      end
    end
  end
  st.stats.upgrades = (st.stats.upgrades or 0) + done
  st.stats.lost = (st.stats.lost or 0) + lost
  st.busy = {}
  st.time_factor = nil
  return done, lost
end

---------------------------------------------------------------------------------------------------
-- Migration des EMPRISES (lot V3-T). Une sauvegarde d'avant V3-T (0.4.1) contient des mitrailleuses de niveau 7
-- et plus posées à l'ancienne taille (2×2). Au chargement, le moteur leur applique le NOUVEAU prototype (3×3 à
-- 6×6) à la MÊME position (moteur réel 1.1.91, suite H-T3 du 22/10 : position gardée telle quelle, sans
-- recalage ni destruction) : un côté impair centré sur un coin de tuile est hors grille, et le nouveau carré peut
-- chevaucher un voisin. Comportement choisi, sûr (aucune entité détruite sans remplaçant, aucun objet perdu) :
--   - pour chaque (famille, niveau) dont le côté a changé depuis le relevé de la sauvegarde (global :
--     footprints ; absent = sauvegarde d'avant V3-T, côtés de base), chaque bâtiment de ce nom est REPOSÉ par la
--     règle d'agrandissement (ancien carré = l'ancien côté autour de sa position) : position libre trouvée,
--     même place → rien à faire ; autre place → remplacement par script (contenu transféré, PV en proportion) ;
--   - aucune position libre : le bâtiment est LAISSÉ où il est (chevauchement toléré, compté, journalisé), en
--     service, avec son contenu ;
--   - un chantier 0.4.0 en cours suit son bâtiment reposé (achevé ensuite par finish_legacy_jobs).
-- Puis le relevé de la sauvegarde est mis à jour. Ordre déterministe : familles et niveaux dans l'ordre de la
-- config, surfaces par index, entités dans l'ordre du moteur. Renvoie reposés, déjà en place, laissés, et la liste
-- des laissés { {force, name, x, y} } (message aux joueurs : Levels.tell_migration).
---------------------------------------------------------------------------------------------------
function Levels.migrate_footprints()
  local st = S()
  local current = L.footprint_snapshot()
  local keys = {}
  for _, f in ipairs(L.families) do keys[#keys + 1] = f.key end
  local changes = Foot.diff(st.footprints, current, keys, function(k) return L.by_key[k].size end)
  local moved, inplace, kept = 0, 0, 0
  local kept_list = {}
  for _, ch in ipairs(changes) do
    local family = L.by_key[ch.key]
    local name = L.name(family, ch.level)
    for _, surface in ipairs(sorted_surfaces()) do
      for _, e in ipairs(surface.find_entities_filtered({ name = name })) do
        if e.valid then
          local room = Levels.room(e, ch.from, name, ch.to)
          local cand = room.chosen
          local pos = e.position
          if cand and math.abs(cand.x - pos.x) < Foot.EPS and math.abs(cand.y - pos.y) < Foot.EPS then
            inplace = inplace + 1
          else
            local new
            if cand then
              local old_unit, ratio = e.unit_number, e.get_health_ratio() or 1
              local was_cc, force = Levels.cc(e.force) == e, e.force
              new = Levels.resize_replace(e, name, ch.from, ch.to, { room = room })
              if new then
                new.health = new.prototype.max_health * ratio
                if was_cc then st.cc[force.name] = new end
                local job = st.jobs and st.jobs[old_unit]
                if job then
                  st.jobs[old_unit] = nil
                  job.entity, job.unit = new, new.unit_number
                  st.jobs[new.unit_number] = job
                end
                for _, f in ipairs(Levels.on_replaced) do f(old_unit, new) end
                moved = moved + 1
              end
            end
            if not new then
              kept = kept + 1
              kept_list[#kept_list + 1] = { force = e.force.name, name = name, x = pos.x, y = pos.y }
              log("[FO-LEVELS] emprise : " .. name .. " en " .. pos.x .. ", " .. pos.y .. " laissé en place ("
                .. ch.from .. "×" .. ch.from .. " → " .. ch.to .. "×" .. ch.to .. ", aucune place libre ; gêne : "
                .. Levels.blockers_text(room.target) .. ")")
            end
          end
        end
      end
    end
  end
  st.footprints = current
  st.stats.migrated = (st.stats.migrated or 0) + moved
  st.stats.overlap_kept = (st.stats.overlap_kept or 0) + kept
  return moved, inplace, kept, kept_list
end

--- Doublons SUPERPOSÉS hérités (lot V3-T2, correction du défaut 13) : avant 0.4.3, améliorer un bâtiment laissé
--- hors grille par une migration passait par le remplacement rapide moteur, qui recalait la position, ne remplaçait
--- rien et posait le nouveau PAR-DESSUS l'ancien (F86) : deux bâtiments de la même famille dont les centres sont à
--- une demi-tuile au plus l'un de l'autre (jamais le cas de deux bâtiments posés normalement : ils se
--- chevaucheraient). Ils sont seulement relevés (journal, compteur, message) : aucun n'est détruit, chacun a son
--- contenu ; le joueur ramasse celui qu'il veut. Familles de côté ≥ 2 (le mur 1×1 ne passe jamais hors grille),
--- surfaces par index, entités dans l'ordre du moteur, chaque paire une fois (numéros croissants). Renvoie
--- { {force, a, b, x, y} } (noms des deux bâtiments, position du premier).
function Levels.find_stacked()
  local out = {}
  for _, f in ipairs(L.families) do
    if f.size >= 2 then
      local names = {}
      for n = 1, f.max do names[#names + 1] = L.name(f, n) end
      for _, surface in ipairs(sorted_surfaces()) do
        for _, e in ipairs(surface.find_entities_filtered({ name = names })) do
          local p, u = e.position, e.unit_number
          if u then
            local near = surface.find_entities_filtered({ name = names, area = { { p.x - 0.6, p.y - 0.6 }, { p.x + 0.6, p.y + 0.6 } } })
            for _, o in ipairs(near) do
              local q = o.position
              if o ~= e and o.unit_number and o.unit_number > u and math.abs(q.x - p.x) <= 0.5 + Foot.EPS
                  and math.abs(q.y - p.y) <= 0.5 + Foot.EPS then
                out[#out + 1] = { force = e.force.name, a = e.name, b = o.name, x = p.x, y = p.y }
                log("[FO-LEVELS] doublon superposé (hérité d'avant 0.4.3) : " .. e.name .. " en " .. p.x .. ", " .. p.y
                  .. " et " .. o.name .. " en " .. q.x .. ", " .. q.y .. " (aucun n'est retiré)")
              end
            end
          end
        end
      end
    end
  end
  local st = S()
  st.stats.stacked = (st.stats.stacked or 0) + #out
  return out
end

--- Liens de carte « [gps=x,y] » (texte enrichi du moteur : cliquables dans la console) des 5 premiers lieux, puis « … ».
local function gps_list(list)
  local parts = {}
  for i, k in ipairs(list) do
    if i > 5 then
      parts[#parts + 1] = "…"
      break
    end
    parts[#parts + 1] = "[gps=" .. k.x .. "," .. k.y .. "]"
  end
  return table.concat(parts, " ")
end

--- Message aux joueurs après une migration des emprises (lot V3-T2, correction du défaut 9) : par force (ordre des
--- noms), le nombre de bâtiments LAISSÉS hors grille faute de place, ce qu'ils deviennent et le remède, avec des
--- liens vers les 5 premiers ; idem pour les doublons superposés hérités (find_stacked). Rien si les deux listes
--- sont vides. Renvoie le nombre de messages.
function Levels.tell_migration(kept_list, stacked)
  local by, names = {}, {}
  local function slot(fname)
    if not by[fname] then
      by[fname] = { kept = {}, stacked = {} }
      names[#names + 1] = fname
    end
    return by[fname]
  end
  for _, k in ipairs(kept_list or {}) do local t = slot(k.force); t.kept[#t.kept + 1] = k end
  for _, k in ipairs(stacked or {}) do local t = slot(k.force); t.stacked[#t.stacked + 1] = k end
  table.sort(names)
  local sent = 0
  for _, fname in ipairs(names) do
    local force, t = game.forces[fname], by[fname]
    log("[FO-LEVELS] message de migration à la force " .. fname .. " : " .. #t.kept .. " laissé(s), " .. #t.stacked .. " doublon(s)")
    if force then
      if #t.kept > 0 then
        force.print({ "fo-levels-taille.migration-kept", #t.kept, gps_list(t.kept) })
        sent = sent + 1
      end
      if #t.stacked > 0 then
        force.print({ "fo-levels-taille.migration-stacked", #t.stacked, gps_list(t.stacked) })
        sent = sent + 1
      end
    end
  end
  return sent
end

---------------------------------------------------------------------------------------------------
-- Changement de version (0.3.0 → 15 époques ; 0.4.0 → amélioration instantanée ; toute mise à jour)
-- Les noms gardent leur sens : aucune donnée à convertir. Réparation : emprises (lot V3-T), chantiers hérités
-- achevés, centre disparu oublié, PV ramenés au maximum.
---------------------------------------------------------------------------------------------------
function Levels.repair()
  local st = S()
  -- Emprises D'ABORD : un chantier hérité suit son bâtiment reposé, puis il est achevé à la bonne taille.
  local moved, inplace, kept, kept_list = Levels.migrate_footprints()
  if moved + kept > 0 then
    log("[FO-LEVELS] mise à jour des emprises : " .. moved .. " bâtiment(s) reposé(s), " .. inplace
      .. " déjà en place, " .. kept .. " laissé(s) faute de place (chevauchement toléré)")
  end
  -- Lot V3-T2 (corrections, défauts 9 et 13) : doublons superposés hérités relevés, joueurs prévenus.
  Levels.tell_migration(kept_list, Levels.find_stacked())
  local done, lost = Levels.finish_legacy_jobs()
  -- Recensement Q16 en cache : vidé (une mise à jour peut changer les niveaux et les noms ; sauvegarde 0.4.0 :
  -- la clé n'existe pas encore).
  st.census = {}
  local forces = {}
  for name in pairs(st.cc) do forces[#forces + 1] = name end
  table.sort(forces)
  for _, name in ipairs(forces) do
    local cc = st.cc[name]
    if not (cc and cc.valid and L.parse(cc.name)) then st.cc[name] = nil end
  end
  return done, lost
end

--- PV au-dessus du maximum du prototype (0.3.0 → V2 : un mur niveau 10 passe de 3 712 à 1 925 PV) :
--- ramenés au maximum. Le moteur borne toute écriture de `health` ; on n'écrit que si c'est nécessaire.
--- Renvoie le nombre de bâtiments corrigés. Surfaces dans l'ordre de leur index, entités dans l'ordre du
--- moteur (déterministe).
function Levels.clamp_health()
  local names = {}
  for _, f in ipairs(L.families) do
    for n = 2, f.max do names[#names + 1] = L.name(f, n) end
  end
  local fixed = 0
  for _, surface in ipairs(sorted_surfaces()) do
    for _, e in ipairs(surface.find_entities_filtered({ name = names })) do
      local max = e.prototype.max_health
      if max and e.health and e.health > max then
        e.health = max
        fixed = fixed + 1
      end
    end
  end
  return fixed
end

Events.on_configuration_changed(function()
  local done, lost = Levels.repair()
  if done + lost > 0 then
    log("[FO-LEVELS] mise à jour : " .. done .. " chantier(s) en cours achevé(s), " .. lost .. " perdu(s) (bâtiment disparu)")
  end
  local clamped = Levels.clamp_health()
  if clamped > 0 then log("[FO-LEVELS] mise à jour : PV ramenés au maximum sur " .. clamped .. " bâtiment(s)") end
end)

--- Le relevé des emprises de la sauvegarde (global : footprints) diffère-t-il de la table du mod chargé ?
--- Absent (sauvegarde d'avant V3-T) : oui. Comparaison sans rien allouer (familles puis niveaux, dans l'ordre de
--- la config) : au plus 7 × 30 lectures, arrêtées à la première différence.
function Levels.footprints_stale()
  local saved = S().footprints
  if not saved then return true end
  for _, f in ipairs(L.families) do
    local row = saved[f.key]
    if not row then return true end
    for n = 1, f.max do
      if row[n] ~= L.footprint(f, n) then return true end
    end
  end
  return false
end

-- Filets pour une sauvegarde rechargée SANS on_configuration_changed (doc 1.1.91 de
-- LuaBootstrap.on_configuration_changed : « game version or any mod version changed, mod added or removed, startup
-- setting changed, prototypes added or removed, migration applied »). Moteur réel 1.1.91 (suite H-T3, 22/10) :
-- l'événement est AUSSI appelé, mod_changes vide, quand les données de prototypes existants ont changé sans
-- montée de version ni prototype ajouté (somme « Checksum of factorio-overhaul » du journal différente, même
-- « Prototype list checksum ») ; un commentaire ajouté à un script de l'étape control ne change pas cette somme et
-- ne l'appelle pas. Une sauvegarde 0.4.1 rechargée par ce mod passe donc par Levels.repair ; ce filet reste pour
-- un cas que le moteur ne signalerait pas (coût : une comparaison) :
--   - correction V3-T (défauts 1 et 11) : EMPRISES d'abord, si le relevé de la sauvegarde diffère de la table
--     (sauvegarde 0.4.1 chargée par le mod V3-T sans montée de version) : migration au premier passage, puis le
--     relevé est à jour et le filet ne coûte plus que la comparaison ;
--   - chantiers 0.4.0 : achevés au premier passage (next sur une table vide sinon).
-- Même ordre que Levels.repair : un chantier hérité suit son bâtiment reposé, puis il est achevé.
Events.on_nth_tick(30, function()
  if Levels.footprints_stale() then
    local moved, inplace, kept, kept_list = Levels.migrate_footprints()
    log("[FO-LEVELS] emprises (filet, sans changement de version) : " .. moved .. " bâtiment(s) reposé(s), "
      .. inplace .. " déjà en place, " .. kept .. " laissé(s) faute de place (chevauchement toléré)")
    Levels.tell_migration(kept_list, Levels.find_stacked())
  end
  local jobs = S().jobs
  if jobs and next(jobs) ~= nil then
    local done, lost = Levels.finish_legacy_jobs()
    log("[FO-LEVELS] chantiers hérités : " .. done .. " achevé(s), " .. lost .. " perdu(s)")
  end
end)

-- Lot V3-T2 : progressions de fabrication reportées (resume_later). Chaque tick : une lecture de table vide dans
-- le cas courant ; une entrée vit un tick en général (la machine agrandie reprend sa fabrication à sa première
-- mise à jour).
Events.on(defines.events.on_tick, function()
  Levels.resume_progress()
end)

---------------------------------------------------------------------------------------------------
-- Construction et retrait
---------------------------------------------------------------------------------------------------
local function on_built(e)
  local ent = e.created_entity or e.entity
  if not (ent and ent.valid) then return end
  local family, n = L.parse(ent.name)
  if not family then return end
  if family.key ~= "command" then
    census_built(ent, family, n)
    return
  end
  local st = S()
  local cur = Levels.cc(ent.force)
  if cur and cur ~= ent and not st.replacing then
    -- Un seul centre par force : le second est rendu au joueur.
    local player = e.player_index and game.get_player(e.player_index)
    local surface, pos, item = ent.surface, ent.position, ent.name
    ent.destroy()
    local put = 0
    if player and player.valid then
      put = player.insert({ name = item, count = 1 })
      player.print({ "fo-levels.only-one-cc" })
    end
    if put == 0 then surface.spill_item_stack(pos, { name = item, count = 1 }, true, nil, false) end
    return
  end
  st.cc[ent.force.name] = ent
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)

local function on_removed(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local st = S()
  local family = L.parse(ent.name)
  if family and family.key ~= "command" then census_removed(ent) end
  if st.cc[ent.force.name] == ent and not st.replacing then st.cc[ent.force.name] = nil end
end

Events.on(defines.events.on_player_mined_entity, on_removed)
Events.on(defines.events.on_robot_mined_entity, on_removed)
Events.on(defines.events.on_entity_died, on_removed)
Events.on(defines.events.script_raised_destroy, on_removed)

return Levels
