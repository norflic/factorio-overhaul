-- Lot DESIGN-ATTAQUES (5/11) : sites communs des bancs `att2-controle` (contrôles, sans images) et `att2-images` (captures).
-- Une base ennemie DENSE et ALIMENTÉE (machines, tapis, poteaux moyens reliés en cuivre, lampes, tourelles, une source d'énergie), une force
-- par géant (âge 15 : plafond des géants), un bâtiment de la force du géant DANS la zone (il doit rester debout, sans falaise ni lave dessous).
local C = {}

C.CIBLE = "fo-att2-cible"
C.ZONE = { cairn = 15, stylet = 30, trombe = 45, ixion = 60, tournesol = 75, bourdon = 60 }
C.PORTEE = { cairn = 38, stylet = 42, trombe = 38, ixion = 42, tournesol = 56 }
C.CHARGE = { cairn = 90, stylet = 60, trombe = 100, ixion = 120, tournesol = 150, bourdon = 70 }
function C.rayon_base(id) return math.max(42, C.ZONE[id] + 6) end
--- Le bâtiment ami : sur le tracé de chaque attaque (canyon du Stylet, couloir de la Trombe, lac d'Ixion).
function C.ami_pos(id, x, y)
  local P = { cairn = { -20.5, 30.5 }, stylet = { 1.5, 21.5 }, trombe = { 6.5, 3.5 }, ixion = { 8.5, 4.5 }, tournesol = { -30.5, 20.5 } }
  local p = P[id]
  return { x + p[1], y + p[2] }
end

function C.forces()
  local cible = game.forces[C.CIBLE] or game.create_force(C.CIBLE)
  game.forces.enemy.set_cease_fire(cible, true)
  cible.set_cease_fire(game.forces.enemy, true)
  game.map_settings.enemy_expansion.enabled = false
  return cible
end

--- La force du géant du site k : hostile à la cible (qui ne lui tire pas dessus), en paix avec les biters, âge 15.
function C.force_geant(k)
  local cible = game.forces[C.CIBLE]
  local fname = "fo-att2-g" .. k
  local f = game.forces[fname] or game.create_force(fname)
  cible.set_cease_fire(f, true)
  f.set_cease_fire(cible, false)
  game.forces.enemy.set_cease_fire(f, true)
  f.set_cease_fire(game.forces.enemy, true)
  remote.call("fo-robots", "set_age", fname, 15)
  return f
end

local TYPES = { "assembling-machine-2", "assembling-machine-2", "lab", "solar-panel", "storage-tank", "assembling-machine-1", "lab" }

--- La base ennemie autour de (cx, cy), rayon R : îlots de 4 machines (6 × 6), tapis, un poteau moyen par îlot relié aux voisins, une lampe,
--- une tourelle sur 5 îlots, une source d'énergie au centre ; des arbres au sud. Rend le nombre de poteaux et la liste des lampes.
function C.base(s, cx, cy, R, graine)
  local poles, lampes = {}, {}
  local n = 0
  for gx = -R, R - 9, 9 do
    for gy = -R, R - 9, 9 do
      local x, y = cx + gx, cy + gy
      n = n + 1
      local ty = TYPES[(n * 7 + graine) % #TYPES + 1]
      for _, o in ipairs({ { 1.5, 1.5 }, { 4.5, 1.5 }, { 1.5, 4.5 }, { 4.5, 4.5 } }) do
        local e = s.create_entity({ name = ty, position = { x + o[1], y + o[2] }, force = C.CIBLE })
        if e and ty:find("assembling") then pcall(e.set_recipe, "iron-gear-wheel") end
      end
      for bx = 0, 6 do s.create_entity({ name = "transport-belt", position = { x + bx + 0.5, y + 7.5 }, direction = defines.direction.east, force = C.CIBLE }) end
      local p = s.create_entity({ name = "medium-electric-pole", position = { x + 7.5, y + 7.5 }, force = C.CIBLE })
      if p then poles[#poles + 1] = p end
      local l = s.create_entity({ name = "small-lamp", position = { x + 7.5, y + 5.5 }, force = C.CIBLE })
      if l then lampes[#lampes + 1] = l end
      if (n % 5) == 0 then s.create_entity({ name = "gun-turret", position = { x + 8, y + 2 }, force = C.CIBLE }) end
    end
  end
  -- la place de la source au centre d'abord (elle peut retirer un poteau d'îlot), puis le câblage des seuls poteaux restants
  for _, en in ipairs(s.find_entities_filtered({ area = { { cx - 1, cy - 1 }, { cx + 4, cy + 2 } } })) do en.destroy() end
  local restants = {}
  for _, p in ipairs(poles) do if p.valid then restants[#restants + 1] = p end end
  poles = restants
  for i, p in ipairs(poles) do
    for k = i + 1, #poles do
      local q = poles[k]
      local dx, dy = q.position.x - p.position.x, q.position.y - p.position.y
      if dx * dx + dy * dy <= 81.5 then p.connect_neighbour(q) end
    end
  end
  local src = s.create_entity({ name = "electric-energy-interface", position = { cx + 0.5, cy + 0.5 }, force = C.CIBLE })
  if src then src.power_production = 1e9; src.electric_buffer_size = 1e10 end
  local p0 = s.create_entity({ name = "medium-electric-pole", position = { cx + 2.5, cy + 0.5 }, force = C.CIBLE })
  if p0 then
    for _, q in ipairs(poles) do
      local dx, dy = q.position.x - p0.position.x, q.position.y - p0.position.y
      if dx * dx + dy * dy <= 81.5 then p0.connect_neighbour(q) end
    end
  end
  for t = 0, 30 do
    s.create_entity({ name = "tree-0" .. (t % 9 + 1), position = { cx - R + t * (2 * R / 30), cy + R + 3 } })
  end
  return #poles, lampes
end

--- Le géant du site, posé (raise_built) au pied de la base.
function C.poser(s, ss)
  ss.g = s.create_entity({ name = "fo-xp-" .. ss.id, position = { ss.x - C.PORTEE[ss.id], ss.y + 4 }, force = ss.force, raise_built = true })
  return ss.g
end

--- Prépare un site complet : terrain, base, force, bâtiment ami, géant (raise_built). Rend { g, ami, poles, lampes, force }.
--- `tard` : le géant n'est PAS posé (C.poser au moment de la grande attaque) ; sinon sa 1re attaque frappe la base avant (captures du 7/11 :
--- les pointes de glace du gel de la Trombe et des machines déjà mortes sur la base « avant »).
function C.site(ctx, k, id, x, y, tard)
  local s = ctx.surface()
  local R = C.rayon_base(id)
  ctx.prepare_area(x - R - 70, y - R - 30, x + R + 25, y + R + 25, "dry-dirt")
  for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - R - 120, y - R - 120 }, { x + R + 120, y + R + 120 } } })) do en.destroy() end
  local f = C.force_geant(k)
  local np, lampes = C.base(s, x, y, R, k * 3)
  local out = { id = id, x = x, y = y, poles = np, lampes = lampes, force = f.name }
  if id == "bourdon" then
    out.b = remote.call("fo-bourdon", "descendre", f.name, x, y)
    return out
  end
  local ap = C.ami_pos(id, x, y)
  for _, en in ipairs(s.find_entities_filtered({ area = { { ap[1] - 2, ap[2] - 2 }, { ap[1] + 2, ap[2] + 2 } } })) do en.destroy() end
  out.ami = s.create_entity({ name = "lab", position = ap, force = f })
  if not tard then C.poser(s, out) end
  return out
end

return C
