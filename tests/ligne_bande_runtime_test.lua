--[[
  Lot RACCORD-BANDE 2 : script/team/ligne_bande.lua (partie moteur) sous un moteur simulé minimal (surface, plan directeur et journal factices) :
    §1 LB.ensure : une ligne par avant-poste, suivie tant que son projet vit, redemandée après un refus (3 au plus) ;
    §2 le site « ligne_bande » : un tronçon par passe (« loin »), puis le plan complet (poteaux, boîte, masques) ; terrain non généré : chunks demandés,
       l'essai ne compte pas ; une ligne impossible est refusée avec sa raison ;
    §3 mutants (câblage).
  Usage : lua5.2 tests/ligne_bande_runtime_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end

local P
local logs = {}
_G.log = function(s) logs[#logs + 1] = s end
_G.game = { tick = 1000 }

local function load_lb(src)
  package.loaded["script.team.ligne_bande"] = nil
  local fn = assert(load(src, "=ligne_bande(variante)"))
  return fn()
end
local SRC = read("script/team/ligne_bande.lua")
local LB = load_lb(SRC)

local function new_build()
  local Build = { SITES = {}, requests = {} }
  Build.request = function(f, spec)
    local b = f.build
    b.next_id = (b.next_id or 1) + 1
    local id = b.next_id
    b.projects[id] = { id = id, spec = spec, state = "attente", ents = {}, parts = {} }
    Build.requests[#Build.requests + 1] = id
    return id
  end
  return Build
end
local function new_team()
  return { key = "banc", build = { projects = {}, order = {}, occ = {}, next_id = 10 } }
end
local band = { id = 5, prio = 50, spec = { site = "champ", champ = { oid = 2 } } }
local fail = { at = { x = 280.5, y = 5.5 }, to = { x = 0.5, y = 0.5 }, d = 280, n = 14 }

-- §1
do
  local Build, f = new_build(), new_team()
  LB.install(Build)
  local ok, why = LB.ensure(f, nil, band, fail, 7.5, "small-electric-pole", 1000)
  local pid = f.build.lignes["2"] and f.build.lignes["2"].pid
  check(ok and pid ~= nil and #Build.requests == 1, "§1 la ligne est demandée (" .. tostring(why) .. ")")
  local sp = f.build.projects[pid].spec
  check(sp.site == "ligne_bande" and sp.lg.ax == 0.5 and sp.lg.bx == 280.5 and sp.lg.reach == 7.5 and sp.lg.pole == "small-electric-pole" and sp.domain == "infrastructures",
    "§1 spec : site, but, portée et poteau obtenable")
  ok, why = LB.ensure(f, nil, band, fail, 7.5, "small-electric-pole", 1060)
  check(ok and #Build.requests == 1 and why:find("en cours", 1, true) ~= nil, "§1 une seule ligne par avant-poste : la suivante suit la première (" .. tostring(why) .. ")")
  local band2 = { id = 6, prio = 50, spec = { site = "champ", champ = { oid = 2 } } }
  ok = LB.ensure(f, nil, band2, fail, 7.5, "small-electric-pole", 1100)
  check(ok and #Build.requests == 1, "§1 partagée par une autre bande du même avant-poste")
  local band3 = { id = 7, prio = 50, spec = { site = "champ", champ = { oid = 3 } } }
  LB.ensure(f, nil, band3, fail, 7.5, "small-electric-pole", 1100)
  check(#Build.requests == 2, "§1 un autre avant-poste : sa propre ligne")
  -- refus : redemandée, 3 au plus
  f.build.projects[pid].state = "refuse"
  ok = LB.ensure(f, nil, band, fail, 7.5, "small-electric-pole", 1200)
  check(ok and #Build.requests == 3, "§1 après un refus : une nouvelle ligne")
  local pid2 = f.build.lignes["2"].pid
  f.build.projects[pid2].state, f.build.projects[pid2].reason = "refuse", "ligne impossible"
  ok = LB.ensure(f, nil, band, fail, 7.5, "small-electric-pole", 1300)
  check(ok and #Build.requests == 4, "§1 deuxième refus : encore une demande")
  local pid3 = f.build.lignes["2"].pid
  f.build.projects[pid3].state, f.build.projects[pid3].reason = "refuse", "ligne impossible"
  ok, why = LB.ensure(f, nil, band, fail, 7.5, "small-electric-pole", 1400)
  check(not ok and #Build.requests == 4 and why:find("refusee", 1, true) ~= nil, "§1 trois refus : la bande retombe sur son refus (" .. tostring(why) .. ")")
  -- finie : suivie, puis une nouvelle ligne si la bande ne se raccorde toujours pas
  local f2 = new_team()
  local B2 = new_build()
  LB.install(B2)
  LB.ensure(f2, nil, band, fail, 7.5, "small-electric-pole", 1000)
  f2.build.projects[f2.build.lignes["2"].pid].state = "fini"
  for _ = 1, 4 do ok, why = LB.ensure(f2, nil, band, fail, 7.5, "small-electric-pole", 1100) end
  check(ok and why:find("finie", 1, true) ~= nil and #B2.requests == 1, "§1 ligne finie : la bande réessaie son raccord")
  ok = LB.ensure(f2, nil, band, fail, 7.5, "small-electric-pole", 1200)
  check(ok and #B2.requests == 2, "§1 finie mais la bande ne se raccorde toujours pas : une nouvelle ligne")
  check(select(2, LB.ensure(f, nil, { spec = {} }, fail, 7.5, "p", 1)) == "ligne : cible inconnue", "§1 bande sans avant-poste : refus net")
  -- API générique (méga-fonderie) : demande par clé, lecture d'état
  local f4, B4 = new_team(), new_build()
  LB.install(B4)
  check(LB.status(f4, "mf1") == "absente", "§1 status : absente avant la demande")
  local okr = LB.request(f4, "mf1", { x = 0, y = 0 }, { x = 200, y = 50 }, 9, "medium-electric-pole", 40, 500)
  local stt, pidr = LB.status(f4, "mf1")
  check(okr and stt == "en cours" and pidr ~= nil and B4.requests[1] == pidr, "§1 request/status : ligne demandée, en cours")
  f4.build.projects[pidr].state = "fini"
  check(LB.status(f4, "mf1") == "finie", "§1 status : finie")
  f4.build.projects[pidr].state, f4.build.projects[pidr].reason = "refuse", "ligne impossible"
  local stt3, _, why3 = LB.status(f4, "mf1")
  check(stt3 == "refusee" and why3 == "ligne impossible", "§1 status : refusee avec sa raison")
end

-- §1 ter LB.projects : les lignes vivantes, triées par clé (leurs poteaux manquants deviennent des buts du cerveau)
do
  local Build, f = new_build(), new_team()
  LB.install(Build)
  LB.request(f, "b", { x = 0, y = 0 }, { x = 100, y = 0 }, 7.5, "small-electric-pole", 40, 500)
  LB.request(f, "a", { x = 0, y = 0 }, { x = 0, y = 100 }, 7.5, "small-electric-pole", 40, 500)
  local l = LB.projects(f)
  check(#l == 2 and l[1].key == "a" and l[2].key == "b", "§1ter lignes vivantes triées par clé")
  f.build.projects[l[1].pid].state = "fini"
  check(#LB.projects(f) == 1 and LB.projects(f)[1].key == "b", "§1ter une ligne finie n'est plus un projet à nourrir")
  check(#LB.projects({ build = { projects = {} } }) == 0, "§1ter sans registre : aucune")
  local auto = read("script/ai3/automatisation.lua")
  check(auto:find("for i, lp in ipairs(LigneBande.projects(f)) do", 1, true) ~= nil and auto:find("pile = \"couverture\", line = true }", 1, true) ~= nil,
    "§1ter automatisation : les poteaux manquants d'une ligne sont des buts « ligne-bande » de la famille couverture")
end

-- §2 le site
local function surface(generated)
  local s = { asked = {} }
  s.is_chunk_generated = function(c) return generated(c.x, c.y) end
  s.request_to_generate_chunks = function(pos, r) s.asked[#s.asked + 1] = pos end
  return s
end
local function handler(reads)
  return { read_masks = function(x0, y0, x1, y1)
    reads.n = (reads.n or 0) + 1
    local water = {}
    for _, w in ipairs(reads.water or {}) do
      for x = math.max(w[1], x0), math.min(w[3], x1) do for y = math.max(w[2], y0), math.min(w[4], y1) do water[P.tkey(x, y)] = true end end
    end
    return { water = water, blocked = {}, clear = {} }
  end }
end
P = require("shared.team.plan")
do
  local Build, f = new_build(), new_team()
  LB.install(Build)
  LB.ensure(f, nil, band, fail, 7.5, "small-electric-pole", 1000)
  local p = f.build.projects[f.build.lignes["2"].pid]
  local site = Build.SITES.ligne_bande
  local reads = { water = { { 120, -30, 180, 40 } } }
  local s = surface(function() return true end)
  local lay, why, wait
  local passes_n = 0
  repeat
    lay, why, wait = site(f, s, p, handler(reads))
    passes_n = passes_n + 1
  until lay or wait ~= "loin" or passes_n > 60
  check(lay ~= nil, "§2 la ligne finit par se planifier (" .. tostring(why) .. ")")
  check(passes_n >= 5 and (passes_n == 1 or wait == "loin" or lay), "§2 plusieurs passes (un tronçon par passe) : " .. passes_n)
  check(lay and #lay.ents >= 30 and lay.ents[1].name == "small-electric-pole" and lay.ents[1].role == "liaison", "§2 poteaux du bon objet, rôle liaison (" .. tostring(lay and #lay.ents) .. ")")
  if lay then
    local pts = { { x = 0.5, y = 0.5 } }
    for _, e in ipairs(lay.ents) do pts[#pts + 1] = e end
    pts[#pts + 1] = { x = 280.5, y = 5.5 }
    local okc = true
    for i = 1, #pts - 1 do if (pts[i].x - pts[i + 1].x) ^ 2 + (pts[i].y - pts[i + 1].y) ^ 2 > 7.5 ^ 2 + 1e-6 then okc = false end end
    check(okc, "§2 chaque pas à portée du fil, du poteau alimenté à la bande")
    local bad = false
    for _, e in ipairs(lay.ents) do if e.x >= 120 and e.x <= 181 and e.y >= -30 and e.y <= 41 then bad = true end end
    check(not bad, "§2 aucun poteau dans le lac")
    check(lay.box[1] <= lay.box[3] and lay.masks and lay.masks.water and lay.masks.clear and lay.masks.blocked and type(lay.masks.free) == "function", "§2 boîte et masques pour les points d'appui")
    check(type(lay.key) == "string" and lay.key:find("ligne:2:", 1, true) == 1, "§2 clé du site")
  end
  check(p.lgs ~= nil and p.lgs.done == true, "§2 l'état de la recherche est dans le projet")
  local function plain(t, seen)
    seen = seen or {}
    if seen[t] then return false end
    seen[t] = true
    for k, v in pairs(t) do
      if type(v) == "function" or type(v) == "userdata" then return false end
      if type(v) == "table" and not plain(v, seen) then return false end
    end
    return true
  end
  check(plain(p.lgs) and plain(f.build.lignes), "§2 aucune fonction dans global (état de la recherche, registre des lignes)")
  local lay2 = site(f, s, p, handler({}))
  check(lay2 ~= nil and #lay2.ents == #lay.ents, "§2 replanification d'une ligne finie : les mêmes poteaux")
end
do
  -- terrain non généré : l'essai ne compte pas, les chunks sont demandés
  local Build, f = new_build(), new_team()
  LB.install(Build)
  LB.ensure(f, nil, band, fail, 7.5, "small-electric-pole", 1000)
  local p = f.build.projects[f.build.lignes["2"].pid]
  local s = surface(function(cx, cy) return cx < 4 end)
  local lay, why, wait
  for _ = 1, 30 do
    lay, why, wait = Build.SITES.ligne_bande(f, s, p, handler({}))
    if lay or #s.asked > 0 then break end
  end
  check(lay == nil and wait == "loin" and #s.asked > 0 and p.far_poll == 1200, "§2 terrain non généré : chunks demandés, nouvel essai plus tard (" .. tostring(why) .. ")")
  check(p.lgs.fails == 0, "§2 l'essai sans terrain ne compte pas parmi les échecs (" .. tostring(p.lgs and p.lgs.fails) .. ")")
end
do
  -- ligne impossible : refusée avec sa raison
  local Build, f = new_build(), new_team()
  LB.install(Build)
  LB.ensure(f, nil, band, fail, 7.5, "small-electric-pole", 1000)
  local p = f.build.projects[f.build.lignes["2"].pid]
  local s = surface(function() return true end)
  local reads = { water = { { 100, -400, 140, 400 } } }
  local lay, why, wait
  for _ = 1, 200 do
    lay, why, wait = Build.SITES.ligne_bande(f, s, p, handler(reads))
    if lay or wait ~= "loin" then break end
  end
  check(lay == nil and wait == nil and tostring(why):find("ligne impossible", 1, true) ~= nil, "§2 mur d'eau : ligne refusée avec la raison (" .. tostring(why) .. ")")
  local said = false
  for _, l in ipairs(logs) do if l:find("[FO-LIGNE-BANDE]", 1, true) and l:find("refusee", 1, true) then said = true end end
  check(said, "§2 la raison est au journal [FO-LIGNE-BANDE]")
end

-- §3 mutants
local function battery(L)
  local bad = 0
  local function exp(c) if not c then bad = bad + 1 end end
  local Build, f = new_build(), new_team()
  L.install(Build)
  local ok = L.ensure(f, nil, band, fail, 9, "medium-electric-pole", 1000)
  L.ensure(f, nil, band, fail, 9, "medium-electric-pole", 1060)
  exp(ok and #Build.requests == 1)
  local p = f.build.projects[f.build.lignes["2"].pid]
  exp(p.spec.lg.pole == "medium-electric-pole" and p.spec.lg.reach == 9)
  local reads = {}
  local s = surface(function() return true end)
  local lay, _, wait
  local n = 0
  repeat lay, _, wait = Build.SITES.ligne_bande(f, s, p, handler(reads)) n = n + 1 until lay or wait ~= "loin" or n > 60
  exp(lay ~= nil and #lay.ents >= 25 and #lay.ents <= 40 and n >= 5 and lay.ents[1].name == "medium-electric-pole")
  -- terrain non généré
  local Build2, f2 = new_build(), new_team()
  L.install(Build2)
  L.ensure(f2, nil, band, fail, 7.5, "p", 1000)
  local p2 = f2.build.projects[f2.build.lignes["2"].pid]
  local s2 = surface(function(cx, cy) return cx < 4 end)
  for _ = 1, 30 do
    local l2 = Build2.SITES.ligne_bande(f2, s2, p2, handler({}))
    if l2 or #s2.asked > 0 then break end
  end
  exp(#s2.asked > 0 and p2.lgs.fails == 0)
  -- refus répétés
  local Build3, f3 = new_build(), new_team()
  L.install(Build3)
  L.ensure(f3, nil, band, fail, 7.5, "p", 1000)
  for _ = 1, 3 do
    local q = f3.build.projects[f3.build.lignes["2"].pid]
    q.state = "refuse"
    L.ensure(f3, nil, band, fail, 7.5, "p", 1100)
  end
  exp(#Build3.requests <= 3)
  return bad
end
check(battery(LB) == 0, "§3 la batterie des mutants passe sur le vrai module")
local function plain_sub(from, to) return function(s) local i, j = s:find(from, 1, true) if not i then return nil end return s:sub(1, i - 1) .. to .. s:sub(j + 1) end end
local MUT = {
  { "une ligne par bande (le registre n'est pas lu)", plain_sub("local rec = bd.lignes[k]", "local rec = nil") },
  { "refus sans limite", plain_sub("if rec.tries >= LB.TRIES then", "if false then") },
  { "terrain non genere : l'essai compte", plain_sub("st.shift, st.trees, st.fails = shift0, trees0, fails0", "st.shift, st.trees = shift0, trees0") },
  { "poteau de la mauvaise sorte", plain_sub("name = lg.pole, x = c.x", "name = \"small-electric-pole\", x = c.x") },
  { "toute la ligne dans une passe", plain_sub("if status == \"more\" then", "if status == \"more\" and false then") },
  { "portee de la bande ignoree", plain_sub("lg.reach)\n    p.lgs = st", "7.5)\n    p.lgs = st") },
}
local refused = 0
for _, m in ipairs(MUT) do
  local src2 = m[2](SRC)
  if not src2 or src2 == SRC then
    print("  MUTANT introuvable : " .. m[1])
  else
    local ok, L2 = pcall(load_lb, src2)
    local killed = not ok
    if ok then
      local ok2, bad = pcall(battery, L2)
      killed = (not ok2) or bad > 0
    end
    if killed then refused = refused + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
  end
end
check(refused == #MUT, "§3 mutants refusés : " .. refused .. " sur " .. #MUT)
print(string.format("[LIGNE-BANDE-RT] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, refused, #MUT))
os.exit(failures == 0 and 0 or 1)
