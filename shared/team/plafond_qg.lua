--[[
  Lot STOCK-QG (directive du DC, 8/11 vers 18 h 45) : « Le stockage de la base principale (qui devrait centraliser les outils, convoyeurs,
  bras, etc.) se fait totalement polluer par le rapatriement excessif de ressources brutes ou secondaires (pierre brute, fours en pierre,
  soufre, charbon). Les PNJ ne doivent pas rapatrier ces ressources basiques vers le hub central à l'infini. Le charbon ou la pierre
  doivent rester plafonnés dans les coffres tampons (buffers) de leurs zones d'extraction ou de fonderie. Mettez en place des plafonds
  stricts pour le rapatriement au QG. On n'agrandit les coffres du QG que pour des objets finis réellement utiles. »

  Règle PURE (aucune API Factorio, aucun nom d'objet du jeu) ; la lecture des prototypes est script/team/plafond_qg.lua. Quatre CATÉGORIES
  d'objet, déduites des prototypes :
    brut      objet qu'une ressource ou un arbre donne au minage (minerai, pierre, charbon, bois) ;
    base      intermédiaire de base : objet courant (type « item ») ni posable ni brut, fabriqué en au plus Pq.DEFAULT.base_depth étapes de
              recette à partir de bruts et de fluides (plaques, briques, engrenages, câbles, tuyaux, soufre) ;
    declasse  bâtiment de 1er âge DÉCLASSÉ : un objet qui pose une entité d'une famille de remplacement rapide dont un membre plus
              performant (vitesse de fabrication ou de minage) est fabricable par l'équipe (four de pierre après les fours meilleurs) ;
    fini      tout le reste (bâtiments utiles, munitions, packs, modules, circuits...) : AUCUN plafond.
  Un plafond en PILES par catégorie (Pq.DEFAULT) : au-delà, l'objet n'est plus rapatrié au QG (ni ramassé aux avant-postes, ni collecté
  aux coffres de sortie, ni miné à la main, ni vidé d'un tampon) et RESTE dans le tampon de sa zone. Brut : plafond DUR, relevé à
  brut_demande fois le plafond (32 piles) tant que la matière est DEMANDÉE (la fonderie du QG, les chaudières et les bruleurs la prennent
  au stock : un tampon de 80 secondes de fonte ne doit pas les affamer), jamais au-delà. Base et déclassé : le plafond cède devant une
  matière DEMANDÉE en ce moment (manque mesuré, objectif, projets en réserve : Sg.demanded). Les cases prises par du brut et du déclassé ne comptent PAS pour agrandir le QG
  (annexe ouverte pour un objet fini utile seulement).

    Pq.depths(recipes, raw)                         profondeur de recette de chaque objet : { [objet] = n } (brut : 0)
    Pq.obsolete(buildings, available)               bâtiments déclassés : { [objet] = vrai }
    Pq.classify(items, raw, depths, obsolete, cfg)  catégorie de chaque objet : { [objet] = "brut" | "base" | "declasse" | "fini" }
    Pq.cap_count(cat, stack, cfg)                   plafond en objets d'une catégorie (nil : aucun)
    Pq.room(cat, count, stack, wanted, cfg)         place restante au plafond (nil : aucun plafond, 0 : au plafond)
    Pq.capped(cat_of, counts, stack_of, need, cfg)  objets au plafond : { [objet] = compte }, noms parcourus triés
    Pq.discards(cat)                                brut et déclassé : retirés de la poche d'un PNJ au dépôt quand le stock est au plafond
    Pq.junk_slots(cat_of, counts, stack_of)         cases prises par du brut et du déclassé (ne comptent pas pour agrandir le QG)
    Pq.grows(used, size, junk)                      remplissage utile (cases prises moins le junk) / cases
  Entrées : `recipes` = { { ins = {objets}, outs = {objets} }, ... } (fluides exclus des listes) ; `raw` = { [objet] = vrai } ;
  `items` = { [objet] = { place = vrai si posable (entité, tuile ou équipement), plain = vrai si type « item » } } ;
  `buildings` = { { item, group, rating }, ... } (famille de remplacement rapide et vitesse lues aux prototypes) ;
  `available(item)` = l'équipe sait-elle fabriquer cet objet.
  Déterminisme : noms triés, aucun pairs décisionnel.
]]

local Pq = {}

Pq.CAT = { BRUT = "brut", BASE = "base", DECLASSE = "declasse", FINI = "fini" }
-- Plafonds en PILES par objet, et profondeur de recette d'un « intermédiaire de base ». Valeurs PROVISOIRES (jamais mesurées en partie
-- complète : à régler par le DC) : brut 8 piles (charbon ou pierre 400, bois 800), 4 fois plus (brut_demande) quand la matière est DEMANDÉE ; base 40 piles (plaques 4 000) ; déclassé 2 piles (100 fours).
Pq.DEFAULT = { brut = 8, base = 40, declasse = 2, base_depth = 2, brut_demande = 4 }

local function cfg_of(cfg) return cfg or Pq.DEFAULT end

local function sorted_keys(t)
  local out = {}
  for k in next, t or {} do out[#out + 1] = k end
  table.sort(out)
  return out
end

--- Profondeur de recette : 0 pour un brut, sinon 1 + la plus grande profondeur des ingrédients (objets seulement : un fluide n'est pas
--- listé, une recette qui n'a que des fluides compte 1) de la recette la moins profonde qui le donne. Relaxation bornée (cycles).
function Pq.depths(recipes, raw)
  local d = {}
  for it in next, raw or {} do d[it] = 0 end
  for _ = 1, 24 do
    local changed = false
    for _, r in ipairs(recipes or {}) do
      local m, known = 0, true
      for _, i in ipairs(r.ins or {}) do
        if d[i] == nil then known = false break end
        if d[i] > m then m = d[i] end
      end
      if known then
        for _, o in ipairs(r.outs or {}) do
          if d[o] == nil or m + 1 < d[o] then d[o] = m + 1; changed = true end
        end
      end
    end
    if not changed then break end
  end
  return d -- un brut reste à 0 même si une recette le fabrique (liquéfaction, recyclage) : la relaxation ne fait que baisser
end

--- Bâtiments déclassés : dans une famille de remplacement rapide (group), un bâtiment dont la vitesse (rating) est STRICTEMENT inférieure
--- à celle d'un autre bâtiment de la famille que l'équipe sait fabriquer. Sans famille ou sans vitesse : jamais déclassé.
function Pq.obsolete(buildings, available)
  local best = {}
  for _, b in ipairs(buildings or {}) do
    if b.group and type(b.rating) == "number" and available(b.item) then
      if best[b.group] == nil or b.rating > best[b.group] then best[b.group] = b.rating end
    end
  end
  local out = {}
  for _, b in ipairs(buildings or {}) do
    if b.group and type(b.rating) == "number" and best[b.group] ~= nil and b.rating < best[b.group] then out[b.item] = true end
  end
  return out
end

function Pq.classify(items, raw, depths, obsolete, cfg)
  cfg = cfg_of(cfg)
  local out = {}
  for _, it in ipairs(sorted_keys(items)) do
    local info = items[it]
    if raw and raw[it] then
      out[it] = Pq.CAT.BRUT
    elseif info.place then
      out[it] = (obsolete and obsolete[it]) and Pq.CAT.DECLASSE or Pq.CAT.FINI
    elseif info.plain and depths and depths[it] ~= nil and depths[it] <= cfg.base_depth then
      out[it] = Pq.CAT.BASE
    else
      out[it] = Pq.CAT.FINI
    end
  end
  for _, it in ipairs(sorted_keys(raw)) do if out[it] == nil then out[it] = Pq.CAT.BRUT end end
  return out
end

function Pq.cap_count(cat, stack, cfg)
  cfg = cfg_of(cfg)
  local piles = cat and cfg[cat]
  if cat == Pq.CAT.FINI or type(piles) ~= "number" or type(stack) ~= "number" or stack <= 0 then return nil end
  return piles * stack
end

--- Place restante au plafond de la catégorie pour `count` objets au stock : nil sans plafond (objet fini, catégorie inconnue, base ou
--- déclassé DEMANDÉ), 0 au plafond, sinon la différence. Une matière BRUTE demandée (`wanted`) a un plafond cfg.brut_demande fois plus haut
--- (jamais supprimé).
function Pq.room(cat, count, stack, wanted, cfg)
  local cap = Pq.cap_count(cat, stack, cfg)
  if not cap then return nil end
  if wanted then
    if cat == Pq.CAT.BRUT then cap = cap * (cfg_of(cfg).brut_demande or 1) else return nil end
  end
  local room = cap - (count or 0)
  return room > 0 and room or 0
end

--- Objets au plafond de leur catégorie (Pq.room = 0). `need` = { [objet] = q } : matières demandées en ce moment (Sg.demanded).
--- `counts` = { [objet] = nombre au stock }.
function Pq.capped(cat_of, counts, stack_of, need, cfg)
  local out = {}
  for _, it in ipairs(sorted_keys(counts)) do
    local cat = cat_of[it]
    if cat and Pq.room(cat, counts[it], stack_of[it], need and need[it] ~= nil, cfg) == 0 then out[it] = counts[it] end
  end
  return out
end

--- Les catégories qu'on RETIRE de la poche d'un PNJ au dépôt quand le stock est au plafond (du déchet : brut et déclassé) ; une base
--- reste en poche (ses plaques valent mieux qu'un rebut : seul le ramassage s'en abstient).
function Pq.discards(cat)
  return cat == Pq.CAT.BRUT or cat == Pq.CAT.DECLASSE
end

--- Cases prises par du brut et du déclassé (piles entières), les seules à ne pas compter pour agrandir le QG.
function Pq.junk_slots(cat_of, counts, stack_of)
  local n = 0
  for _, it in ipairs(sorted_keys(counts)) do
    local cat = cat_of[it]
    if (cat == Pq.CAT.BRUT or cat == Pq.CAT.DECLASSE) and counts[it] > 0 then
      n = n + math.ceil(counts[it] / math.max(1, stack_of[it] or 1))
    end
  end
  return n
end

--- Cases prises utiles : les cases prises moins le junk, jamais négatif.
function Pq.grows(used, size, junk)
  local u = (used or 0) - (junk or 0)
  if u < 0 then u = 0 end
  return u, size
end

return Pq
