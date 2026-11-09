--[[
  Lot VOIE-AVANT-FOURS : banc HORS JEU de Sa.link_prio (shared/team/champ_saut.lua) et de son branchement (script/team/champ.lua, Champ.links_step).
  Lancement : lua5.2 tests/voie_avant_fours_test.lua (depuis la racine du mod).
  Cas mesuré (candidat 1d7c6218, graine 123456789, Normal, votre équipe) : bande -37 (projet 8, 46 fours, 804 entités) finie à 51,9 min ; son réseau du
  charbon lié (projet 9, 344 entités, demandé à la priorité de la bande) fini à 71,8 min : les fours sans voie.
]]
package.path = "./?.lua;" .. package.path
local Sa = require("shared.team.champ_saut")
local passes, failures = 0, 0
local QUIET = false
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1 if not QUIET then print("  ECHEC : " .. m) end end end

local function body()
  QUIET = true
  local f0 = failures
  local base = 52
  check(Sa.link_prio(base, nil) == base, "v1 bande absente : priorite de la demande")
  check(Sa.link_prio(base, "refuse") == base, "v2 bande refusee : priorite de la demande")
  check(Sa.link_prio(base, "reserve") == base + Sa.LINK_ALIVE, "v3 bande vivante (reserve) : un rang devant les soeurs")
  check(Sa.link_prio(base, "chantier") == base + Sa.LINK_ALIVE, "v4 bande au chantier : un rang devant")
  check(Sa.link_prio(base, "fini") == base + Sa.LINK_DONE, "v5 bande finie : ses fours attendent la voie, trois rangs")
  check(Sa.link_prio(base, "fini") > Sa.link_prio(base, "chantier"), "v6 finie > au chantier")
  check(Sa.link_prio(base, "chantier") > base, "v7 vivante > demande")
  check(Sa.link_prio(54, "fini") == Sa.LINK_CAP, "v8 plafond tenu")
  check(Sa.link_prio(Sa.LINK_CAP + 10, "fini") == Sa.LINK_CAP + 10, "v9 une demande deja au-dessus du plafond n'est jamais baissee")
  check(Sa.link_prio(base, "fini") + 30 < 90, "v10 la tache d'un fantome (priorite + 30) reste sous l'urgence (90)")
  check(Sa.LINK_CAP + 30 <= 85, "v11 la tache d'un fantome ne passe pas la garnison (85)")
  local on = Sa.LINK_ON
  Sa.LINK_ON = false
  check(Sa.link_prio(base, "fini") == base, "v12 interrupteur eteint : comme avant")
  Sa.LINK_ON = on
  QUIET = false
  return failures - f0
end
print("== regle")
body()
local c = 0
debug.sethook(function() c = c + 1 end, "", 1000)
for i = 1, 1000 do Sa.link_prio(52, i % 2 == 0 and "fini" or "chantier") end
debug.sethook()
check(c < 60, "cout : moins de 60 instructions par appel (" .. c .. ")")
print("== branchement (texte)")
local f = io.open("script/team/champ.lua", "rb")
local ch = f:read("*a")
f:close()
check(ch:find("Sa.link_prio(q.spec.prio or Build.PRIO, it.band_state)", 1, true) ~= nil, "links_step applique Sa.link_prio a la priorite du projet lie")
check(ch:find("priorite %s -> %s", 1, true) ~= nil, "le changement de priorite est ecrit au journal")
local a = ch:find("Sa.link_prio(q.spec.prio", 1, true)
local b = ch:find("local acts = Ln.decide(items)", 1, true)
check(a and b and a < b, "la priorite est posee avant la decision d'annulation (items lus une fois)")
check(ch:find('q.state == "attente" or q.state == "plan" or q.state == "reserve" or q.state == "fantomes" or q.state == "chantier"', 1, true) ~= nil,
  "seuls les projets vivants non finis sont touches")
print("== mutants")
local f2 = io.open("shared/team/champ_saut.lua", "rb")
local src = f2:read("*a")
f2:close()
local mutants = {
  { "interrupteur ignore", "if not Sa.LINK_ON or band_state == nil", "if band_state == nil" },
  { "bande absente avancee", "or band_state == nil or band_state == \"refuse\" then return base end", "or band_state == \"refuse\" then return base end" },
  { "bande refusee avancee", "band_state == nil or band_state == \"refuse\" then", "band_state == nil then" },
  { "finie = vivante", "(band_state == \"fini\") and Sa.LINK_DONE or Sa.LINK_ALIVE", "Sa.LINK_ALIVE" },
  { "vivante = finie", "(band_state == \"fini\") and Sa.LINK_DONE or Sa.LINK_ALIVE", "Sa.LINK_DONE" },
  { "plafond ignore", "return math.min(base + bonus, math.max(base, Sa.LINK_CAP))", "return base + bonus" },
  { "demande au-dessus baissee", "math.max(base, Sa.LINK_CAP)", "Sa.LINK_CAP" },
  { "plafond trop haut", "Sa.LINK_CAP = 55", "Sa.LINK_CAP = 70" },
  { "bonus nul", "Sa.LINK_ALIVE = 1", "Sa.LINK_ALIVE = 0" },
}
for _, m in ipairs(mutants) do
  local x, y = src:find(m[2], 1, true)
  if not x then check(false, "motif introuvable : " .. m[1])
  else
    local chunk = load(src:sub(1, x - 1) .. m[3] .. src:sub(y + 1), "=mut", "t")
    local Tm = chunk and chunk()
    if not Tm then check(false, "mutant illisible : " .. m[1])
    else
      local Sa0 = Sa
      Sa = Tm
      local p0, f0 = passes, failures
      local n = body()
      passes, failures = p0, f0
      Sa = Sa0
      QUIET = false
      check(n > 0, "mutant detecte : " .. m[1])
    end
  end
end
print(string.format("[VOIE-AVANT-FOURS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
