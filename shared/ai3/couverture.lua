--[[
  Lot COUVERTURE (retour du DC du 8/11, 0.6.65, Azure, 2 h 30 de partie) : « il y a souvent un à deux max rangées de mineurs électriques
  [...] ils construisent pas en boucle. Alors que un joueur typiquement qui a en réserve des centaines de foreuses [...] il s'amuserait
  juste à poser en boucle en boucle des usines pour avoir plus de ressources. » Règle de speedrun : tant que la force a de quoi poser
  (la capitalisation a déjà payé l'ordre sur le stock libre) et que la sortie a un DÉBOUCHÉ (le produit n'est pas saturé), elle continue
  de couvrir le gisement jusqu'à ses bords ; le surplus s'investit dans plus de ressources.

  Mesuré (0.6.64, partie neuve de 60 min, graine 20261020) : la porte L6 (shared/ai3/portes_extension.lua) retenait « transport sature »
  15 ordres couvrir sur 15 chez Azure, 26 sur 27 chez votre équipe, 19 sur 21 chez Scarlet, de la minute 2 à la 60 : les PNJ d'une force
  sont occupés en permanence (moins de 10 % de libres), la porte reste fermée, et seul un ordre « racine » (produit en manque mesuré) la
  passe. Un produit en surplus n'est donc jamais étendu. Cette règle ajoute la seconde sorte de racine : un couvrir/ouvrir dont le produit
  n'est PAS saturé passe la porte du transport. Il reste soumis à la porte des chantiers (Pe.site_room : un chantier de plus à la fois par
  Pe.MODULES_PER_SITE modules posés) : le travail ouvert reste borné.

  Règle PURE (aucune API Factorio, aucun nom d'objet : anti-échelle de tests/iag_test.lua §8). Déterminisme : aucun pairs, aucun hasard,
  aucun temps mesuré. Testée hors jeu : tests/couverture_test.lua (mutants).
]]

local Cv = {}

-- Sortes d'ordres de la capitalisation qui étendent l'EXTRACTION (noms de sortes d'ordres, pas des objets du jeu).
Cv.KINDS = { couvrir = true, ouvrir = true }

--- Verdict d'un ordre. a = {
---   kind     : sorte de l'ordre (shared/ai3/capitalisation.lua : couvrir, ouvrir, chaine, ...),
---   product  : produit de la ressource de l'ordre (clé de st.saturated), nil si la ressource n'a pas de produit suivi,
---   saturated: { [produit] = true } (f.team.ia3.saturated : stock >= B.SAT_FACTOR x besoin, pente comprise),
---   free     : places libres du gisement de l'ordre (res.coverage) ; nil = inconnu (compte comme aucune place),
---   crisis   : mode survie ou QG menacé (le travail de base passe avant),
--- }
--- Rend (vrai, raison) quand l'ordre passe la porte du transport « en boucle », (faux, raison) sinon. La raison est écrite au journal.
function Cv.loop(a)
  a = a or {}
  if not Cv.KINDS[a.kind] then return false, "sorte sans extraction (" .. tostring(a.kind) .. ")" end
  if a.crisis then return false, "crise (survie ou QG menace) : le travail de base d'abord" end
  if type(a.product) ~= "string" then return false, "aucun produit suivi pour cette ressource" end
  if type(a.free) ~= "number" or a.free ~= a.free or a.free <= 0 then return false, "gisement sans place libre" end
  -- Saturation totale (directive du DC du 8/11) : l'ordre de saturation d'un gisement revendiqué n'a pas besoin de débouché.
  if (a.saturated or {})[a.product] and not a.saturation then return false, a.product .. " sature (stock au-dela du besoin) : plus de debouche" end
  if a.saturation then return true, string.format("saturation du gisement : %d place(s) libre(s)", math.floor(a.free)) end
  return true, string.format("debouche : %s non sature, %d place(s) libre(s)", a.product, math.floor(a.free))
end

--- Lot s44 GISEMENTS : places libres du gisement AVANT l'ordre. `res.coverage[].free` est relu dans le plan APRÈS application des ordres
--- de la décision (Ca.apply -> add_drills compte la couverture de l'ordre) : un ordre couvrir de n foreuses qui remplit à lui seul le reste du
--- gisement y laissait 0 place et Cv.loop le refusait (« gisement sans place libre ») ; retenu alors par la porte du transport, il ne passait
--- jamais (journal 0.7.102 : « couvrir:iron-ore@-382,388 x57 : ... boucle non retenue : gisement sans place libre », emerald minute 80).
--- Rend free + own (own = foreuses de l'ordre lui-même) ; free illisible reste nil (inconnu), own illisible compte 0.
function Cv.free_before(free, own)
  if type(free) ~= "number" or free ~= free then return nil end
  local n = (type(own) == "number" and own == own and own > 0 and own < math.huge) and math.floor(own) or 0
  return math.max(0, free) + n
end

-- SATURATION TOTALE DES GISEMENTS (directive du DC du 8/11, 14 h 50 : « Un speedrunner ne laisse jamais un champ de minerai à moitié vide. Il le
-- sature de foreuses [...] La règle est binaire : s'il reste une tuile de minerai exploitable sur un gisement revendiqué, l'ordre de
-- construction de foreuses reste actif. »). Mesuré sur la partie du DC (39 à 44 min) : les grands gisements revendiqués sont à 0,3 à 11 %
-- (azure cuivre 12/3010 inchangé de la minute 8 à la 43), parce que la couverture d'avance exige une demande NETTE de minerai (Ri > 0 : le
-- besoin de la plaque moins 10 minutes de stock) : avec 10 minutes de plaques en stock, plus aucune option, ni refus écrit.
--- a = { free (places libres du gisement), kappa (‰ des tuiles couvertes), kappa_max (‰ visé, 1000), electric (la foreuse choisie n'a pas de
--- combustible), crisis (survie ou QG menacé) }. Rend (vrai, raison) quand le gisement garde un ordre de couverture ouvert, (faux, cause) sinon.
--- La cause est TOUJOURS écrite (refus, journal [FO-SATURATION]) : plus de cas silencieux.
function Cv.saturation(a)
  a = a or {}
  if a.crisis then return false, "crise (survie ou QG menace) : le travail de base d'abord" end
  if a.electric ~= true then return false, "foreuse a combustion : la saturation se fait en electrique (combustible porte a vie par les PNJ)" end
  if type(a.free) ~= "number" or a.free ~= a.free or a.free <= 0 then return false, "aucune place libre (tuiles toutes couvertes ou prises)" end
  local kmax = type(a.kappa_max) == "number" and a.kappa_max or 1000
  if type(a.kappa) ~= "number" or a.kappa ~= a.kappa then return false, "couverture inconnue" end
  if a.kappa >= kmax then return false, "gisement sature (" .. math.floor(a.kappa) .. " pour mille)" end
  return true, string.format("%d place(s) libre(s), couverture %d pour mille", math.floor(a.free), math.floor(a.kappa))
end

--- Modules d'un ordre de SATURATION (accord du lead, 8/11 : « plusieurs modules par ordre, pour les ordres de saturation seulement »). `want` =
--- modules que le débit de l'ordre demande (⌈débit ÷ capacité d'un module⌉), `hands` = bras libres (escouades de zéro-idle), `per_hand` = bras
--- par module (Dm.HANDS_PER_SITE), `hard` = plafond de sûreté (Dm.SLOTS_HARD). Rend (obtenus, cause de l'écart ou nil) : toujours au moins 1 (le
--- budget de matières a déjà borné l'ordre : Ca.decide réduit n au stock libre après la réserve), au plus `want`, `hard`, et 1 + bras ÷ par module.
function Cv.sat_modules(want, hands, per_hand, hard)
  local w = (type(want) == "number" and want == want and want >= 1) and math.floor(want) or 1
  local h = (type(hands) == "number" and hands == hands and hands > 0) and hands or 0
  local ph = (type(per_hand) == "number" and per_hand >= 1) and per_hand or 1
  local cap = (type(hard) == "number" and hard >= 1) and math.floor(hard) or 1
  local by_hands = 1 + math.floor(h / ph + 1e-9)
  local got = math.min(w, cap, by_hands)
  if got >= w then return got, nil end
  if got == cap and cap <= by_hands then return got, "plafond de surete (" .. cap .. " modules)" end
  return got, string.format("bras libres (%d libre(s), %d par module)", math.floor(h), math.floor(ph))
end

--- Modules posés (G12, porte des chantiers) : les modules DÉJÀ FINIS (compteur cumulé, `done`) plus ceux qui sont finis parmi les ordres
--- encore ouverts (`open_fini`). Avant le lot, seul le second terme comptait : un ordre fini quitte la liste des ordres ouverts, son module
--- disparaissait du compte et la limite de chantiers restait à 1 pour toute la partie (mesuré : « places de chantier 1 sur 1 (0 pose(s) »
--- à la minute 257 d'une partie de 255 min). Une valeur absente ou illisible compte zéro.
function Cv.batis(done, open_fini)
  local function nat(v) if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then return 0 end return math.floor(v) end
  return nat(done) + nat(open_fini)
end

--- Sortes d'exécutants qui posent un chantier du plan directeur (un module de gabarit, une bande du champ) : leurs ordres finis comptent.
Cv.SITE_EXECS = { module = true, champ = true }

--- Emplacements de chantier de plus selon la taille de la force (lot COUVERTURE, mesure du 8/11 : « plan directeur occupé (4 modules ouverts,
--- 2 emplacements) » sur la sauvegarde du DC) : un par tranche de `per` chantiers déjà finis (la même règle que la porte G12, Pe.MODULES_PER_SITE),
--- jamais négatif ; l'appelant borne le total (Dm.SLOTS_HARD). Valeur illisible : zéro.
function Cv.slot_growth(done, per)
  local d = Cv.batis(done, 0)
  if type(per) ~= "number" or per ~= per or per < 1 then return 0 end
  return math.floor(d / per)
end

--- Amorce du compteur cumulé pour une partie qui n'en a pas encore (sauvegarde d'avant le lot) : les ordres de chantier finis gardés dans
--- l'historique `done` ({ { exec, state } }, borné par le runtime). Rend un entier. `mods_of(rec)` rend le nombre de chantiers de l'ordre.
function Cv.seed(history, mods_of)
  local n = 0
  for _, r in ipairs(history or {}) do
    if type(r) == "table" and Cv.SITE_EXECS[r.exec] and r.state == "fini" then
      local k = mods_of and mods_of(r) or 1
      if type(k) == "number" and k > 0 then n = n + math.floor(k) end
    end
  end
  return n
end

-- RÉSERVE DE MACHINES (lot COUVERTURE, suite). Le mall ne suit que la fabrication à la main PASSÉE : un chantier de couverture consomme d'un
-- coup des dizaines de foreuses, des centaines de tapis et des poteaux, qui attendent alors « reserve:materiaux » fabriqués à la main
-- (mesuré 0.6.64 : « manque transport-belt 449 » à la minute 27, 135 encore à la 57, tous les objets du mall en « amorcage a la main »
-- pendant 60 min). La pose PRÉVUE devient une demande du mall : chaque objet du module d'un ordre de couverture qui passe, divisé par le
-- rythme de pose, est une demande par minute (Ml.want, source Cv.SRC) ; le mall en tient Ml.HORIZON_MIN minutes au coffre de sortie.
Cv.PACE_MIN = 15      -- minutes : un chantier de couverture est posé toutes les 15 minutes au plus (rythme mesuré : une bande par 12 à 20 min)
Cv.RATE_MAX = 60      -- objets par minute au plus par objet (un mall de 10 assembleurs par objet : Ml.MACHINES_MAX borne en plus)
Cv.SRC = "couverture" -- source de la demande notée par Ml.want

--- `orders` : ordres de la décision qui PASSENT (clé, kind, items = { { objet, quantité } }) ; `held` : { [clé] = raison } des ordres
--- retenus (ils ne comptent pas, sauf une raison de chantier : l'ordre passera dès qu'une place se libère). Rend la liste triée par objet
--- { { item, rate } } : somme des quantités des modules ÷ Cv.PACE_MIN, plafonnée à Cv.RATE_MAX. Entrées illisibles ignorées.
function Cv.reserve_wants(orders, held)
  local qty = {}
  for _, o in ipairs(orders or {}) do
    local why = held and held[o.key] or nil
    local counts = why == nil or tostring(why):find("chantier", 1, true) ~= nil
    if type(o) == "table" and Cv.KINDS[o.kind] and counts then
      for _, it in ipairs(o.items or {}) do
        local name, n = it[1], it[2]
        if type(name) == "string" and type(n) == "number" and n == n and n > 0 and n < math.huge then qty[name] = (qty[name] or 0) + n end
      end
    end
  end
  local names = {}
  for k in next, qty do names[#names + 1] = k end
  table.sort(names)
  local out = {}
  for _, k in ipairs(names) do
    local rate = qty[k] / Cv.PACE_MIN
    if rate > Cv.RATE_MAX then rate = Cv.RATE_MAX end
    out[#out + 1] = { item = k, rate = rate }
  end
  return out
end

return Cv
