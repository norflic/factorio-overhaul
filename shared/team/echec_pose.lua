--[[
  Lot INJOIGNABLE : verdict PUR d'une construction d'avant-poste ratée (script/team/worker.lua, ACTS.build : Outposts.build a rendu nil).

  Partie du DC (0.7.113, équipe azure) : son seul gisement de fer proche (310, 374), à 45 tuiles, remis au constructeur à 8,1 min ;
  l'ouvrier ARRIVE sur place, rien n'est posé, et le site était marqué « injoignable » pendant 30 min (UNREACHABLE_TICKS) : refusé
  à 8,5 / 10 / 15 / 20 / 29 min, fer à la main jusqu'à 36 min. Or ACTS.build ne s'exécute qu'APRÈS la marche réussie : l'échec n'est
  jamais un échec de CHEMIN (celui-là est marqué ailleurs, à la marche, et garde ses 30 min), c'est un échec de POSE.

  Motifs (dans l'ordre des refus de Outposts.build, script/faction/outposts.lua) :
    « thermique_ferme » : gisement balayé fermé aux paires thermiques (Th.site_closed) : écarté Ep.SHORT_TICKS ;
    « lacking »         : l'ouvrier n'a pas de foreuse ou pas de réceptacle sur lui (place_pairs s'arrête avant le premier essai) : le
                          SITE n'est pas en cause, aucun écart ;
    « pose »            : objets portés, aucun emplacement n'a tenu (tuile réservée, zone mêlée, obstacle, bord) : écarté Ep.SHORT_TICKS.
]]

local Ep = {}

Ep.SHORT_TICKS = 2 * 3600 -- 2 min (au lieu des 30 min d'un vrai injoignable)

--- c = { closed (vrai/faux), drills (foreuses portées), sinks (réceptacles portés) }. Rend motif, ttl (nil : le site n'est pas écarté).
function Ep.verdict(c)
  c = c or {}
  if c.closed then return "thermique_ferme", Ep.SHORT_TICKS end
  if (c.drills or 0) < 1 or (c.sinks or 0) < 1 then return "lacking", nil end
  return "pose", Ep.SHORT_TICKS
end

--- Ligne du journal [FO-SITES] d'une pose ratée.
function Ep.line(team, tick, resource, site, motif, ttl, c)
  c = c or {}
  return string.format("[FO-SITES] pose ratee tick %d %s %s : (%d, %d), motif %s, foreuses %d et receptacles %d portes, %s",
    tick, tostring(team), tostring(resource or "?"), math.floor(site.x), math.floor(site.y), tostring(motif), c.drills or 0, c.sinks or 0,
    ttl and string.format("site ecarte %.1f min (pas injoignable)", ttl / 3600) or "site non ecarte")
end

return Ep
