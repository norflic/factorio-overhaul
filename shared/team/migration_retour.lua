--[[
  Lot AZURE : RETOUR EN ARRIÈRE d'une migration de champ (retour du DC du 3/11, 0.6.46 : « la Ligue Azur est restée en âge 1 [...] elle
  s'est arrêtée en plein milieu [...] après avoir déconstruit »). PUR : aucune API Factorio, aucun nom d'objet ; testé hors jeu
  (tests/migration_retour_test.lua). Exécutant : script/team/migration_champ.lua (retire, step_build, rollback).

  Défaut mesuré (fo-logs/2026-11-03_RETOUR3, équipe azure) : 38 paires thermiques retirées à 38-41 min pour deux bandes jamais finies,
  « la ligne n'aboutit pas (chantier, 90 min depuis le retrait) : migration arrêtée, 0 ligne neuve ont produit » à 138-142 min, et RIEN ne
  remet les paires : 100 minutes sans production de fer.

  Décision du DC (mot pour mot) : « je valide la B : si la bande est en chantier lent (sans progrès depuis 15 minutes) ou abandonnée, les
  foreuses thermiques et leurs fours sont reposés sur leurs positions si les tuiles sont libres, et la bande revient en réserve. »

  Règles :
  - `pack` : la liste BORNÉE (R.CFG.undo_max) et déterministe des paires retirées, gardée sur l'état de la migration (nombres et chaînes) ;
  - `progress` / `stalled` : le dernier tick où une entité de plus de la bande a été posée ;
  - `decide` : retour en arrière si la ligne n'a rien produit, qu'il y a des paires à reposer et que la bande est abandonnée ou sans progrès
    depuis R.CFG.stall ; jamais une bande qui avance, jamais une ligne qui a produit, jamais une ligne finie (elle a son propre délai) ;
  - `after` : après le retour la bande attend en réserve (pause R.CFG.cool), au plus R.CFG.max_rollbacks fois, puis elle est annulée ;
  - `line` : la ligne [FO-ROLLBACK].
  Aucun `pairs` décisionnel, aucun hasard, aucun temps mesuré.
]]

local R = {}

R.CFG = {
  stall = 15 * 3600,     -- 15 min sans entité de plus posée : chantier lent
  cool = 30 * 3600,      -- 30 min en réserve avant que le plan puisse retirer de nouveau (les paires produisent entre-temps)
  max_rollbacks = 2,     -- retours en arrière par bande au plus ; le dernier annule la bande
  undo_max = 40,         -- paires gardées au plus (une bande retire 8 paires par partie en général, 21 au pire mesuré)
  craft_depth = 3,       -- profondeur des recettes dépliées pour refaire un objet rendu au stock puis dépensé (foreuse -> engrenage -> plaque)
}

--- Paires retirées -> liste bornée, triée par (x, y, nom) de la foreuse. entries : { { name, x, y, dir, oid, sink = { name, x, y } }, ... }.
--- Rend (liste, nombre écarté).
function R.pack(entries, max)
  max = max or R.CFG.undo_max
  local list = {}
  for _, e in ipairs(entries or {}) do list[#list + 1] = e end
  table.sort(list, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return tostring(a.name) < tostring(b.name)
  end)
  local out, dropped = {}, 0
  for i, e in ipairs(list) do
    if i <= max then
      out[#out + 1] = { name = e.name, x = e.x, y = e.y, dir = e.dir or 0, oid = e.oid,
        sink = e.sink and { name = e.sink.name, x = e.sink.x, y = e.sink.y } or nil }
    else
      dropped = dropped + 1
    end
  end
  return out, dropped
end

--- Suivi du progrès : rec = { built, since } ou nil ; built = entités posées du projet. Rend le nouvel enregistrement (une entité de plus :
--- `since` repart de `now`).
function R.progress(rec, built, now)
  if not rec or built > (rec.built or 0) then return { built = built, since = now } end
  return { built = rec.built, since = rec.since }
end

--- Ticks sans progrès.
function R.stalled(rec, now)
  if not rec then return 0 end
  return math.max(0, now - rec.since)
end

--- Décision. c = { undo (paires gardées), produced (une ligne neuve a produit), state (état du projet : "fini", "bloque", ... ou nil si perdu),
--- stalled (ticks), abandon (le suivi vient d'abandonner la bande) }. Rend ("retour" | "rien", raison).
function R.decide(c, cfg)
  cfg = cfg or R.CFG
  if (c.undo or 0) == 0 then return "rien", "sans-paire" end
  if c.produced then return "rien", "produit" end
  if c.abandon then return "retour", "abandon" end
  if c.state == "fini" then return "rien", "fini" end
  if (c.stalled or 0) >= cfg.stall then return "retour", "chantier-lent" end
  return "rien", "avance"
end

--- Suite du retour n° `n` (1 pour le premier) : "reserve" (la bande attend, pause R.CFG.cool) ou "annuler" (dernier retour, ou fin imposée).
function R.after(n, final, cfg)
  cfg = cfg or R.CFG
  if final or n >= cfg.max_rollbacks then return "annuler" end
  return "reserve"
end

--- Plan d'obtention de `qty` objets `name` : d'abord ce qui est au stock, le reste fabriqué de ses ingrédients (récursif, R.CFG.craft_depth).
--- `have(nom)` : stock libre ; `recipe(nom)` : { out = produits par fabrication, ingredients = { { name, amount }, ... } } ou nil (objet qui ne se
--- fabrique pas, ou recette à fluide). `used` : { [nom] = quantité À PRENDRE au stock } (créé si nil). Rend (vrai, used) ou (faux).
--- Mesuré (B long, 20261020, azure) : « 17 sans objet » : les foreuses et fours rendus au stock par le retrait avaient été dépensés ailleurs,
--- aucune paire reposée. Le retour refait ce qu'il avait rendu.
function R.plan(name, qty, have, recipe, used, depth)
  used = used or {}
  depth = depth or 0
  local avail = have(name) - (used[name] or 0)
  local take = math.min(qty, math.max(0, avail))
  if take > 0 then used[name] = (used[name] or 0) + take end
  local rest = qty - take
  if rest <= 0 then return true, used end
  if depth >= R.CFG.craft_depth then return false end
  local rc = recipe(name)
  if not rc or (rc.out or 0) < 1 then return false end
  local runs = math.ceil(rest / rc.out)
  for _, ing in ipairs(rc.ingredients or {}) do
    if not R.plan(ing.name, ing.amount * runs, have, recipe, used, depth + 1) then return false end
  end
  return true, used
end

--- La pause du retour est-elle en cours ? (until : tick de fin ou nil)
function R.cooling(until_tick, now)
  return until_tick ~= nil and now < until_tick
end

--- Ligne [FO-ROLLBACK]. ev = { team, outpost, pid, why, minute, undo, placed, busy (tuiles prises), items (sans objet), n, next ("reserve"|"annuler") }.
function R.line(ev)
  return string.format(
    "[FO-ROLLBACK] %s : avant-poste %d, projet %s a %.1f min (%s) : %d paire(s) gardee(s), %d reposee(s), %d tuile(s) prise(s), %d sans objet ; retour %d, %s",
    tostring(ev.team), ev.outpost or 0, tostring(ev.pid), ev.minute or 0, tostring(ev.why), ev.undo or 0, ev.placed or 0, ev.busy or 0, ev.items or 0,
    ev.n or 0, ev.next == "annuler" and "bande annulee, une autre sera essayee" or "bande remise en reserve")
end

return R
