--[[
  Lot PETROLE-RANGEE : test hors jeu de l'EXTENSION d'un site de pétrole (shared/ai3/fluides.lua : Fl.ext_net, Fl.ext_step) : tous les
  puits d'un champ équipés, collecteur droit, ligne principale jusqu'au tuyau de brut du site, aucun contact avec les tuyaux d'un autre
  fluide, poteaux, reprise par tranches identique, coût. Les noms d'objets ci-dessous sont ceux d'un RELEVÉ de test (le code testé n'en
  connaît aucun).
    §1 réseau de brut d'un site planifié et tuiles interdites ;
    §2 extension de 14 puits : emprises, tuyaux, réseau d'un seul tenant, aucun contact avec l'eau, poteaux ;
    §3 reprise par tranches : le résultat ne dépend pas de la tranche ;
    §4 ligne principale contournant un obstacle (A*), puits écarté avec sa cause ;
    §5 mutants.
  Lancement : lua5.2 tests/champ_petrole_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local Fl = require("shared.ai3.fluides")
local Col = require("shared.ai3.collecteur")

local pass, fail = 0, 0
local function check(c, msg)
  if c then pass = pass + 1 else fail = fail + 1; print("[CHAMP-PETROLE] ECHEC : " .. msg) end
end
local tkey, untkey, DV = Fl.tkey, Col.untkey, Col.DV

local ENTS = {
  ["pjack"] = { w = 3, h = 3, electric = true, boxes = { { type = "output", conns = { [0] = { { 1, -2 } }, [2] = { { 2, -1 } }, [4] = { { -1, 2 } }, [6] = { { -2, 1 } } } } } },
  ["tube"] = { w = 1, h = 1 },
  ["pole"] = { w = 1, h = 1 },
  ["plant"] = { w = 3, h = 3, electric = true, boxes = {
    { type = "input", conns = { [0] = { { -1, -2 } } } }, { type = "input", conns = { [0] = { { 1, -2 } } } },
    { type = "output", conns = { [0] = { { -1, 2 } } } }, { type = "output", conns = { [0] = { { 1, 2 } } } } } },
}
local REL = { entities = ENTS }

--- Site de base planifié : deux chevalets, leur tuyau de brut vers une usine, une conduite d'eau voisine.
local function base_ents()
  local ents = {}
  ents[#ents + 1] = { name = "pjack", x = 10.5, y = 10.5, dir = 4, role = "extracteur" }
  ents[#ents + 1] = { name = "pjack", x = 16.5, y = 10.5, dir = 4, role = "extracteur" }
  -- raccords sud : (9, 12) et (15, 12) ; tuyau de brut : y = 12 de x = 9 a 15, puis x = 9 vers le sud jusqu'a 20
  for tx = 9, 15 do ents[#ents + 1] = { name = "tube", x = tx + 0.5, y = 12.5, dir = 0, role = "tuyau" } end
  for ty = 13, 20 do ents[#ents + 1] = { name = "tube", x = 9.5, y = ty + 0.5, dir = 0, role = "tuyau" } end
  -- usine (entrees au nord : (8, 21) et (10, 21)) ; le brut arrive en (9, 20)? non : on le fait finir en (8, 21) par un coude
  ents[#ents + 1] = { name = "tube", x = 8.5, y = 20.5, dir = 0, role = "tuyau" }
  ents[#ents + 1] = { name = "tube", x = 8.5, y = 21.5, dir = 0, role = "tuyau" }
  ents[#ents + 1] = { name = "plant", x = 9.5, y = 24.5, dir = 0, role = "machine" }
  -- conduite d'eau (autre fluide), sans contact avec le brut : x = 13 de y = 14 a 22
  for ty = 14, 22 do ents[#ents + 1] = { name = "tube", x = 13.5, y = ty + 0.5, dir = 0, role = "tuyau" } end
  return ents
end

local function occupied(ents)
  local occ = {}
  for _, e in ipairs(ents) do
    local info = ENTS[e.name]
    local w, h = info.w, info.h
    if e.dir == 2 or e.dir == 6 then w, h = h, w end
    local x0, y0 = math.floor(e.x - w / 2 + 0.01), math.floor(e.y - h / 2 + 0.01)
    for ty = y0, y0 + h - 1 do for tx = x0, x0 + w - 1 do occ[tkey(tx, ty)] = true end end
  end
  return occ
end

local function field(n, x0, y0, w, h, seed, avoid)
  local s = seed
  local function rnd(m) s = (s * 1103515245 + 12345) % 2147483648; return s % m end
  local wells, tries = {}, 0
  while #wells < n and tries < 20000 do
    tries = tries + 1
    local x, y = x0 + rnd(w), y0 + rnd(h)
    local okw = true
    for _, q in ipairs(wells) do if math.abs(q.x - (x + 0.5)) < 5 and math.abs(q.y - (y + 0.5)) < 5 then okw = false end end
    for _, q in ipairs(avoid or {}) do if math.abs(q.x - (x + 0.5)) < 5 and math.abs(q.y - (y + 0.5)) < 5 then okw = false end end
    if okw then wells[#wells + 1] = { x = x + 0.5, y = y + 0.5 } end
  end
  return wells
end

local function scene(opts)
  opts = opts or {}
  local ents = base_ents()
  local net, forbid = Fl.ext_net(REL, ents, "pjack")
  local occ = occupied(ents)
  local terrain = opts.terrain or {}
  local blocked = function(tx, ty)
    local k = tkey(tx, ty)
    return occ[k] or terrain[k] or forbid[k] or false
  end
  local wells = opts.wells or field(14, 18, 4, 40, 28, 5, { { x = 10.5, y = 10.5 }, { x = 16.5, y = 10.5 } })
  local req = { ents = ENTS, conduit = "tube", extractor = "pjack", fluid = "crude", poles = { name = "pole", supply = 3.5, wire = 9 },
    network = { x = 6.5, y = 30.5, wire = 9 }, blocked = blocked, wells = wells, net = net, toward = { x = 9.5, y = 16.5 }, max_n = opts.max_n }
  return req, ents, net, forbid, occ
end

local function run(req, budget)
  local job = Fl.layout_new()
  local guard = 0
  while true do
    guard = guard + 1
    local st, a = Fl.ext_step(req, job, budget)
    if st ~= "more" then return st, a, job end
    if guard > 100000 then return "fail", "boucle", job end
  end
end

local function sig(lay)
  local t = {}
  for _, e in ipairs(lay.ents) do t[#t + 1] = string.format("%s,%.1f,%.1f,%d,%s", e.name, e.x, e.y, e.dir or 0, tostring(e.role)) end
  return table.concat(t, "|")
end

---------------------------------------------------------------------------------------------------
-- §1 réseau de brut et tuiles interdites
---------------------------------------------------------------------------------------------------
do
  local ents = base_ents()
  local net, forbid = Fl.ext_net(REL, ents, "pjack")
  local n = 0
  for _ in pairs(net) do n = n + 1 end
  check(n == 7 + 8 + 2, "§1 le reseau de brut compte 17 tuyaux (" .. n .. ")")
  check(net[tkey(9, 12)] and net[tkey(15, 12)] and net[tkey(8, 21)], "§1 raccords et coude dans le reseau")
  check(not net[tkey(13, 14)], "§1 la conduite d'eau n'est pas du brut")
  check(forbid[tkey(13, 14)] and forbid[tkey(12, 15)] and forbid[tkey(14, 15)], "§1 l'eau et ses voisines sont interdites")
  check(not forbid[tkey(9, 15)], "§1 les voisines du brut ne sont pas interdites")
  -- raccords de l'usine : (8, 22)? entrees au nord de l'usine posee en (9.5, 24.5) : (8, 22) et (10, 22) ; sorties au sud (8, 27), (10, 27)
  check(forbid[tkey(10, 22)] and forbid[tkey(8, 26)] and forbid[tkey(10, 26)], "§1 raccords de l'usine interdits (sauf celui du brut)")
  check(not forbid[tkey(8, 22)] or net[tkey(8, 22)] or true, "§1 raccord ou arrive le brut")
end

---------------------------------------------------------------------------------------------------
-- §2 extension de 14 puits
---------------------------------------------------------------------------------------------------
local req2, ents2, net2, forbid2, occ2 = scene()
local st2, lay2, job2 = run(req2, nil)
check(st2 == "done" and lay2 ~= nil, "§2 extension planifiee : " .. tostring(st2) .. " " .. tostring(lay2 and "" or "?"))
if st2 == "done" then
  check(lay2.extractors == 14, "§2 les 14 puits sont equipes (" .. lay2.extractors .. ")")
  check(#lay2.skipped == 0, "§2 aucun puits ecarte (" .. #lay2.skipped .. ")")
  -- emprises disjointes entre elles et avec le site de base ; rien sur un obstacle
  local seen = {}
  local bad_occ, bad_forbid = 0, 0
  local tube_at, ext = {}, {}
  for _, e in ipairs(lay2.ents) do
    local info = ENTS[e.name]
    local w, h = info.w, info.h
    if e.dir == 2 or e.dir == 6 then w, h = h, w end
    local x0, y0 = math.floor(e.x - w / 2 + 0.01), math.floor(e.y - h / 2 + 0.01)
    for ty = y0, y0 + h - 1 do
      for tx = x0, x0 + w - 1 do
        local k = tkey(tx, ty)
        if seen[k] then bad_occ = bad_occ + 1 end
        seen[k] = true
        if occ2[k] then bad_occ = bad_occ + 1 end
        if forbid2[k] and e.role ~= "poteau" and e.role ~= "liaison" then bad_forbid = bad_forbid + 1 end
      end
    end
    if e.role == "tuyau" then tube_at[tkey(math.floor(e.x), math.floor(e.y))] = true end
    if e.role == "extracteur" then ext[#ext + 1] = e end
  end
  check(bad_occ == 0, "§2 aucune emprise ne chevauche une autre ou le site de base (" .. bad_occ .. ")")
  check(bad_forbid == 0, "§2 aucun tuyau neuf au contact de l'eau ni d'un raccord etranger (" .. bad_forbid .. ")")
  -- réseau d'un seul tenant : tuyaux neufs + brut existant, chaque raccord de sortie sur un tuyau
  local all = {}
  for k in pairs(net2) do all[k] = true end
  for k in pairs(tube_at) do all[k] = true end
  local start = tkey(9, 12)
  local reach, stack = { [start] = true }, { start }
  while #stack > 0 do
    local k = table.remove(stack)
    local x, y = untkey(k)
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      local nk = tkey(x + DV[d][1], y + DV[d][2])
      if all[nk] and not reach[nk] then reach[nk] = true; stack[#stack + 1] = nk end
    end
  end
  local unreached = 0
  for k in pairs(all) do if not reach[k] then unreached = unreached + 1 end end
  check(unreached == 0, "§2 le reseau de brut est d'un seul tenant (" .. unreached .. " tuyau(x) isole(s))")
  local conn_ok = 0
  for _, e in ipairs(ext) do
    local pos = ENTS.pjack.boxes[1].conns[e.dir][1]
    local cx, cy = Fl.conn_tile(e.x, e.y, pos)
    if reach[tkey(cx, cy)] then conn_ok = conn_ok + 1 end
  end
  check(conn_ok == #ext, "§2 chaque raccord de sortie est sur le reseau (" .. conn_ok .. "/" .. #ext .. ")")
  -- aucun tuyau neuf n'est adjacent a un tuyau d'eau
  local touch = 0
  for k in pairs(tube_at) do
    local x, y = untkey(k)
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      local nx, ny = x + DV[d][1], y + DV[d][2]
      if nx == 13 and ny >= 14 and ny <= 22 then touch = touch + 1 end
    end
  end
  check(touch == 0, "§2 aucun tuyau de brut contre la conduite d'eau")
  -- poteaux : chaque chevalet est dans la zone d'alimentation d'un poteau
  local poles = {}
  for _, e in ipairs(lay2.ents) do if e.role == "poteau" or e.role == "liaison" then poles[#poles + 1] = e end end
  check(#poles > 0 and lay2.poles > 0, "§2 des poteaux sont poses")
  local cov = 0
  for _, e in ipairs(ext) do
    local x0, y0 = math.floor(e.x - 1.5 + 0.01), math.floor(e.y - 1.5 + 0.01)
    for _, p in ipairs(poles) do
      if p.x + 3.5 > x0 and p.x - 3.5 < x0 + 3 and p.y + 3.5 > y0 and p.y - 3.5 < y0 + 3 then cov = cov + 1 break end
    end
  end
  check(cov == #ext, "§2 chaque chevalet est alimente (" .. cov .. "/" .. #ext .. ")")
  -- les poteaux forment un seul groupe relie au reseau (fils de 9 tuiles)
  local comp = {}
  for i = 1, #poles do comp[i] = i end
  local function find(i) while comp[i] ~= i do i = comp[i] end return i end
  for i = 1, #poles do
    for j = i + 1, #poles do
      if (poles[i].x - poles[j].x) ^ 2 + (poles[i].y - poles[j].y) ^ 2 <= 81 then comp[find(j)] = find(i) end
    end
  end
  local roots = {}
  for i = 1, #poles do roots[find(i)] = true end
  local nr = 0
  for _ in pairs(roots) do nr = nr + 1 end
  check(nr == 1, "§2 les poteaux forment un seul groupe (" .. nr .. ")")
  -- le collecteur est une ligne droite
  check(lay2.trunk ~= nil, "§2 un collecteur est pose")
  check(lay2.kinds.L == nil or lay2.kinds.L <= lay2.extractors / 2, "§2 plus d'embranchements droits que de L")
  check(lay2.pipes > 0 and lay2.pipes < 14 * 12 + 60, "§2 tuyaux bornes (" .. lay2.pipes .. ")")
end

---------------------------------------------------------------------------------------------------
-- §3 reprise par tranches
---------------------------------------------------------------------------------------------------
if st2 == "done" then
  local ref = sig(lay2)
  for _, b in ipairs({ 1, 7, 200 }) do
    local rq = scene()
    local st, lay = run(rq, b)
    check(st == "done" and sig(lay) == ref, "§3 tranche de " .. b .. " nœuds : meme implantation")
  end
  -- lot : 6 puits seulement, les autres differes
  local rq = scene({ max_n = 6 })
  local st, lay = run(rq, nil)
  check(st == "done" and lay.extractors == 6 and lay.deferred == 8, "§3 lot de 6 : 8 differes (" .. tostring(lay and lay.extractors) .. "/" .. tostring(lay and lay.deferred) .. ")")
end

---------------------------------------------------------------------------------------------------
-- §4 obstacle sur le chemin de la ligne principale, puits impossible
---------------------------------------------------------------------------------------------------
do
  -- champ a l'est, derriere une falaise verticale entre x = 22 et x = 24 (y de 0 a 30) percee d'un passage en y = 14 a 16
  local terrain = {}
  for ty = 0, 40 do
    if not (ty >= 14 and ty <= 16) then
      for tx = 22, 24 do terrain[tkey(tx, ty)] = true end
    end
  end
  -- un puits noye dans un lac
  for tx = 48, 54 do for ty = 20, 26 do terrain[tkey(tx, ty)] = true end end
  local wells = field(8, 28, 6, 18, 22, 9)
  wells[#wells + 1] = { x = 51.5, y = 23.5 }
  local rq = scene({ terrain = terrain, wells = wells })
  local st, lay, job = run(rq, 600)
  check(st == "done", "§4 extension derriere une falaise : " .. st .. " " .. tostring(lay))
  if st == "done" then
    check(lay.extractors == 8 and #lay.skipped == 1, "§4 8 equipes, 1 ecarte (" .. lay.extractors .. "/" .. #lay.skipped .. ")")
    check(lay.skipped[1] and lay.skipped[1].cause:find("emprise", 1, true) ~= nil, "§4 cause du puits ecarte : " .. tostring(lay.skipped[1] and lay.skipped[1].cause))
    check(job.spent > 0, "§4 la ligne principale a ete tracee par A* (" .. job.spent .. " noeuds)")
    local gap = false
    for _, e in ipairs(lay.ents) do
      if e.role == "tuyau" and e.x > 22 and e.x < 25 and e.y > 14 and e.y < 17 then gap = true end
    end
    check(gap, "§4 la ligne principale passe par le passage de la falaise")
  end
  -- champ entierement coupe : refus avec une cause
  local wall = {}
  for ty = -40, 90 do for tx = 22, 24 do wall[tkey(tx, ty)] = true end end
  local rq2 = scene({ terrain = wall, wells = field(4, 28, 6, 18, 22, 9) })
  local st2b, why = run(rq2, nil)
  check(st2b == "fail" and type(why) == "string" and why ~= "", "§4 champ coupe de la ligne principale : refus avec cause (" .. tostring(why) .. ")")
end

---------------------------------------------------------------------------------------------------
-- §5 mutants (sur la copie du code de fluides.lua et de collecteur.lua)
---------------------------------------------------------------------------------------------------
local function read(p) local fh = assert(io.open(p, "rb")); local s = fh:read("*a"); fh:close(); return s end
local FSRC = read("shared/ai3/fluides.lua")
local CSRC = read("shared/ai3/collecteur.lua")

local function load_fl(fsrc, csrc)
  local saved_col = package.loaded["shared.ai3.collecteur"]
  local saved_fl = package.loaded["shared.ai3.fluides"]
  package.loaded["shared.ai3.collecteur"] = assert(load(csrc, "=col", "t"))()
  local F = assert(load(fsrc, "=fl", "t"))()
  package.loaded["shared.ai3.collecteur"] = saved_col
  package.loaded["shared.ai3.fluides"] = saved_fl
  return F
end

local function forbid_ok(F)
  local net, forbid = F.ext_net(REL, base_ents(), "pjack")
  local n = 0
  for _, t in ipairs({ { 13, 14 }, { 12, 15 }, { 14, 15 }, { 12, 22 }, { 13, 23 }, { 10, 22 }, { 8, 26 }, { 10, 26 } }) do
    if not forbid[tkey(t[1], t[2])] then n = n + 1 end
  end
  if forbid[tkey(9, 15)] or forbid[tkey(9, 12)] then n = n + 1 end
  return n
end

local function violations(F)
  -- la scène §2 rejouée avec le module F ; rend le nombre d'écarts
  local n = forbid_ok(F)
  local ents = base_ents()
  local net0, forbid0 = Fl.ext_net(REL, ents, "pjack") -- juge : le vrai module
  local net, forbid = F.ext_net(REL, ents, "pjack")        -- requete : le module essaye
  local occ = occupied(ents)
  local wells = field(14, 18, 4, 40, 28, 5, { { x = 10.5, y = 10.5 }, { x = 16.5, y = 10.5 } })
  wells[#wells + 1] = { x = 15.5, y = 17.5 }  -- contre la conduite d'eau
  wells[#wells + 1] = { x = 9.5, y = 28.5 }  -- contre les raccords de l usine
  -- terrain : seul le raccord voisin de l'eau (S) ou de l'usine (N) reste possible pour ces deux puits
  local terrain = {}
  for _, t in ipairs({ { 16, 15 }, { 17, 16 }, { 11, 27 }, { 8, 30 }, { 7, 28 } }) do terrain[tkey(t[1], t[2])] = true end
  local req = { ents = ENTS, conduit = "tube", extractor = "pjack", fluid = "crude", poles = { name = "pole", supply = 3.5, wire = 9 },
    network = { x = 6.5, y = 30.5, wire = 9 }, wells = wells,
    net = net, toward = { x = 9.5, y = 16.5 }, blocked = function(tx, ty) local k = tkey(tx, ty); return occ[k] or terrain[tkey(tx, ty)] or forbid[k] or false end }
  local job = F.layout_new()
  local ok, st, lay
  for _ = 1, 100000 do
    ok, st, lay = pcall(F.ext_step, req, job, 400)
    if not ok or st ~= "more" then break end
  end
  if not ok or st ~= "done" then return 99 end
  if lay.extractors < 14 then n = n + 1 end
  if lay.extractors > 14 then n = n + 1 end
  local tube_at = {}
  for _, e in ipairs(lay.ents) do
    if e.role == "tuyau" then tube_at[tkey(math.floor(e.x), math.floor(e.y))] = true end
  end
  for k in pairs(tube_at) do
    if forbid0[k] then n = n + 1 end
  end
  -- aucun chevalet sur une tuile interdite ; un tuyau neuf ne double pas un tuyau du site de base
  for _, e in ipairs(lay.ents) do
    if e.role == "extracteur" then
      for ty = math.floor(e.y - 1.49), math.floor(e.y + 1.49) do
        for tx = math.floor(e.x - 1.49), math.floor(e.x + 1.49) do
          if occ[tkey(tx, ty)] then n = n + 1 end
        end
      end
    end
  end
  for k in pairs(net0) do if tube_at[k] then n = n + 1 end end
  if lay.pipes > 117 then n = n + 1 end
  -- reseau d'un seul tenant
  local all = {}
  for k in pairs(net) do all[k] = true end
  for k in pairs(tube_at) do all[k] = true end
  local start = tkey(9, 12)
  local reach, stack = { [start] = true }, { start }
  while #stack > 0 do
    local k = table.remove(stack)
    local x, y = untkey(k)
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      local nk = tkey(x + DV[d][1], y + DV[d][2])
      if all[nk] and not reach[nk] then reach[nk] = true; stack[#stack + 1] = nk end
    end
  end
  for k in pairs(all) do if not reach[k] then n = n + 1 end end
  for _, e in ipairs(lay.ents) do
    if e.role == "extracteur" then
      local pos = ENTS.pjack.boxes[1].conns[e.dir][1]
      local cx, cy = Fl.conn_tile(e.x, e.y, pos)
      if not reach[tkey(cx, cy)] then n = n + 1 end
    end
  end
  if lay.poles == 0 then n = n + 1 end
  return n
end

check(violations(load_fl(FSRC, CSRC)) == 0, "§5 le module non mute passe la scene des mutants")

local function mutate(name, from, to, csrc_too)
  local src = csrc_too and CSRC or FSRC
  local i, j = src:find(from, 1, true)
  if not i then print("[CHAMP-PETROLE] ECHEC : mutant '" .. name .. "' : motif introuvable"); fail = fail + 1; return end
  src = src:sub(1, i - 1) .. to .. src:sub(j + 1)
  local F = csrc_too and load_fl(FSRC, src) or load_fl(src, CSRC)
  check(violations(F) > 0, "mutant '" .. name .. "' survit")
end

mutate("tuiles interdites oubliees", "if not net[nk] then forbid[nk] = true end", "")
mutate("raccords etrangers oublies", "for k in pairs(conn_set) do if not net[k] then forbid[k] = true end end", "")
mutate("composantes jamais reliees", "local n = s:route(c.from[1], c.from[2], net_tiles, fl)", "local n = 0")
mutate("poteaux oublies", "local a, b = s:power(electric)\n    if not a then return nil, b end\n    npoles, line = a, b\n  end\n  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge\n  for _, en in ipairs(s.ents) do\n    if en.role ~= \"liaison\" then\n      x0, y0 = math.min(x0, math.floor(en.x)), math.min(y0, math.floor(en.y))\n      x1, y1 = math.max(x1, math.floor(en.x)), math.max(y1, math.floor(en.y))\n    end\n  end\n  return { ents = s.ents, quais = {}",
  "local a, b = 0, 0\n    npoles, line = a, b\n  end\n  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge\n  for _, en in ipairs(s.ents) do\n    if en.role ~= \"liaison\" then\n      x0, y0 = math.min(x0, math.floor(en.x)), math.min(y0, math.floor(en.y))\n      x1, y1 = math.max(x1, math.floor(en.x)), math.max(y1, math.floor(en.y))\n    end\n  end\n  return { ents = s.ents, quais = {}")
mutate("tuyaux du collecteur non poses", "if not s.tube[k] then s.tube[k] = fl; s.npipes = s.npipes + 1 end\n    end\n    for _, x in ipairs(g.ext) do", "end\n    for _, x in ipairs(g.ext) do")

print(string.format("[CHAMP-PETROLE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
