-- Lot DESIGN-MODULES (5/11) : MODULES DES GÉANTS en moteur réel, SUR LA COPIE JETABLE SEULEMENT (tools/autotest/xpm/jetable.py : prototypes
-- et script branchés, crochet de salve, cible d'essai fo-xpm-cible) ; sur le mod livré, le scénario se refuse. 2 500 ticks, sans images :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui DESIGN-MODULES -- 2500 xpm-grille "<copie>"
-- Règle d'échelle du lot EXPERIMENTAUX (shared/robots/echelle.lua) : le géant tire une SALVE de zone au point visé (coup plein sur chaque
-- ennemi du rayon) ; les modules la multiplient (Ech.effectif) : portée de ciblage et rayon × (1 + portée), salve × (1 + puissance).
-- Cibles : fo-xpm-cible (10 000 000 PV, sans résistance, cible militaire) : la salve ne tue pas, les PV perdus la mesurent exactement.
-- (1) prototypes : grille du Cairn 4 x 2, notre seule catégorie ; module sans capacité ; bouclier vanilla refusé ;
-- (2) PUISSANCE : Cairn sans module contre Cairn avec une puissance I : PV perdus par la cible au premier coup, rapport 1,15 ;
-- (3) ZONE : Cairn sans module contre Cairn avec deux portées III (+50 %) : une cible à 19 tuiles du point visé (zone de base 15, agrandie
--     22,5) n'est touchée qu'avec les modules ;
-- (4) PORTÉE : Stylet sans module contre Stylet avec deux portées III : une cible seule à 55 tuiles (portée de base 45, agrandie 67,5)
--     n'est frappée qu'avec les modules ; Cairn avec deux portées III et une cible seule à 50 tuiles (portée de base 40, agrandie 60) ;
-- (5) DÉMONTER puis REPOSER : l'objet du géant porte sa grille, le géant reposé retrouve ses modules ;
-- (6) REFUS AU PLAFOND : force à l'âge 10 (un géant) : le second Cairn, garni de 2 modules, est refusé ; objet et modules tombent au sol ;
-- (7) MARQUES : traits en tirets et anneaux au sol de factorio-overhaul présents après les salves avec modules.
local C = require("scenarios/xp_commun")

local CHECK = 2450
local Y = 5200
local LU = 170                  -- PV relus : après la première salve (vers le tick 60 à 100), avant la seconde (cadence de zone 180 et plus)
local CIBLE = "fo-xpm-cible"
local PU1, PO3 = "fo-xp-module-puissance-1", "fo-xp-module-portee-3"
local SITES = {
  { k = "a", geant = "fo-xp-cairn", force = "fo-xpm-a", x = 20000, mods = {}, cibles = { { 30, 0 } } },
  { k = "p", geant = "fo-xp-cairn", force = "fo-xpm-p", x = 20300, mods = { PU1 }, cibles = { { 30, 0 } } },
  { k = "z0", geant = "fo-xp-cairn", force = "fo-xpm-z0", x = 20600, mods = {}, cibles = { { 30, 0 }, { 30, 19 } } },
  { k = "z", geant = "fo-xp-cairn", force = "fo-xpm-z", x = 20900, mods = { PO3, PO3 }, cibles = { { 30, 0 }, { 30, 19 } } },
  { k = "s0", geant = "fo-xp-stylet", force = "fo-xpm-s0", x = 21200, mods = {}, cibles = { { 55, 0 } } },
  { k = "s", geant = "fo-xp-stylet", force = "fo-xpm-s", x = 21500, mods = { PO3, PO3 }, cibles = { { 55, 0 } } },
  { k = "c", geant = "fo-xp-cairn", force = "fo-xpm-c", x = 21800, mods = { PO3, PO3 }, cibles = { { 50, 0 } } },
}
local XM_, XX = 22100, 22400  -- démontage, refus

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

local function garnir(e, noms)
  local n = 0
  for _, nm in ipairs(noms) do if e and e.valid and e.grid and e.grid.put({ name = nm }) then n = n + 1 end end
  return n
end

--- Pose un géant garni : créé sans événement, modules posés, puis inscrit (script_raised_built) comme une pose par un joueur.
local function poser(s, nom, pos, f, mods)
  local e = s.create_entity({ name = nom, position = pos, force = f })
  if not e then return nil end
  garnir(e, mods)
  script.raise_script_built({ entity = e })
  return e
end

local function perdu(t) return t and t.valid and (t.prototype.max_health - t.health) or -1 end

local function au_sol(s, x, y, noms)
  local out = {}
  for _, nm in ipairs(noms) do out[nm] = 0 end
  for _, it in ipairs(s.find_entities_filtered({ name = "item-on-ground", position = { x, y }, radius = 14 })) do
    local st = it.stack
    if st and st.valid_for_read and out[st.name] ~= nil then out[st.name] = out[st.name] + st.count end
  end
  return out
end

local function rendus()
  local tirets, anneaux = 0, 0
  for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
    local ty = rendering.get_type(id)
    if ty == "line" and (rendering.get_dash_length(id) or 0) > 0 then tirets = tirets + 1 end
    if ty == "circle" and rendering.get_draw_on_ground(id) and not rendering.get_filled(id) then anneaux = anneaux + 1 end
  end
  return tirets, anneaux
end

return {
  description = "DESIGN-MODULES : modules de portee et de puissance des geants (grille, salve, zone, portee, demontage, refus, marques)",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local gp = game.entity_prototypes["fo-xp-cairn"]
    local eq = game.equipment_prototypes[PU1]
    if not (gp and gp.grid_prototype and eq and game.entity_prototypes[CIBLE]) then
      ctx.fail("modules des geants absents (copie jetable seulement : tools/autotest/xpm/jetable.py)")
      return
    end
    st.pret = true
    remote.call("fo-xp", "journal", true)
    local g = gp.grid_prototype
    ctx.check(g.name == "fo-xp-grille-cairn" and g.width == 4 and g.height == 2, "(1) grille du Cairn : 4 x 2", g.name .. " " .. g.width .. "x" .. g.height)
    local cats = g.equipment_categories
    ctx.check(#cats == 1 and cats[1] == "fo-xp-module", "(1) la grille n'accepte que nos modules", table.concat(cats, ","))
    local es = eq.energy_source
    ctx.check(es and (es.buffer_capacity or 0) == 0, "(1) module sans capacite (batterie vide)", es and tostring(es.buffer_capacity) or "nil")
    C.forces()
    local s = ctx.surface()
    s.freeze_daytime = true
    s.daytime = 0
    local noms = {}
    for _, si in ipairs(SITES) do noms[#noms + 1] = si.force end
    noms[#noms + 1] = "fo-xpm-m"
    noms[#noms + 1] = "fo-xpm-10"
    for _, x in ipairs({ SITES[1].x, SITES[#SITES].x, XM_, XX }) do
      ctx.prepare_area(x - 80, Y - 80, x + 120, Y + 80, "dry-dirt")
    end
    ctx.prepare_area(SITES[1].x - 80, Y - 80, XX + 120, Y + 80, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { SITES[1].x - 200, Y - 200 }, { XX + 250, Y + 200 } } })) do en.destroy() end
    for _, nm in ipairs(noms) do force(nm, nm == "fo-xpm-10" and 10 or 15) end
    for _, a in ipairs(noms) do
      for _, b in ipairs(noms) do if a ~= b then game.forces[a].set_friend(game.forces[b], true) end end
    end
    st.sites = {}
    for _, si in ipairs(SITES) do
      local e = poser(s, si.geant, { si.x, Y }, si.force, si.mods)
      local cs = {}
      for _, c in ipairs(si.cibles) do cs[#cs + 1] = s.create_entity({ name = CIBLE, position = { si.x + c[1], Y + c[2] }, force = C.CIBLE }) end
      st.sites[si.k] = { e = e, cibles = cs }
      ctx.check(e and e.valid and e.grid and #e.grid.equipment == #si.mods, "site " .. si.k .. " : " .. si.geant .. " pose avec " .. #si.mods .. " module(s)")
    end
    ctx.check(st.sites.p.e.grid.put({ name = "energy-shield-equipment" }) == nil, "(1) bouclier vanilla refuse par la grille du geant")
    -- (5) démonter puis reposer
    local m = poser(s, "fo-xp-cairn", { XM_, Y }, "fo-xpm-m", { PU1, PO3 })
    local inv = game.create_inventory(4)
    local mine = m and m.valid and m.mine({ inventory = inv, force = true, raise_destroyed = true })
    local stack = inv[1]
    local porte = stack and stack.valid_for_read and stack.name == "fo-xp-cairn" and stack.grid and #stack.grid.equipment or -1
    ctx.check(mine and porte == 2, "(5) l'objet du geant demonte porte sa grille et ses 2 modules", tostring(porte))
    local m2 = stack and stack.valid_for_read and s.create_entity({ name = "fo-xp-cairn", position = { XM_, Y + 40 }, force = "fo-xpm-m",
      item = stack, raise_built = true })
    ctx.check(m2 and m2.valid and m2.grid and #m2.grid.equipment == 2, "(5) le geant repose retrouve ses 2 modules",
      m2 and m2.valid and m2.grid and tostring(#m2.grid.equipment) or "absent")
    inv.destroy()
    -- (6) refus au plafond (âge 10 : un géant)
    st.x1 = poser(s, "fo-xp-cairn", { XX, Y }, "fo-xpm-10", {})
    local x2 = poser(s, "fo-xp-cairn", { XX, Y + 60 }, "fo-xpm-10", { PU1, PO3 })
    ctx.check(st.x1 and st.x1.valid and not (x2 and x2.valid), "(6) le second Cairn de l'age 10 est refuse")
    local sol = au_sol(s, XX, Y + 60, { "fo-xp-cairn", PU1, PO3 })
    ctx.check(sol["fo-xp-cairn"] == 1 and sol[PU1] == 1 and sol[PO3] == 1, "(6) le geant refuse rend son objet ET ses 2 modules",
      string.format("geant %d, puissance %d, portee %d", sol["fo-xp-cairn"], sol[PU1], sol[PO3]))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    if e.tick == LU then
      local S = st.sites
      st.l = { a = perdu(S.a.cibles[1]), p = perdu(S.p.cibles[1]), z0 = perdu(S.z0.cibles[2]), z = perdu(S.z.cibles[2]),
        s0 = perdu(S.s0.cibles[1]), s = perdu(S.s.cibles[1]), c = perdu(S.c.cibles[1]), z0c = perdu(S.z0.cibles[1]), zc = perdu(S.z.cibles[1]) }
      st.tirets, st.anneaux = rendus()
      local l = st.l
      ctx.log(string.format("PV perdus au tick %d : sans module %.0f, puissance I %.0f ; zone : 19 tuiles sans %.0f, avec %.0f (centre %.0f / %.0f) ;"
        .. " Stylet a 55 : sans %.0f, avec %.0f ; Cairn a 50 avec portee %.0f ; tirets %d, anneaux au sol %d",
        LU, l.a, l.p, l.z0, l.z, l.z0c, l.zc, l.s0, l.s, l.c, st.tirets, st.anneaux))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local l = st.l or {}
    ctx.check((l.a or 0) > 0, "(2) le Cairn sans module frappe sa cible", tostring(l.a))
    ctx.check((l.a or 0) > 0 and math.abs((l.p or 0) / l.a - 1.15) < 0.002, "(2) puissance I : salve x 1,15 exactement",
      (l.a or 0) > 0 and string.format("%.4f", (l.p or 0) / l.a) or "?")
    ctx.check((l.z0c or 0) > 0 and l.z0 == 0, "(3) sans module, la cible a 19 tuiles du point vise reste hors de la zone (15)", tostring(l.z0))
    ctx.check((l.zc or 0) > 0 and (l.z or 0) > 0, "(3) avec deux portees III, la zone (22,5) touche la cible a 19 tuiles", tostring(l.z))
    ctx.check(l.s0 == 0, "(4) Stylet sans module : la cible a 55 tuiles reste hors de portee (45)", tostring(l.s0))
    ctx.check((l.s or 0) > 0, "(4) Stylet avec deux portees III (67,5) : la cible a 55 tuiles est frappee", tostring(l.s))
    ctx.check((l.c or 0) > 0, "(4) Cairn avec deux portees III (60) : la cible a 50 tuiles est frappee", tostring(l.c))
    ctx.check((st.tirets or 0) >= 1 and (st.anneaux or 0) >= 1, "(7) marques des modules : trait de visee en tirets et anneau au sol",
      string.format("tirets %d, anneaux %d", st.tirets or 0, st.anneaux or 0))
  end,
}
