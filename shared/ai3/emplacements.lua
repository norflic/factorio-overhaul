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
    5. Lot DIAG-USINE (31/10), Scarlet de la partie EVOLUTION : deux modules NEUFS (câble, pignons) suspendus par la pile
       (réserve « pile » : ils ont REMIS leurs objets au coffre, Build.reserve_suspended) tenaient les deux emplacements de la
       minute 30 à la minute 90, alors que la pile n'admet que les modules qui produisent la matière qui manque (le fer) : la
       seule fonderie (75 plaques/min pour un besoin de 154 à 429) ne pouvait pas être agrandie, « plan directeur occupe (2
       module(s) ouvert(s), 2 en attente de matiere) ». Un module SUSPENDU PAR LA PILE depuis Em.PILE_HOLD ne tient donc plus
       d'emplacement (la règle 1 protège le coffre d'une réserve qui PREND ; celle-ci ne prend rien). Au plus Em.PILED_FREE
       modules suspendus hors du compte, comme pour les figés.
    6. Lot INDUSTRIE I6 : le BLOC DE MALL a son emplacement à lui (Em.mall, Em.MALL_SLOTS = 1), hors du compte des fonderies et des
       chaînes : sinon la fonte, qui paie en premier, le privait toujours de sa place (plan INDUSTRIE §3). Un bloc FIGÉ (Em.STALL) ou
       SUSPENDU par la pile (Em.PILE_HOLD) libère l'emplacement, comme un module ordinaire : le mall ne bloque jamais.
    7. Lot DEPENSES2 (essai 4, accord du lead du 5/11) : le COMPLÉMENT du stock qui dort. Quand un produit des fonderies DORT (règle de
       shared/ai3/depenses.lua) et qu'un autre ne dort pas, celui qui ne dort pas manque en face (mesuré, essai 3, Azur sur 271828182 :
       5 190 fer dormaient, cuivre à 45/min, ses foreuses refusées « plan directeur occupe », Em.extra à 0 car il prend le plus FAIBLE des
       produits). Em.COMP_SLOTS emplacement de plus, RÉSERVÉ aux modules qui produisent un produit qui ne dort pas (extraction et fonte :
       fonderies à foreuses) : room_comp ; les autres modules gardent room. Jamais plus d'un siège : un module ouvert ainsi est compté
       à la décision suivante.
    8. Lot CORR-CHAMP-MANQUE (EFFONDREMENT, accord du lead du 5/11) : le MÊME siège pour le produit dont la matière MANQUE aux ordres
       ouverts (Em.short, sur le prédicat partagé Ca.blocked_items de shared/ai3/capitalisation.lua), même quand rien ne dort. Mesuré
       (partie du DC 717152950 en 0.6.51) : 2 modules qui attendaient du fer tenaient les 2 emplacements de 11 à 31 min (règle 1), la
       foreuse de fer était refusée « plan directeur occupe » (12 foreuses de fer contre 18 à 28 en 0.6.50) ; la pile, qui battait
       (26 changements en 36 min), remettait à zéro l'horloge de la règle 5 ; la règle 7 ne s'ouvrait pas (rien ne dormait).
       QUI PREND LE SIÈGE (un seul, Em.COMP_SLOTS ; point de relecture de DEPENSES2, 5/11) : quand un produit dort et qu'un autre
       manque, le complément (Em.complement) est celui de la règle 7, TOUS les produits qui ne dorment pas, ceux qui manquent compris,
       sans priorité de plus ; sans rien qui dort, il se réduit aux produits qui manquent ; un produit qui dort ne le prend jamais, même
       s'il manque. Chaque foreuse d'un produit du complément est accordée tant que room_comp > 0 (Em.drill_refused) ; à la décision, le
       siège va au PREMIER ordre, dans l'ordre trié de Ca.decide, dont le produit est dans le complément (Em.order_seat) ; les suivants
       sont refusés « plan directeur occupe ».
    9. Lot VIDEO-SIEGES (C4 de DIAG_CONSO, 7/11 ; partie du DC, minute 256 : 5 emplacements sur 5 tenus par des modules qui
       s'affament, 48 annulations « materiaux introuvables » en 4 h 16) : un module qui attend sa MATIÈRE (Em.MATERIAL_STATES) sans que
       rien avance depuis Em.STALL (10 min : ni objet de moins à réunir, ni changement d'état) est « figé » lui aussi (Em.mat_tick,
       m.mat_tick) : il ne tient plus d'emplacement, au plus Em.STALLED_FREE hors du compte avec les figés de chantier. Sans horloge
       (m.mat_tick absent : sauvegarde d'avant) la règle 1 reste telle quelle.
   10. Lot VIDEO-SIEGES (C5) : on n'ouvre jamais deux CHAÎNES dont les manques d'ouverture se recoupent à plus de Em.OVERLAP_MAX % (le
       plus petit des deux ensembles est couvert par l'autre : Em.overlap) ; le siège va d'abord au produit qui DÉBLOQUE le manque, puis
       au moins couvert (Em.arbitrate). Les 5 chaînes de la partie du DC manquaient toutes des mêmes assembleurs 2.
  Déterminisme : listes parcourues dans l'ordre donné, aucun hasard, aucun temps mesuré ; entrée et sortie : nombres, chaînes,
  tables.
]]

local Em = {}

Em.STALL = 10 * 3600   -- ticks sans entité bâtie de plus : un module de chantier est « figé »
Em.STALLED_FREE = 2    -- modules figés au plus hors du compte des emplacements
Em.EXTRA_MAX = 2       -- emplacements de plus au plus avec un stock riche
Em.PILE_HOLD = 5 * 3600 -- ticks de suspension continue par la pile avant de libérer l'emplacement (lot DIAG-USINE)
Em.PILED_FREE = 2      -- modules suspendus par la pile au plus hors du compte des emplacements
Em.PER_SLOT = 1000     -- plaques libres de chaque produit des fonderies par emplacement de plus
Em.MALL_SLOTS = 1      -- lot INDUSTRIE I6 : blocs de mall ouverts à la fois (emplacement à part)
Em.COMP_SLOTS = 1      -- lot DEPENSES2 (essai 4) : emplacement de plus réservé au complément du stock qui dort
Em.OVERLAP_MAX = 50    -- lot VIDEO-SIEGES (C5) : % de recoupement des manques d'ouverture au-delà duquel une seconde chaîne n'ouvre pas

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

--- Lot VIDEO-SIEGES (C4, règle 9) : horloge de la MATIÈRE d'un ordre. states = états de ses modules, n = nombre d'objets qui lui
--- manquent encore (somme des manques de ses modules en réserve). (prev_t, prev_n, prev_s) = valeurs gardées (nil au départ) ; rend
--- (t, n, s) : t = tick du dernier progrès (premier tick en matière, ou un manque qui BAISSE, ou un changement d'états), nil hors matière.
function Em.mat_tick(prev_t, prev_n, prev_s, states, n, tick)
  if phase(states) ~= "matiere" then return nil, nil, nil end
  local s = table.concat(states or {}, ",")
  n = type(n) == "number" and n or 0
  if prev_t == nil or prev_s ~= s or (type(prev_n) == "number" and n < prev_n) then return tick, n, s end
  return prev_t, n, s
end

--- Lot DIAG-USINE : horloge de SUSPENSION par la pile d'un ordre (ou d'un module). `suspended` : tous ses modules non finis sont en
--- réserve avec la raison « pile » (lue par le runtime). prev = valeur gardée ; rend nil hors suspension, le tick de la première
--- pensée suspendue sinon.
function Em.pile_tick(prev, suspended, tick)
  if not suspended then return nil end
  return prev or tick
end

--- Suspendu par la pile depuis Em.PILE_HOLD au moins ? (since : horloge de Em.pile_tick, nil hors suspension)
function Em.piled(since, tick)
  return type(since) == "number" and type(tick) == "number" and tick - since >= Em.PILE_HOLD
end

--- Classe un ordre « module » ouvert. m = { states = { état de chaque module suivi }, progress_tick, opened, work_tick, pile_tick } ; tick.
--- Rend "pile" (suspendu par la pile depuis Em.PILE_HOLD : il a rendu ses objets), "matiere" (attend ses matériaux ou son plan),
--- "fige" (chantier sans progrès depuis Em.STALL, compté depuis le plus tard du dernier progrès et de l'entrée en chantier) ou "actif".
function Em.class(m, tick)
  if m and Em.piled(m.pile_tick, tick) then return "pile" end
  local ph = phase(m and m.states)
  if ph == "matiere" then
    -- Lot VIDEO-SIEGES (C4, règle 9) : la matière n'avance plus depuis Em.STALL ticks.
    if m and type(m.mat_tick) == "number" and type(tick) == "number" and tick - m.mat_tick >= Em.STALL then return "fige" end
    return "matiere"
  end
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

--- Lot DEPENSES2 (règle 7) : produits du COMPLÉMENT. names = liste des produits des fonderies, sleeping = { [produit] = true } (ceux
--- qui dorment). Rend { [produit] = true } des produits qui ne dorment pas quand au moins un dort et au moins un ne dort pas ; nil sinon.
--- Lot CORR-CHAMP-MANQUE (règle 8) : short = { [produit] = true } (facultatif) : les produits dont la matière MANQUE aux ordres ouverts
--- (Ca.blocked_items, prédicat partagé) ; ils ont droit au MÊME siège, même quand rien ne dort (jamais un produit qui dort).
function Em.complement(names, sleeping, short)
  local comp, any_sleep, any_comp = {}, false, false
  for _, n in ipairs(names or {}) do
    if (sleeping or {})[n] then any_sleep = true else comp[n] = true any_comp = true end
  end
  -- Règle 8 : sans rien qui dort, le siège ne va qu'aux produits qui manquent ; avec, ils sont déjà dans le complément (un produit
  -- qui manque ne dort pas).
  local miss = Em.missing_seat(names, sleeping, short)
  if miss and not (any_sleep and any_comp) then return miss end
  if any_sleep and any_comp then return comp end
  return nil
end

--- Règle 8 : produits qui manquent (short) et ne dorment pas ; nil s'il n'y en a aucun.
function Em.missing_seat(names, sleeping, short)
  local out = nil
  for _, n in ipairs(names or {}) do
    if (short or {})[n] and not (sleeping or {})[n] then
      out = out or {}
      out[n] = true
    end
  end
  return out
end

--- Lot CORR-CHAMP-MANQUE (règle 8) : produits des fonderies dont la matière manque aux ordres ouverts. names = produits des fonderies,
--- ores = { [produit] = minerai }, blocked = { [objet] = vrai } (Ca.blocked_items : matières manquantes des ordres ouverts et leurs
--- ingrédients directs), free = { [produit] = stock libre }. Un produit RICHE (Em.PER_SLOT plaques libres ou plus) ne manque pas : son
--- module attend autre chose (un circuit, un assembleur), pas lui. Rend { [produit] = true } (éventuellement vide).
function Em.short(names, ores, blocked, free)
  local out = {}
  blocked = blocked or {}
  for _, n in ipairs(names or {}) do
    local ore = (ores or {})[n]
    if (blocked[n] or (ore ~= nil and blocked[ore])) and ((free or {})[n] or 0) < Em.PER_SLOT then out[n] = true end
  end
  return out
end

--- Le siège du complément est-il ouvert à un module qui produit `product` ? (sl : rendu d'Em.slots)
function Em.comp_ok(sl, product)
  return sl ~= nil and sl.comp ~= nil and product ~= nil and sl.comp[product] == true and (sl.room_comp or 0) > 0
end

--- Relecture DEPENSES2 (revue, point 4) : les deux décisions du runtime (script/ai3/capitalisation.lua), ici pour être testées.
--- Foreuse électrique d'un minerai qui produit `product` refusée « plan directeur occupe » ? (emplacements pleins, et pas de siège du
--- complément pour ce produit)
function Em.drill_refused(sl, product)
  return sl ~= nil and sl.busy == true and not Em.comp_ok(sl, product)
end

--- Siège d'un ORDRE de la décision (décompte de la décision entière) : room = emplacements libres restants (nil : aucun plafond),
--- room_comp = sièges du complément restants, comp = { [produit] = true }, product = produit de l'ordre (nil : pas une foreuse).
--- Rend "libre" (aucun plafond), "ordinaire", "complement", ou nil (refusé : « plan directeur occupe »).
function Em.order_seat(room, room_comp, comp, product)
  if room == nil then return "libre" end
  if room > 0 then return "ordinaire" end
  if comp ~= nil and product ~= nil and comp[product] == true and (room_comp or 0) > 0 then return "complement" end
  return nil
end

--- Décompte d'un module envoyé (n modules) : rend room, room_comp (nil gardés nil).
function Em.take(room, room_comp, n)
  n = n or 1
  return room ~= nil and room - n or nil, room_comp ~= nil and room_comp - n or nil
end

--- Relecture du lead (18 h 10, point 1, BLOQUANT) : siège d'un ordre CHAMP (« couvrir » ou « ouvrir » d'un minerai que le champ pose).
--- Le champ n'est pas un module (lot CHAMP) : quand il restait des emplacements au début de la décision (full faux), il n'en prend
--- aucun, comme avant ("hors"). Quand ils étaient PLEINS (full vrai), sa foreuse n'a pu être accordée que par le siège du complément
--- (Em.drill_refused) : il le prend s'il en reste un pour son produit ("complement" ; le runtime marque l'ordre, qui le tient tant
--- qu'il est ouvert : Em.slots, held_comp), sinon il est refusé (nil, « plan directeur occupe »).
function Em.champ_seat(full, room, room_comp, comp, product)
  if not full then return "hors" end
  if Em.order_seat(room, room_comp, comp, product) == "complement" then return "complement" end
  return nil
end

--- Seconde relecture (revue-depenses2, point 1) : un ordre CHAMP sur le siège ne le TIENT que s'il AVANCE VRAIMENT. Son étiquette de
--- progrès (étape, projet, état, raison, posées : script/ai3/capitalisation.lua, follow) change aussi quand la pile bat sans rien
--- bâtir (26 changements en 36 min, MESURÉ dans la partie du DC) : progress_tick avance, ORDER_TTL ne tombe jamais. Ici, seul le
--- PROGRÈS RÉEL compte : entités posées en hausse (Em.champ_advance). Un champ sans progrès réel depuis Em.STALL ticks (depuis son
--- ouverture s'il n'a jamais rien posé) lâche le siège, comme un module « figé ». o = { exec, seat, adv_tick, opened }.
function Em.champ_holds(o, tick)
  if not (o and o.exec == "champ" and o.seat == "complement") then return false end
  local t0 = o.adv_tick or o.opened or tick or 0
  return (tick or 0) - t0 < Em.STALL
end

--- Dernier progrès RÉEL d'un champ : rend adv_tick, built_hi (le plus haut nombre d'entités posées vu). Le premier relevé fixe la
--- référence sans compter comme progrès ; ensuite, seule une HAUSSE des posées en est un (une baisse : entités perdues, pas un progrès).
function Em.champ_advance(adv_tick, built_hi, built, tick)
  local b = type(built) == "number" and built or 0
  if built_hi == nil then return adv_tick, b end
  if b > built_hi then return tick, b end
  return adv_tick, built_hi
end

--- Relecture de CORR-CHAMP-MANQUE (remarque 6) : un ordre refusé faute de place compte-t-il dans cs.blocked_slots (ordres retenus
--- faute de place, qui ouvrent des emplacements ORDINAIRES de chantier à la décision suivante, lot C2) ? Non quand il n'a été refusé
--- que parce que le siège UNIQUE du complément était déjà pris (son produit est dans le complément) : sinon le second ordre du fer
--- d'une décision ouvrait un emplacement ordinaire de plus, et le siège unique n'en était plus un. Oui pour tout autre refus.
function Em.blocked_counts(comp, product)
  return not (comp ~= nil and product ~= nil and comp[product] == true)
end

--- Lot VIDEO-SIEGES (C5, règle 10) : recouvrement de deux ensembles de manques { [objet] = vrai } : % des objets du plus petit qui sont
--- aussi dans l'autre (0 si l'un est vide).
function Em.overlap(a, b)
  local na, nb, common = 0, 0, 0
  for k in pairs(a or {}) do
    na = na + 1
    if (b or {})[k] then common = common + 1 end
  end
  for _ in pairs(b or {}) do nb = nb + 1 end
  local m = math.min(na, nb)
  if m == 0 then return 0 end
  return 100 * common / m
end

--- Arbitrage des SIÈGES d'une décision. cands = ordres « module » de la décision, dans l'ordre rendu : { key, kind, miss = { [objet] =
--- vrai } (manque d'ouverture), unblocks (vrai : le produit débloque un manque des ordres ouverts), theta (couverture du produit, nil :
--- inconnue) } ; open = chaînes ouvertes : { key, miss }. Rend (keys, refused) : keys = les clés de cands dans l'ordre où elles prennent
--- leur siège (celles qui débloquent d'abord, puis la moins couverte, puis l'ordre rendu), en ne changeant que les places des ordres
--- « module » ; refused = { [clé] = raison } des CHAÎNES dont le manque recoupe à plus de Em.OVERLAP_MAX % celui d'une chaîne ouverte
--- ou d'une chaîne qui a déjà son siège dans la décision. Aucun pairs qui décide : listes seulement.
function Em.arbitrate(cands, open)
  local idx = {}
  for i, c in ipairs(cands or {}) do idx[i] = c end
  local pos = {}
  for i = 1, #idx do pos[idx[i]] = i end
  local sorted = {}
  for i = 1, #idx do sorted[i] = idx[i] end
  table.sort(sorted, function(a, b)
    if (a.unblocks and true or false) ~= (b.unblocks and true or false) then return a.unblocks and true or false end
    local ta, tb = a.theta or math.huge, b.theta or math.huge
    if ta ~= tb then return ta < tb end
    return pos[a] < pos[b]
  end)
  local sets = {}
  for _, o in ipairs(open or {}) do sets[#sets + 1] = { key = o.key, miss = o.miss } end
  local refused, keys = {}, {}
  for _, c in ipairs(sorted) do
    local why = nil
    if c.kind == "chaine" then
      for _, o in ipairs(sets) do
        if why == nil and Em.overlap(c.miss, o.miss) > Em.OVERLAP_MAX then
          why = string.format("recoupement : meme manque d'ouverture que %s (plus de %d %%)", tostring(o.key), Em.OVERLAP_MAX)
        end
      end
    end
    if why then refused[c.key] = why
    else
      keys[#keys + 1] = c.key
      if c.kind == "chaine" and next(c.miss or {}) ~= nil then sets[#sets + 1] = { key = c.key, miss = c.miss } end
    end
  end
  return keys, refused, sorted
end

--- s = { base (A.MAX_OPEN), plates (liste des stocks libres des produits des fonderies), mods (liste de { states, progress_tick,
--- opened, work_tick, key }), tick, names (produits des fonderies, dans l'ordre de plates), sleeping ({ [produit] = true } : ceux qui
--- dorment, lot DEPENSES2), short ({ [produit] = true } : leur matière manque aux ordres ouverts, Em.short, lot CORR-CHAMP-MANQUE),
--- held_comp (ordres CHAMP ouverts qui tiennent le siège du complément : ils ne sont pas dans mods ; relecture du lead, 18 h 10) }.
--- Rend { cap, counted, stalled, free_stalled, materials, open, room, busy, keys_stalled, why, comp, room_comp, held_comp }.
function Em.slots(s)
  local base = math.max(0, math.floor((s and s.base) or 0))
  local extra = Em.extra(s and s.plates)
  local cap = base + extra
  local counted, stalled, free_stalled, materials = 0, 0, 0, 0
  local piled, free_piled = 0, 0
  local keys_stalled, keys_piled = {}, {}
  local mods = (s and s.mods) or {}
  for _, m in ipairs(mods) do
    local c = Em.class(m, s.tick)
    if c == "pile" then
      piled = piled + 1
      if free_piled < Em.PILED_FREE then
        free_piled = free_piled + 1
        keys_piled[#keys_piled + 1] = tostring(m.key)
      else
        counted = counted + 1
      end
    elseif c == "fige" then
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
  if free_piled > 0 then why = why .. string.format(", %d suspendu(s) par la pile hors du compte", free_piled) end
  -- Règle 7 (lot DEPENSES2) : le siège du complément du stock qui dort ; règle 8 (CORR-CHAMP-MANQUE) : le même siège pour les
  -- produits dont la matière manque aux ordres ouverts (s.short)
  local comp = Em.complement(s and s.names, s and s.sleeping, s and s.short)
  local room_comp = room
  -- Relecture du lead (18 h 10, point 1, BLOQUANT) : un ordre CHAMP qui a pris le siège (Em.champ_seat) n'est pas un module, il n'est
  -- pas dans `mods` : il le TIENT quand même (s.held_comp), sinon chaque décision relancerait un champ de plus sur la plaque qui manque.
  local held = math.max(0, math.floor((s and s.held_comp) or 0))
  if comp then
    room_comp = math.max(0, cap + Em.COMP_SLOTS - counted)
    room_comp = math.max(0, room_comp - held) -- (ligne à part : la précédente est celle des mutants de DEPENSES2)
    local cn, cm = {}, {}
    local short = (s and s.short) or {}
    local sleep_comp = Em.complement(s.names, s.sleeping)
    for _, n in ipairs(s.names) do
      if comp[n] then
        if sleep_comp and sleep_comp[n] then cn[#cn + 1] = n end
        if short[n] then cm[#cm + 1] = n end
      end
    end
    if #cn > 0 then why = why .. string.format(", +%d pour le complement du stock qui dort (%s)", Em.COMP_SLOTS, table.concat(cn, " ")) end
    if #cm > 0 and #cn > 0 then
      why = why .. string.format(" ; meme siege pour la matiere qui manque aux ordres ouverts (%s)", table.concat(cm, " "))
    elseif #cm > 0 then
      why = why .. string.format(", +%d pour la matiere qui manque aux ordres ouverts (%s)", Em.COMP_SLOTS, table.concat(cm, " "))
    end
    if held > 0 then why = why .. string.format(" ; siege tenu par %d champ(s)", held) end
  end
  return { cap = cap, base = base, extra = extra, counted = counted, stalled = stalled, free_stalled = free_stalled,
    piled = piled, free_piled = free_piled, keys_piled = keys_piled, held_comp = held,
    materials = materials, open = #mods, room = room, busy = room <= 0, keys_stalled = keys_stalled, why = why,
    comp = comp, room_comp = room_comp }
end

--- Lot INDUSTRIE I6 : l'emplacement des blocs de mall. s = { mods = liste de { states, progress_tick, opened, work_tick, pile_tick, key }
--- (les blocs ouverts), tick, base (défaut Em.MALL_SLOTS) }. Un bloc figé ou suspendu par la pile ne tient pas l'emplacement.
--- Rend { cap, counted, room, busy, open, why }.
function Em.mall(s)
  local cap = math.max(0, math.floor((s and s.base) or Em.MALL_SLOTS))
  local counted, free = 0, 0
  for _, m in ipairs((s and s.mods) or {}) do
    local c = Em.class(m, s.tick)
    if c == "fige" or c == "pile" then free = free + 1 else counted = counted + 1 end
  end
  local room = math.max(0, cap - counted)
  return { cap = cap, counted = counted, room = room, busy = room <= 0, open = #((s and s.mods) or {}), free = free,
    why = string.format("%d bloc(s) de mall ouvert(s), %d compte(s) sur %d emplacement(s), %d fige(s) ou suspendu(s) hors du compte",
      #((s and s.mods) or {}), counted, cap, free) }
end

--- Texte du refus quand plus aucun emplacement n'est libre (préfixe « plan directeur occupe » : celui de main, relu par les journaux).
function Em.busy_text(sl)
  return "plan directeur occupe (" .. tostring(sl and sl.why or "?") .. ")"
end

return Em
