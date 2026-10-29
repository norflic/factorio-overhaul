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
  -- lot REBUILD-SUIVI : entrées de production (classe 1) : le projet entier, compteur à part (fonderie 6 d'Azur : 122 pièces, 61 rouvertes puis l'attente)
  c(Sw.hour_cap(122, 1) == 122 and Sw.hour_cap(400, 1) == 400 and Sw.hour_cap(30, 1) == Sw.HOUR_MIN, "plafond horaire des entrées de production : le projet entier")
  c(Sw.hour_cap(122, 2) == 61 and Sw.hour_cap(122) == 61, "plafond horaire du reste : la moitié")
  do
    local qf = proj(122)
    local got1, got2 = 0, 0
    for pass = 1, 6 do
      local cc = {}
      for i = 1, 122 do
        local e = qf.ents[i]
        if not e.done then cc[#cc + 1] = { q = qf, pi = 1, i = i, e = e, class = i <= 100 and 1 or 2 } end
      end
      for _, x in ipairs(Sw.select(cc, 2000 + pass, nil)) do
        x.e.done = true
        if x.class == 1 then got1 = got1 + 1 else got2 = got2 + 1 end
      end
    end
    c(got1 == 100, "projet de 122 pièces détruit : toutes les 100 entrées de production sont rouvertes dans l'heure (" .. got1 .. ")")
    c(got2 == 22 and (qf.sw_n or 0) == 22 and (qf.sw_n1 or 0) == 100, "le reste a son compteur à part (" .. got2 .. ")")
  end
  do
    -- les entrées de production ont un plafond aussi : max(HOUR_MIN, projet) par heure, même si les mêmes pièces sont détruites sans cesse
    local q1p = proj(30)
    local total1 = 0
    for pass = 1, 5 do
      local cc = {}
      for i = 1, 30 do q1p.ents[i].rb = nil cc[i] = { q = q1p, pi = 1, i = i, e = q1p.ents[i], class = 1 } end
      total1 = total1 + #Sw.select(cc, 3000 + pass, nil)
    end
    c(total1 == Sw.HOUR_MIN and (q1p.sw_n1 or 0) == Sw.HOUR_MIN and (q1p.sw_n or 0) == 0, "entrées de production : plafond horaire respecté (" .. total1 .. ")")
  end
  do
    local qg = proj(122)
    local cc = {}
    for i = 1, 122 do cc[i] = { q = qg, pi = 1, i = i, e = qg.ents[i], class = 2 } end
    local n = 0
    for pass = 1, 6 do
      local live = {}
      for _, x in ipairs(cc) do if not x.e.done then live[#live + 1] = x end end
      for _, x in ipairs(Sw.select(live, 2000 + pass, nil)) do x.e.done = true n = n + 1 end
    end
    c(n == 61, "classe 2 : toujours la moitié du projet par heure (" .. n .. ")")
  end
  -- lot REBUILD-SUIVI : suivi d'un module que le cerveau croyait fini
  do
    local m = { state = "fini", rate_meas = 76, built = 95, total = 95, finished = 100, made_prev = 4000 }
    c(Sw.follow(m, { state = "fini" }, 500) == false and m.state == "fini", "suivi : un projet toujours fini ne change rien")
    c(Sw.follow(m, { state = "refuse" }, 500) == false and m.state == "fini", "suivi : un projet refusé n'est pas un module rouvert")
    c(Sw.follow(m, nil, 500) == false and m.state == "fini", "suivi : projet inconnu : rien")
    c(Sw.follow({ state = "chantier" }, { state = "reserve" }, 500) == false, "suivi : seul un module tenu pour fini est rouvert")
    local s = { state = "reserve", reason = "materiaux", missing = { { "four", 40 }, { "tapis", 77 } }, built = 52, total = 95 }
    c(Sw.follow(m, s, 500) == true and m.state == "reserve" and m.reason == "materiaux" and #m.missing == 2 and m.built == 52 and m.total == 95,
      "suivi : module fini dont le projet est en réserve : état, manques et construits relus")
    c(m.reopened_at == 500 and m.reopened_n == 1 and m.rate_meas == 0, "suivi : date de réouverture notée, production mesurée remise à 0")
    c(m.made_prev == nil, "suivi : compteur de fabrication remis à zéro (pas de pic de débit au retour à fini)")
    c(Sw.follow(m, { state = "chantier" }, 900) == false and m.state == "reserve", "suivi : un module déjà rouvert n'est pas relu par ce chemin")
    m.state = "fini"
    c(Sw.follow(m, { state = "chantier", missing = {}, built = 60, total = 95 }, 900) == true and m.reopened_at == 500 and m.reopened_n == 2,
      "suivi : deuxième réouverture avant la fin de la réparation : la date de début est gardée")
    c(Sw.repaired(m, 500 + 7200) == 7200 and m.reopened_at == nil, "suivi : réparation finie : durée rendue, marque effacée")
    c(Sw.repaired(m, 9999) == nil, "suivi : module jamais rouvert : pas de durée")
    for _, st in ipairs({ "reserve", "defrichage", "fantomes", "chantier", "raccordement", "bloque" }) do
      c(Sw.follow({ state = "fini" }, { state = st }, 1) == true, "suivi : l'état « " .. st .. " » rouvre un module fini")
    end
    for _, st in ipairs({ "attente", "plan", "refuse", "fini" }) do
      c(Sw.follow({ state = "fini" }, { state = st }, 1) == false, "suivi : l'état « " .. st .. " » ne rouvre pas un module fini")
    end
  end
  do
    local q = { ents = {
      { item = "b", built = false }, { item = "a", built = false }, { item = "b", built = false }, { item = "a", built = true },
      { item = "c", built = false, gave_up = true }, { built = false }, { item = "d", built = false, dropped = true } } }
    local todo, pieces = Sw.todo(q)
    c(pieces == 4 and #todo == 2 and todo[1][1] == "b" and todo[1][2] == 2 and todo[2][1] == "a" and todo[2][2] == 1,
      "à refaire : pièces non posées, abandonnées et lâchées exclues, tri par nombre puis par nom")
    c(Sw.items_text(todo) == "bx2,ax1" and Sw.items_text({}) == "" and Sw.items_text(nil) == "", "texte des objets à refaire")
    local long = {}
    for i = 1, 9 do long[i] = { "o" .. i, 10 - i } end
    c(Sw.items_text(long, 3) == "o1x9,o2x8,o3x7,...", "texte des objets : borné")
  end
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
  c(ea.gave_t == 5000 + (Sw.MAX_REBUILD + 1) * 10, "D3 : l'abandon est daté (Sw.select)")
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
  -- Lot INTEG-RECONSTRUCTION (D2) : refus répété d'un fantôme
  c(Sw.refusal_verdict(nil, 5, 3) == "bloque" and Sw.refusal_verdict(0, 5, 3) == "bloque", "D2 : projet jamais rouvert : bloqué comme avant, quelles que soient les reprises")
  c(Sw.refusal_verdict(1, 0, 3) == "bloque" and Sw.refusal_verdict(2, 2, 3) == "bloque", "D2 : projet rouvert avec des reprises restantes : bloqué puis repris")
  c(Sw.refusal_verdict(1, 3, 3) == "abandon" and Sw.refusal_verdict(4, nil, 0) == "abandon", "D2 : projet rouvert aux reprises épuisées : la pièce est abandonnée")
  -- Lot INTEG-RECONSTRUCTION (D3) : abandon levé après Sw.GAVE_KEEP
  do
    local e1 = { gave_up = true, gave_t = 1000 }
    c(Sw.gave_expired(e1, 1000 + Sw.GAVE_KEEP - 1) == false, "D3 : abandon tenu avant la durée")
    c(Sw.gave_expired(e1, 1000 + Sw.GAVE_KEEP) == true, "D3 : abandon levé à la durée")
    c(Sw.gave_expired({ gave_up = true, gave_t = 1000, hand_gave = true }, 1000 + 10 * Sw.GAVE_KEEP) == false, "D3 : retrait à la main : jamais levé")
    c(Sw.gave_expired({ gave_up = true }, 10 * Sw.GAVE_KEEP) == false, "D3 : abandon sans date (sauvegarde d'avant) : jamais levé")
    c(Sw.gave_expired({ gave_t = 1000 }, 10 * Sw.GAVE_KEEP) == false, "D3 : pièce non abandonnée : rien à lever")
    c(Sw.GAVE_KEEP > Sw.FORGET, "D3 : l'abandon dure plus que l'oubli de l'historique")
  end
  -- Lot INTEG-RECONSTRUCTION (D4) : un projet rouvert retient les améliorations
  do
    local q = { reopened = 1, reopened_tick = 5000, state = "reserve", ents = { { item = "a", built = false } } }
    c(Sw.project_holds(q, 5000 + 60) == true, "D4 : projet rouvert à refaire : retient")
    c(Sw.project_holds(q, 5000 + Sw.HOLD_MAX) == true and Sw.project_holds(q, 5000 + Sw.HOLD_MAX + 1) == false, "D4 : ne retient que Sw.HOLD_MAX ticks")
    for _, st in ipairs({ "fantomes", "chantier", "defrichage" }) do
      q.state = st
      c(Sw.project_holds(q, 5100) == true, "D4 : « " .. st .. " » retient")
    end
    for _, st in ipairs({ "fini", "raccordement", "bloque", "refuse", "plan" }) do
      q.state = st
      c(Sw.project_holds(q, 5100) == false, "D4 : « " .. st .. " » ne retient pas")
    end
    q.state = "chantier"
    q.ents[1].built = true
    c(Sw.project_holds(q, 5100) == false, "D4 : plus rien à refaire : ne retient plus")
    q.ents[1].built = false
    q.ents[1].gave_up = true
    c(Sw.project_holds(q, 5100) == false, "D4 : pièce abandonnée : ne retient pas")
    c(Sw.project_holds({ state = "chantier", ents = { { item = "a", built = false } } }, 5100) == false, "D4 : projet jamais rouvert : ne retient pas")
    c(Sw.project_holds({ reopened = 1, state = "chantier", ents = { { item = "a", built = false } } }, 5100) == false, "D4 : sans date de réouverture (murs d'enceinte) : ne retient pas")
    c(Sw.project_holds(nil, 5100) == false, "D4 : projet absent")
  end
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
  { "pas de plafond horaire", "if (used or 0) < Sw.hour_cap(#q.ents, c.class) and", "if true and" },
  { "pas d'abandon", "if (e.rb or 0) >= Sw.MAX_REBUILD then", "if false then" },
  { "danger compté", "if (used or 0) < Sw.hour_cap(#q.ents, c.class) and (not safe or safe(c)) then", "if (used or 0) < Sw.hour_cap(#q.ents, c.class) then" },
  { "plafond des entrées de production = la moitié", "if class == 1 then return math.max(Sw.HOUR_MIN, n or 0) end", "" },
  { "un seul compteur horaire", "local used = c.class == 1 and q.sw_n1 or q.sw_n", "local used = q.sw_n" },
  { "suivi : projet fini rouvert", "if not (m and s and m.state == \"fini\" and Sw.REOPEN_STATES[s.state]) then return false end", "if not (m and s) then return false end" },
  { "suivi : production mesurée gardée", "  m.rate_meas = 0\n", "" },
  { "suivi : compteur de fabrication gardé", "  m.made_prev = nil", "  local _keep = nil" },
  { "suivi : manques non relus", "  m.missing = s.missing or {}\n", "" },
  { "suivi : date de début écrasée", "m.reopened_at = m.reopened_at or tick", "m.reopened_at = tick" },
  { "suivi : marque non effacée", "  m.reopened_at = nil\n", "" },
  { "à refaire : abandonnées comptées", "if not e.built and not e.gave_up and not e.dropped then", "if not e.built then" },
  { "à refaire : tri inversé", "return count[a] > count[b]", "return count[a] < count[b]" },
  { "infra refaite", "if not ty or (skip and skip[ty]) then return nil end", "if not ty then return nil end" },
  { "D2 : jamais d'abandon de la pièce", "if (reopened or 0) > 0 and (retries or 0) >= max_retries then return \"abandon\" end", "" },
  { "D2 : abandon avant les reprises", "(retries or 0) >= max_retries then return \"abandon\"", "(retries or 0) >= 0 then return \"abandon\"" },
  { "D2 : abandon d'un projet jamais rouvert", "if (reopened or 0) > 0 and (retries", "if (retries" },
  { "D3 : date de l'abandon non écrite", "        e.gave_t = tick -- lot INTEG-RECONSTRUCTION (D3) : date de l'abandon (Sw.gave_expired)\n", "" },
  { "D3 : abandon jamais levé", "return tick - e.gave_t >= Sw.GAVE_KEEP", "return false" },
  { "D3 : abandon levé sans attendre", "return tick - e.gave_t >= Sw.GAVE_KEEP", "return true" },
  { "D3 : retrait à la main levé", "if not e.gave_up or e.hand_gave or not e.gave_t then return false end", "if not e.gave_up or not e.gave_t then return false end" },
  { "D3 : abandon sans date levé", "if not e.gave_up or e.hand_gave or not e.gave_t then return false end", "if not e.gave_up or e.hand_gave then return false end" },
  { "D4 : jamais retenu", "return pieces > 0\nend", "return false\nend" },
  { "D4 : retenu sans fin", "if tick - q.reopened_tick > Sw.HOLD_MAX then return false end", "" },
  { "D4 : retenu une fois fini", "and Sw.HOLD_STATES[q.state]) then", ") then" },
  { "D4 : retenu sans pièce à refaire", "return pieces > 0\nend", "return true\nend" },
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
local Rule = require("shared.team.rebuild_sweep")

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

-- 8 bis. Lot REBUILD-SUIVI : journal [FO-REBUILD-ETAT] d'un projet rouvert (toutes les 5 min, puis la fin) ; plafond horaire d'une fonderie détruite
do
  local defs = {}
  for i = 1, 122 do defs[i] = { i <= 80 and "belt" or "asm", 1000 + i, 5 } end
  local f, q = team("forge", "fini", defs)
  q.id, q.spec.key = 6, "fonderie"
  local function etat() local out = {} for _, l in ipairs(logs) do if l:find("FO%-REBUILD%-ETAT%] forge") then out[#out + 1] = l end end return out end
  local t = 20000
  Sweep.step(f, surface, t) -- horloge
  for i = 1, 122 do present[(1000 + i) .. ",5"] = nil end -- tout est détruit
  local reopened = 0
  for _ = 1, 40 do
    t = t + 180
    reopened = reopened + Sweep.step(f, surface, t)
    if t > 20000 + 180 * 3 + Sw.CALM + 180 * 12 then break end
  end
  for _ = 1, 20 do t = t + 180 reopened = reopened + Sweep.step(f, surface, t) end
  check(reopened == 122, "fonderie de 122 pièces toute détruite : toutes rouvertes dans l'heure, pas seulement la moitié (" .. reopened .. ")")
  check(q.state == "reserve" and q.etat_open == true and q.etat_n == 122, "projet rouvert : suivi ouvert, pièces comptées (" .. tostring(q.etat_n) .. ")")
  check(#etat() == 0, "pas de ligne d'état avant 5 minutes")
  q.missing = { { "four", 40 }, { "tapis", 77 } }
  q.reason = "materiaux"
  t = q.etat_next
  Sweep.step(f, surface, t)
  local l = etat()
  check(#l == 1 and l[1]:find("projet 6 %(fonderie%)") and l[1]:find("etat reserve%[materiaux%]") and l[1]:find("122 piece%(s%) a refaire sur 122")
    and l[1]:find("manque au coffre {fourx40,tapisx77}", 1, true), "ligne d'état : projet, état, pièces à refaire, manques (" .. tostring(l[1]) .. ")")
  check(l[1] and l[1]:find("a refaire {item%-belt", 1) and l[1]:find("item%-asmx42") , "ligne d'état : objets à refaire, les plus nombreux d'abord (" .. tostring(l[1]) .. ")")
  Sweep.step(f, surface, t + 180)
  check(#etat() == 1, "une seule ligne par période de 5 minutes")
  Sweep.step(f, surface, t + Rule.ETAT_EVERY)
  check(#etat() == 2, "nouvelle ligne 5 minutes plus tard")
  -- la fin : le plan a tout refait
  for _, e in ipairs(q.ents) do e.built = true end
  q.state = "fini"
  Sweep.step(f, surface, t + Rule.ETAT_EVERY + 180)
  l = etat()
  check(#l == 3 and l[3]:find("REFAIT en") and l[3]:find("122 piece%(s%) rouverte%(s%)") and q.etat_open == nil, "fin de la réparation : ligne « REFAIT » puis suivi fermé")
  Sweep.step(f, surface, t + 3 * Rule.ETAT_EVERY)
  check(#etat() == 3, "projet refait : plus de ligne")
  -- plafond de lignes par équipe
  local f2, q2 = team("plafond", "fini", { { "belt", 7001, 5 } })
  q2.id = 1
  Sweep.step(f2, surface, 5)
  f2.build.sweep.etat_logs = Rule.ETAT_LOGS
  q2.etat_open, q2.etat_next, q2.etat_from = true, 0, 0
  q2.state = "reserve"
  local before = #logs
  Sweep.step(f2, surface, 5 + 180)
  check(#logs == before, "lignes d'état bornées par équipe (" .. Rule.ETAT_LOGS .. ")")
end

-- 10. Lot INTEG-RECONSTRUCTION : exécutant (D2 reprises remises à zéro, D3 abandon levé, D4 retenue des améliorations), sources (D1, D2, D6)
do
  -- D2 : les reprises de la construction ne comptent pas pour la reconstruction
  local f, q = team("integ-d2", "fini", { { "belt", 9001, 5 } })
  q.retries, q.retry_at = 3, nil
  Sweep.step(f, surface, 10)
  present["9001,5"] = nil
  Sweep.step(f, surface, 10 + 180)
  Sweep.step(f, surface, 10 + 360 + Sw.CALM)
  check(q.state == "reserve" and q.retries == 0 and q.retry_at == nil, "D2 : projet rouvert : reprises remises à zéro (" .. tostring(q.retries) .. ")")

  -- D4 : le projet rouvert retient les améliorations (Sweep.hold), puis plus rien une fois refait
  check(Sweep.hold(f, q.reopened_tick + 60) == true, "D4 : l'équipe retient les améliorations tant que le projet rouvert est à refaire")
  check(Sweep.hold(f, q.reopened_tick + Sw.HOLD_MAX + 1) == false, "D4 : plus de retenue après Sw.HOLD_MAX")
  q.ents[1].built = true
  q.state = "fini"
  check(Sweep.hold(f, q.reopened_tick + 60) == false, "D4 : projet refait : plus de retenue")
  check(Sweep.hold({ key = "x" }, 100) == false and Sweep.hold({ key = "x", build = {} }, 100) == false, "D4 : équipe sans projets : rien")

  -- D3 : un abandon est écrit au journal, puis levé après Sw.GAVE_KEEP ; un retrait à la main ne l'est jamais
  local f3, q3 = team("integ-d3", "fini", { { "belt", 9101, 5 }, { "belt", 9201, 5 } })
  Sweep.step(f3, surface, 100)
  local e = q3.ents[1]
  local t0 = 100
  present["9101,5"] = nil
  e.rb, e.rb_t = Sw.MAX_REBUILD, t0
  local before = #logs
  Sweep.step(f3, surface, t0 + 180)
  Sweep.step(f3, surface, t0 + 360 + Sw.CALM)
  check(e.gave_up == true and e.gave_t ~= nil and q3.state == "fini", "D3 : pièce détruite trop souvent : abandonnée, datée, rien rouvert")
  local found = false
  for i = before + 1, #logs do if logs[i]:find("ABANDONNEE") and logs[i]:find("belt") then found = true end end
  check(found, "D3 : l'abandon est écrit au journal [FO-REBUILD]")
  local t1 = e.gave_t + Sw.GAVE_KEEP + 10
  Sweep.step(f3, surface, t1)
  check(e.gave_up == nil and e.gave_t == nil and e.rb == nil, "D3 : abandon levé après " .. Sw.GAVE_KEEP .. " ticks, historique remis à zéro")
  Sweep.step(f3, surface, t1 + 180 + 1)
  Sweep.step(f3, surface, t1 + 360 + Sw.CALM + 2)
  check(not e.built and q3.state == "reserve", "D3 : la pièce abandonnée puis levée est refaite")
  -- retrait à la main
  local e2 = q3.ents[2]
  local t2 = t1 + 360 + Sw.CALM + 2 + 400
  Sweep.note_hand(f3, { valid = true, position = { x = 9201, y = 5 } }, t2)
  present["9201,5"] = nil
  Sweep.step(f3, surface, t2 + 200)
  check(e2.gave_up == true and e2.hand_gave == true, "D3 : retrait à la main : abandon marqué « main »")
  Sweep.step(f3, surface, t2 + 200 + Sw.GAVE_KEEP + 500)
  Sweep.step(f3, surface, t2 + 200 + Sw.GAVE_KEEP + 1000)
  check(e2.gave_up == true and e2.built == true, "D3 : retrait à la main : jamais refait, même après la durée")
end
do
  local src_build, src_rv, src_rs, src_auto = read("script/team/build.lua"), read("script/team/reseau_vivant.lua"), read("script/team/rebuild_sweep.lua"),
    read("script/ai3/automatisation.lua")
  check(src_build:find('Sweep.refusal_verdict(p.reopened, p.retries, Build.RETRIES) == "abandon"', 1, true)
    and src_build:find("e.built, e.dropped = true, true", 1, true), "D2 : build.lua abandonne la pièce refusée d'un projet rouvert (Sweep.refusal_verdict)")
  check(src_rv:find("q.retries, q.retry_at = 0, nil", 1, true) and src_rs:find("q.retries, q.retry_at = 0, nil", 1, true),
    "D2 : les deux réouvertures (relevé, réseau vivant) remettent les reprises à zéro")
  check(src_auto:find("Sweep.goal_for_module(m)", 1, true), "D1 : le suivi du cerveau décide du but « auto » par Sweep.goal_for_module")
  check(read("script/team/reconstruction.lua"):find("Sweep.hold(f, game.tick)", 1, true), "D4 : Recon.hold_upgrades lit aussi les projets rouverts")
  check(src_build:find("refresh_missing(f, p)", 1, true) and src_build:find("p.miss_next = tick + 60", 1, true), "D6 : build.lua relit les manques d'un projet rouvert hors « reserve »")
end
-- D6 : refresh_missing extrait de build.lua (texte réel), joué avec un coffre simulé
do
  local src = read("script/team/build.lua")
  local a = assert(src:find("local function needs_of(p)", 1, true))
  local b = assert(src:find("--- Stock LIBRE du coffre", 1, true))
  local c1 = assert(src:find("--- Lot INTEG-RECONSTRUCTION (D6)", 1, true))
  local d = assert(src:find("local function release(f, p)", 1, true))
  local chunk = src:sub(a, b - 1) .. "\n" .. src:sub(c1, d - 1) .. "\nreturn refresh_missing, needs_of"
  local chest, freed = {}, nil
  local env = {
    ipairs = ipairs, pairs = pairs, math = math, table = table, type = type,
    bump = function(t, k, n) t[k] = (t[k] or 0) + (n or 1) end,
    sorted_keys = function(t) local ks = {} for k in pairs(t) do ks[#ks + 1] = k end table.sort(ks) return ks end,
    Stock = { count = function(_, it) return chest[it] or 0 end },
    free_stock = function() return freed or chest end,
  }
  local fn = assert(load(chunk, "=build_d6", "t", env))
  local refresh = fn()
  local p = { stock = { belt = 1 }, ents = {
    { item = "belt", built = false }, { item = "belt", built = false }, { item = "belt", built = false },
    { item = "furnace", built = false }, { item = "furnace", built = true }, { item = "pole", built = false } } }
  chest = { belt = 1, furnace = 0, pole = 5 }
  refresh({}, p)
  local m = {}
  for _, x in ipairs(p.missing) do m[x[1]] = x[2] end
  check(#p.missing == 2 and m.belt == 1 and m.furnace == 1 and m.pole == nil, "D6 : manques = besoin - réservé - coffre libre (belt 3-1-1, four 1, poteau couvert)")
  check(chest.belt == 1 and chest.pole == 5 and p.stock.belt == 1, "D6 : rien n'est retiré au coffre ni ajouté au stock du projet")
  freed = { belt = 0, furnace = 3, pole = 5 }
  chest = { belt = 9, furnace = 3, pole = 5 }
  refresh({}, p)
  m = {}
  for _, x in ipairs(p.missing) do m[x[1]] = x[2] end
  check(#p.missing == 1 and m.belt == 2, "D6 : le stock LIBRE compte, pas le coffre brut (objets promis à une tâche)")
  for _, e in ipairs(p.ents) do e.built = true end
  refresh({}, p)
  check(#p.missing == 0, "D6 : plus rien à refaire : aucun manque")
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
