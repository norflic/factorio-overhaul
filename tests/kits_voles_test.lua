--[[
  Lot KITS-VOLES (12/11) : la remise directe des kits au QG (script/ai3/amorce_rt.lua, AmRt.deliver) donnait les objets livrés au PREMIER
  projet en réserve de b.order, et non au projet pour lequel le kit avait été fabriqué : scarlet, graine 2507543475, le réseau du charbon
  (projet 7) prenait les tapis des kits des modules 3, 4 et 13, refusés « materiaux introuvables (15 min sans progres) » à 44,7 min.
  Règle : la part d'un kit va à SES projets (ceux du but qui l'a demandé, task.pids) tant qu'ils vivent et l'attendent ; sinon au coffre
  (stock commun), jamais à un autre projet. Chaîne : but (g.pids) -> P.want_kit (task.pids) -> dépôt du PNJ (kits_of) -> AmRt.deliver.
  Lancement : lua5.2 tests/kits_voles_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
log = function() end

local function read(p)
  local fh = assert(io.open(p, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local SRC = { rt = read("script/ai3/amorce_rt.lua"), projets = read("shared/ai3/projets.lua"), auto = read("shared/ai3/automatiser.lua"),
  capi = read("shared/ai3/capitalisation.lua") }
local recipes = dofile("tests/fixtures/recipes.lua")

local QUIET = false
local n_ok, n_ko = 0, 0
local function check(c, what)
  if c then n_ok = n_ok + 1 else n_ko = n_ko + 1; if not QUIET then print("ECHEC : " .. what) end end
  return c
end

local function patched(name, src, edits)
  for _, e in ipairs(edits or {}) do
    local s, n = src:gsub(e[1]:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (e[2]:gsub("%%", "%%%%")))
    assert(n >= 1, "mutant sans effet : " .. e[1])
    src = s
  end
  return assert(load(src, "=" .. name))()
end

local TAPIS, BRAS = "transport-belt", "inserter" -- données du banc (la règle n'en nomme aucun)

-- Le cas du journal : le réseau du charbon (7) est en tête de b.order et attend 100 tapis ; les modules 3 et 13, derrière, attendent les leurs.
local function world()
  local f = { key = "scarlet", team = { delivered = {} }, build = { order = { 7, 3, 4, 13 }, projects = {
    [7] = { id = 7, state = "reserve", stock = {}, missing = { { TAPIS, 100 } } },
    [3] = { id = 3, state = "reserve", stock = {}, missing = { { BRAS, 2 }, { TAPIS, 20 } } },
    [4] = { id = 4, state = "fini", stock = {}, missing = { { TAPIS, 9 } } },
    [13] = { id = 13, state = "reserve", stock = {}, missing = { { TAPIS, 5 } } },
  } } }
  local inv = { has = { [TAPIS] = 0, [BRAS] = 0 } }
  function inv.remove(t)
    local k = math.min(t.count, inv.has[t.name] or 0)
    inv.has[t.name] = (inv.has[t.name] or 0) - k
    return k
  end
  return f, inv
end

local function battery(mut)
  local AmRt = patched("amorce_rt", SRC.rt, mut.rt)
  local f, inv = world()
  local P = f.build.projects
  -- 1. le kit du module 3 (20 tapis) va au module 3, pas au réseau du charbon 7 en tête de la file
  inv.has[TAPIS] = 20
  local g = AmRt.deliver(f, inv, TAPIS, 20, { { pids = { 3 }, n = 20 } })
  check(g == 20 and (P[3].stock[TAPIS] or 0) == 20, "1. kit du module 3 : ses 20 tapis vont au module 3 (" .. tostring(P[3].stock[TAPIS]) .. ")")
  check((P[7].stock[TAPIS] or 0) == 0 and P[7].missing[1][2] == 100, "1. ... et rien au projet 7 en tete de b.order")
  check(#P[3].missing == 1 and P[3].missing[1][1] == BRAS, "1. ... le manque du module 3 ne garde que ses bras")
  -- 2. kit d'un projet FINI (4) : rien n'est remis, les tapis restent pour le coffre (stock commun), jamais au projet 7
  f, inv = world()
  P = f.build.projects
  inv.has[TAPIS] = 9
  g = AmRt.deliver(f, inv, TAPIS, 9, { { pids = { 4 }, n = 9 } })
  check(g == 0 and inv.has[TAPIS] == 9 and (P[7].stock[TAPIS] or 0) == 0, "2. kit d'un projet fini : rien remis, 9 tapis gardes pour le coffre (" .. g .. ")")
  -- 2b. kit d'un projet MORT (absent du plan) : de même
  f, inv = world()
  P = f.build.projects
  inv.has[TAPIS] = 6
  g = AmRt.deliver(f, inv, TAPIS, 6, { { pids = { 99 }, n = 6 } })
  check(g == 0 and inv.has[TAPIS] == 6 and (P[7].stock[TAPIS] or 0) == 0, "2b. kit d'un projet mort : rien remis, tout au coffre")
  -- 3. kit plus gros que le manque de son projet (13 attend 5, kit de 12) : 5 au module 13, 7 au coffre, rien au 7
  f, inv = world()
  P = f.build.projects
  inv.has[TAPIS] = 12
  g = AmRt.deliver(f, inv, TAPIS, 12, { { pids = { 13 }, n = 12 } })
  check(g == 5 and P[13].stock[TAPIS] == 5 and inv.has[TAPIS] == 7 and (P[7].stock[TAPIS] or 0) == 0,
    "3. kit servi : 5 au module 13, 7 pour le coffre, rien au projet 7 (" .. g .. ", " .. inv.has[TAPIS] .. ")")
  -- 4. poche mêlée : 20 tapis du kit du module 3 + 10 tapis hors kit : le kit au 3, le reste par la règle d'avant (le 7, en tête)
  f, inv = world()
  P = f.build.projects
  inv.has[TAPIS] = 30
  g = AmRt.deliver(f, inv, TAPIS, 30, { { pids = { 3 }, n = 20 } })
  check(g == 30 and P[3].stock[TAPIS] == 20 and P[7].stock[TAPIS] == 10, "4. poche melee : 20 au module 3 (kit), 10 hors kit au 7 (" .. tostring(P[7].stock[TAPIS]) .. ")")
  -- 5. deux kits, deux projets : chacun le sien, dans l'ordre des kits
  f, inv = world()
  P = f.build.projects
  inv.has[TAPIS] = 25
  g = AmRt.deliver(f, inv, TAPIS, 25, { { pids = { 13 }, n = 5 }, { pids = { 3 }, n = 20 } })
  check(g == 25 and P[13].stock[TAPIS] == 5 and P[3].stock[TAPIS] == 20 and (P[7].stock[TAPIS] or 0) == 0, "5. deux kits : 5 au 13, 20 au 3, rien au 7")
  -- 6. kit sans projet connu (pids vide) : tout au coffre
  f, inv = world()
  P = f.build.projects
  inv.has[TAPIS] = 8
  g = AmRt.deliver(f, inv, TAPIS, 8, { { pids = {}, n = 8 } })
  check(g == 0 and inv.has[TAPIS] == 8, "6. kit sans projet : tout au coffre")
  -- 7. sans kit : la remise d'avant (premier en réserve de la file) est intacte
  f, inv = world()
  P = f.build.projects
  inv.has[TAPIS] = 40
  g = AmRt.deliver(f, inv, TAPIS, 40)
  check(g == 40 and P[7].stock[TAPIS] == 40, "7. sans kit : la regle d'avant (le 7 en tete)")
  check(f.team.delivered[TAPIS] == 40, "7. ... comptee livree au QG")

  -- 8. producteur : P.want_kit écrit sur la tâche les projets du but (copiés, une table par tâche)
  package.loaded["shared.ai3.projets"] = nil
  local Pm = patched("projets", SRC.projets, mut.projets)
  package.loaded["shared.ai3.projets"] = nil
  local Book = require("shared.team.book")
  local book = Book.new(recipes, { stack_of = function() return 100 end })
  local E = Pm.context({ ["iron-plate"] = 500, ["copper-plate"] = 200 }, book, { open = {} }, {})
  E.st, E.tick = {}, 600
  local goal = { key = "auto:stone-brick", kind = "module", pids = { 3 } }
  Pm.want_kit(E, { id = 35, key = "auto:stone-brick", goal = goal }, { { TAPIS, 30 } }, 80, "module")
  local nk, okp, shared_tbl = 0, true, false
  for _, t in ipairs(E.tasks) do
    if t.kit then
      nk = nk + 1
      if not (type(t.pids) == "table" and #t.pids == 1 and t.pids[1] == 3) then okp = false end
      if t.pids == goal.pids then shared_tbl = true end
    end
  end
  check(nk >= 1 and okp, "8. P.want_kit : chaque kit porte les projets de son but (pids = {3}, " .. nk .. " kit(s))")
  check(not shared_tbl, "8. ... copies (la tache va dans global, le but change a chaque pensee)")

  -- 9. buts : module (m.id), alimentation (fd.id), ordre capi (mod_ids)
  local A = patched("automatiser", SRC.auto, mut.auto)
  local goals = A.goals({}, { mods = { { id = 13, product = "electronic-circuit", state = "reserve", missing = { { TAPIS, 5 } } } },
    feeds = { { id = 5, product = "automation-science-pack", items = { { "iron-gear-wheel", 10 } } } } }, {}, nil)
  local gm, gf
  for _, g2 in ipairs(goals) do
    if g2.key == "auto:electronic-circuit" then gm = g2 end
    if g2.key == "alim:automation-science-pack" then gf = g2 end
  end
  check(gm and gm.pids and gm.pids[1] == 13, "9. but auto:<produit> : pids = { id du module }")
  check(gf and gf.pids and gf.pids[1] == 5, "9. but alim:<produit> : pids = { id du module nourri }")
  local Ca = patched("capitalisation", SRC.capi, mut.capi)
  local cg = Ca.goals({}, nil, { { key = "packs:x", kind = "packs", value = 40, mod_ids = { 12, 14 }, missing = {} } })
  check(cg[1] and cg[1].pids and cg[1].pids[1] == 12 and cg[1].pids[2] == 14, "9. but capi:<ordre> : pids = modules de l'ordre")

  -- 10. une bande de la migration (line) a son projet du cerveau même quand les K places sont prises (emerald, bandes 5 et 14 sans projet)
  local mods = {}
  for i = 1, 8 do mods[#mods + 1] = { id = 100 + i, product = "p" .. i, state = "reserve", missing = { { TAPIS, 1 } }, gain = 5 } end
  mods[#mods + 1] = { id = 5, product = "migration-2", item = "copper-plate", state = "reserve", missing = { { TAPIS, 137 } }, gain = 0, line = true }
  local gl = A.goals({}, { mods = mods }, {}, nil)
  local st = {}
  local order = Pm.update(st, gl, 600, 0)
  local band
  for _, p in ipairs(order) do if p.key == "auto:migration-2" then band = p end end
  check(band ~= nil and band.goal.pids and band.goal.pids[1] == 5, "10. bande de la migration : projet du cerveau malgre K places prises (K " .. Pm.K(0) .. ")")
end

print("[KITS-VOLES] cas")
battery({})

-- câblage (source) : le dépôt du PNJ passe ses kits, les entrées du cerveau portent l'id du plan directeur
print("[KITS-VOLES] cablage")
local wk = read("script/team/worker.lua")
check(wk:find("AmRt.deliver(f, inv, name, n, kits and kits[name])", 1, true) ~= nil, "worker.lua : deposit_inventory passe les kits de l'objet a AmRt.deliver")
check(wk:find("deposit_inventory(f, main_inv(agent), nil, chest, kits_of(agent))", 1, true) ~= nil, "worker.lua : deposit_all lit les kits portes (kits_of)")
check(wk:find("{ pids = t.pids, n = w[2] }", 1, true) ~= nil, "worker.lua : kits_of lit task.pids")
local au = read("script/ai3/automatisation.lua")
local _, nid = au:gsub("mods%[#mods %+ 1%] = { id = ", "")
local _, nall = au:gsub("mods%[#mods %+ 1%] = {", "")
check(nid == nall and nall >= 8, "automatisation.lua : chaque entree du cerveau porte l'id de son projet (" .. nid .. "/" .. nall .. ")")
check(read("script/ai3/capitalisation.lua"):find("short = makes_short(rec), mod_ids = rec.mod_ids }", 1, true) ~= nil, "capitalisation.lua : les ordres ouverts portent leurs modules")
do -- l'entrée d'une bande de la migration porte line (investissement de fond)
  local a0 = au:find("for i, mp in ipairs(MigChamp.projects(f)) do", 1, true)
  local a1 = a0 and au:find("\n  end\n", a0, true)
  local blk = a0 and a1 and au:sub(a0, a1) or ""
  check(blk:find("line = true,", 1, true) ~= nil, "automatisation.lua : une bande de la migration est un investissement de fond (line)")
end
check(read("script/team/mall_rangee.lua"):find("mods[#mods + 1] = { id = q.id,", 1, true) ~= nil, "mall_rangee.lua : la section du mall porte son id")

-- mutants : chaque maillon retiré fait échouer au moins un contrôle de la batterie
print("[KITS-VOLES] mutants")
local function mutant(name, mut)
  local b0 = n_ko
  QUIET = true
  local ok = pcall(battery, mut)
  QUIET = false
  local killed = (not ok) or n_ko > b0
  n_ko = b0
  check(killed, "mutant tue : " .. name)
end
mutant("la remise ignore les kits (regle d'avant)", { rt = { { "for _, k in ipairs(kits or {}) do", "for _, k in ipairs({}) do" } } })
mutant("la part du kit offerte a toute la file (sans filtre de projet)", { rt = { { "local p = (own == nil or own[id]) and b.projects[id] or nil", "local p = b.projects[id]" } } })
mutant("le reste du kit repart a la file (pas au coffre)", { rt = { { "given, free = given + g, free - part", "given, free = given + g, free - g" } } })
mutant("le kit ne porte pas ses projets", { projets = { { "pids = pids })", "pids = nil })" } } })
mutant("le kit partage la table du but", { projets = { { "pids = pids })", "pids = owners })" } } })
mutant("le but module sans pids", { auto = { { "pids = m.id and { m.id } or nil,", "" } } })
mutant("le but alim sans pids", { auto = { { "pids = fd.id and { fd.id } or nil,", "" } } })
mutant("la ligne ou bande sans fond (K places)", { auto = { { "fond = m.line or nil,", "fond = nil," } } })
mutant("le but capi sans pids", { capi = { { "order = copy, pids = copy.mod_ids }", "order = copy }" } } })

print(string.format("[KITS-VOLES] BILAN : %d OK, %d ECHEC(S)", n_ok, n_ko))
os.exit(n_ko == 0 and 0 or 1)
