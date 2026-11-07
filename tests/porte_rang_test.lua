--[[
  Lot L2 « la porte de rang ciblée » : test hors jeu de la règle PURE shared/ai3/porte_rang.lua. Rien n'est branché en jeu.
    §1 cas central : l'interblocage du fer (EFFONDREMENT) : deux modules qui attendent du fer et la foreuse de fer, deux
       emplacements ; sans la porte, la foreuse n'a pas de place ; avec, elle l'a ;
    §2 porte CIBLÉE : chaîne indépendante permise, dépendance indirecte retenue, manque sans issue, pile R0/R1, même rang,
       manque d'un rang plus haut, cause départagée par (rang, nom) quel que soit l'ordre d'entrée ;
    §3 anti-répétition (gist de l'auteur l.181-204) ;
    §4 coût en instructions (debug.sethook) ; §5 mutants appliqués au SOURCE de la règle.
  Usage : lua5.2 tests/porte_rang_test.lua   (depuis la racine du mod). Fichier de TEST : il nomme des objets vanilla.
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")
local Rg = require("shared.ai3.rang")
local Pr0 = require("shared.ai3.porte_rang")

local pass, fail, quiet = 0, 0, false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[PORTE-RANG] ECHEC : " .. msg) end
  end
end

-- Livre réel (fixture des tests), recette choisie = la recette du même nom (assez pour la fermeture des dépendances).
local D = Ca.data(F.dump(), {})
local function pick(i) return D.recipes[i], D.recipes[i] and nil or "aucune recette" end
local RC = Rg.chain(D, pick, { "iron-gear-wheel", "electronic-circuit", "copper-cable", "stone-brick", "electric-mining-drill" })
local function keys(l)
  local t = {}
  for _, o in ipairs(l) do t[#t + 1] = (o.order or o).key end
  return table.concat(t, ",")
end
local function order(item, extra)
  local o = { key = "o:" .. item, item = item, rank = RC.rank[item] }
  for k, v in pairs(extra or {}) do o[k] = v end
  return o
end
local function seats(list, n)
  local out = {}
  for j = 1, math.min(n, #list) do out[#out + 1] = list[j].key end
  return table.concat(out, ",")
end

local function battery(Pr)
  local p0, f0 = pass, fail
  local deps = Pr.deps(RC)
  local ore = { item = "iron-ore", rank = 0, option = true }

  -- §1 Interblocage du fer : les modules (rangs 2 et 3) passent devant la foreuse au tri ; deux emplacements.
  local orders = { order("iron-gear-wheel"), order("electronic-circuit"), { key = "o:foreuse", item = "iron-ore", rank = 0 } }
  check(seats(orders, 2) == "o:iron-gear-wheel,o:electronic-circuit", "§1 sans la porte, les modules tiennent les 2 emplacements")
  local r1 = Pr.decide({ orders = orders, short = { ore }, deps = deps })
  check(seats(r1.allowed, 2) == "o:foreuse", "§1 avec la porte, la foreuse prend un emplacement (" .. seats(r1.allowed, 2) .. ")")
  check(#r1.held == 2 and r1.held[1].cause == "rang : iron-ore (rang 0) d'abord", "§1 les deux modules retenus, cause écrite ("
    .. tostring(r1.held[1] and r1.held[1].cause) .. ")")
  check(r1.rstar == 0, "§1 rang du manque le plus bas : 0")

  -- §2 Porte ciblée.
  local r2 = Pr.decide({ orders = { order("electronic-circuit"), order("stone-brick"), order("copper-cable") }, short = { ore }, deps = deps })
  check(keys(r2.allowed) == "o:stone-brick,o:copper-cable", "§2 chaînes sans fer permises, le circuit retenu (" .. keys(r2.allowed) .. ")")
  check(deps["electronic-circuit"]["iron-ore"] and not RC.rec["electronic-circuit"].ingredients[1].name:find("ore"),
    "§2 dépendance INDIRECTE (le circuit dépend du minerai par la plaque)")
  local r3 = Pr.decide({ orders = { order("iron-gear-wheel") }, short = { { item = "iron-ore", rank = 0, option = false } }, deps = deps })
  check(#r3.allowed == 1 and r3.rstar == nil, "§2 manque sans issue : rien n'est retenu")
  local r4 = Pr.decide({ orders = { order("iron-gear-wheel", { pile = 0 }), order("electronic-circuit", { pile = 1 }),
    order("iron-gear-wheel", { pile = 2, key = "o:r2" }) }, short = { ore }, deps = deps })
  check(keys(r4.allowed) == "o:iron-gear-wheel,o:electronic-circuit" and #r4.held == 1, "§2 R0 et R1 jamais retenus, R2 retenu")
  local cyc = { list = { "a", "b" }, rec = { a = { ingredients = { { name = "b" } } }, b = { ingredients = { { name = "a" } } } } }
  local r5 = Pr.decide({ orders = { { key = "o:b", item = "b", rank = 1 } }, short = { { item = "a", rank = 1, option = true } },
    deps = Pr.deps(cyc) })
  check(#r5.allowed == 1, "§2 même rang (cycle contracté) : pas de blocage")
  local r6 = Pr.decide({ orders = { order("iron-gear-wheel") }, short = { { item = "electronic-circuit", rank = RC.rank["electronic-circuit"], option = true } }, deps = deps })
  check(#r6.allowed == 1, "§2 un manque d'un rang plus HAUT ne retient pas l'amont")
  local plate = { item = "iron-plate", rank = 1, option = true }
  local ra = Pr.decide({ orders = { order("electronic-circuit") }, short = { plate, ore }, deps = deps })
  local rb = Pr.decide({ orders = { order("electronic-circuit") }, short = { ore, plate }, deps = deps })
  check(ra.held[1] and rb.held[1] and ra.held[1].cause == rb.held[1].cause and ra.held[1].cause:find("iron%-ore") and ra.rstar == 0 and rb.rstar == 0,
    "§2 cause départagée par (rang, nom) quel que soit l'ordre des manques : le minerai d'abord")

  -- §3 Anti-répétition.
  local r7 = Pr.decide({ orders = { order("iron-gear-wheel"), order("copper-cable") }, short = {}, deps = deps, last = "iron-gear-wheel" })
  check(keys(r7.allowed) == "o:copper-cable" and r7.held[1] and r7.held[1].cause:find("^anti%-repetition"),
    "§3 l'objet du tour précédent cède sa place à un autre objet du même rang (" .. keys(r7.allowed) .. ")")
  local r8 = Pr.decide({ orders = { order("iron-gear-wheel"), order("electronic-circuit") }, short = {}, deps = deps, last = "iron-gear-wheel" })
  check(#r8.allowed == 2, "§3 seul de son rang, l'objet du tour précédent passe quand même")
  local r9 = Pr.decide({ orders = { order("iron-gear-wheel", { pile = 1 }), order("copper-cable") }, short = {}, deps = deps, last = "iron-gear-wheel" })
  check(#r9.allowed == 2, "§3 un ordre de R0 ou R1 n'est pas retenu par l'anti-répétition")
  return pass - p0, fail - f0
end

local _, BASE = battery(Pr0)

-- §4 Coût : fermeture des dépendances de TOUT le livre ouvert, puis une décision de 24 ordres et 10 manques.
do
  local all = {}
  for _, rn in ipairs(D.recipe_list) do
    for _, p in ipairs(D.recipes[rn].products) do if not D.res[p.name] then all[#all + 1] = p.name end end
  end
  local RA = Rg.chain(D, pick, all)
  local c1, c2, deps = 0, 0, nil
  debug.sethook(function() c1 = c1 + 1 end, "", 1)
  deps = Pr0.deps(RA)
  debug.sethook()
  local orders, short = {}, {}
  for j, i in ipairs(RA.order) do
    if #orders < 24 and RA.rank[i] >= 2 then orders[#orders + 1] = { key = "o:" .. i, item = i, rank = RA.rank[i] } end
    if #short < 10 and RA.rank[i] <= 2 and RA.rank[i] >= 1 and j % 3 == 0 then short[#short + 1] = { item = i, rank = RA.rank[i], option = true } end
  end
  debug.sethook(function() c2 = c2 + 1 end, "", 1)
  local res = Pr0.decide({ orders = orders, short = short, deps = deps, last = orders[1].item })
  debug.sethook()
  print(string.format("[PORTE-RANG] §4 instructions : fermeture des dépendances de %d objets %d ; décision (%d ordres, %d manques) %d : %d permis, %d retenus",
    RA.n_items, c1, #orders, #short, c2, #res.allowed, #res.held))
  -- Gardes : le double du mesuré le 7/11 (15 857 et 1 767).
  check(c1 <= 32000 and c2 <= 3600, string.format("§4 coût borné (fermeture %d, sous 32 000 ; décision %d, sous 3 600)", c1, c2))
end

-- §5 Mutants.
do
  local f = assert(io.open("shared/ai3/porte_rang.lua", "rb"))
  local SRC = f:read("*a")
  f:close()
  local MUT = {
    { "porte globale (tout rang supérieur retenu)", "if cause == nil and s.rank < o.rank and up[s.item] then", "if cause == nil and s.rank < o.rank then" },
    { "porte supprimée", "if cause then held", "if false then held" },
    { "manque sans issue qui bloque", "if s.option and s.item ~= nil", "if s.item ~= nil" },
    { "R0 et R1 retenus", "if (o.pile or 2) > Pr.KEEP_PILE and o.rank ~= nil then", "if o.rank ~= nil then" },
    { "dépendances directes seulement", "for k in pairs(deps[j] or {}) do if k ~= i then d[k] = true end end", "" },
    { "rang égal qui bloque", "s.rank < o.rank and up[s.item]", "s.rank <= o.rank and up[s.item]" },
    { "anti-répétition absente", "if last ~= nil then", "if false then" },
    { "anti-répétition qui retient le seul de son rang", "and others[o.rank] and", "and true and" },
    { "manques non triés (cause dans l'ordre d'entrée)", "  table.sort(def, function(a, b)\n    if a.rank ~= b.rank then return a.rank < b.rank end\n    return a.item < b.item\n  end)\n", "" },
  }
  local caught = 0
  check(BASE == 0, "§5 mutants jugés sur une batterie de base verte (" .. BASE .. " échec(s))")
  for _, mu in ipairs(BASE == 0 and MUT or {}) do
    local s, e = SRC:find(mu[2], 1, true)
    if not s or SRC:find(mu[2], e + 1, true) then
      check(false, "§5 mutant mal formé : " .. mu[1])
    else
      local Pm = assert(load(SRC:sub(1, s - 1) .. mu[3] .. SRC:sub(e + 1), "=porte-mutant"))()
      local p0, f0 = pass, fail
      quiet = true
      local ok, err = pcall(battery, Pm)
      debug.sethook()
      quiet = false
      local fails = fail - f0
      pass, fail = p0, f0
      local hit = (not ok) or fails > 0
      if hit then caught = caught + 1 end
      check(hit, "§5 mutant NON refusé : " .. mu[1])
      print(string.format("[PORTE-RANG] §5 mutant « %s » : %s", mu[1], ok and (fails .. " contrôle(s) en échec") or ("plantage " .. tostring(err))))
    end
  end
  check(caught == #MUT, string.format("§5 mutants : %d refusés sur %d", caught, #MUT))
end

print(string.format("[PORTE-RANG] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
