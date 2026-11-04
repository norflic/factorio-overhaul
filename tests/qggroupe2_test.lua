--[[
  Lot QG-GROUPE2 : banc HORS JEU de la pose groupée des tourelles du QG (shared/team/qg_groupe.lua) et du péril au point le plus faible
  (shared/team/survie_qg.lua, Sq.peril avec `facing` et `hq`). Lancement : lua5.2 tests/qggroupe2_test.lua (racine du mod).
  Côtés, mémoire des pertes, côté de départ par les nids, choix des côtés (90° au moins, pas de va-et-vient), lignes (nombre constant, écart
  tenu, couvrent le coffre), places libres (rien ne bouge), appui au point le plus faible (la mesure de QGSURVIE2 : une par côté = UNE
  tourelle ; une tourelle d'avant-poste loin du coffre n'est pas un point d'entrée), péril (cause « dispersion » sans tourelle de plus,
  tourelles voulues relatives au groupe « hq »). Mutants des deux fichiers.
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function read_src(path)
  local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end
local SRC_G = read_src("shared/team/qg_groupe.lua")
local SRC_S = read_src("shared/team/survie_qg.lua")
local function load_src(src, name) return assert(load(src, "@" .. name))() end

local function dist(a, b) return math.sqrt((a.dx - b.dx) ^ 2 + (a.dy - b.dy) ^ 2) end

local function facts(G, Sq)
  local r = {}
  r.sides = table.concat({ G.side(0, -10), G.side(10, -10), G.side(10, 0), G.side(10, 10), G.side(0, 10), G.side(-10, 10),
    G.side(-10, 0), G.side(-10, -10) }, ",")
  r.edge = tostring(G.side(1000, -414)) .. "," .. tostring(G.side(1000, -415))
  r.centre = tostring(G.side(0, 0))
  r.gap = G.gap_sides(1, 8) .. "," .. G.gap_sides(1, 5) .. "," .. G.gap_sides(2, 4)
  -- mémoire : une perte à 39 tuiles au sud compte, une à 41 non ; une vieille de 31 min part
  local marks = {}
  G.note(marks, 0, 0, 39, 2)
  G.note(marks, 0, 0, 41, 5)
  G.note(marks, 100, 30, 30, 1) -- SE, 42,4 tuiles : hors rayon
  G.note(marks, 200, 20, 20, 1) -- SE
  G.note(marks, 300, -1, -20, 1) -- N
  r.n_marks = #marks
  local rk = G.rank(marks, 400)
  r.rank = (rk[1] and rk[1].side or 0) .. ":" .. (rk[1] and rk[1].w or 0) .. "," .. (rk[2] and rk[2].side or 0) .. "," .. (rk[3] and rk[3].side or 0)
  local old = {}
  G.note(old, 0, 0, 10, 1)
  G.note(old, G.MEMORY + 1, 10, 0, 1)
  r.expire = #old .. "," .. old[1].side
  -- départ : le nid le plus proche l'emporte sur deux nids lointains ; sans nid, côté par défaut (S)
  local pr = G.prior({ { dx = 100, dy = 0 }, { dx = 0, dy = -300 }, { dx = 10, dy = -290 } })
  r.prior = pr[1].side .. ":" .. pr[1].w .. "," .. pr[2].side
  r.default = table.concat(G.choose_sides({}, 2, nil), ",")
  r.keep_none = table.concat(G.choose_sides({}, 2, { 3 }), ",")
  -- choix des côtés : S le plus lourd, SE adjacent écarté, N pris ; pas de va-et-vient à 80 %, départ sous 75 %
  r.choose = table.concat(G.choose_sides({ { side = 5, w = 10 }, { side = 4, w = 8 }, { side = 1, w = 3 } }, 2, nil), ",")
  r.keep = table.concat(G.choose_sides({ { side = 3, w = 10 }, { side = 5, w = 8 } }, 2, { 5, 1 }), ",")
  r.leave = table.concat(G.choose_sides({ { side = 3, w = 10 }, { side = 5, w = 7 } }, 2, { 5, 1 }), ",")
  -- tailles : 4 -> une ligne de 4 ; 5 -> 3 + 2 ; 8 -> 4 + 4 ; 9 sur 2 côtés -> 5 + 4 (jamais plus de lignes que de côtés)
  r.sizes = table.concat(G.sizes(4, 2), "+") .. "|" .. table.concat(G.sizes(5, 2), "+") .. "|" .. table.concat(G.sizes(8, 2), "+") .. "|" ..
    table.concat(G.sizes(9, 2), "+") .. "|" .. table.concat(G.sizes(3, 1), "+") .. "|" .. #G.sizes(0, 2)
  -- places : 4 au sud, écart 6 -> ligne y = 10, du centre vers les bouts ; toutes couvrent le coffre (portée 18)
  local s4 = G.slots(4, { 5 }, 6)
  local xs, cov = {}, 0
  for _, p in ipairs(s4) do
    xs[#xs + 1] = p.dx .. ":" .. p.dy
    if G.covers(p.dx, p.dy, 0, 0, 18) then cov = cov + 1 end
  end
  r.slots4, r.cov4 = table.concat(xs, " "), cov
  local s7 = G.slots(7, { 5, 1 }, 6)
  r.n7 = #s7
  local mind, maxin = math.huge, 0
  for i = 1, #s7 do
    for j = i + 1, #s7 do
      local dd = dist(s7[i], s7[j])
      if dd < mind then mind = dd end
      if s7[i].group == s7[j].group and dd > maxin then maxin = dd end
    end
  end
  r.min7, r.maxin7 = math.floor(mind * 10 + 0.5), math.floor(maxin * 10 + 0.5)
  local s3 = G.slots(3, { 4 }, 6)
  r.slots3 = s3[1].dx .. ":" .. s3[1].dy .. " " .. s3[2].dx .. ":" .. s3[2].dy .. " " .. s3[3].dx .. ":" .. s3[3].dy
  r.noside = #G.slots(4, {}, 6)
  -- places libres : une tourelle à 1,5 tuile d'une place la prend ; à 2 tuiles, non (rien ne bouge, seules les places vides servent)
  local abs = { { x = 3, y = 10 }, { x = -3, y = 10 }, { x = 9, y = 10 } }
  local fr = G.free(abs, { { x = 3, y = 11.5 }, { x = -3, y = 12 } })
  r.free = #fr .. ":" .. fr[1].x .. "," .. fr[2].x
  -- appui : une par côté (QGSURVIE2, 10 à 12 tuiles du coffre) -> UNE tourelle au point le plus faible
  local ring = { { x = 12, y = 0, s = 1000, p = true }, { x = -12, y = 0, s = 1000, p = true }, { x = 0, y = 10, s = 1000, p = true },
    { x = 0, y = -10, s = 1000, p = true } }
  local w, t, _, e = G.support(ring, 18, 0, 0)
  r.ring = w .. "/" .. t .. "/" .. e
  -- ligne de 4 : le cracheur d'un bout est sous 2 tourelles (le double de l'anneau)
  local line = {}
  for _, p in ipairs(s4) do line[#line + 1] = { x = p.dx, y = p.dy, s = 1000, p = true } end
  local w2, t2 = G.support(line, 18, 0, 0)
  r.line = w2 .. "/" .. t2
  -- tourelle d'avant-poste à 40 tuiles : comptée au total, jamais point d'entrée (elle ne défend pas le coffre)
  local mixed = { { x = 3, y = 10, s = 1000, p = true }, { x = -3, y = 10, s = 1000, p = true }, { x = 40, y = 0, s = 1000, p = false } }
  local w3, t3, i3, e3 = G.support(mixed, 18, 0, 0)
  r.mixed = w3 .. "/" .. t3 .. "@" .. tostring(i3) .. "/" .. e3
  local we = G.support({ { x = 0, y = 0, s = 500, p = true }, { x = 31, y = 0, s = 1000, p = true } }, 18, -10, 0)
  r.edge18 = we
  r.cover = tostring(G.covers(18, 0, 0, 0, 18)) .. "," .. tostring(G.covers(18.1, 0, 0, 0, 18))
  r.facing = G.facing(4023, 1000, 7000) .. "," .. G.facing(2296, 4000, 4000) .. "," .. G.facing(100, 0, 0) .. "," .. G.facing(500, 900, 600)
  -- Sq.peril : sans `facing`, la règle d'avant (7 tourelles armées, 4 023 PV, menace 2 000 : hors de péril, comme 0.6.45 avant la chute)
  local base = { threat = 2000, armed_value = 4023, turret_value = 574, turrets = 7, armed = 7, cap = 8 }
  local p0 = Sq.peril(base)
  r.p0 = tostring(p0.peril) .. "," .. tostring(p0.hq_want)
  -- avec facing (anneau : une tourelle, 574 PV) : péril « dispersion », aucune tourelle de plus, groupe « hq » à 4 -> 4 voulues
  local a1 = {}
  for k, v in pairs(base) do a1[k] = v end
  a1.facing, a1.hq = 574, 4
  local p1 = Sq.peril(a1)
  r.p1 = tostring(p1.peril) .. "," .. tostring(p1.cause) .. "," .. p1.fresh .. "," .. tostring(p1.hq_want) .. "," .. p1.gap
  -- menace plus grande que la somme : « menace », tourelles de plus comptées sur le groupe « hq » (4 + fresh), jamais sur le recensement
  local a2 = { threat = 4000, armed_value = 2296, turret_value = 574, turrets = 4, armed = 4, cap = 8, facing = 1148, hq = 2 }
  local p2 = Sq.peril(a2)
  r.p2 = tostring(p2.cause) .. "," .. p2.want .. "," .. p2.fresh .. "," .. tostring(p2.hq_want)
  -- point le plus faible assez fort : hors de péril ; sortie avec hystérésis
  local a3 = { threat = 1000, armed_value = 2296, turret_value = 574, turrets = 4, armed = 4, cap = 8, facing = 1250, hq = 4 }
  r.p3 = tostring(Sq.peril(a3).peril)
  a3.was = true
  r.p3b = tostring(Sq.peril(a3).peril)
  -- munitions vides : la cause reste « munitions »
  local a4 = { threat = 2000, armed_value = 574, turret_value = 574, turrets = 7, armed = 1, cap = 8, facing = 574, hq = 4 }
  r.p4 = tostring(Sq.peril(a4).cause)
  return r
end

local F = facts(load_src(SRC_G, "shared.team.qg_groupe"), load_src(SRC_S, "shared.team.survie_qg"))
check(F.sides == "1,2,3,4,5,6,7,8", "huit côtés N, NE, E, SE, S, SO, O, NO (y vers le bas) : " .. F.sides)
check(F.edge == "3,2", "bord du secteur E/NE à tan(22,5°) : " .. F.edge)
check(F.centre == "nil", "centre sans côté")
check(F.gap == "1,4,2", "écart circulaire des côtés : " .. F.gap)
check(F.n_marks == 3, "mémoire : hors de 40 tuiles, rien n'est noté (" .. F.n_marks .. ")")
check(F.rank == "5:2,1,4", "rang des côtés : S (tourelle, 2) puis N et SE à égalité, côté croissant : " .. F.rank)
check(F.expire == "1,3", "une marque de plus de 30 min part : " .. F.expire)
check(F.prior == "3:100,1", "départ : le nid le plus proche (E, 100 tuiles) l'emporte sur deux nids au N à 290-300 tuiles : " .. F.prior)
check(F.default == "5", "sans marque ni nid : côté par défaut S")
check(F.keep_none == "3", "sans marque : côtés retenus avant")
check(F.choose == "5,1", "côtés : S, puis N (SE adjacent écarté) : " .. F.choose)
check(F.keep == "5,1", "pas de va-et-vient : anciens côtés gardés à 80 % : " .. F.keep)
check(F.leave == "3,5", "anciens côtés quittés sous 75 % : " .. F.leave)
check(F.sizes == "4|3+2|4+4|5+4|3|0", "tailles des lignes : " .. F.sizes)
check(F.slots4 == "3:10 -3:10 9:10 -9:10", "4 au sud en ligne serrée du centre vers les bouts : " .. F.slots4)
check(F.cov4 == 4, "les 4 places de la ligne couvrent le coffre (portée 18)")
check(F.n7 == 7, "nombre CONSTANT : 7 tourelles, 7 places")
check(F.min7 == 60, "écart de pose tenu (6 tuiles) entre toutes les places : " .. F.min7)
check(F.maxin7 == 180, "une ligne de 4 tient dans la portée (18 tuiles de bout en bout) : " .. F.maxin7)
check(F.slots3 == "7:7 11:3 3:11", "3 au SE : centre (7, 7), ligne NE-SO : " .. F.slots3)
check(F.noside == 0, "sans côté, aucune place")
check(F.free == "2:-3,9", "places libres : prise à 1,5 tuile, libre à 2 tuiles ; ordre gardé : " .. F.free)
check(F.ring == "1000/4000/4", "une par côté (mesure QGSURVIE2) : UNE tourelle au point le plus faible : " .. F.ring)
check(F.line == "2000/4000", "ligne de 4 : le cracheur d'un bout est sous 2 tourelles : " .. F.line)
check(F.mixed == "2000/3000@1/2", "tourelle d'avant-poste loin du coffre : au total, jamais point d'entrée : " .. F.mixed)
check(F.edge18 == 1000, "portée bornes comprises : " .. tostring(F.edge18))
check(F.cover == "true,false", "couvre le coffre à 18 tuiles, pas à 18,1")
check(F.facing == "574,2296,0,500", "valeur face à une vague = valeur × appui / total : " .. F.facing)
check(F.p0 == "false,nil", "Sq.peril sans facing : règle d'avant (hors de péril à 4 023 PV) : " .. F.p0)
check(F.p1 == "true,dispersion,0,4,1926", "facing d'une tourelle : péril « dispersion », 0 tourelle de plus, hq 4 voulues : " .. F.p1)
check(F.p2 == "menace,8,4,6", "menace : 8 voulues (plafond), 4 de plus comptées sur le groupe hq (2 + 4), pas sur le recensement : " .. F.p2)
check(F.p3 == "false" and F.p3b == "true", "point le plus faible = cible : hors de péril ; déjà en péril, il faut 110 % pour sortir (hystérésis)")
check(F.p4 == "munitions", "tourelles vides : cause munitions")

local function mutate(src, old, new)
  local a, b = src:find(old, 1, true)
  if not a then return nil end
  return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local mutants = {
  { "G", "nord et sud inversés", "return dy < 0 and 1 or 5", "return dy < 0 and 5 or 1" },
  { "G", "rayon des marques ignoré", "if w <= 0 or dx * dx + dy * dy > G.MARK_R * G.MARK_R then return nil end", "if w <= 0 then return nil end" },
  { "G", "mémoire sans fin", "if tick - m.t <= G.MEMORY then keep[#keep + 1] = m end", "keep[#keep + 1] = m" },
  { "G", "nids sans distance", "w[s] = w[s] + math.floor(1000000 / math.max(1, dx * dx + dy * dy))", "w[s] = w[s] + 1" },
  { "G", "pas de côté par défaut", "    return { G.DEFAULT_SIDE }\n", "    return {}\n" },
  { "G", "côtés adjacents permis", "if G.gap_sides(s, r.side) < 2 then ok = false end", "if G.gap_sides(s, r.side) < 1 then ok = false end" },
  { "G", "va-et-vient", "if wp * 100 >= ranked[1].w * G.KEEP_PCT then return prev end", "" },
  { "G", "lignes de 8", "G.GROUP_MAX = 4 ", "G.GROUP_MAX = 8 " },
  { "G", "reste perdu", "for g = 1, ng do out[g] = base + (g <= extra and 1 or 0) end", "for g = 1, ng do out[g] = base end" },
  { "G", "pas de tangente", "local tx, ty = -u[2], u[1]", "local tx, ty = u[1], u[2]" },
  { "G", "anneau d'avant (une par côté)", "local cx, cy = u[1] * G.RADIUS, u[2] * G.RADIUS", "local cx, cy = u[1] * G.RADIUS * 3, u[2] * G.RADIUS * 3" },
  { "G", "place prise ignorée", "if dx * dx + dy * dy < G.FREE_R * G.FREE_R then taken = true end", "" },
  { "G", "appui = total", "if weakest == nil or sum < weakest then weakest, worst = sum, i end", "if weakest == nil or sum > weakest then weakest, worst = sum, i end" },
  { "G", "tueur au contact", "if l > 0 then px, py = px + ux / l * G.REACH, py + uy / l * G.REACH end", "" },
  { "G", "toute tourelle point d'entrée", "    if a.p then\n", "    if true then\n" },
  { "G", "portée exclusive", "if dx * dx + dy * dy <= r2 then sum = sum + num(b.s) end", "if dx * dx + dy * dy < r2 then sum = sum + num(b.s) end" },
  { "G", "valeur entière gardée", "return math.floor(value * weakest / total)", "return math.floor(value)" },
  { "S", "facing ignoré", "local held = a.facing ~= nil and num(a.facing) or armed_value", "local held = armed_value" },
  { "S", "pas de dispersion", "if out.cause == \"menace\" and a.facing ~= nil and armed_value >= limit then out.cause = \"dispersion\" end", "" },
  { "S", "hq_want sur le recensement", "if a.hq ~= nil then out.hq_want = num(a.hq) + out.fresh end", "if a.hq ~= nil then out.hq_want = out.want end" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local sg, ss = SRC_G, SRC_S
  local txt
  if m[1] == "G" then txt = mutate(SRC_G, m[3], m[4]); sg = txt else txt = mutate(SRC_S, m[3], m[4]); ss = txt end
  if not txt then check(false, "mutant « " .. m[2] .. " » : texte introuvable")
  else
    local ok, M = pcall(function() return facts(load_src(sg, "shared.team.qg_groupe"), load_src(ss, "shared.team.survie_qg")) end)
    local same = ok
    if ok then for k, v in pairs(F) do if M[k] ~= v then same = false end end end
    if not same then killed = killed + 1 end
    check(not same, "mutant « " .. m[2] .. " » détecté")
  end
end
print(string.format("[QG-GROUPE2] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[QG-GROUPE2] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
