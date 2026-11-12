--[[
  Lot MEGA-FONDERIE, tranche 2 (A2) : règle pure shared/team/mega_pose.lua (bandes en avance d'un gisement à méga-fonderie décidée).
    lua5.2 tests/mega_pose_test.lua   -> [MEGA-POSE] BILAN : N OK, 0 ECHEC(S)
  Contrôles : bornes du parallélisme (lignes, plafond), refus causés (crise, courant, ennemi, rien en vol, plafond atteint, matières de la
  bande principale, stock), seuil de stock exact (bande + marge), reap des projets (dégel compris), déterminisme, puis MUTANTS de la source.
  Lot BANDES-PARALLELES : des paires thermiques sous la bande ne refusent plus l'avance ; câblage de script/team/migration_champ.lua (le dégel
  d'une bande en avance est celui de la voie principale, le stock est jugé avant le plan de la bande).
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
  return { on = true, power = true, crisis = false, enemy = false, inflight = 1, par_max = 3, main_ready = true, iron = 1000,
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
  refuse(function(c) c.inflight = 0 end, "voie principale")
  refuse(function(c) c.inflight = 3 end, "parallelisme")
  refuse(function(c) c.inflight = 5 end, "parallelisme")
  refuse(function(c) c.main_ready = false end, "matieres")
  refuse(function(c) c.iron = 799 end, "stock")
  -- lot BANDES-PARALLELES : des paires thermiques sous la bande ne la renvoient plus à la voie principale (son dégel est fait en avance)
  local c = base()
  c.pairs_under = 2
  ck(Mp.allow(c) == true, "paires thermiques dessous : la bande part en avance")
  -- seuil de stock exact : (1 + marge) × fer de la bande = 800
  c = base()
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
  ck(Mp.reap({ state = "reserve", reason = "materiaux" }) == "attendre", "reap : reserve (materiaux) -> attendre")
  ck(Mp.reap({ state = "reserve", reason = "degel" }) == "degel", "reap : reserve (degel) -> degel")
  ck(Mp.reap({ state = "reserve", reason = "degel", degele = true }) == "attendre", "reap : deja degelee -> attendre (pas de second retrait)")
  ck(Mp.reap({ state = "fantomes", reason = "degel" }) == "attendre", "reap : degel passe, chantier -> attendre")
  ck(Mp.reap({ state = "bloque", blocked_for = Mp.CFG.block_max }) == "attendre", "reap : bloque a la limite exacte -> attendre")
  ck(Mp.reap({ state = "bloque", blocked_for = Mp.CFG.block_max + 1 }) == "bloquee", "reap : bloque au-dela -> bloquee")
  -- déterminisme
  local a1, a2 = { Mp.allow(base()) }, { Mp.allow(base()) }
  ck(a1[1] == a2[1] and a1[2] == a2[2], "determinisme")
  -- lot SATURATION : pièces d'une bande déjà au stock (directive du DC du 9/11)
  local band = { { name = "d", n = 42, machine = true }, { name = "f", n = 46, machine = true }, { name = "b", n = 84 }, { name = "p", n = 38 } }
  local s = Mp.saturation(band, { d = 52, f = 104, b = 10, p = 0 })
  ck(s.machines == true and s.all == false and s.starts == true, "saturation : 52 foreuses et 104 fours au coffre paient les machines, pas les tapis")
  -- seuil de départ (2e directive du DC) : 30 % des machines au coffre suffisent, 29 % non ; une bande sans machine ne part jamais ainsi
  s = Mp.saturation(band, { d = 13, f = 14 })            -- 27 sur 88 = 30,7 %
  ck(s.starts == true and s.machines == false, "saturation : 27 machines sur 88 (30,7 %) : la bande part, kit incomplet")
  s = Mp.saturation(band, { d = 12, f = 14 })            -- 26 sur 88 = 29,5 %
  ck(s.starts == false, "saturation : 26 sur 88 (29,5 %) : ne part pas")
  s = Mp.saturation(band, { d = 26, f = 0 }, { start_pct = 30 })
  ck(s.starts == false, "saturation : 26 sur 88 avec un cfg explicite : ne part pas")
  ck(Mp.saturation({ { name = "p", n = 38 } }, { p = 100 }).starts == false, "saturation : bande sans machine : starts faux")
  ck(Mp.saturation(band, { d = 42, f = 46 }).starts == true, "saturation : tout au coffre : part")
  ck(Mp.saturation({ { name = "d", n = 20, machine = true }, { name = "f", n = 20, machine = true } }, { d = 12 }).starts == true, "saturation : 12 sur 40, seuil exact de 30 % : part")
  s = Mp.saturation(band, { d = 52, f = 104, b = 10, p = 0 }) -- (les controles suivants relisent ce cas)
  ck(s.dormant == 88 and s.want == 88, "saturation : machines prises au stock 88 sur 88")
  ck(#s.net == 2 and s.net[1][1] == "b" and s.net[1][2] == 74 and s.net[2][1] == "p" and s.net[2][2] == 38, "saturation : reste a fabriquer 74 tapis et 38 poteaux, dans l'ordre de la liste")
  s = Mp.saturation(band, { d = 41, f = 104, b = 100, p = 100 })
  ck(s.machines == false and s.all == false and #s.net == 1 and s.net[1][2] == 1, "saturation : une foreuse manque : machines non payees, reste 1")
  s = Mp.saturation(band, { d = 42, f = 46, b = 84, p = 38 })
  ck(s.machines == true and s.all == true and #s.net == 0, "saturation : tout au stock : rien a fabriquer")
  s = Mp.saturation(band, nil)
  ck(s.machines == false and s.all == false and #s.net == 4 and s.dormant == 0, "saturation : stock vide : rien de paye")
  s = Mp.saturation({ { name = "p", n = 38 } }, { p = 100 })
  ck(s.machines == false and s.all == true, "saturation : une bande sans machine n'est pas « payee par le stock dormant »")
  s = Mp.saturation(nil, { d = 1 })
  ck(s.machines == false and #s.net == 0, "saturation : liste vide")
  -- la bande payée par le stock ne demande plus de fer : allow passe avec un fer libre nul
  c = base()
  c.band_iron, c.iron = 0, 0
  ck(Mp.allow(c) == true, "saturation : bande payee par le stock (reste 0) : le fer libre ne bloque pas")
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
  { "degel non reconnu", 'if p.state == "reserve" and p.reason == "degel" and not p.degele then return "degel" end', "" },
  { "degel refait", ' and not p.degele then return "degel"', ' then return "degel"' },
  { "degel sur toute reserve", 'p.state == "reserve" and p.reason == "degel" and', 'p.state == "reserve" and' },
  { "saturation : machines jamais payees", "if e.machine then out.machines = false end", "" },
  { "saturation : reste a fabriquer oublie", "out.net%[#out.net %+ 1%] = { e.name, n %- have }", "" },
  { "saturation : bande sans machine payee", "if not any then out.machines = false end", "" },
  { "saturation : stock inclusif", "if n > have then", "if n >= have then" },
  { "saturation : seuil de depart ignore", "out.starts = any and out.dormant %* 100 >= out.want %* cfg.start_pct", "out.starts = any" },
  { "saturation : seuil de depart exclusif", "out.dormant %* 100 >= out.want %* cfg.start_pct", "out.dormant * 100 > out.want * cfg.start_pct" },
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

-- Lot BANDES-PARALLELES : câblage de l'exécutant (script/team/migration_champ.lua), lu dans la source
do
  local mig = read("script/team/migration_champ.lua")
  local function count(pat) local _, n = mig:gsub(pat, "") return n end
  local function body(name)
    local a = mig:find("local function " .. name .. "(", 1, true)
    local z = a and mig:find("\nend\n", a, true)
    return a and mig:sub(a, z) or ""
  end
  check(not mig:find("pairs_under", 1, true) and not mig:find("paires dessous", 1, true), "cablage : plus de refus « paires dessous » dans l'executant")
  check(count("Mg%.gate%(") == 1, "cablage : une seule decision de degel (Mg.gate) pour les deux voies")
  check(count("= retire%(f, surface, o, st, ") == 0 and body("thaw_cut"):find("retire(f, surface, o, { ids = ln.ids", 1, true) ~= nil,
    "cablage : le retrait des paires d'une voie passe par thaw_cut")
  check(body("step_project"):find("thaw_gate(f, surface, ms, o, st, st, p,", 1, true) ~= nil and body("step_project"):find("thaw_cut(", 1, true) ~= nil,
    "cablage : la voie principale degele par thaw_gate et thaw_cut")
  local th = body("ahead_thaw")
  check(th:find("thaw_gate(f, surface, ms, o, st, a, p,", 1, true) ~= nil and th:find("thaw_cut(", 1, true) ~= nil and th:find("p.degele", 1, true) ~= nil,
    "cablage : la voie en avance degele par le meme code (thaw_gate, thaw_cut, p.degele)")
  check(body("ahead_reap"):find('if v == "degel" then', 1, true) ~= nil and body("ahead_reap"):find("ahead_thaw(", 1, true) ~= nil,
    "cablage : ahead_reap fait le degel d'une bande en avance")
  local la = body("ahead_launch")
  check(la:find("spec.degel = { oid = o.id, tiles = thaw }", 1, true) ~= nil and la:find("band_cut(bd,", 1, true) ~= nil,
    "cablage : une bande en avance porte son degel (tuiles des paires dessous)")
  check(count("= band_cut%(bd, ") == 2, "cablage : les paires sous une bande se relevent par band_cut sur les deux voies")
  local i_stock, i_band = la:find("c.band_iron = enemy_near(f, surface, o.pos.x, o.pos.y), (st.band_need and band_iron(book, st.band_need, free)) or 1", 1, true), la:find("Champ.band(", 1, true)
  local i_allow = i_stock and la:find("Mp.allow(c)", i_stock, true)
  check(i_stock ~= nil and i_band ~= nil and i_allow ~= nil and i_stock < i_allow and i_allow < i_band,
    "cablage : le stock est juge avant le plan de la bande (Champ.band)")
  local stp = body("ahead_step")
  check(stp:find("(st.mega_par or dormant or st.ahead)", 1, true) ~= nil, "cablage : les bandes en avance sont suivies meme sans droit a une de plus")
end
print(string.format("[MEGA-POSE] BILAN : %d OK, %d ECHEC(S) (%d mutants)", pass, fail, #MUT))
os.exit(fail == 0 and 0 or 1)
