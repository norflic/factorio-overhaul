--[[
  Lot FOREUSES-THERMIQUES, partie C : le réseau qui tombe (fo-logs/2026-11-05_FOREUSES-TH/C_CRITERES.md). Règle PURE.

  Une électrique d'avant-poste (remplacement sur place, script/team/foreuse_swap.lua) dont le réseau ne donne plus de courant se tait :
  ni « à sec », ni ravitaillement, sorties qui baissent. Observation (exécutant, à chaque passe de repli) : électriques de l'avant-poste et
  celles SANS COURANT (statut du moteur no_power ; low_power = le réseau produit, la foreuse tourne lentement : jamais compté ; une foreuse
  figée par x10-gel, active == false, n'est jamais comptée). Mémoire PAR ÉLECTRIQUE (o.dark_units : début de SA panne), effacée pour
  chacune dès qu'une observation la voit avec du courant.
    - Rt.observe : électriques prêtes (sans courant à CHAQUE observation depuis au moins cfg.wait ticks : au-delà du délai de réparation
      du réseau, lot ENERGIE) et état de l'avant-poste, « rien », « signal » ou « repli » (au moins une prête).
      Banc foreuses-panne-diag du 8/11 (mesuré) : une électrique posée par le remplacement est no_power AU TICK de sa pose (tampon vide),
      au travail 30 ticks plus tard. Avec une mémoire par AVANT-POSTE, chaque pensée qui posait des électriques prolongeait la « panne »
      et des électriques JUSTE posées étaient repliées sur un réseau alimenté (2 replis au tick 480, réseau coupé au tick 900 seulement) ;
    - Rt.plan : électriques à replier à cette passe. Avant-postes de COMBUSTIBLE d'abord (la centrale repart), puis le plus
      d'électriques sans courant, puis le numéro ; dans un avant-poste, numéros d'unité croissants. Au plus cfg.per_pass en tout, et au
      plus les thermiques du stock libre ; le reste attend une thermique (à fabriquer, ou introuvable : raison au journal) ;
    - Rt.places : places candidates de la thermique (celle notée au remplacement, puis la place inverse de Ru.burner_center) ; la place
      est vérifiée au moteur AVANT le retrait de l'électrique (F70) par l'exécutant.
  Après un repli, la place reste tranquille cfg.hold ticks (retry du remplacement, relu par le relevé à pass.t0) ; le remplacement
  reprend ensuite s'il y a du courant (lecture existante du relevé : poteau d'un réseau qui produit, producing()).

  Déterminisme : entiers et flottants à valeurs exactes, listes triées, aucun hasard, aucun temps mesuré.
]]

local S = require("shared.team.foreuse_swap")
local Ru = require("shared.team.ruines")

local Rt = {}

-- wait : ticks de panne continue avant le repli (5 min) ; hold : ticks sans remplacement sur la place après un repli (10 min) ;
-- per_pass : replis au plus par passe ; every : ticks entre deux passes de repli d'une équipe (comme T.swap.every).
Rt.CFG = { wait = 5 * 3600, hold = 10 * 3600, per_pass = 4, every = 300 }
Rt.KEYS = { "wait", "hold", "per_pass", "every" }

--- Réglage effectif : `over` (bancs : f.team.repli, remote fo-ia1 set_repli) remplace champ par champ ; over.on == false : règle éteinte.
function Rt.cfg(over)
  local c = {}
  for _, k in ipairs(Rt.KEYS) do
    local v = over and over[k]
    c[k] = (type(v) == "number" and v >= 0) and v or Rt.CFG[k]
  end
  c.on = not (over and over.on == false)
  return c
end

--- Mémoire de la panne PAR ÉLECTRIQUE d'un avant-poste. `prev` : { [numéro d'unité] = début de sa panne } de l'observation d'avant (nil :
--- aucune) ; `dark` : numéros des électriques sans courant à cette observation. Une électrique qui avait du courant à l'observation d'avant
--- (absente de `prev`) recommence à `now`. Rend (mémoire', prêtes, since, état) :
---   - mémoire' : { [numéro] = début } des seules électriques sans courant (nil : aucune) ;
---   - prêtes : numéros sans courant depuis au moins cfg.wait ticks, dans l'ordre de `dark` ;
---   - since : le plus ancien début (nil : aucune) ; état : « rien », « signal » (aucune prête) ou « repli ».
function Rt.observe(prev, dark, now, cfg)
  local mem, ready, since = nil, {}, nil
  for _, u in ipairs(dark or {}) do
    local s = (prev and prev[u]) or now
    mem = mem or {}
    mem[u] = s
    if since == nil or s < since then since = s end
    if now - s >= cfg.wait then ready[#ready + 1] = u end
  end
  if not mem then return nil, ready, nil, "rien" end
  return mem, ready, since, (#ready > 0) and "repli" or "signal"
end

local function before(a, b)
  local fa, fb = a.fuel == true, b.fuel == true
  if fa ~= fb then return fa end
  if #a.dark ~= #b.dark then return #a.dark > #b.dark end
  return a.id < b.id
end

--- Électriques à replier à cette passe. `list` : { { id, fuel, dark = { numéros d'unité des électriques PRÊTES (Rt.observe) } } } des
--- avant-postes en état « repli » ; `have` : thermiques au stock libre. Rend picks = { { id = numéro de l'avant-poste, unit } } (au plus
--- cfg.per_pass, au plus `have`, dans l'ordre) et `short` : électriques en repli qui attendent une thermique (au plus cfg.per_pass - #picks).
function Rt.plan(list, have, cfg)
  local order = {}
  for i, o in ipairs(list or {}) do order[i] = o end
  table.sort(order, before)
  local picks, short = {}, 0
  have = have or 0
  for _, o in ipairs(order) do
    local units = {}
    for i, u in ipairs(o.dark) do units[i] = u end
    table.sort(units)
    for _, u in ipairs(units) do
      if #picks + short >= cfg.per_pass then return picks, short end
      if #picks < have then picks[#picks + 1] = { id = o.id, unit = u } else short = short + 1 end
    end
  end
  return picks, short
end

--- Places candidates de la thermique qui remplace l'électrique centrée en (ex, ey), direction `edir`, dont le récepteur est la boîte
--- `sink` ({ x, y, w, h }) ; `burner` = { size, drop = { dx, dy } } (emprise et dépôt vers le nord de la thermique), `esize` : emprise
--- de l'électrique. Dans l'ordre :
---   1. la place notée au remplacement (`from` = { x, y, dir }), si son dépôt tombe dans `sink` et qu'elle ne le recouvre pas ;
---   2. la place inverse (Ru.burner_center : 2 × 2 dans l'ancienne 3 × 3, dépôt dans le même réceptacle, direction de l'électrique),
---      si elle diffère de la première.
--- Rend une liste de { x, y, dir, how = "notee" | "inverse" } (vide : aucune ; sans récepteur, aucune).
function Rt.places(from, ex, ey, edir, sink, burner, esize)
  local out = {}
  if not sink then return out end
  if from and type(from.x) == "number" and type(from.y) == "number" then
    local dir = from.dir or edir
    local vx, vy = S.rotate(dir, burner.drop[1], burner.drop[2])
    local box = { x = from.x, y = from.y, w = burner.size, h = burner.size }
    if S.inside(sink, from.x + vx, from.y + vy) and not S.overlap(box, sink) then
      out[#out + 1] = { x = from.x, y = from.y, dir = dir, how = "notee" }
    end
  end
  local bx, by = Ru.burner_center(ex, ey, edir, sink, burner, esize)
  if bx then
    local p = out[1]
    if not (p and p.x == bx and p.y == by and p.dir == edir) then out[#out + 1] = { x = bx, y = by, dir = edir, how = "inverse" } end
  end
  return out
end

--- Fin de la garde de la place après un repli (retry du remplacement : f.swap.retry[clé]).
function Rt.hold_until(now, cfg)
  return now + cfg.hold
end

return Rt
