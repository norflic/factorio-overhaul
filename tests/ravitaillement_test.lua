--[[
  Lot MALL « ravitaillement » : test hors jeu de la règle pure shared/team/ravitaillement.lua et de sa lecture par shared/team/liaison.lua
  (appariement, tracé, prix) et par le script (script/team/liaison.lua, script/team/build.lua, lus comme texte).
    §1 constantes et aides ; §2 appariement des quais de mall (portée, partage d'une sortie) ; §3 tracé et prix ; §4 portage de secours ;
    §5 déterminisme ; §6 la règle ne nomme aucun objet ; §7 branchement ; §8 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/ravitaillement_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local Rv = require("shared.team.ravitaillement")
local Li = require("shared.team.liaison")
local RSRC, LSRC = read("shared/team/ravitaillement.lua"), read("shared/team/liaison.lua")

local function dock(key, pid, x, y, item, flow, mall, linked)
  return { key = key, pid = pid, x = x, y = y, item = item, flow = flow, mall = mall, linked = linked }
end
local function src(key, pid, x, y, item, taken) return { key = key, pid = pid, x = x, y = y, item = item, taken = taken } end

-- §1 constantes et aides
check(Rv.SPAN > Li.MAX_SPAN and Rv.LEN > Li.MAX_LEN and Rv.TMAX > Li.TMAX, "1.1 un mall a plus de portée, de tapis et de temps qu'un autre module")
check(Rv.FAN == 2, "1.2 une sortie sert deux quais de mall")
check(Rv.is_mall({ mall = true }) and not Rv.is_mall({ mall = false }) and not Rv.is_mall({}) and not Rv.is_mall(nil), "1.3 is_mall")
check(Rv.span_max({ mall = true }, Li.MAX_SPAN) == Rv.SPAN and Rv.span_max({}, Li.MAX_SPAN) == Li.MAX_SPAN, "1.4 portée")
check(Rv.span_max({ mall = true }, 500) == 500, "1.5 la portée d'un mall n'est jamais réduite")
check(Rv.len_max({ mall = true }, Li.MAX_LEN) == Rv.LEN and Rv.len_max({}, Li.MAX_LEN) == Li.MAX_LEN, "1.6 longueur de tapis")
check(Rv.tmax({ mall = true }, Li.TMAX) == Rv.TMAX and Rv.tmax({}, Li.TMAX) == Li.TMAX, "1.7 retour accepté")
check(Rv.fan({ mall = true }) == Rv.FAN and Rv.fan({}) == 1, "1.8 partage")
check(Rv.taken({ taken = 2 }) == 2 and Rv.taken({ linked = true }) == 1 and Rv.taken({}) == 0 and Rv.taken({ taken = 0, linked = true }) == 0,
  "1.9 liaisons déjà tirées d'une sortie (forme ancienne comprise)")

-- §2 appariement
local far = Li.MAX_SPAN + 20
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1, true) }, { src("s", 2, far, 0, "X") }) == 1, "2.1 un quai de mall se relie au-delà de Li.MAX_SPAN")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1, false) }, { src("s", 2, far, 0, "X") }) == 0, "2.2 un autre quai non (comme avant)")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1, true) }, { src("s", 2, Rv.SPAN + 1, 0, "X") }) == 0, "2.3 au-delà de Rv.SPAN, rien")
check(#Li.pairs({ dock("d", 1, 0, 0, "X", 1, true) }, { src("s", 2, Rv.SPAN, 0, "X") }) == 1, "2.4 à Rv.SPAN, une paire")
local two = Li.pairs({ dock("a", 1, 0, 0, "X", 2, true), dock("b", 2, 0, 10, "X", 1, true), dock("c", 3, 0, 20, "X", 0.5, true) }, { src("s", 9, 5, 5, "X") })
check(#two == 2 and two[1].dock.key == "a" and two[2].dock.key == "b", "2.5 une sortie sert deux quais de mall, les plus gros débits d'abord, pas trois")
check(#Li.pairs({ dock("a", 1, 0, 0, "X", 1, false), dock("b", 2, 0, 10, "X", 1, false) }, { src("s", 9, 5, 5, "X") }) == 1, "2.6 un autre module : une seule liaison par sortie")
check(#Li.pairs({ dock("a", 1, 0, 0, "X", 1, true) }, { src("s", 9, 5, 5, "X", 2) }) == 0, "2.7 une sortie déjà prise par deux liaisons ne sert plus")
check(#Li.pairs({ dock("a", 1, 0, 0, "X", 1, true) }, { src("s", 9, 5, 5, "X", 1) }) == 1, "2.8 une sortie prise une fois sert un second quai de mall")
check(#Li.pairs({ dock("a", 1, 0, 0, "X", 1, false) }, { src("s", 9, 5, 5, "X", 1) }) == 0, "2.9 mais pas un quai d'un autre module")
local m = Li.pairs({ dock("a", 1, 0, 0, "X", 1, true) }, { src("s1", 2, 60, 0, "X"), src("s2", 3, 8, 0, "X") })
check(#m == 1 and m[1].src.key == "s2", "2.10 la sortie la plus proche l'emporte aussi pour un mall")
check(#Li.pairs({ dock("a", 1, 0, 0, "X", 1, true) }, { src("s", 1, 5, 0, "X") }) == 0, "2.11 jamais la sortie de son propre projet")
check(#Li.pairs({ dock("a", 1, 0, 0, "X", 1, false) }, { { key = "s", pid = 2, x = 5, y = 0, item = "X", linked = true } }) == 0, "2.12 ancienne forme (linked) : une liaison, pas deux pour un autre")

-- §3 tracé et prix
check(select(1, Li.route_ok(Li.MAX_LEN + 10, Li.MAX_LEN + 5, Rv.len_max({ mall = true }, Li.MAX_LEN))), "3.1 un tapis de mall plus long que Li.MAX_LEN passe")
check(not select(1, Li.route_ok(Li.MAX_LEN + 10, Li.MAX_LEN + 5)), "3.2 le défaut est inchangé")
check(not select(1, Li.route_ok(Rv.LEN + 1, Rv.LEN, Rv.LEN)), "3.3 au-delà de Rv.LEN, rien")
check(not select(1, Li.route_ok(40, 10, Rv.LEN)), "3.4 le détour reste borné pour un mall")
local win = { flow = 0.4, dist = 60, span = 50, fill = 400, low = 60 }
local ok_def = Li.worth(win)
win.tmax = Rv.tmax({ mall = true }, Li.TMAX)
local ok_mall, _, det = Li.worth(win)
check(not ok_def and ok_mall and det.payback_min > Li.TMAX and det.payback_min <= Rv.TMAX, "3.5 un quai de faible débit ne se paie pas en 90 min, se paie sur la durée du mall ("
  .. string.format("%.0f min", det.payback_min) .. ")")
win.flow = 0.001
check(not Li.worth(win), "3.6 un débit sous Li.MIN_FLOW ne vaut aucune ligne, mall compris")

-- §4 portage de secours
check(Rv.rescue_low(60, false) == 60 and Rv.rescue_low(60, nil) == 60, "4.1 sans ligne finie, le seuil est celui d'avant")
check(Rv.rescue_low(60, true) == 20, "4.2 une ligne finie : le tiers")
check(Rv.rescue_low(2, true) == 1 and Rv.rescue_low(0, true) == 1, "4.3 jamais moins de 1")
check(Rv.hand_due(30, 100, 60, false) and not Rv.hand_due(30, 100, 60, true), "4.4 30 objets : le PNJ porte sans ligne, laisse la ligne finie travailler")
check(Rv.hand_due(10, 100, 60, true), "4.5 secours : 10 objets avec une ligne finie, le PNJ porte")
check(not Rv.hand_due(10, 0, 60, true) and not Rv.hand_due(10, nil, 60, false), "4.6 sans stock au QG, aucune tâche")
check(not Rv.hand_due(60, 100, 60, false) and Rv.hand_due(59, 100, 60, false), "4.7 le seuil sans ligne est exclusif (n < low)")

-- 4 bis. charge minimale d'un voyage vers un quai de mall
check(Rv.batch_min(400) == 100 and Rv.batch_min(10) == 3 and Rv.batch_min(0) == 1 and Rv.batch_min(nil) == 1, "4b.1 le quart de la charge pleine, au moins 1")
check(Rv.batch_ok(false, 50, 1, 400), "4b.2 hors mall : toujours (comportement d'avant)")
check(not Rv.batch_ok(true, 50, 60, 400), "4b.3 mall : 60 objets pour un voyage de 400, le PNJ attend")
check(Rv.batch_ok(true, 50, 100, 400), "4b.4 mall : le quart de la charge, il part")
check(Rv.batch_ok(true, 0, 3, 400), "4b.5 mall, quai à sec : il porte ce qu'il y a")
check(Rv.batch_ok(true, 395, 5, 400), "4b.6 mall : la charge comble le coffre, il part")
check(not Rv.batch_ok(true, 300, 20, 400), "4b.7 mall : 20 objets pour 100 de place libre, le PNJ attend")

-- §5 déterminisme
local function shuffle(t)
  local out, n = {}, #t
  for i = 1, n do out[i] = t[((i * 7) % n) + 1] end
  local seen, res = {}, {}
  for _, v in ipairs(out) do if not seen[v] then seen[v] = true; res[#res + 1] = v end end
  for _, v in ipairs(t) do if not seen[v] then res[#res + 1] = v end end
  return res
end
local bd, bs = {}, {}
for i = 1, 14 do
  bd[#bd + 1] = dock(string.format("d%02d", i), i, (i * 7) % 60, (i * 3) % 40, i % 2 == 0 and "X" or "Y", (i % 4) + 1, i % 3 ~= 0)
  bs[#bs + 1] = src(string.format("s%02d", i), 100 + i, (i * 5) % 60, (i * 11) % 40, i % 2 == 0 and "X" or "Y")
end
local a, b = Li.pairs(bd, bs), Li.pairs(shuffle(bd), shuffle(bs))
local same = #a == #b and #a > 0
for i = 1, math.min(#a, #b) do if a[i].dock.key ~= b[i].dock.key or a[i].src.key ~= b[i].src.key then same = false end end
check(same, "5.1 appariement identique quel que soit l'ordre des listes (" .. #a .. " paires)")

-- §6 aucun nom d'objet, aucun pairs, aucune API du jeu
local code = RSRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find("iron%-") and not code:find("copper%-") and not code:find("transport%-belt") and not code:find("[a-z]%-inserter")
  and not code:find("electric%-pole") and not code:find("assembling") and not code:find("wooden") and not code:find("plate"), "6.1 aucun nom d'objet")
check(not code:find("[^i%.]pairs%(") and not code:find("game%.") and not code:find("global") and not code:find("math%.random") and not code:find("os%."), "6.2 ni pairs, ni API du jeu, ni hasard, ni horloge")

-- §7 branchement (lu comme texte)
local SCRIPT, BUILD = read("script/team/liaison.lua"), read("script/team/build.lua")
check(SCRIPT:find('require%("shared%.team%.ravitaillement"%)') ~= nil and BUILD:find('local Ra = require%("shared%.team%.ravitaillement"%)') ~= nil,
  "7.1 require au chargement (jamais en événement)")
check(SCRIPT:find("tmax = Rv%.tmax%(d, Ln%.TMAX%)") ~= nil, "7.2 le prix d'un quai de mall est jugé sur la durée du mall")
check(SCRIPT:find("Rv%.len_max%(") ~= nil and SCRIPT:find("mall = d%.mall }") ~= nil, "7.3 la longueur du tapis suit le genre du quai (lc.mall au plan)")
check(SCRIPT:find("mark_line%(b, link,") ~= nil and SCRIPT:find("dp%.line_ok%[link%.dock_idx%] = true") ~= nil, "7.4 une ligne finie est notée sur le projet du quai")
check(BUILD:find("Ra%.hand_due%(n, have, Build%.QUAI_LOW, p%.line_ok and p%.line_ok%[i%] and is_mall_project%(p%)%)") ~= nil,
  "7.5 le portage lit la ligne finie du quai, pour un mall seulement (les autres modules gardent le seuil d'avant)")
check(BUILD:find("Ra%.batch_ok%(mall, n, load, Build%.QUAI_FILL%)") ~= nil, "7.5b le voyage vers un mall lit la charge minimale")
check(SCRIPT:find("made_by_neighbour%(f, surface, o%.x, o%.y%)") ~= nil, "7.6 la sortie vide d'un mall prend l'objet de sa machine")
check(SCRIPT:find("s%.taken = taken%[s%.key%] or 0") ~= nil, "7.7 le relevé compte les liaisons tirées de chaque sortie")
check(not SCRIPT:find("function%s*%(%)%s*[^\n]*line_ok"), "7.8 l'état noté sur le projet ne garde aucune fonction")
check(SCRIPT:find("local PRODUCING = { chantier = true, raccordement = true }", 1, true) ~= nil and SCRIPT:find("eligible%(b%.projects%[pid%]%) or eligible_source%(b%.projects%[pid%]%)") ~= nil,
  "7.9 un chantier qui fabrique déjà peut servir de départ")
check(SCRIPT:find("for idx, q in ipairs(fini and p.quais or {}) do", 1, true) ~= nil, "7.10 jamais un quai d'arrivée sur un module non fini")
check(SCRIPT:find("elseif #names == 0 and fini then", 1, true) ~= nil, "7.11 un chantier non fini ne sert que s'il est vu plein d'un seul objet (ni mémoire, ni machine voisine)")

-- §8 mutants
local function load_mod(text, name)
  local fn, err = load(text, "=" .. name, "t")
  assert(fn, err)
  return fn()
end
local function with_rv(rsrc)
  package.loaded["shared.team.ravitaillement"] = load_mod(rsrc, "rv")
  local ok, L = pcall(load_mod, LSRC, "li")
  package.loaded["shared.team.ravitaillement"] = Rv
  return ok and L or nil
end
local function mutant_rv(name, from, to, probe)
  local text, n = RSRC:gsub(from, to, 1)
  if n == 0 then check(false, "mutant " .. name .. " : motif introuvable") return end
  local okl, R2 = pcall(load_mod, text, "rv-mutant")
  if not okl then check(true, "mutant " .. name .. " (ne se charge pas)") return end
  local okp, seen = pcall(probe, R2)
  check(not okp or seen, "mutant " .. name .. " vu")
end
local function mutant_li(name, from, to, probe)
  local text, n = LSRC:gsub(from, to, 1)
  if n == 0 then check(false, "mutant " .. name .. " : motif introuvable") return end
  package.loaded["shared.team.ravitaillement"] = Rv
  local okl, L2 = pcall(load_mod, text, "li-mutant")
  if not okl then check(true, "mutant " .. name .. " (ne se charge pas)") return end
  local okp, seen = pcall(probe, L2)
  check(not okp or seen, "mutant " .. name .. " vu")
end
-- (sonde : rend vrai quand le mutant est VU)
mutant_rv("portee de mall egale a l'autre", "Rv%.SPAN = 72", "Rv.SPAN = 40", function(R) return R.span_max({ mall = true }, 40) ~= 72 end)
mutant_rv("portee reservee aux malls oubliee", "return Rv%.is_mall%(d%) and math%.max%(base, Rv%.SPAN%) or base end", "return math.max(base, Rv.SPAN) end",
  function(R) return R.span_max({}, 40) ~= 40 end)
mutant_rv("portee reduisant l'autre", "math%.max%(base, Rv%.SPAN%)", "Rv.SPAN", function(R) return R.span_max({ mall = true }, 500) ~= 500 end)
mutant_rv("tapis de mall egal a l'autre", "Rv%.LEN = 96", "Rv.LEN = 48", function(R) return R.len_max({ mall = true }, 48) ~= 96 end)
mutant_rv("retour de mall egal a l'autre", "Rv%.TMAX = 360", "Rv.TMAX = 90", function(R) return R.tmax({ mall = true }, 90) ~= 360 end)
mutant_rv("pas de partage", "Rv%.FAN = 2", "Rv.FAN = 1", function(R) return R.fan({ mall = true }) ~= 2 end)
mutant_rv("partage pour tous", "return Rv%.is_mall%(d%) and Rv%.FAN or 1 end", "return Rv.FAN end", function(R) return R.fan({}) ~= 1 end)
mutant_rv("forme ancienne ignoree", "return s%.linked and 1 or 0", "return 0", function(R) return R.taken({ linked = true }) ~= 1 end)
mutant_rv("taken ignore", "if s%.taken ~= nil then return s%.taken end", "", function(R) return R.taken({ taken = 2 }) ~= 2 end)
mutant_rv("secours = seuil ordinaire", "if not line_done then return low end", "do return low end", function(R) return R.rescue_low(60, true) ~= 20 end)
mutant_rv("secours sans plancher", "return math%.max%(1, math%.floor%(low / Rv%.RESCUE_DIV%)%)", "return math.floor(low / Rv.RESCUE_DIV)",
  function(R) return R.rescue_low(2, true) ~= 1 end)
mutant_rv("tiers devenu moitie", "Rv%.RESCUE_DIV = 3", "Rv.RESCUE_DIV = 2", function(R) return R.rescue_low(60, true) ~= 20 end)
mutant_rv("portage sans stock", "and %(have or 0%) > 0", "", function(R) return R.hand_due(10, 0, 60, true) end)
mutant_rv("seuil inclusif", "return n < Rv%.rescue_low", "return n <= Rv.rescue_low", function(R) return R.hand_due(60, 100, 60, false) end)
mutant_rv("charge minimale oubliee", "return load >= Rv%.batch_min%(fill%) or load >= %(fill or 0%) %- n", "return true",
  function(R) return R.batch_ok(true, 50, 60, 400) end)
mutant_rv("quai a sec attend", "if n <= 0 then return true end", "", function(R) return not R.batch_ok(true, 0, 3, 400) end)
mutant_rv("coffre a combler attend", " or load >= %(fill or 0%) %- n", "", function(R) return not R.batch_ok(true, 395, 5, 400) end)
mutant_rv("hors mall attend", "if not mall then return true end", "", function(R) return not R.batch_ok(false, 50, 1, 400) end)
mutant_rv("quart devenu moitie", "Rv%.BATCH_DIV = 4", "Rv.BATCH_DIV = 2", function(R) return R.batch_min(400) ~= 100 end)
mutant_li("portee d'un mall oubliee dans l'appariement", "local reach, cap = Rv%.span_max%(d, Li%.MAX_SPAN%), Rv%.fan%(d%)", "local reach, cap = Li.MAX_SPAN, Rv.fan(d)",
  function(L) return #L.pairs({ dock("d", 1, 0, 0, "X", 1, true) }, { src("s", 2, far, 0, "X") }) == 0 end)
mutant_li("partage oublie dans l'appariement", "local reach, cap = Rv%.span_max%(d, Li%.MAX_SPAN%), Rv%.fan%(d%)", "local reach, cap = Rv.span_max(d, Li.MAX_SPAN), 1",
  function(L) return #L.pairs({ dock("a", 1, 0, 0, "X", 2, true), dock("b", 2, 0, 10, "X", 1, true) }, { src("s", 9, 5, 5, "X") }) == 1 end)
mutant_li("sortie prise deux fois", "used%[best%.key%] = %(used%[best%.key%] or 0%) %+ 1", "", function(L)
  return #L.pairs({ dock("a", 1, 0, 0, "X", 3, true), dock("b", 2, 0, 10, "X", 2, true), dock("c", 3, 0, 20, "X", 1, true) }, { src("s", 9, 5, 5, "X") }) == 3 end)
mutant_li("liaisons existantes ignorees", "%(used%[s%.key%] or 0%) %+ Rv%.taken%(s%) < cap", "(used[s.key] or 0) < cap",
  function(L) return #L.pairs({ dock("a", 1, 0, 0, "X", 1, true) }, { src("s", 9, 5, 5, "X", 2) }) == 1 end)
mutant_li("longueur du mall oubliee dans le trace", "max_len = max_len or Li%.MAX_LEN", "max_len = Li.MAX_LEN",
  function(L) return not select(1, L.route_ok(Li.MAX_LEN + 10, Li.MAX_LEN + 5, Rv.LEN)) end)
package.loaded["shared.team.ravitaillement"] = Rv

print(string.format("[RAVITAILLEMENT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
