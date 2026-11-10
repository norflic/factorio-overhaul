--[[
  Lot ASSAUTS-TITANESQUES (10/11, axe 2 du Mode Démon) : ASSAUTS DE BOSS coordonnés sur les bases des factions (IA et équipe du joueur).
  Règles PURES (Lua pur, testées par tests/assaut_titan_test.lua ; aucune API du jeu). Le moteur réel : script/combat/assaut_titan.lua.

  Un assaut = un Kaiju cristallin de l'ÈRE de la partie (shared/robots/titans.lua, T.kaiju) à la tête d'une escorte de déchiqueteurs
  dimensionnée aux DÉFENSES relevées de la cible, qui part de points de rassemblement autour de la base visée, marche groupé, assaille,
  et se replie si le Kaiju meurt. Tout est lu aux données : évolution des ennemis (force naturelle), âge de la partie (le plus haut des
  forces, Armee.age), ères (L.ERA_EPOCHS), paliers des déchiqueteurs (shared/content/enemies.lua), défenses comptées par l'appelant.
  Rien de mesuré en temps (ticks du jeu seulement), aucun pairs, aucun hasard, aucune trigonométrie, aucun nom d'objet en dur
  (noms de prototypes par T.kaiju_name / E.unit_name). Chiffres PROVISOIRES, le DC tranche.

  Phases : annonce (les joueurs sont prévenus Ra.ANNONCE ticks avant) -> rassemblement (apparition étalée) -> marche (ordre d'attaque de
  la zone) -> assaut (arrivés à Ra.CIBLE_R de la base) -> fin « tombee » (plus une tourelle), « repoussee » (plus un assaillant) ;
  « repli » dès que le Kaiju meurt (les survivants rentrent, Ra.REPLI ticks au plus) ; « bloque » au-delà de Ra.TIMEOUT.
]]

local L = require("shared.levels.config")
local T = require("shared.robots.titans")
local E = require("shared.content.enemies")
local TD = require("shared.td.waves")

local Ra = {}

Ra.LOG = "[FO-ASSAUT]"
Ra.EVO_MIN = 0.50          -- évolution à partir de laquelle un assaut peut partir même tôt en âge
Ra.PERIODE = 30 * 3600     -- ticks entre deux assauts au départ (30 min)
Ra.PERIODE_MIN = 8 * 3600  -- plancher (8 min) quand évolution et âge sont au plus haut
Ra.ANNONCE = 45 * 60       -- préavis aux joueurs (45 s)
Ra.RASSEMBLEMENT = 3 * 3600 -- durée maximale du rassemblement (apparition étalée) avant la marche
Ra.REPLI = 2 * 3600        -- durée du repli après la mort du Kaiju : au-delà, les survivants sont rappelés
Ra.TIMEOUT = 15 * 3600     -- un assaut qui n'aboutit pas (chemin introuvable) est rappelé
Ra.DISTANCE = TD.spawn_distance -- rayon des points de rassemblement autour de la base (tuiles)
Ra.CIBLE_R = TD.target_radius   -- arrivé : à moins de ce rayon du centre de la base
Ra.DEFENSE_R = 60          -- rayon de relevé des tourelles d'une base (tuiles autour du QG)
Ra.ESCORTE = { par_tourelle = 1.5, min = 8, max = 90, cracheurs = 0.3 }
Ra.POINTS = { min = 1, max = 3 }     -- points de rassemblement selon le nombre d'assaillants
Ra.PAR_POINT = 30                    -- un point de rassemblement de plus par tranche de PAR_POINT assaillants
Ra.PHASES = { "annonce", "rassemblement", "marche", "assaut", "repli", "fin" }
Ra.ISSUES = { "tombee", "repoussee", "repli", "bloque" }

-- Douze positions d'un cercle unité (pas de 30°), sans trigonométrie (même table que les drones du Léviathan).
Ra.CERCLE = {
  { 1.0, 0.0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0.0, 1.0 }, { -0.5, 0.866 }, { -0.866, 0.5 },
  { -1.0, 0.0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0.0, -1.0 }, { 0.5, -0.866 }, { 0.866, -0.5 },
}

local function num(x) return type(x) == "number" and x or tonumber(x) end
local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- Âge de la partie : le plus haut des âges donnés (liste), au moins 1.
function Ra.age_partie(ages)
  local a = 1
  for _, x in ipairs(ages or {}) do
    local v = num(x)
    if v and v > a then a = math.floor(v) end
  end
  return a
end

--- Période entre deux assauts : Ra.PERIODE, réduite de moitié par l'évolution pleine et de moitié par l'âge au bout du jeu ; plancher PERIODE_MIN.
function Ra.periode(evolution, age, epochs)
  local evo = clamp(num(evolution) or 0, 0, 1)
  epochs = num(epochs) or L.EPOCHS
  local part_age = epochs > 1 and clamp(((num(age) or 1) - 1) / (epochs - 1), 0, 1) or 0
  local p = Ra.PERIODE * (1 - 0.5 * evo) * (1 - 0.5 * part_age)
  return math.max(Ra.PERIODE_MIN, math.floor(p))
end

--- Un assaut peut-il partir ? c = { tick, last (tick du départ du dernier assaut, nil : aucun), evolution, age, epochs, bases (nombre) }.
--- Rend ok, raison, période. Conditions : au moins une base ; l'âge atteint le premier âge des géants (T.AGE_MIN) OU l'évolution atteint
--- Ra.EVO_MIN ; la période est écoulée depuis le dernier départ (ou depuis le début de la partie).
function Ra.pret(c)
  c = c or {}
  local tick = num(c.tick) or 0
  if (num(c.bases) or 0) <= 0 then return false, "aucune base", nil end
  local age = num(c.age) or 1
  local evo = num(c.evolution) or 0
  if age < T.AGE_MIN and evo < Ra.EVO_MIN then return false, "trop tot", nil end
  local p = Ra.periode(evo, age, c.epochs)
  local since = tick - (num(c.last) or 0)
  if since < p then return false, "cadence", p end
  return true, "pret", p
end

--- Cible : parmi les bases { id, pos = { x, y }, defenses }, les bases visées aux `#bases - 1` derniers assauts (liste `recent` d'ids, la plus
--- récente en dernier) sont écartées (rotation), puis la mieux défendue l'emporte, à égalité le plus petit id (comparaison textuelle).
function Ra.cible(bases, recent)
  if not bases or #bases == 0 then return nil, "aucune base" end
  local exclus = {}
  local k = #bases - 1
  recent = recent or {}
  if k > 0 then
    for i = #recent, math.max(1, #recent - k + 1), -1 do exclus[tostring(recent[i])] = true end
  end
  local best
  for _, b in ipairs(bases) do
    if not exclus[tostring(b.id)] then
      if not best or (b.defenses or 0) > (best.defenses or 0)
        or ((b.defenses or 0) == (best.defenses or 0) and tostring(b.id) < tostring(best.id)) then
        best = b
      end
    end
  end
  if not best then return nil, "toutes recentes" end
  return best, "la mieux defendue"
end

--- Nombre de Kaijus d'un assaut : 1, un de plus toutes les 3 ères (ères lues aux données).
function Ra.kaijus(era) return 1 + math.floor((clamp(era, 1, T.ERAS) - 1) / 3) end

--- Palier des déchiqueteurs d'escorte : 2 par ère, borné aux paliers du mode défense (E.TD_TIERS, les plus lourds).
function Ra.palier_escorte(era) return clamp(2 * era, 1, E.TD_TIERS) end

--- Escorte : Ra.ESCORTE.par_tourelle déchiqueteurs par tourelle relevée, bornée [min, max] ; part de cracheurs.
function Ra.escorte(defenses)
  local n = math.ceil((num(defenses) or 0) * Ra.ESCORTE.par_tourelle)
  n = clamp(n, Ra.ESCORTE.min, Ra.ESCORTE.max)
  local cracheurs = math.floor(n * Ra.ESCORTE.cracheurs)
  return n - cracheurs, cracheurs
end

--- Part des mordeurs d'escorte doublés d'ÉCORCHÉS (mordeurs mutants, KAIJUS-MUTANTS) dès que leur ère est ouverte.
Ra.ECORCHES = 0.25

--- Composition : { { nom, nombre }, ... }, Kaiju(s) en tête (archétype de la ROTATION par les données : T.kaiju_pour(ère, n), n = numéro de
--- l'assaut, 1 par défaut), puis mordeurs puis cracheurs du palier d'escorte, puis les Écorchés (variante tournante) si leur ère est ouverte.
function Ra.composition(age, defenses, n)
  local era = T.era(age)
  n = math.max(1, math.floor(num(n) or 1))
  local out = { { T.kaiju_name(era, T.kaiju_pour(era, n)), Ra.kaijus(era) } }
  local tier = Ra.palier_escorte(era)
  local m, c = Ra.escorte(defenses)
  if m > 0 then out[#out + 1] = { E.unit_name("biter", tier), m } end
  if c > 0 then out[#out + 1] = { E.unit_name("spitter", tier), c } end
  if era >= T.ECORCHE.era_min and m > 0 then
    local v = T.ECORCHE.variants[(n - 1) % #T.ECORCHE.variants + 1]
    out[#out + 1] = { T.ecorche_name(v, era), math.ceil(m * Ra.ECORCHES) }
  end
  return out
end

function Ra.total(compo)
  local n = 0
  for _, it in ipairs(compo or {}) do n = n + it[2] end
  return n
end

--- Nombre de points de rassemblement pour `total` assaillants.
function Ra.n_points(total)
  return clamp(1 + math.floor((num(total) or 0) / Ra.PAR_POINT), Ra.POINTS.min, Ra.POINTS.max)
end

--- Points de rassemblement : `n` positions à Ra.DISTANCE du centre, sur le cercle à 12 crans, décalées de `cran` (0 à 11), réparties.
function Ra.points(centre, n, cran)
  local out = {}
  n = math.max(1, math.floor(num(n) or 1))
  for k = 1, n do
    local i = ((num(cran) or 0) + math.floor(12 * (k - 1) / n)) % 12 + 1
    local c = Ra.CERCLE[i]
    out[k] = { x = centre.x + c[1] * Ra.DISTANCE, y = centre.y + c[2] * Ra.DISTANCE }
  end
  return out
end

--- Point de rassemblement de l'assaillant numéro `i` (1..) parmi `n` points : tour de rôle.
function Ra.point_de(i, n) return (i - 1) % n + 1 end

--- Machine à phases. st = { phase, t0 (départ de l'annonce), t_phase (entrée dans la phase), issue } ;
--- obs = { tick, tout_apparu, kaijus_vivants, vivants, arrives, defenses }. Rend la phase suivante (ou la même) et l'issue si « fin ».
function Ra.suivante(st, obs)
  local tick = num(obs.tick) or 0
  local ph = st.phase
  if ph == "fin" then return "fin", st.issue end
  if tick - (num(st.t0) or tick) > Ra.TIMEOUT then return "fin", "bloque" end
  if ph == "annonce" then
    if tick - (num(st.t_phase) or tick) >= Ra.ANNONCE then return "rassemblement", nil end
    return ph, nil
  end
  -- dès que des assaillants existent : plus un vivant -> repoussée ; Kaiju mort -> repli
  local vivants = num(obs.vivants) or 0
  local kaijus = num(obs.kaijus_vivants) or 0
  if ph == "rassemblement" then
    if obs.tout_apparu and vivants == 0 then return "fin", "repoussee" end
    if obs.tout_apparu or tick - (num(st.t_phase) or tick) >= Ra.RASSEMBLEMENT then return "marche", nil end
    return ph, nil
  end
  if ph == "repli" then
    if vivants == 0 or tick - (num(st.t_phase) or tick) >= Ra.REPLI then return "fin", "repli" end
    return ph, nil
  end
  if vivants == 0 then return "fin", "repoussee" end
  if kaijus == 0 then return "repli", nil end
  if ph == "marche" then
    if obs.arrives then return "assaut", nil end
    return ph, nil
  end
  if ph == "assaut" then
    if (num(obs.defenses) or 0) == 0 then return "fin", "tombee" end
    return ph, nil
  end
  return ph, nil
end

--- Une ligne de journal par changement de phase (déterministe).
function Ra.ligne(cible_id, n_assaut, phase, issue, detail)
  local s = string.format("%s assaut %d sur %s : %s", Ra.LOG, n_assaut or 0, tostring(cible_id), phase)
  if issue then s = s .. " (" .. tostring(issue) .. ")" end
  if detail and detail ~= "" then s = s .. " ; " .. detail end
  return s
end

return Ra
