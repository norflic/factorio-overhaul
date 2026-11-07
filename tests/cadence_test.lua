--[[
  Lot X10-S10 « factions lointaines plus lentes » : banc HORS JEU de shared/faction/cadence.lua. Lancement, depuis la racine du mod :
    lua5.2 tests/cadence_test.lua
  Sections :
    1. zone : boîte du QG et des avant-postes élargie de Cd.NEAR ; points invalides ignorés ; sans point : nil ;
    2. causes de réveil, une par une, et leurs bornes ;
    3. garde fermée : zone ou joueurs inconnus ne ralentissent jamais ; votre équipe garde son rythme ;
    4. créneaux : une pensée sur deux quand tout est calme (Cd.SLOW), aucune sautée quand une cause tient ;
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
    local s = { box = box, players = { { x = 5000, y = 5000 } } }
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
  end

  section("3. garde fermee, votre equipe")
  do
    local up, why = Cd.awake({ players = {} }, 0)
    check(up and why == "zone inconnue", "3 : zone inconnue : rythme normal")
    up, why = Cd.awake({ box = box }, 0)
    check(up and why == "joueurs inconnus", "3 : joueurs inconnus : rythme normal")
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
    check(Cd.skip({}, calm(), 300) == false, "4 : premiere pensee jamais sautee")
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
      local s = { box = box, players = { player } }
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
    local up = Cd.wake({ asleep = false }, { box = box, players = { { x = 0, y = 0 } } }, 0)
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
    if not quiet then print(string.format("   Cd.zone (30 points) : %d instructions ; Cd.awake (2 joueurs, calme) : %d ; Cd.wake : %d", i_zone, i_awake, i_wake)) end
    check(i_awake < 300 and i_wake < 350, "7 : le guet d'une faction sous 350 instructions par tick (" .. i_wake .. ")")
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
  { "premiere pensee sautee", { 'if type(st.last) ~= "number" then return false, "premiere pensee" end', 'if type(st.last) ~= "number" then return true, "premiere pensee" end' } },
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
