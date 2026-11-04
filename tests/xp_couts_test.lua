--[[
  Lot XP-COUTS (4/11) : banc hors jeu de la règle des packs C.packs (shared/content/crafts.lua). Lua 5.2, depuis la racine du mod :
      lua5.2 tests/xp_couts_test.lua
  Décision du DC (4/11, 19 h 48, QCM) : « Oui, tous les packs de l'âge ». C.packs(k) = tous les packs vanilla apparus à l'âge k ou avant.
    §1 la règle, âge par âge (1 à 15) : liste figée ; seuls les âges 9 et 13 changent par rapport à l'ancienne règle (fenêtre X0) ;
    §2 toutes les technologies EN JEU dont les packs passent par C.packs (crafts, robots, robot_parts, bauxite, géothermie, combustible
       usé, étain, calcul, calcul v2, Bourdon, expérimentaux) : les 6 attendues changent comme prévu, AUCUNE autre ne change ;
       le relais Cp.packs (calcul) rend la même chose qu'avant pour toutes ses technologies ;
    §3 mutants : l'ancienne règle, une règle trop généreuse et une règle décalée d'un âge sont refusées.
]]

package.path = "./?.lua;" .. package.path

local X = require("shared.content.epochs")
local C = require("shared.content.crafts")
local Ro = require("shared.content.robots")
local P = require("shared.content.robot_parts")
local Bx = require("shared.content.bauxite")
local Gt = require("shared.content.geothermal")
local F = require("shared.content.spent_fuel")
local Sn = require("shared.content.tin")
local Cp = require("shared.content.compute")
local Cv = require("shared.content.compute_chain")
local Bo = require("shared.robots.bourdon")
local Xp = require("shared.robots.experimentaux")

local pass, fail, msgs = 0, 0, {}
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

local ORDER = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
                "production-science-pack", "utility-science-pack", "space-science-pack" }
local LETTER = { "R", "V", "M", "B", "P", "J", "S" }
local function letters(packs)
  local o = {}
  for _, p in ipairs(packs) do
    local l = "?"
    for i, q in ipairs(ORDER) do if q == p then l = LETTER[i] end end
    o[#o + 1] = l
  end
  return table.concat(o)
end

--- L'ANCIENNE règle (shared/content/crafts.lua avant le lot XP-COUTS, main c039712c), recopiée telle quelle : témoin.
local function old_packs(k)
  local want = {}
  for _, p in ipairs(X.pack_window(k, { military = true })) do want[p] = true end
  local top = 0
  for i, p in ipairs(ORDER) do if want[p] then top = i end end
  local out = {}
  for i = 1, top do
    local p = ORDER[i]
    if p ~= "military-science-pack" or want[p] or k >= 3 then out[#out + 1] = p end
  end
  return out
end
--- L'ancien relais du calcul : C.packs(math.min(k, 12)) avec l'ancienne règle.
local function old_cp_packs(k) return old_packs(math.min(k, 12)) end

-- §1 la règle, âge par âge
local WANT_AGE = { "R", "RV", "RVM", "RVMB", "RVMB", "RVMBP", "RVMBP", "RVMBP", "RVMBP", "RVMBPJ", "RVMBPJ", "RVMBPJ", "RVMBPJ",
                   "RVMBPJS", "RVMBPJS" }
local CHANGED_AGES = { [9] = true, [13] = true }

--- Les technologies en jeu qui passent par C.packs : { src, name, epoch, cp = bool (relais du calcul) }.
local function techs()
  local rows = {}
  local function add(src, name, epoch, cp) rows[#rows + 1] = { src = src, name = name, epoch = epoch, cp = cp or false } end
  for _, t in ipairs(C.TECHS) do add("crafts", t.name, t.epoch) end
  for _, t in ipairs(Ro.TECHS) do add("robots", t.name, t.epoch) end
  for _, t in ipairs(P.TECHS) do add("robot_parts", t.name, t.epoch) end
  for _, t in ipairs(Bx.TECHS) do add("bauxite", t.name, t.epoch) end
  add("geothermal", Gt.TECH.name, Gt.TECH.epoch)
  add("spent_fuel", F.TECH.name, F.TECH.epoch)
  for _, t in ipairs(Sn.TECHS) do add("tin", t.name, t.epoch) end
  for _, t in ipairs(Cp.TECHS) do add("compute", t.name, t.epoch, true) end
  for _, t in ipairs(Cv.TECHS) do if t.new then add("compute_v2", t.name, t.epoch, true) end end -- les autres retouchent une technologie
  add("bourdon", Bo.TECH.name, Bo.TECH.epoch)
  for _, r in ipairs(Xp.ROBOTS) do add("experimentaux", r.tech, r.age) end
  for _, r in ipairs(Xp.GEANTS) do add("experimentaux", r.tech, r.age) end
  return rows
end
local TECHS = techs()

-- Les 6 technologies qui changent, et comment (inventaire du 4/11, fo-logs/2026-11-04_XP-COUTS/PROPOSITION.md §1).
local WANT_CHANGE = {
  ["fo-xp-demi-vie"] = "RVMBP", ["fo-robot-mortar"] = "RVMBP", ["fo-spent-fuel"] = "RVMBP",
  ["fo-xp-ixion"] = "RVMBPJ", ["fo-xp-veilleuse"] = "RVMBPJ", ["fo-robot-gantry"] = "RVMBPJ",
}

--- La suite pour une règle `packs` (réelle ou mutante) et son relais du calcul `cp_packs`. Rend le nombre d'échecs, et compte.
local function suite(packs, cp_packs, report)
  local bad = 0
  local function chk(c, m)
    if not c then bad = bad + 1 end
    if report then check(c, m) end
  end
  for k = 1, 15 do
    chk(letters(packs(k)) == WANT_AGE[k], string.format("§1 âge %d : %s, attendu %s", k, letters(packs(k)), WANT_AGE[k]))
    chk((letters(packs(k)) ~= letters(old_packs(k))) == (CHANGED_AGES[k] == true),
      string.format("§1 âge %d : %s par rapport à l'ancienne règle", k, CHANGED_AGES[k] and "change" or "ne change pas"))
  end
  local changed, same = 0, 0
  for _, t in ipairs(TECHS) do
    local now = letters(t.cp and cp_packs(t.epoch) or packs(t.epoch))
    local before = letters(t.cp and old_cp_packs(t.epoch) or old_packs(t.epoch))
    local want = WANT_CHANGE[t.name]
    if want then
      chk(before ~= want and now == want, string.format("§2 %s (%s, âge %d) : %s -> %s, attendu %s", t.name, t.src, t.epoch, before, now, want))
      changed = changed + 1
    else
      chk(now == before, string.format("§2 %s (%s, âge %d) : inchangé, %s -> %s", t.name, t.src, t.epoch, before, now))
      same = same + 1
    end
  end
  chk(changed == 6, "§2 les 6 technologies attendues sont présentes : " .. changed)
  return bad, changed, same
end

local _, changed, same = suite(C.packs, Cp.packs, true)
check(#TECHS >= 59, "§2 inventaire : au moins les 59 technologies du 4/11 (" .. #TECHS .. ")")

-- §3 mutants (règles de remplacement) : chacun doit faire échouer la suite
local MUTANTS = {
  { "ancienne règle (fenêtre X0)", old_packs, old_cp_packs },
  { "tous les packs à tout âge", function() return ORDER end, function() return ORDER end },
  { "règle décalée d'un âge", function(k) return C.packs(math.max(1, k - 1)) end, function(k) return C.packs(math.max(1, k - 1)) end },
  { "relais du calcul sans l'âge 13", C.packs, function(k) return C.packs(math.min(k, 12) - 1) end },
  { "spatial dès l'âge 13", function(k) return C.packs(k >= 13 and 14 or k) end, Cp.packs },
}
local kept = {}
for _, m in ipairs(MUTANTS) do
  local bad = suite(m[2], m[3], false)
  if bad == 0 then kept[#kept + 1] = m[1] end
end
check(#kept == 0, "§3 mutants NON refusés : " .. table.concat(kept, " ; "))

for _, m in ipairs(msgs) do print("[XP-COUTS] ECHEC " .. m) end
print(string.format("[XP-COUTS] technologies passant par C.packs : %d ; changées : %d ; inchangées : %d ; mutants refusés : %d sur %d",
  #TECHS, changed, same, #MUTANTS - #kept, #MUTANTS))
print(string.format("[XP-COUTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
