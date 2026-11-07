--[[
  Lot X10-S10 « factions lointaines plus lentes » : banc HORS JEU de shared/faction/cadence.lua. Lancement, depuis la racine du mod :
    lua5.2 tests/cadence_test.lua
  Sections :
    1. zone : boîte du QG et des avant-postes élargie de Cd.NEAR ; points invalides ignorés ; sans point : nil ;
    2. causes de réveil, une par une, et leurs bornes (coup reçu sur une tourelle compris) ;
    2 bis. armée dehors (Cd.army_out) : groupes, attaque préparée, nettoyage et expédition de l'IA3, alerte et regroupement de la
       prévision ; garde fermée sur un état de forme inconnue ;
    3. garde fermée : zone ou joueurs inconnus ne ralentissent jamais ; votre équipe garde son rythme ;
    4. créneaux : une pensée sur deux quand tout est calme (Cd.SLOW), aucune sautée quand une cause tient ;
    4 bis. créneau qui suit un réveil (Cd.recent) : jamais deux pensées à moins d'une période, quel que soit le tick du réveil ;
    5. réveil : une faction endormie repense au tick qui suit l'arrivée du joueur (simulation tick par tick) ;
    6. déterminisme ;
    7. coût en INSTRUCTIONS (debug.sethook) ;
    8. mutants : chaque règle retirée fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end

local PATH = "shared/faction/cadence.lua"
local function load_cd(mutate)
  local src = slurp(PATH)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. PATH)
  if not fn then return nil, err end
  return fn()
end

local function run_all(Cd)
  local box = Cd.zone({ { x = 0, y = 0 }, { x = 100, y = -50 } }, Cd.NEAR)
  local function calm(extra)
    local s = { box = box, players = { { x = 5000, y = 5000 } }, army_out = false }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
  end

  section("1. zone")
  do
    check(box.x0 == -Cd.NEAR and box.x1 == 100 + Cd.NEAR and box.y0 == -50 - Cd.NEAR and box.y1 == Cd.NEAR, "1 : boite des points elargie de NEAR")
    check(Cd.zone({}, 10) == nil and Cd.zone(nil, 10) == nil, "1 : sans point : nil")
    local b2 = Cd.zone({ { x = "a", y = 1 }, { 3, 4 } }, 1)
    check(b2 and b2.x0 == 2 and b2.x1 == 4 and b2.y0 == 3 and b2.y1 == 5, "1 : point invalide ignore, {x, y} en liste accepte")
  end

  section("2. causes de reveil")
  do
    local T = 10000
    local up, why = Cd.awake(calm(), T)
    check(up == false and why == "loin et calme", "2 : loin et calme : ralentie")
    up, why = Cd.awake(calm({ threatened_until = T + 1 }), T)
    check(up and why == "menace", "2 : menace en cours")
    check(not Cd.awake(calm({ threatened_until = T }), T), "2 : menace finie au tick meme : plus de menace")
    up, why = Cd.awake(calm({ attack_t = T - Cd.ALERT + 1 }), T)
    check(up and why == "attaque", "2 : attaque recente")
    check(not Cd.awake(calm({ attack_t = T - Cd.ALERT }), T), "2 : attaque de plus de ALERT ticks : oubliee")
    up, why = Cd.awake(calm({ lost_t = T - 10 }), T)
    check(up and why == "perte", "2 : perte recente")
    check(not Cd.awake(calm({ lost_t = T - Cd.ALERT }), T), "2 : perte ancienne : oubliee")
    up, why = Cd.awake(calm({ base_alert = true }), T)
    check(up and why == "ennemi pres du QG", "2 : ennemi pres du QG")
    up, why = Cd.awake(calm({ players = { { x = 9999, y = 0 }, { x = 100 + Cd.NEAR, y = -50 } } }), T)
    check(up and why == "joueur proche", "2 : un des joueurs dans la zone (bord compris)")
    check(not Cd.awake(calm({ players = { { x = 100 + Cd.NEAR + 1, y = 0 } } }), T), "2 : joueur juste hors de la zone : loin")
    check(not Cd.awake(calm({ players = {} }), T), "2 : aucun joueur connecte : loin")
    up, why = Cd.awake(calm({ army_out = true }), T)
    check(up and why == "armee dehors", "2 : une armee dehors (attaque, retour, eclaireur, attaque preparee) : rythme normal")
    up, why = Cd.awake(calm({ hit_t = T - Cd.ALERT + 1 }), T)
    check(up and why == "attaque", "2 : coup recu d'une force adverse (tourelle comprise, f.hit_t) recent : attaque")
    check(not Cd.awake(calm({ hit_t = T - Cd.ALERT }), T), "2 : coup de plus de ALERT ticks : oublie")
  end

  section("2 bis. armee dehors : groupes, attaque preparee, IA3 (nettoyage, expedition, prevision)")
  do
    local o, w = Cd.army_out({})
    check(o == false and w == nil, "2 bis : rien dehors : armee rentree")
    o = Cd.army_out({ groups = {}, route_pending = false, armee = { alert = false } })
    check(o == false, "2 bis : aucun groupe, prevision sans alerte ni regroupement : armee rentree")
    o, w = Cd.army_out({ groups = { [3] = { n = 4 } } })
    check(o and w == "groupe arme", "2 bis : un groupe arme (attaque, retour, eclaireur) : dehors")
    o, w = Cd.army_out({ route_pending = { ticket = 1 } })
    check(o and w == "attaque preparee", "2 bis : attaque preparee (itineraire demande) : dehors")
    for _, ph in ipairs({ "rassemble", "attaque", "phase inconnue" }) do
      o, w = Cd.army_out({ nt = { phase = ph } })
      check(o and w == "nettoyage", "2 bis : operation de nettoyage d'un site en phase « " .. ph .. " » : dehors")
    end
    o, w = Cd.army_out({ clearing = { x = 1, y = 2, ids = { 5 } } })
    check(o and w == "expedition", "2 bis : expedition contre un champ de nids : dehors")
    o, w = Cd.army_out({ armee = { alert = true } })
    check(o and w == "alerte", "2 bis : armee de la prevision en alerte : dehors")
    o, w = Cd.army_out({ armee = { alert = false, muster = { x = 0, y = 0 } } })
    check(o and w == "regroupement", "2 bis : armee de la prevision au regroupement : dehors")
    check(Cd.army_out(nil) == true, "2 bis : entree absente : dehors (garde fermee)")
    check(Cd.army_out({ groups = 5 }) == true, "2 bis : groupes de forme inconnue : dehors (garde fermee)")
    check(Cd.army_out({ armee = "?" }) == true, "2 bis : prevision de forme inconnue : dehors (garde fermee)")
    check(Cd.army_out({ armee = { alert = "oui" } }) == true, "2 bis : alerte ni vraie ni fausse : dehors (garde fermee)")
  end

  section("3. garde fermee, votre equipe")
  do
    local up, why = Cd.awake({ players = {} }, 0)
    check(up and why == "zone inconnue", "3 : zone inconnue : rythme normal")
    up, why = Cd.awake({ box = box, army_out = false }, 0)
    check(up and why == "joueurs inconnus", "3 : joueurs inconnus : rythme normal")
    up, why = Cd.awake({ box = box, players = {} }, 0)
    check(up and why == "armee inconnue", "3 : etat de l'armee non dit : rythme normal")
    up, why = Cd.awake({ is_player = true, box = box, players = {} }, 0)
    check(up and why == "votre equipe", "3 : votre equipe garde son rythme")
    check(Cd.skip({ last = 0 }, { is_player = true, box = box, players = {} }, 300) == false, "3 : votre equipe ne saute jamais")
  end

  section("4. creneaux")
  do
    local function slots(s_of, n)
      local st, thought = {}, {}
      for k = 0, n do
        local tick = k * 300
        local skip = Cd.skip(st, s_of(tick), tick)
        if not skip then st.last = tick thought[#thought + 1] = tick end
      end
      return thought
    end
    local t1 = slots(function() return calm() end, 8)
    check(#t1 == 5 and t1[1] == 0 and t1[2] == 600 and t1[5] == 2400, "4 : calme : une pensee sur deux (" .. table.concat(t1, " ") .. ")")
    check(Cd.SLOW == 600, "4 : Cd.SLOW vaut 600 ticks (decision du DC)")
    local t2 = slots(function(tick) return calm({ threatened_until = tick + 900 }) end, 8)
    check(#t2 == 9, "4 : menace : aucune pensee sautee")
    local t3 = slots(function(tick) return calm({ army_out = tick >= 600 and tick < 1500 }) end, 8)
    check(table.concat(t3, " ") == "0 600 900 1200 1800 2400", "4 : armee dehors de 600 a 1500 : aucune pensee sautee pendant ce temps (" .. table.concat(t3, " ") .. ")")
    check(Cd.skip({}, calm(), 300) == false, "4 : premiere pensee jamais sautee")
  end

  section("4 bis. creneau qui suit un reveil (Cd.recent) : jamais deux pensees a moins d'une periode")
  do
    check(Cd.recent({ last = 100 }, 399, 300) == true and Cd.recent({ last = 100 }, 400, 300) == false, "4 bis : moins d'une periode : creneau laisse ; une periode : la faction pense")
    check(Cd.recent({ last = 100 }, 100, 300) == true, "4 bis : meme tick : creneau laisse")
    check(Cd.recent({}, 0, 300) == false and Cd.recent({ last = 0 }, 10, nil) == false, "4 bis : sans derniere pensee ou sans periode : la faction pense")
    -- Comme au runtime : créneau (Cd.recent, puis Cd.skip) aux multiples de 300, puis guet (Cd.wake) au même tick. La faction dort au
    -- créneau de 900 ; une menace naît à 900 + k et tient jusqu'à la fin.
    for _, k in ipairs({ 1, 150, 297, 298, 299 }) do
      local st, thinks = {}, {}
      local A = 900 + k
      for tick = 0, 2400 do
        local s = calm({ threatened_until = tick >= A and 1e9 or nil })
        if tick % 300 == 0 and not Cd.recent(st, tick, 300) then
          if Cd.skip(st, s, tick) then st.asleep = true else st.asleep, st.last = false, tick thinks[#thinks + 1] = tick end
        end
        if Cd.wake(st, s, tick) then st.asleep, st.last = false, tick thinks[#thinks + 1] = tick end
      end
      local min_gap, after = math.huge, nil
      for i = 2, #thinks do
        local g = thinks[i] - thinks[i - 1]
        if g < min_gap then min_gap = g end
        if thinks[i - 1] == A then after = g end
      end
      check(thinks[3] == A and min_gap >= 300 and after and after <= 599,
        string.format("4 bis : reveil a 900 + %d : pense a %d, puis aucun ecart sous 300 (min %s), %s ticks apres le reveil (%s)", k, A,
          tostring(min_gap), tostring(after), table.concat(thinks, " ")))
    end
  end

  section("5. reveil au tick suivant")
  do
    -- Créneaux toutes les 300 ticks ; le joueur entre dans la zone au tick 950, juste après le créneau sauté de 900.
    local st = {}
    local thinks = {}
    local player = { x = 5000, y = 5000 }
    local pending
    for tick = 0, 1300 do
      if tick == 950 then player = { x = 50, y = 0 } end
      local s = { box = box, players = { player }, army_out = false }
      if pending and tick == pending then
        st.asleep, st.last, pending = false, tick, nil
        thinks[#thinks + 1] = tick
      elseif tick % 300 == 0 then
        if Cd.skip(st, s, tick) then st.asleep = true else st.asleep, st.last = false, tick thinks[#thinks + 1] = tick end
      end
      if not pending and Cd.wake(st, s, tick) then pending = tick + 1 end
    end
    check(thinks[1] == 0 and thinks[2] == 600 and thinks[3] == 951, "5 : endormie a 900, joueur a 950 : repense a 951 (" .. table.concat(thinks, " ") .. ")")
    check(thinks[4] == 1200, "5 : puis au rythme normal (" .. tostring(thinks[4]) .. ")")
    local up = Cd.wake({ asleep = false }, { box = box, players = { { x = 0, y = 0 } }, army_out = false }, 0)
    check(up == false, "5 : une faction eveillee n'est pas reveillee (rien a faire)")
    check(Cd.wake({ asleep = true }, calm(), 0) == false, "5 : endormie et calme : reste endormie")
  end

  section("6. determinisme")
  do
    local s = calm({ players = { { x = 0, y = 0 }, { x = 1, y = 1 } } })
    local a1, w1 = Cd.awake(s, 5)
    local a2, w2 = Cd.awake(s, 5)
    check(a1 == a2 and w1 == w2, "6 : meme entree, meme sortie")
  end

  section("7. cout en instructions (debug.sethook)")
  do
    local function instr(fn)
      local c = 0
      debug.sethook(function() c = c + 1 end, "", 1)
      fn()
      debug.sethook()
      return c
    end
    local pts = {}
    for i = 1, 30 do pts[i] = { x = i * 7, y = -i * 3 } end
    local i_zone = instr(function() Cd.zone(pts, Cd.NEAR) end)
    local s = calm({ players = { { x = 9000, y = 0 }, { x = 8000, y = 1 } } })
    local i_awake = instr(function() Cd.awake(s, 100) end)
    local i_wake = instr(function() Cd.wake({ asleep = true }, s, 100) end)
    local i_army = instr(function() Cd.army_out({ groups = {}, armee = { alert = false } }) end)
    if not quiet then print(string.format("   Cd.zone (30 points) : %d instructions ; Cd.awake (2 joueurs, calme) : %d ; Cd.wake : %d ; Cd.army_out (rentree) : %d", i_zone, i_awake, i_wake, i_army)) end
    check(i_awake < 300 and i_wake < 350, "7 : le guet d'une faction sous 350 instructions par tick (" .. i_wake .. ")")
    check(i_army < 120, "7 : Cd.army_out sous 120 instructions (" .. i_army .. ")")
  end
end

local Cd0 = assert(load_cd())
run_all(Cd0)

section("8. mutants")
local MUTANTS = {
  { "jamais reveillee", { "  local up, why = Cd.awake(s, tick)\n  return up, why", "  local up, why = Cd.awake(s, tick)\n  return false, why" } },
  { "menace ignoree", { 'if type(s.threatened_until) == "number" and tick < s.threatened_until then return true, "menace" end', "" } },
  { "attaque ignoree", { 'if type(s.attack_t) == "number" and tick - s.attack_t < Cd.ALERT then return true, "attaque" end', "" } },
  { "perte ignoree", { 'if type(s.lost_t) == "number" and tick - s.lost_t < Cd.ALERT then return true, "perte" end', "" } },
  { "ennemi pres du QG ignore", { 'if s.base_alert then return true, "ennemi pres du QG" end', "" } },
  { "joueur proche ignore", { 'inside(s.box, x, y) then return true, "joueur proche" end', 'false then return true, "joueur proche" end' } },
  { "zone inconnue ralentit (garde ouverte)", { 'if type(s.box) ~= "table" then return true, "zone inconnue" end', 'if type(s.box) ~= "table" then return false, "zone inconnue" end' } },
  { "votre equipe ralentie", { 'if s.is_player then return true, "votre equipe" end', "" } },
  { "saute toujours (SLOW ignore)", { "if tick - st.last >= Cd.SLOW then return false, why end", "" } },
  { "zone sans elargissement", { "local d = near or Cd.NEAR", "local d = 0" } },
  { "armee dehors ignoree", { 'if s.army_out ~= false then return true, s.army_out == true and "armee dehors" or "armee inconnue" end', "" } },
  { "armee inconnue lue comme rentree (garde ouverte)", { "if s.army_out ~= false then", "if s.army_out == true then" } },
  { "premiere pensee sautee", { 'if type(st.last) ~= "number" then return false, "premiere pensee" end', 'if type(st.last) ~= "number" then return true, "premiere pensee" end' } },
  -- Revue de 87ac84fe (trois corrections) :
  { "coup recu (tourelle) ignore", { 'if type(s.hit_t) == "number" and tick - s.hit_t < Cd.ALERT then return true, "attaque" end', "" } },
  { "nettoyage IA3 ignore", { 'if a.nt ~= nil then return true, "nettoyage" end', "" } },
  { "expedition IA3 ignoree", { 'if a.clearing ~= nil then return true, "expedition" end', "" } },
  { "alerte de la prevision ignoree", { 'if ar.alert ~= nil and ar.alert ~= false then return true, "alerte" end', "" } },
  { "regroupement de la prevision ignore", { 'if ar.muster ~= nil then return true, "regroupement" end', "" } },
  { "groupes armes ignores", { 'if next(g) ~= nil then return true, "groupe arme" end', "" } },
  { "attaque preparee ignoree", { 'if a.route_pending ~= nil and a.route_pending ~= false then return true, "attaque preparee" end', "" } },
  { "alerte inconnue lue comme fausse (garde ouverte)", { "if ar.alert ~= nil and ar.alert ~= false then", "if ar.alert == true then" } },
  { "prevision inconnue lue comme rentree (garde ouverte)", { 'if type(ar) ~= "table" then return true, "armee inconnue" end', 'if type(ar) ~= "table" then return false, nil end' } },
  { "pensee recente ignoree (garde du meme tick seule)", { "tick - st.last < period", "tick - st.last < 1" } },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local mod, err = load_cd(m[2])
  local dead
  if not mod then
    quiet = false
    check(false, "mutant '" .. m[1] .. "' : " .. tostring(err))
    quiet = true
    dead = false
  else
    local p0, f0 = passes, failures
    local okrun, e = pcall(run_all, mod)
    local nf = failures - f0
    dead = (not okrun) or nf > 0
    passes, failures = p0, f0
    quiet = false
    print(string.format("   %s : %s", m[1], (not okrun) and ("PLANTAGE " .. tostring(e)) or (nf .. " controle(s) en echec")))
    quiet = true
  end
  if dead then killed = killed + 1 else
    quiet = false
    check(false, "mutant SURVIVANT : " .. m[1])
    quiet = true
  end
end
quiet = false
print(string.format("   mutants refuses : %d / %d", killed, #MUTANTS))
check(killed == #MUTANTS, "tous les mutants sont refuses")

print(string.format("[CADENCE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
