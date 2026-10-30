--[[
  Lot CRAFT-PARALLELE (retour du DC du 29/10, 0.6.18 : « ils peuvent fabriquer et faire autre chose en même temps […] peut-être
  qu'ils fabriquent et ils font rien en même temps […] vérifiez ça ») : règles PURES de la fabrication EN ARRIÈRE-PLAN d'un PNJ.

  Avant ce lot, une tâche « craft » (script/team/worker.lua) était home -> take -> craft -> home, et l'étape « craft » mettait le
  PNJ dans l'état « craft » jusqu'à ce que la file de fabrication de son personnage soit VIDE : il restait planté au QG pendant
  toute la fabrication (5 min au plus), alors que dans Factorio la file d'un personnage avance pendant qu'il marche, mine ou pose.
  Moteur simulé (scénario de pteam_test, 20 min, 6 graines) : 24,6 à 25,5 % du temps des PNJ dans cet état.
  Désormais, à l'étape « craft », la fabrication devient un TRAVAIL en arrière-plan (agent.bg.jobs, au plus C.MAX_JOBS) : le PNJ
  rend la main et prend une autre tâche ; la tâche « craft » reste PRISE au tableau (à son nom) jusqu'à la livraison de ses
  produits au coffre, à son prochain passage au QG.

  Ce module ne touche ni au moteur ni à `global` : il dit quelles matières mettre en réserve (étapes pas encore lancées), quelles
  tâches un PNJ qui fabrique prend, ce qui lui reste de file, et écrit le bilan [FO-CRAFT].
]]

local C = {}

-- Genres de tâches qu'un PNJ qui fabrique en arrière-plan NE PREND PAS (porte de la place de marché, script/team/board.lua) :
--   garrison : attente sur place de 5 min (O.TASK_WORK) : les produits resteraient 5 min en poche ;
--   build    : nouvel avant-poste, souvent loin (centaines de tuiles) : produits retenus longtemps, et un PNJ tué perd sa file.
-- Une fabrication de plus est permise jusqu'à C.MAX_JOBS travaux : elle s'enchaîne dans SA file, et le PNJ reste libre (essai
-- au moteur simulé, 3 graines : sans 2e fabrication, 141 à 153 fabrications en 20 min contre 195 à 198 pour l'ancien PNJ bloqué,
-- livraisons au coffre -15 à -25 % ; avec, 170 à 198).
C.EXCLUDED = { garrison = true, build = true }
C.MAX_JOBS = 2 -- travaux en arrière-plan par PNJ (un en cours, un qui attend derrière)
-- Genres qui se passent AU QG sans retarder la livraison (le programme ne quitte pas le QG avant de rendre la main) : pas de borne
-- de durée (C.fits).
C.AT_HOME = { craft = true }

C.REPORT_EVERY = 5 * 3600 -- bilan [FO-CRAFT] au plus toutes les 5 min par équipe

-- Retard de livraison toléré (s) : un PNJ qui fabrique ne prend une tâche NON urgente que si son travail estimé (task.work, durées
-- mesurées par script/team/poles.lua, sinon O.TASK_WORK) tient dans ce qui reste de sa file + C.SLACK_S. Moteur simulé (scénario de
-- pteam_test, 20 min) sans borne : produits 30 à 72 s en poche après la fin de la file (minage à 60 tuiles).
C.SLACK_S = 20
C.STEP_S = 0.5 -- durée d'une fabrication quand l'étape ne dit pas la sienne (energy absente) : la plus courte des recettes vanilla

--- Le PNJ qui fabrique en arrière-plan peut-il prendre une tâche de ce genre ? `full` : il a déjà C.MAX_JOBS travaux.
function C.allowed(kind, full)
  if C.EXCLUDED[kind or ""] then return false end
  if kind == "craft" and full then return false end
  return true
end

--- Secondes de file restantes d'un travail (vitesse de fabrication 1) : étapes list[i-1..n] (l'étape en cours, list[i-1], comptée
--- entière : estimation par excès). `energy` d'une étape = durée de toutes ses fabrications (shared/team/book.lua).
function C.left_s(list, i)
  local s = 0
  for k = math.max(1, (i or 1) - 1), #(list or {}) do
    local c = list[k]
    s = s + (c.energy or C.STEP_S * (c.runs or 1))
  end
  return s
end

--- Secondes de file restantes de tous les travaux pas encore fabriqués (`jobs` : { {list, i, ready}, ... }).
function C.left_jobs(jobs)
  local s = 0
  for _, j in ipairs(jobs or {}) do
    if not j.ready then s = s + C.left_s(j.list, j.i) end
  end
  return s
end

--- La tâche (genre `kind`, travail estimé `work_s`, priorité `prio`) tient-elle pendant la file restante `left_s` ? Une urgence
--- (prio >= urgent) passe toujours (la défense avant la livraison), une tâche du QG aussi (C.AT_HOME).
function C.fits(kind, work_s, prio, urgent, left_s)
  if (prio or 0) >= (urgent or math.huge) then return true end
  if C.AT_HOME[kind or ""] then return true end
  return (work_s or 0) <= (left_s or 0) + C.SLACK_S
end

--- `cannot` (genres interdits du PNJ, table { [genre] = true } ou nil) augmentée des genres exclus pendant une fabrication en
--- arrière-plan (et de « craft » s'il est plein, `full`). Table NEUVE (l'entrée, souvent une constante partagée, n'est jamais
--- modifiée). Ensemble : l'ordre de copie ne change rien.
function C.cannot_with(cannot, full)
  local out = {}
  if cannot then for k, v in pairs(cannot) do out[k] = v end end
  for k, v in pairs(C.EXCLUDED) do out[k] = v end
  if full then out.craft = true end
  return out
end

--- Matières à mettre en RÉSERVE : ingrédients des étapes pas encore lancées (list[i..n]) ; ingredients_of(recette) rend
--- { {objet, n}, ... } pour UNE fabrication. Les intermédiaires d'une étape lancée (engrenages pour la tourelle) y sont : ils
--- ne doivent ni partir au coffre au passage du PNJ au QG, ni être pris par une autre tâche. Rend { [objet] = n }.
function C.keep(list, i, ingredients_of)
  local out = {}
  for k = i or 1, #(list or {}) do
    local c = list[k]
    for _, ing in ipairs(ingredients_of(c.recipe) or {}) do
      out[ing[1]] = (out[ing[1]] or 0) + ing[2] * (c.runs or 1)
    end
  end
  return out
end

--- C.keep de tous les travaux, additionné.
function C.keep_jobs(jobs, ingredients_of)
  local out = {}
  for _, j in ipairs(jobs or {}) do
    local k = C.keep(j.list, j.i, ingredients_of)
    for item, n in pairs(k) do out[item] = (out[item] or 0) + n end
  end
  return out
end

--- Fenêtre du bilan (état créé en événement, sous l'équipe : `team.craft_bg`).
function C.window(team)
  local w = team.craft_bg
  if not w then
    w = { started = 0, done = 0, failed = 0, causes = {}, bg_ticks = 0, work_ticks = 0, delay_ticks = 0 }
    team.craft_bg = w
  end
  return w
end

--- Le bilan est-il dû ? La première demande arme seulement la date (pas de bilan d'une fenêtre partielle).
function C.due(w, tick)
  if not w.t then
    w.t = tick
    return false
  end
  return tick - w.t >= C.REPORT_EVERY
end

--- Remet la fenêtre à zéro (après le bilan).
function C.reset(w, tick)
  w.t = tick
  w.started, w.done, w.failed, w.causes = 0, 0, 0, {}
  w.bg_ticks, w.work_ticks, w.delay_ticks = 0, 0, 0
end

local function sorted_keys(t)
  local k = {}
  for key in pairs(t) do k[#k + 1] = key end
  table.sort(k)
  return k
end

--- Ligne du bilan [FO-CRAFT] : `live` = PNJ qui fabriquent en arrière-plan maintenant, `live_work` = parmi eux, ceux qui ont
--- AUSSI une tâche (ils fabriquent ET travaillent). Sur la fenêtre : travaux passés en arrière-plan, livrés, perdus (par cause) ;
--- secondes de fabrication en arrière-plan (travaux clos) et, parmi elles, secondes où le PNJ avait une autre tâche (temps de PNJ
--- RENDU au travail : avant ce lot, il attendait au QG) ; attente moyenne entre la fin de la fabrication et le dépôt au coffre.
function C.report_line(key, tick, w, live, live_work)
  local causes = {}
  for _, c in ipairs(sorted_keys(w.causes or {})) do causes[#causes + 1] = c .. ":" .. w.causes[c] end
  local pct = w.bg_ticks > 0 and math.floor(100 * w.work_ticks / w.bg_ticks + 0.5) or 0
  local delay = w.done > 0 and (w.delay_ticks / w.done / 60) or 0
  return string.format("[FO-CRAFT] %s a %.1f min : %d PNJ fabriquent en arriere-plan, dont %d au travail en meme temps | "
    .. "5 min : %d fabrication(s) passee(s) en arriere-plan, %d livree(s), %d perdue(s) {%s} | fond %.0f s dont %.0f s a "
    .. "travailler (%d %%) | depot au coffre %.1f s apres la fin (moyenne)",
    tostring(key), tick / 3600, live, live_work, w.started, w.done, w.failed, table.concat(causes, " "),
    w.bg_ticks / 60, w.work_ticks / 60, pct, delay)
end

return C
