--[[
  Lot TV-FLUX, point C11 (docs/TODO_VIDEO.md l.306, « sans modules, recalculer les quotas ») : test hors jeu de Q.pieces et Q.scale
  (shared/team/quotas.lua) et de leur branchement dans la colle script/team/quotas_glue.lua (Qg.of, Qg.pieces, réglage fo-war-quotas-pieces).
    §1 Q.pieces : machines à recette posées / prévues, le reste ne compte pas ;
    §2 Q.scale : débits ramenés à la part posée, bornes, copie, mêmes clés ;
    §3 Qg.of : tout posé = le quota d'avant au chiffre près ; machines manquantes = quota réduit (coffre de sortie plus petit, une minute
       d'ingrédients plus petite) ; réglage éteint ou absent = nominal ; recalcul quand la part change, pas avant ; journal [FO-QUOTAS] ;
    §4 mutants (substitution dans les sources de quotas.lua et quotas_glue.lua).
  Lancement, depuis la racine du mod :   lua5.2 tests/flux_quotas_test.lua   -> [FLUX-QUOTAS] BILAN : N OK, 0 ECHEC(S)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1 if not quiet then print("[FLUX-QUOTAS] ECHEC : " .. msg) end end
  return cond
end
local function say(s) if not quiet then print("[FLUX-QUOTAS] " .. s) end end
local function read_all(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local function near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-9 end

local Q_SRC = read_all("shared/team/quotas.lua")
local G_SRC = read_all("script/team/quotas_glue.lua")

local LOGS
_G.log = function(s) LOGS[#LOGS + 1] = s end
_G.game = { item_prototypes = { ["aa-plaque"] = { stack_size = 100 }, ["bb-minerai"] = { stack_size = 50 } } }
local SETTING = true
_G.settings = { global = setmetatable({}, { __index = function(_, k)
  if k == "fo-war-quotas-pieces" then if SETTING == nil then return nil end return { value = SETTING } end
  return nil
end }) }

local function project(built_n, total_n)
  local ents = { { name = "tapis" }, { name = "bras" } }
  for i = 1, total_n do ents[#ents + 1] = { name = "four", recipe = "aa-fonte", built = i <= built_n } end
  return { id = 7, ents = ents, outflow = { ["aa-plaque"] = 2 }, inflow = { ["bb-minerai"] = 2 },
    outs = { { x = 0, y = 0 } }, quais = { { x = 1, y = 1, item = "bb-minerai" } } }
end

local function load_mod(q_src, g_src)
  local saved_q, saved_g = package.loaded["shared.team.quotas"], package.loaded["script.team.quotas_glue"]
  package.loaded["shared.team.quotas"] = nil
  package.loaded["script.team.quotas_glue"] = nil
  local Q = assert(load(q_src, "@quotas"))()
  package.loaded["shared.team.quotas"] = Q
  local Qg = assert(load(g_src, "@quotas_glue"))()
  package.loaded["shared.team.quotas"], package.loaded["script.team.quotas_glue"] = saved_q, saved_g
  return Q, Qg
end

local function suite(Q, Qg, chk)
  -- §1
  local num, den = Q.pieces({ { name = "x", recipe = "r", built = true }, { name = "y", recipe = "r" }, { name = "tapis", built = true },
    { name = "z", recipe = "r", built = true }, { name = "bras" } })
  chk(num == 2 and den == 3, "§1 2 machines à recette posées sur 3 prévues (tapis et bras ne comptent pas) : " .. tostring(num) .. "/" .. tostring(den))
  local n0, d0 = Q.pieces({})
  chk(n0 == 0 and d0 == 0, "§1 rien : 0 sur 0")
  n0, d0 = Q.pieces(nil)
  chk(n0 == 0 and d0 == 0, "§1 liste absente : 0 sur 0")

  -- §2
  local sc = Q.scale({ a = 4, b = 1 }, 1, 4)
  chk(near(sc.a, 1) and near(sc.b, 0.25), "§2 un quart : 4 -> 1 et 1 -> 0,25")
  local full = Q.scale({ a = 4 }, 3, 3)
  chk(near(full.a, 4), "§2 tout posé : mêmes débits")
  local flows = { a = 4 }
  local cp = Q.scale(flows, 4, 4)
  chk(cp ~= flows, "§2 table neuve (copie) même sans changement")
  chk(near(Q.scale({ a = 4 }, 9, 3).a, 4) and near(Q.scale({ a = 4 }, -2, 3).a, 0), "§2 num borné à [0, den]")
  chk(near(Q.scale({ a = 4 }, 1, 0).a, 4) and near(Q.scale({ a = 4 }, nil, nil).a, 4), "§2 rien de prévu : mêmes débits")
  chk(next(Q.scale(nil, 1, 2)) == nil, "§2 débits absents : table vide")
  chk(Q.scale({ a = "x" }, 1, 2).a == "x", "§2 une valeur non numérique est gardée telle quelle")

  -- §3
  LOGS = {}
  SETTING = true
  local pall = project(3, 3)
  local qall = Qg.of(pall, 32, 32, 200)
  SETTING = false
  local qall_off = Qg.of(project(3, 3), 32, 32, 200)
  chk(qall and qall_off and qall.ins[1].want == qall_off.ins[1].want and qall.outs[1].cap == qall_off.outs[1].cap
    and qall.outs[1].collect_at == qall_off.outs[1].collect_at, "§3 tout posé : le quota d'avant, au chiffre près")
  chk(#LOGS == 0, "§3 tout posé : aucune ligne de journal")
  SETTING = true
  local phalf = project(1, 3)
  local qhalf = Qg.of(phalf, 32, 32, 200)
  chk(qhalf and qhalf.ins[1].want < qall.ins[1].want and qhalf.outs[1].cap < qall.outs[1].cap,
    "§3 1 machine sur 3 : moins d'ingrédients portés (" .. tostring(qhalf and qhalf.ins[1].want) .. " contre " .. tostring(qall.ins[1].want)
    .. "), coffre de sortie plus petit (" .. tostring(qhalf and qhalf.outs[1].cap) .. " contre " .. tostring(qall.outs[1].cap) .. ")")
  chk(qhalf and qhalf.ins[1].want == 50, "§3 une minute d'ingrédients à 1/3 de 2 objets/s = 40 objets, remontée à une pile (50) par voyage : " .. tostring(qhalf and qhalf.ins[1].want))
  chk(#LOGS == 1 and LOGS[1]:find("%[FO%-QUOTAS%] projet 7 : 1 machine") and LOGS[1]:find("sur 3"), "§3 une ligne [FO-QUOTAS] au changement de part : " .. tostring(LOGS[1]))
  -- même part : le quota gardé, pas de nouvelle ligne
  local qagain = Qg.of(phalf, 32, 32, 200)
  chk(qagain == qhalf and #LOGS == 1, "§3 même part : quota gardé, pas de nouvelle ligne")
  -- une machine de plus : recalcul
  phalf.ents[4].built = true
  local q2 = Qg.of(phalf, 32, 32, 200)
  chk(q2 ~= qhalf and q2.ins[1].want > qhalf.ins[1].want and q2.ins[1].want < qall.ins[1].want and #LOGS == 2, "§3 une machine de plus : quota recalculé (80 contre 50), une ligne de plus")
  -- tout posé après un chantier partiel : retour au nominal et une ligne le dit
  phalf.ents[5].built = true
  local q3 = Qg.of(phalf, 32, 32, 200)
  chk(q3 and q3.ins[1].want == qall.ins[1].want and #LOGS == 3 and LOGS[3]:find("toutes les machines"), "§3 tout posé après coup : nominal, une ligne le dit")
  -- réglage éteint ou absent : nominal même avec des machines manquantes
  SETTING = false
  local qoff = Qg.of(project(1, 3), 32, 32, 200)
  chk(qoff and qoff.ins[1].want == qall.ins[1].want, "§3 réglage éteint : nominal malgré les machines manquantes")
  SETTING = nil
  local qabs = Qg.of(project(1, 3), 32, 32, 200)
  chk(qabs and qabs.ins[1].want == qall.ins[1].want, "§3 réglage absent (moteur simulé) : nominal")
  SETTING = true
  -- aucune machine posée : débits nuls, ancienne règle (pas de quota)
  local qzero = Qg.of(project(0, 3), 32, 32, 200)
  chk(qzero == nil, "§3 aucune machine posée : pas de quota (ancienne règle)")
  -- sans machine à recette : le nominal
  local pnone = project(0, 0)
  local qn = Qg.of(pnone, 32, 32, 200)
  chk(qn and qn.ins[1].want == qall.ins[1].want, "§3 aucune machine à recette dans le projet : nominal")
  -- pièces : les débits du projet ne sont pas modifiés (table de nominaux intacte)
  local pc = project(1, 3)
  Qg.of(pc, 32, 32, 200)
  chk(near(pc.outflow["aa-plaque"], 2) and near(pc.inflow["bb-minerai"], 2), "§3 les débits nominaux du projet restent intacts")
  -- part retrouvée dans la clé : deux parts, deux quotas
  chk(Qg.pieces(project(1, 3)) == 1 and select(2, Qg.pieces(project(1, 3))) == 3 and Qg.pieces(project(3, 3)) == nil, "§3 Qg.pieces : 1 sur 3, ou nil quand tout est posé")
end

local Q, Qg = load_mod(Q_SRC, G_SRC)
suite(Q, Qg, check)
say(string.format("suite principale : %d OK, %d ECHEC(S)", pass, fail))

-- §4 mutants
local function mutate(src, old, new)
  local i, j = src:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  assert(not src:find(old, j + 1, true), "mutant : motif ambigu : " .. old)
  return src:sub(1, i - 1) .. new .. src:sub(j + 1)
end
local MUTANTS = {
  { "q", "machine sans recette comptée", "    if e.recipe then\n      den = den + 1", "    if true then\n      den = den + 1" },
  { "q", "machine non posée comptée posée", "      if e.built then num = num + 1 end", "      num = num + 1" },
  { "q", "part inversée", "k = max(0, min(num, den)) / den", "k = den / max(1, min(num, den))" },
  { "q", "num non borné", "k = max(0, min(num, den)) / den", "k = num / den" },
  { "q", "débits non réduits", "if type(v) == \"number\" and k and k < 1 then out[key] = v * k else out[key] = v end", "out[key] = v" },
  { "q", "valeur non numérique multipliée", "if type(v) == \"number\" and k and k < 1 then", "if k and k < 1 then" },
  { "g", "réglage ignoré (toujours recalculé)", "  if not Qg.pieces_on() then return nil end", "" },
  { "g", "réglage inversé", "  if not Qg.pieces_on() then return nil end", "  if Qg.pieces_on() then return nil end" },
  { "g", "tout posé traité en manque", "if den <= 0 or num >= den then return nil end", "if den <= 0 then return nil end" },
  { "g", "part absente de la clé (quota gardé à tort)", "num and string.format(\":p%d/%d\", num, den) or \"\")", "\"\")" },
  { "g", "sortie nominale gardée", "if num then outflow, inflow = Qt.scale(outflow, num, den), Qt.scale(inflow, num, den) end", "" },
  { "g", "entrée nominale gardée", "Qt.scale(outflow, num, den), Qt.scale(inflow, num, den)", "Qt.scale(outflow, num, den), inflow" },
  { "g", "sortie nominale gardée (produits)", "Qt.scale(outflow, num, den), Qt.scale(inflow, num, den)", "outflow, Qt.scale(inflow, num, den)" },
  { "g", "journal à chaque calcul", "if (p.quota_share or \"tout\") ~= share then", "if true then" },
  { "g", "journal jamais", "if (p.quota_share or \"tout\") ~= share then", "if false then" },
}
local killed, survivors = 0, {}
for _, m in ipairs(MUTANTS) do
  local qs, gs = Q_SRC, G_SRC
  if m[1] == "q" then qs = mutate(Q_SRC, m[3], m[4]) else gs = mutate(G_SRC, m[3], m[4]) end
  local dead = false
  local okl, Qm, Gm = pcall(load_mod, qs, gs)
  if not okl then dead = true else
    local f0, p0, q0 = fail, pass, quiet
    quiet = true
    local ran = pcall(suite, Qm, Gm, check)
    dead = (not ran) or fail > f0
    fail, pass, quiet = f0, p0, q0
  end
  if dead then killed = killed + 1 else survivors[#survivors + 1] = m[2] end
end
check(#survivors == 0, "§4 mutants survivants : " .. table.concat(survivors, " ; "))
say(string.format("mutants refusés : %d sur %d", killed, #MUTANTS))
print(string.format("[FLUX-QUOTAS] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, killed, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
