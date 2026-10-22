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
  Déterminisme : tout se passe dans des événements ; listes triées (chantiers hérités par numéro, surfaces
  par index), jamais l'ordre de pairs.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")
local Foot = require("shared.levels.footprint")

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

--- Place pour passer `entity` (emprise actuelle : old_side) au prototype `new_name` de côté new_side.
--- Une seule recherche d'entités et une lecture des tuiles sur la réunion des positions candidates (au plus
--- (2b - a)² tuiles : 49 pour 5 → 6) ; la décision est la fonction pure Foot.evaluate. Renvoie
--- { index, chosen, preferred, target, target_index, candidates, from, to, box_old } (chosen = nil : aucune
--- position libre ; target = la candidate à montrer, shared/levels/footprint.lua F.evaluate).
function Levels.room(entity, old_side, new_name, new_side)
  local surface = entity.surface
  local old_box = Foot.tile_box(entity.position, old_side)
  local cands = Foot.candidates(old_box, new_side)
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
  local blockers = {}
  if #layers > 0 then
    local found = surface.find_entities_filtered({ area = { { area.x0, area.y0 }, { area.x1, area.y1 } } })
    for _, e in ipairs(found) do
      if e.valid and e ~= entity and not Levels.NON_BLOCKING[e.type] and shares(layers, e.prototype.collision_mask) then
        local bb = e.bounding_box
        blockers[#blockers + 1] = {
          box = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y },
          name = e.name, type = e.type, x = e.position.x, y = e.position.y,
        }
      end
    end
  end
  local res = Foot.evaluate(cands, tiles, blockers, Foot.MARGIN)
  res.from, res.to, res.box_old = old_side, new_side, old_box
  return res
end

--- Ce qui bloque une candidate, en texte court et trié : « [entity=stone-wall]×2 [tile=water]×3 » (texte
--- enrichi du moteur, sans clé de traduction : les icônes suffisent). Vide si rien.
function Levels.blockers_text(cand)
  if not cand then return "" end
  local count, names = {}, {}
  local function add(tag)
    if not count[tag] then names[#names + 1] = tag; count[tag] = 0 end
    count[tag] = count[tag] + 1
  end
  for _, e in ipairs(cand.entities or {}) do add("[entity=" .. e.name .. "]") end
  for _, t in ipairs(cand.tiles or {}) do add("[tile=" .. t.name .. "]") end
  table.sort(names)
  local parts = {}
  for _, tag in ipairs(names) do parts[#parts + 1] = count[tag] > 1 and (tag .. "×" .. count[tag]) or tag end
  return table.concat(parts, " ")
end

--- Noms de ce qui bloque une candidate (interface distante, tests) : entités puis « tile:<nom> », triés.
function Levels.blocker_names(cand)
  local out = {}
  if not cand then return out end
  for _, e in ipairs(cand.entities or {}) do out[#out + 1] = e.name end
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
local function transfer_inventories(old, new)
  local spilled = 0
  for i = 1, 10 do
    local oi = old.get_inventory(i)
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
      if new.insert_fluid({ name = ing.name, amount = ing.amount }) < ing.amount - 1e-6 then
        log("[FO-LEVELS] agrandissement : fluide de la fabrication en cours non rendu en entier (" .. ing.name .. ")")
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
function Levels.resume_progress()
  local pending = S().pending
  if not pending or next(pending) == nil then return 0 end
  local units = {}
  for u in pairs(pending) do units[#units + 1] = u end
  table.sort(units)
  local done = 0
  for _, u in ipairs(units) do
    local rec = pending[u]
    local e = rec.entity
    if not (e and e.valid) then
      pending[u] = nil
    elseif e.is_crafting() then
      local r = e.get_recipe() or (e.type == "furnace" and e.previous_recipe) or nil
      if r and r.name == rec.recipe then
        e.crafting_progress = rec.progress
        if rec.bonus > 0 then e.bonus_progress = rec.bonus end
        done = done + 1
      end
      pending[u] = nil
    elseif game.tick - rec.tick > Levels.PENDING_TTL then
      pending[u] = nil
    end
  end
  if done > 0 then
    local st = S()
    st.stats.resumed = (st.stats.resumed or 0) + done
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
      carry("crafting_progress")
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
local function move_ground_items(surface, rect, radius)
  local moved, left = 0, 0
  local items = surface.find_entities_filtered({ area = { { rect.x0, rect.y0 }, { rect.x1, rect.y1 } }, type = "item-entity" })
  for _, it in ipairs(items) do
    if it.valid then
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
  st.replacing = true
  local new = surface.create_entity({
    name = name, position = { x = cand.x, y = cand.y }, direction = dir, force = force,
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
  if cur and L.footprint(family, cur) ~= L.footprint(family, n) then
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
--- montre la place dans tous les cas).
function Levels.preview(entity, player, fresh)
  local family, n = L.parse(entity.name)
  if not family then return nil end
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
  if from ~= to then
    info.resize = { from = from, to = to }
    info.room = Levels.room(entity, from, L.name(family, n + 1), to)
    if info.ok and not info.room.chosen then info.ok, info.reason = false, "no-room" end
  end
  return info
end

--- Améliore `entity` AUSSITÔT si c'est permis et payable (player facultatif : source de paiement).
--- Renvoie ok, raison, info, nouvelle entité. Raison du succès : "done". Lot V3-T : la place est vérifiée par
--- l'aperçu, donc AVANT le paiement ; refus « no-room » : rien n'est payé, le contour nécessaire est dessiné
--- (visible du joueur, ou de la force sans joueur). Échec du remplacement par script alors que l'ancien
--- bâtiment est intact : le coût est rendu, chaque part à l'inventaire qui l'a payée.
function Levels.start(entity, player)
  if not (entity and entity.valid) then return false, "invalid" end
  -- Décision : recensement Q16 complet, jamais le cache.
  local info = Levels.preview(entity, player, true)
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
-- config, surfaces par index, entités dans l'ordre du moteur. Renvoie reposés, déjà en place, laissés.
---------------------------------------------------------------------------------------------------
function Levels.migrate_footprints()
  local st = S()
  local current = L.footprint_snapshot()
  local keys = {}
  for _, f in ipairs(L.families) do keys[#keys + 1] = f.key end
  local changes = Foot.diff(st.footprints, current, keys, function(k) return L.by_key[k].size end)
  local moved, inplace, kept = 0, 0, 0
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
  return moved, inplace, kept
end

---------------------------------------------------------------------------------------------------
-- Changement de version (0.3.0 → 15 époques ; 0.4.0 → amélioration instantanée ; toute mise à jour)
-- Les noms gardent leur sens : aucune donnée à convertir. Réparation : emprises (lot V3-T), chantiers hérités
-- achevés, centre disparu oublié, PV ramenés au maximum.
---------------------------------------------------------------------------------------------------
function Levels.repair()
  local st = S()
  -- Emprises D'ABORD : un chantier hérité suit son bâtiment reposé, puis il est achevé à la bonne taille.
  local moved, inplace, kept = Levels.migrate_footprints()
  if moved + kept > 0 then
    log("[FO-LEVELS] mise à jour des emprises : " .. moved .. " bâtiment(s) reposé(s), " .. inplace
      .. " déjà en place, " .. kept .. " laissé(s) faute de place (chevauchement toléré)")
  end
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
    local moved, inplace, kept = Levels.migrate_footprints()
    log("[FO-LEVELS] emprises (filet, sans changement de version) : " .. moved .. " bâtiment(s) reposé(s), "
      .. inplace .. " déjà en place, " .. kept .. " laissé(s) faute de place (chevauchement toléré)")
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
