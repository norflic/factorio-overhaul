-- Lot EXPERIMENTAUX (3/11) : sites communs des bancs `xp-petits` (contrôles, sans images) et `xp-images` (joueur, captures).
-- Un site par petit, à 160 tuiles l'un de l'autre : l'expérimental, des cibles d'une force hostile qui ne tire pas (cessez-le-feu),
-- un témoin de la force du joueur DANS la zone de l'effet (il doit rester à pleine vie), et une usine de robots de son âge qui
-- fabrique l'objet pour de vrai (technologie recherchée, recette posée, ingrédients insérés).
local C = {}

C.CIBLE = "fo-xp-cible"
C.Y = 3000
C.IDS = { "mat-foudre", "geode", "sarracenie", "demi-vie", "veilleuse" }
C.USINE = { ["mat-foudre"] = "fo-robot-workshop", geode = "fo-robotics-bay", sarracenie = "fo-robotics-bay", ["demi-vie"] = "fo-robotics-bay",
  veilleuse = "fo-robot-gantry" }
-- distance des cibles à l'expérimental (tourelles : dans la portée ; attaquants : lancés à cette distance)
C.DIST = { ["mat-foudre"] = 16, geode = 34, sarracenie = 22, ["demi-vie"] = 40, veilleuse = 30 }

function C.x(i) return 9000 + (i - 1) * 160 end

function C.forces()
  local cible = game.forces[C.CIBLE] or game.create_force(C.CIBLE)
  local joueur = game.forces.player
  -- la cible est hostile au joueur, mais ne tire pas : ce banc mesure l'effet, pas un duel
  cible.set_cease_fire(joueur, true)
  joueur.set_cease_fire(cible, false)
  game.forces.enemy.set_cease_fire(cible, true)
  cible.set_cease_fire(game.forces.enemy, true)
  game.forces.enemy.set_cease_fire(joueur, true)
  joueur.set_cease_fire(game.forces.enemy, true)
  game.map_settings.enemy_expansion.enabled = false
end

--- Prépare un site : sol, aucun ennemi naturel, alimentation. Rend la source d'énergie.
function C.terrain(ctx, x)
  local s = ctx.surface()
  ctx.prepare_area(x - 30, C.Y - 40, x + 70, C.Y + 70, "dry-dirt")
  for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 80, C.Y - 90 }, { x + 120, C.Y + 120 } } })) do en.destroy() end
  return ctx.power(x - 12, C.Y + 6)
end

--- Cibles : `n` tourelles sans munition de la force cible, en colonne à (x, y), espacées de `dy`.
function C.cibles(s, x, y, n, dy)
  local l = {}
  for k = 1, n do
    local e = s.create_entity({ name = "gun-turret", position = { x, y + (k - 1 - (n - 1) / 2) * dy }, force = C.CIBLE })
    if e then l[#l + 1] = e end
  end
  return l
end

--- Témoin de la force du joueur (un laboratoire) : doit finir à pleine vie.
function C.temoin(s, x, y)
  return s.create_entity({ name = "lab", position = { x, y }, force = "player" })
end

--- L'usine de l'âge, sa recette, ses ingrédients (la technologie de l'expérimental est recherchée : elle débloque la recette).
function C.usine(ctx, id, x, y)
  local s = ctx.surface()
  local force = game.forces.player
  local tech = "fo-xp-" .. id
  local t = force.technologies[tech]
  if t then t.researched = true end
  local rec = force.recipes["fo-xp-make-" .. id]
  local m = s.create_entity({ name = C.USINE[id], position = { x, y }, force = force })
  local inserted = {}
  if m and rec and rec.enabled then
    m.set_recipe(rec.name)
    for _, g in ipairs(rec.ingredients) do inserted[#inserted + 1] = g.name .. " " .. m.insert({ name = g.name, count = g.amount }) .. "/" .. g.amount end
  end
  return { m = m, tech = t, rec = rec, inserted = inserted }
end

return C
