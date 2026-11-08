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
      g.members[#g.members + 1] = { id = e.id, n = n, working = e.working and true or false }
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
      table.sort(avail, function(a, b)
        if a.working ~= b.working then return a.working end
        return a.id < b.id
      end)
      if #avail == 0 then
        row.cause = "refus-recent"
      else
        local unit = Ld.cost(fam, m + 1)
        local u_cost, missing = Cap.work_cost(unit, ctx)
        if #missing > 0 then
          row.cause = "sans-cout:" .. table.concat(missing, ",")
          row.missing = missing
        else
          local pay_n = Am.supported(unit, ctx.stock, math.min(Am.BATCH_MAX, #avail))
          -- Rien en stock pour un seul : un seul est demandé (fabrication, comme un bâtiment seul), le lot grossit avec le stock.
          local n = math.max(1, pay_n)
          local ids, value, kind, gain = {}, 0, nil, 0
          for i = 1, n do
            local mb = avail[i]
            ids[i] = mb.id
            local v, why = Cap.building_value(Ld, ctx.proto, fam, m, mb.working, ctx)
            value = value + v
            if why then kind, gain = why[1], why[2] end
          end
          if value > 0 then
            if kind == "debit" then value = math.floor(value * Am.PROD_PCT / 100 + 0.5) end
            local need = ctx.need and ctx.need(g.block, fam.key) or 100
            if need ~= 100 then value = math.floor(value * need / 100 + 0.5) end
            local cost = Am.scaled(unit, n)
            local work, _, all_in = Cap.work_cost(cost, ctx)
            local score = math.floor(value * 1000 / (work + Cap.COST_FLOOR))
            if ctx.current and ctx.current == key then score = math.floor(score * (100 + Cap.INERTIA_PCT) / 100) end
            cands[#cands + 1] = { key = key, id = ids[1], ids = ids, n = n, unit = unit, family = fam.key, from = m, to = m + 1,
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
