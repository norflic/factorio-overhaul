--[[
  Cas PURS de la règle de décalage « libérer la place » (lot V3-T3, shared/levels/clear.lua), joués par
  tests/levels_test.lua (fichier à part : le bloc principal de levels_test est à la limite des 200 variables locales
  de Lua 5.2). Chaque cas bâtit une scène à la main (boîtes de collision vanilla relevées par
  tests/datastage/harness.lua --dump-proto : bras ± 0,15, convoyeur ± 0,4, mur ± 0,29, poteau moyen ± 0,15, coffre
  ± 0,35, assembleur 3×3 ± 1,2, mitrailleuse 2×2 ± 0,7) et compare le plan à ce que la règle (en tête de clear.lua)
  impose. Directions : nord 0, est 2, sud 4, ouest 6 ; un bras orienté au nord PREND au nord et DÉPOSE au sud
  (moteur réel, essai E56).
]]

local C = require("shared.levels.clear")
local Foot = require("shared.levels.footprint")

local Cases = {}

--- Bavard sur demande (variable d'environnement FO_VERBOSE_CLEAR=1) : chaque contrôle et son détail.
local function verbose(check)
  if not os.getenv("FO_VERBOSE_CLEAR") then return check end
  return function(cond, msg, detail)
    print((cond and "  OK " or "  ECHEC ") .. msg .. (detail and (" : " .. tostring(detail)) or ""))
    check(cond, msg)
  end
end

function Cases.pure(check, section)
  check = verbose(check)
  section("Libérer la place (lot V3-T3) : règle de décalage, cas purs")

  local HALF = { inserter = 0.15, ["transport-belt"] = 0.4, wall = 0.29, ["electric-pole"] = 0.15, container = 0.35,
    ["assembling-machine"] = 1.2, ["ammo-turret"] = 0.7, tree = 0.4, cliff = 1.5, pipe = 0.29, gate = 0.29, ["entity-ghost"] = 0.15 }

  --- Scène : enregistrements au format de Levels.free_room (script/levels/levels.lua).
  local function scene()
    local S = { recs = {}, n = 0 }
    function S.add(name, etype, x, y, dir, extra)
      S.n = S.n + 1
      local h = (extra and extra.half) or HALF[etype] or 0.4
      local r = { id = S.n, name = name, type = etype, x = x, y = y, dir = dir or 0,
        box = { x0 = x - h, y0 = y - h, x1 = x + h, y1 = y + h } }
      for k, v in pairs(extra or {}) do r[k] = v end
      r.kind = C.kind(etype, r.foreign)
      if etype == "inserter" then
        -- Bras vanilla : prise à 1 tuile, dépôt à 1,2 tuile, côté opposé ; « nord » = prend au nord.
        local v = C.DIRV[r.dir]
        r.pick = r.pick or { x = x + v.x, y = y + v.y }
        r.drop = r.drop or { x = x - 1.2 * v.x, y = y - 1.2 * v.y }
      end
      S.recs[#S.recs + 1] = r
      return r
    end
    return S
  end

  --- Gêneurs de la candidate B (comme Levels.room : chevauchement strict avec la boîte de collision de B).
  local function blockers(S, B)
    local rect = Foot.collision_rect(B)
    local out = {}
    for _, r in ipairs(S.recs) do
      if r.kind ~= "ghost" and Foot.overlap(rect, r.box) then out[#out + 1] = r.id end
    end
    return out
  end

  local function plan(S, B, old, extra)
    local input = { new_box = B, old_rect = old, scene = S.recs, blockers = blockers(S, B), connector = "stone-wall" }
    for k, v in pairs(extra or {}) do input[k] = v end
    return C.plan(input)
  end

  local function has_ghost(p, name, x, y, dir)
    for _, g in ipairs(p.ghosts) do
      if g.name == name and math.abs(g.x - x) < 1e-6 and math.abs(g.y - y) < 1e-6 and (dir == nil or g.dir == dir) then return true end
    end
    return false
  end

  local function ids(list)
    local t = {}
    for _, v in ipairs(list) do t[#t + 1] = tostring(v) end
    table.sort(t)
    return table.concat(t, ",")
  end

  local function sig_ids(p)
    local t = {}
    for _, s in ipairs(p.signals) do if s.id then t[#t + 1] = tostring(s.id) end end
    table.sort(t)
    return table.concat(t, ",")
  end

  local function ghosts_text(p)
    local t = {}
    for _, g in ipairs(p.ghosts) do t[#t + 1] = string.format("%s@%g,%g/%d", g.name, g.x, g.y, g.dir) end
    return table.concat(t, " ")
  end

  -- 0. Sorties ------------------------------------------------------------------------------------------------
  local B = { x0 = 15, y0 = 49, x1 = 19, y1 = 53 }
  local ex = C.exits(B, { x0 = 16, y0 = 52, x1 = 17, y1 = 53 })
  check(ex[1].dir == 4 and ex[1].d == 1 and ex[2].d > 1, "sortie minimale : une tuile de la rangée sud sort au sud d'une tuile")
  local exc = C.exits(B, { x0 = 18, y0 = 52, x1 = 19, y1 = 53 })
  check(exc[1].d == 1 and exc[2].d == 1 and exc[1].dir == 2 and exc[2].dir == 4,
    "coin sud-est : deux sorties d'une tuile, ordre fixe est puis sud (égalité de profondeur, toutes deux s'éloignent du centre)")
  check(C.kind("inserter") == "arm" and C.kind("tree") == "natural" and C.kind("assembling-machine") == "fixed"
    and C.kind("container", true) == "fixed" and C.kind("cliff") == "fixed",
    "sortes : bras, arbre, bâtiment, coffre d'une autre force (signalé), falaise (signalée)")

  -- 1. Usine dense : assembleur 3×3 en (16,5 ; 50,5), bras au nord (entrée) et au sud (sortie), convoyeurs vers
  --    l'est au-delà, voisin collé à l'ouest, colonne est libre. 3×3 → 4×4 : candidate sud-est (règle de position).
  local function dense(extra_east)
    local S = scene()
    local old = { x0 = 15.3, y0 = 49.3, x1 = 17.7, y1 = 51.7 }
    S.add("assembling-machine-2", "assembling-machine", 13.5, 50.5) -- voisin ouest
    local armN = S.add("inserter", "inserter", 16.5, 48.5, 0)       -- prend au nord (convoyeur), dépose dans la machine
    local armS = S.add("inserter", "inserter", 16.5, 52.5, 0)       -- prend dans la machine, dépose au sud
    for x = 11.5, 21.5 do
      S.add("transport-belt", "transport-belt", x, 47.5, 2)
      S.add("transport-belt", "transport-belt", x, 53.5, 2)
    end
    if extra_east then extra_east(S) end
    return S, old, armN, armS
  end
  local S1, old1, _, armS1 = dense()
  local cands = Foot.candidates(Foot.tile_box({ x = 16.5, y = 50.5 }, 3), 4)
  local B1 = cands[1].box
  check(B1.x0 == 15 and B1.y0 == 49 and B1.x1 == 19 and B1.y1 == 53, "usine dense : la candidate préférée du 4×4 est au sud-est (x 15..19, y 49..53)")
  local p1 = plan(S1, B1, old1)
  check(#p1.signals == 0 and #p1.groups == 1 and #p1.marks == 3,
    "usine dense : un groupe (bras sud + bosse), 3 marques (bras, convoyeur sous le bras, convoyeur amont tourné), rien de signalé",
    ghosts_text(p1) .. " ; signaux " .. sig_ids(p1))
  check(has_ghost(p1, "inserter", 16.5, 53.5, 0) and has_ghost(p1, "transport-belt", 15.5, 53.5, 4)
    and has_ghost(p1, "transport-belt", 15.5, 54.5, 2) and has_ghost(p1, "transport-belt", 16.5, 54.5, 2)
    and has_ghost(p1, "transport-belt", 17.5, 54.5, 0) and #p1.ghosts == 5,
    "usine dense : bras reposé une tuile au sud, même orientation ; bosse : amont tourné au sud, deux tuiles décalées, retour au nord sur l'aval")
  -- Le bras reposé : son point côté bâtiment tombe dans le nouveau carré, son dépôt sur la bosse.
  local ga = p1.ghosts[1]
  check(C.point_in_tiles(B1, ga.x, ga.y - 1) and math.abs(ga.y + 1.2 - 54.7) < 1e-6,
    "usine dense : le bras reposé prend dans le nouveau carré (52,5) et dépose sur la bosse (54,7)")
  -- Déterminisme : scène dans un autre ordre, même plan.
  local S1b = scene()
  for i = #S1.recs, 1, -1 do local r = S1.recs[i]; S1b.recs[#S1b.recs + 1] = r end
  local p1b = plan(S1b, B1, old1)
  check(ghosts_text(p1b) == ghosts_text(p1) and ids(p1b.marks) == ids(p1.marks), "déterminisme : scène relevée dans l'ordre inverse, même plan")

  -- 1b. Même usine, candidate nord-est (rang 3) : bras d'ENTRÉE reposé une tuile au nord, bosse vers le nord.
  local S1n, old1n = dense()
  local B1n = cands[3].box
  local p1n = plan(S1n, B1n, old1n)
  check(B1n.y0 == 48 and B1n.x0 == 15 and #p1n.signals == 0 and #p1n.marks == 3 and has_ghost(p1n, "inserter", 16.5, 47.5, 0)
    and has_ghost(p1n, "transport-belt", 15.5, 47.5, 0) and has_ghost(p1n, "transport-belt", 15.5, 46.5, 2)
    and has_ghost(p1n, "transport-belt", 16.5, 46.5, 2) and has_ghost(p1n, "transport-belt", 17.5, 46.5, 4),
    "candidate nord-est : bras d'entrée une tuile au nord (il prend sur la bosse et dépose dans le nouveau carré), bosse vers le nord",
    ghosts_text(p1n))

  -- 2. Place de la bosse prise (un coffre en (16,5 ; 54,5)) : le groupe ne tient pas, le bras est SIGNALÉ, rien marqué.
  local S2 = dense(function(S) S.add("iron-chest", "container", 16.5, 54.5) end)
  local p2 = plan(S2, B1, old1)
  check(#p2.marks == 0 and #p2.ghosts == 0 and #p2.signals == 1 and p2.signals[1].id == armS1.id,
    "bosse impossible (place prise) : bras signalé, rien marqué ni posé (groupe tout ou rien)", p2.signals[1] and p2.signals[1].why)

  -- 3. Bras voisin qui prend sur la tuile démontée : refusé (il serait privé).
  local S3 = dense(function(S) S.add("long-handed-inserter", "inserter", 16.5, 55.5, 0, { pick = { x = 16.5, y = 53.5 }, drop = { x = 16.5, y = 57.5 } }) end)
  local p3 = plan(S3, B1, old1)
  check(#p3.marks == 0 and #p3.signals == 1 and p3.signals[1].why:find("voisin", 1, true),
    "bras long d'un voisin qui prend sur la tuile reprise : groupe refusé (il serait privé), bras signalé", p3.signals[1] and p3.signals[1].why)

  -- 4. Candidate à l'ouest (colonne est prise par un bâtiment) : le voisin collé est SIGNALÉ, jamais marqué.
  local S4, old4 = dense()
  local B4 = cands[2].box -- (14, 49) - (18, 53) : sud-ouest
  local p4 = plan(S4, B4, old4)
  local neigh_sig = false
  for _, s in ipairs(p4.signals) do if s.id == 1 then neigh_sig = true end end
  local neigh_marked = false
  for _, id in ipairs(p4.marks) do if id == 1 then neigh_marked = true end end
  check(B4.x0 == 14 and neigh_sig and not neigh_marked and #p4.groups == 1,
    "candidate sud-ouest : l'assembleur voisin est signalé (à retirer à la main), jamais marqué ; le bras sud est quand même traité",
    "B4 " .. B4.x0 .. "," .. B4.y0 .. " ; signaux " .. sig_ids(p4))

  -- 5. Bras nourri par un coffre : le coffre suit le bras.
  local S5 = scene()
  local old5 = { x0 = 15.3, y0 = 49.3, x1 = 17.7, y1 = 51.7 }
  S5.add("inserter", "inserter", 16.5, 52.5, 4) -- prend au sud (coffre), dépose au nord dans la machine
  S5.add("iron-chest", "container", 16.5, 53.5)
  local p5 = plan(S5, B1, old5)
  check(#p5.signals == 0 and has_ghost(p5, "inserter", 16.5, 53.5, 4) and has_ghost(p5, "iron-chest", 16.5, 54.5) and #p5.marks == 2,
    "bras nourri par un coffre : bras et coffre décalés ensemble d'une tuile", ghosts_text(p5))

  -- 6. Bras au bout d'une ligne qui arrive du sud (ligne dans l'axe du bras) : la ligne est raccourcie d'une tuile.
  local S6 = scene()
  S6.add("inserter", "inserter", 16.5, 52.5, 4)
  for y = 53.5, 57.5 do S6.add("transport-belt", "transport-belt", 16.5, y, 0) end -- vers le nord, finit au bras
  local p6 = plan(S6, B1, old5)
  check(#p6.signals == 0 and #p6.ghosts == 1 and has_ghost(p6, "inserter", 16.5, 53.5, 4) and #p6.marks == 2,
    "ligne dans l'axe du bras : raccourcie d'une tuile, le bras reposé prend sur la nouvelle fin de ligne", ghosts_text(p6))
  -- Ligne trop courte (une seule tuile) : le bras perdrait sa prise : signalé.
  local S6b = scene()
  S6b.add("inserter", "inserter", 16.5, 52.5, 4)
  S6b.add("transport-belt", "transport-belt", 16.5, 53.5, 0)
  local p6b = plan(S6b, B1, old5)
  check(#p6b.marks == 0 and #p6b.signals == 1, "ligne d'une seule tuile dans l'axe : signalé (le nouveau point ne serait plus servi)",
    p6b.signals[1] and p6b.signals[1].why)

  -- 7. Poteau dans la colonne est : décalé d'une tuile à l'est si son fil reste à portée.
  local S7 = scene()
  S7.add("medium-electric-pole", "electric-pole", 18.5, 50.5, 0, { reach = 9, wires = { { x = 26.5, y = 50.5, reach = 9 } } })
  local p7 = plan(S7, B1, old5)
  check(#p7.signals == 0 and has_ghost(p7, "medium-electric-pole", 19.5, 50.5), "poteau : décalé d'une tuile vers l'est, fil à 7 tuiles (portée 9)", ghosts_text(p7))
  local S7b = scene()
  S7b.add("medium-electric-pole", "electric-pole", 18.5, 50.5, 0, { reach = 9, wires = { { x = 9.5, y = 50.5, reach = 9 } } })
  local p7b = plan(S7b, B1, old5)
  check(#p7b.signals == 0 and has_ghost(p7b, "medium-electric-pole", 14.5, 50.5),
    "poteau : fil vers l'ouest hors de portée par l'est (10 > 9), le nord et le sud ; sortie ouest (4 tuiles) retenue", ghosts_text(p7b))
  local S7c = scene()
  S7c.add("medium-electric-pole", "electric-pole", 18.5, 50.5, 0, { reach = 9, wires = { { x = 9.5, y = 50.5, reach = 9 }, { x = 26.5, y = 50.5, reach = 9 } } })
  local p7c = plan(S7c, B1, old5)
  check(#p7c.marks == 0 and #p7c.signals == 1 and p7c.signals[1].why:find("portee", 1, true),
    "poteau tenu par deux fils opposés : aucune sortie ne garde les deux à portée : signalé, pas marqué", p7c.signals[1] and p7c.signals[1].why)

  -- 8. Arbre : marqué, rien à reposer ; falaise, bâtiment d'une autre force : signalés.
  local S8 = scene()
  local tree = S8.add("tree-01", "tree", 18.5, 49.5)
  local cliff = S8.add("cliff", "cliff", 17.5, 52.5, 0, { half = 0.5 })
  local foreign = S8.add("iron-chest", "container", 18.5, 51.5, 0, { foreign = true })
  local p8 = plan(S8, B1, old5)
  local sig8 = sig_ids(p8)
  check(ids(p8.marks) == tostring(tree.id) and #p8.ghosts == 0 and sig8 == ids({ cliff.id, foreign.id }),
    "arbre marqué sans fantôme ; falaise et coffre d'une autre force signalés", "marques " .. ids(p8.marks) .. " ; signaux " .. sig8)

  -- 9. Eau dans la candidate : chaque tuile est signalée.
  local p9 = plan(scene(), B1, old5, { tiles = { { x = 18, y = 52, name = "water" } } })
  check(#p9.signals == 1 and p9.signals[1].tile and p9.signals[1].tile.name == "water", "tuile d'eau de la candidate : signalée (à remblayer)")
  -- Eau AUTOUR : un fantôme n'y est jamais posé (poteau qui sortirait sur l'eau : autre sortie).
  local S9 = scene()
  S9.add("medium-electric-pole", "electric-pole", 18.5, 49.5, 0, { reach = 9, wires = {} })
  local p9b = plan(S9, B1, old5, { area_tiles = { { x = 18, y = 48, name = "water" } } })
  check(#p9b.signals == 0 and has_ghost(p9b, "medium-electric-pole", 19.5, 49.5),
    "poteau du coin : sortie nord sur l'eau refusée, sortie est retenue", ghosts_text(p9b))

  -- 10. Mur d'une rangée au nord d'une mitrailleuse 2×2 (Q-T3) : 2×2 → 3×3, candidate nord.
  --     Mitrailleuse en (20 ; 40) (tuiles 19..21 × 39..41), mur en y = 38,5 de x = 15,5 à 24,5.
  local S10 = scene()
  for x = 15.5, 24.5 do S10.add("stone-wall", "wall", x, 38.5) end
  local old10 = { x0 = 19.3, y0 = 39.3, x1 = 20.7, y1 = 40.7 }
  local B10 = { x0 = 19, y0 = 38, x1 = 22, y1 = 41 }
  local p10 = plan(S10, B10, old10)
  check(#p10.signals == 0 and #p10.marks == 3 and has_ghost(p10, "stone-wall", 19.5, 37.5) and has_ghost(p10, "stone-wall", 21.5, 37.5)
    and has_ghost(p10, "stone-wall", 18.5, 37.5) and has_ghost(p10, "stone-wall", 22.5, 37.5) and #p10.ghosts == 5 and #p10.warnings == 0,
    "mur d'une rangée : 3 murs décalés d'une tuile au nord, 2 murs de liaison (ligne refermée)", ghosts_text(p10))
  -- Mur épais (deux rangées) : la rangée intérieure pousse l'extérieure ; liaisons sur la rangée extérieure seulement.
  local S11 = scene()
  for x = 15.5, 24.5 do S11.add("fo-lvl-wall-7", "wall", x, 38.5); S11.add("fo-lvl-wall-7", "wall", x, 37.5) end
  local p11 = plan(S11, B10, old10)
  check(#p11.signals == 0 and #p11.marks == 6 and has_ghost(p11, "fo-lvl-wall-7", 20.5, 37.5) and has_ghost(p11, "fo-lvl-wall-7", 20.5, 36.5)
    and has_ghost(p11, "stone-wall", 18.5, 36.5) and has_ghost(p11, "stone-wall", 22.5, 36.5) and #p11.ghosts == 8,
    "mur épais : 3 + 3 murs décalés (épaisseur gardée), 2 liaisons au mur de base (un mur de niveau ne se fabrique pas)", ghosts_text(p11))
  -- Liaison impossible (rocher sur sa place) : la ligne reste ouverte, c'est dit.
  local S12 = scene()
  for x = 15.5, 24.5 do S12.add("stone-wall", "wall", x, 38.5) end
  S12.add("rock-big", "simple-entity", 22.5, 37.5, 0, { half = 0.45, foreign = true })
  local p12 = plan(S12, B10, old10)
  check(#p12.warnings == 1 and has_ghost(p12, "stone-wall", 18.5, 37.5) and not has_ghost(p12, "stone-wall", 22.5, 37.5),
    "liaison impossible : ligne laissée ouverte et signalée en avertissement", p12.warnings[1] and p12.warnings[1].why)

  -- 13. Convoyeur qui longe le côté DANS le carré (pas de bras) : bosse de toutes ses tuiles du carré.
  local S13 = scene()
  for x = 13.5, 22.5 do S13.add("transport-belt", "transport-belt", x, 52.5, 6) end -- vers l'ouest, rangée 52
  local p13 = plan(S13, B1, old5)
  check(#p13.signals == 0 and #p13.marks == 5 and has_ghost(p13, "transport-belt", 15.5, 53.5, 6) and has_ghost(p13, "transport-belt", 18.5, 53.5, 6)
    and has_ghost(p13, "transport-belt", 19.5, 52.5, 4) and has_ghost(p13, "transport-belt", 19.5, 53.5, 6) and has_ghost(p13, "transport-belt", 14.5, 53.5, 0),
    "convoyeur qui longe dans le carré : 4 tuiles en bosse au sud, amont tourné, retour sur l'aval", ghosts_text(p13))
  -- Convoyeur qui ENTRE dans le carré par le sud et y finit : raccourci.
  local S14 = scene()
  for y = 52.5, 56.5 do S14.add("transport-belt", "transport-belt", 17.5, y, 0) end
  local p14 = plan(S14, B1, old5)
  check(#p14.signals == 0 and #p14.marks == 1 and #p14.ghosts == 0, "ligne qui finit dans le carré : raccourcie d'une tuile, rien à reposer")
  -- Tuyau qui longe le côté : signalé (décaler un tuyau casserait le réseau).
  local S15 = scene()
  for x = 13.5, 22.5 do S15.add("pipe", "pipe", x, 52.5) end
  local p15 = plan(S15, B1, old5)
  check(#p15.marks == 0 and #p15.signals >= 1, "tuyau qui longe le côté : signalé, rien marqué", p15.signals[1] and p15.signals[1].why)

  -- 16. Coffre qui sert un point de jeu (dépôt d'une foreuse) : il suit le point.
  local S16 = scene()
  local chest = S16.add("iron-chest", "container", 16.5, 48.5)
  local p16 = plan(S16, B1, old5, { blockers = {}, moved = { { id = chest.id, old = { x = 16.5, y = 48.6 }, new = { x = 17.5, y = 48.6 } } } })
  check(#p16.signals == 0 and has_ghost(p16, "iron-chest", 17.5, 48.5), "coffre du dépôt d'une foreuse : suit le point (une tuile à l'est)", ghosts_text(p16))

  -- 17. Gêneur déjà marqué par le joueur : ni marqué ni reposé par le mod.
  local S17 = scene()
  S17.add("iron-chest", "container", 18.5, 50.5, 0, { marked = true })
  local p17 = plan(S17, B1, old5)
  check(#p17.marks == 0 and #p17.ghosts == 0 and #p17.signals == 0, "gêneur déjà marqué par le joueur : laissé tel quel (il part déjà)")

  -- 18. Fantôme déjà posé sur la place visée : place prise.
  local S18 = scene()
  S18.add("medium-electric-pole", "electric-pole", 18.5, 50.5, 0, { reach = 9, wires = {} })
  S18.add("entity-ghost", "entity-ghost", 19.5, 50.5)
  local p18 = plan(S18, B1, old5)
  check(not has_ghost(p18, "medium-electric-pole", 19.5, 50.5), "un fantôme existant occupe la place : jamais de fantôme par-dessus", ghosts_text(p18))

  -- 19. Trop de gêneurs : refus.
  local S19 = scene()
  for x = 0.5, 70.5 do S19.add("tree-01", "tree", x, 50.5) end
  local p19 = plan(S19, { x0 = 0, y0 = 49, x1 = 72, y1 = 53 }, { x0 = 30, y0 = 49.3, x1 = 31, y1 = 49.4 })
  check(p19.too_many and #p19.marks == 0, "plus de " .. C.MAX_MARKS .. " gêneurs : refus, rien marqué")
end

--- Script en moteur simulé (script/levels/free.lua) : demande, marques, fantômes, attente, agrandissement, annulation,
--- expiration, bâtiment disparu, panneau, état de global (données simples). À jouer APRÈS les sections de
--- levels_test qui posent les prototypes des niveaux (masques et boîtes des mitrailleuses, mur, coffre).
function Cases.runtime(check, section)
  check = verbose(check)
  section("Libérer la place (lot V3-T3) : script en moteur simulé")
  local M = require("tests.mock_engine")
  local Wd = M.world()
  local L = require("shared.levels.config")
  local Levels = require("script.levels.levels")
  local Free = require("script.levels.free")
  local GUN, CCF = L.by_key.gun, L.by_key.command
  local s = game.surfaces[1]
  local MASKB = { ["object-layer"] = true, ["item-layer"] = true, ["player-layer"] = true, ["water-tile"] = true }
  local function proto(name, ptype, half, mask, extra)
    local p = { type = ptype, max_health = 100, collision_mask = mask,
      collision_box = { left_top = { x = -half, y = -half }, right_bottom = { x = half, y = half } } }
    for k, v in pairs(extra or {}) do p[k] = v end
    rawset(Wd.prototypes, name, p)
  end
  proto("inserter", "inserter", 0.15, MASKB)
  proto("transport-belt", "transport-belt", 0.4, { ["floor-layer"] = true, ["object-layer"] = true, ["transport-belt-layer"] = true, ["water-tile"] = true })
  local F3 = "fo-t3-sim"
  game.create_force(F3)
  local cc = s.create_entity({ name = L.name(CCF, 15), position = { x = 2900.5, y = 2900.5 }, force = F3, raise_built = true })
  local cinv = cc.get_inventory(defines.inventory.chest)
  for _ = 1, 3 do for _, c in ipairs(L.cost(GUN, 7)) do cinv.insert({ name = c[1], count = c[2] }) end end

  --- Mitrailleuse 6 collée à un mur au nord, nourrie par un bras au sud (convoyeur vers l'est au-delà).
  local function layout(x, y)
    local g = s.create_entity({ name = L.name(GUN, 6), position = { x = x, y = y }, force = F3 })
    for wx = x - 4.5, x + 5.5 do s.create_entity({ name = "stone-wall", position = { x = wx, y = y - 1.5 }, force = F3 }) end
    local arm = s.create_entity({ name = "inserter", position = { x = x + 0.5, y = y + 1.5 }, direction = 4, force = F3 })
    for bx = x - 4.5, x + 5.5 do s.create_entity({ name = "transport-belt", position = { x = bx, y = y + 2.5 }, direction = 2, force = F3 }) end
    return g, arm
  end
  local function ghosts_near(x, y)
    local out = {}
    for _, e in ipairs(s.find_entities_filtered({ area = { { x - 8, y - 8 }, { x + 8, y + 8 } }, type = "entity-ghost" })) do
      out[#out + 1] = string.format("%s@%g,%g/%d", e.ghost_name, e.position.x, e.position.y, e.direction)
    end
    table.sort(out)
    return table.concat(out, " ")
  end
  local function marked_near(x, y)
    local out = {}
    for _, e in ipairs(s.find_entities_filtered({ area = { { x - 8, y - 8 }, { x + 8, y + 8 } } })) do
      if e.valid and e.to_be_deconstructed() then out[#out + 1] = e end
    end
    return out
  end
  local function call(fn, ...) return remote.call("factorio-overhaul", fn, ...) end
  local function stats() return Free.status().stats end

  -- 1. Demande : marques, fantômes, attente.
  local g1, arm1 = layout(3000, 3000)
  local r1 = call("levels_free_room", g1)
  local want = "inserter@3000.5,3002.5/4 transport-belt@2999.5,3002.5/4 transport-belt@2999.5,3003.5/2 transport-belt@3000.5,3003.5/2 transport-belt@3001.5,3003.5/0"
  check(r1.ok and r1.reason == "pending" and #r1.marks == 3 and #r1.ghosts == 5 and arm1.to_be_deconstructed() and ghosts_near(3000, 3000) == want,
    "moteur simulé : « libérer la place » d'une mitrailleuse collée au mur : bras marqué, bosse, 5 fantômes aux places de la règle",
    ghosts_near(3000, 3000))
  check(not call("levels_upgrade", g1).ok and g1.valid and Free.check() == 0 and #Free.status().requests == 1,
    "moteur simulé : sans place, la demande attend ; la règle Q24 refuse toujours l'amélioration")
  local r1b = call("levels_free_room", g1)
  check(not r1b.ok and r1b.reason == "already", "moteur simulé : une seule demande par bâtiment")
  -- global : NOMBRES seulement dans les demandes (consigne du lot : aucune chaîne, aucune entité, aucune fonction).
  local function numbers_only(v, seen)
    if type(v) == "number" or type(v) == "boolean" then return true end
    if type(v) ~= "table" or rawget(v, "_lua_object") then return false end
    seen = seen or {}
    if seen[v] then return true end
    seen[v] = true
    for _, x in pairs(v) do if not numbers_only(x, seen) then return false end end
    return true
  end
  check(numbers_only(global.fo.levels_free.list) and #global.fo.levels_free.list == 1,
    "moteur simulé : la demande dans global ne garde que des nombres (aucune chaîne, aucune entité, aucune fonction)")
  -- Robots : les marques minées ; la vérification suivante agrandit, à la position du contour, coût payé.
  local robot = game.create_inventory(50)
  for _, e in ipairs(marked_near(3000, 3000)) do e.mine({ inventory = robot, raise_destroyed = true }) end
  local done = Free.check()
  local g7 = s.find_entities_filtered({ name = L.name(GUN, 7), area = { { 2995, 2995 }, { 3005, 3005 } } })[1]
  check(done == 1 and g7 and g7.position.x == 2999.5 and g7.position.y == 3000.5 and not g1.valid and #Free.status().requests == 0
    and robot.get_item_count("inserter") == 1 and robot.get_item_count("transport-belt") == 2,
    "moteur simulé : gêneurs démontés → agrandissement en attente fait à la vérification suivante (3×3 au sud-ouest, position du contour)",
    g7 and (g7.position.x .. "," .. g7.position.y) or "absent")
  local revived = 0
  for _, gh in ipairs(s.find_entities_filtered({ area = { { 2992, 2992 }, { 3008, 3008 } }, type = "entity-ghost" })) do
    local _, e = gh.revive({ raise_revive = true })
    if e then revived = revived + 1 end
  end
  check(revived == 5, "moteur simulé : les 5 fantômes se construisent (revive)")

  -- 2. Annuler : marques et fantômes du mod retirés, et seulement eux.
  local g2 = layout(3100, 3000)
  local other = s.create_entity({ name = "entity-ghost", inner_name = "iron-chest", position = { x = 3104.5, y = 3005.5 }, force = F3 })
  local chest = s.create_entity({ name = "iron-chest", position = { x = 3105.5, y = 3005.5 }, force = F3 })
  chest.order_deconstruction(F3)
  call("levels_free_room", g2)
  local c = call("levels_free_cancel", g2)
  local left = marked_near(3100, 3000)
  check(c and c.unmarked == 3 and c.removed == 5 and c.kept == 0 and #left == 1 and left[1] == chest and other.valid
    and ghosts_near(3100, 3000) == "iron-chest@3104.5,3005.5/0" and #Free.status().requests == 0,
    "moteur simulé : Annuler retire 3 marques et 5 fantômes du mod ; la marque et le fantôme du joueur restent")

  -- 3. Expiration : au-delà de Free.TTL, la demande est retirée comme par Annuler.
  local g3 = layout(3200, 3000)
  call("levels_free_room", g3)
  local tick0 = game.tick
  game.tick = Free.status().requests[1].expire
  local e0 = stats().expired or 0
  Free.check()
  game.tick = tick0
  check((stats().expired or 0) == e0 + 1 and #marked_near(3200, 3000) == 0 and ghosts_near(3200, 3000) == "" and g3.valid,
    "moteur simulé : demande expirée (" .. Free.TTL .. " ticks) : marques annulées, fantômes retirés, bâtiment intact")

  -- 4. Bâtiment disparu : la demande est retirée.
  local g4 = layout(3300, 3000)
  call("levels_free_room", g4)
  g4.destroy()
  local gone0 = stats().gone or 0
  Free.check()
  check((stats().gone or 0) == gone0 + 1 and #marked_near(3300, 3000) == 0 and ghosts_near(3300, 3000) == "",
    "moteur simulé : bâtiment disparu : demande retirée, marques et fantômes rendus")

  -- 5. Panneau : bouton « Libérer la place » quand la place manque, puis « Annuler l'agrandissement ».
  local player = Wd.player
  local home = player.force
  rawset(player, "force", game.forces[F3])
  local g5 = layout(3400, 3000)
  local function find_el(el, name)
    for _, ch in ipairs(rawget(el, "_list") or {}) do
      if ch.name == name then return ch end
      local f = find_el(ch, name)
      if f then return f end
    end
    return nil
  end
  rawset(player, "selected", g5)
  local ev = Wd.events
  local okp = pcall(M.dispatch, ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
  local fr = player.gui.left["fo_lvl_panel"]
  local btn = fr and find_el(fr, "fo_lvl_free")
  check(okp and btn ~= nil and find_el(fr, "fo_lvl_free_cancel") == nil, "panneau : bouton « Libérer la place » quand la place manque")
  local okc = btn and pcall(M.dispatch, ev[defines.events.on_gui_click], { element = btn, player_index = 1, tick = game.tick })
  fr = player.gui.left["fo_lvl_panel"]
  local cancel_btn = fr and find_el(fr, "fo_lvl_free_cancel")
  check(okc and cancel_btn ~= nil and find_el(fr, "fo_lvl_free") == nil and Free.request_of(g5) ~= nil and #marked_near(3400, 3000) == 3,
    "panneau : clic → demande en attente (ligne d'attente, bouton « Annuler l'agrandissement »)")
  local okx = cancel_btn and pcall(M.dispatch, ev[defines.events.on_gui_click], { element = cancel_btn, player_index = 1, tick = game.tick })
  check(okx and Free.request_of(g5) == nil and #marked_near(3400, 3000) == 0 and ghosts_near(3400, 3000) == "",
    "panneau : « Annuler l'agrandissement » rend tout")
  rawset(player, "selected", nil)
  rawset(player, "force", home)
  for _, lang in ipairs({ "fr", "en" }) do
    local fh = io.open("locale/" .. lang .. "/levels-taille.cfg", "rb")
    local txt = fh and fh:read("*a") or ""
    if fh then fh:close() end
    local miss = {}
    for _, k in ipairs({ "free-button", "free-tooltip", "free-cancel-button", "free-pending", "free-started", "free-signalled",
        "free-wall-open", "free-wired", "free-done", "free-no-resources", "free-cancelled", "free-expired", "free-gone", "free-kept",
        "free-refused-room-free", "free-refused-already", "free-refused-too-many", "free-refused-other" }) do
      if not txt:find("\n" .. k .. "=", 1, true) then miss[#miss + 1] = k end
    end
    check(#miss == 0, lang .. " : clés du lot V3-T3 (libérer la place)", table.concat(miss, ", "))
  end
end

return Cases
