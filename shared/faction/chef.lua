--[[
  CHEF d'une faction (lot IA2-a, « chef v0 ») — PUR (aucune API Factorio), testable hors jeu (tests/chef_test.lua).
  Conception : fo-logs/2026-10-24_ANALYSE/IA_ADAPTATIVE.md §B2 (postures, utilité), §B3.1 (mémoire), §B6 (hasard
  borné, enveloppes PvP) ; choix provisoires D-16 (brouillard partout, alliances tacites).

  Le chef pense une fois par minute (C.PERIOD). Il ne commande aucun PNJ : il REMPLACE des constantes que le cerveau
  d'équipe et la décision d'attaque lisaient :
    - l'ORDRE des objectifs d'équipe (T.ladder, le même pour tous avant IA2-a) : C.ladder_order ;
    - le multiplicateur du seuil d'attaque entre factions (tirage ±20 % refait à chaque pensée × posture) ;
    - la RIVALE visée (valeur ÷ défense estimée sous brouillard, rancune, ouverture, mémoire des échecs) ;
    - les RAIDS (5 à 10 soldats sur l'avant-poste vu le moins défendu) ;
    - le CÔTÉ d'arrivée d'une attaque (rassemblement avancé dans l'un des 8 octants autour de la cible) : C.pick_side.
  `S.decide` (shared/faction/strategy.lua) reste le juge final : contre le joueur, rien ne change ; entre factions,
  à un niveau agressif, la réserve du joueur passe avant (S.player_reserve).

  Postures (8) : expansion, capitalisation, technologie, fortification, armee, assaut, raids, reconstruction. Chacune
  a 3 ou 4 CONSIDÉRATIONS (courbes entières de 0 à 1 000) ; score = moyenne × poids du trait (pour mille) × confiance
  de la mémoire (500 à 1 500) × inertie (dominante en cours : + 15 % × discipline). Une dominante tient au moins
  C.MIN_HOLD (5 min), sauf crise (menace ≥ 800). HASARD BORNÉ : tirage, au prorata du score, entre les postures à 90 %
  ou plus de la meilleure ; jamais une option faible. Mélange : dominante 60 %, 2e 25 %, 3e 15 %.

  Mémoire (B3.1) : registre des 8 dernières attaques {cible, octant, effectif, issue} ; une attaque REPOUSSÉE pénalise
  son octant (le côté suivant change), grossit la suivante (seuil × 1,3 contre cette cible) et fait baisser la cible
  10 min ; confiance par posture (± 100 à la fin de chaque épisode, bornée) ; sites perdus (menace, reconstruction) ;
  rancune envers qui a détruit nos bâtiments (décroît de 10 % par pensée).

  Déterminisme : entiers et listes triées (aucun `pairs` décisionnel), aucune trigonométrie ; tirages injectés
  (`draw(n)` → entier de 1 à n), flux du chef `Tr.new_stream(graine, 200 + id)` (script/faction/chef.lua).
  État : nombres, chaînes et tables seulement (stocké dans `global` par le runtime).
]]

local T = require("shared.team.config")

local C = {}

C.PERIOD = 3600            -- une pensée par minute
C.MIN_HOLD = 5 * 3600      -- durée minimale d'une dominante
C.CRISIS = 800             -- menace au-delà de laquelle la dominante peut changer avant MIN_HOLD
C.CRISIS_HOLD = 2 * 3600   -- même en crise, une dominante tient au moins 2 min
C.NEAR = 900               -- hasard entre les options à 90 % ou plus de la meilleure (pour mille)
C.INERTIA = 150            -- + 15 % pour la dominante en cours, × discipline / 1 000
C.WEARY = 25               -- lassitude : − 2,5 % par minute au-delà de MIN_HOLD (÷ discipline), jusqu'à − 50 %
                           -- (moteur réel, 1er essai à 4 % : 6,5 à 9,5 changements de dominante par heure, seuil ≤ 6)
C.EPISODE_CHECK = 10 * 3600 -- bilan intermédiaire d'un épisode long (confiance − 50 si rien n'avance)
C.MIX = { 600, 250, 150 }  -- dominante, 2e, 3e (pour mille)
C.MULT_LO, C.MULT_HI = 700, 1400 -- bornes du multiplicateur du seuil d'attaque entre factions
C.MEMORY = 8               -- attaques retenues
C.AVOID_TICKS = 10 * 3600  -- une cible qui a repoussé une attaque est moins attirante pendant 10 min
C.RAID_GAP = 5 * 3600      -- un raid au plus toutes les 5 min
C.LOST_WINDOW = 15 * 3600  -- sites perdus « récents »
C.SIDE_RADIUS = 56         -- rassemblement avancé : à 56 tuiles de la cible (hors de portée des tourelles)

C.POSTURES = { "expansion", "capitalisation", "technologie", "fortification", "armee", "assaut", "raids", "reconstruction" }

-- Facteur de la posture sur le seuil d'attaque entre factions (pour mille) : < 1 000 = attaque plus tôt.
C.WAR_FACTOR = { expansion = 1050, capitalisation = 1100, technologie = 1100, fortification = 1300, armee = 1150,
  assaut = 800, raids = 1000, reconstruction = 1300 }

-- Catégorie de chaque marche de T.ladder (ordre des objectifs) et affinité des postures (pour mille).
C.CATEGORY = { coal = "boot", iron = "boot", copper = "boot2c", stone = "boot2s", defense = "fort", army = "army",
  iron2 = "ext", tech1 = "tech", smelter = "cap", army2 = "army", iron3 = "ext", tech2 = "tech", fortify = "fort",
  iron4 = "ext", tech3 = "tech", expand = "ext", oil = "last" }
C.AFFINITY = {
  expansion = { ext = 1000, cap = 300 },
  capitalisation = { cap = 1000, ext = 500 },
  technologie = { tech = 1000 },
  fortification = { fort = 1000, army = 300 },
  armee = { army = 1000, fort = 300 },
  assaut = { army = 1000 },
  raids = { army = 600 },
  reconstruction = { fort = 600, ext = 600 },
}
C.LADDER_SHIFT = 400 -- avance au plus de 4 marches (rang × 100 − affinité × 400 / 1 000) ; 250 au 1er essai en moteur
                     -- réel : 9 premières décisions identiques pour toutes les factions (distance des 20 décisions 0,32)
-- Cuivre et pierre (amorçage, après charbon et fer) suivent les affinités de la technologie et de la fortification.
C.BOOT_CAT = { boot2c = "tech", boot2s = "fort" }
-- Trait qui biaise chaque catégorie dès la 1re pensée (caractère).
C.CAT_TRAIT = { ext = "ambition", cap = "discipline", tech = "curiosite", fort = "prudence", army = "agressivite" }
-- Place au plus tard d'une marche (l'armée : 7e, la 1re attaque contre le joueur dépend de la garnison).
C.LATEST = { { "army", 7 } }
-- Prérequis : une marche ne passe jamais devant celles-ci.
-- Lot IA2-a, 3e essai en moteur réel : avec la recherche avant le 2e avant-poste de fer, une faction a payé deux
-- recherches avant son fer II (la recherche suivante continue en fond dès « tech1 » atteint, shared/team/planner.lua)
-- et s'est effondrée (graine 777, Écarlate : tech 2 à 18 min, plus jamais de fer II, 0 soldat à 60 min). La recherche
-- et la grande armée suivent l'économie du fer.
C.AFTER = { iron3 = { "iron2" }, iron4 = { "iron3" }, expand = { "iron4" }, tech1 = { "iron2" }, tech2 = { "tech1" },
  tech3 = { "tech2", "iron3" }, army2 = { "army", "iron2" }, oil = { "tech3", "expand" } }

---------------------------------------------------------------------------------------------------
-- Courbes entières
---------------------------------------------------------------------------------------------------
--- 0 en a, 1 000 en b (a < b), bornée.
local function lin(x, a, b)
  if x <= a then return 0 end
  if x >= b then return 1000 end
  return math.floor((x - a) * 1000 / (b - a))
end
C.lin = lin

local function mean(list)
  local s = 0
  for _, x in ipairs(list) do s = s + x end
  return math.floor(s / #list)
end

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
function C.new(stream, tick)
  local conf = {}
  for _, p in ipairs(C.POSTURES) do conf[p] = 1000 end
  return {
    stream = stream, next_think = tick or 0, thinks = 0, changes = 0,
    dominant = nil, since = nil, mix = {}, scores = {}, reason = "-",
    confidence = conf, attacks = {}, grudge = {}, lost = {}, avoid = {}, extra_defense = {},
    war_mult = 1000, raid = nil, last_raid = nil, target = nil, ladder = nil, ladder_for = nil,
    episode = nil,
  }
end

---------------------------------------------------------------------------------------------------
-- Menace et considérations
---------------------------------------------------------------------------------------------------
--- Sites perdus pendant la fenêtre récente.
local function lost_recent(st, tick)
  local n = 0
  for _, t in ipairs(st.lost) do if tick - t <= C.LOST_WINDOW then n = n + 1 end end
  return n
end

--- Rancune la plus forte (pour mille) et la faction visée, dans l'ordre des numéros.
local function max_grudge(st, rivals)
  local best, who = 0, nil
  for _, r in ipairs(rivals) do
    local g = st.grudge[r.id] or 0
    if g > best then best, who = g, r.id end
  end
  return best, who
end

--- Menace (0 à 1 000) : pertes près du QG, sites perdus récents, soldats perdus, armée ennemie vue chez nous.
function C.threat(v, st)
  local t = 0
  if v.threatened then t = t + 400 end
  t = t + 250 * lost_recent(st, v.tick)
  t = t + math.floor(lin(v.soldiers_lost or 0, 0, 10) / 4)
  if v.enemy_near then t = t + 250 end
  return clamp(t, 0, 1000)
end

--- Meilleure cible (rivale) au sens de la valeur ÷ défense, avec rancune, ouverture et mémoire. Renvoie la liste
--- notée, triée (score décroissant, puis numéro).
function C.rank_targets(v, st)
  local tr = v.traits
  local out = {}
  for _, r in ipairs(v.rivals) do
    if r.reachable ~= false then
      local value = 2 + (r.outposts_seen or 0)
      if (r.outposts_seen or 0) > math.max(2, (v.outposts or 0) * 1.3) then value = value * 3 / 2 end -- leader vu : coalition tacite
      local def = (r.defense or 0) + (st.extra_defense[r.id] or 0)
      local s = math.floor(value * 100000 / (def + 10))
      s = math.floor(s * (1000 + math.floor((st.grudge[r.id] or 0) * tr.rancune / 1000)) / 1000)
      if r.army_out then s = math.floor(s * (1000 + math.floor(tr.opportunisme / 2)) / 1000) end
      if st.avoid[r.id] and v.tick < st.avoid[r.id] then s = math.floor(s / 2) end
      -- Inertie de la cible en cours (discipline) : on ne change pas de rivale pour un écart minime.
      if r.id == st.target then s = math.floor(s * (1000 + math.floor(C.INERTIA * tr.discipline / 1000)) / 1000) end
      local d = r.dist or 600
      s = math.floor(s * 600 / math.max(600, d))
      out[#out + 1] = { id = r.id, score = math.max(1, s), defense = def, rival = r }
    end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.id < b.id
  end)
  return out
end

--- Considérations des 8 postures (moyennes entières) et raison principale de chacune.
function C.considerations(v, st, best)
  local safety = 1000 - v.threat
  local lostn = lost_recent(st, v.tick)
  local g = max_grudge(st, v.rivals)
  local stock_dormant = (v.copper or 0) + (v.stone or 0)
  local workers = math.max(1, v.workers or 1)
  local idle = math.floor((v.idle or 0) * 1000 / workers)
  local c = {}
  c.expansion = { mean({ lin((v.desired or 0) - (v.outposts or 0), -1, 3), (v.sites or 0) > 0 and 1000 or 250, safety,
    lin(v.iron or 0, 20, 300) }), "territoire a prendre" }
  c.capitalisation = { mean({ lin(stock_dormant, 300, 2000), safety, lin(idle, 100, 600), lin(v.outposts or 0, 2, 8) }),
    "stock qui dort" }
  c.technologie = { mean({ lin(4 - (v.tech or 0), 0, 3), lin(v.copper or 0, 30, 400), safety, lin(v.minutes or 0, 5, 25) }),
    "retard technologique" }
  c.fortification = { mean({ v.threat, lin(v.unprotected or 0, 0, 4), g }), "menace" }
  local room = (v.army_target or 0) - (v.garrison or 0)
  c.armee = { mean({ lin(room, 0, math.max(1, v.army_target or 1)), 500 + math.floor(v.threat / 2),
    lin(v.minutes or 0, 3, 15) }), "armee a lever" }
  if best then
    local force = (v.garrison or 0) * (v.strength or 1)
    local ratio = math.floor(force * 1000 / (best.defense + 10))
    c.assaut = { mean({ lin(ratio, 1000, 3000), lin(2 + (best.rival.outposts_seen or 0), 2, 8),
      best.rival.army_out and 1000 or 400, lin(st.grudge[best.id] or 0, 0, 1000) }), "cible a portee" }
    local weak = best.rival.weak and 1000 or 0
    c.raids = { weak > 0 and mean({ weak, lin((v.garrison or 0) - (v.reserve or 0), 5, 20), safety }) or 0,
      "avant-poste isole" }
  else
    c.assaut = { 0, "aucune cible" }
    c.raids = { 0, "aucune cible" }
  end
  local lost_soldiers = v.soldiers_lost or 0
  if lostn > 0 or lost_soldiers > 5 then
    c.reconstruction = { mean({ lin(lostn, 0, 2), lin(lost_soldiers, 0, 15), lin((v.desired or 0) - (v.outposts or 0), 0, 4) }),
      "pertes a reparer" }
  else
    c.reconstruction = { 0, "rien a reparer" }
  end
  return c
end

--- Poids d'une posture par les traits (pour mille).
function C.weight(p, tr)
  if p == "expansion" then return tr.ambition end
  if p == "capitalisation" then return math.floor((tr.ambition + tr.discipline) / 2) end
  if p == "technologie" then return tr.curiosite end
  if p == "fortification" then return tr.prudence end
  if p == "armee" then return math.floor((tr.agressivite + tr.prudence) / 2) end
  if p == "assaut" then return tr.agressivite end
  if p == "raids" then return math.floor((tr.ruse + tr.opportunisme) / 2) end
  return tr.discipline -- reconstruction
end

--- Scores des 8 postures, triés (score décroissant, puis ordre de C.POSTURES).
function C.scores(v, st, best)
  local cons = C.considerations(v, st, best)
  local list = {}
  for i, p in ipairs(C.POSTURES) do
    local s = cons[p][1]
    s = math.floor(s * C.weight(p, v.traits) / 1000)
    s = math.floor(s * (st.confidence[p] or 1000) / 1000)
    if p == st.dominant then
      s = math.floor(s * (1000 + math.floor(C.INERTIA * v.traits.discipline / 1000)) / 1000)
      -- Lassitude : au-delà de MIN_HOLD, la dominante perd WEARY pour mille par minute (÷ discipline), jusqu'à
      -- la moitié : une autre posture finit par passer devant, sans retour au hasard pur.
      local held = math.floor((v.tick - (st.since or v.tick) - C.MIN_HOLD) / 3600)
      if held > 0 then
        local w = math.floor(held * C.WEARY * 1000 / math.max(500, v.traits.discipline))
        s = math.floor(s * (1000 - math.min(500, w)) / 1000)
      end
    end
    list[#list + 1] = { key = p, score = s, i = i, reason = cons[p][2] }
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.i < b.i
  end)
  return list
end

--- Hasard borné : tirage au prorata du score entre les options à C.NEAR pour mille ou plus de la meilleure.
--- `list` triée (meilleure d'abord) ; renvoie l'élément choisi.
function C.pick(list, draw)
  local best = list[1]
  if not best or best.score <= 0 then return best end
  local cand, total = {}, 0
  for _, it in ipairs(list) do
    if it.score * 1000 >= best.score * C.NEAR then
      cand[#cand + 1] = it
      total = total + it.score
    end
  end
  if #cand == 1 then return best end
  local x = draw(total)
  for _, it in ipairs(cand) do
    x = x - it.score
    if x <= 0 then return it end
  end
  return cand[#cand]
end

---------------------------------------------------------------------------------------------------
-- Ordre des objectifs (T.ladder)
---------------------------------------------------------------------------------------------------
--- Biais d'une catégorie par le caractère (−250 à + 250) : un trait au-dessus de 1 000 avance les marches de sa
--- catégorie dès la 1re pensée (l'ouverture n'est plus la même pour toutes les factions).
local function trait_bias(cat, traits)
  local k = C.CAT_TRAIT[cat]
  if not (k and traits and traits[k]) then return 0 end
  return clamp(math.floor((traits[k] - 1000) / 2), -250, 250)
end

--- Ordre des marches de T.ladder pour un mélange de postures et un caractère : charbon puis fer en tête ; cuivre et
--- pierre ensuite, dans l'ordre de leurs affinités ; les autres triées par rang × 100 − affinité × LADDER_SHIFT / 1 000
--- (affinité = mélange des postures + biais du caractère, bornée à 1 000 : avance de 4 marches au plus), en
--- respectant les prérequis (C.AFTER) et une place au plus tard pour l'armée (C.LATEST : la 1re attaque contre le
--- joueur dépend de la garnison). Renvoie une liste de clés.
function C.ladder_order(mix, ladder, traits)
  ladder = ladder or T.ladder
  local items = {}
  for i, g in ipairs(ladder) do
    local cat = C.CATEGORY[g.key] or "other"
    local key = i * 100
    local rank = cat == "boot" and 1 or ((cat == "boot2c" or cat == "boot2s") and 2 or 3)
    if cat ~= "boot" and cat ~= "last" then
      local acat = C.BOOT_CAT[cat] or cat
      local aff = trait_bias(acat, traits)
      for _, m in ipairs(mix) do
        local a = (C.AFFINITY[m.key] or {})[acat] or 0
        aff = aff + math.floor(a * m.w / 1000)
      end
      aff = clamp(aff, -1000, 1000)
      key = key - math.floor(aff * C.LADDER_SHIFT / 1000)
    end
    if cat == "last" then rank = 4 end
    items[#items + 1] = { key = g.key, sort = key, i = i, rank = rank }
  end
  table.sort(items, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.sort ~= b.sort then return a.sort < b.sort end
    return a.i < b.i
  end)
  -- Place au plus tard (armée) : remontée si elle a été repoussée au-delà.
  for _, lt in ipairs(C.LATEST) do
    local key, last = lt[1], lt[2]
    for k, it in ipairs(items) do
      if it.key == key and k > last then
        table.remove(items, k)
        table.insert(items, last, it)
        break
      end
    end
  end
  -- Prérequis : une marche placée avant l'un de ses prérequis est repoussée juste après lui (passes successives).
  for _ = 1, #items do
    local moved = false
    local pos = {}
    for k, it in ipairs(items) do pos[it.key] = k end
    for k, it in ipairs(items) do
      for _, req in ipairs(C.AFTER[it.key] or {}) do
        if pos[req] and pos[req] > k then
          table.remove(items, k)
          table.insert(items, pos[req], it)
          moved = true
          break
        end
      end
      if moved then break end
    end
    if not moved then break end
  end
  local out = {}
  for k, it in ipairs(items) do out[k] = it.key end
  return out
end

--- Marches de T.ladder dans l'ordre d'une liste de clés (mêmes tables : le planificateur compare par identité).
function C.ladder_entries(st)
  if not (st and st.ladder) then return nil end
  local by = {}
  for _, g in ipairs(T.ladder) do by[g.key] = g end
  local out = {}
  for _, k in ipairs(st.ladder) do
    if by[k] then out[#out + 1] = by[k] end
  end
  if #out ~= #T.ladder then return nil end
  return out
end

---------------------------------------------------------------------------------------------------
-- Épisodes et confiance
---------------------------------------------------------------------------------------------------
--- Résultat d'un épisode (−1, 0, +1) selon la posture et le bilan (valeurs de début et de fin).
function C.episode_result(ep, v, st)
  local p = ep.posture
  if p == "expansion" then return (v.outposts or 0) > ep.outposts and 1 or -1 end
  if p == "technologie" then return (v.tech or 0) > ep.tech and 1 or ((v.tick - ep.tick >= 10 * 3600) and -1 or 0) end
  if p == "fortification" then return (st.lost_total or 0) > ep.lost and -1 or 1 end
  if p == "armee" then return (v.garrison or 0) > ep.garrison and 1 or -1 end
  if p == "capitalisation" then return (v.goals or 0) > ep.goals and 1 or -1 end
  if p == "assaut" or p == "raids" then
    local w, l = 0, 0
    for _, a in ipairs(st.attacks) do
      if a.tick >= ep.tick and a.outcome and a.outcome ~= "dissous" then
        if a.outcome == "reussie" then w = w + 1 else l = l + 1 end
      end
    end
    if w > l then return 1 elseif l > w then return -1 end
    return 0
  end
  if p == "reconstruction" then return (v.outposts or 0) >= ep.outposts and 1 or 0 end
  return 0
end

local function open_episode(st, p, v)
  st.episode = { posture = p, tick = v.tick, outposts = v.outposts or 0, tech = v.tech or 0, lost = st.lost_total or 0,
    garrison = v.garrison or 0, goals = v.goals or 0 }
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
--- Pensée du chef. `v` : vue (nombres, voir script/faction/chef.lua) ; `draw(n)` : tirage entier de 1 à n.
--- Met à jour `st` et renvoie la décision : { dominant, mix, scores, reason, war_mult, raid, target, changed }.
function C.think(st, v, draw)
  st.thinks = (st.thinks or 0) + 1
  -- Rancune : décroît de 10 % par pensée.
  for _, r in ipairs(v.rivals) do
    local g = st.grudge[r.id]
    if g then
      g = math.floor(g * 9 / 10)
      st.grudge[r.id] = g > 0 and g or nil
    end
  end
  v.threat = C.threat(v, st)
  -- Bilan intermédiaire d'un épisode long : une dominante qui n'obtient rien en EPISODE_CHECK perd confiance.
  local ep = st.episode
  if ep and v.tick - (ep.checked or ep.tick) >= C.EPISODE_CHECK then
    if C.episode_result(ep, v, st) < 0 then
      st.confidence[ep.posture] = clamp((st.confidence[ep.posture] or 1000) - 50, 500, 1500)
    end
    ep.checked = v.tick
  end
  local targets = C.rank_targets(v, st)
  local best = targets[1]
  if #targets > 1 then best = C.pick(targets, draw) end
  local scores = C.scores(v, st, best)
  -- Dominante tenue MIN_HOLD ; en crise, elle peut changer plus tôt, mais pas avant CRISIS_HOLD (pas de girouette).
  local held_for = st.since and (v.tick - st.since) or 0
  local hold = st.dominant ~= nil and st.since ~= nil and held_for < C.MIN_HOLD
    and (v.threat < C.CRISIS or held_for < C.CRISIS_HOLD)
  local chosen
  if hold then
    for _, s in ipairs(scores) do if s.key == st.dominant then chosen = s end end
  end
  if not chosen then chosen = C.pick(scores, draw) end
  local changed = chosen.key ~= st.dominant
  if changed then
    if st.episode then
      local r = C.episode_result(st.episode, v, st)
      local p = st.episode.posture
      st.confidence[p] = clamp((st.confidence[p] or 1000) + 100 * r, 500, 1500)
    end
    if st.dominant then st.changes = (st.changes or 0) + 1 end
    st.dominant, st.since = chosen.key, v.tick
    open_episode(st, chosen.key, v)
  end
  -- Mélange : dominante, puis les 2 meilleures autres (score > 0).
  local mix = { { key = chosen.key, score = chosen.score } }
  for _, s in ipairs(scores) do
    if #mix >= 3 then break end
    if s.key ~= chosen.key and s.score > 0 then mix[#mix + 1] = { key = s.key, score = s.score } end
  end
  local wsum = 0
  for k, m in ipairs(mix) do wsum = wsum + C.MIX[k] end
  for k, m in ipairs(mix) do m.w = math.floor(C.MIX[k] * 1000 / wsum) end
  st.mix, st.scores, st.reason = mix, scores, chosen.reason
  -- Ordre des objectifs : recalculé quand la dominante change (stable entre deux changements).
  if changed or not st.ladder then
    st.ladder = C.ladder_order(mix, nil, v.traits)
    st.ladder_for = chosen.key
  end
  -- Seuil d'attaque entre factions : tirage (v.jitter, refait à chaque pensée par le runtime) × posture.
  local factor = 0
  for _, m in ipairs(mix) do factor = factor + math.floor((C.WAR_FACTOR[m.key] or 1000) * m.w / 1000) end
  local mult = math.floor((v.jitter or 1000) * factor / 1000)
  st.target = best and best.id or nil
  -- Mémoire : la dernière attaque contre cette cible a été repoussée : la suivante sera plus grosse.
  if best then
    for k = #st.attacks, 1, -1 do
      local a = st.attacks[k]
      if a.target == best.id then
        if a.outcome == "repoussee" or a.outcome == "aneantie" then mult = math.floor(mult * 13 / 10) end
        break
      end
    end
  end
  st.war_mult = clamp(mult, C.MULT_LO, C.MULT_HI)
  -- Raid : posture « raids » dans le mélange (poids ≥ 25 %), un avant-poste faible vu, au plus un toutes les RAID_GAP.
  st.raid = nil
  local raid_w = 0
  for _, m in ipairs(mix) do if m.key == "raids" then raid_w = m.w end end
  if best and best.rival.weak and raid_w >= 250 and (not st.last_raid or v.tick - st.last_raid >= C.RAID_GAP) then
    st.raid = 4 + draw(6)
    st.raid_target = best.id
  end
  return { dominant = chosen.key, mix = mix, scores = scores, reason = chosen.reason, war_mult = st.war_mult,
    raid = st.raid, target = st.target, changed = changed, threat = v.threat }
end

---------------------------------------------------------------------------------------------------
-- Côté d'arrivée (rassemblement avancé)
---------------------------------------------------------------------------------------------------
-- Vecteurs unitaires des 8 octants (0 = est, sens horaire à l'écran : 2 = sud, 4 = ouest, 6 = nord), sans trigonométrie.
local D = 0.70710678
C.DIRS = { [0] = { 1, 0 }, { D, D }, { 0, 1 }, { -D, D }, { -1, 0 }, { -D, -D }, { 0, -1 }, { D, -D } }

--- Octant d'un vecteur (même découpage que script/faction/journal.lua).
function C.octant(dx, dy)
  if dx == 0 and dy == 0 then return -1 end
  local TAN = 0.41421356
  local ax, ay = math.abs(dx), math.abs(dy)
  if ay <= TAN * ax then return dx > 0 and 0 or 4 end
  if ax <= TAN * ay then return dy > 0 and 2 or 6 end
  if dx > 0 then return dy > 0 and 1 or 7 end
  return dy > 0 and 3 or 5
end

--- Choix du côté d'arrivée : 8 octants autour de la cible, notés par l'écart à la direction directe (depuis notre
--- QG ; la ruse aplatit la courbe), pénalisés quand une attaque y a été repoussée (registre) ; tirage parmi les
--- 3 meilleurs, au prorata. `dx, dy` = vecteur cible → notre QG. Renvoie l'octant (0 à 7).
function C.pick_side(st, target_id, dx, dy, ruse, draw)
  local direct = C.octant(dx, dy)
  if direct < 0 then direct = 0 end
  local base = { [0] = 1000, 800, 450, 150, 50 }
  local flat = clamp(ruse or 1000, 500, 1500)
  local list = {}
  for o = 0, 7 do
    local gap = math.abs(o - direct)
    if gap > 4 then gap = 8 - gap end
    local s = base[gap]
    -- Ruse : une faction rusée accepte des détours (courbe aplatie).
    s = s + math.floor((1000 - s) * (flat - 500) / 2000)
    for _, a in ipairs(st.attacks) do
      if a.target == target_id and a.octant == o and (a.outcome == "repoussee" or a.outcome == "aneantie") then
        s = math.floor(s * 3 / 10)
      end
    end
    list[#list + 1] = { key = o, score = math.max(1, s), i = o }
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.i < b.i
  end)
  local top, total = {}, 0
  for k = 1, 3 do
    top[k] = list[k]
    total = total + list[k].score
  end
  local x = draw(total)
  for _, it in ipairs(top) do
    x = x - it.score
    if x <= 0 then return it.key end
  end
  return top[3].key
end

---------------------------------------------------------------------------------------------------
-- Mémoire : événements
---------------------------------------------------------------------------------------------------
--- Une attaque (ou un raid) part.
function C.record_attack(st, rec)
  st.attacks[#st.attacks + 1] = { target = rec.target, octant = rec.octant, n = rec.n, tick = rec.tick, gid = rec.gid,
    raid = rec.raid or nil }
  while #st.attacks > C.MEMORY do table.remove(st.attacks, 1) end
  if rec.raid then st.last_raid = rec.tick end
end

--- Fin d'une attaque : issue « reussie » (cible détruite), « repoussee » (survivants, cible debout), « aneantie »
--- (aucun survivant, cible debout) ou « dissous » (groupe défait par le moteur, soldats vivants : F174, sans leçon).
--- Une attaque repoussée rend la cible moins attirante et lui ajoute de la défense estimée (les pertes subies, en
--- équivalents fusiliers).
function C.record_outcome(st, gid, outcome, sent, survivors, tick)
  for k = #st.attacks, 1, -1 do
    local a = st.attacks[k]
    if a.gid == gid and not a.outcome then
      a.outcome, a.survivors = outcome, survivors
      st.dissolved = st.dissolved or {}
      if outcome == "dissous" then
        -- Groupe défait par le moteur (F174) : aucune leçon sur la défense ; mais 2 de suite contre la même cible
        -- (moteur réel, graine 777 : 328 groupes défaits au départ contre la même cible) la font éviter 10 min.
        local n = (st.dissolved[a.target] or 0) + 1
        st.dissolved[a.target] = n
        if n >= 2 then st.avoid[a.target] = tick + C.AVOID_TICKS end
        return a
      end
      st.dissolved[a.target] = nil
      if outcome ~= "reussie" then
        st.avoid[a.target] = tick + C.AVOID_TICKS
        local lost = math.max(0, (sent or 0) - (survivors or 0))
        st.extra_defense[a.target] = math.max(st.extra_defense[a.target] or 0, lost)
      else
        st.extra_defense[a.target] = nil
      end
      return a
    end
  end
  return nil
end

--- Un de nos sites est perdu (par `by` : numéro de faction, « player » ou nil).
function C.record_loss(st, tick, by)
  st.lost[#st.lost + 1] = tick
  while #st.lost > C.MEMORY do table.remove(st.lost, 1) end
  st.lost_total = (st.lost_total or 0) + 1
  if by and by ~= "player" then st.grudge[by] = clamp((st.grudge[by] or 0) + 400, 0, 1000) end
end

--- Un de nos bâtiments ou soldats est détruit par `by` (rancune légère).
function C.record_hit(st, by)
  if by and by ~= "player" then st.grudge[by] = clamp((st.grudge[by] or 0) + 20, 0, 1000) end
end

return C
