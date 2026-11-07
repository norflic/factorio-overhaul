--[[
  Lot L12, partie 1 : hystérésis de la menace sur le QG (`hq_threat`). Test hors jeu de shared/team/menace_qg.lua (règle pure) et de
  script/team/menace_qg.lua (runtime, au moteur simulé tests/mock_engine.lua). Lancer depuis la racine du mod :
    lua5.2 tests/menace_qg_test.lua   -> [L12A] BILAN : N OK, 0 ECHEC(S)
  §1 règle pure ; §2 moteur simulé : un biter à 50, 40, 60 tuiles puis plus rien ; oscillation autour de 48 ; §3 effet sur la retenue des
  recrues (QGSURVIE, shared/team/survie_qg.lua Sq.recruit_hold) : AVANT (seuil unique) contre APRÈS (hystérésis), en pensées ; §4 câblage
  de team.lua (lecture du source) ; §5 mutants ; §6 coût en instructions (debug.sethook).
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L12A] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

local R_IN = 48 -- T.hq_threat_radius (shared/team/config.lua:293), relu plus bas
local Sq = require("shared.team.survie_qg")
local T = require("shared.team.config")
check(T.hq_threat_radius == R_IN, "T.hq_threat_radius vaut 48 (" .. tostring(T.hq_threat_radius) .. ")")

-- Une pensée de la règle pure, distance d (nil : aucune unité) : found selon le rayon sondé.
local function think(Mq, st, d, armed)
  local fin = d ~= nil and d <= R_IN
  local fout = fin
  if Mq.needs_outer(st, fin) then fout = d ~= nil and d <= Mq.EXIT_RADIUS end
  return (Mq.update(st, fin, fout, armed))
end
-- Règle d'AVANT (0.6.58, team.lua:571-575) : une unité à 48 tuiles ou moins à cette pensée.
local function old(d) return d ~= nil and d <= R_IN end

local PASSAGE = { 50, 40, 60, false, false }   -- false : plus aucune unité
local OSC = { 47, 50, 47, 50, 47, 50, 47, 50, false, false, false }

local function seq(Mq, list, armed)
  local st, out = Mq.new(), {}
  for i, d in ipairs(list) do out[i] = think(Mq, st, d or nil, armed) end
  return out, st
end
local function toggles(list)
  local n, prev = 0, false
  for _, v in ipairs(list) do if v ~= prev then n = n + 1 end prev = v end
  return n
end
local function str(list) local o = {} for i, v in ipairs(list) do o[i] = v and "T" or "f" end return table.concat(o) end

-- Suite de la règle pure : rend la liste des défauts.
local function suite(Mq)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  local p = seq(Mq, PASSAGE)
  want(str(p) == "fTTTf", "passage 50, 40, 60, rien, rien : fTTTf attendu (" .. str(p) .. ")")
  local o = seq(Mq, OSC)
  want(str(o) == "TTTTTTTTTff", "oscillation 47/50 : menace tenue, levee 2 pensees apres la derniere unite (" .. str(o) .. ")")
  want(toggles(o) == 2, "oscillation : 2 bascules (entree, sortie) (" .. toggles(o) .. ")")
  local far = seq(Mq, { 60, 55, 50, 49, false })
  want(str(far) == "fffff", "unites entre 49 et 64 sans entree : jamais de menace (" .. str(far) .. ")")
  -- verrou (besoin) : levé par une tourelle armée, la menace reste (hystérésis seule).
  local st = Mq.new()
  think(Mq, st, 40, false)
  want(st.besoin == true, "besoin a l'entree")
  think(Mq, st, 40, true)
  want(st.besoin == false and st.crise == true, "tourelle armee : besoin libere, menace tenue")
  -- rayon de sortie sondé seulement en menace et sans unité au rayon d'entrée
  local s0 = Mq.new()
  want(Mq.needs_outer(s0, false) == false, "hors menace : pas de second sondage")
  think(Mq, s0, 40, false)
  want(Mq.needs_outer(s0, true) == false and Mq.needs_outer(s0, false) == true, "en menace : second sondage seulement sans unite a 48")
  -- BORNE : un biter entré à 40 puis FIXE à 55 : la menace tient 6 pensées (Mq.HOLD_THINKS) puis sort ; pas de rentrée à 55.
  local fixe = seq(Mq, { 40, 55, 55, 55, 55, 55, 55, 55, 55 })
  want(str(fixe) == "TTTTTTfff", "borne : biter fixe a 55 apres l'entree, sortie a la 7e pensee (" .. str(fixe) .. ")")
  local fixe40 = seq(Mq, { 40, 40, 40, 40, 40, 40, 40, 40, 40, 40 })
  want(str(fixe40) == "TTTTTTTTTT", "biter fixe a 40 : la menace tient (la borne ne joue pas sous 48) (" .. str(fixe40) .. ")")
  local fixe0 = seq(Mq, { 55, 55, 55 })
  want(str(fixe0) == "fff", "biter fixe a 55 des le debut : jamais de menace")
  -- la borne repart à chaque retour sous 48
  local back = seq(Mq, { 40, 55, 55, 55, 55, 55, 47, 55, 55, 55, 55, 55, 55 })
  want(str(back) == "TTTTTTTTTTTTf", "borne : un retour sous 48 la relance (" .. str(back) .. ")")
  return bad
end

local Mq = require("shared.team.menace_qg")
local bad = suite(Mq)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "§1 suite de la regle pure")
print(string.format("[L12A] §1 passage : avant %s, apres %s ; oscillation : avant %s (%d bascules), apres %s (%d bascules)",
  (function() local o = {} for i, d in ipairs(PASSAGE) do o[i] = old(d or nil) end return str(o) end)(), str(seq(Mq, PASSAGE)),
  (function() local o = {} for i, d in ipairs(OSC) do o[i] = old(d or nil) end return str(o) end)(),
  toggles((function() local o = {} for i, d in ipairs(OSC) do o[i] = old(d or nil) end return o end)()),
  str(seq(Mq, OSC)), toggles(seq(Mq, OSC))))

-- §2 Moteur simulé : le runtime (script/team/menace_qg.lua) sur une vraie surface simulée, unités de la force « enemy ».
local M = require("tests.mock_engine")
M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0 })
local QG_ARMED = 0
package.loaded["script.ai3.prevision"] = { qg_view = function() return { qg = { tick = game.tick, armed = QG_ARMED } } end }
local MenaceQg = require("script.team.menace_qg")
local s = game.surfaces[1]
local f = { key = "player", is_player = true, team = {}, hq_pos = { x = 0, y = 0 }, hq = { valid = true, surface = s } }
local unit
local function place(d)
  if unit then unit.destroy() unit = nil end
  if d then unit = s.create_entity({ name = "small-biter", position = { x = d, y = 0 }, force = "enemy" }) end
end
local function run(list)
  f.team.hq_menace = nil
  local out = {}
  for i, d in ipairs(list) do
    place(d or nil)
    out[i] = MenaceQg.observe(f, 300 * i)
  end
  place(nil)
  return out
end
local W = M.world()
local c0 = W.count_calls or 0
local mp = run(PASSAGE)
local calls = (W.count_calls or 0) - c0
check(str(mp) == "fTTTf", "§2 moteur simule, passage 50, 40, 60, rien, rien : fTTTf (" .. str(mp) .. ")")
-- comptages : 1 par pensée hors menace (pensées 1 et 2) ; en menace, 1 à 48 plus 1 à 64 sans unité à 48 (pensées 3 à 5) : 1 + 1 + 2 + 2 + 2
check(calls == 8, "§2 comptages du moteur : 1 hors menace, 2 au plus en menace (" .. calls .. " pour " .. #PASSAGE .. " pensees, 8 attendus)")
print(string.format("[L12A] §2 comptages du moteur sur le passage : %d pour %d pensees (avant : %d)", calls, #PASSAGE, #PASSAGE))
local mf = run({ 40, 55, 55, 55, 55, 55, 55, 55 })
check(str(mf) == "TTTTTTff", "§2 moteur simule, biter fixe a 55 apres l'entree : sortie apres 6 pensees (" .. str(mf) .. ")")
local mo = run(OSC)
check(str(mo) == "TTTTTTTTTff" and toggles(mo) == 2, "§2 moteur simule, oscillation 47/50 : 2 bascules (" .. str(mo) .. ")")
local n_log = 0
for _, l in ipairs(W.logs or {}) do if l:find("[FO-QG-MENACE]", 1, true) then n_log = n_log + 1 end end
check(n_log == 6, "§2 journal [FO-QG-MENACE] : entree et sortie de chaque suite (" .. n_log .. " lignes)")
local n_borne = 0
for _, l in ipairs(W.logs or {}) do if l:find("[FO-QG-MENACE]", 1, true) and l:find("borne", 1, true) then n_borne = n_borne + 1 end end
check(n_borne == 1, "§2 journal : la sortie par la borne est ecrite comme telle (" .. n_borne .. ")")
QG_ARMED = 1
run({ 40, 40 }) -- (entrée à la 1re pensée ; la pose ne libère qu'à la pensée suivante : shared/ai3/hysteresis.lua)
check(f.team.hq_menace.besoin == false and f.team.hq_menace.crise == true, "§2 tourelle armee au QG : besoin libere, menace tenue")
QG_ARMED = 0
-- état sérialisable (vit dans la sauvegarde)
local okser = pcall(M.serialize, f.team.hq_menace)
check(okser, "§2 etat serialisable")

-- §3 Effet sur la retenue des recrues de votre équipe (QGSURVIE : Sq.recruit_hold { armed, threat }), sans tourelle armée.
local function held(list_threat)
  local n = 0
  for _, t in ipairs(list_threat) do if Sq.recruit_hold({ armed = 0, threat = t }) then n = n + 1 end end
  return n
end
local function held_armed(list_threat)
  local n = 0
  for _, t in ipairs(list_threat) do if Sq.recruit_hold({ armed = 1, threat = t }) then n = n + 1 end end
  return n
end
local oldP, oldO = {}, {}
for i, d in ipairs(PASSAGE) do oldP[i] = old(d or nil) end
for i, d in ipairs(OSC) do oldO[i] = old(d or nil) end
local newP, newO = seq(Mq, PASSAGE), seq(Mq, OSC)
local hP0, hP1, hO0, hO1 = held(oldP), held(newP), held(oldO), held(newO)
print(string.format("[L12A] §3 QGSURVIE sans tourelle armee : passage %d pensee(s) de retenue avant, %d apres (+%d pensees = +%d ticks) ; oscillation %d avant (%d bascules de la retenue), %d apres (%d bascules)",
  hP0, hP1, hP1 - hP0, 300 * (hP1 - hP0), hO0, toggles(oldO), hO1, toggles(newO)))
check(hP0 == 1 and hP1 == 3, "§3 passage : 1 pensee de retenue avant, 3 apres")
check(hO0 == 4 and hO1 == 9, "§3 oscillation : 4 pensees de retenue (8 bascules) avant, 9 d'affilee apres")
check(held_armed(newP) == 0 and held_armed(newO) == 0, "§3 avec une tourelle armee au QG : aucune retenue, avant comme apres")
do -- nid entre 48 et 64 tuiles : un biter entré à 40 puis qui reste à 55 pendant 20 pensées
  local nid = { 40 }
  for i = 2, 21 do nid[i] = 55 end
  local oldN = {}
  for i, d in ipairs(nid) do oldN[i] = old(d) end
  local hN0, hN1 = held(oldN), held((seq(Mq, nid)))
  print(string.format("[L12A] §3 nid a 55 tuiles (21 pensees) : retenue %d pensee(s) avant, %d apres (borne de %d pensees ; sans borne : 21)",
    hN0, hN1, Mq.HOLD_THINKS))
  check(hN0 == 1 and hN1 == Mq.HOLD_THINKS, "§3 nid a 55 tuiles : retenue bornee a Mq.HOLD_THINKS pensees (" .. hN1 .. ")")
end

-- §4 Câblage de team.lua (lecture du source) : l'ancien comptage a disparu, un seul appel de MenaceQg.observe, require en tête.
do
  local src = read("script/team/team.lua")
  local code = src:gsub("%-%-[^\n]*", "")
  local n_obs = select(2, code:gsub("MenaceQg%.observe%(f, tick%)", ""))
  check(n_obs == 1, "§4 team.lua appelle MenaceQg.observe une fois (" .. n_obs .. ")")
  check(not code:find("radius = T.hq_threat_radius", 1, true), "§4 team.lua ne compte plus lui-meme a T.hq_threat_radius")
  check(code:find('local MenaceQg = require("script.team.menace_qg")', 1, true) ~= nil, "§4 require en tete de team.lua (jamais pendant un evenement, F24)")
end

-- §5 Mutants (règle pure ; un du runtime).
local SRC = read("shared/team/menace_qg.lua")
local MUT = {
  { "pas de rayon de sortie (seuil unique)", "else lvl = 1 end", "end" },
  { "sans borne (maintien sans fin entre 48 et 64)", "if st.since_in >= Mq.HOLD_THINKS then opts = { sortie_n = 1 } -- borne échue : sortie à cette pensée\n      else lvl = 1 end", "lvl = 1" },
  { "borne non relancee par un retour sous 48", "lvl = st.crise and 1 or 2\n    st.since_in = 0", "lvl = st.crise and 1 or 2" },
  { "sortie a la premiere pensee sans unite", "Mq.EXIT_THINKS = 2 ", "Mq.EXIT_THINKS = 1 " },
  { "unite vue a 48 en menace comptee pour rien", "lvl = st.crise and 1 or 2\n", "lvl = st.crise and 0 or 2\n" },
  { "jamais d'entree (niveau 1 hors menace)", "lvl = st.crise and 1 or 2\n", "lvl = 1\n" },
  { "tourelle armee ignoree (besoin jamais libere)", "armed and true or false", "false" },
  { "sortie sans attente (sortie_n ignore)", "local lvl, opts = 0, { sortie_n = Mq.EXIT_THINKS }", "local lvl, opts = 0, nil" },
}
local refused = 0
for _, m in ipairs(MUT) do
  local s2, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if n ~= 1 then
    check(false, "§5 mutant introuvable (" .. n .. ") : " .. m[1])
  else
    local ok, Mm = pcall(function() return assert(load(s2, "=menace_qg", "t", _ENV))() end)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Mm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[L12A] mutant NON refuse : " .. m[1]) end
    check(killed, "§5 mutant refuse : " .. m[1])
  end
end
-- mutant du runtime : rayon fixe (l'état n'est pas lu).
do
  local RS = read("script/team/menace_qg.lua")
  local s2, n = RS:gsub(("if Mq.needs_outer(st, found_in) then"):gsub("%p", "%%%0"), "if false then")
  local killed = false
  if n == 1 then
    package.loaded["script.team.menace_qg"] = nil
    local Rm = assert(load(s2, "=menace_qg_rt", "t", _ENV))()
    f.team.hq_menace = nil
    local out = {}
    for i, d in ipairs(PASSAGE) do place(d or nil) out[i] = Rm.observe(f, 300 * i) end
    place(nil)
    killed = str(out) ~= "fTTTf"
  end
  if killed then refused = refused + 1 end
  check(n == 1 and killed, "§5 mutant du runtime refuse : rayon de sortie jamais sonde")
end
print(string.format("[L12A] §5 mutants refuses : %d sur %d", refused, #MUT + 1))

-- §6 Coût en instructions.
local function instr(fn, n)
  local worst = 0
  for _ = 1, n do
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    fn()
    debug.sethook()
    if c > worst then worst = c end
  end
  return worst
end
local stc, k = Mq.new(), 0
local w = instr(function() k = k + 1 think(Mq, stc, (k % 3 == 0) and nil or (40 + k % 30), k % 7 == 0) end, 200)
print(string.format("[L12A] §6 cout : une pensee de la regle (rayon + mise a jour) pire %d instructions (sethook, compte de 1)", w))
check(w <= 250, "§6 cout borne : 250 instructions par pensee (" .. w .. ")")

print(string.format("[L12A] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
