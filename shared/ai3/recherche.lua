--[[
  IA3-a « RECHERCHE D'ABORD, RIEN D'IMPAYABLE » (docs/IA3_CERVEAU.md §6.2) : règle PURE appelée par le planificateur
  de l'ancien cerveau (shared/team/planner.lua) à l'étape « recherche », derrière un réglage éteint par défaut.

  Ce qu'elle change par rapport au planificateur de 0.4.28 (IA3-DIAG, causes C1 et C2) :
    1. les packs sont demandés DÈS LE DÉPART (plus de verrou « tech1 », 8e marche de l'échelle) ;
    2. la priorité dépend du CARACTÈRE (D-18, « recherche ou armée d'abord selon le caractère ») au lieu de 40 fixe :
       penchant recherche contre armée, tiré de la curiosité et de l'agressivité (traits d'IA2-0) et des postures du
       chef (IA2-a) ; de 36 (conquérant) à 56 (technocrate), l'armée ordinaire étant à 45 ;
    3. le plafond de 10 packs par sorte en cours devient A.BATCH (30) ;
    4. un niveau dont un pack est IMPAYABLE (pack non fabricable à la main, ou matière première qu'aucune source ne
       fournit) ne fait fabriquer AUCUN pack (critère K6 : 0 fabrication jetée ; défaut C1 : 120 rouges, 52 à 105
       verts et jusqu'à 60 militaires pour un niveau 4 impossible sans pétrole) ;
    5. GARDE DE L'ÉCONOMIE (revue B3 : IA2-a, 3e essai, une faction qui payait sa recherche avant son fer II s'est
       effondrée) : tant que l'économie du fer n'est pas faite (« fer II » non atteint), la priorité reste sous la
       fabrication d'objectif (50) ; et les packs ne puisent jamais dans le PLANCHER (matières du prochain avant-poste
       de l'échelle, calculé par l'appelant) : le nombre de packs est réduit pour le respecter.

  A.lean(traits, mix, affinity) -> penchant (−1000 à 1000) ; A.priority(lean, opts) -> priorité ;
  A.level_status(book, packs, obtainable) -> payable, causes ; A.plan(args) -> décision (voir plus bas).
  Aucun nom d'objet du jeu : les packs viennent de la table des niveaux de l'appelant (T.research), les matières du
  livre de recettes (shared/team/book.lua). Entiers et listes triées ; aucun hasard ; aucun pairs décisionnel.
]]

local A = {}

A.BATCH = 30            -- packs d'une sorte demandés à la fois (10 avant IA3-a)
A.PRIO_MID = 46         -- caractère neutre : juste au-dessus de l'armée ordinaire (45)
A.PRIO_SPAN = 10        -- ± 10 selon le penchant (36 à 56)
A.PRIO_GOAL = 50        -- fabrication d'objectif : plafond avant le fer II, plancher quand la recherche EST l'objectif
A.TRAIT_SPAN = 250      -- biais d'un trait (même forme que le chef d'IA2-a : (trait − 1 000) ÷ 2, borné)

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Penchant recherche contre armée (−1 000 armée d'abord, + 1 000 recherche d'abord).
--- traits = { curiosite, agressivite } (× 1 000, IA2-0) ; mix = postures du chef { {key, w}, ... } (w pour mille) ;
--- affinity = table des affinités des postures (C.AFFINITY d'IA2-a : { [posture] = { tech = ..., army = ... } }).
function A.lean(traits, mix, affinity)
  local tech, army = 0, 0
  if traits then
    tech = clamp(math.floor(((traits.curiosite or 1000) - 1000) / 2), -A.TRAIT_SPAN, A.TRAIT_SPAN)
    army = clamp(math.floor(((traits.agressivite or 1000) - 1000) / 2), -A.TRAIT_SPAN, A.TRAIT_SPAN)
  end
  for _, m in ipairs(mix or {}) do
    local a = affinity and affinity[m.key] or nil
    if a then
      tech = tech + math.floor((a.tech or 0) * (m.w or 0) / 1000)
      army = army + math.floor((a.army or 0) * (m.w or 0) / 1000)
    end
  end
  return clamp(tech - army, -1000, 1000)
end

--- Priorité des packs. opts = { economy_done = bool (fer II atteint), is_goal = bool (la recherche est l'objectif) }.
function A.priority(lean, opts)
  opts = opts or {}
  local p = A.PRIO_MID + math.floor((lean or 0) * A.PRIO_SPAN / 1000)
  if not opts.economy_done and p > A.PRIO_GOAL - 1 then p = A.PRIO_GOAL - 1 end
  if opts.is_goal and p < A.PRIO_GOAL then p = A.PRIO_GOAL end
  return p
end

--- Un niveau est-il PAYABLE ? Chaque pack doit être fabricable à la main (livre : recette active, catégorie de la
--- main) et chaque matière première de son coût doit avoir une source (obtainable(matière) vrai). Renvoie payable,
--- causes (liste triée des packs ou matières en défaut).
function A.level_status(book, packs, obtainable)
  local causes = {}
  for _, it in ipairs(packs) do
    if not book:handcraftable(it[1]) then causes[it[1]] = true end
  end
  if next(causes) == nil then
    local raw = book:raw_cost(packs)
    for _, r in ipairs(sorted_keys(raw)) do
      if not obtainable(r) then causes[r] = true end
    end
  end
  local list = sorted_keys(causes)
  return #list == 0, list
end

--- Matières premières d'UN pack (livre, sans stock). Pas de cache : 3 packs au plus par niveau, calcul court, et
--- aucun état caché entre deux pensées (revue B1).
local function raw_per_pack(book, pack)
  return book:raw_cost({ { pack, 1 } })
end

--- Décision de recherche pour une pensée.
--- args = {
---   tech, levels (T.research), stock ({[objet] = n}), book, obtainable (fonction),
---   avail = stock virtuel APRÈS les besoins plus prioritaires de la pensée (le planificateur le tient),
---   floor = { [matière] = n } plancher à ne pas entamer (matières du prochain avant-poste de l'échelle), ou nil,
---   economy_done = bool, is_goal = bool, lean = penchant (A.lean),
--- }
--- Renvoie { level, payable, causes, have_all, wants = { {pack, n}, ... }, prio, held = raison ou nil, capped }.
---   have_all : tous les packs du niveau sont au stock (le planificateur paie le niveau) ;
---   wants    : packs à fabriquer (besoin d'accumulation, « fresh »), au plus A.BATCH par sorte, réduits par le plancher.
function A.plan(args)
  local level = (args.tech or 0) + 1
  local packs = args.levels and args.levels[level]
  local out = { level = level, wants = {}, payable = false, causes = {} }
  if not packs then out.held = "aucun niveau suivant" return out end
  local have_all = true
  for _, it in ipairs(packs) do
    if (args.stock[it[1]] or 0) < it[2] then have_all = false break end
  end
  out.have_all = have_all
  local ok, causes = A.level_status(args.book, packs, args.obtainable)
  out.payable, out.causes = ok, causes
  out.prio = A.priority(args.lean, { economy_done = args.economy_done, is_goal = args.is_goal })
  if have_all then return out end
  if not ok then out.held = "impayable" return out end
  -- Packs voulus, au plus A.BATCH par sorte (le reste à la pensée suivante).
  local wants = {}
  for _, it in ipairs(packs) do
    local h = args.stock[it[1]] or 0
    if h < it[2] then wants[#wants + 1] = { it[1], math.min(A.BATCH, it[2] - h) } end
  end
  -- Plancher : réduire chaque sorte (dans l'ordre du niveau) pour que les matières restantes ne passent jamais sous
  -- le plancher. Matières disponibles = stock virtuel − plancher.
  if args.floor and next(args.floor) ~= nil then
    local room = {}
    for _, r in ipairs(sorted_keys(args.floor)) do
      local a = (args.avail and args.avail[r]) or 0
      room[r] = a - args.floor[r]
    end
    local kept = {}
    for _, w in ipairs(wants) do
      local per = raw_per_pack(args.book, w[1])
      local n = w[2]
      for _, r in ipairs(sorted_keys(room)) do
        local need = per[r] or 0
        if need > 0 then
          local fit = room[r] > 0 and math.floor(room[r] / need) or 0
          if fit < n then n = fit end
        end
      end
      if n < w[2] then out.capped = true end
      if n > 0 then
        for _, r in ipairs(sorted_keys(room)) do room[r] = room[r] - (per[r] or 0) * n end
        kept[#kept + 1] = { w[1], n }
      end
    end
    wants = kept
    if #wants == 0 then out.held = "plancher de l'economie" end
  end
  out.wants = wants
  return out
end

return A
