--[[
  CHANTIER 4 du DC (ordres du joueur trop lents à démarrer ; partie du DC en 0.9.4 : ordre Maj+A à 29,4 min, bande de l'ordre en vol à
  31,8 min, prise par l'entrepreneur à 53,5 min seulement, pose à 57,8 min, 1 706 s ; l'ordre « porte par le projet 'ordre:iron' : etat
  bloque, cause electrique:iron »).
    1. E.order_step : la bande d'un ordre est prise tout de suite, le chantier courant (pas un ordre) est suspendu ; sans bande en vol, le
       champ de l'ordre est déclenché (ni débit ni place exigés).
    2. Co.goals : un type refusé en thermique (view.thermal_off) n'a plus de but « ordre:<type> » bloqué : l'ordre est porté par la bande.
    3. Co.pose_steps : les pas joués à la POSE (tournée Maj+E, bande Maj+A) au lieu d'une passe périodique.
    4. Câblage (sources) : pas de l'ordre au pas du kit (300 ticks) et dès que l'ordre retient son champ, suspension sans perte, reprise.
  Chaque batterie a son MUTANT (règle retirée : la batterie échoue).
  Lancement, depuis la racine du mod : lua5.2 tests/c4_ordres_test.lua
]]
package.path = "./?.lua;" .. package.path
local ok, ko = 0, 0
local function check(c, msg) if c then ok = ok + 1 else ko = ko + 1; print("  ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local function mutant(path, pat, rep)
  local src = read(path)
  local s2, n = src:gsub(pat, rep, 1)
  if n ~= 1 then return nil end
  return assert(load(s2, "=" .. path .. "(mutant)"))()
end

-- 1. E.order_step ---------------------------------------------------------------------------------------------------------------
local function battery_step(E)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  local fl = { { pid = 35, oid = 100001 }, { pid = 50, oid = 100004 } }
  local w = { [100004] = true }
  -- partie du DC : chantier 35 (pas un ordre), bande 50 de l'ordre en vol -> attache 50, 35 suspendu
  local a, i, sus = E.order_step({ wanted = w, cur = { pid = 35, oid = 100001 }, inflight = fl })
  ck(a == "attache" and i == 2 and sus == true)
  -- sans chantier : attache sans suspension
  a, i, sus = E.order_step({ wanted = w, inflight = fl })
  ck(a == "attache" and i == 2 and not sus)
  -- déjà sur l'ordre : rien
  ck(E.order_step({ wanted = w, cur = { pid = 50, oid = 100004 }, inflight = fl }) == "rien")
  -- bande de l'ordre pas encore en vol : déclenche le champ de l'ordre, chantier courant suspendu
  a, i, sus = E.order_step({ wanted = w, cur = { pid = 35, oid = 100001 }, inflight = { fl[1] } })
  ck(a == "declenche" and i == 100004 and sus == true)
  -- déjà attendu : rien (pas de rafale)
  ck(E.order_step({ wanted = w, inflight = {}, waiting = 100004 }) == "rien")
  -- attente d'un champ SANS ordre : l'ordre reprend la main
  a, i = E.order_step({ wanted = w, inflight = {}, waiting = 100001 })
  ck(a == "declenche" and i == 100004)
  -- aucun ordre : rien (le scan garde sa règle)
  ck(E.order_step({ wanted = {}, cur = { pid = 35, oid = 100001 }, inflight = fl }) == "rien")
  -- deux ordres : le plus petit numéro de champ d'abord (déterministe)
  a, i = E.order_step({ wanted = { [100009] = true, [100005] = true }, inflight = {} })
  ck(a == "declenche" and i == 100005)
  return fails
end
local E = require("shared.team.entrepreneur")
check(battery_step(E) == 0, "1. E.order_step : bande d'ordre prise, chantier courant suspendu, champ déclenché")
do
  local m = mutant("shared/team/entrepreneur.lua", "if x%.oid ~= nil and wanted%[x%.oid%] then return \"attache\", i, cur ~= nil end", "")
  check(m ~= nil and battery_step(m) > 0, "1. mutant (pas d'attache de la bande d'ordre) : la batterie échoue")
  local m2 = mutant("shared/team/entrepreneur.lua", "return \"attache\", i, cur ~= nil", "return \"attache\", i, false")
  check(m2 ~= nil and battery_step(m2) > 0, "1. mutant (pas de suspension) : la batterie échoue")
end

-- 2. Co.goals et la garde électrique -----------------------------------------------------------------------------------------------
local function battery_goals(Co)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  local orders = { { id = 1, kind = "gisement", outpost = "iron", x = 2, y = 92, r = 41 } }
  -- type refusé en thermique : aucun but d'ordre, l'extraction existante n'est pas relevée en ordre
  local g = Co.goals({ { key = "extraction:iron", family = "extraction", outpost = "iron", value = 10 } }, orders, 1000, { iron = "iron-plate" },
    { iron = "centrale finie" })
  ck(#g == 1 and g[1].ordre == nil and g[1].value == 10)
  -- type permis : le but d'ordre comme avant
  g = Co.goals({}, orders, 1000, { iron = "iron-plate" }, nil)
  ck(#g == 1 and g[1].key == "ordre:iron" and g[1].ordre == 1)
  g = Co.goals({}, orders, 1000, { iron = "iron-plate" }, { copper = "x" })
  ck(#g == 1 and g[1].key == "ordre:iron")
  return fails
end
local Co = require("shared.ai3.commande")
check(battery_goals(Co) == 0, "2. Co.goals : type refusé en thermique porté par la bande, sinon but d'ordre")
do
  local m = mutant("shared/ai3/commande.lua", " and not %(off and off%[k%]%)", "")
  check(m ~= nil and battery_goals(m) > 0, "2. mutant (garde électrique retirée) : la batterie échoue")
end

-- 3. Co.pose_steps ------------------------------------------------------------------------------------------------------------------
local function has(list, x) for _, v in ipairs(list) do if v == x then return true end end return false end
local function battery_pose(C)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  ck(has(C.pose_steps("liaison"), "tournee") and has(C.pose_steps("liaison"), "liaison"))
  ck(has(C.pose_steps("gisement"), "bande") and not has(C.pose_steps("gisement"), "tournee"))
  ck(has(C.pose_steps("amelioration"), "capital") and has(C.pose_steps("bastion"), "capital"))
  return fails
end
check(battery_pose(Co) == 0, "3. Co.pose_steps : tournée (Maj+E) et bande (Maj+A) jouées à la pose")
do
  local m = mutant("shared/ai3/commande.lua", "; out%[#out %+ 1%] = \"tournee\"", "")
  check(m ~= nil and battery_pose(m) > 0, "3. mutant (tournée renvoyée à la passe de résolution) : la batterie échoue")
end

-- 4. Câblage -----------------------------------------------------------------------------------------------------------------------
local MC = read("script/team/migration_champ.lua")
local CMD = read("script/gui/commande.lua")
check(MC:find("then Mig.entrepreneur_order(f, e.tick) end", 1, true) ~= nil, "4. pas de l'ordre au pas du kit (300 ticks)")
check(CMD:find("MigChamp.entrepreneur_order(f, tick)", 1, true) ~= nil, "4. réveil dès que l'ordre retient son champ (want_band)")
check(CMD:find("for _, step in ipairs(Co.pose_steps(o.kind)) do", 1, true) ~= nil, "4. pose : pas de Co.pose_steps joués")
check(CMD:find("step == \"tournee\" and order.a and not order.tour then liaison_tour(", 1, true) ~= nil, "4. tournée Maj+E à la pose")
check(MC:find("cur.spec.entrepreneur, cur.spec.ent_susp = nil, true", 1, true) ~= nil, "4. suspension : marquage retiré, suspendu noté")
check(MC:find("p.spec.entrepreneur, p.spec.ent_susp = true, nil", 1, true) ~= nil, "4. reprise du suspendu")
check(read("script/team/build.lua"):find("if p.spec and p.spec.ent_susp then return nil end", 1, true) ~= nil, "4. réserve du suspendu gardée (pile_family)")
check(MC:find("if ent.ordre then ok = true end", 1, true) ~= nil, "4. la bande d'un ordre tient la tête (kit)")
check(read("shared/ai3/cerveau.lua"):find("prod, view.thermal_off)", 1, true) ~= nil, "4. le cerveau passe la garde électrique à Co.goals")
check(MC:find("ordre = ms.ent_wait.ordre", 1, true) ~= nil, "4. une bande d'ordre reconnue par follow garde sa marque d'ordre")

print(string.format("[C4-ORDRES] BILAN : %d OK, %d ECHEC(S)", ok, ko))
if ko > 0 then os.exit(1) end
