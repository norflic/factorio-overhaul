package.path = "./?.lua;" .. package.path
local logs = {}
log = function(m) logs[#logs + 1] = m end
defines = { inventory = { chest = 1 } }
local ok, Col = pcall(require, "script.team.collecte")
print(ok, ok and "loaded" or Col)
if not ok then os.exit(1) end
local T = require("shared.team.config")
local plate = T.outposts.iron.product
local function chest(n) return { valid = true, force = { name = "player" }, get_item_count = function() return n end } end
local chests = { ["10,0"] = chest(600), ["50,0"] = chest(300), ["5,0"] = chest(100), ["200,0"] = chest(900) }
local enemy_at = { ["10,0"] = true }
local surface = {
  find_entity = function(_, p) return chests[p[1] .. "," .. p[2]] end,
  find_nearest_enemy = function(a) if enemy_at[a.position.x .. "," .. a.position.y] then return { valid = true } end return nil end,
}
local f = { is_player = true, key = "player", force = "player", stats = {}, engineers_count = 2, hq = { valid = true, position = { x = 0, y = 0 }, get_item_count = function() return 0 end },
  team = { floor = 5, missing = {} }, outposts = {} }
local b = { order = { 12 }, projects = { [12] = { spec = { champ = { oid = 2 } }, outs = { { x = 10, y = 0 }, { x = 50, y = 0 }, { x = 5, y = 0 }, { x = 200, y = 0 } } } } }
local function mk() local t = {} for i = 1, 4 do t[i] = { key = "ia1d:12:o:" .. i, kind = "carry", prio = 55, ia1d = { pid = 12, mode = "collect", idx = i } } end return t end
local tasks = mk()
local n = Col.apply(f, surface, b, tasks, 1000)
print("boostees", n)
for _, t in ipairs(tasks) do print(t.key, t.prio, t.critical, t.no_rush) end
assert(n == 2 and tasks[2].prio == 94 and tasks[4].prio == 94 and tasks[1].prio == 55 and tasks[3].prio == 55, "10,0 dangereux, 5,0 sous le seuil, 50 puis 200 pris")
f.engineers_count = 5
tasks = mk(); f.team.collecte.t = -999999
assert(Col.apply(f, surface, b, tasks, 2000) == 0 and tasks[2].prio == 55, "equipe au complet : rien")
local tot, nch = Col.waiting(f, surface, b)
assert(tot == 600 + 300 + 100 + 900 and nch == 4, "Col.waiting : plaques des coffres de sortie du projet : " .. tot)
local refus = 0
for _, m in ipairs(logs) do if m:find("REFUSEE %(ennemi%)") then refus = refus + 1 end end
assert(refus == 1, "une ligne de refus par coffre et par cause, pas de doublon : " .. refus)
for i = 1, 5 do f.engineers_count = 2; f.team.collecte.t = -999999; Col.apply(f, surface, b, mk(), 3000 + i) end
refus = 0
for _, m in ipairs(logs) do if m:find("REFUSEE") then refus = refus + 1 end end
assert(refus == 1, "relances : toujours une seule ligne de refus : " .. refus)
print("[COLLECTE-GLUE] BILAN : 5 OK (choix des coffres, équipe au complet, ligne de refus unique, plaques en attente)")
