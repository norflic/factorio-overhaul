--[[
  Lot IA3-k : banc HORS JEU des rôles des soldats (shared/ai3/soldats.lua ; B5, C4, C7) : défense du QG, escortes,
  repos, nettoyage d'un nid selon le caractère et la force, patrouille dosée par l'agressivité et qui tourne, gardes,
  personne « sans ordre » ; mutants qui doivent échouer.
  Lancement : lua5.2 tests/ia3k_soldats_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Sd = require("shared.ai3.soldats")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

local HQ = { x = 0, y = 0 }
local function soldiers(n, over)
  local out = {}
  for i = 1, n do
    out[i] = { id = i, x = (i % 5) * 3, y = 14 + math.floor(i / 5) * 2 }
    for k, v in pairs((over and over[i]) or {}) do out[i][k] = v end
  end
  return out
end
local function count(orders, role)
  local n = 0
  for _, o in pairs(orders) do if o.role == role then n = n + 1 end end
  return n
end

local function suite()
  section("défense du QG (C7)")
  local o, sm = Sd.assign({ tick = 100, hq = HQ, agr = 1000, soldiers = soldiers(10, { [3] = { rest_until = 5000 } }),
    defend = { { key = "hq", x = 30, y = 0 } } })
  check(count(o, "defense") == 10, "QG menacé : les 10 soldats défendent, repos compris (" .. count(o, "defense") .. ")")
  local o2 = Sd.assign({ tick = 100, hq = HQ, agr = 1000, soldiers = soldiers(10), defend = { { key = "alerte", x = 40, y = 40, n = 4 } } })
  check(count(o2, "defense") == 4, "alerte d'un PNJ : les 4 plus proches y vont")

  section("escortes (C5, C6)")
  local o3 = Sd.assign({ tick = 100, hq = HQ, agr = 1000, soldiers = soldiers(10, { [1] = { rest_until = 5000 } }),
    escorts = { { aid = 7, x = 0, y = 10, n = 3 } } })
  check(count(o3, "escort") == 3, "demande de 3 escorteurs servie")
  check(not (o3[1] and o3[1].role == "escort"), "un soldat au repos n'escorte pas")
  local keep = soldiers(10, { [9] = { escort = 7 }, [10] = { escort = 7 } })
  local o4 = Sd.assign({ tick = 100, hq = HQ, agr = 1000, soldiers = keep, escorts = { { aid = 7, x = 0, y = 10, n = 3 } } })
  check(o4[9].role == "escort" and o4[10].role == "escort" and count(o4, "escort") == 3, "les escorteurs déjà attribués restent")
  local farsold = { { id = 1, x = 500, y = 0 } }
  local o5 = Sd.assign({ tick = 100, hq = HQ, agr = 1000, soldiers = farsold, escorts = { { aid = 2, x = 0, y = 0, n = 2 } } })
  check(count(o5, "escort") == 0, "un soldat à 500 tuiles du QG n'est pas pris pour une escorte")

  section("repos (B5 : hors du temps compté)")
  local o6, sm6 = Sd.assign({ tick = 100, hq = HQ, agr = 1000, soldiers = soldiers(6, { [2] = { rest_until = 3000 }, [4] = { rest_until = 3000 } }) })
  check(sm6.rest == 2 and o6[2] == nil and o6[4] == nil, "2 soldats au repos, sans ordre")
  check(sm6.idle == 0, "aucun soldat libre sans ordre (patrouille ou garde)")

  section("nettoyage (C4)")
  local th = { { x = 120, y = 0, k = 2 } }
  local o7 = Sd.assign({ tick = 100, hq = HQ, agr = 1000, soldiers = soldiers(10), threats = th })
  check(count(o7, "clear") == 7, "faction agressive, garnison suffisante : 7 soldats nettoient (2 par menace + 3)")
  local o8 = Sd.assign({ tick = 100, hq = HQ, agr = 800, soldiers = soldiers(10), threats = th })
  check(count(o8, "clear") == 0, "faction pacifique : pas de nettoyage d'un nid qui n'a tué personne")
  local o9 = Sd.assign({ tick = 100, hq = HQ, agr = 800, soldiers = soldiers(10), threats = { { x = 120, y = 0, k = 2, killed = true } } })
  check(count(o9, "clear") == 7, "faction pacifique : nettoyage d'un nid qui a TUÉ")
  local o10 = Sd.assign({ tick = 100, hq = HQ, agr = 1500, soldiers = soldiers(5), threats = th })
  check(count(o10, "clear") == 0, "garnison trop petite (5 < 7) : pas de nettoyage")
  local o11 = Sd.assign({ tick = 100, hq = HQ, agr = 800, soldiers = soldiers(10), clearing = { x = 120, y = 0, k = 2 } })
  check(count(o11, "clear") == 7, "opération en cours : poursuivie")

  section("patrouille et garde (B5, C4)")
  local oa = Sd.assign({ tick = 0, hq = HQ, agr = 1500, soldiers = soldiers(20) })
  local ob = Sd.assign({ tick = 0, hq = HQ, agr = 600, soldiers = soldiers(20) })
  check(count(oa, "patrol") == 15 and count(oa, "guard") == 5, "agressif : 75 % en patrouille (" .. count(oa, "patrol") .. ")")
  check(count(ob, "patrol") == 6 and count(ob, "guard") == 14, "pacifique : 30 % en patrouille (" .. count(ob, "patrol") .. ")")
  check(count(oa, "patrol") > count(ob, "patrol"), "un agressif patrouille plus qu'un pacifique")
  local far_ok = true
  for _, x in pairs(oa) do
    if x.role == "patrol" then
      local d = math.sqrt(x.x * x.x + x.y * x.y)
      if d < 70 or d > 90 then far_ok = false end
    end
  end
  check(far_ok, "patrouilles sur l'anneau de la frontière (80 tuiles)")
  local oc = Sd.assign({ tick = 2400, hq = HQ, agr = 1500, soldiers = soldiers(20) })
  check(oc[1].key ~= oa[1].key, "la patrouille change de point toutes les 2 400 ticks")
  check(oa[1].x == oa[2].x and oa[1].y == oa[2].y, "patrouille par paires")
  local od = Sd.assign({ tick = 0, hq = HQ, agr = 1000, soldiers = soldiers(4), marked_outposts = { { x = 200, y = 0 } } })
  local at_out = 0
  for _, x in pairs(od) do if x.role == "guard" and x.x == 200 then at_out = at_out + 1 end end
  check(at_out == 2, "avant-poste marqué : 2 gardes (" .. at_out .. ")")
  local oe1 = Sd.assign({ tick = 50, hq = HQ, agr = 1100, soldiers = soldiers(12), threats = th })
  local oe2 = Sd.assign({ tick = 50, hq = HQ, agr = 1100, soldiers = soldiers(12), threats = th })
  local same = true
  for id, x in pairs(oe1) do if not oe2[id] or oe2[id].key ~= x.key then same = false end end
  check(same, "déterministe : mêmes entrées, mêmes ordres")

  section("soldats égarés loin du QG")
  local og, sg = Sd.assign({ tick = 100, hq = HQ, agr = 1500, soldiers = { { id = 1, x = 600, y = 0 }, { id = 2, x = 610, y = 0, role = "clear" } },
    clearing = { x = 620, y = 0, k = 1 } })
  check(og[1] == nil and sg.far == 1, "égaré sans rôle : aucun ordre (le rappel du chef s'en charge)")
  check(og[2] and og[2].role == "clear", "loin du QG en plein nettoyage : il continue")
  section("groupes de menaces")
  local cl = Sd.clusters({ { x = 0, y = 0 }, { x = 10, y = 5 }, { x = 100, y = 0, killed = true }, { x = 112, y = 0 } })
  check(#cl == 2 and cl[1].k == 2 and cl[2].k == 2 and cl[2].killed, "deux groupes de 2 menaces, le second a tué")
end

local function run_quiet()
  quiet = true
  local f0 = failures
  local ok = pcall(suite)
  local n = failures - f0
  failures = f0
  quiet = false
  return n + (ok and 0 or 1)
end

suite()
local p0 = passes
print("== mutants")
local keep = {}
local function patch(t, k, v) keep[#keep + 1] = { t, k, t[k] }; t[k] = v end
local function unpatch() for i = #keep, 1, -1 do local e = keep[i]; e[1][e[2]] = e[3] end keep = {} end
local function mutant(name, apply)
  local pp = passes
  apply()
  local n = run_quiet()
  unpatch()
  passes = pp
  check(n > 0, "mutant « " .. name .. " » détecté (" .. n .. ")")
end
mutant("patrouille égale pour tous", function() patch(Sd, "patrol_share", function() return 500 end) end)
mutant("nettoyage sans garde-fou de force", function() patch(Sd, "clear_need", function() return 0 end) end)
mutant("pas de rotation des patrouilles", function() patch(Sd, "PATROL_TICKS", 1e12) end)
mutant("défense ignorée", function()
  local a = Sd.assign
  patch(Sd, "assign", function(i) local j = {} for k, v in pairs(i) do j[k] = v end j.defend = nil return a(j) end)
end)
mutant("escortes ignorées", function()
  local a = Sd.assign
  patch(Sd, "assign", function(i) local j = {} for k, v in pairs(i) do j[k] = v end j.escorts = nil return a(j) end)
end)
mutant("repos ignoré", function() patch(Sd, "REST", 0)
  local a = Sd.assign
  patch(Sd, "assign", function(i)
    local j = {} for k, v in pairs(i) do j[k] = v end
    local s2 = {} for n, s in ipairs(i.soldiers) do local c = {} for k, v in pairs(s) do c[k] = v end c.rest_until = nil s2[n] = c end
    j.soldiers = s2 return a(j) end)
end)
print(string.format("[IA3K-SOLDATS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
