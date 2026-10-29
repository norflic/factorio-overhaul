--[[
  Lot PD-ELEC (D05) : la chaîne de bout en bout de script/team/raccord.lua sur un moteur FACTICE (surface, entités, réseaux
  électriques posés à la main) : relevé borné (une partie de module par passe), classement île / sous aucun poteau, groupes,
  confirmation sur 2 relevés, demande d'un projet de raccordement (bouts, portée, poteau), suivi (fini, groupe disparu),
  fil tiré directement quand les bouts sont à portée, poteau perdu laissé à [FO-RESEAU], machine du joueur ignorée,
  état sans fonction ni entité (sauvegarde), journal [FO-RACCORD].
  Le plan de la chaîne (build.lua, plan_raccord) n'est pas joué ici : P.pole_chain et les masques ont leurs propres bancs
  (tests/poteaux_astar_test.lua, tests/masques_test.lua).
  Usage : lua5.2 tests/raccord_script_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end

local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
local PROTOS = {
  ["medium-electric-pole"] = { max_wire_distance = 9, tile_width = 1 },
  ["big-electric-pole"] = { max_wire_distance = 30, tile_width = 2 },
}
_G.game = { entity_prototypes = PROTOS, tick = 0 }

local R = require("shared.team.raccord")
local Ra = require("script.team.raccord")

---------------------------------------------------------------------------------------------------
-- Moteur factice
---------------------------------------------------------------------------------------------------
local ENTS, UN = {}, 0
local function ent(name, type_, x, y, net, opts)
  UN = UN + 1
  opts = opts or {}
  local w = opts.w or 1
  local e = { name = name, type = type_, position = { x = x, y = y }, electric_network_id = net, unit_number = UN, valid = true,
    force = opts.force or "f1",
    bounding_box = { left_top = { x = x - w / 2, y = y - w / 2 }, right_bottom = { x = x + w / 2, y = y + w / 2 } },
    prototype = { electric_energy_source_prototype = (not opts.burner) and {} or nil, max_wire_distance = opts.wire or 9 } }
  e.connect_neighbour = function(o) e.wired_to = o; return true end
  ENTS[#ENTS + 1] = e
  return e
end
local function remove(e)
  for i, x in ipairs(ENTS) do if x == e then table.remove(ENTS, i) return end end
end
local function has_type(filter, t)
  if filter == nil then return true end
  if type(filter) == "string" then return filter == t end
  for _, x in ipairs(filter) do if x == t then return true end end
  return false
end
local surface = {
  find_entities_filtered = function(fl)
    local out = {}
    for _, e in ipairs(ENTS) do
      local okf = has_type(fl.type, e.type) and (fl.force == nil or fl.force == e.force)
      if okf and fl.area then
        local a = fl.area
        okf = e.position.x >= a[1][1] and e.position.x <= a[2][1] and e.position.y >= a[1][2] and e.position.y <= a[2][2]
      end
      if okf and fl.position then
        local dx, dy = e.position.x - fl.position[1], e.position.y - fl.position[2]
        okf = dx * dx + dy * dy <= (fl.radius or 0) ^ 2 + 1e-9
      end
      if okf then
        out[#out + 1] = e
        if fl.limit and #out >= fl.limit then break end
      end
    end
    return out
  end,
  find_nearest_enemy = function() return nil end,
}

---------------------------------------------------------------------------------------------------
-- Équipe : une centrale finie, un module fini relié (réseau 1), un module fini sur une ÎLE (réseau 2), un module fini dont la
-- machine est sous aucun poteau, une machine du JOUEUR (pas du plan) sur une île.
---------------------------------------------------------------------------------------------------
ent("steam-engine", "generator", 0, 0, 1, { w = 3 })
ent("medium-electric-pole", "electric-pole", 3, 0, 1)
ent("medium-electric-pole", "electric-pole", 40, 0, 1)            -- poteau alimenté le plus proche de l'île
ent("assembling-machine-1", "assembling-machine", 40, 3, 1, { w = 3 }) -- module relié
ent("medium-electric-pole", "electric-pole", 60, 0, 2)            -- poteau de l'île (à 20 tuiles du réseau : une chaîne)
ent("assembling-machine-1", "assembling-machine", 60, 3, 2, { w = 3 })
ent("assembling-machine-1", "assembling-machine", 63, 3, 2, { w = 3 })
ent("electric-mining-drill", "mining-drill", 10, 40, nil, { w = 3 }) -- sous aucun poteau
ent("assembling-machine-1", "assembling-machine", 200, 200, 7, { w = 3 }) -- posée par un joueur (pas au plan)
ent("burner-mining-drill", "mining-drill", 12, 44, nil, { w = 2, burner = true }) -- à combustible : jamais comptée

local function proj(id, state, ents, spec)
  return { id = id, state = state, ents = ents, spec = spec or { gen = "x" }, parts = { { ox = 0, oy = 0, w = 1, h = 1 } } }
end
local b = {
  order = { 1, 2, 3, 4 },
  projects = {
    [1] = proj(1, "fini", { { name = "steam-engine", x = 0, y = 0, built = true, part = 1 }, { name = "medium-electric-pole", x = 3, y = 0, built = true, part = 1 } },
      { gen = "steam" }),
    [2] = proj(2, "fini", { { name = "assembling-machine-1", x = 40, y = 3, built = true, part = 1 }, { name = "medium-electric-pole", x = 40, y = 0, built = true, part = 1 } }),
    [3] = proj(3, "fini", { { name = "assembling-machine-1", x = 60, y = 3, built = true, part = 1 }, { name = "assembling-machine-1", x = 63, y = 3, built = true, part = 1 },
      { name = "medium-electric-pole", x = 60, y = 0, built = true, part = 1 } }),
    [4] = proj(4, "fini", { { name = "electric-mining-drill", x = 10, y = 40, built = true, part = 2 }, { name = "burner-mining-drill", x = 12, y = 44, built = true, part = 2 } }),
  },
  plant = 1, opts = {},
}
local f = { key = "f1", force = "f1", build = b }
local REQ = {}
local api = { prio = 59, request = function(ff, spec)
  local id = 100 + #REQ
  REQ[#REQ + 1] = spec.raccord
  check(spec.prio == 59 and spec.domain == "infrastructures", "0.1 demande : priorite et domaine de l'api")
  b.projects[id] = proj(id, "reserve", {}, spec)
  b.order[#b.order + 1] = id
  return id
end }

local tick = 0
local function run(ticks)
  for _ = 1, ticks / 5 do
    tick = tick + 5
    game.tick = tick
    Ra.step(api, f, surface, tick)
  end
end
local function logs_with(pat)
  local n = 0
  for _, l in ipairs(LOGS) do if l:find(pat) then n = n + 1 end end
  return n
end
local function no_function(t, seen)
  seen = seen or {}
  if seen[t] then return true end
  seen[t] = true
  for _, v in pairs(t) do
    if type(v) == "function" then return false end
    if type(v) == "table" and not no_function(v, seen) then return false end
  end
  return true
end

-- 1. premier relevé (après R.PERIOD) : groupes vus une fois, rien demandé
run(R.PERIOD + 100)
check(b.raccord ~= nil, "1.1 etat cree a la premiere passe")
check(#REQ == 0, "1.2 rien demande au premier releve (a confirmer)")
check(logs_with("%[FO%-RACCORD%] f1 : releve : 5 machine%(s%) des modules finis, 3 sans courant %(ile 2, sous aucun poteau 1%) en 2 groupe") == 1,
  "1.3 releve : 5 machines du plan (dont une a combustible), 3 sans courant (machine du joueur et machine a combustible exclues)")
check(b.raccord.seen.i3 == 1 and b.raccord.seen["u4:2"] == 1, "1.4 groupes i3 et u4:2 vus une fois")
check(logs_with("a confirmer") >= 1, "1.5 attente de confirmation ecrite")
check(no_function(b.raccord), "1.6 etat sans fonction (sauvegarde)")
-- borné : une partie de module par passe (4 parties : la centrale n'a pas de machine électrique relevée au plan, mais sa partie compte)
check(b.raccord.cyc == nil, "1.7 releve termine")

-- 2. second relevé : UN raccordement demandé (un par relevé), pour l'île (clé triée « i3 » avant « u4:2 »)
run(R.PERIOD + 100)
check(#REQ == 1, "2.1 un raccordement demande au second releve (" .. #REQ .. ")")
local sp = REQ[1] or {}
check(sp.key == "i3" and sp.kind == "ile", "2.2 pour l'ile i3")
check(sp.start and not sp.start.new and sp.start.x == 60 and sp.start.y == 0, "2.3 depart : le poteau de l'ile")
check(sp.target and sp.target.x == 40 and sp.target.y == 0, "2.4 cible : le poteau alimente le plus proche")
check(sp.reach == 9 and sp.pole == "medium-electric-pole" and sp.big == false, "2.5 portee 9, poteau moyen")
check(b.raccord.open.i3 == 100 and b.raccord.tries.i3 == 1, "2.6 raccordement ouvert, essai 1")
check(logs_with("groupe i3 %(ile, 2 machine%(s%), projet%(s%) 3%) : raccordement demande %(projet 100%)") == 1, "2.7 journal de la demande")
check(no_function(b.raccord), "2.8 etat sans fonction")

-- 3. troisième relevé : le second groupe (sans réseau) : poteau neuf contre la foreuse
run(R.PERIOD + 100)
check(#REQ == 2 and REQ[2].key == "u4:2" and REQ[2].start.new == true, "3.1 groupe sans reseau : poteau neuf")
check(REQ[2] and #REQ[2].cands > 0 and #REQ[2].cands <= 12, "3.2 places candidates contre la machine")
local c1 = REQ[2] and REQ[2].cands[1]
check(c1 and (c1.x < 8.5 or c1.x > 11.5 or c1.y < 38.5 or c1.y > 41.5), "3.3 premiere place hors de la foreuse")
check(REQ[2] and REQ[2].target.x == 3 and REQ[2].target.y == 0, "3.4 cible : le poteau alimente le plus proche de la foreuse")

-- 4. le raccordement de l'île est fini et l'île est reliée : fin écrite, groupe effacé
b.projects[100].state, b.projects[100].wired = "fini", 2
for _, e in ipairs(ENTS) do if e.electric_network_id == 2 then e.electric_network_id = 1 end end
run(R.PERIOD + 100)
check(logs_with("groupe i3 : raccordement fini") == 1, "4.1 raccordement fini ecrit")
check(logs_with("groupe i3 : plus de machine sans courant") == 1, "4.2 groupe repare ecrit")
check(b.raccord.seen.i3 == nil and b.raccord.tries.i3 == nil and b.raccord.open.i3 == nil, "4.3 groupe efface")

-- 5. fil seul : une nouvelle île dont le poteau est À PORTÉE du réseau (8 tuiles) : fil tiré, aucun projet
local isl = ent("medium-electric-pole", "electric-pole", 48, 0, 5)
ent("assembling-machine-1", "assembling-machine", 48, 3, 5, { w = 3 })
b.projects[5] = proj(5, "fini", { { name = "assembling-machine-1", x = 48, y = 3, built = true, part = 1 }, { name = "medium-electric-pole", x = 48, y = 0, built = true, part = 1 } })
b.order[#b.order + 1] = 5
b.projects[101].state = "fini" -- le raccordement de la foreuse est fini aussi (son groupe reste : la machine n'est pas encore reliée ici)
local nreq = #REQ
run(2 * (R.PERIOD + 100))
local i5 = 0
for i = nreq + 1, #REQ do if REQ[i].key == "i5" then i5 = i5 + 1 end end
check(i5 == 0, "5.1 aucun projet pour des bouts a portee")
-- le raccordement fini de la foreuse ne l'a pas reliée (moteur factice) : un second essai est demandé, au plafond R.MAX_TRIES
check(b.raccord.tries["u4:2"] == 2, "5.4 raccordement fini sans effet : second essai (" .. tostring(b.raccord.tries["u4:2"]) .. ")")
check(isl.wired_to ~= nil and isl.wired_to.position.x == 40, "5.2 fil tire du poteau de l'ile au poteau alimente")
check(logs_with("groupe i5 %(ile, 1 machine%(s%)%) : poteaux a portee, fil tire directement") == 1, "5.3 journal du fil")

-- 6. poteau PERDU : l'île d'un module dont un poteau du plan a disparu est laissée à [FO-RESEAU]
remove(isl)
for _, e in ipairs(ENTS) do if e.position.x == 48 and e.position.y == 3 then e.electric_network_id = nil end end
local nreq6 = #REQ
run(2 * (R.PERIOD + 100))
check(#REQ == nreq6, "6.1 aucun raccordement quand un poteau du plan est perdu")
check(logs_with("u5:1 .*laisser : 1 poteau%(x%) perdu%(s%) a portee") == 1, "6.2 laisse a [FO-RESEAU] (journal)")

-- 6 bis. relecture au moment d'agir : un groupe vu sans courant mais alimenté entre le relevé et la décision ne coûte pas d'essai ;
-- essais épuisés : un essai de plus après R.RETRY_AFTER seulement
local st = b.raccord
local drill
for _, e in ipairs(ENTS) do if e.position.x == 10 and e.position.y == 40 then drill = e end end
st.open["u4:2"] = nil
st.tries["u4:2"] = R.MAX_TRIES
st.last_try["u4:2"] = tick
local nreq6b = #REQ
run(2 * (R.PERIOD + 100))
check(#REQ == nreq6b and st.tries["u4:2"] == R.MAX_TRIES, "6.3 essais epuises, dernier essai recent : rien demande")
st.last_try["u4:2"] = tick - R.RETRY_AFTER
local real_find = surface.find_entities_filtered
surface.find_entities_filtered = function(fl) -- la foreuse est reliée juste après le relevé : la relecture la voit alimentée
  if fl.position and fl.limit == 1 and fl.position[1] == 10 and fl.position[2] == 40 then drill.electric_network_id = 1 end
  return real_find(fl)
end
run(R.PERIOD + 100)
surface.find_entities_filtered = real_find
drill.electric_network_id = nil
check(#REQ == nreq6b and st.tries["u4:2"] == R.MAX_TRIES, "6.4 alimentee a la relecture : aucun essai gache")
check(logs_with("u4:2 .*attendre : alimentee a la relecture") == 1, "6.5 relecture ecrite au journal")
st.last_try["u4:2"] = tick - R.RETRY_AFTER
run(R.PERIOD + 100)
check(#REQ == nreq6b + 1 and REQ[#REQ].key == "u4:2", "6.6 essais epuises depuis R.RETRY_AFTER : un essai de plus")
check(st.tries["u4:2"] == R.MAX_TRIES and st.last_try["u4:2"] > tick - R.PERIOD - 100, "6.7 compteur borne a R.MAX_TRIES, date du dernier essai")
check(no_function(b.raccord), "6.8 etat sans fonction")

-- 7. interrupteur d'essai
local before = #LOGS
b.opts.raccord = false
run(3 * (R.PERIOD + 100))
check(#LOGS == before, "7.1 interrupteur d'essai : rien")
b.opts.raccord = nil

-- 8. équipe sans centrale finie : aucun relevé
local b2 = { order = {}, projects = {}, opts = {} }
local f2 = { key = "f2", force = "f2", build = b2 }
for _ = 1, 2 * R.PERIOD / 5 do Ra.step(api, f2, surface, tick) end
check(b2.raccord ~= nil and b2.raccord.cyc == nil, "8.1 sans centrale finie : pas de releve")

print(string.format("[RACCORD-SCRIPT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
