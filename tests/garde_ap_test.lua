--[[
  Lot DEFENSE-AP : banc HORS JEU de la garde d'un avant-poste dimensionnée sur la menace (shared/team/garde_ap.lua).
  Lancement, depuis la racine du mod : lua5.2 tests/garde_ap_test.lua

  Sections :
    1. la règle d'avant reste le plancher (menace nulle, inconnue ou plus petite) ;
    2. la menace RELÈVE la garde : vague prévue à 5 min, à 15 min, vague reçue ; le plus grand des trois compte ;
    3. cas mesurés (diag1, 9/11) : ap1 de fer, 16 foreuses, tourelle 574 PV : 294 PV -> base ; 1750 PV -> 4 ; 2457 PV -> 5 ;
    4. plafond Ga.CAP, jamais en dessous de la règle d'avant ;
    5. entrées dégradées (nil, négatif, NaN) ; constante de marge alignée sur la prévision ; déterminisme ; anti-échelle (aucun nom d'objet) ;
    6. mutants (règle modifiée par substitution du texte) : chacun fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    print("  ECHEC : " .. msg)
  end
  return cond
end

local function load_module(src)
  local chunk, err = load(src, "=garde_ap", "t", _ENV)
  if not chunk then error(err) end
  return chunk()
end

local function read_all(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local SRC = read_all("shared/team/garde_ap.lua")

-- Les contrôles, rejouables sur un module modifié (mutant) : rendent le nombre d'échecs.
local function run_checks(Ga, label, loud)
  local fails = 0
  local function ck(cond, msg)
    if not cond then
      fails = fails + 1
      if loud then check(false, label .. " : " .. msg) end
    elseif loud then
      check(true, msg)
    end
  end
  local TV = 574
  -- 1. plancher = règle d'avant
  ck(Ga.want({ base = 3, tv = TV }) == 3, "sans menace : la règle d'avant")
  ck(Ga.want({ base = 3, w5 = 0, w15 = 0, mem = 0, tv = TV }) == 3, "vague nulle : la règle d'avant")
  ck(Ga.want({ base = 3, w5 = 294, tv = TV }) == 3, "vague 294 PV (0,6 tourelle) : la règle d'avant")
  ck(Ga.want({ base = 3, w5 = 5000, tv = 0 }) == 3, "valeur de tourelle inconnue : la règle d'avant")
  ck(select(3, Ga.want({ base = 3, w5 = 294, tv = TV })) == "base", "raison base")
  -- 2. la menace relève
  ck(Ga.want({ base = 1, w5 = 1750, tv = TV }) == 4, "w5 seule relève (1750 -> 4)")
  ck(Ga.want({ base = 1, w15 = 1750, tv = TV }) == 4, "w15 seule relève")
  ck(Ga.want({ base = 1, mem = 1750, tv = TV }) == 4, "la vague reçue seule relève")
  ck(Ga.want({ base = 1, w5 = 600, w15 = 1750, mem = 900, tv = TV }) == 4, "le plus grand des trois compte (w15)")
  ck(Ga.want({ base = 1, w5 = 1750, w15 = 600, mem = 900, tv = TV }) == 4, "le plus grand des trois compte (w5)")
  ck(Ga.want({ base = 1, w5 = 600, w15 = 900, mem = 1750, tv = TV }) == 4, "le plus grand des trois compte (mem)")
  ck(select(3, Ga.want({ base = 1, w5 = 1750, tv = TV })) == "menace", "raison menace")
  ck(select(2, Ga.want({ base = 1, w5 = 600, w15 = 900, mem = 1750, tv = TV })) == 1750, "vague retenue rendue")
  -- 3. cas mesurés (diag1)
  ck(Ga.want({ base = 3, w5 = 294, w15 = 294, tv = TV }) == 3, "diag1 5 min : base")
  ck(Ga.want({ base = 3, w5 = 1750, w15 = 1750, tv = TV }) == 4, "diag1 10 min : 4 tourelles")
  ck(Ga.want({ base = 3, w5 = 2457, w15 = 2457, tv = TV }) == 5, "diag1 15 min : 5 tourelles")
  -- bord exact : 1,1 x vague = n tourelles pile -> n, pas n + 1
  ck(Ga.want({ base = 1, w5 = 1000 * 574 * 3 / 1100, tv = 574 }) == 3, "bord exact : 3 tourelles")
  ck(Ga.want({ base = 1, w5 = 1000 * 574 * 3 / 1100 + 1, tv = 574 }) == 4, "un PV de plus : 4 tourelles")
  -- 4. plafond
  ck(Ga.want({ base = 1, w5 = 100000, tv = TV }) == 6, "plafond de 6 tourelles")
  ck(select(3, Ga.want({ base = 1, w5 = 100000, tv = TV })) == "plafond", "raison plafond")
  ck(Ga.want({ base = Ga.CAP + 2, w5 = 100000, tv = TV }) == Ga.CAP + 2, "jamais sous la règle d'avant")
  ck(select(3, Ga.want({ base = Ga.CAP + 2, w5 = 100000, tv = TV })) == "base", "base au-dessus du plafond : raison base")
  ck(Ga.want({ base = Ga.CAP, w5 = 100000, tv = TV }) == Ga.CAP, "base = plafond")
  -- monotonie en la vague
  local last = 0
  local mono = true
  for w = 0, 6000, 50 do
    local n = Ga.want({ base = 2, w5 = w, tv = TV })
    if n < last then mono = false end
    last = n
  end
  ck(mono, "monotone en la vague")
  -- 5. entrées dégradées
  ck(Ga.want() == 0, "sans entrée : 0")
  ck(Ga.want({}) == 0, "table vide : 0")
  ck(Ga.want({ base = -4, w5 = -5, tv = TV }) == 0, "négatifs ignorés")
  ck(Ga.want({ base = 3, w5 = 0 / 0, tv = TV }) == 3, "NaN ignoré")
  ck(Ga.want({ base = "x", w5 = "y", tv = TV }) == 0, "chaînes ignorées")
  ck(Ga.want({ base = 2.9, tv = TV }) == 2, "base fractionnaire arrondie vers le bas")
  return fails
end

-- Module réel
local Ga = load_module(SRC)
local f0 = run_checks(Ga, "reel", true)
check(f0 == 0, "module réel : tous les contrôles")

-- Alignement sur la prévision (même marge)
do
  local Pc = require("shared.ai3.prevision_choix")
  check(Ga.MARGE == Pc.MARGE, "marge alignée sur Pc.MARGE")
  check(Ga.CAP >= Pc.PREP_TURRETS, "plafond au moins égal aux tourelles d'avance de la prévision")
end

-- Déterminisme
do
  local a = { Ga.want({ base = 2, w5 = 1234, w15 = 2345, mem = 345, tv = 574 }) }
  local b = { Ga.want({ base = 2, w5 = 1234, w15 = 2345, mem = 345, tv = 574 }) }
  check(a[1] == b[1] and a[2] == b[2] and a[3] == b[3], "mêmes entrées, mêmes sorties")
end

-- Anti-échelle : aucun nom d'objet ni de bâtiment du jeu, aucun pairs
do
  local code = SRC:gsub("%-%-%[%[.-%]%]", "")
  for _, bad in ipairs({ "gun%-turret", "iron%-plate", "firearm", "copper", "stone", "pairs%(", "game%.", "math%.random" }) do
    check(not code:find(bad), "anti-échelle : pas de « " .. bad .. " »")
  end
end

-- 6. Mutants
local mutants = {
  { "marge à 1000", "Ga.MARGE = 1100", "Ga.MARGE = 1000" },
  { "marge à 1200", "Ga.MARGE = 1100", "Ga.MARGE = 1200" },
  { "plafond à 2", "Ga.CAP = 6", "Ga.CAP = 2" },
  { "plafond à 9", "Ga.CAP = 6", "Ga.CAP = 9" },
  { "w5 seul (w15 et mem ignorées)", "math.max(num(a.w5), num(a.w15), num(a.mem))", "num(a.w5)" },
  { "mem ignorée", "math.max(num(a.w5), num(a.w15), num(a.mem))", "math.max(num(a.w5), num(a.w15))" },
  { "w15 ignorée", "math.max(num(a.w5), num(a.w15), num(a.mem))", "math.max(num(a.w5), num(a.mem))" },
  { "plus petit au lieu du plus grand", "math.max(num(a.w5), num(a.w15), num(a.mem))", "math.min(num(a.w5), num(a.w15), num(a.mem))" },
  { "arrondi bas au lieu de haut", "math.ceil(w * Ga.MARGE / 1000 / tv - 1e-9)", "math.floor(w * Ga.MARGE / 1000 / tv)" },
  { "arrondi haut sans tolérance", "math.ceil(w * Ga.MARGE / 1000 / tv - 1e-9)", "math.ceil(w * Ga.MARGE / 1000 / tv + 1e-9)" },
  { "sous la règle d'avant", "if need <= base then return base, w, \"base\" end", "if need <= 0 then return base, w, \"base\" end" },
  { "plafond ignoré", "if need > Ga.CAP then", "if false then" },
  { "plafond sous la base", "if Ga.CAP <= base then return base, w, \"base\" end", "" },
  { "raison menace -> base", "return need, w, \"menace\"", "return need, w, \"base\"" },
  { "valeur de tourelle nulle acceptée", "if tv <= 0 or w <= 0 then", "if w <= 0 then" },
  { "base non arrondie", "local base = math.floor(num(a.base))", "local base = num(a.base)" },
  { "négatifs acceptés", "if type(x) ~= \"number\" or x ~= x or x < 0 then return 0 end", "if type(x) ~= \"number\" then return 0 end" },
  { "NaN accepté", "if type(x) ~= \"number\" or x ~= x or x < 0 then return 0 end", "if type(x) ~= \"number\" or x < 0 then return 0 end" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local s, e = SRC:find(m[2], 1, true)
  if not s then
    check(false, "mutant « " .. m[1] .. " » : texte à remplacer introuvable")
  else
    local mutated = SRC:sub(1, s - 1) .. m[3] .. SRC:sub(e + 1)
    local ok, M = pcall(load_module, mutated)
    local dead = false
    if not ok then dead = true else
      local ok2, fails = pcall(run_checks, M, m[1], false)
      dead = (not ok2) or fails > 0
    end
    if dead then killed = killed + 1 end
    check(dead, "mutant « " .. m[1] .. " » refusé")
  end
end
print(string.format("[GARDE-AP] mutants refusés : %d / %d", killed, #mutants))
print(string.format("[GARDE-AP] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
