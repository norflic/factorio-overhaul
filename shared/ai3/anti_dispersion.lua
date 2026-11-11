--[[
  ANTI-DISPERSION (lot IA-GARDE, règle de design DÉCIDÉE par le DC le 11/11 après sa partie 0.6.96) : « si l'équipe ne possède pas au moins
  2 colonnes de fonderie automatisées et 6 machines d'assemblage actives, toutes les tâches d'exploration lointaine, de pétrole ou de
  sur-stockage de charbon/pierre sont formellement inhibées ». Constats : rush pétrole d'Ambre à 41,6 min (projet 29) et du joueur à 46,2 min
  sans base de fer et de cuivre automatisée ; 46 foreuses électriques de charbon du joueur (bandes 4, 7, 21 du champ, 12 à 30 min) pour
  10 foreuses de fer.
  PUR : aucune API Factorio, aucun nom d'objet ; les mesures et les tables de données arrivent de script/ai3/anti_dispersion.lua (seul
  lecteur du jeu) et de ses appelants. UNE garde, lue par tous les points de décision :
    - exploration lointaine : script/ai3/exploration.lua (ouverture d'une demande d'exploration, open_request ; départ d'une veille) ;
    - pétrole : script/ai3/petrole.lua (Pet.think : demande d'un site, extension du champ de puits, fabrications d'un site pas fini) ;
    - sur-stockage de charbon/pierre : shared/ai3/cerveau.lua (buts « couverture:<type> » et « releve:<type> » sans manque, factions) et
      script/team/migration_champ.lua (bande du champ d'un minerai brut, toutes les équipes).

  DÉFINITIONS (mesurées sur les données du jeu, jamais sur un nom) :
    - COLONNE DE FONDERIE AUTOMATISÉE (Ad.colonne) : une bande du champ (projet du plan directeur au gabarit « champ » : spec.champ.pr, hors
      projet du réseau du charbon spec.champ.coal) à l'état « fini », qui porte au moins un four posé et présent au sol (rôle « champ-four »,
      motif shared/team/champ_colonne.lua et shared/team/champ_fonderie.lua : fours nourris par le tapis de la bande), et dont au moins un
      four a fondu depuis la mesure précédente ou travaille à la mesure : le minerai arrive bien par le tapis. Une bande de charbon ou de
      pierre (sans four) n'est jamais une colonne.
    - ASSEMBLEUR ACTIF (Ad.assembleur) : une entité de l'équipe dont le TYPE de prototype est celui des machines d'assemblage, qui a une
      recette, dont la catégorie de recette n'est pas une catégorie des prototypes de type four (une machine d'assemblage qui fond est un
      four), et qui travaille à la mesure ou a fini au moins un produit depuis la mesure précédente (compteur du moteur).
    - RESSOURCES DE DÉMARRAGE (Ad.demarrage) : les ressources des types d'avant-poste de la configuration (T.outposts) ; « brut » quand le
      produit de l'avant-poste est la ressource elle-même (porté brut au coffre : le combustible et la pierre des données vanilla), « fondre »
      sinon (le minerai part au four : le fer et le cuivre). Une ressource hors de cette table (pétrole, minerais des paliers) n'est pas de
      démarrage.
    - BESOIN MESURÉ (c.manque, posé par l'appelant) : la matière manque par rapport au besoin à la dernière pensée du cerveau
      (f.team.ia3.starved_open, shared/team/gisement.lua) ou porte un manque propre (f.team.ia3.short_core > 0).

  LIMITES, écrites et prouvées par tests/anti_dispersion_test.lua :
    - exploration : une ressource de démarrage que l'équipe ne tient pas encore (aucun avant-poste, aucun gisement connu) n'est JAMAIS
      inhibée (premier fer, premier cuivre, premier charbon, première pierre) ; un minerai brut (charbon, pierre) en manque mesuré non plus ;
      l'eau d'une centrale (demande « centrale ») non plus : sans courant, ni colonne électrique ni assembleur ne travaille, le seuil serait
      inatteignable (interblocage). Le tour du propriétaire (anneau des abords à la fondation) et la reconnaissance de la direction des
      attaques (défense) ne passent pas par cette garde ;
    - sur-stockage : seul un minerai BRUT est concerné ; un but d'extraction dimensionné par les capacités visées (« extraction:<type> »)
      ou une relève pour manque (« releve:<type> », raison « manque ») n'est pas un sur-stockage et passe ; un minerai brut en manque
      mesuré passe toujours ;
    - pétrole : tout est inhibé sous le seuil (aucune exception de démarrage : le pétrole n'en a pas) ; la recherche n'est pas une tâche
      et n'est pas touchée.
  Pas de mesure (moteur sans surface, équipe sans QG) : état nil, rien n'est inhibé.
  Déterminisme : listes triées, entiers, aucune horloge (la mesure est l'état du jeu au tick de la pensée).
]]

local Ad = {}

Ad.COLONNES = 2    -- décision du DC (11/11) : colonnes de fonderie automatisées au moins
Ad.ASSEMBLEURS = 6 -- décision du DC (11/11) : machines d'assemblage actives au moins
Ad.FAMILLES = { "exploration", "petrole", "surstock" } -- ordre du journal
Ad.NOMS = { exploration = "exploration lointaine", petrole = "petrole", surstock = "sur-stockage charbon/pierre" }
Ad.LIGNES_MAX = 80 -- lignes [FO-ANTI-DISPERSION] au plus par équipe (garde contre un seuil qui oscillerait)

local function sorted_keys(t)
  local out = {}
  for k in pairs(t or {}) do out[#out + 1] = k end
  table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
  return out
end

--- Ressources de démarrage depuis la table des types d'avant-poste { [type] = { resource, product } } : { [ressource] = "brut" | "fondre" }.
function Ad.demarrage(kinds)
  local out = {}
  for _, k in ipairs(sorted_keys(kinds)) do
    local s = kinds[k]
    if type(s) == "table" and s.resource ~= nil then
      out[s.resource] = (s.product == s.resource) and "brut" or "fondre"
    end
  end
  return out
end

--- Sorte d'un type d'avant-poste (« brut », « fondre ») ou nil.
function Ad.sorte_type(kinds, kind)
  local s = kinds and kinds[kind]
  if type(s) ~= "table" or s.resource == nil then return nil end
  return (s.product == s.resource) and "brut" or "fondre"
end

--- Une bande lue au plan directeur est-elle une colonne de fonderie automatisée ?
--- b = { bande (bande du champ, pas le réseau du charbon), etat, fours (posés et présents), fours_actifs (ont fondu ou travaillent) }.
function Ad.colonne(b)
  return type(b) == "table" and b.bande == true and b.etat == "fini" and (b.fours or 0) > 0 and (b.fours_actifs or 0) > 0
end

--- Une machine est-elle un assembleur actif ?
--- m = { assembleur (type de prototype des machines d'assemblage), recette (nom ou nil), categorie (de la recette), fours = { [catégorie] = true }
--- (catégories des prototypes de type four), travaille (état du moteur à la mesure), fini, fini_avant (compteurs de produits finis) }.
function Ad.assembleur(m)
  if type(m) ~= "table" or m.assembleur ~= true or m.recette == nil then return false end
  if m.categorie ~= nil and (m.fours or {})[m.categorie] then return false end
  if m.travaille == true then return true end
  return m.fini_avant ~= nil and (m.fini or 0) > m.fini_avant
end

--- État de la garde : { ouvert, colonnes, assembleurs }.
function Ad.etat(colonnes, assembleurs)
  local c, a = colonnes or 0, assembleurs or 0
  return { ouvert = c >= Ad.COLONNES and a >= Ad.ASSEMBLEURS, colonnes = c, assembleurs = a }
end

--- La décision de la famille `famille` est-elle permise ? Rend (permis, raison).
--- c (contexte de la décision) :
---   exploration : { sorte = Ad.demarrage(...)[ressource] (nil : pas de démarrage), tenu (avant-poste ou gisement connu de la ressource),
---                   manque (besoin mesuré), centrale (demande de l'eau d'une centrale) } ; une veille (reconnaissance sans ressource) n'a ni sorte ni
---                   exception : inhibée ;
---   surstock    : { sorte, manque } ;
---   petrole     : rien.
function Ad.permet(etat, famille, c)
  if etat == nil or etat.ouvert then return true, nil end
  c = c or {}
  if famille == "petrole" then return false, "seuil" end
  if famille == "exploration" then
    if c.centrale then return true, "eau de la centrale" end
    if c.sorte ~= nil and not c.tenu then return true, "premier gisement" end
    if c.sorte == "brut" and c.manque then return true, "besoin mesure" end
    return false, "seuil"
  end
  if famille == "surstock" then
    if c.sorte ~= "brut" then return true, nil end
    if c.manque then return true, "besoin mesure" end
    return false, "seuil"
  end
  return true, nil
end

local function texte_inhibees(inh)
  local parts = {}
  for _, fam in ipairs(Ad.FAMILLES) do
    if (inh[fam] or 0) > 0 then parts[#parts + 1] = Ad.NOMS[fam] .. " " .. inh[fam] end
  end
  return #parts > 0 and table.concat(parts, ", ") or "aucune"
end

--- Ligne du journal (sans l'étiquette) d'un état, des décisions inhibées comptées et de la minute.
function Ad.ligne(cle, etat, inh, minute, cause)
  return string.format("%s : %s a %.1f min (%s) : colonnes de fonderie automatisees %d/%d, assembleurs actifs %d/%d ; decisions inhibees : %s",
    tostring(cle), etat.ouvert and "OUVERT" or "FERME", minute or 0, cause, etat.colonnes, Ad.COLONNES, etat.assembleurs, Ad.ASSEMBLEURS,
    texte_inhibees(inh or {}))
end

--- Mesure neuve : garde l'état dans `memo` (global : nombres, booléens, chaînes) et rend le texte de la ligne quand l'état CHANGE (première
--- mesure comprise), sinon nil. Les décisions inhibées comptées pendant une fermeture sont dites à l'ouverture, puis remises à zéro.
function Ad.mesure(memo, etat, cle, minute)
  local avant = memo.ouvert
  memo.colonnes, memo.assembleurs = etat.colonnes, etat.assembleurs
  if avant == etat.ouvert then return nil end
  memo.ouvert = etat.ouvert
  local txt = Ad.ligne(cle, etat, memo.inh, minute, avant == nil and "premiere mesure" or "changement d'etat")
  memo.inh, memo.dites = {}, {}
  memo.lignes = (memo.lignes or 0) + 1
  if memo.lignes > Ad.LIGNES_MAX then return nil end
  return txt
end

--- Une décision de `famille` vient d'être inhibée : comptée ; rend le texte de la ligne la PREMIÈRE fois pour cette famille dans la fermeture
--- en cours (l'ensemble des familles inhibées change), sinon nil.
function Ad.inhibe(memo, famille, cle, minute)
  memo.inh = memo.inh or {}
  memo.dites = memo.dites or {}
  memo.inh[famille] = (memo.inh[famille] or 0) + 1
  if memo.dites[famille] then return nil end
  memo.dites[famille] = true
  memo.lignes = (memo.lignes or 0) + 1
  if memo.lignes > Ad.LIGNES_MAX then return nil end
  local etat = { ouvert = false, colonnes = memo.colonnes or 0, assembleurs = memo.assembleurs or 0 }
  return Ad.ligne(cle, etat, memo.inh, minute, "premiere decision inhibee : " .. (Ad.NOMS[famille] or tostring(famille)))
end

return Ad
