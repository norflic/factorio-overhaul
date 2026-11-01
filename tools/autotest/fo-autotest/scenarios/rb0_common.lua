-- Lot RB-0 (31/10) : utilitaires communs des scénarios rb0-* (essais moteur E1 à E9 des robots).
-- Tous les scénarios rb0-* se jouent sur la COPIE JETABLE du mod (tools/autotest/robots/jetable.py), qui seule a les
-- prototypes de test ; sur le mod livré ils s'arrêtent à l'init (« prototypes de test absents »).

local C = {}

--- Table d'état persistante des gestionnaires d'événements (pas de ctx dans un gestionnaire) : global.rb0.
function C.g()
  global.rb0 = global.rb0 or {}
  return global.rb0
end

local STATUT
--- Nom lisible d'un état d'entité (defines.entity_status), « sans-etat » si nil.
function C.statut(e)
  if not STATUT then
    STATUT = {}
    for nom, v in pairs(defines.entity_status) do STATUT[v] = nom end
  end
  local ok, s = pcall(function() return e.status end)
  if not ok then return "erreur" end
  return s and STATUT[s] or "sans-etat"
end

--- Vérifie que les prototypes de test existent ; sinon un ECHEC et false.
function C.exige(ctx, noms, quoi)
  local manque = {}
  for _, n in ipairs(noms) do
    if not (game.entity_prototypes[n] or game.item_prototypes[n] or game.recipe_prototypes[n]) then manque[#manque + 1] = n end
  end
  if #manque > 0 then
    ctx.fail("prototypes de test presents (copie jetable tools/autotest/robots/jetable.py)", table.concat(manque, ", "))
    return false
  end
  ctx.ok("prototypes de test presents", quoi or (#noms .. " prototype(s)"))
  return true
end

--- Pose le sol d'une zone (tuile, defaut grass-1), retire tout ce qui s'y trouve.
function C.pave(ctx, x0, y0, x1, y1, tuile)
  ctx.prepare_area(x0, y0, x1, y1, tuile or "grass-1")
end

--- Remplace des tuiles par de l'eau dans le rectangle [x0, x1) x [y0, y1).
function C.eau(s, x0, y0, x1, y1, tuile)
  local t = {}
  for x = x0, x1 - 1 do
    for y = y0, y1 - 1 do t[#t + 1] = { name = tuile or "water", position = { x, y } } end
  end
  s.set_tiles(t)
end

--- Retire les entités ennemies naturelles (nids, vers) d'un rectangle.
function C.sans_ennemis(s, x0, y0, x1, y1)
  local n = 0
  for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x0, y0 }, { x1, y1 } } })) do
    e.destroy()
    n = n + 1
  end
  return n
end

--- Force de test : creee si absente, en guerre avec « enemy » dans les deux sens.
function C.force(nom)
  local f = game.forces[nom] or game.create_force(nom)
  f.set_cease_fire("enemy", false)
  game.forces.enemy.set_cease_fire(nom, false)
  -- paix avec toutes les autres forces (joueur, factions du mod) : seul l'ennemi naturel est hostile
  for _, o in pairs(game.forces) do
    if o.name ~= nom and o.name ~= "enemy" then
      f.set_cease_fire(o, true)
      o.set_cease_fire(f, true)
    end
  end
  return f
end

function C.fmt(v, n)
  if v == nil then return "nil" end
  return string.format("%." .. (n or 3) .. "f", v)
end

function C.dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

function C.pos(p)
  if p == nil then return "nil" end
  return string.format("(%.1f,%.1f)", p.x or p[1], p.y or p[2])
end

return C
