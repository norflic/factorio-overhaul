--[[
  Lot COMBUSTIBLE-MIGRATION (suite, 9/11) : déduplication des pièces d'un projet de champ (shared/team/champ_dedupe.lua) et son branchement dans
  Build.SITES.champ (script/team/champ.lua). Défaut cherché : INTEG candidat 1d7c6218, projet 9 : 24 tapis et 4 poteaux du réseau du charbon écartés parce que
  leurs tuiles sont au plan du projet 11 (rien ne vérifiait ce que le projet 11 y pose).
  Lancement : lua5.2 tests/champ_dedupe_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local quiet = false
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end

local function battery(Cd)
  local belt = { name = "b", role = "champ-charbon", dir = 2 }
  check(Cd.same(belt, { name = "b", role = "champ-charbon", dir = 2 }) == true, "même nom, rôle, direction : doublon légitime")
  check(Cd.same(belt, { name = "b", role = "champ-charbon", dir = 4 }) == false, "autre direction : pas un doublon (le tronc irait de travers)")
  check(Cd.same(belt, { name = "b", role = "champ-tapis", dir = 2 }) == false, "autre rôle (tapis d'un autre flux) : pas un doublon")
  check(Cd.same(belt, { name = "u", role = "champ-charbon", dir = 2 }) == false, "autre nom : pas un doublon")
  check(Cd.same({ name = "p", role = "x" }, { name = "p", role = "x", dir = 0 }) == true, "direction absente = 0")
  check(Cd.same(belt, nil) == false, "aucune pièce chez le détenteur : pas un doublon")
  check(Cd.verdict(belt, {}) == "garder", "rien de pris : gardée")
  check(Cd.verdict(belt, { { pid = 11, ent = { name = "b", role = "champ-charbon", dir = 2 } } }) == "ecarter", "une tuile, doublon : écartée")
  check(Cd.verdict(belt, { { pid = 11, ent = { name = "b", role = "champ-charbon", dir = 2 } }, { pid = 11, ent = { name = "b", role = "champ-tapis", dir = 2 } } }) == "conflit",
    "deux tuiles dont une portée par un autre flux : conflit")
  check(Cd.verdict(belt, { { pid = 11, ent = nil } }) == "conflit", "tuile prise sans pièce chez le détenteur : conflit")
  -- réservation du tronc par le cadre
  check(Cd.marker(7) == "cadre:7" and Cd.own("cadre:7", 7) == true and Cd.own("cadre:7", 8) == false and Cd.own(12, 7) == false and Cd.own(nil, 7) == false, "marqueur du cadre : propre à son avant-poste")
  local occ = { ["1,1"] = 5, ["2,2"] = "cadre:9" }
  local key = function(x, y) return x .. "," .. y end
  check(Cd.reserve(occ, { { 1, 1 }, { 2, 2 }, { 3, 3 }, { 4, 4 } }, 7, key) == 2 and occ["3,3"] == "cadre:7" and occ["4,4"] == "cadre:7", "réservation : seules les tuiles libres sont retenues")
  check(occ["1,1"] == 5 and occ["2,2"] == "cadre:9", "réservation : une tuile d'un projet ou d'un autre cadre n'est jamais écrasée")
  check(Cd.clear(occ, 7) == 2 and occ["3,3"] == nil and occ["2,2"] == "cadre:9" and occ["1,1"] == 5, "cadre refait : ses tuiles seules sont libérées")
  check(Cd.clear(nil, 7) == 0, "occ absent : rien")
  local o2 = { a = "cadre:12", b = "cadre:3", c = 9, d = "cadre:3", e = "autre" }
  local ow = Cd.owners(o2)
  check(#ow == 2 and ow[1] == 3 and ow[2] == 12, "propriétaires de cadre triés, sans les projets ni les chaînes étrangères")
  local dd = Cd.dead(ow, { [12] = true })
  check(#dd == 1 and dd[1] == 3, "cadre sans projet vivant : à libérer (3), celui qui a un projet vivant (12) garde ses tuiles")
  check(#Cd.dead(ow, nil) == 2 and #Cd.dead({}, { [1] = true }) == 0, "aucun projet vivant : tous libérés ; aucun cadre : rien")
  check(Cd.cuts_trunk("conflit", true) == true and Cd.cuts_trunk("conflit", false) == false and Cd.cuts_trunk("ecarter", true) == false and Cd.cuts_trunk("garder", true) == false,
    "seul un conflit sur une pièce du réseau du charbon coupe le tronc")
  -- lot UPS-2 : prochain essai d'un plan qui attend son tronc (banc V0679-A : 1 781 plans en 5 min de jeu)
  check(Cd.next_try(1000, 1000, 18000, 600) == 1600, "attente commencée : prochain essai 600 ticks plus tard")
  check(Cd.next_try(18700, 1000, 18000, 600) == 19000, "fin d'attente proche : l'essai tombe au tick exact de la fin (t0 + attente)")
  check(Cd.next_try(19000, 1000, 18000, 600) == 19000, "au tick de la fin : essai à ce tick, jamais repoussé")
  check(Cd.next_try(25000, 1000, 18000, 600) == 25000, "attente dépassée : essai tout de suite (jamais dans le passé)")
  local n, tk = 0, 1000
  while tk < 19000 and n < 1000 do tk = Cd.next_try(tk, 1000, 18000, 600); n = n + 1 end -- (borne : un mutant « sans poll » ne boucle pas)
  check(n == 30 and tk == 19000, "5 min d'attente : 30 essais au plus, le dernier à la fin exacte")
  -- lot CC-SAUT (F515) : tuiles du cadre figé retenues dès sa création (pièces hors ressource seulement)
  local ore = function(x, y) return x >= 0 and x <= 9 and y >= 0 and y <= 9 end -- gisement 10 x 10
  local ft = Cd.frame_tiles({
    { kind = "foreuse", x = 1.5, y = 1.5, size = 3 },          -- foreuse sur le minerai : jamais retenue
    { kind = "foreuse", x = 20.5, y = 20.5, size = 3 },        -- foreuse hors minerai : jamais retenue non plus (le champ la pose)
    { kind = "tapis", x = 5.5, y = 5.5, size = 1 },            -- tapis de bande sur le minerai : libre pour les lignes de poteaux
    { kind = "four", x = 14.0, y = 4.0, size = 2 },            -- four 2 x 2 hors minerai : tuiles 13..14 x 3..4
    { kind = "coffre", x = 12.5, y = 7.5, size = 1 },          -- coffre hors minerai : tuile (12, 7)
    { kind = "bras", x = 10.5, y = 9.5, w = 1, h = 3, size = 1 }, -- pièce 1 x 3 : tuiles (10, 8..10), aucune ne touche le minerai
    { kind = "poteau", x = 10.0, y = 5.0, size = 2 },          -- 2 x 2 à cheval sur le bord : tuile (9, 4) de minerai, toute la pièce reste libre
    { kind = "poteau", x = 0.0, y = 10.0, size = 2 },           -- 2 x 2 : 1re tuile (-1, 9) hors minerai, (0, 9) sur le minerai : libre aussi
  }, ore)
  local got = {}
  for _, t in ipairs(ft) do got[#got + 1] = t[1] .. "," .. t[2] end
  local s = table.concat(got, " ")
  check(s == "13,3 13,4 14,3 14,4 12,7 10,8 10,9 10,10", "cadre figé : tuiles des pièces hors ressource seules, emprise exacte, dans l'ordre des pièces (vu : " .. s .. ")")
  check(#Cd.frame_tiles({}, ore) == 0 and #Cd.frame_tiles(nil, ore) == 0, "cadre sans pièce : aucune tuile")
  local occ3 = { ["13,3"] = 4 }
  local nr = Cd.reserve(occ3, ft, 1, function(x, y) return x .. "," .. y end)
  check(nr == 7 and occ3["13,3"] == 4 and occ3["12,7"] == "cadre:1" and Cd.own(occ3["10,10"], 1), "tuiles du cadre retenues sous son marqueur, celle d'un projet déjà planifié gardée par lui")
end

local Cd0 = dofile("shared/team/champ_dedupe.lua")
battery(Cd0)

-- branchement dans l'exécutant (lecture du code)
local src = read("script/team/champ.lua")
check(src:find('require("shared.team.champ_dedupe")', 1, true) ~= nil, "champ.lua requiert la règle")
check(src:find("Cd.verdict(e, held)", 1, true) ~= nil and src:find('Cd.cuts_trunk(Cd.verdict(e, held), e.role == "champ-charbon")', 1, true) ~= nil,
  "Build.SITES.champ : le verdict lit ce que le détenteur porte sur la tuile")
check(src:find("TRONC COUPE", 1, true) ~= nil and src:find("Champ.CFG.cut_wait", 1, true) ~= nil and src:find("cut_wait = 5 * 3600", 1, true) ~= nil,
  "tronc coupé : journal et attente bornée (jamais une impasse)")
local i = src:find("if cut > 0 then", 1, true)
local blk = i and src:sub(i, i + 2200) or ""
check(blk:find("if waiting then", 1, true) ~= nil and blk:find("return nil, string.format(\"champ: reseau du charbon coupe", 1, true) ~= nil and blk:find("or \"?\"), true", 1, true) ~= nil,
  "l'attente rend « attendre » (3e valeur vraie), pas un refus définitif")
check(blk:find("p.plan_after = Cd.next_try(game.tick, t0, Champ.CFG.cut_wait, Champ.CFG.cut_poll)", 1, true) ~= nil and src:find("cut_poll = 600,", 1, true) ~= nil,
  "lot UPS-2 : pendant l'attente du tronc, le prochain essai est daté (Cd.next_try), plus un plan à chaque passe")
local bsrc0 = read("script/team/build.lua")
local ia = bsrc0:find('if p.state == "attente" then', 1, true)
check(ia ~= nil and bsrc0:sub(ia, ia + 200):find("tick >= (p.plan_after or 0)", 1, true) ~= nil, "build.lua : l'état « attente » lit p.plan_after (la date posée par le site)")

check(src:find("Cd.reserve(b.occ, bd.deferred_tiles, o.id, P.tkey)", 1, true) ~= nil and src:find("Cd.clear(f.build.occ, o.id)", 1, true) ~= nil
  and src:find("not Cd.own(q, o.id)", 1, true) ~= nil and src:find("deferred_tiles = deferred_tiles", 1, true) ~= nil,
  "champ.lua : tuiles du réseau reporté retenues à la planification de la première bande, libérées au cadre refait, libres pour les projets du même avant-poste")
local bsrc = read("script/team/build.lua")
check(bsrc:find("Build.Cd.own(ow, p.spec.champ.oid)", 1, true) ~= nil, "build.lua : reserve_tiles rend ses tuiles retenues au projet de son cadre")
check(src:find("function(_, _, owner) return Cd.own(owner, o.id) end", 1, true) ~= nil, "blocked_in : tuiles retenues par le cadre libres pour son avant-poste")
check(src:find("Cd.dead(Cd.owners(b.occ), alive)", 1, true) ~= nil and src:find('q.state ~= "refuse"', 1, true) ~= nil, "Champ.report libère les cadres sans projet de champ vivant")
check(src:find("[FO-CHAMP-VOIE]", 1, true) ~= nil and src:find("vlogs < 8", 1, true) ~= nil, "relevé de la voie de charbon par projet (borné à 8 lignes)")
-- lot CC-SAUT (F515) : Champ.frame retient les tuiles hors ressource du cadre dès qu'il est figé (avant tout autre projet)
local fi = src:find("function Champ.frame(f, surface, o)", 1, true)
local fe = fi and src:find("\nfunction ", fi + 10, true) or nil
local fblk = (fi and fe) and src:sub(fi, fe) or ""
local wr = fblk:find("Cd.reserve(f.build.occ, Cd.frame_tiles(plan.ents, is_res), o.id, P.tkey)", 1, true)
local pl = fblk:find("local plan, why = Ch.plan_result(seq.st)", 1, true) -- s49 tranches : le plan entier sort de sa séquence pas à pas
local rt = fblk:find("return plan.frame, prs, plan", 1, true)
check(wr ~= nil and pl ~= nil and rt ~= nil and pl < wr and wr < rt, "Champ.frame : tuiles du cadre figé retenues après le plan, avant de rendre le cadre")
check(fblk:find("for i = 1, #spec.ore - 1, 2 do res[Ch.key(spec.ore[i], spec.ore[i + 1])] = true end", 1, true) ~= nil and fblk:find("spec.foreign and spec.foreign[k]", 1, true) ~= nil,
  "Champ.frame : le minerai visé ET les autres ressources restent libres (lignes de poteaux à travers le gisement)")
check(fblk:find("[FO-CHAMP] %s : avant-poste %d : %d tuile(s) du cadre fige retenue(s) au plan", 1, true) ~= nil, "Champ.frame : la réservation se lit au journal")

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
local P = "shared/team/champ_dedupe.lua"
mutant("tronc coupé par un autre flux (rôle ignoré)", "e.name == h.name and e.role == h.role and (e.dir or 0) == (h.dir or 0)", "e.name == h.name and (e.dir or 0) == (h.dir or 0)")
mutant("tronc coupé par un tapis dans l'autre sens (direction ignorée)", "e.name == h.name and e.role == h.role and (e.dir or 0) == (h.dir or 0)", "e.name == h.name and e.role == h.role")
mutant("tronc coupé par une autre pièce (nom ignoré)", "e.name == h.name and e.role == h.role and (e.dir or 0) == (h.dir or 0)", "e.role == h.role and (e.dir or 0) == (h.dir or 0)")
mutant("détenteur vide pris pour un doublon", "if not (e and h) then return false end", "if not e then return false end if not h then return true end")
mutant("la première tuile seule est lue", "for _, x in ipairs(held) do\n    if not M.same(e, x.ent) then return \"conflit\" end\n  end", "if not M.same(e, held[1].ent) then return \"conflit\" end")
mutant("réservation écrasant les tuiles d'un projet", "if occ[k] == nil then occ[k] = M.marker(oid); n = n + 1 end", "occ[k] = M.marker(oid); n = n + 1")
mutant("cadre d'un autre avant-poste pris pour le sien", 'return owner ~= nil and owner == M.marker(oid)', 'return owner ~= nil and type(owner) == "string"')
-- lot CC-SAUT (F515)
mutant("foreuses retenues au cadre (le champ se bloquerait lui-même)", 'if e.kind ~= "foreuse" then', 'if true then')
mutant("pièces sur le minerai retenues (lignes de poteaux bloquées)", 'if not on_ore then for _, t in ipairs(tiles) do out[#out + 1] = t end end', 'for _, t in ipairs(tiles) do out[#out + 1] = t end')
mutant("emprise réduite à une tuile", 'local w, h = e.w or e.size or 1, e.h or e.size or 1', 'local w, h = 1, 1')
mutant("largeur et hauteur confondues", 'local x0, y0 = math.floor(e.x - w / 2 + 0.5), math.floor(e.y - h / 2 + 0.5)', 'local x0, y0 = math.floor(e.x - h / 2 + 0.5), math.floor(e.y - w / 2 + 0.5)')
mutant("seule la première tuile testée sur le minerai", 'if is_ore(x, y) then on_ore = true end', 'if #tiles == 0 and is_ore(x, y) then on_ore = true end')
mutant("aucune tuile retenue (cadre jamais réservé)", 'if not on_ore then for _, t in ipairs(tiles) do out[#out + 1] = t end end', '')
mutant("cadre refait sans libérer", "if v == m then occ[k] = nil; n = n + 1 end", "")
mutant("libération de tous les cadres", "if v == m then occ[k] = nil; n = n + 1 end", "if type(v) == \"string\" then occ[k] = nil; n = n + 1 end")
mutant("cadre sans projet vivant jamais libéré (tuiles perdues)", "if not (alive and alive[oid]) then out[#out + 1] = oid end", "")
mutant("cadre libéré même avec un projet vivant", "if not (alive and alive[oid]) then out[#out + 1] = oid end", "out[#out + 1] = oid")
mutant("tout conflit coupe le tronc", "return verdict == \"conflit\" and role_coal == true", "return verdict == \"conflit\"")
mutant("aucun conflit ne coupe le tronc", "return verdict == \"conflit\" and role_coal == true", "return false")
-- lot UPS-2 : prochain essai d'un plan qui attend son tronc
mutant("essai repoussé après la fin de l'attente (borne ignorée)", "if nx > stop then nx = stop end", "")
mutant("essai à chaque passe (poll ignoré)", "local nx = tick + poll", "local nx = tick")
mutant("essai daté du début de l'attente (dans le passé)", "if nx < tick then nx = tick end", "")
mutant("fin de l'attente décalée d'un poll", "local stop = t0 + wait", "local stop = t0 + wait + poll")
mutant("essai daté de t0 + poll (oublie le tick courant)", "local nx = tick + poll", "local nx = t0 + poll")

print(string.format("[CHAMP-DEDUPE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
