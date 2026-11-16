--[[
  N102-BANDES (B3) : le balayage des cadres « sans projet de champ vivant » (Champ.report) passait entre le cadre figé et la demande de sa
  première bande, et libérait toutes les tuiles retenues par le lot CC-SAUT (F515). Rejeu des valeurs du journal (graine 271828182, archive
  fo-logs/2026-11-16_n100-panel-271, identique dans -271-fix) :
    26,9 min  [FO-CHAMP] player : avant-poste 1 : 1942 tuile(s) du cadre fige retenue(s) au plan (cadre:1 ...)
    27,3 min  [FO-CHAMP] player : cadre de l'avant-poste 1 sans projet de champ vivant : 1942 tuile(s) ... liberee(s)
              (même passe : cadre de l'avant-poste 2, 123 tuiles)
    27,3 min  [FO-MIGRATION] player : avant-poste 1 (iron) : bande -8 du champ demandee, projet 21   (0,25 s plus tard)
    53,0 min  bande 0 ecartee (bande vide : 29 foreuse(s) ..., 1re tuile prise (-49.0, 4.0), place du cadre figé, cote - : aucune entite
              visible, relevee « reserve ») ; puis bandes 8, 16, 24, 32 : 5 bandes sur 7 écartées
    34,6 -> 37,7 min : même chose pour le cadre:100002 (fer, 3 296 tuiles, 2 912 tuiles retenues) avant le projet 26 (38,1 min).
  Projets de champ vivants à 27,3 min (FO-CHAMP-VOIE) : 3, 7, 8, 12, 15, tous d'autres avant-postes (100001, ...).
  Lancement : lua5.2 tests/n102_bandes_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local quiet = false
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end

local function battery(Cd)
  local key = function(x, y) return x .. "," .. y end
  -- état du plan à 27,3 min : cadre:1 (fer du joueur) et cadre:2 retenus, un projet 9 d'une autre équipe d'avant
  local occ = { ["0,0"] = 9 }
  local t1, t2 = {}, {}
  for i = 1, 1942 do t1[#t1 + 1] = { -60 + (i % 40), 1000 + math.floor(i / 40) } end
  for i = 1, 123 do t2[#t2 + 1] = { 500 + i, 0 } end
  check(Cd.reserve(occ, t1, 1, key) == 1942 and Cd.reserve(occ, t2, 2, key) == 123, "rejeu : 1942 + 123 tuiles retenues (journal 26,0 et 26,9 min)")
  -- projets de champ à cet instant : aucun pour 1 ni 2 (le projet 21 vient 0,25 s plus tard)
  local fields = { { oid = 100001, state = "fini" }, { oid = 100001, state = "chantier" }, { oid = 100001, state = "reserve" }, { oid = 100003, state = "reserve" } }
  -- états de la migration : cadres 1 et 2 figés et tenus (bandes à demander), cadre 100004 rendu (ordre épuisé), 3 abandonné, 7 cible disparue
  local frames = {
    { oid = 1, frame = true, abandoned = false, target = true },
    { oid = 2, frame = true, abandoned = false, target = true },
    { oid = 3, frame = true, abandoned = true, target = true },
    { oid = 7, frame = true, abandoned = false, target = false },
    { oid = 100004, frame = false, abandoned = false, target = true },
  }
  local alive = Cd.alive(fields, frames)
  local dead = Cd.dead(Cd.owners(occ), alive)
  check(#dead == 0, "B3 : cadres 1 et 2 figés, première bande pas encore demandée : AUCUN libéré (vu : " .. table.concat(dead, ",") .. ")")
  check(occ["-59,1000"] == "cadre:1" and Cd.own(occ["-59,1000"], 1), "la place figée d'une colonne reste au cadre:1 (la bande 0 la retrouve à 53 min)")
  check(alive[1] and alive[2] and alive[100001] and alive[100003], "vivants : les deux cadres tenus et les avant-postes à projets")
  check(not alive[3] and not alive[7] and not alive[100004], "un cadre abandonné, rendu ou sans cible n'est pas vivant (pas de tuiles perdues, B7)")
  -- le balayage garde son rôle : cadre rendu par la migration et sans projet -> libéré
  local occ2 = {}
  Cd.reserve(occ2, { { 1, 1 }, { 2, 2 } }, 100004, key)
  local d2 = Cd.dead(Cd.owners(occ2), Cd.alive(fields, frames))
  check(#d2 == 1 and d2[1] == 100004 and Cd.clear(occ2, 100004) == 2, "cadre 100004 sans projet ni cadre tenu : libéré comme avant (12,0 min)")
  -- un projet refusé ne fait pas vivre son cadre
  local a3 = Cd.alive({ { oid = 5, state = "refuse" } }, {})
  check(not a3[5], "bande refusée seule : le cadre n'est pas vivant")
  check(next(Cd.alive(nil, nil)) == nil, "rien : aucun vivant")
  -- après la demande du projet 21 : vivant par le projet même si la migration rend le cadre
  local a4 = Cd.alive({ { oid = 1, state = "reserve" } }, { { oid = 1, frame = false, abandoned = false, target = true } })
  check(a4[1] == true, "projet 21 en réserve : le cadre:1 reste vivant")
end

local Cd0 = dofile("shared/team/champ_dedupe.lua")
battery(Cd0)

-- branchement (lecture du code) : Champ.report lit les cadres tenus par la migration
local src = read("script/team/champ.lua")
local ri = src:find("function Champ.report(f, surface, tick)", 1, true)
local rb = ri and src:sub(ri, ri + 2400) or ""
check(rb:find("for _, oid in ipairs(sorted_keys(ms and ms.o)) do", 1, true) ~= nil, "Champ.report parcourt les états de migration dans l'ordre trié")
check(rb:find("frame = st.frame ~= nil, abandoned = st.abandoned == true, target = Champ.target(f, oid) ~= nil", 1, true) ~= nil, "Champ.report : cadre tenu, abandon, cible")
check(rb:find("local alive = Cd.alive(fields, frames)", 1, true) ~= nil and rb:find("Cd.dead(Cd.owners(b.occ), alive)", 1, true) ~= nil, "Champ.report : Cd.alive puis Cd.dead")

local function load_with(path, from, to)
  local s = read(path)
  local a, b = s:find(from, 1, true)
  assert(a, "motif de mutant introuvable : " .. from)
  assert(not s:find(from, b + 1, true), "motif de mutant ambigu : " .. from)
  return assert(load(s:sub(1, a - 1) .. to .. s:sub(b + 1), "=" .. path))()
end
local function mutant(label, from, to)
  local Cd = load_with("shared/team/champ_dedupe.lua", from, to)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(battery, Cd)
  quiet = false
  local caught = failures > f0 or not ok
  passes, failures = p0, f0
  check(caught, "mutant refuse : " .. label)
end
-- mutant principal = l'ancien code (seuls les projets de champ font vivre un cadre)
mutant("ancien code : cadre figé tenu ignoré (libéré avant sa première bande)", "if s.frame and not s.abandoned and s.target then alive[s.oid] = true end", "")
mutant("cadre abandonné gardé", "if s.frame and not s.abandoned and s.target then", "if s.frame and s.target then")
mutant("cadre sans cible gardé", "if s.frame and not s.abandoned and s.target then", "if s.frame and not s.abandoned then")
mutant("cadre rendu gardé", "if s.frame and not s.abandoned and s.target then", "if not s.abandoned and s.target then")
mutant("projet refusé compté vivant", 'if q.state ~= "refuse" then alive[q.oid] = true end', "alive[q.oid] = true")

print(string.format("[N102-BANDES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
