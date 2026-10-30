--[[
  Lot CAPI-DEBIT (30/10) : EMPLACEMENTS du plan directeur ouverts aux modules de la capitalisation (fonderies à foreuses,
  chaînes). Règle PURE, testée hors jeu (tests/capi_debit_test.lua). Aucun nom du jeu : les produits sont des chaînes opaques
  données par le runtime (A.METHODS, données de l'exécutant).

  Retours du DC : « le vrai probleme du fer c'est principalement le fait qu'ils ne capitalisent pas assez » (29/10, 15 h) ;
  audit CAPI-AUDIT (T2) : 2 modules ouverts au plus (A.MAX_OPEN), un module bloqué (défrichage 74 min, réserve) tient un des
  deux emplacements ; 48 950 plaques de fer dormaient au coffre dans la partie du DC pendant que la capitalisation écrivait
  « plan directeur occupe (2 module(s) ouvert(s), au plus 2) ».

  Ce que faisait main 0.6.21 (script/ai3/capitalisation.lua, build_input) : busy = (ordres « module » ouverts) >= A.MAX_OPEN,
  quel que soit l'état des modules et le stock ; et rien ne bornait le NOMBRE d'ordres « module » d'une même décision (jusqu'à
  Capi.MAX_ORDERS = 4) : de 0 module ouvert, une décision pouvait en ouvrir 4 d'un coup, alors que le plafond voulait 2.

  Règles d'ici :
    1. Un module qui ATTEND SES MATÉRIAUX (Em.MATERIAL_STATES : la matière lui est réservée au fil de l'eau) ou qui n'est pas
       encore planifié tient TOUJOURS son emplacement : en ouvrir un autre viderait le coffre (raison de A.MAX_OPEN, banc p4).
    2. Un module FIGÉ (aucune entité bâtie de plus depuis Em.STALL, dans un état de chantier : défrichage, fantômes, chantier,
       raccordement, bloqué ; compté depuis l'ENTRÉE en chantier au plus tôt, Em.work_tick : le temps de réserve n'y entre pas)
       ne tient plus d'emplacement : il reste ouvert et suivi (Capi.ORDER_TTL l'annule à 30 min), mais
       un autre module peut partir. Au plus Em.STALLED_FREE modules figés hors du compte (au-delà, ils comptent : une équipe
       n'accumule pas les chantiers morts).
    3. STOCK RICHE : Em.PER_SLOT plaques libres de CHAQUE produit des fonderies (le plus faible des produits) donnent un
       emplacement de plus, au plus Em.EXTRA_MAX.
    4. Le plafond vaut pour la décision ENTIÈRE : Em.room rend les emplacements libres, que le runtime décompte à chaque
       module envoyé.
  Déterminisme : listes parcourues dans l'ordre donné, aucun hasard, aucun temps mesuré ; entrée et sortie : nombres, chaînes,
  tables.
]]

local Em = {}

Em.STALL = 10 * 3600   -- ticks sans entité bâtie de plus : un module de chantier est « figé »
Em.STALLED_FREE = 2    -- modules figés au plus hors du compte des emplacements
Em.EXTRA_MAX = 2       -- emplacements de plus au plus avec un stock riche
Em.PER_SLOT = 1000     -- plaques libres de chaque produit des fonderies par emplacement de plus

-- États de l'exécutant (script/team/build.lua) où la matière du module se réserve encore ou n'est pas encore planifiée.
Em.MATERIAL_STATES = { attente = true, plan = true, reserve = true }
-- États de chantier : la matière est prise, le travail est aux PNJ ; seul cet état peut être « figé ».
Em.WORK_STATES = { defrichage = true, fantomes = true, chantier = true, raccordement = true, bloque = true }

local function phase(states)
  local any_work, any_mat = false, false
  for _, s in ipairs(states or {}) do
    if Em.MATERIAL_STATES[s] then any_mat = true
    elseif Em.WORK_STATES[s] then any_work = true end
  end
  if any_mat then return "matiere" end
  if any_work then return "chantier" end
  return "autre"
end

--- Relecture CAPI-DEBIT (30/10) : tick d'ENTRÉE en chantier d'un ordre (tous ses modules sortis de la matière). Le dernier progrès
--- (progress_tick, entités bâties) ne bouge pas pendant la réserve : sans cette horloge, un module resté 10 min en réserve était
--- « figé » dès son premier tick de défrichage, alors que son chantier commençait. prev = valeur gardée (nil au départ) ; rend
--- la nouvelle valeur : nil tant que la matière est attendue (ou hors chantier), le tick de la première pensée en chantier sinon.
function Em.work_tick(prev, states, tick)
  if phase(states) ~= "chantier" then return nil end
  return prev or tick
end

--- Classe un ordre « module » ouvert. m = { states = { état de chaque module suivi }, progress_tick, opened, work_tick } ; tick.
--- Rend "matiere" (attend ses matériaux ou son plan), "fige" (chantier sans progrès depuis Em.STALL, compté depuis le plus tard du
--- dernier progrès et de l'entrée en chantier) ou "actif".
function Em.class(m, tick)
  local ph = phase(m and m.states)
  if ph == "matiere" then return "matiere" end
  if ph ~= "chantier" then return "actif" end -- fini ou refusé au relevé suivant : le suivi le fermera
  local since = (m.progress_tick or m.opened or tick or 0)
  if type(m.work_tick) == "number" and m.work_tick > since then since = m.work_tick end
  if type(tick) == "number" and tick - since >= Em.STALL then return "fige" end
  return "actif"
end

--- Emplacements de plus permis par le stock : plates = { [produit] = plaques libres } des produits des fonderies (au moins un).
function Em.extra(plates)
  local low = nil
  for _, v in ipairs(plates or {}) do
    local n = type(v) == "number" and v or 0
    if low == nil or n < low then low = n end
  end
  if not low or low <= 0 then return 0 end
  return math.min(Em.EXTRA_MAX, math.floor(low / Em.PER_SLOT + 1e-9))
end

--- s = { base (A.MAX_OPEN), plates (liste des stocks libres des produits des fonderies), mods (liste de { states, progress_tick,
--- opened, work_tick, key }), tick }. Rend { cap, counted, stalled, free_stalled, materials, open, room, busy, keys_stalled, why }.
function Em.slots(s)
  local base = math.max(0, math.floor((s and s.base) or 0))
  local extra = Em.extra(s and s.plates)
  local cap = base + extra
  local counted, stalled, free_stalled, materials = 0, 0, 0, 0
  local keys_stalled = {}
  local mods = (s and s.mods) or {}
  for _, m in ipairs(mods) do
    local c = Em.class(m, s.tick)
    if c == "fige" then
      stalled = stalled + 1
      if free_stalled < Em.STALLED_FREE then
        free_stalled = free_stalled + 1
        keys_stalled[#keys_stalled + 1] = tostring(m.key)
      else
        counted = counted + 1
      end
    else
      if c == "matiere" then materials = materials + 1 end
      counted = counted + 1
    end
  end
  local room = math.max(0, cap - counted)
  local why = string.format("%d module(s) ouvert(s), %d compte(s) sur %d emplacement(s) (%d + %d par le stock), %d fige(s) hors du compte, %d en attente de matiere",
    #mods, counted, cap, base, extra, free_stalled, materials)
  return { cap = cap, base = base, extra = extra, counted = counted, stalled = stalled, free_stalled = free_stalled,
    materials = materials, open = #mods, room = room, busy = room <= 0, keys_stalled = keys_stalled, why = why }
end

--- Texte du refus quand plus aucun emplacement n'est libre (préfixe « plan directeur occupe » : celui de main, relu par les journaux).
function Em.busy_text(sl)
  return "plan directeur occupe (" .. tostring(sl and sl.why or "?") .. ")"
end

return Em
