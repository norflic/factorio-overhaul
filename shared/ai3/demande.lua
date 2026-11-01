--[[
  Lot C2 « DEMANDE OUVERTE » (demande du DC du 1/11 : « assurez moi que les bases s ameliore a l infini »). Mesure (partie EVOLUTION,
  Emerald à 105 min) : 24 700 fer et 33 000 MU de stock, budget 0 et AUCUN ordre pendant 60 min. Le budget n'est pas le mur : la DEMANDE
  l'est. La capitalisation (shared/ai3/capitalisation.lua, Ca.options) n'ouvre une option que pour un objet que quelqu'un demande
  (puits du mall, besoin des buts, file de recherche) : une base « finie » ne veut plus rien, donc plus rien ne s'ouvre.

  CAUSE en 3 lignes (AUDIT_PLAFONDS n°1, 2, 3, 5, 6, 7, 8, 9) :
    1. Ca.requirements (capitalisation.lua) ne propage que les puits, les buts, les ordres ouverts et les packs de la file ; un stock qui
       dort n'est la demande de personne, et B.saturated (buts.lua:150) le déclare « saturé » contre un PLANCHER (3 × 100 plaques).
    2. A.decide (automatiser.lua) refuse un module dont la charge à la main est <= A.LOAD_MIN (0,25 PNJ) : une base qui automatise pour NE
       PAS charger ne passe jamais ; la voie de minerai n'a de tapis qu'au-delà de 1 minerai/s (P.AUTO_FLOW) ; Tmax est un caractère fixe.
    3. Les emplacements de chantier (A.MAX_OPEN + stock riche) et les capacités visées (Br.cap_max, labos, fours) sont des CONSTANTES ou des
       parts de l'effectif, alors que l'effectif est lui-même borné par le travail disponible (12/30 « inactifs »).

  Ce que fait cette règle (PURE : aucune API Factorio, AUCUN nom d'objet, de machine, de recette ou de technologie : soumise à l'anti-échelle de
  tests/iag_test.lua §8 ; les candidats sont LUS dans le relevé de données Ca.data) :
    1. PUITS OUVERT (Dm.step). Le stock « dort » quand il dépasse Dm.DORM_FACTOR (2, critère 3) fois le besoin évalué d'I1 (shared/ai3/
       reserve.lua : ce que le noyau garde). Tant qu'il dort, la base se fixe un débit visé EN PLUS de sa consommation, p (MU/min), qui
       croît de Dm.GROW ‰ par cycle ; il est plafonné par ce que le stock libre nourrit pendant Dm.DRAIN_H minutes ET par Dm.Y_MULT fois la
       production mesurée (le plafond monte avec la production : croissance géométrique, sans borne fixe). Quand le stock ne dort plus, p
       redescend de Dm.DECAY ‰ par cycle. Le puits est une liste de puits ÉLASTIQUES d'objets, que Ca.decide ajoute à ses puits :
         - SCIENCE : les objets d'entrée des laboratoires (D.packs), tant qu'il reste des technologies à la file ;
         - ÉQUIPEMENT : les biens d'équipement (fabriques, foreuses, laboratoires) les plus chers que l'équipe sait obtenir, les plus
           utiles à la croissance elle-même (les chantiers les consomment : le capital fabrique le capital).
       La part de chaque classe est égale ; dans une classe, égale en MU. Sans technologie restante (arbre fini), toute la part va à
       l'équipement ; les technologies à formule (n°18), les matières nouvelles et les packs suivants sont les destinations suivantes, que la
       cause écrit (elles relèvent de shared/ai3/general.lua et de l'exploration, hors de ce lot).
    2. SATURATION relative (Dm.sat_need) : une matière n'est saturée qu'au-delà de B.SAT_FACTOR × le plus grand du plancher, du besoin des buts
       et du DÉBIT DU PUITS × Dm.SAT_H minutes (le flux que la capitalisation a calculé pour la matière, puits compris).
    3. DÉCISION sur le débit voulu : Dm.load met à l'échelle la charge à la main mesurée (au débit mesuré) sur le débit voulu ; Dm.belt_flow
       fixe le seuil du tapis par le COÛT RÉEL de la voie (pose, matières) contre le gain des porteurs, à Tmax ; Dm.tmax prolonge le retour
       accepté de la durée pendant laquelle le stock dormant dormirait (son coût d'opportunité est nul).
    4. DÉBIT DE CONSTRUCTION : Dm.slots ajoute des emplacements de chantier selon les bras libres et les ordres RETENUS faute de place
       (jamais plus que les bras n'en occupent : un chantier neuf exige des bras libres) ; Dm.extra_cap ajoute des capacités (labos, fours,
       extraction) selon les bras libres. Plafond de sûreté Dm.SLOTS_HARD (calcul et pose : K10 à part).
  Ce que la règle NE fait PAS : elle ne touche ni la défense, ni la réparation, ni le noyau d'I1 (le puits ne se nourrit que du stock LIBRE
  hors besoin) ; menacé, ou réglage maître éteint, l'appelant n'appelle pas Dm.step.
  Déterminisme : listes triées (valeur décroissante puis nom), entiers et flottants calculés dans un ordre fixe, aucun hasard, aucun temps
  mesuré, aucune horloge ; l'état `st` ne garde que des nombres.
]]

local Dm = {}

Dm.DORM_FACTOR = 2     -- critère 3 : le stock dort au-delà de 2 fois le besoin évalué
Dm.NEED_MIN_MU = 1     -- MU : plancher du besoin évalué (un besoin nul ne rend pas tout stock « dormant » à l'infini)
Dm.GROW = 100          -- ‰ par cycle (1 min) : croissance du débit visé tant que le stock dort
Dm.DECAY = 50          -- ‰ par cycle : décroissance quand le stock ne dort plus
Dm.SEED_PCT = 5        -- % du plafond : première valeur du débit visé
Dm.DRAIN_H = 60        -- minutes : le stock libre doit pouvoir nourrir le débit visé pendant ce temps
Dm.Y_MULT = 4          -- le débit visé ne dépasse jamais 4 fois la production mesurée (le plafond suit la production)
Dm.Y_FLOOR = 10        -- MU/min : production comptée au moins (une base à l'arrêt a quand même un plafond)
Dm.EQUIP_MAX = 3       -- biens d'équipement au plus dans le puits (les plus chers que l'équipe sait obtenir)
Dm.EPS = 1e-9
Dm.P_MIN = 0.01        -- MU/min : sous ce débit visé, le puits est fermé
Dm.SAT_H = 10          -- minutes de débit du puits qu'une matière saturée doit couvrir au moins (comme Ca.H_GOALS)
Dm.TMAX_CAP = 120      -- minutes : le retour accepté ne dépasse jamais cela, quelle que soit la durée de sommeil
Dm.HANDS_PER_SITE = 2  -- bras libres par chantier de plus
Dm.SLOTS_HARD = 8      -- emplacements de chantier au plus, quels que soient les bras (calcul et pose ; à mesurer en K10)
Dm.HANDS_PER_CAP = 3   -- bras libres par capacité de plus (comme Br.HANDS_PER_CAP)
Dm.CAP_EXTRA_MAX = 6   -- capacités de plus au plus, par ressource, laboratoire ou lot de fours

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

---------------------------------------------------------------------------------------------------
-- Lecture des données
---------------------------------------------------------------------------------------------------
--- Candidats du puits, LUS dans le relevé de données D (Ca.data) : { { item, mu, class } } triés (classe, MU décroissant, nom).
--- ok(objet) : l'équipe sait-elle l'obtenir ? (Ca.obtainable). Science : les entrées des laboratoires (D.packs) ; équipement : les objets
--- des fabriques, foreuses et laboratoires du relevé (hors packs), les Dm.EQUIP_MAX plus chers.
function Dm.candidates(D, ok)
  local out = { science = {}, equipement = {} }
  if type(D) ~= "table" then return out end
  local mu = D.mu or {}
  for _, p in ipairs(sorted_keys(D.packs)) do
    if (mu[p] or 0) > 0 and ok(p) then out.science[#out.science + 1] = { item = p, mu = mu[p], class = "science" } end
  end
  local seen = {}
  for _, list in ipairs({ D.makers or {}, D.drills or {}, D.labs or {} }) do
    for _, m in ipairs(list) do
      local i = m.item
      if i and not seen[i] and not (D.packs or {})[i] and (mu[i] or 0) > 0 and ok(i) then
        seen[i] = true
        out.equipement[#out.equipement + 1] = { item = i, mu = mu[i], class = "equipement" }
      end
    end
  end
  table.sort(out.equipement, function(a, b)
    if a.mu ~= b.mu then return a.mu > b.mu end
    return a.item < b.item
  end)
  while #out.equipement > Dm.EQUIP_MAX do table.remove(out.equipement) end
  return out
end

---------------------------------------------------------------------------------------------------
-- 1. Le puits ouvert
---------------------------------------------------------------------------------------------------
--- Le stock dort-il ? stock_mu > Dm.DORM_FACTOR × max(besoin évalué, Dm.NEED_MIN_MU).
function Dm.dormant(stock_mu, need_mu)
  return (stock_mu or 0) > Dm.DORM_FACTOR * math.max(need_mu or 0, Dm.NEED_MIN_MU) + Dm.EPS
end

--- Un cycle. st = état (nombres : p, dormant_cycles) ; inp = { stock_mu (stock convertible, besoin compris), free_mu (stock hors besoin),
--- Y (MU/min produits), cands = Dm.candidates(...), research = vrai s'il reste des technologies à la file }.
--- Rend { dormant, p, cap, cap_why, sinks = { { item, rate, want, elastic, class } }, classes = { noms }, tmax_sleep, left (MU du stock qui
--- dort : leur coût d'opportunité est nul, la capitalisation les retire du coût du retour et les entame ordre après ordre), cause, need_mu }.
function Dm.new() return { p = 0, dormant_cycles = 0 } end

function Dm.step(st, inp)
  st.p = st.p or 0
  st.dormant_cycles = st.dormant_cycles or 0
  local stock_mu, free_mu = inp.stock_mu or 0, math.max(0, inp.free_mu or 0)
  local need_mu = math.max(0, stock_mu - free_mu)
  local y = math.max(inp.Y or 0, Dm.Y_FLOOR)
  local by_stock, by_prod = free_mu / Dm.DRAIN_H, Dm.Y_MULT * y
  local cap, cap_why = by_stock, "stock libre / " .. Dm.DRAIN_H .. " min"
  if by_prod < cap then cap, cap_why = by_prod, Dm.Y_MULT .. " x production" end
  local dormant = Dm.dormant(stock_mu, need_mu) and free_mu > 0
  local p = st.p
  if dormant then
    st.dormant_cycles = st.dormant_cycles + 1
    p = (p > Dm.EPS) and p * (1000 + Dm.GROW) / 1000 or cap * Dm.SEED_PCT / 100
  else
    st.dormant_cycles = 0
    p = p * (1000 - Dm.DECAY) / 1000
  end
  if p > cap then p = cap end
  if p < Dm.P_MIN then p = 0 end
  st.p = p
  local out = { dormant = dormant, p = p, cap = cap, cap_why = cap_why, sinks = {}, classes = {}, need_mu = need_mu,
    tmax_sleep = dormant and (free_mu / y) or 0,
    left = dormant and math.max(0, stock_mu - Dm.DORM_FACTOR * math.max(need_mu, Dm.NEED_MIN_MU)) or 0 }
  out.left0 = out.left -- (le stock qui dort au départ du cycle ; `left` s'use ordre après ordre)
  if p <= 0 then
    out.cause = dormant and "puits : stock dormant mais rien a ouvrir (plafond nul)" or "puits ferme : le stock ne dort pas"
    return out
  end
  local cands = inp.cands or {}
  local classes = {}
  if inp.research and #(cands.science or {}) > 0 then classes[#classes + 1] = "science" end
  if #(cands.equipement or {}) > 0 then classes[#classes + 1] = "equipement" end
  out.classes = classes
  if #classes == 0 then
    out.cause = "puits : aucune destination (ni technologie restante ni bien d'equipement obtenable) ; suite : technologies a formule, matieres nouvelles"
    return out
  end
  local share = p / #classes
  local names = {}
  for _, c in ipairs(classes) do
    local list = cands[c]
    local each = share / #list
    for _, it in ipairs(list) do
      local rate = each / it.mu
      out.sinks[#out.sinks + 1] = { item = it.item, rate = rate, want = rate, elastic = true, class = c }
      names[#names + 1] = it.item
    end
  end
  table.sort(out.sinks, function(a, b) return a.item < b.item end)
  out.cause = string.format("puits ouvert : stock %d MU > %d x besoin %d MU, debit vise +%.1f MU/min (plafond %.1f : %s, %d cycle(s)) vers %s%s",
    math.floor(stock_mu), Dm.DORM_FACTOR, math.floor(need_mu), p, cap, cap_why, st.dormant_cycles, table.concat(classes, "+"),
    (inp.research or #(cands.science or {}) == 0) and "" or " (arbre fini : suite = technologies a formule, matieres nouvelles)")
  return out
end

--- Retour accepté (minutes) : au moins `tmax`, prolongé de la durée pendant laquelle le stock dormant dormirait (coût d'opportunité nul),
--- au plus Dm.TMAX_CAP. sleep_min = out.tmax_sleep (0 quand le stock ne dort pas).
function Dm.tmax(tmax, sleep_min)
  if (sleep_min or 0) <= 0 then return tmax end
  return math.max(tmax, math.min(Dm.TMAX_CAP, sleep_min))
end

---------------------------------------------------------------------------------------------------
-- 2. Saturation relative au puits
---------------------------------------------------------------------------------------------------
--- Besoin servant de base à la saturation : le plus grand du plancher, du besoin des buts et du débit du puits (objets/min, nil : aucun)
--- sur Dm.SAT_H minutes.
function Dm.sat_need(floor, need, flow)
  return math.max(floor or 0, need or 0, (flow or 0) * Dm.SAT_H)
end

---------------------------------------------------------------------------------------------------
-- 3. Décision sur le débit voulu
---------------------------------------------------------------------------------------------------
--- Charge à la main (PNJ) au DÉBIT VOULU : la charge mesurée L au débit mesuré D, mise à l'échelle sur max(D, voulu). Sans débit mesuré, la
--- charge par objet est inconnue : rien ne change. Rend (L, D, changé).
function Dm.load(L, D, wanted)
  L, D = L or 0, D or 0
  if type(wanted) ~= "number" or wanted <= D + Dm.EPS or D <= Dm.EPS then return L, D, false end
  return L * wanted / D, wanted, true
end

--- Seuil du tapis (objets/s) par le COÛT RÉEL : une voie à foreuses et tapis coûte C PNJ-secondes (pose, matières) et libère les porteurs,
--- qui coûtent plate_s PNJ-secondes par objet : retour = C / (60 × plate_s × flux) minutes <= tmax. Rend le plus petit flux qui paie, au
--- plus `ceiling` (l'ancien seuil constant : jamais plus strict qu'avant).
function Dm.belt_flow(C, plate_s, tmax, ceiling)
  if type(C) ~= "number" or C <= 0 or type(plate_s) ~= "number" or plate_s <= 0 or type(tmax) ~= "number" or tmax <= 0 then return ceiling end
  local f = C / (60 * plate_s * tmax)
  if ceiling and f > ceiling then return ceiling end
  return f
end

---------------------------------------------------------------------------------------------------
-- 4. Débit de construction
---------------------------------------------------------------------------------------------------
--- Emplacements de chantier : base + min(ordres retenus faute de place, bras libres ÷ Dm.HANDS_PER_SITE), au plus Dm.SLOTS_HARD ; jamais sous
--- la base, et la base seule quand le puits est fermé.
function Dm.slots(base, open, hands, blocked)
  base = math.max(0, math.floor(base or 0))
  if not open then return base end
  local extra = math.min(math.max(0, math.floor(blocked or 0)), math.floor(math.max(0, hands or 0) / Dm.HANDS_PER_SITE + 1e-9))
  return math.max(base, math.min(Dm.SLOTS_HARD, base + extra))
end

--- Capacités de plus (laboratoires, fours, extraction) : les bras libres ÷ Dm.HANDS_PER_CAP, au plus Dm.CAP_EXTRA_MAX ; 0 puits fermé.
function Dm.extra_cap(open, hands)
  if not open then return 0 end
  return math.min(Dm.CAP_EXTRA_MAX, math.floor(math.max(0, hands or 0) / Dm.HANDS_PER_CAP + 1e-9))
end

return Dm
