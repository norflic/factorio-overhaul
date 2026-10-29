--[[
  Lot REBUILD-AVANT-POSTE : règles PURES (aucune API Factorio, aucun nom d'objet : les noms et dimensions viennent de shared/team/config.lua
  et du moteur, passés par l'appelant) de la RUINE d'un avant-poste de ressource perdu en entier.

  Retour du DC (29/10, 0.6.16) : « si les biters détruisent des zones de gisements et des fours, ça ralentit voire bloque toute l'avancée
  car ce n'était pas remplacé » ; « reconstruire IMPÉRATIVEMENT tous les bâtiments détruits ». Avant : quand la dernière foreuse d'un
  avant-poste meurt, son enregistrement (f.outposts[oid]) disparaît, le registre de reconstruction jette ses pièces (« avant-poste
  disparu ») et le site perd de la valeur pendant 30 min (shared/faction/valeur.lua : danger « site perdu »). Le champ n'est jamais
  remis en place ; seule la voie ordinaire (prospection, tâche « build ») le refait ailleurs ou plus tard.

  La RUINE garde le plan : les pièces détruites (foreuses et réceptacles, noms, places, directions, objets) sont DÉJÀ au registre de
  reconstruction (script/team/reconstruction.lua) ; la ruine n'ajoute que l'en-tête (ressource, place, lectures du site) et la durée
  de vie. Tant qu'elle est vivante, les pièces ne sont pas jetées ; la première foreuse reposée RECRÉE l'enregistrement de l'avant-poste.
  Elle est lâchée (les pièces suivent la règle d'avant) quand :
    - « refait »   : l'enregistrement existe de nouveau ;
    - « pieces »   : plus aucune pièce refaisable (abandonnées, oubliées) ;
    - « expire »   : Ru.TTL ticks sans retour (le site est tenu par l'ennemi : la voie ordinaire reprend la main, et les réceptacles
                      restés sur place peuvent être démontés après leur attente de 30 min, avant-postes) ;
    - « remplace » : un avant-poste vivant de la même ressource est posé à moins de Ru.SUPERSEDE_R tuiles (la voie ordinaire a refait
                      le champ avant nous : aucun doublon) ;
    - « rival »    : une AUTRE équipe a revendiqué le site.

  Foreuse de remplacement (Ru.burner_center) : une foreuse électrique perdue dont l'objet n'est pas au stock est remplacée par la foreuse à
  combustion, posée pour que son dépôt tombe dans le MÊME réceptacle (miroir de S.electric_center, shared/team/foreuse_swap.lua) ; le lot
  FOREUSES la passe en électrique dès que l'objet et le courant sont là.

  Déterminisme : entiers et flottants à valeurs exactes, listes triées, aucun hasard, aucun temps mesuré.
]]

local S = require("shared.team.foreuse_swap")

local Ru = {}

Ru.TTL = 25 * 3600       -- 25 min : en deçà de l'attente de 30 min des réceptacles orphelins (Outposts.ORPHAN_WAIT)
Ru.SUPERSEDE_R = 24      -- tuiles : même champ (rayon de reprise des orphelins à la pose d'un avant-poste)
Ru.MAX_DEFERS = 150      -- reports (ennemi près de la place, 10 s chacun) d'une pièce d'avant-poste avant l'abandon : 25 min, la durée de la ruine
Ru.SAME_SITE_R = 12      -- tuiles : un site perdu « à refaire en place » ne pénalise que les AUTRES sites, pas celui-là (valeur.lua)

local EPS = 1e-6

--- Verdict d'une ruine. `x` : { x, y, kind, tick } ; `c` :
---   tick ; record (vrai si f.outposts[oid] existe) ; pending (pièces refaisables de l'avant-poste au registre) ;
---   live : liste de { kind, x, y } (avant-postes vivants) ; rival (vrai si une autre équipe tient le site).
--- Rend "garde" ou ("lache", raison).
function Ru.verdict(x, c)
  if c.record then return "lache", "refait" end
  if (c.pending or 0) <= 0 then return "lache", "pieces" end
  if c.tick - x.tick > Ru.TTL then return "lache", "expire" end
  for _, o in ipairs(c.live or {}) do
    if o.kind == x.kind then
      local dx, dy = o.x - x.x, o.y - x.y
      if dx * dx + dy * dy <= Ru.SUPERSEDE_R * Ru.SUPERSEDE_R then return "lache", "remplace" end
    end
  end
  if c.rival then return "lache", "rival" end
  return "garde"
end

--- Le site perdu en x,y est-il le même champ que le site candidat ? (exemption de la pénalité de valeur, lot REBUILD-AVANT-POSTE)
function Ru.same_site(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy <= Ru.SAME_SITE_R * Ru.SAME_SITE_R
end

--- Centre de la foreuse à combustion qui remplace une foreuse électrique perdue centrée en (ex, ey), direction `dir`, le réceptacle étant
--- la boîte `sink` ({ x, y, w, h }). `burner` = { size, drop = { dx, dy } } (emprise et dépôt vers le nord de la foreuse à combustion).
--- La boîte de la foreuse à combustion (size × size, centre sur un entier) doit tenir dans l'ancienne emprise (électrique, `esize`), ne pas
--- recouvrir le réceptacle et déposer dedans. Choix : x puis y croissants (les quatre candidats sont à égale distance). nil si aucun.
function Ru.burner_center(ex, ey, dir, sink, burner, esize)
  local vx, vy = S.rotate(dir, burner.drop[1], burner.drop[2])
  local best
  for _, ox in ipairs({ -0.5, 0.5 }) do
    for _, oy in ipairs({ -0.5, 0.5 }) do
      local bx, by = ex + ox, ey + oy
      local box = { x = bx, y = by, w = burner.size, h = burner.size }
      -- tient dans l'ancienne emprise
      local fits = math.abs(bx - ex) + burner.size / 2 <= esize / 2 + EPS and math.abs(by - ey) + burner.size / 2 <= esize / 2 + EPS
      if fits and S.inside(sink, bx + vx, by + vy) and not S.overlap(box, sink) then
        if not best or bx < best[1] - EPS or (math.abs(bx - best[1]) <= EPS and by < best[2]) then best = { bx, by } end
      end
    end
  end
  if not best then return nil end
  return best[1], best[2]
end

--- Le réceptacle qui reçoit le dépôt de la foreuse électrique perdue : la première boîte de `boxes` qui contient le point de dépôt.
--- `drop` = { dx, dy } vers le nord de l'électrique.
function Ru.sink_of(ex, ey, dir, drop, boxes)
  local vx, vy = S.rotate(dir, drop[1], drop[2])
  for _, b in ipairs(boxes) do
    if S.inside(b, ex + vx, ey + vy) then return b end
  end
  return nil
end

return Ru
