--[[
  Lot s43 UX-COMMANDE : banc HORS JEU de la règle pure shared/ai3/commande.lua et de son câblage (lu dans les sources).
  Lancement : lua5.2 tests/s43_ux-commande_test.lua (racine du mod).
    1. orientation : poids bornés, « aucune » neutre, effet dans le bon sens, plage de B.weights jamais quittée ;
    2. ordres : pose, numéros croissants, plafond, refus, annulation, zone touchée ;
    3. type d'avant-poste lu aux données (shared/team/config.lua), ressource majoritaire, zone bornée ;
    4. buts : un gisement désigné ajoute ou relève le but d'extraction de son type (jamais la couverture), une fois par type ;
    5. sites et liaisons désignés d'abord (ordre relatif gardé), restriction des candidats, résolution ;
    6. câblage (sources) : chemin commun des équipes (aucun is_player), aucun pairs, aucun nom de minerai écrit ;
    7. mutants : chaque défaut injecté change au moins un fait observé.
]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")
local B = require("shared.ai3.buts")
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function read(path)
  local fh = assert(io.open(path, "r"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local function base_w(v)
  local w = {}
  for _, fam in ipairs(B.FAMILIES) do w[fam] = v end
  return w
end

---------------------------------------------------------------------------------------------------
section("1. orientation")
---------------------------------------------------------------------------------------------------
do
  local w = base_w(1000)
  local same = Co.weights(w, "aucune", B.W_MIN, B.W_MAX, B.FAMILIES)
  for _, fam in ipairs(B.FAMILIES) do check(same[fam] == 1000, "aucune : " .. fam .. " inchangé") end
  local unk = Co.weights(w, "n'importe", B.W_MIN, B.W_MAX, B.FAMILIES)
  check(unk.extraction == 1000, "orientation inconnue : inchangé")
  local ex = Co.weights(w, "expansion", B.W_MIN, B.W_MAX, B.FAMILIES)
  check(ex.extraction == 1600 and ex.extraction > same.extraction, "expansion : extraction × 1,6")
  check(ex.armee < 1000, "expansion : armée moins")
  local am = Co.weights(w, "amelioration", B.W_MIN, B.W_MAX, B.FAMILIES)
  check(am.capital > 1000 and am.recherche > 1000 and am.extraction < 1000, "amélioration : capital et recherche plus, extraction moins")
  local de = Co.weights(w, "defense", B.W_MIN, B.W_MAX, B.FAMILIES)
  check(de.defense == 1700 and de.armee == 1700, "défense : défense et armée × 1,7")
  check(w.extraction == 1000, "l'entrée n'est pas modifiée")
  -- Bornes : jamais hors [W_MIN, W_MAX], quelle que soit l'entrée de la plage.
  local ok = true
  for _, o in ipairs(Co.ORIENTATIONS) do
    for _, v in ipairs({ B.W_MIN, 800, 1000, 1500, B.W_MAX }) do
      local r = Co.weights(base_w(v), o, B.W_MIN, B.W_MAX, B.FAMILIES)
      for _, fam in ipairs(B.FAMILIES) do
        if r[fam] < B.W_MIN or r[fam] > B.W_MAX or r[fam] ~= math.floor(r[fam]) then ok = false end
      end
    end
  end
  check(ok, "poids toujours entiers et dans [W_MIN, W_MAX]")
  for _, o in ipairs(Co.ORIENTATIONS) do
    for _, fam in ipairs(B.FAMILIES) do
      local p = Co.PCT[o][fam] or 100
      check(p >= Co.PCT_MIN and p <= Co.PCT_MAX, "pourcentage borné " .. o .. "/" .. fam)
    end
  end
  check(Co.valid_orientation("defense") and not Co.valid_orientation("x"), "orientations valides")
  local part = Co.weights({ extraction = 1000 }, "expansion", B.W_MIN, B.W_MAX, B.FAMILIES)
  check(part.extraction == 1600 and part.armee == nil, "famille absente : absente")
end

---------------------------------------------------------------------------------------------------
section("2. ordres")
---------------------------------------------------------------------------------------------------
do
  local st = Co.new_state()
  check(st.orient == "aucune" and #st.orders == 0, "état vierge")
  local id1 = Co.add(st, { kind = "gisement", x = 10, y = 20, r = 30, resource = "r1", outpost = "k1" })
  local id2 = Co.add(st, { kind = "liaison", x = -5, y = 0, r = 1000 })
  check(id1 == 1 and id2 == 2, "numéros croissants")
  check(st.orders[2].r == Co.R_MAX, "rayon borné au maximum")
  local idx, why = Co.add(st, { kind = "gisement", x = 0, y = 0 })
  check(idx == nil and why == "ressource", "gisement sans type refusé")
  idx, why = Co.add(st, { kind = "autre", x = 0, y = 0 })
  check(idx == nil and why == "type", "sorte inconnue refusée")
  for i = 3, Co.MAX_ORDERS do Co.add(st, { kind = "liaison", x = i * 100, y = 0, r = 10 }) end
  idx, why = Co.add(st, { kind = "liaison", x = 0, y = 0 })
  check(#st.orders == Co.MAX_ORDERS and idx == nil and why == "plein", "plafond d'ordres")
  local o = Co.cancel(st, 2)
  check(o and o.id == 2 and #st.orders == Co.MAX_ORDERS - 1, "annulation")
  check(Co.cancel(st, 2) == nil, "annulation double : rien")
  local id9 = Co.add(st, { kind = "liaison", x = 1, y = 1 })
  check(id9 == Co.MAX_ORDERS + 1, "un numéro annulé n'est jamais repris")
  local hit = Co.hit(st, 0, 10, 20, 30)
  check(#hit == 1 and hit[1] == 1, "zone d'annulation : l'ordre dont le centre est dedans")
  check(#Co.deposits(st) == 1 and Co.deposits(st)[1].id == 1, "gisements vivants")
end

---------------------------------------------------------------------------------------------------
section("3. données")
---------------------------------------------------------------------------------------------------
do
  for _, k in ipairs(T.OUTPOST_ORDER) do
    local res = T.outposts[k].resource
    check(Co.kind_of(res, T.outposts, T.OUTPOST_ORDER) == k, "type lu aux données pour " .. k)
  end
  check(Co.kind_of("ressource-inconnue", T.outposts, T.OUTPOST_ORDER) == nil, "ressource sans type : nil")
  check(Co.majority({ "b", "a", "b", "a" }) == "a", "égalité : le plus petit nom")
  check(Co.majority({ "b", "a", "b" }) == "b", "majorité")
  check(Co.majority({}) == nil, "vide : nil")
  local cx, cy, r = Co.zone(0, 0, 2, 2)
  check(cx == 1 and cy == 1 and r == Co.R_MIN, "zone minuscule : rayon minimal")
  cx, cy, r = Co.zone(-100, -100, 100, 100)
  check(cx == 0 and cy == 0 and r == Co.R_MAX, "zone immense : rayon maximal")
end

---------------------------------------------------------------------------------------------------
section("4. buts")
---------------------------------------------------------------------------------------------------
do
  local orders = { { id = 3, kind = "gisement", outpost = "k1", x = 0, y = 0, r = 20 }, { id = 4, kind = "gisement", outpost = "k1", x = 50, y = 0, r = 20 } }
  local g = Co.goals({}, orders, 1000, { k1 = "p1" })
  check(#g == 1 and g[1].family == "extraction" and g[1].outpost == "k1" and g[1].value == Co.ORDER_VALUE and g[1].ordre == 3,
    "un but neuf par type désigné")
  check(g[1].kind == "outpost" and g[1].why == "p1" and not g[1].extend_only and not g[1].fond, "but de nouveau site, pas de fond")
  local low = { { key = "extraction:k1", family = "extraction", kind = "outpost", outpost = "k1", value = 55, fond = true } }
  g = Co.goals(low, orders, 1000, {})
  check(#g == 1 and g[1].value == Co.ORDER_VALUE and g[1].fond == nil, "but existant relevé, plus de fond")
  local high = { { key = "extraction:k1", family = "extraction", kind = "outpost", outpost = "k1", value = 92 } }
  g = Co.goals(high, orders, 1000, {})
  check(g[1].value == 92, "but plus haut gardé")
  local cover = { { key = "couverture:k1", family = "extraction", kind = "outpost", outpost = "k1", value = 40, extend_only = true } }
  g = Co.goals(cover, orders, 1000, {})
  check(#g == 2 and g[1].value == 40 and g[2].key == "ordre:k1", "la couverture n'est pas relevée : un but de nouveau site s'ajoute")
  g = Co.goals({}, orders, 2000, {})
  check(g[1].value <= 100, "valeur bornée à 100")
  g = Co.goals({}, orders, 500, {})
  check(g[1].value == Co.ORDER_VALUE, "un poids bas ne fait pas descendre l'ordre")
  local none = { { key = "x" } }
  check(Co.goals(none, nil, 1000, {}) == none and #none == 1, "sans ordre : inchangé")
  check(Co.ORDER_VALUE < B.BOOT_FUEL and Co.ORDER_VALUE > B.GROW, "valeur entre la croissance et l'amorçage")
end

---------------------------------------------------------------------------------------------------
section("5. sites, liaisons, résolution")
---------------------------------------------------------------------------------------------------
do
  local orders = { { id = 1, kind = "gisement", resource = "r1", outpost = "k1", x = 100, y = 100, r = 20 },
    { id = 2, kind = "liaison", x = -50, y = -50, r = 10 } }
  local a = { x = 0, y = 0, resource = "r1" }
  local b = { x = 105, y = 100, resource = "r1" }
  local c = { x = 100, y = 95, resource = "r2" }
  local d = { x = 110, y = 110, resource = "r1" }
  local list = { a, b, c, d }
  local p = Co.prefer(list, orders)
  check(p[1] == b and p[2] == d and p[3] == a and p[4] == c, "sites de la zone d'abord (même ressource), ordre relatif gardé")
  check(Co.prefer({ a, c }, orders)[1] == a, "aucun site dans la zone : liste telle quelle")
  check(Co.prefer(list, {}) == list, "sans ordre : même liste")
  local r = Co.restrict({ a, b, c, d }, orders)
  check(#r == 2 and r[1] == b and r[2] == d, "candidats restreints à la zone")
  check(#Co.restrict({ a, c }, orders) == 2, "aucun candidat dans la zone : tous")
  local p1 = { dock = { x = 0, y = 0 }, src = { x = 5, y = 5 } }
  local p2 = { dock = { x = 200, y = 0 }, src = { x = -52, y = -48 } }
  local p3 = { dock = { x = -50, y = -55 }, src = { x = 9, y = 9 } }
  local pp = Co.prefer_pairs({ p1, p2, p3 }, orders)
  check(pp[1] == p2 and pp[2] == p3 and pp[3] == p1, "paires de la zone de liaison d'abord (un bout suffit)")
  local st = { orders = orders }
  check(#Co.resolve(st, { { kind = "k1", x = 0, y = 0 } }) == 0, "avant-poste hors zone : rien")
  check(#Co.resolve(st, { { kind = "k2", x = 100, y = 100 } }) == 0, "autre type : rien")
  local done = Co.resolve(st, { { kind = "k1", x = 130, y = 100 } })
  check(#done == 1 and done[1] == 1 and #st.orders == 2, "rempli dans rayon + marge, sans rien modifier")
end

---------------------------------------------------------------------------------------------------
section("6. câblage")
---------------------------------------------------------------------------------------------------
do
  local src = read("shared/ai3/commande.lua")
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local np = code:gsub("ipairs%(", "")
  check(not np:find("%f[%w_]pairs%("), "aucun pairs dans la règle")
  check(not code:find("is_player"), "aucun is_player dans la règle")
  check(not code:find("game%.") and not code:find("defines%."), "règle pure (aucune API)")
  for _, k in ipairs(T.OUTPOST_ORDER) do
    check(not code:find(T.outposts[k].resource, 1, true), "aucun nom de minerai écrit : " .. k)
  end
  local cerv = read("script/ai3/cerveau.lua")
  local i_w = cerv:find("w = Co.weights(w, cmd.orient", 1, true)
  local i_b = cerv:find("local w = B.weights(", 1, true)
  check(i_w and i_b and i_w > i_b, "orientation appliquée juste après B.weights (toute équipe)")
  check(cerv:find("ordres = f.team.commande and Co.deposits", 1, true) ~= nil, "gisements désignés passés au cerveau")
  local sc = read("shared/ai3/cerveau.lua")
  check(sc:find("goals = Co.goals(goals, ctx.ordres", 1, true) ~= nil, "buts des ordres après B.generate")
  local sites = read("script/faction/sites.lua")
  local i_pref = sites:find("f.prospects = Co.prefer(", 1, true)
  local i_br = sites:find("if not f.is_player then return find_by_value", 1, true)
  check(i_pref and i_br and i_pref < i_br, "réserve réordonnée AVANT la branche faction / joueur")
  check(sites:find("cands = Co.restrict(", 1, true) ~= nil, "choix par valeur restreint à la zone")
  local li = read("script/team/liaison.lua")
  check(li:find("pairs_ = Co.prefer_pairs(pairs_", 1, true) ~= nil, "relevé des liaisons : zone d'abord")
  local proto = read("prototypes/commande.lua")
  local gui = read("script/gui/commande.lua")
  check(proto:find('"fo-commande-outil"', 1, true) and gui:find('Cmd.TOOL = "fo-commande-outil"', 1, true), "outil : même nom aux deux stades")
  for _, lang in ipairs({ "fr", "en" }) do
    local loc = read("locale/" .. lang .. "/commande.cfg")
    for key in gui:gmatch('"fo%-commande%.([%w%-]+)"') do
      if key:sub(-1) ~= "-" then check(loc:find("\n" .. key .. "=", 1, true) ~= nil, lang .. " : clé " .. key) end
    end
    for _, o in ipairs(Co.ORIENTATIONS) do
      check(loc:find("\nor-" .. o .. "=", 1, true) and loc:find("\nor-" .. o .. "-aide=", 1, true), lang .. " : orientation " .. o)
    end
    for _, why in ipairs({ "plein", "vide", "ressource", "type" }) do check(loc:find("\nrefus-" .. why .. "=", 1, true), lang .. " : refus " .. why) end
    for _, k in ipairs({ "gisement", "liaison" }) do check(loc:find("\npose-" .. k .. "=", 1, true), lang .. " : pose " .. k) end
  end
end

---------------------------------------------------------------------------------------------------
section("7. mutants")
---------------------------------------------------------------------------------------------------
do
  local function facts()
    local f = {}
    local w = Co.weights(base_w(1000), "expansion", B.W_MIN, B.W_MAX, B.FAMILIES)
    f[#f + 1] = w.extraction
    f[#f + 1] = Co.weights(base_w(1000), "defense", B.W_MIN, B.W_MAX, B.FAMILIES).armee
    local orders = { { id = 1, kind = "gisement", resource = "r1", outpost = "k1", x = 0, y = 0, r = 10 } }
    f[#f + 1] = #Co.goals({}, orders, 1000, {})
    f[#f + 1] = Co.prefer({ { x = 50, y = 0, resource = "r1" }, { x = 1, y = 0, resource = "r1" } }, orders)[1].x
    f[#f + 1] = #Co.resolve({ orders = orders }, { { kind = "k1", x = 20, y = 0 } })
    return table.concat(f, ",")
  end
  local ref = facts()
  local function mutant(name, apply, undo)
    apply()
    local got = facts()
    undo()
    check(got ~= ref, "mutant détecté : " .. name)
  end
  local pct = Co.PCT.expansion.extraction
  mutant("expansion neutre", function() Co.PCT.expansion.extraction = 100 end, function() Co.PCT.expansion.extraction = pct end)
  local wmax = B.W_MAX
  mutant("borne des pourcentages resserrée", function() Co.PCT_MAX = 150 end, function() Co.PCT_MAX = 200 end)
  local g = Co.goals
  mutant("buts ignorés", function() Co.goals = function(x) return x end end, function() Co.goals = g end)
  local p = Co.prefer
  mutant("réserve non réordonnée", function() Co.prefer = function(l) return l end end, function() Co.prefer = p end)
  local m = Co.DONE_MARGIN
  mutant("marge de résolution nulle", function() Co.DONE_MARGIN = 0 end, function() Co.DONE_MARGIN = m end)
  check(facts() == ref and B.W_MAX == wmax, "état rendu après les mutants")
end

print(string.format("s43_ux-commande : %d OK, %d ECHEC", passes, failures))
if failures > 0 then os.exit(1) end
