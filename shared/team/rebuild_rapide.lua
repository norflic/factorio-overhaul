--[[
  Lot REBUILD-RAPIDE : règles PURES (aucune API Factorio, aucun nom d'objet du jeu) de la reconstruction rapide. Testées hors jeu par
  tests/rebuild_rapide_test.lua (avec mutants).

  Retour du DC (29/10 vers 22 h, en jouant la 0.6.18) : « Ils attendent. Pourquoi ils attendent ? […] Moi, j'ai attendu 1 minute, donc
  ils ont mis 10 minutes à reconstruire. C'est énorme, il y a une vague qui peut arriver entre-temps » ; « l'électricité est repartie mais
  tout n'est pas relié, surtout la partie la plus critique de la base n'est pas reliée, tout est toujours hors service. C'est la production
  principale de la base » ; « ils se font réattaquer au même endroit […] pas de nouvelles tourelles […] ils ont les ressources, ils ont 8000
  de fer » ; « le mieux, ça serait évidemment de remettre des foreuses thermiques et cetera, on refait fondre […] ils peuvent pas faire de
  foreuses électriques parce qu'ils ont plus de cuivre, donc voilà, thermiques. Ils auraient dû faire ça. »

  Quatre règles :
    (a) LATENCE. Une pièce d'un projet du plan directeur tuée (on_entity_died) est inscrite AU MOMENT de sa mort (Rr.hot_add : e.miss = date
        de la mort, liste « chaude » relue à chaque passe du relevé) au lieu d'attendre que le curseur du relevé (100 pièces par passe, une
        passe par pensée d'équipe de 5 s) repasse deux fois dessus ; et un projet ROUVERT n'attend plus d'avoir TOUTE sa matière au coffre
        pour reposer ses fantômes (Rr.partial_go) : ce qui est au coffre est refait tout de suite, le reste quand il arrive.
    (b) ORDRE. Priorité des tâches de reconstruction : l'infrastructure électrique (poteaux, centrale) d'abord, puis la production
        principale (fonderies, foreuses, champs de minerai), puis le reste (Rr.registry_prio, Rr.project_prio).
    (c) RICHE ET RÉATTAQUÉE. Une cellule du front attaquée par au moins Rr.WAVES vagues distinctes chez une équipe riche (Rr.rich) veut une
        tourelle de plus que la règle du front et reçoit TOUT son manque d'un coup (Rr.boost, Rr.rich_count) au lieu de Fr.BATCH par voyage.
    (d) FOREUSE THERMIQUE DE SECOURS. Une foreuse électrique d'un projet rouvert qui ne peut être ni prise au coffre ni fabriquée (plus de
        cuivre, donc plus de circuits) est remplacée au plan par une foreuse à combustion qui dépose dans le même réceptacle (Rr.subst_center) ;
        elle repasse en électrique dès que l'objet électrique est au coffre (Rr.revert_due).
  Déterminisme : listes dans l'ordre d'arrivée des événements (déterministe), clés triées, entiers, aucun hasard, aucun temps mesuré.
]]

local Ru = require("shared.team.ruines")
local S = require("shared.team.foreuse_swap") -- rotation des vecteurs de dépôt (même règle que Ru)
local Sw = require("shared.team.rebuild_sweep") -- lot FUITES-PILE : Sw.rebuilding (reconstruction contre agrandissement)
local Rc = require("shared.team.reconstruction") -- valeur d'une pièce d'infrastructure (poteau ou production d'énergie)

local Rr = {}

---------------------------------------------------------------------------------------------------
-- (a) Latence : liste chaude du relevé et réserve partielle d'un projet rouvert
---------------------------------------------------------------------------------------------------
Rr.HOT_MAX = 400 -- pièces chaudes retenues au plus par équipe (une attaque massive au-delà : le curseur du relevé fait le reste)

--- Une pièce `e` (rang `i` du projet `pid`) vient d'être tuée à `tick` : inscrite dans la liste chaude `st` (état du relevé) et marquée
--- absente à la date de sa mort (e.miss). Rend vrai si elle a été ajoutée. Une pièce non bâtie, abandonnée, retirée ou un mur : rien.
function Rr.hot_add(st, pid, i, e, tick)
  if not (st and e and e.built) or e.gave_up or e.dropped or e.wall then return false end
  st.hot = st.hot or {}
  st.hot_set = st.hot_set or {}
  local key = pid .. ":" .. i
  if st.hot_set[key] then return false end
  if #st.hot >= Rr.HOT_MAX then
    st.hot_full = (st.hot_full or 0) + 1
    return false
  end
  st.hot[#st.hot + 1] = { pid, i }
  st.hot_set[key] = true
  if not e.miss then e.miss = tick end
  e.died_t = tick
  return true
end

--- Remplace la liste chaude par `keep` ({ {pid, i} }, ordre conservé) et refait l'ensemble des clés.
function Rr.hot_set_list(st, keep)
  st.hot = keep
  st.hot_set = {}
  for _, h in ipairs(keep) do st.hot_set[h[1] .. ":" .. h[2]] = true end
end

-- Relecture REBUILD-RAPIDE : la liste chaude coûtait jusqu'à Rr.HOT_MAX lectures du moteur (count_entities_filtered) par passe et par
-- équipe tant qu'un ennemi tient la place (pic régulier, 4 factions, jeu en x10). Au plus Rr.HOT_PER_PASS pièces relues par passe (le
-- budget du curseur, Sw.SLICE) ; les autres passent EN TÊTE de la passe suivante (Rr.hot_next : rotation, aucune n'est oubliée).
Rr.HOT_PER_PASS = 100

--- Liste chaude après une passe : les entrées non relues (`later`, ordre gardé) d'abord, puis celles gardées après relecture (`kept`).
function Rr.hot_next(later, kept)
  local out = {}
  for _, h in ipairs(later or {}) do out[#out + 1] = h end
  for _, h in ipairs(kept or {}) do out[#out + 1] = h end
  return out
end

--- Relecture REBUILD-RAPIDE : un lot de chantier (une ancre) d'un projet ROUVERT vaut-il un voyage ? Vrai si au moins un objet qui pose
--- une de ses pièces (`items`) est au coffre pour lui (`have(item)` : réserve du projet + stock libre). Sinon le PNJ irait au coffre pour
--- rien (abandon « stock », puis 30 s de repos de la tâche) à la priorité de la reconstruction, devant les fabrications qui manquent.
function Rr.batch_ready(items, have)
  for _, it in ipairs(items or {}) do
    if (have(it) or 0) >= 1 then return true end
  end
  return false
end

--- Un projet rouvert par le relevé ou le réseau vivant (date de réouverture connue) reprend son chantier avec la matière qui est au coffre
--- au lieu d'attendre TOUTE la matière (« reserve[materiaux] » de 40 min pour 2 bras sans cuivre, alors que 27 tapis étaient à refaire).
--- Les murs d'enceinte rouverts (sans date) gardent la règle du tout-ou-rien.
function Rr.partial_go(p)
  return Sw.rebuilding(p) -- lot FUITES-PILE : rouvert APRÈS sa dernière fin (un agrandissement d'une ligne déjà réparée n'en est pas)
end

---------------------------------------------------------------------------------------------------
-- (b) Ordre de la reconstruction
---------------------------------------------------------------------------------------------------
-- Sous l'urgence et les tourelles (90 : O.URGENT_PRIO, T.defend_prio) ; au-dessus de la fin de chantier ordinaire (Build.FINISH_BONUS : 85).
Rr.PRIO_POWER = 89  -- production d'énergie : chaudières, machines à vapeur, pompes, centrale rouverte
Rr.PRIO_POLE = 88   -- poteaux (ils relient la production à la centrale)
Rr.PRIO_MAIN = 87   -- production principale : fonderies, foreuses, champs de minerai
-- Générateurs de modules (shared/team/modules.lua, M.GENERATORS) : des clés de gabarit, pas des objets du jeu.
Rr.POWER_GENS = { steam = true }
Rr.MAIN_GENS = { smelter = true, drills = true, outpost_burner = true }

--- Rang d'un projet rouvert selon son générateur : 1 = alimentation, 2 = production principale, 3 = le reste.
function Rr.project_rank(spec)
  local g = spec and (spec.gen or spec.key)
  if g and Rr.POWER_GENS[g] then return 1 end
  if g and Rr.MAIN_GENS[g] then return 2 end
  return 3
end

--- Priorité des tâches de chantier d'un projet : `base` (finish_prio) sauf pour un projet ROUVERT (Rr.partial_go), relevé à son rang.
function Rr.project_prio(p, base)
  if not Rr.partial_go(p) then return base end
  local rank = Rr.project_rank(p.spec)
  if rank == 1 then return math.max(base, Rr.PRIO_POWER) end
  if rank == 2 then return math.max(base, Rr.PRIO_MAIN) end
  return base
end

--- Priorité d'un lot du registre de reconstruction dont la pièce de tête est `r` : production d'énergie, poteaux, puis pièces d'un champ de
--- minerai (foreuses et réceptacles d'avant-poste), puis `base` (Rc.task_prio).
function Rr.registry_prio(r, base)
  if r and r.infra then return math.max(base, Rc.is_pole_value(r) and Rr.PRIO_POLE or Rr.PRIO_POWER) end
  if r and (r.kind == "drill" or r.kind == "sink") then return math.max(base, Rr.PRIO_MAIN) end
  return base
end

---------------------------------------------------------------------------------------------------
-- (c) Cellule du front réattaquée chez une équipe riche
---------------------------------------------------------------------------------------------------
Rr.WAVE_GAP = 1800        -- ticks (30 s) sans mort dans la cellule : la mort suivante ouvre une NOUVELLE vague
Rr.WAVE_FORGET = 30 * 3600 -- ticks : une cellule sans mort depuis 30 min oublie ses vagues
Rr.WAVES = 2              -- vagues distinctes pour « réattaquée »
Rr.RICH_IRON = 4          -- « riche » : fer au coffre >= 4 × le plancher de la défense (T.defend_iron_floor)
Rr.RICH_EXTRA = 1         -- tourelle(s) voulue(s) en plus de la règle du front
-- Partie du DC (factorio-current.log, Scarlet, de 98 à 133 min) : « front pose 16 », cellules « plafond » 1 330 pensées durant, avec 6 000 à
-- 19 000 de fer au coffre : le plafond d'équipe du front (Fr.TEAM_CAP = 16) empêchait toute tourelle de plus aux cellules réattaquées.
Rr.RICH_CAP = 8           -- places de plus sous le plafond d'équipe du front pour une équipe riche

--- Une mort dans la cellule `key` à `tick` : compte des vagues (st.waves[key] = { n, last }).
function Rr.wave_note(st, key, tick)
  if not (st and key) then return nil end
  st.waves = st.waves or {}
  local w = st.waves[key]
  if not w then
    w = { n = 0 }
    st.waves[key] = w
  end
  if w.last and tick - w.last > Rr.WAVE_FORGET then w.n = 0 end
  if not w.last or tick - w.last > Rr.WAVE_GAP then w.n = w.n + 1 end
  w.last = tick
  return w.n
end

--- Oublie les vagues trop anciennes (clés triées). Rend le nombre oublié.
function Rr.wave_prune(st, tick)
  if not (st and st.waves) then return 0 end
  local keys = {}
  for k in next, st.waves do keys[#keys + 1] = k end
  table.sort(keys)
  local n = 0
  for _, k in ipairs(keys) do
    local w = st.waves[k]
    if not w.last or tick - w.last > Rr.WAVE_FORGET then st.waves[k] = nil n = n + 1 end
  end
  return n
end

--- L'équipe est-elle riche ? Fer au moins Rr.RICH_IRON × `floor_i` et cuivre au moins `floor_cu` (une tourelle demande du cuivre).
function Rr.rich(iron, copper, floor_i, floor_cu)
  return (iron or 0) >= Rr.RICH_IRON * (floor_i or 0) and (copper or 0) >= (floor_cu or 0)
end

--- Cellules du front (Fr.top) d'une équipe riche : une cellule réattaquée (au moins Rr.WAVES vagues dans la mémoire `waves`) voit son
--- score relevé pour vouloir Rr.RICH_EXTRA tourelle(s) de plus, sous le plafond de cellule de Fr.want (`want(score)` : Fr.want, `base`,
--- `per` : Fr.BASE, Fr.PER_TURRET). Rend une
--- NOUVELLE liste (les lignes relevées sont copiées et marquées `rich = true`) et l'ensemble des clés relevées. Pas riche : la liste telle
--- quelle.
function Rr.boost(cells, waves, rich, tick, want, base, per)
  local out, boosted = {}, {}
  for _, c in ipairs(cells or {}) do
    local w = waves and waves[c.key]
    if rich and w and w.n >= Rr.WAVES and w.last and tick - w.last <= Rr.WAVE_FORGET then
      local target = want(c.score) + Rr.RICH_EXTRA
      local score = math.max(c.score, (target - base) * per)
      out[#out + 1] = { key = c.key, cx = c.cx, cy = c.cy, score = score, x = c.x, y = c.y, rich = true, waves = w.n }
      boosted[c.key] = true
    else
      out[#out + 1] = c
    end
  end
  return out, boosted
end

--- Tourelles du front déjà posées, telles que le plafond d'équipe (Fr.TEAM_CAP) les compte : une équipe riche a Rr.RICH_CAP places de plus.
function Rr.cap_placed(placed, rich)
  if not rich then return placed or 0 end
  return math.max(0, (placed or 0) - Rr.RICH_CAP)
end

--- Tourelles à poser d'un coup pour une cellule riche et réattaquée : tout le manque (`want` - `have`), sous les places restantes `left`.
function Rr.rich_count(want, have, left)
  return math.max(0, math.min((want or 0) - (have or 0), left or 0))
end

---------------------------------------------------------------------------------------------------
-- (d) Foreuse thermique de secours
---------------------------------------------------------------------------------------------------
Rr.SUBST_FUEL = 20      -- combustible porté et mis dans la foreuse à combustion posée (environ 9 min de marche)
Rr.SUBST_PER_PASS = 6   -- substitutions au plus par pensée d'équipe
Rr.REVERT_PER_PASS = 2  -- retours à l'électrique au plus par pensée d'équipe

--- Faut-il remplacer cette pièce par la foreuse à combustion ? `e` : pièce du plan non bâtie (rouverte), `elec` : nom de la foreuse
--- électrique (config) ; `elec_ok` : l'objet électrique est au coffre ou fabricable avec le coffre ; `burner_ok` : l'objet à combustion l'est.
function Rr.subst_due(e, elec, elec_ok, burner_ok)
  if not e or e.built or e.subst or e.gave_up or e.dropped then return false end
  if e.name ~= elec then return false end
  return (not elec_ok) and burner_ok and true or false
end

--- Faut-il rendre à la pièce sa foreuse électrique ? Seulement quand l'OBJET électrique est au coffre (`have_elec` >= 1) : la foreuse à
--- combustion produit jusque-là (la retirer avant ferait un trou).
function Rr.revert_due(e, have_elec)
  return (e and e.subst ~= nil and (have_elec or 0) >= 1) or false
end

--- Réceptacle de la foreuse électrique `e` : la pièce du plan (`ents`, ordre du plan) dont la boîte contient son point de dépôt (`drop` vers le
--- nord) ; à défaut la tuile du point de dépôt. `size_of(name, dir)` -> largeur, hauteur. Rend { x, y, w, h }.
function Rr.sink_box(ents, e, drop, size_of)
  local boxes = {}
  for _, o in ipairs(ents or {}) do
    if o ~= e then
      local w, h = size_of(o.name, o.dir)
      if w and h then boxes[#boxes + 1] = { x = o.x, y = o.y, w = w, h = h } end
    end
  end
  local sink = Ru.sink_of(e.x, e.y, e.dir or 0, drop, boxes)
  if sink then return sink end
  local vx, vy = S.rotate(e.dir or 0, drop[1], drop[2])
  return { x = math.floor(e.x + vx) + 0.5, y = math.floor(e.y + vy) + 0.5, w = 1, h = 1 }
end

--- Centre de la foreuse à combustion qui remplace `e` (électrique de taille `esize`, dépôt `edrop`) : elle tient dans l'ancienne emprise et
--- dépose dans le même réceptacle (Ru.burner_center). `burner` = { size, drop }. Rend x, y ou nil.
function Rr.subst_center(ents, e, esize, edrop, burner, size_of)
  local sink = Rr.sink_box(ents, e, edrop, size_of)
  return Ru.burner_center(e.x, e.y, e.dir or 0, sink, burner, esize)
end

return Rr
