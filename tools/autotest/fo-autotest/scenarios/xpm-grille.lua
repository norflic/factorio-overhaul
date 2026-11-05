-- Lot DESIGN-MODULES (5/11) : MODULES DES GÉANTS en moteur réel, SUR LA COPIE JETABLE SEULEMENT (tools/autotest/xpm/jetable.py :
-- prototypes et script branchés, experimentaux_geants.lua remplacé par le fichier branché proposé) ; sur le mod livré, le scénario se
-- refuse (« modules des géants absents »). 2 500 ticks, sans images :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui DESIGN-MODULES -- 2500 xpm-grille "<copie>"
-- (1) prototypes : la grille du Cairn (4 x 2, notre seule catégorie), l'équipement sans capacité, un bouclier vanilla refusé ;
-- (2) PUISSANCE : deux Cairn, l'un sans module, l'autre avec un module de puissance I (+15 %), chacun devant 8 béhémoths immobiles
--     (3 000 PV, aucune résistance électrique ; le coup partagé en 8 ne tue pas) : PV perdus au premier balayage, rapport 1,15 ;
--     brûlures cramoisies au sol (une par cible) ;
-- (3) PORTÉE : deux Cairn devant un béhémoth à 50 tuiles (portée de base 40) : seul celui qui porte deux portées III (+50 %, 60 tuiles)
--     le frappe ; trait de visée violet en tirets dessiné ;
-- (4) DÉMONTER puis REPOSER : un Cairn garni de 2 modules est démonté dans un inventaire, l'objet porte la grille, le géant reposé
--     retrouve ses 2 modules ;
-- (5) REFUS AU PLAFOND : une force à l'âge 10 (plafond 1) : un second Cairn garni de 2 modules est refusé ; ses 2 modules et l'objet du
--     géant tombent au sol (rien de perdu).
local C = require("scenarios/xp_commun")

local CHECK = 2450
local Y = 5200
local X = { p = 20000, r = 20400, m = 20800, x = 21200 }
local LU = 150                  -- lecture des PV : après le premier balayage (balayage au tick 30, tir 30 ticks plus tard), avant le second (210)
local MOD_PU1, MOD_PO3 = "fo-xp-module-puissance-1", "fo-xp-module-portee-3"

local function force(nom, age)
  local f = game.forces[nom] or game.create_force(nom)
  local cible = game.forces[C.CIBLE]
  cible.set_cease_fire(f, true)
  f.set_cease_fire(cible, false)
  game.forces.enemy.set_cease_fire(f, true)
  f.set_cease_fire(game.forces.enemy, true)
  remote.call("fo-robots", "set_age", nom, age)
  return f
end

local function amies(noms)
  for _, a in ipairs(noms) do
    for _, b in ipairs(noms) do
      if a ~= b then game.forces[a].set_friend(game.forces[b], true) end
    end
  end
end

local function behemoths(s, x, y, n)
  local l = {}
  for k = 1, n do
    local b = s.create_entity({ name = "behemoth-biter", position = { x + (k - 1) % 4 * 3, y + math.floor((k - 1) / 4) * 3 }, force = C.CIBLE })
    if b then
      b.active = false
      l[#l + 1] = b
    end
  end
  return l
end

local function perdus(l)
  local t = 0
  for _, b in ipairs(l) do
    if b.valid then t = t + (b.prototype.max_health - b.health) else t = t + 1e9 end
  end
  return t
end

local function garnir(e, noms)
  local n = 0
  for _, nm in ipairs(noms) do if e and e.valid and e.grid and e.grid.put({ name = nm }) then n = n + 1 end end
  return n
end

--- Objets rendus au sol autour d'un point : { [nom] = nombre }, lus par une liste triée (aucun pairs).
local function au_sol(s, x, y, noms)
  local out = {}
  for _, nm in ipairs(noms) do out[nm] = 0 end
  for _, it in ipairs(s.find_entities_filtered({ name = "item-on-ground", position = { x, y }, radius = 12 })) do
    local st = it.stack
    if st and st.valid_for_read and out[st.name] ~= nil then out[st.name] = out[st.name] + st.count end
  end
  return out
end

--- Objets du `rendering` de factorio-overhaul encore vivants : traits en tirets, cercles pleins au sol.
local function rendus()
  local tirets, sol = 0, 0
  for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
    local ty = rendering.get_type(id)
    if ty == "line" and (rendering.get_dash_length(id) or 0) > 0 then tirets = tirets + 1 end
    if ty == "circle" and rendering.get_filled(id) and rendering.get_draw_on_ground(id) then sol = sol + 1 end
  end
  return tirets, sol
end

return {
  description = "DESIGN-MODULES : modules de portee et de puissance des geants (grille, bonus, marques, demontage, refus)",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local gp = game.entity_prototypes["fo-xp-cairn"]
    local eq = game.equipment_prototypes and game.equipment_prototypes[MOD_PU1]
    if not (gp and gp.grid_prototype and eq) then
      ctx.fail("modules des geants absents (copie jetable seulement : tools/autotest/xpm/jetable.py)")
      return
    end
    st.pret = true
    -- (1) prototypes
    local g = gp.grid_prototype
    ctx.check(g.name == "fo-xp-grille-cairn" and g.width == 4 and g.height == 2, "(1) grille du Cairn : 4 x 2", g.name .. " " .. g.width .. "x" .. g.height)
    local cats = g.equipment_categories
    ctx.check(#cats == 1 and cats[1] == "fo-xp-module", "(1) la grille n'accepte que nos modules", table.concat(cats, ","))
    local es = eq.energy_source
    ctx.check(es and (es.buffer_capacity or 0) == 0, "(1) module sans capacite (batterie vide)", es and tostring(es.buffer_capacity) or "nil")
    C.forces()
    local noms = { "fo-xpm-0", "fo-xpm-p", "fo-xpm-r0", "fo-xpm-r", "fo-xpm-m", "fo-xpm-10" }
    local s = ctx.surface()
    for _, x in ipairs({ X.p, X.r, X.m, X.x }) do
      ctx.prepare_area(x - 60, Y - 60, x + 120, Y + 120, "dry-dirt")
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 160, Y - 160 }, { x + 220, Y + 220 } } })) do en.destroy() end
    end
    force("fo-xpm-0", 15); force("fo-xpm-p", 15); force("fo-xpm-r0", 15); force("fo-xpm-r", 15); force("fo-xpm-m", 15); force("fo-xpm-10", 10)
    amies(noms)
    -- (2) puissance : sites à 160 tuiles l'un de l'autre (au-delà de toute portée)
    st.a = s.create_entity({ name = "fo-xp-cairn", position = { X.p, Y }, force = "fo-xpm-0", raise_built = true })
    st.ta = behemoths(s, X.p + 20, Y - 3, 8)
    local b = s.create_entity({ name = "fo-xp-cairn", position = { X.p, Y + 160 }, force = "fo-xpm-p" })
    garnir(b, { MOD_PU1 })
    script.raise_script_built({ entity = b })
    st.b = b
    st.tb = behemoths(s, X.p + 20, Y + 157, 8)
    ctx.check(st.a and st.a.valid and st.b and st.b.valid, "(2) deux Cairn poses (age 15)")
    ctx.check(st.b.grid and #st.b.grid.equipment == 1, "(2) module de puissance I dans la grille")
    local vanille = st.b.grid.put({ name = "energy-shield-equipment" })
    ctx.check(vanille == nil, "(1) bouclier vanilla refuse par la grille du geant")
    -- (3) portée : une cible à 50 tuiles
    st.r0 = s.create_entity({ name = "fo-xp-cairn", position = { X.r, Y }, force = "fo-xpm-r0", raise_built = true })
    st.tr0 = behemoths(s, X.r + 50, Y, 1)
    local r = s.create_entity({ name = "fo-xp-cairn", position = { X.r, Y + 160 }, force = "fo-xpm-r" })
    garnir(r, { MOD_PO3, MOD_PO3 })
    script.raise_script_built({ entity = r })
    st.r = r
    st.tr = behemoths(s, X.r + 50, Y + 160, 1)
    -- (4) démonter puis reposer
    local m = s.create_entity({ name = "fo-xp-cairn", position = { X.m, Y }, force = "fo-xpm-m" })
    ctx.check(garnir(m, { MOD_PU1, MOD_PO3 }) == 2, "(4) deux modules poses dans la grille")
    script.raise_script_built({ entity = m })
    local inv = game.create_inventory(4)
    local mine = m.valid and m.mine({ inventory = inv, force = true, raise_destroyed = true })
    local stack = inv[1]
    local porte = stack and stack.valid_for_read and stack.name == "fo-xp-cairn" and stack.grid and #stack.grid.equipment or -1
    ctx.check(mine and porte == 2, "(4) l'objet du geant demonte porte sa grille et ses 2 modules", tostring(porte))
    local m2 = stack and stack.valid_for_read and s.create_entity({ name = "fo-xp-cairn", position = { X.m, Y + 40 }, force = "fo-xpm-m",
      item = stack, raise_built = true })
    ctx.check(m2 and m2.valid and m2.grid and #m2.grid.equipment == 2, "(4) le geant repose retrouve ses 2 modules",
      m2 and m2.valid and m2.grid and tostring(#m2.grid.equipment) or "absent")
    inv.destroy()
    -- (5) refus au plafond (âge 10 : un géant)
    st.x1 = s.create_entity({ name = "fo-xp-cairn", position = { X.x, Y }, force = "fo-xpm-10", raise_built = true })
    local x2 = s.create_entity({ name = "fo-xp-cairn", position = { X.x, Y + 60 }, force = "fo-xpm-10" })
    garnir(x2, { MOD_PU1, MOD_PO3 })
    script.raise_script_built({ entity = x2 })
    ctx.check(st.x1 and st.x1.valid and not x2.valid, "(5) le second Cairn de l'age 10 est refuse")
    local sol = au_sol(s, X.x, Y + 60, { "fo-xp-cairn", MOD_PU1, MOD_PO3 })
    ctx.check(sol["fo-xp-cairn"] == 1 and sol[MOD_PU1] == 1 and sol[MOD_PO3] == 1, "(5) le geant refuse rend son objet ET ses 2 modules",
      string.format("geant %d, puissance %d, portee %d", sol["fo-xp-cairn"], sol[MOD_PU1], sol[MOD_PO3]))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    if e.tick == LU then
      st.pa, st.pb = perdus(st.ta), perdus(st.tb)
      st.tirets, st.sol = rendus()
      ctx.log(string.format("PV perdus au premier balayage : sans module %.1f, puissance I %.1f ; traits en tirets %d, brulures au sol %d",
        st.pa, st.pb, st.tirets, st.sol))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    ctx.check(st.pa and st.pa > 0 and st.pa < 1e8, "(2) le Cairn sans module frappe ses 8 cibles sans les tuer", tostring(st.pa))
    ctx.check(st.pa and st.pb and st.pa > 0 and math.abs(st.pb / st.pa - 1.15) < 0.002, "(2) puissance I : degats x 1,15 exactement",
      st.pa and st.pb and st.pa > 0 and string.format("%.4f", st.pb / st.pa) or "?")
    ctx.check((st.sol or 0) >= 8, "(2) une brulure cramoisie au sol par cible frappee (au moins 8)", tostring(st.sol))
    local h0 = st.tr0[1] and st.tr0[1].valid and st.tr0[1].health or -1
    local h1 = st.tr[1] and st.tr[1].valid and st.tr[1].health or -1
    ctx.check(h0 == 3000, "(3) sans module, la cible a 50 tuiles reste hors de portee (40)", tostring(h0))
    ctx.check(h1 < 3000, "(3) avec deux portees III (60 tuiles), la cible a 50 tuiles est frappee", tostring(h1))
    ctx.check((st.tirets or 0) >= 1, "(3) trait de visee violet en tirets dessine", tostring(st.tirets))
  end,
}
