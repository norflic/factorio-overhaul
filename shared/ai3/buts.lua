--[[
  IA3-c « le cerveau par besoins » : GÉNÉRATEURS DE BUTS (docs/IA3_CERVEAU.md §3.1). PUR (aucune API Factorio).

  Plus d'échelle écrite à la main : chaque FAMILLE de buts a un générateur qui lit la situation (stock, débits manqués,
  avant-postes, recherche, armée) et rend des buts { key, family, value 0 à 100, ... }. La valeur d'un but =
  base de la famille × POIDS DU CHEF (IA2, selon le caractère : postures et traits) × urgence. Le cerveau
  (shared/ai3/cerveau.lua) garde les meilleurs comme PROJETS (shared/ai3/projets.lua).

  Familles de ce lot :
    extraction  avant-postes PAR BESOIN : amorçage (une capacité par ressource dont le produit manque), « fer II »
                (économie avant recherche, revue B3), croissance quand un produit MANQUE durablement (goulot, H2) ;
                une ressource dont le stock dépasse le besoin prévu (horizon) ne fait plus rien bâtir (constat du DC du
                25/10, 18 h 45 : « ils farment de la pierre et du charbon […] ils en ont a foison ») ;
    capital     fonderie du QG (fours posés au QG) ;
    defense     réserve de munitions (les tourelles et la défense d'IA1-b2 restent au planificateur permanent) ;
    recherche   la VRAIE technologie choisie par le runtime (valeur ÷ coût, payable) ; factions seulement ;
    armee       soldats visés (posture du chef) ; factions seulement.
  Survie, entretien, défense d'IA1-b2, recrues : familles PERMANENTES, gardées telles quelles (shared/team/planner.lua
  appelé sans échelle par le cerveau), comme la conception le demande (§3.1, dernières lignes ; §5.1, tableau IA1-b2).

  Aucun nom d'objet ni de bâtiment du jeu ici : les ressources, produits et kits viennent de shared/team/config.lua
  (données du mod), la technologie du runtime. Listes triées, entiers, aucun hasard, aucun pairs décisionnel.
]]

local T = require("shared.team.config")
local R = require("shared.ai3.reglages") -- lot IA-G : ressources clés de repli (équipe du joueur, avant la 1re décision)
local Br = require("shared.ai3.bras") -- lot SCALE : travail des bras libres (bornes qui suivent l'effectif)

local B = {}

B.FAMILIES = { "extraction", "capital", "defense", "recherche", "armee" }

-- Affinité des postures du chef (IA2-a, C.POSTURES) pour chaque famille, pour mille (mêmes catégories que C.AFFINITY :
-- ext = extraction, cap = capital, tech = recherche, fort = defense, army = armee).
B.POSTURE = {
  expansion = { extraction = 1000, capital = 300 },
  capitalisation = { capital = 1000, extraction = 500 },
  technologie = { recherche = 1000 },
  fortification = { defense = 1000, armee = 300 },
  armee = { armee = 1000, defense = 300 },
  assaut = { armee = 1000 },
  raids = { armee = 600 },
  reconstruction = { defense = 600, extraction = 600 },
}
-- Trait du caractère (IA2-0) qui biaise chaque famille dès la première pensée.
B.TRAIT = { extraction = "ambition", capital = "discipline", recherche = "curiosite", defense = "prudence",
  armee = "agressivite" }
B.W_MIN, B.W_MAX = 500, 2000

-- Bases des familles (valeur avant poids et urgence).
-- Premier avant-poste d'une ressource qui manque. Lot IA-G : plus de valeur écrite par ressource ; la valeur suit le RANG
-- de la ressource dans le besoin brut des buts de l'équipe (s.key, déduit du dépliage par shared/ai3/general.lua :
-- Gen.key_resources), le combustible à part. Sur les données vanilla, le rang déduit rend les valeurs d'avant (fer 92,
-- charbon 90, cuivre 82, pierre 70 : tests/iag_test.lua §3).
B.BOOT_RANK = { 92, 82, 70 }
B.BOOT_FUEL = 90
B.IRON2 = 66        -- « fer II » (2 capacités de fer et 2 de charbon) : l'économie avant la recherche (revue B3)
B.GROW = 55         -- croissance d'une ressource qui manque durablement (goulot)
-- Lot SCALE-COMPLET (retour du DC du 29/10, 21 h 40, en jouant la 0.6.18 : « Le cuivre, ils l'ont pas ils ont pas pris tout le
-- gisement alors qu'ils auraient pu. Le fer pareil ») : COUVERTURE d'un gisement déjà ouvert, au-delà du besoin. But de FOND
-- (aucune des K places, servi après tous les autres projets, comme la capitalisation : Ca.V_MIN 35 à Ca.V_MAX 50), au-dessus
-- du seuil du travail qui fait recruter (35, IA3-d).
B.COVER = 40
-- Relecture SCALE-COMPLET : la couverture est un but AU-DELÀ du besoin ; le poids du chef (500 à 2 000 pour mille) la portait
-- jusqu'à 80 (priorité de tâche 40 + 0,45 × (80 + 20 % d'inertie) + 3 = 86), au-dessus des tournées des avant-postes (70) et
-- des tourelles d'avant-poste (75) : un chef « expansion » aurait agrandi pendant que ses brûleurs s'éteignaient. Bornée à
-- B.COVER_MAX (tâche à 68 au plus, hors vieillissement), dans la bande de la capitalisation (Ca.V_MIN 35 à Ca.V_MAX 50).
B.COVER_MAX = 48
B.GROW_SHORT = 100  -- manque (objets) qui compte comme « durable » …
B.GROW_THINKS = 6   -- … pendant au moins 6 pensées de suite (30 s)
B.GROW_MAX = 5      -- capacités visées au plus, par ressource
B.IDLE_GROW_EVERY = 3 * 3600 -- lot IA-G (bras libres) : une capacité de plus au plus toutes les 3 min
B.SMELTERS = 45
B.SMELTERS_WANT = 4
B.AMMO = 55
B.AMMO_STOCK = 60   -- réserve de munitions visée (ancienne marche « defense »)
B.AMMO_MIN = 20     -- lot INTEG-ECONOMIE (D1) : réserve MINIMALE de munitions, jamais retenue par « production d'abord » (shared/team/priorite.lua)
B.RESEARCH = 62
B.RESEARCH_PALIER = 14 -- la technologie suivante ouvre un pack (« la recherche vaut ce qu'elle débloque », H9)
B.RESEARCH_PRE = 44    -- plafond avant « fer II » (économie d'abord, revue B3)
B.RESEARCH_CHEAP = 60  -- … sauf une recherche PEU CHÈRE : fer encore à dépenser (packs et laboratoire) ≤ 60 plaques (lot IA-V2)
B.ARMY_FIRST = 58      -- les 10 premiers soldats (ancienne marche « army »)
B.ARMY_FIRST_N = 10
B.ARMY_MORE = 46       -- l'armée qui grandit (l'ancien cerveau : 45, sous l'objectif courant à 50)
-- Lot ARMEE-ANTICIPATION (« recruter un maximum de soldats », DC 29/10) : vague annoncée (shared/ai3/armee.lua) : l'armée monte
-- jusqu'au besoin estimé avec la valeur de la PROTECTION (au-dessus de la croissance, de « fer II » et de la recherche, sous les
-- premiers avant-postes), jamais retenue par « production d'abord » (minimal).
B.ARMY_ALERT = 86
B.ARMY_WAR_PCT = 150   -- en guerre : × 1,5 (pvp_test allumé, essai 2 : sans cette règle, Difficile et Impitoyable
                       -- n'attaquaient pas plus que Normal, ordre strict perdu : 2 < 3 = 3 attaques)
-- Besoin prévu d'une matière brute (horizon) : au-delà de SAT_FACTOR fois ce besoin, plus aucune extraction n'est
-- bâtie ni faite au fond (constat du DC). Un plancher évite qu'un besoin nul sature tout.
B.NEED_FLOOR = 100
B.SAT_FACTOR = 3

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- Poids des familles (pour mille, 500 à 2 000) : 1 000 + biais du trait + la moitié des affinités des postures du chef.
--- mix = { { key = posture, w = poids pour mille }, ... } (C.think) ; traits = { curiosite = …, … } (× 1 000).
function B.weights(mix, traits)
  local out = {}
  for _, fam in ipairs(B.FAMILIES) do
    local w = 1000
    local tk = B.TRAIT[fam]
    if traits and tk and traits[tk] then w = w + clamp(math.floor((traits[tk] - 1000) / 2), -250, 250) end
    local aff = 0
    for _, m in ipairs(mix or {}) do
      local a = (B.POSTURE[m.key] or {})[fam] or 0
      aff = aff + math.floor(a * (m.w or 0) / 1000)
    end
    out[fam] = clamp(w + math.floor(aff / 2), B.W_MIN, B.W_MAX)
  end
  return out
end

local function val(base, w) return clamp(math.floor(base * (w or 1000) / 1000), 1, 100) end

--- Ressources clés de la situation (lot IA-G) : { top, fuel, order, optional } en types d'avant-poste.
function B.key(s)
  local k = s and s.key
  if k and k.top and k.fuel then return k end
  return R.FALLBACK_KEY
end

--- Valeur d'amorçage d'un type d'avant-poste : son rang dans le besoin brut (s.key.order), le combustible à part.
function B.boot_value(s, kind)
  local key = B.key(s)
  if kind == key.fuel then return B.BOOT_FUEL end
  for i, k in ipairs(key.order or {}) do
    if k == kind then return B.BOOT_RANK[i] or B.BOOT_RANK[#B.BOOT_RANK] end
  end
  return B.BOOT_RANK[#B.BOOT_RANK]
end

--- Produit de chaque type d'avant-poste et type de chaque produit (données de shared/team/config.lua).
function B.kind_of_product(item)
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    if spec.product == item or spec.resource == item then return kind end
  end
  return nil
end

--- Besoin prévu d'une matière (horizon) : manque des projets + le plancher. `s.need` = { [objet] = n } (dernière
--- pensée). Une matière SATURÉE (stock ≥ B.SAT_FACTOR × besoin) ne génère plus de travail d'extraction.
function B.saturated(s, item)
  -- Lot SCALE : plancher qui suit l'effectif (Br.need_floor : 100 à 8 PNJ, 375 à 30).
  local need = math.max(Br.need_floor(s.workers, B.NEED_FLOOR), (s.need and s.need[item]) or 0)
  return (s.stock[item] or 0) >= B.SAT_FACTOR * need
end

--- Capacités visées par type d'avant-poste (état persistant `st.targets`, mis à jour ici). Amorçage : fer, charbon,
--- cuivre toujours ; pierre seulement si elle manque. « Fer II » dès l'amorçage fait. Croissance : un produit qui manque
--- durablement (st.short_n) fait viser une capacité de plus, jamais pour une ressource saturée.
function B.targets(s, st)
  st.targets = st.targets or {}
  local tg = st.targets
  local key = B.key(s)
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    local cur = tg[kind] or 0
    if cur < 1 then
      local needed = not (key.optional or {})[kind] or (s.stock[spec.product] or 0) < B.NEED_FLOOR
        or (st.short_n or {})[spec.product]
      if needed then cur = 1 end
    end
    tg[kind] = cur
  end
  local boot = (s.cap[key.top] or 0) >= 0.75 and (s.cap[key.fuel] or 0) >= 0.75
  if boot and not st.iron2_set then
    st.iron2_set = true
    tg[key.top] = math.max(tg[key.top] or 0, 2)
    tg[key.fuel] = math.max(tg[key.fuel] or 0, 2)
  end
  -- Lot SCALE : capacités visées au plus par ressource, selon l'effectif (Br.cap_max : 5 jusqu'à 25 PNJ, 6 à 30).
  local grow_max = Br.cap_max(s.workers, B.GROW_MAX)
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local product = T.outposts[kind].product
    local n = (st.short_n or {})[product] or 0
    local short = (st.short or {})[product] or 0
    -- Lot PILE-PRIORITE : le produit d'un cadre ouvert de la pile (fer des tourelles d'un poste sous son minimum, objet d'une
    -- pièce à refaire ; s.focus, shared/ai3/pile.lua) grandit dès qu'il manque durablement, quelle que soit la quantité (la
    -- commande partielle d'une tourelle coûte moins que B.GROW_SHORT : audit C1).
    local grow_short = (s.focus and s.focus[product]) and 1 or B.GROW_SHORT
    if n >= B.GROW_THINKS and short >= grow_short and not B.saturated(s, product) and tg[kind] < grow_max
      and (s.cap[kind] or 0) >= tg[kind] * 0.75 then
      tg[kind] = tg[kind] + 1
      st.short_n[product] = 0
    end
  end
  -- Lot IA-G (bras libres, demande « ils ne scalent pas ») : des PNJ sans tâche (s.idle_grow, règle Gen.ahead_depth) et
  -- aucun manque durable : la ressource NÉCESSAIRE la plus demandée (ordre des ressources clés, déduit du dépliage) dont
  -- le produit n'est pas saturé reçoit une capacité de plus, d'avance (un joueur agrandit ce que ses buts mangeront),
  -- au plus toutes les B.IDLE_GROW_EVERY ; jamais au-delà de B.GROW_MAX ni avant que la capacité visée tourne.
  -- Lot SCALE : la vague suit le nombre de bras libres (s.spare, PNJ sans tâche durables ; Br.wave : une capacité par
  -- Br.HANDS_PER_CAP bras, au plus Br.WAVE_MAX, une par ressource et par vague, dans l'ordre du besoin brut) ; sans ce
  -- nombre (s.idle_grow seul), une capacité par vague comme IA-G.
  if s.idle_grow and (s.tick or 0) - (st.idle_grow_tick or -B.IDLE_GROW_EVERY) >= B.IDLE_GROW_EVERY then
    local wave = s.spare and Br.wave(s.spare) or 1
    local added = 0
    for _, kind in ipairs(key.order or {}) do
      if added >= wave then break end
      local product = T.outposts[kind] and T.outposts[kind].product
      if product and not (key.optional or {})[kind] and not B.saturated(s, product) and (tg[kind] or 0) < grow_max
        and (s.cap[kind] or 0) >= (tg[kind] or 0) * 0.75 then
        tg[kind] = (tg[kind] or 0) + 1
        st.idle_grow_tick = s.tick or 0
        st.idle_grown = (st.idle_grown or 0) + 1
        added = added + 1
      end
    end
  end
  return tg
end

--- Situation de la fonderie pour Br.smelters : entrées de la fonderie (données de shared/team/config.lua), triées.
local SMELT_INPUTS = {}
do
  local ps = {}
  for p in pairs(T.smelter_inputs) do ps[#ps + 1] = p end
  table.sort(ps)
  for _, p in ipairs(ps) do SMELT_INPUTS[#SMELT_INPUTS + 1] = { p, T.smelter_inputs[p][1], T.smelter_inputs[p][2] } end
end
function B.smelt_situation(s)
  return { workers = s.workers, stock = s.stock or {}, smelters = s.smelters, smelters_pending = s.smelters_pending,
    tick = s.tick, smelter_inputs = SMELT_INPUTS }
end

--- Buts de la pensée. s = situation (shared/ai3/cerveau.lua, B.situation) ; rend une liste triée (valeur
--- décroissante, puis clé).
function B.generate(s, st)
  local w = s.weights or {}
  local goals = {}
  local tg = B.targets(s, st)
  local key = B.key(s)
  -- Extraction.
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    local want = tg[kind] or 0
    local have = (s.cap[kind] or 0) + (s.pending[kind] or 0)
    if want > 0 and have < want * 0.75 and not ((s.cap[kind] or 0) > 0 and B.saturated(s, spec.product)) then
      local base
      if (s.cap[kind] or 0) < 0.75 then base = B.boot_value(s, kind)
      elseif want <= 2 and (kind == key.top or kind == key.fuel) then base = B.IRON2
      else base = B.GROW + math.min(20, math.floor(((st.short or {})[spec.product] or 0) / 20)) end
      goals[#goals + 1] = { key = "extraction:" .. kind, family = "extraction", kind = "outpost", outpost = kind,
        value = val(base, w.extraction), want = want, why = spec.product }
    end
  end
  -- Lot SCALE-COMPLET : couverture des gisements OUVERTS (factions). Partie du DC (Écarlate, 0.6.18, 46 min) : cuivre et
  -- charbon « saturés » (stock ≥ B.SAT_FACTOR × besoin) dès 19 et 26 min, donc plus aucun but d'extraction (ci-dessus) :
  -- cuivre resté à 6 foreuses sur 197 tuiles (121 pour mille), charbon à 12 sur 197 (243 pour mille) ; la couverture
  -- d'avance de la capitalisation ne pose que des foreuses ÉLECTRIQUES par le plan directeur (Ca.AHEAD_BURNER faux) : refusée
  -- pour le charbon et la pierre (« aucune fonderie a foreuses pour ce minerai ») et pour le cuivre (« plan directeur occupe »
  -- par les ordres du fer). Ici : tout type dont un avant-poste a encore des places (s.room, ni plein ni au plafond) et qui
  -- n'a pas de but d'extraction à cette pensée reçoit un but « couverture:<type> » qui n'AGRANDIT que l'existant (le plus
  -- proche : EMIT.outpost, extendable ; jamais de build). Garde-fous :
  --   * type optionnel (sans besoin au dépliage, s.key.optional) : rien ;
  --   * combustible : un type dont l'agrandissement brûle du combustible (tous sauf le combustible lui-même) attend tant
  --     que le combustible MANQUE (st.short) : les brûleurs ajoutés vivraient du charbon porté (banc p2 du lot CAPIB : 75 à
  --     102 foreuses sans charbon) ; le combustible, lui, se ravitaille sur sa propre production ;
  --   * produit saturé PENDANT qu'une autre matière manque (st.other_short, critère A5) : le but ne prend que le reste du
  --     stock virtuel, sans rien faire fabriquer (g.take_only) : la matière va d'abord à ce qui manque.
  -- Intégration 0.6.20 (SCALE-COMPLET x PLAFOND-FOREUSES) : sans plafond de foreuses, la couverture restait ouverte tant qu'un
  -- gisement n'était pas couvert à KAPPA et mangeait le fer qu'une recrue accumule (la recrue n'est réservée que quand elle se paie) :
  -- au moteur simulé (ia1_scale_test), Écarlate et Ambre finissaient à 22 et 24 PNJ en 12 min au lieu de 30 et 29. La couverture,
  -- « au-delà du besoin », attend que l'effectif voulu soit atteint (ou la recrue retenue ou bloquée).
  if not s.is_player and not s.recruiting then
    local emitted = {}
    for _, g in ipairs(goals) do if g.outpost then emitted[g.outpost] = true end end
    local fuel_kind = key.fuel
    local fuel_product = fuel_kind and T.outposts[fuel_kind] and T.outposts[fuel_kind].product
    local fuel_short = fuel_product ~= nil and ((st.short or {})[fuel_product] or 0) > 0
    -- Relecture : un produit COUVERT par un module fini (st.covered, lot IA3-e, posé par C.think à la pensée précédente) perd
    -- ses tournées ordinaires (C.think les retire) : des brûleurs ajoutés là ne seraient jamais ravitaillés ni vidés.
    local covered = st.covered or {}
    for _, kind in ipairs(T.OUTPOST_ORDER) do
      local spec = T.outposts[kind]
      if (s.room or {})[kind] and not emitted[kind] and not (key.optional or {})[kind]
        and not (kind ~= fuel_kind and fuel_short) and not covered[spec.product] then
        local take_only = st.other_short == true and B.saturated(s, spec.product) or nil
        goals[#goals + 1] = { key = "couverture:" .. kind, family = "extraction", kind = "outpost", outpost = kind,
          extend_only = true, take_only = take_only, fond = true,
          value = math.min(B.COVER_MAX, val(B.COVER, w.extraction)), why = spec.product }
      end
    end
  end
  -- Capital : fonderie du QG.
  local smelters_want = s.is_player and 2 or B.SMELTERS_WANT
  -- Lot SCALE (capacité de FONTE) : une faction dont une plaque manque alors que son minerai attend au coffre agrandit sa
  -- fonderie, par vagues, jusqu'à la moitié de son effectif (shared/ai3/bras.lua, Br.smelters).
  if not s.is_player then smelters_want = Br.smelters(B.smelt_situation(s), st, B.SMELTERS_WANT, B.GROW_THINKS) end
  if (s.smelters or 0) + (s.smelters_pending or 0) < smelters_want and (s.cap[key.top] or 0) >= 0.75 then
    goals[#goals + 1] = { key = "capital:fonderie", family = "capital", kind = "smelters",
      n = smelters_want - (s.smelters or 0) - (s.smelters_pending or 0), value = val(B.SMELTERS, w.capital) }
  end
  -- Défense : réserve de munitions. Famille PERMANENTE (comme l'armée) : toujours dépliée à son rang de valeur, sans
  -- prendre de place parmi les K projets (la réserve d'un joueur, H10 ; l'armée qui grandit en fond comme avant).
  -- Amorçage d'abord : fer et charbon en route avant la réserve et l'armée de départ (l'ordre de l'ancienne échelle :
  -- charbon, fer, … puis « defense » et « army » ; moteur simulé de pvp_test, essai 3 de ce lot : 240 fers de chargeurs
  -- dès la 1re minute, fer à 35 à 5 min, armée à 0), sauf menace ou guerre.
  local boot = ((s.cap[key.top] or 0) >= 0.75 and (s.cap[key.fuel] or 0) >= 0.75) or s.at_war
  local ammo = T.turret_ammo
  if boot and (s.stock[ammo] or 0) < B.AMMO_STOCK then
    goals[#goals + 1] = { key = "defense:munitions", family = "defense", kind = "stock", item = ammo,
      n = B.AMMO_STOCK - (s.stock[ammo] or 0), value = val(B.AMMO, w.defense), permanent = true,
      -- lot INTEG-ECONOMIE (D1) : sous B.AMMO_MIN, la part jusqu'au minimum reste payée même quand la production passe d'abord
      minimal_n = math.max(0, B.AMMO_MIN - (s.stock[ammo] or 0)) }
  end
  -- Recherche (factions) : la technologie choisie par le runtime. ÉCONOMIE D'ABORD (revue B3 : IA2-a, 3e essai, une
  -- faction qui payait sa recherche avant son fer II s'est effondrée ; moteur simulé de pvp_test, essai 3 de ce lot :
  -- recherche à 81 avant le fer II, fer à 0 pendant 10 min, avant-poste de fer bloqué faute de tourelles, armée à 0) :
  -- tant que « fer II » n'est pas atteint (s.economy_done), sa valeur est plafonnée à B.RESEARCH_PRE, sous
  -- l'extraction, l'armée de départ et la réserve de munitions.
  local r = s.research
  if r and r.tech then
    local v = val(B.RESEARCH + (r.palier and B.RESEARCH_PALIER or 0), w.recherche)
    -- Lot IA-V2 (critère K1, constat du DC « pas de vraie recherche ») : une recherche dont il reste à dépenser au plus
    -- B.RESEARCH_CHEAP plaques de fer (palier 1 : un laboratoire et 10 packs rouges, environ 56 plaques) n'est pas
    -- plafonnée : un joueur pose son laboratoire dès les premières minutes, l'économie n'en souffre pas (les packs ne
    -- descendent toujours pas sous le plancher de fer, ctx.iron_floor). Moteur réel, ia3c-reduit, 27/10 : plafonnée
    -- jusqu'au fer II (72 min), palier 1 à 16-20 min.
    local cheap = r.iron_cost ~= nil and r.iron_cost <= B.RESEARCH_CHEAP
    -- Lot IA3-e : une recherche qui débloque un objet que l'automatisation attend (r.for_auto : poteau moyen d'une
    -- fonderie électrique) n'est pas plafonnée : elle libère des bras (le plancher de fer des packs reste).
    if not s.economy_done and v > B.RESEARCH_PRE and not cheap and not r.for_auto then v = B.RESEARCH_PRE end
    -- Lot IA-G : une recherche PEU CHÈRE (même règle) est un travail COURT : elle est servie avant les familles
    -- permanentes (armée, réserve) ; voir P.update (le plus court d'abord).
    goals[#goals + 1] = { key = "recherche", family = "recherche", kind = "research", tech = r.tech, value = v,
      short = cheap or nil }
  end
  -- Armée (factions).
  -- Une faction EN GUERRE (déclarée au joueur, ou posture guerrière du chef) s'arme d'abord : valeur × B.ARMY_WAR_PCT.
  if boot and not s.is_player and (s.soldiers_max or 0) > 0 then
    local first = math.min(B.ARMY_FIRST_N, s.soldiers_max)
    local war = s.at_war and B.ARMY_WAR_PCT or 100
    local alert_need = s.army_alert and math.min(s.army_need or 0, s.soldiers_max) or 0
    if (s.soldiers or 0) < alert_need then
      goals[#goals + 1] = { key = "armee", family = "armee", kind = "army", target = alert_need,
        value = val(B.ARMY_ALERT, w.armee), permanent = true, minimal = true, alert = true }
    elseif (s.soldiers or 0) < first then
      -- lot INTEG-ECONOMIE (D1) : les premiers soldats sont la défense MINIMALE, jamais retenue par « production d'abord »
      goals[#goals + 1] = { key = "armee", family = "armee", kind = "army", target = first,
        value = val(math.floor(B.ARMY_FIRST * war / 100), w.armee), permanent = true, minimal = true }
    elseif (s.soldiers or 0) < (s.army_target or 0) then
      goals[#goals + 1] = { key = "armee", family = "armee", kind = "army", target = s.army_target,
        value = val(math.floor(B.ARMY_MORE * war / 100), w.armee), permanent = true }
    end
  end
  table.sort(goals, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.key < b.key
  end)
  return goals
end

return B
