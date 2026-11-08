--[[
  Lot MEGA-FONDERIE (8/11) : test hors jeu de shared/team/mega_fonderie.lua (conception : docs/MEGA_FONDERIE.md). Depuis la racine du mod :
    lua5.2 tests/mega_fonderie_test.lua   -> [MEGA] BILAN : N OK, 0 ECHEC(S)
  Parties : (1) dimensionnement (chiffres de la conception), (2) décision, (3) plan du bloc et contrôle sur une grille de cas, (4) le
  contrôle VOIT les plans faux, (5) croissance, (6) journal et budget, (7) coût du pire cas par debug.sethook (instructions, déterministe),
  (8) mutants : une substitution dans le source, module rechargé, la suite doit ÉCHOUER.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/mega_fonderie.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[MEGA] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

local COST_MAX = 400 -- milliers d'instructions : décision complète du pire cas (taille, échantillon, contrôle, coût d'une colonne), ≈ 5 ms

-- Données de référence (vanilla lu aux prototypes par Champ.data : foreuse électrique 3 × 3 à 0,5/s, four de pierre 2 × 2 à 0,3125/s et
-- 90 kW, bras 0,83 tour/s, petit poteau portée 2 fil 7,5, tapis jaune / rouge / bleu). Aucun nom : des nombres.
local function ref(t)
  local s = { tiles = 1000, drill = { size = 3, rate = 0.5 }, belts = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } },
    furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 }, pole = { reach = 2, wire = 7.5 } }
  for k, v in pairs(t or {}) do s[k] = v end
  return s
end
local ELEC = { size = 3, rate = 0.625, fuel = false }
local STEEL = { size = 2, rate = 0.625, fuel = true, fuel_rate = 0.0225 }

local function dump(pl)
  local out = {}
  for _, e in ipairs(pl.ents) do out[#out + 1] = table.concat({ e.kind, e.u, e.v, e.dir or "", e.role or "" }, ",") end
  return table.concat(out, ";")
end

local function suite(Mf)
  local bad, n = {}, 0
  local function want(ok, msg) n = n + 1; if not ok then bad[#bad + 1] = msg end end
  local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

  -- 1. Dimensionnement : les chiffres du tableau de docs/MEGA_FONDERIE.md §3
  local z = Mf.size(ref())
  want(z ~= nil, "1 000 tuiles : une taille")
  if z then
    want(z.drills == 83 and near(z.ore, 41.5), "1 000 tuiles : 83 foreuses, 41,5 minerai/s (" .. tostring(z.drills) .. ")")
    want(z.lines == 6 and z.belt == 1 and z.kpl == 1, "1 000 tuiles : 6 lignes de tapis jaune, une voie de minerai par ligne (" .. tostring(z.lines) .. ")")
    want(z.ncol == 24 and z.nside == 12 and z.furnaces == 133 and z.last == 13, "1 000 tuiles : 24 fours par colonne, 133 fours, 13 dans la derniere")
    want(z.full_lines == 5 and near(z.plates, 41.5) and math.abs(z.coal - 133 * 0.0225) < 1e-6, "1 000 tuiles : 5 lignes pleines, plaques, charbon")
    want(z.pitch == 10 and z.w == 61 and z.hf == 24 and z.h > z.hf, "1 000 tuiles : pas 10, rectangle 61 de large")
    want(z.start == 6 and z.start_why == "cible", "sans budget : toutes les colonnes")
  end
  local z2 = Mf.size(ref({ tiles = 2000 }))
  want(z2 and z2.drills == 166 and z2.lines == 12 and z2.furnaces == 266 and z2.belt == 1, "2 000 tuiles : 166 foreuses, 12 lignes jaunes, 266 fours")
  local z5 = Mf.size(ref({ tiles = 5000 }))
  want(z5 and z5.belt == 3 and z5.lines <= Mf.MAX_LINES, "5 000 tuiles : le tapis le plus lent qui tient en 12 lignes (bleu)")
  want(z5 and z5.nside == Mf.MAX_SIDE and z5.clamp == "colonne", "5 000 tuiles : colonne bornee a 32 fours par cote, borne ecrite")
  local zh = Mf.size(ref({ tiles = 1e6 }))
  want(zh and zh.lines == Mf.MAX_LINES and zh.clamp ~= nil and zh.drills * 0.5 <= Mf.MAX_LINES * zh.per_line + 1e-6,
    "gisement immense : 12 lignes au plus, foreuses bornees au bus")
  local zr = Mf.size(ref({ tiles = 2000, belts = { { lane = 7.5 }, { lane = 15 } } }))
  want(zr and zr.belt == 1 and zr.lines == 12, "2 000 tuiles, jaune et rouge : le jaune tient en 12 lignes")
  local zr2 = Mf.size(ref({ tiles = 2200, belts = { { lane = 7.5 }, { lane = 15 } } }))
  want(zr2 and zr2.belt == 2 and zr2.lines == 7 and zr2.ncol == 48, "2 200 tuiles (13 lignes jaunes) : rouge, 7 lignes, 48 fours par colonne")
  local ze = Mf.size(ref({ furnace = ELEC }))
  want(ze and ze.kpl == 2 and near(ze.per_line, 15) and ze.ncol == 24 and ze.lines == 3 and ze.coal == 0 and ze.pitch == 12,
    "four electrique : minerai sur les deux voies, 24 fours par ligne, aucun charbon")
  local zs = Mf.size(ref({ furnace = STEEL }))
  want(zs and zs.ncol == 12 and zs.lines == 6 and zs.furnaces == 67, "four d'acier : 12 fours par ligne")
  local zd = Mf.size(ref({ drills = 30, tiles = 0 }))
  want(zd and zd.drills == 30 and zd.lines == 2, "foreuses connues du cadre du champ : prises telles quelles")
  local zc = Mf.size(ref({ cover = 0.5 }))
  want(zc and zc.drills == 41, "couverture visee 50 % : moitie des foreuses")
  local zy = Mf.size(ref({ furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225, yield = 4 }, inserter = { rate = 2.31 } }))
  want(zy and zy.nside == 6 and zy.clamp == "sortie", "rendement 4 : la voie de sortie borne la colonne (6 fours par cote)")
  -- données illisibles : nil et la cause, jamais d'erreur
  local cases = {
    { { drill = { size = 3, rate = 0 } }, "foreuse" }, { { furnace = { size = 2 } }, "four" }, { { furnace = { size = 1, rate = 1, fuel = true } }, "petit" },
    { { inserter = {} }, "bras" }, { { pole = { reach = 2 } }, "poteau" }, { { belts = {} }, "tapis" }, { { belts = { { lane = 0 / 0 } } }, "tapis" },
    { { tiles = 5 }, "vide" }, { { inserter = { rate = 0.3 } }, "nourrir" },
    { { furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225, yield = 4 } }, "vider" }, { { pole = { reach = 0.4, wire = 9 } }, "poteau" },
    { { pole = { reach = 2, wire = 3 } }, "fils" }, { { furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 1 }, inserter = { rate = 5 } }, "charbon" },
  }
  for _, c in ipairs(cases) do
    local zz, why = Mf.size(ref(c[1]))
    want(zz == nil and type(why) == "string" and why:find(c[2], 1, true) ~= nil, "donnees refusees avec leur cause : " .. c[2] .. " (" .. tostring(why) .. ")")
  end
  want(Mf.size(nil) == nil, "entree absente : nil")
  local zb = Mf.size(ref({ budget_cols = 2.7 }))
  want(zb and zb.start == 2 and zb.start_why == "budget", "budget de 2,7 colonnes : depart 2")
  local zb0 = Mf.size(ref({ budget_cols = 0 }))
  want(zb0 and zb0.start == 1, "budget nul : au moins une colonne (le cerveau fabrique le reste)")
  local zb9 = Mf.size(ref({ budget_cols = 99 }))
  want(zb9 and zb9.start == zb9.lines and zb9.start_why == "cible", "budget large : la cible")

  -- 2. Décision
  local inp = { on = true, smeltable = true, size = z, power = true, crisis = false }
  local function with(t) local c = {} for k, v in pairs(inp) do c[k] = v end for k, v in pairs(t) do c[k] = v end return c end
  local a, why = Mf.decide(inp)
  want(a == "decider" and why:find("6 ligne", 1, true) ~= nil, "gisement geant, courant, hors crise : decider (" .. tostring(why) .. ")")
  want(Mf.decide(with({ on = false })) == "refuser", "reglage eteint : refus")
  want(Mf.decide(with({ smeltable = false })) == "refuser", "minerai sans four : refus")
  local a3, w3 = Mf.decide(with({ size = false, size_why = "aucun tapis" }))
  want(a3 == "refuser" and w3:find("aucun tapis", 1, true) ~= nil, "donnees : refus avec la cause de la taille")
  local small = Mf.size(ref({ tiles = 200 }))
  local a4, w4 = Mf.decide(with({ size = small }))
  want(a4 == "refuser" and w4:find("trop petit", 1, true) ~= nil, "200 tuiles : trop petit pour un bus (" .. tostring(w4) .. ")")
  want(Mf.decide(with({ size = Mf.size(ref({ drills = 30 })) })) == "decider", "2 lignes pleines : decider")
  want(Mf.decide(with({ size = Mf.size(ref({ drills = 29 })) })) == "refuser", "moins de 2 lignes pleines : refus")
  local a5, w5 = Mf.decide(with({ crisis = true }))
  want(a5 == "attendre" and w5:find("crise", 1, true) ~= nil, "crise : attendre")
  want(Mf.decide(with({ power = false })) == "attendre", "sans courant : attendre")
  do local c = with({}); c.power = nil; want(Mf.decide(c) == "attendre", "courant inconnu : attendre (garde fermee)") end
  want(Mf.decide(with({ sig = Mf.signature(z) })) == "garder", "meme taille deja decidee : garder")
  want(Mf.decide(with({ sig = Mf.signature(z2) })) == "decider", "taille changee : decider de nouveau")
  want(Mf.decide(nil) == "refuser", "entree absente : refus")

  -- 3. Plan du bloc et contrôle : grille de cas
  local grid = {
    { "pierre jaune 1000", ref() }, { "pierre jaune 2000", ref({ tiles = 2000 }) }, { "pierre jaune 300", ref({ tiles = 300 }) },
    { "pierre bleu 5000", ref({ tiles = 5000 }) }, { "electrique", ref({ furnace = ELEC }) }, { "acier", ref({ furnace = STEEL }) },
    { "electrique 3000", ref({ tiles = 3000, furnace = ELEC }) }, { "portee 1", ref({ pole = { reach = 1, wire = 7.5 } }) },
    { "portee 3", ref({ pole = { reach = 3, wire = 9 } }) }, { "portee 3 electrique", ref({ furnace = ELEC, pole = { reach = 3, wire = 9 } }) },
    { "portee 4", ref({ pole = { reach = 4, wire = 10 } }) }, { "derniere colonne d'un four", ref({ drills = 46 }) },
    { "derniere colonne impaire", ref({ drills = 33 }) }, { "rendement 4", ref({ furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225, yield = 4 }, inserter = { rate = 2.31 } }) },
  }
  for _, g in ipairs(grid) do
    local zz = Mf.size(g[2])
    if not zz then want(false, g[1] .. " : taille absente")
    else
      local pl = Mf.block(zz)
      local b = Mf.verify(pl, zz)
      want(#b == 0, g[1] .. " : plan juste (" .. tostring(b[1]) .. ")")
      local c = Mf.cost(pl)
      want(c.four == zz.furnaces, g[1] .. " : fours poses = fours voulus")
      want(c.bras >= 2 * zz.furnaces and c.coffre >= 1 and c.poteau >= 1, g[1] .. " : bras, coffres, poteaux")
      want(#pl.ports.arrivals == zz.cols and #pl.ports.outputs == zz.cols + 1, g[1] .. " : une arrivee par ligne du bus, C + 1 tapis de plaques")
      want(pl.w == zz.w and pl.h == zz.h, g[1] .. " : rectangle")
      local sm = Mf.sample(zz)
      local bs = Mf.verify(Mf.block(sm), sm)
      want(#bs == 0, g[1] .. " : echantillon juste (" .. tostring(bs[1]) .. ")")
      local st = Mf.block(zz, true)
      want(st.cols == zz.start and #Mf.verify(st, zz) == 0, g[1] .. " : colonnes de depart justes")
    end
  end
  want(dump(Mf.block(z)) == dump(Mf.block(z)), "plan deterministe")
  local sm3 = Mf.sample(z)
  want(sm3.cols == 3 and sm3.last == z.last and sm3.furnaces == 2 * z.ncol + z.last and sm3.w == 31, "echantillon : 3 colonnes, la derniere partielle")
  local sm1 = Mf.sample(z, 1, true)
  want(sm1.cols == 1 and sm1.furnaces == z.ncol and z.furnaces == 133, "echantillon d'une colonne pleine, la taille d'origine intacte")
  local cc = Mf.col_cost(z)
  want(cc.four == 24 and cc.bras >= 48, "cout d'une colonne : 24 fours, 48 bras au moins")

  -- 4. Le contrôle voit les plans faux
  local function broken(fn)
    local pl = Mf.block(z)
    fn(pl)
    return #Mf.verify(pl, z) > 0
  end
  local function find(pl, kind, role)
    for i, e in ipairs(pl.ents) do if e.kind == kind and (role == nil or e.role == role) then return i, e end end
  end
  want(broken(function(pl) local _, e = find(pl, "bras", "entree"); e.pick = { e.u - 1, e.v } end), "bras d'entree qui ne prend pas sur le tapis")
  want(broken(function(pl) local _, e = find(pl, "bras", "sortie"); e.drop = { e.u + 1, e.v } end), "bras de sortie qui ne depose pas sur un tapis")
  want(broken(function(pl) local i = find(pl, "bras", "sortie"); table.remove(pl.ents, i) end), "four sans bras de sortie")
  want(broken(function(pl) local _, e = find(pl, "tapis", "entree"); pl.ents[#pl.ents + 1] = { kind = e.kind, u = e.u, v = e.v, size = 1, dir = e.dir, role = e.role } end),
    "deux tapis sur la meme tuile (chevauchement seul)")
  want(broken(function(pl) local i = find(pl, "tapis", "entree"); table.remove(pl.ents, i) end), "tapis d'entree interrompu")
  want(broken(function(pl) local _, e = find(pl, "tapis", "plaques"); e.dir = 2 end), "tapis de plaques dans le mauvais sens")
  want(broken(function(pl) local _, e = find(pl, "bras", "quai"); e.drop = { e.u, e.v + 1 } end), "bras de quai sans coffre")
  want(broken(function(pl) local keep = {} for _, e in ipairs(pl.ents) do if e.kind ~= "poteau" or e.v > 4 then keep[#keep + 1] = e end end; pl.ents = keep end),
    "bras sans courant (poteaux du haut retires)")
  want(broken(function(pl) pl.ents[#pl.ents + 1] = { kind = "poteau", u = 0, v = pl.h + 5, size = 1 } end), "entite hors du rectangle")
  do -- fils trop courts pour les écarts du plan (portée inchangée : seul le contrôle des fils peut le voir)
    local zw = Mf.sample(z)
    local pl = Mf.block(zw)
    zw.wire = 2.5
    local b = Mf.verify(pl, zw)
    want(#b == 1 and b[1]:find("non relies", 1, true) ~= nil, "fils trop courts : reseau non relie, seul ecart (" .. tostring(b[1]) .. ")")
  end
  do
    local ze2 = Mf.size(ref({ furnace = ELEC }))
    local pl = Mf.block(ze2)
    local keep = {}
    for _, e in ipairs(pl.ents) do if e.kind ~= "poteau" then keep[#keep + 1] = e end end
    pl.ents = keep
    local b = Mf.verify(pl, ze2)
    local seen = false
    for _, m in ipairs(b) do if m:find("four electrique", 1, true) then seen = true end end
    want(seen, "four electrique sans poteau : vu")
  end

  -- 5. Croissance : en unités colonne (7,5/s) et bande (3,75/s)
  local g0 = { input = 20, per_col = 7.5, posted = 2, cols = 6, bands = 6, band_rate = 3.75, bands_max = 22 }
  local function gw(t) local c = {} for k, v in pairs(g0) do c[k] = v end for k, v in pairs(t) do c[k] = v end return Mf.grow(c) end
  want(gw({}).action == "ajouter_colonne" and gw({}).n == 1, "entree au-dela des colonnes posees : une colonne de plus")
  want(gw({ input = 60, posted = 3 }).action == "ajouter_colonne", "entree au-dela de toute la reservation, colonnes restantes : une colonne")
  want(gw({ input = 60, posted = 6 }).action == "plein", "toutes les colonnes posees : plein")
  local ab = gw({ input = 7.5, bands = 2, posted = 2 })
  want(ab.action == "ajouter_bandes" and ab.n == 2, "colonnes en attente de minerai : 2 bandes de plus (" .. tostring(ab.n) .. ")")
  want(gw({ input = 15, bands = 4 }).action == "equilibre", "2 colonnes pleines : equilibre")
  want(gw({ input = 7.5, bands = 2, bands_max = 2 }).action == "sans_minerai", "gisement plein, colonnes en attente : jamais de retrait")
  want(gw({ input = 0 }).action == "sans_entree", "aucune entree")
  want(gw({ cols = 0 }).action == "invalide", "aucune colonne reservee : invalide")

  -- 6. Journal
  local line = Mf.line("azure", { id = 7, res = "minerai", tiles = 1000 }, "DECIDE", "6 ligne(s)", z, "plan verifie", 12.25)
  want(line:find("[FO-MEGA] azure : gisement 7 (minerai, 1000 tuiles) : DECIDE", 1, true) == 1, "journal : tete")
  for _, frag in ipairs({ "83 foreuse(s)", "bus 6 ligne(s)", "6 colonne(s) x 24 four(s) = 133 four(s)", "rectangle 61 x", "depart 6 colonne(s)", "a 12.2 min" }) do
    want(line:find(frag, 1, true) ~= nil, "journal : " .. frag .. " (" .. line .. ")")
  end
  local l2 = Mf.line(nil, { id = 3 }, "REFUS", "minerai sans four de champ", nil, nil, 1)
  want(l2:find("player", 1, true) ~= nil and l2:find("REFUS : minerai sans four de champ", 1, true) ~= nil, "journal d'un refus")
  want(Mf.signature(nil) == "-" and Mf.signature(z) ~= Mf.signature(z2), "signature")
  return bad, n
end

local Mf = require("shared.team.mega_fonderie")
local bad, nwant = suite(Mf)
for _, m in ipairs(bad) do check(false, m) end
pass = pass + nwant - #bad -- chaque assertion juste de la suite de référence compte

-- 7. Coût du pire cas (instructions, déterministe) : la décision complète du runtime, au plus COST_MAX milliers
local function decision_cost(M)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1000)
  local z = M.size(ref({ tiles = 1e6, belts = { { lane = 22.5 } } }))
  local sm = M.sample(z)
  local b = M.verify(M.block(sm), sm)
  local cc = M.col_cost(z)
  debug.sethook()
  return c, #b, cc
end
do
  local c, nbad = decision_cost(Mf)
  print(string.format("[MEGA] cout du pire cas (12 lignes x 64 fours, echantillon) : %d milliers d'instructions (plafond %d)", c, COST_MAX))
  check(c <= COST_MAX and nbad == 0, string.format("cout du pire cas %d k <= %d k, plan juste", c, COST_MAX))
end

-- 8. Mutants
local MUTANTS = {
  { "voies de minerai par ligne", "local kpl = fuel and 1 or 2", "local kpl = 2" },
  { "seuil de lignes pleines", "if (z.full_lines or 0) < Mf.MIN_LINES then", "if (z.full_lines or 0) < 0 then" },
  { "courant ignore", "if inp.power ~= true then return", "if false then return" },
  { "crise ignoree", "if inp.crisis then return", "if false then return" },
  { "poteaux trop espaces", "local stepv = floor(min(2 * r + 1, r + fs + 1) / fs + EPS) * fs", "local stepv = floor((2 * r + 3) / fs + EPS) * fs" },
  { "controle du courant aveugle", "if not cover[(a.u + 4096) * K + a.v + 4096] then", "if false then" },
  { "bras de sortie de droite a l'envers", "arm(u0 + 2 * fs + 5, v, -1, 0, \"sortie\", c)", "arm(u0 + 2 * fs + 5, v, 1, 0, \"sortie\", c)" },
  { "derniere colonne pleine", "local last = min(ncol, max(1, ceil((ore - (lines - 1) * per_eff) / rate - EPS)))", "local last = ncol" },
  { "plein jamais dit", "(a == \"retirer_foreuses\" and posted < cols)", "(a == \"retirer_foreuses\")" },
  { "bus sans borne", "if lines > Mf.MAX_LINES then", "if false then" },
  { "echantillon mal compte", "c.furnaces = (k - 1) * z.ncol + c.last", "c.furnaces = k * z.ncol" },
  { "garder sans signature", "if inp.sig ~= nil and inp.sig == Mf.signature(z) then", "if inp.sig ~= nil then" },
  { "bras d'entree sans controle de debit", "if ins.rate * Mf.PICKUP + EPS < rate + fuel_rate then", "if false then" },
  { "tapis le plus lent toujours", "if lines <= Mf.MAX_LINES then break end", "if true then break end" },
  { "bras de quai a l'envers", "arm(uo + sg, v, -sg, 0, \"quai\", k)", "arm(uo + sg, v, sg, 0, \"quai\", k)" },
  { "fils non controles", "if n ~= np then no(", "if false then no(" },
  { "voie de sortie non bornee", "if nmax > nside_out then", "if false then" },
  { "echantillon de 12 colonnes (cout)", "k = max(1, min(z.cols, k or 3))", "k = max(1, min(z.cols, k or 12))" },
  { "chevauchement non vu", "if at[k] then no(", "if false then no(" },
  { "poteaux de premiere colonne oublies", "if c == 1 or r < 2 then pcols[#pcols + 1] = u0 + 1 end", "if r < 2 then pcols[#pcols + 1] = u0 + 1 end" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local s2, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if n ~= 1 then
    check(false, "mutant introuvable (" .. n .. " substitution(s)) : " .. m[1])
  else
    local ok, Mm = pcall(load_mod, s2)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Mm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if not killed and ok then
      local okc, c, nbad = pcall(decision_cost, Mm)
      killed = (not okc) or c > COST_MAX or nbad > 0
    end
    if killed then refused = refused + 1 else print("[MEGA] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[MEGA] mutants refuses : %d sur %d", refused, #MUTANTS))
print(string.format("[MEGA] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
