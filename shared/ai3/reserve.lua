--[[
  Lot INDUSTRIE I1 (RESERVE). Retour du DC du 31/10 : « les IA gardent une réserve, mais pour aucune raison [...] elles doivent donc
  évaluer ou alors directement construire ». La capitalisation investissait un POURCENTAGE du stock libre (s × (1 - δ - α) × 50 %, soit
  18,75 % par minute avec les valeurs de base, 80 % au plus) : le reste dormait, sans besoin évalué derrière. Un module de coût C
  n'était payable que si le stock atteignait environ 5,3 × C.

  Règle (PURE : aucune API Factorio, aucun nom d'objet ; les listes { {objet, n} } et le livre de recettes viennent des appelants) :
    1. le BESOIN (le noyau) est ÉVALUÉ : ce que le planificateur va consommer (tâches libres, recrue, armée, munitions), la défense
       (postes sous leur minimum, objets non encore pris par une tâche), la reconstruction (pièces sans tâche, projet rouvert) et les
       recrues voulues (sous l'effectif de départ, ou du travail attend et la recrue n'est pas encore payée), majorés de
       Rs.MARGIN_PCT % (le stock bouge entre deux pensées) ;
    2. le stock LIBRE est ce qui reste de chaque matière une fois le noyau payé (Book:plan : exact par matière, 49 000 plaques de
       cuivre ne paient pas une tourelle de fer) ; un noyau non couvert vide la matière qui manque ;
    3. la capitalisation (shared/ai3/capitalisation.lua, Ca.budget) investit CE stock libre, sans pourcentage : un ordre se paie dès que
       le stock hors besoin le couvre. Le rythme reste borné par les emplacements ouverts et Ca.MAX_ORDERS, pas de vidage en un cycle ;
    4. le FLUX garde sa règle (s, δ, α) ; sous menace du QG la règle d'avant s'applique en entier (Ca.decide ne reçoit pas de réserve).
  La « production d'abord » (shared/team/priorite.lua : le fer ne paie pas la défense ET la production) retire la défense du noyau,
  comme elle retire déjà δ et α du budget : sinon le stock restait bloqué par une défense que cette décision a justement différée.
  Déterminisme : listes triées, entiers, aucun hasard, aucun temps mesuré.
]]

local Bg = require("shared.ai3.budget")
local Pi = require("shared.ai3.pile")

local Rs = {}

Rs.MARGIN_PCT = 110 -- le noyau est majoré de 10 % (comme Bg.MARGIN_PCT)
Rs.FRESH_TICKS = 1800 -- un noyau plus vieux que 6 pensées n'est plus lu (la règle d'avant s'applique)
-- Raisons de la règle d'effectif (shared/ai3/effectif.lua) où une recrue est VOULUE : du travail attend au-delà des bras libres
-- (« cout » : pas encore payée ; « rythme » : payée, la période n'est pas écoulée ; « recrue » : décidée) ; sous l'effectif de
-- départ (« plancher ») et sans frein : la recrue part dès que le stock la paie.
Rs.RECRUIT_REASONS = { cout = true, rythme = true, recrue = true, plancher = true, sans_frein = true }

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Ajoute `list` ({ {objet, n} }) à la somme `acc` ({ [objet] = n }), `times` fois.
local function add(acc, list, times)
  for _, it in ipairs(list or {}) do
    if it[1] and (it[2] or 0) > 0 then acc[it[1]] = (acc[it[1]] or 0) + it[2] * (times or 1) end
  end
end

--- Recrues voulues : v = { workers, wanted, floor, blocked, held, reason (règle d'effectif, factions) ou nil, cost = { {objet, n} },
--- margin = { objet, n } (facultatif : la marge que la règle d'effectif garde au-delà du coût) }. Rend (nombre, liste du coût).
--- Plancher : toutes les recrues qui manquent à l'effectif de départ ; sinon une seule (la règle de croissance en fait une à la fois).
function Rs.recruits(v)
  v = v or {}
  if v.blocked then return 0, {} end
  local workers, wanted, floor = v.workers or 0, v.wanted or 0, v.floor or 0
  local n = 0
  if workers < floor then n = floor - workers
  elseif workers < wanted then
    if v.reason ~= nil then
      if Rs.RECRUIT_REASONS[v.reason] then n = 1 end
    elseif not v.held then
      n = 1 -- votre équipe : la recrue part dès que le coffre la paie (planificateur)
    end
  end
  if n <= 0 then return 0, {} end
  local acc = {}
  add(acc, v.cost, n)
  if v.margin and v.margin[1] and (v.margin[2] or 0) > 0 then acc[v.margin[1]] = (acc[v.margin[1]] or 0) + v.margin[2] end
  local list = {}
  for _, k in ipairs(sorted_keys(acc)) do list[#list + 1] = { k, acc[k] } end
  return n, list
end

--- Le noyau. in = { posts = { { id, have, want, claim } }, repair = { { item, claimed, enemy } }, plan_wants = { {objet, n} },
--- planned = { [objet] = n } (consommation du planificateur permanent, shared/ai3/cerveau.lua C.consumed), recruit = { {objet, n} },
--- production_first }. Rend la liste TRIÉE { {objet, n} } (avant la marge) et les parts { defense, rebuild, planned, recruit } en
--- nombre d'objets, pour le journal.
function Rs.core(inp)
  inp = inp or {}
  local acc = {}
  local parts = { defense = 0, rebuild = 0, planned = 0, recruit = 0, research = 0 }
  local function count(list) local s = 0 for _, it in ipairs(list or {}) do s = s + (it[2] or 0) end return s end
  -- consommation déjà décidée du planificateur
  local planned = {}
  for _, k in ipairs(sorted_keys(inp.planned)) do planned[#planned + 1] = { k, inp.planned[k] } end
  add(acc, planned)
  parts.planned = count(planned)
  -- défense : postes sous leur minimum, sauf les postes de croissance et facultatifs (comme la pile) et sauf « production d'abord »
  if not inp.production_first then
    for _, p in ipairs(inp.posts or {}) do
      if (p.have or 0) < (p.want or 0) and not Pi.GROWTH_POSTS[p.id] and not Pi.OPTIONAL_POSTS[p.id] then
        add(acc, p.claim)
        parts.defense = parts.defense + count(p.claim)
      end
    end
  end
  -- Lot PARITE (reprise du 2/11) : réserve de survie (shared/team/priorite.lua, Pr.survival_reserve) : en « production d'abord », le fer de la
  -- défense d'une cellule attaquée n'est pas du stock libre (ni la capitalisation ni le puits ne le prennent) ; payée même si la production passe d'abord
  add(acc, inp.floor)
  parts.defense = parts.defense + count(inp.floor)
  -- reconstruction : pièces dont aucune tâche n'est prise (une place tenue par l'ennemi n'est pas refaite), puis le projet rouvert
  local by_item = {}
  for _, r in ipairs(inp.repair or {}) do
    if r.item and not r.claimed and not r.enemy then by_item[r.item] = (by_item[r.item] or 0) + 1 end
  end
  for _, k in ipairs(sorted_keys(by_item)) do
    acc[k] = (acc[k] or 0) + by_item[k]
    parts.rebuild = parts.rebuild + by_item[k]
  end
  add(acc, inp.plan_wants)
  parts.rebuild = parts.rebuild + count(inp.plan_wants)
  add(acc, inp.recruit)
  parts.recruit = count(inp.recruit)
  -- Lot S1 : réserve de chargeurs sur la menace reçue (au coffre : Rs.evaluate compte le stock), payée même quand la production passe d'abord
  add(acc, inp.ammo)
  parts.defense = parts.defense + count(inp.ammo)
  -- Lot S1 : packs de la recherche qui débloque la tourelle (sans elle, la défense ne se bâtit pas)
  add(acc, inp.research)
  parts.research = count(inp.research)
  local list = {}
  for _, k in ipairs(sorted_keys(acc)) do list[#list + 1] = { k, acc[k] } end
  return list, parts
end

--- Évaluation. book : livre de recettes (Book:plan) ; stock : { [objet] = n } (non modifié) ; core : liste de Rs.core.
--- Rend { covered, free = { [objet] = n } (le stock une fois le noyau payé), missing = { [matière] = n }, core = liste majorée }.
function Rs.evaluate(book, stock, core)
  local out = { covered = true, free = {}, missing = {}, core = {}, zero = {} }
  if not (book and book.plan) then
    out.covered = false
    return out
  end
  out.core = Bg.scaled(core, Rs.MARGIN_PCT)
  local pl = book:plan(out.core, stock or {})
  out.missing = pl.raw
  out.covered = next(pl.raw) == nil
  for _, k in ipairs(sorted_keys(pl.avail)) do
    if (pl.avail[k] or 0) > 0 then out.free[k] = pl.avail[k] end
    if (pl.avail[k] or 0) <= 0 then out.zero[k] = true end
  end
  -- Intégration 0.6.30 : `zero` = matières que le besoin prend en entier (absentes de `free`) : Ca.capi_view ne les confond pas avec un objet que
  -- l'évaluation n'a pas vu (en route, pas au coffre), sinon les projets gardaient 75 % de la matière même qui manque à la défense.
  for _, k in ipairs(sorted_keys(pl.raw)) do out.zero[k] = true end
  return out
end

--- L'état gardé par l'équipe (nombres, listes et tables : peut aller dans `global`), recalculé à chaque pensée du cerveau.
--- inp.raw_need = { [matière] = { n, prio } } (manques bruts du planificateur) : intégration 0.6.30, moteur simulé (survie_moteur_test) : 30 fer au
--- coffre, le planificateur en manque, rien à payer sur l'instant : besoin « couvert », réserve de croissance levée, 2 recrues de votre équipe de
--- plus et le fer à 6 (le risque d'IA1-b2, essai 6 : 8 -> 14 PNJ, fer à 56, QG perdu). Le manque déclaré n'est jamais couvert.
function Rs.state(book, stock, inp, tick)
  local core, parts = Rs.core(inp)
  local ev = Rs.evaluate(book, stock, core)
  local raw = (inp or {}).raw_need
  for _, k in ipairs(sorted_keys(raw)) do
    local n = raw[k].n or 0
    if n > 0 then
      ev.covered = false
      ev.missing[k] = math.max(ev.missing[k] or 0, n)
    end
  end
  ev.tick, ev.parts = tick, parts
  return ev
end

--- Le noyau est-il couvert et récent ? (votre équipe : la réserve de croissance ne s'applique plus.) st = l'état de Rs.state.
function Rs.covered(st, tick)
  return st ~= nil and st.covered == true and st.tick ~= nil and tick - st.tick <= Rs.FRESH_TICKS
end

--- Entrée de la capitalisation : { free, covered, parts, missing } ou nil (état absent ou périmé : la règle d'avant).
function Rs.input(st, tick)
  if st == nil or st.tick == nil or tick - st.tick > Rs.FRESH_TICKS then return nil end
  return { free = st.free or {}, zero = st.zero or {}, covered = st.covered == true, parts = st.parts, missing = st.missing or {} }
end

--- Une ligne lisible du besoin (journal [FO-RESERVE] ; aucune décision ne la lit).
function Rs.describe(st)
  if not st then return "besoin : non evalue" end
  local p = st.parts or {}
  local miss = {}
  for _, k in ipairs(sorted_keys(st.missing)) do miss[#miss + 1] = k .. " " .. math.ceil(st.missing[k] - 1e-9) end
  return string.format("besoin %s : prevu %d, defense %d, reconstruction %d, recrues %d%s (objets, marge %d %%)%s",
    st.covered and "COUVERT" or "NON couvert", p.planned or 0, p.defense or 0, p.rebuild or 0, p.recruit or 0,
    (p.research or 0) > 0 and string.format(", recherche de la tourelle %d", p.research) or "", Rs.MARGIN_PCT,
    #miss > 0 and (" ; manque " .. table.concat(miss, ", ")) or "")
end

return Rs
