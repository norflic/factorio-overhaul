-- Lot BANDE-FIN-TAPIS (F475) : une tâche de chantier abandonnée rend à la réserve de SON projet ce que le PNJ porte de ses objets.
-- Défaut mesuré (banc BANDEFIN-SONDE, graine 123456789) : à 29,5 min un PNJ rappelé (préempté) portait les 24 tapis, 8 bras, 4 poteaux,
-- 4 fours et 20 charbons d'un lot de la bande -30 du joueur (projet 4) ; son retour au QG les a remis d'abord à un autre module en réserve
-- (AmRt.deliver), puis au coffre libre ; de 30,5 à 90 min la bande est restée à 341/365, p.stock 0, coffre 0, échecs « stock » en boucle.
-- Le test joue le TEXTE RÉEL (Build.restore_reserved de build.lua, tête d'abort de worker.lua) dans un environnement simulé, puis les
-- mêmes scènes sous mutants du texte : chaque mutant doit être refusé.
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local function plain(s, pat, init) return s:find(pat, init or 1, true) end

local BUILD = read("script/team/build.lua")
local WORKER = read("script/team/worker.lua")

-- Inventaire simulé d'un personnage (get_item_count, remove)
local function inventory(t)
  local inv = { c = t }
  function inv.get_item_count(name) return inv.c[name] or 0 end
  function inv.remove(st) local have = inv.c[st.name] or 0 local k = math.min(have, st.count) inv.c[st.name] = have - k return k end
  return inv
end

--- Fonctions du texte réel : restore (Build.restore_reserved) et abort (tête d'abort jusqu'à « Worker.abort = abort »).
local function load_env(build_src, worker_src)
  local a = plain(build_src, "function Build.restore_reserved(f, pid, items, inv)")
  if not a then return nil, "Build.restore_reserved absent" end
  local b = build_src:find("\nend\n", a, true)
  local chunk_b = "local Build = {}\n" .. build_src:sub(a, b + 4) .. "\nreturn Build"
  local env = { ipairs = ipairs, pairs = pairs, math = math, table = table, type = type, tostring = tostring }
  local fb, err = load(chunk_b, "=restore", "t", env)
  if not fb then return nil, err end
  local Build = fb()
  local c = plain(worker_src, "local function abort(agent, f, tick, reason)")
  local d = plain(worker_src, "Worker.abort = abort", c)
  if not (c and d) then return nil, "abort absent" end
  local chunk_w = worker_src:sub(c, d - 1) .. "\nreturn abort"
  local envw = { ipairs = ipairs, Build = Build, set = function() end, main_inv = function(agent) return agent.inv end, tostring = tostring }
  local fw, err2 = load(chunk_w, "=abort", "t", envw)
  if not fw then return nil, err2 end
  return { restore = Build.restore_reserved, abort = fw() }
end

local LOT = { { "coal", 20 }, { "inserter", 8 }, { "pole", 4 }, { "furnace", 4 }, { "tapis", 24 } }

local function agent_with(task, carried)
  return { task = task, entity = { valid = true }, inv = inventory(carried) }
end

local function scenes(build_src, worker_src)
  local out = {}
  local function c(ok, m) out[#out + 1] = { ok and true or false, m } end
  local E, why = load_env(build_src, worker_src)
  if not E then c(false, "texte réel chargé (" .. tostring(why) .. ")") return out end
  -- 1. La scène du banc : PNJ préempté avec tout le lot du projet 4 en poche.
  local p4 = { id = 4, state = "chantier", stock = { tapis = 0 } }
  local p5 = { id = 5, state = "reserve", stock = {} }
  local f = { build = { projects = { [4] = p4, [5] = p5 } } }
  local task = { key = "ia1d:4:b:c132.5:-32.5", took = true, items = LOT, ia1d = { pid = 4, mode = "build" } }
  local ag = agent_with(task, { coal = 20, inserter = 8, pole = 4, furnace = 4, tapis = 24, ammo = 10 })
  E.abort(ag, f, 106076, "preempte")
  c(p4.stock.tapis == 24 and p4.stock.inserter == 8 and p4.stock.coal == 20 and p4.stock.furnace == 4 and p4.stock.pole == 4,
    "abandon : le lot porté revient à la réserve du projet 4 (24 tapis, 8 bras, 4 poteaux, 4 fours, 20 charbons)")
  c(ag.inv.c.tapis == 0 and ag.inv.c.coal == 0, "abandon : la poche ne garde rien du lot (rien ne part au coffre ni à un autre module)")
  c(ag.inv.c.ammo == 10, "abandon : ce qui n'est pas du lot reste en poche (déposé au QG comme avant)")
  c(next(p5.stock) == nil, "abandon : aucun objet donné à un autre projet")
  c(task.fail == "preempte" and ag.failed == true, "abandon : la tâche échoue avec son motif, le PNJ rentre")
  -- 2. Lot en partie posé : seulement ce qui reste en poche, jamais plus que le compte de la tâche.
  local q = { id = 7, state = "fantomes", stock = {} }
  f.build.projects[7] = q
  local t2 = { key = "ia1d:7:b:x", took = true, items = { { "tapis", 10 } }, ia1d = { pid = 7, mode = "build" } }
  local a2 = agent_with(t2, { tapis = 13 })
  E.abort(a2, f, 1, "fuite")
  c(q.stock.tapis == 10 and a2.inv.c.tapis == 3, "lot en partie porté : au plus le compte de la tâche (10 sur 13 en poche)")
  local t3 = { key = "ia1d:7:b:y", took = true, items = { { "tapis", 10 } }, ia1d = { pid = 7, mode = "build" } }
  local a3 = agent_with(t3, { tapis = 4 })
  E.abort(a3, f, 1, "chemin")
  c(q.stock.tapis == 14 and a3.inv.c.tapis == 0, "lot en partie posé : ce qui reste en poche seulement (4)")
  -- 3. Projet fini ou refusé : rien n'est rendu (sa réserve est déjà au coffre).
  for _, s in ipairs({ "fini", "refuse" }) do
    local r = { id = 8, state = s, stock = {} }
    f.build.projects[8] = r
    local t4 = { key = "ia1d:8:b:z", took = true, items = { { "tapis", 5 } }, ia1d = { pid = 8, mode = "build" } }
    local a4 = agent_with(t4, { tapis = 5 })
    E.abort(a4, f, 1, "preempte")
    c(next(r.stock) == nil and a4.inv.c.tapis == 5, "projet " .. s .. " : rien n'est rendu, la poche part au QG")
  end
  -- 4. Rien pris (avant take_res), autre mode (défrichage), PNJ mort : rien.
  local t5 = { key = "ia1d:4:b:w", items = { { "tapis", 5 } }, ia1d = { pid = 4, mode = "build" } }
  local a5 = agent_with(t5, { tapis = 5 })
  local before = p4.stock.tapis
  E.abort(a5, f, 1, "preempte")
  c(p4.stock.tapis == before and a5.inv.c.tapis == 5, "rien pris à la réserve (took absent) : rien n'est rendu")
  local t6 = { key = "ia1d:4:c:w", took = true, items = { { "tapis", 5 } }, ia1d = { pid = 4, mode = "clear" } }
  local a6 = agent_with(t6, { tapis = 5 })
  E.abort(a6, f, 1, "preempte")
  c(p4.stock.tapis == before and a6.inv.c.tapis == 5, "tâche de défrichage : rien n'est rendu")
  local a7 = agent_with({ key = "ia1d:4:b:v", took = true, items = { { "tapis", 5 } }, ia1d = { pid = 4, mode = "build" } }, { tapis = 5 })
  a7.entity.valid = false
  E.abort(a7, f, 1, "preempte")
  c(p4.stock.tapis == before, "PNJ invalide : rien")
  -- 5. Projet inconnu : rien, sans erreur.
  local a8 = agent_with({ key = "ia1d:99:b:v", took = true, items = { { "tapis", 5 } }, ia1d = { pid = 99, mode = "build" } }, { tapis = 5 })
  local ok8 = pcall(E.abort, a8, f, 1, "preempte")
  c(ok8 and a8.inv.c.tapis == 5, "projet inconnu : rien, sans erreur")
  return out
end

-- §1 : le texte réel
for _, r in ipairs(scenes(BUILD, WORKER)) do check(r[1], r[2]) end

-- §2 : câblage (abort appelle la restitution AVANT le retour au QG : deposit_inventory remet aux modules en réserve)
do
  local c = plain(WORKER, "local function abort(agent, f, tick, reason)")
  local d = plain(WORKER, "agent.steps = { { \"home\" } }", c)
  local r = plain(WORKER, "Build.restore_reserved(f, t.ia1d.pid, t.items, main_inv(agent))", c)
  check(r and d and r < d, "worker.lua : abort rend la réserve avant le programme « home »")
  check(plain(WORKER, "local all = Build.take_reserved(f, step[2], step[3], main_inv(agent))") ~= nil
    and plain(WORKER, "if agent.task then agent.task.took = true end") ~= nil, "worker.lua : take_res pose task.took (lu par abort)")
end

-- §3 : mutants (chacun doit faire échouer au moins une scène)
local function refused(target, mut)
  local b2, w2, n = BUILD, WORKER, 0
  if target == "b" then b2, n = mut(BUILD) else w2, n = mut(WORKER) end
  if n == 0 then return false end
  for _, r in ipairs(scenes(b2, w2)) do if not r[1] then return true end end
  return false
end
local MUTANTS = {
  { "w", "abort sans restitution", function(s) return s:gsub("    Build%.restore_reserved%(f, t%.ia1d%.pid, t%.items, main_inv%(agent%)%)\n", "", 1) end },
  { "w", "restitution sans « pris »", function(s) return s:gsub("if t and t%.took and t%.ia1d", "if t and t.ia1d", 1) end },
  { "w", "restitution des tâches de défrichage aussi", function(s) return s:gsub('t%.ia1d%.mode == "build" and agent%.entity', "agent.entity", 1) end },
  { "w", "rendu à un autre projet (identifiant de la tâche)", function(s) return s:gsub("Build%.restore_reserved%(f, t%.ia1d%.pid,", "Build.restore_reserved(f, t.key,", 1) end },
  { "b", "toute la poche au lieu du compte de la tâche", function(s) return s:gsub("local k = math%.min%(it%[2%], inv%.get_item_count%(it%[1%]%)%)", "local k = inv.get_item_count(it[1])", 1) end },
  { "b", "projet fini ou refusé servi", function(s) return s:gsub(' or p%.state == "fini" or p%.state == "refuse" then return 0 end', " then return 0 end", 1) end },
  { "b", "retiré de la poche sans aller à la réserve", function(s) return s:gsub("p%.stock%[it%[1%]%] = %(p%.stock%[it%[1%]%] or 0%) %+ got\n", "", 1) end },
  { "b", "réserve créditée sans retirer de la poche", function(s) return s:gsub("local got = inv%.remove%({ name = it%[1%], count = k }%)", "local got = k", 1) end },
}
local nm = 0
for _, m in ipairs(MUTANTS) do
  local ok = refused(m[1], m[3])
  if ok then nm = nm + 1 end
  check(ok, "mutant refusé : " .. m[2])
end

-- §4 : forme (aucun nom du jeu, ni pairs ni hasard dans le texte ajouté)
do
  local a = plain(BUILD, "function Build.restore_reserved(f, pid, items, inv)")
  local body = a and BUILD:sub(a, BUILD:find("\nend\n", a, true)) or "pairs( absent"
  check(a ~= nil and not body:find("[^i]pairs%(") and not body:find("math%.random") and not body:find('"[%w%-]+%-[%w%-]+"'), "restore_reserved : ni pairs, ni hasard, ni nom du jeu")
end

print(string.format("[BANDE-FIN] BILAN : %d OK, %d ECHEC(S) (%d mutants refusés sur %d)", pass, fail, nm, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
