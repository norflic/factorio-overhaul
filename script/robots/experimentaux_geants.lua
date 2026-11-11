--[[
  Lot EXPERIMENTAUX (3/11), palier 3 : les 5 GÉANTS en jeu. Règles pures : shared/robots/experimentaux.lua (Xp.GEANTS, Xp.giant_cap,
  Xp.marks, Xp.circuit, Xp.fissure, Xp.foyer_fires) ; prototypes : prototypes/experimentaux_geants.lua.

  - Posé (objet, robot, script) : inscrit ; refusé au-delà du plafond des géants (Xp.giant_ok, géants de shared/content/robots.lua COMPRIS,
    lus par script/robots/armee.lua sans y écrire) : l'entité est retirée, l'objet rendu au joueur (sinon au sol).
  - Le joueur qui le pose reçoit la télécommande vanilla liée (comme le Bourdon).
  - Corps : si Xp.GIANT_BODY == "rendering", sprites `rendering` attachés à l'entité (principale, lueur, ombre), sinon le prototype.
  - Toutes les 30 ticks : chaque géant prêt cherche l'ennemi le plus proche à portée (find_nearest_enemy), sinon toute entité ennemie à
    portée (bâtiments compris : décision du DC du 5/11, « jusqu'à la fin »), et lance son effet, puis une SALVE DE ZONE (règle d'échelle,
    shared/robots/echelle.lua : coup plein par cible dans 15 × (âge − 9) tuiles, cratère, sol brûlé), au plus toutes les Ech.CADENCE_ZONE
    ticks. Effets et salves qui s'étirent dans le temps passent par la file `gjobs`, traitée à chaque tick tant qu'elle n'est pas vide ; une
    salve de zone cherche ses cibles secteur par secteur (un par tick, Ech.SECTEUR), puis frappe ; toutes les salves en cours se partagent
    Ech.BUDGET coups et Ech.MORTS morts par tick (Ech.partage), et une unité ne relance pas sa salve tant que la précédente frappe. Bonus des modules (portée, puissance) : g.bonus, écrit par G.set_bonus (remote « fo-xp », « bonus »).
  Dégâts : script/robots/experimentaux_commun.lua (jamais sur sa force, ses amis, en cessez-le-feu).
]]

local Events = require("script.core.events")
local Xp = require("shared.robots.experimentaux")
local K = require("script.robots.experimentaux_commun")
local Armee = require("script.robots.armee")
local Ech = require("shared.robots.echelle")

local G = {}

local GEANT = {}
for _, r in ipairs(Xp.GEANTS) do GEANT[r.name] = r end

local SCAN = 30
local CAIRN_ARC = Xp.PREFIX .. "cairn-arc"
local FOYER = Xp.PREFIX .. "tournesol-foyer"
local PILIER = Xp.PREFIX .. "stylet-pilier"
local SPR_GLACE, SPR_VERRE = Xp.PREFIX .. "glace", Xp.PREFIX .. "verre"
local CRATERE = Xp.PREFIX .. "cratere-"
local CIBLES_MAX = 50 -- entités lues au plus pour trouver une cible non militaire (une recherche bornée toutes les 30 ticks par géant)
local BOUCHE = { cairn = { 0, -30 }, stylet = { 0, -2 }, trombe = { 0, -26 }, ixion = { 0, -8 }, tournesol = { -8.5, -31 } }

--- Couleur du `rendering` : le moteur la lit PRÉMULTIPLIÉE (gi1, 4/11 : { 0,85 ; 0,95 ; 1 ; a = 0,3 } donnait un disque blanc opaque).
local function rgba(r, g, b, a) return { r = r * a, g = g * a, b = b * a, a = a } end

--- Un rayon vise la POSITION de la cible : la cible tuée par le coup ne l'efface plus au tick suivant (gi1 : arcs du Cairn et foyer du
--- Tournesol invisibles, chaque coup tuant sa cible).
local function rayon(e, name, b, target, duration)
  e.surface.create_entity({ name = name, position = e.position, source = e, source_offset = { b[1], b[2] },
    target_position = { target.position.x, target.position.y }, duration = duration })
end

---------------------------------------------------------------------------------------------------
-- Registre et plafond
---------------------------------------------------------------------------------------------------
--- Géants de cette famille, vivants, pour une force (sans compter `sauf`).
local function mine(force_name, sauf)
  local n = 0
  for _, g in ipairs(K.S().giants) do
    if g.e.valid and g.e.force.name == force_name and g.un ~= sauf then n = n + 1 end
  end
  return n
end

--- Géants de cette famille pour une force : son NOM (chaîne, ce qu'envoie script/robots/armee.lua de robotsjeu) ; un LuaForce est aussi lu.
local appels = 0 -- appels de G.count pendant UN calcul (jamais gardé d'un tick à l'autre : rien en storage)
function G.count(force)
  appels = appels + 1
  local name = type(force) == "string" and force or (force and force.valid and force.name)
  if not name then return 0 end
  return mine(name, nil)
end

--- Modules (lot DESIGN-MODULES) : bonus de portée et de puissance d'un géant (0,2 = + 20 % ; PRODUIT avec la règle d'échelle,
--- Ech.effectif). Rend vrai si le géant est inscrit. Lu à chaque recherche de cible et à chaque salve ; la cadence ne change pas.
function G.set_bonus(unit_number, portee, puissance)
  local s = K.S()
  if not s then return false end
  for _, g in ipairs(s.giants) do
    if g.un == unit_number then
      g.bonus = { portee = tonumber(portee) or 0, puissance = tonumber(puissance) or 0 }
      return true
    end
  end
  -- géants de robotsjeu (ceux des factions compris, QCM-7/11 : modules « posés aussi sur les géants des factions selon leur âge ») :
  -- bonus gardés à part, lus par Geant.salves (script/robots/geant.lua)
  local u = Armee.entity(unit_number)
  if u and u.type == "spider-vehicle" then
    if not s.bonus_ro then s.bonus_ro = {} end
    s.bonus_ro[unit_number] = { portee = tonumber(portee) or 0, puissance = tonumber(puissance) or 0 }
    return true
  end
  return false
end

--- Bonus d'un géant de robotsjeu (nil sans module).
function G.bonus_de(unit_number)
  local s = K.S()
  return s and s.bonus_ro and s.bonus_ro[unit_number] or nil
end

--- Écouteurs d'une salve de zone (lot DESIGN-MODULES : marque visible des modules, UNE fois par salve). Fonctions gardées dans le module,
--- réinscrites à chaque chargement par le `require` de leur auteur : rien en storage. Appel : f(e, r, bonus, c, eff), bonus pouvant être nil
--- (géants de robotsjeu, géant sans module), eff = Ech.effectif(r, bonus).
local ecouteurs = {}
function G.ecoute(f) ecouteurs[#ecouteurs + 1] = f end

-- couche du corps -> couche de dessin (Xp.CORPS_COUCHES, dans l'ordre de dessin)
local COUCHE_RENDU = { ombre = "lower-object", corps = "air-object", ["lueur-1"] = "air-object" }

local function corps(g, r)
  if Xp.GIANT_BODY ~= "rendering" then return end
  local e = g.e
  local s = e.surface
  -- F525 : un géant au corps orienté (Xp.CORPS_DIRS) est posé dans la pose de son TORSE et garde les ids de ses couches (g.rid) pour la
  -- changer quand il tourne ; un géant à une image garde ses sprites fixes
  local pose = Xp.pose(r.id, e.torso_orientation)
  local rid = {}
  for _, c in ipairs(Xp.CORPS_COUCHES) do
    rid[c] = rendering.draw_sprite({ sprite = Xp.sprite_corps(r.id, c, pose), target = e, surface = s, render_layer = COUCHE_RENDU[c] })
  end
  if pose then g.rid, g.pose = rid, pose end
end

--- F525 : un géant au corps orienté suit son torse (balayage de SCAN ticks). Un géant d'une partie d'avant F525 (sans g.rid) a ses sprites fixes
--- d'une image : ils sont retirés (lecture bornée aux ids du mod qui visent cette entité, une fois) et le corps est reposé, orienté.
local function orienter(g, r)
  local e = g.e
  if not g.rid then
    for _, id in ipairs(rendering.get_all_ids(script.mod_name)) do
      if rendering.is_valid(id) and rendering.get_type(id) == "sprite" then
        local t = rendering.get_target(id)
        if t and t.entity == e then
          local nom = rendering.get_sprite(id)
          for _, c in ipairs(Xp.CORPS_COUCHES) do
            if nom == Xp.sprite_corps(r.id, c) then rendering.destroy(id) break end
          end
        end
      end
    end
    corps(g, r)
    return
  end
  local pose = Xp.pose(r.id, e.torso_orientation)
  if pose == g.pose then return end
  for _, c in ipairs(Xp.CORPS_COUCHES) do
    local id = g.rid[c]
    if id and rendering.is_valid(id) then rendering.set_sprite(id, Xp.sprite_corps(r.id, c, pose)) end
  end
  g.pose = pose
end

local function rendre(player, e, name)
  if player and player.valid and player.insert({ name = name, count = 1 }) == 1 then return end
  e.surface.spill_item_stack(e.position, { name = name, count = 1 }, true)
end

local function on_built(ev)
  local e = ev.created_entity or ev.entity
  if not (e and e.valid) then return end
  local r = GEANT[e.name]
  if not r then return end
  local force = e.force
  local age = Armee.age(force)
  -- Armee.giants (robotsjeu) compte déjà les miens s'il appelle l'interface « fo-xp » (integ-0647, armee.lua) : sinon, on les ajoute ici.
  -- Le nouveau venu n'est pas encore inscrit : il n'est compté ni par l'un ni par l'autre.
  local avant = appels
  local have = Armee.giants(force.name)
  if appels == avant then have = have + mine(force.name, e.unit_number) end
  local player = ev.player_index and game.get_player(ev.player_index)
  if not Xp.giant_ok(age, have) then
    K.journal("%s refuse : plafond des geants (%d deja, age %d, plafond %d)", r.id, have, age, Xp.giant_cap(age))
    local name = e.name
    -- les modules de sa grille sont rendus aussi (DESIGN-MODULES : un objet neuf ne les porte pas)
    if e.grid then
      for _, eq in ipairs(e.grid.equipment) do
        local it = eq.prototype.take_result
        if it then rendre(player, e, it.name) end
      end
    end
    rendre(player, e, name)
    if player then player.print({ "fo-xp.plafond", { "entity-name." .. name }, Xp.giant_cap(age), age }) end
    e.destroy()
    return
  end
  local s = K.S()
  local g = { un = e.unit_number, e = e, id = r.id, next = ev.tick or game.tick, n = 0 }
  s.giants[#s.giants + 1] = g
  corps(g, r)
  if player and game.item_prototypes["spidertron-remote"] then
    local stack = player.cursor_stack
    if stack and player.clear_cursor() and stack.valid and stack.set_stack({ name = "spidertron-remote", count = 1 }) then
      stack.connected_entity = e
    end
  end
  K.journal("%s pose #%d force %s (age %d, geants %d / %d)", r.id, e.unit_number, force.name, age, have + 1, Xp.giant_cap(age))
end

---------------------------------------------------------------------------------------------------
-- Effets
---------------------------------------------------------------------------------------------------
local function pos_of(e) return { x = e.position.x, y = e.position.y } end
local function bouche(g)
  local b = BOUCHE[g.id]
  return { x = g.e.position.x + b[1], y = g.e.position.y + b[2] }
end

local function job(j)
  local s = K.S()
  s.gjobs[#s.gjobs + 1] = j
end

--- Bonus des modules d'un géant (lot DESIGN-MODULES) : une COPIE de nombres pour les effets différés (jamais une table partagée).
local function bonus_de(g)
  local b = g.bonus
  return { portee = b and b.portee or 0, puissance = b and b.puissance or 0 }
end

--- SÉQUELLES (QCM-7/11 : « durer 1 heure, se résorber ») : registre des tuiles de cratère de chaque surface (shared/robots/echelle.lua).
local function traces(s)
  local st = K.S()
  if not st.traces then st.traces = {} end
  local R = st.traces[s.index]
  if not R then
    R = Ech.trace_nouveau()
    st.traces[s.index] = R
  end
  return R
end

--- Sol qui peut recevoir un cratère : ni hors de la carte, ni eau, ni sol posé par un joueur (tuile minable : béton, remblai…). Mémorisé par
--- NOM de tuile (revue de la 0.6.57, point 2 : get_tile, collides_with et la lecture du prototype sur 1 200 tuiles coûtaient 17 ms au tick
--- du tir) ; table du module, refaite à chaque chargement, jamais dans global : les prototypes ne changent pas pendant une partie.
local sol_cratere = {}
local function cratere_possible(name)
  local v = sol_cratere[name]
  if v == nil then
    local p = game.tile_prototypes[name]
    v = p ~= nil and name ~= "out-of-map" and not p.collision_mask["water-tile"] and not p.mineable_properties.minable
    sol_cratere[name] = v
  end
  return v
end

--- Tuiles a à b de la liste `tiles` passées en sol de cratère `nuclear-ground` (sol de la bombe atomique vanilla) pendant Ech.TRACE_TICKS,
--- jamais sur l'eau ni sur un sol posé par un joueur (cratere_possible), entités jamais retirées.
local function cratere_lot(s, tiles, a, b, tick)
  local R = traces(s)
  local fin = tick + (K.S().trace_ticks or Ech.TRACE_TICKS) -- trace_ticks : durée raccourcie par les bancs seulement (remote « fo-xp »)
  local pose = {}
  for i = a, b do
    local t = tiles[i]
    local name = s.get_tile(t.x, t.y).name
    if cratere_possible(name) then
      if Ech.trace_marquer(R, t.x, t.y, name, fin) and name ~= "nuclear-ground" then
        pose[#pose + 1] = { name = "nuclear-ground", position = { t.x, t.y } }
      end
    end
  end
  if #pose > 0 then s.set_tiles(pose, true, false, true, false) end
end

--- Cratère entier de rayon `rc` au point `c`, en une fois (remote de banc « cratere ») ; une salve le pose par lots (cratere_suite).
local function cratere(s, c, rc, tick)
  local tiles = Ech.disque(c, rc)
  cratere_lot(s, tiles, 1, #tiles, tick)
end
G.cratere = cratere

--- Lot suivant du cratère d'une salve (`j.cr` : tuiles du centre vers le bord, `j.ci` : prochaine), au plus Ech.CRATERE_LOT tuiles, ou
--- tout le reste si `tout` (le géant est mort : le cratère est fini quand même). Rend vrai quand le cratère est posé.
local function cratere_suite(j, tick, tout)
  local s = game.surfaces[j.surf]
  if not s then j.cr = nil; return true end
  local n = #j.cr
  local a, b, suite = Ech.lot_cratere(j.ci, n, tout)
  cratere_lot(s, j.cr, a, b, tick)
  j.ci = suite
  if j.ci > n then j.cr = nil end
  return j.cr == nil
end

--- Trace dessinée d'une heure (`id` : objet de rendu) : comptée par surface, les plus anciennes retirées au-delà de Ech.RENDUS_MAX (point 4).
local function trace_rendu(s, id)
  if not id then return end
  local st = K.S()
  if not st.rendus then st.rendus = {} end
  local F = st.rendus[s.index]
  if not F then
    F = Ech.rendus_nouveau()
    st.rendus[s.index] = F
  end
  for _, vieux in ipairs(Ech.rendus_ajouter(F, id, st.rendus_max or Ech.RENDUS_MAX)) do
    if rendering.is_valid(vieux) then rendering.destroy(vieux) end
  end
end
G.trace_rendu = trace_rendu

--- Résorption : les tuiles échues reprennent leur sol d'origine si elles sont encore un sol de cratère (au plus Ech.RESORPTION_LOT par
--- surface et par passage, toutes les RESORPTION ticks).
local RESORPTION = 5
local function resorber(ev)
  local st = K.S()
  if not (st and st.traces) then return end
  local idx = {}
  for i in pairs(st.traces) do idx[#idx + 1] = i end -- trié juste après
  table.sort(idx)
  for _, i in ipairs(idx) do
    local s = game.surfaces[i]
    if not s then
      st.traces[i] = nil
    else
      local rend = {}
      for _, e in ipairs(Ech.trace_echues(st.traces[i], ev.tick, Ech.RESORPTION_LOT)) do
        local t = s.get_tile(e.x, e.y)
        -- sol d'origine disparu depuis (mod retiré ou tuile renommée : set_tiles d'un nom inconnu lève une erreur) : le cratère reste
        -- (revue-0657, 7/11)
        if t.valid and t.name == "nuclear-ground" and e.orig ~= "nuclear-ground" and game.tile_prototypes[e.orig] then
          rend[#rend + 1] = { name = e.orig, position = { e.x, e.y } }
        end
      end
      if #rend > 0 then s.set_tiles(rend, true, false, true, false) end
    end
  end
end

--- Salve de zone en cours d'une unité (numéro d'unité -> vrai) : une unité ne relance pas de salve tant que la précédente frappe encore
--- (avec un budget partagé, deux salves d'un même géant pourraient sinon s'empiler sans fin). Rien d'autre n'y est gardé.
local function actives()
  local s = K.S()
  if not s.zones_actives then s.zones_actives = {} end
  return s.zones_actives
end
function G.zone_active(un) return actives()[un] == true end

--- E3 et E4 (règle d'échelle, shared/robots/echelle.lua) : salve de ZONE au point visé `c`, lancée par `g` = { e, un, bonus }. Cratère et
--- sol brûlé, puis un coup PLEIN (salve effective, jamais partagée) sur chaque entité ennemie de la zone effective, bâtiments compris.
--- Recherche par secteurs (un par tick), puis, par tick, sa part des budgets de coups et de morts (Ech.BUDGET, Ech.MORTS pour toutes les
--- salves), du centre vers le bord (l'onde se voit), au plus Ech.PLAFOND cibles par salve.
local function zone(g, r, c, tick)
  local e = g.e
  local s = e.surface
  actives()[g.un] = true
  local eff = Ech.effectif(r, g.bonus)
  for _, f in ipairs(ecouteurs) do f(e, r, g.bonus, c, eff) end
  s.create_entity({ name = CRATERE .. r.age, position = { c.x, c.y } }) -- explosion et décoratifs retirés ; le sol, par cratere()
  local cr = Ech.disque_radial(c, r.cratere) -- cratère posé par lots du centre vers le bord (premier lot ici, la suite par zone_pas)
  local b = K.S().impact == "B" -- design IMPACT : variante B (sol brûlé sur la zone), posée par les bancs d'images seulement
  if b then
    for _, x in ipairs(Ech.brulures(c, eff.zone)) do s.create_entity({ name = Xp.PREFIX .. x.nom, position = { x.x, x.y } }) end
  else
    s.create_entity({ name = Xp.PREFIX .. "big-scorchmark", position = { c.x, c.y } })
  end
  -- recherche par SECTEURS (un par tick : le tick 0 du double tir coûtait 10,7 ms de script, 7/11), puis frappe
  local forces = K.enemy_forces(e.force)
  job({ kind = "zone", e = e, un = g.un, id = r.id, dtype = r.dtype, force = e.force.name, forces = forces, c = { x = c.x, y = c.y },
        secteurs = Ech.secteurs(c, eff.zone, Ech.SECTEUR), si = 1, plan = Ech.nouveau_plan(c), salve = eff.salve, zone = eff.zone,
        at = tick, total = 0, tues = 0, debut = tick, brule = b or nil, nb = 0, cr = cr, ci = 1, surf = s.index })
  cratere_suite(K.S().gjobs[#K.S().gjobs], tick, false)
end

--- Recherche d'UN secteur : entités ennemies du carré, gardées si leur position est dans le secteur demi-ouvert (aucun doublon de bord,
--- F96) et dans le disque de la zone ; rangées par anneau. Quand tous les secteurs sont lus, le plan est figé.
local function zone_chercher(j)
  local q = j.secteurs[j.si]
  local s = j.e.surface
  -- un chunk non généré n'a pas d'entité : ne pas le chercher (la recherche par carré faisait générer les chunks de bord, revue 0.6.57)
  if #j.forces > 0 and (q.cx == nil or s.is_chunk_generated({ x = q.cx, y = q.cy })) then
    local r2 = j.zone * j.zone
    for _, x in ipairs(s.find_entities_filtered({ area = { { q.x0, q.y0 }, { q.x1, q.y1 } }, force = j.forces })) do
      if x.valid and x.health and x.destructible then
        local p = x.position
        if Ech.dans_secteur(q, p.x, p.y) then
          local dx, dy = p.x - j.c.x, p.y - j.c.y
          if dx * dx + dy * dy <= r2 then
            Ech.poser(j.plan, p.x, p.y, x)
            j.nb = j.nb + 1
          end
        end
      end
    end
  end
  j.si = j.si + 1
  if j.si > #j.secteurs then
    j.secteurs, j.forces, j.cur = nil, nil, Ech.curseur()
    if j.brule then j.pas = Ech.pas_brulure(math.min(j.nb, Ech.PLAFOND)) end
  end
end

local function zone_pas(j, tick)
  local e = j.e
  if j.cr then cratere_suite(j, tick, not (e and e.valid)) end
  if not (e and e.valid) then
    actives()[j.un] = nil
    return true
  end
  if not Ech.zone_jouable(j) then
    -- job d'une sauvegarde d'avant la recherche par secteurs (B1, revue de la 0.6.57) : abandonné ; le géant pourra tirer de nouveau
    K.journal("%s zone #%s d'une version d'avant : abandonnee tick %d", tostring(j.id), tostring(j.un), tick)
    actives()[j.un] = nil
    return true
  end
  if j.secteurs then
    zone_chercher(j)
    j.at = tick + 1
    return false
  end
  -- parts des budgets de ce tick (Ech.partage, posées par on_tick) : Ech.BUDGET coups et Ech.MORTS morts pour TOUTES les salves
  local qh, qm = j.quota or 0, j.quota_m or 0
  j.quota, j.quota_m = nil, nil
  if qh <= 0 or qm <= 0 then
    j.at = tick + 1
    return false
  end
  -- frappe sans allocation (K.frappe) : force par son nom, ennemis par leurs index, relus à CHAQUE tick (paix ou cessez-le-feu pendant la
  -- salve : compté dès le tick suivant) ; un job d'une version d'avant reçoit le nom de sa force ici, une fois
  if not j.force then j.force = e.force.name end
  local st_r, fid, en = K.stat(j.id), j.force, K.ennemis_du_tick(j.force) -- statistiques par robot : les géants de robotsjeu y ont aussi leur ligne
  local c, m, fini = Ech.frapper(j.plan, j.cur, qh, qm, function(t)
    if not t.valid then return false end
    local p = j.brule and t.position
    j.total = j.total + K.frappe(st_r, t, j.salve, j.dtype, fid, e, en)
    if not t.valid or t.health <= 0 then
      j.tues = j.tues + 1
      if p and j.tues % j.pas == 0 then e.surface.create_entity({ name = Xp.PREFIX .. "small-scorchmark", position = { p.x, p.y } }) end
      return true
    end
    return false
  end)
  -- bancs seulement (journal allumé) : coups et morts par tick, pour mesurer le coût du script et des débris par mort (pics_zone.py)
  local st = K.S()
  if st.journal and c > 0 then
    if not st.morts_tick then st.morts_tick, st.coups_tick = {}, {} end
    st.morts_tick[tick] = (st.morts_tick[tick] or 0) + m
    st.coups_tick[tick] = (st.coups_tick[tick] or 0) + c
  end
  if fini then
    K.journal("%s zone #%d rayon %.0f cibles %d tues %d degats %.0f ticks %d tick %d", j.id, j.un, j.zone, j.cur.pris, j.tues, j.total,
      tick - j.debut + 1, tick)
    actives()[j.un] = nil
    return true
  end
  j.at = tick + 1
  return false
end

--- Cairn : marque les cibles, puis (après `delay`) tire un arc sur chaque marque et la salve de zone autour de la cible.
local function balayage(g, r, target, tick)
  local e = g.e
  local eff = Ech.effectif(r, g.bonus) -- portée et zone EFFECTIVES (modules), comme cible() (défaut vu par DESIGN-MODULES, 6/11)
  local marks = Xp.marks(pos_of(e), K.candidates(e.surface, e.force, e.position, eff.range), r.marks, eff.range)
  if #marks == 0 then return false end
  local list = {}
  for _, m in ipairs(marks) do
    rendering.draw_circle({ color = rgba(0.3, 0.7, 1.0, 0.8), radius = 1.6, width = 6, filled = false, target = m.e, surface = e.surface,
      time_to_live = r.delay + 20 })
    list[#list + 1] = m.e
  end
  rendering.draw_circle({ color = rgba(0.15, 0.4, 0.8, 0.25), radius = eff.zone, width = 4, filled = false, target = pos_of(target),
    surface = e.surface, time_to_live = r.delay + 10, draw_on_ground = true })
  job({ kind = "cairn", e = e, un = g.un, bonus = bonus_de(g), list = list, c = pos_of(target), at = tick + r.delay })
  return true
end

local function cairn_tire(j, tick)
  local e = j.e
  if not (e and e.valid) then return end
  local r = Xp.robot("cairn")
  local b = BOUCHE.cairn
  local n = 0
  for _, t in ipairs(j.list) do
    if t.valid then rayon(e, CAIRN_ARC, b, t, 20); n = n + 1 end
  end
  K.journal("cairn balayage #%d arcs %d tick %d", j.un, n, tick)
  zone(j, r, j.c, tick)
end

--- Stylet : le circuit à angles droits court de la pointe aux nœuds, un pilier à chaque nœud ; la salve de zone autour de la cible.
local function ecriture(g, r, target, tick)
  local e = g.e
  local cands = K.candidates(e.surface, e.force, target.position, 40)
  local first = { x = target.position.x, y = target.position.y, id = target.unit_number or 0, e = target }
  local nodes, pts = Xp.circuit(pos_of(e), first, cands, r.nodes, 12)
  job({ kind = "stylet", e = e, un = g.un, nodes = nodes, pts = pts, k = 1, at = tick + 1 })
  zone(g, r, pos_of(target), tick)
  return true
end

local function stylet_pas(j, tick)
  local e = j.e
  local r = Xp.robot("stylet")
  if not (e and e.valid) then return true end
  local a, b = j.pts[j.k], j.pts[j.k + 1]
  if not b then
    K.journal("stylet ecriture #%d noeuds %d tick %d", j.un, #j.nodes, tick)
    return true
  end
  rendering.draw_line({ color = rgba(0.6, 0.85, 1.0, 0.9), width = 12, from = { a.x, a.y }, to = { b.x, b.y }, surface = e.surface,
    time_to_live = 150, draw_on_ground = true })
  rendering.draw_line({ color = { r = 1, g = 1, b = 1, a = 1 }, width = 4, from = { a.x, a.y }, to = { b.x, b.y }, surface = e.surface,
    time_to_live = 60, draw_on_ground = true })
  for _, nd in ipairs(j.nodes) do
    if math.abs(nd.x - b.x) < 1e-6 and math.abs(nd.y - b.y) < 1e-6 then e.surface.create_entity({ name = PILIER, position = { b.x, b.y } }) end
  end
  j.k = j.k + 1
  j.at = tick + r.step_ticks
  return false
end

--- Trombe : le sol blanchit dans la zone, les unités ennemies s'arrêtent ; au dégel, pics de glace et salve de zone.
local function gel(g, r, target, tick)
  local e = g.e
  local c = pos_of(target)
  local frozen = {}
  for _, it in ipairs(Xp.in_radius(c, K.candidates(e.surface, e.force, c, r.zone + 2), r.zone)) do
    local t = it.c.e
    if t.valid and t.active then
      t.active = false
      frozen[#frozen + 1] = t
    end
  end
  rendering.draw_circle({ color = rgba(0.75, 0.9, 1.0, 0.22), radius = r.zone, filled = true, target = { c.x, c.y }, surface = e.surface,
    time_to_live = r.freeze + 40, draw_on_ground = true })
  rendering.draw_circle({ color = rgba(0.6, 0.9, 1.0, 0.7), radius = r.zone, width = 12, filled = false, target = { c.x, c.y },
    surface = e.surface, time_to_live = r.freeze + 40, draw_on_ground = true })
  job({ kind = "trombe", e = e, un = g.un, bonus = bonus_de(g), c = c, frozen = frozen, at = tick + r.freeze })
  K.journal("trombe gel #%d geles %d tick %d", g.un, #frozen, tick)
  return true
end

local function trombe_degel(j, tick)
  local r = Xp.robot("trombe")
  for _, t in ipairs(j.frozen) do
    if t.valid then t.active = true end
  end
  if not (j.e and j.e.valid) then return end
  local surface = j.e.surface
  for _, t in ipairs(j.frozen) do
    if t.valid then rendering.draw_sprite({ sprite = SPR_GLACE, target = t.position, surface = surface, time_to_live = 90, render_layer = "object" }) end
  end
  K.journal("trombe degel #%d geles %d tick %d", j.un, #j.frozen, tick)
  zone(j, r, j.c, tick)
end

--- Ixion : la fissure court vers la cible et au-delà, geysers le long ; la salve de zone autour de la cible.
local function tranchee(g, r, target, tick)
  local e = g.e
  local pts = Xp.fissure(pos_of(e), pos_of(target), r.step, r.beyond)
  if #pts == 0 then return false end
  job({ kind = "ixion", e = e, un = g.un, pts = pts, k = 1, at = tick + 1, prev = pos_of(e) })
  zone(g, r, pos_of(target), tick)
  return true
end

local function ixion_pas(j, tick)
  local e = j.e
  local r = Xp.robot("ixion")
  if not (e and e.valid) then return true end
  local p = j.pts[j.k]
  if not p then
    K.journal("ixion tranchee #%d points %d tick %d", j.un, #j.pts, tick)
    return true
  end
  trace_rendu(e.surface, rendering.draw_line({ color = rgba(0.12, 0.07, 0.05, 0.95), width = 32 * r.width * 0.5, from = { j.prev.x, j.prev.y },
    to = { p.x, p.y }, surface = e.surface, time_to_live = Ech.TRACE_TICKS, draw_on_ground = true })) -- séquelle : 1 h (QCM-7/11), plafonnée
  rendering.draw_line({ color = { r = 1.0, g = 0.5, b = 0.12, a = 1 }, width = 32 * r.width * 0.15, from = { j.prev.x, j.prev.y }, to = { p.x, p.y },
    surface = e.surface, time_to_live = 240, draw_on_ground = true })
  e.surface.create_entity({ name = "big-explosion", position = { p.x, p.y } })
  j.prev = p
  j.k = j.k + 1
  j.at = tick + r.step_ticks
  return false
end

--- Tournesol : de jour, le foyer rend un trait sur la cible pendant toute la cadence ; verre fondu au sol ; la salve de zone autour.
local function foyer(g, r, target, tick)
  local e = g.e
  if not Xp.foyer_fires(e.surface.darkness, r.night) then return false end
  local b = BOUCHE.tournesol
  rayon(e, FOYER, b, target, r.zone_cooldown)
  g.n = g.n + 1
  if g.n % r.glass_every == 0 and target.valid then
    trace_rendu(e.surface, rendering.draw_sprite({ sprite = SPR_VERRE, target = target.position, surface = e.surface, time_to_live = Ech.TRACE_TICKS,
      render_layer = "decals", tint = rgba(1, 0.9, 0.6, 0.8) })) -- séquelle : 1 h, plafonnée
  end
  K.journal("tournesol foyer #%d tick %d", g.un, tick)
  zone(g, r, pos_of(target), tick)
  return true
end

local EFFECTS = { balayage = balayage, ecriture = ecriture, gel = gel, tranchee = tranchee, foyer = foyer }

--- Cible d'un géant : l'ennemi MILITAIRE le plus proche à portée, sinon (décision du DC, 5/11 : « tout ce qui est ennemi, jusqu'à la fin »)
--- la première entité ennemie avec des PV à portée (ordre de la recherche du moteur, le même sur toutes les machines).
local function cible(g, r)
  local e = g.e
  local range = Ech.effectif(r, g.bonus).range
  local t = e.surface.find_nearest_enemy({ position = e.position, max_distance = range, force = e.force })
  if t then return t end
  local forces = K.enemy_forces(e.force)
  if #forces == 0 then return nil end
  for _, x in ipairs(e.surface.find_entities_filtered({ position = e.position, radius = range, force = forces, limit = CIBLES_MAX })) do
    if x.valid and x.health and x.destructible then return x end
  end
  return nil
end

--- Pour les géants de robotsjeu (script/robots/geant.lua, règle d'échelle) : cible et salve de zone, mêmes règles que les géants de cette
--- famille. `r` : un robot de données avec id, age, dtype, range, zone, salve, cratere (shared/content/robots.lua).
function G.cible(e, r, bonus) return cible({ e = e, bonus = bonus }, r) end

--- Bancs seulement (B1, banc xp-zone-ancien) : pose dans la file deux jobs de salve au FORMAT DE LA 0.6.56 pour le géant `un` (ce qu'une
--- sauvegarde faite pendant une salve contient) : l'un avant rangement (liste `found`, rang `i`), l'autre en frappe (plan SANS `cnt`,
--- curseur), et marque la salve active. Rend le nombre de jobs posés (0 si le géant n'est pas inscrit).
function G.ancien_job(un)
  local s = K.S()
  for _, g in ipairs(s.giants) do
    if g.un == un and g.e and g.e.valid then
      local e = g.e
      local c = { x = e.position.x, y = e.position.y }
      local found = e.surface.find_entities_filtered({ position = c, radius = 40, force = K.enemy_forces(e.force) })
      local tick = game.tick
      job({ kind = "zone", e = e, un = un, id = g.id, dtype = "laser", found = found, i = 1, plan = { c = c, rings = {}, top = 0 },
            salve = 1, zone = 40, at = tick, total = 0, tues = 0, debut = tick, nb = 0 })
      local plan = { c = c, rings = { found }, top = 1 }
      job({ kind = "zone", e = e, un = un, id = g.id, dtype = "laser", plan = plan, cur = { k = 1, i = 1, pris = 0 }, salve = 1, zone = 40,
            at = tick, total = 0, tues = 0, debut = tick, nb = #found })
      actives()[un] = true
      return 2
    end
  end
  return 0
end

--- Bancs seulement : jobs de salve de zone dans la file, { n = tous, anciens = ceux qui ne peuvent pas frapper (Ech.zone_jouable faux) }.
function G.jobs_zone()
  local n, a = 0, 0
  for _, j in ipairs(K.S().gjobs) do
    if j.kind == "zone" then
      n = n + 1
      if not Ech.zone_jouable(j) then a = a + 1 end
    end
  end
  return { n = n, anciens = a }
end
function G.salve(e, un, r, c, tick, bonus) zone({ e = e, un = un, bonus = bonus }, r, c, tick) end

local function scan(ev)
  local s = K.S()
  if not s or #s.giants == 0 then return end
  local keep = {}
  for _, g in ipairs(s.giants) do
    if g.e.valid then
      keep[#keep + 1] = g
      if Xp.GIANT_BODY == "rendering" and Xp.CORPS_DIRS[g.id] then orienter(g, Xp.robot(g.id)) end
      if ev.tick >= g.next and not G.zone_active(g.un) then
        local r = Xp.robot(g.id)
        local t = cible(g, r)
        if t and EFFECTS[r.effect](g, r, t, ev.tick) then
          local st = K.stat(r.id)
          st.coups = st.coups + 1
          g.next = ev.tick + r.zone_cooldown
        end
      end
    end
  end
  s.giants = keep
end

local STEP = { stylet = stylet_pas, ixion = ixion_pas, zone = zone_pas }

local function on_tick(ev)
  local s = K.S()
  if not s or #s.gjobs == 0 then return end
  local keep = {}
  local n0 = #s.gjobs
  -- budget de coups de zone du tick, partagé par les salves qui frappent (dans l'ordre de la file ; le reste tourne d'un tick à l'autre)
  local zj, fz = {}, {}
  for i = 1, n0 do
    local j = s.gjobs[i]
    if j.kind == "zone" and not j.secteurs and j.at <= ev.tick and Ech.zone_jouable(j) then
      zj[#zj + 1] = j
      fz[#zj] = j.force or (j.e and j.e.valid and j.e.force.name) or "?" -- j.force : posée par zone() depuis le partage par force
    end
  end
  -- parts équitables PAR FORCE, puis par salve (Ech.partage_forces) ; s.budgets : autres budgets, bancs de mesure seulement (remote
  -- « fo-xp », « budgets ») ; en jeu, Ech.BUDGET et Ech.MORTS
  local parts = Ech.partage_forces(fz, s.budgets and s.budgets.coups or Ech.BUDGET, ev.tick)
  local morts = Ech.partage_forces(fz, s.budgets and s.budgets.morts or Ech.MORTS, ev.tick)
  for k, j in ipairs(zj) do j.quota, j.quota_m = parts[k], morts[k] end
  for i = 1, n0 do
    local j = s.gjobs[i]
    local done = false
    if j.at <= ev.tick then
      if j.kind == "cairn" then cairn_tire(j, ev.tick); done = true
      elseif j.kind == "trombe" then trombe_degel(j, ev.tick); done = true
      else done = STEP[j.kind](j, ev.tick) end
    end
    if not done then keep[#keep + 1] = j end
  end
  -- les salves lancées pendant ce tick (cairn_tire, trombe_degel) ont été ajoutées en fin de liste : elles sont gardées
  for i = n0 + 1, #s.gjobs do keep[#keep + 1] = s.gjobs[i] end
  s.gjobs = keep
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on(defines.events.on_tick, on_tick)
Events.on_nth_tick(SCAN, scan)
Events.on_nth_tick(RESORPTION, resorber)

return G
