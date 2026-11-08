-- Lot RANGEES-ASM (suite) : rangée d'assembleurs dynamique (shared/team/rangee_dyn.lua, script/team/rangee_dyn.lua) et sortie sur deux
-- voies (shared/team/modules.lua, G.simple voies = 2). Hors jeu ; mutants refusés en fin.
package.path = "./?.lua;" .. package.path
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
local M = require("shared.team.modules")
local Rd = require("shared.team.rangee_dyn")
local Rg = require("script.team.rangee_dyn")

local ok, ko = 0, 0
local function check(name, cond, info)
  if cond then ok = ok + 1 else ko = ko + 1 print("ECHEC : " .. name .. (info and (" (" .. tostring(info) .. ")") or "")) end
end

local CABLE, PLATE, A1, A2 = "copper-cable", "copper-plate", "assembling-machine-1", "assembling-machine-2"
local function kind(name)
  local sp = M.spec(name)
  if sp and sp.kind == "assembler" then return "machine" end
  if sp and sp.kind == "inserter" then return "inserter" end
end
local function width(name) return (M.spec(name) or {}).w or 1 end
local function count_kind(ents, k) local c = 0 for _, e in ipairs(ents) do if kind(e.name) == k then c = c + 1 end end return c end

-- §1 gabarit à deux voies : bornes, débits, contrôle complet
local g1 = M.GEN.simple(CABLE, 3, A1)
check("§1 une voie, assembleur 1 : borne 3", g1 and g1.extensions[1].max == 3, g1 and g1.extensions[1].max)
local g6 = M.GEN.simple(CABLE, 6, A1, 2)
check("§1 deux voies, assembleur 1 : borne 6", g6 and g6.extensions[1].max == 6, g6 and g6.extensions[1].max)
local g4 = M.GEN.simple(CABLE, 4, A2, 2)
check("§1 deux voies, assembleur 2 : borne 4", g4 and g4.extensions[1].max == 4, g4 and g4.extensions[1].max)
for n = 1, 6 do
  local g = M.GEN.simple(CABLE, n, A1, 2)
  local errs, rep = M.check(g)
  check("§1 deux voies n=" .. n .. " : 0 erreur, " .. 2 * n .. " cables/s", g and #errs == 0 and math.abs((rep.outputs[CABLE] or 0) - 2 * n) < 1e-6,
    errs and errs[1])
end
local g5b = M.GEN.simple(CABLE, 5, A2, 2)
check("§1 deux voies, assembleur 2 a 5 : une voie depasse (refus du controle)", g5b and #M.check(g5b) > 0)
local nports = 0
for _, p in ipairs(g6.ports) do if p.io == "out" then nports = nports + 1 end end
check("§1 un seul port de sortie", nports == 1, nports)
check("§1 arguments gardes (voies = 2) : refait a l'identique", #g6.args == 4 and g6.args[4] == 2 and M.extend(g6, 3) ~= nil)

-- §1 bis tapis des données (argument 5) : la borne suit la voie du tapis posé (réponse du lead : tapis le plus rapide débloqué)
local FB = { name = "fast-transport-belt", lane = 15 }
local gf = M.GEN.simple(CABLE, 5, A2, 1, FB)
local errs_f, rep_f = M.check(gf)
check("§1b tapis a 15/s par voie, assembleur 2 : borne 5 sur une voie", gf and gf.extensions[1].max == 5, gf and gf.extensions[1].max)
check("§1b 5 assembleurs 2 : 0 erreur, 15 cables/s", gf and #errs_f == 0 and math.abs((rep_f.outputs[CABLE] or 0) - 15) < 1e-6, errs_f and errs_f[1])
local all_fast, nbelt = true, 0
for _, e in ipairs(gf.entities) do if (M.spec(e.name) or {}).kind == "belt" then nbelt = nbelt + 1 if e.name ~= FB.name then all_fast = false end end end
check("§1b tous les tapis du gabarit sont ceux des donnees", all_fast and nbelt > 0)
local gf2 = M.GEN.simple(CABLE, 6, A2, 2, FB)
check("§1b deux voies rapides : borne 6 (largeur), 0 erreur", gf2 and gf2.extensions[1].max == 6 and #M.check(gf2) == 0)
check("§1b refait a l'identique (M.extend garde le tapis)", M.extend(gf, 3) and M.extend(gf, 3).params.belt == FB.name and #M.extend(gf, 3).args == 5)
local gy = { entities = {}, ports = gf.ports, w = gf.w, h = gf.h, key = gf.key, anchors = gf.anchors, fuel_ports = gf.fuel_ports,
  water = gf.water, notes = {}, params = gf.params, power_pole = gf.power_pole }
for i, e in ipairs(gf.entities) do gy.entities[i] = { name = e.name == FB.name and "transport-belt" or e.name, x = e.x, y = e.y, dir = e.dir, recipe = e.recipe, rate = e.rate, role = e.role } end
check("§1b controle : les memes 5 machines sur le tapis du modele depassent une voie", #M.check(gy) > 0)
check("§1b tapis invalide refuse", M.GEN.simple(CABLE, 2, A2, 1, { name = "x" }) == nil)

-- §2 colonnes, ordre, découpe, croissance (pur)
local cols, m = Rd.columns(g6.entities, kind, width)
check("§2 6 machines", m == 6, m)
local per = {}
for i, e in ipairs(g6.entities) do
  local c = cols[i]
  if c then per[c] = per[c] or { m = 0, b = 0 }; if kind(e.name) == "machine" then per[c].m = per[c].m + 1 else per[c].b = per[c].b + 1 end end
  if not c and kind(e.name) then check("§2 bras sans colonne " .. i, false) end
end
local okc = true
for c = 1, 6 do if not (per[c] and per[c].m == 1 and per[c].b >= 2) then okc = false end end
check("§2 chaque colonne : une machine et ses bras (haut et sortie)", okc)
local o = Rd.order(6, 3)
check("§2 ordre depuis la jonction", table.concat(o, ",") == "3,4,2,5,1,6", table.concat(o, ","))
check("§2 ordre sans jonction : ouest -> est", table.concat(Rd.order(4, nil), ",") == "1,2,3,4")
local keep, held = Rd.split(cols, #g6.entities, o, 2)
local hm = 0
for _, i in ipairs(held) do if kind(g6.entities[i].name) == "machine" then hm = hm + 1 end end
check("§2 n=2 : 4 machines en attente, tapis et poteaux gardes", hm == 4 and #keep + #held == #g6.entities)
local kept_belts = 0
for _, i in ipairs(keep) do if (M.spec(g6.entities[i].name) or {}).kind == "belt" then kept_belts = kept_belts + 1 end end
local all_belts = 0
for _, e in ipairs(g6.entities) do if (M.spec(e.name) or {}).kind == "belt" then all_belts = all_belts + 1 end end
check("§2 tous les tapis gardes", kept_belts == all_belts and all_belts > 0, kept_belts .. "/" .. all_belts)
local t, add = Rd.grow(2, 6, 5)
check("§2 croissance 2 -> 5", t == 5 and add == 3)
t, add = Rd.grow(5, 6, 9)
check("§2 croissance bornee a 6", t == 6 and add == 1)
t, add = Rd.grow(4, 6, 3)
check("§2 jamais de recul", t == 4 and add == 0)
-- rangée partielle (pièces en attente retirées) : contrôle complet à chaque taille
for n = 1, 6 do
  local _, h = Rd.split(cols, #g6.entities, o, n)
  local drop = {}
  for _, i in ipairs(h) do drop[i] = true end
  local gp = { entities = {}, ports = {}, w = g6.w, h = g6.h, key = g6.key, anchors = g6.anchors, fuel_ports = g6.fuel_ports,
    water = g6.water, notes = {}, params = g6.params }
  local remap = {}
  for i, e in ipairs(g6.entities) do if not drop[i] then gp.entities[#gp.entities + 1] = e remap[i] = #gp.entities end end
  for _, p in ipairs(g6.ports) do local q = {} for k, v in pairs(p) do q[k] = v end q.ent = remap[p.ent] gp.ports[#gp.ports + 1] = q end
  gp.power_pole = remap[g6.power_pole]
  local errs, rep = M.check(gp)
  check("§2 rangee partielle " .. n .. "/6 : 0 erreur, " .. 2 * n .. " cables/s", #errs == 0 and math.abs((rep.outputs[CABLE] or 0) - 2 * n) < 1e-6,
    errs[1] or rep.outputs[CABLE])
end

-- §3 au plan directeur (script/team/rangee_dyn.lua) : full, tag, split, grow
local function project(rangee)
  return { id = 7, state = "plan", spec = { gen = "simple", args = { CABLE, 2, A1, 2 }, rangee = rangee }, ents = {},
    outflow = { [CABLE] = 0 }, inflow = { [PLATE] = 0 } }
end
local f = { key = "test", build = { projects = {} } }
local p = project(true)
f.build.projects[7] = p
local gs = M.GEN.simple(CABLE, 2, A1, 2)
local gm = Rg.full(p, gs)
check("§3 gabarit a la borne (6), place entiere", gm.params.n == 6 and p.rangee_plan and p.rangee_plan.n == 2 and p.rangee_plan.n_max == 6)
p.outflow[CABLE], p.inflow[PLATE] = gm.nominal[CABLE], gm.inputs[PLATE]
local ents = {}
for _, e in ipairs(gm.entities) do ents[#ents + 1] = { name = e.name, x = e.x, y = e.y, part = 1 } end
Rg.tag(p, ents, gm)
p.ents = ents
Rg.after(f, p, true)
check("§3 2 machines posees, 4 en attente", count_kind(p.ents, "machine") == 2 and p.rangee and #p.rangee.held > 0 and p.rangee.n == 2)
check("§3 debit annonce a 2/6", math.abs(p.outflow[CABLE] - 4) < 1e-6, p.outflow[CABLE])
check("§3 journal de la rangee dynamique", LOGS[#LOGS]:find("rangee dynamique 2/6", 1, true) ~= nil, LOGS[#LOGS])
local mv = Rg.grow(f, 7, 5, 100)
check("§3 rangee pas finie : pas d'agrandissement", mv == 0)
p.state = "fini"
mv = Rg.grow(f, 7, 5, 100)
check("§3 finie : agrandie a 5 sur place", mv > 0 and p.rangee.n == 5 and count_kind(p.ents, "machine") == 5 and p.state == "reserve" and p.reopened == 1)
check("§3 debit annonce a 5/6", math.abs(p.outflow[CABLE] - 10) < 1e-6, p.outflow[CABLE])
p.state = "fini"
Rg.grow(f, 7, 9, 200)
check("§3 bornee a 6", p.rangee.n == 6 and count_kind(p.ents, "machine") == 6 and #p.rangee.held == 0)
p.state = "fini"
local mv2, why2 = Rg.grow(f, 7, 9, 300)
check("§3 pleine : rien", mv2 == 0 and why2 == "rangee pleine", why2)
local q = project(nil)
check("§3 sans spec.rangee : gabarit inchange", Rg.full(q, gs) == gs and q.rangee_plan == nil)
local old = { id = 8, state = "fini", ents = {} }
f.build.projects[8] = old
check("§3 projet d'avant ce lot : jamais agrandi", Rg.grow(f, 8, 5, 1) == 0)
_G.settings = { global = { ["fo-war-rangee-dyn"] = { value = false } } }
local q2 = project(true)
check("§3 reglage eteint : gabarit inchange", Rg.full(q2, gs) == gs and q2.rangee_plan == nil)
_G.settings = nil

-- §3 bis crochet du modèle : un tapis des données inconnu est lu aux prototypes (partie chargée, poste qui rejoint : aucun gabarit
-- n'a encore été généré)
local function proto(speed) return { belt_speed = speed, items_to_place_this = { { name = "obj" } }, has_flag = function() return false end } end
_G.game = { get_filtered_entity_prototypes = function() return { ["tapis-banc-x"] = proto(0.0625), ["tapis-banc-y"] = proto(0.03125) } end }
local sx = M.spec("tapis-banc-x")
check("§3b tapis inconnu lu aux prototypes : voie 15/s", sx and sx.kind == "belt" and math.abs(sx.lane - 15) < 1e-9 and sx.w == 1, sx and sx.lane)
check("§3b nom qui n'est pas un tapis : rien", M.spec("pas-un-tapis-banc") == nil)
_G.game = nil

-- §4 mutants : chacun doit faire échouer au moins un contrôle de la règle pure
local function rule_ok(R)
  local c2, m2 = R.columns(g6.entities, kind, width)
  if m2 ~= 6 then return false end
  if table.concat(R.order(6, 3), ",") ~= "3,4,2,5,1,6" then return false end
  local k2, h2 = R.split(c2, #g6.entities, R.order(6, 3), 2)
  local hm2 = 0
  for _, i in ipairs(h2) do if kind(g6.entities[i].name) == "machine" then hm2 = hm2 + 1 end end
  if hm2 ~= 4 or #k2 + #h2 ~= #g6.entities then return false end
  local nb = 0
  for _, i in ipairs(h2) do if kind(g6.entities[i].name) == "inserter" then nb = nb + 1 end end
  if nb == 0 then return false end
  local a, b = R.grow(5, 6, 9)
  return a == 6 and b == 1
end
check("§4 temoin : la regle passe", rule_ok(Rd))
local MUTANTS = {
  { "ordre sans alternance", function(R) R.order = function(n) local t = {} for i = 1, n do t[i] = i end return t end end },
  { "decoupe qui garde tout", function(R) local s = R.split R.split = function(c, n) local k = {} for i = 1, n do k[i] = i end return k, {} end end },
  { "bras sans colonne", function(R) local c0 = R.columns R.columns = function(e, kd, w) return c0(e, function(n) local k = kd(n) return k == "machine" and k or nil end, w) end end },
  { "croissance sans borne", function(R) R.grow = function(n, nm, n2) return n2, n2 - n end end },
  { "machines comptees en double", function(R) local c0 = R.columns R.columns = function(...) local c, m3 = c0(...) return c, m3 + 1 end end },
}
for _, mu in ipairs(MUTANTS) do
  package.loaded["shared.team.rangee_dyn"] = nil
  local R = require("shared.team.rangee_dyn")
  mu[2](R)
  check("§4 mutant refuse : " .. mu[1], not rule_ok(R))
end
package.loaded["shared.team.rangee_dyn"] = nil

print(string.format("[RANGEE-DYN] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
