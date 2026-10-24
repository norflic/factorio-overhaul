--[[
  ÉCHELLE 30 (lot IA1-a, docs/EQUIPES_PNJ.md §16, §11, §12, §4.5) — PUR (aucune API Factorio).

  Décision du Directeur Créatif (24/10, 10 h 25, D-14) : équipes de PNJ organisées, propositions par défaut
  du §17. Ce module en porte la partie « taille » :
    - Q-IA1-2 (2) « 30 dès l'époque 1 » : le plafond d'effectif est le maximum réglé dès l'époque 1
      (fractions vides pour O.headcount_cap) ; départ à `fo-npc-start` (8) ; SEUL LE STOCK FREINE la montée
      (chaque recrue paie O.recruit_cost : kit + (10 + effectif) plaques de fer) ;
    - réglages de la taille (settings/team.lua) : une seule source pour les défauts, les bornes et la lecture
      runtime (un réglage absent, par exemple dans le moteur simulé des tests, rend son défaut) ;
    - tables CONSTANTES qui remplacent la trigonométrie de chargement relevée par la conception (§2) :
      cases au QG (64, au moins 36 exigées) et directions des gisements de départ ;
    - mesures publiées par équipe (§16) : inactivité RÉELLE et exécutants AU-DELÀ DU CARNET, séparément.

  Règles (ARCHITECTURE §2) : aucune API, aucune itération par l'ordre de `pairs`, aucune trigonométrie,
  arithmétique entière pour les décisions.
]]

local O = require("shared.team.org")

local S = {}

---------------------------------------------------------------------------------------------------
-- Réglages (étape settings : settings/team.lua ; runtime : S.read)
---------------------------------------------------------------------------------------------------
-- Ordre FIXE (déclaration et affichage). `min`/`max` : bornes du réglage. Défauts : docs/EQUIPES_PNJ.md §11.
S.SETTINGS = {
  -- Nombre de factions lancées par « /fo-war start » sans argument (le §11 prévoit 0 à 4 ; la guerre en exige
  -- au moins 2, War.start_at : bornes 2 à 4).
  { name = "fo-factions", default = 4, min = 2, max = 4, order = "f-a" },
  -- PNJ par faction (remplace F.defaults.engineers_max = 10).
  { name = "fo-team-npc-max", default = 30, min = 6, max = 60, order = "f-b" },
  -- PNJ de votre équipe (remplace T.player_workers_max = 8). Commande du lot : 6 à 60 (le §11 écrivait 0 à 60).
  { name = "fo-player-team-npc-max", default = 30, min = 6, max = 60, order = "f-c" },
  -- Effectif de départ (2 avant IA1), borné par le plafond de l'époque 1.
  { name = "fo-npc-start", default = 8, min = 2, max = 30, order = "f-d" },
  -- Garde de performance COMPTÉE EN AGENTS (jamais en temps : règle 4) : au-delà, recrutement suspendu.
  { name = "fo-agents-max", default = 300, min = 50, max = 600, order = "f-e" },
  -- Demandes de chemin ÉMISES par tick pour tout le mod (lissage ; la vraie limite reste fo-path-max-inflight).
  { name = "fo-path-issue-per-tick", default = 2, min = 1, max = 6, order = "f-f" },
  -- Correction du lot IA1-a (défauts M1 et M2 de la vérification, 24/10) : FREIN PAR LE TRAVAIL. Une équipe ne
  -- recrute (et ne fabrique l'équipement d'une recrue) que si AU PLUS ce nombre de ses PNJ sont sans tâche à la
  -- pensée. 0 (défaut provisoire, à confirmer par le DC) : on recrute quand tout le monde travaille ; 60 : aucun
  -- frein, seul le stock freine (Q-IA1-2 (2) à la lettre). Le plafond (30 dès l'époque 1) n'est pas touché.
  -- Raison, mesurée en moteur réel : sans travail (IA1-b), les recrues restent inactives et vident le stock
  -- (votre coffre de 1 540 à 148 fer à 20 min, 29 PNJ inactifs sur 30 ; NOTES.md du lot, « Correction »).
  { name = "fo-recruit-idle-max", default = 0, min = 0, max = 60, order = "f-g" },
}
S.DEFAULTS = {}
for _, s in ipairs(S.SETTINGS) do S.DEFAULTS[s.name] = s.default end

--- Valeur d'un réglage : `get(name)` rend la valeur brute (ou nil, ou lève une erreur si le réglage est
--- inconnu) ; on rend le défaut si elle manque, bornée sinon. Sans effet de bord.
function S.read(name, get)
  local spec
  for _, s in ipairs(S.SETTINGS) do if s.name == name then spec = s break end end
  assert(spec, "reglage inconnu : " .. tostring(name))
  local ok, v = pcall(get, name)
  if not ok or type(v) ~= "number" then return spec.default end
  v = math.floor(v)
  if v < spec.min then return spec.min end
  if v > spec.max then return spec.max end
  return v
end

---------------------------------------------------------------------------------------------------
-- Effectifs : Q-IA1-2 (2)
---------------------------------------------------------------------------------------------------
-- Fractions du plafond par époque passées à O.headcount_cap : VIDE = « 30 dès l'époque 1 » (option 2).
-- Option 1 (15, 25 puis 30) : O.CAP_FRACTION. Changer ici suffit : tout le runtime lit S.cap.
S.HEADCOUNT_FRACTIONS = {}

--- Plafond d'effectif d'une équipe à l'époque `epoch` pour un maximum réglé `max`.
function S.cap(epoch, max)
  return O.headcount_cap(epoch or 1, max, S.HEADCOUNT_FRACTIONS)
end

--- Effectif de départ : le réglage, borné par le plafond de l'époque 1 (et par le maximum).
function S.start_headcount(start, max)
  return math.min(start, S.cap(1, max))
end

--- Ouvriers voulus par le cerveau : le plafond de l'époque (le stock seul freine : la recrue se paie).
function S.workers_wanted(epoch, max)
  return S.cap(epoch, max)
end

--- Frein par le travail (réglage fo-recruit-idle-max) : vrai si l'équipe a PLUS de `limit` PNJ sans tâche ;
--- elle ne recrute alors pas. `limit` ≥ 60 (le maximum d'une équipe) : jamais de frein.
function S.recruit_held(idle, limit)
  return (idle or 0) > (limit or S.DEFAULTS["fo-recruit-idle-max"])
end

--- Coût d'une recrue (rang 1) : kit + (10 + effectif actuel) plaques de fer (O.recruit_cost, docs §9).
function S.recruit_cost(headcount)
  return O.recruit_cost(headcount)
end

---------------------------------------------------------------------------------------------------
-- Cases au QG (constantes : plus de trigonométrie au chargement, docs §2)
---------------------------------------------------------------------------------------------------
-- 64 cases en 4 anneaux autour du point de rassemblement (rayons 2,5 ; 4,5 ; 6,5 ; 8,5 ; 8, 12, 20 et 24 cases),
-- coordonnées multiples de 1/8 de tuile (exactes en virgule fixe 1/256, F92). Écart minimal entre deux cases :
-- 1,90 tuile (contrôlé par tests/ia1_scale_test.lua). Avant IA1-a : 16 cases calculées par cos/sin ; au-delà
-- de 16 PNJ, deux PNJ partageaient une case (F27).
S.HOME_SLOTS = {
  { 2.5, 0 }, { 1.75, 1.75 }, { 0, 2.5 }, { -1.75, 1.75 }, { -2.5, 0 }, { -1.75, -1.75 }, { 0, -2.5 }, { 1.75, -1.75 },
  { 4.375, 1.125 }, { 3.125, 3.125 }, { 1.125, 4.375 }, { -1.125, 4.375 }, { -3.125, 3.125 }, { -4.375, 1.125 }, { -4.375, -1.125 }, { -3.125, -3.125 },
  { -1.125, -4.375 }, { 1.125, -4.375 }, { 3.125, -3.125 }, { 4.375, -1.125 }, { 6.5, 0 }, { 6.125, 2 }, { 5.25, 3.875 }, { 3.875, 5.25 },
  { 2, 6.125 }, { 0, 6.5 }, { -2, 6.125 }, { -3.875, 5.25 }, { -5.25, 3.875 }, { -6.125, 2 }, { -6.5, 0 }, { -6.125, -2 },
  { -5.25, -3.875 }, { -3.875, -5.25 }, { -2, -6.125 }, { 0, -6.5 }, { 2, -6.125 }, { 3.875, -5.25 }, { 5.25, -3.875 }, { 6.125, -2 },
  { 8.375, 1.125 }, { 7.875, 3.25 }, { 6.75, 5.125 }, { 5.125, 6.75 }, { 3.25, 7.875 }, { 1.125, 8.375 }, { -1.125, 8.375 }, { -3.25, 7.875 },
  { -5.125, 6.75 }, { -6.75, 5.125 }, { -7.875, 3.25 }, { -8.375, 1.125 }, { -8.375, -1.125 }, { -7.875, -3.25 }, { -6.75, -5.125 }, { -5.125, -6.75 },
  { -3.25, -7.875 }, { -1.125, -8.375 }, { 1.125, -8.375 }, { 3.25, -7.875 }, { 5.125, -6.75 }, { 6.75, -5.125 }, { 7.875, -3.25 }, { 8.375, -1.125 },
}
S.SLOTS_REQUIRED = 36 -- docs §16, lot IA1-a : « au moins 36 cases au QG »
S.SLOT_CHECKS_PER_THINK = 2 -- cases revalidées par pensée d'équipe (tour de rôle : 64 cases en 32 pensées)

--- Première case libre (ni bloquée, ni prise) dans l'ordre de la table ; nil si aucune. `bad[i]` et
--- `owner[i]` : tables indexées par numéro de case (aucun parcours de `pairs`).
function S.free_slot(bad, owner)
  for i = 1, #S.HOME_SLOTS do
    if not bad[i] and owner[i] == nil then return i end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Gisements de départ des factions : directions CONSTANTES (remplace cos/sin de team.lua, docs §2)
---------------------------------------------------------------------------------------------------
-- Valeurs exactes de (cos a × 46, sin a × 46) pour les angles 0,35 ; 1,9 ; 3,45 ; 5,0 ; 2,7 ; 4,2 ; 5,8 ; 1,1 rad
-- (calculées une fois en Lua 5.2, 17 chiffres significatifs : les gisements tombent aux mêmes tuiles qu'avant).
S.SEED_DIST = 46
S.SEED_OFFSETS = {
  { 43.211144790979432, 15.773299142950762 },
  { -14.871320075721155, 43.529804033621069 },
  { -43.829637871338015, -13.962909584587749 },
  { 13.048460531308407, -44.110516634504371 },
  { -41.587318532784813, 19.659474490756171 },
  { -22.551997781672174, -40.092485531025055 },
  { 40.733897779300669, -21.371700253032838 },
  { 20.865421585576556, 40.995538562826027 },
}

---------------------------------------------------------------------------------------------------
-- Mesures publiées (docs §16 : « inactivité réelle et exécutants au-delà du carnet publiés séparément »)
---------------------------------------------------------------------------------------------------
--- tasks = tâches du tableau { kind, worker, claimed, work } (libres et prises) ; n = PNJ vivants ; idle = PNJ
--- sans tâche ; orientation = préréglage ou table (O.normalize) ; tick = maintenant.
--- Le reste d'une tâche prise est estimé par le runtime : durée estimée (O.TASK_WORK) moins le temps écoulé
--- depuis sa prise, au moins 0 (docs §4.2 : `work_left`). Renvoie :
---   { n, idle, idle_pct (entier, %), backlog_s (travail ouvert + restant, s), surplus (exécutants au-delà du
---     carnet à l'horizon de 5 min, O.pole_targets), open_s, taken_s }.
function S.metrics(tasks, n, idle, orientation, threatened, tick)
  local light = {}
  for i = 1, #tasks do
    local t = tasks[i]
    local w = t.work or O.TASK_WORK[t.kind] or O.DEFAULT_WORK
    local l = { kind = t.kind, worker = t.worker, work = w }
    if t.worker then
      local spent = math.floor(((tick or 0) - (t.claimed or tick or 0)) / 60)
      l.work_left = math.max(0, w - spent)
    end
    light[i] = l
  end
  local d = O.demand_from_tasks(light)
  local pts = O.normalize(orientation or "equilibre", threatened)
  local _, surplus = O.pole_targets(n, d.poles, pts, 0)
  local backlog = d.poles[1] + d.poles[2] + d.poles[3]
  return {
    n = n, idle = idle, idle_pct = n > 0 and math.floor(idle * 100 / n) or 0,
    backlog_s = backlog, surplus = surplus,
    open_s = d.open[1] + d.open[2] + d.open[3], taken_s = d.taken[1] + d.taken[2] + d.taken[3],
  }
end

-- Débit livré (« le m de Q-IA1-1 ») : production de la force en unités de matière brute (MU, BALANCE_SHEET §12 :
-- 1 = une plaque de fer). Seules les matières premières FINALES sont comptées (le minerai fondu en plaques ne
-- l'est qu'une fois, en plaques) : plaques de fer et de cuivre, charbon, pierre. Lue sur les statistiques de
-- production de la force (LuaForce.item_production_statistics) : aucune entité parcourue.
S.MU_ITEMS = { { "iron-plate", 1 }, { "copper-plate", 1 }, { "coal", 1 }, { "stone", 1 } }

return S
