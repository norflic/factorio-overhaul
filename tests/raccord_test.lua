--[[
  Lot PD-ELEC (D05) : test hors jeu de la couverture électrique (shared/team/raccord.lua) et du branchement (script/team/raccord.lua,
  script/team/build.lua, lus comme texte).
    §1 classement d'une machine ; §2 groupes (clé stable d'une île, un groupe par partie sans réseau, boîtes) ; §3 table de décision ;
    §4 paire de bouts (plus courte, départages, distance max) ; §5 anneau du poteau neuf ; §6 portée de chaîne ; §7 déterminisme
    (ordre des observations) ; §8 aucun nom d'objet dans la règle ; §9 branchement (dispatch du plan, appel par passe, état sans
    fonction ni entité) ; §10 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/raccord_test.lua   (depuis la racine du mod)
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
local SRC = read("shared/team/raccord.lua")
local function load_r(src)
  local fn, err = load(src, "=raccord", "t")
  assert(fn, err)
  return fn()
end
local R = load_r(SRC)

-- §1 classement
local live = function(id) return id == 1 end
check(R.classify(1, live, true) == "ok", "1.1 reseau alimente : ok")
check(R.classify(2, live, true) == "ile", "1.2 reseau sans generatrice : ile")
check(R.classify(nil, live, true) == "sans_reseau", "1.3 sous aucun poteau : sans_reseau")
check(R.classify(nil, live, false) == "ok", "1.4 machine a combustible : ok")

-- §2 groupes
local function ob(pid, part, net, x, y, kind)
  return { pid = pid, part = part, net = net, x = x, y = y, kind = kind or (net and "ile" or "sans_reseau"), box = { x - 1.5, y - 1.5, x + 1.5, y + 1.5 } }
end
local obs = { ob(7, 1, 42, 10, 10), ob(3, 1, 42, 20, 5), ob(9, 2, nil, 50, 50), ob(9, 2, nil, 45, 52), ob(9, 3, nil, 70, 70), ob(5, 1, 43, 0, 0) }
local gs = R.groups(obs)
check(#gs == 4, "2.1 quatre groupes (deux iles, deux parties sans reseau) : " .. #gs)
local by = {}
for _, g in ipairs(gs) do by[g.key] = g end
check(by.i3 ~= nil and by.i3.n == 2, "2.2 ile du reseau 42 : cle du plus petit projet (i3), 2 machines")
check(by.i3 and by.i3.pids[1] == 3 and by.i3.pids[2] == 7, "2.3 projets de l'ile tries")
check(by.i3 and by.i3.x == 20 and by.i3.y == 5, "2.4 machine la plus au nord-ouest (y puis x)")
check(by.i3 and by.i3.box[1] == 8.5 and by.i3.box[4] == 11.5, "2.5 boite englobante")
check(by.i5 ~= nil and by.i5.n == 1, "2.6 autre reseau, autre ile")
check(by["u9:2"] ~= nil and by["u9:2"].n == 2 and by["u9:3"] ~= nil, "2.7 un groupe par partie sans reseau")
check(by["u9:2"] and by["u9:2"].mbox[1] == 48.5, "2.8 boite de la machine du poteau neuf (la plus au nord)")
for i = 2, #gs do check(gs[i - 1].key < gs[i].key, "2.9 groupes tries par cle") end

-- §3 décision
local function inp(t)
  local base = { has_live = true, lost = 0, pending = 0, open = false, open_total = 0, seen = R.CONFIRM, tries = 0, enemies = 0 }
  for k, v in pairs(t or {}) do base[k] = v end
  return base
end
check(R.decide(inp()) == "relier", "3.1 cas nominal : relier")
check(R.decide(inp({ has_live = false })) == "attendre", "3.2 sans reseau alimente : attendre")
check(R.decide(inp({ lost = 1 })) == "laisser", "3.3 poteau perdu : laisser a [FO-RESEAU]")
check(R.decide(inp({ open = true })) == "attendre", "3.4 raccordement deja ouvert : attendre")
check(R.decide(inp({ pending = 2 })) == "attendre", "3.5 chantier voisin : attendre")
check(R.decide(inp({ seen = R.CONFIRM - 1 })) == "attendre", "3.6 pas confirme : attendre")
check(R.decide(inp({ tries = R.MAX_TRIES })) == "laisser", "3.7 essais epuises : laisser")
check(R.decide(inp({ enemies = 1 })) == "attendre", "3.8 ennemi : attendre")
check(R.decide(inp({ open_total = R.MAX_OPEN })) == "attendre", "3.9 plafond des raccordements ouverts : attendre")
check(R.decide(inp({ lost = 1, has_live = false })) == "attendre", "3.10 la centrale d'abord, avant le poteau perdu")
check(R.decide(inp({ tries = R.MAX_TRIES, since_try = R.RETRY_AFTER - 1 })) == "laisser", "3.11 essais epuises, dernier essai recent : laisser")
check(R.decide(inp({ tries = R.MAX_TRIES, since_try = R.RETRY_AFTER })) == "relier", "3.12 essais epuises depuis R.RETRY_AFTER : un essai de plus (jamais abandonne pour toujours)")

check(R.decide(inp({ lost = 1, waited_lost = R.WAIT_LOST - 1 })) == "laisser", "3.13 poteau perdu, attente pas epuisee : laisser")
check(R.decide(inp({ lost = 1, waited_lost = R.WAIT_LOST })) == "relier", "3.14 poteau perdu, attente epuisee (R.WAIT_LOST) : decide comme sans perte")
check(R.decide(inp({ lost = 1, has_live = false, waited_lost = R.WAIT_LOST })) == "attendre", "3.15 attente epuisee mais pas de reseau alimente : attendre")
check(R.decide(inp({ lost = 2, waited_lost = R.WAIT_LOST, enemies = 1 })) == "attendre", "3.16 attente epuisee : les autres portes restent (ennemi)")
check(R.MAX_OPEN == 4, "3.17 R.MAX_OPEN = 4")

-- §3 bis fenetre tournante (lot COURANT2)
do
  local w, nr = R.window(4, 0, 6)
  check(#w == 4 and w[1] == 1 and w[4] == 4 and nr == 0, "3b.1 jusqu'a max groupes : tous, dans l'ordre, depart remis a 0")
  w, nr = R.window(6, 3, 6)
  check(#w == 6 and w[1] == 1 and nr == 0, "3b.2 exactement max groupes : tous, depart remis a 0")
  w, nr = R.window(8, 0, 6)
  check(#w == 6 and w[1] == 1 and w[6] == 6 and nr == 6, "3b.3 8 groupes, depart 0 : 1 a 6, puis depart 6")
  w, nr = R.window(8, nr, 6)
  check(#w == 6 and w[1] == 7 and w[2] == 8 and w[3] == 1 and w[6] == 4 and nr == 4, "3b.4 puis 7, 8, 1, 2, 3, 4 (fenetre qui boucle), depart 4")
  local covered = {}
  local rot = 0
  for _ = 1, 4 do
    local ww
    ww, rot = R.window(13, rot, 6)
    for _, i in ipairs(ww) do covered[i] = true end
  end
  local n = 0
  for _ in pairs(covered) do n = n + 1 end
  check(n == 13, "3b.5 13 groupes : tous decides en 3 releves (" .. n .. ")")
  w = R.window(8, 8 * 5 + 3, 6)
  check(w[1] == 4, "3b.6 depart modulo le nombre de groupes (le nombre de groupes change d'un releve a l'autre)")
  w = R.window(8, nil, 6)
  check(w[1] == 1, "3b.7 depart absent (sauvegarde existante) : 0")
end

-- §4 paire de bouts
local s, t, d = R.best_pair({ { x = 0, y = 0 }, { x = 10, y = 0 } }, { { x = 30, y = 0 }, { x = 0, y = 40 } }, 100)
check(s and s.x == 10 and t.x == 30 and math.abs(d - 20) < 1e-9, "4.1 paire la plus courte")
check(R.best_pair({ { x = 0, y = 0 } }, { { x = 200, y = 0 } }, 160) == nil, "4.2 au-dela de la distance max : rien")
local s2, t2 = R.best_pair({ { x = 0, y = 0 } }, { { x = 5, y = 0 }, { x = -5, y = 0 }, { x = 0, y = -5 } }, 100)
check(t2 and t2.x == 0 and t2.y == -5, "4.3 ex aequo : cible la plus au nord")
local s3 = R.best_pair({ { x = 5, y = 1 }, { x = -5, y = 1 } }, { { x = 0, y = 1 } }, 100)
check(s3 and s3.x == -5, "4.4 ex aequo : depart le plus a l'ouest")

-- §5 anneau
local ring = R.ring_tiles({ 10, 10, 13, 13 }, { x = 30, y = 11.5 })
check(#ring == 16, "5.1 anneau d'une machine 3 x 3 : 16 tuiles (" .. #ring .. ")")
check(ring[1].x == 13.5 and ring[1].y == 11.5, "5.2 premiere tuile : cote de la cible")
local inside = false
for _, c in ipairs(ring) do if c.x > 10 and c.x < 13 and c.y > 10 and c.y < 13 then inside = true end end
check(not inside, "5.3 aucune tuile sous la machine")
-- Lot POTEAUX (F560, banc etape1-guide graine 2507543475, 52 min) : 4 foreuses d'une bande finie sous aucun poteau, longees par le
-- couloir d'acces (2 tuiles) ; l'anneau d'UNE tuile etait tout entier sur la bande ou le couloir : 3 refus « aucune place libre », pour
-- toujours. L'anneau va jusqu'a la distance d'alimentation du poteau pose (prototype, supply_area_distance) : au-dela du couloir.
local function covers(c, box, supply)
  return c.x + supply > box[1] and c.x - supply < box[3] and c.y + supply > box[2] and c.y - supply < box[4]
end
local box = { 10, 10, 13, 13 }
local deep = R.ring_tiles(box, { x = 30, y = 11.5 }, 3.5)
local d3, d4, all_cover = false, false, true
for _, c in ipairs(deep) do
  if c.x == 7.5 and c.y == 11.5 then d3 = true end
  if c.x == 6.5 then d4 = true end
  if not covers(c, box, 3.5) then all_cover = false end
  if c.x > 10 and c.x < 13 and c.y > 10 and c.y < 13 then all_cover = false end
end
check(d3, "5.4 poteau d'alimentation 3,5 : tuile a 3 de la machine candidate (au-dela d'un couloir de 2)")
check(not d4 and all_cover, "5.5 toute tuile candidate alimente la machine (aucune a 4 tuiles, aucune dessous)")
local small = R.ring_tiles(box, { x = 30, y = 11.5 }, 2.5)
local s2, s3 = false, false
for _, c in ipairs(small) do
  if c.x == 8.5 then s2 = true end
  if c.x == 7.5 then s3 = true end
end
check(s2 and not s3, "5.6 poteau d'alimentation 2,5 : 2 tuiles au plus")
check(#R.ring_tiles(box, { x = 30, y = 11.5 }, 0.5) == 16, "5.7 alimentation 0,5 : l'anneau d'une tuile (16)")
check(deep[1].x == 15.5 and deep[1].y == 11.5, "5.8 la tuile la plus proche de la cible passe devant (chaine plus courte)")

-- §6 portée
check(R.chain_reach(9, 30, 9) == 9, "6.1 la plus courte des trois portees")
check(R.chain_reach(nil, 30, 9) == 9, "6.2 depart neuf : portee du poteau neuf")
check(R.chain_reach(30, 7.5, 9) == 7.5, "6.3 cible plus courte")

-- §7 déterminisme : l'ordre des observations ne change rien
local rev = {}
for i = #obs, 1, -1 do rev[#rev + 1] = obs[i] end
local gr = R.groups(rev)
local same = #gr == #gs
for i = 1, math.min(#gr, #gs) do
  local a, b = gr[i], gs[i]
  if a.key ~= b.key or a.n ~= b.n or a.x ~= b.x or a.y ~= b.y or table.concat(a.pids, ",") ~= table.concat(b.pids, ",") then same = false end
end
check(same, "7.1 groupes identiques quel que soit l'ordre du releve")

-- §8 aucun nom d'objet, aucun pairs dans la règle
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find("electric%-pole") and not code:find("assembling") and not code:find("medium") and not code:find("big%-"),
  "8.1 aucun nom d'objet dans shared/team/raccord.lua")
check(not code:find("[^i]pairs%("), "8.2 aucun pairs dans la regle")

-- §9 branchement
local BUILD = read("script/team/build.lua")
local SCRIPT = read("script/team/raccord.lua")
check(BUILD:find('if spec.raccord then return plan_raccord%(f, surface, p%) end') ~= nil, "9.1 plan_project renvoie au plan du raccordement")
check(BUILD:find("Raccord%.step%(") ~= nil, "9.2 pulse_team appelle Raccord.step")
check(BUILD:find('require%("script%.team%.raccord"%)') ~= nil, "9.3 require au chargement (jamais en evenement)")
check(not SCRIPT:find("global"), "9.4 global jamais nomme dans script/team/raccord.lua")
check(SCRIPT:find("%[FO%-RACCORD%]") ~= nil and BUILD:find("%[FO%-RACCORD%]") ~= nil, "9.5 journal [FO-RACCORD]")
-- l'état b.raccord ne garde ni fonction ni entité : les entités (ent =) ne vivent que dans ends_of (locales)
local spec_block = SCRIPT:match("local spec = (%b{})")
check(spec_block ~= nil and not spec_block:find("ent"), "9.6 la demande ne porte aucune entite")
check(BUILD:find("p%.counted = true %-%- un raccordement n'est pas un module") ~= nil, "9.7 un raccordement n'est pas compte comme module")
check(SCRIPT:find("R%.ring_tiles%(g%.mbox, t, proto and proto%.supply_area_distance") ~= nil,
  "9.8 l'anneau du poteau neuf lit la distance d'alimentation du prototype pose")

-- §10 mutants
local function mutant(name, from, to, probe)
  local src = SRC:gsub(from, to, 1)
  if src == SRC then check(false, "mutant " .. name .. " : motif introuvable") return end
  local okl, Rm = pcall(load_r, src)
  if not okl then check(true, "mutant " .. name .. " (ne se charge pas)") return end
  local okp, seen = pcall(probe, Rm)
  check(not okp or seen, "mutant " .. name .. " vu")
end
mutant("perdu ignore", 'if %(inp%.lost or 0%) > 0 and %(inp%.waited_lost or 0%) < R%.WAIT_LOST then', 'if false then',
  function(Rm) return Rm.decide(inp({ lost = 1 })) ~= "laisser" end)
mutant("sans confirmation", "if %(inp%.seen or 0%) < R%.CONFIRM", "if false",
  function(Rm) return Rm.decide(inp({ seen = 0 })) == "relier" end)
mutant("essais sans plafond", "if %(inp%.tries or 0%) >= R%.MAX_TRIES", "if false",
  function(Rm) return Rm.decide(inp({ tries = 99 })) == "relier" end)
mutant("ennemi ignore", "if %(inp%.enemies or 0%) > 0", "if false",
  function(Rm) return Rm.decide(inp({ enemies = 1 })) == "relier" end)
mutant("chantier ignore", "if %(inp%.pending or 0%) > 0", "if false",
  function(Rm) return Rm.decide(inp({ pending = 1 })) == "relier" end)
mutant("ile = sans reseau", 'if net == nil then return "sans_reseau" end', 'if true then return "sans_reseau" end',
  function(Rm) return Rm.classify(2, live, true) ~= "ile" end)
mutant("cle d'ile instable", 'key = "i" %.%. min_pid%[o%.net%]', 'key = "i" .. o.pid',
  function(Rm) return #Rm.groups(obs) ~= 4 end)
mutant("paire sans distance max", "if d2 <= lim then", "if true then",
  function(Rm) return Rm.best_pair({ { x = 0, y = 0 } }, { { x = 200, y = 0 } }, 160) ~= nil end)
mutant("portee du depart oubliee", "return math%.min%(start_reach or new_reach, ", "return math.min(new_reach, ",
  function(Rm) return Rm.chain_reach(5, 30, 9) ~= 5 end)
mutant("attente derriere un poteau perdu sans borne", 'if %(inp%.lost or 0%) > 0 and %(inp%.waited_lost or 0%) < R%.WAIT_LOST then', 'if (inp.lost or 0) > 0 then',
  function(Rm) return Rm.decide(inp({ lost = 1, waited_lost = Rm.WAIT_LOST })) == "laisser" end)
mutant("anneau d'une tuile seulement", "local depth = math%.max%(1, math%.ceil%(%(supply or 0%) %+ 0%.5%) %- 1%)", "local depth = 1",
  function(Rm) for _, c in ipairs(Rm.ring_tiles({ 10, 10, 13, 13 }, { x = 30, y = 11.5 }, 3.5)) do if c.x == 7.5 then return false end end return true end)
mutant("anneau trop large", "local depth = math%.max%(1, math%.ceil%(%(supply or 0%) %+ 0%.5%) %- 1%)", "local depth = math.max(1, math.ceil((supply or 0) + 0.5))",
  function(Rm) for _, c in ipairs(Rm.ring_tiles({ 10, 10, 13, 13 }, { x = 30, y = 11.5 }, 3.5)) do if c.x == 6.5 then return true end end return false end)
mutant("fenetre qui ne tourne pas", 'return idxs, %(start %+ max%) %% n', 'return idxs, 0',
  function(Rm) local _, nr = Rm.window(8, 0, 6); return nr == 0 end)
mutant("fenetre sans retour au debut", '%(start %+ i%) %% n %+ 1', 'math.min(start + i + 1, n)',
  function(Rm) local w = Rm.window(8, 6, 6); return w[3] ~= 1 end)
mutant("fenetre ignorant le depart", 'local start = %(rot or 0%) %% n', 'local start = 0',
  function(Rm) local w = Rm.window(8, 6, 6); return w[1] == 1 end)

print(string.format("[RACCORD] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
