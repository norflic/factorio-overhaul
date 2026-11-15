--[[
  C2-PAVAGE (chantier 2.1 du DC, 15/11 : « grands gisements presque vides, gisement du spawn traversé de tapis, gisements collés, falaises »).
  Test PUR du plan de champ (shared/team/champ.lua, Ch.plan) sur des formes de gisement : couverture = tuiles de minerai dans la zone d'une
  foreuse du plan / tuiles du gisement (champ_verif, Cv.verify), plan VALIDE (Cv.verify : rep.ok, aucun chevauchement, foreuse sans courant,
  voie mêlée, raccord faux...). Deux specs RÉELLES de la carte du DC (tests/fixtures/champ_*_dc.lua, Profiler.dump) et des formes
  synthétiques (tapis jaune seul, sans répartiteur : début de partie, comme la carte du DC).

  Couverture avant / après le lot (mesurée par ce test, plan pur) :
    ovale 45x28 isolé                        100 / 100
    fer collé au cuivre (est)                100 / 100
    fer entre cuivre et charbon               68 / 100
    tapis traversant, souterrains            100 / 100   (lot ENJAMBE : s'applique)
    tapis traversant, sans souterrain        100 / 100   (la bande se coupe en deux bouts, chacun sa colonne)
    deux tapis traversants, souterrains       97 /  97
    deux tapis traversants, sans souterrain   56 /  56   (le milieu n'a aucune sortie sans souterrain : limite connue)
    falaise en travers                        82 /  93
    base au bout ouest                       100 / 100
    dc joueur fer 1 (carte du DC)             42 /  83
    dc emerald fer 3 (carte du DC)            47 /  73   (sous l'objectif : couloir d'accès sur tout le bord ouest)

  Maillons coupés (shared/team/champ.lua, ONCE.bare / Ch.extend_other / Ch.prune_unpowered ; shared/team/champ_colonne.lua, Co.away),
  chacun avec un MUTANT (substitution unique dans le source, module rechargé : la suite doit échouer) :
    extend   bout orphelin -> ses foreuses au groupe de l'autre bout (tapis prolongé)          falaise 93 -> 82
    release  premier bout orphelin des deux : collecteur rendu, l'autre bout essaie             entre 100 -> 40
    wide     colonne ailleurs cherchée sur toute la largeur lue (avant : deux pas de bande)    emerald 73 -> 47 (ROC-097)
    capw     plafond du tracé de la recherche large (Ch.CFG.away_cap_wide)                      emerald 73 -> 47
    pwin     le lien ne prend pas les places des poteaux des foreuses                           joueur 83 -> 34
    front    le lien ne passe pas devant le bout d'un tapis déjà posé                           joueur : voies mêlées
    relf     le lien ne passe pas devant un bout de tapis de SA colonne                         joueur : voies mêlées
    prune    foreuse sans place de poteau retirée                                               joueur : sans courant
  Lancement (racine du mod) : lua5.2 tests/c2_pavage_test.lua   -> [C2-PAVAGE] BILAN : N OK, 0 ECHEC(S)  (environ 2 min)
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[C2-PAVAGE] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

local SRC_CH = read("shared/team/champ.lua")
local SRC_CO = read("shared/team/champ_colonne.lua")
local function sub1(src, a, b, name)
  local i, j = src:find(a, 1, true)
  assert(i, "mutant introuvable : " .. name)
  assert(not src:find(a, j + 1, true), "mutant ambigu : " .. name)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
-- (re)charge champ_colonne puis champ (champ lit champ_colonne au chargement) ; rend Ch, Cv
local function load_mods(ch_src, co_src)
  for _, m in ipairs({ "shared.team.champ_colonne", "shared.team.champ", "shared.team.champ_verif" }) do package.loaded[m] = nil end
  package.loaded["shared.team.champ_colonne"] = assert(load(co_src, "=shared/team/champ_colonne.lua", "t", _ENV))()
  package.loaded["shared.team.champ"] = assert(load(ch_src, "=shared/team/champ.lua", "t", _ENV))()
  return package.loaded["shared.team.champ"], require("shared.team.champ_verif")
end

---------------------------------------------------------------------------------------------------
-- Formes
---------------------------------------------------------------------------------------------------
local function K(x, y) return (x + 50000) * 100000 + (y + 50000) end -- (Ch.key)
local function ellipse(cx, cy, a, b, skip)
  local out = {}
  for x = cx - a, cx + a do for y = cy - b, cy + b do
    if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 and not (skip and skip(x, y)) then out[#out + 1] = x; out[#out + 1] = y end
  end end
  return out
end
local function set_of(l, s) s = s or {} for i = 1, #l - 1, 2 do s[K(l[i], l[i + 1])] = true end return s end
local function spec_of(ore, o)
  o = o or {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for i = 1, #ore - 1, 2 do
    x0, x1 = math.min(x0, ore[i]), math.max(x1, ore[i])
    y0, y1 = math.min(y0, ore[i + 1]), math.max(y1, ore[i + 1])
  end
  -- fenêtre lue comme en jeu (script/team/champ.lua, Champ.CFG : margin_u 120 le long de l'axe long, margin_v 10 en travers)
  local win = (y1 - y0 > x1 - x0) and { x0 - 10, y0 - 120, x1 + 10, y1 + 120 } or { x0 - 120, y0 - 10, x1 + 120, y1 + 10 }
  local res, foreign = set_of(ore), {}
  for _, l in ipairs(o.others or {}) do set_of(l, res); set_of(l, foreign) end
  local coal = o.coal or ellipse(0, 70, 8, 8)
  set_of(coal, res)
  return { ore = ore, blocked = o.blocked or {}, mine = {}, soft = {}, foreign = foreign, nforeign = 0, resources = res,
    drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = { { lane = 7.5 } }, furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
    target = o.target or { x = 0, y = 200 }, max_side = 8, design = "colonne", window = win,
    coal = { tiles = coal, rate = 0.5, foreign = {}, nforeign = 0 }, logistics = o.logistics or { splitter = false }, ug_tiles = {} }
end
local function belts_across(xs, ug)
  local bl = {}
  for _, x in ipairs(xs) do for y = -60, 60 do bl[K(x, y)] = "transport-belt" end end
  return spec_of(ellipse(0, 0, 45, 28), { blocked = bl, logistics = ug and { splitter = false, underground = 5 } or nil })
end
local FORMES = {
  { "ovale", 0.80, function() return spec_of(ellipse(0, 0, 45, 28)) end },
  { "colle", 0.80, function()
    local cu = ellipse(75, 0, 32, 30)
    local cs = set_of(cu)
    return spec_of(ellipse(0, 0, 45, 28, function(x, y) return cs[K(x, y)] end), { others = { cu } }) end },
  { "entre", 0.80, function()
    local cu, co = ellipse(75, 0, 32, 34), ellipse(-75, 0, 32, 34)
    local cs = set_of(co, set_of(cu))
    return spec_of(ellipse(0, 0, 48, 28, function(x, y) return cs[K(x, y)] end), { others = { cu, co }, coal = co }) end },
  { "tapis-ug", 0.80, function() return belts_across({ 5 }, true) end },
  { "tapis", 0.80, function() return belts_across({ 5 }, false) end },
  { "deux-tapis-ug", 0.80, function() return belts_across({ -15, 15 }, true) end },
  { "deux-tapis", 0.50, function() return belts_across({ -15, 15 }, false) end },
  { "falaise", 0.90, function()
    local bl = {}
    for x = -60, 60 do local y = math.floor(x / 3) - 4; bl[K(x, y)] = "cliff"; bl[K(x, y + 1)] = "cliff" end
    return spec_of(ellipse(0, 0, 45, 28), { blocked = bl }) end },
  { "base", 0.80, function()
    local bl = {}
    for x = -130, -48 do for y = -40, 40 do if (x + y) % 7 ~= 0 then bl[K(x, y)] = "reserve" end end end
    return spec_of(ellipse(0, 0, 45, 28), { blocked = bl, target = { x = -60, y = 0 } }) end },
  { "dc-joueur", 0.80, function() return dofile("tests/fixtures/champ_joueur_dc.lua").spec end },
  { "dc-emerald", 0.70, function() return dofile("tests/fixtures/champ_emerald_dc.lua").spec end },
}
local BY = {}
for _, f in ipairs(FORMES) do BY[f[1]] = f end

-- plan d'une forme : couverture (0..1) et rapport de vérification
local function measure(Ch, Cv, name)
  local spec = BY[name][3]()
  local p = Ch.plan(spec)
  if not p then return 0, nil end
  local rep = Cv.verify(p, spec)
  return rep.elec, rep, p
end

---------------------------------------------------------------------------------------------------
-- 1. Le code livré : couverture et validité par forme
---------------------------------------------------------------------------------------------------
local Ch, Cv = load_mods(SRC_CH, SRC_CO)
local got = {}
for _, f in ipairs(FORMES) do
  local cov, rep, p = measure(Ch, Cv, f[1])
  got[f[1]] = cov
  print(string.format("[C2-PAVAGE] %-14s couverture %3d %%  (seuil %d %%)  %s", f[1], math.floor(100 * cov + 0.5), math.floor(100 * f[2] + 0.5),
    rep and Cv.line(rep):gsub("^couverture [^,]*, ", "") or "pas de plan"))
  check(rep ~= nil, f[1] .. " : un plan")
  check(cov >= f[2], string.format("%s : couverture %.0f %% >= %.0f %%", f[1], 100 * cov, 100 * f[2]))
  if rep then
    check(rep.overlaps == 0 and rep.blocked == 0, f[1] .. " : ni chevauchement ni obstacle")
    check(rep.unpowered == 0, f[1] .. " : aucune foreuse ni bras sans courant (" .. rep.unpowered .. ")")
    check((rep.mixed or 0) == 0 and (rep.junction or 0) == 0, f[1] .. " : aucune voie mêlée, aucun raccord faux")
    check((rep.no_ore or 0) == 0 and rep.starved == 0, f[1] .. " : fours nourris, débits tenus")
    check(rep.components <= 1, f[1] .. " : un seul réseau électrique")
  end
end
-- déterminisme : même plan deux fois (forme où les trois maillons jouent)
do
  local _, _, p1 = measure(Ch, Cv, "falaise")
  local _, _, p2 = measure(Ch, Cv, "falaise")
  local function sig(p) local t = {} for _, e in ipairs(p.ents) do t[#t + 1] = e.kind .. e.x .. ":" .. e.y .. ":" .. e.dir end return table.concat(t, " ") end
  check(p1 and p2 and sig(p1) == sig(p2), "falaise : plan déterministe")
end

---------------------------------------------------------------------------------------------------
-- 2. Mutants : chaque maillon retiré, la suite échoue sur la forme qui le montre
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "extend", "ch", "local ext = Ch.extend_other(s, t, bo, g0, e_end)", "local ext = 0", "falaise", "cov" },
  { "release", "ch", "if o.bi == t.bi and o.side == -t.side then later = true end", "", "entre", "cov" },
  -- (ROC-097 : sur dc-joueur, les bouts dont la colonne est refusée faute de voie de charbon cherchent aussi une colonne ailleurs ; sans
  -- la recherche large, ils la trouvent sur deux pas de bande : 83 % sans ce maillon. Il se montre sur dc-emerald, 73 -> 47.)
  { "wide", "ch", "if win then r = math.max(r, win.v1 - win.v0) end", "", "dc-emerald", "cov" },
  { "capw", "ch", "cap = nrows > 2 * pitch and Ch.CFG.away_cap_wide or nil,", "cap = nil,", "dc-emerald", "cov" },
  { "pwin", "ch", "if pwin[Co.tk(u, v)] or front[Co.tk(u, v)]", "if front[Co.tk(u, v)]", "dc-joueur", "cov" },
  { "front", "ch", "if pwin[Co.tk(u, v)] or front[Co.tk(u, v)]", "if pwin[Co.tk(u, v)]", "dc-joueur", "ok" },
  { "relf", "co", "for _, r in ipairs(relf) do mine[Co.tk(s_edge + r[1], b2 + r[2])] = true end", "Co.AWAY_DETOUR = 1e9", "dc-joueur", "ok" }, -- (N098-DETOUR : sur dc-joueur, le lien qui longeait la ligne de plaques était un détour, refusé depuis ; le maillon se montre sous la règle d'avant, premier tracé gardé)
  { "prune", "ch", "  s.unpowered = Ch.prune_unpowered(s)", "  s.unpowered = 0", "dc-joueur", "ok" },
}
local killed = 0
for _, m in ipairs(MUTANTS) do
  local ch_src, co_src = SRC_CH, SRC_CO
  if m[2] == "ch" then ch_src = sub1(SRC_CH, m[3], m[4], m[1]) else co_src = sub1(SRC_CO, m[3], m[4], m[1]) end
  local MCh, MCv = load_mods(ch_src, co_src)
  local cov, rep = measure(MCh, MCv, m[5])
  local dead
  if m[6] == "cov" then dead = cov < BY[m[5]][2] and cov < got[m[5]]
  else dead = rep == nil or rep.unpowered > 0 or (rep.mixed or 0) > 0 or (rep.junction or 0) > 0 end
  print(string.format("[C2-PAVAGE] mutant %-8s %-11s couverture %3d %%%s -> %s", m[1], m[5], math.floor(100 * cov + 0.5),
    rep and string.format(", sans courant %d, voies mêlées %d", rep.unpowered, rep.mixed or 0) or "", dead and "refusé" or "SURVIT"))
  check(dead, "mutant " .. m[1] .. " refusé par la suite (" .. m[5] .. ")")
  if dead then killed = killed + 1 end
end
load_mods(SRC_CH, SRC_CO)
print(string.format("[C2-PAVAGE] MUTANTS : %d / %d refusés", killed, #MUTANTS))
print(string.format("[C2-PAVAGE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
--[[ RESTE (non traité par ce lot) :
  - « deux tapis sans souterrain » (56 %) : le tronçon entre deux tapis étrangers n'a aucune sortie tant que les souterrains ne sont pas
    recherchés ; ses foreuses ne sont pas comptées orphelines (stats.capped).
  - emerald (73 %) : un couloir d'accès (Build.couloirs) longe tout le bord ouest et coupe chaque sortie sans souterrain ; à l'est, les
    colonnes de 24 fours (64 tuiles) n'ont de place joignable que derrière un autre gisement. ]]
os.exit(fail == 0 and 0 or 1)
