--[[
  Lot REBUILD-TOUT : test hors jeu du relevé de reconstruction des projets du plan directeur
  (règle pure shared/team/rebuild_sweep.lua et exécutant script/team/rebuild_sweep.lua, moteur simulé réduit).
  Défaut corrigé (retour du DC, 29/10, 1 h 30 sur 0.6.13) : une pièce POSÉE d'un projet, puis détruite, n'était jamais remise à bâtir
  (les projets finis ne reprennent pas leurs pièces ; le registre de reconstruction était éteint pour les factions et les pièces de production).
  Usage : lua5.2 tests/rebuild_sweep_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local logs = {}
function log(s) logs[#logs + 1] = s end

---------------------------------------------------------------------------------------------------
-- Règle pure
---------------------------------------------------------------------------------------------------
local SRC = read("shared/team/rebuild_sweep.lua")
local function load_rule(src)
  local fn, err = load(src, "=rebuild_sweep", "t")
  if not fn then return nil, err end
  local ok, m = pcall(fn)
  if not ok then return nil, m end
  return m
end

--- Banc de la règle : rend le nombre de contrôles réussis et la liste des échecs (pour les mutants).
local function suite(Sw)
  local ok, bad = 0, {}
  local function c(cond, m) if cond then ok = ok + 1 else bad[#bad + 1] = m end end

  -- classes
  local first, skip = { belt = true, drill = true }, { pole = true }
  c(Sw.class_of("drill", first, skip) == 1 and Sw.class_of("belt", first, skip) == 1, "classe 1 : entrées de production")
  c(Sw.class_of("lab", first, skip) == 2, "classe 2 : le reste")
  c(Sw.class_of("pole", first, skip) == nil and Sw.class_of(nil, first, skip) == nil, "infrastructure ou type inconnu : laissé à un autre mécanisme")

  -- tranches : bornées, bouclent, sautent les projets vides
  local segs, pi, ei = Sw.slice({ 5, 0, 4 }, 1, 1, 6)
  c(#segs == 2 and segs[1][1] == 1 and segs[1][2] == 1 and segs[1][3] == 5 and segs[2][1] == 3 and segs[2][2] == 1 and segs[2][3] == 1
    and pi == 3 and ei == 2, "tranche : 6 pièces, projet vide sauté, curseur au bon endroit")
  segs, pi, ei = Sw.slice({ 5, 0, 4 }, pi, ei, 100)
  local n = 0
  for _, sg in ipairs(segs) do n = n + (sg[3] - sg[2] + 1) end
  c(n == 3 + 5, "tranche : un seul tour complet par passe, jamais plus que le contenu (" .. n .. ")")
  segs, pi, ei = Sw.slice({}, 1, 1, 10)
  c(#segs == 0 and pi == 1 and ei == 1, "tranche : aucun projet")
  segs = Sw.slice({ 300 }, 1, 1, Sw.SLICE)
  c(#segs == 1 and segs[1][3] - segs[1][2] + 1 == Sw.SLICE, "tranche : au plus Sw.SLICE pièces par passe")

  -- deux vues
  local e = {}
  c(Sw.observe(e, true, 100) == "ok" and e.miss == nil, "vue en place : rien")
  c(Sw.observe(e, false, 100) == "marque" and e.miss == 100, "première vue absente : inscrite, pas rouverte")
  c(Sw.observe(e, false, 100 + Sw.CALM - 1) == "marque", "patience non écoulée : toujours inscrite")
  c(Sw.observe(e, false, 100 + Sw.CALM) == "due", "absente à une seconde vue espacée : due")
  c(Sw.observe(e, true, 100 + Sw.CALM + 5) == "ok" and e.miss == nil, "revue en place : l'inscription est effacée")

  -- ordre, plafonds
  local function proj(n) local q = { ents = {} } for i = 1, n do q.ents[i] = { name = "x" .. i } end return q end
  local q1, q2 = proj(10), proj(10)
  local cands = {
    { q = q2, pi = 2, i = 1, e = q2.ents[1], class = 2 },
    { q = q1, pi = 1, i = 3, e = q1.ents[3], class = 2 },
    { q = q2, pi = 2, i = 5, e = q2.ents[5], class = 1 },
    { q = q1, pi = 1, i = 2, e = q1.ents[2], class = 1 },
  }
  local picked = Sw.select(cands, 1000, nil)
  c(#picked == 4 and picked[1].e == q1.ents[2] and picked[2].e == q2.ents[5] and picked[3].e == q1.ents[3] and picked[4].e == q2.ents[1],
    "ordre : entrées de production d'abord, puis projet, puis place")
  -- plafond de passe
  local big = proj(200)
  local cs = {}
  for i = 1, 150 do cs[i] = { q = big, pi = 1, i = i, e = big.ents[i], class = 2 } end
  picked = Sw.select(cs, 1000, nil)
  c(#picked == Sw.PASS_MAX, "plafond de passe : " .. #picked)
  -- plafond horaire : max(40, moitié)
  local small = proj(30)
  local total = 0
  for pass = 1, 5 do
    local cc = {}
    for i = 1, 30 do if small.ents[i].rb == nil or small.ents[i].rb < 99 then cc[#cc + 1] = { q = small, pi = 1, i = i, e = small.ents[i], class = 2 } end end
    for _, x in ipairs(cc) do x.e.rb = nil end -- l'historique de pièce n'est pas l'objet de ce contrôle
    total = total + #Sw.select(cc, 1000 + pass, nil)
  end
  c(total == Sw.hour_cap(30) and Sw.hour_cap(30) == Sw.HOUR_MIN, "plafond horaire d'un petit projet : " .. total)
  c(Sw.hour_cap(400) == 200, "plafond horaire d'un gros projet : la moitié")
  -- la fenêtre se renouvelle après une heure
  local after = Sw.select({ { q = small, pi = 1, i = 1, e = small.ents[1], class = 2 } }, 1000 + Sw.HOUR + 10, nil)
  c(#after == 1, "plafond horaire : fenêtre renouvelée après une heure")
  -- abandon d'une pièce détruite sans cesse
  local qa = proj(3)
  local ea = qa.ents[1]
  local rounds = 0
  for k = 1, Sw.MAX_REBUILD + 2 do
    local got = Sw.select({ { q = qa, pi = 1, i = 1, e = ea, class = 1 } }, 5000 + k * 10, nil)
    if #got == 1 then rounds = rounds + 1 end
  end
  c(rounds == Sw.MAX_REBUILD and ea.gave_up == true, "pièce détruite sans cesse : abandonnée après " .. Sw.MAX_REBUILD .. " réouvertures (" .. rounds .. ")")
  -- oubli de l'historique
  local qb = proj(3)
  local eb = qb.ents[1]
  eb.rb, eb.rb_t = Sw.MAX_REBUILD - 1, 100
  local got = Sw.select({ { q = qb, pi = 1, i = 1, e = eb, class = 1 } }, 100 + Sw.FORGET + 1, nil)
  c(#got == 1 and eb.rb == 1 and not eb.gave_up, "historique oublié après Sw.FORGET sans destruction")
  -- danger : pièce non rouverte, ne compte pas dans le plafond
  local qd = proj(100)
  local cd = {}
  for i = 1, 100 do cd[i] = { q = qd, pi = 1, i = i, e = qd.ents[i], class = 2 } end
  picked = Sw.select(cd, 1000, function(x) return x.i > 50 end)
  c(#picked == Sw.PASS_MAX and picked[1].i == 51 and (qd.sw_n or 0) == Sw.PASS_MAX and (qd.ents[1].rb or 0) == 0,
    "danger : les pièces en danger restent inscrites et ne comptent pas")
  return ok, bad
end

local Sw = assert(load_rule(SRC))
local ok, bad = suite(Sw)
pass = pass + ok
for _, m in ipairs(bad) do fail = fail + 1 print("  ECHEC : " .. m) end

-- Mutants : la suite doit tous les refuser
local MUTANTS = {
  { "SLICE sans borne", "local last = math.min(size, ei + left - 1)", "local last = size" },
  { "tour multiple", "while left > 0 and visited < n do", "while left > 0 and visited <= n do" },
  { "pas de patience", "if tick - e.miss >= Sw.CALM then return \"due\" end", "if tick - e.miss >= 0 then return \"due\" end" },
  { "première vue rouvre", "    e.miss = tick\n    return \"marque\"", "    e.miss = tick\n    return \"due\"" },
  { "ordre inversé", "if a.class ~= b.class then return a.class < b.class end", "if a.class ~= b.class then return a.class > b.class end" },
  { "pas de plafond de passe", "if #picked >= Sw.PASS_MAX then break end", "" },
  { "pas de plafond horaire", "(q.sw_n or 0) < Sw.hour_cap(#q.ents) and", "" },
  { "pas d'abandon", "if (e.rb or 0) >= Sw.MAX_REBUILD then", "if false then" },
  { "danger compté", "if (q.sw_n or 0) < Sw.hour_cap(#q.ents) and (not safe or safe(c)) then", "if (q.sw_n or 0) < Sw.hour_cap(#q.ents) then" },
  { "infra refaite", "if not ty or (skip and skip[ty]) then return nil end", "if not ty then return nil end" },
}
local refused = 0
for _, mu in ipairs(MUTANTS) do
  local a, b = SRC:find(mu[2], 1, true)
  if not a then
    fail = fail + 1 print("  ECHEC : mutant introuvable : " .. mu[1])
  else
    local msrc = SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1)
    local M = load_rule(msrc)
    local caught = false
    if not M then caught = true
    else
      local okc, o2, b2 = pcall(suite, M)
      caught = (not okc) or #b2 > 0
    end
    if caught then refused = refused + 1 else fail = fail + 1 print("  ECHEC : mutant survivant : " .. mu[1]) end
  end
end
pass = pass + refused
print(string.format("[REBUILD-TOUT] mutants refusés : %d sur %d", refused, #MUTANTS))

---------------------------------------------------------------------------------------------------
-- Exécutant (moteur simulé)
---------------------------------------------------------------------------------------------------
local R = require("shared.ai3.reglages")
check(R.REBUILD_SWEEP == true and R.RECON_FACTIONS == true and R.RECON_ALL_PIECES == true, "réglages par défaut allumés")
check(R.REBUILD_FIRST["mining-drill"] and R.REBUILD_FIRST["transport-belt"] and R.REBUILD_FIRST["inserter"] and R.REBUILD_FIRST["furnace"],
  "entrées de production : foreuse, tapis, bras, four")
check(not R.REBUILD_FIRST["lab"] and not R.REBUILD_FIRST["assembling-machine"], "le reste n'est pas prioritaire")

local PROTO = {
  drill = { type = "mining-drill" }, belt = { type = "transport-belt" }, asm = { type = "assembling-machine" }, lab = { type = "lab" },
  pole = { type = "electric-pole" }, wall = { type = "wall" }, boiler = { type = "boiler" },
}
game = { tick = 0, entity_prototypes = PROTO }
local Sweep = require("script.team.rebuild_sweep")

local present = {}    -- "x,y" -> vrai : entité réelle en place
local calls = 0
local enemy = nil     -- { x, y } d'un ennemi
local surface = {
  count_entities_filtered = function(a)
    calls = calls + 1
    return present[a.position[1] .. "," .. a.position[2]] and 1 or 0
  end,
  find_nearest_enemy = function(a)
    if enemy and math.abs(enemy.x - a.position.x) <= a.max_distance and math.abs(enemy.y - a.position.y) <= a.max_distance then return { valid = true } end
    return nil
  end,
}
local function team(name, state, defs)
  local q = { id = 1, state = state, ents = {}, spec = {} }
  for i, d in ipairs(defs) do
    q.ents[i] = { name = d[1], x = d[2], y = d[3], built = true, item = "item-" .. d[1] }
    present[d[2] .. "," .. d[3]] = true
  end
  return { key = name, force = name, build = { order = { 1 }, projects = { [1] = q } } }, q
end

-- 1. Pièces détruites d'un projet FINI de faction : rouvertes en deux vues, entrées de production avant le reste
do
  local f, q = team("ambre", "fini", { { "lab", 0, 0 }, { "drill", 5, 0 }, { "belt", 6, 0 }, { "asm", 10, 0 }, { "pole", 12, 0 }, { "wall", 14, 0 } })
  q.ents[6].wall = true
  Sweep.step(f, surface, 100) -- initialise l'horloge
  present["0,0"], present["5,0"], present["6,0"], present["10,0"], present["12,0"], present["14,0"] = nil, nil, nil, nil, nil, nil
  local n1 = Sweep.step(f, surface, 100 + 180)
  check(n1 == 0 and q.state == "fini", "première vue : rien n'est rouvert")
  check(q.ents[1].miss and q.ents[2].miss and q.ents[3].miss and q.ents[4].miss, "première vue : les pièces absentes sont inscrites")
  check(q.ents[5].miss == nil and q.ents[6].miss == nil, "infrastructure électrique et mur d'enceinte : laissés à leurs mécanismes")
  local n2 = Sweep.step(f, surface, 100 + 180 + 180 + Sw.CALM)
  check(n2 == 4, "seconde vue : 4 pièces rouvertes (" .. n2 .. ")")
  check(not q.ents[1].built and not q.ents[2].built and not q.ents[3].built and not q.ents[4].built, "les pièces sont remises à bâtir")
  check(q.ents[5].built and q.ents[6].built, "poteau et mur intacts au plan")
  check(q.state == "reserve" and q.counted == true and q.reopened == 1, "projet fini : repasse en réserve, non recompté, non annulable")
  check(q.ents[2].ghosted == false and q.ents[2].fails == 0, "fantôme à reposer, échecs remis à zéro")
  check(logs[#logs] and logs[#logs]:find("%[FO%-REBUILD%]") and logs[#logs]:find("drill"), "journal : la pièce d'entrée de production est citée en premier")
end

-- 2. Chantier en cours : l'état est conservé ; raccordement : retour en chantier
do
  local f, q = team("azur", "chantier", { { "belt", 1, 1 }, { "belt", 2, 1 } })
  Sweep.step(f, surface, 10)
  present["1,1"] = nil
  Sweep.step(f, surface, 10 + 180)
  local n = Sweep.step(f, surface, 10 + 360 + Sw.CALM)
  check(n == 1 and q.state == "chantier" and not q.ents[1].built and q.ents[2].built, "chantier : une pièce rouverte, état conservé")
  local f2, q2 = team("azur2", "raccordement", { { "belt", 31, 1 } })
  Sweep.step(f2, surface, 10)
  present["31,1"] = nil
  Sweep.step(f2, surface, 10 + 180)
  Sweep.step(f2, surface, 10 + 360 + Sw.CALM)
  check(q2.state == "chantier" and not q2.ents[1].built, "raccordement : retour en chantier (le projet ne se déclare pas fini)")
end

-- 3. Pièce revue en place (refaite par un autre moyen) : jamais rouverte
do
  local f, q = team("c", "fini", { { "asm", 41, 1 } })
  Sweep.step(f, surface, 10)
  present["41,1"] = nil
  Sweep.step(f, surface, 10 + 180)
  check(q.ents[1].miss ~= nil, "pièce absente : inscrite")
  present["41,1"] = true
  local n = Sweep.step(f, surface, 10 + 360 + Sw.CALM)
  check(n == 0 and q.ents[1].built and q.ents[1].miss == nil, "pièce revenue : inscription effacée, rien rouvert")
end

-- 4. Ennemi sur place : rien n'est rouvert tant qu'il y est
do
  local f, q = team("d", "fini", { { "asm", 51, 1 } })
  Sweep.step(f, surface, 10)
  present["51,1"] = nil
  Sweep.step(f, surface, 10 + 180)
  enemy = { x = 60, y = 1 }
  local n = Sweep.step(f, surface, 10 + 360 + Sw.CALM)
  check(n == 0 and q.ents[1].built and q.state == "fini" and f.build.sweep.danger == 1, "ennemi à moins de " .. Sweep.ENEMY_R .. " tuiles : pas de réouverture")
  enemy = nil
  n = Sweep.step(f, surface, 10 + 540 + Sw.CALM)
  check(n == 1 and not q.ents[1].built, "ennemi parti : la pièce est rouverte")
end

-- 5. Retrait à la main : jamais refait
do
  local f, q = team("player", "fini", { { "asm", 71, 1 }, { "asm", 74, 1 } })
  Sweep.step(f, surface, 10)
  Sweep.note_hand(f, { valid = true, position = { x = 71, y = 1 } }, 15)
  present["71,1"], present["74,1"] = nil, nil
  Sweep.step(f, surface, 10 + 180)
  local n = Sweep.step(f, surface, 10 + 360 + Sw.CALM)
  check(n == 1 and q.ents[1].built and not q.ents[2].built, "retiré à la main : conservé au plan, l'autre pièce est rouverte")
  check(q.ents[1].gave_up == true, "retiré à la main : abandonné pour de bon (ne revient pas à l'expiration de la mémoire)")
  -- sans objet pour la poser : jamais rouverte
  local fi, qi = team("i", "fini", { { "asm", 301, 1 } })
  qi.ents[1].item = nil
  Sweep.step(fi, surface, 10)
  present["301,1"] = nil
  Sweep.step(fi, surface, 10 + 180)
  check(Sweep.step(fi, surface, 10 + 360 + Sw.CALM) == 0 and qi.ents[1].built, "pièce sans objet pour la poser : laissée")
  -- mémoire bornée
  local f2 = team("e", "fini", {})
  for i = 1, Sweep.HAND_MAX * 2 + 5 do Sweep.note_hand(f2, { valid = true, position = { x = i, y = 0 } }, i) end
  check(f2.build.sweep.hand_cnt <= Sweep.HAND_MAX + 5, "mémoire des retraits à la main bornée (" .. f2.build.sweep.hand_cnt .. ")")
end

-- 6. Tranches : un projet de 1000 pièces n'est jamais lu d'un coup
do
  local defs = {}
  for i = 1, 1000 do defs[i] = { "belt", 100 + i, 5 } end
  local f, q = team("g", "fini", defs)
  calls = 0
  Sweep.step(f, surface, 10)
  Sweep.step(f, surface, 10 + 180)
  check(calls <= Sw.SLICE, "une passe lit au plus " .. Sw.SLICE .. " pièces (" .. calls .. ")")
  local t = 10 + 180
  for _ = 1, 12 do t = t + 180 Sweep.step(f, surface, t) end
  check(f.build.sweep.seen >= 1000, "au bout de quelques passes, tout le projet a été vu (" .. f.build.sweep.seen .. ")")
end

-- 7. Réglage éteint, projet abandonné, enceinte : rien
do
  local f, q = team("h", "fini", { { "asm", 201, 1 } })
  Sweep.step(f, surface, 10)
  present["201,1"] = nil
  R.REBUILD_SWEEP = false
  calls = 0
  Sweep.step(f, surface, 10 + 180)
  Sweep.step(f, surface, 10 + 360 + Sw.CALM)
  check(calls == 0 and q.ents[1].built, "réglage éteint : le relevé ne tourne pas")
  R.REBUILD_SWEEP = true
  q.abandoned = true
  Sweep.step(f, surface, 10 + 540 + Sw.CALM)
  Sweep.step(f, surface, 10 + 720 + Sw.CALM)
  check(q.ents[1].built, "projet abandonné : ignoré")
  q.abandoned = nil
  q.spec.enceinte = true
  Sweep.step(f, surface, 10 + 900 + Sw.CALM)
  Sweep.step(f, surface, 10 + 1080 + Sw.CALM)
  check(q.ents[1].built, "segment d'enceinte : laissé à son contrôle des murs")
end

-- 8. Pièce détruite sans cesse : abandonnée au plan (e.gave_up), elle ne vide pas le coffre
do
  local f, q = team("i", "fini", { { "belt", 301, 1 } })
  local t = 10
  Sweep.step(f, surface, t)
  local reopened = 0
  for _ = 1, 8 do
    present["301,1"] = nil
    t = t + 180
    Sweep.step(f, surface, t)
    t = t + 180 + Sw.CALM
    reopened = reopened + Sweep.step(f, surface, t)
    q.ents[1].built = true -- le plan l'a refaite, puis elle est détruite de nouveau
    q.state = "fini"
  end
  check(reopened == Sw.MAX_REBUILD and q.ents[1].gave_up, "détruite sans cesse : " .. reopened .. " réouvertures puis abandon")
end

-- 9. Source : ni pairs, ni hasard, ni nom du jeu, ni global
for _, file in ipairs({ "shared/team/rebuild_sweep.lua", "script/team/rebuild_sweep.lua" }) do
  local src = read(file)
  local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("[^i]pairs%(") and not code:find("math.random", 1, true), file .. " : ni pairs ni hasard")
  check(not code:find("global", 1, true) and not code:find("game.tick", 1, true), file .. " : ni global ni temps mesuré")
  for _, nom in ipairs({ "iron%-plate", "gun%-turret", "burner", "stone%-furnace", "transport%-belt", "mining%-drill", "inserter" }) do
    local hit = false
    for lit in code:gmatch('"([^"]*)"') do if lit:find(nom) then hit = true end end
    check(not hit, file .. " : aucun nom du jeu (" .. nom .. ")")
  end
end

print(string.format("[REBUILD-TOUT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
