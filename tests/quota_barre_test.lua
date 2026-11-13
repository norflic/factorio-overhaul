--[[
  Lot VIDEO-L4, complément (demande du lead, 7/11) : Ind.sweep (script/ai3/industrie.lua) pose la BARRE des coffres de sortie de tout projet
  fini qui a un quota (p.quota.outs[i].cases, posé par script/team/quotas_glue.lua), la plus petite avec la barre d'un patron ou d'un bloc.
  Le VRAI module est chargé par le moteur simulé (tests/mock_engine.lua) ; la surface et les coffres sont des bouchons (le mock n'a pas
  de barre d'inventaire) : chaque set_bar est noté.
    §1 projet « module » fini à 2 sorties, quota 3 et 5 cases : barres 4 et 6 (F95 : cases + 1), 3e valeur rendue 2 ;
    §2 idempotent : un second passage ne pose rien ; un quota recalculé (autre clé) la refait ; une nouvelle fin la refait ;
    §3 rien sans quota (absent ou false), rien pour un projet pas fini, rien pour un coffre absent ;
    §4 coffre de 2 cases, quota de 5 : barre 3 (jamais plus que le coffre) ;
    §5 patron (barre propre 2) au quota de 4 cases : la plus petite, barre 3 ; patron au quota de 1 case : barre 2 ;
    §6 réglage de l'industrie éteint : la barre de quota est posée quand même (les quotas de L4 valent sans lui).
  Usage : lua5.2 tests/quota_barre_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[QUOTA-BARRE] ECHEC : " .. msg) end
end

M.new_world({ difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
M.dispatch(M.world().on_init) -- (global.fo : le journal d'Ind.sweep lit l'horloge de la guerre)
local Ind = package.loaded["script.ai3.industrie"]
local A = package.loaded["shared.ai3.automatiser"]
local Rsv = package.loaded["script.ai3.reserve"]
assert(Ind and A and Rsv, "modules absents")
local CHEST = A.exec_chest()
assert(CHEST, "coffre de l'exécutant inconnu")

-- Bouchons : coffres par position « x,y », chacun avec ses cases et la liste des set_bar reçus.
local function new_surface()
  local s = { chests = {} }
  function s.add(x, y, slots)
    local inv = setmetatable({ bars = {} }, { __len = function() return slots end })
    inv.supports_bar = function() return true end
    inv.set_bar = function(v) inv.bars[#inv.bars + 1] = v end
    s.chests[x .. "," .. y] = { valid = true, inv = inv, get_inventory = function() return inv end }
    return inv
  end
  s.find_entity = function(name, pos)
    if name ~= CHEST then return nil end
    return s.chests[pos[1] .. "," .. pos[2]]
  end
  return s
end
local function team(surface, projects)
  local order, by = {}, {}
  for i, p in ipairs(projects) do order[i] = i; by[i] = p end
  return { key = "banc", hq = { valid = true, surface = surface }, build = { order = order, projects = by } }
end
local function project(gen, outs, quota, extra)
  local p = { state = "fini", finished = 1, spec = { gen = gen, args = {} }, outs = outs, quota = quota, quota_key = "k1", ents = {}, quais = {} }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end
local function last(inv) return inv.bars[#inv.bars] end

local rsv_on = Rsv.on
Rsv.on = function() return false end -- §1 à §5 : l'industrie éteinte (la partie patron n'est jouée qu'au §5)

-- §1
local s = new_surface()
local i1, i2 = s.add(10, 0, 32), s.add(12, 0, 32)
local p = project("module", { { x = 10, y = 0 }, { x = 12, y = 0 } }, { outs = { { cases = 3 }, { cases = 5 } } })
local f = team(s, { p })
local _, _, qb = Ind.sweep(f, 60)
check(qb == 2 and last(i1) == 4 and last(i2) == 6, string.format("§1 barres de quota 4 et 6 (%s, %s), %s posée(s)", tostring(last(i1)),
  tostring(last(i2)), tostring(qb)))
-- §2
local _, _, qb2 = Ind.sweep(f, 120)
check(qb2 == 0 and #i1.bars == 1, "§2 second passage : rien (" .. tostring(qb2) .. ")")
p.quota_key, p.quota = "k2", { outs = { { cases = 2 }, { cases = 5 } } }
local _, _, qb3 = Ind.sweep(f, 180)
check(qb3 == 2 and last(i1) == 3, "§2 quota recalculé : barre refaite (" .. tostring(last(i1)) .. ")")
p.finished = 2
local _, _, qb4 = Ind.sweep(f, 240)
check(qb4 == 2 and #i1.bars == 3, "§2 nouvelle fin du projet : barre refaite (" .. tostring(qb4) .. ")")
-- §3
local s3 = new_surface()
local j1, j2, j3 = s3.add(1, 1, 32), s3.add(2, 2, 32), s3.add(3, 3, 32)
local f3 = team(s3, { project("module", { { x = 1, y = 1 } }, nil), project("module", { { x = 2, y = 2 } }, false),
  project("module", { { x = 3, y = 3 } }, { outs = { { cases = 4 } } }, { state = "chantier" }),
  project("module", { { x = 9, y = 9 } }, { outs = { { cases = 4 } } }) })
local _, _, q5 = Ind.sweep(f3, 60)
check(q5 == 0 and #j1.bars == 0 and #j2.bars == 0 and #j3.bars == 0,
  "§3 sans quota, quota false, projet pas fini, coffre absent : aucune barre (" .. tostring(q5) .. ")")
-- §4
local s4 = new_surface()
local k1 = s4.add(5, 5, 2)
Ind.sweep(team(s4, { project("module", { { x = 5, y = 5 } }, { outs = { { cases = 5 } } }) }), 60)
check(last(k1) == 3, "§4 coffre de 2 cases, quota de 5 : barre 3 (" .. tostring(last(k1)) .. ")")
-- §6 (avant §5 : l'industrie est toujours éteinte ici)
check(last(i1) ~= nil and last(k1) ~= nil, "§6 réglage de l'industrie éteint : les barres de quota sont posées quand même")

-- §5 patron : la partie patron d'Ind.sweep tourne avec l'industrie allumée
Rsv.on = function() return true end
local s5 = new_surface()
local m1, m2 = s5.add(20, 0, 32), s5.add(22, 0, 32)
local pa = project("patron", { { x = 20, y = 0 } }, { outs = { { cases = 4 } } })
pa.spec.args = { nil, nil, nil, nil, nil, 2 }
local pb = project("patron", { { x = 22, y = 0 } }, { outs = { { cases = 1 } } })
pb.spec.args = { nil, nil, nil, nil, nil, 2 }
Ind.sweep(team(s5, { pa, pb }), 60)
check(last(m1) == 3, "§5 patron à barre 2, quota de 4 : la plus petite, barre 3 (" .. tostring(last(m1)) .. ")")
check(last(m2) == 2, "§5 patron à barre 2, quota de 1 : barre 2 (" .. tostring(last(m2)) .. ")")
Rsv.on = rsv_on

-- s40 p19 : les blocs morts (refusés ou perdus, report déjà posé) quittent la liste suivie ; les vivants gardent leur ordre
do
  local a, b, c, d = { id = 1 }, { id = 2, dead = true }, { id = 3 }, { id = 4, dead = true }
  local out = Ind.vivants({ a, b, c, d })
  check(#out == 2 and out[1] == a and out[2] == c, "s40 p19 : blocs morts retirés, ordre des vivants gardé")
  local same = { a, c }
  check(Ind.vivants(same) == same, "s40 p19 : aucun mort : la même table est rendue (rien n'est réécrit)")
  check(#Ind.vivants({}) == 0 and #Ind.vivants({ b }) == 0, "s40 p19 : liste vide, liste de morts")
end

print(string.format("[QUOTA-BARRE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
