--[[
  Lot FOURS « banque de fours dimensionnée au flux, répartiteurs » (demande du DC, 28/10 : « une giga surface de fours
  qu'ils n'ont pas le temps de nourrir », « pas de SPLITS », « il ne faut pas tomber dans l'ultra-maximisation
  (engrenages qui prennent tout le fer) »). Lua PUR : aucune API du jeu, AUCUN NOM d'objet (règle anti-échelle,
  tests/iag_test.lua §8 bis) : le caller donne les NOMBRES lus dans les prototypes du jeu (vitesse, énergie, temps de la
  recette, débit des tapis) ; un mod futur (four électrique, tapis plus rapide) change les nombres, pas ce fichier.

  Le problème, en trois lignes :
    - un flux entrant F de minerai (objets/s) ; un four absorbe r = vitesse ÷ temps de recette (objets/s), plafonné par
      ses bras ; trouver le plus petit n de fours qui absorbe au moins B.COVER × F ; le minerai qui reste attend sur le
      tapis (rien ne se perd). Sur un tapis, les bras d'amont puisent d'abord : les rangées d'amont sont saturées, la
      DERNIÈRE rangée (un ou deux fours) reçoit le reste ; aucun four n'est affamé si ce reste charge chacun de ses
      fours à B.LOAD_MIN au moins. Pour n = ⌈B.COVER × F ÷ r⌉ cela tient dès que n ≥ 2 (démonstration dans
      tests/fours_test.lua §2, vérifiée par simulation) ;
    - répartir les n fours en BANQUES (un tapis d'alimentation, deux rangées de fours de part et d'autre, une ligne de
      sortie par rangée, comme le gabarit « fonderie » de shared/team/modules.lua) : le moins de banques tel que chaque
      banque respecte la hauteur de lot (max_rows), la voie de minerai (une voie si le four brûle un combustible porté
      par l'AUTRE voie du même tapis, deux voies s'il est électrique), la voie de combustible, la voie de sortie ;
    - répartir la sortie : des RÉPARTITEURS (splitters, priorité de sortie) envoient vers chaque consommateur au plus
      sa demande, au plus sa part maximale du total (jamais « tout le fer »), en laissant au moins `reserve` du total
      sur la ligne principale ; le flux est CONSERVÉ (somme des prises + reste = production), à l'épsilon près.

  Un glouton suffit, et il est PROUVÉ contre la force brute (tests/fours_test.lua) : compte de fours (énumération de
  toutes les compositions en banques), allocation (énumération de toutes les allocations entières), simulation de
  fours qui puisent dans une file (charge réelle ≥ seuil).

  Déterminisme : listes, tris à clé complète (priorité, identifiant), aucune itération `pairs`, aucun hasard.
]]

local B = {}

B.COVER = 0.85       -- part du flux que la banque doit pouvoir absorber (le reste attend sur le tapis : pas de perte)
B.LOAD_MIN = 0.3     -- charge minimale du four le moins servi quand il y en a au moins deux (« aucun four affamé »)
B.MARGIN = 0.9       -- toute voie garde 10 % de marge (comme shared/team/modules.lua, M.MARGIN)
B.LANE = 7.5         -- objets/s d'une voie de tapis (valeur par défaut ; le caller donne celle de son tapis)
B.MAX_ROWS = 12      -- rangées de fours au plus par banque (valeur par défaut : lot de 24 tuiles ÷ 2)
B.SIDE = 24          -- côté d'un lot (shared/team/modules.lua, M.MAX_SIDE), en tuiles
B.EPS = 1e-9

local function ceil_eps(x) return math.ceil(x - B.EPS) end

--- Débit d'un four : { rate (minerai/s absorbé à pleine charge, bras compris), fuel (combustible/s à pleine charge),
--- raw (débit sans bras) }.
--- f = { speed, time, fuel_kw (0 : électrique), fuel_kj (énergie d'un combustible), arm_in, arm_out (objets/s, facultatifs) }.
function B.furnace(f)
  local raw = f.speed / f.time
  local fuel = 0
  if (f.fuel_kw or 0) > 0 then fuel = f.fuel_kw / (f.fuel_kj or 4000) end
  local rate = raw
  if f.arm_out and f.arm_out < rate then rate = f.arm_out end
  if f.arm_in then
    -- le bras d'entrée porte minerai ET combustible (tapis commun)
    local room = f.arm_in - fuel * (rate / raw)
    if room < rate then rate = math.max(0, room) end
  end
  local duty = raw > 0 and rate / raw or 0
  return { rate = rate, fuel = fuel * duty, raw = raw }
end

--- Nombre de fours pour un flux `flow` (minerai/s) quand un four en absorbe `rate` : le plus petit n tel que
--- n × rate ≥ cover × flow (0 pour un flux nul). `cover` vaut B.COVER par défaut.
function B.count(flow, rate, cover)
  if not flow or flow <= B.EPS then return 0 end
  if not rate or rate <= B.EPS then return nil, "four sans debit" end
  local n = ceil_eps((cover or B.COVER) * flow / rate)
  if n < 1 then n = 1 end
  return n
end

--- Plus grande banque (nombre de fours) qui passe les contraintes, 0 si même un four seul est refusé. lanes_ore : voies
--- de minerai (2 si le four est électrique : le tapis n'a pas de combustible à porter).
function B.bank_cap(fr, p)
  local lane = (p.lane or B.LANE) * B.MARGIN
  local max_rows = p.max_rows or B.MAX_ROWS
  local lanes_ore = (fr.fuel > B.EPS) and 1 or 2
  local best = 0
  for k = 1, 2 * max_rows do
    local rows = math.floor((k + 1) / 2)
    local ok = rows <= max_rows
      and k * fr.rate <= lanes_ore * lane + B.EPS
      and k * fr.fuel <= lane + B.EPS
      and rows * fr.rate <= lane + B.EPS -- une rangée dépose sur UNE voie de sa ligne de sortie
    if ok then best = k else break end
  end
  return best
end

--- Charge de chaque four d'une banque de k fours recevant `x` fours-équivalents de minerai (flux ÷ débit d'un four) :
--- les rangées d'amont puisent d'abord (saturées, charge 1), la dernière reçoit le reste ; les deux fours d'une rangée se
--- partagent ce qu'elle reçoit. Rend une liste de k charges, indices 2r - 1 (ouest) et 2r (est) pour la rangée r.
function B.loads(x, k)
  local out = {}
  local left = x
  local rows = math.floor((k + 1) / 2)
  for r = 1, rows do
    local m = (r == rows and k % 2 == 1) and 1 or 2
    local take = math.min(m, math.max(0, left))
    left = left - take
    for j = 1, m do out[2 * r - 2 + j] = take / m end
  end
  return out
end

--- Fours par banque, équilibré : { k1 ≥ k2 ≥ … } de somme n, au moins de banques possible.
function B.banks(n, cap)
  if n <= 0 then return {} end
  if cap < 1 then return nil, "aucune banque possible" end
  local b = ceil_eps(n / cap)
  local out = {}
  local base, extra = math.floor(n / b), n % b
  for i = 1, b do out[i] = base + (i <= extra and 1 or 0) end
  return out
end

--- Répartition d'une production entre des consommateurs par répartiteurs à priorité de sortie.
--- lines : débits (objets/s) des lignes de sortie, dans l'ordre ; consumers : { { id, demand, priority, share_max
--- (0 à 1 du total, facultatif) }, ... } ; reserve : part (0 à 1) du total qui reste sur la ligne principale ;
--- available : faux si le prototype « répartiteur » n'est pas débloqué (aucune prise).
--- Rend { total, main = { par ligne }, takes = { { id, take, short, parts = { { line, flow } } } }, splitters = n,
--- main_total }.
function B.allocate(lines, consumers, reserve, available)
  local total = 0
  local left = {}
  for i, f in ipairs(lines) do left[i] = f; total = total + f end
  local res = { total = total, takes = {}, splitters = 0, main = {} }
  local order = {}
  for i, c in ipairs(consumers or {}) do order[i] = c end
  table.sort(order, function(a, b)
    local pa, pb = a.priority or 0, b.priority or 0
    if pa ~= pb then return pa < pb end
    return tostring(a.id) < tostring(b.id)
  end)
  local allowance = total * (1 - math.min(1, math.max(0, reserve or 0)))
  local taken = 0
  for _, c in ipairs(order) do
    local want = math.max(0, c.demand or 0)
    if c.share_max then want = math.min(want, math.max(0, c.share_max) * total) end
    local take = 0
    local rec = { id = c.id, take = 0, short = want, parts = {} }
    if available ~= false then take = math.min(want, math.max(0, allowance - taken)) end
    local rest = take
    for i = 1, #left do
      if rest <= B.EPS then break end
      local part = math.min(rest, left[i])
      if part > B.EPS then
        left[i] = left[i] - part
        rest = rest - part
        rec.parts[#rec.parts + 1] = { line = i, flow = part }
        res.splitters = res.splitters + 1
      end
    end
    rec.take = take - rest
    taken = taken + rec.take
    rec.short = math.max(0, math.max(0, c.demand or 0) - rec.take)
    res.takes[#res.takes + 1] = rec
  end
  local main_total = 0
  for i = 1, #left do res.main[i] = left[i]; main_total = main_total + left[i] end
  res.main_total = main_total
  return res
end

--- Plan complet. input = {
---   flow (minerai/s), furnace = { speed, time, fuel_kw, fuel_kj, arm_in, arm_out, size },
---   lane (objets/s d'une voie), max_rows, cover, n_max (fours disponibles au plus),
---   consumers, reserve, splitter (vrai si le prototype est débloqué) }
--- Rend le plan { ok, n, banks = { { k, west, east, rows, ore, fuel } }, util, processed, produced, lines,
--- allocation, warnings } ou nil, raison.
function B.plan(input)
  local fr = B.furnace(input.furnace)
  local flow = input.flow or 0
  local plan = { ok = true, n = 0, banks = {}, lines = {}, warnings = {}, flow = flow, furnace = fr }
  if flow <= B.EPS then
    plan.util, plan.processed, plan.produced = 0, 0, 0
    plan.allocation = B.allocate({}, input.consumers, input.reserve, input.splitter)
    return plan
  end
  local n, why = B.count(flow, fr.rate, input.cover)
  if not n then return nil, why end
  local cap = B.bank_cap(fr, input)
  if cap < 1 then return nil, "four trop gros pour une banque (voie ou rangee)" end
  if input.n_max and n > input.n_max then
    plan.warnings[#plan.warnings + 1] = "fours disponibles insuffisants"
    n = math.max(0, input.n_max)
  end
  plan.n = n
  if n == 0 then
    plan.util, plan.processed, plan.produced = 0, 0, 0
    plan.allocation = B.allocate({}, input.consumers, input.reserve, input.splitter)
    return plan
  end
  local sizes = B.banks(n, cap)
  local min_load = 1
  for i, k in ipairs(sizes) do
    local west, east = math.floor((k + 1) / 2), math.floor(k / 2)
    local loads = B.loads(flow * k / n / fr.rate, k)
    local w_sum, e_sum, tot = 0, 0, 0
    for j = 1, k do
      local row = math.floor((j + 1) / 2)
      -- le four de l'ouest de la rangée row est l'indice 2 row - 1, celui de l'est 2 row (B.loads les range dans cet ordre)
      if j % 2 == 1 then w_sum = w_sum + loads[j] else e_sum = e_sum + loads[j] end
      tot = tot + loads[j]
      if loads[j] < min_load then min_load = loads[j] end
    end
    plan.banks[i] = { k = k, west = west, east = east, rows = west, loads = loads,
      ore = tot * fr.rate, fuel = tot * fr.fuel }
    plan.lines[#plan.lines + 1] = w_sum * fr.rate
    if east > 0 then plan.lines[#plan.lines + 1] = e_sum * fr.rate end
  end
  plan.min_load = min_load
  plan.processed = math.min(flow, n * fr.rate)
  plan.util = plan.processed / (n * fr.rate)
  plan.produced = plan.processed
  plan.cover = plan.processed / flow
  if n >= 2 and min_load < B.LOAD_MIN - 1e-9 then plan.warnings[#plan.warnings + 1] = "fours affames" end
  plan.allocation = B.allocate(plan.lines, input.consumers, input.reserve, input.splitter)
  if input.furnace.size then
    plan.height = B.height(plan, input.furnace.size)
    if plan.height > (input.side or B.SIDE) then plan.warnings[#plan.warnings + 1] = "hauteur de lot depassee" end
  end
  return plan
end

--- Hauteur (tuiles) de la plus haute banque : rangées de fours + deux rangées par répartiteur de la ligne qui en porte le
--- plus. Les lignes sont numérotées banque par banque (ouest, puis est quand elle en a une).
function B.height(plan, size)
  local per_line = B.splitters_by_line(plan)
  local li, h = 1, 0
  for _, bk in ipairs(plan.banks) do
    local a = per_line[li] or 0
    li = li + 1
    local e = 0
    if bk.east > 0 then e = per_line[li] or 0; li = li + 1 end
    h = math.max(h, bk.rows * size + 2 * math.max(a, e))
  end
  return h
end

--- Fours (nombre pair, au moins 2 par paire de rangées) du gabarit « fonderie » à n paires : un gabarit qui pose des
--- rangées symétriques (une paire = un four à l'ouest et un à l'est) arrondit au-dessus.
function B.pairs(n) return math.max(1, math.floor((n + 1) / 2)) end

--- Contrôle d'un plan : rend la liste des violations (vide : correct). Invariants : charge, voies, conservation.
function B.check(plan, input)
  local bad = {}
  if not plan or not plan.ok then return { "plan absent" } end
  local fr = plan.furnace
  local lane = (input.lane or B.LANE) * B.MARGIN
  local sum = 0
  for i, bk in ipairs(plan.banks) do
    sum = sum + bk.k
    local lanes_ore = (fr.fuel > B.EPS) and 1 or 2
    if bk.rows > (input.max_rows or B.MAX_ROWS) then bad[#bad + 1] = "banque " .. i .. " : trop de rangees" end
    if bk.k * fr.rate > lanes_ore * lane + 1e-6 then bad[#bad + 1] = "banque " .. i .. " : voie de minerai depassee" end
    if bk.k * fr.fuel > lane + 1e-6 then bad[#bad + 1] = "banque " .. i .. " : voie de combustible depassee" end
  end
  for i, f in ipairs(plan.lines) do
    if f > lane + 1e-6 then bad[#bad + 1] = "ligne de sortie " .. i .. " : voie depassee" end
  end
  if sum ~= plan.n then bad[#bad + 1] = "somme des banques differente de n" end
  if plan.n >= 2 and plan.min_load < B.LOAD_MIN - 1e-9 then bad[#bad + 1] = "fours affames" end
  if plan.n > 0 and not (input.n_max and plan.n >= input.n_max) and plan.processed + 1e-6 < (input.cover or B.COVER) * plan.flow then
    bad[#bad + 1] = "couverture non atteinte"
  end
  local al = plan.allocation
  if al then
    local out = al.main_total
    for _, t in ipairs(al.takes) do out = out + t.take end
    if math.abs(out - plan.produced) > 1e-6 then bad[#bad + 1] = "flux non conserve" end
    local reserve = math.min(1, math.max(0, input.reserve or 0))
    if al.main_total + 1e-6 < reserve * plan.produced and #al.takes > 0 then bad[#bad + 1] = "reserve entamee" end
    for _, t in ipairs(al.takes) do
      if t.take < -1e-9 then bad[#bad + 1] = "prise negative" end
    end
  end
  return bad
end

--- Disposition de la première banque en rectangles (tuiles, coin nord-ouest en (0, 0), y vers le sud) : colonnes du
--- gabarit « fonderie » (sortie, bras de sortie, four, bras d'entrée, tapis, bras d'entrée, four, bras de sortie,
--- sortie), et pour chaque prise d'une ligne de sortie un répartiteur 2 × 1 posé à l'EXTÉRIEUR de la ligne, deux
--- rangées par répartiteur (la branche part en travers). size : côté d'un four (tuiles) ; splitters_by_line : { n par
--- ligne de sortie, dans l'ordre des lignes }. Rend { w, h, rects = { { kind, x, y, w, h } } }.
function B.layout(bank, size, splitters_by_line)
  local s = size
  local rects = {}
  local function add(kind, x, y, w, h) rects[#rects + 1] = { kind = kind, x = x, y = y, w = w, h = h } end
  local H = bank.rows * s
  local x_out_w, x_ins_w, x_f_w = 0, 1, 2
  local x_in_w, x_belt, x_in_e = 2 + s, 3 + s, 4 + s
  local x_f_e, x_ins_e, x_out_e = 5 + s, 5 + 2 * s, 6 + 2 * s
  add("tapis-entree", x_belt, 0, 1, H)
  add("tapis-sortie", x_out_w, 0, 1, H)
  if bank.east > 0 then add("tapis-sortie", x_out_e, 0, 1, H) end
  for i = 0, bank.rows - 1 do
    local y = i * s
    add("four", x_f_w, y, s, s)
    add("bras", x_ins_w, y, 1, 1); add("bras", x_in_w, y, 1, 1)
    if i < bank.east then
      add("four", x_f_e, y, s, s)
      add("bras", x_in_e, y, 1, 1); add("bras", x_ins_e, y, 1, 1)
    end
  end
  local extra = 0
  local nsp = splitters_by_line or {}
  local min_x, max_x = 0, 6 + 2 * s
  for line = 1, 2 do
    local n = nsp[line] or 0
    local inner = (line == 1) and x_out_w or x_out_e
    local outer = (line == 1) and (x_out_w - 1) or (x_out_e + 1)
    for j = 0, n - 1 do
      -- répartiteur 2 × 1 sous la fin de la ligne : sa sortie intérieure prolonge le tapis, sa sortie extérieure part
      -- en branche vers le consommateur (une rangée plus bas) ; deux rangées par répartiteur
      add("repartiteur", math.min(inner, outer), H + 2 * j, 2, 1)
      add("tapis-sortie", inner, H + 2 * j + 1, 1, 1)
      add("branche", outer, H + 2 * j + 1, 1, 1)
    end
    if n > 0 then
      extra = math.max(extra, 2 * n)
      min_x = math.min(min_x, outer); max_x = math.max(max_x, outer)
    end
  end
  return { w = 7 + 2 * s, h = H + extra, x0 = min_x, x1 = max_x + 1, rects = rects }
end

--- Nombre de prises (répartiteurs) par ligne de sortie d'un plan, dans l'ordre des lignes.
function B.splitters_by_line(plan)
  local out = {}
  for i = 1, #plan.lines do out[i] = 0 end
  for _, t in ipairs((plan.allocation or {}).takes or {}) do
    for _, p in ipairs(t.parts) do out[p.line] = out[p.line] + 1 end
  end
  return out
end

--- Chevauchements dans une disposition (liste vide : correcte). Les tapis de sortie sont traversés par le répartiteur
--- qui les prolonge : ils se touchent sans se recouvrir (le répartiteur commence sous la fin du tapis).
function B.layout_overlaps(lay)
  local bad = {}
  local r = lay.rects
  for i = 1, #r do
    for j = i + 1, #r do
      local a, b = r[i], r[j]
      if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then
        bad[#bad + 1] = a.kind .. "/" .. b.kind .. " en (" .. math.max(a.x, b.x) .. ", " .. math.max(a.y, b.y) .. ")"
      end
    end
  end
  return bad
end

return B
