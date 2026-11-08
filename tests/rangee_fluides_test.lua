--[[
  Lot PETROLE-RANGEE, étape 2 : test hors jeu de la RANGÉE de modules sur bus (shared/ai3/rangee_fluides.lua, règle pure).
    §1 analyse d'un site de base (raffinerie, deux usines, bras, coffres, tuyaux de gaz, brut et eau) : module, prises, axe ;
    §2 plan : pas, bus, copies ; vérificateur indépendant (aucun chevauchement, aucun contact entre fluides, aucun tuyau sur un raccord
       qui n'attend pas son fluide, chaque prise reliée au réseau du site) ;
    §3 obstacles : la rangée s'arrête devant la première tuile bloquée, dans le sens qui en pose le plus ; cause dite ;
    §4 chantiers successifs : le pas et les bus d'un chantier précédent sont repris, les copies suivent sans trou ;
    §5 demande : consommation d'un module et nombre de modules ;
    §6 déterminisme ; MUTANTS.
  Lancement : lua5.2 tests/rangee_fluides_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local Rf = require("shared.ai3.rangee_fluides")

local pass, fail = 0, 0
local function check(c, msg)
  if c then pass = pass + 1 else fail = fail + 1; print("[RANGEE] ECHEC : " .. msg) end
end
local tkey, untkey = Rf.tkey, Rf.untkey
local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

-- relevé de test (raccords vanilla 1.1.91, direction nord ; les autres directions par rotation)
local function rot(p, d)
  local x, y = p[1], p[2]
  for _ = 1, d / 2 do x, y = -y, x end
  return { x, y }
end
local function boxes_of(spec)
  local out = {}
  for _, b in ipairs(spec) do
    local conns = {}
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      conns[d] = {}
      for _, p in ipairs(b.pts) do conns[d][#conns[d] + 1] = b.explicit and b.explicit[d] or rot(p, d) end
    end
    out[#out + 1] = { type = b.type, conns = conns }
  end
  return out
end
local REL = { entities = {
  refinery = { w = 5, h = 5, speed = 1, electric = true, boxes = boxes_of({ { type = "input", pts = { { -1, 3 } } }, { type = "input", pts = { { 1, 3 } } },
    { type = "output", pts = { { -2, -3 } } }, { type = "output", pts = { { 0, -3 } } }, { type = "output", pts = { { 2, -3 } } } }) },
  plant = { w = 3, h = 3, speed = 1, electric = true, boxes = boxes_of({ { type = "input", pts = { { -1, -2 } } }, { type = "input", pts = { { 1, -2 } } },
    { type = "output", pts = { { -1, 2 } } }, { type = "output", pts = { { 1, 2 } } } }) },
  pjack = { w = 3, h = 3, boxes = boxes_of({ { type = "output", pts = { { 1, -2 } }, explicit = { [0] = { 1, -2 }, [2] = { 2, -1 }, [4] = { -1, 2 }, [6] = { -2, 1 } } } }) },
  pump = { w = 1, h = 1, boxes = boxes_of({ { type = "output", pts = { { 0, 1 } } } }) },
  arm = { w = 1, h = 1, electric = true }, chest = { w = 1, h = 1 }, tube = { w = 1, h = 1 }, pole = { w = 1, h = 1 },
}, recipes = {
  ["oil-r"] = { energy = 5, ingredients = { { type = "fluid", name = "crude", amount = 100 } }, products = { { type = "fluid", name = "gas", amount = 45 } } },
  ["sulf"] = { energy = 1, ingredients = { { type = "fluid", name = "gas", amount = 30 }, { type = "fluid", name = "water", amount = 30 } }, products = {} },
} }

--- Site de base : raffinerie (brut au sud, gaz au nord), usine du plastique (gaz au nord), usine du soufre (gaz et eau au nord).
local function base_ents()
  local e = {}
  local function add(name, x, y, dir, role, extra)
    local t = { name = name, x = x, y = y, dir = dir or 0, role = role }
    for k, v in pairs(extra or {}) do t[k] = v end
    e[#e + 1] = t
  end
  add("refinery", 10.5, 10.5, 0, "machine", { recipe = "oil-r" })
  add("plant", 16.5, 10.5, 0, "machine", { recipe = "plastic" })
  add("plant", 23.5, 10.5, 0, "machine", { recipe = "sulf" })
  -- gaz : sorties de la raffinerie en (8, 7) (10, 7) (12, 7), tuyau le long de y = 7 jusqu'a x = 22 ; entrees des usines au nord
  for x = 8, 22 do add("tube", x + 0.5, 7.5, 0, "tuyau") end
  add("tube", 15.5, 8.5, 0, "tuyau"); add("tube", 17.5, 8.5, 0, "tuyau"); add("tube", 22.5, 8.5, 0, "tuyau")
  -- brut : chevalet en (9.5, 19.5), raccord (10, 17), tuyau vertical jusqu'a la rangee y = 13 (prises (9, 13) et (11, 13))
  add("pjack", 9.5, 19.5, 0, "extracteur")
  for y = 13, 17 do add("tube", 10.5, y + 0.5, 0, "tuyau") end
  add("tube", 9.5, 13.5, 0, "tuyau"); add("tube", 11.5, 13.5, 0, "tuyau")
  -- eau : pompe en (24.5, -6.5) (raccord (24, -6)), tuyau vertical jusqu'a la prise (24, 8)
  add("pump", 24.5, -6.5, 0, "pompe")
  for y = -6, 8 do add("tube", 24.5, y + 0.5, 0, "tuyau") end
  -- quai du plastique : bras et coffre sous l'usine, entre ses deux raccords inutilises (15, 12) et (17, 12)
  add("arm", 16.5, 12.5, 4, "bras-entree"); add("chest", 16.5, 13.5, 0, "quai")
  return e
end
local QUAIS = { { x = 16.5, y = 13.5, item = "coal" } }
local OUTS = { { x = 20.5, y = 14.5, at = 10 } }

local function analyzed(blocked_terrain)
  local mod, why = Rf.analyze(REL, base_ents(), { crude = "crude", water = "water", quais = QUAIS, outs = OUTS })
  return mod, why
end

--- Tuiles occupées par une entité (boîte du relevé).
local function tiles_of(e)
  local info = REL.entities[e.name]
  local w, h = info.w, info.h
  if e.dir == 2 or e.dir == 6 then w, h = h, w end
  local x0, y0 = math.floor(e.x - w / 2 + 0.01), math.floor(e.y - h / 2 + 0.01)
  local out = {}
  for ty = y0, y0 + h - 1 do for tx = x0, x0 + w - 1 do out[#out + 1] = { tx, ty } end end
  return out
end

--- Vérificateur INDÉPENDANT : monde = base + sortie du plan. Rend la liste des violations.
local function verify(plan, ents0, terrain, label)
  local bad = {}
  local function ko(m) if #bad < 6 then bad[#bad + 1] = (label or "") .. m end end
  local occ, pipes = {}, {}
  local all = {}
  for _, e in ipairs(ents0) do all[#all + 1] = e end
  for _, e in ipairs(plan.ents or {}) do all[#all + 1] = e end
  for _, e in ipairs(all) do
    if e.role == "tuyau" then
      pipes[tkey(math.floor(e.x), math.floor(e.y))] = pipes[tkey(math.floor(e.x), math.floor(e.y))] or "?"
    else
      for _, t in ipairs(tiles_of(e)) do
        local k = tkey(t[1], t[2])
        if occ[k] then ko(string.format("chevauchement de machines en (%d,%d)", t[1], t[2])) end
        occ[k] = e
        if terrain and terrain[k] then ko(string.format("entite sur un obstacle (%d,%d)", t[1], t[2])) end
      end
    end
  end
  -- fluide de chaque tuyau : le plan etiquette les tuyaux neufs ; les tuyaux de base par parcours depuis extracteur / pompe
  local lab = {}
  local base_pipes = {}
  for _, e in ipairs(ents0) do if e.role == "tuyau" then base_pipes[tkey(math.floor(e.x), math.floor(e.y))] = true end end
  local L0 = Rf.world0(REL, ents0)
  for k, v in pairs(L0) do lab[k] = v end
  for _, t in ipairs(plan.tubes or {}) do
    local k = tkey(t.x, t.y)
    if lab[k] and lab[k] ~= t.fluid then ko(string.format("tuyau neuf de %s sur un tuyau de %s en (%d,%d)", t.fluid, lab[k], t.x, t.y)) end
    if occ[k] then ko(string.format("tuyau sur une machine en (%d,%d)", t.x, t.y)) end
    if terrain and terrain[k] then ko(string.format("tuyau sur un obstacle (%d,%d)", t.x, t.y)) end
    lab[k] = t.fluid
  end
  -- aucun contact entre fluides differents
  for _, k in ipairs((function() local l = {} for kk in pairs(lab) do l[#l + 1] = kk end table.sort(l) return l end)()) do
    local x, y = untkey(k)
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      local g = lab[tkey(x + DV[d][1], y + DV[d][2])]
      if g and g ~= lab[k] then ko(string.format("%s contre %s en (%d,%d)", lab[k], g, x, y)) end
    end
  end
  -- raccords des machines : un tuyau sur un raccord doit etre du fluide attendu ; deux raccords de la meme boite partagent le fluide
  local conn_lab = {}
  for _, e in ipairs(all) do
    local info = REL.entities[e.name]
    if info and info.boxes and e.role == "machine" then
      for bi, b in ipairs(info.boxes) do
        for _, p in ipairs(b.conns[e.dir or 0]) do
          local tx, ty = math.floor(e.x + p[1] + 0.01), math.floor(e.y + p[2] + 0.01)
          local k = tkey(tx, ty)
          if lab[k] then
            -- le fluide de ce raccord sur la copie 0 (base) sert de reference : meme boite, meme fluide
            conn_lab[e.name .. ":" .. (e.recipe or "") .. ":" .. bi] = conn_lab[e.name .. ":" .. (e.recipe or "") .. ":" .. bi] or lab[k]
            if conn_lab[e.name .. ":" .. (e.recipe or "") .. ":" .. bi] ~= lab[k] then ko(string.format("raccord %d de %s alimente par %s au lieu de %s en (%d,%d)", bi, e.name,
              lab[k], conn_lab[e.name .. ":" .. (e.recipe or "") .. ":" .. bi], tx, ty)) end
          end
        end
      end
    end
  end
  -- connexite : toutes les tuiles du brut forment un seul reseau avec l'extracteur ; de meme l'eau
  for _, f in ipairs({ "brut", "eau" }) do
    local start
    for k, v in pairs(L0) do if v == f then start = start and math.min(start, k) or k end end
    local reach, stack = {}, { start }
    if start then reach[start] = true end
    while #stack > 0 do
      local k = table.remove(stack)
      local x, y = untkey(k)
      for _, d in ipairs({ 0, 2, 4, 6 }) do
        local nk = tkey(x + DV[d][1], y + DV[d][2])
        if lab[nk] == f and not reach[nk] then reach[nk] = true; stack[#stack + 1] = nk end
      end
    end
    for k, v in pairs(lab) do
      if v == f and not reach[k] then local x, y = untkey(k); ko(string.format("tuyau de %s isole en (%d,%d)", f, x, y)) end
    end
    -- chaque raccord de machine qui attend ce fluide est sur le reseau
    for _, e in ipairs(all) do
      if e.role == "machine" then
        local info = REL.entities[e.name]
        for bi, b in ipairs(info.boxes) do
          for _, p in ipairs(b.conns[e.dir or 0]) do
            local k = tkey(math.floor(e.x + p[1] + 0.01), math.floor(e.y + p[2] + 0.01))
            if lab[k] == f and not reach[k] then ko("raccord hors reseau de " .. f) end
          end
        end
      end
    end
  end
  return bad
end

local function req_of(terrain, extra)
  local ents0 = base_ents()
  local L0, conn0 = Rf.world0(REL, ents0)
  local occ = {}
  for _, e in ipairs(ents0) do
    if e.role == "tuyau" then occ[tkey(math.floor(e.x), math.floor(e.y))] = true
    else for _, t in ipairs(tiles_of(e)) do occ[tkey(t[1], t[2])] = true end end
  end
  terrain = terrain or {}
  local r = { blocked = function(tx, ty) local k = tkey(tx, ty); return occ[k] or terrain[k] or false end, L0 = L0, conn0 = conn0, kmax = 4 }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r, ents0
end

---------------------------------------------------------------------------------------------------
-- §1 analyse
---------------------------------------------------------------------------------------------------
local mod, why = analyzed()
check(mod ~= nil, "§1 le site de base est analyse : " .. tostring(why))
if mod then
  check(mod.axis == "h", "§1 axe horizontal (prises sur des rangees)")
  check(mod.taps.brut and #mod.taps.brut.tiles == 2 and mod.taps.brut.out == 4, "§1 deux prises de brut, sortant au sud")
  check(mod.taps.eau and #mod.taps.eau.tiles == 1 and mod.taps.eau.out == 0, "§1 une prise d'eau, sortant au nord")
  local nm, nt = 0, 0
  for _, e in ipairs(mod.ents) do if e.role == "machine" then nm = nm + 1 end if e.role == "tuyau" then nt = nt + 1 end end
  check(nm == 3, "§1 trois machines dans le module")
  check(nt == 15 + 3, "§1 dix-huit tuyaux de gaz dans le module (" .. nt .. ")")
  local nx = 0
  for _, e in ipairs(mod.ents) do if e.role == "extracteur" or e.role == "pompe" then nx = nx + 1 end end
  check(nx == 0, "§1 ni chevalet ni pompe dans le module")
  check(mod.lo == 8 and mod.hi == 24, "§1 emprise le long de l'axe : 8 a 24 (" .. mod.lo .. " a " .. mod.hi .. ")")
  -- prises sur deux rangees differentes : refus
  local ents = base_ents()
  for _, e in ipairs(ents) do if e.role == "tuyau" and e.x == 11.5 and e.y == 13.5 then e.y = 14.5 end end
  ents = base_ents()
  ents[#ents + 1] = { name = "plant", x = 4.5, y = 10.5, dir = 4, role = "machine", recipe = "x" }
  for _, t in ipairs({ { 3, 12 }, { 4, 12 }, { 5, 12 }, { 5, 13 }, { 6, 13 }, { 7, 13 }, { 8, 13 } }) do
    ents[#ents + 1] = { name = "tube", x = t[1] + 0.5, y = t[2] + 0.5, dir = 0, role = "tuyau" }
  end
  local m2, w2 = Rf.analyze(REL, ents, { crude = "crude", water = "water" })
  check(m2 == nil and tostring(w2):find("plusieurs rangees", 1, true) ~= nil, "§1 prises de brut sur deux rangees : refus (" .. tostring(w2) .. ")")
  -- aucune machine : refus
  local m3, w3 = Rf.analyze(REL, { { name = "tube", x = 1.5, y = 1.5, role = "tuyau" } }, {})
  check(m3 == nil and type(w3) == "string", "§1 sans machine : refus avec cause")
end

---------------------------------------------------------------------------------------------------
-- §2 plan
---------------------------------------------------------------------------------------------------
local req2, ents2 = req_of()
local plan2 = Rf.plan(mod, req2)
check(plan2.n == 4, "§2 quatre copies posees (" .. tostring(plan2.n) .. ", cause : " .. tostring(plan2.cause) .. ")")
check(plan2.dx and plan2.dx >= mod.hi - mod.lo + 2, "§2 pas au moins la largeur du module + 1 (" .. tostring(plan2.dx) .. ")")
check(plan2.hs and plan2.hs.brut >= 1 and plan2.hs.eau >= 3, "§2 bus du brut a >= 1 tuile des prises (le coffre est sur la rangee), bus de l'eau a >= 3 (le gaz longe la rangee 7) : h = "
  .. tostring(plan2.hs and plan2.hs.brut) .. "/" .. tostring(plan2.hs and plan2.hs.eau))
local bad2 = verify(plan2, ents2, nil, "§2 ")
for _, b in ipairs(bad2) do print("[RANGEE]   " .. b) end
check(#bad2 == 0, "§2 verificateur independant : aucune violation (" .. #bad2 .. ")")
do
  local nm = 0
  for _, e in ipairs(plan2.ents) do if e.role == "machine" then nm = nm + 1 end end
  check(nm == 12, "§2 12 machines pour 4 copies (" .. nm .. ")")
  check(#plan2.quais == 4 and #plan2.outs == 4, "§2 un quai et une sortie par copie")
  if #plan2.quais == 4 then
    local step = plan2.dx * plan2.sign
    check(plan2.quais[1].x == QUAIS[1].x + step and plan2.quais[4].x == QUAIS[1].x + 4 * step and plan2.quais[1].y == QUAIS[1].y and plan2.quais[1].item == "coal",
      "§2 quais translates du pas")
  end
  -- les recettes sont gardees
  local rec = {}
  for _, e in ipairs(plan2.ents) do if e.recipe then rec[e.recipe] = (rec[e.recipe] or 0) + 1 end end
  check(rec["oil-r"] == 4 and rec["plastic"] == 4 and rec["sulf"] == 4, "§2 recettes gardees")
  -- aucun tuyau de plan sur un tuyau deja la
  local seen = {}
  local dup = 0
  for _, t in ipairs(plan2.tubes) do
    local k = tkey(t.x, t.y)
    if seen[k] then dup = dup + 1 end
    seen[k] = true
    if req2.L0[k] == t.fluid then dup = dup + 1 end
  end
  check(dup == 0, "§2 aucun tuyau en double ni deja au site de base (" .. dup .. ")")
end

---------------------------------------------------------------------------------------------------
-- §3 obstacles
---------------------------------------------------------------------------------------------------
do
  local step = plan2.dx * plan2.sign
  -- un mur de falaise sur la route des copies 3 et 4 (dans le sens choisi)
  local terrain = {}
  for _, sg in ipairs({ 1, -1 }) do
    local wallx = 10 + 3 * step * sg
    for ty = -2, 20 do for tx = wallx, wallx + 1 do terrain[tkey(tx, ty)] = true end end
  end
  local r3, ents3 = req_of(terrain)
  local p3 = Rf.plan(mod, r3)
  check(p3.n == 2, "§3 murs a trois pas des deux cotes : la rangee s'arrete devant la falaise apres 2 copies (" .. p3.n .. ")")
  local bad3 = verify(p3, ents3, terrain, "§3 ")
  check(#bad3 == 0, "§3 mur : verificateur sans violation (" .. #bad3 .. ")")
  -- le sens contraire est libre : il est choisi quand l'autre est bloque tout de suite
  local terrain2 = {}
  for ty = -10, 30 do for tx = 30, 32 do terrain2[tkey(tx, ty)] = true end end
  local r4, ents4 = req_of(terrain2)
  local p4 = Rf.plan(mod, r4)
  check(p4.n >= 1 and p4.sign == -1, "§3 obstacle juste a droite : la rangee part a gauche (sens " .. tostring(p4.sign) .. ", " .. p4.n .. " copies)")
  check(#verify(p4, ents4, terrain2, "§3b ") == 0, "§3 sens inverse verifie")
  -- obstacle des deux cotes : aucune copie, cause dite
  local terrain3 = {}
  for ty = -10, 30 do for tx = 30, 32 do terrain3[tkey(tx, ty)] = true end for tx = -12, -10 do terrain3[tkey(tx, ty)] = true end end
  local r5 = req_of(terrain3)
  local p5 = Rf.plan(mod, r5)
  check(p5.n == 0 and type(p5.cause) == "string" and p5.cause ~= "", "§3 bloque des deux cotes : zero copie avec cause (" .. tostring(p5.cause) .. ")")
  -- le premier pas est bloque par un mur d'une colonne (rangees 7 a 12) dans les deux sens : un autre pas passe
  local terr = {}
  for ty = 7, 12 do terr[tkey(8 + plan2.dx, ty)] = true; terr[tkey(24 - plan2.dx, ty)] = true end
  local r7 = req_of(terr)
  local p7 = Rf.plan(mod, r7)
  check(p7.n >= 1 and p7.dx ~= plan2.dx, "§3 pas bloque par un mur d'une colonne : un autre pas est choisi (" .. tostring(p7.n) .. " copies, pas " .. tostring(p7.dx) .. " contre " .. tostring(plan2.dx) .. ")")
  check(#verify(p7, ents2, terr, "§3c ") == 0, "§3 autre pas verifie")
  -- un tuyau d'un autre fluide sur la route du bus : la copie qui le toucherait n'est pas posee
  local r6 = req_of()
  r6.L0 = (function() local l = {} for k, v in pairs(req2.L0) do l[k] = v end l[tkey(plan2.dx * plan2.sign * 2 + 24, 20)] = "interne" return l end)()
  local p6 = Rf.plan(mod, r6)
  check(p6.n >= 1, "§3 tuyau etranger lointain : la rangee continue (" .. p6.n .. ")")
end

---------------------------------------------------------------------------------------------------
-- §4 chantiers successifs
---------------------------------------------------------------------------------------------------
do
  local r, ents = req_of(nil, { kmax = 2 })
  local a = Rf.plan(mod, r)
  check(a.n == 2, "§4 premier chantier : 2 copies (" .. a.n .. ")")
  -- le monde du second chantier : base + premier plan poses
  local world_ents = base_ents()
  for _, e in ipairs(a.ents) do world_ents[#world_ents + 1] = e end
  for _, t in ipairs(a.tubes) do world_ents[#world_ents + 1] = { name = "tube", x = t.x + 0.5, y = t.y + 0.5, dir = 0, role = "tuyau" } end
  local L0, conn0 = Rf.world0(REL, world_ents)
  local occ = {}
  for _, e in ipairs(world_ents) do
    if e.role == "tuyau" then occ[tkey(math.floor(e.x), math.floor(e.y))] = true
    else for _, t in ipairs(tiles_of(e)) do occ[tkey(t[1], t[2])] = true end end
  end
  local r2b = { blocked = function(tx, ty) return occ[tkey(tx, ty)] or false end, L0 = L0, conn0 = conn0, kmax = 2, from = 3,
    fixed = { dx = a.dx, sign = a.sign, hs = a.hs } }
  local b = Rf.plan(mod, r2b)
  check(b.n == 2, "§4 second chantier : 2 copies de plus (" .. b.n .. ", " .. tostring(b.cause) .. ")")
  check(b.dx == a.dx and b.sign == a.sign, "§4 meme pas, meme sens")
  -- le monde du second chantier = 4 copies : identique au plan d'un seul chantier de 4
  local full = Rf.plan(mod, req_of(nil, { kmax = 4 }))
  local function tubes_sig(list)
    local t = {}
    for _, x in ipairs(list) do t[#t + 1] = string.format("%d,%d,%s", x.x, x.y, x.fluid) end
    table.sort(t)
    return table.concat(t, "|")
  end
  local both = {}
  for _, x in ipairs(a.tubes) do both[#both + 1] = x end
  for _, x in ipairs(b.tubes) do both[#both + 1] = x end
  check(tubes_sig(both) == tubes_sig(full.tubes), "§4 deux chantiers de 2 = un chantier de 4 (memes tuyaux)")
  local full_world = base_ents()
  for _, e in ipairs(a.ents) do full_world[#full_world + 1] = e end
  for _, e in ipairs(b.ents) do full_world[#full_world + 1] = e end
  local bothp = { ents = {}, tubes = both }
  for _, e in ipairs(a.ents) do bothp.ents[#bothp.ents + 1] = e end
  for _, e in ipairs(b.ents) do bothp.ents[#bothp.ents + 1] = e end
  check(#verify(bothp, base_ents(), nil, "§4 ") == 0, "§4 les quatre copies verifiees ensemble")
end

---------------------------------------------------------------------------------------------------
-- §5 demande
---------------------------------------------------------------------------------------------------
do
  local cells = { { recipe = "oil-r", machine = "refinery" }, { recipe = "plastic", machine = "plant" }, { recipe = "sulf", machine = "plant" } }
  REL.recipes.plastic = { energy = 1, ingredients = { { type = "fluid", name = "gas", amount = 20 }, { type = "item", name = "coal", amount = 1 } }, products = {} }
  check(math.abs(Rf.use(REL, cells, "crude") - 20) < 1e-9, "§5 le module consomme 20 unites de brut par seconde (100 par 5 s)")
  check(math.abs(Rf.use(REL, cells, "gas") - 50) < 1e-9, "§5 et 50 unites de gaz par seconde (20 + 30)")
  REL.entities.refinery.speed = 2
  check(math.abs(Rf.use(REL, cells, "crude") - 40) < 1e-9, "§5 la vitesse de la machine compte")
  REL.entities.refinery.speed = 1
  check(Rf.count(200, 20, 8) == 8 and Rf.count(100, 20, 8) == 5 and Rf.count(19, 20, 8) == 1 and Rf.count(0, 20, 8) == 1 and Rf.count(1000, 20, 8) == 8,
    "§5 nombre de modules : borne a 1 et a kmax")
  check(Rf.count(nil, 20, 8) == 1 and Rf.count(100, 0, 8) == 1, "§5 donnees absentes : un module")
end

---------------------------------------------------------------------------------------------------
-- §7 implantation (Fl.ext_step, mode rangée) : entités posées, poteaux qui alimentent les machines et les bras
---------------------------------------------------------------------------------------------------
do
  local Fl = require("shared.ai3.fluides")
  local r7, ents7 = req_of(nil, { kmax = 2 })
  local job = Fl.layout_new()
  local req = { mod = mod, ents = REL.entities, conduit = "tube", poles = { name = "pole", supply = 3.5, wire = 9 }, network = { x = 40.5, y = 20.5, wire = 9 },
    blocked = r7.blocked, L0 = r7.L0, conn0 = r7.conn0, kmax = 2, from = 1 }
  local st, lay = Fl.ext_step(req, job, 600)
  check(st == "done" and lay and lay.copies == 2, "§7 rangee de 2 copies implantee : " .. tostring(st) .. " " .. tostring(lay and lay.copies or lay))
  if st == "done" then
    local nm, npole, ntube = 0, 0, 0
    for _, e in ipairs(lay.ents) do
      if e.role == "machine" then nm = nm + 1 elseif e.role == "tuyau" then ntube = ntube + 1 elseif e.role == "poteau" or e.role == "liaison" then npole = npole + 1 end
    end
    check(nm == 6 and ntube == lay.pipes and npole == lay.poles, "§7 6 machines, tuyaux et poteaux comptes (" .. nm .. "/" .. ntube .. "/" .. npole .. ")")
    local poles = {}
    for _, e in ipairs(lay.ents) do if e.role == "poteau" or e.role == "liaison" then poles[#poles + 1] = e end end
    local unpowered = 0
    for _, e in ipairs(lay.ents) do
      if e.role == "machine" or e.role == "bras-entree" then
        local ok = false
        for _, t in ipairs(tiles_of(e)) do
          for _, pl in ipairs(poles) do
            if math.abs(pl.x - (t[1] + 0.5)) < 3.5 + 0.5 and math.abs(pl.y - (t[2] + 0.5)) < 3.5 + 0.5 then ok = true end
          end
        end
        if not ok then unpowered = unpowered + 1 end
      end
    end
    check(unpowered == 0, "§7 chaque machine et chaque bras est dans la zone d'un poteau (" .. unpowered .. " sans courant)")
    check(#lay.quais == 2 and #lay.outs == 2, "§7 quais et sorties des copies")
    -- sans poteau configure : refus
    local job2 = Fl.layout_new()
    local req2b = {}
    for k, v in pairs(req) do req2b[k] = v end
    req2b.poles = nil
    local st2, why2 = Fl.ext_step(req2b, job2, 600)
    check(st2 == "fail" and tostring(why2):find("poteau", 1, true) ~= nil, "§7 sans poteau : refus (" .. tostring(why2) .. ")")
  end
  -- aucune copie : refus avec la cause
  local terrain = {}
  for ty = -10, 30 do for tx = 30, 32 do terrain[tkey(tx, ty)] = true end for tx = -12, -10 do terrain[tkey(tx, ty)] = true end end
  local r8 = req_of(terrain, { kmax = 2 })
  local job3 = Fl.layout_new()
  local st3, why3 = Fl.ext_step({ mod = mod, ents = REL.entities, conduit = "tube", poles = req.poles, blocked = r8.blocked, L0 = r8.L0, conn0 = r8.conn0, kmax = 2, from = 1 }, job3, 600)
  check(st3 == "fail" and tostring(why3):find("aucune copie", 1, true) ~= nil, "§7 bloque des deux cotes : refus (" .. tostring(why3) .. ")")
end

---------------------------------------------------------------------------------------------------
-- §6 déterminisme et mutants
---------------------------------------------------------------------------------------------------
local function sig(plan)
  local t = { tostring(plan.n), tostring(plan.dx), tostring(plan.sign), tostring(plan.hs and plan.hs.brut), tostring(plan.hs and plan.hs.eau) }
  for _, e in ipairs(plan.ents) do t[#t + 1] = string.format("%s,%.1f,%.1f,%d", e.name, e.x, e.y, e.dir) end
  for _, x in ipairs(plan.tubes) do t[#t + 1] = string.format("%d,%d,%s", x.x, x.y, x.fluid) end
  return table.concat(t, "|")
end
check(sig(Rf.plan(mod, req_of())) == sig(plan2), "§6 deux plans identiques")

local function read(p) local fh = assert(io.open(p, "rb")); local s = fh:read("*a"); fh:close(); return s end
local SRC = read("shared/ai3/rangee_fluides.lua")

local function failures(M)
  local ok, m = pcall(M.analyze, REL, base_ents(), { crude = "crude", water = "water", quais = QUAIS, outs = OUTS })
  if not ok or not m then return 99 end
  local n = 0
  local L0, conn0 = M.world0(REL, base_ents())
  local ents0 = base_ents()
  local occ = {}
  for _, e in ipairs(ents0) do
    if e.role == "tuyau" then occ[tkey(math.floor(e.x), math.floor(e.y))] = true
    else for _, t in ipairs(tiles_of(e)) do occ[tkey(t[1], t[2])] = true end end
  end
  local function plan_with(terrain, extra)
    terrain = terrain or {}
    local r = { blocked = function(tx, ty) local k = tkey(tx, ty); return occ[k] or terrain[k] or false end, L0 = L0, conn0 = conn0, kmax = 4 }
    for k, v in pairs(extra or {}) do r[k] = v end
    local okp, p = pcall(M.plan, m, r)
    return okp and p or nil, terrain
  end
  local p, _ = plan_with()
  if not p then return n + 99 end
  if p.n ~= 4 then n = n + 1 end
  n = n + #verify(p, ents0, nil, "")
  if not (p.hs and p.hs.brut >= 1 and p.hs.eau >= 3) then n = n + 1 end
  if not (#p.quais == 4 and p.quais[1] and p.quais[1].x == QUAIS[1].x + p.dx * p.sign) then n = n + 1 end
  -- mur
  local step = p.dx * p.sign
  local terrain = {}
  for _, sg in ipairs({ 1, -1 }) do
    for ty = -2, 20 do for tx = 10 + 3 * step * sg, 10 + 3 * step * sg + 1 do terrain[tkey(tx, ty)] = true end end
  end
  local p3 = plan_with(terrain)
  if not p3 then return n + 99 end
  if p3.n ~= 2 then n = n + 1 end
  n = n + #verify(p3, ents0, terrain, "")
  -- obstacle a droite
  local t2 = {}
  for ty = -10, 30 do for tx = 30, 32 do t2[tkey(tx, ty)] = true end end
  local p4 = plan_with(t2)
  if not (p4 and p4.n >= 1 and p4.sign == -1) then n = n + 1 else n = n + #verify(p4, ents0, t2, "") end
  -- des deux cotes
  local t3 = {}
  for ty = -10, 30 do for tx = 30, 32 do t3[tkey(tx, ty)] = true end for tx = -12, -10 do t3[tkey(tx, ty)] = true end end
  local p5 = plan_with(t3)
  if not (p5 and p5.n == 0 and p5.cause) then n = n + 1 end
  -- pas bloque par un mur d'une colonne
  local terr = {}
  for ty = 7, 12 do terr[tkey(8 + p.dx, ty)] = true; terr[tkey(24 - p.dx, ty)] = true end
  local p7 = plan_with(terr)
  if not (p7 and p7.n >= 1 and p7.dx ~= p.dx) then n = n + 1 end
  -- chantiers successifs
  local a = plan_with(nil, { kmax = 2 })
  if not a or a.n ~= 2 then return n + 1 end
  local wents = base_ents()
  for _, e in ipairs(a.ents) do wents[#wents + 1] = e end
  for _, t in ipairs(a.tubes) do wents[#wents + 1] = { name = "tube", x = t.x + 0.5, y = t.y + 0.5, dir = 0, role = "tuyau" } end
  local L1, c1 = M.world0(REL, wents)
  local occ1 = {}
  for _, e in ipairs(wents) do
    if e.role == "tuyau" then occ1[tkey(math.floor(e.x), math.floor(e.y))] = true
    else for _, t in ipairs(tiles_of(e)) do occ1[tkey(t[1], t[2])] = true end end
  end
  local okb, b = pcall(M.plan, m, { blocked = function(tx, ty) return occ1[tkey(tx, ty)] or false end, L0 = L1, conn0 = c1, kmax = 2, from = 3,
    fixed = { dx = a.dx, sign = a.sign, hs = a.hs } })
  if not (okb and b and b.n == 2) then n = n + 1 else
    local both = { ents = {}, tubes = {} }
    for _, x in ipairs(a.tubes) do both.tubes[#both.tubes + 1] = x end
    for _, x in ipairs(b.tubes) do both.tubes[#both.tubes + 1] = x end
    for _, e in ipairs(a.ents) do both.ents[#both.ents + 1] = e end
    for _, e in ipairs(b.ents) do both.ents[#both.ents + 1] = e end
    n = n + #verify(both, ents0, nil, "")
  end
  -- terrain libre : le sens + l'emporte a egalite ; aucun tuyau neuf ne double un tuyau du site
  if p.sign ~= 1 then n = n + 1 end
  for _, t in ipairs(p.tubes) do if L0[tkey(t.x, t.y)] == t.fluid then n = n + 1 end end
  -- prises sur deux rangees
  local ents = base_ents()
  ents[#ents + 1] = { name = "plant", x = 4.5, y = 10.5, dir = 4, role = "machine", recipe = "x" }
  for _, t in ipairs({ { 3, 12 }, { 4, 12 }, { 5, 12 }, { 5, 13 }, { 6, 13 }, { 7, 13 }, { 8, 13 } }) do
    ents[#ents + 1] = { name = "tube", x = t[1] + 0.5, y = t[2] + 0.5, dir = 0, role = "tuyau" }
  end
  local mm = M.analyze(REL, ents, { crude = "crude", water = "water" })
  if mm ~= nil then n = n + 1 end
  -- module fait a la main : un raccord inutilise sur la rangee des prises fait monter le bus d'une tuile
  local hand = { axis = "h", ents = {}, quais = {}, outs = {}, label0 = {}, lo = 0, hi = 1,
    tiles = { { 0, 0, "m" }, { 1, 0, "m" } }, conns = { { 3, 2, false } },
    taps = { brut = { tiles = { { tx = 0, ty = 2, out = 4 } }, out = 4 } } }
  local okh, ph = pcall(M.plan, hand, { blocked = function() return false end, L0 = {}, conn0 = {}, kmax = 2 })
  if not (okh and ph and ph.n == 2 and ph.hs.brut >= 1) then n = n + 1 end
  -- demande
  local cells = { { recipe = "oil-r", machine = "refinery" } }
  if math.abs(M.use(REL, cells, "crude") - 20) > 1e-9 then n = n + 1 end
  REL.entities.refinery.speed = 2
  if math.abs(M.use(REL, cells, "crude") - 40) > 1e-9 then n = n + 1 end
  REL.entities.refinery.speed = 1
  if M.count(100, 20, 8) ~= 5 or M.count(110, 20, 8) ~= 5 or M.count(5, 20, 8) ~= 1 or M.count(1000, 20, 8) ~= 8 then n = n + 1 end
  return n
end

check(failures(Rf) == 0, "§6 le module non mute passe les scenes des mutants")

local function mutate(name, from, to)
  local i, j = SRC:find(from, 1, true)
  if not i then print("[RANGEE] ECHEC : mutant '" .. name .. "' : motif introuvable"); fail = fail + 1; return end
  local chunk, err = load(SRC:sub(1, i - 1) .. to .. SRC:sub(j + 1), "=mutant", "t")
  if not chunk then print("[RANGEE] ECHEC : mutant '" .. name .. "' ne compile pas : " .. tostring(err)); fail = fail + 1; return end
  local okm, nres = pcall(failures, chunk())
  check((not okm) or nres > 0, "mutant '" .. name .. "' survit")
end

mutate("pas juge sur une seule copie", "local ks = { 0, 1, 2 }", "local ks = { 0 }")
mutate("hauteur des bus toujours nulle", "local hlist = {}", "local hlist = { brut = 0, eau = 0 }; Rf.HMAX = 0")
mutate("contact des fluides ignore", "if g and g ~= \"m\" and g ~= lab then", "if false then")
mutate("raccord inutilise permis", "if lab and lab ~= \"m\" and lab ~= c[3] then", "if false then")
mutate("obstacle ignore", "if req.blocked(x, y) then\n              fails =", "if false then\n              fails =")
mutate("un seul sens essaye", "if n2 > np then dx, hs, sign, np, cp = c.dx, c.hs, -1, n2, c2 end", "")
mutate("sens inverse prefere", "if n2 > np then dx, hs, sign, np, cp = c.dx, c.hs, -1, n2, c2 end", "if n2 >= np then dx, hs, sign, np, cp = c.dx, c.hs, -1, n2, c2 end")
mutate("un seul candidat de pas", "if #cands >= Rf.CANDS then break end", "if #cands >= 1 then break end")
mutate("quais non translates", "out.quais[#out.quais + 1] = { x = x, y = y, item = q.item, flow = q.flow }", "out.quais[#out.quais + 1] = { x = q.x, y = q.y, item = q.item, flow = q.flow }")
mutate("tuyaux deja au site refaits", "if lab ~= \"m\" and E0[key] ~= lab and req.L0[key] ~= lab then", "if lab ~= \"m\" and E0[key] ~= lab then")
mutate("consommation sans la vitesse", "local dur = (r.energy and r.energy > 0) and r.energy / speed or 0", "local dur = (r.energy and r.energy > 0) and r.energy or 0")
mutate("nombre de modules arrondi au plus proche", "local n = floor(supply / use + 1e-9)", "local n = floor(supply / use + 0.5)")
mutate("nombre de modules sans plafond", "if n > kmax then n = kmax end", "")
mutate("chantier suivant sans pas fixe", "cands[1] = { dx = req.fixed.dx, hs = req.fixed.hs }", "cands[1] = { dx = req.fixed.dx + 1, hs = req.fixed.hs }")
mutate("prises sur deux rangees acceptees", "if horiz and t.ty ~= list[1].ty then return nil, \"prises du fluide \" .. f .. \" sur plusieurs rangees\" end", "")

print(string.format("[RANGEE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
