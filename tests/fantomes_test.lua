--[[
  Lot FANTOMES : aperçu en fantômes des paires que le PNJ va poser (script/team/fantomes.lua, moteur simulé réduit).
    - montrés à la prise d'une tâche build ou extend de VOTRE équipe, jamais pour une faction ni une autre sorte de tâche ;
    - retirés à l'arrivée (crochet Outposts.on_arrive), à la fin de la tâche, par le balayage (PNJ mort, tâche disparue, trop vieux) ;
    - réglage coupé : rien ; aucun nom d'objet du jeu dans le module.
  Lancement : lua5.2 tests/fantomes_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local ns = { pteam = {} }
package.loaded["script.core.storage"] = { ns = function(n) ns[n] = ns[n] or {}; return ns[n] end }
package.loaded["script.faction.state"] = { sorted_keys = function(t)
  local k = {}
  for key in pairs(t) do k[#k + 1] = key end
  table.sort(k)
  return k
end }
local previews = 0
local Outposts = { preview_pairs = function(_, _, kind, center, max_pairs)
  previews = previews + 1
  local out = {}
  for i = 1, math.min(max_pairs, 2) do
    out[#out + 1] = { drill = { name = T.DRILL, position = { x = center.x + i * 3, y = center.y }, direction = 0 },
      sink = { name = T.outposts[kind].sink, position = { x = center.x + i * 3, y = center.y - 2 } } }
  end
  return out
end }
package.loaded["script.faction.outposts"] = Outposts
local setting_value = true
settings = { global = setmetatable({}, { __index = function(_, k) if k == "fo-war-fantomes" then return { value = setting_value } end end }) }
local ifaces = {}
remote = { add_interface = function(n, t) ifaces[n] = t end }
defines = { direction = { north = 0 } }
local logs = {}
function log(s) logs[#logs + 1] = s end

local live = 0
local surface = { create_entity = function(t)
  live = live + 1
  local g = { valid = true, name = t.name, inner = t.inner_name }
  g.destroy = function() if g.valid then g.valid = false; live = live - 1 end end
  return g
end }
local Fantomes = require("script.team.fantomes")
check(ifaces["fo-fantomes"] ~= nil and Outposts.on_arrive ~= nil, "interface distante et crochet d'arrivée posés")

local function team(player)
  local f = { is_player = player, key = player and "player" or "scarlet", force = "player", hq = { valid = true, surface = surface },
    started = 0, stats = {}, outposts = { [3] = { id = 3, kind = "iron", pos = { x = 50, y = 50 }, drills = 2 } },
    team = { board = { tasks = {} } } }
  ns.pteam.team = f
  return f
end
local function task(f, key, kind, extra)
  local t = { key = key, kind = kind, worker = 7, outpost_kind = "iron", site = { x = 100, y = 100 }, outpost = 3 }
  for k, v in pairs(extra or {}) do t[k] = v end
  f.team.board.tasks[key] = t
  return t
end

do
  local f = team(true)
  local t = task(f, "build:iron", "build")
  check(Fantomes.show(f, t, 600) > 0 and live > 0, "tâche build : fantômes montrés (" .. live .. ")")
  check(Fantomes.show(f, t, 700) == 0, "pas de doublon pour la même tâche")
  local n = live
  Outposts.on_arrive(f, t.site, nil)
  check(live == 0 and f.stats.fantomes_arrivee == n and f.fantomes["build:iron"] == nil, "arrivée du PNJ : fantômes retirés")
  local e = task(f, "extend:3", "extend")
  check(Fantomes.show(f, e, 800) > 0, "tâche extend : fantômes montrés")
  Outposts.on_arrive(f, nil, 99)
  check(live > 0, "arrivée d'un autre avant-poste : rien n'est retiré")
  Fantomes.finish(f, "extend:3")
  check(live == 0 and (f.stats.fantomes_fin or 0) > 0, "fin de tâche (réussie ou non) : retirés")
  check(Fantomes.show(f, task(f, "mine:coal", "mine"), 900) == 0, "une autre sorte de tâche : rien")
end
do
  local f = team(true)
  local t = task(f, "build:iron", "build")
  Fantomes.show(f, t, 0)
  check(Fantomes.sweep(f, 100) == 0 and live > 0, "balayage : tâche vivante, rien")
  t.worker = nil
  check(Fantomes.sweep(f, 200) > 0 and live == 0, "balayage : PNJ mort (plus d'ouvrier) : purgé")
  local t2 = task(f, "build:copper", "build", { site = { x = 5, y = 5 } })
  Fantomes.show(f, t2, 300)
  f.team.board.tasks["build:copper"] = nil
  Fantomes.sweep(f, 400)
  check(live == 0, "balayage : tâche disparue du tableau : purgé")
  local t3 = task(f, "build:stone", "build", { site = { x = 9, y = 9 } })
  Fantomes.show(f, t3, 1000)
  Fantomes.sweep(f, 1000 + Fantomes.MAX_AGE + 1)
  check(live == 0, "balayage : trop vieux : purgé")
  local st = Fantomes.status(f)
  check(st.entries == 0 and st.live == 0 and st.shown > 0 and st.balayage > 0, "statut : 0 orphelin, compteurs")
end
do
  local f = team(false)
  local before = previews
  check(Fantomes.show(f, task(f, "build:iron", "build"), 0) == 0 and previews == before, "une faction : jamais")
  local g = team(true)
  setting_value = false
  check(Fantomes.show(g, task(g, "build:iron", "build"), 0) == 0, "réglage coupé : rien")
  setting_value = true
  -- site inconnu
  check(Fantomes.show(g, task(g, "build:x", "build", { site = false }), 0) == 0, "site inconnu : rien")
end
do
  local fh = assert(io.open("script/team/fantomes.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local bad = {}
  for _, w in ipairs({ "stone%-furnace", "burner%-mining%-drill", "iron%-plate", "\"coal\"", "iron%-chest" }) do
    if code:find(w) then bad[#bad + 1] = w end
  end
  check(#bad == 0, "aucun nom d'objet en dur dans fantomes.lua (" .. table.concat(bad, ",") .. ")")
end

print(string.format("[FANTOMES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
