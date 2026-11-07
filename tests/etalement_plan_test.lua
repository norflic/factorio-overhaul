--[[
  Lot ÉTALEMENT (5/11) : plan d'un projet du plan directeur en TROIS passes (pose et alimentation, poteaux, points d'appui) au lieu
  d'une (script/team/build.lua : ET.cut, ET.resume, Build.TRANCHES).

  Preuve « tranche contre bloc » au moteur simulé : une partie de 4 factions tourne, chacune avec un plan directeur (centrale sur un
  étang près du QG, modules électriques demandés) ; à CHAQUE projet qui entre en « plan », au même tick et sans faire avancer le jeu
  (terrain figé) :
    1. global est copié ; le plan est joué D'UN BLOC (Build.TRANCHES = false) : résultat A ;
    2. global est remis à la copie ; le plan est joué EN TRANCHES (Build.TRANCHES = true), une passe après l'autre, global
       recopié entre deux passes comme par une sauvegarde et un chargement : résultat B ;
    3. A et B doivent être identiques : le projet (entités, parties, obstacles, état, raison, attentes), et dans le plan directeur
       de l'équipe les tuiles réservées, le réseau, les lots, la centrale, les compteurs (hors b.stats.tranches), et les lignes de
       journal du plan (hors [FO-MASQUES], dont le compte « lus au moteur / en cache » dépend du cache local réchauffé par A).
  Le jeu reprend ensuite avec le résultat B. Mutants (relevé gelé faussé en entier : tout bloqué, tout défrichable, eau partout) :
  au moins une différence chacun.
  Montage (7/11) : le mock compte ici l'eau des étangs (count_tiles_filtered rend toujours 0 au mock : la centrale n'avait jamais de
  lot) et donne has_flag aux prototypes de tapis ; chaque partie comparée part d'un registre de jetons neuf et d'une mémoire SCAN
  vide (toutes deux locales au module : la seconde partie jouée au même tick y lisait l'état de la première).
  Résultat le 7/11 (8 min) : 5 759 plans comparés dont 40 en plusieurs passes, tous identiques ; 3 mutants vus ; partie libre :
  37 plans coupés, 618 chargements ; 15 OK, environ 3 min.
  Usage : lua5.2 tests/etalement_plan_test.lua [minutes=8]
]]
package.path = "./?.lua;" .. package.path
local MIN = tonumber(arg[1]) or 8

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local M = require("tests.mock_engine")
local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

-- Un étang près de chaque QG (rive de la centrale du plan directeur) : le moteur simulé n'a pas d'eau sans cela.
local PONDS = {}
do
  local d = 0.7071
  for _, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do
    PONDS[#PONDS + 1] = { x = c[1] * 320 + 30, y = c[2] * 320 + 2 }
  end
end
local function tile_at(x, y)
  for _, q in ipairs(PONDS) do
    local dx, dy = x + 0.5 - q.x, y + 0.5 - q.y
    if dx * dx + dy * dy <= 49 then return "water" end
  end
  return "grass-1"
end
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, ia3e = true, tile_at = tile_at })
local W = M.world()
-- Le mock ne donne pas has_flag a ses prototypes de tapis (script/team/convoyeurs.lua:42) : on le leur ajoute ici,
-- a l'identique pour les deux codes compares (aucun prototype du mock n'est cache).
for _, p in pairs(W.prototypes) do if p.has_flag == nil then p.has_flag = function() return false end end end
W.settings["fo-recruit-idle-max"] = 60
W.settings["fo-war-workers"] = 4
assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
remote.call("factorio-overhaul", "war_fund", 3000)
-- Le mock compte toujours 0 tuile d'eau (count_tiles_filtered) : le releve des lots ne voyait pas les etangs et la centrale
-- restait « pas de lot », si bien qu'aucun plan n'allait jusqu'au bout. On compte ici l'eau par find_tiles_filtered, APRES la
-- pose des QG (leur placement reste celui d'avant), a l'identique pour les deux codes compares.
do
  local s = game.surfaces[1]
  local find = s.find_tiles_filtered
  s.count_tiles_filtered = function(t)
    if t.collision_mask ~= "water-tile" then return 0 end
    local area, cx, cy, r2 = t.area, nil, nil, nil
    if not area then
      local p, r = t.position, t.radius
      cx, cy, r2 = p.x or p[1], p.y or p[2], r * r
      area = { { math.floor(cx - r), math.floor(cy - r) }, { math.ceil(cx + r), math.ceil(cy + r) } }
    end
    local n = 0
    for _, tl in ipairs(find({ area = area, collision_mask = "water-tile" })) do
      local ok = true
      if r2 then local dx, dy = tl.position.x + 0.5 - cx, tl.position.y + 0.5 - cy; ok = dx * dx + dy * dy <= r2 end
      if ok then n = n + 1; if t.limit and n >= t.limit then return n end end
    end
    return n
  end
end

local Build = require("script.team.build")
local State = require("script.faction.state")
M.run_ticks(120)
-- Plan directeur de chaque faction : centrale, puis modules électriques (engrenages, plaques) qui demandent poteaux et points d'appui
for _, id in ipairs(State.alive()) do
  local f = State.faction(id)
  Build.enable(f, { radius = 3 })
  Build.plant(f)
  Build.request(f, { gen = "gears", args = { 2, "assembling-machine-1" }, feed = true, prio = 60 })
  Build.request(f, { gen = "simple", args = { "iron-gear-wheel", 1, "assembling-machine-1" }, feed = true, prio = 55 })
  Build.request(f, { gen = "gears", args = { 1, "assembling-machine-1" }, feed = true, prio = 50 })
end
check(type(Build._advance) == "function" and type(Build._masks_freeze) == "function", "crochets de test présents")
check(Build.TRANCHES == true, "plan en tranches allumé par défaut")

local function restore(copy)
  for k in pairs(global) do global[k] = nil end
  local c = M.deepcopy_global(copy)
  for k, v in pairs(c) do global[k] = v end
end

local function teams()
  local out = {}
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.build then out[#out + 1] = id end
  end
  return out
end

-- Ce qu'un plan écrit : le projet entier (sauf sa tranche) et le plan directeur de l'équipe (sauf le compteur de tranches)
local function result_of(fid, pid, log0)
  local f = State.faction(fid)
  local b = f.build
  local p = b.projects[pid]
  local pc = {}
  for k, v in pairs(p) do if k ~= "pjob" then pc[k] = v end end
  local st = {}
  for k, v in pairs(b.stats) do if k ~= "tranches" then st[k] = v end end
  local lines = {}
  for i = log0 + 1, #W.logs do
    local l = tostring(W.logs[i])
    if not l:find("[FO-MASQUES]", 1, true) then lines[#lines + 1] = l end
  end
  return M.serialize({ p = pc, occ = b.occ, net = b.net, lots = b.lots, plant = b.plant, order = b.order, stats = st, lines = lines,
    pjob_pid = b.pjob_pid or false })
end

-- Joue le plan du projet `pid` : d'un bloc (tranches = false) ou en tranches (global recopié entre deux passes). Rend le résultat et
-- le nombre de passes.
-- Les jetons du tick (script/team/tokens.lua) vivent hors de global, dans un registre local au module : sans remise a zero, le
-- second plan joue au MEME tick serait refuse faute de jetons. Chaque partie comparee part donc d'un registre neuf.
local Tokens = require("script.team.tokens")
local function tokens_fresh()
  for i = 1, 60 do
    local name, v = debug.getupvalue(Tokens.take, i)
    if not name then break end
    if name == "ledger" then v.tick = -1 return true end
  end
  error("registre des jetons introuvable")
end

-- Meme chose pour la memoire des releves de lots du tick (SCAN, script/team/build.lua, lot AGENCEMENT) : locale au module, valable
-- pour un tick et une equipe, elle garde des releves dont la fonction `free` lit les reservations de la partie qui les a faits. Le
-- plan rejoue au meme tick apres une restauration de global y lirait les reservations de l'AUTRE partie. En jeu, un chargement la
-- vide et la passe suivante est a un autre tick : on la vide donc au depart de chaque partie et a chaque chargement simule.
local SCAN_T
do
  local seen = {}
  local function walk(fn, depth)
    if SCAN_T or depth > 6 or seen[fn] then return end
    seen[fn] = true
    for i = 1, 255 do
      local name, v = debug.getupvalue(fn, i)
      if not name then break end
      if name == "SCAN" and type(v) == "table" and v.data then SCAN_T = v return end
      if type(v) == "function" then walk(v, depth + 1) end
      if SCAN_T then return end
    end
  end
  walk(Build._advance, 0)
  assert(SCAN_T, "memoire SCAN de build.lua introuvable")
end
local function scan_fresh() SCAN_T.tick, SCAN_T.key, SCAN_T.data = -1, nil, {} end

local function play(fid, pid, tranches, tick)
  Build.TRANCHES = tranches
  tokens_fresh()
  scan_fresh()
  local log0 = #W.logs
  local n = 0
  for _ = 1, 6 do
    local f = State.faction(fid)
    local p = f.build.projects[pid]
    if not (p and p.state == "plan") then break end
    local before = p.pjob ~= nil
    Build._advance(f, f.hq.surface, p, tick)
    n = n + 1
    local p2 = State.faction(fid).build.projects[pid]
    if not (p2 and p2.pjob) then break end -- plan fini, refusé ou en attente (ou pas joué : jetons, centrale)
    if tranches then restore(M.deepcopy_global(global)); scan_fresh() end -- sauvegarde et chargement entre deux tranches
    if not before and not p2.pjob then break end
  end
  Build.TRANCHES = true
  return result_of(fid, pid, log0), n
end

section("Tranche contre bloc, à chaque projet qui entre en « plan » (" .. MIN .. " min de jeu)")
-- Mutants du relevé GELÉ (celui que reprennent les passes suivantes) : chacun doit changer le plan final. Sur la carte du test (ni
-- arbre ni rocher, terrain fixe), vider `clear` ou `blocked` ou décaler le rectangle ne change rien d'observable (le relevé par
-- chunk relit le même terrain) : ces mutants-là ne prouvent rien ici. On fausse donc le relevé en entier : si la reprise ne lisait
-- pas le relevé gelé, aucun de ces mutants ne serait vu.
-- (Une table pleine en DONNÉES : une métatable ne passerait pas la sauvegarde simulée entre deux tranches, M.deepcopy_global.)
local Pl = require("shared.team.plan")
local function all_of(z)
  local t, r = {}, z.rect
  for y = math.floor(r.y0), math.ceil(r.y1) do for x = math.floor(r.x0), math.ceil(r.x1) do t[Pl.tkey(x, y)] = true end end
  return t
end
local MUT = {
  ["relevé gelé : tout bloqué"] = function(z) z.blocked = all_of(z) return z end,
  ["relevé gelé : tout défrichable"] = function(z) z.clear = all_of(z) return z end,
  ["relevé gelé : eau partout"] = function(z) z.water = all_of(z) return z end,
}
local caught = {}
local freeze0 = Build._masks_freeze
local compared, same, staged, skipped, multi = 0, 0, 0, 0, 0
local seen = {}
local t0 = os.clock()
for _ = 1, MIN * 3600 do
  M.run_ticks(1)
  local tick = game.tick
  -- les passes du plan directeur sont aux multiples de 5 : on joue les plans entre deux passes (terrain figé)
  if tick % 5 == 2 then
    for _, fid in ipairs(teams()) do
      local f = State.faction(fid)
      local b = f.build
      for _, pid in ipairs(b.order) do
        local p = b.projects[pid]
        if p and p.state == "plan" and not p.pjob then
          local key = fid .. ":" .. pid .. ":" .. tostring(p.masq_n or 0) .. ":" .. tostring(p.wait_net or 0) .. ":" .. tick
          if not seen[key] then
            seen[key] = true
            local saved = M.deepcopy_global(global)
            local ra, na = play(fid, pid, false, tick)
            restore(saved)
            local rb, nb = play(fid, pid, true, tick)
            if na == 1 and nb == 1 and ra == rb then
              skipped = skipped + 1 -- rien de joué (jetons, garde de la centrale) ou plan fini d'un bloc sans tranche
            end
            compared = compared + 1
            if nb > 1 then multi = multi + 1 end
            if ra == rb then same = same + 1 else print(string.format("  ECHEC : projet %s de %s, tick %d : tranche (%d passes) != bloc", pid, tostring(f.key), tick, nb)) failures = failures + 1 end
            -- mutants : même départ, relevé gelé faussé
            if nb > 1 then
              for name, fn in pairs(MUT) do
                if not caught[name] then
                  local cur = M.deepcopy_global(global)
                  restore(saved)
                  Build._masks_freeze = function(m) local z = freeze0(m) return z and fn(z) or z end
                  local rm = play(fid, pid, true, tick)
                  Build._masks_freeze = freeze0
                  if rm ~= ra then caught[name] = true end
                  restore(cur)
                end
              end
              staged = staged + 1
            end
            break -- un plan par équipe et par passe
          end
        end
      end
    end
  end
end
print(string.format("  %d plans comparés (%d joués en plusieurs passes, %d sans rien de joué), %d identiques ; %.0f s", compared, multi, skipped, same,
  os.clock() - t0))
check(compared > 0 and same == compared, string.format("tranche = bloc dans les %d plans comparés", compared))
check(multi >= 5, string.format("plans joués en tranches : %d (au moins 5)", multi))
for _, name in ipairs({ "relevé gelé : tout bloqué", "relevé gelé : tout défrichable", "relevé gelé : eau partout" }) do
  check(caught[name], "mutant refusé : " .. name)
end

section("Partie libre : tranches jouées par les passes du jeu (verrou, une tranche par passe, sauvegarde entre deux)")
do
  -- nouvelles demandes (les premières sont planifiées) ; plus d'interception : les passes du jeu jouent les tranches
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    Build.request(f, { gen = "gears", args = { 3, "assembling-machine-1" }, feed = true, prio = 45 })
    Build.request(f, { gen = "simple", args = { "iron-gear-wheel", 2, "assembling-machine-1" }, feed = true, prio = 44 })
  end
  local t1 = {}
  for _, id in ipairs(State.alive()) do t1[id] = State.faction(id).build.stats.tranches or 0 end
  local two, bad_lock, mid_jobs, saves = 0, 0, 0, 0
  for k = 1, 6 * 3600 do
    M.run_ticks(1)
    for _, id in ipairs(State.alive()) do
      local b = State.faction(id).build
      local n = 0
      for _, pid in ipairs(b.order) do
        local p = b.projects[pid]
        if p and p.pjob then
          n = n + 1
          if p.state == "plan" then
            mid_jobs = mid_jobs + 1
            if b.pjob_pid ~= p.id then bad_lock = bad_lock + 1 end
          end
        end
      end
      if n > 1 then two = two + 1 end
    end
    -- une sauvegarde et un chargement toutes les 7 passes (au milieu des tranches)
    if k % 35 == 3 then restore(M.deepcopy_global(global)) saves = saves + 1 end
  end
  local grown = 0
  for _, id in ipairs(State.alive()) do grown = grown + (State.faction(id).build.stats.tranches or 0) - t1[id] end
  print(string.format("  6 min : %d plan(s) coupé(s) par les passes du jeu, %d tick(s) avec une tranche en cours, %d chargement(s)", grown, mid_jobs, saves))
  check(grown >= 2, string.format("des plans coupés par les passes du jeu (%d)", grown))
  check(mid_jobs > 0, "des ticks avec une tranche en cours entre deux passes")
  check(two == 0, "jamais deux plans en tranches à la fois dans une équipe")
  check(bad_lock == 0, "le verrou nomme toujours le projet dont la tranche est en cours")
end

section("Relevé gelé : données seules (gardable dans global)")
do
  local okser = pcall(M.serialize, global)
  check(okser, "global sérialisable en fin de partie")
  local z = Build._masks_freeze({ water = { [1] = true }, blocked = {}, clear = {}, rect = { x0 = 0, y0 = 0, x1 = 1, y1 = 1 }, free = function() end })
  check(z and z.free == nil and pcall(M.serialize, z), "relevé gelé sans fonction")
  check(Build._masks_freeze({ water = {}, blocked = {}, clear = {}, rect = {}, free = function() end, view = 1 }) == nil,
    "relevé d'une autre forme : pas de tranche (plan d'un bloc)")
  check(Build._masks_freeze(nil) == nil, "pas de relevé : pas de tranche")
end

print(string.format("[ETALEMENT-PLAN] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
