--[[
  Lot INDUSTRIE I5 « patrons » : la famille de gabarits qui fabrique n'importe quel objet selon le nombre de ses entrées
  (shared/team/patrons.lua), contre le contrôle du lot IA1-c (M.analyze, M.check) et le gabarit ordinaire (regenerate, extend,
  rotate, at_level). Hors jeu, Lua pur : lua5.2 tests/patrons_test.lua

    §1 topologie (s → tapis, bras, côté de la sortie), voies, cadence des bras, colonnes de bras, déclaration d'un mod ;
    §2 la CELLULE sur une machine écrite pour le test : 1 à 8 entrées × 3 sorties, dimensions et recensement des entités
       attendus (écrits ici à la main, d'après le plan), débits nominaux exacts, ports, barre, machine d'unité au bord ;
    §3 cadence réduite quand les bras du kit ne tiennent pas la machine ; rangées de n machines, borne d'extension EXACTE ;
    §4 fluides en entrée : machine tournée (F91 : recette et direction ensemble), tuyaux au bord, refus écrits ;
    §5 refus : chacun avec sa raison « limite : … » ;
    §6 services du gabarit : regenerate identique, extend, rotation, niveaux du mod (at_level) ;
    §7 le BLOC de mall : voies communes, dimensions du plan (11 × 14), refus, regroupement P.groups, copies, assemblage ;
    §8 balayage : TOUTES les recettes solides de tests/fixtures/recipes.lua × machines de côté 3, 5, 7 et 11 × 3 sorties × 2
       poteaux : le contrôle est vide pour chacune ;
    §9 NOMS PERMUTÉS (peu importe le mod) : recettes, objets, catégorie, machine et kit remplacés par un hachage → mêmes formes ;
    §10 MUTANTS : chaque règle de shared/team/patrons.lua cassée (une substitution du source) est vue par la batterie.
]]

package.path = "./?.lua;" .. package.path

local M = require("shared.team.modules")
local L = require("shared.levels.config")
local P = require("shared.team.patrons")
local RECIPES = require("tests.fixtures.recipes")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then
    pass = pass + 1
  else
    fail = fail + 1
    print("ECHEC : " .. label)
  end
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-9) end

local KIT = { bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", coffre = "wooden-chest", tuyau = "pipe" }
local KIT_SMALL = { bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", coffre = "wooden-chest",
  tuyau = "pipe", poteau = "small-electric-pole" }

--- Recette au format du relevé. ins/outs : { {nom, quantité} } ; un nom précédé de « ~ » est un fluide.
local function rec(name, cat, time, ins, outs)
  local function conv(list)
    local out = {}
    for i, v in ipairs(list) do
      local n, fluid = v[1], false
      if n:sub(1, 1) == "~" then n, fluid = n:sub(2), true end
      out[i] = { type = fluid and "fluid" or "item", name = n, amount = v[2] or 1 }
    end
    return out
  end
  return { name = name, category = cat, energy = time, ingredients = conv(ins), products = conv(outs) }
end

local function count_by(g)
  local c = { belt = 0, arm = 0, long = 0, chest = 0, pole = 0, machine = 0, pipe = 0 }
  for _, e in ipairs(g.entities) do
    local sp = M.spec(e.name)
    if sp.kind == "belt" then c.belt = c.belt + 1
    elseif sp.kind == "inserter" then if sp.reach == 2 then c.long = c.long + 1 else c.arm = c.arm + 1 end
    elseif sp.kind == "chest" then c.chest = c.chest + 1
    elseif sp.kind == "pole" then c.pole = c.pole + 1
    elseif sp.kind == "pipe" then c.pipe = c.pipe + 1
    else c.machine = c.machine + 1 end
  end
  return c
end

local function port_count(g, kind, io)
  local n = 0
  for _, p in ipairs(g.ports) do if p.kind == kind and (io == nil or p.io == io) then n = n + 1 end end
  return n
end

local RUN = 0

---------------------------------------------------------------------------------------------------
-- La batterie : tout ce qui précède, contre une version `Pm` de la règle. Rend (écarts, contrôles).
---------------------------------------------------------------------------------------------------
local function battery(Pm, verbose, tag)
  RUN = RUN + 1
  local id = tostring(RUN)
  local bad, total = 0, 0
  local function chk(cond, label)
    total = total + 1
    if not cond then
      bad = bad + 1
      if verbose then print("ECHEC : " .. label) end
    end
  end
  local function nm(x) return x .. "-" .. id end

  -------------------------------------------------------------------------------------------------
  -- §1 topologie, voies, bras, colonnes, déclaration
  -------------------------------------------------------------------------------------------------
  -- s → { tapis, nord, sud, côté }
  local TOPO = { [0] = { 0, 0, 0, "sud" }, { 1, 1, 0, "sud" }, { 1, 1, 0, "sud" }, { 2, 2, 0, "sud" }, { 2, 2, 0, "sud" },
    { 3, 2, 1, "est" }, { 3, 2, 1, "est" }, { 4, 2, 2, "est" }, { 4, 2, 2, "est" } }
  for s = 0, 8 do
    local t, why = Pm.topologie(s, "coffre")
    local x = TOPO[s]
    chk(t and t.belts == x[1] and t.nord == x[2] and t.sud == x[3] and t.cote == x[4], "topologie s=" .. s)
    local tu = Pm.topologie(s, "unite")
    chk(tu and tu.cote == "aucun" and tu.belts == x[1], "topologie unité s=" .. s)
  end
  local t9, why9 = Pm.topologie(9, "coffre")
  chk(t9 == nil and why9 and why9:sub(1, 8) == "limite :" and why9:find("9 entrées solides (8 au plus)", 1, true), "topologie : 9 entrées refusées avec le chiffre")
  chk(Pm.topologie(-1, "tapis") == nil and Pm.topologie(2.5, "tapis") == nil and Pm.topologie("x", "tapis") == nil, "topologie : entrée invalide")

  local v = Pm.voies({ { name = "a", demande = 1 }, { name = "b", demande = 3 }, { name = "c", demande = 2 }, { name = "d", demande = 3 }, { name = "e", demande = 1 } })
  chk(#v == 3 and v[1][1].name == "b" and v[1][2].name == "d" and v[2][1].name == "c" and v[2][2].name == "a" and v[3][1].name == "e" and v[3][2] == nil,
    "voies : demande décroissante puis nom, deux objets par tapis")

  chk(near(Pm.arm_rate(0.014), 0.81) and near(Pm.arm_rate(0.02), 1.16) and near(Pm.arm_rate(0.04), 2.32) and Pm.arm_rate(0) == nil and Pm.arm_rate(-1) == nil,
    "cadence d'un bras d'après sa rotation (0,81 / 1,16 / 2,32)")
  local function eqlist(a, b) if #a ~= #b then return false end for i = 1, #a do if a[i] ~= b[i] then return false end end return true end
  chk(eqlist(Pm.colonnes_bras(11, 4), { 0, 1, 2, 4, 5, 6, 8, 9, 10 }), "colonnes de bras : 11 de large, période 4")
  chk(eqlist(Pm.colonnes_bras(5, 4), { 0, 1, 2, 4 }) and eqlist(Pm.colonnes_bras(4, 4), { 0, 1, 2 }), "colonnes de bras : 4 et 5 de large")
  chk(eqlist(Pm.colonnes_bras(3, 4), { 0, 1 }) and eqlist(Pm.colonnes_bras(2, 4), { 0 }), "colonnes de bras : 3 et 2 de large gardent une tuile libre")
  chk(eqlist(Pm.colonnes_bras(7, 3), { 0, 1, 3, 4, 6 }), "colonnes de bras : période 3 (poteau de 2,5)")
  chk(Pm.periode(3.5) == 4 and Pm.periode(2.5) == 3 and Pm.periode(nil) == 4 and Pm.periode(0.5) == 4 and Pm.periode(7) == 8, "période des tuiles libres")

  local MN = nm("tm")
  chk(Pm.declare(M, MN, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "cat-" .. id } }) == true, "déclaration d'une machine")
  chk(M.spec(MN) and M.spec(MN).usage_kw == 100 and M.spec(MN).drain == true and M.epoch_index()[MN] == 1, "déclaration : puissance et époque par défaut")
  Pm.declare(M, MN, { kind = "assembler", w = 9, h = 9, speed = 9, categories = { "autre" } })
  chk(M.spec(MN).w == 3 and M.spec(MN).speed == 1, "déclaration idempotente (un nom connu n'est pas écrasé)")
  local d0, dwhy = Pm.declare(M, "x", { w = 1 })
  chk(d0 == nil and dwhy and dwhy:sub(1, 8) == "limite :", "déclaration sans sorte refusée")
  -- une machine déclarée gagne les catégories d'un second appel (une catégorie par recette lue) ; une machine du modèle, jamais
  local UN = nm("union")
  Pm.declare(M, UN, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "zz-" .. id } })
  Pm.declare(M, UN, { kind = "assembler", w = 9, h = 9, speed = 9, categories = { "aa-" .. id, "zz-" .. id } })
  chk(M.spec(UN).categories and #M.spec(UN).categories == 2 and M.spec(UN).categories[1] == "aa-" .. id and M.spec(UN).categories[2] == "zz-" .. id
    and M.spec(UN).w == 3, "déclaration : catégories réunies et triées, taille inchangée")
  local n_am2 = #M.BASE["assembling-machine-2"].categories
  Pm.declare(M, "assembling-machine-2", { kind = "assembler", categories = { "autre-" .. id } })
  chk(#M.BASE["assembling-machine-2"].categories == n_am2, "déclaration : une machine du modèle garde ses catégories")

  -- définitions d'après le relevé de lecture (lot I4)
  local dm = Pm.def_machine({ entity = "e", type = "assembling-machine", speed = 1.5, w = 4, h = 4, energy = "electric",
    boxes = { { type = "input", conns = { [0] = { { -1, -2.5 } }, [2] = {}, [4] = {}, [6] = {} } },
      { type = "output", conns = { [0] = { { 1, 2.5 } } } }, { type = "input-output", conns = { [0] = { { 0, 2.5 } } } } } }, { "c1" })
  chk(dm.kind == "assembler" and dm.w == 4 and dm.h == 4 and dm.speed == 1.5 and dm.categories[1] == "c1" and dm.burner_kw == nil
    and #dm.boxes == 3 and dm.boxes[1].io == "in" and dm.boxes[2].io == "out" and dm.boxes[3].io == "io"
    and dm.boxes[1].pts[1][1] == -1 and dm.boxes[1].pts[1][2] == -2.5, "définition d'une machine lue : sorte, taille, boîtes")
  local df = Pm.def_machine({ entity = "f", type = "furnace", speed = 2, w = 2, h = 2, energy = "burner", boxes = {} }, { "smelting" })
  chk(df.kind == "assembler" and df.burner_kw == 1 and df.boxes == nil, "définition d'une machine à combustible lue")
  local kit_read = {
    bras = { entity = nm("k-bras"), reach = 1, rot = 0.014, energy = "electric" },
    bras_long = { entity = nm("k-long"), reach = 2, rot = 0.02, energy = "electric" },
    tapis = { entity = nm("k-tapis") }, coffre = { entity = nm("k-coffre"), slots = 32 },
    poteau = { entity = nm("k-pole"), supply = 2.5, wire = 7.5 } }
  local kn, kwhy = Pm.declare_kit(M, kit_read)
  chk(kn and kn.bras == nm("k-bras") and kn.poteau == nm("k-pole") and kn.coffre == nm("k-coffre"), "kit lu déclaré : noms d'entités rendus (" .. tostring(kwhy) .. ")")
  chk(M.spec(nm("k-bras")).rate == 0.81 and M.spec(nm("k-bras")).reach == 1 and M.spec(nm("k-long")).reach == 2 and M.spec(nm("k-long")).rate == 1.16
    and M.spec(nm("k-pole")).supply == 2.5 and M.spec(nm("k-pole")).wire == 7.5 and M.spec(nm("k-coffre")).slots == 32 and M.spec(nm("k-tapis")).kind == "belt",
    "kit lu déclaré : cadence, portée, couverture, cases")
  -- une cellule avec ce kit lu : contrôle vide
  local gk = kn and Pm.cellule(M, MN, rec(nm("kitr"), "cat-" .. id, 50, { { nm("ka") }, { nm("kb") }, { nm("kc") } }, { { nm("kp") } }), "coffre", 1, kn, 0)
  chk(gk and #M.check(gk) == 0 and gk.pole_name == nm("k-pole"), "cellule avec le kit lu d'un mod : contrôle vide, poteau du kit")
  local k_bad = {}
  for k, v in pairs(kit_read) do k_bad[k] = v end
  k_bad.coffre = nil
  local kx, kxwhy = Pm.declare_kit(M, k_bad)
  chk(kx == nil and kxwhy and kxwhy:find("coffre", 1, true), "kit lu sans coffre refusé")
  k_bad.coffre = kit_read.coffre
  k_bad.bras = { entity = nm("k-b2"), reach = 1, energy = "electric" }
  local kx2, kx2why = Pm.declare_kit(M, k_bad)
  chk(kx2 == nil and kx2why and kx2why:find("rotation", 1, true), "bras lu sans vitesse de rotation refusé")

  -------------------------------------------------------------------------------------------------
  -- §2 la cellule : 1 à 8 entrées × 3 sorties, machine de côté 3, recette si lente que les bras ne limitent jamais
  -------------------------------------------------------------------------------------------------
  local function slow(s, out_amount, name)
    local ins = {}
    for i = 1, s do ins[i] = { nm("i" .. i), 1 } end
    return rec(name or nm("slow" .. s), "cat-" .. id, 100, ins, { { nm("o" .. s), out_amount or 1 } })
  end
  for s = 5, 8 do
    local gt, wt = Pm.cellule(M, MN, slow(s, 2, nm("slowt" .. s)), "tapis", 1, KIT, 0)
    chk(gt == nil and wt and wt:find("sortie en coffre ou en unité", 1, true), "cellule s=" .. s .. " tapis : refusée, un tapis croiserait ceux du sud (" .. tostring(wt) .. ")")
  end
  for s = 1, 8 do
    for _, so in ipairs(s >= 5 and { "coffre", "unite" } or { "tapis", "coffre", "unite" }) do
      local r = slow(s, 2, nm("slow" .. s .. so))
      local g, why = Pm.cellule(M, MN, r, so, 1, KIT, 0)
      local lab = "cellule s=" .. s .. " " .. so
      chk(g ~= nil, lab .. " rendue (" .. tostring(why) .. ")")
      if g then
        local errs = M.check(g)
        chk(#errs == 0, lab .. " : contrôle vide (" .. tostring(errs[1]) .. ")")
        -- dimensions du plan : lignes = tapis nord, bras, machine (3), [bras + tapis sud | rangée de sortie] ; colonnes = 3 + est
        local nb = math.ceil(s / 2)
        local nN, nS = math.min(nb, 2), math.max(nb - 2, 0)
        local H = nN + (nN > 0 and 1 or 0) + 3
        if nS > 0 then H = H + 1 + nS elseif so ~= "unite" then H = H + 2 end
        local Wd = 3
        if nS > 0 then Wd = Wd + (so == "unite" and 1 or 2) else Wd = Wd + 1 end
        chk(g.w == Wd and g.h == H, lab .. string.format(" : emprise %dx%d attendue, %dx%d rendue", Wd, H, g.w, g.h))
        local c = count_by(g)
        -- tapis impairs par l'est (toute la largeur), pairs par l'ouest (jusqu'à la dernière colonne de machine : 3)
        local belts_in = 0
        for k = 1, nb do belts_in = belts_in + ((k % 2 == 1) and Wd or 3) end
        local belts_out = (so == "tapis") and Wd or 0
        chk(c.belt == belts_in + belts_out, lab .. ": " .. c.belt .. " tapis pour " .. (belts_in + belts_out))
        local normal, long = 0, 0
        for k = 1, nb do if k % 2 == 1 then normal = normal + 1 else long = long + 1 end end
        chk(c.long == long and c.arm == normal + (so ~= "unite" and 1 or 0), lab .. string.format(" : bras %d normaux et %d longs", c.arm, c.long))
        chk(c.chest == (so == "coffre" and 1 or 0) and c.machine == 1 and c.pole >= 1, lab .. " : coffre, machine et poteau")
        -- débit nominal exact : 2 objets par fabrication, une fabrication par 100 s à vitesse 1
        chk(g.nominal and near(g.nominal[nm("o" .. s)], 2 * 0.01, 1e-12), lab .. " : débit nominal 0,02/s")
        local nin = 0
        for _, k in ipairs(sorted_keys(g.inputs)) do nin = nin + 1; chk(near(g.inputs[k], 0.01, 1e-12), lab .. " : entrée " .. k .. " à 0,01/s") end
        chk(nin == s, lab .. " : " .. nin .. " entrées déclarées pour " .. s)
        -- ports d'entrée : un objet par voie, jamais deux ; tapis impair : le dernier sur ses deux voies
        local seen, tin = {}, 0
        for _, p in ipairs(g.ports) do
          if p.kind == "tapis" and p.io == "in" then
            tin = tin + 1
            for l = 1, 2 do seen[p.lanes[l]] = (seen[p.lanes[l]] or 0) + 1 end
          end
        end
        chk(tin == nb, lab .. " : " .. tin .. " ports d'entrée pour " .. nb .. " tapis")
        local distinct = 0
        for _ in pairs(seen) do distinct = distinct + 1 end
        chk(distinct == s, lab .. " : chaque entrée sur une voie")
        -- sorties
        if so == "tapis" then chk(port_count(g, "tapis", "out") == 1 and port_count(g, "quai") == 0, lab .. " : un port de sortie en tapis") end
        if so == "coffre" then chk(port_count(g, "quai", "out") == 1 and port_count(g, "tapis", "out") == 0, lab .. " : un quai de sortie") end
        if so == "unite" then
          local q
          for _, p in ipairs(g.ports) do if p.kind == "quai" then q = p end end
          chk(q and q.unite == true and q.item == nm("o" .. s) and M.spec(g.entities[q.ent].name).kind == "assembler", lab .. " : la machine est le quai")
          chk(c.arm == normal and c.chest == 0, lab .. " : ni bras ni coffre de sortie")
        end
        -- recette et direction ensemble sur l'entité de la machine (F91)
        local me
        for _, e in ipairs(g.entities) do if M.spec(e.name).kind == "assembler" then me = e end end
        chk(me and me.recipe == r.name and me.dir == 0, lab .. " : recette et direction sur la machine")
      end
    end
  end

  -- barre du coffre
  do
    local g = Pm.cellule(M, MN, slow(2, 1, nm("bar")), "coffre", 1, KIT, 3)
    local q
    for _, p in ipairs(g and g.ports or {}) do if p.kind == "quai" then q = p end end
    chk(q and q.bar == 3, "barre : le quai porte la barre demandée")
    local g0 = Pm.cellule(M, MN, slow(2, 1, nm("bar0")), "coffre", 1, KIT, 0)
    local q0
    for _, p in ipairs(g0 and g0.ports or {}) do if p.kind == "quai" then q0 = p end end
    chk(q0 and q0.bar == nil, "barre : aucune barre sans demande")
  end

  -- plusieurs produits : coffre, un port par produit net ; un produit rendu en entier n'est pas net
  do
    local r2 = rec(nm("deux"), "cat-" .. id, 100, { { nm("a") }, { nm("b") } }, { { nm("p"), 1 }, { nm("q"), 2 } })
    local g = Pm.cellule(M, MN, r2, "coffre", 1, KIT, 0)
    chk(g and #M.check(g) == 0 and port_count(g, "quai", "out") == 2, "deux produits : coffre, deux ports")
    local rc = rec(nm("cycle"), "cat-" .. id, 100, { { nm("u"), 40 }, { nm("v"), 5 } }, { { nm("u"), 41 }, { nm("v"), 2 } })
    local gc = Pm.cellule(M, MN, rc, "coffre", 1, KIT, 0)
    local items = {}
    for _, p in ipairs(gc and gc.ports or {}) do if p.kind == "quai" then items[#items + 1] = p.item end end
    chk(gc and #M.check(gc) == 0 and #items == 1 and items[1] == nm("u"), "recette cyclique : seul le surplus a un port (" .. table.concat(items, ",") .. ")")
    local rz = rec(nm("zero"), "cat-" .. id, 100, { { nm("zx"), 2 }, { nm("zk"), 1 } }, { { nm("zx"), 2 }, { nm("zy"), 1 } })
    local gz = Pm.cellule(M, MN, rz, "coffre", 1, KIT, 0)
    local zitems = {}
    for _, p in ipairs(gz and gz.ports or {}) do if p.kind == "quai" then zitems[#zitems + 1] = p.item end end
    chk(gz and #M.check(gz) == 0 and #zitems == 1 and zitems[1] == nm("zy"), "produit net nul : pas de port (" .. table.concat(zitems, ",") .. ")")
    local rn = rec(nm("rien"), "cat-" .. id, 100, { { nm("w"), 2 } }, { { nm("w"), 1 } })
    local gn, wn = Pm.cellule(M, MN, rn, "coffre", 1, KIT, 0)
    chk(gn == nil and wn and wn:find("net", 1, true), "aucun produit net : refusé")
  end

  -------------------------------------------------------------------------------------------------
  -- §3 cadence réduite, rangées de n machines, borne d'extension
  -------------------------------------------------------------------------------------------------
  do
    local FM = nm("fast")
    Pm.declare(M, FM, { kind = "assembler", w = 3, h = 3, speed = 20, categories = { "cat-" .. id } })
    local r = rec(nm("vite"), "cat-" .. id, 1, { { nm("x"), 1 } }, { { nm("y"), 1 } })
    local g, why = Pm.cellule(M, FM, r, "tapis", 1, KIT, 0)
    chk(g and #M.check(g) == 0, "machine rapide : contrôle vide (" .. tostring(why) .. ")")
    -- 2 bras normaux (3 colonnes dont une libre) depuis un tapis : 2 × 0,83 × 0,85 × 0,9 = 1,2699 objets/s
    chk(g and near(g.nominal[nm("y")], 2 * 0.83 * 0.85 * 0.9, 1e-9), "machine rapide : cadence réduite à ce que les bras tiennent (" .. tostring(g and g.nominal[nm("y")]) .. ")")
    local me
    for _, e in ipairs(g and g.entities or {}) do if M.spec(e.name).kind == "assembler" then me = e end end
    chk(me and me.rate < 20 and near(me.rate, 2 * 0.83 * 0.85 * 0.9, 1e-9), "machine rapide : la cadence prévue est l'écrite")
    -- bras rapides : la voie d'entrée devient la limite, la borne d'extension est exacte
    local KF = { bras = "fast-inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", coffre = "wooden-chest", tuyau = "pipe" }
    local MN2 = nm("m1")
    Pm.declare(M, MN2, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "cat-" .. id } })
    local r2 = rec(nm("lourde"), "cat-" .. id, 0.5, { { nm("z"), 2 } }, { { nm("t"), 1 } })
    local g1 = Pm.cellule(M, MN2, r2, "tapis", 1, KF, 0)
    local top = g1 and g1.extensions[1] and g1.extensions[1].max
    chk(top == 4, "extension : le plus grand n est 4 (voie d'entrée et voie de sortie) : " .. tostring(top))
    for n = 1, (top or 0) do
      local gn = Pm.cellule(M, MN2, r2, "tapis", n, KF, 0)
      chk(gn and #M.check(gn) == 0, "extension : n=" .. n .. " passe le contrôle (" .. tostring(gn and M.check(gn)[1]) .. ")")
    end
    local r3 = rec(nm("sortie2"), "cat-" .. id, 0.5, { { nm("zz"), 1 } }, { { nm("tt"), 2 } })
    local g3 = Pm.cellule(M, MN2, r3, "tapis", 1, KF, 0)
    chk(g3 and #M.check(g3) == 0 and g3.extensions[1].max == 1, "extension : la voie de sortie seule borne à 1 (" .. tostring(g3 and g3.extensions[1].max) .. ")")
    local g3b = Pm.cellule(M, MN2, r3, "tapis", 2, KF, 0)
    chk(g3b == nil or #M.check(g3b) > 0, "extension : n=2 invalide quand la voie de sortie déborde")
    local gx = Pm.cellule(M, MN2, r2, "tapis", (top or 0) + 1, KF, 0)
    chk(gx == nil or #M.check(gx) > 0, "extension : n=" .. ((top or 0) + 1) .. " est refusé ou invalide")
    -- largeur du lot : machines de 3, 5 colonnes au plus
    local gw = Pm.cellule(M, MN, slow(1, 1, nm("larg")), "tapis", 5, KIT, 0)
    chk(gw and #M.check(gw) == 0 and gw.w == 19 and gw.extensions[1].max == 5, "largeur : 5 machines de 3 dans 19 colonnes, borne 5 (tête à l'est : 3 + 1)")
    local gw6, why6 = Pm.cellule(M, MN, slow(1, 1, nm("larg6")), "tapis", 6, KIT, 0)
    chk(gw6 == nil and why6 and why6:find("emprise 23 × 7, avec les têtes d'alimentation 27 × 10, au-delà du lot de 24 × 24", 1, true),
      "largeur : 6 machines refusées (23 colonnes, têtes comprises 27) avec les chiffres (" .. tostring(why6) .. ")")
    -- deux tapis : une tête de chaque côté, 4 machines au plus
    local gw2 = Pm.cellule(M, MN, slow(3, 1, nm("larg3")), "tapis", 4, KIT, 0)
    chk(gw2 and #M.check(gw2) == 0 and gw2.extensions[1].max == 4, "largeur : 3 entrées, 4 machines au plus (têtes des deux côtés)")
    local gw2b, why2b = Pm.cellule(M, MN, slow(3, 1, nm("larg3b")), "tapis", 5, KIT, 0)
    chk(gw2b == nil and why2b and why2b:find("au-delà du lot de 24 × 24", 1, true), "largeur : 5 machines à 3 entrées refusées")
    for n = 2, 5 do
      local gn = Pm.cellule(M, MN, slow(2, 1, nm("rg" .. n)), "coffre", n, KIT, 0)
      chk(gn and #M.check(gn) == 0 and port_count(gn, "quai", "out") == n and count_by(gn).machine == n, "rangée de " .. n .. " : un coffre par machine")
    end
  end

  -------------------------------------------------------------------------------------------------
  -- §4 fluides en entrée
  -------------------------------------------------------------------------------------------------
  do
    local CM = nm("chim")
    Pm.declare(M, CM, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "chem-" .. id },
      boxes = { { io = "in", pts = { { -1, -2 } } }, { io = "in", pts = { { 1, -2 } } }, { io = "out", pts = { { -1, 2 } } }, { io = "out", pts = { { 1, 2 } } } } })
    local r1 = rec(nm("plas"), "chem-" .. id, 1, { { "~" .. nm("gaz"), 20 }, { nm("charb"), 1 } }, { { nm("barre"), 2 } })
    for _, so in ipairs({ "tapis", "coffre", "unite" }) do
      local g, why = Pm.cellule(M, CM, r1, so, 1, KIT, 0)
      chk(g ~= nil, "fluide 1 solide " .. so .. " rendue (" .. tostring(why) .. ")")
      if g then
        chk(#M.check(g) == 0, "fluide " .. so .. " : contrôle vide (" .. tostring(M.check(g)[1]) .. ")")
        local me
        for _, e in ipairs(g.entities) do if M.spec(e.name).kind == "assembler" then me = e end end
        chk(me and me.dir == 6 and me.recipe == r1.name, "fluide " .. so .. " : machine tournée vers l'ouest avec sa recette (F91)")
        chk(me and near(me.x, 1 + 1.5), "fluide " .. so .. " : machine décalée d'une colonne pour le tuyau")
        local tp
        for _, p in ipairs(g.ports) do if p.kind == "tuyau" then tp = p end end
        chk(port_count(g, "tuyau", "in") == 1 and tp and tp.fluid == nm("gaz") and g.entities[tp.ent].x == 0.5, "fluide " .. so .. " : tuyau au bord ouest, port de " .. nm("gaz"))
        chk(count_by(g).pipe == 1, "fluide " .. so .. " : un tuyau")
        chk(g.inputs[nm("gaz")] and near(g.inputs[nm("gaz")], 20 * g.nominal[nm("barre")] / 2, 1e-9) and g.extensions[1].max == 1, "fluide " .. so .. " : entrée de fluide au débit de la recette, une machine seule")
      end
    end
    -- deux fluides, aucun solide : deux tuyaux, ports dans l'ordre de la recette
    local r2 = rec(nm("souf"), "chem-" .. id, 1, { { "~" .. nm("eau"), 30 }, { "~" .. nm("gaz2"), 30 } }, { { nm("sou"), 2 } })
    local g2, why2 = Pm.cellule(M, CM, r2, "coffre", 1, KIT, 0)
    chk(g2 ~= nil and #M.check(g2) == 0, "deux fluides, aucun solide : contrôle vide (" .. tostring(why2) .. ")")
    if g2 then
      local fl = {}
      for _, p in ipairs(g2.ports) do if p.kind == "tuyau" then fl[#fl + 1] = p.fluid end end
      chk(#fl == 2 and fl[1] == nm("eau") and fl[2] == nm("gaz2"), "deux fluides : ports dans l'ordre de la recette")
      chk(port_count(g2, "tapis") == 0, "aucun solide : aucun tapis d'entrée")
    end
    -- refus
    local gn, wn = Pm.cellule(M, CM, r1, "coffre", 2, KIT, 0)
    chk(gn == nil and wn and wn:find("une machine seule", 1, true), "fluides : une rangée de 2 est refusée")
    local kit2 = {}
    for k, v in pairs(KIT) do if k ~= "tuyau" then kit2[k] = v end end
    local gk, wk = Pm.cellule(M, CM, r1, "coffre", 1, kit2, 0)
    chk(gk == nil and wk and wk:find("tuyau", 1, true), "fluides : kit sans tuyau refusé")
    local rout = rec(nm("sortf"), "chem-" .. id, 1, { { nm("a1") } }, { { "~" .. nm("fl"), 5 }, { nm("o9"), 1 } })
    local go, wo = Pm.cellule(M, CM, rout, "coffre", 1, KIT, 0)
    chk(go == nil and wo and wo:find("sortie en fluide", 1, true), "fluide en sortie refusé")
    local r3 = rec(nm("trois"), "chem-" .. id, 1, { { "~" .. nm("f1") }, { "~" .. nm("f2") }, { "~" .. nm("f3") } }, { { nm("o3f") } })
    local g3, w3 = Pm.cellule(M, CM, r3, "coffre", 1, KIT, 0)
    chk(g3 == nil and w3 and w3:find("boîte(s) d'entrée", 1, true), "trois fluides pour deux boîtes : refusé")
    -- machine dont les raccords ne regardent pas un même côté / sont voisins
    local BM = nm("cote")
    Pm.declare(M, BM, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "chem-" .. id },
      boxes = { { io = "in", pts = { { -1, -2 } } }, { io = "in", pts = { { 1, 2 } } } } })
    local gb, wb = Pm.cellule(M, BM, rec(nm("opp"), "chem-" .. id, 1, { { "~" .. nm("f1") }, { "~" .. nm("f2") } }, { { nm("o5f") } }), "coffre", 1, KIT, 0)
    chk(gb == nil and wb and wb:find("même côté", 1, true), "raccords sur deux côtés : refusé")
    local NM = nm("voisin")
    Pm.declare(M, NM, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "chem-" .. id },
      boxes = { { io = "in", pts = { { 0, -2 } } }, { io = "in", pts = { { 1, -2 } } } } })
    local gv, wv = Pm.cellule(M, NM, rec(nm("voi"), "chem-" .. id, 1, { { "~" .. nm("f1") }, { "~" .. nm("f2") } }, { { nm("o6f") } }), "coffre", 1, KIT, 0)
    chk(gv == nil and wv and wv:find("non voisins", 1, true), "raccords voisins : refusé")
    -- raccords à l'est avec 5 entrées solides : la colonne de sortie est prise
    local EM = nm("est")
    Pm.declare(M, EM, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "chem-" .. id }, boxes = { { io = "in", pts = { { 1, 2 } } } } })
    -- entrée au sud (1, 2) : machine tournée vers l'est (E : (x, y) → (−y, x) = (−2, 1) : ouest !) ; E donne l'ouest ici, donc W
    local ge = Pm.cellule(M, EM, rec(nm("sud"), "chem-" .. id, 1, { { "~" .. nm("f1") }, { nm("e1") } }, { { nm("o7f") } }), "coffre", 1, KIT, 0)
    local me
    for _, e in ipairs(ge and ge.entities or {}) do if M.spec(e.name).kind == "assembler" then me = e end end
    chk(ge and #M.check(ge) == 0 and me and me.dir == 2, "entrée au sud : machine tournée vers l'est pour regarder l'ouest")
    local NE = nm("estp")
    Pm.declare(M, NE, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "chem-" .. id }, boxes = { { io = "in", pts = { { -1, 2 } } } } })
    -- (−1, 2) tourné W : (y, −x) = (2, 1) → à l'est ; tourné E : (−y, x) = (−2, −1) → à l'ouest ; W est essayé d'abord mais ne convient pas
    local gE = Pm.cellule(M, NE, rec(nm("sudE"), "chem-" .. id, 1, { { "~" .. nm("f1") }, { nm("e2") } }, { { nm("o8f") } }), "coffre", 1, KIT, 0)
    local mE
    for _, e in ipairs(gE and gE.entities or {}) do if M.spec(e.name).kind == "assembler" then mE = e end end
    chk(gE and #M.check(gE) == 0 and mE and mE.dir == 2, "autre entrée : tournée vers l'est (essai de l'ouest d'abord)")
  end

  -------------------------------------------------------------------------------------------------
  -- §5 refus, chacun avec sa raison
  -------------------------------------------------------------------------------------------------
  do
    local r = slow(2, 1, nm("ref"))
    local function refused(label, g, why, needle)
      chk(g == nil and why and why:sub(1, 8) == "limite :" and (needle == nil or why:find(needle, 1, true)), "refus : " .. label .. " (" .. tostring(why) .. ")")
    end
    refused("sortie inconnue", Pm.cellule(M, MN, r, "robot", 1, KIT, 0)) 
    refused("n = 0", Pm.cellule(M, MN, r, "tapis", 0, KIT, 0))
    refused("n = 65", Pm.cellule(M, MN, r, "tapis", 65, KIT, 0))
    refused("n fractionnaire", Pm.cellule(M, MN, r, "tapis", 1.5, KIT, 0))
    refused("barre négative", Pm.cellule(M, MN, r, "coffre", 1, KIT, -1))
    local g_, w_ = Pm.cellule(M, "machine-inconnue", r, "tapis", 1, KIT, 0)
    refused("machine inconnue (texte)", g_, w_, "machine-inconnue")
    local g2, w2 = Pm.cellule(M, MN, rec(nm("autrecat"), "ailleurs", 1, { { nm("a") } }, { { nm("b") } }), "tapis", 1, KIT, 0)
    refused("catégorie étrangère", g2, w2, "ailleurs")
    local g3, w3 = Pm.cellule(M, MN, slow(8, 1, nm("n8")), "coffre", 1, KIT, 0)
    chk(g3 ~= nil, "8 entrées : rendue")
    local many = {}
    for i = 1, 9 do many[i] = { nm("m" .. i), 1 } end
    local g4, w4 = Pm.cellule(M, MN, rec(nm("n9"), "cat-" .. id, 1, many, { { nm("o") } }), "tapis", 1, KIT, 0)
    refused("9 entrées", g4, w4, "9 entrées solides (8 au plus)")
    local g5, w5 = Pm.cellule(M, MN, rec(nm("noin"), "cat-" .. id, 1, {}, { { nm("o") } }), "tapis", 1, KIT, 0)
    refused("aucune entrée", g5, w5, "aucune entrée")
    local g6, w6 = Pm.cellule(M, MN, rec(nm("noout"), "cat-" .. id, 1, { { nm("a") } }, { { "~" .. nm("f") } }), "tapis", 1, KIT, 0)
    refused("seulement un fluide en sortie", g6, w6, "sortie en fluide")
    local g7, w7 = Pm.cellule(M, MN, rec(nm("multi"), "cat-" .. id, 1, { { nm("a") } }, { { nm("b1") }, { nm("b2") } }), "tapis", 1, KIT, 0)
    refused("deux produits en tapis", g7, w7, "coffre seulement")
    local g8, w8 = Pm.cellule(M, MN, slow(5, 1, nm("deux5")), "coffre", 2, KIT, 0)
    refused("5 entrées en rangée de 2", g8, w8, "une machine seule")
    local g9, w9 = Pm.cellule(M, MN, rec(nm("sansnom"), "cat-" .. id, 0, { { nm("a") } }, { { nm("b") } }), "tapis", 1, KIT, 0)
    refused("durée nulle", g9, w9, "durée")
    local g10, w10 = Pm.cellule(M, MN, { ingredients = {} }, "tapis", 1, KIT, 0)
    refused("recette sans nom", g10, w10, "sans nom")
    -- kit
    local k1 = {}
    for k, v in pairs(KIT) do k1[k] = v end
    k1.bras_long = "inserter"
    local gk1, wk1 = Pm.cellule(M, MN, r, "tapis", 1, k1, 0)
    refused("bras long de portée 1", gk1, wk1, "portée")
    local k2 = {}
    for k, v in pairs(KIT) do k2[k] = v end
    k2.coffre = "transport-belt"
    local gk2, wk2 = Pm.cellule(M, MN, r, "tapis", 1, k2, 0)
    refused("coffre qui n'en est pas un", gk2, wk2, "chest")
    local gk3, wk3 = Pm.cellule(M, MN, r, "tapis", 1, nil, 0)
    refused("kit absent", gk3, wk3, "kit absent")
    local k4 = {}
    for k, v in pairs(KIT) do k4[k] = v end
    k4.tapis = "pièce-inconnue"
    local gk4, wk4 = Pm.cellule(M, MN, r, "tapis", 1, k4, 0)
    refused("pièce de kit inconnue", gk4, wk4, "pièce-inconnue")
    Pm.declare(M, nm("sansrate"), { kind = "inserter", reach = 1 })
    local k5 = {}
    for k, v in pairs(KIT) do k5[k] = v end
    k5.bras = nm("sansrate")
    local gk5, wk5 = Pm.cellule(M, MN, r, "tapis", 1, k5, 0)
    refused("bras sans cadence", gk5, wk5, "aucune cadence")
    local k6 = {}
    for k, v in pairs(KIT) do k6[k] = v end
    k6.tuyau = "steel-chest"
    local rf = rec(nm("avecfluide"), "cat-" .. id, 1, { { "~" .. nm("f1") }, { nm("a") } }, { { nm("o") } })
    local gk6, wk6 = Pm.cellule(M, MN, rf, "tapis", 1, k6, 0)
    chk(gk6 == nil and wk6 ~= nil, "refus : tuyau de la mauvaise forme ou machine sans boîtes (" .. tostring(wk6) .. ")")
    Pm.declare(M, nm("tuyau2"), { kind = "pipe", w = 2, h = 1 })
    local CM2 = nm("chim2")
    Pm.declare(M, CM2, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "cat-" .. id }, boxes = { { io = "in", pts = { { -1, -2 } } } } })
    local k7 = {}
    for k, v in pairs(KIT) do k7[k] = v end
    k7.tuyau = nm("tuyau2")
    local gk7, wk7 = Pm.cellule(M, CM2, rf, "tapis", 1, k7, 0)
    refused("tuyau de deux tuiles", gk7, wk7, "n'a pas une tuile")
    -- machine à combustible
    local BN = nm("brule")
    Pm.declare(M, BN, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "cat-" .. id }, burner_kw = 90 })
    local gb, wb = Pm.cellule(M, BN, r, "tapis", 1, KIT, 0)
    refused("machine à combustible", gb, wb, "combustible")
    -- machine trop grande pour le lot : 19 de côté et 8 entrées
    local BIG = nm("big")
    Pm.declare(M, BIG, { kind = "assembler", w = 19, h = 19, speed = 1, categories = { "cat-" .. id } })
    local gB, wB = Pm.cellule(M, BIG, slow(8, 1, nm("big8")), "coffre", 1, KIT, 0)
    refused("emprise au-delà du lot", gB, wB, "au-delà du lot de 24 × 24")
    -- machine de 2 de large : deux groupes de bras ne tiennent pas dans une rangée qui garde une tuile libre
    local SM = nm("deux")
    Pm.declare(M, SM, { kind = "assembler", w = 2, h = 2, speed = 1, categories = { "cat-" .. id } })
    local gS, wS = Pm.cellule(M, SM, slow(3, 1, nm("s3")), "coffre", 1, KIT, 0)
    refused("machine de 2 colonnes, 2 groupes de bras", gS, wS, "aucun bras")
  end

  -------------------------------------------------------------------------------------------------
  -- §6 services du gabarit
  -------------------------------------------------------------------------------------------------
  do
    local r = rec(nm("serv"), "crafting", 6, { { nm("p1"), 2 }, { nm("p2"), 2 }, { nm("p3"), 4 } }, { { nm("pr"), 1 } })
    local LV = L.name(L.by_key["assembler"], 7)
    local g, why = Pm.cellule(M, "assembling-machine-2", r, "coffre", 2, KIT, 3)
    chk(g and #M.check(g) == 0, "services : gabarit de base (" .. tostring(why) .. ")")
    if g then
      chk(g.gen == "patron" and #g.args == 6 and g.args[1] == "assembling-machine-2" and g.args[3] == "coffre" and g.args[4] == 2 and g.args[6] == 3 and g.level_arg == 1,
        "services : gen, args complets et level_arg")
      local g2 = M.regenerate(g)
      chk(g2 and M.serialize(g) == M.serialize(g2), "services : regenerate redonne le même gabarit, octet pour octet")
      local ex = g.extensions[1]
      chk(ex and ex.param == "n" and ex.arg == 4 and ex.max >= 2, "services : extension sur n")
      local g3 = M.extend(g, 3)
      chk(g3 and #M.check(g3) == 0 and count_by(g3).machine == 3, "services : extend à 3")
      local gx = M.extend(g, ex.max + 1)
      chk(gx == nil, "services : extend au-delà de la borne refusé")
      for k = 1, 3 do
        local rt = M.rotate(g, k)
        chk(rt and #M.check(rt) == 0, "services : rotation " .. k .. " : contrôle vide")
      end
      local gl, whyl = Pm.cellule(M, LV, r, "coffre", 1, KIT, 0)
      chk(gl and #M.check(gl) == 0, "services : machine du niveau 7 (" .. tostring(whyl) .. ")")
      if gl then
        chk(#M.leveled(gl) == 1, "services : un bâtiment à niveaux reconnu")
        for _, lvl in ipairs({ 1, 6, 7, 13, 19, 30 }) do
          local v2, w2 = M.at_level(gl, lvl)
          chk(v2 and #M.check(v2) == 0, "services : at_level " .. lvl .. " (" .. tostring(w2) .. ")")
          if v2 then
            local side = L.footprint(L.by_key["assembler"], lvl)
            local me
            for _, e in ipairs(v2.entities) do if M.spec(e.name).kind == "assembler" then me = e end end
            chk(me and M.spec(me.name).w == side, "services : at_level " .. lvl .. " : machine de côté " .. side)
          end
        end
        local up = M.upgrade_plan(gl, 8)
        chk(up.mode == "sur-place", "services : amélioration sur place du niveau 7 au niveau 8 (" .. tostring(up.mode) .. " " .. tostring(up.reason) .. ")")
      end
    end
  end

  -------------------------------------------------------------------------------------------------
  -- §7 le bloc de mall, le regroupement, les copies
  -------------------------------------------------------------------------------------------------
  do
    local cat = "cat-" .. id
    local function brec(name, ins, amount) 
      local list = {}
      for i, v in ipairs(ins) do list[i] = { nm(v), 1 } end
      return rec(nm(name), cat, 20, list, { { nm(name .. "-o"), amount or 1 } })
    end
    -- 5 objets, 4 voies (a b c d) ; aucun objet fait ici n'est consommé ici
    local recs = { brec("r1", { "a", "b", "c" }), brec("r2", { "a", "d" }), brec("r3", { "b" }), brec("r4", { "c", "d" }), brec("r5", { "a" }) }
    local g, why = Pm.bloc(M, MN, recs, KIT, 4)
    chk(g ~= nil, "bloc rendu (" .. tostring(why) .. ")")
    if g then
      local errs = M.check(g)
      chk(#errs == 0, "bloc : contrôle vide (" .. tostring(errs[1]) .. ")")
      -- 5 machines : 3 au nord, 2 au sud ; largeur 3 × 3 + 2 = 11 ; hauteur 2 + 3 + 4 + 3 + 2 = 14
      chk(g.w == 11 and g.h == 14, "bloc : emprise 11 × 14 (" .. g.w .. " × " .. g.h .. ")")
      local c = count_by(g)
      chk(c.machine == 5 and c.chest == 5 and c.belt == 22, "bloc : 5 machines, 5 coffres, 2 tapis de 11 (" .. c.machine .. ", " .. c.chest .. ", " .. c.belt .. ")")
      chk(port_count(g, "tapis", "in") == 2 and port_count(g, "quai", "out") == 5, "bloc : 2 ports d'entrée, 5 quais de sortie")
      local seen = {}
      for _, p in ipairs(g.ports) do
        if p.kind == "tapis" then for l = 1, 2 do seen[p.lanes[l]] = true end end
        if p.kind == "quai" then chk(p.bar == 4, "bloc : barre de 4 sur chaque quai") end
      end
      chk(#sorted_keys(seen) == 4, "bloc : 4 voies, 4 objets")
      -- débit : somme des fabrications (une par 20 s à vitesse 1, 1 par fabrication)
      for _, r in ipairs(recs) do chk(near(g.nominal[r.products[1].name], 0.05, 1e-12), "bloc : débit de " .. r.products[1].name) end
      chk(g.gen == "bloc" and #g.args == 4 and g.level_arg == 1, "bloc : gen et args")
      local g2 = M.regenerate(g)
      chk(g2 and M.serialize(g) == M.serialize(g2), "bloc : regenerate identique")
      -- l'ordre des recettes données ne change rien
      local rev = {}
      for i = #recs, 1, -1 do rev[#rev + 1] = recs[i] end
      local gr = Pm.bloc(M, MN, rev, KIT, 4)
      chk(gr and M.serialize(gr.entities) == M.serialize(g.entities), "bloc : l'ordre des recettes données ne change rien")
      for k = 1, 3 do local rt = M.rotate(g, k); chk(rt and #M.check(rt) == 0, "bloc : rotation " .. k) end
    end
    -- un seul tapis (2 voies) et une seule machine
    local g1, w1 = Pm.bloc(M, MN, { brec("u1", { "a", "b" }) }, KIT, 0)
    chk(g1 and #M.check(g1) == 0 and g1.h == 2 + 3 + 1 + 1 and port_count(g1, "tapis", "in") == 1, "bloc d'une machine : contrôle vide, un tapis (" .. tostring(w1) .. ")")
    -- le plan comptait 10 machines de 3 dans le lot ; les têtes d'alimentation (3 tuiles de chaque côté) n'en laissent que 8
    local ten = {}
    local names = { "a", "b", "c", "d" }
    for i = 1, 8 do ten[i] = brec("t" .. i, { names[(i - 1) % 4 + 1] }) end
    local gt, wt = Pm.bloc(M, MN, ten, KIT, 0)
    chk(gt and #M.check(gt) == 0 and gt.w == 15 and gt.h == 14, "bloc de 8 : contrôle vide, 15 × 14 (" .. tostring(wt) .. ")")
    chk(Pm.bloc_max(M, MN) == 8 and Pm.colonnes(3) == 4 and Pm.colonnes(5) == 3 and Pm.colonnes(11) == 1, "bloc : 8 machines de 3, 6 de 5, 2 de 11")
    local eleven = {}
    for i = 1, 9 do eleven[i] = brec("e" .. i, { names[(i - 1) % 4 + 1] }) end
    local ge, we = Pm.bloc(M, MN, eleven, KIT, 0)
    chk(ge == nil and we and we:find("9 recettes, 8 machines au plus", 1, true), "bloc : 9 recettes refusées avec les chiffres")
    -- refus
    local g5, w5 = Pm.bloc(M, MN, { brec("v1", { "a", "b", "c" }), brec("v2", { "d", "e" }) }, KIT, 0)
    chk(g5 == nil and w5 and w5:find("5 entrées distinctes pour le bloc (4 voies)", 1, true), "bloc : 5 entrées distinctes refusées")
    local gc, wc = Pm.bloc(M, MN, { rec(nm("w1"), cat, 20, { { nm("pa") } }, { { nm("pb") } }), rec(nm("w2"), cat, 20, { { nm("pb") } }, { { nm("pc") } }) }, KIT, 0)
    chk(gc == nil and wc and wc:find("fait ET consommé", 1, true), "bloc : un objet fait et consommé dans le même bloc refusé")
    local gl, wl = Pm.bloc(M, MN, { rec(nm("l1"), cat, 0.1, { { nm("la"), 3 } }, { { nm("lb") } }) }, KIT, 0)
    chk(gl ~= nil, "bloc : une machine rapide en cadence réduite (" .. tostring(wl) .. ")")
    local gd, wd = Pm.bloc(M, MN, { brec("dd", { "a" }), brec("dd", { "a" }) }, KIT, 0)
    chk(gd == nil and wd and wd:find("deux fois", 1, true), "bloc : même recette deux fois refusée")
    local gf, wf = Pm.bloc(M, MN, { rec(nm("f1"), cat, 5, { { "~" .. nm("liq") }, { nm("a") } }, { { nm("fo") } }) }, KIT, 0)
    chk(gf == nil and wf and wf:find("fluide en entrée", 1, true), "bloc : fluide en entrée refusé")
    local gz, wz = Pm.bloc(M, MN, {}, KIT, 0)
    chk(gz == nil and wz and wz:find("sans recette", 1, true), "bloc : aucune recette")
    local gcat, wcat = Pm.bloc(M, MN, { rec(nm("c1"), "ailleurs", 5, { { nm("a") } }, { { nm("co") } }) }, KIT, 0)
    chk(gcat == nil and wcat and wcat:find("ailleurs", 1, true), "bloc : catégorie étrangère refusée")
    -- une voie surchargée : 6 machines du même ingrédient à 3/s chacune n'ont pas de voie (7,5/s) qui suffise
    local FASTM = nm("bfast")
    Pm.declare(M, FASTM, { kind = "assembler", w = 3, h = 3, speed = 10, categories = { cat } })
    local heavy = {}
    for i = 1, 6 do heavy[i] = rec(nm("h" .. i), cat, 1, { { nm("ha"), 1 } }, { { nm("ho" .. i), 1 } }) end
    heavy[7] = rec(nm("h7"), cat, 1, { { nm("hb"), 1 } }, { { nm("ho7"), 1 } })
    heavy[8] = rec(nm("h8"), cat, 1, { { nm("hc"), 1 } }, { { nm("ho8"), 1 } })
    local gh, wh = Pm.bloc(M, FASTM, heavy, KIT, 0)
    chk(gh == nil and wh and wh:find("voie 1 :", 1, true) and wh:find("7.50/s", 1, true), "bloc : six machines sur une voie de 7,5/s refusées (" .. tostring(wh) .. ")")

    -- §7 bis le RUBAN (lot MALL-RUE) : le bloc sur la géométrie de Mp.pattern, corridor A vers l'est (2 voies, port ouest), B vers l'ouest (1 entrée, port est)
    do
      local rr = { brec("q1", { "a", "b", "c" }), brec("q2", { "a", "c" }), brec("q3", { "b" }), brec("q4", { "c" }), brec("q5", { "a" }) }
      local gq, wq = Pm.ruban(M, MN, rr, KIT, 4)
      chk(gq ~= nil, "ruban rendu (" .. tostring(wq) .. ")")
      if gq then
        local errs = M.check(gq)
        chk(#errs == 0, "ruban : contrôle vide (" .. tostring(errs[1]) .. ")")
        -- (MALL-DIRECTIONS, 10e5f16c, F461 : le ruban est ORIENTABLE, la série suit l'orientation de sa première section)
        chk(gq.w == 11 and gq.h == 14 and gq.gen == "ruban" and not gq.no_rotate and gq.level_arg == 1 and #gq.args == 4, "ruban : 11 × 14 (la hauteur du bloc), gen ruban, orientable, args du bloc")
        chk(type(gq.ruban) == "table" and gq.ruban.belts[1] == 7 and gq.ruban.fam == "ruban-" .. MN, "ruban : g.ruban = ligne du convoyeur A (7), famille")
        local pa, pb
        for _, pt in ipairs(gq.ports) do
          if pt.kind == "tapis" then
            local e = gq.entities[pt.ent]
            if e.dir == 2 then pa = { e = e, p = pt } else pb = { e = e, p = pt } end
          end
        end
        chk(pa and pa.e.x == 0.5 and pa.e.y == 7.5 and pa.p.ent == gq.ruban.port, "ruban : convoyeur A entré à l'ouest (0, 7), vers l'est : le port servi par le souterrain")
        chk(pb and pb.e.x == 10.5 and pb.e.y == 6.5 and pb.e.dir == 6 and pb.p.lanes[1] == pb.p.lanes[2], "ruban : convoyeur B entré à l'est (10, 6), vers l'ouest, une seule entrée sur ses deux voies")
        chk(pa and pa.p.lanes[1] == nm("a") and pa.p.lanes[2] == nm("c") and pb.p.lanes[1] == nm("b"), "ruban : A porte les deux entrées les plus demandées (a, c), B la troisième (b)")
        local c = count_by(gq)
        chk(c.machine == 5 and c.chest == 5 and c.belt == 22 and port_count(gq, "quai", "out") == 5, "ruban : 5 machines, 5 coffres, 2 tapis de 11, 5 quais de sortie")
        for _, r in ipairs(rr) do chk(near(gq.nominal[r.products[1].name], 0.05, 1e-12), "ruban : débit de " .. r.products[1].name) end
        local gq2 = M.regenerate(gq)
        chk(gq2 and M.serialize(gq) == M.serialize(gq2), "ruban : regenerate identique")
        chk(M.rotate(gq, 1) ~= nil, "ruban : la rotation est permise (MALL-DIRECTIONS : séries dans les quatre directions)")
        -- la géométrie est celle de Mp.pattern : machines et convoyeurs aux mêmes lignes
        local Mp = require("shared.team.mall_paving")
        local pat = Mp.pattern({ asm = { w = 3, h = 3 }, belts = 2, n = 3 })
        local ok_rows = true
        for _, e in ipairs(gq.entities) do
          if e.name == MN then
            local found = false
            for _, cl in ipairs(pat.cells) do if cl.kind == "asm" and cl.dx == e.x - 1.5 and cl.dy == e.y - 1.5 then found = true end end
            if not found then ok_rows = false end
          end
        end
        chk(ok_rows and pat.w == gq.w and pat.h == gq.h, "ruban : chaque machine est sur une cellule « asm » de Mp.pattern, même emprise")
      end
      local g4, w4 = Pm.ruban(M, MN, { brec("x1", { "a", "b", "c" }), brec("x2", { "d" }) }, KIT, 0)
      chk(g4 == nil and w4 and w4:find("4 entrées distinctes pour le ruban", 1, true), "ruban : 4 entrées refusées (le bloc reste le gabarit)")
      local g2, w2 = Pm.ruban(M, MN, { brec("y1", { "a", "b" }) }, KIT, 0)
      chk(g2 and #M.check(g2) == 0 and port_count(g2, "tapis", "in") == 2, "ruban à 2 entrées : A = a, B = b, contrôle vide (" .. tostring(w2) .. ")")
      local g1, w1 = Pm.ruban(M, MN, { brec("z1", { "a" }) }, KIT, 0)
      chk(g1 and #M.check(g1) == 0 and port_count(g1, "tapis", "in") == 1 and count_by(g1).belt == 3, "ruban à 1 entrée : A seul, pas de convoyeur de retour (" .. tostring(w1) .. ")")
      local nine = {}
      for i = 1, 9 do nine[i] = brec("n" .. i, { names[(i - 1) % 3 + 1] }) end
      local g9, w9 = Pm.ruban(M, MN, nine, KIT, 0)
      chk(g9 == nil and w9 and w9:find("9 recettes, 8 machines au plus par section", 1, true), "ruban : une section tient dans un lot (9 recettes refusées)")
      chk(M.GEN.ruban ~= nil and M.GEN.ruban(MN, rr, KIT, 4) ~= nil, "ruban : générateur « ruban » de M.GEN")
    end

    -- regroupement
    local objs = {
      { name = "o1", solides = { "a", "b", "c" }, machine = "m" }, { name = "o2", solides = { "a", "d" }, machine = "m" },
      { name = "o3", solides = { "e" }, machine = "m" }, { name = "o4", solides = { "a" }, machine = "m" },
      { name = "o5", solides = { "a", "b", "c", "d", "e" }, machine = "m" }, { name = "o6", solides = { "a" }, machine = "n" },
      { name = "o7", solides = { "o1" }, machine = "m" }, { name = "o8", solides = { "b" }, machine = "m" },
    }
    local gr = Pm.groups(objs, { max = 10 })
    local placed = {}
    for _, bl in ipairs(gr.blocs) do
      chk(#bl.voies <= 4, "groupes : un bloc a au plus 4 voies")
      for _, o in ipairs(bl.objets) do placed[o] = (placed[o] or 0) + 1 end
    end
    for _, o in ipairs(gr.seuls) do placed[o] = (placed[o] or 0) + 1 end
    chk(#sorted_keys(placed) == 8, "groupes : chaque objet va quelque part")
    for _, k in ipairs(sorted_keys(placed)) do chk(placed[k] == 1, "groupes : " .. k .. " une seule fois") end
    chk(#gr.seuls == 1 and gr.seuls[1] == "o5", "groupes : l'objet à 5 entrées reste seul")
    local cls = {}
    for _, bl in ipairs(gr.blocs) do for _, o in ipairs(bl.objets) do cls[o] = bl.classe end end
    chk(cls.o6 == "n" and cls.o1 == "m", "groupes : une classe de machine par bloc")
    for _, bl in ipairs(gr.blocs) do
      local has_o1, has_o7 = false, false
      for _, o in ipairs(bl.objets) do if o == "o1" then has_o1 = true end if o == "o7" then has_o7 = true end end
      chk(not (has_o1 and has_o7), "groupes : o7 consomme o1, ils ne vont pas dans le même bloc")
    end
    -- déterminisme : l'ordre des objets donnés ne change rien
    local rev = {}
    for i = #objs, 1, -1 do rev[#rev + 1] = objs[i] end
    chk(M.serialize(Pm.groups(rev, { max = 10 })) == M.serialize(gr), "groupes : l'ordre des objets donnés ne change rien")
    -- ordre : les objets à plus d'entrées d'abord, puis le nom
    local ord = Pm.groups({ { name = "x1", solides = { "a" }, machine = "m" }, { name = "y1", solides = { "e" }, machine = "m" },
      { name = "z1", solides = { "a", "b", "c", "d" }, machine = "m" } }, { max = 10 })
    chk(#ord.blocs == 2 and ord.blocs[1].objets[1] == "z1" and ord.blocs[1].objets[2] == "x1" and ord.blocs[2].objets[1] == "y1",
      "groupes : le plus d'entrées d'abord, puis le nom")
    -- plafond de machines par bloc
    local many = {}
    for i = 1, 7 do many[i] = { name = "x" .. i, solides = { "a" }, machine = "m" } end
    local g3 = Pm.groups(many, { max = 3 })
    chk(#g3.blocs == 3 and #g3.blocs[1].objets == 3 and #g3.blocs[3].objets == 1, "groupes : 7 objets, 3 par bloc au plus → 3 blocs")
    chk(#Pm.groups(many).blocs == 1, "groupes : plafond par défaut de 10")
    chk(#Pm.groups({ { name = "z", solides = {}, machine = "m" } }, {}).seuls == 1, "groupes : un objet sans entrée reste seul")
    -- copies et assemblage
    chk(Pm.copies(100, 30) == 4 and Pm.copies(90, 30) == 3 and Pm.copies(1, 30) == 1 and Pm.copies(0, 30) == 1 and Pm.copies(5, 0) == nil, "copies : arrondi au-dessus, au moins une")
    chk(Pm.assemblage(30, 30) == "rangee" and Pm.assemblage(29.9, 30) == "bloc" and Pm.assemblage(100, 30) == "rangee" and Pm.assemblage(1, -3) == nil,
      "assemblage : une machine entière → rangée, sinon bloc")
  end

  -------------------------------------------------------------------------------------------------
  -- §8 échantillon de balayage (la totalité est plus bas, hors batterie)
  -------------------------------------------------------------------------------------------------
  do
    local cats = { "crafting", "basic-crafting", "advanced-crafting" }
    local pick = { "iron-gear-wheel", "electronic-circuit", "inserter", "advanced-circuit", "artillery-turret", "artillery-wagon", "satellite", "spidertron" }
    for _, side in ipairs({ 3, 5, 11 }) do
      local mn = nm("sw" .. side)
      Pm.declare(M, mn, { kind = "assembler", w = side, h = side, speed = 1, categories = cats })
      for _, rn in ipairs(pick) do
        local r = RECIPES[rn]
        local rr = { name = rn, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products }
        for _, so in ipairs({ "tapis", "coffre", "unite" }) do
          local g, why = Pm.cellule(M, mn, rr, so, 1, KIT, 0)
          if so == "tapis" and #r.ingredients > 4 then
            chk(g == nil, "balayage " .. rn .. " côté " .. side .. " tapis : refusé au-delà de 4 entrées")
          else
            chk(g and #M.check(g) == 0, "balayage " .. rn .. " côté " .. side .. " " .. so .. " (" .. tostring(why or (g and M.check(g)[1])) .. ")")
          end
        end
      end
    end
  end

  -------------------------------------------------------------------------------------------------
  -- §11 les têtes d'alimentation du plan directeur (shared/team/plan.lua) : P.fit place chaque forme dans un lot de 24 et les
  -- quais (P.feeder, P.out_quai) tiennent à côté du module sans rien recouvrir, au pire (une source « quai » sur les deux voies)
  -------------------------------------------------------------------------------------------------
  do
    local Plan = require("shared.team.plan")
    chk(Pm.LOT == Plan.LOT and Pm.TETE == Plan.FEED_DEPTH and Pm.MARGE == 1, "têtes : constantes du plan directeur (lot, profondeur de la tête)")
    chk(Pm.cote_tapis(1) == "est" and Pm.cote_tapis(2) == "ouest" and Pm.cote_tapis(3) == "est" and Pm.cote_tapis(4) == "ouest"
      and Pm.cote_tapis(1, "est") == "ouest" and Pm.cote_tapis(2, "est") == "est" and Pm.cote_tapis(1, "ouest") == "est", "côté d'entrée de chaque tapis")
    local function heads_fit(g)
      local rect = { x0 = 0, y0 = 0, x1 = Plan.LOT, y1 = Plan.LOT }
      local best, why = Plan.fit(g, rect)
      if not best then return false, "fit : " .. tostring(why) end
      local inst = M.instantiate(g, best.k, best.ox, best.oy)
      local occ = {}
      local function mark(x, y)
        local k = x .. "," .. y
        if occ[k] or x < rect.x0 or x >= rect.x1 or y < rect.y0 or y >= rect.y1 then return false, k end
        occ[k] = true
        return true
      end
      for _, e in ipairs(inst.entities) do
        local w, h = M.size(e.name, e.direction)
        for tx = math.floor(e.position.x - w / 2 + 0.01), math.floor(e.position.x + w / 2 - 0.01) do
          for ty = math.floor(e.position.y - h / 2 + 0.01), math.floor(e.position.y + h / 2 - 0.01) do
            local ok, k = mark(tx, ty)
            if not ok then return false, "module " .. e.name .. " " .. k end
          end
        end
      end
      for _, port in ipairs(Plan.belt_ports(inst)) do
        local list
        if port.io == "in" then list = Plan.feeder(port, { "quai", "quai" }, KIT.bras).entities
        else list = Plan.out_quai(port, KIT.bras) end
        for _, e in ipairs(list) do
          local ok, k = mark(math.floor(e.x), math.floor(e.y))
          if not ok then return false, "tête " .. tostring(e.role) .. " " .. k end
        end
      end
      return true
    end
    local cat = "cat-" .. id
    local function slowr(s, name)
      local ins = {}
      for i = 1, s do ins[i] = { nm("hi" .. i), 1 } end
      return rec(name, cat, 100, ins, { { nm("ho" .. name), 1 } })
    end
    for s = 1, 8 do
      for _, so in ipairs(s >= 5 and { "coffre", "unite" } or { "tapis", "coffre", "unite" }) do
        local g = Pm.cellule(M, MN, slowr(s, nm("tf" .. s .. so)), so, 1, KIT, 0)
        local ok, why = false, "forme absente"
        if g then ok, why = heads_fit(g) end
        chk(ok, "têtes : s=" .. s .. " " .. so .. " placée avec ses quais (" .. tostring(why) .. ")")
      end
    end
    -- rangées au plus large
    for _, s in ipairs({ 1, 2, 3, 4 }) do
      local g0 = Pm.cellule(M, MN, slowr(s, nm("tg" .. s)), "tapis", 1, KIT, 0)
      local top = g0 and g0.extensions[1].max or 0
      local g = Pm.cellule(M, MN, slowr(s, nm("th" .. s)), "tapis", top, KIT, 0)
      local ok, why = false, "forme absente"
      if g then ok, why = heads_fit(g) end
      chk(ok and top >= 4, "têtes : rangée de " .. top .. " à " .. s .. " entrée(s) placée (" .. tostring(why) .. ")")
    end
    local big = nm("tbig")
    Pm.declare(M, big, { kind = "assembler", w = 11, h = 11, speed = 1, categories = { cat } })
    for _, so in ipairs({ "coffre", "unite" }) do
      local g = Pm.cellule(M, big, slowr(8, nm("tb8" .. so)), so, 1, KIT, 0)
      local ok, why = false, "forme absente"
      if g then ok, why = heads_fit(g) end
      chk(ok, "têtes : machine de 11, 8 entrées, " .. so .. " placée (" .. tostring(why) .. ")")
    end
    -- fluides à l'ouest et à l'est
    local CM = nm("tchim")
    Pm.declare(M, CM, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "chem-" .. id },
      boxes = { { io = "in", pts = { { -1, -2 } } }, { io = "in", pts = { { 1, -2 } } } } })
    local EM = nm("tchime")
    Pm.declare(M, EM, { kind = "assembler", w = 3, h = 3, speed = 1, categories = { "chem-" .. id }, boxes = { { io = "in", pts = { { -1, 2 } } } } })
    local gf = Pm.cellule(M, CM, rec(nm("tfl"), "chem-" .. id, 1, { { "~" .. nm("fa"), 5 }, { nm("fb"), 1 }, { nm("fc"), 1 }, { nm("fd"), 1 } }, { { nm("fo") } }), "coffre", 1, KIT, 0)
    local okf, whyf = false, "forme absente"
    if gf then okf, whyf = heads_fit(gf) end
    chk(okf, "têtes : fluide à l'ouest avec 3 solides placé (" .. tostring(whyf) .. ")")
    local ge = Pm.cellule(M, EM, rec(nm("tfe"), "chem-" .. id, 1, { { "~" .. nm("fa2"), 5 }, { nm("fb2"), 1 }, { nm("fc2"), 1 }, { nm("fd2"), 1 } }, { { nm("foe") } }), "coffre", 1, KIT, 0)
    local oke, whye = false, "forme absente"
    if ge then oke, whye = heads_fit(ge) end
    chk(oke, "têtes : fluide à l'est avec 3 solides placé (" .. tostring(whye) .. ")")
    -- bloc
    local names = { "a", "b", "c", "d" }
    local rs = {}
    for i = 1, 8 do rs[i] = rec(nm("tbl" .. i), cat, 20, { { nm(names[(i - 1) % 4 + 1]), 1 }, { nm(names[i % 4 + 1]), 1 } }, { { nm("tbo" .. i), 1 } }) end
    local gb, wb = Pm.bloc(M, MN, rs, KIT, 4)
    local okb, whyb = false, tostring(wb)
    if gb then okb, whyb = heads_fit(gb) end
    chk(okb, "têtes : bloc de 8 placé (" .. tostring(whyb) .. ")")
    local g9 = Pm.bloc(M, MN, { rs[1], rs[2], rs[3] }, KIT, 4)
    local ok9, why9 = false, "forme absente"
    if g9 then ok9, why9 = heads_fit(g9) end
    chk(ok9, "têtes : bloc de 3 placé (" .. tostring(why9) .. ")")
  end

  return bad, total
end

---------------------------------------------------------------------------------------------------
-- Passage sur la règle livrée
---------------------------------------------------------------------------------------------------
local bad0, total0 = battery(P, true, "livrée")
check(bad0 == 0, "batterie sur la règle livrée : " .. bad0 .. " écart(s) sur " .. total0 .. " contrôles")
pass = pass + total0 - bad0

---------------------------------------------------------------------------------------------------
-- §8 balayage complet : toutes les recettes solides du relevé de référence
---------------------------------------------------------------------------------------------------
do
  local cats, names = {}, {}
  for n, r in pairs(RECIPES) do cats[r.category or "crafting"] = true; names[#names + 1] = n end
  table.sort(names)
  local catlist = sorted_keys(cats)
  local nbuilt, nbad, nref = 0, 0, 0
  local first_bad
  for _, side in ipairs({ 3, 5, 7, 11 }) do
    P.declare(M, "balayage-" .. side, { kind = "assembler", w = side, h = side, speed = 1, categories = catlist })
  end
  for _, kit in ipairs({ KIT, KIT_SMALL }) do
    for _, side in ipairs({ 3, 5, 7, 11 }) do
      for _, rn in ipairs(names) do
        local r = RECIPES[rn]
        local fluid = false
        for _, i in ipairs(r.ingredients) do if i.type == "fluid" then fluid = true end end
        for _, p in ipairs(r.products) do if p.type == "fluid" then fluid = true end end
        if not fluid then
          local rr = { name = rn, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products }
          for _, so in ipairs({ "tapis", "coffre", "unite" }) do
            if not (#r.products > 1 and so == "tapis") and not (#r.ingredients > 4 and so == "tapis") then
              local g, why = P.cellule(M, "balayage-" .. side, rr, so, 1, kit, 0)
              if not g then
                nref = nref + 1
                nbad = nbad + 1
                first_bad = first_bad or (rn .. " " .. so .. " côté " .. side .. " : " .. tostring(why))
              else
                nbuilt = nbuilt + 1
                local errs = M.check(g)
                if #errs > 0 then nbad = nbad + 1; first_bad = first_bad or (rn .. " " .. so .. " côté " .. side .. " : " .. errs[1]) end
              end
            end
          end
        end
      end
    end
  end
  check(nbad == 0 and nbuilt > 3000, string.format("§8 balayage : %d gabarits (2 poteaux × 4 côtés × recettes solides × sorties), %d écart(s), %d refus %s",
    nbuilt, nbad, nref, first_bad or ""))
end

---------------------------------------------------------------------------------------------------
-- §9 Noms permutés : les mêmes formes quels que soient les noms
---------------------------------------------------------------------------------------------------
do
  local function hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return string.format("%08x", h)
  end
  local function shape(g)
    local c = count_by(g)
    local nom, inp = {}, {}
    for _, k in ipairs(sorted_keys(g.nominal)) do nom[#nom + 1] = string.format("%.9f", g.nominal[k]) end
    for _, k in ipairs(sorted_keys(g.inputs)) do inp[#inp + 1] = string.format("%.9f", g.inputs[k]) end
    table.sort(nom)
    table.sort(inp)
    local ports = {}
    for _, p in ipairs(g.ports) do ports[#ports + 1] = p.kind .. ":" .. p.io end
    table.sort(ports)
    return string.format("%dx%d|%d,%d,%d,%d,%d,%d|%s|%s|%s", g.w, g.h, c.belt, c.arm, c.long, c.chest, c.pole, c.machine,
      table.concat(nom, ","), table.concat(inp, ","), table.concat(ports, ","))
  end
  local cats, names = {}, {}
  for n, r in pairs(RECIPES) do cats[r.category or "crafting"] = true; names[#names + 1] = n end
  table.sort(names)
  local catlist = sorted_keys(cats)
  P.declare(M, "iso-orig", { kind = "assembler", w = 5, h = 5, speed = 1.5, categories = catlist })
  local permcats = {}
  for i, c in ipairs(catlist) do permcats[i] = "k" .. hash(c) end
  P.declare(M, "iso-" .. hash("machine"), { kind = "assembler", w = 5, h = 5, speed = 1.5, categories = permcats })
  local n, diff = 0, 0
  local ex
  for _, rn in ipairs(names) do
    local r = RECIPES[rn]
    local fluid = false
    for _, i in ipairs(r.ingredients) do if i.type == "fluid" then fluid = true end end
    for _, p in ipairs(r.products) do if p.type == "fluid" then fluid = true end end
    if not fluid and (#names % 1 == 0) then
      local function conv(list)
        local out = {}
        for i, x in ipairs(list) do out[i] = { type = x.type, name = "o" .. hash(x.name), amount = x.amount } end
        return out
      end
      local a = { name = rn, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products }
      local b = { name = "r" .. hash(rn), category = "k" .. hash(r.category or "crafting"), energy = r.energy, ingredients = conv(r.ingredients), products = conv(r.products) }
      for _, so in ipairs({ "coffre", "unite" }) do
        local ga = P.cellule(M, "iso-orig", a, so, 1, KIT, 0)
        local gb = P.cellule(M, "iso-" .. hash("machine"), b, so, 1, KIT, 0)
        n = n + 1
        if (ga == nil) ~= (gb == nil) or (ga and shape(ga) ~= shape(gb)) then
          diff = diff + 1
          ex = ex or rn
        end
      end
    end
  end
  check(n > 300 and diff == 0, string.format("§9 noms permutés : %d recettes comparées une à une, %d écart(s) %s", n, diff, ex or ""))
  -- kit et machine permutés aussi
  local pk = { bras = "arm-" .. hash("bras"), bras_long = "long-" .. hash("long"), tapis = "belt-" .. hash("tapis"), coffre = "box-" .. hash("coffre"), poteau = "pole-" .. hash("pole") }
  P.declare(M, pk.bras, { kind = "inserter", rate = 0.83, reach = 1, power = 13.6 })
  P.declare(M, pk.bras_long, { kind = "inserter", rate = 1.15, reach = 2, power = 20.4 })
  P.declare(M, pk.tapis, { kind = "belt" })
  P.declare(M, pk.coffre, { kind = "chest", slots = 16 })
  P.declare(M, pk.poteau, { kind = "pole", supply = 3.5, wire = 9 })
  local rr = RECIPES["advanced-circuit"]
  local ga = P.cellule(M, "iso-orig", { name = "advanced-circuit", category = rr.category, energy = rr.energy, ingredients = rr.ingredients, products = rr.products }, "coffre", 1, KIT, 0)
  local gb = P.cellule(M, "iso-orig", { name = "advanced-circuit", category = rr.category, energy = rr.energy, ingredients = rr.ingredients, products = rr.products }, "coffre", 1, pk, 0)
  check(ga and gb and #M.check(gb) == 0 and shape(ga) == shape(gb), "§9 kit permuté (bras, tapis, coffre, poteau d'un mod) : même forme, contrôle vide")
  check(gb and gb.pole_name == pk.poteau, "§9 le poteau du kit est celui du gabarit")
  -- mini-mod : machine 4 × 4 d'une catégorie neuve, recette à 4 entrées, 7 entrées sur 11 de large
  P.declare(M, "mm-quatre", { kind = "assembler", w = 4, h = 4, speed = 2, categories = { "cat-neuve" } })
  P.declare(M, "mm-onze", { kind = "assembler", w = 11, h = 11, speed = 1, categories = { "cat-neuve" } })
  local r4 = rec("mm-r4", "cat-neuve", 3, { { "m-a", 2 }, { "m-b", 1 }, { "m-c", 5 }, { "m-d", 1 } }, { { "m-out", 1 } })
  local r7 = rec("mm-r7", "cat-neuve", 30, { { "m-a" }, { "m-b" }, { "m-c" }, { "m-d" }, { "m-e" }, { "m-f" }, { "m-g" } }, { { "m-out7", 1 } })
  for _, so in ipairs({ "tapis", "coffre", "unite" }) do
    local g4 = P.cellule(M, "mm-quatre", r4, so, 1, KIT, 0)
    if so == "tapis" then
      local g7t = P.cellule(M, "mm-onze", r7, so, 1, KIT, 0)
      check(g7t == nil, "§9 mini-mod : 7 entrées en tapis refusées")
    end
    check(g4 and #M.check(g4) == 0, "§9 mini-mod : machine 4 × 4 de catégorie neuve, 4 entrées, " .. so .. " (" .. tostring(g4 and M.check(g4)[1]) .. ")")
    local g7 = P.cellule(M, "mm-onze", r7, so, 1, KIT, 0)
    if so ~= "tapis" then
      check(g7 and #M.check(g7) == 0, "§9 mini-mod : machine 11 × 11, 7 entrées, " .. so .. " (" .. tostring(g7 and M.check(g7)[1]) .. ")")
    end
  end
  local g7 = P.cellule(M, "mm-onze", r7, "unite", 1, KIT, 0)
  local me
  for _, e in ipairs(g7 and g7.entities or {}) do if M.spec(e.name).kind == "assembler" then me = e end end
  check(me and g7 and (me.x - 5.5 < 1e-9 or me.x + 5.5 > g7.w - 1e-9), "§9 unité de 7 entrées : la machine touche un bord")
end

---------------------------------------------------------------------------------------------------
-- §10 Mutants
---------------------------------------------------------------------------------------------------
local function read_source(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = read_source("shared/team/patrons.lua")

local function plain_replace(s, old, new)
  local i, j = s:find(old, 1, true)
  if not i then return nil end
  if s:find(old, j + 1, true) then return nil, "motif en double" end
  return s:sub(1, i - 1) .. new .. s:sub(j + 1)
end

local MUTANTS = {
  { "tapis : plafond par arrondi inférieur", "local nb = ceil(s / 2)", "local nb = floor(s / 2)" },
  { "tapis au nord : 3 au lieu de 2", "local nord = min(nb, 2)", "local nord = min(nb, 3)" },
  { "côté de la sortie inversé", 'if sud > 0 then cote = "est" end', 'if sud == 0 then cote = "est" end' },
  { "unité : le côté reste au sud", 'if sortie == "unite" then cote = "aucun" end', 'if false then cote = "aucun" end' },
  { "plafond des entrées : 9", "P.MAX_SOLIDES = 8", "P.MAX_SOLIDES = 9" },
  { "voies : demande croissante", "if a.demande ~= b.demande then return a.demande > b.demande end", "if a.demande ~= b.demande then return a.demande < b.demande end" },
  { "voies : nom décroissant", "return a.name < b.name\n  end)\n  local belts = {}", "return a.name > b.name\n  end)\n  local belts = {}" },
  { "bras : cadence 60 au lieu de 58", "return floor(58 * rot * 100 + 1e-6) / 100", "return floor(60 * rot * 100 + 1e-6) / 100" },
  { "colonnes de bras : la dernière du motif prise", "if c % period ~= period - 1 and", "if c % period ~= period - 2 and" },
  { "colonnes de bras : rangée de 3 pleine", "and not (width <= period - 1 and c == width - 1)", "and not (false and c == width - 1)" },
  { "période : couverture arrondie au-dessus", "return max(2, floor(supply + EPS) + 1)", "return max(2, floor(supply + EPS) + 2)" },
  { "déclaration : un nom connu écrasé", "if M.BASE[name] == nil then", "if true then" },
  { "déclaration : époque non posée", "if idx[name] == nil then idx[name] = 1 end", "" },
  { "déclaration : catégories non réunies", "elseif M.BASE[name].declared and def.categories then", "elseif false then" },
  { "déclaration : une machine du modèle gagne des catégories", "elseif M.BASE[name].declared and def.categories then", "elseif def.categories then" },
  { "déclaration : catégories non triées", "    table.sort(cats)\n    M.BASE[name].categories = cats", "    M.BASE[name].categories = cats" },
  { "machine lue : combustible ignoré", 'if m.energy == "burner" then def.burner_kw = 1 end', "" },
  { "machine lue : boîte entrée-sortie prise pour une entrée", 'local io = (bx.type == "input" and "in") or (bx.type == "output" and "out") or "io"',
    'local io = (bx.type == "output" and "out") or "in"' },
  { "machine lue : boîtes lues pour le nord seulement", "local c = bx.conns and bx.conns[0] and bx.conns[0][1]", "local c = bx.conns and bx.conns[2] and bx.conns[2][1]" },
  { "kit lu : bras sans cadence accepté", 'if not rate then return fail("bras « %s » sans vitesse de rotation", tostring(c.entity)) end', "" },
  { "kit lu : poteau sans couverture", "def = { kind = \"pole\", supply = c.supply, wire = c.wire }", "def = { kind = \"pole\", wire = c.wire }" },
  { "recette : fluide en sortie accepté", "if fout > 0 then return fail", "if false then return fail" },
  { "recette : produit net compté >=", "if p.amount - used > EPS then nets", "if p.amount - used >= -EPS then nets" },
  { "kit : portée du bras long ignorée", "if sp.reach ~= reach then return fail", "if false then return fail" },
  { "kit : sorte de la pièce ignorée", "if kind and sp.kind ~= kind then return fail", "if false then return fail" },
  { "kit : bras sans cadence accepté", 'if type(sp.rate) ~= "number" then return fail', "if false then return fail" },
  { "kit : tuyau de plusieurs tuiles accepté", 'if key == "tuyau" and not (sp.w == 1 and sp.h == 1) then', "if false then" },
  { "catégorie de la machine ignorée", "if not cat_ok then return fail(\"« %s » ne fabrique pas la catégorie « %s »\", machine, r.category) end",
    "" },
  { "deux produits sur un tapis acceptés", 'if #r.prods > 1 and sortie == "tapis" then', "if false then" },
  { "fluides : rangée de plusieurs acceptée", "if #r.fin > 0 and n ~= 1 then return fail", "if false then return fail" },
  { "tapis du sud : rangée de plusieurs acceptée", "if topo.sud > 0 and n ~= 1 then return fail", "if false then return fail" },
  { "fluides : l'est essayé avant l'ouest", 'for _, side in ipairs({ "ouest", "est" }) do', 'for _, side in ipairs({ "est", "ouest" }) do' },
  { "fluides : raccords voisins acceptés", "if rows[i] - rows[i - 1] < 2 then ok = false end", "if false then ok = false end" },
  { "fluides : tuyau sur la mauvaise ligne", "ty = floor(mh / 2 + py)", "ty = floor(mh / 2 + py) + 1" },
  { "cadence : bras normal pris pour le tapis lointain", "local long = (k % 2 == 0)\n    kin[k]", "local long = (k % 2 == 1)\n    kin[k]" },
  { "cadence : le plafond de la machine oublié", "if ng == 1 then return min(1, f_of(groups[1], slots)) end", "if ng == 1 then return f_of(groups[1], slots) end" },
  { "bras : arrondi inférieur", "c[i] = max(1, ceil(g.d * rate / arm_cap1(M, g.arm, g.belt) - EPS))", "c[i] = max(1, floor(g.d * rate / arm_cap1(M, g.arm, g.belt)))" },
  { "bras : marge de 10 % oubliée", "return M.BASE[arm].rate * (from_belt and M.BELT_PICKUP or 1) * M.MARGIN", "return M.BASE[arm].rate * (from_belt and M.BELT_PICKUP or 1)" },
  { "lot : 26 au lieu de 24", "P.LOT = 24 ", "P.LOT = 26 " },
  { "tête : 2 au lieu de 3", "P.TETE = 3 ", "P.TETE = 2 " },
  { "tapis voisins du même côté", 'local est = (k % 2 == 1)', 'local est = true' },
  { "tapis pairs et impairs échangés", 'local est = (k % 2 == 1)', 'local est = (k % 2 == 0)' },
  { "fluide à l'est : côtés non inversés", 'if cote_fluide == "est" then est = not est end', "" },
  { "cellule : tête de l'ouest oubliée", 'if sides[k] == "ouest" then w_need = P.TETE else e_need = P.TETE end', 'if sides[k] == "ouest" then w_need = P.MARGE else e_need = P.TETE end' },
  { "cellule : tête de l'est oubliée", 'if sides[k] == "ouest" then w_need = P.TETE else e_need = P.TETE end', 'if sides[k] == "ouest" then w_need = P.TETE else e_need = P.MARGE end' },
  { "cellule : rangées de la tête oubliées", "local top_need = (#belts > 0) and P.TETE_LARGEUR or P.MARGE", "local top_need = P.MARGE" },
  { "cellule : tapis de sortie en colonne accepté", 'if topo.sud > 0 and sortie == "tapis" then', "if false then" },
  { "bloc : tapis voisins du même côté", 'if P.cote_tapis(k) == "ouest" then belt_first[k] = b:belt_line(0,', 'if true then belt_first[k] = b:belt_line(0,' },
  { "colonne de liaison oubliée entre deux machines", "local span = n * mw + (n - 1)", "local span = n * mw" },
  { "extension : largeur comptée sans la liaison", "floor_eps((P.LOT - w_need - e_need - ox + 1) / (mw + 1))", "floor_eps((P.LOT - w_need - e_need - ox + 1) / mw)" },
  { "extension : têtes oubliées", "floor_eps((P.LOT - w_need - e_need - ox + 1) / (mw + 1))", "floor_eps((P.LOT - ox + 1) / (mw + 1))" },
  { "extension : voie de sortie à 15", "bounds[#bounds + 1] = floor_eps(M.LANE_RATE / (d_out * rate))", "bounds[#bounds + 1] = floor_eps(2 * M.LANE_RATE / (d_out * rate))" },
  { "extension : voie d'entrée à une seule voie", "local cap = (#belt == 1) and 2 * M.LANE_RATE or M.LANE_RATE", "local cap = M.LANE_RATE" },
  { "unité : quai sans l'indicateur", "item = nm, unite = true", "item = nm" },
  { "barre perdue", "item = nm, bar = (barre > 0) and barre or nil }) end", "item = nm }) end" },
  { "bloc : colonnes sans la liaison", "function P.colonnes(mw) return floor_eps((P.LOT - 2 * P.TETE + 1) / (mw + 1)) end", "function P.colonnes(mw) return floor_eps((P.LOT - 2 * P.TETE + 1) / mw) end" },
  { "bloc : colonnes sans les têtes", "function P.colonnes(mw) return floor_eps((P.LOT - 2 * P.TETE + 1) / (mw + 1)) end", "function P.colonnes(mw) return floor_eps((P.LOT + 1) / (mw + 1)) end" },
  { "bloc : plus de 4 voies acceptées", "if #names > P.BLOC_VOIES then return fail", "if false then return fail" },
  { "bloc : objet fait et consommé accepté", "if inputs_of[nm] then return fail", "if false then return fail" },
  { "bloc : voie surchargée acceptée", "if demand[nm] > cap + EPS then return fail", "if false then return fail" },
  { "bloc : le sud prend le tapis éloigné", "local near_s, far_s = nbelts, (nbelts == 2) and 1 or nil", "local near_s, far_s = 1, (nbelts == 2) and 2 or nil" },
  { "bloc : 4 voies = 5", "P.BLOC_VOIES = 4", "P.BLOC_VOIES = 5" },
  { "groupes : la classe de machine ignorée", "if not clash and bl.classe == o.machine and #bl.objets < cap then", "if not clash and #bl.objets < cap then" },
  { "groupes : le conflit fait/consommé ignoré", "        if not clash and bl.classe", "        if false and bl.classe" },
  { "groupes : plafond de machines ignoré", "and #bl.objets < cap then", "then" },
  { "groupes : tri par nom seulement", "if #a.solides ~= #b.solides then return #a.solides > #b.solides end\n    return a.name < b.name\n  end)\n  local blocs, seuls", "do end\n    return a.name < b.name\n  end)\n  local blocs, seuls" },
  { "copies : arrondi inférieur", "return max(1, ceil(demande / par_min - EPS))", "return max(1, floor(demande / par_min))" },
  { "assemblage : égalité en bloc", "if demande >= par_min - EPS then return \"rangee\" end", "if demande > par_min + EPS then return \"rangee\" end" },
}

local caught = 0
for _, mu in ipairs(MUTANTS) do
  local src, why = plain_replace(SRC, mu[2], mu[3])
  if not src then
    check(false, "§10 motif du mutant introuvable (" .. tostring(why) .. ") : " .. mu[1])
  else
    local chunk, err = load(src, "=patrons_mutant", "t")
    local detected
    if not chunk then
      detected = true
      print("  (mutant « " .. mu[1] .. " » : source invalide " .. tostring(err) .. ")")
    else
      local ok, Pm = pcall(chunk)
      if not ok then
        detected = true
      else
        local ok2, bad = pcall(battery, Pm, false, mu[1])
        detected = (not ok2) or bad > 0
      end
    end
    if detected then caught = caught + 1 end
    check(detected, "§10 mutant refusé : " .. mu[1])
  end
end
check(caught == #MUTANTS, string.format("§10 mutants : %d refusés sur %d", caught, #MUTANTS))

print(string.format("[PATRONS-TEST] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, caught, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
