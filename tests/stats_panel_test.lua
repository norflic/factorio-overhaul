-- Banc hors jeu du lot PANEL-STATS : modèle pur du panneau de statistiques (shared/gui/stats.lua).
--   lua5.2 tests/stats_panel_test.lua      -> BILAN : N OK, 0 ECHEC(S) ; mutants refusés M / M
-- Contrôles : tri et réduction des compteurs, anneau de relevés (borné, même tick), débits par minute (écart de deux
-- relevés, plus ancien relevé qui contient l'objet, compteur qui baisse), tableau des flux (ordre, égalités, débit
-- inconnu en dernier), décompte des tâches des PNJ (la somme vaut l'effectif), formats, état borné, AUCUN nom d'objet
-- du jeu dans le modèle, traductions FR et EN des clés du panneau. Mutants : chaque règle faussée doit faire échouer au
-- moins un contrôle. Le moteur réel est prouvé par le scénario « ia1-gui » (valeurs du panneau contre le moteur).

package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(cond, what, detail)
  if cond then
    ok_n = ok_n + 1
  else
    fail_n = fail_n + 1
    print("ECHEC " .. what .. (detail and (" : " .. tostring(detail)) or ""))
  end
end

local function read_file(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SOURCE = read_file("shared/gui/stats.lua")

local function load_module(src)
  local chunk, err = load(src, "=shared/gui/stats.lua")
  assert(chunk, err)
  return chunk()
end

local function near(a, b, eps) return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or 1e-9) end

local function run_all(S)
  ok_n, fail_n = 0, 0

  ---------------------------------------------------------------------------------------------------
  -- Outils
  ---------------------------------------------------------------------------------------------------
  local keys = S.sorted_keys({ b = 1, a = 2, c = 3 })
  check(table.concat(keys, ",") == "a,b,c", "clés triées", table.concat(keys, ","))
  check(#S.sorted_keys(nil) == 0, "clés d'une table absente")
  local mixed = S.sorted_keys({ [3] = 1, [1] = 1, x = 1 })
  check(mixed[1] == 1 and mixed[2] == 3 and mixed[3] == "x", "clés mêlées : nombres avant chaînes")
  check(S.sum({ a = 3, b = 4.5, c = "x" }) == 7.5 and S.sum(nil) == 0, "somme (valeurs non numériques ignorées)")

  local top = S.top({ a = 5, b = 9, c = 9, d = 0, e = -3, f = 1 }, 3)
  check(#top == 3 and top[1].name == "b" and top[2].name == "c" and top[3].name == "a",
    "top : décroissant, égalités par clé, zéro et négatifs exclus")
  check(#S.top({ a = 1 }, 5) == 1 and #S.top({}, 5) == 0, "top : moins d'éléments que demandé")
  check(#S.top({ z = 0, y = 1, w = -1 }, 5) == 1, "top : un compteur à zéro n'est pas un flux")
  local trimmed = S.trim({ a = 1, b = 2, c = 3, d = 4 }, 2)
  check(trimmed.d == 4 and trimmed.c == 3 and trimmed.a == nil and trimmed.b == nil, "trim : les 2 plus gros")

  ---------------------------------------------------------------------------------------------------
  -- Relevés
  ---------------------------------------------------------------------------------------------------
  local s1 = S.make_sample(100, { x = 10, y = 5 }, { x = 2 }, { y = 1 }, 7, 3)
  check(s1.tick == 100 and s1.prod.x == 10 and s1.cons.x == 2 and s1.hand.y == 1 and s1.mined == 7 and s1.crafted == 3,
    "relevé : champs")
  local big = {}
  for i = 1, 100 do big["item" .. string.format("%03d", i)] = i end
  local sb = S.make_sample(0, big, big, big)
  local np, nc, nh = 0, 0, 0
  for _ in pairs(sb.prod) do np = np + 1 end
  for _ in pairs(sb.cons) do nc = nc + 1 end
  for _ in pairs(sb.hand) do nh = nh + 1 end
  check(np == S.KEEP.prod and nc == S.KEEP.cons and nh == S.KEEP.hand, "relevé borné par champ",
    np .. "/" .. nc .. "/" .. nh)
  check(sb.prod.item100 == 100 and sb.prod.item001 == nil, "relevé : garde les plus gros")
  check(sb.mined == 0 and sb.crafted == 0, "relevé : scalaires absents = 0")
  -- Un objet récent à faible cumul mais à fort débit entre dans le relevé grâce au débit récent lu au moteur (`hot`).
  local base = {}
  for i = 1, 40 do base["old" .. string.format("%02d", i)] = 1000 + i end
  local cur, hot = {}, { prod = {}, cons = {} }
  for k, v in pairs(base) do cur[k] = v; hot.prod[k] = 1 end
  cur.newpack = 300 -- cumul faible (300 < 1000) mais 300 de plus par minute
  hot.prod.newpack = 300
  local s_with = S.make_sample(S.PERIOD, cur, {}, {}, 0, 0, hot)
  local s_without = S.make_sample(S.PERIOD, cur, {}, {})
  check(s_with.prod.newpack == 300 and s_without.prod.newpack == nil,
    "relevé : l'objet récent à fort débit entre grâce au débit récent (et pas sans lui)")
  local n_with = 0
  for _ in pairs(s_with.prod) do n_with = n_with + 1 end
  check(n_with <= 2 * S.KEEP.prod, "relevé : borné à 2 x la limite avec le débit récent", tostring(n_with))
  hot.prod.ghost = 999 -- un débit récent sans compteur (objet absent) ne crée rien
  check(S.make_sample(S.PERIOD, cur, {}, {}, 0, 0, hot).prod.ghost == nil, "relevé : débit récent d'un objet sans compteur ignoré")
  local ring = {}
  S.push(ring, s_with, S.RING)
  local nxt = {}
  for k, v in pairs(cur) do nxt[k] = v + 1 end
  nxt.newpack = 600
  S.push(ring, S.make_sample(2 * S.PERIOD, nxt, {}, {}, 0, 0, hot), S.RING)
  local rows = S.flows(ring, "prod", 3)
  check(rows[1] and rows[1].name == "newpack" and rows[1].rate and rows[1].rate > 300, "flux : l'objet récent est en tête du tableau par débit",
    rows[1] and (rows[1].name .. " " .. tostring(rows[1].rate)))

  local ring = {}
  for i = 1, 20 do S.push(ring, S.make_sample(i * S.PERIOD, { x = i }, {}, {}), S.RING) end
  check(#ring == S.RING and ring[1].tick == (20 - S.RING + 1) * S.PERIOD and ring[#ring].tick == 20 * S.PERIOD,
    "anneau borné : les " .. S.RING .. " derniers relevés")
  local twice = {}
  S.push(twice, S.make_sample(500, { x = 1 }, {}, {}), S.RING)
  S.push(twice, S.make_sample(500, { x = 99 }, {}, {}), S.RING)
  check(#twice == 1 and twice[1].prod.x == 99, "deux relevés au même tick : le dernier remplace")

  ---------------------------------------------------------------------------------------------------
  -- Débits par minute
  ---------------------------------------------------------------------------------------------------
  local r = {}
  S.push(r, S.make_sample(0, { x = 100 }, { x = 10 }, { h = 1 }, 0, 0), 7)
  check(S.rate(r, "prod", "x") == nil, "un seul relevé : pas de débit")
  S.push(r, S.make_sample(1800, { x = 160 }, { x = 40 }, { h = 4 }, 5, 1), 7)
  check(near(S.rate(r, "prod", "x"), 120), "débit : 60 objets en 30 s = 120 / min", S.rate(r, "prod", "x"))
  check(near(S.rate(r, "cons", "x"), 60), "consommation : 30 en 30 s = 60 / min")
  check(near(S.rate(r, "hand", "h"), 6), "mains : 3 en 30 s = 6 / min")
  check(near(S.rate_scalar(r, "mined"), 10) and near(S.rate_scalar(r, "crafted"), 2), "débit des compteurs scalaires")
  check(S.rate(r, "prod", "absent") == nil, "objet inconnu : pas de débit")
  S.push(r, S.make_sample(3600, { x = 160, y = 60 }, { x = 40 }, { h = 4 }, 5, 1), 7)
  check(near(S.rate(r, "prod", "x"), 60), "débit sur toute la fenêtre : 60 objets en 60 s (plus ancien relevé)", S.rate(r, "prod", "x"))
  check(S.rate(r, "prod", "y") == nil, "objet apparu au dernier relevé seulement : pas de débit")
  S.push(r, S.make_sample(5400, { x = 160, y = 90 }, { x = 40 }, { h = 4 }, 5, 1), 7)
  check(near(S.rate(r, "prod", "y"), 60), "objet apparu en cours de fenêtre : relevé le plus ancien qui le contient",
    S.rate(r, "prod", "y"))
  check(near(S.rate(r, "prod", "x"), 40), "débit de x sur 90 s : 60 objets = 40 / min", S.rate(r, "prod", "x"))
  local reset = {}
  S.push(reset, S.make_sample(0, { x = 500 }, {}, {}), 7)
  S.push(reset, S.make_sample(3600, { x = 20 }, {}, {}), 7)
  check(S.rate(reset, "prod", "x") == 0, "compteur qui baisse : débit 0, jamais négatif")
  check(S.rate({}, "prod", "x") == nil and S.rate_scalar({}, "mined") == nil, "anneau vide")
  local same = {}
  S.push(same, S.make_sample(0, { x = 1 }, {}, {}), 7)
  check(S.rate_scalar(same, "mined") == nil, "un relevé : pas de débit scalaire")
  check(S.span({}) == 0 and S.span(same) == 0 and S.span(r) == 5400, "durée couverte", S.span(r))

  ---------------------------------------------------------------------------------------------------
  -- Tableau des flux
  ---------------------------------------------------------------------------------------------------
  local fr = {}
  S.push(fr, S.make_sample(0, { a = 0.5, b = 100, c = 100, d = 7, f = 1000 }, {}, {}), 7)
  S.push(fr, S.make_sample(3600, { a = 10, b = 400, c = 700, d = 7, e = 50, f = 1000 }, {}, {}), 7)
  local rows = S.flows(fr, "prod", 10)
  local names = {}
  for _, row in ipairs(rows) do names[#names + 1] = row.name end
  -- débits : c 600, b 300, a 9,5, f 0 (cumul 1000), d 0 (cumul 7) ; e sans débit (apparu au dernier relevé) en dernier
  check(table.concat(names, ",") == "c,b,a,f,d,e", "flux triés par débit, débit inconnu en dernier", table.concat(names, ","))
  check(rows[1].total == 700 and near(rows[1].rate, 600) and rows[6].rate == nil, "flux : cumul et débit")
  check(#S.flows(fr, "prod", 2) == 2 and #S.flows({}, "prod", 2) == 0, "flux : n premiers, anneau vide")
  local tie = {}
  S.push(tie, S.make_sample(0, { m = 0.001, k = 0.001 }, {}, {}), 7)
  S.push(tie, S.make_sample(3600, { m = 10, k = 10 }, {}, {}), 7)
  local tr = S.flows(tie, "prod", 5)
  check(tr[1].name == "k" and tr[2].name == "m", "flux : égalité départagée par la clé")

  ---------------------------------------------------------------------------------------------------
  -- PNJ : décompte des tâches
  ---------------------------------------------------------------------------------------------------
  local npcs = { { task = "mine", resource = "r1" }, { task = "mine", resource = "r2" }, { task = "mine", resource = "r1" },
    { task = "craft" }, {}, {}, { task = "smelt" }, { task = "craft", resource = "r9" } }
  local tc = S.task_counts(npcs, 10)
  local by = {}
  for _, e in ipairs(tc.list) do by[e.key] = e.n end
  check(tc.total == 10, "décompte : la somme vaut l'effectif vivant", tc.total)
  check(by.mine == 3 and by.craft == 2 and by.smelt == 1 and by.idle == 2 and by.norole == 2, "décompte par tâche")
  check(tc.list[1].key == "mine" and tc.list[2].key == "craft" and tc.list[3].key == "idle" and tc.list[4].key == "norole",
    "décompte trié : décroissant, égalités par clé (" .. tc.list[1].key .. "," .. tc.list[2].key .. "," .. tc.list[3].key .. ")")
  check(#tc.mining == 2 and tc.mining[1].key == "r1" and tc.mining[1].n == 2 and tc.mining[2].key == "r2",
    "ressources visées par le minage")
  local tc0 = S.task_counts({}, 0)
  check(tc0.total == 0 and #tc0.list == 0 and #tc0.mining == 0, "équipe vide")
  local tc1 = S.task_counts({ { task = "mine" } }, nil)
  check(tc1.total == 1 and #tc1.mining == 0, "alive absent : effectif = PNJ listés ; minage sans ressource")
  local tc2 = S.task_counts({ { task = "a" }, { task = "b" } }, 1)
  check(tc2.total == 2, "plus de PNJ listés que d'effectif : aucun retrait", tc2.total)
  check(S.busy_pct(10, 3) == 70 and S.busy_pct(3, 1) == 67 and S.busy_pct(0, 0) == 0 and S.busy_pct(5, nil) == 100,
    "part au travail")

  ---------------------------------------------------------------------------------------------------
  -- Formats
  ---------------------------------------------------------------------------------------------------
  check(S.int(0) == "0" and S.int(999) == "999" and S.int(1234) == "1 234" and S.int(1234567) == "1 234 567"
    and S.int(-1234) == "-1 234" and S.int(12.6) == "13", "entiers")
  check(S.fmt_rate(nil) == "—" and S.fmt_rate(0) == "0,0" and S.fmt_rate(7.26) == "7,3" and S.fmt_rate(9.96) == "10,0"
    and S.fmt_rate(120.4) == "120" and S.fmt_rate(1234) == "1,2 k" and S.fmt_rate(2.5e6) == "2,5 M" and S.fmt_rate(-3) == "0,0",
    "débits", S.fmt_rate(9.96))
  check(S.fmt_total(0) == "0" and S.fmt_total(99999) == "99 999" and S.fmt_total(123456) == "123 k"
    and S.fmt_total(4500000) == "4,5 M" and S.fmt_total(nil) == "0", "cumuls")
  check(S.pct(0.374) == 37 and S.pct(0.375) == 38 and S.pct(-1) == 0 and S.pct(2) == 100 and S.pct(nil) == 0, "pourcentage")
  check(S.PERIOD <= 3600 and S.RING >= 3, "réglages : un relevé au moins par minute, trois relevés au moins")
  return ok_n, fail_n
end

print("== Modèle pur du panneau de statistiques")
local S0 = load_module(SOURCE)
local ok, fail = run_all(S0)

---------------------------------------------------------------------------------------------------
-- État borné : un anneau plein de 5 équipes ne dépasse pas ses bornes (contrôle en nombre d'entrées)
---------------------------------------------------------------------------------------------------
print("== État borné")
do
  local saved_n, saved_f = ok_n, fail_n
  local rings = {}
  for team = 1, 5 do
    local ring = {}
    for i = 1, 500 do -- 500 relevés avec des objets toujours nouveaux
      local prod, cons, hand = {}, {}, {}
      for j = 1, 80 do
        prod["p" .. j + i] = j * i
        cons["c" .. j + i] = j
        hand["h" .. j + i] = j
      end
      S0.push(ring, S0.make_sample(i * S0.PERIOD, prod, cons, hand, i, i), S0.RING)
    end
    rings[team] = ring
  end
  local entries = 0
  for _, ring in ipairs(rings) do
    entries = entries + #ring
    for _, s in ipairs(ring) do
      for _, f in ipairs({ "prod", "cons", "hand" }) do for _ in pairs(s[f]) do entries = entries + 1 end end
    end
  end
  local bound = 5 * S0.RING * (1 + S0.KEEP.prod + S0.KEEP.cons + S0.KEEP.hand)
  check(entries <= bound, "5 équipes, 500 relevés : entrées <= " .. bound, entries)
  -- ~ 30 octets par entrée sérialisée : l'état reste très en dessous de 50 Ko
  check(entries * 30 < 50 * 1024, "état estimé < 50 Ko", entries * 30)
  ok_n, fail_n = ok_n, fail_n
  ok = ok + (ok_n - saved_n)
  fail = fail + (fail_n - saved_f)
end

---------------------------------------------------------------------------------------------------
-- Aucun nom d'objet du jeu dans le modèle ; l'onglet n'en nomme aucun non plus
---------------------------------------------------------------------------------------------------
print("== Aucun nom d'objet en dur")
do
  local function code_only(path)
    local s = read_file(path)
    s = s:gsub("%-%-%[%[.-%]%]", "")          -- commentaires longs
    s = s:gsub("%-%-[^\n]*", "")              -- commentaires de ligne
    return s
  end
  local banned = { "iron", "copper", "coal", "stone", "plate", "ore", "gear", "circuit", "wood", "steel", "oil", "science" }
  for _, path in ipairs({ "shared/gui/stats.lua", "script/gui/ia1i_stats.lua", "script/gui/partie.lua" }) do
    local src = code_only(path)
    local hit
    for lit in src:gmatch('"([^"\n]*)"') do
      for _, b in ipairs(banned) do
        if lit:find(b, 1, true) and not lit:find("^fo%-") and not lit:find("^script%.") and not lit:find("^shared%.") then
          hit = hit or lit
        end
      end
    end
    check(hit == nil, "aucun nom d'objet du jeu dans " .. path, hit)
  end
end

---------------------------------------------------------------------------------------------------
-- Traductions : chaque clé « fo-panel.* » utilisée existe en français et en anglais, mêmes clés des deux côtés
---------------------------------------------------------------------------------------------------
print("== Traductions")
do
  local function keys_of(path)
    local out, section = {}, nil
    for line in read_file(path):gmatch("[^\r\n]+") do
      local sec = line:match("^%[(.-)%]$")
      if sec then
        section = sec
      else
        local k = line:match("^([%w%-_%.]+)=")
        if k and section then out[section .. "." .. k] = true end
      end
    end
    return out
  end
  local fr, en = keys_of("locale/fr/panel.cfg"), keys_of("locale/en/panel.cfg")
  local missing_en, missing_fr = {}, {}
  for k in pairs(fr) do if not en[k] then missing_en[#missing_en + 1] = k end end
  for k in pairs(en) do if not fr[k] then missing_fr[#missing_fr + 1] = k end end
  table.sort(missing_en); table.sort(missing_fr)
  check(#missing_en == 0 and #missing_fr == 0, "mêmes clés en FR et en EN",
    "manque en EN : " .. table.concat(missing_en, ",") .. " ; manque en FR : " .. table.concat(missing_fr, ","))
  local used = {}
  for _, path in ipairs({ "script/gui/partie.lua", "script/gui/team_window.lua" }) do
    for k in read_file(path):gmatch('"(fo%-panel%.[%w%-_]+)"') do used[k] = true end
  end
  -- clés construites : fo-panel.col-<k>, fo-panel.tip-<k>, fo-panel.team-player, fo-panel.task-<kind>
  for _, k in ipairs({ "team", "level", "tech", "outposts", "soldiers", "pnj", "kills", "lost", "att-out", "att-in" }) do
    used["fo-panel.col-" .. k], used["fo-panel.tip-" .. k] = true, true
  end
  for _, k in ipairs({ "idle", "norole", "ghost", "equiper", "centrale", "explore", "clear", "carry", "other" }) do used["fo-panel.task-" .. k] = true end
  used["fo-panel.col-rate-hand"] = true
  local absent = {}
  for k in pairs(used) do
    if not (fr[k] and en[k]) and k ~= "fo-panel.col-" and k ~= "fo-panel.tip-" and k ~= "fo-panel.task-" then absent[#absent + 1] = k end
  end
  table.sort(absent)
  check(#absent == 0, "chaque clé utilisée est traduite en FR et en EN", table.concat(absent, ","))
  check(fr["fo-ia1i.tab-partie"] and en["fo-ia1i.tab-partie"], "onglet : légende FR et EN")
end

---------------------------------------------------------------------------------------------------
-- Mutants : chacun fausse une règle ; le banc doit le refuser
---------------------------------------------------------------------------------------------------
local function mutant(label, from, to)
  local src, n = SOURCE:gsub(from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (to:gsub("%%", "%%%%")), 1)
  if n ~= 1 then return false, label .. " (motif introuvable)" end
  local okl, M = pcall(load_module, src)
  if not okl then return false, label .. " (ne compile pas)" end
  local saved = print
  print = function() end
  local okc, _, f = pcall(run_all, M)
  print = saved
  if not okc then return true, label .. " (plantage)" end
  return f > 0, label
end
local mutants = {
  { "tri du top croissant", "if a.v ~= b.v then return a.v > b.v end\n    return a.name < b.name", "if a.v ~= b.v then return a.v < b.v end\n    return a.name < b.name" },
  { "top garde les zéros", "if type(v) == \"number\" and v > 0 then list", "if type(v) == \"number\" and v >= 0 then list" },
  { "égalités du top par clé décroissante", "return a.name < b.name\n  end)\n  while #list > n", "return a.name > b.name\n  end)\n  while #list > n" },
  { "anneau non borné", "while #ring > (max or M.RING) do table.remove(ring, 1) end", "" },
  { "anneau retire le plus récent", "while #ring > (max or M.RING) do table.remove(ring, 1) end", "while #ring > (max or M.RING) do table.remove(ring) end" },
  { "même tick : doublon gardé", "if last and last.tick == sample.tick then", "if false then" },
  { "débit par seconde au lieu de par minute", "return d * M.TICKS_PER_MIN / dt\n    end\n  end\n  return nil", "return d * 60 / dt\n    end\n  end\n  return nil" },
  { "débit négatif toléré", "      if d < 0 then d = 0 end\n      return d * M.TICKS_PER_MIN / dt", "      return d * M.TICKS_PER_MIN / dt" },
  { "débit depuis le dernier relevé seulement", "for i = 1, #ring - 1 do", "for i = #ring - 1, #ring - 1 do" },
  { "débit scalaire sans durée", "local d = (last[field] or 0) - (first[field] or 0)\n  if d < 0 then d = 0 end\n  return d * M.TICKS_PER_MIN / dt",
    "local d = (last[field] or 0) - (first[field] or 0)\n  if d < 0 then d = 0 end\n  return d" },
  { "débit inconnu trié en tête", "if (ra ~= nil) ~= (rb ~= nil) then return ra ~= nil end", "if (ra ~= nil) ~= (rb ~= nil) then return ra == nil end" },
  { "flux triés par cumul", "if ra and ra ~= rb then return ra > rb end", "if false then return ra > rb end" },
  { "relevé non borné", "prod = M.trim(prod, M.KEEP.prod, hot and hot.prod)", "prod = prod or {}" },
  { "relevé sans les objets qui grandissent", "    for _, e in ipairs(M.top(live, n)) do out[e.name] = counts[e.name] end", "" },
  { "relevé garde les plus petits", "table.sort(list, function(a, b)\n    if a.v ~= b.v then return a.v > b.v end", "table.sort(list, function(a, b)\n    if a.v ~= b.v then return a.v < b.v end" },
  { "PNJ sans rôle oubliés", "if extra > 0 then by.norole = extra end", "" },
  { "PNJ sans tâche comptés ailleurs", "local k = n.task or \"idle\"", "local k = n.task or \"none\"" },
  { "ressource de minage comptée pour toute tâche", "if n.task == \"mine\" and n.resource then", "if n.resource then" },
  { "part au travail inversée", "return math.floor(100 * (n - (idle or 0)) / n + 0.5)", "return math.floor(100 * (idle or 0) / n + 0.5)" },
  { "point décimal", "local function comma(s) return (s:gsub(\"%.\", \",\")) end", "local function comma(s) return s end" },
  { "pourcentage non borné", "if p > 100 then return 100 end", "" },
  { "période de relevé de 10 min", "M.PERIOD = 1800", "M.PERIOD = 36000" },
}
local refused = 0
for _, m in ipairs(mutants) do
  local caught, label = mutant(m[1], m[2], m[3])
  if caught then refused = refused + 1 else print("MUTANT NON REFUSE : " .. label) end
end
print(string.format("  mutants refusés : %d / %d", refused, #mutants))

local total_fail = fail + (#mutants - refused)
print(string.format("BILAN : %d OK, %d ECHEC(S)", ok, total_fail))
os.exit(total_fail == 0 and 0 or 1)
