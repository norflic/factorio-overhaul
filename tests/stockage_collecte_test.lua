--[[
  Lot STOCKAGE-VITAL (7/11), demande du lead après le plantage « Colr » de sol-dc-c8239b75 (corrigé par 259aca16) : le VRAI code de
  script/team/build.lua (out_wanted, out_tasks, et la branche « collect » de Build.work), extrait entre ses repères et exécuté avec
  un moteur de bouchons, quand Stock.skip_fn REND une fonction (stock plein : la pierre est écartée). Avant 259aca16, ces chemins
  appelaient Colr.take_list, un global absent : la partie du DC plantait dès la première collecte d'un coffre de sortie.

  Critères (écrits avant le code du test) :
    C1. aucun appel ne lève d'erreur quand Stock.skip_fn rend une fonction ;
    C2. out_tasks : un coffre de sortie qui ne tient que des objets écartés n'émet AUCUNE tâche ; un coffre qui tient aussi du fer
        en émet une (clé ia1d:<projet>:o:<i>, mode collect) ;
    C3. Stock.skip_fn absent, ou qui rend nil : les deux coffres émettent leur tâche (règle d'avant) ;
    C4. collecte (Build.work, mode collect) : le fer entre au sac, la pierre écartée reste au coffre, « done », compteur collected ;
    C5. coffre qui ne tient que de l'écarté : rien n'est pris, « done » (pas un voyage à vide : rien à prendre à l'arrivée) ;
    C6. sac plein devant du fer : « fail », f.stats.collecte_vide = 1, une ligne [FO-COLLECTE] ;
    C7. sans écart, sac de 60 objets : le fer d'abord (50), puis 10 pierres (matières vitales d'abord, code réel).
  Mutants, sur le texte extrait :
    « Colr nu » (Build.Colr.take_list -> Colr.take_list, le défaut d'avant 259aca16) : doit PLANTER, erreur qui nomme Colr ;
    « écart ignoré à la sortie » et « écart ignoré à la collecte » : au moins un contrôle doit échouer.
  Usage, depuis la racine du mod :   lua5.2 tests/stockage_collecte_test.lua
]]
package.path = "./?.lua;" .. package.path
local Colr = require("shared.team.collecte")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end

---------------------------------------------------------------------------------------------------
-- Le vrai code, extrait entre ses repères
---------------------------------------------------------------------------------------------------
local fh = assert(io.open("script/team/build.lua", "rb"))
local src = fh:read("*a")
fh:close()
local function between(a_mark, b_mark)
  local a = assert(src:find(a_mark, 1, true), "repere absent : " .. a_mark)
  local b = assert(src:find(b_mark, a + #a_mark, true), "repere absent : " .. b_mark)
  return src:sub(a, b - 1)
end
local KEYS = between("local function sorted_keys(t)", "local function bump(")
local OUT = between("local function out_wanted(f, p, chest)", "local function quai_tasks(")
local WORK = between("function Build.work(agent, f, tick)", "\n---------------------------------------------------------------")

-- Le nom du coffre des quais est LU dans build.lua (96c6adf0 : Build.QUAI_CHEST remplace "iron-chest" en dur ; la doublure l'ignorait,
-- find_entity(nil, ...) ne rendait plus rien et le test voyait 0 tache).
local QUAI_CHEST = assert(src:match('\nBuild%.QUAI_CHEST = "([^"]+)"'), "repere absent : Build.QUAI_CHEST")

local function count(s, pat) local _, n = s:gsub(pat, "") return n end
section("0. Reperes")
check(count(OUT, "Build%.Colr%.take_list") == 1, "out_wanted extrait : un appel a Build.Colr.take_list (repere toujours sur la ligne corrigee)")
check(count(WORK, "Build%.Colr%.take_list") == 2, "Build.work extrait : deux appels a Build.Colr.take_list (branche collect)")
check(count(WORK, 'job%.mode == "collect"') == 1, "Build.work extrait : la branche collect")
check(Colr.VITAL["iron-plate"] == true and not Colr.VITAL["stone"], "donnees : la plaque de fer est vitale, la pierre non")

---------------------------------------------------------------------------------------------------
-- Moteur de bouchons
---------------------------------------------------------------------------------------------------
local W -- monde du cas en cours

local function total(items, name)
  if name then return items[name] or 0 end
  local n = 0
  for _, v in pairs(items) do n = n + v end
  return n
end

local function new_bag(cap)
  local bag = { items = {}, cap = cap }
  function bag.get_item_count(name) return total(bag.items, name) end
  function bag.insert(st)
    local k = math.max(0, math.min(st.count, bag.cap - total(bag.items)))
    if k > 0 then bag.items[st.name] = (bag.items[st.name] or 0) + k end
    return k
  end
  function bag.remove(st)
    local k = math.min(st.count, bag.items[st.name] or 0)
    bag.items[st.name] = (bag.items[st.name] or 0) - k
    return k
  end
  return bag
end

local function new_chest(contents)
  local c = { force = { name = "f1" }, valid = true, items = contents }
  local inv = setmetatable({}, { __len = function() return 32 end })
  function inv.get_contents()
    local t = {}
    for k, v in pairs(c.items) do if v > 0 then t[k] = v end end
    return t
  end
  function inv.get_item_count(name) return total(c.items, name) end
  function inv.get_bar() return 33 end -- F95 : sans barre, get_bar() = cases + 1
  function c.get_inventory(i) assert(i == 1, "inventaire du coffre attendu") return inv end
  function c.get_item_count(name) return total(c.items, name) end
  function c.remove_item(st)
    local k = math.min(st.count, c.items[st.name] or 0)
    c.items[st.name] = (c.items[st.name] or 0) - k
    return k
  end
  return c
end

local surface = {
  find_entity = function(name, pos)
    if name ~= QUAI_CHEST then return nil end
    return W.chests[pos[1] .. "," .. pos[2]]
  end,
}

local Stock = { count = function() return 0 end }
local STONE_SKIP = function() return function(it) return it == "stone" end end

local function load_code(out_src, work_src)
  local Build = { COLLECT_AT = 200, Quotas = require("script.team.quotas_glue"), Colr = Colr, QUAI_CHEST = QUAI_CHEST }
  local env = setmetatable({
    Build = Build, Stock = Stock, REACH = 16,
    -- lot LOGISTIQUE : rue (W.street) et tuile libre (W.spot) reglables par monde ; par defaut le point tel quel
    P = { anchor_for = function(_, x, y) if W.street then return W.street(x, y) end return { x = x, y = y } end },
    seg_passable = function() return function() return true end end,
    free_spot = function(_, _, x, y) if W.spot then return W.spot(x, y) end return x, y end,
    defines = { inventory = { chest = 1 } },
    log = function(s) W.logs[#W.logs + 1] = s end,
  }, { __index = _G })
  local X = assert(load(KEYS .. out_src .. "\nreturn { out_tasks = out_tasks }", "stockage_collecte_out", "t", env))()
  assert(load(KEYS .. work_src, "stockage_collecte_work", "t", env))()
  return X, Build
end

--- Équipe d'un projet (id 7) à deux coffres de sortie : (1.5, 1.5) ne tient que de la pierre, (4.5, 1.5) de la pierre et du fer.
local function world(c1, c2)
  W = { logs = {}, chests = { ["1.5,1.5"] = new_chest(c1), ["4.5,1.5"] = new_chest(c2) } }
  local p = { id = 7, prio = 50, outs = { { x = 1.5, y = 1.5 }, { x = 4.5, y = 1.5 } }, quais = {} }
  local f = { key = "f1", force = "f1", stats = {}, build = { lat = {}, projects = { [7] = p }, stats = { collected = 0 } } }
  return f, p
end

local function agent_for(idx, bag)
  local o = idx == 1 and { x = 1.5, y = 1.5 } or { x = 4.5, y = 1.5 }
  return { ia1d = { pid = 7, mode = "collect", idx = idx }, entity = { surface = surface, position = o, get_main_inventory = function() return bag end } }
end

local function battery(out_src, work_src)
  local X, Build = load_code(out_src, work_src)

  section("1. out_tasks : Stock.skip_fn rend une fonction (stock plein, pierre ecartee)")
  local f, p = world({ stone = 300 }, { stone = 150, ["iron-plate"] = 100 })
  Stock.skip_fn = STONE_SKIP
  local out = {}
  X.out_tasks(f, p, surface, out)
  check(#out == 1 and out[1].key == "ia1d:7:o:2" and out[1].ia1d.mode == "collect" and out[1].ia1d.idx == 2,
    "C2 : coffre de pierre seule, aucune tache ; coffre avec du fer, une tache (" .. #out .. " tache(s))")

  section("2. out_tasks : regle d'avant sans ecart")
  Stock.skip_fn = nil
  out = {}
  X.out_tasks(f, p, surface, out)
  check(#out == 2, "C3 : Stock.skip_fn absent, les deux coffres collectes (" .. #out .. ")")
  Stock.skip_fn = function() return nil end
  out = {}
  X.out_tasks(f, p, surface, out)
  check(#out == 2, "C3 : Stock.skip_fn rend nil, les deux coffres collectes (" .. #out .. ")")

  section("3. Build.work, collecte avec ecart")
  Stock.skip_fn = STONE_SKIP
  f = world({ stone = 300 }, { stone = 150, ["iron-plate"] = 100 })
  local bag = new_bag(1000)
  local r = Build.work(agent_for(2, bag), f, 3600)
  local c2 = W.chests["4.5,1.5"]
  check(r == "done" and bag.items["iron-plate"] == 100 and (bag.items.stone or 0) == 0, "C4 : le fer au sac, pas la pierre, done (" .. tostring(r) .. ")")
  check(c2.items.stone == 150 and c2.items["iron-plate"] == 0, "C4 : la pierre ecartee reste au coffre")
  check(f.build.stats.collected == 100, "C4 : compteur collected = 100 (" .. tostring(f.build.stats.collected) .. ")")
  bag = new_bag(1000)
  r = Build.work(agent_for(1, bag), f, 3600)
  check(r == "done" and total(bag.items) == 0 and W.chests["1.5,1.5"].items.stone == 300 and f.stats.collecte_vide == nil,
    "C5 : coffre de pierre seule, rien pris, done, pas un voyage a vide (" .. tostring(r) .. ")")

  section("4. Build.work, sac plein")
  f = world({ stone = 300 }, { stone = 150, ["iron-plate"] = 100 })
  bag = new_bag(0)
  r = Build.work(agent_for(2, bag), f, 7200)
  check(r == "fail" and f.stats.collecte_vide == 1, "C6 : sac plein devant du fer, fail, collecte_vide = 1 (" .. tostring(r) .. ")")
  check(#W.logs == 1 and W.logs[1]:find("[FO-COLLECTE]", 1, true) ~= nil, "C6 : une ligne [FO-COLLECTE]")

  section("5. Build.work, sans ecart : le fer d'abord")
  Stock.skip_fn = nil
  f = world({ stone = 300 }, { stone = 200, ["iron-plate"] = 50 })
  bag = new_bag(60)
  r = Build.work(agent_for(2, bag), f, 3600)
  check(r == "done" and bag.items["iron-plate"] == 50 and bag.items.stone == 10, "C7 : 50 fer puis 10 pierres dans un sac de 60")
  Stock.skip_fn = nil

  -- Lot LOGISTIQUE (B2, banc partie-reelle-120 graine 123456789, emerald projet 4 : le point de la rue tombait entre deux bras du quai,
  -- 110 « no_path ») : le point d'appui de la collecte passe par free_spot, autour du point de la rue, ou autour du coffre sans rue.
  section("6. out_tasks : point d'appui de la collecte sur une tuile libre")
  f, p = world({ ["iron-plate"] = 300 }, { ["iron-plate"] = 300 })
  local asked = {}
  W.street = function() return { x = 10, y = 20 } end
  W.spot = function(x, y) asked[#asked + 1] = x .. "," .. y; return x + 0.5, y + 3.5 end
  out = {}
  X.out_tasks(f, p, surface, out)
  check(#out == 2 and out[1].ia1d.ax == 10.5 and out[1].ia1d.ay == 23.5,
    "C8 : rue sous le quai, l'appui est la tuile libre autour du point de la rue (" .. tostring(out[1] and out[1].ia1d.ax) .. ", " .. tostring(out[1] and out[1].ia1d.ay) .. ")")
  check(asked[1] == "10,20", "C8 : free_spot interroge autour du point de la rue (" .. tostring(asked[1]) .. ")")
  W.street = function() return nil end
  out = {}
  X.out_tasks(f, p, surface, out)
  check(#out == 2 and out[2].ia1d.ax == 5 and out[2].ia1d.ay == 5, "C9 : sans rue, l'appui est la tuile libre autour du coffre (" .. tostring(out[2] and out[2].ia1d.ax) .. ")")
end

local ok, err = pcall(battery, OUT, WORK)
check(ok, "C1 : aucune erreur quand Stock.skip_fn rend une fonction (" .. tostring(err) .. ")")

---------------------------------------------------------------------------------------------------
-- Mutants
---------------------------------------------------------------------------------------------------
section("6. Mutants")
local function mutate(s, pat, rep)
  local m, n = s:gsub(pat, rep)
  return m, n
end
local mut_report = {}
do -- « Colr nu » : le défaut d'avant 259aca16 doit planter
  local mo, n1 = mutate(OUT, "Build%.Colr%.take_list", "Colr.take_list")
  local mw, n2 = mutate(WORK, "Build%.Colr%.take_list", "Colr.take_list")
  local p0, f0 = passes, failures
  quiet = true
  local mok, merr = pcall(battery, mo, mw)
  quiet = false
  passes, failures = p0, f0
  local killed = n1 == 1 and n2 == 2 and not mok and tostring(merr):find("Colr", 1, true) ~= nil
  check(killed, "mutant Colr nu : doit planter en nommant Colr (" .. tostring(merr) .. ")")
  mut_report[#mut_report + 1] = "Colr nu : " .. (killed and "plante (" .. tostring(merr) .. ")" or "SURVIT")
end
local function must_fail(name, o, w)
  local p0, f0 = passes, failures
  quiet = true
  local mok = pcall(battery, o, w)
  local bad = failures - f0
  quiet = false
  passes, failures = p0, f0
  local killed = (not mok) or bad > 0
  check(killed, "mutant " .. name .. " : au moins un controle doit echouer")
  mut_report[#mut_report + 1] = name .. " : " .. (not mok and "plante" or killed and (bad .. " controle(s) en echec") or "SURVIT")
end
do
  local mo, n = mutate(OUT, "if skip and #Build%.Colr%.take_list", "if false and #Build.Colr.take_list")
  check(n == 1, "mutant ecart ignore a la sortie : applique")
  must_fail("ecart ignore a la sortie", mo, WORK)
  local mw, n2 = mutate(WORK, "local skip = Stock%.skip_fn and Stock%.skip_fn%(f%) or nil", "local skip = nil")
  check(n2 == 1, "mutant ecart ignore a la collecte : applique")
  must_fail("ecart ignore a la collecte", OUT, mw)
  -- lot LOGISTIQUE : le point de la rue pris tel quel (l'etat d'avant le lot)
  local ma, n3 = mutate(OUT, "if a then fx, fy = free_spot%(b, nil, a%.x, a%.y%) else", "if a then fx, fy = a.x, a.y else")
  check(n3 == 1, "mutant point de la rue tel quel : applique")
  must_fail("point de la rue tel quel", ma, WORK)
end
for _, line in ipairs(mut_report) do print("  " .. line) end

print(string.format("[STOCKAGE-COLLECTE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
