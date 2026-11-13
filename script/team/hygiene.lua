--[[
  Lot SCAN-TRANCHES (directive du DC du 9/11) : HYGIÈNE ÉLECTRIQUE, audit en LECTURE SEULE des poteaux d'une équipe, par impulsions
  (toutes les St.CFG.period ticks) étalées sur une fenêtre de St.CFG.slices ticks successifs, équipes désynchronisées (règle pure :
  shared/team/scan_tranches.lua). Cette première livraison COMPTE et JOURNALISE ([FO-HYGIENE]) ; elle ne retire AUCUNE entité.

  Branchement : requis par script/team/build.lua (Build.Hygiene) ; abonnement statique à on_tick, sortie O(1) hors fenêtre
  (St.rank_at : une division et un reste). Rang d'une équipe = sa place dans l'ordre stable « factions vivantes (ids triés), puis votre
  équipe » (le même ordre que la passe du plan directeur).

  Une impulsion, pour une équipe :
    1. RELEVÉ (première tranche où le jeton des travaux lourds est accordé, script/core/lourd.lua, coût déclaré = chunks de la boîte) :
       les poteaux de la force dans la boîte des chunks générés (script/team/boite_chunks.lua), gardés en données pures
       { unit_number, x, y }, triés par unit_number ;
    2. AUDIT par tranches (St.share sur les tranches restantes, au plus St.CFG.max_per_slice poteaux par tranche ; le poteau est RETROUVÉ
       à sa position et reconnu à son unit_number : un chargement de sauvegarde ne perd rien) :
       (a) SUR GISEMENT : au moins une entité de type « resource » sur l'emprise en tuiles entières du poteau ;
       (b) REDONDANT CANDIDAT = « feuille sans consommateur propre » : au plus UN voisin de fil de cuivre (un sommet de degré ≤ 1 n'est
           jamais un point d'articulation : son retrait ne coupe aucun autre poteau du réseau) ET chaque entité ALIMENTÉE par lui (source
           électrique au prototype, pas un poteau, même electric_network_id, boîte de collision dans son carré d'alimentation) est
           aussi dans le carré d'alimentation d'un AUTRE poteau de la même force et du même réseau. Un poteau isolé (aucun fil, rien
           d'alimenté) est compté candidat : il peut appartenir à un chantier en cours (lecture seule : rien n'est décidé ici).
       Ce qui N'EST PAS mesuré : la connexion des fils après retrait (hors de portée sans simulation ; la feuille s'en passe), la portée
       de fil entre les poteaux restants, les réseaux rouges et verts.
    3. JOURNAL, une ligne à la dernière tranche : « [FO-HYGIENE] <équipe> : impulsion a X.X min : P poteaux releves, S sur gisement,
       R redondants candidats (feuilles sans consommateur propre) ; cout : N tranches » (N = tranches ayant travaillé).
  État : f.team.hygiene (nombres, booléens, liste de triplets de nombres), jamais de fonction ni d'entité.

  Lot SCAN-EVENEMENTS (directive du DC du 9/11, « bannissement du H24 ») : période de 3 min (St.CFG.period = 10 800) ET RÉVEIL événementiel.
  La période est un train de créneaux de stride ticks ; le créneau k appartient au rang k mod n (n équipes) : k < n, c'est la fenêtre
  périodique du rang k ; au-delà, un créneau libre de la VOIE du rang, où une passe ne part qu'à la tranche 0 si un réveil est posé
  (St.due / St.ack sur f.team.scan ; déclencheurs : script/team/scan_reveil.lua). Journal au départ d'une passe de réveil :
  « [FO-SCAN] <équipe> : reveil (<cause>) a X.X min » ; la ligne [FO-HYGIENE] de la passe redit sa cause. Le début d'une passe est le
  tick de sa tranche 0 (t0 = tick - tranche) : une passe de réveil et une passe périodique ont le même moteur.

  Lot HYGIENE-ACTIVE (décision du DC du 10/11 : « passer de l'audit (F444, lecture seule) au démontage sécurisé ») : l'audit d'un poteau
  est suivi, DANS LA MÊME TRANCHE (les lectures datent du tick même), d'une action bornée (règle pure : shared/team/hygiene_regle.lua) :
    (a) FEUILLE sans consommateur propre (Hr.feuille_retirable : couvrant ALIMENTÉ au registre des génératrices, hors projet non fini,
        hors pièce d'un plan fini (le réseau vivant la reposerait), hors chaîne des foreuses en cours, hors box MAXED, jamais posée par un
        joueur) : l'objet est rendu au coffre (Stock.insert du nom d'objet du prototype) PUIS le poteau est détruit (coffre plein : rien) ;
    (b) SUR GISEMENT (voisins de fil, ou consommateur propre) : Hr.sur_gisement_plan sur l'anneau des positions à portée de fil (hors
        tuile de ressource, place libre, non réservée par le plan directeur, aucun ennemi près) ; le REMPLAÇANT est posé payé au stock
        (jamais sans poteau au coffre : cause « stock »), relié à chaque ancien voisin ; à la tranche SUIVANTE (f.team.hygiene_pending,
        données pures), on vérifie qu'il est connecté à tous les anciens voisins (neighbours.copper), sur le réseau alimenté de l'ancien,
        et que tout consommateur de l'ancien est couvert par un autre poteau : alors l'ancien est rendu au coffre et détruit ; sinon le
        remplaçant est détruit et rendu (jamais deux poteaux sur le gisement). Une seule pose en attente par équipe.
  Gardes : budget Hr.budget par impulsion (4), jamais sous menace du QG (f.team.hq_menace.crise, f.threatened_until), jamais pendant une
  famine de la plaque clé (Famine.team_starved : le fer des poteaux). Journal, agrégé dans la ligne d'impulsion : « ; retire poteau feuille
  (x, y) ; remplace poteau sur gisement (x, y) -> (x', y') ; refus : <cause> N ». Critère de banc : [FO-RESEAU] sans « poteaux perdus »
  ni « consommateurs hors reseau » nouveaux après un retrait.

  Lot HYGIENE-PLANS-FINIS (directive du DC du 10/11, priorité 3) : une pièce d'un plan FINI sur gisement n'est plus refusée d'office
  (règle pure Hr.plan_cedable). Lectures au tick : la couverture est exigée d'un poteau EXTÉRIEUR (hors gisement, même réseau :
  own_fed(…, ext = true)) ; la continuité du réseau tient par la feuille (≤ 1 fil) ou par la voie du remplaçant (relié à tous les voisins,
  vérifié à la tranche suivante). La cession est écrite par UN SEUL écrivain, Build.cede_piece (script/team/build.lua) : feuille cédée ->
  e.dropped, p.dropped + 1, tuiles rendues à b.occ (le minerai redevient exploitable, le réseau vivant et le relevé de reconstruction ne la
  reposent plus) ; remplacée -> la pièce du plan SUIT le remplaçant hors gisement (mêmes lecteurs, le plan garde son poteau). Journal, une
  ligne par acte : « [FO-HYGIENE] <équipe> : cede poteau du plan <id> en (x, y) a X.X min : feuille | remplacant -> (x', y') ».
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local BoiteChunks = require("script.team.boite_chunks")
local Lourd = require("script.core.lourd")
local Profiler = require("script.core.profiler")
local St = require("shared.team.scan_tranches")
local Sr = require("script.team.scan_reveil") -- lot SCAN-EVENEMENTS : réveils (ordre des équipes, état f.team.scan)
local Boxes = require("script.team.boxes_rt") -- lot BOXES (DC 9/11) : relevé des boxes à la tranche 0, poteaux d'une box MAXED sautés à l'audit
local Balises = require("script.team.balises_teinte") -- lot BALISES-TEINTE (DC 10/11) : lueur des balises d'après leurs modules, une tranche par appel
local Hr = require("shared.team.hygiene_regle") -- lot HYGIENE-ACTIVE (DC 10/11) : règle pure du retrait
local P = require("shared.team.plan") -- lot HYGIENE-ACTIVE : clé de tuile (f.swap.pole_pos)
local PlacesQG = require("script.ai3.places_qg") -- lot TUILES-RESERVEES : tuiles réservées au plan (crochet unique)
local Stock = require("script.team.stock") -- lot HYGIENE-ACTIVE : objet rendu au coffre, remplaçant payé au stock
local Famine = require("script.team.famine_fer") -- lot HYGIENE-ACTIVE : jamais pendant une famine de la plaque clé
local Gens = require("script.team.generateurs") -- lot HYGIENE-ACTIVE : réseaux alimentés (registre des génératrices)
local Rv = require("script.team.reseau_vivant") -- lot HYGIENE-ACTIVE : Rv.foe_near (aucun remplaçant posé avec un ennemi près)
local Zone = require("script.team.zone_equipe") -- lot UPS-HYGIENE : relevé dans la zone de l'équipe (rectangles du plan), plus sur toute la carte

local Hy = {}

Hy.CFG = St.CFG
Hy.MAX_RANKS = 16     -- garde : au-delà, aucune équipe (sortie avant toute lecture de l'état)
Hy.SEEK_R = 0.2       -- tuiles : rayon pour retrouver un poteau à sa position relevée
Hy.GEN_TYPES = Gens.TYPES -- lot HYGIENE-ACTIVE : types de génératrices d'un réseau « alimenté » (ceux du registre, les mêmes que raccord.lua)

local function key_of(f) return tostring(f.key or "player") end
local function who(f) return key_of(f) .. ":hygiene" end

--- Identifiants des équipes dans l'ordre stable des rangs : factions vivantes (ids triés), puis « player » si votre équipe existe.
function Hy.ids() return Sr.ids() end

--- Déclencheurs d'une pensée d'équipe (script/team/team.lua, E6 : Build.Hygiene.reveil) : palier de stock, coupure d'énergie, rupture de
--- ressource (script/team/scan_reveil.lua, Sr.think). Rend la première cause posée ou nil.
function Hy.reveil(f, stock, tick) return Sr.think(f, stock, tick) end

local function new_pass(t0, why)
  return { t0 = t0, why = why or "periode", poles = {}, n = 0, sur = 0, red = 0, audited = 0, gone = 0, skipped = 0, cost = 0, dmax = 0,
    r0 = nil, logged = false, retraits = 0, acts = { feuilles = {}, remplaces = {}, refus = {}, cedes = {} }, plan = {}, plan_ref = {} } -- lot HYGIENE-ACTIVE : actions ; HYGIENE-PLANS-FINIS : cessions
end

--- Clé de tuile d'un poteau (position du centre ou du coin : la tuile entière), chaîne : l'état de passe reste en données pures.
local function tile_key(x, y) return math.floor(x) .. ":" .. math.floor(y) end

local pole_names = {} -- mémo du type des noms rencontrés dans les plans (dérivé des prototypes : identique sur tous les pairs)
local function is_pole_name(name)
  local v = pole_names[name]
  if v == nil then
    local pr = game and game.entity_prototypes and game.entity_prototypes[name]
    v = (pr and pr.type == "electric-pole") and true or false
    pole_names[name] = v
  end
  return v
end

--- Lot HYGIENE-ACTIVE : tuiles des poteaux des projets du plan directeur (f.build.projects, ordre b.order) : « chantier » (projet non
--- fini : jamais touché), « fini » (pièce bâtie d'un plan fini : le réseau vivant la reposerait comme poteau perdu). Un projet abandonné
--- n'y est pas (ses poteaux sont des feuilles comme les autres). Données pures (chaînes).
local function plan_poles(f)
  local out, ref = {}, {}
  local b = f.build
  if not (b and b.projects and b.order) then return out, ref end
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and not q.abandoned and q.ents then
      local tag = (q.state == "fini") and "fini" or "chantier"
      for i, e in ipairs(q.ents) do
        if e.x and e.y and is_pole_name(e.name) and not e.dropped then -- lot HYGIENE-PLANS-FINIS : une pièce cédée n'est plus du plan
          local k = tile_key(e.x, e.y)
          if out[k] ~= "chantier" then out[k], ref[k] = tag, { pid, i } end -- lot HYGIENE-PLANS-FINIS : (projet, rang) de la pièce, données pures
        end
      end
    end
  end
  return out, ref
end

--- Lot HYGIENE-PLANS-FINIS : la pièce du plan (projet, pièce) d'une référence { pid, i } relevée, si elle est toujours un poteau.
local function piece_of(f, ref)
  local b = f.build
  local q = ref and b and b.projects and b.projects[ref[1]]
  local pe = q and q.ents and q.ents[ref[2]]
  if pe and is_pole_name(pe.name) then return q, pe end
  return nil, nil
end

--- 1. Relevé des poteaux de la force (jeton des travaux lourds pris d'abord ; faux s'il est refusé : on réessaie à la tranche suivante).
local function releve(f, surface, h, tick, slice)
  local box = BoiteChunks.get(surface)
  local rects = Zone.rects(f, surface, tick) -- lot UPS-HYGIENE : rectangles du plan (nil : équipe sans plan ni QG, la boîte entière)
  if not Lourd.take(tick, who(f), nil, Zone.cost(rects, box)) then return false end
  Profiler.fstart("hyg:releve")
  local q = { type = "electric-pole", force = f.force }
  local poles, dmax = {}, 0
  h.zone = rects and #rects or 0
  for _, e in ipairs(Zone.find(surface, q, rects, box)) do
    if e.valid and e.unit_number then
      poles[#poles + 1] = { e.unit_number, e.position.x, e.position.y }
      local d = e.prototype.supply_area_distance or 0
      if d > dmax then dmax = d end
    end
  end
  table.sort(poles, function(a, b) return a[1] < b[1] end)
  h.poles, h.n, h.dmax, h.r0, h.cost = poles, #poles, dmax, slice, h.cost + 1
  h.plan, h.plan_ref = plan_poles(f) -- lot HYGIENE-ACTIVE ; lot HYGIENE-PLANS-FINIS : références des pièces
  Profiler.fstop("hyg:releve")
  return true
end

--- Le poteau relevé `p` = { unit_number, x, y }, s'il est encore là.
local function pole_at(surface, force, p)
  local found = surface.find_entities_filtered({ position = { p[2], p[3] }, radius = Hy.SEEK_R, type = "electric-pole", force = force })
  for i = 1, #found do
    if found[i].unit_number == p[1] then return found[i] end
  end
  return nil
end

--- (a) Une entité de type « resource » sur l'emprise en tuiles entières du poteau.
local function on_ore(surface, e)
  local bb = e.bounding_box
  local x0, y0, x1, y1 = St.tile_box(bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y)
  return surface.count_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = "resource" }) > 0
end

--- Entités ALIMENTÉES par le poteau `e` : source électrique au prototype, pas un poteau, même réseau, dans son carré d'alimentation.
local function fed_by(surface, e, force, d)
  local out = {}
  local net = e.electric_network_id
  if not net then return out end
  local px, py = e.position.x, e.position.y
  for _, c in ipairs(surface.find_entities_filtered({ area = { { px - d, py - d }, { px + d, py + d } }, force = force })) do
    if c.type ~= "electric-pole" and c.prototype.electric_energy_source_prototype and c.electric_network_id == net then out[#out + 1] = c end
  end
  return out
end

--- Un AUTRE poteau de la même force et du même réseau que `e` alimente-t-il aussi `c` (son carré touche la boîte de `c`) ?
--- Lot HYGIENE-PLANS-FINIS : `ext` = seul un poteau EXTÉRIEUR (hors gisement) compte comme couvrant ; `ctx.ore` mémoïse « sur gisement »
--- par unit_number le temps de la tranche (banc HYGPLANS-A2 : 0,020 ms/tick sans mémo, les mêmes poteaux couvrants relus à chaque consommateur).
local function pole_on_ore(surface, p, ctx)
  local memo = ctx and ctx.ore
  if not memo then return on_ore(surface, p) end
  local un = p.unit_number
  local v = memo[un]
  if v == nil then v = on_ore(surface, p) memo[un] = v end
  return v
end

local function other_pole_covers(surface, e, c, force, dmax, ext, ctx)
  local bb = c.bounding_box
  local x0, y0, x1, y1 = bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y
  local net, un = e.electric_network_id, e.unit_number
  local r = dmax + math.max(x1 - x0, y1 - y0)
  for _, p in ipairs(surface.find_entities_filtered({ position = c.position, radius = r, type = "electric-pole", force = force })) do
    if p.unit_number ~= un and p.electric_network_id == net
      and St.covers(p.position.x, p.position.y, p.prototype.supply_area_distance or 0, x0, y0, x1, y1)
      and not (ext and pole_on_ore(surface, p, ctx)) then return true end
  end
  return false
end

--- Consommateurs du poteau `e` qu'il alimente SEUL (aucun autre poteau du même réseau ne les couvre) : liste (au plus `limit`) et le
--- total des entités alimentées. Lot HYGIENE-ACTIVE : partagé par l'audit (limit 1 : il suffit d'en voir un) et par le plan de remplacement.
local function own_fed(surface, f, h, e, limit, ext, ctx)
  local d = e.prototype.supply_area_distance or 0
  local dmax = (h.dmax > d) and h.dmax or d
  local fed = fed_by(surface, e, f.force, d)
  local own = {}
  for _, c in ipairs(fed) do
    if not other_pole_covers(surface, e, c, f.force, dmax, ext, ctx) then
      own[#own + 1] = c
      if limit and #own >= limit then break end
    end
  end
  return own, #fed
end

--- Audit d'un poteau : compteurs (a) sur gisement, (b) redondant candidat (feuille sans consommateur propre). Rend le bilan lu à ce tick
--- { ore, wires, fed, own } (own = nombre de consommateurs propres vus, 0 ou 1 pour une feuille ; nil hors feuille).
local function audit(surface, f, h, e)
  local info = { ore = on_ore(surface, e), fed = 0, own = nil }
  if info.ore then h.sur = h.sur + 1 end
  local nb = e.neighbours
  info.wires = (nb and nb.copper and #nb.copper) or 0
  if info.wires > 1 then return info end
  local own, fed = own_fed(surface, f, h, e, 1)
  info.fed, info.own = fed, #own
  if #own == 0 then h.red = h.red + 1 end
  return info
end

---------------------------------------------------------------------------------------------------
-- Lot HYGIENE-ACTIVE : action après l'audit, dans la même tranche (les lectures datent de ce tick)
---------------------------------------------------------------------------------------------------
local function refus(h, cause) h.acts.refus[cause] = (h.acts.refus[cause] or 0) + 1 end

--- Nom de l'OBJET qui pose le poteau `e` (prototype : items_to_place_this), à défaut le nom de l'entité.
local function item_of(e)
  local items = e.prototype.items_to_place_this
  local it = items and items[1]
  return (type(it) == "table" and it.name) or it or e.name
end

--- Réseaux alimentés de l'équipe, lus une fois par tranche (ctx) au registre des génératrices.
local function live_nets(ctx, f, surface)
  if not ctx.live then ctx.live = Gens.networks(surface, f.force, Hy.GEN_TYPES) end
  return ctx.live
end

--- Gardes d'une action (lues une fois par tranche) : budget de l'impulsion, famine de la plaque clé, menace du QG. Cause ou nil.
local function garde(f, h, ctx, tick, sur_gisement)
  if not Hr.budget(h.retraits, Hr.CFG) then return "budget" end
  if ctx.famine == nil then ctx.famine = Famine.team_starved(f, tick) and true or false end
  if Hr.famine_bloque(ctx.famine, sur_gisement) then return "famine" end -- s42 gisements : jamais pour un poteau sur gisement
  if ctx.menace == nil then
    local hm = f.team.hq_menace
    ctx.menace = ((hm and hm.crise) or (f.threatened_until and tick < f.threatened_until)) and true or false
  end
  if ctx.menace then return "menace du QG" end
  return nil
end

--- Entrées structurelles de Hr.feuille_retirable pour le poteau `e` : plan directeur (h.plan), chaîne des foreuses en cours de pose
--- (f.swap.pass et tuile f.swap.pole_pos), poteau posé par un joueur (last_user). (La box MAXED est sautée avant l'audit.)
local function structure(f, h, e)
  local x, y = e.position.x, e.position.y
  local tag = h.plan[tile_key(x, y)]
  local sw = f.swap
  local chain = sw ~= nil and sw.pass ~= nil and sw.pole_pos ~= nil and sw.pole_pos[P.tkey(math.floor(x), math.floor(y))] == true
  return { projet_fini = tag ~= "chantier", piece_plan = tag == "fini", chaine_foreuses = chain or false, pose_par_joueur = e.last_user ~= nil }
end

--- (a) Retrait d'une feuille : l'objet est rendu au coffre D'ABORD (coffre plein : rien n'est détruit), puis le poteau est détruit.
--- Lot HYGIENE-PLANS-FINIS : `cession` = { q, pe } : la pièce du plan est cédée (Build.cede_piece, l'unique écrivain) entre le retour au
--- coffre et la destruction ; une cession refusée (pièce déjà cédée) laisse le poteau en place.
local function retire_feuille(f, h, e, cause, cession, tick)
  local item = item_of(e)
  if Stock.insert(f, item, 1) < 1 then refus(h, "coffre plein") return end
  local x, y = e.position.x, e.position.y
  if cession then
    local Build = package.loaded["script.team.build"]
    if not (Build and Build.cede_piece and Build.cede_piece(f, cession[1], cession[2], "hygiene: feuille sur gisement")) then
      Stock.remove(f, item, 1)
      refus(h, "piece deja cedee")
      return
    end
    h.acts.cedes[#h.acts.cedes + 1] = { x, y, cession[1].id }
    log(string.format("[FO-HYGIENE] %s : cede poteau du plan %s en (%.1f, %.1f) a %.1f min : feuille", key_of(f), tostring(cession[1].id), x, y, (tick or 0) / 3600))
  end
  e.destroy()
  h.retraits = h.retraits + 1
  h.acts.feuilles[#h.acts.feuilles + 1] = { x, y, cause }
end


--- Anneau des positions candidates (décalages entiers : même alignement de tuile que l'ancien) dans le carré de rayon `r` (portée de fil).
local function anneau(r)
  local out = {}
  for dy = -r, r do
    for dx = -r, r do
      if dx ~= 0 or dy ~= 0 then out[#out + 1] = { dx = dx, dy = dy } end
    end
  end
  return out
end

--- (b) Plan de remplacement du poteau `e` sur gisement : voisins et consommateurs propres lus à ce tick, candidats géométriques (règle
--- pure), puis sondes du moteur (tuile de ressource sous l'emprise, place libre, non réservée) sur les Hr.CFG.max_sondes plus proches.
--- Rend { x, y, voisins = { unit_number } } ou nil, cause.
local function plan_remplacement(surface, f, h, e)
  local pr = e.prototype
  local wire, d = pr.max_wire_distance or 0, pr.supply_area_distance or 0
  local px, py = e.position.x, e.position.y
  local voisins, uns = {}, {}
  for _, n in ipairs(e.neighbours and e.neighbours.copper or {}) do
    if n.valid then
      voisins[#voisins + 1] = { dx = n.position.x - px, dy = n.position.y - py }
      uns[#uns + 1] = n.unit_number
    end
  end
  local own = own_fed(surface, f, h, e, nil)
  local couverts = {}
  for _, c in ipairs(own) do
    local bb = c.bounding_box
    couverts[#couverts + 1] = { dx = c.position.x - px, dy = c.position.y - py, w = bb.right_bottom.x - bb.left_top.x, h = bb.right_bottom.y - bb.left_top.y }
  end
  local p = { sur_gisement = true, voisins = voisins, portee_fil = wire, portee_alim = d, couverts = couverts, candidats = anneau(math.floor(wire)) }
  if #voisins == 0 then return nil, "aucun voisin de fil" end
  local ordered = Hr.candidats_ordonnes(p)
  if #ordered == 0 then return nil, select(2, Hr.sur_gisement_plan(p)) end
  local bb = e.bounding_box
  local name = e.name
  local sondes = {}
  for i = 1, math.min(#ordered, Hr.CFG.max_sondes) do
    local c = ordered[i]
    local x, y = px + c.dx, py + c.dy
    local x0, y0, x1, y1 = St.tile_box(bb.left_top.x + c.dx, bb.left_top.y + c.dy, bb.right_bottom.x + c.dx, bb.right_bottom.y + c.dy)
    local hors = surface.count_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = "resource" }) == 0
    local libre = hors and surface.can_place_entity({ name = name, position = { x = x, y = y }, force = f.force }) and not PlacesQG.is_reserved(f, name, { x = x, y = y }, 0) -- (lot TUILES-RESERVEES : crochet unique)
    sondes[#sondes + 1] = { dx = c.dx, dy = c.dy, hors_gisement = hors, libre = libre or false }
    if hors and libre then break end -- le plus proche qui convient : la règle pure le retiendra (même ordre)
  end
  p.candidats = sondes
  local c, why = Hr.sur_gisement_plan(p)
  if not c then return nil, why end
  return { x = px + c.dx, y = py + c.dy, voisins = uns }
end

--- (b) Pose du remplaçant, payé au stock, relié à chaque ancien voisin ; la vérification et le retrait de l'ancien sont faits à la tranche
--- suivante (finish_pending). Une seule pose en attente par équipe.
local function pose_remplacant(surface, f, h, e, tick, ref)
  if f.team.hygiene_pending then refus(h, "remplacement en attente") return end
  local item = item_of(e)
  if Stock.count(f, item) < 1 then refus(h, "stock") return end
  if Rv.foe_near(f, surface, e.position.x, e.position.y) then refus(h, "ennemi") return end
  local plan, why = plan_remplacement(surface, f, h, e)
  if not plan then refus(h, why) return end
  if Stock.remove(f, item, 1) < 1 then refus(h, "stock") return end
  local new = surface.create_entity({ name = e.name, position = { x = plan.x, y = plan.y }, force = f.force, raise_built = true })
  if not (new and new.valid) then
    Stock.insert(f, item, 1)
    refus(h, "pose refusee")
    return
  end
  for _, n in ipairs(e.neighbours and e.neighbours.copper or {}) do
    if n.valid and n.unit_number ~= new.unit_number then new.connect_neighbour(n) end
  end
  h.retraits = h.retraits + 1
  f.team.hygiene_pending = { tick = tick, item = item, old = { e.unit_number, e.position.x, e.position.y },
    new = { new.unit_number, plan.x, plan.y }, voisins = plan.voisins, piece = ref } -- lot HYGIENE-PLANS-FINIS : { pid, i } ou nil
end

--- Le remplaçant `new` relie-t-il tous les anciens voisins (par unit_number ; un voisin disparu n'est plus exigé) ?
local function relie(surface, new, voisins)
  local have = {}
  for _, n in ipairs(new.neighbours and new.neighbours.copper or {}) do if n.valid then have[n.unit_number] = true end end
  local r = (new.prototype.max_wire_distance or 0) + 1
  for _, un in ipairs(voisins) do
    if not have[un] then
      -- le voisin existe-t-il encore ? (retrouvé à portée de fil du remplaçant, reconnu à son numéro)
      for _, p in ipairs(surface.find_entities_filtered({ position = new.position, radius = r, type = "electric-pole" })) do
        if p.unit_number == un then return false, "voisin non relie" end
      end
    end
  end
  return true
end

--- (b) Tranche suivante : vérification AU TICK puis retrait de l'ancien, ou destruction du remplaçant (rendu au coffre).
local function finish_pending(f, surface, h, tick)
  local pd = f.team.hygiene_pending
  if not pd or pd.tick >= tick then return end
  f.team.hygiene_pending = nil
  local new = pole_at(surface, f.force, pd.new)
  local old = pole_at(surface, f.force, pd.old)
  if not new then refus(h, "remplacant disparu") return end
  if not old then h.acts.remplaces[#h.acts.remplaces + 1] = { pd.old[2], pd.old[3], pd.new[2], pd.new[3] } return end
  local ok, why = relie(surface, new, pd.voisins)
  local live = live_nets({}, f, surface)
  local net = new.electric_network_id
  if ok and not (net and net == old.electric_network_id and live[net]) then ok, why = false, "remplacant non alimente" end
  if ok then
    local own = own_fed(surface, f, h, old, 1)
    if #own > 0 then ok, why = false, "couverture perdue" end
  end
  local q, pe
  if ok and pd.piece then -- lot HYGIENE-PLANS-FINIS : la pièce du plan doit être retrouvée à sa place, non cédée
    q, pe = piece_of(f, pd.piece)
    if not (pe and not pe.dropped and math.abs(pe.x - pd.old[2]) < 0.5 and math.abs(pe.y - pd.old[3]) < 0.5) then ok, why = false, "piece introuvable" end
  end
  if ok and Stock.insert(f, pd.item, 1) < 1 then ok, why = false, "coffre plein" end
  if ok and pd.piece then
    local Build = package.loaded["script.team.build"]
    if not (Build and Build.cede_piece and Build.cede_piece(f, q, pe, "hygiene: remplacant hors gisement", { x = pd.new[2], y = pd.new[3] })) then
      Stock.remove(f, pd.item, 1)
      ok, why = false, "piece deja cedee"
    end
  end
  if not ok then
    -- s40 : le remplaçant n'est détruit que si son objet rentre au coffre (« coffre plein » : le même Stock.insert échouait une seconde
    -- fois après la destruction, un poteau perdu à chaque essai) ; sinon il reste posé, relié, sans matière perdue
    if Stock.insert(f, pd.item, 1) >= 1 then new.destroy() end
    refus(h, why)
    return
  end
  old.destroy()
  h.acts.remplaces[#h.acts.remplaces + 1] = { pd.old[2], pd.old[3], pd.new[2], pd.new[3] }
  if pd.piece then
    h.acts.cedes[#h.acts.cedes + 1] = { pd.old[2], pd.old[3], q.id, pd.new[2], pd.new[3] }
    log(string.format("[FO-HYGIENE] %s : cede poteau du plan %s en (%.1f, %.1f) a %.1f min : remplacant -> (%.1f, %.1f)", key_of(f),
      tostring(q.id), pd.old[2], pd.old[3], tick / 3600, pd.new[2], pd.new[3]))
  end
end

local REMPLACABLE = { ["pas une feuille"] = true, ["consommateur propre"] = true, ["couvrant non alimente"] = true } -- causes propres aux feuilles

--- Action sur le poteau `e` audité à ce tick (bilan `info`) : feuille sans consommateur propre -> retrait ; sur gisement -> remplacement.
local function act(surface, f, h, e, info, ctx, tick, slice)
  local feuille = info.own == 0
  if not (feuille or info.ore) then return end
  local why = garde(f, h, ctx, tick, info.ore and true or false)
  if why then refus(h, why) return end
  local st = structure(f, h, e)
  if st.piece_plan then
    -- lot HYGIENE-PLANS-FINIS : pièce d'un plan fini ; sur gisement seulement, couverture par un poteau EXTÉRIEUR, cession au plan
    if not info.ore then refus(h, "piece du plan") return end
    local ref = h.plan_ref and h.plan_ref[tile_key(e.position.x, e.position.y)]
    local q, pe = piece_of(f, ref)
    st.sur_gisement, st.deja_cedee, st.fils = true, (pe == nil) or pe.dropped == true, info.wires
    if info.wires <= 1 then
      local own_ext, fed = own_fed(surface, f, h, e, 1, true, ctx)
      st.consommateurs, st.consommateurs_propres = fed, #own_ext
      st.couvrant_alimente = fed == 0 or live_nets(ctx, f, surface)[e.electric_network_id or -1] == true
    end
    local ok, mode = Hr.plan_cedable(st)
    if not ok then refus(h, mode) return end
    if mode == "feuille" then retire_feuille(f, h, e, "plan fini sur gisement", { q, pe }, tick) return end
    if slice >= Hy.CFG.slices - 1 then refus(h, "derniere tranche") return end
    pose_remplacant(surface, f, h, e, tick, ref)
    return
  end
  if feuille then
    st.fils, st.consommateurs, st.consommateurs_propres = info.wires, info.fed, 0
    st.couvrant_alimente = info.fed == 0 or live_nets(ctx, f, surface)[e.electric_network_id or -1] == true
    local ok, cause = Hr.feuille_retirable(st)
    if ok then retire_feuille(f, h, e, cause) else refus(h, cause) end
    return
  end
  -- sur gisement, et il sert (voisins de fil ou consommateur propre) : un remplaçant hors gisement ou rien
  if slice >= Hy.CFG.slices - 1 then refus(h, "derniere tranche") return end
  local ok, cause = Hr.feuille_retirable(st) -- les mêmes exclusions structurelles (plan, chaîne, joueur) valent pour un remplacement
  if not ok and not REMPLACABLE[cause] then refus(h, cause) return end
  pose_remplacant(surface, f, h, e, tick)
end

--- 2. Une tranche d'audit : la part de la liste relevée (tranches restantes après le relevé), plafonnée à max_per_slice.
local function slice_step(f, surface, h, slice, tick)
  local eff = Hy.CFG.slices - h.r0 - 1
  local s = slice - h.r0 - 1
  if eff <= 0 or s < 0 or s >= eff or h.n == 0 then return end
  local a, b, skipped = St.share_capped(h.n, s, eff, Hy.CFG.max_per_slice)
  if b < a then return end
  Profiler.fstart("hyg:tranche")
  local ctx = { ore = {} } -- lot HYGIENE-ACTIVE : lectures partagées de la tranche (réseaux alimentés, famine, menace), jamais gardées ; HYGIENE-PLANS-FINIS : mémo « sur gisement »
  for i = a, b do
    local boxed = Boxes.skip_at(f, h.poles[i][2], h.poles[i][3]) -- lot BOXES : poteau d'une box MAXED : ni retrouvé ni audité, compté
    local e = (not boxed) and pole_at(surface, f.force, h.poles[i]) or nil
    if e then
      local info = audit(surface, f, h, e)
      h.audited = h.audited + 1
      act(surface, f, h, e, info, ctx, tick, slice) -- lot HYGIENE-ACTIVE : action au tick même de l'audit
    elseif boxed then
      h.boxed = (h.boxed or 0) + 1 -- lot BOXES
    else
      h.gone = h.gone + 1
    end
  end
  h.skipped, h.cost = h.skipped + skipped, h.cost + 1
  Profiler.fstop("hyg:tranche")
end

--- Lot HYGIENE-ACTIVE : « ; retire poteau feuille (x, y) ; remplace poteau sur gisement (x, y) -> (x2, y2) ; refus : <cause> N »
--- (causes triées : aucun ordre de `pairs`).
local function actions_text(h)
  local a, out = h.acts, ""
  if a == nil then return out end
  if #a.feuilles > 0 then
    local l = {}
    for _, q in ipairs(a.feuilles) do l[#l + 1] = string.format("(%.1f, %.1f)", q[1], q[2]) end
    out = out .. " ; retire poteau feuille " .. table.concat(l, ", ")
  end
  if #a.remplaces > 0 then
    local l = {}
    for _, q in ipairs(a.remplaces) do l[#l + 1] = string.format("(%.1f, %.1f) -> (%.1f, %.1f)", q[1], q[2], q[3], q[4]) end
    out = out .. " ; remplace poteau sur gisement " .. table.concat(l, ", ")
  end
  if a.cedes and #a.cedes > 0 then -- lot HYGIENE-PLANS-FINIS
    local l = {}
    for _, q in ipairs(a.cedes) do l[#l + 1] = string.format("%s (%.1f, %.1f)", tostring(q[3]), q[1], q[2]) end
    out = out .. " ; cede poteau du plan " .. table.concat(l, ", ")
  end
  local causes = {}
  for k in pairs(a.refus) do causes[#causes + 1] = k end
  if #causes > 0 then
    table.sort(causes)
    local l = {}
    for _, k in ipairs(causes) do l[#l + 1] = k .. " " .. a.refus[k] end
    out = out .. " ; refus : " .. table.concat(l, ", ")
  end
  return out
end

--- 3. Journal de l'impulsion (une ligne) ; la liste relevée est rendue (rien à garder jusqu'à l'impulsion suivante).
local function report(f, h, why)
  local extra = ""
  if h.r0 == nil then extra = " ; jeton des travaux lourds refuse sur toute la fenetre : rien releve" end
  if h.skipped > 0 then extra = extra .. string.format(" ; %d non audites (plafond %d par tranche)", h.skipped, Hy.CFG.max_per_slice) end
  if h.gone > 0 then extra = extra .. string.format(" ; %d disparus pendant la passe", h.gone) end
  if h.why and h.why ~= "periode" then extra = extra .. " ; reveil (" .. h.why .. ")" end -- lot SCAN-EVENEMENTS : la cause de la passe
  if (h.boxed or 0) > 0 then extra = extra .. string.format(" ; %d ignores (box MAXED)", h.boxed) end -- lot BOXES
  if (h.zone or 0) > 0 then extra = extra .. string.format(" ; zone : %d rectangle(s)", h.zone) end -- lot UPS-HYGIENE
  extra = extra .. actions_text(h) -- lot HYGIENE-ACTIVE
  if why then extra = extra .. " ; " .. why end
  log(string.format("[FO-HYGIENE] %s : impulsion a %.1f min : %d poteaux releves, %d sur gisement, %d redondants candidats (feuilles sans consommateur propre) ; cout : %d tranches%s",
    key_of(f), h.t0 / 3600, h.n, h.sur, h.red, h.cost, extra))
  h.logged, h.poles = true, {}
end

--- Tranche `slice` de l'équipe `f` au tick `tick` (St.window ou la voie de réveil a dit actif). Le début de la passe est le tick de sa
--- tranche 0 ; sa cause est celle servie par St.ack sur f.team.scan pour ce début (« periode » sinon).
function Hy.step(f, surface, tick, slice)
  local t = f.team
  local t0 = tick - slice
  local h = t.hygiene
  if not h or h.t0 ~= t0 then
    if h and not h.logged then report(f, h, "passe interrompue") end
    local sc = t.scan
    h = new_pass(t0, sc and sc.served == t0 and sc.why or nil)
    t.hygiene = h
  end
  if not h.acts then h.acts, h.plan, h.retraits = { feuilles = {}, remplaces = {}, refus = {} }, h.plan or {}, h.retraits or 0 end -- passe d'une sauvegarde d'avant le lot
  if not h.acts.cedes then h.acts.cedes, h.plan_ref = {}, h.plan_ref or {} end -- lot HYGIENE-PLANS-FINIS : passe d'une sauvegarde d'avant le lot
  finish_pending(f, surface, h, tick) -- lot HYGIENE-ACTIVE : remplaçant posé à la tranche d'avant : vérification au tick, puis retrait
  if h.logged then return end
  if slice == 0 then Boxes.releve(f, surface, tick) end -- lot BOXES : relevé des boxes au début de l'impulsion (une ligne [FO-BOX])
  Balises.step(f, surface, tick, slice) -- lot BALISES-TEINTE : relevé à la tranche 0, parts St.share ensuite, journal [FO-BALISES]
  local last = (slice == Hy.CFG.slices - 1)
  if h.r0 == nil then
    if not releve(f, surface, h, tick, slice) then
      if last then
        Lourd.drop(who(f))
        report(f, h)
      end
      return
    end
  else
    slice_step(f, surface, h, slice, tick)
  end
  if last then report(f, h) end
end

--- Départ ou suite d'une passe au tick `tick` (tranche `slice`, début t0) pour l'équipe `f` de rang `rank` : rend vrai si la tranche se
--- joue. Créneau périodique (`periodic`) : la passe se joue toujours et la première tranche vue la marque servie (St.ack : un réveil en
--- attente est servi par elle). Créneau de la voie : départ à la tranche 0 seulement, sur St.due ; les tranches suivantes ne se jouent
--- que si c'est bien cette passe qui a commencé (sc.served == t0) : pas de double passe, pas de demi-fenêtre.
local function admit(f, rank, tick, slice, periodic)
  local t0 = tick - slice
  local sc = Sr.state(f)
  if sc.served == t0 then return true end
  if not periodic and slice ~= 0 then return false end
  local due, why = St.due(sc, t0, Hy.CFG, rank)
  if not due then return false end
  St.ack(sc, t0, why)
  if why ~= "periode" then
    log(string.format("[FO-SCAN] %s : reveil (%s) a %.1f min", key_of(f), why, t0 / 3600))
  end
  return true
end

Events.on(defines.events.on_tick, function(e)
  local tick = e.tick
  local k, slice = St.rank_at(tick, Hy.CFG) -- créneau k de la période (k < n : fenêtre périodique du rang k ; sinon voie du rang k mod n)
  if not k then return end
  local ids = Hy.ids()
  local n = #ids
  if n == 0 then return end
  local rank = k % n
  if rank >= Hy.MAX_RANKS then return end
  local f = State.faction(ids[rank + 1])
  if not (f and f.team and f.hq and f.hq.valid) then return end
  if not admit(f, rank, tick, slice, k < n) then return end
  Profiler.start("hygiene")
  Hy.step(f, f.hq.surface, tick, slice)
  Profiler.stop("hygiene")
end)

return Hy
