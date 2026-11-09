--[[
  Lot AMELIORATION « monter en LARGEUR et PAR BLOC » (retour du DC en jeu, 8/11, 0.6.65 : « en termes d'amélioration, je remarque
  qu'ils n'améliorent pas du tout la base [...] quand ils pourraient améliorer tous les fours et améliorer toutes les foreuses [...]
  Et quand ils décident de le faire, c'est un seul et ils le max pour aucune raison [...] penser en bloc et pas penser en petite
  unité [...] c'est beaucoup plus simple d'améliorer un bloc entier que d'améliorer petit à petit chaque unité. Évidemment, ça sera en
  fonction de l'orientation. »). PUR (aucune API Factorio, aucun nom du jeu : tests/iag_test.lua §8) ; testé hors jeu
  (tests/amelioration_test.lua). Le runtime (script/ai3/capital.lua) lui donne le relevé des bâtiments à niveaux avec leur BLOC, et
  paie le lot choisi par le mécanisme du joueur (Levels.start) ou, pour votre équipe, par son propre coffre.

  Diagnostic de départ (fo-logs/2026-11-08_AMELIORATION, 0.6.65) : la règle de Cap.candidates choisissait UN bâtiment par pensée, le
  mieux noté en valeur ÷ coût ; les murs et les tourelles passaient toujours devant les foreuses et les fours (gain de vitesse de 11 %
  par niveau contre 15 % de résistance), le relevé ne voyait que les bâtiments à 64 tuiles du QG (les 241 foreuses du champ de
  votre équipe ne l'étaient jamais), et la chaîne du centre (Q16) poussait toujours le MÊME bâtiment au plafond.

  RÈGLE (par bloc et par famille) :
  1. BLOC = ensemble de bâtiments qui travaillent ensemble (un module du plan directeur, un avant-poste, le quartier du QG) ; la clé est
     donnée par le relevé (ent.block), la règle n'en sait pas plus.
  2. Dans un bloc, une famille ne monte que par son NIVEAU MINIMAL m : le candidat « bloc » est l'ensemble des bâtiments de la famille
     qui sont au niveau m, tous vers m + 1 (au plus Am.BATCH_MAX par décision, moins si le stock libre n'en paie pas plus). Aucun
     bâtiment ne passe donc à m + 2 avant que tout le bloc soit à m + 1. Exception unique, dite au journal : la chaîne du centre
     (Q16 : un bâtiment par famille au plafond), qui reste un candidat seul (shared/ai3/capital.lua).
  3. Autorisé seulement si les données des niveaux le permettent (Ld.check : plafond du centre) ET si l'emprise ne change pas quand le
     bloc est « fixe » (ent.fixed : bande de champ au gabarit serré, un bâtiment plus grand n'y tiendrait pas : cause « emprise »).
  4. COÛT = n × le coût du niveau m + 1 LU DANS LES DONNÉES (Ld.cost), valorisé par Cap.work_cost (graphe du cerveau général, stock à
     Cap.STOCK_PCT %) ; un objet sans coût connu rend le bloc impayable (règle H8, comme un bâtiment seul).
  5. VALEUR = somme, sur les n bâtiments, de la valeur d'un bâtiment seul (Cap.building_value : gain de vitesse ou de force lu dans les
     prototypes, en marche ou à l'arrêt, poids de la famille de buts : traits du chef, défense sous menace), × Am.PROD_PCT % pour une
     famille de DÉBIT (le DC : fours et foreuses d'abord : la production se compose, la défense ne le fait qu'en cas de menace, où sa
     valeur double déjà), × le besoin du bloc (ctx.need(bloc, famille), pour cent : une chaîne en manque monte avant les autres).
  6. SCORE = valeur × 1 000 ÷ (coût + Cap.COST_FLOOR), inertie de Cap.INERTIA_PCT % pour le bloc en cours ; égalités par la clé.
  Chaque (bloc, famille) rend soit un candidat, soit une cause de refus (plafond, emprise, objet sans coût, refus récent) : le runtime
  écrit une ligne [FO-AMELIORATION] par décision et par changement de cause.

  Déterminisme : listes triées par numéro d'entité et par clé, entiers, aucun hasard, aucun pairs décisionnel.
]]

-- (Cap, shared/ai3/capital.lua, est PASSÉ en paramètre à Am.candidates : capital.lua requiert ce module, pas l'inverse.)

local Am = {}

Am.BATCH_MAX = 12   -- bâtiments par décision (une décision par pensée de 5 s : 240 foreuses en 100 s)
Am.PROD_PCT = 200   -- % : valeur d'un lot de DÉBIT (fours, foreuses, assembleurs) contre un lot de défense au même gain
Am.NEED_PCT = 150   -- % : valeur d'un bloc dont le PRODUIT manque au cerveau (« les chaînes en manque d'abord »)
Am.TOP = 3          -- blocs gardés pour le journal

--[[
  Lot AMELIORATION-CONTINUE (directive du DC, 8/11, 18 h 40 : « Amélioration Continue (Upgrade Continu) : Les PNJ ne doivent jamais
  s'arrêter. Disposant d'une automatisation totale de la production, ils doivent enchaîner la pose de structures en boucle et remplacer
  en continu les vieux convoyeurs/bras par leurs versions supérieures. » ; 11 h 20 : « penser en bloc et pas penser en petite unité
  [...] vérifiez également que les blocs soient améliorés en fonction de l'orientation. »).
  Mesure de départ (fo-logs/2026-11-08_AMELIORATION-CONTINUE/CRITERES.md) : une décision ne portait que ce que le stock payait déjà (un
  seul objet quand le stock était vide : « x1 ») ; la fabrication de la version supérieure n'était donc demandée qu'à l'unité, un
  paiement à la fois, et le bloc ne finissait jamais. Règles ajoutées (allumées avec la montée par bloc, ctx.continu) :
  1. FABRICATION PAR BLOC : la décision demande à la fabrication (projet de fond) le lot ENTIER du bloc (Am.fab : au plus Am.FAB_MAX
     pièces), pas seulement ce qui est payable ; le reste du lot est demandé même quand une partie vient d'être payée.
  2. FINIR LE BLOC : le groupe (bloc, rang) payé à la décision précédente garde une inertie de Am.GROUP_PCT % (Cap.candidates) : on
     termine un bloc avant d'en ouvrir un autre.
  3. ORIENTATION (Am.run_order) : les pièces d'un lot se suivent le long de la ligne (même axe, même ligne, puis dans le sens contraire
     du flux : l'aval d'abord), pour qu'une ligne ne reste pas mêlée de tapis lents et rapides ; aucun nom d'objet ; la table de
     direction est celle du moteur (nord 0, est 2, sud 4, ouest 6).
  4. OBTENABLE : un rang supérieur pas encore débloqué est RÉCLAMÉ à la recherche dès qu'il y a Am.RESEARCH_MIN pièces à monter (avant,
     « no_want » : la recherche n'était jamais réclamée par le remplacement).
  5. PARC (Am.parc) : le journal dit, par type et par rang, combien de pièces sont à chaque niveau (preuve de « plus de 50 % montés »).
]]
Am.FAB_MAX = 12        -- pièces d'un bloc de rangs demandées d'un coup à la fabrication
Am.GROUP_PCT = 25      -- % d'inertie du groupe (bloc, rang) payé à la décision précédente
Am.RESEARCH_MIN = 24   -- pièces d'un rang inférieur à partir desquelles la recherche du rang supérieur est réclamée
Am.ENGAGE_TICKS = 21600  -- 6 min : un remplacement entamé garde la tête tant qu'il progresse (un paiement) ; au-delà sans paiement, il est lâché
Am.FAIL_GAP = 28800     -- 8 min : après un engagement lâché sans progrès, aucun nouvel engagement (les buts payables au stock passent)
Am.REST_TICKS = 54000   -- 15 min : le groupe lâché ne reprend pas la tête avant ce repos
Am.STARVE_TICKS = 72000 -- 20 min : un rang (objet cible) sans aucun paiement depuis ce temps passe devant les buts payables au stock
Am.DIR_AXIS = { [0] = "v", [2] = "h", [4] = "v", [6] = "h" }   -- axe d'une direction du moteur (nord 0, est 2, sud 4, ouest 6)
Am.DIR_SIGN = { [0] = -1, [2] = 1, [4] = 1, [6] = -1 }         -- sens du flux le long de l'axe (+1 : vers les coordonnées croissantes)

--- Pièces demandées à la fabrication pour un bloc de `total` pièces à monter : le bloc entier, au plus `cap` (Am.FAB_MAX), au moins 1.
function Am.fab(total, cap)
  return math.max(1, math.min(cap or Am.FAB_MAX, total or 1))
end

--- Ordre d'orientation : `list` = { { id, x, y, dir } } (x, y, dir facultatifs) ; rend une NOUVELLE liste : d'abord les pièces à
--- direction connue, par axe (horizontal puis vertical), par ligne (la coordonnée qui ne change pas le long de l'axe), puis par la
--- coordonnée le long de l'axe, l'AVAL d'abord (sens contraire du flux) ; les pièces sans position ou sans direction à la fin, par
--- numéro. Déterministe (le numéro départage en dernier).
local function order_key(m)
  local axis = m.dir ~= nil and Am.DIR_AXIS[m.dir] or nil
  if not (axis and m.x and m.y) then return 3, 0, 0 end
  local sign = Am.DIR_SIGN[m.dir]
  if axis == "h" then return 1, m.y, -sign * m.x end
  return 2, m.x, -sign * m.y
end

-- a, b = { axe, ligne, le long, numéro, pièce } : a passe-t-il avant b ?
local function before(a, b)
  if a[1] ~= b[1] then return a[1] < b[1] end
  if a[2] ~= b[2] then return a[2] < b[2] end
  if a[3] ~= b[3] then return a[3] < b[3] end
  return a[4] < b[4]
end

function Am.run_order(list)
  local dec = {}
  for i, m in ipairs(list or {}) do
    local ax, ln, al = order_key(m)
    dec[i] = { ax, ln, al, m.id, m }
  end
  table.sort(dec, before)
  local out = {}
  for i, it in ipairs(dec) do out[i] = it[5] end
  return out
end

--- Les `n` premières pièces de Am.run_order(list), sans trier la liste entière (une insertion bornée : O(taille × n) au pire, une
--- comparaison par pièce en général) : un bloc de milliers de tapis n'en paie que douze à la fois.
function Am.first_n(list, n)
  if n <= 0 then return {} end
  local kept, nk = {}, 0
  local axes, signs = Am.DIR_AXIS, Am.DIR_SIGN
  list = list or {}
  for i = 1, #list do
    local m = list[i]
    -- (la clé d'order_key, en ligne : un bloc de milliers de pièces passe ici une fois par décision)
    local ax, ln, al
    local d, x, y = m.dir, m.x, m.y
    local axis = d and axes[d]
    if axis and x and y then
      if axis == "h" then ax, ln, al = 1, y, -signs[d] * x else ax, ln, al = 2, x, -signs[d] * y end
    else
      ax, ln, al = 3, 0, 0
    end
    -- Une pièce qui ne passe pas avant la dernière gardée (liste pleine) n'alloue rien : le cas courant d'un grand bloc.
    local worst = kept[nk]
    local wax = worst and worst[1]
    if nk < n or ax < wax or (ax == wax and (ln < worst[2] or (ln == worst[2] and (al < worst[3] or (al == worst[3] and m.id < worst[4]))))) then
      local it = { ax, ln, al, m.id, m }
      local pos = nk + 1
      while pos > 1 and before(it, kept[pos - 1]) do pos = pos - 1 end
      table.insert(kept, pos, it)
      nk = nk + 1
      if nk > n then kept[nk] = nil; nk = n end
    end
  end
  local out = {}
  for i, it in ipairs(kept) do out[i] = it[5] end
  return out
end

--- Parc : `machines` = { { name } } (relevé des pièces remplaçables), `mproto(nom)` -> { type, group, speed } ou nil. Rend une liste
--- TRIÉE de { key = "type/groupe", total, tiers = { { name, speed, n } } (vitesse croissante), up = pièces au-dessus du plus bas niveau
--- de la famille (`catalog`, facultatif : noms du catalogue des prototypes ; sans lui, le plus bas niveau vu) }.
function Am.parc(machines, mproto, catalog)
  local by, keys, low = {}, {}, {}
  for _, m in ipairs(machines or {}) do
    local p = mproto(m.name)
    if p and p.group and (p.speed or 0) > 0 then
      local k = tostring(p.type) .. "/" .. tostring(p.group)
      local g = by[k]
      if not g then g = { key = k, total = 0, per = {} }; by[k] = g; keys[#keys + 1] = k end
      g.total = g.total + 1
      g.per[m.name] = (g.per[m.name] or 0) + 1
    end
  end
  for _, name in ipairs(catalog or {}) do
    local p = mproto(name)
    if p and p.group and (p.speed or 0) > 0 then
      local k = tostring(p.type) .. "/" .. tostring(p.group)
      if not low[k] or p.speed < low[k] then low[k] = p.speed end
    end
  end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    local g = by[k]
    local tiers = {}
    for _, name in ipairs(Am.sorted_keys(g.per)) do tiers[#tiers + 1] = { name = name, speed = mproto(name).speed, n = g.per[name] } end
    table.sort(tiers, function(a, b)
      if a.speed ~= b.speed then return a.speed < b.speed end
      return a.name < b.name
    end)
    local floor_speed = low[k] or tiers[1].speed
    local up = 0
    for _, t in ipairs(tiers) do if t.speed > floor_speed then up = up + t.n end end
    out[#out + 1] = { key = k, total = g.total, tiers = tiers, up = up }
  end
  return out
end

--- Ligne de journal (ASCII) d'un groupe du parc.
function Am.parc_line(row)
  local parts = {}
  for _, t in ipairs(row.tiers) do parts[#parts + 1] = t.name .. " " .. t.n end
  return string.format("%s : %s ; montees %d/%d (%d%%)", row.key, table.concat(parts, ", "), row.up, row.total,
    row.total > 0 and math.floor(100 * row.up / row.total) or 0)
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Coût d'un lot : `n` fois la liste { {objet, quantité} } (nouvelle liste).
function Am.scaled(list, n)
  local out = {}
  for i, it in ipairs(list or {}) do out[i] = { it[1], it[2] * n } end
  return out
end

--- Stock NET : `stock` moins ce que la reconstruction des projets rouverts prendra encore (`recon` : { [objet] = quantité }, facultatif),
--- objet par objet, jamais sous zéro. Nouvelle table ; `stock` n'est pas modifié.
function Am.net(stock, recon)
  local out = {}
  for _, k in ipairs(sorted_keys(stock)) do out[k] = stock[k] end
  for _, k in ipairs(sorted_keys(recon)) do
    if out[k] then out[k] = math.max(0, out[k] - recon[k]) end
  end
  return out
end

--- Le stock `avail` couvre-t-il toute la liste ?
function Am.covers(avail, list)
  for _, it in ipairs(list or {}) do
    if ((avail or {})[it[1]] or 0) < it[2] then return false end
  end
  return true
end

--- Plus grand nombre de fois (≤ cap) que le stock paie la liste `unit` ; `stock` : { [objet] = quantité }.
function Am.supported(unit, stock, cap)
  local k = cap
  for _, it in ipairs(unit or {}) do
    if it[2] > 0 then
      local n = math.floor(((stock or {})[it[1]] or 0) / it[2])
      if n < k then k = n end
    end
  end
  if k < 0 then k = 0 end
  return k
end

--- Lot AMELIORATION-CONTINUE, ENGAGEMENT (cause mesurée, banc geants432-02ffcbe5 : 0 tapis monté en 120 min) : un but dont la pièce est à
--- fabriquer perdait la tête, à chaque décision, contre tout but payable au stock (Cap.candidates, `ready`) : son projet de fabrication
--- se fermait au bout d'une minute et la pièce n'existait jamais. Un pas de l'état `st` (nombres et tables de nombres, aucune fonction) :
---   ev.start  = groupe du remplacement décidé ; ev.paid = groupe d'un paiement fait ; ev.threat = danger (rien ne passe devant la défense) ;
---   ev.alive  = false quand le groupe engagé n'a plus aucun candidat (bloc fini, rang plus faisable).
--- Rend le groupe ENGAGÉ (ou nil) : Cap.candidates le met en tête. Engagé dès la décision ; lâché sans progrès après Am.ENGAGE_TICKS
--- (repos Am.REST_TICKS pour ce groupe, intervalle Am.FAIL_GAP avant tout autre engagement) ; un paiement du groupe relance le compte.
function Am.engage_update(st, tick, ev)
  st.rest = st.rest or {}
  for _, k in ipairs(sorted_keys(st.rest)) do
    if tick >= st.rest[k] then st.rest[k] = nil end
  end
  ev = ev or {}
  if st.group and ev.paid == st.group then st.progress = tick end
  if st.group then
    if ev.threat or ev.alive == false then
      st.group = nil
    elseif tick - (st.progress or tick) > Am.ENGAGE_TICKS then
      st.rest[st.group] = tick + Am.REST_TICKS
      st.gap_until = tick + Am.FAIL_GAP
      st.group = nil
    end
  end
  if not st.group and ev.start and not ev.threat and not st.rest[ev.start] and tick >= (st.gap_until or 0) then
    st.group, st.progress = ev.start, tick
  end
  return st.group
end

--- Lot AMELIORATION-CONTINUE, FAMINE : rangs (objets cibles des remplacements) sans paiement depuis Am.STARVE_TICKS. `kinds` = liste des
--- cibles présentes parmi les candidats ; st.seen[cible] = 1er tick vu, st.paid[cible] = dernier paiement. Rend { [cible] = true }.
function Am.starved_kinds(st, tick, kinds)
  st.seen, st.paid = st.seen or {}, st.paid or {}
  local out = {}
  for _, k in ipairs(kinds or {}) do
    if st.seen[k] == nil then st.seen[k] = tick end
    local since = math.max(st.seen[k], st.paid[k] or 0)
    if tick - since >= Am.STARVE_TICKS then out[k] = true end
  end
  return out
end

--- Groupes (bloc, famille) du relevé. ents = liste { id, name, working, block, fixed } ; rend une liste TRIÉE de
--- { block, fam, members (triés par numéro), fixed }. Le centre (famille sans condition de centre) n'en fait pas partie.
function Am.groups(Ld, ents, cfam)
  local by, keys = {}, {}
  for _, e in ipairs(ents or {}) do
    local fam, n = Ld.parse(e.name)
    if fam and fam ~= cfam and n then
      local block = e.block or "?"
      local k = block .. "|" .. fam.key
      local g = by[k]
      if not g then
        g = { block = block, fam = fam, members = {}, fixed = false }
        by[k] = g
        keys[#keys + 1] = k
      end
      g.members[#g.members + 1] = { id = e.id, n = n, working = e.working and true or false, x = e.x, y = e.y, dir = e.dir }
      if e.fixed then g.fixed = true end
    end
  end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    local g = by[k]
    table.sort(g.members, function(a, b) return a.id < b.id end)
    out[#out + 1] = g
  end
  return out
end

--- Candidats « bloc ». Rend { cands (non triés), report } : report = une entrée par groupe { block, family, size, low, level,
--- state = "decide" ou "refuse", cause (chaîne), n }. ctx : celui de Cap.candidates + cc_level (niveau du centre, 0 : aucun),
--- exclude ("bloc:..." ou "e:<numéro>" -> vrai), need(bloc, famille) -> pour cent (facultatif), current (clé en cours).
function Am.candidates(Ld, ents, ctx, cfam, Cap)
  local cands, report = {}, {}
  local cc = ctx.cc_level or 0
  local net = Am.net(ctx.stock, ctx.recon) -- le lot ne prend jamais ce qui manque encore à une reconstruction ouverte
  for _, g in ipairs(Am.groups(Ld, ents, cfam)) do
    local fam = g.fam
    local m = math.huge
    for _, mb in ipairs(g.members) do if mb.n < m then m = mb.n end end
    local low = {}
    for _, mb in ipairs(g.members) do if mb.n == m then low[#low + 1] = mb end end
    local row = { block = g.block, family = fam.key, size = #g.members, low = #low, level = m, state = "refuse" }
    report[#report + 1] = row
    local key = "bloc:" .. g.block .. ":" .. fam.key .. ":" .. (m + 1)
    if m >= fam.max then
      row.cause = "niveau-max"
    elseif not Ld.check(fam, m + 1, cc) then
      row.cause = cc < 1 and "sans-centre" or "plafond-centre"
    elseif g.fixed and Ld.footprint(fam, m) ~= Ld.footprint(fam, m + 1) then
      row.cause = "emprise"
    elseif ctx.exclude and ctx.exclude[key] then
      row.cause = "refus-recent"
    else
      -- Les bâtiments déjà refusés seuls (place, moteur) sont écartés du lot sans fermer le bloc ; en marche d'abord.
      local avail = {}
      for _, mb in ipairs(low) do
        if not (ctx.exclude and ctx.exclude["e:" .. mb.id]) then avail[#avail + 1] = mb end
      end
      -- Lot AMELIORATION-CONTINUE : en marche d'abord, puis dans l'ordre d'orientation (la ligne se suit ; sans position : par numéro).
      avail = Am.run_order(avail)
      local run, idle = {}, {}
      for _, mb in ipairs(avail) do
        if mb.working then run[#run + 1] = mb else idle[#idle + 1] = mb end
      end
      for _, mb in ipairs(idle) do run[#run + 1] = mb end
      avail = run
      if #avail == 0 then
        row.cause = "refus-recent"
      else
        local unit = Ld.cost(fam, m + 1)
        local u_cost, missing = Cap.work_cost(unit, ctx)
        if #missing > 0 then
          row.cause = "sans-cout:" .. table.concat(missing, ",")
          row.missing = missing
        else
          local pay_n = Am.supported(unit, net, math.min(Am.BATCH_MAX, #avail))
          -- Gel levé sauf manque : le stock couvre le coût mais pas le coût PLUS les pièces manquantes d'une reconstruction ouverte, objet par objet.
          local held
          if pay_n == 0 then
            for _, it in ipairs(unit) do
              if ((ctx.stock or {})[it[1]] or 0) >= it[2] and (net[it[1]] or 0) < it[2] then held = it[1] break end
            end
          end
          -- Rien en stock pour un seul : un seul est demandé (fabrication, comme un bâtiment seul), le lot grossit avec le stock.
          local n = math.max(1, pay_n)
          local ids, value, kind, gain = {}, 0, nil, 0
          if held then n = 0; row.cause = "reconstruction:" .. held end
          for i = 1, n do
            local mb = avail[i]
            ids[i] = mb.id
            local v, why = Cap.building_value(Ld, ctx.proto, fam, m, mb.working, ctx)
            value = value + v
            if why then kind, gain = why[1], why[2] end
          end
          if held then
            -- refus dit (cause reconstruction:<objet>), rien à décider
          elseif value > 0 then
            if kind == "debit" then value = math.floor(value * Am.PROD_PCT / 100 + 0.5) end
            local need = ctx.need and ctx.need(g.block, fam.key) or 100
            if need ~= 100 then value = math.floor(value * need / 100 + 0.5) end
            local cost = Am.scaled(unit, n)
            local work, _, all_in = Cap.work_cost(cost, ctx)
            local score = math.floor(value * 1000 / (work + Cap.COST_FLOOR))
            if ctx.current and ctx.current == key then score = math.floor(score * (100 + Cap.INERTIA_PCT) / 100) end
            cands[#cands + 1] = { key = key, id = ids[1], ids = ids, n = n, unit = unit, family = fam.key, from = m, to = m + 1,
              fab = ctx.continu and Am.fab(#avail, Am.BATCH_MAX) or nil, -- lot AMELIORATION-CONTINUE : le bloc entier est demandé à la fabrication
              cost = cost, work = work, all_in = all_in, value = value, score = score, bloc = g.block, bloc_size = #g.members,
              bloc_low = #low, why = { { kind or "debit", gain }, { "bloc", g.block }, { "batiments", n .. "/" .. #low } } }
            row.state, row.n, row.cause = "decide", n, nil
            row.pay_n = pay_n
          else
            row.cause = "sans-gain"
          end
        end
      end
    end
  end
  return { cands = cands, report = report }
end

--- Ligne de journal (ASCII) d'un groupe du rapport.
function Am.line(row)
  if row.state == "decide" then
    return string.format("bloc %s famille %s : decide %d/%d batiment(s) niveau %d -> %d (taille %d)", row.block, row.family, row.n,
      row.low, row.level, row.level + 1, row.size)
  end
  return string.format("bloc %s famille %s : refuse (%s) niveau %d, %d/%d au plus bas", row.block, row.family, tostring(row.cause),
    row.level, row.low, row.size)
end

--- Signature d'un groupe (le journal ne répète pas une ligne identique).
function Am.signature(row)
  return table.concat({ row.state, tostring(row.cause or ""), row.level, row.size, row.n or 0 }, "|")
end

Am.sorted_keys = sorted_keys

return Am
