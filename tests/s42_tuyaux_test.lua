--[[
  Lot s42 TUYAUX (chantier 5.1 du DC, règle des 5 cases) : test hors jeu de shared/ai3/tuyaux.lua (Tu.plan, Tu.buried,
  Tu.next_conversion), contrôle de raccord d'un tracé converti (simulation des raccords d'une pièce souterraine), et relecture du
  câblage (fluides.lua, petrole.lua, build.lua) dans la source.
  Usage : lua5.2 tests/s42_tuyaux_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local Tu = require("shared.ai3.tuyaux")
local K = Tu.tkey

-- pièce neutre : direction d = raccord de surface du côté d (convention relevée du prototype par l'appelant)
local UNDER = { name = "piece-x", reach = 10, open = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } } }
-- convention inverse (un mod pourrait la porter) : la règle ne suppose rien, elle lit `open`
local UNDER_INV = { name = "piece-y", reach = 10, open = { [0] = { 0, 1 }, [2] = { -1, 0 }, [4] = { 0, -1 }, [6] = { 1, 0 } } }

local function line(t, x0, y0, x1, y1, fl)
  local dx, dy = (x1 > x0 and 1) or (x1 < x0 and -1) or 0, (y1 > y0 and 1) or (y1 < y0 and -1) or 0
  local x, y = x0, y0
  while true do
    t[K(x, y)] = fl or "a"
    if x == x1 and y == y1 then break end
    x, y = x + dx, y + dy
  end
  return t
end

--- Le réseau converti relie-t-il les mêmes tuiles de surface que le tracé d'origine ? Simulation des raccords : un tuyau de
--- surface se raccorde à ses 4 voisins ; une pièce seulement par sa face ouverte et, sous terre, à la première pièce de sens
--- inverse sur sa ligne (dans la portée).
local function connected(tubes, plan, under)
  local keys = {}
  for k in pairs(tubes) do if not plan.mid[k] then keys[#keys + 1] = k end end
  table.sort(keys)
  local adj = {}
  local function link(a, b) adj[a] = adj[a] or {}; adj[b] = adj[b] or {}; adj[a][b] = true; adj[b][a] = true end
  local function faces(k, nk) -- k accepte-t-il un raccord de surface vers nk ?
    if plan.mid[k] or tubes[k] == nil then return false end
    local d = plan.piece[k]
    if d == nil then return true end
    local x, y = Tu.untkey(k)
    local o = under.open[d]
    return K(x + o[1], y + o[2]) == nk
  end
  for _, k in ipairs(keys) do
    local x, y = Tu.untkey(k)
    for _, v in ipairs({ { 1, 0 }, { 0, 1 } }) do
      local nk = K(x + v[1], y + v[2])
      if faces(k, nk) and faces(nk, k) and tubes[k] == tubes[nk] then link(k, nk) end
    end
    local d = plan.piece[k]
    if d ~= nil then
      local o = under.open[d]
      for step = 1, under.reach do
        local nk = K(x - step * o[1], y - step * o[2])
        local nd = plan.piece[nk]
        if nd ~= nil then
          local no = under.open[nd]
          if no[1] == -o[1] and no[2] == -o[2] then link(k, nk) end
          break
        end
      end
    end
  end
  local seen, stack, n = { [keys[1]] = true }, { keys[1] }, 1
  while #stack > 0 do
    local k = table.remove(stack)
    for nk in pairs(adj[k] or {}) do if not seen[nk] then seen[nk] = true; n = n + 1; stack[#stack + 1] = nk end end
  end
  return n == #keys, n, #keys
end

---------------------------------------------------------------------------------------------------
-- 1. Règle des 5 cases
---------------------------------------------------------------------------------------------------
do
  -- 5 tuyaux droits : rien (pas « plus de 5 »)
  local t = line({}, 0, 0, 4, 0)
  local p = Tu.plan(t, {}, UNDER)
  check(p.npieces == 0 and p.nmids == 0, "5 tuyaux droits restent en surface")
  -- 6 tuyaux droits : bouts en surface, 4 tuiles enterrables : une paire, 2 tuiles libérées
  t = line({}, 0, 0, 5, 0)
  p = Tu.plan(t, {}, UNDER)
  check(p.npieces == 2 and p.nmids == 2, "6 tuyaux droits : une paire, 2 tuiles liberees (" .. p.npieces .. ", " .. p.nmids .. ")")
  check(p.piece[K(1, 0)] == 6 and p.piece[K(4, 0)] == 2, "faces ouvertes vers l'exterieur (ouest puis est)")
  check(p.piece[K(0, 0)] == nil and p.piece[K(5, 0)] == nil and not p.mid[K(0, 0)] and not p.mid[K(5, 0)], "les bouts restent des tuyaux de surface")
  check(connected(t, p, UNDER), "6 droits : reseau toujours relie")
  -- convention de direction inverse : lue, pas supposée
  p = Tu.plan(t, {}, UNDER_INV)
  check(p.piece[K(1, 0)] == 2 and p.piece[K(4, 0)] == 6, "direction lue dans `open` (convention inverse)")
  check(connected(t, p, UNDER_INV), "convention inverse : reseau relie")
  -- vertical
  t = line({}, 3, -2, 3, 9)
  p = Tu.plan(t, {}, UNDER)
  check(p.npieces == 2 and p.nmids == 8 and p.piece[K(3, -1)] == 0 and p.piece[K(3, 8)] == 4, "vertical : paire nord / sud, 8 tuiles liberees")
  check(connected(t, p, UNDER), "vertical : reseau relie")
end

do
  -- longue conduite : portée respectée, tronçons dos à dos, tout relié
  local t = line({}, 0, 0, 40, 0)
  local p = Tu.plan(t, {}, UNDER)
  local okr = true
  for _, pr in ipairs(p.pairs) do
    if math.abs(pr.b.x - pr.a.x) + math.abs(pr.b.y - pr.a.y) > UNDER.reach then okr = false end
  end
  check(#p.pairs == 4 and okr, "41 tuyaux : 4 paires dans la portee (" .. #p.pairs .. ")")
  check(p.npieces + p.nmids == 39, "41 tuyaux : les 39 tuiles interieures sont converties")
  check(connected(t, p, UNDER), "41 tuyaux : reseau relie")
  -- portée courte
  local u3 = { name = "c", reach = 3, open = UNDER.open }
  p = Tu.plan(t, {}, u3)
  okr = true
  for _, pr in ipairs(p.pairs) do if math.abs(pr.b.x - pr.a.x) > 3 then okr = false end end
  check(#p.pairs >= 10 and okr and connected(t, p, u3), "portee 3 : paires courtes, reseau relie")
  -- portée insuffisante ou pièce absente : tout en surface
  check(Tu.plan(t, {}, { name = "c", reach = 1, open = UNDER.open }).npieces == 0, "portee 1 : rien")
  check(Tu.plan(t, {}, nil).npieces == 0, "aucune piece : rien")
  check(Tu.plan(t, {}, { name = "c", reach = 10, open = {} }).npieces == 0, "direction inconnue : rien")
end

do
  -- coude, embranchement, raccord gardé, réseau existant : en surface
  local t = line({}, 0, 0, 12, 0)
  line(t, 12, 0, 12, 10)          -- coude en (12,0)
  line(t, 6, 0, 6, -8)            -- embranchement en (6,0)
  local keep = { [K(12, 5)] = true } -- raccord d'une machine sur la branche verticale
  local p = Tu.plan(t, keep, UNDER)
  for _, c in ipairs({ { 12, 0, "coude" }, { 6, 0, "embranchement" }, { 12, 5, "raccord garde" }, { 0, 0, "bout" }, { 12, 10, "bout" },
    { 6, -8, "bout" }, { 5, 0, "voisin d'embranchement" }, { 7, 0, "voisin d'embranchement" } }) do
    local k = K(c[1], c[2])
    -- les voisins de l'embranchement PEUVENT être des pièces (face ouverte vers lui) : seuls les nœuds eux-mêmes sont contrôlés
    if c[3]:sub(1, 6) ~= "voisin" then check(p.piece[k] == nil and not p.mid[k], c[3] .. " en surface") end
  end
  check(p.piece[K(1, 0)] == 6 and p.piece[K(5, 0)] == 2, "troncon (1..5, 0) enterre jusqu'a l'embranchement")
  check(p.piece[K(6, -1)] == 4 and p.piece[K(6, -7)] == 0, "branche enterree, faces vers l'embranchement et vers le bout")
  check(p.piece[K(12, 1)] == 0 and p.piece[K(12, 4)] == 4, "avant le raccord garde : paire (12, 1..4)")
  check(p.piece[K(12, 6)] == 0 and p.piece[K(12, 9)] == 4, "apres le raccord garde : paire (12, 6..9)")
  check(connected(t, p, UNDER), "plan ramifie : reseau relie")
  -- réseau existant voisin : la tuile qui le touche reste en surface
  local t2 = line({}, 0, 0, 9, 0)
  local anchor = { [K(4, 1)] = true }
  local p2 = Tu.plan(t2, {}, UNDER, anchor)
  check(p2.piece[K(4, 0)] == nil and not p2.mid[K(4, 0)], "tuile contre le reseau existant : en surface")
  check(connected(t2, p2, UNDER), "ancre : reseau relie")
  -- deux fluides côte à côte (interdit en amont) : aucune conversion des tuiles en contact
  local t3 = line({}, 0, 0, 9, 0, "a")
  line(t3, 0, 1, 9, 1, "b")
  check(Tu.plan(t3, {}, UNDER).npieces == 0, "contact de deux fluides : rien n'est enterre")
  -- deux conduites parallèles du même fluide collées : embranchements partout, rien
  local t4 = line({}, 0, 0, 9, 0, "a")
  line(t4, 0, 1, 9, 1, "a")
  check(Tu.plan(t4, {}, UNDER).npieces == 0, "conduites jumelles collees : rien")
end

do
  -- déterminisme : deux appels, mêmes paires dans le même ordre
  local t = line({}, 0, 0, 30, 0)
  line(t, 30, 0, 30, 20)
  local a, b = Tu.plan(t, {}, UNDER), Tu.plan(t, {}, UNDER)
  local same = #a.pairs == #b.pairs
  for i = 1, #a.pairs do
    if a.pairs[i].a.x ~= b.pairs[i].a.x or a.pairs[i].a.y ~= b.pairs[i].a.y or a.pairs[i].b.x ~= b.pairs[i].b.x then same = false end
  end
  check(same and #a.pairs > 0, "plan deterministe")
end

---------------------------------------------------------------------------------------------------
-- 2. Tu.buried : relecture des paires posées
---------------------------------------------------------------------------------------------------
do
  local t = line({}, 0, 0, 20, 0)
  local p = Tu.plan(t, {}, UNDER)
  local ents = {}
  local keys = {}
  for k in pairs(p.piece) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local x, y = Tu.untkey(k)
    ents[#ents + 1] = { name = "piece-x", x = x + 0.5, y = y + 0.5, dir = p.piece[k], role = Tu.ROLE }
  end
  ents[#ents + 1] = { name = "tube", x = 0.5, y = 0.5, dir = 0, role = "tuyau" }
  local infos = { ["piece-x"] = { under = UNDER } }
  local bur = Tu.buried(ents, infos)
  check(#bur == p.npieces + p.nmids, "buried : bouts et milieux retrouves (" .. #bur .. " / " .. (p.npieces + p.nmids) .. ")")
  local nb = 0
  for _, q in ipairs(bur) do if q.bout then nb = nb + 1 end end
  check(nb == p.npieces, "buried : bouts marques")
  check(#Tu.buried({ { name = "tube", x = 0.5, y = 0.5, role = "tuyau" } }, infos) == 0, "buried : un tuyau de surface n'est pas enterre")
  -- une pièce seule (partenaire absente) : son bout seulement
  check(#Tu.buried({ ents[1] }, infos) == 1, "buried : piece sans partenaire")
end

---------------------------------------------------------------------------------------------------
-- 3. Passe bornée (existant) : une paire par appel, stock exigé
---------------------------------------------------------------------------------------------------
do
  local p = Tu.plan(line({}, 0, 0, 30, 0), {}, UNDER)
  local pr, why = Tu.next_conversion(p, 1)
  check(pr == nil and why == "stock", "conversion : refusee sans les deux pieces en stock")
  pr = Tu.next_conversion(p, 2)
  check(pr ~= nil and pr.a.x == 1 and pr.a.y == 0, "conversion : la premiere paire, une seule")
  pr, why = Tu.next_conversion(Tu.plan(line({}, 0, 0, 3, 0), {}, UNDER), 50)
  check(pr == nil and why ~= "stock", "conversion : rien a enterrer")
end

---------------------------------------------------------------------------------------------------
-- 4. Câblage et règles du mod
---------------------------------------------------------------------------------------------------
do
  local rule = read("shared/ai3/tuyaux.lua")
  local code = rule:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("game%.") and not code:find("global"), "regle pure : aucune API du jeu")
  check(not code:find('"pipe') and not code:find("underground%-"), "regle pure : aucun nom du jeu")
  local fl = read("shared/ai3/fluides.lua")
  check(fl:find("Tu.plan(s.tube, s.rsv, req.under, N)", 1, true) ~= nil, "fluides : l'extension enterre ses conduites droites")
  check(fl:find("Tu.buried(ents, rel.entities)", 1, true) ~= nil, "fluides : ext_net relit les paires posees")
  local pet = read("script/ai3/petrole.lua")
  check(pet:find('filter = "type", type = "pipe-to-ground"', 1, true) ~= nil, "petrole : piece souterraine trouvee par type")
  check(pet:find("max_underground_distance", 1, true) ~= nil, "petrole : portee lue au prototype")
  check(pet:find("req.under = fz.under or nil", 1, true) ~= nil, "petrole : piece gelee avec le plan")
  check(pet:find('L0[Fl.tkey(t.x, t.y)] = "souterrain"', 1, true) ~= nil, "petrole : la rangee n'utilise pas une paire posee")
  local bl = read("script/team/build.lua")
  check(bl:find("for _, t in ipairs(lay.sous or {})", 1, true) ~= nil, "build : sol au-dessus des paires retenu au plan")
end

---------------------------------------------------------------------------------------------------
-- 5. Intégration : extension d'un champ de puits (Fl.ext_step) avec la pièce souterraine
---------------------------------------------------------------------------------------------------
do
  local Fl = require("shared.ai3.fluides")
  local ENTS = {
    ["pjack"] = { w = 3, h = 3, electric = true, boxes = { { type = "output", conns = { [0] = { { 1, -2 } }, [2] = { { 2, -1 } }, [4] = { { -1, 2 } }, [6] = { { -2, 1 } } } } } },
    ["tube"] = { w = 1, h = 1 }, ["pole"] = { w = 1, h = 1 },
    ["piece-x"] = { role = "piece", w = 1, h = 1, under = { reach = UNDER.reach, open = UNDER.open } },
  }
  local REL = { entities = ENTS }
  local function base_ents()
    local ents = {}
    ents[#ents + 1] = { name = "pjack", x = 10.5, y = 10.5, dir = 4, role = "extracteur" }
    for tx = 9, 15 do ents[#ents + 1] = { name = "tube", x = tx + 0.5, y = 12.5, dir = 0, role = "tuyau" } end
    for ty = 13, 20 do ents[#ents + 1] = { name = "tube", x = 9.5, y = ty + 0.5, dir = 0, role = "tuyau" } end
    return ents
  end
  local function occupied(ents)
    local occ = {}
    for _, e in ipairs(ents) do
      local info = ENTS[e.name]
      local x0, y0 = math.floor(e.x - info.w / 2 + 0.01), math.floor(e.y - info.h / 2 + 0.01)
      for ty = y0, y0 + info.h - 1 do for tx = x0, x0 + info.w - 1 do occ[K(tx, ty)] = true end end
    end
    return occ
  end
  local function plan(ents, wells, under)
    local net, forbid = Fl.ext_net(REL, ents, "pjack")
    local occ = occupied(ents)
    local req = { ents = ENTS, conduit = "tube", extractor = "pjack", fluid = "crude", poles = { name = "pole", supply = 3.5, wire = 9 },
      network = { x = 6.5, y = 30.5, wire = 9 }, wells = wells, net = net, toward = { x = 9.5, y = 16.5 }, under = under,
      blocked = function(tx, ty) local k = K(tx, ty); return occ[k] or forbid[k] or false end }
    local job = Fl.layout_new()
    for _ = 1, 100000 do
      local st, a = Fl.ext_step(req, job, nil)
      if st ~= "more" then return st, a end
    end
    return "fail", "boucle"
  end
  --- Raccords physiques : chaque chevalet rejoint-il la tuile (9, 12) du site de base ?
  local function physical(all)
    local surf, piece = {}, {}
    for _, e in ipairs(all) do
      local k = K(math.floor(e.x), math.floor(e.y))
      if e.role == "tuyau" then surf[k] = true elseif e.role == Tu.ROLE then piece[k] = e.dir end
    end
    local function faces(k, nk)
      if surf[k] then return true end
      local d = piece[k]
      if d == nil then return false end
      local x, y = Tu.untkey(k)
      local o = UNDER.open[d]
      return K(x + o[1], y + o[2]) == nk
    end
    local seen, stack = { [K(9, 12)] = true }, { K(9, 12) }
    while #stack > 0 do
      local k = table.remove(stack)
      local x, y = Tu.untkey(k)
      local nexts = {}
      for _, v in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local nk = K(x + v[1], y + v[2])
        if faces(k, nk) and faces(nk, k) then nexts[#nexts + 1] = nk end
      end
      local d = piece[k]
      if d ~= nil then
        local o = UNDER.open[d]
        for step = 1, UNDER.reach do
          local nk = K(x - step * o[1], y - step * o[2])
          if piece[nk] ~= nil then
            local no = UNDER.open[piece[nk]]
            if no[1] == -o[1] and no[2] == -o[2] then nexts[#nexts + 1] = nk end
            break
          end
        end
      end
      for _, nk in ipairs(nexts) do if not seen[nk] then seen[nk] = true; stack[#stack + 1] = nk end end
    end
    local okall, n = true, 0
    for _, e in ipairs(all) do
      if e.role == "extracteur" then
        n = n + 1
        local hit = false
        for _, pos in ipairs(ENTS.pjack.boxes[1].conns[e.dir or 0]) do
          if seen[K(math.floor(e.x + pos[1]), math.floor(e.y + pos[2]))] then hit = true end
        end
        if not hit then okall = false end
      end
    end
    return okall, n
  end
  local function join(a, b) local o = {} for _, e in ipairs(a) do o[#o + 1] = e end for _, e in ipairs(b) do o[#o + 1] = e end return o end

  local wells = { { x = 40.5, y = 8.5 }, { x = 47.5, y = 15.5 }, { x = 55.5, y = 9.5 }, { x = 44.5, y = 26.5 }, { x = 60.5, y = 22.5 } }
  local base = base_ents()
  local st0, lay0 = plan(base, wells, nil)
  local st1, lay1 = plan(base, wells, UNDER)
  check(st0 == "done" and st1 == "done", "§5 extension planifiee avec et sans piece (" .. tostring(st0) .. ", " .. tostring(st1) .. " " .. tostring(st1 ~= "done" and lay1 or "") .. ")")
  if st0 == "done" and st1 == "done" then
    check((lay0.souterrains or 0) == 0 and #(lay0.sous or {}) == 0, "§5 sans piece : tout en surface")
    check(lay1.extractors == lay0.extractors, "§5 memes chevalets equipes")
    check(lay1.souterrains > 0 and #lay1.sous > 0, "§5 des conduites passent sous terre (" .. lay1.souterrains .. " pieces, " .. #lay1.sous .. " tuiles liberees)")
    check(lay1.pipes + lay1.souterrains + #lay1.sous == lay0.pipes, "§5 meme trace : surface + pieces + liberees = tuyaux d'avant ("
      .. lay1.pipes .. " + " .. lay1.souterrains .. " + " .. #lay1.sous .. " / " .. lay0.pipes .. ")")
    local np, nu, occ, dup = 0, 0, {}, false
    for _, e in ipairs(lay1.ents) do
      if e.role == "tuyau" then np = np + 1 elseif e.role == Tu.ROLE then nu = nu + 1 end
      local k = K(math.floor(e.x), math.floor(e.y))
      if (e.role == "tuyau" or e.role == Tu.ROLE) then if occ[k] then dup = true end occ[k] = true end
    end
    check(np == lay1.pipes and nu == lay1.souterrains and not dup, "§5 comptes des entites")
    local free_ok = true
    for _, t in ipairs(lay1.sous) do if occ[K(t[1], t[2])] then free_ok = false end end
    check(free_ok, "§5 aucune entite sur une tuile liberee")
    local ok0, n0 = physical(join(base, lay0.ents))
    local ok1, n1 = physical(join(base, lay1.ents))
    check(ok0 and n0 == lay0.extractors + 1, "§5 temoin : chevalets relies en surface")
    check(ok1 and n1 == lay1.extractors + 1, "§5 chevalets relies au site a travers les paires souterraines")
    check(Fl.check(lay1, ENTS), "§5 Fl.check accepte le plan enterre")
    -- extension suivante : le réseau lu traverse les paires, mais on ne se raccorde ni à un bout ni au milieu
    local all = join(base, lay1.ents)
    local net, forbid = Fl.ext_net(REL, all, "pjack")
    local bad, reached = false, false
    for _, t in ipairs(Tu.buried(all, ENTS)) do
      if net[K(t.x, t.y)] or not forbid[K(t.x, t.y)] then bad = true end
    end
    for _, e in ipairs(lay1.ents) do
      if e.role == "tuyau" and net[K(math.floor(e.x), math.floor(e.y))] then reached = true end
    end
    check(not bad, "§5 ext_net : aucune tuile enterree n'est une cible, toutes sont interdites")
    check(reached, "§5 ext_net : le reseau de brut traverse les paires (tuyaux de surface de l'extension relies)")
    local wells2 = { { x = 70.5, y = 12.5 }, { x = 66.5, y = 30.5 }, { x = 30.5, y = 30.5 } }
    local st2, lay2 = plan(all, wells2, UNDER)
    check(st2 == "done", "§5 seconde extension planifiee (" .. tostring(st2) .. " " .. tostring(st2 ~= "done" and lay2 or "") .. ")")
    if st2 == "done" then
      local ok2, n2 = physical(join(all, lay2.ents))
      check(ok2 and n2 == lay1.extractors + 1 + lay2.extractors, "§5 seconde extension reliee au site a travers les paires de la premiere")
    end
  end
end

print(string.format("s42_tuyaux_test : %d OK, %d ECHEC", pass, fail))
os.exit(fail == 0 and 0 or 1)
