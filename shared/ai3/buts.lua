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
B.BOOT = { coal = 90, iron = 92, copper = 82, stone = 70 }   -- premier avant-poste d'une ressource qui manque
B.IRON2 = 66        -- « fer II » (2 capacités de fer et 2 de charbon) : l'économie avant la recherche (revue B3)
B.GROW = 55         -- croissance d'une ressource qui manque durablement (goulot)
B.GROW_SHORT = 100  -- manque (objets) qui compte comme « durable » …
B.GROW_THINKS = 6   -- … pendant au moins 6 pensées de suite (30 s)
B.GROW_MAX = 5      -- capacités visées au plus, par ressource
B.SMELTERS = 45
B.SMELTERS_WANT = 4
B.AMMO = 55
B.AMMO_STOCK = 60   -- réserve de munitions visée (ancienne marche « defense »)
B.RESEARCH = 62
B.RESEARCH_PALIER = 14 -- la technologie suivante ouvre un pack (« la recherche vaut ce qu'elle débloque », H9)
B.ARMY_FIRST = 58      -- les 10 premiers soldats (ancienne marche « army »)
B.ARMY_FIRST_N = 10
B.ARMY_MORE = 40
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
  local need = math.max(B.NEED_FLOOR, (s.need and s.need[item]) or 0)
  return (s.stock[item] or 0) >= B.SAT_FACTOR * need
end

--- Capacités visées par type d'avant-poste (état persistant `st.targets`, mis à jour ici). Amorçage : fer, charbon,
--- cuivre toujours ; pierre seulement si elle manque. « Fer II » dès l'amorçage fait. Croissance : un produit qui manque
--- durablement (st.short_n) fait viser une capacité de plus, jamais pour une ressource saturée.
function B.targets(s, st)
  st.targets = st.targets or {}
  local tg = st.targets
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    local cur = tg[kind] or 0
    if cur < 1 then
      local needed = kind ~= "stone" or (s.stock[spec.product] or 0) < B.NEED_FLOOR or (st.short_n or {})[spec.product]
      if needed then cur = 1 end
    end
    tg[kind] = cur
  end
  local boot = (s.cap.iron or 0) >= 0.75 and (s.cap.coal or 0) >= 0.75
  if boot and not st.iron2_set then
    st.iron2_set = true
    tg.iron = math.max(tg.iron, 2)
    tg.coal = math.max(tg.coal, 2)
  end
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local product = T.outposts[kind].product
    local n = (st.short_n or {})[product] or 0
    local short = (st.short or {})[product] or 0
    if n >= B.GROW_THINKS and short >= B.GROW_SHORT and not B.saturated(s, product) and tg[kind] < B.GROW_MAX
      and (s.cap[kind] or 0) >= tg[kind] * 0.75 then
      tg[kind] = tg[kind] + 1
      st.short_n[product] = 0
    end
  end
  return tg
end

--- Buts de la pensée. s = situation (shared/ai3/cerveau.lua, B.situation) ; rend une liste triée (valeur
--- décroissante, puis clé).
function B.generate(s, st)
  local w = s.weights or {}
  local goals = {}
  local tg = B.targets(s, st)
  -- Extraction.
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    local want = tg[kind] or 0
    local have = (s.cap[kind] or 0) + (s.pending[kind] or 0)
    if want > 0 and have < want * 0.75 and not ((s.cap[kind] or 0) > 0 and B.saturated(s, spec.product)) then
      local base
      if (s.cap[kind] or 0) < 0.75 then base = B.BOOT[kind] or B.GROW
      elseif want <= 2 and (kind == "iron" or kind == "coal") then base = B.IRON2
      else base = B.GROW + math.min(20, math.floor(((st.short or {})[spec.product] or 0) / 20)) end
      goals[#goals + 1] = { key = "extraction:" .. kind, family = "extraction", kind = "outpost", outpost = kind,
        value = val(base, w.extraction), want = want, why = spec.product }
    end
  end
  -- Capital : fonderie du QG.
  local smelters_want = s.is_player and 2 or B.SMELTERS_WANT
  if (s.smelters or 0) + (s.smelters_pending or 0) < smelters_want and (s.cap.iron or 0) >= 0.75 then
    goals[#goals + 1] = { key = "capital:fonderie", family = "capital", kind = "smelters",
      n = smelters_want - (s.smelters or 0) - (s.smelters_pending or 0), value = val(B.SMELTERS, w.capital) }
  end
  -- Défense : réserve de munitions.
  local ammo = T.turret_ammo
  if (s.stock[ammo] or 0) < B.AMMO_STOCK then
    goals[#goals + 1] = { key = "defense:munitions", family = "defense", kind = "stock", item = ammo,
      n = B.AMMO_STOCK - (s.stock[ammo] or 0), value = val(B.AMMO, w.defense) }
  end
  -- Recherche (factions) : la technologie choisie par le runtime.
  local r = s.research
  if r and r.tech then
    goals[#goals + 1] = { key = "recherche", family = "recherche", kind = "research", tech = r.tech,
      value = val(B.RESEARCH + (r.palier and B.RESEARCH_PALIER or 0), w.recherche) }
  end
  -- Armée (factions).
  if not s.is_player and (s.soldiers_max or 0) > 0 then
    local first = math.min(B.ARMY_FIRST_N, s.soldiers_max)
    if (s.soldiers or 0) < first then
      goals[#goals + 1] = { key = "armee", family = "armee", kind = "army", target = first,
        value = val(B.ARMY_FIRST, w.armee) }
    elseif (s.soldiers or 0) < (s.army_target or 0) then
      goals[#goals + 1] = { key = "armee", family = "armee", kind = "army", target = s.army_target,
        value = val(B.ARMY_MORE, w.armee) }
    end
  end
  table.sort(goals, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.key < b.key
  end)
  return goals
end

return B
