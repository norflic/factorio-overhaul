-- Lot BOURDON (1er/11) : une vraie base vanilla, pour les bancs du Bourdon. `bourdon` (contrôles), `bourdon-images` (captures).
local C = {}

C.CIBLE, C.ALLIE, C.TREVE = "fo-bourdon-cible", "fo-bourdon-allie", "fo-bourdon-treve"

function C.forces()
  local cible = game.forces[C.CIBLE] or game.create_force(C.CIBLE)
  local allie = game.forces[C.ALLIE] or game.create_force(C.ALLIE)
  local treve = game.forces[C.TREVE] or game.create_force(C.TREVE)
  local joueur = game.forces.player
  -- la cible est hostile au joueur pour le Bourdon, mais ne lui tire pas dessus : ce banc juge l'onde, pas un duel
  cible.set_cease_fire(joueur, true)
  joueur.set_cease_fire(cible, false)
  cible.set_cease_fire(allie, true)
  allie.set_cease_fire(cible, true)
  cible.set_cease_fire(treve, true)
  treve.set_cease_fire(cible, true)
  joueur.set_friend(allie, true)
  allie.set_friend(joueur, true)
  joueur.set_cease_fire(allie, true)
  allie.set_cease_fire(joueur, true)
  joueur.set_cease_fire(treve, true)
  treve.set_cease_fire(joueur, true)
  game.forces.enemy.set_cease_fire(cible, true)
  cible.set_cease_fire(game.forces.enemy, true)
  game.forces.enemy.set_cease_fire(allie, true)
  game.forces.enemy.set_cease_fire(treve, true)
  game.map_settings.enemy_expansion.enabled = false
end

--- Îlots de production alignés sur la grille, tapis, poteaux. trou(x, y) : vrai = rien ici. Rend la liste.
function C.rangees(s, x0, x1, y0, y1, force, graine, trou)
  local etat = { v = graine }
  local function alea()
    etat.v = (etat.v * 16807) % 2147483647
    return etat.v / 2147483647
  end
  local L = {}
  local function pose(nom, x, y)
    if trou and trou(x, y) then return end
    local e = s.create_entity({ name = nom, position = { x, y }, force = force })
    if e then L[#L + 1] = e end
  end
  local familles = { "assembling-machine-2", "steel-furnace", "assembling-machine-2", "lab", "steel-furnace", "solar-panel" }
  local y, bloc = y0, 0
  while y < y1 do
    local famille = familles[bloc % 6 + 1]
    local x = x0 + (bloc % 2) * 2
    while x < x1 do
      if alea() < 0.2 then
        x = x + 4 * (1 + math.floor(alea() * 2))
      else
        for _ = 1, 3 + math.floor(alea() * 5) do
          if x >= x1 then break end
          pose(famille, x + 0.5, y + 0.5)
          if famille ~= "solar-panel" then pose(famille, x + 0.5, y + 6.5) end
          x = x + 4
        end
      end
    end
    if famille ~= "solar-panel" then
      for bx = x0 - 2, x1 + 1 do pose("transport-belt", bx + 0.5, y + 3.5) end
    end
    y = y + (famille ~= "solar-panel" and 15 or 7)
    bloc = bloc + 1
  end
  return L
end

--- Un terrain nu, et une base de la cible autour du centre (les 6 tuiles sous la cloche restent vides).
function C.site(ctx, x, y, rayon)
  ctx.prepare_area(x - rayon, y - rayon, x + rayon, y + rayon, "dry-dirt")
  local s = ctx.surface()
  for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - rayon - 70, y - rayon - 70 }, { x + rayon + 70, y + rayon + 70 } } })) do
    en.destroy()
  end
  local trou = function(px, py)
    local dx, dy = px - x, py - y
    return dx * dx + dy * dy < 49
  end
  return C.rangees(s, x - rayon + 4, x + rayon - 4, y - rayon + 4, y + rayon - 4, C.CIBLE, (x * 13 + y * 7) % 2147483646 + 1, trou)
end

return C
