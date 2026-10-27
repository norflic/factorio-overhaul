--[[
  Lot SCALE « passage à l'échelle » (docs/IA_ATTENDUS.md B1 et A7 ; demande du DC du 26/10 : « beaucoup d'agents ne
  font rien […] Ils ne scalent pas alors qu'ils pourraient ») : le TRAVAIL DES BRAS LIBRES. PUR (aucune API Factorio),
  aucun nom du jeu (règle anti-échelle d'IA-G, tests/iag_test.lua §8) : les objets, ressources et recettes arrivent du
  runtime et des données du mod (shared/team/config.lua) par la situation `s` du cerveau (shared/ai3/cerveau.lua).

  Ce qu'un joueur fait de bras libres : il ne les laisse pas au coffre, il agrandit ce que ses buts mangeront. Les
  bras libres (PNJ sans tâche DURABLES : Gen.spare_depth, 12 pensées de suite, jamais avant 5 min) ouvrent, EN MÊME
  TEMPS, des buts d'avance proportionnés à leur nombre, chacun déplié en tâches par les méthodes existantes :
    1. FONTE : une plaque qui manque alors que son minerai attend au coffre (au-dessus de ce que la fonderie absorbe)
       a pour goulot la fonderie du QG, pas l'extraction : des fours de plus (moteur réel, IA-G g7, 30 PNJ : minerai de
       fer SATURÉ au coffre, plaque de fer en manque, 4 fours au QG, 15 à 17 PNJ sur 30 sans tâche) ;
    2. EXTRACTION : une capacité de plus par Br.HANDS_PER_CAP bras libres, pour les ressources nécessaires dont le
       produit n'est pas saturé, dans l'ordre du besoin brut (ressources clés déduites du dépliage) ;
    3. RECHERCHE : les packs des technologies suivantes d'avance (Gen.lookahead) : la profondeur suit les bras libres
       et l'effectif (Br.depth_max) au lieu d'un plafond fixe de 3 ;
    4. ARMÉE selon le CARACTÈRE : des soldats d'avance, d'autant plus que la faction est agressive (trait
       « agressivite », IA2-0), quand sa matière clé ne manque pas.
  Les bornes suivent l'EFFECTIF (pour cent de PNJ), jamais un nombre de bâtiments écrit pour une partie : 8 PNJ rendent
  les bornes d'avant (5 capacités, 4 fours, 3 recherches), 30 PNJ des bornes plus hautes.
  La recrue (règle d'IA3-d, shared/ai3/effectif.lua) suit le travail en attente : ce travail d'avance qui attend au-delà
  des bras libres fait venir des recrues, qui ne viennent jamais quand des PNJ restent sans tâche.

  Déterminisme : entiers, listes données triées par l'appelant, aucun pairs, aucun hasard, aucun temps mesuré.
]]

local Br = {}

-- 0. Bras libres DURABLES : moyenne glissante des PNJ sans tâche (en dixièmes, entiers), sur environ Br.EMA_THINKS
-- pensées (1 min). Diagnostic du lot (moteur simulé, 4 factions à 30 PNJ, minutes 18 à 20 : 7,8 à 9,5 PNJ sans tâche
-- par pensée chez deux factions, AUCUNE tâche libre, et AUCUN travail d'avance : la règle d'IA-G comptait les pensées DE
-- SUITE au-dessus de 25 % de l'effectif ; une seule pensée sous le seuil la remettait à zéro).
Br.EMA_THINKS = 12
-- 2. Extraction d'avance.
Br.HANDS_PER_CAP = 3      -- une capacité de plus par 3 bras libres (pose, agrandissements, tournées de ses foreuses)
Br.WAVE_MAX = 3           -- au plus 3 capacités de plus par vague (toutes ressources)
Br.CAP_PCT = 20           -- capacités visées au plus par ressource : 20 % de l'effectif, au moins le plafond d'avant (5)
-- 1. Fonte.
Br.SMELT_PCT = 50         -- fours du QG au plus : la moitié de l'effectif (8 PNJ : 4 ; 30 PNJ : 15), au moins le défaut
Br.SMELT_STEP = 2         -- fours de plus par vague
Br.SMELT_EVERY = 3600     -- une vague de fours au plus par minute
Br.ORE_WAIT = 2           -- … quand le minerai au coffre couvre au moins 2 fois ce qu'il faut pour le manque de plaques
-- 3. Recherche d'avance.
Br.DEPTH_PCT = 15         -- recherches suivantes préparées au plus : 15 % de l'effectif (8 : 1, plancher 3 ; 30 : 4)
-- 3 bis. Laboratoires : une recherche se paie en packs ET en temps de laboratoire ; des bras libres font les packs, des
-- laboratoires de plus raccourcissent la recherche (moteur réel, s0-ia1-scale, Émeraude à 30 PNJ : tout saturé, 1 100
-- fer libres, la recherche seule ouverte avec 3 laboratoires au plus, 10 PNJ sans tâche).
Br.LABS_PCT = 20          -- laboratoires au plus : 20 % de l'effectif (8 PNJ : 2, plancher 3 ; 30 PNJ : 6)
Br.LAB_WINDOW_MIN_PCT = 25 -- la fenêtre « un laboratoire par N s de recherche restante » descend au plus à 25 %
-- 5. Besoin de réserve : le plancher du besoin prévu d'une matière (au-delà de 3 fois, elle est « saturée » : plus
-- d'extraction) suit l'effectif ; 8 PNJ (le départ, D-18) est la référence. Une équipe de 30 consomme environ 4 fois
-- plus vite : sa réserve « suffisante » est 4 fois plus grande (moteur réel, s0-ia1-scale : à 30 PNJ, fer, cuivre,
-- charbon et pierre saturés à 1 100 plaques de fer libres, aucun but d'extraction, 10 PNJ sans tâche).
Br.REF_WORKERS = 8
-- 4. Armée d'avance.
Br.ARMY_STEP_PCT = 10     -- soldats visés de plus : 10 % du plafond × agressivité (pour mille) : 600 -> + 6 %,
                          -- 1 000 -> + 10 %, 1 400 -> + 14 % ; jamais au-delà du plafond

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function pct(n, p) return math.floor(((n or 0) * p + 99) / 100) end -- arrondi au-dessus

--- Moyenne glissante des PNJ sans tâche (dixièmes) : prev (nil à la première pensée) et idle (PNJ sans tâche).
function Br.smooth(prev, idle)
  local x = (idle or 0) * 10
  if prev == nil then return x end
  local d = x - prev
  local step = d >= 0 and math.floor(d / Br.EMA_THINKS) or -math.floor(-d / Br.EMA_THINKS)
  if step == 0 and d ~= 0 then step = d > 0 and 1 or -1 end
  return prev + step
end

--- Plancher du besoin prévu d'une matière : `floor` × effectif ÷ Br.REF_WORKERS, au moins `floor`.
function Br.need_floor(workers, floor)
  return math.max(floor or 0, math.floor((floor or 0) * (workers or 0) / Br.REF_WORKERS))
end

--- Capacités visées au plus par ressource : Br.CAP_PCT % de l'effectif, au moins `floor` (le plafond d'avant).
function Br.cap_max(workers, floor) return math.max(floor or 0, pct(workers, Br.CAP_PCT)) end

--- Fours du QG au plus : Br.SMELT_PCT % de l'effectif, au moins `floor` (le défaut d'avant).
function Br.smelt_max(workers, floor) return math.max(floor or 0, pct(workers, Br.SMELT_PCT)) end

--- Recherches suivantes préparées d'avance au plus : Br.DEPTH_PCT % de l'effectif, au moins `floor` (3, IA-G).
function Br.depth_max(workers, floor) return math.max(floor or 0, pct(workers, Br.DEPTH_PCT)) end

--- Laboratoires au plus : Br.LABS_PCT % de l'effectif, au moins `floor` (3, IA3-c).
function Br.labs_max(workers, floor) return math.max(floor or 0, pct(workers, Br.LABS_PCT)) end

--- Fenêtre d'un laboratoire de plus (secondes de recherche restante par laboratoire) : `window` sans bras libres ;
--- avec `spare` bras libres, window × HANDS_PER_CAP / (HANDS_PER_CAP + spare), au moins Br.LAB_WINDOW_MIN_PCT %.
function Br.lab_window(window, spare)
  local w = math.floor((window or 0) * Br.HANDS_PER_CAP / (Br.HANDS_PER_CAP + math.max(0, spare or 0)))
  return math.max(math.floor((window or 0) * Br.LAB_WINDOW_MIN_PCT / 100), w)
end

--- Capacités de plus dans une vague : une par Br.HANDS_PER_CAP bras libres (au moins une), au plus Br.WAVE_MAX.
function Br.wave(spare)
  if (spare or 0) <= 0 then return 0 end
  return clamp(math.floor((spare + Br.HANDS_PER_CAP - 1) / Br.HANDS_PER_CAP), 1, Br.WAVE_MAX)
end

--- Fours visés (état persistant st.smelt_target, nombres) : `base` (défaut de la famille capital) ; une vague de
--- Br.SMELT_STEP fours de plus quand une plaque fondue au QG MANQUE durablement (st.short_n ≥ grow_thinks) alors que son
--- minerai attend au coffre (stock ≥ Br.ORE_WAIT × ce qu'il faut pour le manque), au plus une vague par Br.SMELT_EVERY,
--- jamais au-delà de Br.smelt_max ni avant que les fours visés soient posés. Rend le nombre de fours visés.
--- s = { workers, stock, smelters, smelters_pending, tick, smelter_inputs = { {plaque, minerai, quantité}, ... } triée },
--- shortage : { [plaque] = manque } (st.short), short_n : { [plaque] = pensées de suite }.
function Br.smelters(s, st, base, grow_thinks)
  local target = math.max(base or 0, st.smelt_target or 0)
  local have = (s.smelters or 0) + (s.smelters_pending or 0)
  local max = Br.smelt_max(s.workers, base)
  if target > max then target = max end
  local due = (s.tick or 0) - (st.smelt_tick or -Br.SMELT_EVERY) >= Br.SMELT_EVERY
  if due and have >= target and target < max then
    for _, it in ipairs(s.smelter_inputs or {}) do
      local plate, ore, per = it[1], it[2], it[3] or 1
      local short = (st.short or {})[plate] or 0
      local n = (st.short_n or {})[plate] or 0
      if short > 0 and n >= (grow_thinks or 0) and (s.stock[ore] or 0) >= Br.ORE_WAIT * short * per then
        target = math.min(max, target + Br.SMELT_STEP)
        st.smelt_tick = s.tick or 0
        st.smelt_waves = (st.smelt_waves or 0) + 1
        st.smelt_why = plate
        break
      end
    end
  end
  st.smelt_target = target
  return target
end

--- Soldats visés d'avance pour une faction (caractère) : la cible du chef, plus Br.ARMY_STEP_PCT % du plafond × son
--- agressivité (pour mille), quand des bras sont libres et que la matière clé ne manque pas ; jamais au-delà du
--- plafond. Rend la cible.
function Br.army(target, soldiers_max, agressivite, spare, key_short)
  target = target or 0
  if (spare or 0) <= 0 or key_short then return target end
  local a = agressivite or 1000
  if a < 0 then a = 0 end
  local add = math.floor((soldiers_max or 0) * Br.ARMY_STEP_PCT * a / 100 / 1000)
  return math.min(soldiers_max or 0, target + add)
end

return Br
