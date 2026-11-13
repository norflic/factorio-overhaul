--[[
  Lot MALL, tranche 2 : contrôle hors jeu de la règle pure de la rangée du mall (shared/team/mall_rangee.lua) : voies, ajouts, cellules scellées, géométrie aux 4
  orientations relue au motif du catalogue (asm-miroir-2e-coffres), contrôle de chaque bras (prise et dépose sur la bonne pièce), continuité des tapis, déclaration
  `carries` de chaque tapis, poteaux reliés et machines couvertes, coût mesuré par debug.sethook ; mutants.
  Usage : lua5.2 tests/mall_rangee_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end

local Cat = require("shared.team.motifs.catalogue")
local P = require("shared.team.plan")
local Mr = require("shared.team.mall_rangee")

local NAMES = { machine = "assembling-machine-1", bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", poteau = "small-electric-pole",
  coffre = "iron-chest" }
local function size(name) if name == "assembling-machine-1" then return 3, 3 end return 1, 1 end

local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

local function modele()
  local inst = Cat.instancier(Mr.MOTIF, 1, { rot = 0, miroir = false })
  return assert(Mr.modele(inst.pieces))
end

local function row_of(voies, n)
  local cells = {}
  for i = 1, n do cells[i] = { h = "r-h" .. i, b = "r-b" .. i, ih = "it-h" .. i, ib = "it-b" .. i } end
  return { j = 1, voies = voies, cells = cells }
end

---------------------------------------------------------------------------------------------------
-- §1 voies, acceptation
---------------------------------------------------------------------------------------------------
do
  local v = Mr.voies({ { name = "a", solides = { "fer", "cuivre" } }, { name = "b", solides = { "fer", "a" } }, { name = "c", solides = { "fer", "cuivre" } } })
  check(v[1] == "fer" and v[2] == "cuivre" and #v == 2, "§1 voies triées par usages, un produit (a) n'est pas une voie")
  check(Mr.accepte({ "fer", "cuivre" }, { "fer" }, "x") == true, "§1 accepte : entrées sur les voies")
  check(Mr.accepte({ "fer" }, { "cuivre" }, "x") == false, "§1 accepte : entrée hors voies")
  check(Mr.accepte({ "fer" }, { "fer" }, "fer") == false, "§1 accepte : l'objet-voie n'entre pas")
  check(Mr.accepte({ "fer" }, {}, "x") == false, "§1 accepte : aucune entrée solide")
  local v4 = Mr.voies({ { name = "z", solides = { "a", "b", "c", "d", "e" } } })
  check(#v4 == 4, "§1 quatre voies au plus")
end

---------------------------------------------------------------------------------------------------
-- §2 ajouts, sceller
---------------------------------------------------------------------------------------------------
do
  local row = { j = 1, voies = { "fer", "cuivre" }, cells = { { h = "ra", b = "ra", ih = "a", ib = "a" } } }
  check(Mr.compte(row, "ra") == 2, "§2 compte")
  local d = { { item = "a", recipe = "ra", machines = 5, solides = { "fer" } }, { item = "b", recipe = "rb", machines = 1, solides = { "fer" } },
    { item = "c", recipe = "rc", machines = 1, solides = { "mystere" } } }
  local aj = Mr.ajouts(row, d)
  check(#aj == 2 and aj[1].n == 3 and aj[2].n == 1, "§2 ajouts : la différence seulement, hors voies écarté")
  local aj2 = Mr.ajouts(row, d, 2)
  check(#aj2 == 1 and aj2[1].n == 2, "§2 ajouts bornés par max_new")
  local cells = Mr.sceller(aj)
  check(#cells == 2, "§2 sceller : 4 machines = 2 cellules")
  check(cells[1].h == "ra" and cells[1].b == "ra" and cells[2].h == "ra" and cells[2].b == "rb", "§2 sceller : ordre conservé")
  local odd = Mr.sceller({ { recipe = "x", item = "ix", n = 1 } })
  check(#odd == 1 and odd[1].b == "x" and odd[1].ib == "ix", "§2 sceller : place libre reprise par la voisine (pas de machine sans recette)")
end

---------------------------------------------------------------------------------------------------
-- §3 géométrie : aux 4 orientations, 3 cellules + tête, relue par construction
---------------------------------------------------------------------------------------------------
local function geometry(voies, s, n)
  local row = row_of(voies, n)
  local m = modele()
  local ox, oy = Mr.origin(s)
  local rep = { ox = ox, oy = oy, k = Mr.frame(s.dir) }
  local sec = Mr.section(P, m, row, 1, n, NAMES, rep, true)
  return sec, row, rep
end

local SECTORS = {
  { x0 = -40, y0 = 8, x1 = 24, y1 = 72, dir = 2 },
  { x0 = -40, y0 = 8, x1 = 24, y1 = 72, dir = 4 },
  { x0 = -40, y0 = 8, x1 = 24, y1 = 72, dir = 6 },
  { x0 = -40, y0 = 8, x1 = 24, y1 = 72, dir = 0 },
}

local function tile(x, y) return math.floor(x) .. ":" .. math.floor(y) end

for _, s in ipairs(SECTORS) do
  for _, voies in ipairs({ { "fer", "cuivre", "gear", "circ" }, { "fer", "gear", "circ" }, { "fer", "gear" }, { "fer" } }) do
    local tag = string.format("§3 dir %d, %d voie(s) : ", s.dir, #voies)
    local sec, row, rep = geometry(voies, s, 3)
    local errs = Mr.verifie(sec.ents, size, 7.5, 2.5)
    check(#errs == 0, tag .. "géométrie conforme (" .. table.concat(errs, " ; ") .. ")")
    -- dans le secteur
    local bb = Mr.box(sec.ents, size)
    check(bb[1] >= s.x0 and bb[2] >= s.y0 and bb[3] < s.x1 and bb[4] < s.y1, tag .. "dans le secteur")
    -- indexation
    local at, machines, belts, chests, arms, longs = {}, {}, {}, {}, {}, {}
    for _, e in ipairs(sec.ents) do
      local w, h = size(e.name)
      for ty = math.floor(e.y - h / 2 + 1e-6), math.floor(e.y - h / 2 + 1e-6) + h - 1 do
        for tx = math.floor(e.x - w / 2 + 1e-6), math.floor(e.x - w / 2 + 1e-6) + w - 1 do at[tx .. ":" .. ty] = e end
      end
      if e.name == NAMES.machine then machines[#machines + 1] = e end
      if e.name == NAMES.tapis then belts[#belts + 1] = e end
      if e.name == NAMES.coffre then chests[#chests + 1] = e end
      if e.name == NAMES.bras then arms[#arms + 1] = e end
      if e.name == NAMES.bras_long then longs[#longs + 1] = e end
    end
    check(#machines == 6, tag .. "6 machines")
    -- recettes : haut et bas distinctes par cellule
    local rec = {}
    for _, e in ipairs(machines) do rec[e.recipe] = (rec[e.recipe] or 0) + 1 end
    for i = 1, 3 do check(rec["r-h" .. i] == 1 and rec["r-b" .. i] == 1, tag .. "recettes de la cellule " .. i) end
    -- tapis : continuité (chaque tapis mène à un tapis ou au bout de la rangée) ; le dernier tapis de chaque ligne est dans la dernière cellule
    local ends = 0
    for _, e in ipairs(belts) do
      local v = DV[e.dir]
      local nxt = at[tile(e.x + v[1], e.y + v[2])]
      if nxt and nxt.name == NAMES.tapis then
        local v2 = DV[nxt.dir]
        check(not (v2[1] == -v[1] and v2[2] == -v[2]), tag .. "aucun tapis face à face")
      else ends = ends + 1 end
      check(e.carries ~= nil and #e.carries >= 1, tag .. "carries déclaré sur chaque tapis")
    end
    check(ends == 2, tag .. "deux bouts de tapis (les deux lignes), lu " .. ends)
    -- bras : la prise et la dépose tombent sur la bonne pièce
    for _, e in ipairs(arms) do
      local v = DV[e.dir]
      local pick, drop = at[tile(e.x + v[1], e.y + v[2])], at[tile(e.x - v[1], e.y - v[2])]
      check(pick ~= nil and drop ~= nil, tag .. string.format("bras en (%.1f,%.1f) relie deux pièces", e.x, e.y))
      if pick and drop then
        if e.role == "mall-bras" then
          local outarm = pick.name == NAMES.machine
          if outarm then
            check(drop.name == NAMES.coffre, tag .. "bras de sortie : de la machine au coffre")
          else
            check(pick.name == NAMES.tapis and drop.name == NAMES.machine, tag .. "bras d'entrée : du tapis à la machine")
          end
        elseif e.role == "quai-bras" then
          check(pick.name == NAMES.coffre and drop.name == NAMES.tapis, tag .. "bras de quai : du coffre au tapis")
        end
      end
    end
    for _, e in ipairs(longs) do
      local v = DV[e.dir]
      local pick, drop = at[tile(e.x + 2 * v[1], e.y + 2 * v[2])], at[tile(e.x - 2 * v[1], e.y - 2 * v[2])]
      check(pick ~= nil and pick.name == NAMES.tapis, tag .. "bras long : prise sur un tapis")
      check(drop ~= nil and drop.name == NAMES.machine, tag .. "bras long : dépose dans une machine")
    end
    -- tracés de pureté : chaque tuile mène à la suivante, dans l'ordre du flux
    for k = 1, 2 do
      local ln = sec.lines[k]
      check(#ln >= 12, tag .. "tracé du tapis " .. k .. " (" .. #ln .. " tuiles)")
      for i = 1, #ln - 1 do
        local v = DV[ln[i].dir]
        check(ln[i].x + v[1] == ln[i + 1].x and ln[i].y + v[2] == ln[i + 1].y, tag .. string.format("tracé %d continu à la tuile %d", k, i))
      end
    end
    -- quais et sorties
    check(#sec.quais == Mr.ARMS * #voies, tag .. "Mr.ARMS quais par voie (" .. #sec.quais .. ")")
    for _, q in ipairs(sec.quais) do
      local c = at[tile(q.x, q.y)]
      check(c ~= nil and c.name == NAMES.coffre, tag .. "quai = un coffre posé")
    end
    check(#sec.outs == 6, tag .. "une sortie par machine")
    for _, o in ipairs(sec.outs) do
      local c = at[tile(o.x, o.y)]
      check(c ~= nil and c.name == NAMES.coffre and o.item ~= nil, tag .. "sortie = un coffre posé avec son objet")
    end
    -- Rangée suivante : ne chevauche pas la première
    local row2 = row_of(voies, 3); row2.j = 2
    local sec2 = Mr.section(P, modele(), row2, 1, 3, NAMES, rep, true)
    local both = {}
    for _, e in ipairs(sec.ents) do both[#both + 1] = e end
    for _, e in ipairs(sec2.ents) do both[#both + 1] = e end
    check(#Mr.verifie(both, size, 7.5, 2.5) == 0, tag .. "deux rangées voisines reliées par le relais (fil de 7,5)")
    local o2 = {}
    local dup = false
    for _, e in ipairs(both) do
      local w, h = size(e.name)
      for ty = math.floor(e.y - h / 2 + 1e-6), math.floor(e.y - h / 2 + 1e-6) + h - 1 do
        for tx = math.floor(e.x - w / 2 + 1e-6), math.floor(e.x - w / 2 + 1e-6) + w - 1 do
          if o2[tx .. ":" .. ty] then dup = true end
          o2[tx .. ":" .. ty] = true
        end
      end
    end
    check(not dup, tag .. "la rangée 2 ne recouvre pas la rangée 1")
    -- Section suivante : allongement = les tapis continuent, sans recouvrement
    local row3 = row_of(voies, 5)
    local sA = Mr.section(P, modele(), row3, 1, 3, NAMES, rep, true)
    local sB = Mr.section(P, modele(), row3, 4, 5, NAMES, rep, false)
    local o3, dup3 = {}, false
    local lane_ends = 0
    for _, list in ipairs({ sA.ents, sB.ents }) do
      for _, e in ipairs(list) do
        local w, h = size(e.name)
        for ty = math.floor(e.y - h / 2 + 1e-6), math.floor(e.y - h / 2 + 1e-6) + h - 1 do
          for tx = math.floor(e.x - w / 2 + 1e-6), math.floor(e.x - w / 2 + 1e-6) + w - 1 do
            if o3[tx .. ":" .. ty] then dup3 = true end
            o3[tx .. ":" .. ty] = e
          end
        end
      end
    end
    check(not dup3, tag .. "section suivante sans recouvrement")
    for _, e in ipairs(sA.ents) do
      if e.name == NAMES.tapis then
        local v = DV[e.dir]
        local nxt = o3[tile(e.x + v[1], e.y + v[2])]
        if not (nxt and nxt.name == NAMES.tapis) then lane_ends = lane_ends + 1 end
      end
    end
    check(lane_ends == 0, tag .. "les tapis de la section 1 se prolongent dans la section 2 (" .. lane_ends .. " bout(s))")
  end
end

---------------------------------------------------------------------------------------------------
-- §4 capacité du secteur
---------------------------------------------------------------------------------------------------
do
  local rows, cells = Mr.capacite({ x0 = 0, y0 = 0, x1 = 48, y1 = 48, dir = 2 })
  check(rows == 3 and cells == 10, "§4 secteur de 48 × 48 : 3 rangées de 10 cellules (20 machines par rangée, " .. rows .. " " .. cells .. ")")
  local rows2, cells2 = Mr.capacite({ x0 = 0, y0 = 0, x1 = 64, y1 = 64, dir = 4 })
  check(rows2 == 4 and cells2 == 14, "§4 secteur de 64 × 64 : 4 rangées de 14 cellules")
end

---------------------------------------------------------------------------------------------------
-- §5 coût (debug.sethook, instructions Lua)
---------------------------------------------------------------------------------------------------
do
  local count = 0
  local m = modele()
  local row = row_of({ "fer", "cuivre", "gear", "circ" }, 12)
  local s = { x0 = 0, y0 = 0, x1 = 64, y1 = 64, dir = 2 }
  local ox, oy = Mr.origin(s)
  debug.sethook(function() count = count + 1000 end, "", 1000)
  local sec = Mr.section(P, m, row, 1, 12, NAMES, { ox = ox, oy = oy, k = 0 }, true)
  local errs = Mr.verifie(sec.ents, size, 7.5, 2.5)
  debug.sethook()
  check(#errs == 0, "§5 rangée de 12 cellules conforme")
  check(count <= 370000, "§5 coût d'une section de 12 cellules ≤ 370 k instructions (" .. count .. ")")
  print("[MALL-RANGEE] instructions Lua, section de 12 cellules + contrôle : " .. count)
end

---------------------------------------------------------------------------------------------------
-- §6 mutants
---------------------------------------------------------------------------------------------------
do
  local path = "shared/team/mall_rangee.lua"
  local src = assert(io.open(path, "rb")):read("*a")
  local function run_mutant(from, to)
    if not src:find(from, 1, true) then return "motif introuvable" end
    local i, j = src:find(from, 1, true)
    local code = src:sub(1, i - 1) .. to .. src:sub(j + 1)
    local M2 = assert(load(code, "mutant", "t"))()
    local ok, res = pcall(function()
      -- le contrôle de géométrie de §3, repris sur une seule orientation
      local s = SECTORS[1]
      local voies = { "fer", "cuivre", "gear", "circ" }
      local row = row_of(voies, 3)
      local inst = Cat.instancier(Mr.MOTIF, 1, { rot = 0, miroir = false })
      local m = assert(M2.modele(inst.pieces))
      local ox, oy = M2.origin(s)
      local sec = M2.section(P, m, row, 1, 3, NAMES, { ox = ox, oy = oy, k = M2.frame(s.dir) }, true)
      local errs = M2.verifie(sec.ents, size, 7.5, 2.5)
      if #errs > 0 then return false end
      local at = {}
      for _, e in ipairs(sec.ents) do
        local w, h = size(e.name)
        for ty = math.floor(e.y - h / 2 + 1e-6), math.floor(e.y - h / 2 + 1e-6) + h - 1 do
          for tx = math.floor(e.x - w / 2 + 1e-6), math.floor(e.x - w / 2 + 1e-6) + w - 1 do at[tx .. ":" .. ty] = e end
        end
      end
      for _, e in ipairs(sec.ents) do
        if e.name == NAMES.bras and e.role == "mall-bras" then
          local v = DV[e.dir]
          local pick, drop = at[tile(e.x + v[1], e.y + v[2])], at[tile(e.x - v[1], e.y - v[2])]
          if not (pick and drop) then return false end
        end
        if e.name == NAMES.tapis and e.carries == nil then return false end
      end
      if #sec.quais ~= 2 * 4 then return false end
      -- tapis continus jusqu'aux deux bouts
      local ends = 0
      for _, e in ipairs(sec.ents) do
        if e.name == NAMES.tapis then
          local v = DV[e.dir]
          local nxt = at[tile(e.x + v[1], e.y + v[2])]
          if not (nxt and nxt.name == NAMES.tapis) then ends = ends + 1 end
        end
      end
      if ends ~= 2 then return false end
      -- deux rangées distinctes
      local row2 = row_of(voies, 3); row2.j = 2
      local sec2 = M2.section(P, m, row2, 1, 3, NAMES, { ox = ox, oy = oy, k = M2.frame(s.dir) }, true)
      for _, e in ipairs(sec2.ents) do
        local w, h = size(e.name)
        for ty = math.floor(e.y - h / 2 + 1e-6), math.floor(e.y - h / 2 + 1e-6) + h - 1 do
          for tx = math.floor(e.x - w / 2 + 1e-6), math.floor(e.x - w / 2 + 1e-6) + w - 1 do
            if at[tx .. ":" .. ty] then return false end
          end
        end
      end
      local haut = {}
      for _, e in ipairs(sec.ents) do if e.recipe then haut[e.recipe] = true end end
      for i2 = 1, 3 do if not (haut["r-h" .. i2] and haut["r-b" .. i2]) then return false end end
      return true
    end)
    return ok and res or false
  end
  local mutants = {
    { "Mr.PERIODE = 4 ", "Mr.PERIODE = 3 ", "cellules qui se chevauchent (période 3)" },
    { "Mr.PORT_X = -4 ", "Mr.PORT_X = -1 ", "tête décalée sur les bras de la cellule" },
    { "c.carries = carries[p.k]", "c.carries = nil", "carries oublié sur le tapis de cellule" },
    { "c.recipe = (p.groupe == \"haut\") and cell.h or cell.b", "c.recipe = cell.h", "recette du bas perdue" },
    { "rot_pt(x, y + ((j or 1) - 1) * Mr.PITCH, k)", "rot_pt(x, y, k)", "toutes les rangées au même endroit" },
    { "for x = Mr.PORT_X, -1 do", "for x = Mr.PORT_X + 2, -1 do", "tapis de tête troué" },
    { "x = -4.5, y = 4.5", "x = -8.5, y = 4.5", "poteau de tête hors de portée" },
  }
  local killed = 0
  for _, mu in ipairs(mutants) do
    local res = run_mutant(mu[1], mu[2])
    local refused = res ~= true
    check(refused, "§6 mutant refusé : " .. mu[3] .. " (" .. tostring(res) .. ")")
    if refused then killed = killed + 1 end
  end
  print(string.format("[MALL-RANGEE] mutants refusés : %d/%d", killed, #mutants))
end

-- §4c tuiles libres de la réserve : aucune pièce d'une rangée n'y tombe, aux 4 orientations ; aller-retour du repère
do
  local floor = math.floor
  check(Mr.reserve_libre(10, 14, 6, 0) and Mr.reserve_libre(10, 29, 6, 0), "§4c passage entre deux rangées : libre")
  check(not Mr.reserve_libre(3, 14, 6, 0), "§4c tuile du poteau relais : réservée")
  check(not Mr.reserve_libre(10, 13, 6, 0) and not Mr.reserve_libre(10, 0, 6, 0), "§4c rangée : réservée")
  check(Mr.reserve_libre(-20, 5, 16, 3) and Mr.reserve_libre(5, -2, 16, 3) and Mr.reserve_libre(5, -4, 16, 3), "§4c hors de la place du tronc : libre")
  check(not Mr.reserve_libre(-5, -2, 16, 3) and not Mr.reserve_libre(-5, 14, 16, 3), "§4c place du tronc : réservée")
  check(Mr.reserve_libre(-5, -2, 6, 0), "§4c sans tronc, la bande nord n'est que la marge")
  for _, s in ipairs(SECTORS) do
    local ox, oy = Mr.origin(s)
    local k = Mr.frame(s.dir)
    local rx, ry = Mr.from_world(select(1, Mr.to_world(7.5, 22.5, 0, k, ox, oy, 1)), select(2, Mr.to_world(7.5, 22.5, 0, k, ox, oy, 1)), k, ox, oy)
    check(rx == 7.5 and ry == 22.5, "§4c aller-retour du repère, dir " .. s.dir)
    for _, j in ipairs({ 1, 3 }) do
      for _, voies in ipairs({ { "fer", "cuivre", "gear", "circ" }, { "fer" } }) do
        local row = row_of(voies, 3)
        row.j = j
        local rep = { ox = ox, oy = oy, k = k }
        local sec = Mr.section(P, modele(), row, 1, 3, NAMES, rep, true)
        local bad = 0
        for _, e in ipairs(sec.ents) do
          for _, t in ipairs(P.tiles_of(e)) do
            local cx, cy = Mr.from_world(t[1] + 0.5, t[2] + 0.5, k, ox, oy)
            if Mr.reserve_libre(floor(cx), floor(cy), Mr.TETE, 0) then bad = bad + 1 end
          end
        end
        check(bad == 0, string.format("§4c dir %d, rangée %d, %d voie(s) : aucune pièce sur une tuile dite libre (%d)", s.dir, j, #voies, bad))
      end
    end
  end
end

-- §4b capacité : ce que Mr.capacite annonce tient dans le secteur, marge comprise, aux 4 orientations, avec et sans la place du tronc ; un de plus ne tient pas
do
  local floor = math.floor
  local function inside(s, k, ox, oy, m, x, y)
    local wx, wy = Mr.to_world(x + 0.5, y + 0.5, 0, k, ox, oy, 1)
    local tx, ty = floor(wx), floor(wy)
    return tx >= s.x0 + m and tx <= s.x1 - 1 - m and ty >= s.y0 + m and ty <= s.y1 - 1 - m
  end
  for _, dir in ipairs({ 0, 2, 4, 6 }) do
    for _, place in ipairs({ { nil, nil }, { 16, 3 } }) do
      for _, size in ipairs({ { 60, 45 }, { 61, 46 }, { 64, 64 }, { 48, 75 }, { 47, 74 }, { 90, 62 } }) do
        local s = { x0 = 100, y0 = -40, x1 = 100 + size[1], y1 = -40 + size[2], dir = dir }
        local west, north = place[1], place[2]
        local tag = string.format("§4b dir %d, %dx%d, ouest %s, nord %s : ", dir, size[1], size[2], tostring(west), tostring(north))
        local rows, cells = Mr.capacite(s, west, north)
        local k = Mr.frame(dir)
        local ox, oy = Mr.origin(s, west, north)
        local m = Mr.MARGE
        local w0, n0 = -(west or Mr.TETE), -(north or 0)
        if rows > 0 and cells > 0 then
          local xe, ye = 4 * cells - 1, 15 * (rows - 1) + 13
          check(inside(s, k, ox, oy, m, w0, n0) and inside(s, k, ox, oy, m, xe, ye) and inside(s, k, ox, oy, m, w0, ye) and inside(s, k, ox, oy, m, xe, n0), tag .. "annoncé " .. rows .. "x" .. cells .. " : tient dans le secteur")
        end
        check(not inside(s, k, ox, oy, m, w0, 15 * rows + 13), tag .. "une rangée de plus ne tient pas (" .. rows .. ")")
        check(not inside(s, k, ox, oy, m, 4 * (cells + 1) - 1, n0), tag .. "une cellule de plus ne tient pas (" .. cells .. ")")
      end
    end
  end
end

-- s40 p6 : la dernière section vivante (une section refusée reste dans la liste)
do
  local a, b, c = { id = 1 }, { id = 2 }, { id = 3, dead = true }
  check(Mr.derniere({ a, b, c }) == b, "derniere : saute la section morte en fin de liste")
  check(Mr.derniere({ a, b }) == b, "derniere : la derniere quand elle vit")
  check(Mr.derniere({ c }) == nil and Mr.derniere({}) == nil and Mr.derniere(nil) == nil, "derniere : nil sans section vivante")
end

print(string.format("[MALL-RANGEE] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
