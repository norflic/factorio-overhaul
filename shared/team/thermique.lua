--[[
  THERMIQUE (lot THERMIQUE, retour du DC du 2/11 en jouant la 0.6.38) : « forcer à enlever les foreuses thermiques au bout d'un certain niveau
  de production : on REMPLACE les thermiques par l'électrique. On voit bien par contre les rangées de foreuses sur un ou 2 gisements (pas tous) ».
  PUR : aucune API Factorio, aucun nom d'objet (un minerai est une étiquette opaque `res`, les cadences et les coûts arrivent en DONNÉES),
  testé hors jeu par tests/thermique_test.lua.

  Ce que les parties montrent (fo-logs/2026-11-02_THERMIQUE/RAPPORT.md, 150 min, main 0.6.37 avec le champ) : le champ pose ses bandes sur un
  ou deux gisements à la fois ; des paires thermiques RESTENT (a) sur des gisements déjà couverts par une bande qui produit (les paires hors
  des bandes : bords, tuiles occupées, groupes sans place), (b) sur les gisements pas encore servis (une bande à la fois par minerai, derrière
  les autres), (c) pour le charbon et la pierre, que le champ ne migrait jamais (réceptacle = coffre).

  Trois décisions, toutes sur des NOMBRES lus par l'exécutant (script/team/migration_champ.lua) :
    1. COUVERT (M.covered) : le gisement a une bande électrique qui PRODUIT (au moins `min_working` foreuses en marche) dont l'extraction
       atteint `cover_ratio` fois celle de ses paires thermiques restantes. Seuil de production : il se lit des données (cadence d'une
       foreuse, nombre de foreuses en marche), jamais d'un nombre fixe de paires.
    2. BALAYAGE (M.sweep) : un gisement couvert perd ses paires thermiques restantes (rendues au stock), sauf si la PROTECTION refuse.
    3. ORDRE (M.order) et FINANCEMENT (M.financed) : les gisements non couverts sont servis du plus productif au moins productif ; une bande
       est « financée » quand le courant tient et que le stock de fer couvre les foreuses qui remplacent les paires. Au plus
       `per_mineral` chantier par minerai à la fois, `slots` au total (M.free_slot).

  PROTECTION (M.cut_ok) : on ne coupe jamais la dernière source d'un minerai. Après la coupe, l'approvisionnement restant du minerai
  (électrique en marche + thermique gardé, tous gisements de la force) doit tenir le PLANCHER du minerai (`ctx.floor[res]`, ore/s : le
  charbon de la centrale, par exemple, que le script lit aux chaudières) ; sous le plancher, un minerai ordinaire peut être pontée par le
  stock (`ctx.stock[res]` >= manque × `horizon`), un minerai CRITIQUE (`ctx.critical[res]`) jamais : sa coupe attend que l'électrique produise.
  Un minerai dont la coupe supprimerait toute source (reste nul) est traité comme sous le plancher.

  M.covered(fl, cfg)                    -> vrai/faux, raison
  M.supply(fl)                          -> thermique ore/s, électrique ore/s
  M.cut_ok(fl, fields, lost, ctx, cfg)  -> vrai/faux, raison  (protection)
  M.sweep(fields, ctx, cfg)             -> actions { id, res, pairs } et refus { id, why }
  M.verdict(ok, critical, age, cfg)     -> "retirer" | "attendre" | "annuler"  (au moment du retrait d'une bande)
  M.financed(fl, ctx, cfg)              -> vrai/faux, raison  (courant + fer)
  M.order(cands)                        -> liste triée (voulus, puis les plus productifs)
  M.free_slot(res, busy, cfg)           -> vrai/faux, raison ; M.band_stuck(état, raison, âge, cfg) -> vrai/faux (bande bloquée par ses matières)
  M.shares(fields, order)               -> part électrique par minerai (journal et critères)
  Lot THERMIQUE5 : M.band_covers(état du projet), M.covering(état), M.pile_permits(action, retenue, porte), M.order_end(...), M.noop_counts(ids), M.stop_state(...); fl.fueled (paires avec combustible, facultatif) remplace fl.pairs dans M.supply.
  fl = { id, res, tier (0 : plaques, 1 : sans plaque), pairs (paires thermiques debout), th_rate (ore/s d'une foreuse thermique), working (foreuses électriques en marche),
         el_rate (ore/s d'une foreuse électrique), busy (une bande de ce gisement est en chantier), wanted, have }
  ctx = { power, iron (fer libre au stock), drill_cost (fer d'une foreuse électrique), floor = { [res] }, stock = { [res] }, critical = { [res] } }
  Déterminisme : listes triées, égalités départagées par le numéro, aucun `pairs` décisionnel, aucun temps mesuré.
]]

local M = {}

-- Réglages propres au lot (ni dans shared/team/config.lua, ni de nom d'objet).
M.CFG = {
  cover_ratio = 1.0,      -- extraction électrique en marche / extraction thermique restante à partir de laquelle le gisement est couvert
  min_working = 2,        -- foreuses électriques en marche au moins pour qu'une bande compte comme productive
  horizon = 10 * 60,      -- s : durée de coupure d'une bande que le stock d'un minerai ordinaire doit pouvoir ponter
  protect_wait = 10 * 3600, -- ticks : attente au plus d'un pont de stock avant une coupe d'un minerai ordinaire (jamais un blocage définitif)
  critical_wait = 20 * 3600, -- ticks : attente d'une coupe d'un minerai critique avant d'annuler la demande (la bande est redemandée plus tard)
  fund_ratio = 1.0,       -- fer libre / coût des foreuses de remplacement à partir duquel une bande est financée
  per_mineral = 1,        -- chantiers de bande simultanés au plus par minerai
  key_per_mineral = 2,    -- plaque CLÉ (le fer) : chantiers de bande simultanés au plus quand TOUS ceux du minerai attendent leurs matières (9/11, directive du lead :
                          -- partie 314159265 / geants, une bande de fer bloquée par ses matières gardait le créneau « un par minerai » pendant des dizaines de minutes)
  stuck_wait = 5 * 3600,  -- ticks : une bande en réserve (matières) depuis plus que cela est « bloquée » : elle ne retient plus le créneau de la plaque clé seule
  slots = 3,              -- chantiers de bande simultanés au plus, tous minerais = les 3 créneaux réels (SLOTS, migration_champ) ; lot REINVEST (DC 11/11) : à 2, le combustible et une bande tenaient tout, la 2e et la 3e colonne attendaient
  sweep_max = 1,          -- gisements balayés au plus par pensée (le retrait est immédiat : un gisement à la fois suffit)
  every = 600,            -- ticks entre deux balayages (une pensée d'équipe de la migration)
  raw_stock_max = 3000,   -- lot THERMIQUE2 (essai 3, décision du lead) : stock libre d'un minerai BRUT au-delà duquel plus aucun brûleur n'est posé
  cover_by_output = true, -- lot THERMIQUE6 (essai 3) : couverture lue à la production de la bande (bloquée qui a produit, sortie pleine si elle produit)
  dry_wait = 10 * 3600,   -- lot THERMIQUE6, règle B : ticks à sec avant qu'un brûleur d'un gisement à bande finie soit retiré seul
}

local EPS = 1e-9

local function cfg_of(cfg) return cfg or M.CFG end

--- Lot THERMIQUE2 (essai 3) : un minerai porté BRUT au coffre (produit = ressource : charbon, pierre ; pas de four dans la paire) dont le
--- stock libre atteint cfg.raw_stock_max ne reçoit plus de brûleur (couverture et relève du cerveau, agrandissement et avant-poste du travail
--- de fond). spec = { resource, product } (T.outposts[type]) ; stock = { [objet] = nombre }. Le fer et le cuivre (paire avec four) ne sont
--- jamais « pleins » ici : leurs paires sont remplacées par les bandes du champ et balayées.
function M.raw_full(spec, stock, cfg)
  cfg = cfg_of(cfg)
  if spec == nil or spec.product ~= spec.resource then return false end
  return ((stock or {})[spec.product] or 0) >= cfg.raw_stock_max
end

--- Extraction (ore/s) des paires thermiques qui PRODUISENT et des foreuses électriques en marche du gisement. Lot THERMIQUE5 (revue du 3/11 :
--- Émeraude, 24 brûleurs à sec contre 12 électriques, jamais balayés) : `fl.fueled` (paires avec du combustible), quand l'exécutant le donne,
--- remplace `fl.pairs` : une paire à sec n'extrait rien. `fl.pairs` reste le nombre de paires à retirer.
function M.supply(fl)
  local th = fl.fueled
  if th == nil then th = fl.pairs end
  return (th or 0) * (fl.th_rate or 0), (fl.working or 0) * (fl.el_rate or 0)
end

--- Lot THERMIQUE5 : états moteur d'une foreuse électrique qui COUVRE son gisement. Une foreuse qui mine (« working ») ou dont la sortie est
--- pleine (« waiting_for_space_in_destination » : le minerai est déjà en trop) couvre ; à l'arrêt faute de courant, de minerai ou bouchée par
--- autre chose, non (revue du 3/11 : une bande à sortie pleine comptait 0, refus « bande-qui-ne-produit-pas » à 150 min). Noms des états
--- de defines.entity_status (des clés de l'API, pas des noms d'objet).
M.COVERING_STATUS = { "working", "waiting_for_space_in_destination" }
function M.covering(status_name)
  for _, s in ipairs(M.COVERING_STATUS) do if s == status_name then return true end end
  return false
end

--- Lot THERMIQUE5, PRIORITÉ 0 (revue-fonderie du 3/11, mesuré : INTEG-0643N, graine 271828182, Scarlet projet 6 : les 3 dernières paires
--- balayées « 14 foreuses en marche » alors que la bande était EN CHANTIER, puis 20 fours sur 23 sans combustible et 14 foreuses figées à
--- 57 min) : l'amorce d'une bande suffit à faire tourner ses premières foreuses. Les foreuses d'une bande ne comptent pour « couvert » que si
--- son projet est FINI au plan directeur (`state` : état du projet, p.state). Rend vrai/faux.
--- Lot THERMIQUE7 (essai 4, GO du lead 3/11 18 h) : les bandes n'atteignent pas l'état « fini » au plan, ou ne le gardent pas (e3-lot
--- 271828182 : joueur, 5 bandes en chantier et 0 finie à 149 min, alors que ses électriques tournent). Une bande est jugée à sa PRODUCTION,
--- quel que soit son état : elle couvre si ses fours ont produit (`made_ok` : made_by >= produce_min) ET si elle produit EN CE MOMENT (`live` :
--- un four en marche ; bande à coffres : 2 foreuses en marche). Une bande qui n'a jamais produit ne couvre rien (P0 : pas de retrait avant que
--- la bande remplaçante fonde). Éteint (cfg.cover_by_output faux) : la règle de P0, bande « fini » seulement. Rend vrai/faux.
function M.band_covers(state, made_ok, live, cfg)
  cfg = cfg_of(cfg)
  if cfg.cover_by_output ~= true then return state == "fini" end
  return made_ok == true and live == true
end

--- Lot THERMIQUE6, règle B (GO du lead, 3/11 ; plainte du DC : « 35 foreuses thermiques qui ne sont plus alimentées ») : un brûleur À SEC
--- depuis `since` (tick de la première vue à sec, nil s'il a du combustible) est-il retiré seul, sans exiger que le gisement soit couvert ?
--- Oui si la date est connue, si `now - since >= cfg.dry_wait`, si une bande du même gisement est FINIE (`band_done`) et si la protection ne
--- refuse pas (`protect_ok` : faux pour le charbon de la centrale sous son plancher ou sans autre source, M.cut_ok sans perte). Rend vrai/faux.
function M.dry_retire(since, now, band_done, protect_ok, cfg)
  cfg = cfg_of(cfg)
  if since == nil or band_done ~= true or protect_ok == false then return false end
  return now - since >= cfg.dry_wait
end

--- Lot THERMIQUE6 (essai 3) : une foreuse électrique d'une bande qui couvre compte-t-elle ? `status_name` : état moteur (Th.COVERING_STATUS) ;
--- `live` : la bande produit EN CE MOMENT (au moins un four en marche ; bande à coffres : au moins 2 foreuses en marche). En marche : oui. Sortie
--- pleine : seulement si la bande produit (sinon la sortie est pleine parce que la fonderie est à l'arrêt : Émeraude, 45 fours sur 45 sans
--- combustible à 151 min, p0-lot). Éteint (cfg.cover_by_output faux) : la règle de THERMIQUE5 (Th.covering). Rend vrai/faux.
function M.drill_counts(status_name, live, cfg)
  cfg = cfg_of(cfg)
  if not M.covering(status_name) then return false end
  if cfg.cover_by_output ~= true or status_name == "working" then return true end
  return live == true
end

--- Lot THERMIQUE5 (revue du 3/11, cause 1 : la retenue de la pile gelait TOUTE la migration du champ, balayage et dégel compris ; Azure et
--- Scarlet retenues 99 à 100 % du temps, graine 271828182, 139 thermiques et 0 électrique) : que peut faire la migration pendant une retenue ?
---   "suivre"  : étapes d'une bande DÉJÀ demandée (dégel, retrait de ses paires, chantier, ligne comptée) ;
---   "balayer" : paires d'un gisement couvert retirées ;
---   "partir"  : bande NEUVE demandée au plan.
--- Suivre et balayer RENDENT des objets au stock : jamais retenus. Une bande neuve prend des matières : retenue, sauf si la porte de la pile
--- laisse passer sa plaque (`porte` vrai : plaque d'un cadre ouvert ou qui manque, comme la réserve de la bande au plan directeur). Rend vrai/faux.
function M.pile_permits(action, hold, porte)
  if not hold then return true end
  if action == "suivre" or action == "balayer" then return true end
  return porte == true
end

--- Lot THERMIQUE5 (revue du 3/11, cause 2) : fin de l'ordre des bandes d'un champ. `left` : paires thermiques encore debout sur le gisement ;
--- `done`, `produced` : bandes migrées, bandes qui ont produit. Rend l'état :
---   "replanifier" : rien de migré et des paires restent : le cadre (vide, ou bandes toutes refusées) est refait après CFG.revive (le gisement
---                   a pu se libérer), l'avant-poste reste FERMÉ aux brûleurs (avant : « abandon », qui le rendait extensible) ;
---   "partiel"     : des paires restent hors des bandes posées : le champ n'est PAS déclaré « fini » (le balayage les retire quand il est
---                   couvert ; un ordre de la capitalisation peut le rouvrir, Mig.want). Un cadre qui porte des bandes n'est jamais refait
---                   (ses bandes voisines partagent leurs rangées : script/team/migration_champ.lua, begin_band) ;
---   "fini"        : plus aucune paire ;  "abandon" : rien n'a été migré ni produit, et plus aucune paire.
function M.order_end(left, done, produced)
  local migrated = (done or 0) > 0 or (produced or 0) > 0
  if (left or 0) > 0 then return migrated and "partiel" or "replanifier" end
  return migrated and "fini" or "abandon"
end

--- Lot THERMIQUE5 (revue du 3/11, cause 2) : une ligne posée « sans libérer la place voulue » ne compte comme telle que si sa bande portait
--- des paires (`ids` : paires sous la bande). Une bande SANS paire (agrandissement, état déjà avancé) n'avait rien à libérer : la compter
--- arrêtait le champ en « partiel » après deux (Émeraude AP4, graine 20261020). Rend vrai si la ligne compte comme sans effet.
function M.noop_counts(ids)
  return #(ids or {}) > 0
end

--- Lot THERMIQUE5 (revue du 3/11, cause 2) : état d'une migration arrêtée parce que sa ligne n'aboutit pas. Des paires DÉJÀ retirées
--- (`retired` > 0) ne reviennent pas : « partiel » (l'avant-poste reste fermé aux brûleurs) ; « abandon » rend l'avant-poste extensible, ce
--- qui reposait des brûleurs (Azure 20261020 : 6 paires de cuivre retirées, chantier de 90 min, puis 3 -> 6 brûleurs). Rend la chaîne.
function M.stop_state(done, produced, retired)
  if (done or 0) > 0 or (produced or 0) > 0 or (retired or 0) > 0 then return "partiel" end
  return "abandon"
end

--- Le gisement est-il couvert par une bande électrique qui produit ? Rend (vrai/faux, raison).
function M.covered(fl, cfg)
  cfg = cfg_of(cfg)
  if (fl.working or 0) < cfg.min_working then return false, "bande-qui-ne-produit-pas" end
  local th, el = M.supply(fl)
  if el + EPS < cfg.cover_ratio * th then return false, "extraction-electrique-insuffisante" end
  return true, "couvert"
end

local function sum_supply(fields, res)
  local total = 0
  for _, g in ipairs(fields) do
    if g.res == res then
      local th, el = M.supply(g)
      total = total + th + el
    end
  end
  return total
end

--- Protection : couper `lost` ore/s de thermique du gisement `fl` laisse-t-il assez du minerai ? `fields` : tous les gisements de la force.
--- Rend (vrai/faux, raison).
function M.cut_ok(fl, fields, lost, ctx, cfg)
  cfg = cfg_of(cfg)
  local res = fl.res
  local rest = sum_supply(fields, res) - lost
  if rest < 0 then rest = 0 end
  local floor = ((ctx.floor or {})[res]) or 0
  local sole = rest <= EPS
  if rest + EPS >= floor and not sole then return true, "plancher-tenu" end
  if (ctx.critical or {})[res] then return false, "source-critique" end
  local need = math.max(floor, sole and lost or 0) - rest
  local stock = ((ctx.stock or {})[res]) or 0
  if stock + EPS >= need * cfg.horizon then return true, "stock-ponte" end
  return false, sole and "derniere-source" or "plancher"
end

--- Gisements à balayer : couverts, avec des paires thermiques, hors chantier, dont la coupe passe la protection. Rend (actions, refus) :
--- actions = { { id, res, pairs } } (au plus cfg.sweep_max, les plus productifs d'abord), refus = { { id, why } } dans l'ordre des numéros.
function M.sweep(fields, ctx, cfg)
  cfg = cfg_of(cfg)
  local cands, refused = {}, {}
  local sorted = {}
  for _, g in ipairs(fields) do sorted[#sorted + 1] = g end
  table.sort(sorted, function(a, b) return a.id < b.id end)
  for _, g in ipairs(sorted) do
    if (g.pairs or 0) > 0 then
      local ok, why = M.covered(g, cfg)
      if g.busy then
        ok, why = false, "chantier-en-cours"
      end
      if ok then
        local th = M.supply(g)
        ok, why = M.cut_ok(g, fields, th, ctx, cfg)
        if ok then cands[#cands + 1] = g end
      end
      if not ok then refused[#refused + 1] = { id = g.id, why = why } end
    end
  end
  table.sort(cands, function(a, b)
    local ta, tb = M.supply(a), M.supply(b)
    if ta ~= tb then return ta > tb end
    return a.id < b.id
  end)
  local out = {}
  for i = 1, math.min(#cands, cfg.sweep_max) do
    out[#out + 1] = { id = cands[i].id, res = cands[i].res, pairs = cands[i].pairs }
  end
  for i = cfg.sweep_max + 1, #cands do refused[#refused + 1] = { id = cands[i].id, why = "file" } end
  return out, refused
end

--- Verdict au moment de retirer les paires d'une bande : ok/why de M.cut_ok, `critical` (le minerai l'est), `age` (ticks d'attente de la
--- coupe). Rend "retirer", "attendre" ou "annuler". Un minerai ordinaire attend `protect_wait` au plus (la protection ne bloque jamais pour
--- toujours : sans cela un cuivre dont la seule source est une bande ne migrerait jamais) ; un minerai critique n'est jamais coupé sous son
--- plancher : après `critical_wait`, la demande est annulée.
function M.verdict(ok, critical, age, cfg)
  cfg = cfg_of(cfg)
  if ok then return "retirer" end
  if critical then
    if age > cfg.critical_wait then return "annuler" end
    return "attendre"
  end
  if age > cfg.protect_wait then return "retirer" end
  return "attendre"
end

--- Une bande qui remplace les paires du gisement est-elle financée ? Courant qui tient ET fer libre >= fund_ratio × coût des foreuses
--- électriques qui rendent l'extraction des paires. Rend (vrai/faux, raison).
function M.financed(fl, ctx, cfg)
  cfg = cfg_of(cfg)
  if not ctx.power then return false, "courant" end
  local th = M.supply(fl)
  local need = 0
  if (fl.el_rate or 0) > 0 and th > 0 then need = math.ceil(th / fl.el_rate - EPS) end
  local cost = need * (ctx.drill_cost or 0)
  if (ctx.iron or 0) + EPS < cfg.fund_ratio * cost then return false, "fer" end
  return true, "finance"
end

--- Ordre de service des gisements à migrer : voulus par la capitalisation d'abord, puis le plus d'extraction thermique en jeu, puis le
--- stock libre de leur produit le plus bas (le cuivre en manque), puis le numéro. Rend une NOUVELLE liste.
function M.order(cands)
  local out = {}
  for _, g in ipairs(cands) do out[#out + 1] = g end
  table.sort(out, function(a, b)
    local wa, wb = a.wanted and 1 or 0, b.wanted and 1 or 0
    if wa ~= wb then return wa > wb end
    -- les minerais qui fournissent les matières des bandes (rang 0 : plaques) avant ceux qui n'en fournissent pas (rang 1 : charbon, pierre) :
    -- une bande de charbon avant celle du fer vide le fer qui lui manque (mesuré : 20 bandes demandées, 9 produisent, contre 14 et 13 au témoin)
    local ra, rb = a.tier or 0, b.tier or 0
    if ra ~= rb then return ra < rb end
    local ta, tb = M.supply(a), M.supply(b)
    if ta ~= tb then return ta > tb end
    local ha, hb = a.have or 0, b.have or 0
    if ha ~= hb then return ha < hb end
    -- lot GEANT-D-ABORD : à égalité, le gisement le plus GRAND d'abord (tuiles réelles ; un gisement de taille inconnue compte 0) : le champ du géant
    -- avant celui d'un petit cercle plus ancien (le numéro seul donnait le premier avant-poste, près du QG, petit)
    local sa, sb = a.tiles or 0, b.tiles or 0
    if sa ~= sb then return sa > sb end
    return a.id < b.id
  end)
  return out
end

--- Une bande est-elle « bloquée par ses matières » ? Réserve (pas encore au chantier), autre raison que la porte « degel » (qui attend le retrait des paires,
--- matières déjà réunies), depuis plus de cfg.stuck_wait ticks. `state` : état du projet du plan, `reason` : sa raison, `age` : ticks depuis la demande.
function M.band_stuck(state, reason, age, cfg)
  cfg = cfg_of(cfg)
  return state == "reserve" and reason ~= "degel" and (age or 0) > cfg.stuck_wait
end

--- Reste-t-il un créneau pour un chantier de ce minerai ? busy = { total, [res] = n, key = minerai de la plaque clé, stuck = { [res] = chantiers bloqués
--- par leurs matières } } (chantiers de bande en cours). Rend (vrai/faux, raison). La plaque clé a un 2e chantier quand tous les siens sont bloqués.
--- Lot IA-SPAWN (B2, partie du DC 0.6.96) : la plaque clé SANS chantier à elle a sa voie même quand les autres minerais tiennent tous les créneaux
--- (raison « voie-cle ») : de 30 à 114 min, le charbon et le cuivre tenaient les 2 créneaux, le champ du fer du spawn (couvert à 177 pour mille,
--- fer en manque) restait en veille, « plein » pour le reste du cerveau (o.migr), et l'équipe bâtissait le fer ailleurs.
function M.free_slot(res, busy, cfg)
  cfg = cfg_of(cfg)
  if (busy.total or 0) >= cfg.slots then
    if busy.key ~= nil and busy.key == res and (busy[res] or 0) == 0 then return true, "voie-cle" end
    return false, "creneaux"
  end
  if (busy[res] or 0) >= cfg.per_mineral then
    if busy.key ~= nil and busy.key == res and (busy[res] or 0) < cfg.key_per_mineral and ((busy.stuck and busy.stuck[res]) or 0) >= (busy[res] or 0) then
      return true, "libre-cle"
    end
    return false, "minerai-occupe"
  end
  return true, "libre"
end

--- Part électrique par minerai : liste triée de { res, el, th, share (0 à 1 de l'extraction, nil sans foreuse), pairs, working, covered_with_pairs }.
--- `order` : les minerais dans l'ordre voulu (liste). covered_with_pairs : gisements couverts qui gardent des paires thermiques (critère T2).
function M.shares(fields, order, cfg)
  cfg = cfg_of(cfg)
  local out = {}
  for _, res in ipairs(order) do
    local row = { res = res, el = 0, th = 0, pairs = 0, working = 0, covered_with_pairs = 0 }
    for _, g in ipairs(fields) do
      if g.res == res then
        local th, el = M.supply(g)
        row.th, row.el = row.th + th, row.el + el
        row.pairs, row.working = row.pairs + (g.pairs or 0), row.working + (g.working or 0)
        if (g.pairs or 0) > 0 and M.covered(g, cfg) then row.covered_with_pairs = row.covered_with_pairs + 1 end
      end
    end
    if row.el + row.th > EPS then row.share = row.el / (row.el + row.th) end
    out[#out + 1] = row
  end
  return out
end

return M
