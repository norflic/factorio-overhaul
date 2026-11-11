-- Lot CC-MATIERES (F520) : une ligne de rapatriement en réserve voit ses objets manquants devenir des buts du cerveau.
-- Banc CC-ROUTE-VERIF (graine 1618033988, 45 min) : lignes 11 et 12 planifiées à 25 min, « reserve:materiaux », 0 entité bâtie sur 101 :
-- p.missing écrit par la réserve (script/team/build.lua) n'était lu par aucun but ; les lignes de bande et de migration ont le même câblage
-- (script/ai3/automatisation.lua), pas les lignes de rapatriement (classe A3).
-- Règle pure : shared/team/rapatriement.lua (Rp.open_lines) ; but : shared/ai3/automatiser.lua (A.goals) ; câblage lu sur le texte réel.
package.path = "./?.lua;" .. package.path
local Rp = require("shared.team.rapatriement")
local A = require("shared.ai3.automatiser")

local ok, bad = 0, 0
local function check(name, cond)
  if cond then ok = ok + 1 else bad = bad + 1 print("ECHEC : " .. name) end
end

local function read(path)
  local fh = io.open(path, "rb")
  if not fh then return "" end
  local s = fh:read("*a")
  fh:close()
  return s
end

-- Scène : l'état du banc à 35 min (deux lignes en réserve, une finie, une refusée, une abandonnée, une sans projet).
local function scene()
  local lines = {
    ["3:o3"] = { pid = 12, done = false },
    ["3:o2"] = { pid = 11, done = false },
    ["3:o1"] = { pid = 9, done = true },
    ["3:o5"] = { pid = 25, done = false },
    ["3:o6"] = { pid = 30, done = false },
    ["3:o7"] = { pid = 99, done = false },
    ["3:o8"] = { pid = 40, done = true },
  }
  local projects = {
    [11] = { state = "reserve", spec = { pile = "capital" } },
    [12] = { state = "reserve", spec = { pile = "capital" } },
    [9] = { state = "fini", spec = { pile = "capital" } },
    [25] = { state = "refuse", spec = { pile = "capital" } },
    [30] = { state = "reserve", abandoned = true, spec = { pile = "capital" } },
    [40] = { state = "chantier", spec = { pile = "capital" } }, -- ligne finie puis rouverte (reconstruction) : servie ailleurs
  }
  return lines, projects
end

-- Contrôles de la règle (appliqués à la vraie règle et aux mutants).
local function rule_checks(fn)
  local fails = {}
  local function c(name, cond) if not cond then fails[#fails + 1] = name end end
  if type(fn) ~= "function" then return { "regle absente" } end
  local lines, projects = scene()
  local out = fn(lines, projects) or {}
  c("deux lignes ouvertes", #out == 2)
  c("ordre par cle (3:o2 puis 3:o3)", out[1] and out[1].key == "3:o2" and out[2] and out[2].key == "3:o3")
  c("pid de la ligne", out[1] and out[1].pid == 11 and out[2] and out[2].pid == 12)
  c("famille de la pile lue au projet", out[1] and out[1].pile == "capital")
  local seen = {}
  for _, l in ipairs(out) do seen[l.pid] = true end
  c("ligne finie exclue", not seen[9])
  c("ligne refusee exclue", not seen[25])
  c("ligne abandonnee exclue", not seen[30])
  c("ligne sans projet exclue", not seen[99])
  c("ligne deja finie (done) exclue", not seen[40])
  local empty = fn(nil, nil) or {}
  c("sans etat : liste vide", #empty == 0)
  return fails
end

-- 1. La vraie règle.
local f1 = rule_checks(Rp.open_lines)
check("regle : " .. table.concat(f1, ", "), #f1 == 0)
local a, b = scene()
local o1, o2 = Rp.open_lines(a, b), Rp.open_lines(a, b)
check("deux appels identiques", #o1 == #o2 and o1[1] and o2[1] and o1[1].key == o2[1].key)

-- 2. Mutants de la règle : chacun doit échouer à au moins un contrôle.
local function mutant(skip)
  return function(lines, projects)
    local keys = {}
    for k in next, lines or {} do keys[#keys + 1] = k end
    table.sort(keys)
    if skip == "ordre" then -- ordre inverse (déterministe)
      local r = {}
      for i = #keys, 1, -1 do r[#r + 1] = keys[i] end
      keys = r
    end
    local out = {}
    for _, k in ipairs(keys) do
      local l = lines[k]
      local q = l and projects and projects[l.pid]
      local open = q ~= nil
      if skip ~= "done" then open = open and not l.done end
      if skip ~= "fini" then open = open and q.state ~= "fini" end
      if skip ~= "refuse" then open = open and q.state ~= "refuse" end
      if skip ~= "abandon" then open = open and not q.abandoned end
      if open then out[#out + 1] = { key = k, pid = l.pid, pile = skip ~= "pile" and q.spec.pile or nil } end
    end
    return out
  end
end
local nmut, killed = 0, 0
for _, m in ipairs({ "done", "refuse", "abandon", "pile", "ordre" }) do
  nmut = nmut + 1
  local fm = rule_checks(mutant(m))
  if #fm > 0 then killed = killed + 1 else print("MUTANT VIVANT : " .. m) end
end
-- mutant « fini » : la ligne finie est aussi marquée done dans la scène ; on la rouvre pour qu'il se voie
do
  nmut = nmut + 1
  local fm = mutant("fini")
  local lines, projects = scene()
  lines["3:o1"].done = false
  local out = fm(lines, projects)
  local seen = false
  for _, l in ipairs(out) do if l.pid == 9 then seen = true end end
  local real = Rp.open_lines(lines, projects)
  local seen_real = false
  for _, l in ipairs(real) do if l.pid == 9 then seen_real = true end end
  if seen and not seen_real then killed = killed + 1 else print("MUTANT VIVANT : fini") end
end

-- 3. Le but du cerveau : l'entrée posée par l'automatisation devient « auto:rapatriement » avec ses manques, but de fond.
local goals = A.goals({}, { mods = { { product = "rapatriement", state = "reserve", missing = { { "transport-belt", 96 }, { "inserter", 2 } },
  reason = "materiaux", gain = 0, pile = "capital", line = true } } }, nil, nil)
local g
for _, x in ipairs(goals) do if x.key == "auto:rapatriement" then g = x end end
check("but auto:rapatriement", g ~= nil)
check("ses manques", g and g.missing and g.missing[1] and g.missing[1][1] == "transport-belt" and g.missing[1][2] == 96)
check("famille de la pile portee", g and g.pile == "capital")
check("but de fond (ne prend pas de place parmi les K)", g and g.fond == true and g.invest == true)

-- 4. Câblage sur le texte réel.
local auto = read("script/ai3/automatisation.lua")
local rap = read("script/team/rapatriement.lua")
local function wiring_checks(auto_txt, rap_txt)
  local fails = {}
  local function c(name, cond) if not cond then fails[#fails + 1] = name end end
  local i = auto_txt:find("Build.Rapatriement.projects(f)", 1, true)
  c("automatisation lit les lignes de rapatriement", i ~= nil)
  local seg = i and auto_txt:sub(i, i + 700) or ""
  c("module ajoute avec ses manques", seg:find("missing = ps.missing", 1, true) ~= nil)
  c("ligne de fond", seg:find("line = true", 1, true) ~= nil)
  c("famille de la pile du projet", seg:find("pile = rp.pile", 1, true) ~= nil)
  c("produit rapatriement", seg:find("\"rapatriement\"", 1, true) ~= nil)
  c("Rap.projects lit Rp.open_lines", rap_txt:find("return Rp.open_lines(st.lines, b.projects)", 1, true) ~= nil)
  return fails
end
local fw = wiring_checks(auto, rap)
check("cablage : " .. table.concat(fw, ", "), #fw == 0)
for _, m in ipairs({ { "Build.Rapatriement.projects(f)", "Build.Rapatriement.none(f)" }, { "pile = rp.pile, line = true }", "pile = rp.pile, line = nil }" },
                    { "pile = rp.pile", "pile = nil" }, { "missing = ps.missing or {}, reason = ps.reason,\n        gain = 0, pile = rp.pile", "missing = {}, reason = ps.reason,\n        gain = 0, pile = rp.pile" } }) do
  nmut = nmut + 1
  local s, n = auto:gsub(m[1]:gsub("%p", "%%%0"), (m[2]:gsub("%%", "%%%%")), 1)
  if n == 1 and #wiring_checks(s, rap) > 0 then killed = killed + 1 else print("MUTANT VIVANT : " .. m[1]) end
end
check(string.format("mutants refuses %d sur %d", killed, nmut), killed == nmut)

print(string.format("[CC-MATIERES] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", ok, bad, killed, nmut))
os.exit(bad == 0 and 0 or 1)
