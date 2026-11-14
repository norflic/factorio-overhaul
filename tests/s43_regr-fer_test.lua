--[[
  Sprint s43 (regr-fer) : la levée « au calme » de la retenue de la pile (shared/ai3/pile.lua, lot S42-UPGRADES) n'agit qu'après
  Pi.CALM_AFTER ticks d'attente CONTINUE. Banc s43-parite-seule, graine 271828182 : en 0.7.97 la retenue tombait à la 1re pensée,
  le centre s'ouvrait en projet à 0,3 min et chaque faction perdait 21 à 40 % de son fer à 60 min.
    1. poste qui attend sa matière, au calme, 1re pensée : l'amélioration reste retenue (règle d'avant le lot S42-UPGRADES) ;
    2. même poste après Pi.CALM_AFTER ticks de calme continu : la retenue est levée (règle du lot S42-UPGRADES) ;
    3. un danger mesuré entre-temps remet le compte à zéro ; un poste revenu à son minimum aussi ;
    4. MUTANT : sans le délai (Pi.CALM_AFTER = 0), la 1re pensée lève la retenue : vu.
  Usage : lua5.2 tests/s43_regr-fer_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local Pi = require("shared.ai3.pile")

local pass, fail = 0, 0
local function check(c, m)
  if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end
end

local IRON = "iron-plate" -- donnée du banc (la règle n'en nomme aucune)
local function sig_of(danger, have)
  return { danger = danger, posts = { { id = 1, have = have or 0, want = 1, why = "manque", raw = { [IRON] = 34 }, claim = {} } },
    raw_need = { [IRON] = { n = 34, prio = 90 } }, sources = { [IRON] = true }, inputs = {} }
end
local W = Pi.CALM_AFTER

-- 1. Première pensée au calme : retenue.
local st = Pi.update(Pi.new(), sig_of(false), 600)
check(st.hold == true and st.top == Pi.ADAPTER, "1. 1re pensée au calme : l'amélioration reste retenue")
-- 2. Calme continu au-delà du délai : levée.
st = Pi.update(st, sig_of(false), 600 + W - 1)
check(st.hold == true, "2. calme depuis W-1 ticks : encore retenue")
st = Pi.update(st, sig_of(false), 600 + W)
check(st.hold == false and st.top == Pi.AMELIORER, "2. calme depuis W ticks : retenue levée")
-- 3. Danger mesuré : remise à zéro.
st = Pi.update(Pi.new(), sig_of(false), 0)
st = Pi.update(st, sig_of(true), W / 2)
st = Pi.update(st, sig_of(false), W)
check(st.hold == true, "3. danger mesuré entre-temps : le compte repart (retenue)")
st = Pi.update(st, sig_of(false), 2 * W)
check(st.hold == false, "3. puis W ticks de calme : levée")
st = Pi.update(Pi.new(), sig_of(false), 0)
st = Pi.update(st, sig_of(false, 1), W / 2)
st = Pi.update(st, sig_of(false), W)
check(st.hold == true, "3. poste revenu à son minimum entre-temps : le compte repart")
-- 4. Mutant.
Pi.CALM_AFTER = 0
st = Pi.update(Pi.new(), sig_of(false), 600)
check(st.hold == false, "4. MUTANT sans délai : la 1re pensée lève la retenue (vu)")
Pi.CALM_AFTER = W

print(string.format("[S43-REGR-FER] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
