--[[
  Lot FOREUSES-THERMIQUES : exécutant de la chaîne de poteaux (script/team/foreuse_swap.lua : place_chain, free_for, power_of). Le TEXTE
  de ces fonctions est extrait de foreuse_swap.lua et joué avec un moteur factice minimal (surface, poteaux reliés par fil, numéro de réseau
  par composante connexe, stock). Le moteur simulé (tests/mock_engine.lua) n'a ni réseau électrique ni petit poteau : ce test couvre la
  logique de l'exécutant ; la pose réelle se prouve au micro-scénario tools/autotest/fo-autotest/scenarios/foreuses-chaine.lua.

  Usage, depuis la racine du mod :   lua5.2 tests/foreuse_chaine_script_test.lua
]]
package.path = "./?.lua;" .. package.path
local S = require("shared.team.foreuse_swap")

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[FOREUSE-CHAINE-SCRIPT] ECHEC : " .. name .. (detail and (" (" .. detail .. ")") or "")) end
end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local SRC = read("script/team/foreuse_swap.lua")
-- lot RETROFIT-GABARITS : le coeur de swap_one (retrait, pose, repose de l'ancienne place verifiee) est la primitive partagee
local SE_SRC = read("script/team/swap_entity.lua")

local function extract(text, head)
  local a = text:find(head, 1, true)
  if not a then return nil end
  local z = text:find("\nend\n", a, true) or text:find("\r\nend\r\n", a, true)
  return text:sub(a, z + 4)
end

-- Moteur factice : entités poteaux, fils, réseau = composante connexe (une source « alimentée » a le réseau 1, les autres un numéro propre).
local function world(blocked)
  local W = { ents = {}, stock = {}, next_net = 100 }
  local function net_of(e)
    local seen, stack, found = { [e] = true }, { e }, nil
    while #stack > 0 do
      local c = table.remove(stack)
      if c.source then found = c.source end
      for _, n in ipairs(c.wires) do if not seen[n] and n.valid then seen[n] = true; stack[#stack + 1] = n end end
    end
    return found
  end
  local mt = { __index = function(t, k)
    if k == "electric_network_id" then return net_of(t) or t.own_net end
    if k == "connect_neighbour" then
      return function(o)
        if not (o and o.valid) then return false end
        local d2 = (t.position.x - o.position.x) ^ 2 + (t.position.y - o.position.y) ^ 2
        if d2 > (W.reach or 7.5) ^ 2 + 1e-9 then return false end
        t.wires[#t.wires + 1] = o; o.wires[#o.wires + 1] = t
        return true
      end
    end
    if k == "destroy" then return function() t.valid = false; W.destroyed = (W.destroyed or 0) + 1 end end
    if k == "neighbours" then return { copper = t.wires } end
    if k == "disconnect_neighbour" then
      return function(o)
        for i = #t.wires, 1, -1 do if t.wires[i] == o then table.remove(t.wires, i) end end
        for i = #o.wires, 1, -1 do if o.wires[i] == t then table.remove(o.wires, i) end end
      end
    end
  end }
  function W.pole(x, y, source)
    W.next_net = W.next_net + 1
    local e = setmetatable({ position = { x = x, y = y }, valid = true, wires = {}, source = source, own_net = W.next_net }, mt)
    W.ents[#W.ents + 1] = e
    return e
  end
  W.surface = {
    can_place_entity = function(o)
      if blocked and blocked[math.floor(o.position.x) .. "," .. math.floor(o.position.y)] then return false end
      for _, e in ipairs(W.ents) do if e.valid and e.position.x == o.position.x and e.position.y == o.position.y then return false end end
      return true
    end,
    create_entity = function(o)
      if W.refuse_create then return nil end
      W.created = (W.created or 0) + 1
      local e = W.pole(o.position.x, o.position.y, nil)
      if W.autoconnect then -- le moteur relie de lui-meme un poteau pose aux voisins a portee (deduit)
        for _, n in ipairs(W.ents) do
          if n ~= e and n.valid and (n.position.x - e.position.x) ^ 2 + (n.position.y - e.position.y) ^ 2 <= 7.5 ^ 2 then
            e.wires[#e.wires + 1] = n; n.wires[#n.wires + 1] = e
          end
        end
      end
      return e
    end,
  }
  W.Stock = {
    count = function(_, n) return W.stock[n] or 0 end,
    remove = function(_, n, c) local h = W.stock[n] or 0; local t = math.min(h, c); W.stock[n] = h - t; return t end,
    insert = function(_, n, c) W.stock[n] = (W.stock[n] or 0) + c; return c end,
  }
  return W
end

local function load_fn(text, head, env_extra)
  local body = extract(text, head)
  if not body then return nil, "absente" end
  local env = setmetatable(env_extra, { __index = _G })
  local name = head:match("local function ([%w_]+)")
  local fn, err = load(body .. "\nreturn " .. name, "=" .. name, "t", env)
  if not fn then return nil, err end
  return fn()
end

local function suite(text, se_text)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local POLE = { name = "small-electric-pole", supply = 2.5, wire = 7.5 }
  local f = { force = "player" }
  -- A. chaîne de 3 poteaux depuis une source alimentée : posés, reliés, stock débité
  local W = world()
  local place_chain = load_fn(text, "local function place_chain(f, surface, pole, list, src, free, mine)", { Stock = W.Stock })
  c("A : place_chain extraite", place_chain ~= nil)
  if not place_chain then return res end
  local src = W.pole(30.5, 10.5, 1)
  W.stock[POLE.name] = 5
  local list = { { x = 23.5, y = 10.5 }, { x = 16.5, y = 10.5 }, { x = 12.5, y = 10.5 } }
  local freeA = { n = 5 }
  local ok, _, placed = place_chain(f, W.surface, POLE, list, src, freeA)
  c("A : les poteaux poses sont rendus (o.swap_poles, lus par le plan du champ avec CHAMP-COUVERTURE R7)", type(placed) == "table" and #placed == 3)
  c("A : chaine posee et reliee au reseau de la source", ok == true and W.created == 3 and W.ents[#W.ents].electric_network_id == 1)
  c("A : 3 poteaux pris au stock", W.stock[POLE.name] == 2, tostring(W.stock[POLE.name]))
  c("A (3) : stock libre debite de la chaine", freeA.n == 2, tostring(freeA.n))
  -- B. stock insuffisant : rien n'est posé
  local W2 = world()
  place_chain = load_fn(text, "local function place_chain(f, surface, pole, list, src, free, mine)", { Stock = W2.Stock })
  local src2 = W2.pole(30.5, 10.5, 1)
  W2.stock[POLE.name] = 2
  local ok2, why2 = place_chain(f, W2.surface, POLE, list, src2, { n = 2 })
  c("B : poteaux manquants : rien pose, raison", ok2 == false and why2 == "poteaux au stock" and (W2.created or 0) == 0 and W2.stock[POLE.name] == 2, tostring(why2))
  -- B'. (3) revue du lead : 5 poteaux au stock mais 2 seulement LIBRES (le reste reserve par le plan directeur) : rien n'est pose
  local W2b = world()
  place_chain = load_fn(text, "local function place_chain(f, surface, pole, list, src, free, mine)", { Stock = W2b.Stock })
  local src2b = W2b.pole(30.5, 10.5, 1)
  W2b.stock[POLE.name] = 5
  local ok2b, why2b = place_chain(f, W2b.surface, POLE, list, src2b, { n = 2 })
  c("B' (3) : stock reserve : rien pose, raison", ok2b == false and why2b == "poteaux au stock" and (W2b.created or 0) == 0 and W2b.stock[POLE.name] == 5, tostring(why2b))
  -- C. une place prise en route : tout est repris (poteaux retirés, stock rendu)
  local W3 = world({ ["12,10"] = true })
  place_chain = load_fn(text, "local function place_chain(f, surface, pole, list, src, free, mine)", { Stock = W3.Stock })
  local src3 = W3.pole(30.5, 10.5, 1)
  W3.stock[POLE.name] = 5
  local ok3, why3 = place_chain(f, W3.surface, POLE, list, src3, { n = 5 })
  local alive = 0
  for _, e in ipairs(W3.ents) do if e.valid and not e.source then alive = alive + 1 end end
  c("C : place prise : tout repris, stock rendu", ok3 == false and why3 == "place prise" and alive == 0 and W3.stock[POLE.name] == 5,
    tostring(why3) .. ", vivants " .. alive .. ", stock " .. tostring(W3.stock[POLE.name]))
  -- D. maillon trop long (le fil ne passe pas) : réseau non relié, tout repris
  local W4 = world()
  W4.reach = 7.5
  place_chain = load_fn(text, "local function place_chain(f, surface, pole, list, src, free, mine)", { Stock = W4.Stock })
  local src4 = W4.pole(30.5, 10.5, 1)
  W4.stock[POLE.name] = 5
  local ok4, why4 = place_chain(f, W4.surface, POLE, { { x = 20.5, y = 10.5 }, { x = 12.5, y = 10.5 } }, src4, { n = 5 })
  local alive4 = 0
  for _, e in ipairs(W4.ents) do if e.valid and not e.source then alive4 = alive4 + 1 end end
  c("D : fil trop long : reseau non relie, tout repris", ok4 == false and why4 == "reseau non relie" and alive4 == 0 and W4.stock[POLE.name] == 5, tostring(why4))
  -- E. pose refusée par le moteur : rien ne reste
  local W5 = world()
  W5.refuse_create = true
  place_chain = load_fn(text, "local function place_chain(f, surface, pole, list, src, free, mine)", { Stock = W5.Stock })
  local src5 = W5.pole(30.5, 10.5, 1)
  W5.stock[POLE.name] = 5
  local ok5, why5 = place_chain(f, W5.surface, POLE, list, src5, { n = 5 })
  c("E : pose refusee : stock rendu", ok5 == false and why5 == "pose refusee" and W5.stock[POLE.name] == 5, tostring(why5) .. " " .. tostring(W5.stock[POLE.name]))
  -- K. (4) revue du lead : le poteau neuf ne garde de fil que vers l'equipe (poteau du joueur a portee : fil retire)
  local function chain_with(mine)
    local Wk = world()
    Wk.autoconnect = true
    local pc = load_fn(text, "local function place_chain(f, surface, pole, list, src, free, mine)", { Stock = Wk.Stock })
    local srck = Wk.pole(30.5, 10.5, 1)
    local foreign = Wk.pole(24.5, 13.5, nil) -- poteau du joueur (son reseau a lui ; ici sans source, pour lire le seul fil)
    Wk.stock[POLE.name] = 5
    local okk = pc(f, Wk.surface, POLE, list, srck, { n = 5 }, mine and function(p) return p == srck end or nil)
    local wired = false
    for _, w in ipairs(foreign.wires) do if w.valid and w ~= srck then wired = true end end
    return okk, wired
  end
  local ok_k0, wired0 = chain_with(false)
  c("K (4) temoin : sans filtre, le poteau neuf se relie au poteau du joueur", ok_k0 ~= nil and wired0 == true)
  local ok_k1, wired1 = chain_with(true)
  c("K (4) : fil vers le poteau du joueur retire, chaine reliee a la source", ok_k1 == true and wired1 == false, tostring(ok_k1) .. " " .. tostring(wired1))
  -- team_pole et plan_pole_tiles : poteau de l'equipe (enregistre, tuile d'une chaine, piece du plan), jamais un poteau du joueur
  local Pl = require("shared.team.plan")
  local owners = { [1] = { f = 7 }, [2] = { f = 9 } }
  local Sk = { owner = function(u) return owners[u] end }
  local team_pole = load_fn(text, "local function team_pole(f, p, plan_set)", { P = Pl, State = Sk })
  local plan_pole_tiles = load_fn(text, "local function plan_pole_tiles(f)", { P = Pl, plan_poles = {} })
  c("K : team_pole et plan_pole_tiles extraites", team_pole ~= nil and plan_pole_tiles ~= nil)
  if team_pole and plan_pole_tiles then
    local fk = { id = 7, key = "player", swap = { pole_pos = { [Pl.tkey(5, 5)] = true } },
      build = { order = { 1, 2 }, projects = { [1] = { ents = { { name = "small-electric-pole", x = 10.5, y = 3.5 }, { name = "assembling-machine-1", x = 20.5, y = 3.5 } } },
        [2] = { ents = {} } } } }
    local set = plan_pole_tiles(fk)
    local function pl(u, x, y) return { unit_number = u, position = { x = x, y = y } } end
    c("K : poteau enregistre a l'equipe : source", team_pole(fk, pl(1, 40.5, 40.5), set) == true)
    c("K : poteau enregistre a une autre force du mod, hors plan : pas source", team_pole(fk, pl(2, 41.5, 40.5), set) == false)
    c("K : poteau d'une chaine refait (tuile retenue) : source", team_pole(fk, pl(3, 5.5, 5.5), set) == true)
    c("K : poteau du plan directeur : source ; machine du plan : rien", team_pole(fk, pl(4, 10.5, 3.5), set) == true and set[Pl.tkey(20, 3)] == nil)
    c("K : poteau du joueur : jamais source", team_pole(fk, pl(5, 60.5, 60.5), set) == false)
    fk.build.projects[2].ents[1] = { name = "medium-electric-pole", x = 60.5, y = 60.5 }
    c("K : projets changes : tuiles refaites", team_pole(fk, pl(5, 60.5, 60.5), plan_pole_tiles(fk)) == true)
  end
  -- F. free_for : ni sur la foreuse, ni sur le four, ni sur une tuile réservée (couloir, plan directeur)
  local reserved = {}
  local free_for = load_fn(text, "local function free_for(f, surface, pole)", { S = S, PlacesQG = { is_reserved = function(_, _, p) return reserved[p.x .. ":" .. p.y] == true end } })
  c("F : free_for extraite", free_for ~= nil)
  if free_for then
    local W6 = world()
    local e = { sink = { x = 9, y = 8, w = 2, h = 2 } }
    local box = { x = 9.5, y = 10.5, w = 3, h = 3 }
    local fr = free_for(f, W6.surface, POLE)(e, box)
    reserved["13.5:10.5"] = true
    c("F : tuile de la foreuse refusee", fr(9.5, 10.5) == false and fr(10.5, 11.5) == false)
    c("F : tuile du four refusee", fr(8.5, 7.5) == false)
    c("F : tuile reservee refusee", fr(13.5, 10.5) == false)
    c("F : tuile libre acceptee", fr(12.5, 10.5) == true)
  end
  -- G. power_of : capacité et production de f.build.grow (J/tick -> kW), sans plan directeur : nil
  local power_of = load_fn(text, "local function power_of(f)", { Swap = { JTICK_KW = 60 / 1000 }, Sante = { committed = function() return 270 end } })
  c("G : power_of extraite", power_of ~= nil)
  if power_of then
    local pc = power_of({ build = { grow = { capacity = 15000, power = 10000 } } })
    c("G : 900 kW de capacite, 600 produits, 270 en chantier", pc and math.abs(pc.capacity - 900) < 1e-6 and math.abs(pc.used - 600) < 1e-6 and pc.committed == 270)
    c("G : sans centrale : nil", power_of({}) == nil and power_of({ build = { grow = { capacity = 0 } } }) == nil)
  end
  -- H. (iii) échange : exchange_remove (contenus et objets au stock, désappropriés, détruits), exchange_undo (reposés, objets repris),
  -- compact (listes sans les retirées, compte de foreuses)
  local Wx = world()
  local disowned, owned = {}, {}
  local Statex = { disown = function(u) disowned[#disowned + 1] = u end, own = function(e, fid, kind, oid) owned[#owned + 1] = kind end }
  local Tx = { DRILL = "burner-mining-drill" }
  local function ent(name, typ, x, y, contents)
    local inv = { get_contents = function() return contents or {} end }
    local e = { name = name, type = typ, position = { x = x, y = y }, direction = 0, valid = true, unit_number = math.floor(x * 100 + y),
      get_inventory = function() return inv end }
    e.destroy = function() e.valid = false end
    return e
  end
  local ex_remove = load_fn(text, "local function exchange_remove(f, plan)", { Stock = Wx.Stock, State = Statex, T = Tx, defines = { inventory = { fuel = 1, furnace_source = 2, furnace_result = 3, chest = 4 } },
    sorted_keys = function(t) local k = {} for n in pairs(t) do k[#k + 1] = n end table.sort(k) return k end, INVS = { furnace = { "furnace_source", "furnace_result", "fuel" }, container = { "chest" } } })
  c("H : exchange_remove extraite", ex_remove ~= nil)
  if ex_remove then
    local d5 = ent("burner-mining-drill", "mining-drill", 20, 10, { coal = 4 })
    local s50 = ent("stone-furnace", "furnace", 20, 8, { ["iron-plate"] = 7 })
    local undo, got = ex_remove({}, { ents = { d5, s50 } })
    c("H : paire retiree (detruite, desappropriee)", d5.valid == false and s50.valid == false and #disowned == 2)
    c("H : objets et contenus au stock", (Wx.stock["burner-mining-drill"] or 0) == 1 and (Wx.stock["stone-furnace"] or 0) == 1
      and (Wx.stock.coal or 0) >= 4 and (Wx.stock["iron-plate"] or 0) >= 7, string.format("drill %s four %s charbon %s plaques %s",
      tostring(Wx.stock["burner-mining-drill"]), tostring(Wx.stock["stone-furnace"]), tostring(Wx.stock.coal), tostring(Wx.stock["iron-plate"])))
    c("H : de quoi reposer (2 entrees, positions et genres)", #undo == 2 and undo[1].kind == "drill" and undo[2].kind == "sink" and undo[1].x == 20)
    local ex_undo = load_fn(text, "local function exchange_undo(f, surface, o, undo)", { Stock = Wx.Stock, State = Statex })
    c("H : exchange_undo extraite", ex_undo ~= nil)
    if ex_undo then
      local o = { id = 3, drill_list = {}, sinks = {} }
      ex_undo({ force = "player" }, Wx.surface, o, undo)
      c("H : l'electrique ne passe pas : paire reposee, objets repris", #o.drill_list == 1 and #o.sinks == 1 and (Wx.stock["burner-mining-drill"] or 0) == 0
        and (Wx.stock["stone-furnace"] or 0) == 0 and #owned == 2)
    end
    -- (2) revue du lead : la foreuse reposee reprend la case de la retiree (le compte de foreuses ne tombe pas) ; place prise : rien n'est
    -- pose par-dessus (F70), l'objet reste au stock et la case morte compte perdue
    local compact2 = load_fn(text, "local function compact(o)", {})
    if ex_undo and compact2 then
      local Wy = world({ ["30,8"] = true })
      local ex_undo2 = load_fn(text, "local function exchange_undo(f, surface, o, undo)", { Stock = Wy.Stock, State = Statex })
      Wy.stock["burner-mining-drill"], Wy.stock["stone-furnace"] = 1, 1
      local alive, dead = { valid = true }, { valid = false }
      local o2 = { id = 4, drill_list = { alive, dead }, sinks = { { valid = false } }, drills = 2 }
      ex_undo2({ force = "player" }, Wy.surface, o2, { { name = "burner-mining-drill", x = 20, y = 10, dir = 0, kind = "drill" },
        { name = "stone-furnace", x = 30, y = 8, dir = 0, kind = "sink" } })
      compact2(o2)
      c("H (2) : foreuse reposee dans la case de la retiree : compte de foreuses tenu", o2.drills == 2 and #o2.drill_list == 2 and o2.drill_list[2].valid == true,
        tostring(o2.drills))
      c("H (2) : place prise : rien pose par-dessus, objet garde au stock", (Wy.stock["stone-furnace"] or 0) == 1 and #o2.sinks == 0, tostring(Wy.stock["stone-furnace"]))
    end
    -- lot RETROFIT-GABARITS : la repose de l'ancienne (place verifiee d'abord, F70) vit dans la primitive partagee script/team/swap_entity.lua
    local se_env = setmetatable({ require = function(n) if n == "script.faction.state" then return Statex end return require(n) end }, { __index = _G })
    local se_fn = load(se_text or SE_SRC, "=swap_entity", "t", se_env)
    local Se = se_fn and se_fn() or nil
    c("H (2) : primitive partagee Se.swap chargee (swap_one l'appelle)", Se ~= nil and Se.swap ~= nil and text:find("Se.swap(surface, f, d, item,", 1, true) ~= nil)
    if Se and Se.swap then
      local Wz = world({ ["20,10"] = true })
      local sz = setmetatable({ find_entities_filtered = function() return {} end }, { __index = Wz.surface })
      local old = { name = "burner-mining-drill", position = { x = 20.5, y = 10.5 }, direction = 0, unit_number = 77, valid = true, destroy = function() end }
      local new, back = Se.swap(sz, { force = "player", id = 1 }, old, "electric-mining-drill", { x = 20.5, y = 10.5, dir = 0, size = 3 })
      c("H (2) : ancienne foreuse sur une place prise : pas reposee par-dessus", new == nil and back == nil and (Wz.created or 0) == 0)
    end
    local compact = load_fn(text, "local function compact(o)", {})
    c("H : compact extraite", compact ~= nil)
    if compact then
      local a, b, k = { valid = true }, { valid = false }, { valid = false }
      local o = { drill_list = { a, b }, sinks = { k }, drills = 2 }
      compact(o)
      c("H : listes sans les retirees, compte tenu", #o.drill_list == 1 and o.drill_list[1] == a and #o.sinks == 0 and o.drills == 1)
    end
  end
  -- J. B1 (revue du lead, 7/11) : fits_for lit le récepteur RÉEL de chaque foreuse (drop_target) et ne retire jamais le four d'une électrique
  local J = { reads = 0 }
  local jents = {}
  local function jent(name, typ, x, y, w, extra)
    local e = { name = name, type = typ, position = { x = x, y = y }, valid = true, unit_number = #jents + 100, prototype = { tile_width = w, tile_height = w },
      bounding_box = { left_top = { x = x - w / 2, y = y - w / 2 }, right_bottom = { x = x + w / 2, y = y + w / 2 } } }
    for k, v in pairs(extra or {}) do e[k] = v end
    local tgt = e.drop_target
    e.drop_target = nil
    local p = setmetatable(e, { __index = function(_, k) if k == "drop_target" then J.reads = J.reads + 1 return tgt end end })
    jents[#jents + 1] = p
    return p
  end
  local function inter(e, a)
    local b = e.bounding_box
    return b.left_top.x < a[2][1] and b.right_bottom.x > a[1][1] and b.left_top.y < a[2][2] and b.right_bottom.y > a[1][2]
  end
  local jsurf = {
    count_tiles_filtered = function() return 0 end,
    count_entities_filtered = function() return 25 end,
    find_entities_filtered = function(o)
      local out = {}
      for _, e in ipairs(jents) do
        if e.valid and inter(e, o.area) and (not o.type or o.type == e.type) then out[#out + 1] = e end
      end
      return out
    end,
  }
  local BUR, ELE = "burner-mining-drill", "electric-mining-drill"
  local Tj = { DRILL = BUR, DRILL_ELECTRIC = ELE, drill_electric = { size = 3 }, drill_drop = { 100, 100 }, outposts = { iron = { resource = "iron-ore" } } }
  -- (récepteur sans drop_target, banc foreuses-dense du 7/11 : aides du repli au point de dépôt des données)
  local box_of = load_fn(text, "local function box_of(e)", {})
  local drop_point = load_fn(text, "local function drop_point(d)", { T = Tj, S = S })
  local sink_tiles = load_fn(text, "local function sink_tiles(o)", { box_of = box_of })
  local receiver_of = load_fn(text, "local function receiver_of(d, at)", { drop_point = drop_point })
  local fed_by_electric = load_fn(text, "local function fed_by_electric(surface, k, except)", { drop_point = drop_point, box_of = box_of, S = S })
  c("J : fed_by_electric extraite", fed_by_electric ~= nil)
  local fits_for = load_fn(text, "local function fits_for(f, surface, refs)", { T = Tj, S = S, Swap = { MIN_ORE = 3 }, fed_by_electric = fed_by_electric,
    sink_tiles = sink_tiles, receiver_of = receiver_of,
    game = { entity_prototypes = { [ELE] = { mining_drill_radius = 2.49 } } },
    sorted_keys = function(t) local k = {} for n in pairs(t) do k[#k + 1] = n end table.sort(k) return k end })
  c("J : fits_for extraite", fits_for ~= nil)
  if fits_for then
    local s50 = jent("stone-furnace", "furnace", 13, 8, 2)
    local s70 = jent("stone-furnace", "furnace", 20, 8, 2)
    local s10 = jent("stone-furnace", "furnace", 10, 8, 2)
    local self = jent(BUR, "mining-drill", 10, 10, 2, { drop_target = s10, burner = {} })
    local d5 = jent(BUR, "mining-drill", 13, 10, 2, { drop_target = s50, burner = {} })
    local e11 = jent(ELE, "mining-drill", 22.5, 10.5, 3, { drop_target = s70 })
    local d12 = jent(BUR, "mining-drill", 19, 11, 2, { drop_target = s70, burner = {} })
    local o = { id = 1, kind = "iron", drill_list = { self, d5, e11, d12 }, sinks = { s10, s50, s70 } }
    local refs = { [self.unit_number] = { o = o, drill = self } }
    local fit = fits_for({ force = "player" }, jsurf, refs)
    local e = { id = self.unit_number }
    local p1 = fit(e, 11.5, 10.5, 0)
    c("J : thermique voisine qui bloque : elle et son four (lu par drop_target) au plan", type(p1) == "table" and #p1.drills == 1 and p1.drills[1] == d5.unit_number
      and #p1.sinks == 1 and p1.sinks[1] == s50.unit_number, type(p1) == "table" and (#p1.drills .. " / " .. #p1.sinks) or tostring(p1))
    local p2 = fit(e, 19.5, 8.5, 0)
    c("J : le four d'une electrique bloque : refus", p2 == false, tostring(p2))
    local champ = jent(ELE, "mining-drill", 13, 4.5, 3, { drop_target = s50 })
    local p3 = fit(e, 11.5, 10.5, 0)
    c("J : une electrique hors de l'avant-poste depose dans le four a retirer : refus (relecture au moteur)", p3 == false, tostring(p3))
    champ.valid = false
    local p4 = fit(e, 17.5, 12.5, 0)
    c("J : thermique qui partage le four d'une electrique : elle seule au plan, le four reste", type(p4) == "table" and #p4.drills == 1
      and p4.drills[1] == d12.unit_number and #p4.sinks == 0, type(p4) == "table" and (#p4.drills .. " / " .. #p4.sinks) or tostring(p4))
    -- B2 (revue du lead, 7/11, cout) : les paires de l'avant-poste sont relues UNE fois par passe (une fermeture fits_for = une passe)
    J.reads = 0
    local fit2 = fits_for({ force = "player" }, jsurf, refs)
    fit2(e, 11.5, 10.5, 0)
    fit2(e, 19.5, 8.5, 0)
    fit2(e, 17.5, 12.5, 0)
    c("J B2 : 3 lectures de place, recepteurs lus une seule fois (4 foreuses)", J.reads == 4, tostring(J.reads))
    -- plan perime a l'execution : four de l'entree retire plus tot dans la passe, ou electrique posee depuis qui depose dans un four du plan
    local stale_plan = load_fn(text, "local function stale_plan(surface, ref, ex)", { T = Tj, fed_by_electric = fed_by_electric })
    c("J : stale_plan extraite", stale_plan ~= nil)
    if stale_plan then
      local ref1 = { drill = self, sink_ent = s10 }
      c("J : plan intact : bon", stale_plan(jsurf, ref1, p1) == false)
      s10.valid = false
      c("J : four de l'entree retire dans la passe : perime", stale_plan(jsurf, ref1, p1) == true)
      s10.valid = true
      local late = jent(ELE, "mining-drill", 13, 4.5, 3, { drop_target = s50 })
      c("J : electrique posee depuis, qui depose dans le four du plan : perime", stale_plan(jsurf, ref1, p1) == true)
      late.valid = false
    end
  end
  -- I. câblage : l'échange vient APRÈS la chaîne posée et reliée (courant amené), et l'électrique ratée repose la paire
  local i_chain = text:find("local ok, why, placed = place_chain(f, surface, pole, r.poles, src, pole_free, mine)", 1, true)
  local i_ex = text:find("undo, got = exchange_remove(f, ex)", 1, true)
  c("I : retrait apres la chaine reliee", i_chain ~= nil and i_ex ~= nil and i_chain < i_ex)
  c("I : electrique ratee : paire reposee", text:find("if not done_swap and undo then", 1, true) ~= nil and text:find("exchange_undo(f, surface, ref.o, undo)", 1, true) ~= nil)
  c("I : une ligne [FO-FOREUSES-ECHANGE] par echange", text:find("[FO-FOREUSES-ECHANGE]", 1, true) ~= nil)
  c("I : plan relu a l'execution (B2 : paires lues une fois par passe)", text:find("if ref and stale_plan(surface, ref, r.exchange) then", 1, true) ~= nil)
  c("I (5) : poteaux poses enregistres (State.own) et leur tuile retenue", text:find('State.own(e, f.id, "pole", ref.o.id)', 1, true) ~= nil
    and text:find("st.pole_pos[P.tkey(math.floor(e.position.x), math.floor(e.position.y))] = true", 1, true) ~= nil)
  c("I : listes compactees en fin de passe", text:find("for _, oid in ipairs(sorted_keys(pass.touched or {})) do", 1, true) ~= nil)
  return res
end

local function run(text, se_text)
  local okr, res = pcall(suite, text, se_text)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run(SRC)) do check(r[1], r[2], r[3]) end

local MUT = {
  { "sans reprise sur echec", "      if e.valid then e.destroy() end\r\n      Stock.insert(f, pole.name, 1)", "      Stock.insert(f, pole.name, 1)" },
  { "reseau non verifie", "  if not (src and src.valid and last.valid and last.electric_network_id ~= nil and last.electric_network_id == src.electric_network_id) then", "  if false then" },
  { "stock non verifie", "  if (free and free.n or 0) < #list or Stock.count(f, pole.name) < #list then return false, \"poteaux au stock\" end", "" },
  { "(3) stock libre ignore", "if (free and free.n or 0) < #list or Stock.count", "if Stock.count" },
  { "(3) stock libre non debite", "  free.n = free.n - #list", "" },
  { "fil non tire", "    if prev and prev.valid then prev.connect_neighbour(e) end", "" },
  { "four permis", "if S.overlap(pb, box) or S.overlap(pb, e.sink) then return false end", "if S.overlap(pb, box) then return false end" },
  { "echange : contenus perdus", "            Stock.insert(f, n, cnt[n])", "" },
  { "echange : sans desappropriation", "      if e.unit_number then State.disown(e.unit_number) end", "" },
  { "(2) repose sans verifier la place", "and surface.can_place_entity({ name = u.name, position = { x = u.x, y = u.y }, direction = u.dir, force = f.force })", "" },
  { "(2) case de la retiree non reprise", "        for i, x in ipairs(list) do if not x.valid then slot = i break end end", "" },
  -- (lot RETROFIT-GABARITS : motif dans la primitive partagee script/team/swap_entity.lua, essaye apres foreuse_swap.lua)
  { "(2) ancienne reposee sans verifier la place", "  if surface.can_place_entity({ name = name, position = pos, direction = dir, force = f.force }) then", "  if true then" },
  { "(4) fil vers le joueur garde", "        if n.valid and n ~= prev and not mine(n) then e.disconnect_neighbour(n) end", "" },
  { "(4) poteau d'une autre equipe accepte", "  if ow and ow.f == f.id then return true end", "  if ow then return true end" },
  { "(4) tuiles du plan jamais refaites", "  if c and c.sig == s then return c.set end", "  if c then return c.set end" },
  { "echange : compte de foreuses non tenu", "  o.drills = math.max(0, (o.drills or 0) - lost)", "" },
  -- (echange coupe en entier : vu au banc foreuses-chaine, pas ici ; l ordre chaine puis retrait est controle au texte, cas I)
  { "couloir et plan ignores", "      if PlacesQG.is_reserved(f, pole.name, { x = x, y = y }, 0) then return false end", "" },
  { "B1 : recepteur lu au vecteur de la thermique (drop_target ignore)", "  if t and t.valid then return t end", "" },
  { "B1 : relecture du four au moteur oubliee", "      if t == k then return true end", "" },
  { "B2 : paires relues a chaque appel", "    if info then return info end", "" },
  { "B2 : four de l'entree non relu a l'execution", "  if ref.sink_ent and not ref.sink_ent.valid then return true end", "" },
  { "B1 : electriques non fixes", "      if d.name ~= T.DRILL then fixed[du] = true end", "" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local pat = m[2]
  local a, z = SRC:find(pat, 1, true)
  if not a then pat = pat:gsub("\r\n", "\n"); a, z = SRC:find(pat, 1, true) end
  local sa, sz = nil, nil
  if not a then sa, sz = SE_SRC:find(pat, 1, true) end -- (motif de la primitive partagee)
  if not a and not sa then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local res
    if a then
      res = run(SRC:sub(1, a - 1) .. m[3]:gsub("\r\n", SRC:find("\r\n", 1, true) and "\r\n" or "\n") .. SRC:sub(z + 1))
    else
      res = run(SRC, SE_SRC:sub(1, sa - 1) .. m[3] .. SE_SRC:sub(sz + 1))
    end
    local seen = false
    for _, r in ipairs(res) do if not r[2] then seen = true break end end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[FOREUSE-CHAINE-SCRIPT] mutants refuses %d/%d", refused, #MUT))
print(string.format("[FOREUSE-CHAINE-SCRIPT] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
