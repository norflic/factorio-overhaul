--[[
  Lot MEGA-FONDERIE, tranche 2 (A2) : règle pure shared/team/mega_pose.lua (bandes en avance d'un gisement à méga-fonderie décidée).
    lua5.2 tests/mega_pose_test.lua   -> [MEGA-POSE] BILAN : N OK, 0 ECHEC(S)
  Contrôles : bornes du parallélisme (lignes, plafond), refus causés (crise, courant, ennemi, paires dessous, rien en vol, plafond atteint,
  matières de la bande principale, stock), seuil de stock exact (bande + marge), reap des projets, déterminisme, puis MUTANTS de la source.
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local QUIET = false
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 if not QUIET then print("[MEGA-POSE] ECHEC : " .. msg) end end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local PATH = "shared/team/mega_pose.lua"
local SRC = read(PATH)

local function load_src(src)
  local chunk, err = load(src, "=" .. PATH, "t", _ENV)
  assert(chunk, err)
  return chunk()
end

local function base()
  return { on = true, power = true, crisis = false, enemy = false, pairs_under = 0, inflight = 1, par_max = 3, main_ready = true, iron = 1000,
    band_iron = 400 }
end

local function suite(Mp, tag, strict)
  local n0 = fail
  local function ck(ok, msg) check(ok, tag .. msg) end
  -- par_max
  ck(Mp.par_max({ lines = 6 }) == 3, "par_max : 6 lignes -> plafond 3")
  ck(Mp.par_max({ lines = 2 }) == 2, "par_max : 2 lignes -> 2")
  ck(Mp.par_max({ lines = 1 }) == 1, "par_max : 1 ligne -> 1")
  ck(Mp.par_max({ lines = 0 }) == 1 and Mp.par_max({}) == 1 and Mp.par_max(nil) == 1, "par_max : jamais sous 1")
  ck(Mp.par_max({ lines = 12 }) == Mp.CFG.par_cap, "par_max : un gisement geant reste au plafond")
  -- allow : cas libre
  local ok, why = Mp.allow(base())
  ck(ok == true and why == "libre", "allow : tout reuni -> libre")
  -- refus causés, un par un
  local function refuse(mod, cause)
    local c = base()
    mod(c)
    local o, w = Mp.allow(c)
    ck(o == false and tostring(w):find(cause, 1, true) ~= nil, "refus " .. cause .. " (" .. tostring(w) .. ")")
  end
  refuse(function(c) c.on = false end, "decision absente")
  refuse(function(c) c.crisis = true end, "crise")
  refuse(function(c) c.power = false end, "aucun reseau")
  refuse(function(c) c.enemy = true end, "ennemi")
  refuse(function(c) c.pairs_under = 2 end, "paires dessous")
  refuse(function(c) c.inflight = 0 end, "voie principale")
  refuse(function(c) c.inflight = 3 end, "parallelisme")
  refuse(function(c) c.inflight = 5 end, "parallelisme")
  refuse(function(c) c.main_ready = false end, "matieres")
  refuse(function(c) c.iron = 799 end, "stock")
  -- seuil de stock exact : (1 + marge) × fer de la bande = 800
  local c = base()
  c.iron = 800
  ck(Mp.allow(c) == true, "stock : 800 (= bande + marge) passe")
  c.iron = 799.9
  ck(Mp.allow(c) == false, "stock : 799,9 ne passe pas")
  -- un plafond de 2 : la seconde bande en vol est refusée, la première avance passe
  c = base()
  c.par_max, c.inflight = 2, 1
  ck(Mp.allow(c) == true, "plafond 2 : une avance avec 1 en vol")
  c.inflight = 2
  ck(Mp.allow(c) == false, "plafond 2 : pas de troisieme")
  -- ordre des causes : la crise passe avant tout le reste (la défense d'abord)
  c = base()
  c.crisis, c.iron, c.main_ready = true, 0, false
  local _, w = Mp.allow(c)
  ck(w == "crise", "la crise est la premiere cause")
  -- un gisement sans fer demandé (band_iron 0) : le stock ne bloque pas
  c = base()
  c.band_iron, c.iron = 0, 0
  ck(Mp.allow(c) == true, "bande sans fer : le stock ne bloque pas")
  -- reap
  ck(Mp.reap(nil) == "perdue", "reap : projet disparu")
  ck(Mp.reap({ state = "fini" }) == "posee", "reap : fini -> posee")
  ck(Mp.reap({ state = "refuse" }) == "perdue", "reap : refuse -> perdue")
  ck(Mp.reap({ state = "chantier" }) == "attendre", "reap : chantier -> attendre")
  ck(Mp.reap({ state = "reserve" }) == "attendre", "reap : reserve -> attendre")
  ck(Mp.reap({ state = "bloque", blocked_for = Mp.CFG.block_max }) == "attendre", "reap : bloque a la limite exacte -> attendre")
  ck(Mp.reap({ state = "bloque", blocked_for = Mp.CFG.block_max + 1 }) == "bloquee", "reap : bloque au-dela -> bloquee")
  -- déterminisme
  local a1, a2 = { Mp.allow(base()) }, { Mp.allow(base()) }
  ck(a1[1] == a2[1] and a1[2] == a2[2], "determinisme")
  return fail == n0
end

local Mp = load_src(SRC)
suite(Mp, "", false)

-- Mutants : chacun doit faire échouer au moins un contrôle de la suite.
local MUT = {
  { "plafond ignore", "return math.min%(cfg.par_cap, lines%)", "return lines" },
  { "plancher de 1 retire", "if lines < 1 then lines = 1 end", "" },
  { "crise ignoree", 'if c.crisis then return false, "crise" end', "" },
  { "courant ignore", 'if not c.power then return false, "aucun reseau qui produit" end', "" },
  { "ennemi ignore", 'if c.enemy then return false, "ennemi" end', "" },
  { "paires dessous ignorees", 'if %(c.pairs_under or 0%) > 0 then', "if false then" },
  { "rien en vol accepte", 'if %(c.inflight or 0%) <= 0 then', "if false then" },
  { "plafond atteint accepte", 'if %(c.inflight or 0%) >= %(c.par_max or 1%) then', "if false then" },
  { "plafond decale", 'if %(c.inflight or 0%) >= %(c.par_max or 1%) then', "if (c.inflight or 0) > (c.par_max or 1) then" },
  { "matieres ignorees", 'if not c.main_ready then', "if false then" },
  { "marge ignoree", "%(c.band_iron or 0%) %* %(1 %+ cfg.margin%)", "(c.band_iron or 0)" },
  { "stock ignore", 'if %(c.iron or 0%) < need then', "if false then" },
  { "stock inclusif", 'if %(c.iron or 0%) < need then', "if (c.iron or 0) <= need then" },
  { "fini non reconnu", 'if p.state == "fini" then return "posee" end', "" },
  { "refuse non reconnu", 'if p.state == "annule" or p.state == "refuse" then return "perdue" end', "" },
  { "bloque trop tot", "%(p.blocked_for or 0%) > cfg.block_max", "(p.blocked_for or 0) >= cfg.block_max" },
  { "disparu non reconnu", 'if not p then return "perdue" end', "" },
}
local survivors = 0
for _, m in ipairs(MUT) do
  local s, n = SRC:gsub(m[2], function() return m[3] end, 1)
  if n ~= 1 then
    check(false, "mutant '" .. m[1] .. "' : motif introuvable dans la source")
  else
    local before = fail
    local saved_pass = pass
    local mp = load_src(s)
    QUIET = true
    local ok = pcall(suite, mp, "[mutant " .. m[1] .. "] ", true)
    QUIET = false
    local killed = (fail > before) or not ok
    -- les echecs des mutants ne comptent pas comme echecs du banc : ils sont la preuve
    fail, pass = before, saved_pass
    if killed then pass = pass + 1 else survivors = survivors + 1 print("[MEGA-POSE] ECHEC : mutant survivant : " .. m[1]) end
  end
end
check(survivors == 0, "aucun mutant survivant")
print(string.format("[MEGA-POSE] BILAN : %d OK, %d ECHEC(S) (%d mutants)", pass, fail, #MUT))
os.exit(fail == 0 and 0 or 1)
