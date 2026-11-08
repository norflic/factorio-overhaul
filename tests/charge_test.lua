--[[
  Lot TV-VAPEUR, point V89 (dégradation graduée sous charge, signal déterministe) :
    C1. Règle pure shared/core/charge.lua : l'échantillon converge exactement, niveaux 0 à 3, hystérésis, Ch.stretch, déterminisme.
    C2. J.waiting (script/core/lourd.lua) : compte les refusés en attente, purge les périmés.
    C3. Moteur (script/core/charge.lua, doublures de Storage, Events, settings) : le niveau suit la file du jeton ; réglage éteint ou état absent
        d'une vieille sauvegarde : niveau 0 ; une ligne [FO-CHARGE] par changement.
    C4. Cd.skip : la cadence lente s'allonge, une faction ÉVEILLÉE n'est jamais ralentie (urgences intactes).
    C5. Chaîne : commander.lua passe Charge.stretch(Cd.SLOW) ; charbon_step espace Cc.EVERY ; la défense, le courant et votre équipe
        n'appellent JAMAIS Charge.
    Mutants (texte de la source changé) : ils DOIVENT tous être vus.
  Usage, depuis la racine du mod :   lua5.2 tests/charge_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end
local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local function mutated(path, subs)
  local src = read(path)
  for _, x in ipairs(subs) do
    local a, b = src:find(x[1], 1, true)
    assert(a, "mutant : texte absent de " .. path .. " : " .. x[1])
    assert(not src:find(x[1], b + 1, true), "mutant : texte present plusieurs fois : " .. x[1])
    src = src:sub(1, a - 1) .. x[2] .. src:sub(b + 1)
  end
  return src
end
local function load_src(src, name) return assert(load(src, "=" .. name))() end

local Ch = require("shared.core.charge")

------------------------------------------------------------------------------------------------
print("== C1. Regle pure")
do
  local st = { ema = 0, level = 0 }
  for _ = 1, 40 do Ch.sample(st, 5) end
  check(st.ema == 80, "file constante de 5 : le lissage atteint exactement 5 x 16 (arrondi vers la cible)")
  for _ = 1, 40 do Ch.sample(st, 0) end
  check(st.ema == 0 and st.level == 0, "file revenue a 0 : lissage 0, niveau 0")
  local function stable(q) local s = { ema = 0, level = 0 } for _ = 1, 60 do Ch.sample(s, q) end return s.level end
  check(stable(0) == 0 and stable(1) == 0, "file 0 ou 1 : niveau 0")
  check(stable(2) == 1 and stable(3) == 1, "file 2 a 3 : niveau 1")
  check(stable(4) == 2 and stable(7) == 2, "file 4 a 7 : niveau 2")
  check(stable(8) == 3 and stable(40) == 3, "file 8 et plus : niveau 3 (plafond)")
  local s = { ema = 0, level = 0 }
  for _ = 1, 40 do Ch.sample(s, 2) end
  check(s.level == 1, "monte au niveau 1 a 2 files")
  for _ = 1, 40 do Ch.sample(s, 1) end
  check(s.level == 1, "a 1 file (marge) : reste au niveau 1, aucun battement")
  for _ = 1, 40 do Ch.sample(s, 0) end
  check(s.level == 0, "a 0 file : redescend au niveau 0")
  s = { ema = 8 * 16, level = 3 }
  local seq, prev = {}, 3
  for _ = 1, 80 do
    Ch.sample(s, 0)
    if s.level ~= prev then seq[#seq + 1] = s.level prev = s.level end
  end
  check(table.concat(seq, ",") == "2,1,0", "descente 3 -> 2 -> 1 -> 0, jamais d'un saut")
  s = { ema = 0, level = 0 }
  local changes = 0
  for i = 1, 400 do
    local b, a = Ch.sample(s, (i % 2 == 0) and 3 or 1)
    if a ~= b then changes = changes + 1 end
  end
  check(changes <= 2, "file qui bat entre 1 et 3 : au plus 2 changements de niveau (" .. changes .. ")")
  check(Ch.stretch(600, 0) == 600 and Ch.stretch(600, 1) == 900 and Ch.stretch(600, 2) == 1200 and Ch.stretch(600, 3) == 1800,
    "Ch.stretch(600) : 600, 900, 1200, 1800")
  check(Ch.stretch(600, nil) == 600 and Ch.stretch(600, 9) == 600 and Ch.stretch(600, -1) == 600, "niveau inconnu : periode normale")
  local function run(qs)
    local x, lv = { ema = 0, level = 0 }, {}
    for _, q in ipairs(qs) do Ch.sample(x, q) lv[#lv + 1] = x.level .. ":" .. x.ema end
    return table.concat(lv, ",")
  end
  local suite = { 0, 3, 9, 9, 9, 1, 0, 12, 2, 2, 5 }
  check(run(suite) == run(suite), "determinisme : meme suite, memes niveaux")
  local st2 = { ema = 0, level = 0 }
  Ch.sample(st2, nil) Ch.sample(st2, -3) Ch.sample(st2, "x")
  check(st2.ema == 0 and st2.level == 0, "file illisible ou negative : traitee comme 0")
  local ints, s5 = true, { ema = 0, level = 0 }
  for i = 1, 50 do Ch.sample(s5, i % 9) if s5.ema ~= math.floor(s5.ema) then ints = false end end
  check(ints, "le lissage reste entier a chaque echantillon")
  check(Ch.PERCENT[1] == 100 and Ch.PERCENT[4] == 300 and Ch.MAX == 3, "valeurs du lot : 100 %, 300 % au plus, 3 niveaux")
end

------------------------------------------------------------------------------------------------
print("== C2 et C3. J.waiting et le moteur")
local store = {}
package.loaded["script.core.storage"] = {
  declare = function(name, init) store[name] = store[name] or init() end,
  ns = function(name) return store[name] end,
}
local nth = {}
package.loaded["script.core.events"] = { on_nth_tick = function(n, fn) nth[#nth + 1] = { n = n, fn = fn } end }
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
_G.settings = { global = { ["fo-war-degradation"] = { value = true } } }
package.loaded["script.core.lourd"] = nil
local J = require("script.core.lourd")

local function fresh_charge(subs)
  package.loaded["script.core.charge"] = nil
  nth = {}
  LOGS = {}
  if subs then return load_src(mutated("script/core/charge.lua", subs), "script/core/charge.lua") end
  return require("script.core.charge")
end
local function crowd(tick, n) -- n demandeurs differents refuses a ce tick (le premier prend tout le budget)
  J.reset()
  for i = 1, n + 1 do J.take(tick, "w" .. i) end
end

do
  J.reset()
  check(J.waiting(100) == 0, "C2 : file vide : 0 en attente")
  crowd(100, 5)
  check(J.waiting(100) == 5, "C2 : 1 servi + 5 refuses : 5 en attente")
  check(J.waiting(100 + J.STALE + 1) == 0, "C2 : sans nouvelle demande, les entrees perimees sont purgees")
  local keep = store["pouls_jeton"]
  store["pouls_jeton"] = nil
  check(J.waiting(1) == 0, "C2 : etat absent : 0")
  store["pouls_jeton"] = keep
end

do
  local Charge = fresh_charge()
  check(#nth == 1 and nth[1].n == Ch.SAMPLE, "C3 : un seul abonnement, toutes les Ch.SAMPLE ticks")
  J.reset()
  store["pouls_jeton"].charge = nil
  check(Charge.level() == 0 and Charge.stretch(600) == 600, "C3 : sauvegarde d'avant le lot (pas de champ charge) : niveau 0, rien d'espace")
  -- file VIDE : le niveau ne bouge jamais, aucune ligne de journal (demande du lead)
  local te = 500
  local moved = false
  for _ = 1, 500 do
    J.reset()
    Charge.sample(te)
    te = te + 60
    if Charge.level() ~= 0 then moved = true end
  end
  check(not moved and #LOGS == 0 and store["pouls_jeton"].charge.ema == 0, "C3 : file vide pendant 500 echantillons : niveau 0, lissage 0, aucune ligne [FO-CHARGE]")
  local t = 1000
  for _ = 1, 30 do
    crowd(t, 8)
    Charge.sample(t)
    t = t + 60
  end
  check(Charge.level() == 3, "C3 : 8 refuses en attente a chaque echantillon : niveau 3")
  check(Charge.stretch(600) == 1800, "C3 : Charge.stretch(600) = 1800 au niveau 3")
  check(LOGS[1] and LOGS[1]:find("[FO-CHARGE]", 1, true) and LOGS[1]:find("niveau 0 -> 1", 1, true), "C3 : journal [FO-CHARGE] 0 -> 1")
  check(#LOGS == 3, "C3 : une ligne par changement de niveau (0->1, 1->2, 2->3) : " .. #LOGS)
  _G.settings.global["fo-war-degradation"].value = false
  Charge.sample(t)
  check(Charge.level() == 0 and Charge.stretch(600) == 600, "C3 : reglage eteint : niveau 0, rien d'espace")
  _G.settings.global["fo-war-degradation"].value = true
  for _ = 1, 60 do J.reset() t = t + 60 Charge.sample(t) end
  check(Charge.level() == 0, "C3 : file vide : retour au niveau 0")
  local keep = _G.settings
  _G.settings = nil
  check(Charge.enabled() == true, "C3 : reglage illisible : allume (defaut)")
  _G.settings = keep
end

------------------------------------------------------------------------------------------------
print("== C4. Cd.skip")
do
  local Cd = require("shared.faction.cadence")
  local box = { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }
  local calm = { box = box, players = {}, army_out = false }
  local st = { last = 1000 }
  check(Cd.skip(st, calm, 1000 + 700) == false, "C4 : sans parametre, 700 ticks apres : pensee (Cd.SLOW = 600)")
  check(Cd.skip(st, calm, 1000 + 700, 900) == true, "C4 : cadence lente de 900 : a 700 ticks la pensee est sautee")
  check(Cd.skip(st, calm, 1000 + 900, 900) == false, "C4 : a 900 ticks elle pense")
  check(Cd.skip(st, calm, 1000 + 100, 1800) == true, "C4 : 1800 : sautee a 100")
  local sk, why = Cd.skip(st, { box = box, players = {}, army_out = false, threatened_until = 5000 }, 1100, 1800)
  check(sk == false and why == "menace", "C4 : faction MENACEE : jamais sautee, quelle que soit la charge")
  check(Cd.skip(st, { box = box, players = {}, army_out = true }, 1100, 1800) == false, "C4 : armee dehors : jamais sautee")
  check(Cd.skip(st, { box = box, players = { { x = 5, y = 5 } }, army_out = false }, 1100, 1800) == false, "C4 : joueur proche : jamais sautee")
  check(Cd.skip(st, { is_player = true }, 1100, 1800) == false, "C4 : votre equipe : jamais sautee")
end

------------------------------------------------------------------------------------------------
print("== C5. Chaine")
local commander = read("script/faction/commander.lua")
local build = read("script/team/build.lua")
check(commander:find("Cd.skip(cs, inp, tick, Charge.stretch(Cd.SLOW))", 1, true) ~= nil, "C5 : commander.lua : Cd.skip recoit Charge.stretch(Cd.SLOW)")
check(commander:find('require("script.core.charge")', 1, true) ~= nil, "C5 : commander.lua requiert script.core.charge (abonnement charge)")
check(build:find("Build.Charge.stretch(Cc.EVERY)", 1, true) ~= nil, "C5 : charbon_step espace Cc.EVERY")
for _, p in ipairs({ "script/team/reseau_vivant.lua", "script/team/raccord.lua", "script/team/player_team.lua", "script/team/sante_centrale.lua",
  "script/team/plant_arms.lua", "script/faction/defchoix.lua", "script/faction/military.lua", "script/faction/pvp.lua", "script/team/team.lua" }) do
  local fh = io.open(p, "rb")
  check(fh ~= nil, "C5 : " .. p .. " existe")
  if fh then
    local src = fh:read("*a")
    fh:close()
    check(not src:find("script.core.charge", 1, true) and not src:find("Charge.stretch", 1, true), "C5 : " .. p .. " n'appelle jamais Charge (urgence ou votre equipe)")
  end
end

------------------------------------------------------------------------------------------------
print("== Mutants")
local function mutant(name, fn)
  local ok, caught = pcall(fn)
  if ok and caught then check(true, "mutant refuse : " .. name) else check(false, "mutant SURVIVANT : " .. name .. (ok and "" or " (" .. tostring(caught) .. ")")) end
end
local function pure_with(subs) return load_src(mutated("shared/core/charge.lua", subs), "mut_charge") end
local function levels_after(M, qs)
  local st, out = { ema = 0, level = 0 }, {}
  for _, q in ipairs(qs) do M.sample(st, q) out[#out + 1] = st.level end
  return table.concat(out, ",")
end
local ref_seq = {}
for _, q in ipairs({ 2, 1, 0, 9 }) do for _ = 1, 30 do ref_seq[#ref_seq + 1] = q end end
local ref_out = levels_after(Ch, ref_seq)
mutant("pas d'hysteresis", function() return levels_after(pure_with({ { "Ch.HYST = 1 ", "Ch.HYST = 0 " } }), ref_seq) ~= ref_out end)
mutant("arrondi toujours vers le bas", function()
  return levels_after(pure_with({ { "ema = ema + math.ceil(d / 4)", "ema = ema + math.floor(d / 4)" } }), ref_seq) ~= ref_out end)
mutant("seuil du niveau 1 a 3 files", function() return levels_after(pure_with({ { "Ch.UP = { 2, 4, 8 }", "Ch.UP = { 3, 4, 8 }" } }), ref_seq) ~= ref_out end)
mutant("etirement du niveau 3 a 100 %", function() return pure_with({ { "Ch.PERCENT = { 100, 150, 200, 300 }", "Ch.PERCENT = { 100, 150, 200, 100 }" } }).stretch(600, 3) ~= 1800 end)
mutant("jamais de descente", function()
  return levels_after(pure_with({ { "elseif level > 0 and ema <", "elseif false and ema <" } }), ref_seq) ~= ref_out end)
mutant("moteur : reglage ignore", function()
  local Charge = fresh_charge({ { "if ok and v == false then return false end", "" } })
  _G.settings.global["fo-war-degradation"].value = false
  local t = 5000
  for _ = 1, 30 do crowd(t, 8) Charge.sample(t) t = t + 60 end
  local lvl = Charge.level()
  _G.settings.global["fo-war-degradation"].value = true
  return lvl ~= 0
end)
mutant("moteur : file non lue", function()
  local Charge = fresh_charge({ { "local q = Lourd.waiting(tick)", "local q = 0" } })
  store["pouls_jeton"].charge = nil
  local t = 9000
  for _ = 1, 30 do crowd(t, 8) Charge.sample(t) t = t + 60 end
  return Charge.level() == 0
end)
mutant("Cd.skip ignore la cadence passee", function()
  local M = load_src(mutated("shared/faction/cadence.lua", { { "(slow or Cd.SLOW)", "Cd.SLOW" } }), "mut_cd")
  return M.skip({ last = 1000 }, { box = { x0 = 0, y0 = 0, x1 = 1, y1 = 1 }, players = {}, army_out = false }, 1700, 900) == false
end)
mutant("niveau qui monte file vide", function()
  local M = pure_with({ { "local ema = st.ema or 0", "local ema = (st.ema or 0) + 16" } })
  local st = { ema = 0, level = 0 }
  for _ = 1, 60 do M.sample(st, 0) end
  return st.level ~= 0
end)
mutant("Cd.skip ralentit aussi une faction eveillee", function()
  local M = load_src(mutated("shared/faction/cadence.lua", { { "if up then return false, why end", "if up and false then return false, why end" } }), "mut_cd2")
  return M.skip({ last = 1000 }, { box = { x0 = 0, y0 = 0, x1 = 1, y1 = 1 }, players = {}, army_out = false, threatened_until = 9999 }, 1100, 1800) == true
end)

fresh_charge()
print(string.format("[CHARGE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
