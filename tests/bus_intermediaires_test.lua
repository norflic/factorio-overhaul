--[[
  Lot BUS-INTERMEDIAIRES : banc HORS JEU de la règle pure shared/team/bus_intermediaires.lua et de son câblage (lu comme texte).
  Lancement, depuis la racine du mod : lua5.2 tests/bus_intermediaires_test.lua
    §1 Bi.lines : par phase (early : liste vide, jamais nil), k, débit minimal (une machine entière), rangées, ordre, déterminisme ;
    §2 Bi.fallback et Bi.empty_count : ligne absente, pas finie, coffre vide depuis N relevés ;
    §3 bus : Bi.order_buses, Bi.count_links, Bi.link_ok (compte à part : Bus.MAX_LINKS n'arrête pas un intermédiaire) ; mall : Bi.order_cands ;
    §4 Ml (shared/ai3/mall.lua) : Ml.hand_allowed rend la main à un intermédiaire en repli, Ml.sinks met les lignes d'abord sans doublon ;
    §5 DOUBLURE du solveur (contrat du lot RECIPE-SOLVER : Solver.new(book, bus), Solver.hubs(s, demands, k)) sur le livre de recettes du banc ;
    §6 câblage lu comme texte (script/ai3/industrie.lua, script/team/bus.lua, shared/ai3/mall.lua) ; §8 : aucun nom d'objet dans la règle ;
    §7 mutants (chaque règle cassée est vue par la batterie).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = tostring(k) end
  table.sort(ks)
  local parts = {}
  for _, k in ipairs(ks) do parts[#parts + 1] = k .. "=" .. ser(v[k] ~= nil and v[k] or v[tonumber(k)]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

local Bi = require("shared.team.bus_intermediaires")
local Ml = require("shared.ai3.mall")
local P = require("shared.team.patrons")

local HUBS = {
  { item = "h-circ", rate = 18, machines = 1.8 },
  { item = "h-gear", rate = 30, machines = 3 },
  { item = "h-steel", rate = 6, machines = 1 },
  { item = "h-pipe", rate = 4, machines = 0.4 },
  { item = "h-wire", rate = 12, machines = 1.2 },
  { item = "h-stick", rate = 6, machines = 1 },
}

---------------------------------------------------------------------------------------------------
-- Batterie (réutilisée par les mutants) : rend le nombre d'échecs
---------------------------------------------------------------------------------------------------
local function battery(B, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 end
    if verbose then check(c, msg) end
    return c
  end
  -- §1 lignes
  local early = B.lines(HUBS, "early")
  ck(type(early) == "table" and #early == 0, "1.1 early : liste vide, jamais nil")
  ck(#B.lines(HUBS, nil) == 0 and #B.lines(HUBS, "autre") == 0, "1.2 phase absente ou inconnue : aucune ligne")
  local mid = B.lines(HUBS, "mid")
  ck(#mid == 3, "1.3 mid : k = 3 lignes (" .. #mid .. ")")
  ck(#B.lines(HUBS, "late") == 3, "1.4 late : lignes aussi")
  ck(#B.lines(HUBS, "mid", nil, true) == 0 and #B.lines(HUBS, "late", nil, true) == 0, "1.4 bis famine de la plaque clé : aucune ligne, même en mid ou late")
  ck(#B.lines(HUBS, "mid", nil, false) == 3, "1.4 ter sans famine : les 3 lignes")
  do -- débit demandé borné à une rangée (banc V0676-N : 36 machines d'engrenages demandées d'un coup)
    local big = B.lines({ { item = "h-big", rate = 72, machines = 36 }, { item = "h-one", rate = 2, machines = 1 } }, "mid", { machines_par_rangee = 6 })
    ck(big[1] and big[1].item == "h-big" and math.abs(big[1].rate_row - 12) < 1e-9, "1.6 36 machines pour 72/min : la ligne demande 12/min (une rangée de 6)")
    ck(big[2] and math.abs(big[2].rate_row - 2) < 1e-9, "1.6 bis une machine : le débit entier")
  end
  ck(mid[1] and mid[1].item == "h-gear" and mid[2].item == "h-circ" and mid[3].item == "h-wire", "1.5 ordre par débit décroissant")
  local names = {}
  for _, l in ipairs(B.lines(HUBS, "mid", { k = 6 })) do names[l.item] = true end
  ck(names["h-pipe"] == nil and names["h-steel"] and names["h-stick"], "1.6 débit minimal dérivé : 0,4 machine écarté, 1 machine entière gardée")
  local two = B.lines(HUBS, "mid", { k = 2 })
  ck(#two == 2 and two[2].item == "h-circ", "1.7 cfg.k = 2")
  ck(#B.lines(HUBS, "mid", { k = 0 }) == 0, "1.8 k = 0 : rien")
  local tie = B.lines({ { item = "b", rate = 6, machines = 1 }, { item = "a", rate = 6, machines = 1 } }, "mid")
  ck(tie[1].item == "a" and tie[2].item == "b", "1.9 égalité de débit : le nom départage")
  ck(mid[1].rows == 1 and mid[1].machines == 3 and mid[1].rate == 30, "1.10 une rangée pour 3 machines (rows, machines, rate rendus)")
  local big = B.lines({ { item = "x", rate = 1000, machines = P.MAX_N + 1 } }, "mid")
  ck(big[1].rows == 2, "1.11 " .. (P.MAX_N + 1) .. " machines : 2 rangées (machines_par_rangee = P.MAX_N)")
  ck(B.lines({ { item = "x", rate = 1000, machines = P.MAX_N } }, "mid")[1].rows == 1, "1.12 exactement une rangée pleine : 1")
  ck(B.lines({ { item = "x", rate = 100, machines = 25 } }, "mid", { machines_par_rangee = 10 })[1].rows == 3, "1.13 cfg.machines_par_rangee = 10 : 25 machines -> 3 rangées")
  ck(#B.lines({ { item = "x", rate = 0, machines = 2 }, { item = 7, rate = 5, machines = 2 } }, "mid") == 0, "1.14 débit nul ou objet non nommé : écarté")
  ck(#B.lines({ { item = "x", rate = 3, machines = 2 } }, "mid", { min_rate = 5 }) == 0, "1.15 cfg.min_rate : seuil de plus")
  local rev = {}
  for i = #HUBS, 1, -1 do rev[#rev + 1] = HUBS[i] end
  ck(ser(B.lines(rev, "mid")) == ser(mid), "1.16 déterminisme : liste inversée, même résultat")
  ck(ser(B.lines(HUBS, "mid")) == ser(mid), "1.17 déterminisme : deux appels, même résultat")
  ck(#HUBS == 6 and HUBS[1].rows == nil, "1.18 l'entrée n'est pas modifiée")
  -- §2 repli
  ck(B.fallback(nil) == true, "2.1 état absent : main permise")
  ck(B.fallback({ present = false }) == true, "2.2 ligne absente : main permise")
  ck(B.fallback({ present = false, done = true, empty_releves = 0 }) == true, "2.2 bis ligne absente même « finie » ailleurs : main permise")
  ck(B.fallback({ present = true, done = false, empty_releves = 0 }) == true, "2.3 ligne pas finie : main permise")
  ck(B.fallback({ present = true, done = true, empty_releves = 2 }) == false, "2.4 ligne finie qui produit : main refusée")
  ck(B.fallback({ present = true, done = true, empty_releves = 3 }) == true, "2.5 coffre vide depuis 3 relevés : main permise")
  ck(B.fallback({ present = true, done = true, empty_releves = 3 }, { empty_releves = 5 }) == false, "2.6 cfg.empty_releves = 5 : 3 relevés ne suffisent pas")
  local _, why = B.fallback({ present = true, done = true, empty_releves = 4 })
  ck(type(why) == "string" and why:find("4") ~= nil, "2.7 cause écrite")
  ck(B.empty_count(0, true) == 0 and B.empty_count(5, true) == 0, "2.8 une production remet le compte à zéro")
  ck(B.empty_count(2, false) == 3 and B.empty_count(nil, false) == 1, "2.9 sans production : +1")
  -- §3 bus et mall
  local hubs = B.hub_rates(mid)
  ck(hubs["h-gear"] == 30 and hubs["h-circ"] == 18 and hubs["h-wire"] == 12 and hubs["h-steel"] == nil, "3.1 hub_rates")
  local buses = { { item = "x", id = 1 }, { item = "h-circ", id = 2 }, { item = "h-gear", id = 3 }, { item = "y", id = 4 } }
  local ob = B.order_buses(buses, hubs)
  ck(ob[1].id == 3 and ob[2].id == 2 and ob[3].id == 1 and ob[4].id == 4, "3.2 bus d'intermédiaires devant, par débit du hub, les autres dans leur ordre")
  ck(ob ~= buses and buses[1].id == 1, "3.3 liste neuve, entrée intacte")
  local same = B.order_buses(buses, {})
  ck(same[1].id == 1 and same[4].id == 4, "3.4 sans hub : ordre inchangé")
  ck(#B.order_buses(nil, hubs) == 0 and #B.order_buses(buses, nil) == 4, "3.5 entrées absentes tolérées")
  local cands = { { items = { "x" } }, { items = { "y", "h-wire" } }, { items = { "h-gear" } } }
  local oc = B.order_cands(cands, hubs)
  ck(oc[1].items[1] == "h-gear" and oc[2].items[2] == "h-wire" and oc[3].items[1] == "x", "3.6 décisions du mall : celles d'un hub devant")
  local links = { q1 = { bus = true, item = "h-gear" }, q2 = { bus = true, item = "x" }, q3 = { bus = false, item = "x" }, q4 = { bus = true, item = "h-circ", done = true } }
  local counts = B.count_links(links, hubs)
  ck(counts.hubs == 2 and counts.autres == 1, "3.7 comptes à part (hubs 2, autres 1 ; une liaison de quai ne compte pas)")
  ck(B.link_ok({ hubs = 2, autres = 4 }, "h-gear", hubs, 4) == true, "3.8 plafond Bus.MAX_LINKS atteint : une liaison d'intermédiaire passe encore")
  ck(B.link_ok({ hubs = 3, autres = 0 }, "h-gear", hubs, 4) == false, "3.9 k liaisons d'intermédiaires : la suivante attend")
  ck(B.link_ok({ hubs = 0, autres = 4 }, "x", hubs, 4) == false, "3.10 autre objet : Bus.MAX_LINKS tient")
  ck(B.link_ok({ hubs = 3, autres = 3 }, "x", hubs, 4) == true, "3.11 autre objet : les liaisons d'intermédiaires ne le comptent pas")
  ck(B.link_ok(nil, "x", nil, 4) == true, "3.12 comptes absents : permise")
  -- §4 Ml
  local st = Ml.new()
  st.running = { ["h-gear"] = true, fini = true }
  ck(Ml.hand_allowed(st, "h-gear", 10) == false and Ml.hand_allowed(st, "fini", 10) == false, "4.1 sans repli : le mall qui tourne refuse la main")
  st.bi = { lines = { { item = "h-gear", rate = 30, machines = 3, rows = 1 } }, hubs = { ["h-gear"] = 30 }, fallback = { ["h-gear"] = true } }
  ck(Ml.hand_allowed(st, "h-gear", 10) == true, "4.2 ligne en repli : la main reste permise malgré le mall qui tourne")
  ck(Ml.hand_allowed(st, "fini", 10) == false, "4.3 l'objet fini reste refusé")
  st.items = { { item = "fini", rate = 2, machines = 1, target = 20, have = 0 }, { item = "h-gear", rate = 5, machines = 1, target = 50, have = 0 } }
  local sinks = Ml.sinks(st)
  ck(#sinks == 2 and sinks[1].item == "h-gear" and sinks[1].rate == 30 and sinks[1].src == B.SRC and sinks[2].item == "fini", "4.4 Ml.sinks : la ligne d'abord, au débit du hub, sans doublon")
  st.bi = nil
  ck(#Ml.sinks(st) == 2 and Ml.sinks(st)[1].item == "fini", "4.5 sans st.bi : les puits d'avant, ligne pour ligne")
  ck(type(B.describe(mid, { ["h-gear"] = true })) == "string" and B.describe(mid, { ["h-gear"] = true }):find("h%-gear 1 rangee") ~= nil
    and B.describe(mid, { ["h-gear"] = true }):find("main permise") ~= nil and B.describe({}) == "aucune", "4.6 Bi.describe")
  return fails
end

check(battery(Bi, true) == 0, "batterie de référence sans échec")

---------------------------------------------------------------------------------------------------
-- §5 doublure du solveur (contrat du lot RECIPE-SOLVER), sur le livre de recettes du banc
---------------------------------------------------------------------------------------------------
do
  local Book = require("shared.team.book")
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local UNIT = 10 -- objets par minute d'une machine dans la doublure (le vrai solveur lit le débit de la recette)
  local Solver = {}
  function Solver.new(bk, bus) return { book = bk, bus = bus } end
  --- Un niveau de dépliage : tout ingrédient hors bus qui a une recette est un hub, au débit sommé sur les demandes.
  function Solver.hubs(s, demands, k)
    local acc = {}
    for _, d in ipairs(demands) do
      local rn = s.book:recipe_for(d.item)
      local r = rn and s.book.recipes[rn]
      for _, ing in ipairs(r and r.ingredients or {}) do
        if not s.bus[ing.name] and s.book:recipe_for(ing.name) then acc[ing.name] = (acc[ing.name] or 0) + d.rate * ing.amount end
      end
    end
    local out = {}
    for it, rate in pairs(acc) do out[#out + 1] = { item = it, rate = rate, machines = rate / UNIT } end
    table.sort(out, function(a, b) if a.rate ~= b.rate then return a.rate > b.rate end return a.item < b.item end)
    while #out > k do out[#out] = nil end
    return out
  end
  local bus = { ["iron-plate"] = true, ["copper-plate"] = true, coal = true, stone = true }
  local demands = { { item = "assembling-machine-1", rate = 6 } }
  local hubs = Solver.hubs(Solver.new(book, bus), demands, Bi.CFG.k)
  check(#hubs == 2 and hubs[1].item == "iron-gear-wheel" and hubs[1].rate == 30 and hubs[2].item == "electronic-circuit" and hubs[2].rate == 18,
    "5.1 doublure : les plaques (bus) ne sont pas des hubs, les intermédiaires le sont, triés par débit")
  local lines = Bi.lines(hubs, "mid", Bi.CFG)
  check(#lines == 2 and lines[1].item == "iron-gear-wheel" and lines[1].rows == 1 and lines[2].machines == 1.8, "5.2 Bi.lines sur la sortie du solveur (mid)")
  check(#Bi.lines(hubs, "early", Bi.CFG) == 0, "5.3 early : aucune ligne malgré les hubs")
  check(#Bi.lines(hubs, "mid", Bi.CFG, true) == 0, "5.3 bis famine de la plaque clé : aucune ligne en mid (le fer va aux bandes)")
  check(#Bi.lines(hubs, "mid", Bi.CFG, false) == #lines, "5.3 ter sans famine : les lignes de 5.1")
  local small = Solver.hubs(Solver.new(book, bus), { { item = "assembling-machine-1", rate = 1 } }, Bi.CFG.k)
  check(#Bi.lines(small, "mid", Bi.CFG) == 0, "5.4 demande d'une machine par minute : moins d'une machine entière par hub, aucune ligne (pas de micro-usine)")
end

---------------------------------------------------------------------------------------------------
-- §6 câblage lu comme texte
---------------------------------------------------------------------------------------------------
do
  local ind = read("script/ai3/industrie.lua")
  check(ind:find('require("shared.team.bus_intermediaires")', 1, true) ~= nil, "6.1 industrie.lua requiert la règle")
  check(ind:find("intermediaires(f, ml, cs, book, tick)", 1, true) ~= nil, "6.2 Ind.think appelle les lignes d'intermédiaires")
  check(ind:find("Ml.want(ml, tick, l.item, l.rate_row or l.rate, Bi.SRC)", 1, true) ~= nil, "6.3 la demande des lignes passe par Ml.want (source Bi.SRC), bornee a une rangee")
  check(ind:find("Bi.lines(S.hubs(S.new(book, bus_set()), demands, Bi.CFG.k), phase, Bi.CFG, famine)", 1, true) ~= nil and ind:find("Famine.team_starved(f, tick) == true", 1, true) ~= nil, "6.4 contrat Solver.new(book, bus) / Solver.hubs(s, demands, k) ; famine de la plaque clé transmise")
  check(ind:find("T.outposts[kind]", 1, true) ~= nil and ind:find("if T.fuel then out[T.fuel] = true end", 1, true) ~= nil, "6.5 bus = produits des avant-postes et combustible, lus aux données")
  check(ind:find("(f.elec and f.elec.phase) or \"early\"", 1, true) ~= nil, "6.6 phase : l'arbre de décision écrit par Elec (Dt.phase), early sinon")
  check(ind:find("cands = Bi.order_cands(cands, ml.bi and ml.bi.hubs)", 1, true) ~= nil, "6.7 les décisions d'un intermédiaire pivot devant les objets finis")
  check(ind:find("if Bi.fallback(states[l.item], Bi.CFG) then fallback[l.item] = true end", 1, true) ~= nil, "6.8 repli écrit dans ml.bi.fallback")
  check(ind:find("pcall(require, \"shared.team.recipe_solver\")", 1, true) ~= nil, "6.9 solveur requis sous garde (absent : le mall joue comme avant)")
  check(ind:find("rangee d'intermediaire demandee", 1, true) ~= nil, "6.10 journal [FO-MALL] rangee d'intermediaire demandee")
  local bus = read("script/team/bus.lua")
  check(bus:find("Bi.order_buses(res.buses, hubs)", 1, true) ~= nil, "6.11 bus.lua : les bus d'intermédiaires classés devant")
  check(bus:find("Bi.count_links(st.links, hubs)", 1, true) ~= nil and bus:find("Bi.link_ok(counts, bus.item, hubs, Bus.MAX_LINKS)", 1, true) ~= nil, "6.12 bus.lua : compte à part, Bus.MAX_LINKS n'arrête pas un intermédiaire")
  check(bus:find("paire d'intermediaire", 1, true) ~= nil, "6.13 journal [FO-BUS] paire d'intermediaire")
  check(bus:find("f.team.ia3.mall", 1, true) ~= nil and bus:find("ml.bi.hubs", 1, true) ~= nil, "6.14 Bus.hubs lit ml.bi.hubs (données du mall)")
  local code = bus:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(code:find("total < Bus.MAX_LINKS", 1, true) == nil, "6.15 l'ancien plafond unique a disparu")
  local mall = read("shared/ai3/mall.lua")
  check(mall:find("st.bi.fallback[item]", 1, true) ~= nil and mall:find("st.bi.lines", 1, true) ~= nil, "6.16 mall.lua : repli (hand_allowed) et lignes d'abord (sinks)")
  -- §8 : la règle ne nomme aucun objet du jeu (chaînes hors journal)
  local src = read("shared/team/bus_intermediaires.lua"):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not src:find("iron%-") and not src:find("copper%-") and not src:find("gear") and not src:find("circuit") and not src:find("steel")
    and not src:find("%f[%w]pairs%(") and not src:find("os%.clock") and not src:find("math%.random"), "6.17 règle pure : aucun nom d'objet, aucun pairs, ni horloge, ni hasard")
  local n = 0
  for _ in src:gmatch("\nfunction ") do n = n + 1 end
  check(n >= 10, "6.18 fonctions de la règle présentes (" .. n .. ")")
end

---------------------------------------------------------------------------------------------------
-- §7 mutants
---------------------------------------------------------------------------------------------------
local SRC = read("shared/team/bus_intermediaires.lua")
local MUTANTS = {
  { "phase : toute phase sauf early", 'return phase == "mid" or phase == "late"', 'return phase ~= "early"' },
  { "famine ignorée", "if famine == true then return out end", "" },
  { "débit d'une rangée non borné", "math.min(l.rate, l.rate * c.machines_par_rangee / l.machines)", "l.rate" },
  { "débit minimal : demi-machine admise", "m + Bi.EPS >= c.min_machines", "m + Bi.EPS >= 0" },
  { "k ignoré", "for i = 1, math.min(c.k, #cands) do", "for i = 1, #cands do" },
  { "rangées arrondies en dessous", "math.ceil(l.machines / c.machines_par_rangee - Bi.EPS)", "math.floor(l.machines / c.machines_par_rangee + Bi.EPS)" },
  { "ordre des lignes inversé", "if a.rate ~= b.rate then return a.rate > b.rate end\n    return a.item < b.item", "if a.rate ~= b.rate then return a.rate < b.rate end\n    return a.item < b.item" },
  { "repli : ligne pas finie ignorée", 'if ls.done ~= true then return true, "ligne pas finie" end', 'if false then return true, "ligne pas finie" end' },
  { "repli : seuil de relevés décalé", "if n >= c.empty_releves then", "if n > c.empty_releves then" },
  { "compte à part perdu", "if num(counts.hubs) < c.k then", "if num(counts.hubs) + num(counts.autres) < c.k then" },
  { "bonus du hub inversé", "if a.bonus ~= b.bonus then return a.bonus > b.bonus end", "if a.bonus ~= b.bonus then return a.bonus < b.bonus end" },
  { "production qui ne remet pas à zéro", "if produced then return 0 end", "if produced then return math.floor(num(prev)) end" },
  { "repli : ligne absente servie", 'if type(ls) ~= "table" or ls.present ~= true then return true, "ligne absente" end', 'if type(ls) ~= "table" then return true, "ligne absente" end' },
  { "autres liaisons sans plafond", "if num(counts.autres) < num(max_links) then return true", "if true then return true" },
}
local killed = 0
for _, m in ipairs(MUTANTS) do
  local name, from, to = m[1], m[2], m[3]
  local i = SRC:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") else
    local src = SRC:sub(1, i - 1) .. to .. SRC:sub(i + #from)
    local chunk, err = load(src, "=mutant:" .. name)
    if not chunk then check(false, "mutant '" .. name .. "' ne se charge pas : " .. tostring(err)) else
      local ok, B = pcall(chunk)
      local n = ok and type(B) == "table" and battery(B, false) or 1
      if type(n) ~= "number" or n > 0 then killed = killed + 1 else check(false, "mutant survivant : " .. name) end
    end
  end
end
print(string.format("   mutants refusés : %d / %d", killed, #MUTANTS))
check(killed == #MUTANTS, "tous les mutants refusés")
print(string.format("[BUS-INTERMEDIAIRES] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
