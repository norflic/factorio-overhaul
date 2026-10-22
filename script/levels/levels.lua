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
  Déterminisme : tout se passe dans des événements ; listes triées (chantiers hérités par numéro, surfaces
  par index), jamais l'ordre de pairs.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")

local Levels = {}

-- `jobs` et `busy` restent des tables VIDES : ils portaient les chantiers minutés de 0.4.0 (achevés au
-- chargement) et l'interface distante (script/remote.lua, levels_status) les lit encore ; à retirer avec
-- le diff proposé à l'intégrateur. `census` : recensement Q16 en cache, par force (voir plus bas).
Storage.declare("levels", function()
  return { cc = {}, jobs = {}, busy = {}, census = {}, replacing = false,
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

local function pay(invs, cost)
  for _, c in ipairs(cost) do
    local left = c[2]
    for _, inv in ipairs(invs) do
      if left <= 0 then break end
      left = left - inv.remove({ name = c[1], count = left })
    end
  end
end

Levels.sources = sources
Levels.available = available

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

--- Remplace `entity` par le niveau n de sa famille. Renvoie la nouvelle entité ou nil.
local function replace(entity, family, n)
  local st = S()
  local name = L.name(family, n)
  local old_unit = entity.unit_number
  local ratio = entity.get_health_ratio() or 1
  local was_cc = Levels.cc(entity.force) == entity
  local surface, pos, dir, force = entity.surface, entity.position, entity.direction, entity.force
  st.replacing = true
  local new = surface.create_entity({
    name = name, position = pos, direction = dir, force = force,
    fast_replace = true, spill = false, raise_built = true, create_build_effect_smoke = false,
  })
  if not (new and new.valid and new.name == name) then
    if entity.valid then new = manual_replace(entity, name) end
    st.stats.fallback = (st.stats.fallback or 0) + 1
  end
  st.replacing = false
  if not new then return nil end
  new.health = new.prototype.max_health * ratio
  if was_cc then st.cc[force.name] = new end
  celebrate(new, family, n)
  for _, f in ipairs(Levels.on_replaced) do f(old_unit, new) end
  return new
end

---------------------------------------------------------------------------------------------------
-- Améliorer
---------------------------------------------------------------------------------------------------
--- Coût et autorisation de l'amélioration suivante de `entity` (sans rien changer).
--- Renvoie une table { family, level, next, cost, ok, reason, missing, cc_level, required_cc,
--- condition_level, blocking, unknown }. fresh : recensement Q16 complet (décision) ; sinon, le cache
--- (affichage du panneau).
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
  return info
end

--- Améliore `entity` AUSSITÔT si c'est permis et payable (player facultatif : source de paiement).
--- Renvoie ok, raison, info, nouvelle entité. Raison du succès : "done".
function Levels.start(entity, player)
  if not (entity and entity.valid) then return false, "invalid" end
  -- Décision : recensement Q16 complet, jamais le cache.
  local info = Levels.preview(entity, player, true)
  if not info then return false, "not-levelable" end
  if not info.ok then return false, info.reason, info end
  local st = S()
  pay(sources(entity.force, player), info.cost)
  local new = replace(entity, info.family, info.next)
  if not new then return false, "replace-failed", info end
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
        if replace(entity, family, job.to) then done = done + 1 else lost = lost + 1 end
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
-- Changement de version (0.3.0 → 15 époques ; 0.4.0 → amélioration instantanée ; toute mise à jour)
-- Les noms gardent leur sens : aucune donnée à convertir. Réparation : chantiers hérités achevés, centre
-- disparu oublié, PV ramenés au maximum.
---------------------------------------------------------------------------------------------------
function Levels.repair()
  local st = S()
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

-- Filet : une sauvegarde 0.4.0 rechargée SANS changement de version (on_configuration_changed n'est alors
-- pas appelé) garde ses chantiers ; ils sont achevés au premier passage. Coût nul hors de ce cas (next sur
-- une table vide).
Events.on_nth_tick(30, function()
  local jobs = S().jobs
  if jobs and next(jobs) ~= nil then
    local done, lost = Levels.finish_legacy_jobs()
    log("[FO-LEVELS] chantiers hérités : " .. done .. " achevé(s), " .. lost .. " perdu(s)")
  end
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
