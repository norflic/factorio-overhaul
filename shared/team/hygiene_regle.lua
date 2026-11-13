--[[
  Lot HYGIENE-ACTIVE (décision du DC du 10/11 : « passer de l'audit (F444, lecture seule) au démontage sécurisé ») : règles PURES du
  retrait d'un poteau électrique. Aucune lecture du moteur ici : le moteur (script/team/hygiene.lua) relit le monde AU TICK du retrait et
  passe des nombres, des booléens et des positions relatives ; ce module décide et nomme la cause d'un refus.

  Trois règles :
    Hr.feuille_retirable(p) : une FEUILLE (au plus un voisin de fil de cuivre : un sommet de degré ≤ 1 n'est jamais un point
      d'articulation) sans CONSOMMATEUR PROPRE (chaque entité qu'elle alimente est aussi sous un autre poteau du même réseau) se retire
      si l'autre poteau couvrant est ALIMENTÉ (réseau avec génératrice), hors d'un projet non fini, hors d'une pièce d'un plan fini (le
      réseau vivant la reposerait comme « poteau perdu »), hors de la chaîne des foreuses en cours de pose, hors d'une box MAXED, et
      jamais un poteau posé par un joueur. Rend (vrai, « isole » | « feuille ») ou (faux, cause).
    Hr.sur_gisement_plan(p) : un poteau SUR GISEMENT (il gêne l'extraction) n'est retiré que si un REMPLAÇANT hors gisement, sur une
      place libre, à portée de fil de TOUS ses voisins (la topologie du réseau est conservée : le remplaçant relie exactement ce que
      l'ancien reliait) et dont le carré d'alimentation couvre tous les consommateurs que l'ancien alimentait SEUL, existe. Rend la
      position relative du remplaçant (le plus proche de l'ancien ; à égalité, dx puis dy croissants : déterministe) ou nil + cause.
      Hr.candidats_ordonnes(p) rend la liste des candidats géométriquement valables, du plus proche au plus loin : le moteur ne sonde
      (minerai, place libre) que ceux-là, dans cet ordre, et s'arrête au premier bon (coût borné : Hr.CFG.max_sondes).
    Hr.budget(n, cfg) : au plus cfg.max_retraits retraits (feuilles retirées + remplaçants posés) par impulsion : prudence, mesure au banc
      (V0676-H : 4 à 8 redondants candidats à 45 min ; 4 par impulsion de 3 min les épuise en deux impulsions sans jamais vider un réseau
      d'un coup, et le réseau vivant ([FO-RESEAU], toutes les 2 min) a le temps de constater qu'aucune machine n'a perdu le courant).

  Tests : tests/hygiene_regle_test.lua (règles et mutants : couvrant non alimenté accepté, projet non fini retiré, remplaçant hors
  portée, budget ignoré). Aucun réglage, aucun nom d'objet, aucun `pairs` dont l'ordre compte.

  Lot HYGIENE-PLANS-FINIS (directive du DC du 10/11, priorité 3) : une PIÈCE D'UN PLAN FINI posée SUR GISEMENT (elle gêne l'extraction)
  n'est plus refusée d'office : Hr.plan_cedable(p) la CÈDE (le plan la reconnaît cédée : e.dropped, le réseau vivant ne la repose pas)
  quand un poteau EXTÉRIEUR (hors gisement, même réseau, alimenté) couvre tous les consommateurs qu'elle alimentait (couverture) ET que le
  réseau reste continu : une feuille (≤ 1 fil : jamais un point d'articulation) part telle quelle, « feuille » ; sinon, « remplacant » :
  la voie du remplaçant (Hr.sur_gisement_plan : relie tous les voisins, couvre tout) et la pièce du plan suit le remplaçant hors gisement.
  Refus : projet non fini, pièce déjà cédée, pas sur gisement (une pièce d'un plan fini hors gisement reste au plan), couverture
  extérieure manquante (un consommateur ne serait plus couvert que par un poteau lui-même sur gisement, ou par rien), couvrant non alimenté,
  RELAIS SANS CONSOMMATEUR : une feuille qui n'alimente rien ne prouve rien sur sa portée ; c'est la pointe d'une LIGNE électrique vers une
  bande (banc HYGPLANS-A : la ligne du projet 6 mangée pointe après pointe, une tranche après l'autre, 5 bandes finies au lieu de 8) ; seule
  une feuille dont TOUS les consommateurs (au moins un) sont repris par un poteau extérieur est cédée.
]]

local St = require("shared.team.scan_tranches")

local Hr = {}

Hr.CFG = {
  max_retraits = 4, -- retraits par impulsion (feuilles + remplaçants posés) : prudence, mesure au banc (voir l'en-tête)
  max_sondes = 24,  -- candidats de remplacement sondés au moteur (minerai, place) au plus par poteau : coût borné d'une tranche
}

--- s42 gisements (chantier 4.3 du DC, partie 0.7.96 : 639 impulsions sur 904 refusées pour « famine », 13 poteaux déplacés en 4 h 15) : la
--- famine de la plaque clé ne retient plus un poteau SUR GISEMENT. Aucune plaque n'y est dépensée (feuille : l'objet rentre au coffre ;
--- remplaçant : pris au coffre, l'ancien y rentre à la tranche suivante), et le poteau gêne l'extraction du minerai qui manque. Hors
--- gisement, la famine retient toujours (comportement d'avant). Rend vrai si l'action est refusée.
function Hr.famine_bloque(famine, sur_gisement)
  return famine == true and not sur_gisement
end

--- Retraits encore permis dans l'impulsion : (vrai si `n` retraits faits en laissent au moins un, reste).
function Hr.budget(n, cfg)
  cfg = cfg or Hr.CFG
  local reste = (cfg.max_retraits or 0) - (n or 0)
  if reste < 0 then reste = 0 end
  return reste > 0, reste
end

--- p = { fils = n (voisins de cuivre), consommateurs = n (entités alimentées par lui), consommateurs_propres = n (non couvertes par un
--- autre poteau), couvrant_alimente = bool (l'autre poteau couvrant est sur un réseau avec génératrice), projet_fini = bool (faux :
--- pièce d'un projet du plan directeur non fini), piece_plan = bool (pièce bâtie d'un projet FINI : le réseau vivant la reposerait),
--- chaine_foreuses = bool (poteau d'une chaîne du remplacement des foreuses en cours), box_maxed = bool, pose_par_joueur = bool }.
--- Rend (vrai, « isole » | « feuille ») ou (faux, cause). Les causes structurelles d'abord : la première qui tient est rendue.
function Hr.feuille_retirable(p)
  if p.box_maxed then return false, "box MAXED" end
  if p.projet_fini == false then return false, "projet non fini" end
  if p.piece_plan then return false, "piece du plan" end
  if p.chaine_foreuses then return false, "chaine des foreuses" end
  if p.pose_par_joueur then return false, "pose par un joueur" end
  local fils = p.fils or 0
  if fils > 1 then return false, "pas une feuille" end
  if (p.consommateurs_propres or 0) > 0 then return false, "consommateur propre" end
  if (p.consommateurs or 0) > 0 and not p.couvrant_alimente then return false, "couvrant non alimente" end
  if fils == 0 then return true, "isole" end
  return true, "feuille"
end

--- Lot HYGIENE-PLANS-FINIS : p = { piece_plan = bool (pièce bâtie d'un plan FINI), projet_fini = bool, sur_gisement = bool,
--- deja_cedee = bool, fils = n, consommateurs = n, consommateurs_propres = n (alimentés par lui et par AUCUN poteau extérieur : hors
--- gisement, même réseau), couvrant_alimente = bool, box_maxed, chaine_foreuses, pose_par_joueur }.
--- Rend (vrai, « feuille » | « remplacant ») ou (faux, cause). Les causes structurelles d'abord, puis la couverture extérieure.
function Hr.plan_cedable(p)
  if p.box_maxed then return false, "box MAXED" end
  if p.projet_fini == false or not p.piece_plan then return false, "projet non fini" end
  if p.chaine_foreuses then return false, "chaine des foreuses" end
  if p.pose_par_joueur then return false, "pose par un joueur" end
  if p.deja_cedee then return false, "piece deja cedee" end
  if not p.sur_gisement then return false, "piece du plan" end
  local fils = p.fils or 0
  if fils <= 1 then
    if (p.consommateurs or 0) == 0 then return false, "relais sans consommateur" end
    if (p.consommateurs_propres or 0) > 0 then return false, "couverture exterieure manquante" end
    if not p.couvrant_alimente then return false, "couvrant non alimente" end
    return true, "feuille"
  end
  return true, "remplacant"
end

--- Le candidat `c` = { dx, dy } est-il à portée de fil `portee_fil` de TOUS les voisins { dx, dy } ?
local function relie_tous(c, voisins, portee_fil)
  local r2 = portee_fil * portee_fil
  for _, v in ipairs(voisins) do
    local ex, ey = c.dx - v.dx, c.dy - v.dy
    if ex * ex + ey * ey > r2 then return false end
  end
  return true
end

--- Le carré d'alimentation (demi-côté `d`) d'un poteau en `c` couvre-t-il tous les `couverts` ({ dx, dy } point, ou { dx, dy, w, h }
--- boîte centrée) ? Même règle que le moteur (St.covers : intervalles ouverts).
local function couvre_tous(c, couverts, d)
  for _, k in ipairs(couverts) do
    local hw, hh = (k.w or 0) / 2, (k.h or 0) / 2
    if not St.covers(c.dx, c.dy, d, k.dx - hw, k.dy - hh, k.dx + hw, k.dy + hh) then return false end
  end
  return true
end

--- Cause géométrique du rejet d'un candidat, ou nil s'il convient ; `strict` exige aussi hors_gisement et libre VRAIS (nil = refusé).
local function rejet(p, c, strict)
  if not relie_tous(c, p.voisins or {}, p.portee_fil or 0) then return "hors portee de fil" end
  if not couvre_tous(c, p.couverts or {}, p.portee_alim or 0) then return "couverture perdue" end
  if c.hors_gisement == false or (strict and c.hors_gisement == nil) then return "sur gisement" end
  if c.libre == false or (strict and c.libre == nil) then return "place prise" end
  return nil
end

--- Ordre des candidats : le plus proche de l'ancien poteau d'abord ; à égalité dx puis dy croissants (aucun ordre de `pairs`).
local function plus_proche(a, b)
  local da, db = a.dx * a.dx + a.dy * a.dy, b.dx * b.dx + b.dy * b.dy
  if da ~= db then return da < db end
  if a.dx ~= b.dx then return a.dx < b.dx end
  return a.dy < b.dy
end

--- Candidats géométriquement valables (portée de fil vers tous les voisins, couverture de tous les `couverts`, et ni « sur gisement »
--- ni « place prise » quand ces champs sont renseignés), triés du plus proche au plus loin. Rend la liste et le compte des rejets par cause.
function Hr.candidats_ordonnes(p)
  local out, refus = {}, {}
  for _, c in ipairs(p.candidats or {}) do
    local why = rejet(p, c, false)
    if why then refus[why] = (refus[why] or 0) + 1 else out[#out + 1] = c end
  end
  table.sort(out, plus_proche)
  return out, refus
end

local CAUSES = { "hors portee de fil", "couverture perdue", "sur gisement", "place prise" } -- ordre fixe des causes (égalités)

--- La cause dominante d'un compte de refus { [cause] = n } (la plus fréquente ; à égalité, l'ordre de CAUSES).
local function dominante(refus)
  local best, n = nil, 0
  for _, k in ipairs(CAUSES) do
    if (refus[k] or 0) > n then best, n = k, refus[k] end
  end
  return best
end

--- p = { sur_gisement = bool, voisins = { { dx, dy } }, portee_fil, portee_alim, couverts = { { dx, dy[, w, h] } },
--- candidats = { { dx, dy, hors_gisement = bool, libre = bool } } }. Rend le candidat retenu ({ dx, dy }) ou nil + cause.
function Hr.sur_gisement_plan(p)
  if not p.sur_gisement then return nil, "pas sur gisement" end
  if #(p.voisins or {}) == 0 then return nil, "aucun voisin de fil" end
  if #(p.candidats or {}) == 0 then return nil, "aucun candidat" end
  local ok, refus = {}, {}
  for _, c in ipairs(p.candidats) do
    local why = rejet(p, c, true)
    if why then refus[why] = (refus[why] or 0) + 1 else ok[#ok + 1] = c end
  end
  if #ok == 0 then return nil, "remplacant : " .. (dominante(refus) or "aucun candidat") end
  table.sort(ok, plus_proche)
  return ok[1]
end

return Hr
