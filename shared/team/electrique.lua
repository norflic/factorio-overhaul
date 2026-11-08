--[[
  ÉLECTRIQUE (lot ELECTRIQUE, retour du DC du 8/11, 14 h 30, partie neuve en 0.6.66) : « Surutilisation aberrante du thermique : à 33 minutes de
  jeu, l'équipe a posé une soixantaine de foreuses thermiques et continue d'en rajouter [...] alors que la technologie électrique est déjà
  disponible », « La prise de décision pour l'amélioration (upgrade thermique vers électrique) est beaucoup trop lente », « les nouvelles
  expansions de gisements doivent se faire directement en électrique, pas en thermique ».
  PUR : aucune API Factorio, aucun nom d'objet (une foreuse, un type d'avant-poste sont des étiquettes opaques ; cadences et kW arrivent en
  DONNÉES). Testé hors jeu par tests/electrique_test.lua (mutants compris).

  Trois règles, lues par la glue script/team/electrique.lua :
    (a) E.thermal(s)          : une paire THERMIQUE (agrandissement, avant-poste neuf, thermique fabriquée pour la réserve) est-elle encore
                                permise ? Non dès qu'une centrale est finie et que la foreuse électrique et un poteau sont obtenables. Seule
                                exception : le combustible de la centrale quand elle est à l'arrêt (sinon plus rien ne la relance).
        E.task_drills(t, item): foreuses thermiques que porte une tâche du tableau (0 : la tâche n'en pose ni n'en fabrique).
        E.filter(tasks, ...)  : tâches gardées et tâches refusées (cause écrite), dans l'ordre d'arrivée.
    (b) E.swap_quota(c)       : remplacements thermique -> électrique permis à cette passe, lus à la MARGE de kW (et non un nombre fixe).
        E.block(entries, n)   : candidats ramenés aux champs ENTIERS, un avant-poste après l'autre (par bloc), jusqu'au quota.
    (c) E.planned_kw(p)       : kW des électriques PRÉVUES (thermiques à convertir, agrandissements refusés) que la centrale ne couvre pas
                                encore : ajoutés à la demande de croissance des centrales AVANT la pose.
  Déterminisme : listes triées par numéro, aucun `pairs`, aucun temps mesuré.
]]

local E = {}

E.CFG = {
  draw = 0.6,        -- part de leur puissance nominale que tirent les chantiers admis (comme S.power_ok et S.DRAW de sante_centrale)
  block_max = 16,    -- remplacements au plus par passe (chaque place de 3 x 3 est lue au moteur : borne de coût d'une passe)
  tries_max = 8,     -- chaînes de poteaux calculées au plus par passe (recherche de chemin bornée, P.pole_chain)
  refused_ttl = 7200, -- ticks (2 min) pendant lesquels une paire thermique refusée compte dans la demande de centrale
  -- Lot ELECTRIQUE, correctif d'interblocage (partie neuve 0.6.69, etape1-guide, 40 min, lead 8/11 : bascule à 7,7 min, 0 électrique à 10, 20
  -- et 30 min faute de poteaux (6 tout le long), thermiques 28 -> 0, reconstruction « build:copper » refusée à 15,5 min) :
  poles_min = 12,    -- poteaux au stock qui rendent l'électrique MATÉRIELLEMENT possible sans électrique qui tourne (gabarit de fonderie : 12 petits)
  revert = 3 * 3600, -- ticks après la bascule sans aucune électrique qui tourne : retour au thermique
}

local EPS = 1e-9
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local function cfg_of(cfg) return cfg or E.CFG end

local function num(x)
  if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return nil end
  return x
end

--- (a) s = { on (règle allumée, nil = allumée), obtainable (foreuse électrique au stock ou fabricable), plants (centrales finies),
--- poles (un poteau obtenable), fuel (le produit de ce type d'avant-poste est le combustible de la centrale), healthy (centrale saine),
--- el_live (foreuses électriques de la force qui tournent ; absent = 0), poles_stock (poteaux au stock ; absent = 0),
--- since (ticks depuis la bascule, nil avant), res_live (électriques qui tournent sur la ressource de ce type ; nil : pas de ressource lue,
--- seule la règle globale) }. L'électrique doit être MATÉRIELLEMENT là : une électrique qui tourne, ou des poteaux au stock pour un gabarit
--- (cfg.poles_min) ; 0 électrique cfg.revert ticks après la bascule : retour au thermique ; une ressource sur laquelle AUCUNE électrique ne
--- tourne garde sa thermique (agrandir, bâtir, reconstruire : jamais affamée). Rend (permise, raison).
function E.thermal(s, cfg)
  cfg = cfg_of(cfg)
  s = s or {}
  if s.on == false then return true, "regle coupee" end
  if not s.obtainable then return true, "foreuse electrique pas obtenable" end
  if (num(s.plants) or 0) < 1 then return true, "aucune centrale finie" end
  if not s.poles then return true, "aucun poteau obtenable" end
  local live, stock = num(s.el_live) or 0, num(s.poles_stock) or 0
  if live <= 0 and stock < cfg.poles_min then
    return true, string.format("aucune foreuse electrique qui tourne ni poteaux au stock (%d sur %d)", floor(stock), cfg.poles_min)
  end
  if live <= 0 and (num(s.since) or 0) >= cfg.revert then
    return true, string.format("retour thermique : aucune foreuse electrique ne tourne %.0f min apres la bascule", (num(s.since) or 0) / 3600)
  end
  if s.fuel and s.healthy == false then return true, "combustible de la centrale a l'arret : thermique permise" end
  if s.res_live ~= nil and (num(s.res_live) or 0) <= 0 then
    return true, "aucune foreuse electrique ne tourne sur cette ressource : thermique permise (agrandir, batir, reconstruire)"
  end
  return false, string.format("electrique possible (%d centrale(s) finie(s), %d electrique(s) qui tournent) : thermique refusee",
    floor(num(s.plants) or 0), floor(live))
end

--- Foreuses thermiques que porte la tâche `t` (objets `items` = { { nom, nombre } }, ou fabrication `item`/`count`). `drill` : nom de la
--- foreuse thermique (donnée). Seules trois sortes comptent : agrandissement (extend), avant-poste neuf (build, avec son type) et
--- fabrication (craft) de la foreuse thermique. Rend le nombre (0 : tâche hors de la règle).
function E.task_drills(t, drill)
  if type(t) ~= "table" or drill == nil then return 0 end
  if t.kind == "craft" then
    if t.item == drill then return max(1, floor(num(t.count) or 1)) end
    return 0
  end
  if t.kind ~= "extend" and not (t.kind == "build" and t.outpost_kind ~= nil) then return 0 end
  local n = 0
  for _, it in ipairs(t.items or {}) do
    if type(it) == "table" and it[1] == drill then n = n + (num(it[2]) or 0) end
  end
  -- un agrandissement sans liste d'objets pose quand même des paires : il compte pour une
  if n <= 0 then n = 1 end
  return n
end

--- Tâches LIBRES (sans exécutant) passées au filtre : `verdict(t)` rend (permise, raison) pour une tâche de la règle (E.task_drills > 0).
--- Une tâche prise (`t.worker`) est toujours gardée : elle finit ce qu'elle porte. Rend (gardées, refusées) ; refusées = { { task, why, n } }.
function E.filter(tasks, drill, verdict)
  local kept, refused = {}, {}
  for _, t in ipairs(tasks or {}) do
    local n = (not t.worker) and E.task_drills(t, drill) or 0
    local ok, why = true, nil
    if n > 0 then ok, why = verdict(t) end
    if ok then kept[#kept + 1] = t else refused[#refused + 1] = { task = t, why = why, n = n } end
  end
  return kept, refused
end

--- (b) c = { capacity, used, committed (kW), kw (kW d'une électrique), fallback (quota sans mesure de la centrale) }. Marge = capacité −
--- pris − draw × chantiers, la règle de S.power_ok (shared/team/foreuse_swap.lua) qui garde chaque pose. Banc sur la sauvegarde du DC (8/11) :
--- « capacité × draw − pris − chantiers » rendait −1 920 kW à 53 % de charge, aucun remplacement. Rend (quota, marge) : le nombre d'électriques que la marge alimente, au plus cfg.block_max ; sans capacité lue,
--- le quota de secours (au plus block_max). Une marge négative rend 0.
function E.swap_quota(c, cfg)
  cfg = cfg_of(cfg)
  c = c or {}
  local cap, kw = num(c.capacity), num(c.kw)
  if not cap or cap <= 0 or not kw or kw <= 0 then
    return min(cfg.block_max, max(0, floor(num(c.fallback) or 0))), nil
  end
  local margin = cap - (num(c.used) or 0) - cfg.draw * (num(c.committed) or 0)
  local n = floor(margin / kw + EPS)
  return max(0, min(cfg.block_max, n)), margin
end

--- (b) Remplacement PAR BLOC : `entries` = candidats { id, o (avant-poste) } ; les champs sont pris un à un (avant-poste de plus petit
--- numéro d'abord : le premier gisement fini avant d'en commencer un autre), en ENTIER, tant que le quota n'est pas dépassé ; le premier
--- champ est toujours pris, même plus grand que le quota (S.plan s'arrête au quota). `skip` = { [avant-poste] = vrai } : champs sautés
--- (la passe précédente n'y a rien planifié : aucun poteau alimenté à portée, places refusées) ; s'ils le sont TOUS, aucun n'est sauté
--- (jamais de passe vide par la règle). Rend (candidats retenus triés par id, champs { { o, n } } dans l'ordre). Quota nul : rien.
function E.block(entries, quota, skip)
  local by, all = {}, {}
  for _, e in ipairs(entries or {}) do
    local o = e.o
    if o ~= nil then
      if not by[o] then
        by[o] = {}
        all[#all + 1] = o
      end
      by[o][#by[o] + 1] = e
    end
  end
  table.sort(all, function(a, b) return a < b end)
  local ids = {}
  for _, o in ipairs(all) do if not (skip and skip[o]) then ids[#ids + 1] = o end end
  if #ids == 0 then ids = all end
  local out, fields, taken = {}, {}, 0
  if (quota or 0) <= 0 then return out, fields end
  for _, o in ipairs(ids) do
    local list = by[o]
    if taken > 0 and taken + #list > quota then break end
    for _, e in ipairs(list) do out[#out + 1] = e end
    fields[#fields + 1] = { o = o, n = #list }
    taken = taken + #list
    if taken >= quota then break end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out, fields
end

--- (b) Champs à sauter à la passe suivante : ceux de `fields` où le plan n'a retenu AUCUN candidat (`out` : sortie de S.plan, { id } ;
--- `owner` = { [id] = avant-poste }). Rend la liste triée des avant-postes à sauter.
function E.idle_fields(fields, out, owner)
  local planned = {}
  for _, r in ipairs(out or {}) do
    local o = owner and owner[r.id]
    if o ~= nil then planned[o] = (planned[o] or 0) + 1 end
  end
  local idle = {}
  for _, fl in ipairs(fields or {}) do
    if (planned[fl.o] or 0) == 0 then idle[#idle + 1] = fl.o end
  end
  table.sort(idle, function(a, b) return a < b end)
  return idle
end

--- (c) p = { thermals (thermiques à convertir), refused (thermiques refusées récemment), th_speed, el_speed (cadences de minage), kw (kW d'une
--- électrique), margin (kW libres, E.swap_quota ; nil = 0) }. Une électrique remplace el_speed / th_speed thermiques. Rend (kW à demander à
--- la centrale, kW prévus, électriques prévues). Sans donnée valide : 0.
function E.planned_kw(p)
  p = p or {}
  local th, el, kw = num(p.th_speed), num(p.el_speed), num(p.kw)
  if not th or th <= 0 or not el or el <= 0 or not kw or kw <= 0 then return 0, 0, 0 end
  local drills = max(0, num(p.thermals) or 0) + max(0, num(p.refused) or 0)
  if drills <= 0 then return 0, 0, 0 end
  local n_el = ceil(drills * th / el - EPS)
  local planned = n_el * kw
  return max(0, planned - max(0, num(p.margin) or 0)), planned, n_el
end

--- Paires thermiques refusées encore comptées : `log` = { { tick, n } } (ordre d'arrivée) ; garde celles de moins de cfg.refused_ttl ticks.
--- Rend (liste gardée, somme).
function E.refused_window(log, tick, cfg)
  cfg = cfg_of(cfg)
  local keep, sum = {}, 0
  for _, r in ipairs(log or {}) do
    if type(r) == "table" and num(r.tick) and tick - r.tick < cfg.refused_ttl and tick >= r.tick then
      keep[#keep + 1] = r
      sum = sum + (num(r.n) or 0)
    end
  end
  return keep, sum
end

return E
